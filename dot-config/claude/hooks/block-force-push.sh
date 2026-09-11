#!/usr/bin/env bash
# PreToolUse (Bash) hook: refuse to force-push a branch that an open GitHub pull
# request points at.
#
# A branch on a fork carries no branch protection, so the push succeeds and
# nothing warns you. The damage lands on the upstream pull request: review
# threads detach from their lines, "changes since your last review" stops
# working, and commits a reviewer already read can disappear.
#
# Reads the hook payload as JSON on stdin and stays silent (exit 0) unless the
# command force-pushes. On a force push it resolves the target branch and runs
# `gh pr list --head <branch> --state open`. An open pull request denies the
# tool call. A GitHub remote whose pull request state cannot be read also
# denies it, because an unknown answer is not a safe answer. A repository with
# no github.com remote is out of scope and passes through.
#
# Only `Bash` tool calls reach this hook. A push made by any other means is
# not covered.
set -uo pipefail

GH_DEADLINE_SECONDS=10

deny() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

# `gh` has no request deadline of its own. A hung call must not become a silent
# pass: a hook that exceeds its own timeout is skipped, and the push then runs
# unchecked. Bound the call here instead.
run_with_deadline() {
  local seconds="$1"
  shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$seconds" "$@"
    return $?
  fi
  "$@" &
  local job=$!
  (sleep "$seconds"; kill -TERM "$job" 2>/dev/null) </dev/null >/dev/null 2>&1 &
  local watchdog=$!
  wait "$job"
  local status=$?
  kill -TERM "$watchdog" 2>/dev/null
  wait "$watchdog" 2>/dev/null
  return $status
}

payload=$(cat)

# Most Bash calls never mention a push. Leave before spending a jq call on them.
case "$payload" in
  *push*) ;;
  *) exit 0 ;;
esac

command_line=$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
cwd=$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null || true)

[ -n "$command_line" ] || exit 0
[ -n "$cwd" ] || cwd="$PWD"
[ -d "$cwd" ] || exit 0

# The word can also sit in a file path elsewhere in the payload.
case "$command_line" in
  *push*) ;;
  *) exit 0 ;;
esac

# An amended commit rewrites history, so a push that carries one belongs to the
# same rule even when it names no force flag.
amends=0
case "$command_line" in
  *--amend*) amends=1 ;;
esac

# Inspect each command of a compound line on its own, so that a push hidden
# behind `&&` or `;` is still seen.
segments=${command_line//$'\n'/;}
segments=${segments//&&/;}
segments=${segments//||/;}
segments=${segments//|/;}

force=0
branches=()

while IFS= read -r segment; do
  [ -n "$segment" ] || continue
  case "$segment" in
    *push*) ;;
    *) continue ;;
  esac

  read -ra tokens <<<"$segment"
  [ "${#tokens[@]}" -gt 0 ] || continue

  # Step over a leading `sudo`, `command`, `env`, or `VAR=value` assignment.
  index=0
  while [ "$index" -lt "${#tokens[@]}" ]; do
    case "${tokens[$index]}" in
      sudo|command|env|*=*) index=$((index + 1)) ;;
      *) break ;;
    esac
  done
  [ "$index" -lt "${#tokens[@]}" ] || continue
  [ "${tokens[$index]##*/}" = "git" ] || continue

  segment_force="$amends"
  remote=""
  refspecs=()
  seen_push=0
  skip_value=0

  for token in "${tokens[@]:$index}"; do
    if [ "$skip_value" -eq 1 ]; then
      skip_value=0
      continue
    fi
    if [ "$seen_push" -eq 0 ]; then
      [ "$token" = "push" ] && seen_push=1
      continue
    fi
    case "$token" in
      -o|--push-option|--repo|--receive-pack|--exec)
        skip_value=1
        ;;
      --no-force*)
        ;;
      --force|--force-with-lease|--force-with-lease=*|--force-if-includes)
        segment_force=1
        ;;
      --*)
        ;;
      -*)
        # Short flags cluster, as in `git push -fu origin main`.
        case "$token" in
          *f*) segment_force=1 ;;
        esac
        ;;
      +*)
        # A leading plus forces that single refspec.
        segment_force=1
        refspecs+=("${token#+}")
        ;;
      *)
        if [ -z "$remote" ]; then
          remote="$token"
        else
          refspecs+=("$token")
        fi
        ;;
    esac
  done

  [ "$seen_push" -eq 1 ] || continue
  [ "$segment_force" -eq 1 ] || continue
  force=1

  # A push reaches a host, not only a named remote. Skip the segment when that
  # host is not GitHub.
  target="$remote"
  [ -n "$target" ] || target="origin"
  case "$target" in
    *://*|*@*:*)
      remote_url="$target"
      ;;
    *)
      remote_url=$(git -C "$cwd" remote get-url "$target" 2>/dev/null || true)
      ;;
  esac
  case "$remote_url" in
    *github.com*) ;;
    *) continue ;;
  esac

  named_branch=0
  for refspec in ${refspecs[@]+"${refspecs[@]}"}; do
    destination="${refspec##*:}"
    destination="${destination#refs/heads/}"
    case "$destination" in
      ""|HEAD) continue ;;
    esac
    branches+=("$destination")
    named_branch=1
  done

  if [ "$named_branch" -eq 0 ]; then
    current=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || true)
    [ -n "$current" ] && branches+=("$current")
  fi
done <<<"${segments//;/$'\n'}"

[ "$force" -eq 1 ] || exit 0
[ "${#branches[@]}" -gt 0 ] || exit 0

checked=""
for branch in "${branches[@]}"; do
  case " $checked " in
    *" $branch "*) continue ;;
  esac
  checked="$checked $branch"

  result=$(cd "$cwd" && run_with_deadline "$GH_DEADLINE_SECONDS" \
    gh pr list --head "$branch" --state open --json number,url 2>&1)
  status=$?

  if [ "$status" -ne 0 ]; then
    detail=$(printf '%s' "$result" | head -1)
    deny "Force push blocked. The pull request state of branch '$branch' could not be read, and the remote is on GitHub. gh reported: ${detail:-no output} (exit $status). Do not retry the push. Report this to the user and ask how to proceed. If gh reports several remotes, 'gh repo set-default' resolves it."
  fi

  count=$(printf '%s' "$result" | jq 'length' 2>/dev/null || echo 0)
  if [ "${count:-0}" -gt 0 ]; then
    listed=$(printf '%s' "$result" | jq -r '[.[] | "#\(.number) \(.url)"] | join(", ")' 2>/dev/null)
    deny "Force push blocked. Branch '$branch' is the head of an open pull request: $listed. A force push detaches review threads from their lines, breaks 'changes since your last review', and can drop commits a reviewer already read. Add a new commit on top instead. If the history must be rewritten, stop and ask the user first, and name the branch and the pull request number."
  fi
done

exit 0
