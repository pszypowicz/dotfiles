#!/usr/bin/env bash

sketchybar \
  --add item chevron left \
  --set chevron icon="$CHEVRON" label.drawing=off \
  --add item front_app left \
  --set front_app icon.drawing=off script="$PLUGIN_DIR/front_app.sh" \
              click_script="$PLUGIN_DIR/front_app_click.sh" \
              popup.align=left \
  --subscribe front_app front_app_switched mouse.exited.global
