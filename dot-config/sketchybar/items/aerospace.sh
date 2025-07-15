#!/usr/bin/env bash

set -e

sketchybar --add event aerospace_focus_changed
sketchybar --add event aerospace_workspace_change

sketchybar --add alias "AeroSpace" left \
  --set AeroSpace \
  icon.drawing=off \
  label.drawing=off \
  padding_left=0 \
  padding_right=0 \
  --subscribe AeroSpace aerospace_workspace_change \
  --subscribe AeroSpace aerospace_focus_changed
