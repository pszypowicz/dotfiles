#!/usr/bin/env bash

export PATH="/opt/homebrew/bin:$PATH"
source "$CONFIG_DIR/colors.sh"

# Close popup when mouse leaves item/popup area
if [[ "$SENDER" == "mouse.exited" || "$SENDER" == "mouse.exited.global" ]]; then
  sketchybar --set mic popup.drawing=off
  exit 0
fi

# MicGuard app just terminated — show off state immediately
if [[ "$SENDER" == "mic_app_terminated" ]]; then
  sketchybar -m --set mic label="Off" icon=󰍬 icon.color=$YELLOW label.color=$YELLOW
  exit 0
fi

# Check if MicGuard.app is running (monitoring active)
if ! pgrep -f 'MicGuard.app/Contents/MacOS/MicGuard' >/dev/null 2>&1; then
  sketchybar -m --set mic label="Off" icon=󰍬 icon.color=$YELLOW label.color=$YELLOW
  exit 0
fi

# Attempt to get the current input device name
if ! MIC_NAME=$(mic-guard current 2>/dev/null); then
  sketchybar -m --set mic label="" icon=󰍬 icon.color=$YELLOW label.color=$YELLOW
  exit 0
fi
# I just want the first word, in case it's too long
MIC_NAME=$(echo $MIC_NAME | awk '{print $1}')

# When no microphone is connected, mic-guard may return empty
# Validate MIC_NAME as UTF-8, replace invalid sequences with a '?', then compare with original
VALIDATED_MIC_NAME=$(echo "$MIC_NAME" | iconv -f UTF-8 -t UTF-8//IGNORE)

# Get the current microphone volume
if ! MIC_VOLUME=$(osascript -e 'input volume of (get volume settings)' 2>/dev/null); then
  sketchybar -m --set mic label="" icon=󰍬 icon.color=$YELLOW label.color=$YELLOW
  exit 0
fi

# Check if MIC_NAME is not meaningful
if [[ "$MIC_NAME" != "$VALIDATED_MIC_NAME" || -z "$MIC_NAME" ]]; then
  sketchybar -m --set mic label="" icon=󰍬 icon.color=$YELLOW label.color=$YELLOW
else
  if [[ $MIC_VOLUME -eq 0 ]]; then
    sketchybar -m --set mic label="$MIC_NAME" icon=󰍭 icon.color=$RED label.color=$RED
  else
    sketchybar -m --set mic label="$MIC_NAME" icon=󰍬 icon.color=$WHITE label.color=$WHITE
  fi
fi
