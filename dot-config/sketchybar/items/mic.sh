#!/usr/bin/env bash

set -e

# Add order (first = rightmost): mic sits to the right of mic.shield, then a
# separator before input_source. status.sh adds a separator immediately to
# the right of this group (between mic and volume).
# sketchybarrc pings MicGuard after the global call so the items exist when
# the response comes back.

mic=(
  updates=on
  update_freq=60
  icon.width=20
  label.drawing=on
  padding_left=0
  padding_right=4
  label.padding_right=2
  popup.align=right
  popup.height=0
  script="$PLUGIN_DIR/mic.sh"
  click_script="$PLUGIN_DIR/mic_click.sh"
)

mic_shield=(
  icon.drawing=on
  icon.width=20
  label.drawing=off
  padding_left=4
  padding_right=0
)

SBAR_ARGS+=(
  --add event mic_status_changed "com.pszypowicz.MicGuard.statusChanged"
  --add event mic_app_terminated "com.pszypowicz.MicGuard.appTerminated"
  --add item mic right
  --set mic "${mic[@]}"
  --subscribe mic mic_status_changed mic_app_terminated mouse.exited.global
  --add item mic.shield right
  --set mic.shield "${mic_shield[@]}"
  --subscribe mic.shield mouse.exited.global
)
SBAR_ARGS+=( $(separator_args sep_r4 right) )
