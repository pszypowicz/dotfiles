# Stow setup

How the files in this repository become symlinks in the home directory.

## The command

`./bootstrap stow` wraps this invocation. The raw form stays here for reference, and for a stow run from a different checkout.

```bash
stow -d ~/Developer/github.com/pszypowicz -t ~ dotfiles --dotfiles --restow --no-folding
```

| Flag                                   | What it does                                                                                                                                                                                                           |
| -------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `-d ~/Developer/github.com/pszypowicz` | Sets the stow directory, the parent that holds the package. Overlay packages sit beside this repository under the same parent, so one stow directory serves both. `bootstrap` derives this path from its own location. |
| `-t ~`                                 | Sets the target directory.                                                                                                                                                                                             |
| `--dotfiles`                           | Translates a `dot-` prefix in the package into a leading `.` in the target.                                                                                                                                            |
| `--restow`                             | Unstows the package first, then stows it again. This clears links that point at renamed or deleted files.                                                                                                              |
| `--no-folding`                         | Creates every package subdirectory as a real directory in the target, then links the files one by one.                                                                                                                 |

## Why `--no-folding`

Without the flag, stow collapses a whole subtree into a single directory symlink. That breaks any config directory where the tool writes live state next to the tracked files.

Claude Code is the clear case. It writes `history.jsonl`, `projects/`, and caches into `~/.config/claude`. Through a folded directory symlink, those writes land inside the git repository. With a real directory, they stay local.

The flag also carries an invariant for the repository. Whatever exists on disk in a package is tracked, and is meant to be stowed. `.gitignore` and `git clean -fdX` keep untracked files out.

## Relative links

Stow creates relative symlinks. It resolves them from the parent directory of the link. To add a single file without a full re-stow, use the same relative form:

```bash
ln -s ../../Developer/github.com/pszypowicz/dotfiles/dot-config/claude/statusline.sh ~/.config/claude/statusline.sh
```

## Add a new config

1. Put the file in the package under its `dot-` name, for example `dot-config/htop/htoprc`.
2. Run `./bootstrap stow`.
3. Confirm the link with `ls -l ~/.config/htop/htoprc`.

## What stow skips

`.stow-local-ignore` holds the ignore list. It covers the git metadata and the repository-root paths that belong to no package: `README.md`, `docs/`, `bootstrap`, `macos/`, and `.claude/`.

## Conflicts

Stow refuses to link over a real file that already exists in the target. The error names the path. Read that file, then either delete it or move it aside, and run `./bootstrap stow` again.

A service that writes its own config causes this. Colima is the example. On its first start it adds an `Include` line to `~/.ssh/config`, and it creates that file when the file is absent.

A Brewfile entry with `start_service: true` runs inside the `brew` step, before stow. The plain file that colima leaves behind then blocks the stow step. Colima therefore starts in the `services` step, after stow puts the ssh config in place. The stowed config already carries the `Include` line.
