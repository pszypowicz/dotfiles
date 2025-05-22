set fish_greeting

eval "$(/opt/homebrew/bin/brew shellenv)"
fish_add_path ~/bin

if status is-interactive

    starship init fish | source
    fzf --fish | source

    ssh-add --apple-use-keychain -q

    # Check if tmux is already running by checking the TMUX environment variable
    if not set -q TMUX
        # Only run start_tmux session in the Apple Terminal
        if test "$TERM_PROGRAM" = Apple_Terminal
            start_tmux
        else if test "$TERM_PROGRAM" = vscode
            start_tmux_vscode
        end
    end
end
