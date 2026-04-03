#!/usr/bin/env bash

source "$CONFIG_DIR/colors.sh"

if [[ "$BUTTON" == "right" ]]; then
  app=$(sketchybar --query front_app | jq -r '.label.value')
  escaped=$(printf '%s' "$app" | sed "s/\"/\\\\\"/g")

  # Remove existing popup items
  items=$(sketchybar --query front_app 2>/dev/null | jq -r '.popup.items // [] | .[]')
  while IFS= read -r item; do
    [[ -n "$item" ]] && sketchybar --remove "$item"
  done <<< "$items"

  sketchybar \
    --add item front_app.quit popup.front_app \
    --set front_app.quit \
      label="Quit $app" \
      icon=󰅙 \
      icon.color="$RED" \
      label.color="$RED" \
      background.color=0x00000000 \
      background.height=30 \
      background.drawing=on \
      click_script="osascript -e 'tell application \"$escaped\" to quit'; sketchybar --set front_app popup.drawing=off" \
    --set front_app popup.drawing=on
fi
