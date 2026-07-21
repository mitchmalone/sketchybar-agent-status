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

## Install

```sh
./install.sh --with-claude-hooks
```

The installer automatically adds a marked source line to an existing `~/.config/sketchybar/sketchybarrc` and reloads SketchyBar. The installer merges its Claude hooks without replacing existing hook groups, including a `~/.claude-psyke` profile when present.

Click an agent indicator to open its popup. It shows agent/state/task context, the most recent lifecycle detail, and a dedicated **Jump to tmux pane** action.

Copy `config/example.config.sh` to `~/.config/sketchybar-agent-status/config.sh` to alter global state emojis, pin the emoji font/size, or set a per-agent override such as `AGENT_ICON_CODEX_WORKING="⚙️"`.
