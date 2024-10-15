#!/bin/sh

# Some events send additional information specific to the event in the $INFO
# variable. E.g. the front_app_switched event sends the name of the newly
# focused application in the $INFO variable:
# https://felixkratz.github.io/SketchyBar/config/events#events-and-scripting

CONFIG_DIR="$HOME/.config/sketchybar"
PLUGINS_DIR="$CONFIG_DIR/plugins"

source "$PLUGINS_DIR/icon_map.sh"
__icon_map "$INFO"

if [ "$SENDER" = "front_app_switched" ]; then
  sketchybar --set $NAME label="$INFO" icon="$icon_result"
fi
