
set fish_greeting

eval "$(/opt/homebrew/bin/brew shellenv)"
fish_add_path ~/bin

# Set the default editor
set -gx EDITOR vim

if status is-interactive
  starship init fish | source
  fzf --fish | source

  source ~/.config/fish/alias.fish
  ssh-add --apple-use-keychain -q

  set -g fish_key_bindings fish_vi_key_bindings

  set -gx FZF_DEFAULT_COMMAND 'fd --type f'
  set -gx FZF_DEFAULT_OPTS '--tmux bottom,80%,40%'

  # Check if tmux is already running by checking the TMUX environment variable
  set -q TMUX || start_tmux
end


