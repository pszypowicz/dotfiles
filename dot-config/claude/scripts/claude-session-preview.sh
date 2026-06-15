#!/usr/bin/env bash
# Render a Claude Code session transcript (.jsonl) as a readable conversation for
# the ,cr fzf preview pane: the prompts you actually typed and Claude's prose
# replies, in order. Everything else is dropped - tool calls and tool results,
# thinking blocks, and the machine-injected user turns (slash-command wrappers,
# skill expansions, local-command caveats) that carry "promptSource": null.
#
# Output is plain text with ANSI role chips (no markdown renderer): transcript
# text is not markdown, and running it through one garbles command wrappers and
# reinterprets stray #/`/- as syntax. The ESC byte is built here and passed to
# jq via --arg so the program source stays pure ASCII.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: claude-session-preview <transcript.jsonl>

Render a Claude Code session transcript as a readable conversation (your typed
prompts and Claude's replies), for the ,cr session picker's fzf preview pane.

Options:
  -h, --help   Show this help and exit.
EOF
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  "") usage >&2; exit 2 ;;
esac

file="$1"
[ -f "$file" ] || { echo "no such transcript: $file" >&2; exit 1; }

esc=$(printf '\033')

jq -rs --arg esc "$esc" '
  # Reverse-video colour chip, e.g. " you " on cyan.
  def chip(txt; col): $esc + "[1;7;" + col + "m " + txt + " " + $esc + "[0m";

  # Text of a user message (string content, or the text blocks of an array).
  def usertext:
    .message.content
    | if type == "string" then .
      else (map(select(.type == "text") | .text) | join("\n"))
      end;

  .[]
  | if .type == "user" then
      (usertext // "") as $t
      | if .promptSource == "typed" then
          select($t != "") | chip("you"; "36") + "\n" + $t + "\n"
        elif ($t | startswith("<command-message")) then
          # Slash command: show just the /name, drop the args/expansion noise.
          (($t | capture("<command-name>(?<n>/[^<]+)</command-name>")?.n) // "/command") as $cmd
          | chip($cmd; "35")
        else empty end
    elif .type == "assistant" then
      ((.message.content // []) | map(select(.type == "text") | .text) | join("\n")) as $t
      | select($t != "")
      | chip("claude"; "32") + "\n" + $t + "\n"
    else empty end
' "$file"
