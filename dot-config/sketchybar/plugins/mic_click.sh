#!/usr/bin/env bash

# Guard: do nothing if MicGuard.app is not running
if ! pgrep -xq MicGuard; then
  exit 0
fi

if [[ "$BUTTON" == "right" ]]; then
  sketchybar --set mic popup.drawing=toggle
else
  mic-guard -q mute
fi
