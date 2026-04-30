#!/usr/bin/env bash

source "$CONFIG_DIR/icons.sh"
source "$CONFIG_DIR/colors.sh"

# Mouse-exit closes any open monitor popup without touching state.
if [[ "$SENDER" == "mouse.exited.global" ]]; then
  while IFS=: read -r _ monitor_id; do
    [[ -z "$monitor_id" ]] && continue
    sketchybar --set "aerospace.monitor.$monitor_id" popup.drawing=off 2>/dev/null
  done <<<"$(aerospace list-workspaces --monitor all --visible \
              --format '%{workspace}:%{monitor-appkit-nsscreen-screens-id}' 2>/dev/null)"
  exit 0
fi

mapfile -t monitor_items < <(
  sketchybar --query bar | jq -r '.items[] | select(startswith("aerospace.monitor."))'
)

args=()

# AeroSpace down: surface the warning on the always-present observer
# (cheaper than the CLI and survives a wedged daemon) and hide whatever
# workspace icons are still cached from a prior healthy render.
if ! pgrep -xq AeroSpace; then
  args+=(
    --set aerospace.observer
      drawing=on
      padding_left=2
      padding_right=2
      icon.padding_left=7
      icon.padding_right=7
      y_offset=1
      icon="$AEROSPACE_DOWN"
      icon.color="$RED"
  )
  for item in "${monitor_items[@]}"; do
    args+=( --set "$item" drawing=off )
  done
  sketchybar "${args[@]}"
  exit 0
fi

# AeroSpace up: hide the warning carrier; render workspaces below.
args+=( --set aerospace.observer drawing=off )

mode=$(aerospace list-modes --current 2>/dev/null)
if [[ "$mode" == "main" || -z "$mode" ]]; then
  color="$WHITE"
else
  color="$ORANGE"
fi

while IFS=: read -r workspace monitor_id; do
  [[ -z "$workspace" ]] && continue

  item_name="aerospace.monitor.$monitor_id"
  icon_var="AEROWORKSPACE_$workspace"

  exists=0
  for item in "${monitor_items[@]}"; do
    [[ "$item" == "$item_name" ]] && { exists=1; break; }
  done

  if (( exists )); then
    args+=(
      --set "$item_name"
        drawing=on
        display="$monitor_id"
        padding_left=2
        padding_right=2
        icon="${!icon_var}"
        icon.color="$color"
        icon.font.size=22
      --move "$item_name" after aerospace.observer
    )
  else
    args+=(
      --add item "$item_name" left
      --set "$item_name"
        display="$monitor_id"
        background.drawing=off
        background.padding_right=0
        padding_left=2
        padding_right=2
        icon="${!icon_var}"
        icon.color="$color"
        icon.font.size=22
        click_script="$CONFIG_DIR/plugins/aerospace_click.sh"
      --move "$item_name" after aerospace.observer
    )
  fi
done <<<"$(aerospace list-workspaces --monitor all --visible \
            --format '%{workspace}:%{monitor-appkit-nsscreen-screens-id}')"

sketchybar "${args[@]}"
