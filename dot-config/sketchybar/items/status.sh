#!/usr/bin/env bash

# Right-side items added in order; first added sits at the right edge.
# Order here: clock (rightmost), separator, battery, separator, volume, separator.
# mic.sh adds mic.shield + mic immediately to the left, then a separator.

SBAR_ARGS+=(
  --add item clock right
  --set clock update_freq=10 icon="$CLOCK" script="$PLUGIN_DIR/clock.sh"
)
SBAR_ARGS+=( $(separator_args sep_r1 right) )
SBAR_ARGS+=(
  --add item battery right
  --set battery update_freq=120 script="$PLUGIN_DIR/battery.sh"
  --subscribe battery system_woke power_source_change
)
SBAR_ARGS+=( $(separator_args sep_r2 right) )
SBAR_ARGS+=(
  --add item volume right
  --set volume script="$PLUGIN_DIR/volume.sh"
               click_script="$PLUGIN_DIR/volume_click.sh"
               popup.align=right
  --subscribe volume volume_change mouse.exited.global
)
SBAR_ARGS+=( $(separator_args sep_r3 right) )
