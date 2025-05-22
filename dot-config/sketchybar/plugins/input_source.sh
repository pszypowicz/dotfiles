#!/usr/bin/env bash

set -e

# defaults read ~/Library/Preferences/com.apple.HIToolbox.plist AppleSelectedInputSources | egrep -w 'KeyboardLayout Name'
# This returns:
#       "KeyboardLayout Name" = "Polish Pro";

# We just need the name of the keyboard layout, so we can use awk to extract it.

keyboard_layout=$(defaults read ~/Library/Preferences/com.apple.HIToolbox.plist AppleSelectedInputSources | egrep -w 'KeyboardLayout Name' | awk -F\" '{print $4}')

declare -A keyboard_layout_icons
keyboard_layout_icons["Polish Pro"]="PL"
keyboard_layout_icons["Arabic PC"]="ع"
keyboard_layout_icons["USInternational-PC"]="US"

sketchybar --set "$NAME" label="${keyboard_layout_icons[$keyboard_layout]}"
