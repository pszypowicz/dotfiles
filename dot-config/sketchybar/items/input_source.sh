#!/usr/bin/env bash

set -e

input_source=(
  icon.drawing=off
  label.drawing=on
  script="$PLUGIN_DIR/input_source.sh"
)

keyboard_event="AppleSelectedInputSourcesChangedNotification"

SBAR_ARGS+=(
  --add event input_source_changed "$keyboard_event"
  --add item input_source right
  --set input_source "${input_source[@]}"
  --subscribe input_source input_source_changed
)
