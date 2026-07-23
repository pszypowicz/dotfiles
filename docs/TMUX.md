# Tmux session flow

Ghostty windows are viewports onto persistent named tmux sessions. Each
new Ghostty window attaches to the most recently used session that no
other window is showing, so windows never mirror each other. Closing a
window detaches its session; nothing is lost between Ghostty restarts
unless the Mac reboots or you explicitly kill the session.

## Mental model

- **Session** = a long-lived workspace. Named after a project directory
  (`dotfiles`, `journal-agent`, ...) or `scratch` for ad-hoc work.
- **Window** = a tab inside a session. Cmd+1..9 jumps directly; Cmd+Shift+[
  / Cmd+Shift+] steps like Safari tabs, no wrap-around (configured in
  Ghostty).
- **Pane** = a split inside a window. `prefix + "` splits below,
  `prefix + %` splits to the right (tmux defaults).

The titlebar shows `session / window` - workspace plus what's currently
running in the focused pane (`nvim`, `fish`, etc.). The status-left
shows just the session name as a redundant anchor.

## Key bindings

`prefix` is `Ctrl-b` (tmux default).

| Binding      | What it does                                                                           |
| ------------ | -------------------------------------------------------------------------------------- |
| `prefix + f` | **Sessionizer.** fzf popup of project dirs, pick one to switch-or-create.              |
| `prefix + s` | Tree view of all sessions and their windows. Navigate with hjkl, enter to switch.      |
| `prefix + L` | Jump to the _previous_ session - tmux's `cd -`.                                        |
| `prefix + d` | Detach. With `exec tmux` in fish, this also closes Ghostty. The session keeps running. |
| `prefix + $` | Rename the current session.                                                            |
| `prefix + ,` | Rename the current window.                                                             |
| `prefix + S` | Stash current window into a `bg` session (background tunnels etc).                     |
| `prefix + r` | Reload `tmux.conf`.                                                                    |

## Scenarios

### Cold start

1. Boot Mac, open Ghostty.
2. Fish runs, sees no `$TMUX` and a fresh tmux server, creates a `scratch`
   session at `~` and attaches.
3. You're in. Titlebar reads `scratch`.

### Switch to a project

1. `prefix + f`.
2. fzf popup shows all dirs from `__fzf_jump_targets`: every git repo
   under `~/Developer`, `_scratch` playgrounds, host containers, plus `~/`
   and its visible direct children (Downloads, Documents, ...) - visited
   dirs first, in zoxide frecency order.
3. Type `dot`, hit enter on `dotfiles`.
4. If `dotfiles` session doesn't exist, it's created at the repo root.
5. Either way, `switch-client` moves you there. Titlebar updates.

### Open a brand-new project

Same as above. The first `prefix + f` on a fresh repo creates the session
with cwd at the repo root - vim, tests, splits all start there.

### Hop between two projects

Working on `dotfiles`, need to check something in `journal-agent`:

1. `prefix + f`, pick `journal-agent`. Switch.
2. Look at the thing.
3. `prefix + L` (lowercase L). Back to `dotfiles`, exactly where you left
   it - vim still open, output still on screen.

`prefix + L` toggles between the last two sessions. Two-handed hop.

### Lunch break

1. `prefix + d`. Detaches. `exec` exits. Ghostty closes.
2. Eat.
3. Open Ghostty. Lands back in whichever session you were last on.
   All sessions still running detached in the tmux server.

### Ad-hoc shell for non-project work

You need to poke around `/var/log` or `/etc`, no project context:

- **Option A** - stay in `scratch`. `prefix + f`, pick anything matching
  `_scratch` or just hit enter on the default. `cd /var/log`. Sessions
  don't enforce a directory; they just start there.
- **Option B** - new ad-hoc session via tmux's command prompt:
  `prefix + :` then `new -s logs -c /var/log`. Creates and switches.
- **Option C** - from a fresh shell outside tmux: `tmux new -s logs -c
/var/log`.

When done: `tmux kill-session -t logs` from anywhere, or just leave it -
it costs almost nothing.

### See what's running

`prefix + s` opens a tree view. Shows every session, expand to see
windows, hjkl to move, enter to switch, `x` to kill the highlighted
session/window with confirmation.

### Clean up old sessions

```sh
tmux ls                    # list sessions with attach state and last-used time
tmux kill-session -t name  # drop one
tmux kill-server           # nuke everything (last resort - loses all state)
```

In `prefix + s`, `x` on a session kills it after confirmation. Same effect.

### Two Ghostty windows

A second Ghostty window attaches to the most recently used session that
no other window is showing - never a mirror of the first. If every
session is already visible in some window, it starts a fresh session at
`~` instead. Two windows, two sessions, side by side.

## Where this lives

- `dot-config/fish/config.fish` - the attach logic on Ghostty start.
- `dot-config/fish/functions/__tmux_sessionizer.fish` - the fzf picker.
- `dot-config/fish/functions/__fzf_jump_targets.fish` - the candidate list,
  shared with `Alt+C` directory jump.
- `dot-config/tmux/tmux.conf` - the `prefix + f` binding, titlebar format,
  status-left.
