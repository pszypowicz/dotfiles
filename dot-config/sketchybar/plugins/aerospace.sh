#!/usr/bin/env bash

# Exit early if AeroSpace isn't running yet (e.g. during boot)
# Note: pgrep doesn't work from sketchybar's context (macOS sandbox isolation),
# so we use the aerospace CLI itself to check availability.
if ! aerospace list-workspaces --monitor all --count 2>/dev/null; then
  exit 0
fi

source "$CONFIG_DIR/icons.sh"

# Query existing items once
existing_items=$(sketchybar --query bar | grep -o '"aerospace\.monitor\.[^"]*"')

# Update all monitor items with current visible workspaces
while IFS=: read -r workspace monitor_id; do
  [[ -z "$workspace" ]] && continue

  item_name="aerospace.monitor.$monitor_id"
  icon_var="AEROWORKSPACE_$workspace"

  if echo "$existing_items" | grep -q "\"$item_name\""; then
    sketchybar --set "$item_name" \
      display="$monitor_id" \
      icon="${!icon_var}" \
      icon.font.size=22
  else
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
  fi
done <<<"$(aerospace list-workspaces --monitor all --visible --format '%{workspace}:%{monitor-appkit-nsscreen-screens-id}')"
