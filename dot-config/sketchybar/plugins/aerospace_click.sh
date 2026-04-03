#!/usr/bin/env bash

source "$CONFIG_DIR/icons.sh"
source "$CONFIG_DIR/colors.sh"

CHECK=󰄬

if [[ "$BUTTON" != "right" ]]; then
  exit 0
fi

# Close any open aerospace popup
items=$(sketchybar --query "$NAME" 2>/dev/null | jq -r '.popup.items // [] | .[]')
while IFS= read -r item; do
  [[ -n "$item" ]] && sketchybar --remove "$item"
done <<< "$items"

visible=$(aerospace list-workspaces --monitor focused --visible 2>/dev/null)

args=()
while IFS= read -r ws; do
  [[ -z "$ws" ]] && continue
  item="$NAME.ws.$ws"
  icon_var="AEROWORKSPACE_$ws"

  # List apps in this workspace
  apps=$(aerospace list-windows --workspace "$ws" --format '%{app-name}' 2>/dev/null | paste -sd ", " -)
  label="${!icon_var}"
  [[ -n "$apps" ]] && label="${!icon_var}  $apps"

  icon=" " color="$ORANGE"
  if [[ "$ws" == "$visible" ]]; then
    icon="$CHECK"
    color="$WHITE"
  fi

  args+=(
    --add item "$item" popup."$NAME"
    --set "$item"
      label="$label"
      icon="$icon"
      icon.width=20
      icon.color="$color"
      label.color="$color"
      background.color=0x00000000
      background.height=30
      background.drawing=on
      click_script="aerospace workspace $ws; sketchybar --set $NAME popup.drawing=off"
  )
done < <(aerospace list-workspaces --monitor focused 2>/dev/null)

args+=(--set "$NAME" popup.drawing=on popup.align=left)
sketchybar "${args[@]}"
