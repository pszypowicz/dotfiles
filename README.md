# Dotfiles

Personal macOS configuration, managed with GNU Stow. One `./bootstrap` run installs the packages, links the configs into `$HOME`, starts the services, writes the macOS defaults, and opens the machine to remote access.

## What is included

| Area              | Tools                                                         |
| ----------------- | ------------------------------------------------------------- |
| Shell             | Zsh with vi keybindings, autosuggestions, syntax highlighting |
| Prompt            | Powerlevel10k                                                 |
| Terminal          | Ghostty, tmux                                                 |
| Window management | AeroSpace (tiling)                                            |
| Status bar        | SketchyBar                                                    |
| Navigation        | fzf, fd, zoxide, ripgrep, lsd, bat                            |
| Remote access     | Remote Login (sshd), mosh                                     |
| Authentication    | Touch ID for sudo                                             |
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

### Requirements

The minimum supported macOS version is 27. The Claude Code idle page summarizes long replies with the on-device Apple Foundation Model through `/usr/bin/fm`, which ships with macOS 27. The command needs a one-time agreement to Apple's terms, and no script can give it. Run this once per machine in a terminal:

```bash
sudo fm license
```

Until then, the page shows a reminder instead of the summary.

### Steps

`./bootstrap` with no arguments runs every step. To repeat one part, pass its name. The steps always run in dependency order, whatever order you type them in.

| Step       | What it does                                                                         |
| ---------- | ------------------------------------------------------------------------------------ |
| `touchid`  | Install `/etc/pam.d/sudo_local` so that sudo accepts Touch ID.                       |
| `brew`     | Install Homebrew if it is absent, then install the Brewfile packages.                |
| `hooks`    | Install this repo's pre-commit hook, which scans staged changes for secrets.         |
| `stow`     | Symlink the configs into the home directory.                                         |
| `codex`    | Install public Codex defaults and hooks with sudo only for missing or changed files. |
| `services` | Start the Homebrew services that need the stowed config (colima, sketchybar).        |
| `npm`      | Install the global npm tools, with the pinned claude-code version.                   |
| `gh`       | Install the gh extensions (gh-stack).                                                |
| `macos`    | Write the macOS preference defaults.                                                 |
| `sharing`  | Turn on Remote Login and stop system sleep on AC power, for ssh and mosh.            |

```bash
./bootstrap stow          # re-link the configs after an edit
./bootstrap codex         # install public Codex defaults
./bootstrap macos         # re-write the macOS defaults after a tweak
./bootstrap brew npm      # refresh the packages and the npm globals
```

`./bootstrap --help` prints the same list.

The `touchid` step installs `etc/pam.d/sudo_local` into `/etc/pam.d/sudo_local`, which adds `pam_tid.so` to the sudo authentication stack.
Sudo then takes a fingerprint, and it falls back to the password after a failed or a canceled touch.
The step compares the file before it calls sudo, so a run that finds the file current asks for no password.
It runs before every other step, which turns their own password prompts into a touch.
Apple Watch cannot answer a sudo prompt. macOS routes watch approval through `pam_localauthentication.so` with the `continuityunlock` argument, and that module needs an authentication context that sudo does not supply.

The `codex` step installs the public configuration and hook scripts from `etc/codex/` into `/etc/codex/`.
It compares each file before calling sudo and skips files whose contents match.
Private settings stay in `$CODEX_HOME/config.toml` and take priority over the public defaults.

The public defaults select high reasoning effort, enable Vim editing and terminal bells, and disable analytics.
The force-push hook refuses recognized shell commands that rewrite branches with open GitHub pull requests.
It also refuses those commands when GitHub cannot return the pull request state.
The guard inspects shell text and does not cover every way to invoke Git.

The formatting hook handles Markdown and Terraform files named in `apply_patch` calls, including multi-file patches, renames, and deletions.
It runs Prettier for Markdown and `terraform fmt` for Terraform.
It runs `terraform-docs` once per affected module with a `.terraform-docs.yml` file.
Missing tools and formatter failures produce a warning without blocking the session.
Edits made through shell commands do not trigger this formatter.

The hooks require Bash, Python 3, jq, and gh. Install Prettier, Terraform, and terraform-docs to enable the corresponding formatters.
Run `python3 -B -m unittest discover -s tests -p 'test_codex.py'` to test the hooks and installer without modifying system files.

### Private overlays

Machine-specific config lives in sibling `dotfiles-private-*` repositories. Each overlay is a plain stow package with a `Brewfile.<name>` and an optional `npm-globals` list. All setup logic stays in this bootstrap.

To include an overlay, name it:

```bash
./bootstrap --overlay personal
```

The brew, stow, and npm steps then cover the overlay too. `--overlay` combines with step names, so `./bootstrap --overlay work stow` re-links the public and the work config together.

## Layout

| Path                      | Target          | Contents                                            |
| ------------------------- | --------------- | --------------------------------------------------- |
| `dot-zshenv`              | `~/.zshenv`     | Sets `ZDOTDIR` and hands off to `dot-config/zsh/`.  |
| `dot-config/`             | `~/.config/`    | Tool config, one directory per tool.                |
| `dot-local/bin/`          | `~/.local/bin/` | Scripts on `PATH`.                                  |
| `dot-ssh/`                | `~/.ssh/`       | SSH client config.                                  |
| `bootstrap`               | not stowed      | The installer.                                      |
| `etc/`                    | not stowed      | Public system configuration installed by bootstrap. |
| `tests/`                  | not stowed      | Automated tests for bootstrap and hooks.            |
| `.pre-commit-config.yaml` | not stowed      | The secret scan that runs before each commit.       |
| `macos/defaults`          | not stowed      | The `defaults write` calls.                         |
| `macos/sharing`           | not stowed      | The Remote Login and AC sleep switches.             |
| `docs/`                   | not stowed      | Cheat sheets.                                       |

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
