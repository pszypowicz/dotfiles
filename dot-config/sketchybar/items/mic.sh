#!/usr/bin/env bash

set -e

mic=(
  updates=on
  update_freq=60
  icon.width=20
  label.drawing=on
  padding_right=4
  padding_left=0
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
  padding_right=0
  padding_left=5
)

# Events
sketchybar --add event mic_status_changed "com.pszypowicz.MicGuard.statusChanged"
sketchybar --add event mic_app_terminated "com.pszypowicz.MicGuard.appTerminated"

# mic item (rightmost - mic icon + device name label)
sketchybar --add item mic right \
  --set mic "${mic[@]}" \
  --subscribe mic mic_status_changed mic_app_terminated mouse.exited.global

# mic.shield item (left of mic - shield icon only)
sketchybar --add item mic.shield right \
  --set mic.shield "${mic_shield[@]}" \
  --subscribe mic.shield mouse.exited.global

# Request current status so bar populates immediately on (re)start
mic-guard -q ping 2>/dev/null &
