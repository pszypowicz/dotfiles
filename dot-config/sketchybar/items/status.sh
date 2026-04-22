#!/usr/bin/env bash

# Right-side items added in order; first added sits at the right edge.
# Order here: clock (rightmost), separator, battery, separator, volume.
# mic.sh adds mic.shield + mic touching volume on its left, then a separator.

sketchybar \
  --add item clock right \
  --set clock update_freq=10 icon="$CLOCK" script="$PLUGIN_DIR/clock.sh"

add_separator sep_r1 right

sketchybar \
  --add item battery right \
  --set battery update_freq=120 script="$PLUGIN_DIR/battery.sh" \
  --subscribe battery system_woke power_source_change

add_separator sep_r2 right

sketchybar \
  --add item volume right \
  --set volume script="$PLUGIN_DIR/volume.sh" \
              click_script="$PLUGIN_DIR/volume_click.sh" \
              popup.align=right \
  --subscribe volume volume_change mouse.exited.global

add_separator sep_r3 right
