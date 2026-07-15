#!/usr/bin/env bash
# Container entrypoint: verify the bind-mount topology actually delivered a
# usable environment, then hand off to claude. Each check exists because its
# failure mode is otherwise silent or cryptic: docker fabricates an empty dir
# when a mount source is missing in the VM, and an unmounted stow target repo
# makes settings.json a dangling symlink that reads as "no settings".
set -euo pipefail

die() {
    echo "cclaude entrypoint: $*" >&2
    exit 1
}

[ -n "$(ls -A . 2>/dev/null)" ] \
    || die "workspace $PWD is empty - colima's home mount or the workspace bind mount is missing"

[ -r "$CLAUDE_CONFIG_DIR/settings.json" ] \
    || die "settings.json unreadable under $CLAUDE_CONFIG_DIR - a stow symlink target repo is not mounted"

[ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ] \
    || die "CLAUDE_CODE_OAUTH_TOKEN is not set - run 'cclaude token' on the host"

exec claude "$@"
