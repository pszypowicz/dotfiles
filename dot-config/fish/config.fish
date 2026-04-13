set fish_greeting
if test -S /Users/pszypowicz/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh; and pgrep -qf com.maxgoedjen.Secretive.SecretAgent
    set -x SSH_AUTH_SOCK /Users/pszypowicz/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh
end

/opt/homebrew/bin/brew shellenv | source
fish_add_path ~/.local/bin
fish_add_path ~/go/bin
set -gx CLAUDE_CONFIG_DIR ~/.config/claude

if status is-interactive
    # Check if tmux is already running by checking the TMUX environment variable
    # Do not run tmux if inside VSCode terminal
    if not set -q TMUX; and test "$TERM_PROGRAM" = ghostty
        exec tmux new-session -A -D -s (hostname -s) -c "$PWD"
    end

    starship init fish | source
    fzf --fish | source
    zoxide init fish | source

    ssh-add --apple-use-keychain -q
end
