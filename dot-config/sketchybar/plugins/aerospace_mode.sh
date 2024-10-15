#!/usr/bin/env bash

source "$CONFIG_DIR/colors.sh"

echo $MODE

if [ "$MODE" = "service" ]; then
    sketchybar \
      --set "$NAME" \
          background.color=$WHITE \
          icon.color=$ITEM_BG_COLOR
else
    sketchybar \
      --set "$NAME" \
          background.color=$ITEM_BG_COLOR \
          icon.color=$WHITE
fi
