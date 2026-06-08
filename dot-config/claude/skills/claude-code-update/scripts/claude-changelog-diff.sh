#!/usr/bin/env bash
#
# claude-changelog-diff.sh - print the Claude Code CHANGELOG entries between the
# installed CLI version and a target version, with a one-line context header.
#
# Used by the claude-code-update skill, but safe to run on its own.

set -euo pipefail

CHANGELOG_URL_DEFAULT="https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md"
PACKAGE="@anthropic-ai/claude-code"

from=""
to=""
url="$CHANGELOG_URL_DEFAULT"

usage() {
    cat <<EOF
claude-changelog-diff.sh - show Claude Code CHANGELOG entries between two versions.

Prints every "## X.Y.Z" section newer than --from up to and including --to,
preceded by a header line with the resolved versions, install path, and which
npm dist-tag --to matches. Exits 0 with an "Already up to date" line when the
two versions are equal.

Usage:
  claude-changelog-diff.sh [--from <version>] [--to <version>] [--url <url>]
  claude-changelog-diff.sh -h | --help

Options:
  --from <version>  Lower bound, exclusive. Default: installed version,
                    parsed from 'claude --version'.
  --to <version>    Upper bound, inclusive. Default: latest published version,
                    from 'npm view $PACKAGE version'.
  --url <url>       CHANGELOG source. Default:
                    $CHANGELOG_URL_DEFAULT
  -h, --help        Show this help and exit.

Example:
  claude-changelog-diff.sh --from 2.1.165 --to 2.1.168
EOF
}

die() {
    echo "claude-changelog-diff.sh: $*" >&2
    exit 1
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
        -h | --help)
            usage
            exit 0
            ;;
        *)
            die "unknown argument: $1 (try --help)"
            ;;
    esac
done

# Resolve --from from the installed CLI when not given.
if [ -z "$from" ]; then
    command -v claude >/dev/null 2>&1 || die "claude not found on PATH; pass --from explicitly"
    from="$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
    [ -n "$from" ] || die "could not parse installed version from 'claude --version'; pass --from explicitly"
fi

# Resolve --to from npm when not given.
if [ -z "$to" ]; then
    command -v npm >/dev/null 2>&1 || die "npm not found on PATH; pass --to explicitly"
    to="$(npm view "$PACKAGE" version 2>/dev/null)"
    [ -n "$to" ] || die "could not resolve latest version via 'npm view $PACKAGE version'; pass --to explicitly"
fi

# Resolve install location (best effort; never fatal).
install_path="$(command -v claude 2>/dev/null || true)"
[ -n "$install_path" ] && install_path="$(readlink -f "$install_path" 2>/dev/null || echo "$install_path")"
[ -n "$install_path" ] || install_path="unknown"

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
    echo "Already up to date ($from)."
    exit 0
fi

if version_gt "$from" "$to"; then
    echo "Installed version ($from) is newer than target ($to); nothing to show."
    exit 0
fi

# Header line(s).
echo "Claude Code changelog: $from -> $to"
echo "Install: $install_path"
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
