#!/usr/bin/env bash

shopt -s extglob

slugify() {
  local s="${1,,}"
  s="${s//[^a-z0-9]/_}"
  s="${s//+(_)/_}"
  s="${s#_}"; s="${s%_}"
  echo "$s"
}

# Emit --add/--set args for a vertical separator. Designed to be word-split
# into a chained `sketchybar` invocation via $(separator_args NAME SIDE).
# All emitted values are space-free, so unquoted expansion is safe.
separator_args() {
  local name=$1
  local side=$2
  echo "--add item $name $side --set $name label=┃ label.color=0xaaffffff icon.drawing=off background.drawing=off icon.padding_left=0 icon.padding_right=0 label.padding_left=0 label.padding_right=0 padding_left=2 padding_right=2"
}

cleanup_popup() {
  local items
  items=$(sketchybar --query "$1" 2>/dev/null | jq -r '.popup.items // [] | .[]')
  local args=()
  while IFS= read -r item; do
    [[ -n "$item" ]] && args+=(--remove "$item")
  done <<< "$items"
  [[ ${#args[@]} -gt 0 ]] && sketchybar "${args[@]}"
}
