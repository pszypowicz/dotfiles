#!/usr/bin/env bash
# Claude Code hook: remember how much background work (subagents and shell
# commands) a session has in flight, so bell.sh can hold the idle page while
# it runs.
#
# Reads the hook JSON payload on stdin. The Stop payload carries
# background_tasks, the task registry's own view of in-flight work; the number
# of entries typed "subagent" or "shell" goes to a per-session state file that
# bell.sh reads before paging. Both kinds wake the main thread when they
# finish, so the user has nothing to act on until then. A long-lived shell
# command (a dev server started in the background) holds the page for as long
# as it runs. The registry drops killed agents too, which
# SubagentStart/SubagentStop pairs do not (SubagentStop never fires for an
# agent stopped via TaskStop or session exit). UserPromptSubmit clears the
# file, covering turns interrupted before their Stop hook - no Stop fires
# then. SessionEnd removes it.
#
# A Stop hook that exits non-zero can keep Claude from ending its turn, so
# every path here exits 0 and prints nothing.
set -uo pipefail

usage() {
  cat <<'EOF'
Usage: agents-in-flight.sh --event <stop|prompt|end>

Claude Code hook script. Reads the hook JSON payload on stdin and maintains
a per-session count of background subagents and shell commands under
${XDG_STATE_HOME:-~/.local/state}/claude-pager/<session_id>.

Options:
  --event <kind>   Hook event kind. Required. One of:
                     stop     count "subagent" and "shell" entries in
                              .background_tasks and write the count
                              (wire to Stop)
                     prompt   clear the count (wire to UserPromptSubmit)
                     end      remove the state file (wire to SessionEnd)
  -h, --help       Show this help and exit.

Example:
  agents-in-flight.sh --event stop   # wired from settings.json hooks
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
      echo "agents-in-flight.sh: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$EVENT" in
  stop|prompt|end) ;;
  "")
    echo "agents-in-flight.sh: --event is required" >&2
    exit 2
    ;;
  *)
    echo "agents-in-flight.sh: invalid --event: $EVENT (expected stop|prompt|end)" >&2
    exit 2
    ;;
esac

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/claude-pager"

PAYLOAD="$(cat)"

# Stop fires on the main thread only (subagents get SubagentStop), but keep
# agent-scoped payloads from ever touching the session's file.
AGENT_ID="$(printf '%s' "$PAYLOAD" | jq -r '.agent_id // empty' 2>/dev/null)"
[[ -z "$AGENT_ID" ]] || exit 0

# session_id is a UUID; anything else must not become a path under STATE_DIR.
SESSION_ID="$(printf '%s' "$PAYLOAD" | jq -r '.session_id // empty' 2>/dev/null)"
[[ "$SESSION_ID" =~ ^[A-Za-z0-9_-]+$ ]] || exit 0
STATE_FILE="$STATE_DIR/$SESSION_ID"

case "$EVENT" in
  stop)
    COUNT="$(printf '%s' "$PAYLOAD" \
      | jq -r '[.background_tasks[]? | select(.type == "subagent" or .type == "shell")] | length' 2>/dev/null)"
    [[ "$COUNT" =~ ^[0-9]+$ ]] || exit 0
    mkdir -p "$STATE_DIR" 2>/dev/null && printf '%s\n' "$COUNT" > "$STATE_FILE" 2>/dev/null
    # Sessions that die without SessionEnd leave their file behind.
    find "$STATE_DIR" -type f -mtime +2 -delete 2>/dev/null
    ;;
  prompt|end)
    rm -f "$STATE_FILE" 2>/dev/null
    ;;
esac

exit 0
