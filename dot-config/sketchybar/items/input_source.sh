#!/usr/bin/env bash

set -e

input_source=(
  label.drawing=on
  script="$PLUGIN_DIR/input_source.sh"
  click_script="$PLUGIN_DIR/input_source_click.sh"
  popup.align=right
)

keyboard_event="AppleSelectedInputSourcesChangedNotification"

SBAR_ARGS+=(
  --add event input_source_changed "$keyboard_event"
  --add item input_source right
  --set input_source "${input_source[@]}"
  --subscribe input_source input_source_changed mouse.exited.global
)
