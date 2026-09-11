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

# Publish the project folder, the active model, and the context window fill as
# pane-scoped user options. The automatic-rename-format in tmux.conf surfaces
# them in the window name, which set-titles carries into the terminal title.
if [[ -n "$TMUX_PANE" ]]; then
  # Resuming a session from another directory leaves workspace.project_dir
  # pointing at the launch directory, and the pane working directory follows the
  # launch too. The transcript stays filed under the project that owns the
  # session, so its first recorded working directory names that project.
  TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty')
  PROJECT=""
  if [[ -r "$TRANSCRIPT" ]]; then
    PROJECT=$(head -n 50 "$TRANSCRIPT" | jq -r 'select(.cwd) | .cwd' 2>/dev/null | head -1)
  fi
  if [[ -z "$PROJECT" ]]; then
    PROJECT=$(echo "$INPUT" | jq -r '.workspace.project_dir // .cwd // empty')
  fi

  # tmux builds automatic-rename-format with no session in scope, which leaves
  # #{session_name} empty there. Compare here instead, and blank the folder when
  # it repeats the session name that set-titles-string prints already.
  DIR=""
  if [[ -n "$PROJECT" ]]; then
    DIR=$(basename "$PROJECT")
    if [[ "$DIR" == "$(tmux display-message -p -t "$TMUX_PANE" '#{session_name}')" ]]; then
      DIR=""
    fi
  fi
  tmux set-option -p -t "$TMUX_PANE" @claude_dir "$DIR"

  # The payload's model object always reflects the ACTIVE model, including after
  # a mid-session switch. The PostModelSwitch hook in settings.json pushes the
  # raw model ID the moment a switch happens; this refresh then replaces it with
  # the display name.
  #
  # The display name can carry a trailing variant note in parentheses, such as
  # the context window size. The window name only needs the model, so drop it.
  MODEL=$(echo "$INPUT" | jq -r '.model.display_name // empty | sub(" *\\([^)]*\\)$"; "")')
  if [[ -n "$MODEL" ]]; then
    tmux set-option -p -t "$TMUX_PANE" @claude_model "$MODEL"
  fi

  # The payload reports the window size for every model, so the display name
  # does not have to carry it. Sizes print as "1M" or "200k", and the fill joins
  # them as "C:1M:5%".
  #
  # The percent sign is part of the value. A tmux #{?...} conditional reads a
  # bare "0" as false, which would hide the number on a fresh session. The fill
  # is absent until the first assistant reply sets a token count.
  CONTEXT=$(echo "$INPUT" | jq -r '
    .context_window.context_window_size as $size
    | .context_window.used_percentage as $fill
    | [ (if $size == null then empty
         elif $size >= 1000000 then "C:" + ($size / 1000000 | tostring) + "M"
         elif $size >= 1000 then "C:" + ($size / 1000 | round | tostring) + "k"
         else "C:" + ($size | tostring) end),
        (if $fill == null then empty else ($fill | tostring) + "%" end) ]
    | join(":")')
  tmux set-option -p -t "$TMUX_PANE" @claude_context "$CONTEXT"
fi
