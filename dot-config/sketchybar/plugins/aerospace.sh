#!/usr/bin/env bash

source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/icons.sh"

echo $SENDER

# On display_added event (monitor hot-plug), create items for any new monitors
if [[ "$SENDER" == "display_added" || "$SENDER" == "forced" ]]; then
  while read -r monitor_id; do
    [[ -z "$monitor_id" ]] && continue

    item_name="aerospace.monitor.$monitor_id"

    # Add item (sketchybar ignores if already exists)
    sketchybar --add item "$item_name" left \
      --set "$item_name" \
      display="$monitor_id" \
      label.color="$WORKSPACE_FOCUSED" \
      background.drawing=off \
      background.padding_right=0 \
      padding_left=2 \
      padding_right=2 \
      icon.font.size=22 \
      --move "$item_name" after aerospace.observer
  done <<<"$(aerospace list-monitors --format '%{monitor-appkit-nsscreen-screens-id}')"
fi

# Update all monitor items with current visible workspaces
while IFS=: read -r workspace monitor_id; do
  [[ -z "$workspace" ]] && continue
  icon_var="AEROWORKSPACE_$workspace"
  sketchybar --set "aerospace.monitor.$monitor_id" icon="${!icon_var}"
done <<<"$(aerospace list-workspaces --monitor all --visible --format '%{workspace}:%{monitor-appkit-nsscreen-screens-id}')"
