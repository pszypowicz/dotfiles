set fish_greeting

eval "$(/opt/homebrew/bin/brew shellenv)"
fish_add_path ~/bin

if status is-interactive

    starship init fish | source
    fzf --fish | source

    ssh-add --apple-use-keychain -q

    # Check if tmux is already running by checking the TMUX environment variable
    if not set -q TMUX
        start-tmux
    end
end
