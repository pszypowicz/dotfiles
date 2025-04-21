#!/usr/bin/env bash

set -e

sketchybar --add event aerospace_focus_changed
sketchybar --add event aerospace_workspace_change

sketchybar \
  --add item aerospace left \
  --set aerospace \
  drawing=off \
  script="$PLUGIN_DIR/aerospace.sh" \
  --subscribe aerospace aerospace_workspace_change \
  --subscribe aerospace aerospace_focus_changed

for sid in $(aerospace list-workspaces --all);
do
    sketchybar \
      --add space space.$sid left \
      --set space.$sid \
      background.drawing=off \
      icon.drawing=off \
      label="$sid" \
      label.highlight=off \
      label.highlight_color=0xffFF0000 \
      click_script="aerospace workspace $sid" \
      script="exit 0" \
      display=0
done
