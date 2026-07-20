#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
temp="$(mktemp -d)"; trap 'rm -rf "$temp"' EXIT
mkdir -p "$temp/state/sketchybar-agent-status" "$temp/bin"
printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" "$*" >> "$SKETCHYBAR_LOG"' > "$temp/bin/sketchybar"
chmod +x "$temp/bin/sketchybar"
printf '%s\n' '{"sessions":{"claude-1":{"session":"claude-1","agent":"claude","state":"attention","title":"Review plan","detail":"PermissionRequest","tmux":"work:1.0"}}}' > "$temp/state/sketchybar-agent-status/state.json"
XDG_STATE_HOME="$temp/state" SKETCHYBAR_BIN="$temp/bin/sketchybar" SKETCHYBAR_LOG="$temp/commands" AGENT_STATUS_HOME="$root" "$root/scripts/agent_status.sh"
grep -F 'click_script=' "$temp/commands" | grep -F 'popup.drawing=toggle' >/dev/null
grep -F 'Jump to tmux pane' "$temp/commands" >/dev/null
grep -F 'icon=👀' "$temp/commands" >/dev/null
echo 'renderer test passed'
