#!/usr/bin/env bash

source "$CONFIG_DIR/colors.sh"

# ── Nerd Font glyphs ────────────────────────────────────────────────
SHIELD_CHECK=󰕥  # nf-md-shield_check (U+F0565)
SHIELD_OFF=󰦞   # nf-md-shield_off   (U+F099E)
MIC_ON=󰍬       # nf-md-microphone     (U+F036C)
MIC_OFF=󰍭      # nf-md-microphone_off (U+F036D)
CHECK=󰄬        # nf-md-check          (U+F012C)

PREF_FILE="$HOME/.config/mic-guard/preferred-mic"
SHIELD_CLICK="mic-guard -q toggle"

# ── Helpers ─────────────────────────────────────────────────────────

update_bar() {
  local shield_icon="$1" shield_color="$2" mic_icon="$3" mic_color="$4" mic_label="$5" label_color="$6"
  sketchybar -m \
    --set mic.shield icon="$shield_icon" icon.color="$shield_color" label.drawing=off drawing=on click_script="$SHIELD_CLICK" \
    --set mic       icon="$mic_icon"     icon.color="$mic_color" \
                    label="$mic_label"   label.color="$label_color" drawing=on
}

show_off() {
  # Remove stale popup items
  local items
  items=$(sketchybar --query mic 2>/dev/null | jq -r '.popup.items // [] | .[]')
  local args=()
  while IFS= read -r item; do
    [[ -n "$item" ]] && args+=(--remove "$item")
  done <<< "$items"

  args+=(
    --set mic.shield icon="$SHIELD_OFF" icon.color="$RED"
                     label="Off" label.color="$RED" label.drawing=on drawing=on
                     click_script="$SHIELD_CLICK"
    --set mic drawing=off popup.drawing=off
  )
  sketchybar -m "${args[@]}"
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

  # Extract all fields in two jq calls
  CUR=$(echo "$PAYLOAD" | jq -r '(.devices // [] | map(select(.current)) | .[0]) // {}')
  IFS=$'\t' read -r ENABLED CURRENT_NAME CURRENT_MUTED CURRENT_VOLUME PREFERRED <<< "$(
    echo "$PAYLOAD" | jq -r --argjson cur "$CUR" '
      [.enabled,
       ($cur.name // ""),
       ($cur.muted // false),
       ($cur.volume // 0),
       ((.devices // [] | map(select(.preferred)) | .[0].name) // "")]
      | @tsv'
  )"
  DEVICES_JSON=$(echo "$PAYLOAD" | jq -c '.devices // []')

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

  OLD_SLUGS=$(sketchybar --query mic 2>/dev/null | jq -r '.popup.items // [] | .[]' | sort)

  # Sorted names + precomputed slugs
  SORTED_NAMES=()
  SORTED_SLUGS=()
  while IFS= read -r line; do
    if [[ -n "$line" ]]; then
      SORTED_NAMES+=("$line")
      SORTED_SLUGS+=("$(slugify "$line")")
    fi
  done < <(echo "$DEVICES_JSON" | jq -r '.[].name' | sort)

  NEW_SLUGS=""
  for slug in "${SORTED_SLUGS[@]}"; do
    NEW_SLUGS+="mic.device.$slug"$'\n'
  done
  NEW_SLUGS="${NEW_SLUGS%$'\n'}"

  # Unavailable devices
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

    for slug in "${SORTED_SLUGS[@]}"; do
      ARGS+=(--add item "mic.device.$slug" popup.mic)
    done
  fi

  # Update all device properties
  for i in "${!SORTED_NAMES[@]}"; do
    name="${SORTED_NAMES[$i]}"
    ITEM="mic.device.${SORTED_SLUGS[$i]}"
    ESCAPED=$(printf '%s' "$name" | sed "s/'/'\\\\''/g")

    CLICK="mic-guard set '$ESCAPED'; printf '%s' '$ESCAPED' > '$PREF_FILE'; sketchybar --set mic popup.drawing=off"
    if [[ -n "${UNAVAILABLE[$name]+x}" ]]; then
      ICON="$CHECK"; COLOR="0x55ffffff"; DISPLAY="$name (offline)"; CLICK=""
    elif [[ "$name" == "$PREFERRED" ]]; then
      ICON="$CHECK"; COLOR="$WHITE"; DISPLAY="$name"
    else
      ICON=" "; COLOR="$ORANGE"; DISPLAY="$name"
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

# ── Health check: periodic 60s — detect dead MicGuard ─────────────

if ! pgrep -xq MicGuard; then
  show_off
fi
