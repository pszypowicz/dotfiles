#!/usr/bin/env bash
# Claude Code bell hook.
#
# Emits a terminal BEL via the terminalSequence hook field - tmux's
# monitor-bell + alert-bell hook routes that BEL into a clickable macOS
# notification (see tmux.conf and hammerspoon/init.lua). Before emitting,
# it stashes the page kind and reason on the current tmux pane as options
# @claude_bell_kind / @claude_bell_msg, so the notification can show *why*
# Claude paged (permission prompt, idle, turn finished) rather than a
# generic "tmux: <session>" line.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: bell.sh --event <notification|stop>

Claude Code hook script. Reads the hook JSON payload on stdin, records the
page kind and reason on the current tmux pane (options @claude_bell_kind and
@claude_bell_msg), and prints a terminalSequence BEL for Claude Code to emit.

Options:
  --event <kind>   Hook event kind. One of: notification, stop. Required.
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
  notification|stop) ;;
  "")
    echo "bell.sh: --event is required" >&2
    exit 2
    ;;
  *)
    echo "bell.sh: invalid --event: $EVENT (expected notification|stop)" >&2
    exit 2
    ;;
esac

PAYLOAD="$(cat)"

# Only the Notification event carries a human-readable reason; Stop does not.
MSG=""
if [[ "$EVENT" == "notification" ]]; then
  MSG="$(printf '%s' "$PAYLOAD" | jq -r '.message // empty')"
fi

# Stash kind/reason on the belling pane for the tmux alert-bell hook to read.
# Pane options persist, so each Claude bell overwrites the previous; a plain
# non-Claude bell in the same pane may briefly show a stale reason, which is
# cosmetic. Failures here must not suppress the BEL, hence `|| true`.
if [[ -n "${TMUX:-}" && -n "${TMUX_PANE:-}" ]]; then
  tmux set-option -p -t "$TMUX_PANE" @claude_bell_kind "$EVENT" 2>/dev/null || true
  tmux set-option -p -t "$TMUX_PANE" @claude_bell_msg "$MSG" 2>/dev/null || true
fi

# Print the terminalSequence payload: a single BEL. jq escapes the control
# byte to a valid \uXXXX sequence so the JSON is well-formed.
printf '\007' | jq -Rsc '{terminalSequence: .}'
