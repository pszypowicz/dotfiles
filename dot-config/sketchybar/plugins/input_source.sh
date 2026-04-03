#!/usr/bin/env bash

if [[ "$SENDER" == "mouse.exited.global" ]]; then
  sketchybar --set input_source popup.drawing=off
  exit 0
fi

keyboard_layout=$(defaults read ~/Library/Preferences/com.apple.HIToolbox.plist AppleSelectedInputSources | grep -Ew 'KeyboardLayout Name' | awk -F\" '{print $4}')

declare -A keyboard_layout_icons
keyboard_layout_icons["Polish Pro"]="PL"
keyboard_layout_icons["Arabic PC"]="ع"
keyboard_layout_icons["USInternational-PC"]="US"

label="${keyboard_layout_icons[$keyboard_layout]}"
y_offset=0
[[ "$keyboard_layout" == "Arabic PC" ]] && y_offset=3

sketchybar --set "$NAME" label="$label" label.y_offset="$y_offset"
