# cd to another worktree of the current repo. With an argument: match it against
# the branch name (or basename for a detached HEAD) and cd there. Without one:
# fzf-pick from the siblings, matching the prompt style of __tmux_sessionizer.
# fzf renders its own tmux popup via --tmux in FZF_DEFAULT_OPTS.
function ,cdw --description 'cd to another worktree of the current repo'
    if not git rev-parse --is-inside-work-tree >/dev/null 2>&1
        echo ',cdw: not inside a git repository' >&2
        return 1
    end

    set -l rows (__cdw_list)
    if test -z "$rows"
        echo ',cdw: no other worktrees for this repo' >&2
        return 1
    end

    set -l target
    if set -q argv[1]
        for row in $rows
            set -l parts (string split -m1 \t -- $row)
            if test "$parts[1]" = "$argv[1]"
                set target $parts[2]
                break
            end
        end
        if test -z "$target"
            echo ",cdw: no worktree matching '$argv[1]'" >&2
            return 1
        end
    else
        set -l choice (printf '%s\n' $rows \
            | fzf --reverse --prompt='worktree> ' --delimiter=\t --with-nth=1)
        test -z "$choice"; and return
        set target (string split -m1 \t -- $choice)[2]
    end

    cd $target
end
