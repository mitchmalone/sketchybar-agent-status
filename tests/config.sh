#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
temp="$(mktemp -d)"; trap 'rm -rf "$temp"' EXIT
mkdir -p "$temp/bin" "$temp/state/sketchybar-agent-status" "$temp/config/sketchybar-agent-status"
printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" "$*" >> "$SKETCHYBAR_LOG"' > "$temp/bin/sketchybar"
chmod +x "$temp/bin/sketchybar"
printf '%s\n' '{"sessions":{"demo":{"session":"demo","agent":"claude","state":"attention"}}}' > "$temp/state/sketchybar-agent-status/state.json"

printf '%s\n' 'AGENT_STATUS_POSITION=left' 'AGENT_ICON_ATTENTION="👀"' > "$temp/config/sketchybar-agent-status/local.sh"
PATH="$temp/bin:$PATH" XDG_STATE_HOME="$temp/state" XDG_CONFIG_HOME="$temp/config" SKETCHYBAR_LOG="$temp/commands" AGENT_STATUS_HOME="$root" bash -c 'source "$AGENT_STATUS_HOME/sketchybar/agent_status.conf"'
grep -F 'script=AGENT_STATUS_POSITION=left AGENT_STATUS_ANCHOR=agent_status_anchor' "$temp/commands" >/dev/null
grep -F 'icon=👀' "$temp/commands" >/dev/null
echo 'config environment test passed'
