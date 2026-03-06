set fish_greeting

eval "$(/opt/homebrew/bin/brew shellenv)"

if status is-interactive
    # Check if tmux is already running by checking the TMUX environment variable
    # Do not run tmux if inside VSCode terminal
    if not set -q TMUX; and not string match -q "$TERM_PROGRAM" vscode
        ,start-tmux
    end

    starship init fish | source
    fzf --fish | source

    ssh-add --apple-use-keychain -q
end
export PATH="$HOME/.local/bin:$PATH"
