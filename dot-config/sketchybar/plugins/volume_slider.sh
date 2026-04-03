#!/usr/bin/env bash

# Called when user clicks/drags the volume slider
if [[ "$SENDER" == "mouse.clicked" ]]; then
  hs -c "hs.audiodevice.defaultOutputDevice():setOutputVolume($PERCENTAGE)"
fi
