#!/usr/bin/env python3
"""Idempotently add the Agent Status hook to an existing Claude settings file."""
import json
import pathlib
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: install-claude-hooks.py <settings.json>")

settings_path = pathlib.Path(sys.argv[1]).expanduser()
settings = json.loads(settings_path.read_text()) if settings_path.exists() else {}
hooks = settings.setdefault("hooks", {})
command = str(pathlib.Path.home() / ".local/share/sketchybar-agent-status/hooks/claude-status.sh")
events = ("SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse", "PermissionRequest", "Stop", "SessionEnd")
for event in events:
    groups = hooks.setdefault(event, [])
    present = any(hook.get("command") == command for group in groups for hook in group.get("hooks", []))
    if not present:
        groups.append({"hooks": [{"type": "command", "command": command}]})

settings_path.parent.mkdir(parents=True, exist_ok=True)
settings_path.write_text(json.dumps(settings, indent=2) + "\n")
print(f"Updated {settings_path}")
