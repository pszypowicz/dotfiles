#!/bin/bash

sketchybar \
  --add item calendar right \
  --set calendar icon=􀧞 \
        update_freq=30 \
        script="$PLUGINS_DIR/calendar.sh"
