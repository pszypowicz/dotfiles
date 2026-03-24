function clear --description "Clear screen and tmux scrollback"
    command clear $argv
    if set -q TMUX
        tmux clear-history
    end
end
