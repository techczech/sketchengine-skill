# sketchengine-skill

A Claude Code / Claude Desktop skill that installs and configures the [Sketch Engine MCP server](https://github.com/ricCap/sketch-engine-mcp-server), then helps the user run corpus-linguistic tasks against Sketch Engine corpora — Word Sketches, Concordances, Collocations, Word Lists, Word Comparison, Frequency Analysis, Keyword Extraction, and CQL queries — as MCP tools.

## ⚠️ Status: partially smoke-tested — half the upstream tools are broken

End-to-end smoke-tested against an Oxford institutional account on **2026-04-29** (Apple Silicon Mac, Sketch Engine API 5.85.8). Findings:

**Working through this skill (5/9 tools):**
`get_corpora`, `get_corpus_info`, `get_word_sketch`, `get_wordlist`, `get_keywords`.

**Broken at the upstream binary level (4/9 tools):**
`get_concordance`, `get_collocations`, `get_frequency_distribution`, `execute_cql_query` — all fail with `{"error": "Unknown action"}`. The `ricCap/sketch-engine-mcp-server` binary is mid-migration between Sketch Engine's legacy CGI API and its modern REST API; the modern paths (`/ca/api/...`) are wired up correctly for the working five, but the four broken tools still call retired CGI actions. See [`references/troubleshooting.md`](references/troubleshooting.md) for the diagnosis. Until upstream fixes them, use the Sketch Engine web UI for concordance, collocations, frequency, and CQL queries.

**Not yet exercised:** `scripts/install.sh` and `scripts/configure-mcp.sh` (a fresh-machine install was not part of this smoke test), `get_word_sketch_diff`, Linux/Intel-Mac, Claude Desktop config path.

**Help wanted:**
1. PR fixing the four broken tools upstream at <https://github.com/ricCap/sketch-engine-mcp-server> — port the concordance / collocations / freq / CQL paths from `/bonito/run.cgi/?action=...` to `/ca/api/...` to match what `get_corpora` already does.
2. Test on Linux x86_64, Intel Mac, Claude Desktop. Open issues for anything that surprises you.
3. PRs welcome for: Windows install path, more nuanced error handling, additional task patterns, more corpora.

This is a personal skill repo by [@techczech](https://github.com/techczech) (Dominik Lukeš); no warranty, MIT-licensed.

## What this skill does

Once installed in your Claude environment, the skill triggers when you mention setting up Sketch Engine, configuring the SketchEngine MCP, or running corpus-linguistics tasks against Sketch Engine corpora.

It walks the user through:

1. Downloading the right `ricCap/sketch-engine-mcp-server` binary for their platform (Apple Silicon Mac, Intel Mac, Linux x86_64).
2. Acquiring a Sketch Engine API key from [sketchengine.eu](https://www.sketchengine.eu/) — the skill specifically supports institutional sign-in flows.
3. Wiring the MCP entry into the right Claude config (Claude Desktop, Claude Code project-scoped, or Claude Code user-scoped).
4. Verifying the connection with a smoke-test query.

After that, the skill's reference files (`tasks.md`, `cql.md`, `corpora.md`) help Claude pick the right Sketch Engine tool for the user's question and choose the right corpus.

## Install (as a Claude skill)

Clone into a folder Claude Code's skill discovery scans (typically `~/.claude/skills/` for user scope, or symlink from there to wherever you keep the repo):

```bash
git clone https://github.com/techczech/sketchengine-skill.git ~/.claude/skills/sketchengine-skill
```

For Codex, symlink or clone to `~/.codex/skills/sketchengine-skill` instead. The skill self-registers when the host's skill discovery scans the folder.

To package as a `.skill` archive for distribution, use Anthropic's [skill-creator](https://github.com/anthropics/skills) tooling.

## Layout

```
SKILL.md                        # the skill definition Claude reads
scripts/
  install.sh                    # downloads the right MCP-server binary
  configure-mcp.sh              # writes the MCP entry into the right config file
references/
  tasks.md                      # common Sketch Engine task patterns
  cql.md                        # CQL syntax cheatsheet
  corpora.md                    # curated map of Sketch Engine corpora
```

## Background

Built on top of [`ricCap/sketch-engine-mcp-server`](https://github.com/ricCap/sketch-engine-mcp-server) — the only mature general-purpose Sketch Engine MCP server identified in a 2026 survey of agent / MCP tooling for corpus linguistics, partly building on [Yu et al. 2026 (arXiv:2604.07189)](https://arxiv.org/abs/2604.07189) on agent-driven corpus linguistics.

## License

MIT.
