#!/usr/bin/env bash

source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/icons.sh"
source "$CONFIG_DIR/utils.sh"

if [[ "$BUTTON" == "right" ]]; then
  # Get layouts from Hammerspoon
  current=$(hs -c 'print(hs.keycodes.currentLayout())' 2>/dev/null)

  args=( $(popup_remove_args input_source) )
  while IFS= read -r layout; do
    [[ -z "$layout" ]] && continue
    slug=$(slugify "$layout")
    item="input_source.lang.$slug"
    escaped=$(printf '%s' "$layout" | sed "s/'/'\\\\''/g")

    icon=" " color="$ORANGE"
    if [[ "$layout" == "$current" ]]; then
      icon="$CHECK"
      color="$WHITE"
    fi

    args+=(
      --add item "$item" popup.input_source
      --set "$item"
        label="$layout"
        icon="$icon"
        icon.width=20
        icon.color="$color"
        label.color="$color"
        background.color="$TRANSPARENT"
        background.height=30
        background.drawing=on
        click_script="hs -c \"hs.keycodes.setLayout('$escaped')\"; sketchybar --set input_source popup.drawing=off"
    )
  done < <(hs -c 'for _, s in ipairs(hs.keycodes.layouts()) do print(s) end' 2>/dev/null)

  args+=(--set input_source popup.drawing=on)
  sketchybar "${args[@]}"
else
  hs -c "toggleKeyboardViewer()"
fi
