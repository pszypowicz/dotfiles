#!/usr/bin/env bash

export PATH="/opt/homebrew/bin:$PATH"
source "$CONFIG_DIR/colors.sh"

PREF_FILE="$HOME/.config/mic-guard/preferred-mic"

# Guard: do nothing if MicGuard.app is not running
if ! pgrep -xq MicGuard; then
  exit 0
fi

if [[ "$BUTTON" == "right" ]]; then
  # Right-click: build popup with all input devices
  DEVICES=$(mic-guard list)
  CURRENT=$(mic-guard current)

  # Remove existing popup items from both mic and mic.shield
  sketchybar --remove '/mic\.(device|sep|monitoring)\..*/' 2>/dev/null
  sketchybar --remove '/mic\.shield\.(device|sep|monitoring)\..*/' 2>/dev/null

  INDEX=0
  while IFS= read -r device; do
    [[ -z "$device" ]] && continue
    ITEM_NAME="mic.device.$INDEX"

    if [[ "$device" == "$CURRENT" ]]; then
      ICON="󰄬"
      COLOR="$WHITE"
    else
      ICON=" "
      COLOR="$ORANGE"
    fi

    sketchybar --add item "$ITEM_NAME" popup.mic \
      --set "$ITEM_NAME" \
        label="$device" \
        icon="$ICON" \
        icon.width=20 \
        icon.color="$COLOR" \
        label.color="$COLOR" \
        background.color=0x00000000 \
        background.height=30 \
        background.drawing=on \
        click_script="mic-guard set '$device'; echo '$device' > '$PREF_FILE'; sketchybar --set mic popup.drawing=off; sketchybar --trigger mic_clicked"

    INDEX=$((INDEX + 1))
  done <<< "$DEVICES"

  # Determine MicGuard toggle — label shows what clicking will do
  ENABLED=$(cat ~/.config/mic-guard/enabled 2>/dev/null)
  if [[ "$ENABLED" == "0" ]]; then
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
  while IFS= read -r device; do
    [[ ${#device} -gt $MAX_LEN ]] && MAX_LEN=${#device}
  done <<< "$DEVICES"
  # +3 accounts for icon + icon padding equivalent in characters
  SEP_LINE=$(printf '—%.0s' $(seq 1 $(( (MAX_LEN + 3) * 17 / 8 ))))

  sketchybar --add item mic.sep.0 popup.mic \
    --set mic.sep.0 \
      icon.drawing=off \
      label="$SEP_LINE" \
      label.font="CaskaydiaCove Nerd Font:Bold:8.0" \
      label.color=0x44ffffff \
      label.padding_left=4 \
      label.padding_right=4

  sketchybar --add item mic.monitoring.0 popup.mic \
    --set mic.monitoring.0 \
      label="$MONITOR_LABEL" \
      icon="$MONITOR_ICON" \
      icon.color="$YELLOW" \
      label.color="$YELLOW" \
      background.color=0x00000000 \
      background.height=30 \
      background.drawing=on \
      click_script="$MONITOR_CMD; sketchybar --set mic popup.drawing=off; sketchybar --trigger mic_clicked"

  sketchybar --set mic popup.drawing=toggle
else
  # Left-click: mute/unmute toggle via native CoreAudio
  mic-guard mute
  sketchybar --trigger mic_clicked
fi
