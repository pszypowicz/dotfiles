#!/usr/bin/env bash

export PATH="$PATH:/opt/homebrew/bin"

# Guard: do nothing if MicGuard.app is not running
if ! pgrep -xq MicGuard; then
  exit 0
fi

if [[ "$NAME" == "mic.shield" ]]; then
  # Shield left-click: toggle MicGuard enabled/disabled
  ICON=$(sketchybar --query mic.shield 2>/dev/null | jq -r '.icon.value')
  if [[ "$ICON" == "󰕥" ]]; then
    mic-guard -q disable
  else
    mic-guard -q enable
  fi
elif [[ "$BUTTON" == "right" ]]; then
  sketchybar --set mic popup.drawing=toggle
else
  mic-guard mute
fi
