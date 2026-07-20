#!/usr/bin/env bash
# Claude Code hook command. Claude supplies hook JSON on stdin; this adapter intentionally
# degrades safely when session metadata is unavailable.
set -euo pipefail
payload="$(cat)"
event="${CLAUDE_HOOK_EVENT_NAME:-$(printf '%s' "$payload" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin).get("hook_event_name", ""))')}"
case "$event" in
  SessionStart) status=idle;; UserPromptSubmit|PreToolUse|PostToolUse) status=working;; PermissionRequest|Notification) status=attention;; Stop) status=idle;; SessionEnd) status=ended;; *) status=unknown;;
esac
session="$(printf '%s' "$payload" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin).get("session_id", "claude-unknown"))')"
context="$(PAYLOAD="$payload" /usr/bin/python3 - "$event" <<'PY'
import json, os, sys
payload = json.loads(os.environ["PAYLOAD"])
event = sys.argv[1]
prompt = str(payload.get("prompt") or "").replace("\n", " ").strip()
tool = str(payload.get("tool_name") or "").strip()
message = str(payload.get("message") or payload.get("notification_type") or "").replace("\n", " ").strip()
title = prompt[:100]
parts = [event]
if tool:
    parts.append(tool)
elif message:
    parts.append(message[:100])
print(title + "\x1f" + " · ".join(parts))
PY
)"
IFS=$'\x1f' read -r title detail <<< "$context"
tmux_target="${TMUX_PANE:-}"
STATUS_CTL="${AGENT_STATUS_CTL:-$HOME/.local/share/sketchybar-agent-status/bin/agent-statusctl}"
exec "$STATUS_CTL" emit --agent claude --state "$status" --session "$session" --tmux "$tmux_target" --title "$title" --detail "$detail"
