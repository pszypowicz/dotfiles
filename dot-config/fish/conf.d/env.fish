# Set the default editor
set -gx EDITOR vim

set -gx FZF_DEFAULT_COMMAND 'fd --type f'
set -gx FZF_DEFAULT_OPTS '--tmux bottom,80%,40%'

set -gx XDG_CONFIG_HOME ~/.config

set -g fish_key_bindings fish_vi_key_bindings
