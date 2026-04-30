set fish_greeting

/opt/homebrew/bin/brew shellenv | source
fish_add_path ~/.local/bin
fish_add_path ~/go/bin

if status is-interactive
    # Check if tmux is already running by checking the TMUX environment variable
    # Do not run tmux if inside VSCode terminal
    if not set -q TMUX; and test "$TERM_PROGRAM" = ghostty
        tmux has-session -t scratch 2>/dev/null
            or tmux new-session -ds scratch -c $HOME

        set -l target (tmux list-sessions -F '#{session_last_attached} #{session_name}' 2>/dev/null \
            | sort -rn | awk 'NR==1 {print $2}')
        test -z "$target"; and set target scratch

        exec tmux attach -t $target
    end

    starship init fish | source
    fzf --fish | source
    zoxide init fish | source

    ssh-add --apple-use-keychain -q
end
