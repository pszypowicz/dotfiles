#!/usr/bin/env bash

PLUGIN_DIR="$CONFIG_DIR/plugins"

# Register custom events
sketchybar --add event aerospace_workspace_change

# Create hidden dummy item to listen for display changes
sketchybar --add item aerospace.observer left \
  --set aerospace.observer \
  drawing=off \
  script="$PLUGIN_DIR/aerospace.sh" \
  --subscribe aerospace.observer aerospace_workspace_change
