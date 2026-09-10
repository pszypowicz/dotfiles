#!/usr/bin/env bash

# aerospace.status drives the whole aerospace cluster. It is hidden in
# the healthy path and renders the dynamic aerospace.monitor.* items
# (one per visible workspace per monitor). Workspace icons are tinted
# orange when the active binding mode is not 'main'. When the AeroSpace
# daemon is unreachable, aerospace.status itself turns into the red
# warning glyph - the always-present carrier means the warning shows
# even on first sketchybar start, before any monitor item has been
# created.
#
# The item is configured here with its full down-state visuals (warning
# glyph, red, padding, y_offset). This is a deliberate race-proofing
# choice: when sketchybar's --update fires the plugin on first load,
# aerospace.status already exists with all its attributes set, so the
# plugin only needs to mutate `drawing` (and color/icon for monitors)
# during state transitions. It cannot accidentally race against its own
# `--add` and try to `--set` an item that doesn't exist yet.
#
# The plugin subscribes to a single aerospace_state_change event (fired
# from every aerospace hook) plus a 5s periodic poll so the unreachable
# state is caught even though AeroSpace has no shutdown hook to fire.

SBAR_ARGS+=(
  --add event aerospace_state_change

  --add item aerospace.status left
  --set aerospace.status
        drawing=on
        update_freq=5
        label.drawing=off
        padding_left=2
        padding_right=2
        icon.padding_left=7
        icon.padding_right=7
        y_offset="$AEROSPACE_Y_OFFSET"
        icon.font.size="$AEROSPACE_FONT_SIZE"
        icon="$AEROSPACE_DOWN"
        icon.color="$RED"
        script="$PLUGIN_DIR/aerospace.sh"
  --subscribe aerospace.status
        aerospace_state_change
        system_woke
        mouse.exited.global
)
