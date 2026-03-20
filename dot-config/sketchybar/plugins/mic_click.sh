#!/usr/bin/env bash

export PATH="$PATH:/opt/homebrew/bin"
source "$CONFIG_DIR/colors.sh"

# Guard: do nothing if MicGuard.app is not running
if ! pgrep -xq MicGuard; then
  exit 0
fi

if [[ "$BUTTON" == "right" ]]; then
  # Right-click: toggle popup visibility
  # Popup items are pre-built by mic_devices_changed handler
  sketchybar --set mic popup.drawing=toggle
else
  # Left-click: mute/unmute toggle via native CoreAudio
  mic-guard mute
  sketchybar --trigger mic_clicked
fi
