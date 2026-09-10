# macOS keyboard shortcuts

Cheat sheet for the window, desktop, and app shortcuts worth muscle memory. Every binding is a macOS default unless the table says otherwise. The remapped Mission Control bindings live in `macos/defaults`.

## Desktop and windows

| Shortcut         | What it does                                                                           |
| ---------------- | -------------------------------------------------------------------------------------- |
| `F11` / `fn+F11` | **Show Desktop.** Move every window aside to bare the desktop. Press again to restore. |
| `Ctrl+Up`        | Mission Control. Shows an overview of every window and desktop.                        |
| `Ctrl+Down`      | App Exposé. Shows every window of the frontmost app.                                   |
| `Cmd+M`          | Minimize the front window to the Dock.                                                 |
| `Cmd+Opt+M`      | Minimize every window of the front app.                                                |

## Fullscreen

| Shortcut     | What it does                                                        |
| ------------ | ------------------------------------------------------------------- |
| `Ctrl+Cmd+F` | **Native fullscreen.** Moves the app to its own Space. Also `Fn+F`. |

## Hide apps

| Shortcut    | What it does                                                        |
| ----------- | ------------------------------------------------------------------- |
| `Cmd+H`     | **Hide the front app.** The windows vanish and the app stays alive. |
| `Cmd+Opt+H` | Hide every app except the front one.                                |

`Cmd+H` and `Cmd+M` do different things. A hidden window leaves no Dock thumbnail, and `Cmd+Tab` brings it back. A minimized window sits in the Dock as a thumbnail.

## Space switching

| Shortcut             | What it does                                                                   |
| -------------------- | ------------------------------------------------------------------------------ |
| `Ctrl+Left/Right`    | Slide to the previous or next desktop. Cyclist takes these over while it runs. |
| `Ctrl+1` .. `Ctrl+9` | Jump to desktop 1 through 9. Enabled in `macos/defaults`.                      |

## Window drag gesture

`macos/defaults` enables the hidden AppKit preference `NSWindowShouldDragOnGesture`. Hold `Ctrl+Cmd` and drag anywhere inside a window to move it. The title bar is not necessary.

```bash
defaults write NSGlobalDomain NSWindowShouldDragOnGesture -bool true
```

The gesture moves a window and never resizes it. The modifier combination is fixed, and System Settings has no control for it.

An app reads the preference at launch, so relaunch any app that already runs. Windows that AppKit does not draw can ignore the gesture. Some Electron apps and Ghostty with `window-decoration = false` are the examples to expect.
