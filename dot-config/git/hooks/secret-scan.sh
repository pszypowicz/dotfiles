#!/usr/bin/env bash
# Secret scan behind the hook.secret-scan-* entries in ~/.config/git/config.
#
# Hooks registered in git config run in every repository, before the hook in
# the repository's own hooks directory. A repository that installs its own
# hooks (pre-commit, husky, lefthook) keeps them and still gets this scan.
#
#   pre-commit  Scans the staged changes.
#   commit-msg  Scans the commit message, which the staged scan does not read.
#   pre-push    Scans each pushed commit that the remote does not have yet.
#               This covers commits that never ran pre-commit, such as those
#               made with --no-verify, cherry-pick, rebase, or am.
#
# Without the betterleaks binary the hook fails, so nothing is committed or
# pushed unscanned. To turn one scan off in one repository:
#   git config hook.secret-scan-staged.enabled false
set -uo pipefail

# betterleaks exits 1 on its own errors too, so findings get a distinct code.
LEAK_EXIT=42

usage() {
  cat <<'EOF'
Scan git changes for secrets with betterleaks.

Usage: secret-scan.sh --event EVENT [HOOK-ARGS ...]

Git runs this from the hook.secret-scan-* entries in ~/.config/git/config and
appends the hook's own arguments after the flags.

Options:
  --event EVENT  Hook event to handle: pre-commit, commit-msg, or pre-push.
                 Required.
  -h, --help     Show this help and exit.

Examples:
  secret-scan.sh --event pre-commit
  secret-scan.sh --event commit-msg .git/COMMIT_EDITMSG
  git hook run pre-push -- origin "$(git remote get-url origin)" < refs.txt
EOF
}

event=""
while [ $# -gt 0 ]; do
  case "$1" in
    --event)
      if [ $# -lt 2 ]; then
        echo "secret-scan: --event needs a value" >&2
        usage >&2
        exit 2
      fi
      event="$2"
      shift 2
      ;;
    --event=*) event="${1#*=}"; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    -*)
      echo "secret-scan: unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *) break ;;
  esac
done

case "$event" in
  pre-commit|commit-msg|pre-push) ;;
  "")
    echo "secret-scan: --event is required" >&2
    usage >&2
    exit 2
    ;;
  *)
    echo "secret-scan: unsupported event: $event" >&2
    usage >&2
    exit 2
    ;;
esac

# Git GUIs and editors can run hooks with a PATH that lacks Homebrew.
betterleaks=$(command -v betterleaks 2>/dev/null || true)
if [ -z "$betterleaks" ]; then
  for candidate in /opt/homebrew/bin/betterleaks /usr/local/bin/betterleaks \
    /home/linuxbrew/.linuxbrew/bin/betterleaks; do
    if [ -x "$candidate" ]; then
      betterleaks="$candidate"
      break
    fi
  done
fi
if [ -z "$betterleaks" ]; then
  echo "secret-scan: betterleaks is not installed, so the $event scan cannot run." >&2
  echo "secret-scan: install it with 'brew install betterleaks'." >&2
  exit 1
fi

common=(--no-banner --log-level warn --redact --verbose --exit-code "$LEAK_EXIT")

# check STATUS SUBJECT - report a non-zero scan status and return 1.
check() {
  local status="$1" subject="$2"
  case "$status" in
    0) return 0 ;;
    "$LEAK_EXIT")
      echo "secret-scan: betterleaks found a secret in $subject." >&2
      echo "secret-scan: remove it. For a false positive, put a betterleaks:allow comment on that line." >&2
      ;;
    *)
      echo "secret-scan: betterleaks could not scan $subject (exit $status)." >&2
      ;;
  esac
  return 1
}

case "$event" in
  pre-commit)
    "$betterleaks" git --pre-commit --staged "${common[@]}" .
    check $? "the staged changes"
    ;;

  commit-msg)
    message_file="${1:-}"
    if [ -z "$message_file" ] || [ ! -r "$message_file" ]; then
      echo "secret-scan: cannot read the commit message file '${message_file}'." >&2
      exit 1
    fi
    # `git commit -v` appends the staged diff below a scissors line, and git
    # drops everything from that line on. The pre-commit scan covers the diff.
    sed '/ -\{24\} >8 -\{24\}$/,$d' "$message_file" | "$betterleaks" stdin "${common[@]}"
    check $? "the commit message"
    ;;

  pre-push)
    remote="${1:-}"
    failed=0
    while read -r local_ref local_sha remote_ref remote_sha; do
      [ -n "${local_sha:-}" ] || continue
      # An all-zero local object name deletes the remote ref and sends nothing.
      case "$local_sha" in
        *[!0]*) ;;
        *) continue ;;
      esac

      # Skip commits the remote already has. Only this remote's tracking refs
      # count: a commit that so far sits on another remote alone still goes
      # through the scan, because this push can publish it somewhere new.
      exclude=()
      case "$remote_sha" in
        *[!0]*)
          if git cat-file -e "${remote_sha}^{commit}" 2>/dev/null; then
            exclude+=("$remote_sha")
          fi
          ;;
      esac
      if [ -n "$remote" ] && git remote get-url "$remote" >/dev/null 2>&1; then
        exclude+=("--remotes=$remote")
      fi

      log_opts="$local_sha"
      if [ ${#exclude[@]} -gt 0 ]; then
        log_opts="$log_opts --not ${exclude[*]}"
      fi

      # The ref list arrives on stdin, so betterleaks must not read from it.
      "$betterleaks" git "${common[@]}" --log-opts="$log_opts" . </dev/null
      check $? "the commits for ${remote_ref:-$local_ref}" || failed=1
    done
    exit "$failed"
    ;;
esac
