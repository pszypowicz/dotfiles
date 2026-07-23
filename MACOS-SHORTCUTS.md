# macOS keyboard shortcuts

Cheat sheet for the window, desktop, and app-management shortcuts worth
keeping in muscle memory. Defaults unless noted; the remapped Mission
Control bindings live in `macos/defaults`.

## Desktop and windows

| Shortcut         | What it does                                                                                                                                |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `F11` / `fn+F11` | **Show Desktop.** Moves every window aside to bare the desktop; press again to restore. Keyboard equivalent of the click-wallpaper gesture. |
| `Ctrl+Up`        | Mission Control - overview of every window and desktop.                                                                                     |
| `Ctrl+Down`      | App Exposé - all windows of the frontmost app.                                                                                              |
| `Cmd+M`          | Minimize the front window to the Dock.                                                                                                      |
| `Cmd+Opt+M`      | Minimize all windows of the front app.                                                                                                      |

## Fullscreen

| Shortcut     | What it does                                                                                      |
| ------------ | ------------------------------------------------------------------------------------------------- |
| `Ctrl+Cmd+F` | **macOS-native fullscreen** - moves the app to its own Space. Also `Fn+F`.                        |
| `Opt+F`      | AeroSpace tiling fullscreen - window fills the workspace in place, no new Space (aerospace.toml). |

## Hiding apps

| Shortcut    | What it does                                                                     |
| ----------- | -------------------------------------------------------------------------------- |
| `Cmd+H`     | **Hide the current app.** Windows vanish; app stays running. Cmd+Tab back to it. |
| `Cmd+Opt+H` | Hide every app except the front one.                                             |

Hiding (`Cmd+H`) differs from minimizing (`Cmd+M`): hidden windows leave no
Dock thumbnail and come back with Cmd+Tab, minimized ones sit as thumbnails
in the Dock.

## Space switching

| Shortcut             | What it does                                                             |
| -------------------- | ------------------------------------------------------------------------ |
| `Ctrl+Left/Right`    | Slide to the previous / next desktop. Consumed by Cyclist while it runs. |
| `Ctrl+1` .. `Ctrl+9` | Jump straight to desktop 1-9. Enabled in `macos/defaults`.               |
