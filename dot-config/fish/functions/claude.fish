function claude --wraps claude --description "Claude Code with tmux window name tracking"
    # The binary at ~/.local/share/claude/versions/ is named by version number
    # (e.g. "2.1.84"), which Activity Monitor and VS Code show as the process name.
    # Rename it to "claude" so the process name is sensible everywhere.
    set -l claude_bin (command -s claude)
    set -l real_bin (realpath $claude_bin)
    if string match -qr '/[0-9]+\.[0-9]' $real_bin
        set -l renamed (path dirname $real_bin)/claude
        command mv $real_bin $renamed
        and command ln -sf $renamed $claude_bin
    end

    # Track whether this is an update command
    set -l is_update 0
    if set -q argv[1]; and contains -- $argv[1] update upgrade
        set is_update 1
    end

    if not set -q TMUX
        command claude $argv
        set -l s $status
    else
        # Capture this window's ID so updates target it even when focus moves
        set -l win_id (tmux display-message -p '#{window_id}')

        # Claude sets process.title to its version (e.g. "2.1.84"), which automatic-rename
        # picks up via pane_current_command. Override the format for THIS window to use
        # pane_title instead, which Claude sets to the session name (e.g. "⠂ test").
        set -l prev_format (tmux show-window-option -t $win_id -v automatic-rename-format 2>/dev/null)
        tmux set-window-option -t $win_id automatic-rename-format '#{pane_title}'

        command claude $argv
        set -l s $status

        # Restore original format so non-claude processes show normally
        if test -n "$prev_format"
            tmux set-window-option -t $win_id automatic-rename-format "$prev_format"
        else
            tmux set-window-option -t $win_id -u automatic-rename-format
        end
    end

    # Post-update: rename the newly downloaded binary
    if test $is_update -eq 1
        set real_bin (realpath $claude_bin)
        if string match -qr '/[0-9]+\.[0-9]' $real_bin
            set -l renamed (path dirname $real_bin)/claude
            command mv $real_bin $renamed
            and command ln -sf $renamed $claude_bin
        end
    end

    return $s
end
