# Fish prompt shortcuts

Cheat sheet for the bindings available at the fish prompt. The fzf
pickers come from the `fzf --fish` shell integration sourced in
`config.fish` and customized in `conf.d/env.fish`; each opens in a
tmux bottom popup.

## fzf pickers

| Shortcut | What it does                                                                                                                                                                                                                                   |
| -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Ctrl+T` | Insert a file path at the cursor. Candidates come from `fd`; preview shows file contents (`bat`) or a directory tree (`lsd`). A single match auto-accepts.                                                                                     |
| `Ctrl+R` | Fuzzy-search command history. `?` inside the picker toggles a full-command preview.                                                                                                                                                            |
| `Alt+C`  | Jump to a directory. From `~`: curated jump targets (repos under `~/Developer`, `_scratch` playgrounds, home children) with recently visited dirs on top, ranked by zoxide frecency. Elsewhere: zoxide results plus subdirectories of the cwd. |

`fd` supplies the candidates, so the patterns in `dot-config/fd/ignore`
also filter what `Ctrl+T` and `Alt+C` see.

## Vi mode

Fish uses `fish_vi_key_bindings`: `Esc` drops to normal mode for vi
motions and edits at the prompt, `i`/`a` return to insert mode.
