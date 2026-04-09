function claude --wraps claude --description "Claude Code with tmux window name tracking and auto-theme"
    # Build NODE_OPTIONS for runtime patches loaded via --import.
    set -l node_imports

    # Auto-theme: os-state writes OS appearance to a theme file; the JS hook
    # reads it and reactively switches Claude's theme mid-session.
    set -l theme_hook "$HOME/.config/claude/theme/auto-theme.mjs"
    if test -f $theme_hook
        set -a node_imports "--import" $theme_hook
    end

    set -l node_opts
    if test (count $node_imports) -gt 0
        set node_opts NODE_OPTIONS="$node_imports"
    end

    if not set -q TMUX
        env $node_opts command claude $argv
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

    env $node_opts command claude $argv
    set -l s $status

    # Restore original format so non-claude processes show normally
    if test -n "$prev_format"
        tmux set-window-option -t $win_id automatic-rename-format "$prev_format"
    else
        tmux set-window-option -t $win_id -u automatic-rename-format
    end

    return $s
end
