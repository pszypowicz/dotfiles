#!/usr/bin/env bash
# Content-search backend for the ,cs session finder: given a query and one or
# more Claude project transcript dirs, print the matching sessions as
# `<highlighted snippet>  <dim date>` <TAB> `<path>`, newest first, one row per
# session. ,cs wires this to fzf's change:reload so it re-runs as you type.
#
# Matching is two-tiered: ripgrep scans the raw .jsonl for speed and broad recall
# (it sees prompts, replies, and commands alike), then for each hit we render
# just the human-readable text (your typed prompts, Claude's replies, and
# tool-call inputs - not bulky tool output) and pull the matching line as a
# readable, highlighted snippet. The raw file is the haystack; the rendered text
# is only for display. Search is literal (fixed-string) and smart-case, so
# `User.Read.All` matches verbatim. Only top-level transcripts are searched; the
# non-resumable subagents/ subdir is skipped (--max-depth 1).
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: claude-session-search --query QUERY [--] DIR [DIR...]

Print Claude sessions whose transcript contains QUERY (literal, smart-case) as
`snippet <TAB> path` rows, newest first. Backs the ,cs finder's fzf reload.

Options:
  --query QUERY   Text to search for. Empty/blank prints nothing.
  -h, --help      Show this help and exit.

Arguments:
  DIR...          One or more project dirs under ~/.config/claude/projects.

Example:
  claude-session-search --query User.Read.All -- ~/.config/claude/projects/-Users-me-proj
EOF
}

query=""
dirs=()
while [ $# -gt 0 ]; do
  case "$1" in
    --query) query="${2:-}"; shift 2 ;;
    --query=*) query="${1#--query=}"; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; dirs+=("$@"); break ;;
    *) dirs+=("$1"); shift ;;
  esac
done

command -v rg >/dev/null 2>&1 || { echo "claude-session-search: ripgrep (rg) not found on PATH" >&2; exit 1; }

# Blank query: nothing to search, so the picker stays empty until you type.
case "$query" in
  *[![:space:]]*) : ;;
  *) exit 0 ;;
esac
[ "${#dirs[@]}" -gt 0 ] || exit 0

LIMIT=50

# Rendered human-readable text of one transcript, one chunk per message: your
# typed prompts, Claude's reply text, and tool-call inputs (commands), each
# collapsed to a single line and capped so a pasted file body can't dominate.
render() {
  jq -r '
    def chunk:
      if .type == "user" and (.promptSource == "typed") then
        (.message.content
         | if type == "string" then .
           elif type == "array" then (map(select(.type == "text") | .text) | join(" "))
           else "" end)
      elif .type == "assistant" then
        (.message.content
         | if type == "array" then
             (map(if .type == "text" then .text
                  elif .type == "tool_use" then (.input | [.. | strings | .[0:200]] | join(" "))
                  else empty end)
              | join(" "))
           else "" end)
      else "" end;
    (chunk // "")
    | gsub("[\t\n\r]"; " ") | gsub("  +"; " ") | sub("^ +"; "")
    | select(. != "")
    | .[0:300]
  ' "$1" 2>/dev/null
}

# Matching files, top-level only (the non-resumable subagents/ subdir is skipped
# via --max-depth 1), then ordered newest-first and capped.
matched=$(rg -l -F -S -e "$query" -g '*.jsonl' --max-depth 1 -- "${dirs[@]}" 2>/dev/null || true)
[ -n "$matched" ] || exit 0

printf '%s\n' "$matched" | xargs ls -t 2>/dev/null | head -n "$LIMIT" | while IFS= read -r f; do
  [ -f "$f" ] || continue

  snippet=$(render "$f" | rg --color=always -F -S -m1 -N -e "$query" 2>/dev/null | head -1 || true)
  [ -n "$snippet" ] || snippet=$(render "$f" | head -1 || true)
  [ -n "$snippet" ] || snippet="(no preview text) $(basename "${f%.jsonl}")"

  date=$(date -r "$(stat -f %m "$f")" '+%b %d %H:%M' 2>/dev/null || echo '')
  printf '%s  \033[2m%s\033[0m\t%s\n' "$snippet" "$date" "$f"
done
