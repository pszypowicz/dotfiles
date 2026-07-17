#!/usr/bin/env bash

source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/icons.sh"

CACHE_FILE="$HOME/.cache/claude/rate-limits.json"
STATE_FILE="$HOME/.cache/claude/usage-poll.json"
FETCHER="$HOME/.config/claude/fetch-usage.sh"
FRESH_THRESHOLD=120 # statusline refreshes every 60s; older means no live session
AGE_WARN=900        # background polls run every ~5 min; older means polling is failing

# Close popup when the mouse leaves the bar.
if [[ "$SENDER" == "mouse.exited.global" ]]; then
  sketchybar --set "$NAME" popup.drawing=off
  exit 0
fi

NOW=$(date +%s)

# Keep the cache and token state fresh; the fetcher throttles itself
# (60s credential checks, 5-min network polls, error backoff), so firing
# it on every tick is fine.
[[ -x "$FETCHER" ]] && "$FETCHER" >/dev/null 2>&1 &

# ── Row formatters ─────────────────────────────────────────────────

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

# Format a timestamp as a short "when" string.
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
    if (( days_away < 7 && days_away > -7 )); then
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

# ── OAuth token row (from the poller's state file) ─────────────────

TOKEN_EXP=0
[[ -f "$STATE_FILE" ]] && TOKEN_EXP=$(jq -r '.token_expires_at // 0' "$STATE_FILE" 2>/dev/null)
TOKEN_EXP=${TOKEN_EXP%.*}

TOKEN_EXPIRED=0
if (( TOKEN_EXP == 0 )); then
  TOKEN_ROW="unknown"
  TOKEN_COLOR="$DIM_WHITE"
elif (( TOKEN_EXP < NOW )); then
  TOKEN_EXPIRED=1
  TOKEN_ROW=$(printf "%-10s %-9s %s" \
    "expired" \
    "$(format_age $(( NOW - TOKEN_EXP )))" \
    "$(format_reset_at "$TOKEN_EXP")")
  TOKEN_COLOR="$ORANGE"
else
  TOKEN_ROW=$(printf "%-10s %-9s %s" \
    "valid" \
    "$(format_remaining $(( TOKEN_EXP - NOW )))" \
    "$(format_reset_at "$TOKEN_EXP")")
  TOKEN_COLOR="$WHITE"
fi

# ── Cache ───────────────────────────────────────────────────────────

no_data() { # <age-row message>
  sketchybar --set "$NAME" icon="$CLAUDE" icon.color="$DIM_WHITE" \
    label="--" label.color="$DIM_WHITE" \
    --set claude.fivehour label="no data" label.color="$DIM_WHITE" \
    --set claude.sevenday label="no data" label.color="$DIM_WHITE" \
    --set claude.token label="$TOKEN_ROW" label.color="$TOKEN_COLOR" \
    --set claude.age label="$1" label.color="$DIM_WHITE"
  exit 0
}

if (( TOKEN_EXPIRED )); then
  AUTH_MSG="token expired - start claude code to refresh"
fi

[[ ! -f "$CACHE_FILE" ]] && no_data "${AUTH_MSG:-waiting for first poll}"

CACHE=$(cat "$CACHE_FILE")
CACHE_TS=$(echo "$CACHE" | jq -r '.timestamp // 0')
AGE=$(( NOW - ${CACHE_TS%.*} ))
SOURCE=$(echo "$CACHE" | jq -r '.source // "session"')

FIVE_PCT=$(echo "$CACHE" | jq -r '.five_hour.used_percentage // empty')
SEVEN_PCT=$(echo "$CACHE" | jq -r '.seven_day.used_percentage // empty')
FIVE_RESETS=$(echo "$CACHE" | jq -r '.five_hour.resets_at // empty')
SEVEN_RESETS=$(echo "$CACHE" | jq -r '.seven_day.resets_at // empty')

[[ -z "$FIVE_PCT" && -z "$SEVEN_PCT" ]] && no_data "${AUTH_MSG:-cache has no rate limit data}"

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

AGE_LABEL="updated $(format_age "$AGE") ($SOURCE)"
AGE_COLOR="$DIM_WHITE"
(( AGE > AGE_WARN )) && AGE_COLOR="$YELLOW"

LABEL_COLOR="$ICON_COLOR"

# Stale data stays on the bar; "--" is reserved for a dead token, which
# only a Claude Code start on this machine can refresh.
if (( TOKEN_EXPIRED )) && (( AGE > FRESH_THRESHOLD )); then
  LABEL="--"
  ICON_COLOR="$DIM_WHITE"
  LABEL_COLOR="$DIM_WHITE"
  AGE_LABEL="$AUTH_MSG"
  AGE_COLOR="$ORANGE"
fi

sketchybar --set "$NAME" \
  icon="$CLAUDE" \
  icon.color="$ICON_COLOR" \
  label="$LABEL" \
  label.color="$LABEL_COLOR" \
  --set claude.fivehour label="$FIVE_ROW" label.color="$FIVE_COLOR" \
  --set claude.sevenday label="$SEVEN_ROW" label.color="$SEVEN_COLOR" \
  --set claude.token label="$TOKEN_ROW" label.color="$TOKEN_COLOR" \
  --set claude.age label="$AGE_LABEL" label.color="$AGE_COLOR"
