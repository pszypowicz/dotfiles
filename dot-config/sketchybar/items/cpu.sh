#!/bin/bash

sketchybar \
  --add item cpu right \
  --set cpu update_freq=2 \
      icon=􀧓 \
      script="$PLUGINS_DIR/cpu.sh"
