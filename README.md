# Dotfiles

## Installation

```bash
./bootstrap
```

Installs Homebrew (if missing), packages, stows dotfiles, starts services, installs npm globals, and writes macOS defaults. Safe to re-run.

Private overlays (work, personal) live in sibling `dotfiles-private-*` repos as plain stow packages with a `Brewfile.<name>` and an optional `npm-globals` list - all setup logic lives in this bootstrap. On a machine that needs an overlay, pass it by name:

```bash
./bootstrap --overlay personal
```

The brew, stow, and npm steps then cover the overlay too: its Brewfile is bundled, its package is stowed, and its npm globals are installed. `--overlay` combines with step names, so `./bootstrap --overlay work stow` re-links public and work config in one go.

### Running individual steps

`./bootstrap` with no arguments runs everything. To re-apply just one part, pass step names - they always run in dependency order regardless of the order given:

```bash
./bootstrap stow          # re-link dotfiles after editing a config
./bootstrap macos         # re-write macOS defaults after a tweak
./bootstrap brew npm      # refresh packages and npm globals
```

Steps are `brew`, `stow`, `services`, `npm`, and `macos`; `./bootstrap --help` lists them.

### Stow only

`./bootstrap stow` wraps the invocation below; the raw command stays here for reference and for stowing from a different checkout:

```bash
stow -d ~/Developer/github.com/pszypowicz -t ~ dotfiles --dotfiles --restow --no-folding
```

- `--dotfiles` - takes filename prefix `dot-` and replace it in a target with `.`
- `--restow` - remove from target non-existent links
- `--no-folding` - create package subdirs as real dirs in the target and only symlink individual files, instead of collapsing subtrees into one dir-symlink. Prevents tools that write live state inside a config dir (e.g. Claude Code writing `history.jsonl`, `projects/`, caches into `~/.config/claude`) from accidentally writing into the git repo through a folded dir-symlink.
- `-d ~/Developer/github.com/pszypowicz` - shared stow directory, lets overlay packages coexist with the base package

Stow creates **relative** symlinks, resolved from the link's parent directory. To link a single new file without re-running stow, one `ln -s` with the same relative form is enough:

```bash
ln -s ../../Developer/github.com/pszypowicz/dotfiles/dot-config/claude/statusline.sh ~/.config/claude/statusline.sh
```

## What's included

**Shells:** Zsh (vi keybindings, autosuggestions, syntax highlighting)
**Terminal:** Ghostty, Tmux, Powerlevel10k prompt
**Window management:** AeroSpace (tiling)
**Status bar:** SketchyBar
**Dev tools:** Git, GitHub CLI, Vim, fd, fzf, Claude Code
**Other:** npm, Homebrew

## Docs

Cheat sheets and usage notes live in [`docs/`](docs/) (stow-ignored):

- [TMUX.md](docs/TMUX.md) - tmux session flow: sessions, windows, panes, and the Ghostty viewport model
- [MACOS-SHORTCUTS.md](docs/MACOS-SHORTCUTS.md) - native window, desktop, and app-management shortcuts
- [AEROSPACE-SHORTCUTS.md](docs/AEROSPACE-SHORTCUTS.md) - AeroSpace tiling bindings and service mode
- [ZSH-SHORTCUTS.md](docs/ZSH-SHORTCUTS.md) - fzf pickers, autosuggestions, and vi mode at the zsh prompt

## Login shell

zsh, the macOS default, with its config under `~/.config/zsh`. The one-line `dot-zshenv` at home sets `ZDOTDIR` and hands off to `dot-config/zsh/`. A new Mac needs no change.

## XDG

Configs live under `~/.config` via XDG env vars exported in `dot-config/zsh/dot-zshenv`, which every zsh reads, interactive or not. The same file relocates tool state directories (npm, bundler, Go, Terraform, etc.) out of `~/`.

## Scripts

`dot-local/bin` stows to `~/.local/bin`, which `.zprofile` puts first on `PATH`. Commands meant for typing start with `,` (`,cr`); helpers that only bindings and other scripts call have plain names (`fzf-jump-targets`, `fzf-alt-c-source`, `tmux-sessionizer`, `claude-session-preview`). Every script answers `--help`.

## fzf

`.zshrc` sources the fzf shell integration (`fzf --zsh`). `.zshenv` customizes it to use `fd` for file and directory discovery, the `fzf-alt-c-source` script for `Alt+C`, and a tmux popup for the UI. The bindings are in [ZSH-SHORTCUTS.md](docs/ZSH-SHORTCUTS.md).

## fd ignore

`dot-config/fd/ignore` stows to `~/.config/fd/ignore`, which `fd` reads to exclude paths from search results. Since fzf is configured to use `fd` under the hood, these patterns also filter what appears in `Ctrl+T` and `Alt+C`.

Current config excludes macOS system directories: `/Library`, `/Applications`, `/Movies`, `/Music`, `/Pictures`, `/Public`.

## Window drag gesture

`macos/defaults` enables the hidden AppKit preference `NSWindowShouldDragOnGesture`: hold Ctrl+Cmd and click-drag anywhere inside a window to move it, not just the title bar (Linux-style Super+drag).

```bash
defaults write NSGlobalDomain NSWindowShouldDragOnGesture -bool true
```

Move-only, the modifier combo is fixed, and there is no System Settings UI for it. Apps pick it up on launch, so already-running apps need a relaunch. Non-AppKit windows can ignore it (some Electron apps; Ghostty with `window-decoration = false`).

## SketchyBar LaunchAgent

`Library/LaunchAgents/com.felixkratz.sketchybar.plist` is a custom launchd plist that replaces `brew services start sketchybar`.

**Why:** The Homebrew-generated plist loads in all five launchd session types (`Aqua`, `Background`, `LoginWindow`, `StandardIO`, `System`), which causes lock-file conflicts and log noise on reboot. The custom plist restricts loading to the `Aqua` session only via `LimitLoadToSessionType`.

**Switching from brew services:**

```bash
brew services stop sketchybar
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.felixkratz.sketchybar.plist
```

**Managing the service:**

```bash
# Stop
launchctl bootout gui/$(id -u)/com.felixkratz.sketchybar

# Start
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.felixkratz.sketchybar.plist

# Restart (quick) - KeepAlive auto-relaunches after kill
killall sketchybar
```

**Upstream issue:** [FelixKratz/homebrew-formulae#17](https://github.com/FelixKratz/homebrew-formulae/issues/17) - once resolved, `brew services` can be used directly and this custom plist can be removed.
