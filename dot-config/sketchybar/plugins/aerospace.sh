#!/usr/bin/env bash

source "$CONFIG_DIR/icons.sh"

# Update all monitor items with current visible workspaces
while IFS=: read -r workspace monitor_id; do
  [[ -z "$workspace" ]] && continue

  item_name="aerospace.monitor.$monitor_id"

  icon_var="AEROWORKSPACE_$workspace"

  sketchybar --add item "$item_name" left \
    --set "$item_name" \
    display="$monitor_id" \
    background.drawing=off \
    background.padding_right=0 \
    padding_left=2 \
    icon="${!icon_var}" \
    padding_right=2 \
    icon.font.size=22 \
    --move "$item_name" after aerospace.observer
done <<<"$(aerospace list-workspaces --monitor all --visible --format '%{workspace}:%{monitor-appkit-nsscreen-screens-id}')"
