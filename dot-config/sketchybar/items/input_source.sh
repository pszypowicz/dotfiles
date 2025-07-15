#!/usr/bin/env bash

set -e

input_source=(
  label.drawing=on
  script="$PLUGIN_DIR/input_source.sh"
  click_script="$PLUGIN_DIR/input_source_click.sh"
)

keyboard_event="AppleSelectedInputSourcesChangedNotification"
sketchybar --add event input_source_changed $keyboard_event

sketchybar --add item input_source right \
  --set input_source "${input_source[@]}" \
  --subscribe input_source input_source_changed
