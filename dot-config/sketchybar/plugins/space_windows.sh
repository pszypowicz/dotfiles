#!/bin/bash

# TODO: macbook needs to be a main display, otherwise sketchybar will not workq
# https://github.com/FelixKratz/SketchyBar/issues/628

CONFIG_DIR="$HOME/.config/sketchybar"
PLUGINS_DIR="$CONFIG_DIR/plugins"
source "$PLUGINS_DIR/icon_map.sh"
source "$CONFIG_DIR/colors.sh"

WINDOWS=`aerospace list-windows --all --format '%{workspace}:%{app-name}:%{monitor-id}'`
if [ -n "$FOCUSED_WORKSPACE" ]; then
  FOCUSED_WORKSPACE=`aerospace list-workspaces --focused`
fi
ALL_WORKSPACES=`aerospace list-workspaces --all`
NONEMPTY_WORKSPACES=`echo "$WINDOWS" | awk -F: '{print $1}' | sort | uniq`

while read -r ws; do
  # Check if current workspace is NOT empty
  if echo "$NONEMPTY_WORKSPACES" | grep -q "^$ws$"; then

    DISPLAY=`echo "$WINDOWS" | awk -F: '{if ($1 == "'$ws'") print $3}' | uniq`
    sketchybar --set "space.$ws" display=$DISPLAY

    APPS=`echo "$WINDOWS" | awk -F: '{if ($1 == "'$ws'") print $2}' | sort | uniq`

    ICON_STRIP=""
    if [ "${APPS}" != "" ]; then
      while read -r app; do
        __icon_map "$app"
        ICON_STRIP+=" $icon_result"
      done <<< "${APPS}"
    else
      ICON_STRIP="—"
    fi

    sketchybar --set "space.$ws" label="$ICON_STRIP"
  else
    if [ "$ws" = "$FOCUSED_WORKSPACE" ]; then
      #TODO: It seems there is no event when workspace is empty
      sketchybar --set "space.$ws" display=1
    else
      sketchybar --set "space.$ws" display=0
    fi
  fi

  if [ "$ws" = "$FOCUSED_WORKSPACE" ]; then
      sketchybar \
        --set "space.$ws" \
            background.color=$WHITE \
            icon.color=$ITEM_BG_COLOR \
            label.color=$ITEM_BG_COLOR
  else
      sketchybar \
        --set "space.$ws" \
            background.color=$ITEM_BG_COLOR \
            icon.color=$WHITE \
            label.color=$WHITE
  fi
done <<< "${ALL_WORKSPACES}"
