#!/usr/bin/env bash

SBAR_ARGS+=(
  --add item chevron left
  --set chevron
        icon="$CHEVRON"
        label.drawing=off
        padding_left=2
        padding_right=2
        icon.padding_left=0
        icon.padding_right=0
  --add item front_app left
  --set front_app icon.drawing=off
                  script="$PLUGIN_DIR/front_app.sh"
                  click_script="$PLUGIN_DIR/front_app_click.sh"
                  popup.align=left
  --subscribe front_app front_app_switched mouse.exited.global
)
