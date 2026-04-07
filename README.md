# Dotfiles

## Installation

```bash
./bootstrap
```

Installs Homebrew (if missing), packages, stows dotfiles, and writes macOS defaults. Safe to re-run.

If `~/Developer/dotfiles-private` exists, the bootstrap script also installs its packages and stows its configs as an overlay.

### Stow only

```bash
stow -d ~/Developer -t ~ dotfiles --dotfiles --restow
```

- `--dotfiles` -- takes filename prefix `dot-` and replace it in a target with `.`
- `--restow` -- remove from target non-existent links
- `-d ~/Developer` -- shared stow directory, allows the private overlay to coexist

## What's included

**Shells:** Fish (primary, vi keybindings), Bash, Zsh
**Terminal:** Tmux, Starship prompt
**Window management:** AeroSpace (tiling), Borders, Hammerspoon
**Status bar:** SketchyBar
**Dev tools:** Git, GitHub CLI, Vim, fd, fzf, Claude Code
**Other:** npm, Homebrew

## XDG

Configs live under `~/.config` via XDG env vars set in `env.fish` (and equivalents in bash/zsh). `env.fish` also relocates tool state directories (Gradle, npm, Android, bundler, etc.) out of `~/`.

## fzf

Fish sources fzf shell integration (`fzf --fish`), providing `Ctrl+T` (files), `Ctrl+R` (history), and `Alt+C` (directories). `env.fish` customizes these to use `fd` for file/directory discovery, `zoxide` results in `Alt+C`, and a tmux popup for the UI.

## fd ignore

`dot-config/fd/ignore` stows to `~/.config/fd/ignore`, which `fd` reads to exclude paths from search results. Since fzf is configured to use `fd` under the hood, these patterns also filter what appears in `Ctrl+T` and `Alt+C`.

Current config excludes macOS system directories: `/Library`, `/Applications`, `/Movies`, `/Music`, `/Pictures`, `/Public`.

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

# Restart (quick) — KeepAlive auto-relaunches after kill
killall sketchybar
```

**Upstream issue:** [FelixKratz/homebrew-formulae#17](https://github.com/FelixKratz/homebrew-formulae/issues/17) — once resolved, `brew services` can be used directly and this custom plist can be removed.
