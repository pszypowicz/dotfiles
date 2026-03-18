# Dotfiles

## Installation

### Stow

```bash
stow . --target ~ --dotfiles --restow
```

- `--dotfiles` - takes filename prefix `dot-` and replace it in a target with `.`
- `--restow` - remove from target unexsiting links

## Fish Shell Keybindings

### FZF built-ins (`fzf --fish | source`)

| Keybinding | Action                                                      | Customization env var                   |
| ---------- | ----------------------------------------------------------- | --------------------------------------- |
| `Ctrl+T`   | Find files under current dir, insert path into command line | `FZF_CTRL_T_COMMAND`, `FZF_CTRL_T_OPTS` |
| `Ctrl+R`   | Search command history, insert selected command             | `FZF_CTRL_R_OPTS`                       |
| `Alt+C`    | Find directories under current dir, `cd` into selection     | `FZF_ALT_C_COMMAND`, `FZF_ALT_C_OPTS`   |

All three inherit `FZF_DEFAULT_OPTS` (tmux popup).

## fdignore

`dot-fdignore` stows to `~/.fdignore`, which `fd` reads to exclude paths from search results. This directly affects fzf because `env.fish` sets `FZF_DEFAULT_COMMAND` to `fd --type f` and `FZF_ALT_C_COMMAND` to `fd --type d` — so the fdignore patterns filter what appears in `Ctrl+T` and `Alt+C`.

Current config excludes macOS system directories: `/Library`, `/Applications`, `/Movies`, `/Music`, `/Pictures`, `/Public`.