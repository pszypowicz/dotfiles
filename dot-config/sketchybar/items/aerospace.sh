#!/usr/bin/env bash

# aerospace.observer is the single driver for the aerospace cluster. It
# is hidden in the healthy path and renders the dynamic
# aerospace.monitor.* items (one per visible workspace per monitor).
# Workspace icons are tinted orange when the active binding mode is not
# 'main'. When the AeroSpace daemon is unreachable, the observer itself
# turns into the red warning glyph - the always-present carrier means the
# warning shows even on first sketchybar start, before any monitor item
# has ever been created. The observer subscribes to every aerospace event
# plus a 5s periodic poll so the unreachable state is caught even though
# AeroSpace has no shutdown hook to fire.

SBAR_ARGS+=(
  --add event aerospace_workspace_change
  --add event aerospace_mode_change
  --add event aerospace_health

  --add item aerospace.observer left
  --set aerospace.observer
        drawing=off
        update_freq=5
        label.drawing=off
        icon.font.size=22
        script="$PLUGIN_DIR/aerospace.sh"
  --subscribe aerospace.observer
        aerospace_workspace_change
        aerospace_mode_change
        aerospace_health
        system_woke
        mouse.exited.global
)
