#!/usr/bin/env bash
set -euo pipefail

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/sketchybar-agent-status"
state_file="$state_dir/state.json"
SB="${SKETCHYBAR_BIN:-/opt/homebrew/bin/sketchybar}"
status="$(/usr/bin/python3 - "$state_file" "$NAME" <<'PY'
import json,re,sys
try: sessions=json.load(open(sys.argv[1])).get('sessions',{})
except Exception: sessions={}
for key, value in sessions.items():
  if 'agent.' + re.sub(r'[^A-Za-z0-9]+', '_', key) == sys.argv[2]: print(value.get('state','')); break
PY
)"
blink="$state_dir/blink.$NAME"
if [[ "$status" == "attention" ]]; then
  if [[ -f "$blink" ]]; then rm -f "$blink"; "$SB" --set "$NAME" icon.color=0xffffca80; else touch "$blink"; "$SB" --set "$NAME" icon.color=0xffffffff; fi
else
  rm -f "$blink"
fi
