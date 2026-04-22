#!/usr/bin/env bash

claude=(
  update_freq=30
  icon=$CLAUDE
  icon.color="$DIM_WHITE"
  label="--"
  label.color="$DIM_WHITE"
  script="$PLUGIN_DIR/claude.sh"
)

# Sourced last among right-side items so claude sits at the leftmost
# position of the right cluster (closest to center).
add_separator sep_r5 right

sketchybar --add item claude right \
  --set claude "${claude[@]}"
