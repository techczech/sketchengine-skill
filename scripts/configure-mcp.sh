#!/usr/bin/env bash
# Add or update the sketch-engine MCP entry in a Claude client config.
#
# Targets:
#   --target claude-desktop          # ~/Library/Application Support/Claude/claude_desktop_config.json
#   --target claude-code-project --path /path/to/project   # <path>/.mcp.json
#   --target claude-code-user        # ~/.claude.json
#
# Reads SKETCH_ENGINE_API_KEY from the environment. See SKILL.md for ways to
# set the variable.
# Writes the absolute path to the binary at ~/.local/bin/sketch-engine-mcp.
# Refuses to clobber an existing `sketch-engine` entry without --force.

set -euo pipefail

target=""
project_path=""
force=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) target="$2"; shift 2 ;;
    --path)   project_path="$2"; shift 2 ;;
    --force)  force=1; shift ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$target" ]]; then
  echo "Error: --target is required (claude-desktop | claude-code-project | claude-code-user)" >&2
  exit 1
fi

# Resolve config file path
case "$target" in
  claude-desktop)
    config_file="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
    ;;
  claude-code-project)
    if [[ -z "$project_path" ]]; then
      echo "Error: --target claude-code-project requires --path /absolute/project/path" >&2
      exit 1
    fi
    config_file="$project_path/.mcp.json"
    ;;
  claude-code-user)
    config_file="$HOME/.claude.json"
    ;;
  *)
    echo "Error: unknown --target: $target" >&2
    exit 1
    ;;
esac

if [[ -z "${SKETCH_ENGINE_API_KEY:-}" ]]; then
  echo "Error: SKETCH_ENGINE_API_KEY is not set." >&2
  echo "Set it in your shell environment, e.g.:" >&2
  echo "  export SKETCH_ENGINE_API_KEY=\"<your-key>\"" >&2
  echo "(see SKILL.md for options including dotfiles, direnv, and secrets managers)" >&2
  exit 1
fi

binary_path="$HOME/.local/bin/sketch-engine-mcp"
if [[ ! -x "$binary_path" ]]; then
  echo "Error: $binary_path not found or not executable." >&2
  echo "Run scripts/install.sh first." >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required. Install with: brew install jq" >&2
  exit 1
fi

# Ensure config directory exists
mkdir -p "$(dirname "$config_file")"

# Initialise file with {} if missing or empty
if [[ ! -s "$config_file" ]]; then
  echo '{}' > "$config_file"
fi

# Backup before edit
cp "$config_file" "$config_file.bak.$(date +%s)"

# Refuse if entry exists and --force not given
existing="$(jq -r '.mcpServers["sketch-engine"] // empty' "$config_file" 2>/dev/null || true)"
if [[ -n "$existing" && "$force" -eq 0 ]]; then
  echo "An entry mcpServers.sketch-engine already exists in $config_file" >&2
  echo "Re-run with --force to overwrite." >&2
  exit 1
fi

# Build the entry and merge
new_entry="$(jq -n --arg cmd "$binary_path" --arg key "$SKETCH_ENGINE_API_KEY" '{
  command: $cmd,
  env: { SKETCH_ENGINE_API_KEY: $key }
}')"

tmp="$(mktemp)"
jq --argjson entry "$new_entry" \
   '.mcpServers = (.mcpServers // {}) | .mcpServers["sketch-engine"] = $entry' \
   "$config_file" > "$tmp"
mv "$tmp" "$config_file"

echo "Updated $config_file"
echo
echo "Next: restart your Claude client. Then ask:"
echo "  \"Use Sketch Engine to list available corpora\""
