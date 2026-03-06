# Set the default editor
set -gx EDITOR vim

set -gx FZF_DEFAULT_COMMAND 'fd --type f'
set -gx FZF_DEFAULT_OPTS '--tmux bottom,80%,70%,border-native'
set -gx FZF_ALT_C_COMMAND 'fd --type d'
set -gx FZF_ALT_C_OPTS '--preview "lsd --tree --depth 1 {}"'
set -gx FZF_CTRL_T_OPTS '--preview "bat --color=always --style=numbers {}"'

set -gx XDG_CONFIG_HOME ~/.config

set -g fish_key_bindings fish_vi_key_bindings
