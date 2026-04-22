#!/usr/bin/env bash

source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/icons.sh"
source "$CONFIG_DIR/utils.sh"

if [[ "$BUTTON" == "right" ]]; then
  app=$(sketchybar --query front_app | jq -r '.label.value')
  escaped=$(printf '%s' "$app" | sed "s/\"/\\\\\"/g")

  sketchybar \
    $(popup_remove_args front_app) \
    --add item front_app.quit popup.front_app \
    --set front_app.quit \
      label="Quit $app" \
      icon="$QUIT" \
      icon.color="$RED" \
      label.color="$RED" \
      background.color="$TRANSPARENT" \
      background.height=30 \
      background.drawing=on \
      click_script="osascript -e 'tell application \"$escaped\" to quit'; sketchybar --set front_app popup.drawing=off" \
    --set front_app popup.drawing=on
fi
