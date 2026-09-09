# Zsh prompt shortcuts

Cheat sheet for the bindings at the zsh prompt. The fzf pickers come from
the `fzf --zsh` shell integration sourced in `.zshrc` and customized by the
`FZF_*` variables in `.zshenv`; each opens in a tmux bottom popup.

## fzf pickers

| Shortcut | What it does                                                                                                                                                                                                                                                                                           |
| -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `Ctrl+T` | Insert a file path at the cursor. Candidates come from `fd`; preview shows file contents (`bat`) or a directory tree (`lsd`). A single match auto-accepts.                                                                                                                                             |
| `Ctrl+R` | Fuzzy-search command history. `?` inside the picker toggles a full-command preview.                                                                                                                                                                                                                    |
| `Alt+C`  | Jump to a directory. From `~`: curated jump targets (repos under `~/Developer`, `_scratch` playgrounds, home children) with recently visited dirs on top, ranked by zoxide frecency. Elsewhere: zoxide results plus subdirectories of the cwd. The candidates come from the `fzf-alt-c-source` script. |

`fd` supplies the candidates, so the patterns in `dot-config/fd/ignore`
also filter what `Ctrl+T` and `Alt+C` see.

## Autosuggestions

`zsh-autosuggestions` shows the best history match in gray after the
cursor. `Right arrow` or `End` accepts the whole suggestion.

## Vi mode

`bindkey -v` is set: `Esc` drops to normal mode for vi motions and edits at
the prompt, `i`/`a` return to insert mode. Starship shows a `❮` instead of
the prompt character while in normal mode. `KEYTIMEOUT=1` removes the delay
after `Esc`.
