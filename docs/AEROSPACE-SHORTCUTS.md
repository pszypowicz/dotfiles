# AeroSpace keyboard shortcuts

Cheat sheet for the bindings in `dot-config/aerospace/aerospace.toml`.
All main-mode bindings use `Opt` (aerospace's `alt`).

## Layout

| Shortcut          | What it does                                                           |
| ----------------- | ---------------------------------------------------------------------- |
| `Opt+F`           | Tiling fullscreen - window fills the workspace in place, no new Space. |
| `Opt+/`           | Tiles layout; press again to flip horizontal/vertical orientation.     |
| `Opt+,`           | Accordion layout; press again to flip orientation.                     |
| `Opt+-` / `Opt+=` | Shrink / grow the focused window (smart resize, 50 px steps).          |

## Focus and move windows

| Shortcut            | What it does                                                               |
| ------------------- | -------------------------------------------------------------------------- |
| `Opt+H/J/K/L`       | Focus window left / down / up / right.                                     |
| `Opt+Shift+H/J/K/L` | Move the focused window in that direction.                                 |
| `Opt+Cmd+H/J/K/L`   | Swap places with the neighbor in that direction (tree shape stays intact). |

## Workspaces

| Shortcut         | What it does                                    |
| ---------------- | ----------------------------------------------- |
| `Opt+1` .. `9`   | Jump to workspace 1-9.                          |
| `Opt+Shift+1..9` | Send the focused window to that workspace.      |
| `Opt+Tab`        | Toggle between the two most recent workspaces.  |
| `Opt+Shift+Tab`  | Move the current workspace to the next monitor. |

Apps auto-assign on launch: 1 Ghostty, 2 Safari, 3 VS Code, 4
Teams/Slack, 5 Outlook, 9 Music. Workspaces 1-5 stick to the main
monitor, 9 to the secondary.

## Service mode

`Opt+Shift+;` enters service mode (workspace icons tint orange in
sketchybar); most commands drop back to main mode on their own, `Esc`
always does.

| Shortcut            | What it does                                        |
| ------------------- | --------------------------------------------------- |
| `Esc`               | Reload the aerospace config and leave service mode. |
| `R`                 | Reset the layout (flatten the workspace tree).      |
| `F`                 | Toggle the focused window floating / tiling.        |
| `Backspace`         | Close every window except the current one.          |
| `Opt+Shift+H/J/K/L` | Join with the window in that direction.             |
