#!/usr/bin/env bash

claude=(
  update_freq=30
  icon=$CLAUDE
  icon.color="$DIM_WHITE"
  label="--"
  label.color="$DIM_WHITE"
  script="$PLUGIN_DIR/claude.sh"
  click_script="$PLUGIN_DIR/claude_click.sh"
  popup.align=right
  popup.height=0
)

claude_popup_row=(
  icon.width=26
  icon.padding_left=8
  label.padding_left=4
  label.padding_right=14
  background.color="$TRANSPARENT"
  background.height=26
  background.drawing=on
)

# Sourced last among right-side items so claude sits at the leftmost
# position of the right cluster (closest to center).
SBAR_ARGS+=( $(separator_args sep_r5 right) )
SBAR_ARGS+=(
  --add item claude right
  --set claude "${claude[@]}"
  --subscribe claude mouse.exited.global

  --add item claude.fivehour popup.claude
  --set claude.fivehour "${claude_popup_row[@]}" icon="$CLOCK"

  --add item claude.sevenday popup.claude
  --set claude.sevenday "${claude_popup_row[@]}" icon="$CALENDAR"

  --add item claude.age popup.claude
  --set claude.age "${claude_popup_row[@]}" icon.drawing=off
)
