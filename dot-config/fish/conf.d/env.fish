# Set the default editor
set -gx EDITOR vim

set -gx FZF_DEFAULT_COMMAND 'fd --type f'
set -gx FZF_DEFAULT_OPTS '--tmux bottom,80%,70%,border-native'
set -gx FZF_ALT_C_COMMAND '{ zoxide query --list 2>/dev/null; fd --type d; } | awk "!seen[\$0]++"'
set -gx FZF_ALT_C_OPTS '--preview "lsd --tree --depth 1 {}"'
set -gx FZF_CTRL_T_OPTS '--select-1 --exit-0 --preview "test -d {} && lsd --tree --depth 1 {} || bat --color=always --style=numbers {}"'
set -gx FZF_CTRL_R_OPTS '--layout=reverse --preview "echo {}" --preview-window down:3:hidden:wrap --bind "?:toggle-preview"'

set -gx XDG_CONFIG_HOME ~/.config
set -gx CLAUDE_CONFIG_DIR ~/.config/claude

fish_add_path /Users/pszypowicz/bin

set -g fish_key_bindings fish_vi_key_bindings
