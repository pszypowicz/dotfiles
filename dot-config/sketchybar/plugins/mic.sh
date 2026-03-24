#!/usr/bin/env bash

export PATH="/opt/homebrew/bin:$PATH"
source "$CONFIG_DIR/colors.sh"

# ── Nerd Font glyphs ────────────────────────────────────────────────
SHIELD_CHECK=󰕥  # nf-md-shield_check (U+F0565)
SHIELD_OFF=󰦞   # nf-md-shield_off   (U+F099E)
MIC_ON=󰍬       # nf-md-microphone     (U+F036C)
MIC_OFF=󰍭      # nf-md-microphone_off (U+F036D)
CHECK=󰄬        # nf-md-check          (U+F012C)

PREF_FILE="$HOME/.config/mic-guard/preferred-mic"

# ── Helpers ─────────────────────────────────────────────────────────

update_bar() {
  local shield_icon=$1 shield_color=$2 mic_icon=$3 mic_color=$4 mic_label=$5 label_color=$6
  sketchybar -m \
    --set mic.shield icon="$shield_icon" icon.color="$shield_color" label.drawing=off drawing=on \
    --set mic       icon="$mic_icon"     icon.color="$mic_color" \
                    label="$mic_label"   label.color="$label_color" drawing=on
}

show_off() {
  sketchybar -m \
    --set mic.shield icon="$SHIELD_OFF" icon.color="$RED" \
                     label="Off" label.color="$RED" label.drawing=on drawing=on \
    --set mic drawing=off
}

slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g; s/__*/_/g; s/^_//; s/_$//'
}

# ── Mouse exit → close popup ───────────────────────────────────────

if [[ "$SENDER" == "mouse.exited" || "$SENDER" == "mouse.exited.global" ]]; then
  sketchybar --set mic popup.drawing=off
  exit 0
fi

# ── App terminated → "Off" state ───────────────────────────────────

if [[ "$SENDER" == "mic_app_terminated" ]]; then
  show_off
  exit 0
fi

# ── Status changed → update bar icons + popup ─────────────────────

if [[ "$SENDER" == "mic_status_changed" && -n "$INFO" ]]; then

  PAYLOAD=$(echo "$INFO" | jq -r '.info // empty')
  [[ -z "$PAYLOAD" ]] && exit 0

  ENABLED=$(echo "$PAYLOAD" | jq -r '.enabled')
  DEVICES_JSON=$(echo "$PAYLOAD" | jq -c '.devices // []')

  # Current device info
  CURRENT_NAME=$(echo "$DEVICES_JSON"   | jq -r '[.[] | select(.current)] | first | .name // empty')
  CURRENT_MUTED=$(echo "$DEVICES_JSON"  | jq -r '[.[] | select(.current)] | first | .muted // false')
  CURRENT_VOLUME=$(echo "$DEVICES_JSON" | jq -r '[.[] | select(.current)] | first | .volume // 0')

  # Truncate label
  MIC_NAME="$CURRENT_NAME"
  if [[ ${#MIC_NAME} -gt 12 ]]; then
    MIC_NAME="${MIC_NAME:0:11}…"
  fi

  # Muted = native mute flag OR volume zero
  IS_MUTED=false
  [[ "$CURRENT_MUTED" == "true" || "$CURRENT_VOLUME" == "0" ]] && IS_MUTED=true

  # Update bar icons
  if [[ "$ENABLED" == "false" && "$IS_MUTED" == "true" ]]; then
    update_bar "$SHIELD_OFF"   "$YELLOW" "$MIC_OFF" "$RED"    "$MIC_NAME" "$RED"
  elif [[ "$ENABLED" == "false" ]]; then
    update_bar "$SHIELD_OFF"   "$YELLOW" "$MIC_ON"  "$YELLOW" "$MIC_NAME" "$YELLOW"
  elif [[ "$IS_MUTED" == "true" ]]; then
    update_bar "$SHIELD_CHECK" "$WHITE"  "$MIC_OFF" "$RED"    "$MIC_NAME" "$RED"
  else
    update_bar "$SHIELD_CHECK" "$WHITE"  "$MIC_ON"  "$WHITE"  "$MIC_NAME" "$WHITE"
  fi

  # ── Popup: devices only ───────────────────────────────────────

  # Existing popup items (sorted set of slugs)
  OLD_SLUGS=$(sketchybar --query mic 2>/dev/null | jq -r '.popup.items // [] | .[]' | sort)

  # Desired device slugs (sorted)
  SORTED_NAMES=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && SORTED_NAMES+=("$line")
  done < <(echo "$DEVICES_JSON" | jq -r '.[].name' | sort)

  NEW_SLUGS=""
  for name in "${SORTED_NAMES[@]}"; do
    NEW_SLUGS+="mic.device.$(slugify "$name")"$'\n'
  done
  NEW_SLUGS=$(echo -n "$NEW_SLUGS" | sort)

  PREFERRED=$(echo "$DEVICES_JSON" | jq -r '[.[] | select(.preferred)] | first | .name // empty')

  declare -A UNAVAILABLE=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && UNAVAILABLE["$line"]=1
  done < <(echo "$DEVICES_JSON" | jq -r '.[] | select(.available == false) | .name')

  ARGS=()

  if [[ "$OLD_SLUGS" != "$NEW_SLUGS" ]]; then
    # Device list changed — full rebuild (remove all, re-add in sorted order)
    while IFS= read -r item; do
      [[ -n "$item" ]] && ARGS+=(--remove "$item")
    done <<< "$OLD_SLUGS"

    for name in "${SORTED_NAMES[@]}"; do
      ARGS+=(--add item "mic.device.$(slugify "$name")" popup.mic)
    done
  fi

  # Update all device properties (both rebuild and in-place update paths)
  for name in "${SORTED_NAMES[@]}"; do
    slug=$(slugify "$name")
    ITEM="mic.device.$slug"
    ESCAPED=$(printf '%s' "$name" | sed "s/'/'\\\\''/g")

    if [[ -n "${UNAVAILABLE[$name]+x}" ]]; then
      ICON="$CHECK"; COLOR="0x55ffffff"
      DISPLAY="$name (offline)"
      CLICK=""
    elif [[ "$name" == "$PREFERRED" ]]; then
      ICON="$CHECK"; COLOR="$WHITE"
      DISPLAY="$name"
      CLICK="mic-guard set '$ESCAPED'; printf '%s' '$ESCAPED' > '$PREF_FILE'; sketchybar --set mic popup.drawing=off"
    else
      ICON=" "; COLOR="$ORANGE"
      DISPLAY="$name"
      CLICK="mic-guard set '$ESCAPED'; printf '%s' '$ESCAPED' > '$PREF_FILE'; sketchybar --set mic popup.drawing=off"
    fi

    ARGS+=(--set "$ITEM"
      label="$DISPLAY"
      icon="$ICON"
      icon.width=20
      icon.color="$COLOR"
      label.color="$COLOR"
      background.color=0x00000000
      background.height=30
      background.drawing=on
      click_script="$CLICK")
  done

  sketchybar "${ARGS[@]}"
  exit 0
fi
