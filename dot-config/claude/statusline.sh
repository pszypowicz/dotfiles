#!/usr/bin/env bash
# Claude Code statusLine command
# Receives JSON on stdin, writes rate limit cache for SketchyBar.
# No stdout -- usage is shown via the SketchyBar widget only.

CACHE_DIR="$HOME/.cache/claude"
CACHE_FILE="$CACHE_DIR/rate-limits.json"

INPUT=$(cat)

RATE_LIMITS=$(echo "$INPUT" | jq '.rate_limits // empty')

if [[ -n "$RATE_LIMITS" ]]; then
  mkdir -p "$CACHE_DIR"
  TMPFILE=$(mktemp "$CACHE_DIR/.rate-limits.XXXXXX")
  echo "$INPUT" | jq -c '{
    timestamp: now,
    five_hour: .rate_limits.five_hour,
    seven_day: .rate_limits.seven_day,
    effort: .effort.level,
    thinking: .thinking.enabled
  }' > "$TMPFILE" && mv "$TMPFILE" "$CACHE_FILE"
fi
