set fish_greeting
set -x SSH_AUTH_SOCK /Users/pszypowicz/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh

/opt/homebrew/bin/brew shellenv | source
fish_add_path ~/.local/bin

if status is-interactive
    # Check if tmux is already running by checking the TMUX environment variable
    # Do not run tmux if inside VSCode terminal
    if not set -q TMUX; and not string match -q "$TERM_PROGRAM" vscode; and isatty stdin
        exec tmux new-session -A -D -s default -c "$PWD"
    end

    starship init fish | source
    fzf --fish | source
    zoxide init fish | source

    ssh-add --apple-use-keychain -q
end
