# Candidate source for fzf's Alt-C directory jump.
#
# From $HOME: emit a curated list of "places I actually jump to", ordered
# so the most-recently-visited ones sit right under the fzf prompt for
# fast arrow-key selection without typing.
#
# The candidate set is:
#   - Every git repository under ~/Developer, discovered by presence of
#     .git, so any host layout works (github.com/owner/repo,
#     dev.azure.com/org/project/repo, ...).
#   - Top-level directories inside ~/Developer/_scratch (non-repo
#     playgrounds).
#   - Container dirs: ~/Developer's immediate children (host dirs,
#     _scratch) and the owner/org/project groupings beneath each host
#     (github.com/<owner>, dev.azure.com/<org>,
#     dev.azure.com/<org>/<project>). _scratch descendants are excluded
#     from this pass to avoid sub-sub-project noise.
#
# Ordering in the fzf list, top to bottom (fzf --fish forces --reverse,
# so the first input line appears directly under the prompt and the
# default selection lands there):
#   1. Visited candidates in zoxide frecency order (most-frecent first).
#   2. Unvisited candidates after, in fd discovery order.
#
# Zoxide's --base-dir flag natively restricts the frecency list to
# ~/Developer, and a set-membership check against the fd-discovered
# candidate set drops zoxide entries that are not jump targets: the
# ~/Developer root and nested subdirs inside a repo
# (.../claude-skills/.claude-plugin). This is the piece that stops
# "templates" from matching every nested templates/ dir the way the
# old zoxide-in-home setup did.
#
# From anywhere else: fall back to zoxide frecency plus fd's recursive
# walk rooted at $PWD, so Alt-C stays useful for both "jump within this
# project" and "jump to another project without going back to $HOME first".
function __fzf_alt_c_source
    if test "$PWD" = "$HOME"
        awk '
            # Normalize: strip trailing slash so fd (emits with slash on
            # --type d) and zoxide / fd --exec dirname (emit without)
            # compare as the same set.
            { sub(/\/$/, "") }

            # First file: authoritative candidate set from fd. Preserve
            # discovery order and dedupe (a scratch subdir that is itself
            # a git repo appears in both fd passes).
            NR==FNR {
                if (!($0 in candidate)) {
                    candidate[$0] = 1
                    order[++cn] = $0
                }
                next
            }

            # Second file: zoxide frecency list (most-frecent first).
            # Keep only entries that are in the candidate set.
            ($0 in candidate) && !(($0) in seen) {
                seen[$0] = 1
                zlist[++zn] = $0
            }

            END {
                # Visited first (most-frecent on top, directly under
                # the fzf prompt in --reverse layout).
                for (i = 1; i <= zn; i++) print zlist[i]
                # Unvisited after, in fd discovery order.
                for (i = 1; i <= cn; i++)
                    if (!(order[i] in seen)) print order[i]
            }
        ' \
        (begin
            fd --type d --hidden --prune '^\.git$' "$HOME/Developer" --exec dirname
            fd --type d --max-depth 1 . "$HOME/Developer/_scratch"
            fd --type d --max-depth 1 . "$HOME/Developer"
            fd --type d --min-depth 2 --max-depth 3 --exclude _scratch . "$HOME/Developer"
        end | psub) \
        (zoxide query --list --base-dir "$HOME/Developer" 2>/dev/null | psub)
    else
        begin
            zoxide query --list 2>/dev/null
            fd --type d
        end | awk '!seen[$0]++'
    end
end
