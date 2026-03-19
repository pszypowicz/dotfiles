#!/usr/bin/env bash

export PATH="/opt/homebrew/bin:$PATH"
source "$CONFIG_DIR/colors.sh"

# Close popup when mouse leaves item/popup area
if [[ "$SENDER" == "mouse.exited" || "$SENDER" == "mouse.exited.global" ]]; then
  sketchybar --set mic popup.drawing=off
  exit 0
fi

# Nerd Font glyphs
SHIELD_CHECK=󰕥  # nf-md-shield_check (U+F0565)
SHIELD_OFF=󰦞   # nf-md-shield_off (U+F099E)
MIC_ON=󰍬       # nf-md-microphone (U+F036C)
MIC_OFF=󰍭      # nf-md-microphone_off (U+F036D)

# Helper: update both items in a single sketchybar call
update_bar() {
  local shield_icon=$1 shield_color=$2 mic_icon=$3 mic_color=$4 mic_label=$5 label_color=$6
  sketchybar -m \
    --set mic.shield icon="$shield_icon" icon.color=$shield_color label.drawing=off drawing=on \
    --set mic icon="$mic_icon" icon.color=$mic_color label="$mic_label" label.color=$label_color drawing=on
}

show_off() {
  sketchybar -m \
    --set mic.shield icon="$SHIELD_OFF" icon.color=$RED label="Off" label.color=$RED label.drawing=on drawing=on \
    --set mic drawing=off
}

# MicGuard app just terminated — hide both items
if [[ "$SENDER" == "mic_app_terminated" ]]; then
  show_off
  exit 0
fi

# Fast path: notification from MicGuard with full state in $INFO
if [[ "$SENDER" == "mic_status_changed" && -n "$INFO" ]]; then
  ENABLED=$(echo "$INFO" | sed -n 's/.*"enabled"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
  MIC_NAME=$(echo "$INFO" | sed -n 's/.*"device"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
  MIC_VOLUME=$(echo "$INFO" | sed -n 's/.*"volume"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
  MIC_NAME=$(echo "$MIC_NAME" | awk '{print $1}')

  if [[ "$ENABLED" == "0" ]]; then
    update_bar "$SHIELD_OFF" $YELLOW "$MIC_ON" $YELLOW "$MIC_NAME" $YELLOW
  elif [[ "${MIC_VOLUME:-0}" -eq 0 ]]; then
    update_bar "$SHIELD_CHECK" $WHITE "$MIC_OFF" $RED "$MIC_NAME" $RED
  else
    update_bar "$SHIELD_CHECK" $WHITE "$MIC_ON" $WHITE "$MIC_NAME" $WHITE
  fi
  exit 0
fi

# Health check: periodic 60s update / mic_clicked — only detects a dead app
if ! pgrep -xq MicGuard; then
  show_off
fi
