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

## Mic Guard

Prevents Bluetooth audio devices from hijacking the default microphone.

### Install

```bash
cd ~/Documents/Code/MicGuard
make install
```

On first launch MicGuard registers itself as a Login Item via `SMAppService`.

### Change preferred mic

Right-click the microphone icon in SketchyBar, or edit `~/.config/mic-guard/preferred-mic`.
