#!/usr/bin/env bash

export PATH="$PATH:/opt/homebrew/bin"
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
  MIC_MUTED=$(echo "$INFO" | sed -n 's/.*"muted"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
  if [[ ${#MIC_NAME} -gt 12 ]]; then
    MIC_NAME="${MIC_NAME:0:11}…"
  fi

  if [[ "$ENABLED" == "0" && "$MIC_MUTED" == "1" ]]; then
    update_bar "$SHIELD_OFF" $YELLOW "$MIC_OFF" $RED "$MIC_NAME" $RED
  elif [[ "$ENABLED" == "0" ]]; then
    update_bar "$SHIELD_OFF" $YELLOW "$MIC_ON" $YELLOW "$MIC_NAME" $YELLOW
  elif [[ "$MIC_MUTED" == "1" ]]; then
    update_bar "$SHIELD_CHECK" $WHITE "$MIC_OFF" $RED "$MIC_NAME" $RED
  else
    update_bar "$SHIELD_CHECK" $WHITE "$MIC_ON" $WHITE "$MIC_NAME" $WHITE
  fi
  exit 0
fi

# Device list changed — rebuild popup items in the background
if [[ "$SENDER" == "mic_devices_changed" && -n "$INFO" ]]; then
  # Skip rebuild if popup is currently visible (user is interacting with it)
  POPUP_DRAWING=$(sketchybar --query mic 2>/dev/null | jq -r '.popup.drawing // "off"')
  if [[ "$POPUP_DRAWING" == "on" ]]; then
    exit 0
  fi

  PREF_FILE="$HOME/.config/mic-guard/preferred-mic"

  # Parse devices JSON from notification payload
  DEVICES_JSON=$(echo "$INFO" | jq -r '.devices // empty')
  if [[ -z "$DEVICES_JSON" ]]; then
    exit 0
  fi

  NAMES=()
  CURRENT_IDX=-1
  while IFS= read -r line; do
    NAMES+=("$line")
  done < <(echo "$DEVICES_JSON" | jq -r '.[].name')
  CURRENT_IDX=$(echo "$DEVICES_JSON" | jq 'to_entries | map(select(.value.current)) | .[0].key // -1')

  DEVICE_COUNT=${#NAMES[@]}

  # Determine MicGuard toggle state
  ENABLED_VAL=$(cat ~/.config/mic-guard/enabled 2>/dev/null)
  if [[ "$ENABLED_VAL" == "0" ]]; then
    MONITOR_LABEL="Enable MicGuard"
    MONITOR_ICON="󰕥"   # nf-md-shield_check
    MONITOR_CMD="mic-guard enable"
  else
    MONITOR_LABEL="Disable MicGuard"
    MONITOR_ICON="󰦞"   # nf-md-shield_off
    MONITOR_CMD="mic-guard disable"
  fi

  # Separator — build dash line matching the longest popup entry
  MAX_LEN=${#MONITOR_LABEL}
  for name in "${NAMES[@]}"; do
    [[ ${#name} -gt $MAX_LEN ]] && MAX_LEN=${#name}
  done
  SEP_LINE=$(printf '—%.0s' $(seq 1 $(( (MAX_LEN + 3) * 17 / 8 ))))

  # Remove existing popup items and rebuild (query first to avoid regex-no-match noise)
  if sketchybar --query mic.device.0 &>/dev/null; then
    sketchybar --remove '/mic\.(device|sep|monitoring)\..*/'
  fi

  ARGS=()
  for ((i = 0; i < DEVICE_COUNT; i++)); do
    device="${NAMES[$i]}"
    ITEM_NAME="mic.device.$i"

    if [[ $i -eq $CURRENT_IDX ]]; then
      ICON="󰄬"; COLOR="$WHITE"
    else
      ICON=" "; COLOR="$ORANGE"
    fi

    ARGS+=(--add item "$ITEM_NAME" popup.mic
      --set "$ITEM_NAME"
        label="$device"
        icon="$ICON"
        icon.width=20
        icon.color="$COLOR"
        label.color="$COLOR"
        background.color=0x00000000
        background.height=30
        background.drawing=on
        click_script="mic-guard set '$device'; echo '$device' > '$PREF_FILE'; sketchybar --set mic popup.drawing=off; sketchybar --trigger mic_clicked")
  done

  ARGS+=(--add item mic.sep.0 popup.mic
    --set mic.sep.0
      icon.drawing=off
      label="$SEP_LINE"
      "label.font=CaskaydiaCove Nerd Font:Bold:8.0"
      label.color=0x44ffffff
      label.padding_left=4
      label.padding_right=4)

  ARGS+=(--add item mic.monitoring.0 popup.mic
    --set mic.monitoring.0
      label="$MONITOR_LABEL"
      icon="$MONITOR_ICON"
      icon.color="$YELLOW"
      label.color="$YELLOW"
      background.color=0x00000000
      background.height=30
      background.drawing=on
      click_script="$MONITOR_CMD; sketchybar --set mic popup.drawing=off; sketchybar --trigger mic_clicked")

  sketchybar "${ARGS[@]}"
  exit 0
fi

# Health check: periodic 60s update / mic_clicked — only detects a dead app
if ! pgrep -xq MicGuard; then
  show_off
fi
