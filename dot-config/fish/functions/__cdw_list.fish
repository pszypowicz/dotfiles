# Tab-separated `<label>\t<path>` for every worktree of the current repo
# except the one we're standing in. label = branch name (refs/heads/ stripped),
# or "(detached) <basename>" for a detached HEAD. `git worktree list` is the
# source of truth, so base clones, ~/Developer/.worktrees/<id>/... session
# worktrees, and hand-made ones are all covered.
function __cdw_list --description 'List sibling worktrees as label<TAB>path'
    set -l current (git rev-parse --show-toplevel 2>/dev/null)
    test -z "$current"; and return

    git worktree list --porcelain | awk -v cur="$current" '
        function flush() {
            if (path != "" && path != cur && !bare) {
                if (label == "") {
                    n = split(path, parts, "/")
                    label = (detached ? "(detached) " : "") parts[n]
                }
                printf "%s\t%s\n", label, path
            }
            path = ""; label = ""; detached = 0; bare = 0
        }
        /^worktree / { flush(); path = substr($0, 10) }
        /^branch /   { label = $2; sub(/^refs\/heads\//, "", label) }
        /^detached/  { detached = 1 }
        /^bare/      { bare = 1 }
        END { flush() }
    '
end
