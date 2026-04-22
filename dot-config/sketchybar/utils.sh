#!/usr/bin/env bash

shopt -s extglob

slugify() {
  local s="${1,,}"
  s="${s//[^a-z0-9]/_}"
  s="${s//+(_)/_}"
  s="${s#_}"; s="${s%_}"
  echo "$s"
}

add_separator() {
  local name=$1
  local side=$2
  sketchybar --add item "$name" "$side" \
    --set "$name" \
      label="┃" \
      label.color=0xaaffffff \
      icon.drawing=off \
      background.drawing=off \
      icon.padding_left=0 \
      icon.padding_right=0 \
      label.padding_left=0 \
      label.padding_right=0 \
      padding_left=2 \
      padding_right=2
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
