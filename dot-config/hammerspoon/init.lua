require("hs.ipc")

local configDir = hs.configdir

-- Theme watcher: detect macOS dark/light mode changes,
-- write theme file for external consumers, and update Terminal.app colors.

local THEME_FILE = configDir .. "/state/theme"
local COLORS_FILE = configDir .. "/theme-colors.json"

local function readColorsConfig()
    local f = io.open(COLORS_FILE, "r")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    return hs.json.decode(data)
end

local function colorLiteral(rgb)
    -- Terminal.app uses 16-bit RGB (0–65535); config uses 8-bit (0–255)
    return string.format("{%d, %d, %d}", rgb[1] * 257, rgb[2] * 257, rgb[3] * 257)
end

local function applyTerminalColors(colors)
    local props = {
        "set background color to " .. colorLiteral(colors.backgroundColor),
        "set normal text color to " .. colorLiteral(colors.normalTextColor),
        "set bold text color to " .. colorLiteral(colors.boldTextColor),
        "set cursor color to " .. colorLiteral(colors.cursorColor),
    }
    local block = table.concat(props, "\n            ")

    local script = string.format([[
        tell application "Terminal"
            tell default settings
                %s
            end tell
            repeat with w in windows
                repeat with t in tabs of w
                    tell current settings of t
                        %s
                    end tell
                end repeat
            end repeat
        end tell
    ]], block, block)

    hs.osascript.applescript(script)
end

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

local function currentlyDark()
    return hs.host.interfaceStyle() == "Dark"
end

local function applyTheme()
    local isDark = currentlyDark()
    local theme = isDark and "dark" or "light"
    writeThemeFile(theme)

    local config = readColorsConfig()
    if config and config[theme] then
        applyTerminalColors(config[theme])
    end
end

-- Apply immediately on load
applyTheme()

-- Watch for system appearance changes
-- Must keep a reference to prevent garbage collection
themeWatcher = hs.distributednotifications.new(function()
    applyTheme()
end, "AppleInterfaceThemeChangedNotification"):start()

-- Trackpad swipe: 2-finger horizontal swipe switches tmux windows in Terminal.app

local swipe = hs.loadSpoon("Swipe")

local TMUX = "/opt/homebrew/bin/tmux"
local TERMINAL_BUNDLE_ID = "com.apple.Terminal"
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
