#!/usr/bin/env bash
# install.sh — Install copilot-brag-sheet as a Copilot CLI extension
#
# One-liner:
#   curl -sL https://raw.githubusercontent.com/vidhartbhatia/copilot-brag-sheet/main/install.sh | bash
#
# From cloned repo:
#   ./install.sh

set -euo pipefail

REPO_URL="https://github.com/vidhartbhatia/copilot-brag-sheet.git"
EXT_NAME="copilot-brag-sheet"
COPILOT_HOME="${COPILOT_HOME:-$HOME/.copilot}"
TARGET_DIR="$COPILOT_HOME/extensions/$EXT_NAME"

# ── Colors ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${BOLD}$1${NC}"; }
ok()    { echo -e "  ${GREEN}✅ $1${NC}"; }
warn()  { echo -e "  ${YELLOW}⚠️  $1${NC}"; }
fail()  { echo -e "${RED}Error: $1${NC}" >&2; exit 1; }

# ── Checks ───────────────────────────────────────────────────────────────────
info "Installing $EXT_NAME..."
echo ""

command -v git  &>/dev/null || fail "git is required but not found."
command -v node &>/dev/null || fail "Node.js 18+ is required but not found."

NODE_MAJOR=$(node -e "process.stdout.write(String(process.versions.node.split('.')[0]))")
if [ "$NODE_MAJOR" -lt 18 ] 2>/dev/null; then
    fail "Node.js 18+ required (found v$(node --version))"
fi

# ── Install ──────────────────────────────────────────────────────────────────
if [ -d "$TARGET_DIR" ]; then
    info "Updating existing installation..."
    rm -rf "$TARGET_DIR"
fi

# Detect if running from cloned repo
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" 2>/dev/null)" && pwd 2>/dev/null || echo "")"

if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/extension.mjs" ]; then
    mkdir -p "$TARGET_DIR/lib"
    cp "$SCRIPT_DIR/extension.mjs" "$TARGET_DIR/"
    cp "$SCRIPT_DIR/package.json" "$TARGET_DIR/"
    cp "$SCRIPT_DIR"/lib/*.mjs "$TARGET_DIR/lib/"
else
    git clone --depth 1 --quiet "$REPO_URL" "$TARGET_DIR"
    rm -rf "$TARGET_DIR/.git" "$TARGET_DIR/.github" "$TARGET_DIR/test" \
           "$TARGET_DIR/docs" "$TARGET_DIR/bin" "$TARGET_DIR/AGENTS.md" \
           "$TARGET_DIR/CONTRIBUTING.md" "$TARGET_DIR/ROADMAP.md" \
           "$TARGET_DIR/CODEOWNERS"
fi

ok "Extension installed to $TARGET_DIR"

# ── Config ───────────────────────────────────────────────────────────────────
# Resolve data directory
CONFIG_DIR="${WORK_TRACKER_DIR:-}"
if [ -z "$CONFIG_DIR" ]; then
    case "$(uname -s)" in
        Darwin) CONFIG_DIR="$HOME/Library/Application Support/copilot-brag-sheet" ;;
        *)      CONFIG_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/copilot-brag-sheet" ;;
    esac
fi
mkdir -p "$CONFIG_DIR"

# Only run interactive setup if stdin is a terminal (not piped)
if [ -t 0 ]; then
    PRESET=""
    GIT_ENABLED="true"
    GIT_PUSH="false"

    echo ""
    read -r -p "Are you a Microsoft employee? (enables Connect review formatting) [y/N] " ms_response
    if [[ "${ms_response:-}" =~ ^[Yy]$ ]]; then
        PRESET="microsoft"
        ok "Microsoft preset enabled"
    fi

    echo ""
    read -r -p "Enable git history for your work log? (local version control) [Y/n] " git_response
    if [[ "${git_response:-}" =~ ^[Nn]$ ]]; then
        GIT_ENABLED="false"
    else
        ok "Git history enabled (local only)"

        echo ""
        read -r -p "Sync to a remote repo? (paste GitHub/ADO URL, or Enter to skip) " remote_url
        if [ -n "${remote_url:-}" ]; then
            GIT_PUSH="true"
            echo "$remote_url" > "$CONFIG_DIR/.git-remote-pending"
            ok "Remote sync enabled: $remote_url"
        fi
    fi

    # Build config JSON
    CONFIG="{"
    [ -n "$PRESET" ] && CONFIG="$CONFIG \"preset\": \"$PRESET\","
    CONFIG="$CONFIG \"git\": { \"enabled\": $GIT_ENABLED, \"push\": $GIT_PUSH }"
    CONFIG="$CONFIG }"

    echo "$CONFIG" > "$CONFIG_DIR/config.json"
else
    # Non-interactive: write default config (git enabled, local only)
    echo '{ "git": { "enabled": true, "push": false } }' > "$CONFIG_DIR/config.json"
    warn "Non-interactive mode — using defaults. Edit $CONFIG_DIR/config.json to customize."
fi

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}🎉 copilot-brag-sheet installed!${NC}"
echo ""
echo "  Next steps:"
echo "    1. Run /clear in the Copilot CLI (or restart it)"
echo "    2. Start a session — you'll see '📊 Work logger active'"
echo "    3. Say 'brag' to save an accomplishment"
echo ""
echo "  Data stored at:  $CONFIG_DIR"
echo "  Extension at:    $TARGET_DIR"
echo ""
echo "  Uninstall:  rm -rf \"$TARGET_DIR\""
