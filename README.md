# Dotfiles

Personal macOS configuration, managed with GNU Stow. One `./bootstrap` run installs the packages, links the configs into `$HOME`, starts the services, and writes the macOS defaults.

## What is included

| Area              | Tools                                                         |
| ----------------- | ------------------------------------------------------------- |
| Shell             | Zsh with vi keybindings, autosuggestions, syntax highlighting |
| Prompt            | Powerlevel10k                                                 |
| Terminal          | Ghostty, tmux                                                 |
| Window management | AeroSpace (tiling)                                            |
| Status bar        | SketchyBar                                                    |
| Navigation        | fzf, fd, zoxide, ripgrep, lsd, bat                            |
| Development       | Git, GitHub CLI, Vim, Claude Code, Node, Go, Rust, Homebrew   |

The full package list is `dot-config/brewfile/Brewfile`.

## Install

Clone the repository, then run the installer:

```bash
git clone git@github.com:pszypowicz/dotfiles.git ~/Developer/github.com/pszypowicz/dotfiles
cd ~/Developer/github.com/pszypowicz/dotfiles
./bootstrap
```

`bootstrap` derives the stow directory from its own location, so any clone path works. A private overlay must sit beside this repository, in the same parent directory. The path above follows the clone layout that the rest of these configs assume.

`./bootstrap` is safe to re-run.

### Steps

`./bootstrap` with no arguments runs every step. To repeat one part, pass its name. The steps always run in dependency order, whatever order you type them in.

| Step       | What it does                                                                  |
| ---------- | ----------------------------------------------------------------------------- |
| `brew`     | Install Homebrew if it is absent, then install the Brewfile packages.         |
| `stow`     | Symlink the configs into the home directory.                                  |
| `services` | Start the Homebrew services that need the stowed config (colima, sketchybar). |
| `npm`      | Install the global npm tools, with the pinned claude-code version.            |
| `macos`    | Write the macOS preference defaults.                                          |

```bash
./bootstrap stow          # re-link the configs after an edit
./bootstrap macos         # re-write the macOS defaults after a tweak
./bootstrap brew npm      # refresh the packages and the npm globals
```

`./bootstrap --help` prints the same list.

### Private overlays

Machine-specific config lives in sibling `dotfiles-private-*` repositories. Each overlay is a plain stow package with a `Brewfile.<name>` and an optional `npm-globals` list. All setup logic stays in this bootstrap.

To include an overlay, name it:

```bash
./bootstrap --overlay personal
```

The brew, stow, and npm steps then cover the overlay too. `--overlay` combines with step names, so `./bootstrap --overlay work stow` re-links the public and the work config together.

## Layout

| Path             | Target          | Contents                                           |
| ---------------- | --------------- | -------------------------------------------------- |
| `dot-zshenv`     | `~/.zshenv`     | Sets `ZDOTDIR` and hands off to `dot-config/zsh/`. |
| `dot-config/`    | `~/.config/`    | Tool config, one directory per tool.               |
| `dot-local/bin/` | `~/.local/bin/` | Scripts on `PATH`.                                 |
| `dot-ssh/`       | `~/.ssh/`       | SSH client config.                                 |
| `bootstrap`      | not stowed      | The installer.                                     |
| `macos/defaults` | not stowed      | The `defaults write` calls.                        |
| `docs/`          | not stowed      | Cheat sheets.                                      |

`.stow-local-ignore` lists the paths that stow skips.

## Conventions

**Filenames.** Stow runs with `--dotfiles`, so a `dot-` prefix in the repository becomes a leading `.` in the target. `dot-config/git/config` links to `~/.config/git/config`.

**Login shell.** Zsh, the macOS default. The one-line `dot-zshenv` at home sets `ZDOTDIR`, so the rest of the zsh config lives under `~/.config/zsh`.

**XDG.** `dot-config/zsh/dot-zshenv` exports the XDG variables. Every zsh reads that file, interactive or not. The same file moves tool state directories (npm, bundler, Go, Terraform) out of `~/`.

**Scripts.** `dot-local/bin` stows to `~/.local/bin`, which `.zprofile` puts first on `PATH`. A command that you type starts with a comma (`,cr`). A helper that only key bindings and other scripts call has a plain name (`fzf-jump-targets`, `tmux-sessionizer`). Every script answers `--help`.

**Services.** Long-lived tools start through `brew services` in the `services` step, after stow puts their config in place.

## Docs

- [STOW.md](docs/STOW.md) - how stow makes the symlinks, and how to add one by hand
- [TMUX.md](docs/TMUX.md) - sessions, windows, panes, and the Ghostty viewport model
- [ZSH-SHORTCUTS.md](docs/ZSH-SHORTCUTS.md) - fzf pickers, autosuggestions, and vi mode
- [AEROSPACE-SHORTCUTS.md](docs/AEROSPACE-SHORTCUTS.md) - tiling bindings and service mode
- [MACOS-SHORTCUTS.md](docs/MACOS-SHORTCUTS.md) - native window, desktop, and app shortcuts
