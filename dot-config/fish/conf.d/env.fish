# Set the default editor
set -gx EDITOR vim

set -gx LESS -RFiW -x2 --mouse --incsearch

set -gx FZF_DEFAULT_COMMAND 'fd --type f'
set -gx FZF_DEFAULT_OPTS '--tmux bottom,80%,70%,border-native'
set -gx FZF_ALT_C_COMMAND __fzf_alt_c_source
set -gx FZF_ALT_C_OPTS '--preview "lsd --tree --depth 1 {}"'
set -gx FZF_CTRL_T_OPTS '--select-1 --exit-0 --preview "test -d {} && lsd --tree --depth 1 {} || bat --color=always --style=numbers {}"'
set -gx FZF_CTRL_R_OPTS '--layout=reverse --preview "echo {}" --preview-window down:3:hidden:wrap --bind "?:toggle-preview"'

set -gx XDG_CONFIG_HOME ~/.config
set -gx XDG_DATA_HOME ~/.local/share
set -gx XDG_STATE_HOME ~/.local/state
set -gx XDG_CACHE_HOME ~/.cache
set -gx CLAUDE_CONFIG_DIR ~/.config/claude

# Move dotfiles out of ~/
set -gx GRADLE_USER_HOME $XDG_DATA_HOME/gradle
set -gx NPM_CONFIG_USERCONFIG $XDG_CONFIG_HOME/npm/npmrc
set -gx BUNDLE_USER_HOME $XDG_DATA_HOME/bundler
set -gx BUNDLE_USER_CONFIG $XDG_CONFIG_HOME/bundler
set -gx BUNDLE_USER_CACHE $XDG_CACHE_HOME/bundler
set -gx LESSHISTFILE $XDG_STATE_HOME/less/history
set -gx ANDROID_USER_HOME $XDG_DATA_HOME/android
set -gx DOTNET_CLI_HOME $XDG_DATA_HOME
set -gx DOCKER_CONFIG $XDG_CONFIG_HOME/docker
set -gx MPLCONFIGDIR $XDG_CONFIG_HOME/matplotlib
set -gx NUGET_PACKAGES $XDG_CACHE_HOME/nuget/packages
set -gx AZURE_CONFIG_DIR $XDG_CONFIG_HOME/azure
set -gx HISTFILE $XDG_STATE_HOME/zsh/history
set -gx SHELL_SESSIONS_DISABLE 1
set -gx GOPATH $XDG_DATA_HOME/go
set -gx GOMODCACHE $XDG_CACHE_HOME/go/mod
set -gx KUBECONFIG $XDG_CONFIG_HOME/kube/config
set -gx KUBECACHEDIR $XDG_CACHE_HOME/kube
set -gx TF_CLI_CONFIG_FILE $XDG_CONFIG_HOME/terraform/terraformrc
set -gx TF_PLUGIN_CACHE_DIR $XDG_CACHE_HOME/terraform/plugins
set -gx TF_INSTALL_PATH $XDG_DATA_HOME
set -gx TF_BINARY_PATH $HOME/bin/terraform
set -gx CHECKPOINT_DISABLE 1
set -gx BICEP_CACHE_ROOT $XDG_CACHE_HOME/bicep

fish_add_path $GOPATH/bin
fish_add_path $HOME/bin

set -g fish_key_bindings fish_vi_key_bindings
