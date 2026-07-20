#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
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
SKETCHYBARRC="$HOME/.config/sketchybar/sketchybarrc"
if [[ -f "$SKETCHYBARRC" ]] && ! grep -Fq 'agent_status.conf' "$SKETCHYBARRC"; then
  {
    printf '\n# >>> sketchybar-agent-status >>>\n'
    printf 'source "%s/sketchybar/agent_status.conf"\n' "$INSTALL_DIR"
    printf '# <<< sketchybar-agent-status <<<\n'
  } >> "$SKETCHYBARRC"
  echo "Added SketchyBar integration to $SKETCHYBARRC"
elif [[ ! -f "$SKETCHYBARRC" ]]; then
  echo "No sketchybarrc found at $SKETCHYBARRC; source $INSTALL_DIR/sketchybar/agent_status.conf manually." >&2
fi
RENDERED_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/sketchybar-agent-status/rendered-items"
if [[ -f "$RENDERED_FILE" ]]; then
  while IFS= read -r item; do
    [[ -n "$item" ]] && sketchybar --remove "$item" 2>/dev/null || true
  done < "$RENDERED_FILE"
  rm -f "$RENDERED_FILE"
fi
sketchybar --reload
sed -e "s|__INSTALL_DIR__|$INSTALL_DIR|g" -e "s|__HOME__|$HOME|g" "$ROOT/launchd/com.mitchmalone.sketchybar-agent-status.plist" > "$PLIST"
launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
launchctl kickstart -k "gui/$(id -u)/com.mitchmalone.sketchybar-agent-status"
sleep 0.2
echo "Installed daemon and reloaded SketchyBar."
if [[ "$INSTALL_CLAUDE_HOOKS" == true ]]; then
  /usr/bin/python3 "$INSTALL_DIR/hooks/install-claude-hooks.py" "$HOME/.claude/settings.json"
  [[ -d "$HOME/.claude-psyke" ]] && /usr/bin/python3 "$INSTALL_DIR/hooks/install-claude-hooks.py" "$HOME/.claude-psyke/settings.json"
  echo "Claude hooks installed. Start a new Claude Code session inside tmux."
else
  echo "Claude hooks are opt-in: rerun with --with-claude-hooks."
fi
