#!/usr/bin/env bash
# Claude Code page hook.
#
# Reads the hook JSON payload on stdin and pages the user with a macOS
# notification (osascript) naming the tmux session/window where Claude is
# waiting, suppressed when that window is already the current window of an
# attached session. Also emits a terminal BEL via the terminalSequence hook
# field, purely so Ghostty bounces the Dock while unfocused (bell-features
# `attention`); tmux forwards bells to attached clients out of the box
# (monitor-bell on / bell-action any are the defaults), so the BEL needs no
# tmux configuration and carries no information.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bell.sh --event <notification|idle>

Claude Code hook script. Reads the hook JSON payload on stdin, pages the
user with a macOS notification naming the current tmux session/window, and
prints a terminalSequence BEL for Claude Code to emit so Ghostty bounces
the Dock.

Options:
  --event <kind>   Hook event kind. One of: notification, idle. Required.
  -h, --help       Show this help and exit.

Example:
  bell.sh --event notification   # wired from settings.json hooks
EOF
}

EVENT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --event)
      EVENT="${2:-}"
      shift
      [[ $# -gt 0 ]] && shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "bell.sh: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$EVENT" in
  notification|idle) ;;
  "")
    echo "bell.sh: --event is required" >&2
    exit 2
    ;;
  *)
    echo "bell.sh: invalid --event: $EVENT (expected notification|idle)" >&2
    exit 2
    ;;
esac

PAYLOAD="$(cat)"

MSG="$(printf '%s' "$PAYLOAD" | jq -r '.message // empty')"

# Summarize text with the on-device Apple Intelligence model via
# afm-summarize (brew "pszypowicz/tap/afm-summarize"). Prints nothing on any
# failure - tool not installed, model unavailable, guardrail refusal,
# timeout - so callers degrade to clipping instead of losing the page.
summarize() {
  command -v afm-summarize >/dev/null || return 1
  command -v timeout >/dev/null || return 1
  printf '%s' "$1" \
    | timeout 10 afm-summarize --max-chars 150 2>/dev/null \
    | jq -Rrs 'gsub("\\s+"; " ") | .[0:150]'
}

# For idle pages, prefer Claude's last reply over the generic "waiting for
# your input" message - with several sessions running, it tells which one is
# worth visiting first. Replies that fit the ~150-char notification budget
# pass through untouched; longer ones are summarized on-device. The page
# must still fire when summarization is impossible, so every failure path
# falls back to a bare clip (and ultimately to the payload .message).
if [[ "$EVENT" == "idle" ]]; then
  TRANSCRIPT="$(printf '%s' "$PAYLOAD" | jq -r '.transcript_path // empty')"
  if [[ -n "$TRANSCRIPT" && -f "$TRANSCRIPT" ]]; then
    EXCERPT="$(tail -n 200 "$TRANSCRIPT" \
      | jq -rs '[.[] | select(.type=="assistant") | .message.content[]? | select(.type=="text") | .text]
                | last // empty | gsub("\\s+"; " ") | .[0:4000]' 2>/dev/null || true)"
    if [[ -n "$EXCERPT" ]]; then
      if (( ${#EXCERPT} <= 150 )); then
        MSG="$EXCERPT"
      else
        MSG="${EXCERPT:0:150}"
        SUMMARY="$(summarize "$EXCERPT" || true)"
        [[ -n "$SUMMARY" ]] && MSG="$SUMMARY"
      fi
    fi
  fi
fi

# Post the page as a macOS notification via osascript (attributed to Script
# Editor, which must be allowed in System Settings > Notifications).
# Suppress it when the pane's window is the current window of an attached
# session: the user then sees Claude waiting whenever they look at the
# terminal, and the BEL below bounces the Dock while Ghostty is unfocused.
# macOS-level focus is invisible to a shell hook, so attached+active-window
# is the closest available approximation of "the user is looking at it" -
# only background tmux windows and detached sessions page. Values reach
# AppleScript as argv, so quotes/spaces/newlines in them need no escaping.
# Every failure path degrades to the bare BEL, and osascript runs in the
# background so a slow post can't stall the hook past its timeout or delay
# the BEL.
#
# PAGE_SOUND must be a basename from /System/Library/Sounds (or
# ~/Library/Sounds); Funk.aiff is the system's default alert sound (shown
# as "Boop" in Sound settings). Empty means silent.
PAGE_SOUND="Funk"
if [[ -n "${TMUX:-}" && -n "${TMUX_PANE:-}" ]]; then
  INFO="$(tmux display-message -p -t "$TMUX_PANE" '#{window_active} #{session_attached} #{window_index} #{session_name}' 2>/dev/null || true)"
  read -r ACTIVE ATTACHED WINDOW SESSION <<<"$INFO"
  if [[ -n "$SESSION" && -n "$WINDOW" ]] && ! [[ "$ACTIVE" == "1" && "$ATTACHED" != "0" ]]; then
    if [[ -z "$MSG" ]]; then
      MSG="$(tmux display-message -p -t "$TMUX_PANE" '#{pane_title}' 2>/dev/null || true)"
    fi
    osascript - "$SESSION / window $WINDOW" "$MSG" "$PAGE_SOUND" >/dev/null 2>&1 <<'EOF' &
on run argv
    display notification (item 2 of argv) with title "Claude needs you" subtitle (item 1 of argv) sound name (item 3 of argv)
end run
EOF
  fi
fi

# Print the terminalSequence payload: a single BEL. jq escapes the control
# byte to a valid \uXXXX sequence so the JSON is well-formed.
printf '\007' | jq -Rsc '{terminalSequence: .}'
