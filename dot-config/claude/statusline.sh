#!/usr/bin/env bash
# Claude Code statusLine command
# Receives JSON on stdin, writes rate limit cache for SketchyBar, and publishes
# the active model as a tmux pane option for the window-name format.
# No stdout - usage is shown via the SketchyBar widget only.

CACHE_DIR="$HOME/.cache/claude"
CACHE_FILE="$CACHE_DIR/rate-limits.json"

INPUT=$(cat)

RATE_LIMITS=$(echo "$INPUT" | jq '.rate_limits // empty')

if [[ -n "$RATE_LIMITS" ]]; then
  mkdir -p "$CACHE_DIR"
  TMPFILE=$(mktemp "$CACHE_DIR/.rate-limits.XXXXXX")
  echo "$INPUT" | jq -c '{
    timestamp: now,
    source: "session",
    five_hour: .rate_limits.five_hour,
    seven_day: .rate_limits.seven_day
  }' > "$TMPFILE" && mv "$TMPFILE" "$CACHE_FILE"
fi

# The payload's model object always reflects the ACTIVE model, including after
# a mid-session switch. Publish it as a pane-scoped user option; the
# claude.fish wrapper's automatic-rename-format surfaces it in the window name,
# which set-titles carries into the terminal title. The PostModelSwitch hook in
# settings.json pushes the raw model ID the moment a switch happens; this
# refresh then replaces it with the display name.
MODEL=$(echo "$INPUT" | jq -r '.model.display_name // empty')
if [[ -n "$MODEL" && -n "$TMUX_PANE" ]]; then
  tmux set-option -p -t "$TMUX_PANE" @claude_model "$MODEL"
fi
