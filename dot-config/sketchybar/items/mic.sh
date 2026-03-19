#!/usr/bin/env bash

set -e

mic=(
  updates=on
  update_freq=60
  label.drawing=on
  icon.width=22
  padding_right=4
  label.padding_right=2
  popup.align=right
  popup.height=0
  script="$PLUGIN_DIR/mic.sh"
  click_script="$PLUGIN_DIR/mic_click.sh"
)

sketchybar --add event mic_clicked
sketchybar --add event mic_status_changed "com.micguard.statusChanged"
sketchybar --add event mic_app_terminated "com.micguard.appTerminated"

sketchybar --add item mic right \
  --set mic "${mic[@]}" \
  --subscribe mic mic_clicked mic_status_changed mic_app_terminated mouse.exited mouse.exited.global

# Request current status from MicGuard
mic-guard ping 2>/dev/null &
