# AeroSpace keyboard shortcuts

Cheat sheet for the key bindings in `dot-config/aerospace/aerospace.toml`. Every main-mode binding uses `Opt`, which the config calls `alt`.

## Layout

| Shortcut          | What it does                                                                   |
| ----------------- | ------------------------------------------------------------------------------ |
| `Opt+F`           | Tiling fullscreen. The window fills the workspace in place, with no new Space. |
| `Opt+/`           | Tiles layout. Press again to flip the orientation.                             |
| `Opt+,`           | Accordion layout. Press again to flip the orientation.                         |
| `Opt+-` / `Opt+=` | Shrink or grow the focused window in smart 50 px steps.                        |

## Focus and move windows

| Shortcut            | What it does                                                           |
| ------------------- | ---------------------------------------------------------------------- |
| `Opt+H/J/K/L`       | Focus the window to the left, down, up, or right.                      |
| `Opt+Shift+H/J/K/L` | Move the focused window in that direction.                             |
| `Opt+Cmd+H/J/K/L`   | Swap places with the neighbor in that direction. The tree shape holds. |

## Workspaces

| Shortcut         | What it does                                    |
| ---------------- | ----------------------------------------------- |
| `Opt+1` .. `9`   | Jump to workspace 1 through 9.                  |
| `Opt+Shift+1..9` | Send the focused window to that workspace.      |
| `Opt+Tab`        | Toggle between the two most recent workspaces.  |
| `Opt+Shift+Tab`  | Move the current workspace to the next monitor. |

Some apps go to a fixed workspace at launch.

| Workspace | Apps            |
| --------- | --------------- |
| 1         | Ghostty         |
| 2         | Safari          |
| 3         | VS Code         |
| 4         | Teams and Slack |
| 5         | Outlook         |
| 9         | Music           |

Workspaces 1 to 5 stay on the main monitor. Workspace 9 stays on the secondary monitor.

## Service mode

`Opt+Shift+;` enters service mode. SketchyBar tints the workspace icons orange while the mode is active. Every command below returns to main mode on its own.

| Shortcut            | What it does                                        |
| ------------------- | --------------------------------------------------- |
| `Esc`               | Reload the aerospace config and leave service mode. |
| `R`                 | Reset the layout and flatten the workspace tree.    |
| `F`                 | Toggle the focused window between float and tile.   |
| `Backspace`         | Close every window except the current one.          |
| `Opt+Shift+H/J/K/L` | Join with the window in that direction.             |
