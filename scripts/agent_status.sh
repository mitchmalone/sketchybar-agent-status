#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/sketchybar-agent-status/state.json"
CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/sketchybar-agent-status/config.sh"
SKETCHYBAR_BIN="${SKETCHYBAR_BIN:-sketchybar}"
RENDERED_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/sketchybar-agent-status/rendered-items"
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

: "${AGENT_STATUS_MAX_ITEMS:=5}"
: "${AGENT_ICON_STARTING:=⏳}" "${AGENT_ICON_WORKING:=🧑‍🍳}" "${AGENT_ICON_IDLE:=😴}" "${AGENT_ICON_ATTENTION:=👀}" "${AGENT_ICON_COMPLETED:=✅}" "${AGENT_ICON_FAILED:=❌}" "${AGENT_ICON_UNKNOWN:=❔}"
: "${AGENT_COLOR_WORKING:=0xff8aadf4}" "${AGENT_COLOR_IDLE:=0xffa6adc8}" "${AGENT_COLOR_ATTENTION:=0xfff9e2af}" "${AGENT_COLOR_COMPLETED:=0xffa6e3a1}" "${AGENT_COLOR_FAILED:=0xfff38ba8}"

upper(){ printf '%s' "$1" | tr '[:lower:]' '[:upper:]'; }
icon_for(){
  local agent_key="AGENT_ICON_$(upper "$1")_$(upper "$2")"
  local state_key="AGENT_ICON_$(upper "$2")"
  printf '%s' "${!agent_key:-${!state_key:-$AGENT_ICON_UNKNOWN}}"
}
color_for(){ local key="AGENT_COLOR_$(upper "$1")"; printf '%s' "${!key:-$AGENT_COLOR_WORKING}"; }
safe_name(){ printf '%s' "$1" | tr -cs '[:alnum:]' '_'; }
item_exists(){ "$SKETCHYBAR_BIN" --query "$1" 2>&1 | grep -Fq "\"name\": \"$1\""; }
ensure_item(){
  local name="$1" position="$2"
  item_exists "$name" || "$SKETCHYBAR_BIN" --add item "$name" "$position"
}

[[ -f "$STATE_FILE" ]] || exit 0
mkdir -p "$(dirname "$RENDERED_FILE")"
tmp_rendered="$(mktemp)"; trap 'rm -f "$tmp_rendered"' EXIT
count=0
while IFS= read -r line; do
  count=$((count + 1))
  [[ "$count" -le "$AGENT_STATUS_MAX_ITEMS" ]] || continue
  IFS=$'\t' read -r session agent status title detail tmux updated <<< "$line"; name="agent.$(safe_name "$session")"; icon="$(icon_for "$agent" "$status")"; color="$(color_for "$status")"
  ensure_item "$name" right
  ensure_item "$name.info" "popup.$name"
  ensure_item "$name.task" "popup.$name"
  ensure_item "$name.detail" "popup.$name"
  ensure_item "$name.target" "popup.$name"
  ensure_item "$name.updated" "popup.$name"
  ensure_item "$name.jump" "popup.$name"
  $SKETCHYBAR_BIN --set "$name" icon="$icon" label="${title:-$agent}" icon.color="$color" label.max_chars=18 background.drawing=on click_script="$SKETCHYBAR_BIN --set $name popup.drawing=toggle" popup.align=right popup.background.corner_radius=0 popup.background.border_width=1
  $SKETCHYBAR_BIN --set "$name.info" icon.drawing=off label="Agent: ${agent} · State: ${status}"
  $SKETCHYBAR_BIN --set "$name.task" icon.drawing=off label="Task: ${title:-Not available yet}"
  $SKETCHYBAR_BIN --set "$name.detail" icon.drawing=off label="Latest: ${detail:-No lifecycle detail yet}"
  $SKETCHYBAR_BIN --set "$name.target" icon.drawing=off label="tmux target: ${tmux:-Not detected}"
  $SKETCHYBAR_BIN --set "$name.updated" icon.drawing=off label="Updated: ${updated:-Unknown}"
  $SKETCHYBAR_BIN --set "$name.jump" icon="↗" label="Jump to tmux pane" click_script="${AGENT_STATUS_HOME:-$HOME/.local/share/sketchybar-agent-status}/scripts/jump.sh '$tmux'; $SKETCHYBAR_BIN --set $name popup.drawing=off"
  printf '%s\n' "$name" >> "$tmp_rendered"
done < <(/usr/bin/python3 - "$STATE_FILE" <<'PY'
import json,sys
for key,value in json.load(open(sys.argv[1])).get('sessions',{}).items():
 print('\t'.join(str(value.get(x,'')) for x in ('session','agent','state','title','detail','tmux','updated_at')))
PY
)
if [[ -f "$RENDERED_FILE" ]]; then
  while IFS= read -r old; do
    [[ -n "$old" ]] && ! grep -Fxq "$old" "$tmp_rendered" && "$SKETCHYBAR_BIN" --remove "$old" 2>/dev/null || true
  done < "$RENDERED_FILE"
fi
mv "$tmp_rendered" "$RENDERED_FILE"
