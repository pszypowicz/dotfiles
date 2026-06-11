set fish_greeting

/opt/homebrew/bin/brew shellenv | source
fish_add_path ~/.local/bin
fish_add_path ~/go/bin

if status is-interactive
    # Check if tmux is already running by checking the TMUX environment variable
    # Do not run tmux if inside VSCode terminal
    if not set -q TMUX; and test "$TERM_PROGRAM" = ghostty
        # Attach to the most recently used session that no client is showing;
        # never mirror a session already visible in another window.
        set -l target (tmux list-sessions -f '#{==:#{session_attached},0}' \
            -F '#{session_last_attached} #{session_name}' 2>/dev/null \
            | sort -rn | awk 'NR==1 {print $2}')

        if test -n "$target"
            exec tmux attach -t $target
        else if tmux has-session -t scratch 2>/dev/null
            exec tmux new-session -c $HOME
        else
            exec tmux new-session -s scratch -c $HOME
        end
    end

    starship init fish | source
    fzf --fish | source
    zoxide init fish | source

    ssh-add --apple-use-keychain -q
end
