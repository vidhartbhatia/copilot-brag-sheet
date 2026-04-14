#!/usr/bin/env bash
# install.sh — Install copilot-brag-sheet as a Copilot CLI extension
#
# Usage:
#   curl -sL https://raw.githubusercontent.com/vidhartbhatia/copilot-brag-sheet/main/install.sh | bash
#   # or: git clone ... && ./install.sh

set -euo pipefail

REPO_URL="https://github.com/vidhartbhatia/copilot-brag-sheet.git"
EXT_NAME="copilot-brag-sheet"
COPILOT_HOME="${COPILOT_HOME:-$HOME/.copilot}"
TARGET_DIR="$COPILOT_HOME/extensions/$EXT_NAME"

echo "Installing $EXT_NAME..."

# Check for git
if ! command -v git &>/dev/null; then
    echo "Error: git is required but not found." >&2
    exit 1
fi

# Check for node
if ! command -v node &>/dev/null; then
    echo "Error: Node.js 18+ is required but not found." >&2
    exit 1
fi

# Clean previous install
if [ -d "$TARGET_DIR" ]; then
    echo "Removing previous installation..."
    rm -rf "$TARGET_DIR"
fi

# Clone or copy
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" 2>/dev/null)" && pwd 2>/dev/null || echo "")"

if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/extension.mjs" ]; then
    # Running from cloned repo — copy files
    echo "Copying from local repo..."
    mkdir -p "$TARGET_DIR/lib"
    cp "$SCRIPT_DIR/extension.mjs" "$TARGET_DIR/"
    cp "$SCRIPT_DIR/package.json" "$TARGET_DIR/"
    cp "$SCRIPT_DIR"/lib/*.mjs "$TARGET_DIR/lib/"
else
    # Running via curl — clone fresh
    echo "Cloning from GitHub..."
    git clone --depth 1 --quiet "$REPO_URL" "$TARGET_DIR"
    # Remove non-essential files
    rm -rf "$TARGET_DIR/.git" "$TARGET_DIR/.github" "$TARGET_DIR/test"
fi

echo ""
echo "✅ Installed to: $TARGET_DIR"

# ── Setup ────────────────────────────────────────────────────────────────────
# Build config interactively. All prompts are optional (default: skip).

CONFIG_DIR="${WORK_TRACKER_DIR:-}"
if [ -z "$CONFIG_DIR" ]; then
    case "$(uname -s)" in
        Darwin) CONFIG_DIR="$HOME/Library/Application Support/copilot-brag-sheet" ;;
        *)      CONFIG_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/copilot-brag-sheet" ;;
    esac
fi
mkdir -p "$CONFIG_DIR"

CONFIG_JSON="{}"

# Microsoft preset
echo ""
read -r -p "Are you a Microsoft employee? (enables Connect review formatting) [y/N] " ms_response
if [[ "$ms_response" =~ ^[Yy]$ ]]; then
    CONFIG_JSON=$(echo "$CONFIG_JSON" | sed 's/}/, "preset": "microsoft"}/' | sed 's/^{, /{/')
    echo "  ✅ Microsoft preset enabled"
fi

# Git history
echo ""
read -r -p "Enable git history for your work log? (local version control) [Y/n] " git_response
if [[ ! "$git_response" =~ ^[Nn]$ ]]; then
    CONFIG_JSON=$(echo "$CONFIG_JSON" | sed 's/}//')
    CONFIG_JSON="${CONFIG_JSON%\}}, \"git\": { \"enabled\": true, \"push\": false } }"
    CONFIG_JSON=$(echo "$CONFIG_JSON" | sed 's/^{, /{/')
    echo "  ✅ Git history enabled (local only)"

    # Optional remote
    echo ""
    read -r -p "Sync to a remote repo? (paste GitHub/ADO URL, or press Enter to skip) " remote_url
    if [ -n "$remote_url" ]; then
        CONFIG_JSON=$(echo "$CONFIG_JSON" | sed 's/"push": false/"push": true/')
        echo "  ✅ Remote sync enabled: $remote_url"
        echo "  (Remote will be configured on first session start)"
        # Save remote URL for the extension to pick up
        echo "$remote_url" > "$CONFIG_DIR/.git-remote-pending"
    fi
fi

# Write config
if [ "$CONFIG_JSON" != "{}" ]; then
    echo "$CONFIG_JSON" > "$CONFIG_DIR/config.json"
    echo ""
    echo "  Config saved to: $CONFIG_DIR/config.json"
fi

echo ""
echo "Next steps:"
echo "  1. Run /clear in the Copilot CLI or restart it"
echo "  2. Start a session — you'll see '📊 Work logger active'"
echo ""
echo "To uninstall: rm -rf \"$TARGET_DIR\""
