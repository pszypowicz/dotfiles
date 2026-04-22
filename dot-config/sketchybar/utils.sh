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

# Emit `--remove ITEM` args for every item currently in $1's popup, so the
# caller can splice them into a chained sketchybar invocation alongside the
# rebuild work (saves one fork+exec per popup click).
popup_remove_args() {
  sketchybar --query "$1" 2>/dev/null \
    | jq -r '.popup.items // [] | .[] | "--remove \(.)"'
}

# Toggle popup on $1 with one sketchybar --query.
# If the popup is open: close it, return 1 (caller should exit).
# If the popup is closed: echo `--remove ITEM` args for any leftover popup
# items so the caller can splice them into the rebuild call, return 0.
# Usage:
#   removes=$(popup_toggle_args "$NAME") || exit 0
#   sketchybar $removes --add item ... --set "$NAME" popup.drawing=on
popup_toggle_args() {
  local query
  query=$(sketchybar --query "$1" 2>/dev/null)
  if [[ "$(jq -r '.popup.drawing // "off"' <<< "$query")" == "on" ]]; then
    sketchybar --set "$1" popup.drawing=off
    return 1
  fi
  jq -r '.popup.items // [] | .[] | "--remove \(.)"' <<< "$query"
  return 0
}
