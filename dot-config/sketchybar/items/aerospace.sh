#!/usr/bin/env bash

# Hidden observer item that listens for workspace changes and runs the
# plugin to add/update visible aerospace.monitor.* items dynamically.

SBAR_ARGS+=(
  --add event aerospace_workspace_change
  --add item aerospace.observer left
  --set aerospace.observer drawing=off script="$PLUGIN_DIR/aerospace.sh"
  --subscribe aerospace.observer aerospace_workspace_change mouse.exited.global
)
