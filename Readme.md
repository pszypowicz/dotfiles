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

## SketchyBar LaunchAgent

`Library/LaunchAgents/com.felixkratz.sketchybar.plist` is a custom launchd plist that replaces `brew services start sketchybar`.

**Why:** The Homebrew-generated plist loads in all five launchd session types (`Aqua`, `Background`, `LoginWindow`, `StandardIO`, `System`), which causes lock-file conflicts and log noise on reboot. The custom plist restricts loading to the `Aqua` session only via `LimitLoadToSessionType`.

**Switching from brew services:**

```bash
brew services stop sketchybar
launchctl load ~/Library/LaunchAgents/com.felixkratz.sketchybar.plist
```

**Upstream issue:** [FelixKratz/homebrew-formulae#17](https://github.com/FelixKratz/homebrew-formulae/issues/17) — once resolved, `brew services` can be used directly and this custom plist can be removed.