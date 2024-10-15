#!/bin/bash

sketchybar --add event aerospace_update_windows
sketchybar --add event aerospace_workspace_change
sketchybar --add event aerospace_mode

for sid in $(aerospace list-workspaces --all); do
  sketchybar \
    --add space space.$sid left \
    --set space.$sid \
        space=$sid \
        icon=$sid \
        label.font="sketchybar-app-font:Regular:16.0" \
        label.y_offset=-1 \
        click_script="aerospace workspace $sid" \
        script="$PLUGINS_DIR/aerospace.sh"
done

sketchybar \
  --add item space_separator left \
  --set space_separator \
      icon="􀆊" \
      label.drawing=off \
      icon.padding_right=9 \
      script="$PLUGINS_DIR/space_windows.sh" \
  --subscribe space_separator aerospace_update_windows \
  --subscribe space_separator aerospace_workspace_change

sketchybar \
  --add item aerospace_mode right \
  --set aerospace_mode \
      icon="􀣋" \
      label.drawing=off \
      icon.padding_right=6 \
      script="$PLUGINS_DIR/aerospace_mode.sh" \
  --subscribe aerospace_mode aerospace_mode
