#!/usr/bin/env bash

source "$CONFIG_DIR/colors.sh"

# ── Nerd Font glyphs ────────────────────────────────────────────────
SHIELD_CHECK=󰕥  # nf-md-shield_check (U+F0565)
SHIELD_OFF=󰦞   # nf-md-shield_off   (U+F099E)
MIC_ON=󰍬       # nf-md-microphone     (U+F036C)
MIC_OFF=󰍭      # nf-md-microphone_off (U+F036D)
CHECK=󰄬        # nf-md-check          (U+F012C)

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

shopt -s extglob
slugify() {
  local s="${1,,}"
  s="${s//[^a-z0-9]/_}"
  s="${s//+(_)/_}"
  s="${s#_}"; s="${s%_}"
  echo "$s"
}

# ── Mouse exit → close popup ───────────────────────────────────────

if [[ "$SENDER" == "mouse.exited.global" ]]; then
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

  # Extract all fields in a single jq call
  eval "$(echo "$PAYLOAD" | jq -r '
    (.devices // []) as $devs |
    ($devs | map(select(.current)) | .[0] // {}) as $cur |
    (($devs | map(select(.preferred)) | .[0].name) // "") as $pref |
    ($devs | map(select(.available == false) | .name)) as $unavail |
    @sh "ENABLED=\(.enabled // false)",
    @sh "CURRENT_NAME=\($cur.name // "")",
    @sh "CURRENT_MUTED=\($cur.muted // false)",
    @sh "CURRENT_VOLUME=\($cur.volume // 0)",
    @sh "PREFERRED=\($pref)",
    @sh "DEVICES_JSON=\($devs | tojson)",
    "UNAVAILABLE_NAMES=(\($unavail | map(@sh) | join(" ")))"
  ')"

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

  # Unavailable devices (from UNAVAILABLE_NAMES set by jq above)
  declare -A UNAVAILABLE=()
  for _uname in "${UNAVAILABLE_NAMES[@]}"; do
    UNAVAILABLE["$_uname"]=1
  done

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

    CLICK="mic-guard -q set '$ESCAPED'; sketchybar --set mic popup.drawing=off"
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
