#!/usr/bin/env bash

# Close popup on mouse exit
if [[ "$SENDER" == "mouse.exited.global" ]]; then
  sketchybar --set volume popup.drawing=off
  exit 0
fi

source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/icons.sh"

if [ "$SENDER" = "volume_change" ]; then
  VOLUME="$INFO"
  source "$CONFIG_DIR/plugins/volume_icon.sh"
  sketchybar --set "$NAME" icon="$ICON" icon.color="$COLOR" label="$VOLUME%" label.color="$COLOR"
fi
