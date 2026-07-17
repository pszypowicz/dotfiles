#!/usr/bin/env bash

source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/icons.sh"

set_mic() {
  local name="$1" muted="$2"
  if [[ ${#name} -gt 12 ]]; then
    name="${name:0:11}…"
  fi
  if [[ "$muted" == "true" ]]; then
    sketchybar --set mic icon="$MIC_OFF" icon.color="$RED" label="$name" label.color="$RED"
  else
    sketchybar --set mic icon="$MIC_ON" icon.color="$WHITE" label="$name" label.color="$WHITE"
  fi
}

# Event from MicGuard - the steady-state path
if [[ "$SENDER" == "mic_status_changed" ]]; then
  name=$(echo "$INFO" | jq -r '.device // empty')
  muted=$(echo "$INFO" | jq -r '.muted // "false"')
  [[ -n "$name" ]] && set_mic "$name" "$muted"
  exit 0
fi

# Health tick (60s) and the forced update after a bar reload
if ! pgrep -xq MicGuard; then
  sketchybar --set mic icon="$MIC_OFF" icon.color="$DIM_WHITE" label="off" label.color="$DIM_WHITE"
  exit 0
fi

# MicGuard broadcasts changes but cannot be queried, so after a bar reload the
# item stays empty until the next broadcast. Recover once by reading the state
# directly; system_profiler is slow (~1s) but this never runs in steady state.
label=$(sketchybar --query mic | jq -r '.label.value')
if [[ -z "$label" || "$label" == "off" ]]; then
  name=$(system_profiler SPAudioDataType -json 2>/dev/null | jq -r '
    .SPAudioDataType[0]._items[]?
    | select(.coreaudio_default_audio_input_device == "spaudio_yes")
    | ._name' | head -1)
  vol=$(osascript -e 'input volume of (get volume settings)' 2>/dev/null)
  muted=false
  [[ "$vol" == "0" ]] && muted=true
  [[ -n "$name" ]] && set_mic "$name" "$muted"
fi
