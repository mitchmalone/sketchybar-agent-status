# SketchyBar Agent Status

Local-first dynamic SketchyBar widgets for AI coding agents running in tmux.

Each live agent is a clickable item. Click it for task, state, tmux target, and a jump action.

## Current scope

Claude Code + tmux is the first adapter. Codex is deliberately next, not faked into v1.

## Development

```sh
go test ./...
go run ./cmd/agent-statusd
go run ./cmd/agent-statusctl emit --agent claude --state working --session demo --tmux work:1.0 --title "Fix auth"
```

State lives at `~/.local/state/sketchybar-agent-status/state.json`; the Unix socket defaults to `~/.local/state/sketchybar-agent-status/events.sock`.
