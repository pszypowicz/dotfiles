#!/usr/bin/env bash

source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/icons.sh"

CACHE_FILE="$HOME/.cache/claude/rate-limits.json"
STALE_THRESHOLD=300 # 5 minutes

# Close popup when the mouse leaves the bar.
if [[ "$SENDER" == "mouse.exited.global" ]]; then
  sketchybar --set "$NAME" popup.drawing=off
  exit 0
fi

inactive() {
  sketchybar --set "$NAME" icon="$CLAUDE" icon.color="$DIM_WHITE" \
    label="--" label.color="$DIM_WHITE" \
    --set claude.fivehour label="no data" label.color="$DIM_WHITE" \
    --set claude.sevenday label="no data" label.color="$DIM_WHITE" \
    --set claude.age label="statusline has not written a cache yet" label.color="$DIM_WHITE"
  exit 0
}

[[ ! -f "$CACHE_FILE" ]] && inactive

CACHE=$(cat "$CACHE_FILE")
CACHE_TS=$(echo "$CACHE" | jq -r '.timestamp // 0')
NOW=$(date +%s)
AGE=$(( NOW - ${CACHE_TS%.*} ))

(( AGE > STALE_THRESHOLD )) && inactive

FIVE_PCT=$(echo "$CACHE" | jq -r '.five_hour.used_percentage // empty')
SEVEN_PCT=$(echo "$CACHE" | jq -r '.seven_day.used_percentage // empty')
FIVE_RESETS=$(echo "$CACHE" | jq -r '.five_hour.resets_at // empty')
SEVEN_RESETS=$(echo "$CACHE" | jq -r '.seven_day.resets_at // empty')

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

# Format bar label
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

# ── Popup row formatters ───────────────────────────────────────────

format_remaining() {
  local secs="$1"
  if (( secs <= 0 )); then
    echo "now"
    return
  fi
  local d=$((secs / 86400))
  local h=$(( (secs % 86400) / 3600 ))
  local m=$(( (secs % 3600) / 60 ))
  if (( d > 0 )); then
    echo "${d}d ${h}h"
  elif (( h > 0 )); then
    echo "${h}h ${m}m"
  else
    echo "${m}m"
  fi
}

# Format a reset timestamp as a short "when" string.
# Today → "today HH:MM"; tomorrow → "tom   HH:MM" (padded so it aligns
# with "today"); within a week → "Mon   HH:MM"; beyond → "Apr 29 HH:MM".
format_reset_at() {
  local ts="$1"
  [[ -z "$ts" ]] && { echo "?"; return; }
  local reset_day today tomorrow
  reset_day=$(date -r "$ts" +%Y-%m-%d)
  today=$(date +%Y-%m-%d)
  tomorrow=$(date -v+1d +%Y-%m-%d)
  if [[ "$reset_day" == "$today" ]]; then
    date -r "$ts" "+today %H:%M"
  elif [[ "$reset_day" == "$tomorrow" ]]; then
    date -r "$ts" "+tom   %H:%M"
  else
    local days_away=$(( (ts - NOW) / 86400 ))
    if (( days_away < 7 )); then
      date -r "$ts" "+%a   %H:%M"
    else
      date -r "$ts" "+%b %d %H:%M"
    fi
  fi
}

format_age() {
  local secs="$1"
  if (( secs < 60 )); then
    echo "${secs}s ago"
  elif (( secs < 3600 )); then
    echo "$(( secs / 60 ))m ago"
  else
    echo "$(( secs / 3600 ))h $(( (secs % 3600) / 60 ))m ago"
  fi
}

FIVE_RESETS_I="${FIVE_RESETS%.*}"
SEVEN_RESETS_I="${SEVEN_RESETS%.*}"

FIVE_REMAIN=0
SEVEN_REMAIN=0
[[ -n "$FIVE_RESETS_I" ]] && FIVE_REMAIN=$(( FIVE_RESETS_I - NOW ))
[[ -n "$SEVEN_RESETS_I" ]] && SEVEN_REMAIN=$(( SEVEN_RESETS_I - NOW ))

# Column-aligned rows. Monospace alignment relies on the CaskaydiaCove
# Nerd Font set as label.font in sketchybarrc defaults.
#   col 1 (used %):   up to "100% used"   → width 10
#   col 2 (in X):     up to "23h 59m"     → width  9
#   col 3 (resets at): last column, no padding
FIVE_ROW=$(printf "%-10s %-9s %s" \
  "${FIVE_INT}% used" \
  "$(format_remaining "$FIVE_REMAIN")" \
  "$(format_reset_at "$FIVE_RESETS_I")")
SEVEN_ROW=$(printf "%-10s %-9s %s" \
  "${SEVEN_INT}% used" \
  "$(format_remaining "$SEVEN_REMAIN")" \
  "$(format_reset_at "$SEVEN_RESETS_I")")

AGE_LABEL="updated $(format_age "$AGE")"
AGE_COLOR="$DIM_WHITE"
(( AGE > 120 )) && AGE_COLOR="$YELLOW"

sketchybar --set "$NAME" \
  icon="$CLAUDE" \
  icon.color="$ICON_COLOR" \
  label="$LABEL" \
  label.color="$ICON_COLOR" \
  --set claude.fivehour label="$FIVE_ROW" label.color="$FIVE_COLOR" \
  --set claude.sevenday label="$SEVEN_ROW" label.color="$SEVEN_COLOR" \
  --set claude.age label="$AGE_LABEL" label.color="$AGE_COLOR"
