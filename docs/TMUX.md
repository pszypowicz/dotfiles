# Tmux session flow

A Ghostty window is a viewport onto a persistent named tmux session. Each new Ghostty window attaches to the most recently used session that no other window shows, so two windows never mirror each other. A closed window detaches its session. Nothing is lost across a Ghostty restart. Only a Mac reboot or an explicit kill ends a session.

## Mental model

- **Session** = a long-lived workspace. The name comes from a project directory (`dotfiles`, `journal-agent`), or it is `scratch` for ad-hoc work.
- **Window** = a tab inside a session. `Cmd+Shift+[` and `Cmd+Shift+]` step through the tabs with no wrap-around. Ghostty owns that binding.
- **Pane** = a split inside a window. `prefix + "` splits below and `prefix + %` splits to the right. Both are tmux defaults.

The titlebar shows `session / window`. That gives the workspace plus the command in the focused pane, for example `nvim` or `zsh`. The status line on the left repeats the session name as an anchor.

## Key bindings

`prefix` is `Ctrl-b`, the tmux default.

| Binding            | What it does                                                                                                                            |
| ------------------ | --------------------------------------------------------------------------------------------------------------------------------------- |
| `prefix + f`       | **Sessionizer.** Opens an fzf popup of project directories. Pick one to switch to it or to create it.                                   |
| `prefix + s`       | Tree view of every session and its windows. Move with hjkl and press enter to switch. A two-finger double-tap in Ghostty does the same. |
| `prefix + L`       | Jump to the previous session. This is the tmux equivalent of `cd -`.                                                                    |
| `prefix + d`       | Detach. With `exec tmux` in `.zshrc` this closes Ghostty too. The session keeps running.                                                |
| `prefix + $`       | Rename the current session.                                                                                                             |
| `prefix + ,`       | Rename the current window.                                                                                                              |
| `prefix + S`       | Stash the current window into a `bg` session, for background tunnels and similar work.                                                  |
| `prefix + r`       | Reload `tmux.conf`.                                                                                                                     |
| `prefix + ^`       | Toggle between the two most recent windows.                                                                                             |
| `prefix + h/j/k/l` | Jump between panes. Repeatable, so keep tapping after one prefix.                                                                       |
| `Ctrl+H/J/K/L`     | Resize the current pane by 5 cells. No prefix.                                                                                          |

## Tasks

### Start from cold

1. Boot the Mac and open Ghostty.
2. zsh finds no `$TMUX` and a fresh tmux server.
3. zsh creates a `scratch` session at `~` and attaches to it.

The titlebar reads `scratch`.

### Switch to a project

1. Press `prefix + f`.
2. Type part of the directory name, for example `dot`.
3. Press enter on `dotfiles`.

The popup lists every git repository under `~/Developer`, the `_scratch` playgrounds, the host containers, `~/` itself, and the visible children of home. Visited directories come first, in zoxide frecency order.

If the session is absent, tmux creates it at the repository root. Either way `switch-client` moves you there, and the titlebar updates. A new session starts vim, tests, and splits at the repository root.

### Hop between two projects

1. Press `prefix + f` and pick the second project.
2. Do the work there.
3. Press `prefix + L` to return.

`prefix + L` toggles between the last two sessions. The first session is intact, with vim still open and the output still on screen.

### Take a break

1. Press `prefix + d`. tmux detaches, `exec` exits, and Ghostty closes.
2. Leave.
3. Open Ghostty again. It lands on the session you used last.

Every session stays alive and detached in the tmux server.

### Open an ad-hoc shell

For work with no project context, such as a look at `/var/log`, pick one option.

- **Option A.** Stay in `scratch`. Press `prefix + f`, accept the default, then `cd /var/log`. A session does not enforce a directory. It only starts there.
- **Option B.** Press `prefix + :` and run `new -s logs -c /var/log`. This creates the session and switches to it.
- **Option C.** From a shell outside tmux, run `tmux new -s logs -c /var/log`.

To drop the session afterwards, run `tmux kill-session -t logs`. An idle session costs almost nothing, so it is also fine to leave it.

### See what runs

Press `prefix + s` for the tree view. It shows every session. Expand a session to see its windows. Move with hjkl, press enter to switch, and press `x` to kill the highlighted item after a confirmation.

### Clean up old sessions

```sh
tmux ls                    # list the sessions with attach state and last-used time
tmux kill-session -t name  # drop one session
tmux kill-server           # end every session
```

Use `tmux kill-server` as a last resort. The command discards the state of every session.

### Run two Ghostty windows

A second Ghostty window attaches to the most recently used session that no other window shows. It never mirrors the first window. If every session is already visible somewhere, Ghostty starts a fresh session at `~`. The result is two windows on two sessions, side by side.

## Where this lives

- `dot-config/zsh/dot-zshrc` - the attach logic at Ghostty start
- `dot-local/bin/tmux-sessionizer` - the fzf picker
- `dot-local/bin/fzf-jump-targets` - the candidate list, shared with the `Alt+C` directory jump
- `dot-config/tmux/tmux.conf` - the `prefix + f` binding, the titlebar format, and the status line
