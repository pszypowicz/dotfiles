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

# Unified status + devices notification from MicGuard
if [[ "$SENDER" == "mic_status_changed" && -n "$INFO" ]]; then
  slugify() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g; s/__*/_/g; s/^_//; s/_$//'
  }

  # Parse the inner JSON payload
  PAYLOAD=$(echo "$INFO" | jq -r '.info // empty')
  [[ -z "$PAYLOAD" ]] && exit 0

  ENABLED=$(echo "$PAYLOAD" | jq -r '.enabled')
  DEVICES_JSON=$(echo "$PAYLOAD" | jq -c '.devices // []')

  # Extract current device info for bar display
  CURRENT_DEVICE=$(echo "$DEVICES_JSON" | jq -r '.[] | select(.current) | .name // empty')
  CURRENT_VOLUME=$(echo "$DEVICES_JSON" | jq -r '.[] | select(.current) | .volume // 0')
  CURRENT_MUTED=$(echo "$DEVICES_JSON" | jq -r '.[] | select(.current) | .muted // false')

  # Truncate device name for bar label
  MIC_NAME="$CURRENT_DEVICE"
  if [[ ${#MIC_NAME} -gt 12 ]]; then
    MIC_NAME="${MIC_NAME:0:11}…"
  fi

  # Muted = volume at zero or native mute flag
  IS_MUTED=false
  if [[ "$CURRENT_VOLUME" == "0" || "$CURRENT_MUTED" == "true" ]]; then
    IS_MUTED=true
  fi

  # Update bar icons
  if [[ "$ENABLED" == "false" && "$IS_MUTED" == "true" ]]; then
    update_bar "$SHIELD_OFF" $YELLOW "$MIC_OFF" $RED "$MIC_NAME" $RED
  elif [[ "$ENABLED" == "false" ]]; then
    update_bar "$SHIELD_OFF" $YELLOW "$MIC_ON" $YELLOW "$MIC_NAME" $YELLOW
  elif [[ "$IS_MUTED" == "true" ]]; then
    update_bar "$SHIELD_CHECK" $WHITE "$MIC_OFF" $RED "$MIC_NAME" $RED
  else
    update_bar "$SHIELD_CHECK" $WHITE "$MIC_ON" $WHITE "$MIC_NAME" $WHITE
  fi

  # --- Popup: diff-based add/remove/update of device items ---

  PREF_FILE="$HOME/.config/mic-guard/preferred-mic"

  # Extract sorted device names
  SORTED_NAMES=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && SORTED_NAMES+=("$line")
  done < <(echo "$DEVICES_JSON" | jq -r '.[].name' | sort)

  # Build new slugs set
  declare -A NEW_SLUGS=()
  for name in "${SORTED_NAMES[@]}"; do
    slug=$(slugify "$name")
    NEW_SLUGS[$slug]="$name"
  done

  NEW_COUNT=${#SORTED_NAMES[@]}

  # Determine MicGuard toggle state
  if [[ "$ENABLED" == "false" ]]; then
    MONITOR_LABEL="Enable MicGuard"
    MONITOR_ICON="󰕥"   # nf-md-shield_check
    MONITOR_CMD="mic-guard enable"
  else
    MONITOR_LABEL="Disable MicGuard"
    MONITOR_ICON="󰦞"   # nf-md-shield_off
    MONITOR_CMD="mic-guard disable"
  fi

  # Query existing popup items
  POPUP_ITEMS=$(sketchybar --query mic 2>/dev/null | jq -r '.popup.items // [] | .[]')
  declare -A OLD_SLUGS=()
  HAS_SEP=false
  HAS_MONITORING=false
  while IFS= read -r item; do
    [[ -z "$item" ]] && continue
    case "$item" in
      mic.device.*) OLD_SLUGS[${item#mic.device.}]=1 ;;
      mic.sep.*)    HAS_SEP=true ;;
      mic.monitoring.*) HAS_MONITORING=true ;;
    esac
  done <<< "$POPUP_ITEMS"

  # Separator — build dash line matching the longest popup entry
  MAX_LEN=${#MONITOR_LABEL}
  for name in "${SORTED_NAMES[@]}"; do
    [[ ${#name} -gt $MAX_LEN ]] && MAX_LEN=${#name}
  done
  SEP_LINE=$(printf '—%.0s' $(seq 1 $(( (MAX_LEN + 3) * 17 / 8 ))))

  ARGS=()

  # Remove all existing device items so re-adding them preserves sorted order
  for old_slug in "${!OLD_SLUGS[@]}"; do
    ARGS+=(--remove "mic.device.$old_slug")
  done

  # Build availability lookup and find preferred device
  declare -A DEVICE_AVAILABLE=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && DEVICE_AVAILABLE["$line"]=1
  done < <(echo "$DEVICES_JSON" | jq -r '.[] | select(.available == false) | .name')
  PREFERRED_DEVICE=$(echo "$DEVICES_JSON" | jq -r '.[] | select(.preferred == true) | .name // empty')

  # Add/update device items
  for name in "${SORTED_NAMES[@]}"; do
    slug=$(slugify "$name")
    ITEM_NAME="mic.device.$slug"

    ESCAPED_DEVICE=$(printf '%s' "$name" | sed "s/'/'\\\\''/g")

    if [[ -n "${DEVICE_AVAILABLE[$name]+x}" ]]; then
      # Unavailable (disconnected) preferred device
      ICON="󰄬"; COLOR="0x55ffffff"
      DISPLAY_NAME="$name (offline)"
      CLICK_SCRIPT=""
    elif [[ "$name" == "$PREFERRED_DEVICE" ]]; then
      ICON="󰄬"; COLOR="$WHITE"
      DISPLAY_NAME="$name"
      CLICK_SCRIPT="mic-guard set '$ESCAPED_DEVICE'; printf '%s' '$ESCAPED_DEVICE' > '$PREF_FILE'; sketchybar --set mic popup.drawing=off; sketchybar --trigger mic_clicked"
    else
      ICON=" "; COLOR="$ORANGE"
      DISPLAY_NAME="$name"
      CLICK_SCRIPT="mic-guard set '$ESCAPED_DEVICE'; printf '%s' '$ESCAPED_DEVICE' > '$PREF_FILE'; sketchybar --set mic popup.drawing=off; sketchybar --trigger mic_clicked"
    fi

    ARGS+=(--add item "$ITEM_NAME" popup.mic)
    ARGS+=(--set "$ITEM_NAME"
      label="$DISPLAY_NAME"
      icon="$ICON"
      icon.width=20
      icon.color="$COLOR"
      label.color="$COLOR"
      background.color=0x00000000
      background.height=30
      background.drawing=on
      click_script="$CLICK_SCRIPT")
  done

  # Remove separator and monitoring toggle so re-adding keeps correct order
  [[ "$HAS_SEP" == true ]] && ARGS+=(--remove mic.sep.0)
  [[ "$HAS_MONITORING" == true ]] && ARGS+=(--remove mic.monitoring.0)

  # Separator: add if there are devices
  if [[ $NEW_COUNT -gt 0 ]]; then
    ARGS+=(--add item mic.sep.0 popup.mic)
    ARGS+=(--set mic.sep.0
      icon.drawing=off
      label="$SEP_LINE"
      "label.font=CaskaydiaCove Nerd Font:Bold:8.0"
      label.color=0x44ffffff
      label.padding_left=4
      label.padding_right=4)
  fi

  # Monitoring toggle: always present
  ARGS+=(--add item mic.monitoring.0 popup.mic)

  ARGS+=(--set mic.monitoring.0
    label="$MONITOR_LABEL"
    icon="$MONITOR_ICON"
    icon.color="$YELLOW"
    label.color="$YELLOW"
    background.color=0x00000000
    background.height=30
    background.drawing=on
    click_script="$MONITOR_CMD >/dev/null; sketchybar --set mic popup.drawing=off; sketchybar --trigger mic_clicked")

  # Ensure correct popup order: devices (alphabetical), separator, monitoring toggle
  ORDER=()
  for name in "${SORTED_NAMES[@]}"; do
    ORDER+=("mic.device.$(slugify "$name")")
  done
  [[ $NEW_COUNT -gt 0 ]] && ORDER+=("mic.sep.0")
  ORDER+=("mic.monitoring.0")
  ARGS+=(--reorder "${ORDER[@]}")

  sketchybar "${ARGS[@]}"
  exit 0
fi

# Health check: periodic 60s update / mic_clicked — only detects a dead app
if ! pgrep -xq MicGuard; then
  show_off
fi
