#!/usr/bin/env bash
# PostToolUse (Edit|Write) hook: flag forbidden characters in a written file.
#
#   - em dash (U+2014) anywhere            -> use a single '-'
#   - any non-ASCII byte in .ps1 / .psm1   -> ASCII only (avoids PSScriptAnalyzer BOM/encoding noise)
#
# Reads the hook payload as JSON on stdin and inspects .tool_input.file_path.
# On a hit it prints the offending lines to stderr and exits 2, which surfaces
# the message back to the model so it self-corrects. It never blocks the edit
# (the file is already written by the time PostToolUse runs) and never mutates
# the file. No violations -> exit 0, silent.
#
# macOS ships BSD grep (no -P/PCRE), so matching is done on raw bytes under
# LC_ALL=C: the em dash is its 3-byte UTF-8 sequence, non-ASCII is the byte
# range 0x80-0xFF.
set -euo pipefail

payload=$(cat)
file_path=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)

[ -n "$file_path" ] || exit 0
[ -f "$file_path" ] || exit 0

# Skip the Claude config/instruction tree: em dashes are legitimate there (rule
# text and examples) and would be false positives. Skip vendored trees too.
case "$file_path" in
  */.config/claude/*|*/.claude/*|*CLAUDE.md|*CLAUDE.private.md) exit 0 ;;
  */node_modules/*|*/vendor/*|*/.git/*) exit 0 ;;
esac

# Skip binary files.
grep -Iq . "$file_path" 2>/dev/null || exit 0

emdash=$(printf '\342\200\224')          # U+2014 em dash, UTF-8 bytes E2 80 94
nonascii=$(printf '[\200-\377]')         # any byte 0x80-0xFF

problems=""

if LC_ALL=C grep -nF "$emdash" "$file_path" >/dev/null 2>&1; then
  hits=$(LC_ALL=C grep -nF "$emdash" "$file_path" | head -5)
  problems+=$'Em dash (U+2014) found - replace each with a single "-":\n'"$hits"$'\n'
fi

case "$file_path" in
  *.ps1|*.psm1)
    if LC_ALL=C grep -nE "$nonascii" "$file_path" >/dev/null 2>&1; then
      hits=$(LC_ALL=C grep -nE "$nonascii" "$file_path" | head -5)
      problems+=$'Non-ASCII byte(s) in a PowerShell file - use ASCII only:\n'"$hits"$'\n'
    fi
    ;;
esac

if [ -n "$problems" ]; then
  printf '%s' "$problems" >&2
  printf 'Fix %s and re-save.\n' "$file_path" >&2
  exit 2
fi

exit 0
