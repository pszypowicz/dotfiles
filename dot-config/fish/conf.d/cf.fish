# Cloudflare CLI completions. `cf` writes the completion script under
# ~/.config/cf/completions on first run and expects this loader in conf.d.
if test -f "$HOME/.config/cf/completions/cf.fish"
    source "$HOME/.config/cf/completions/cf.fish"
end
