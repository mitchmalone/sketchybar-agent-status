# Spec 01: Claude Code + tmux MVP

## Goal

Render one clickable SketchyBar widget per live Claude Code session running in tmux.

## Stories

- [x] Receive normalized lifecycle events through a local Unix socket and persist session state.
- [x] Reconcile dynamic SketchyBar items from that state, including stale-item cleanup and a five-item cap.
- [x] Make item click open a detail popup containing state, task/context, tmux target, and an explicit jump action.
- [x] Make global and per-agent icons configurable in user-owned configuration.
- [x] Supply a LaunchAgent and explicit Claude hook example.

## Verification gate

- [x] `go test ./...` passes.
- [x] Renderer test asserts attention icon, popup toggle, and jump action.
- [x] Unix-socket integration test persists a real event.
