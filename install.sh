#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="${AGENT_STATUS_HOME:-$HOME/.local/share/sketchybar-agent-status}"
BIN_DIR="$INSTALL_DIR/bin"
PLIST="$HOME/Library/LaunchAgents/com.mitchmalone.sketchybar-agent-status.plist"
INSTALL_CLAUDE_HOOKS=false
[[ "${1:-}" == "--with-claude-hooks" ]] && INSTALL_CLAUDE_HOOKS=true
command -v sketchybar >/dev/null || { echo "SketchyBar is required" >&2; exit 1; }
command -v tmux >/dev/null || { echo "tmux is required" >&2; exit 1; }
mkdir -p "$BIN_DIR" "$HOME/.config/sketchybar-agent-status" "$HOME/.config/sketchybar"
go build -o "$BIN_DIR/agent-statusd" "$ROOT/cmd/agent-statusd"
go build -o "$BIN_DIR/agent-statusctl" "$ROOT/cmd/agent-statusctl"
cp -R "$ROOT/scripts" "$ROOT/sketchybar" "$ROOT/hooks" "$INSTALL_DIR/"
cp -n "$ROOT/config/example.config.sh" "$HOME/.config/sketchybar-agent-status/config.sh" || true
sed -e "s|__INSTALL_DIR__|$INSTALL_DIR|g" -e "s|__HOME__|$HOME|g" "$ROOT/launchd/com.mitchmalone.sketchybar-agent-status.plist" > "$PLIST"
launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "Installed daemon. Add this to sketchybarrc: source '$INSTALL_DIR/sketchybar/agent_status.conf'"
if [[ "$INSTALL_CLAUDE_HOOKS" == true ]]; then
  /usr/bin/python3 "$INSTALL_DIR/hooks/install-claude-hooks.py" "$HOME/.claude/settings.json"
  [[ -d "$HOME/.claude-psyke" ]] && /usr/bin/python3 "$INSTALL_DIR/hooks/install-claude-hooks.py" "$HOME/.claude-psyke/settings.json"
  echo "Claude hooks installed. Start a new Claude Code session inside tmux."
else
  echo "Claude hooks are opt-in: rerun with --with-claude-hooks."
fi
