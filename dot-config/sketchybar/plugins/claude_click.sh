#!/usr/bin/env bash

# Right-click only: toggle the popup.
# Left-click is intentionally unhandled so the bar item stays passive.
if [[ "$BUTTON" == "right" ]]; then
  sketchybar --set claude popup.drawing=toggle
fi
