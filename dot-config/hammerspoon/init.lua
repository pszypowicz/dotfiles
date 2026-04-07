require("hs.ipc")

local configDir = hs.configdir

-- Theme watcher: detect macOS dark/light mode changes
-- and write theme file for external consumers (e.g. Claude Code auto-theme).

local THEME_FILE = configDir .. "/state/theme"

local function writeThemeFile(theme)
    -- Non-atomic write to preserve inode for fs.watch() listeners
    local dir = THEME_FILE:match("(.+)/[^/]+$")
    hs.fs.mkdir(dir)
    local f = io.open(THEME_FILE, "w")
    if f then
        f:write(theme)
        f:close()
    end
end

local function applyTheme()
    local theme = hs.host.interfaceStyle() == "Dark" and "dark" or "light"
    writeThemeFile(theme)
end

-- Apply immediately on load
applyTheme()

-- Watch for system appearance changes
-- Must keep a reference to prevent garbage collection
themeWatcher = hs.distributednotifications.new(function()
    applyTheme()
end, "AppleInterfaceThemeChangedNotification"):start()

-- Keyboard Viewer: callable via `hs -c "toggleKeyboardViewer()"` (e.g. from sketchybar)
function toggleKeyboardViewer()
    hs.osascript.applescript([[
        tell application "System Events"
            tell process "TextInputMenuAgent"
                click menu bar item 1 of menu bar 2
                click menu item "Show Keyboard Viewer" of menu 1 of menu bar item 1 of menu bar 2
            end tell
        end tell
    ]])
end

-- Trackpad swipe: 2-finger horizontal swipe switches tmux windows in Ghostty

local swipe = hs.loadSpoon("Swipe")

local TMUX = "/opt/homebrew/bin/tmux"
local TERMINAL_BUNDLE_ID = "com.mitchellh.ghostty"
local DEBOUNCE_SECONDS = 0.3
local MIN_SWIPE_DISTANCE = 0.05 -- 0.0–1.0, increase for longer swipes
local lastSwipeTime = 0
local lastSwipeId = nil

swipe:start(2, function(direction, distance, id)
    if id == lastSwipeId then return end
    if distance < MIN_SWIPE_DISTANCE then return end

    local now = hs.timer.secondsSinceEpoch()
    if now - lastSwipeTime < DEBOUNCE_SECONDS then return end

    local app = hs.application.frontmostApplication()
    if not app or app:bundleID() ~= TERMINAL_BUNDLE_ID then return end

    if direction == "right" then
        hs.execute(TMUX .. " next-window")
        lastSwipeId = id
        lastSwipeTime = now
    elseif direction == "left" then
        hs.execute(TMUX .. " previous-window")
        lastSwipeId = id
        lastSwipeTime = now
    end
end)
