# Fuzzy-pick a directory from __fzf_alt_c_source and switch to (or create)
# a tmux session named after its basename, with cwd set to that directory.
#
# Bound from tmux.conf as `prefix + f` via `run-shell -b`. fzf renders its
# own popup via --tmux from FZF_DEFAULT_OPTS; an outer display-popup would
# nest and break fzf's self-spawned popup. Also runnable outside tmux.
function __tmux_sessionizer
    set -l choice (__fzf_alt_c_source | fzf --reverse --prompt='session> ')
    test -z "$choice"; and return

    set -l name (basename $choice | string replace -ra '[.: ]' '_')

    tmux has-session -t $name 2>/dev/null
        or tmux new-session -ds $name -c $choice

    if set -q TMUX
        tmux switch-client -t $name
    else
        tmux attach -t $name
    end
end
