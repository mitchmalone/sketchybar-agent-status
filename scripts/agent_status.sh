#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/sketchybar-agent-status/state.json"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/sketchybar-agent-status"
CONFIG_FILE="$CONFIG_DIR/config.sh"
LOCAL_CONFIG_FILE="$CONFIG_DIR/local.sh"
SKETCHYBAR_BIN="${SKETCHYBAR_BIN:-sketchybar}"
RENDERED_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/sketchybar-agent-status/rendered-items"
RENDERED_POSITION_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/sketchybar-agent-status/rendered-position"
BRACKET_MEMBERS_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/sketchybar-agent-status/bracket-members"
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"
[[ -f "$LOCAL_CONFIG_FILE" ]] && source "$LOCAL_CONFIG_FILE"

: "${AGENT_STATUS_MAX_ITEMS:=5}"
: "${AGENT_STATUS_POSITION:=right}"
: "${AGENT_STATUS_ANCHOR:=agent_status_anchor}"
: "${AGENT_ICON_FONT:=SF Pro:Regular:10.0}"
: "${AGENT_ICON_STARTING:=◌}" "${AGENT_ICON_WORKING:=●}" "${AGENT_ICON_IDLE:=○}" "${AGENT_ICON_ATTENTION:=!}" "${AGENT_ICON_COMPLETED:=✓}" "${AGENT_ICON_FAILED:=×}" "${AGENT_ICON_UNKNOWN:=?}"
: "${AGENT_COLOR_WORKING:=0xff64d2ff}" "${AGENT_COLOR_IDLE:=0xffaeaeb2}" "${AGENT_COLOR_ATTENTION:=0xffffd60a}" "${AGENT_COLOR_COMPLETED:=0xff30d158}" "${AGENT_COLOR_FAILED:=0xffff453a}"
: "${AGENT_ITEM_BG:=0xff242426}" "${AGENT_CLUSTER_BG:=0x00000000}" "${AGENT_ITEM_BORDER:=0xff636366}" "${AGENT_POPUP_BG:=0xff1c1c1e}" "${AGENT_POPUP_TEXT:=0xffffffff}" "${AGENT_POPUP_MUTED:=0xff98989d}"
if [[ -z "${AGENT_POPUP_ALIGN:-}" ]]; then
  [[ "$AGENT_STATUS_POSITION" == "left" ]] && AGENT_POPUP_ALIGN=left || AGENT_POPUP_ALIGN=right
fi

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
place_after(){
  local name="$1" reference="$2"
  item_exists "$AGENT_STATUS_ANCHOR" || return 0
  "$SKETCHYBAR_BIN" --move "$name" after "$reference"
}
remove_session_widget(){
  local name="$1"
  for suffix in info task task_more detail detail_more target updated jump; do
    "$SKETCHYBAR_BIN" --remove "$name.$suffix" 2>/dev/null || true
  done
  "$SKETCHYBAR_BIN" --remove "$name" 2>/dev/null || true
}
clear_rendered_widgets(){
  [[ -f "$RENDERED_FILE" ]] || return 0
  while IFS= read -r old; do
    [[ -z "$old" ]] && continue
    if [[ "$old" == agent.separator.* ]]; then
      "$SKETCHYBAR_BIN" --remove "$old" 2>/dev/null || true
    else
      remove_session_widget "$old"
    fi
  done < "$RENDERED_FILE"
  rm -f "$RENDERED_FILE"
  "$SKETCHYBAR_BIN" --remove agent_status 2>/dev/null || true
  rm -f "$BRACKET_MEMBERS_FILE"
}
wrap_parts(){ /usr/bin/python3 - "$1" <<'PY'
import sys, textwrap
lines = textwrap.wrap(sys.argv[1], width=44) or ['']
first = lines[0]
second = ' '.join(lines[1:])
if len(second) > 44: second = second[:43].rstrip() + '…'
print(first + '\x1f' + second)
PY
}

[[ -f "$STATE_FILE" ]] || exit 0
mkdir -p "$(dirname "$RENDERED_FILE")"
# Items retain their original bar side after creation. A position change must
# recreate them once; afterwards normal state updates continue in place.
if [[ ! -f "$RENDERED_POSITION_FILE" ]] || [[ "$(<"$RENDERED_POSITION_FILE")" != "$AGENT_STATUS_POSITION" ]]; then
  clear_rendered_widgets
fi
tmp_rendered="$(mktemp)"; trap 'rm -f "$tmp_rendered"' EXIT
count=0
bracket_members=""
previous_item="$AGENT_STATUS_ANCHOR"
while IFS= read -r line; do
  count=$((count + 1))
  [[ "$count" -le "$AGENT_STATUS_MAX_ITEMS" ]] || continue
  IFS=$'\t' read -r session agent status title detail tmux updated <<< "$line"; name="agent.$(safe_name "$session")"; icon="$(icon_for "$agent" "$status")"; color="$(color_for "$status")"
  if [[ -n "$bracket_members" ]]; then
    sep="agent.separator.$(safe_name "$session")"
    ensure_item "$sep" "$AGENT_STATUS_POSITION"
    place_after "$sep" "$previous_item"
    $SKETCHYBAR_BIN --set "$sep" icon.drawing=off label.drawing=off width=1 padding_left=0 padding_right=0 background.drawing=on background.color="$AGENT_ITEM_BORDER" background.border_width=0 background.height=20
    bracket_members="$bracket_members $sep"
    printf '%s\n' "$sep" >> "$tmp_rendered"
    previous_item="$sep"
  fi
  ensure_item "$name" "$AGENT_STATUS_POSITION"
  place_after "$name" "$previous_item"
  ensure_item "$name.info" "popup.$name"
  ensure_item "$name.task" "popup.$name"
  ensure_item "$name.task_more" "popup.$name"
  ensure_item "$name.detail" "popup.$name"
  ensure_item "$name.detail_more" "popup.$name"
  ensure_item "$name.target" "popup.$name"
  ensure_item "$name.updated" "popup.$name"
  ensure_item "$name.jump" "popup.$name"
  IFS=$'\x1f' read -r task task_more <<< "$(wrap_parts "${title:-Not available yet}")"
  IFS=$'\x1f' read -r latest detail_more <<< "$(wrap_parts "${detail:-No lifecycle detail yet}")"
  $SKETCHYBAR_BIN --set "$name" icon="$icon" icon.color="$color" icon.font="$AGENT_ICON_FONT" icon.width=30 icon.align=center icon.y_offset=0 icon.padding_left=0 icon.padding_right=0 label.drawing=off width=30 padding_left=0 padding_right=0 background.drawing=on background.color="$AGENT_ITEM_BG" background.border_width=0 background.height=20 script="${AGENT_STATUS_HOME:-$HOME/.local/share/sketchybar-agent-status}/scripts/agent_item.sh" update_freq=1 click_script="$SKETCHYBAR_BIN --set $name popup.drawing=toggle" popup.align="$AGENT_POPUP_ALIGN" popup.background.drawing=on popup.background.color="$AGENT_POPUP_BG" popup.background.border_color="$AGENT_ITEM_BORDER" popup.background.corner_radius=0 popup.background.border_width=1 popup.background.padding_left=12 popup.background.padding_right=12
  $SKETCHYBAR_BIN --set "$name.info" icon.drawing=off label="Agent: ${agent} · State: ${status}" label.color="$AGENT_POPUP_TEXT" label.font="Monaco:Regular:10.0" label.align=left label.padding_left=8 label.padding_right=8 width=310 background.drawing=off
  $SKETCHYBAR_BIN --set "$name.task" icon.drawing=off label="Task: $task" label.color="$AGENT_POPUP_TEXT" label.font="Monaco:Regular:10.0" label.align=left label.padding_left=8 label.padding_right=8 width=310 background.drawing=off
  $SKETCHYBAR_BIN --set "$name.task_more" icon.drawing=off label="$task_more" label.drawing="$([[ -n "$task_more" ]] && echo on || echo off)" label.color="$AGENT_POPUP_TEXT" label.font="Monaco:Regular:10.0" label.align=left label.padding_left=8 label.padding_right=8 width=310 background.drawing=off
  $SKETCHYBAR_BIN --set "$name.detail" icon.drawing=off label="Latest: $latest" label.color="$AGENT_POPUP_MUTED" label.font="Monaco:Regular:10.0" label.align=left label.padding_left=8 label.padding_right=8 width=310 background.drawing=off
  $SKETCHYBAR_BIN --set "$name.detail_more" icon.drawing=off label="$detail_more" label.drawing="$([[ -n "$detail_more" ]] && echo on || echo off)" label.color="$AGENT_POPUP_MUTED" label.font="Monaco:Regular:10.0" label.align=left label.padding_left=8 label.padding_right=8 width=310 background.drawing=off
  $SKETCHYBAR_BIN --set "$name.target" icon.drawing=off label="tmux target: ${tmux:-Not detected}" label.color="$AGENT_POPUP_MUTED" label.font="Monaco:Regular:10.0" label.align=left label.padding_left=8 label.padding_right=8 width=310 background.drawing=off
  $SKETCHYBAR_BIN --set "$name.updated" icon.drawing=off label="Updated: ${updated:-Unknown}" label.color="$AGENT_POPUP_MUTED" label.font="Monaco:Regular:10.0" label.align=left label.padding_left=8 label.padding_right=8 width=310 background.drawing=off
  $SKETCHYBAR_BIN --set "$name.jump" icon.drawing=off label="↗  Jump to tmux pane" label.color="$AGENT_POPUP_TEXT" label.font="Monaco:Regular:10.0" label.align=left label.padding_left=8 label.padding_right=8 width=310 background.drawing=off click_script="${AGENT_STATUS_HOME:-$HOME/.local/share/sketchybar-agent-status}/scripts/jump.sh '$tmux'; $SKETCHYBAR_BIN --set $name popup.drawing=off"
  bracket_members="$bracket_members $name"
  printf '%s\n' "$name" >> "$tmp_rendered"
  previous_item="$name"
done < <(/usr/bin/python3 - "$STATE_FILE" <<'PY'
import json,sys
for key,value in json.load(open(sys.argv[1])).get('sessions',{}).items():
 print('\t'.join(str(value.get(x,'')) for x in ('session','agent','state','title','detail','tmux','updated_at')))
PY
)
if [[ -n "$bracket_members" ]]; then
  # SketchyBar does not update an existing bracket's members. Rebuild the
  # bracket only when the session/divider list changes; ordinary state updates
  # preserve it in place and therefore do not flash.
  if ! item_exists agent_status || [[ ! -f "$BRACKET_MEMBERS_FILE" ]] || [[ "$(<"$BRACKET_MEMBERS_FILE")" != "$bracket_members" ]]; then
    $SKETCHYBAR_BIN --remove agent_status 2>/dev/null || true
    $SKETCHYBAR_BIN --add bracket agent_status $bracket_members --set agent_status background.drawing=on background.color="$AGENT_CLUSTER_BG" background.border_color="$AGENT_ITEM_BORDER" background.border_width=1 background.height=22 background.corner_radius=0 background.padding_left=1 background.padding_right=1
    printf '%s\n' "$bracket_members" > "$BRACKET_MEMBERS_FILE"
  fi
else
  $SKETCHYBAR_BIN --remove agent_status 2>/dev/null || true
  rm -f "$BRACKET_MEMBERS_FILE"
fi
if [[ -f "$RENDERED_FILE" ]]; then
  while IFS= read -r old; do
    [[ -n "$old" ]] && ! grep -Fxq "$old" "$tmp_rendered" && "$SKETCHYBAR_BIN" --remove "$old" 2>/dev/null || true
  done < "$RENDERED_FILE"
fi
mv "$tmp_rendered" "$RENDERED_FILE"
printf '%s\n' "$AGENT_STATUS_POSITION" > "$RENDERED_POSITION_FILE"
