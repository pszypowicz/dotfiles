function claude --wraps claude --description "Claude Code with tmux window name tracking"
    if not set -q TMUX
        command claude $argv
        return $status
    end

    # Capture this window's ID so updates target it even when focus moves
    set -l win_id (tmux display-message -p '#{window_id}')

    # Claude sets process.title to its version (e.g. "2.1.84"), which automatic-rename
    # picks up via pane_current_command. Override the format for THIS window to use
    # pane_title instead, which Claude sets to the session name (e.g. "⠂ test").
    set -l prev_format (tmux show-window-option -t $win_id -v automatic-rename-format 2>/dev/null)
    set -l project_name (basename $PWD)
    tmux set-window-option -t $win_id automatic-rename-format "$project_name #{pane_title}"

    command claude $argv
    set -l s $status

    # Restore original format so non-claude processes show normally
    if test -n "$prev_format"
        tmux set-window-option -t $win_id automatic-rename-format "$prev_format"
    else
        tmux set-window-option -t $win_id -u automatic-rename-format
    end

    return $s
end
