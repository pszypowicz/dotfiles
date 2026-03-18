#!/usr/bin/env bash

source "$CONFIG_DIR/colors.sh"

# Close popup when mouse leaves item/popup area
if [[ "$SENDER" == "mouse.exited" || "$SENDER" == "mouse.exited.global" ]]; then
  sketchybar --set mic popup.drawing=off
  exit 0
fi

# Attempt to get the current input device name
MIC_NAME=$(mic-guard current)
# I just want the first word, in case it's too long
MIC_NAME=$(echo $MIC_NAME | awk '{print $1}')

# When no microphone is connected, mic-guard may return empty
# Validate MIC_NAME as UTF-8, replace invalid sequences with a '?', then compare with original
VALIDATED_MIC_NAME=$(echo "$MIC_NAME" | iconv -f UTF-8 -t UTF-8//IGNORE)

# Get the current microphone volume
MIC_VOLUME=$(osascript -e 'input volume of (get volume settings)')

# Check if MIC_NAME is not meaningful
if [[ "$MIC_NAME" != "$VALIDATED_MIC_NAME" || -z "$MIC_NAME" ]]; then
  # If the mic name is not valid or empty
  sketchybar -m --set mic label="" icon= icon.color=$YELLOW label.color=$YELLOW
else
  # Update SketchyBar with the microphone's name and volume
  if [[ $MIC_VOLUME -eq 0 ]]; then
    sketchybar -m --set mic label="$MIC_NAME $MIC_VOLUME" icon= icon.color=$RED label.color=$RED
  elif [[ $MIC_VOLUME -gt 0 && $MIC_VOLUME -lt 100 ]]; then
    sketchybar -m --set mic label="$MIC_NAME $MIC_VOLUME" icon= icon.color=$ORANGE label.color=$ORANGE
  elif [[ $MIC_VOLUME -eq 100 ]]; then
    sketchybar -m --set mic label="$MIC_NAME $MIC_VOLUME" icon= icon.color=$WHITE label.color=$WHITE
  fi
fi
