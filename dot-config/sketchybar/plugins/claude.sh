#!/usr/bin/env bash

source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/icons.sh"

CACHE_FILE="$HOME/.cache/claude/rate-limits.json"
STALE_THRESHOLD=300 # 5 minutes

inactive() {
  sketchybar --set "$NAME" icon="$CLAUDE" icon.color="$DIM_WHITE" \
    label="--" label.color="$DIM_WHITE"
  exit 0
}

# No cache file
[[ ! -f "$CACHE_FILE" ]] && inactive

CACHE=$(cat "$CACHE_FILE")
CACHE_TS=$(echo "$CACHE" | jq -r '.timestamp // 0')
NOW=$(date +%s)
AGE=$(( NOW - ${CACHE_TS%.*} ))

# Stale data
(( AGE > STALE_THRESHOLD )) && inactive

FIVE_PCT=$(echo "$CACHE" | jq -r '.five_hour.used_percentage // empty')
SEVEN_PCT=$(echo "$CACHE" | jq -r '.seven_day.used_percentage // empty')
FIVE_RESETS=$(echo "$CACHE" | jq -r '.five_hour.resets_at // empty')

# No rate limit data
[[ -z "$FIVE_PCT" && -z "$SEVEN_PCT" ]] && inactive

# Color based on percentage
color_for_pct() {
  local pct="${1%.*}"
  if (( pct >= 90 )); then
    echo "$RED"
  elif (( pct >= 80 )); then
    echo "$ORANGE"
  elif (( pct >= 60 )); then
    echo "$YELLOW"
  else
    echo "$WHITE"
  fi
}

FIVE_INT="${FIVE_PCT%.*}"
SEVEN_INT="${SEVEN_PCT%.*}"

FIVE_COLOR=$(color_for_pct "$FIVE_PCT")
SEVEN_COLOR=$(color_for_pct "$SEVEN_PCT")

# Icon color = the more urgent of the two
if (( FIVE_INT >= SEVEN_INT )); then
  ICON_COLOR="$FIVE_COLOR"
else
  ICON_COLOR="$SEVEN_COLOR"
fi

# Format label
# Normal:  "24% 41%"  (5h then 7d)
# High 5h: "82% 1h23m" (countdown replaces 7d%)

COUNTDOWN=""
if (( FIVE_INT >= 80 )) && [[ -n "$FIVE_RESETS" ]]; then
  REMAINING=$(( ${FIVE_RESETS%.*} - NOW ))
  if (( REMAINING > 0 )); then
    HOURS=$(( REMAINING / 3600 ))
    MINS=$(( (REMAINING % 3600) / 60 ))
    if (( HOURS > 0 )); then
      COUNTDOWN="${HOURS}h${MINS}m"
    else
      COUNTDOWN="${MINS}m"
    fi
  else
    COUNTDOWN="now"
  fi
fi

if [[ -n "$COUNTDOWN" ]]; then
  LABEL="$CLOCK ${FIVE_INT}% ${COUNTDOWN}"
  if (( SEVEN_INT >= 80 )); then
    LABEL+=" $CALENDAR ${SEVEN_INT}%"
  fi
else
  LABEL="$CLOCK ${FIVE_INT}% $CALENDAR ${SEVEN_INT}%"
fi

sketchybar --set "$NAME" \
  icon="$CLAUDE" \
  icon.color="$ICON_COLOR" \
  label="$LABEL" \
  label.color="$ICON_COLOR"
