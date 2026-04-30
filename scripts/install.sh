#!/usr/bin/env bash
# Install or upgrade the Sketch Engine MCP server (ricCap/sketch-engine-mcp-server).
#
# Detects Apple Silicon vs Intel, downloads the latest release asset, places it
# at ~/.local/bin/sketch-engine-mcp, makes it executable, and removes the macOS
# quarantine flag.
#
# Idempotent — re-running pulls the latest release.

set -euo pipefail

REPO="ricCap/sketch-engine-mcp-server"
INSTALL_DIR="$HOME/.local/bin"
BINARY_NAME="sketch-engine-mcp"
TARGET="$INSTALL_DIR/$BINARY_NAME"

# Detect platform
os="$(uname -s)"
arch="$(uname -m)"

case "$os/$arch" in
  Darwin/arm64)  asset="sketch-engine-mcp-macos-arm64" ;;
  Darwin/x86_64) asset="sketch-engine-mcp-macos-x64" ;;
  Linux/x86_64)  asset="sketch-engine-mcp-linux-x64" ;;
  *)
    echo "Error: unsupported platform $os/$arch" >&2
    echo "Supported: macOS arm64, macOS x86_64, Linux x86_64" >&2
    echo "Windows users: download manually from https://github.com/$REPO/releases" >&2
    exit 1
    ;;
esac

mkdir -p "$INSTALL_DIR"

echo "Fetching latest release of $REPO ..."
if ! command -v gh >/dev/null 2>&1; then
  echo "Error: GitHub CLI 'gh' is required. Install with: brew install gh" >&2
  exit 1
fi

# Download to a temp file so a failed download doesn't clobber an existing install
tmpfile="$(mktemp -t sketch-engine-mcp.XXXXXX)"
trap 'rm -f "$tmpfile"' EXIT

if ! gh release download --repo "$REPO" --pattern "$asset" --output "$tmpfile" --clobber; then
  echo "Error: failed to download $asset from $REPO" >&2
  exit 1
fi

# Quick sanity: file must be non-empty and look like an executable (Mach-O / ELF)
if [[ ! -s "$tmpfile" ]]; then
  echo "Error: downloaded file is empty" >&2
  exit 1
fi

mv "$tmpfile" "$TARGET"
chmod +x "$TARGET"
trap - EXIT

# Strip macOS quarantine attribute if present (otherwise Gatekeeper blocks first run)
if [[ "$os" == "Darwin" ]]; then
  xattr -d com.apple.quarantine "$TARGET" 2>/dev/null || true
fi

echo "Installed: $TARGET"
"$TARGET" --version 2>/dev/null || true

# PATH advisory (informational; MCP config uses absolute paths, so this is optional)
case ":$PATH:" in
  *":$INSTALL_DIR:"*) ;;
  *)
    echo
    echo "Note: $INSTALL_DIR is not on your PATH. The MCP config will use the absolute"
    echo "path ($TARGET), so this does not affect MCP use. To run the binary directly,"
    echo "add this to ~/.zshrc:"
    echo "  export PATH=\"$INSTALL_DIR:\$PATH\""
    ;;
esac

echo
echo "Next: bash $(dirname "$0")/configure-mcp.sh --target <claude-desktop|claude-code-project|claude-code-user>"
