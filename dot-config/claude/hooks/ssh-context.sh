#!/usr/bin/env bash
# Claude Code hook: tell Claude when the user drives the session over ssh or
# mosh, so that its suggestions fit a user who cannot see this machine's
# screen. A localhost URL, `open`, or `pbcopy` reaches the wrong machine then.
#
# over-ssh decides where the user is. In tmux it checks the client that shows
# the pane or is attached to its session, so a session that started at the Mac
# and is reattached over ssh changes with the client. SessionStart adds the note whenever the user is
# remote, because /clear and compaction drop earlier context. UserPromptSubmit
# adds a note only when the answer differs from the previous prompt, which a
# per-session state file records. SessionEnd removes the file.
#
# Every path exits 0. When the check cannot tell (no tmux client is attached
# to the pane's session), the hook prints nothing. At SessionStart it also
# clears the state, so that the next prompt adds the note again.
set -uo pipefail

usage() {
  cat <<'EOF'
Usage: ssh-context.sh --event <start|prompt|end>

Claude Code hook script. Reads the hook JSON payload on stdin and, when the
user is connected over ssh or mosh, prints additionalContext that tells Claude
the user cannot see this machine's screen. Keeps the last answer per session
under ${XDG_STATE_HOME:-~/.local/state}/claude-ssh-context/<session_id>.

Options:
  --event <kind>   Hook event kind. Required. One of:
                     start    add the note when the user is remote, or a
                              correction when the user came back to the
                              machine (wire to SessionStart)
                     prompt   add a note only when the answer changed since
                              the previous prompt (wire to UserPromptSubmit)
                     end      remove the state file (wire to SessionEnd)
  -h, --help       Show this help and exit.

Example:
  ssh-context.sh --event prompt   # wired from settings.json hooks
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
      echo "ssh-context.sh: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

case "$EVENT" in
  start) HOOK_EVENT=SessionStart ;;
  prompt) HOOK_EVENT=UserPromptSubmit ;;
  end) HOOK_EVENT=SessionEnd ;;
  "")
    echo "ssh-context.sh: --event is required" >&2
    exit 2
    ;;
  *)
    echo "ssh-context.sh: invalid --event: $EVENT (expected start|prompt|end)" >&2
    exit 2
    ;;
esac

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/claude-ssh-context"
OVER_SSH="$HOME/.local/bin/over-ssh"

PAYLOAD="$(cat)"

AGENT_ID="$(printf '%s' "$PAYLOAD" | jq -r '.agent_id // empty' 2>/dev/null)"
[[ -z "$AGENT_ID" ]] || exit 0

# session_id is a UUID; anything else must not become a path under STATE_DIR.
SESSION_ID="$(printf '%s' "$PAYLOAD" | jq -r '.session_id // empty' 2>/dev/null)"
[[ "$SESSION_ID" =~ ^[A-Za-z0-9_-]+$ ]] || exit 0
STATE_FILE="$STATE_DIR/$SESSION_ID"

if [[ "$EVENT" == end ]]; then
  rm -f "$STATE_FILE" 2>/dev/null
  exit 0
fi

[[ -x "$OVER_SSH" ]] || exit 0
RC=0
"$OVER_SSH" </dev/null >/dev/null 2>&1 || RC=$?
case "$RC" in
  0) NOW=remote ;;
  1) NOW=local ;;
  *)
    [[ "$EVENT" == start ]] && rm -f "$STATE_FILE" 2>/dev/null
    exit 0
    ;;
esac

PREV="$(cat "$STATE_FILE" 2>/dev/null)"
mkdir -p "$STATE_DIR" 2>/dev/null && printf '%s\n' "$NOW" > "$STATE_FILE" 2>/dev/null
# Sessions that die without SessionEnd leave their file behind. Every run
# rewrites the file, so a live session keeps a fresh one.
find "$STATE_DIR" -type f -mtime +7 -delete 2>/dev/null

HOST="$(hostname -s 2>/dev/null)"
REMOTE_NOTE="The user is connected to this machine (hostname ${HOST:-unknown}) over ssh or mosh and cannot see its screen. Fit suggestions and commands to that:
- A server that listens on localhost here is not reachable from the user's browser. Give them a port forward to run on their own machine, such as \`ssh -L 3000:localhost:3000 <this host>\`, or bind the server to an address their machine can reach.
- \`open\`, browser launches, GUI apps, desktop notifications, and screenshots show on this machine's screen. Give the URL or the file path instead.
- \`pbcopy\` and \`pbpaste\` use this machine's clipboard, not the user's. Put text they need to copy in the reply.
- Touch ID and keychain dialogs that a command raises on this machine show on its screen, where the user cannot answer them."
LOCAL_NOTE="The user is now at this machine's own screen and keyboard. The earlier note about working over ssh no longer applies."

NOTE=""
case "$EVENT:$NOW" in
  start:remote) NOTE="$REMOTE_NOTE" ;;
  prompt:remote) [[ "$PREV" == remote ]] || NOTE="$REMOTE_NOTE" ;;
  *:local) [[ "$PREV" == remote ]] && NOTE="$LOCAL_NOTE" ;;
esac
[[ -n "$NOTE" ]] || exit 0

jq -n --arg event "$HOOK_EVENT" --arg context "$NOTE" \
  '{hookSpecificOutput: {hookEventName: $event, additionalContext: $context}}' 2>/dev/null
exit 0
