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

local TMUX = "/opt/homebrew/bin/tmux"

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

-- Workspace navigation: Ctrl+Left/Right cycles AeroSpace workspaces on the
-- focused monitor. At the edges, switches macOS Spaces instead.
-- Requires disabling Ctrl+Left/Right in System Settings > Keyboard >
-- Keyboard Shortcuts > Mission Control (macOS grabs them before Hammerspoon).

local AEROSPACE = "/opt/homebrew/bin/aerospace"

local function aerospaceExec(args)
    local output, status, _, rc = hs.execute(AEROSPACE .. " " .. args)
    if status and rc == 0 and output then
        return output
    end
    return nil
end

local function getMonitorWorkspaces()
    local output = aerospaceExec("list-workspaces --monitor focused")
    if not output then return {} end
    local workspaces = {}
    for ws in output:gmatch("%S+") do
        workspaces[#workspaces + 1] = ws
    end
    table.sort(workspaces, function(a, b) return tonumber(a) < tonumber(b) end)
    return workspaces
end

local function getFocusedWorkspace()
    local output = aerospaceExec("list-workspaces --focused")
    if not output then return nil end
    return output:match("%S+")
end

local function switchSpace(direction)
    local screen = hs.mouse.getCurrentScreen()
    if not screen then return end
    local spaces = hs.spaces.spacesForScreen(screen)
    local active = hs.spaces.activeSpaceOnScreen(screen)
    if not spaces or not active then return end

    local currentIdx = nil
    for i, sid in ipairs(spaces) do
        if sid == active then currentIdx = i; break end
    end
    if not currentIdx then return end

    local targetIdx = (direction == "left") and (currentIdx - 1) or (currentIdx + 1)
    if targetIdx < 1 or targetIdx > #spaces then return end

    hs.spaces.gotoSpace(spaces[targetIdx])
end

local function navigateWorkspace(direction)
    local workspaces = getMonitorWorkspaces()
    local focused = getFocusedWorkspace()

    if #workspaces == 0 or not focused then
        switchSpace(direction)
        return
    end

    local currentIndex = nil
    for i, ws in ipairs(workspaces) do
        if ws == focused then currentIndex = i; break end
    end
    if not currentIndex then
        switchSpace(direction)
        return
    end

    local targetIndex = (direction == "left") and (currentIndex - 1) or (currentIndex + 1)
    if targetIndex < 1 or targetIndex > #workspaces then
        switchSpace(direction)
        return
    end

    hs.execute(AEROSPACE .. " workspace " .. workspaces[targetIndex])
end

workspaceTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
    local flags = event:getFlags()
    if not flags:containExactly({ "ctrl", "fn" }) then return false end

    local keyCode = event:getKeyCode()
    local direction = (keyCode == 123 and "left") or (keyCode == 124 and "right") or nil
    if not direction then return false end

    navigateWorkspace(direction)
    return true
end):start()

-- Trackpad swipe: 3-finger horizontal swipe navigates workspaces/spaces

local lastNavSwipeTime = 0
local lastNavSwipeId = nil

swipe:start(3, function(direction, distance, id)
    if id == lastNavSwipeId then return end
    if distance < MIN_SWIPE_DISTANCE then return end

    local now = hs.timer.secondsSinceEpoch()
    if now - lastNavSwipeTime < DEBOUNCE_SECONDS then return end

    if direction == "left" then
        navigateWorkspace("right")
        lastNavSwipeId = id
        lastNavSwipeTime = now
    elseif direction == "right" then
        navigateWorkspace("left")
        lastNavSwipeId = id
        lastNavSwipeTime = now
    end
end)
