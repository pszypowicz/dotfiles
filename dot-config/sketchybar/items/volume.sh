#!/bin/bash

sketchybar \
  --add item volume right \
  --set volume script="$PLUGINS_DIR/volume.sh" \
  --subscribe volume volume_change
