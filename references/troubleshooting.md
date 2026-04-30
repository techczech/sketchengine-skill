# Sketch Engine MCP — Troubleshooting

Symptoms grouped from most common (config) to most surprising (network policy). When in doubt, work top-to-bottom.

## Quick triage of `MCP error -32603: API Error: fetch failed`

This is the catch-all error the MCP server emits when *anything* goes wrong below the application layer — auth, DNS, TLS, network, or upstream outage. The MCP itself swallows the underlying syscall error, so you have to bypass it to learn what's actually wrong.

```bash
# 1. Is the API host reachable at all?
curl -sS --max-time 8 -o /dev/null -w "HTTP %{http_code} time_connect=%{time_connect}\n" \
  https://api.sketchengine.eu/

# 2. If the above hangs/times out at TCP level, check whether www host works
curl -sS --max-time 8 -o /dev/null -w "%{http_code}\n" https://www.sketchengine.eu/

# 3. If www works but api times out, find your egress IP and check for blocklisting
curl -sS https://api.ipify.org
whois <ip-from-above> | grep -iE "netname|descr|origin"
```

Interpretation:

| Pattern | Likely cause | Fix |
|---|---|---|
| HTTP 200 from both | Auth or quota issue | See "Auth/quota" section |
| `api` times out, `www` works, your IP belongs to a VPN AS (Mullvad/Proton/Packethub/etc.) | **VPN block** | Disconnect VPN, or split-tunnel the binary |
| Both time out, general internet works | Routing / firewall on your network | Try a different network |
| Both time out, no internet | Local network problem | Outside scope of this skill |

## VPN / IP block

Sketch Engine's API tier (`app.sketchengine.eu` cluster) blocks packets from common commercial-VPN exit ranges at the firewall level. Their CDN-fronted `www.sketchengine.eu` doesn't apply this filter, which produces a confusing split where the *website* works but the *API* hangs. Fingerprint:

- `curl https://api.sketchengine.eu/` times out instantly with `time_connect=0` (drop-on-SYN, not slow response)
- `curl https://www.sketchengine.eu/` returns HTTP 200 normally
- Your public IP (from `curl https://api.ipify.org`) belongs to an ASN like Mullvad/Proton/Packethub/M247 etc.

The dropped-SYN behaviour gets *worse* the more you retry, because the firewall escalates from "TLS reset" to "no response at all" once it sees repeated probes from a flagged IP. If your debugging seems to be making things worse, suspect this.

Fixes, in increasing effort:

1. **Disconnect the VPN, retry.** Conclusive in ~10 seconds — if it's the VPN, the smoke test will pass immediately afterwards.
2. **Split-tunnel the MCP binary.** In Mullvad: Settings → Split tunneling → exclude `~/.local/bin/sketch-engine-mcp` (and `~/.local/bin/bws` if your launcher fetches secrets). In Proton VPN: Profiles → Split tunneling → app exclusions.
3. **Route 95.129.101.0/24 outside the tunnel** at the network layer. Heavier; useful when you can't pin per-binary.
4. **Different VPN exit.** Mostly hit-or-miss; institutional-research-friendly providers exist but availability varies.

## Auth / quota

- **`Invalid API key`** — regenerate via My Account → API Key on sketchengine.eu. Old keys rotate occasionally. If you store the key in Bitwarden Secrets Manager, update the secret value with `bws secret edit --value "<new-key>" <secret-id>` and then restart Claude Code so the MCP server respawns with the new key.
- **`Quota exceeded`** — Sketch Engine accounts have monthly query limits; check My Account → Subscription. Word-Sketch and CQL queries are more expensive than `get_corpora`.

## Launcher-script pattern (keeps the API key out of MCP config files)

The most defensible way to keep `SKETCH_ENGINE_API_KEY` out of any JSON config is to register a launcher script as the MCP `command`. The launcher fetches the key at runtime from a secrets manager, exports it into the env, then `exec`s the real binary. Sketch of the pattern with [Bitwarden Secrets Manager](https://bitwarden.com/help/secrets-manager-cli/) (`bws`):

```bash
#!/usr/bin/env bash
# ~/.local/bin/sketch-engine-mcp-launcher
set -euo pipefail
# Fetch BWS_ACCESS_TOKEN from wherever you keep it (env var, macOS Keychain, etc.)
: "${BWS_ACCESS_TOKEN:?need BWS_ACCESS_TOKEN}"
SKETCH_ENGINE_API_KEY="$(bws secret get <SECRET-ID> --output json | jq -r .value)"
export SKETCH_ENGINE_API_KEY
unset BWS_ACCESS_TOKEN  # don't pivot wider vault access into the MCP process
exec "$HOME/.local/bin/sketch-engine-mcp" "$@"
```

Then in your MCP config, register `~/.local/bin/sketch-engine-mcp-launcher` as the `command` instead of the binary directly, and omit the `env.SKETCH_ENGINE_API_KEY` field. The same idea works with `op` (1Password), `pass`, `vault`, AWS Secrets Manager, etc. — adapt the secret-fetch line to your tool.

Common failure modes for this pattern:

- **`Doesn't contain a decryption key`** from `bws secret get` — *despite the name*, this almost always means **bws got an empty/missing access token**, not a vault crypto problem. Verify your token-fetch path actually returns a non-empty string before launching.
- **Launcher exec'd, MCP connects, but tool calls fail with `fetch failed`** — the MCP server was launched at session start with whatever was in env then. If you fixed the launcher mid-session, restart Claude Code so the MCP respawns. `claude mcp list` will still show the server as connected even when its in-memory env is stale.

## macOS Gatekeeper

- **Binary refuses to launch on macOS** — Gatekeeper quarantine. Run:

  ```bash
  xattr -d com.apple.quarantine ~/.local/bin/sketch-engine-mcp
  xattr -d com.apple.quarantine ~/.local/bin/sketch-engine-mcp-launcher  # if also flagged
  ```

  Or right-click → Open in Finder once and confirm the override prompt.

## Tool registration

- **MCP tool not visible in Claude Code** — `claude mcp list` to confirm the server is registered. If listed but tools don't appear, restart the Claude Code session (or `/mcp` reconnect). If not listed, re-run `scripts/configure-mcp.sh` for the right scope.

## `"error": "Unknown action"` from the API

If a tool call returns a JSON body like:

```json
{"error": "Unknown action", "api_version": "5.85.8", "request": {...}}
```

…the upstream Sketch Engine API has rejected the call because the binary is hitting a **deprecated CGI endpoint**. Sketch Engine has two API conventions live:

- **Modern REST**: `https://api.sketchengine.eu/ca/api/<resource>` — used by `get_corpora` and `get_keywords` in the ricCap binary, and these work.
- **Legacy CGI**: `https://api.sketchengine.eu/bonito/run.cgi/?action=<name>` — used internally by `get_concordance`, `get_collocations`, `get_frequency_distribution`, and `execute_cql_query`. **The actions these tools invoke have been retired or moved**, hence "Unknown action."

Confirmed broken on the upstream binary as of 2026-04-29 (`ricCap/sketch-engine-mcp-server` API version 5.85.8, manatee 2.36.7). The ricCap binary is mid-migration to the new REST API; word-sketch / wordlist / corpora / keywords / corpus-info work, but the four foundational concordance-family tools do not.

**Workaround until upstream fixes it**: use the Sketch Engine web UI for concordance, collocations, frequency, and CQL queries. Word sketches, keywords, and word-/corpus-list operations *do* work through this skill and are still useful for: contrastive corpus analysis, vocabulary teaching, lexicographic exploration of grammatical relations, and corpus inventorying.

If you fix the upstream binary, please consider opening a PR at <https://github.com/ricCap/sketch-engine-mcp-server> — the project is "preview" tagged with no recent commits, so external contributions are likely welcome.

## Empty results

- **Tool calls succeed but return empty results** — the corpus name is wrong, or your account doesn't license that corpus. Always start by listing corpora (`get_corpora`) and copy the exact `corpname` value (e.g. `preloaded/bnc2`, `preloaded/ententen21_tt31`). The user-friendly names in `references/corpora.md` ("BNC", "COCA", "Hansard") are *category labels*, not API identifiers, and some of them — notably COCA, Hansard — are gated behind subscription tiers and may not appear in your `get_corpora` response at all.

## Response is too large to read

- **`Response too large (N tokens). Full data cached at: cache/<hash>.json`** — this is the MCP server's built-in defence against blowing up the LLM context window with raw corpus data. The full payload is on disk; read it via the file path the response cites. To avoid hitting this in the first place, narrow your query (page size, attribute filtering, smaller corpus, more specific CQL) before issuing it. The cache is per-project, in `cache/` next to SKILL.md.
