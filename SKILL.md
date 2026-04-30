---
name: sketchengine-skill
description: |
  Set up and use the Sketch Engine MCP server (ricCap/sketch-engine-mcp-server) to give Claude direct access to Sketch Engine corpora — Word Sketches, Concordances, Collocations, Word Lists, Word Comparison, Frequency Analysis, Keyword Extraction, and CQL queries.

  TRIGGERS: Use when:
  - User asks to set up, install, or configure the Sketch Engine MCP / SketchEngine MCP
  - User mentions a Sketch Engine API key, sketchengine.eu, or wants to authenticate against Sketch Engine
  - User wants to run corpus-linguistics tasks against Sketch Engine corpora (BNC, COCA, EnTenTen, Hansard, Susanne, etc.) from inside Claude
  - User asks for collocations, concordances, word sketches, or keyword analysis and has access to Sketch Engine
  - User wants to write or run CQL (Corpus Query Language) queries via an agent

  DO NOT trigger for:
  - General corpus-linguistics setup that doesn't involve Sketch Engine specifically — see corpus-tools-skill
  - The Sketch design tool (no relation; this skill is for the corpus query platform)
---

# Sketch Engine Skill

This skill installs and configures the **Sketch Engine MCP server** (`ricCap/sketch-engine-mcp-server`) and helps the user run corpus-linguistic tasks via Claude. It assumes a Mac (Apple Silicon or Intel); Linux and Windows variants are supported by the upstream binaries but not by the install script.

## Source-of-truth notes

- Upstream repo: https://github.com/ricCap/sketch-engine-mcp-server (TypeScript; releases as standalone binaries)
- Upstream API the wrapper calls: https://www.sketchengine.eu (commercial; institutional and individual subscriptions)
- License at retrieval: **none specified in the repo**. Treat as unlicensed third-party tooling — fine for personal use; clear with your institution before deploying widely
- Repo description self-tags as "(preview)"

## Setup workflow

The user always needs three things before queries work: (1) the binary, (2) a Sketch Engine API key, (3) an MCP entry pointing the Claude client at the binary with the key.

### Step 1 — install the binary

Run `scripts/install.sh`. It auto-detects the platform (Apple Silicon vs Intel), downloads the latest release asset from `ricCap/sketch-engine-mcp-server`, places it at `~/.local/bin/sketch-engine-mcp`, and `chmod +x`'s it. Re-running the script upgrades to the latest release.

```bash
bash scripts/install.sh
```

If `~/.local/bin` is not on the user's PATH, the script prints a one-line warning. The MCP config uses an absolute path, so PATH membership is not required for MCP use; it only matters if the user wants to run the binary directly.

### Step 2 — get the API key

The user needs a Sketch Engine account.

1. Visit https://www.sketchengine.eu — many universities have institutional access via Shibboleth (look for `Sign in with your institution`).
2. After login: top-right username → **My Account** → **API Key** section → **Generate API Key** (or copy the existing one).
3. Make the key available as the env var `SKETCH_ENGINE_API_KEY`. Pick whichever fits your setup:
   - **Shell rc file** (`~/.zshrc`, `~/.bashrc`): `export SKETCH_ENGINE_API_KEY="…"` — simplest.
   - **Dedicated dotfile** with restrictive perms (`~/.env.secrets`, chmod 600), sourced from your shell rc.
   - **direnv** (`~/.envrc` or per-project `.envrc`) — if you already use direnv.
   - **Secrets manager** (e.g. Bitwarden Secrets Manager via the [`bws` CLI](https://bitwarden.com/help/secrets-manager-cli/)): store the key in your vault, then write a launcher script that fetches it at runtime. This is the most defensible option for shared machines but the heaviest setup.

The key is a hex string. It is **not** your account password.

### Step 3 — configure the MCP client

There are three plausible clients on this machine. Use whichever the user is in:

- **Claude Desktop**: edits `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Claude Code (project-scoped)**: edits `.mcp.json` in the project root
- **Claude Code (user-scoped, all projects)**: edits `~/.claude.json` under the `mcpServers` key

`scripts/configure-mcp.sh` writes/updates the config for whichever target the user picks. It refuses to overwrite an existing `sketch-engine` entry without confirmation.

```bash
bash scripts/configure-mcp.sh --target claude-desktop
bash scripts/configure-mcp.sh --target claude-code-project --path /path/to/project
bash scripts/configure-mcp.sh --target claude-code-user
```

The script reads `SKETCH_ENGINE_API_KEY` from the environment (and as a convenience also sources `~/.env.secrets` if it exists and the var is unset). It writes the literal key into the MCP server entry's `env.SKETCH_ENGINE_API_KEY` field. If you'd rather keep the key out of any JSON config file, replace the registered MCP `command` with a launcher script that fetches the key at runtime from your secrets manager and `exec`'s the real binary — see `references/troubleshooting.md` for the launcher pattern.

### Step 4 — verify

Restart the Claude client. Then ask:

```
Use Sketch Engine to list available corpora
```

A working setup returns a list including names like `preloaded/ententen21_en1`, `preloaded/bnc2`, `preloaded/coca-2017`. If the call fails with "Invalid API key," recheck Step 2. If the tool isn't visible at all, the MCP server is not reaching the client — check the config path and restart.

## Common task patterns

Once configured, the LLM can call eight tool-types and a CQL passthrough. The user need not memorise these — natural-language asks usually route correctly. For the standard patterns, see [`references/tasks.md`](references/tasks.md).

For CQL specifically (advanced queries the user writes by hand or asks the agent to write), see [`references/cql.md`](references/cql.md). For a curated map of which Sketch Engine corpora to use for which question (BNC for British English, COCA for American, EnTenTen for general web text, Hansard for parliamentary discourse, Susanne for treebank work, etc.), see [`references/corpora.md`](references/corpora.md).

## When things break

For full triage, see [`references/troubleshooting.md`](references/troubleshooting.md). Quick pointers for the most common cases:

- **`MCP error -32603: API Error: fetch failed`** — generic transport error. Bypass the MCP and probe `https://api.sketchengine.eu/` with curl to find the real cause. If TCP times out instantly while `https://www.sketchengine.eu/` works, suspect a **VPN/IP block** — Sketch Engine's API tier drops packets from common commercial-VPN exit ranges (Mullvad, Proton, Packethub, etc.). Disconnect the VPN or split-tunnel. See troubleshooting reference for the full diagnostic recipe.
- **`Invalid API key`** — regenerate via My Account → API Key. If using the bws launcher pattern, update the vault secret and restart Claude Code so the MCP respawns with the new key.
- **`Quota exceeded`** — Sketch Engine accounts have monthly query limits; check My Account → Subscription.
- **Tool calls succeed but return empty results** — the corpus name is wrong, or that corpus isn't on your subscription tier. Always start by listing corpora; the friendly names in `references/corpora.md` are category labels, not always API identifiers.
- **Response too large** — built-in cache writes the full payload to `cache/<hash>.json`. Narrow the query or read from cache directly.

## Out of scope

- Building or uploading custom corpora to Sketch Engine — supported by Sketch Engine itself but not by this MCP wrapper at retrieval. Use the Sketch Engine web UI for that
- Parallel-corpus features — the MCP surface does not specifically expose them; use the Sketch Engine web UI or fall back to corpus-tools-skill for local OPUS/CWB-based work
- LLM-mediated interpretation of results — the MCP returns data; interpretation is up to Claude in conversation
