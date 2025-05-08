#!/usr/bin/env bash

mic=(
  updates=on
  update_freq=10
  label.drawing=on
  padding_right=4
  label.padding_right=2
  script="$PLUGIN_DIR/mic.sh"
  click_script="$PLUGIN_DIR/mic_click.sh"
)

sketchybar --add event mic_clicked

sketchybar --add item mic right \
  --set mic "${mic[@]}" \
  --subscribe mic mic_clicked
