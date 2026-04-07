#!/usr/bin/env bash

# Called when user clicks/drags the volume slider
if [[ "$SENDER" == "mouse.clicked" ]]; then
  hs -c "hs.audiodevice.defaultOutputDevice():setOutputVolume($PERCENTAGE)"

  source "$CONFIG_DIR/colors.sh"
  source "$CONFIG_DIR/icons.sh"
  VOLUME="${PERCENTAGE%.*}"
  source "$CONFIG_DIR/plugins/volume_icon.sh"
  sketchybar --set volume icon="$ICON" icon.color="$COLOR" label="$VOLUME%" label.color="$COLOR"
fi
