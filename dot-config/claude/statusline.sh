#!/usr/bin/env bash
# Claude Code statusLine command
# Receives JSON on stdin, writes rate limit cache for SketchyBar,
# and outputs a terminal-friendly status string to stdout.

CACHE_DIR="$HOME/.cache/claude"
CACHE_FILE="$CACHE_DIR/rate-limits.json"

INPUT=$(cat)

MODEL=$(echo "$INPUT" | jq -r '.model.display_name // "Claude"')
RATE_LIMITS=$(echo "$INPUT" | jq '.rate_limits // empty')

if [[ -n "$RATE_LIMITS" ]]; then
  mkdir -p "$CACHE_DIR"
  TMPFILE=$(mktemp "$CACHE_DIR/.rate-limits.XXXXXX")
  echo "$INPUT" | jq -c '{
    timestamp: now,
    five_hour: .rate_limits.five_hour,
    seven_day: .rate_limits.seven_day
  }' > "$TMPFILE" && mv "$TMPFILE" "$CACHE_FILE"

  FIVE=$(echo "$RATE_LIMITS" | jq -r '.five_hour.used_percentage // empty')
  SEVEN=$(echo "$RATE_LIMITS" | jq -r '.seven_day.used_percentage // empty')
  printf '%s | 5h:%s%% 7d:%s%%' "$MODEL" "${FIVE:-?}" "${SEVEN:-?}"
else
  printf '%s' "$MODEL"
fi
