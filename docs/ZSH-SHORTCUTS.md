# Zsh prompt shortcuts

Cheat sheet for the key bindings at the zsh prompt.

## fzf pickers

`.zshrc` sources the fzf shell integration (`fzf --zsh`). The `FZF_*` variables in `.zshenv` point it at `fd` for file and directory discovery, at the `fzf-alt-c-source` script for `Alt+C`, and at a tmux bottom popup for the interface.

| Shortcut | What it does                                                                                                                                                                                                                              |
| -------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Ctrl+T` | Insert a file path at the cursor. Candidates come from `fd`. The preview shows file contents through `bat`, or a directory tree through `lsd`. A single match accepts itself.                                                             |
| `Ctrl+R` | Fuzzy-search the command history. Press `?` inside the picker for a full-command preview.                                                                                                                                                 |
| `Alt+C`  | Jump to a directory. From `~` the list holds curated targets: git repositories under `~/Developer`, `_scratch` playgrounds, and the children of home. Elsewhere it holds zoxide results plus the subdirectories of the current directory. |

Recently visited directories come first in `Alt+C`, in zoxide frecency order. The `fzf-jump-targets` script builds the candidate list, and `prefix + f` in tmux reuses it.

## Search exclusions

`dot-config/fd/ignore` stows to `~/.config/fd/ignore`. `fd` reads that file and drops the listed paths from every result. Because fzf calls `fd`, the same patterns filter what `Ctrl+T` and `Alt+C` offer.

The current list holds the macOS directories that are noise in a code search: `/Library`, `/Applications`, `/Movies`, `/Music`, `/Pictures`, and `/Public`.

## Autosuggestions

`zsh-autosuggestions` shows the best history match in gray after the cursor. `Right arrow` or `End` accepts the whole suggestion. Home, End, and Delete work in insert mode.

## Vi mode

`bindkey -v` is set. `Esc` drops to normal mode for vi motions and edits at the prompt. `i` and `a` return to insert mode. Powerlevel10k shows a `❮` prompt character in normal mode. `KEYTIMEOUT=1` removes the delay after `Esc`.
