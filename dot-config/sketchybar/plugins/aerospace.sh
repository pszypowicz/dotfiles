#!/usr/bin/env bash

set -e

workspaces=$(aerospace list-workspaces --all --format '%{workspace}|%{workspace-is-visible}|%{workspace-is-focused}|%{monitor-id}|%{monitor-appkit-nsscreen-screens-id}')

options=()

for workspace in $workspaces; do
    IFS='|' read -r sid visible focused monitor_id screen_id <<< "$workspace"

    if [[ "$visible" == "true" ]]; then
        display=$screen_id
    else
        display=0
    fi

    if [[ "$focused" == "true" ]]; then
        highlight=on
    else
        highlight=off
    fi
    options+=("--set" "space.$sid" "display=$display" "label.highlight=$highlight")
done

sketchybar "${options[@]}"
