#!/usr/bin/env bash

# Sets ICON and COLOR based on VOLUME. Source colors.sh and set VOLUME before calling.
# Usage: VOLUME=50; source volume_icon.sh

COLOR="$WHITE"

case "$VOLUME" in
  [6-9][0-9]|100) ICON="$VOLUME_HIGH" ;;
  [3-5][0-9]) ICON="$VOLUME_MED" ;;
  [1-9]|[1-2][0-9]) ICON="$VOLUME_LOW" ;;
  0) ICON="$VOLUME_MUTE"; COLOR="$RED" ;;
  *) ICON="$VOLUME_HIGH"; VOLUME="--" ;;
esac
