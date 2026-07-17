#!/usr/bin/env bash

# Event-driven microphone display fed by MicGuard's status broadcast.
# Read-only: shows the current input device and whether it is muted. The 60s
# tick is a health check - it greys the item out when MicGuard is not running
# and recovers the display after a bar reload (MicGuard cannot be queried, so
# the plugin reads the state directly when its label is empty).

mic=(
  update_freq=60
  icon.width=20
  label.drawing=on
  padding_left=0
  padding_right=4
  label.padding_right=2
  script="$PLUGIN_DIR/mic.sh"
)

SBAR_ARGS+=(
  --add event mic_status_changed "cz.szypowi.micguard.statusChanged"
  --add item mic right
  --set mic "${mic[@]}"
  --subscribe mic mic_status_changed
)
SBAR_ARGS+=( $(separator_args sep_r4 right) )
