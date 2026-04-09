#!/usr/bin/env bash

claude=(
  update_freq=30
  icon=$CLAUDE
  icon.color="$DIM_WHITE"
  label="--"
  label.color="$DIM_WHITE"
  script="$PLUGIN_DIR/claude.sh"
)

sketchybar --add item claude right \
  --set claude "${claude[@]}"
