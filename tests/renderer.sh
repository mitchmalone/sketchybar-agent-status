#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
temp="$(mktemp -d)"; trap 'rm -rf "$temp"' EXIT
mkdir -p "$temp/state/sketchybar-agent-status" "$temp/bin" "$temp/items"
printf '%s\n' '#!/usr/bin/env bash' 'if [[ "$1" == "--query" ]]; then item="$FAKE_ITEMS/$2"; [[ -f "$item" ]] && printf "{\"name\": \"%s\"}\n" "$2" || printf "[!] Query: item %s not found\n" "$2"; exit 0; fi' 'if [[ "$1" == "--add" ]]; then touch "$FAKE_ITEMS/$3"; fi' 'if [[ "$1" == "--remove" ]]; then rm -f "$FAKE_ITEMS/$2"; fi' 'printf "%s\n" "$*" >> "$SKETCHYBAR_LOG"' > "$temp/bin/sketchybar"
chmod +x "$temp/bin/sketchybar"
printf '%s\n' '{"sessions":{"claude-1":{"session":"claude-1","agent":"claude","state":"attention","title":"Review plan","detail":"PermissionRequest","tmux":"work:1.0"}}}' > "$temp/state/sketchybar-agent-status/state.json"
XDG_STATE_HOME="$temp/state" SKETCHYBAR_BIN="$temp/bin/sketchybar" SKETCHYBAR_LOG="$temp/commands" FAKE_ITEMS="$temp/items" AGENT_STATUS_HOME="$root" "$root/scripts/agent_status.sh"
grep -F 'click_script=' "$temp/commands" | grep -F 'popup.drawing=toggle' >/dev/null
grep -F 'Jump to tmux pane' "$temp/commands" >/dev/null
grep -F 'icon=👀' "$temp/commands" >/dev/null
grep -F 'Task: Review plan' "$temp/commands" >/dev/null
grep -F 'tmux target: work:1.0' "$temp/commands" >/dev/null
before_lines="$(wc -l < "$temp/commands")"
XDG_STATE_HOME="$temp/state" SKETCHYBAR_BIN="$temp/bin/sketchybar" SKETCHYBAR_LOG="$temp/commands" FAKE_ITEMS="$temp/items" AGENT_STATUS_HOME="$root" "$root/scripts/agent_status.sh"
! tail -n "+$((before_lines + 1))" "$temp/commands" | grep -F -- '--add item' >/dev/null
echo 'renderer test passed'
