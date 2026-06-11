#!/usr/bin/env bash
# Claude Code bell hook.
#
# Emits a terminal BEL via the terminalSequence hook field - tmux's
# monitor-bell + alert-bell hook routes that BEL into a clickable macOS
# notification (see tmux.conf and hammerspoon/init.lua). Before emitting,
# it stashes the page kind and reason on the current tmux pane as options
# @claude_bell_kind / @claude_bell_msg, so the notification can show *why*
# Claude paged (permission prompt or idle wait) rather than a generic
# "tmux: <session>" line.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bell.sh --event <notification|idle>

Claude Code hook script. Reads the hook JSON payload on stdin, records the
page kind and reason on the current tmux pane (options @claude_bell_kind and
@claude_bell_msg), and prints a terminalSequence BEL for Claude Code to emit.

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

# Both events render with the same Hammerspoon appearance ("Claude needs you"
# plus sound) - they differ only in where MSG comes from - so the kind is
# always "notification" here.
KIND="notification"

# Stash kind/reason on the belling pane for the tmux alert-bell hook to read.
# The alert-bell hook unsets both options after consuming them (see
# tmux.conf), so the metadata is one-shot and a later plain bell in the same
# pane renders as a plain bell again. Failures here must not suppress the
# BEL, hence `|| true`.
if [[ -n "${TMUX:-}" && -n "${TMUX_PANE:-}" ]]; then
  tmux set-option -p -t "$TMUX_PANE" @claude_bell_kind "$KIND" 2>/dev/null || true
  tmux set-option -p -t "$TMUX_PANE" @claude_bell_msg "$MSG" 2>/dev/null || true
fi

# Print the terminalSequence payload: a single BEL. jq escapes the control
# byte to a valid \uXXXX sequence so the JSON is well-formed.
printf '\007' | jq -Rsc '{terminalSequence: .}'
