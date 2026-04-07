#!/usr/bin/env bash

shopt -s extglob

slugify() {
  local s="${1,,}"
  s="${s//[^a-z0-9]/_}"
  s="${s//+(_)/_}"
  s="${s#_}"; s="${s%_}"
  echo "$s"
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
