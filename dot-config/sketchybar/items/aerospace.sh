#!/usr/bin/env bash

set -e

# sketchybar --add event aerospace_focus_changed
# sketchybar --add event aerospace_workspace_change

sketchybar --add alias "Control Center,bobko.aerospace" left \
  --set "Control Center,bobko.aerospace" \
  icon.drawing=off \
  label.drawing=off \
  padding_left=0 \
  padding_right=0
# --subscribe "Control Center,bobko.aerospace" aerospace_workspace_change \
# --subscribe "Control Center,bobko.aerospace" aerospace_focus_changed
