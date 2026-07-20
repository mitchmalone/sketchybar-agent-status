#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
temp="$(mktemp -d)"; trap 'rm -rf "$temp"' EXIT
printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" "$*" > "$HOOK_ARGS"' > "$temp/agent-statusctl"
chmod +x "$temp/agent-statusctl"
printf '%s' '{"session_id":"context-1","hook_event_name":"PermissionRequest","prompt":"Deploy the auth middleware","tool_name":"Bash"}' | TMUX_PANE='%4' AGENT_STATUS_CTL="$temp/agent-statusctl" HOOK_ARGS="$temp/args" "$root/hooks/claude-status.sh"
grep -F -- '--state attention' "$temp/args" >/dev/null
grep -F -- '--title Deploy the auth middleware' "$temp/args" >/dev/null
grep -F -- '--detail PermissionRequest · Bash' "$temp/args" >/dev/null
grep -F -- '--tmux %4' "$temp/args" >/dev/null
printf '%s' '{"session_id":"context-2","hook_event_name":"Stop"}' | TMUX_PANE='%5' AGENT_STATUS_CTL="$temp/agent-statusctl" HOOK_ARGS="$temp/args-empty" "$root/hooks/claude-status.sh"
grep -F -- '--detail Stop' "$temp/args-empty" >/dev/null
echo 'Claude hook context test passed'
