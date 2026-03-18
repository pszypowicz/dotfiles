#!/usr/bin/env bash

export PATH="/opt/homebrew/bin:$PATH"
source "$CONFIG_DIR/colors.sh"

PREF_FILE="$HOME/.config/mic-guard/preferred-mic"

# Guard: do nothing if MicGuard.app is not running
if ! pgrep -f 'MicGuard.app/Contents/MacOS/MicGuard' >/dev/null 2>&1; then
  exit 0
fi

if [[ "$BUTTON" == "right" ]]; then
  # Right-click: build popup with all input devices
  DEVICES=$(mic-guard list)
  CURRENT=$(mic-guard current)

  # Remove existing popup items
  sketchybar --remove '/mic.device\..*/' 2>/dev/null

  INDEX=0
  while IFS= read -r device; do
    [[ -z "$device" ]] && continue
    ITEM_NAME="mic.device.$INDEX"

    if [[ "$device" == "$CURRENT" ]]; then
      ICON="󰄬"
      COLOR="$WHITE"
    else
      ICON=""
      COLOR="$ORANGE"
    fi

    sketchybar --add item "$ITEM_NAME" popup.mic \
      --set "$ITEM_NAME" \
        label="$device" \
        icon="$ICON" \
        icon.color="$COLOR" \
        label.color="$COLOR" \
        click_script="mic-guard set '$device'; echo '$device' > '$PREF_FILE'; sketchybar --set mic popup.drawing=off; sketchybar --trigger mic_clicked"

    INDEX=$((INDEX + 1))
  done <<< "$DEVICES"

  sketchybar --set mic popup.drawing=toggle
else
  # Left-click: mute/unmute toggle
  MIC_NAME=$(mic-guard current)
  MIC_NAME=$(echo "$MIC_NAME" | awk '{print $1}')

  VALIDATED_MIC_NAME=$(echo "$MIC_NAME" | iconv -f UTF-8 -t UTF-8//IGNORE)

  MIC_VOLUME=$(osascript -e 'input volume of (get volume settings)')

  if ! [[ "$MIC_NAME" != "$VALIDATED_MIC_NAME" || -z "$MIC_NAME" ]]; then
    if [[ $MIC_VOLUME -lt 100 ]]; then
      osascript -e 'set volume input volume 100'
    elif [[ $MIC_VOLUME -gt 0 ]]; then
      osascript -e 'set volume input volume 0'
    fi
  fi

  sketchybar --trigger mic_clicked
fi
