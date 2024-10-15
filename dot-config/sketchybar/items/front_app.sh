#!/bin/bash

sketchybar \
  --add item front_app left \
  --set front_app \
        icon.font="sketchybar-app-font:Regular:16.0" \
        background.color=$WHITE \
        icon.color=$ITEM_BG_COLOR \
        label.color=$ITEM_BG_COLOR \
        script="$PLUGINS_DIR/front_app.sh" \
  --subscribe front_app front_app_switched
