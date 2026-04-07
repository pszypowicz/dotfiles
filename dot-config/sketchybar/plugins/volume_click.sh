#!/usr/bin/env bash

source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/icons.sh"
source "$CONFIG_DIR/utils.sh"

show_slider() {
  cleanup_popup volume

  local vol
  vol=$(osascript -e 'output volume of (get volume settings)')

  if [[ "$vol" == "missing value" ]]; then
    sketchybar \
      --add item volume.fixed popup.volume \
      --set volume.fixed \
        label="Fixed volume" \
        icon="$VOLUME_HIGH" \
        icon.color="$WHITE" \
        label.color="$WHITE" \
        background.color="$TRANSPARENT" \
        background.height=30 \
      --set volume popup.drawing=on
    return
  fi

  sketchybar \
    --add slider volume.slider popup.volume \
    --set volume.slider \
      slider.percentage="$vol" \
      slider.highlight_color="$WHITE" \
      slider.background.height=5 \
      slider.background.corner_radius=3 \
      slider.background.color="$TRANSPARENT_BLACK" \
      slider.knob="$SLIDER_KNOB" \
      slider.knob.color="$WHITE" \
      slider.width=150 \
      script="$CONFIG_DIR/plugins/volume_slider.sh" \
    --subscribe volume.slider mouse.clicked \
    --set volume popup.drawing=on
}

show_devices() {
  cleanup_popup volume

  local devices current
  devices=$(hs -c '
    local devs = hs.audiodevice.allOutputDevices()
    for _, d in ipairs(devs) do print(d:name()) end
  ' 2>/dev/null)
  current=$(hs -c 'print(hs.audiodevice.defaultOutputDevice():name())' 2>/dev/null)

  local args=()
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    local slug
    slug=$(slugify "$name")
    local item="volume.device.$slug"
    local escaped
    escaped=$(printf '%s' "$name" | sed "s/'/'\\\\''/g")

    local icon=" " color="$ORANGE"
    if [[ "$name" == "$current" ]]; then
      icon="$CHECK"
      color="$WHITE"
    fi

    args+=(
      --add item "$item" popup.volume
      --set "$item"
        label="$name"
        icon="$icon"
        icon.width=20
        icon.color="$color"
        label.color="$color"
        background.color="$TRANSPARENT"
        background.height=30
        background.drawing=on
        click_script="hs -c \"hs.audiodevice.findOutputByName('$escaped'):setDefaultOutputDevice()\"; sketchybar --set volume popup.drawing=off"
    )
  done <<< "$devices"

  args+=(--set volume popup.drawing=on)
  sketchybar "${args[@]}"
}

if [[ "$BUTTON" == "right" ]]; then
  show_devices
else
  show_slider
fi
