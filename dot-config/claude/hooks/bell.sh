#!/usr/bin/env bash
# Claude Code page hook.
#
# Reads the hook JSON payload on stdin and pages the user via Hammerspoon's
# claudePage (hammerspoon/init.lua), which posts a clickable macOS
# notification that jumps to the tmux session/window where Claude is
# waiting. Also emits a terminal BEL via the terminalSequence hook field,
# purely so Ghostty bounces the Dock while unfocused (bell-features
# `attention`); tmux forwards bells to attached clients out of the box
# (monitor-bell on / bell-action any are the defaults), so the BEL needs no
# tmux configuration and carries no information.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bell.sh --event <notification|idle>

Claude Code hook script. Reads the hook JSON payload on stdin, pages the
user via Hammerspoon's claudePage (a clickable macOS notification targeting
the current tmux session/window), and prints a terminalSequence BEL for
Claude Code to emit so Ghostty bounces the Dock.

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

# Page through Hammerspoon. Every failure path degrades to the bare BEL
# (Dock bounce only): outside tmux, hs CLI absent, Hammerspoon down. Lua
# long-brackets [==[...]==] absorb quotes/spaces/newlines in the values
# without shell-level escaping; the one sequence that would close a bracket
# early is stripped from the free-text message. The hs call runs in the
# background so a busy Hammerspoon (e.g. a blocking popup menu) can't stall
# the hook past its timeout or delay the BEL.
if [[ -n "${TMUX:-}" && -n "${TMUX_PANE:-}" ]] && command -v hs >/dev/null; then
  SESSION="$(tmux display-message -p -t "$TMUX_PANE" '#{session_name}' 2>/dev/null || true)"
  WINDOW="$(tmux display-message -p -t "$TMUX_PANE" '#{window_index}' 2>/dev/null || true)"
  if [[ -z "$MSG" ]]; then
    MSG="$(tmux display-message -p -t "$TMUX_PANE" '#{pane_title}' 2>/dev/null || true)"
  fi
  if [[ -n "$SESSION" && -n "$WINDOW" ]]; then
    MSG="${MSG//]==]/}"
    hs -c "claudePage([==[$SESSION]==], [==[$WINDOW]==], [==[$MSG]==])" >/dev/null 2>&1 </dev/null &
  fi
fi

# Print the terminalSequence payload: a single BEL. jq escapes the control
# byte to a valid \uXXXX sequence so the JSON is well-formed.
printf '\007' | jq -Rsc '{terminalSequence: .}'
