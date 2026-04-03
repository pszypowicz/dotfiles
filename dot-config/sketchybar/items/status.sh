#!/usr/bin/env bash

sketchybar \
  --add item clock right \
  --set clock update_freq=10 icon=  script="$PLUGIN_DIR/clock.sh" \
  --add item volume right \
  --set volume script="$PLUGIN_DIR/volume.sh" \
              click_script="$PLUGIN_DIR/volume_click.sh" \
              popup.align=right \
  --subscribe volume volume_change mouse.exited.global \
  --add item battery right \
  --set battery update_freq=120 script="$PLUGIN_DIR/battery.sh" \
  --subscribe battery system_woke power_source_change
