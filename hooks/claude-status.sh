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
title="$(printf '%s' "$payload" | /usr/bin/python3 -c 'import json,sys; print(json.load(sys.stdin).get("prompt", "Claude Code")[:80])')"
tmux_target="${TMUX_PANE:-}"
STATUS_CTL="${AGENT_STATUS_CTL:-$HOME/.local/share/sketchybar-agent-status/bin/agent-statusctl}"
exec "$STATUS_CTL" emit --agent claude --state "$status" --session "$session" --tmux "$tmux_target" --title "$title" --detail "$event"
