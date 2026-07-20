#!/usr/bin/env bash
set -euo pipefail
target="${1:?tmux target required}"
tmux switch-client -t "${target%%:*}" 2>/dev/null || true
tmux select-window -t "$target" 2>/dev/null || true
