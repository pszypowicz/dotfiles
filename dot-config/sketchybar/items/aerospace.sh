#!/usr/bin/env bash

PLUGIN_DIR="$CONFIG_DIR/plugins"
source "$CONFIG_DIR/colors.sh"

# Register custom events
sketchybar --add event aerospace_workspace_change
sketchybar --add event display_added NSSecondaryDisplayVisChanged

# Create hidden dummy item to listen for display changes
sketchybar --add item aerospace.observer left \
  --set aerospace.observer \
  drawing=off \
  script="$PLUGIN_DIR/aerospace.sh" \
  --subscribe aerospace.observer display_added \
  --subscribe aerospace.observer aerospace_workspace_change
