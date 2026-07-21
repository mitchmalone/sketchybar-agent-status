#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
temp="$(mktemp -d)"; trap 'rm -rf "$temp"' EXIT
mkdir -p "$temp/bin" "$temp/state/sketchybar-agent-status"
printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" "$*" >> "$SKETCHYBAR_LOG"' > "$temp/bin/sketchybar"
chmod +x "$temp/bin/sketchybar"

PATH="$temp/bin:$PATH" XDG_STATE_HOME="$temp/state" SKETCHYBAR_LOG="$temp/commands" AGENT_STATUS_HOME="$root" bash -c 'AGENT_STATUS_POSITION=left; source "$AGENT_STATUS_HOME/sketchybar/agent_status.conf"'
grep -F 'script=AGENT_STATUS_POSITION=left AGENT_STATUS_ANCHOR=agent_status_anchor' "$temp/commands" >/dev/null
echo 'config environment test passed'
