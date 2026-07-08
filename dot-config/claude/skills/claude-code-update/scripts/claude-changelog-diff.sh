#!/usr/bin/env bash
#
# claude-changelog-diff.sh - print the Claude Code CHANGELOG entries between the
# last-analyzed version (the exact pin in the dotfiles bootstrap) and a target
# version, with a context header that includes the installed CLI version.
#
# The bootstrap pin marks the last version whose changelog was reviewed against
# the dotfiles; it is git-synced, so the diff range stays correct even when the
# CLI was updated on another machine.
#
# Used by the claude-code-update skill, but safe to run on its own.

set -euo pipefail

CHANGELOG_URL_DEFAULT="https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md"
PACKAGE="@anthropic-ai/claude-code"

from=""
to=""
url="$CHANGELOG_URL_DEFAULT"
bootstrap=""

usage() {
    cat <<EOF
claude-changelog-diff.sh - show Claude Code CHANGELOG entries between two versions.

Prints every "## X.Y.Z" section newer than --from up to and including --to,
preceded by header lines with the resolved versions (and where --from came
from), the installed CLI version and path, and which npm dist-tag --to matches.
Exits 0 with an "Already analyzed up to" line when the two versions are equal.

Usage:
  claude-changelog-diff.sh [--from <version>] [--to <version>] [--url <url>]
                           [--bootstrap <path>]
  claude-changelog-diff.sh -h | --help

Options:
  --from <version>    Lower bound, exclusive. Default: the $PACKAGE@X.Y.Z
                      pin in the dotfiles bootstrap (the last-analyzed
                      version); falls back to the installed version from
                      'claude --version' when no pin is found.
  --to <version>      Upper bound, inclusive. Default: latest published
                      version, from 'npm view $PACKAGE version'.
  --url <url>         CHANGELOG source. Default:
                      $CHANGELOG_URL_DEFAULT
  --bootstrap <path>  Bootstrap file to read the pin from. Default: the
                      'bootstrap' file at the root of the dotfiles repo this
                      script lives in (resolved through symlinks).
  -h, --help          Show this help and exit.

Example:
  claude-changelog-diff.sh --from 2.1.165 --to 2.1.168
EOF
}

die() {
    echo "claude-changelog-diff.sh: $*" >&2
    exit 1
}

note() {
    echo "claude-changelog-diff.sh: $*" >&2
}

while [ $# -gt 0 ]; do
    case "$1" in
        --from)
            [ $# -ge 2 ] || die "--from requires a value"
            from="$2"
            shift 2
            ;;
        --to)
            [ $# -ge 2 ] || die "--to requires a value"
            to="$2"
            shift 2
            ;;
        --url)
            [ $# -ge 2 ] || die "--url requires a value"
            url="$2"
            shift 2
            ;;
        --bootstrap)
            [ $# -ge 2 ] || die "--bootstrap requires a value"
            bootstrap="$2"
            shift 2
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            die "unknown argument: $1 (try --help)"
            ;;
    esac
done

# Resolve the installed CLI version and path (best effort; never fatal).
# Printed in the header so callers can spot machines whose install is behind
# or ahead of the analyzed range.
installed=""
install_path="$(command -v claude 2>/dev/null || true)"
if [ -n "$install_path" ]; then
    installed="$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
    install_path="$(readlink -f "$install_path" 2>/dev/null || echo "$install_path")"
fi
[ -n "$install_path" ] || install_path="unknown"

# Resolve --from when not given: bootstrap pin first, installed version as
# fallback. An explicit --bootstrap must exist; the default path may not
# (e.g. the script was copied out of the repo).
from_source="--from flag"
if [ -z "$from" ]; then
    if [ -n "$bootstrap" ]; then
        [ -r "$bootstrap" ] || die "cannot read bootstrap file: $bootstrap"
    else
        script_real="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
        repo_root="$(cd "$(dirname "$script_real")/../../../../.." 2>/dev/null && pwd || true)"
        bootstrap="${repo_root:+$repo_root/bootstrap}"
    fi
    if [ -n "$bootstrap" ] && [ -r "$bootstrap" ]; then
        from="$(grep -oE "$PACKAGE@[0-9]+\.[0-9]+\.[0-9]+" "$bootstrap" | head -1 | sed 's/.*@//' || true)"
    fi
    if [ -n "$from" ]; then
        from_source="bootstrap pin ($bootstrap)"
    else
        note "no $PACKAGE@X.Y.Z pin found${bootstrap:+ in $bootstrap}; falling back to the installed version"
        [ -n "$installed" ] || die "claude not found on PATH either; pass --from explicitly"
        from="$installed"
        from_source="installed version"
    fi
fi

# Resolve --to from npm when not given.
if [ -z "$to" ]; then
    command -v npm >/dev/null 2>&1 || die "npm not found on PATH; pass --to explicitly"
    to="$(npm view "$PACKAGE" version 2>/dev/null)"
    [ -n "$to" ] || die "could not resolve latest version via 'npm view $PACKAGE version'; pass --to explicitly"
fi

# Resolve the stable dist-tag so callers can see how far ahead --to is.
stable=""
if command -v npm >/dev/null 2>&1; then
    stable="$(npm view "$PACKAGE" dist-tags.stable 2>/dev/null || true)"
fi

# semver-aware comparison via sort -V. Prints the lexicographically/version
# greater of the two, or the value itself when equal.
version_gt() { # version_gt A B -> true when A > B
    [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1)" = "$1" ]
}

if [ "$from" = "$to" ]; then
    echo "Already analyzed up to $from; nothing new."
    echo "Installed: ${installed:-unknown} ($install_path)"
    exit 0
fi

if version_gt "$from" "$to"; then
    echo "--from ($from) is newer than --to ($to); nothing to show."
    echo "Installed: ${installed:-unknown} ($install_path)"
    exit 0
fi

# Header line(s).
echo "Claude Code changelog: $from -> $to"
echo "From source: $from_source"
echo "Installed: ${installed:-unknown} ($install_path)"
if [ -n "$stable" ]; then
    if [ "$to" = "$stable" ]; then
        echo "Channel: --to matches the 'stable' dist-tag ($stable)"
    else
        echo "Channel: --to ($to) is ahead of the 'stable' dist-tag ($stable)"
    fi
fi
echo

# Fetch and slice. awk emits a section when its "## X.Y.Z" version is
# > from and <= to. Range membership is decided in shell (sort -V) and the set
# of wanted versions is passed to awk, so awk needs no version math.
changelog="$(curl -fsSL "$url")" || die "failed to fetch changelog from $url"

# Collect every version header present, then keep those in (from, to].
# Avoid mapfile so this runs under macOS's stock bash 3.2 as well as bash 5.
wanted=""
while IFS= read -r v; do
    [ -n "$v" ] || continue
    if version_gt "$v" "$from" && { [ "$v" = "$to" ] || version_gt "$to" "$v"; }; then
        wanted="$wanted $v "
    fi
done < <(printf '%s\n' "$changelog" | grep -oE '^## [0-9]+\.[0-9]+\.[0-9]+' | sed 's/^## //')

if [ -z "${wanted// /}" ]; then
    echo "No changelog sections found between $from and $to."
    echo "(The changelog may lag the npm release, or entries were squashed.)"
    exit 0
fi

printf '%s\n' "$changelog" | awk -v wanted="$wanted" '
    /^## [0-9]+\.[0-9]+\.[0-9]+/ {
        ver = $2
        emit = (index(wanted, " " ver " ") > 0)
    }
    emit { print }
'
