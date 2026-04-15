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

-- Trackpad swipe: 2-finger horizontal swipe switches tmux windows in Ghostty.
-- Synthesizes the same Cmd+Shift+[ / Cmd+Shift+] chord that Ghostty's keybind
-- uses, so the keystroke is delivered to the focused Ghostty client and tmux
-- operates on that client's session unambiguously. Shelling out to `tmux
-- next-window` instead would let tmux's "most recently used client" heuristic
-- pick a different session (e.g. the stashed `bg` session) and jump windows
-- out of order.

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

    -- 30 ms delay between keyDown and keyUp so Ghostty has time to latch the
    -- Cmd+Shift modifier flags before the key is released. With delay=0 the
    -- keyUp occasionally raced ahead of the flags and Ghostty saw an
    -- unmodified `[`/`]`, dropping through its keybind and emitting a bare
    -- `p`/`n` into the shell.
    if direction == "right" then
        hs.eventtap.keyStroke({ "cmd", "shift" }, "[", 30000)
        lastSwipeId = id
        lastSwipeTime = now
    elseif direction == "left" then
        hs.eventtap.keyStroke({ "cmd", "shift" }, "]", 30000)
        lastSwipeId = id
        lastSwipeTime = now
    end
end)

-- Workspace navigation: Ctrl+Left/Right walks an ordered chain of AeroSpace
-- workspaces followed by macOS native fullscreen spaces on the focused
-- monitor, so a Safari YouTube-fullscreen space is reachable from the last
-- aerospace workspace and can be left by stepping back the way you came.
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

-- Prefer the focused window's screen, then mouse screen, then main. During
-- native fullscreen video the cursor auto-hides and hs.mouse.getCurrentScreen()
-- can return a stale/wrong display.
local function getActiveScreen()
    local fw = hs.window.focusedWindow()
    if fw then
        local s = fw:screen()
        if s then return s end
    end
    return hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
end

-- Analyse aerospace workspaces against macOS fullscreen spaces.
--
-- Returns two tables:
--   blocked         - set of workspace IDs whose *every* window lives in a
--                     macOS fullscreen-typed space. These workspaces should be
--                     skipped during Ctrl+Arrow navigation, because aerospace
--                     activating them would focus a fullscreen-space window
--                     and macOS would transition into that space, trapping us.
--   visitableWindow - map of workspace ID -> one aerospace window-id in that
--                     workspace that is NOT in a fullscreen space. When set,
--                     navigation should prefer `aerospace focus --window-id N`
--                     over `aerospace workspace N`, so that mixed workspaces
--                     (e.g. one fullscreen Safari + one normal Safari) don't
--                     accidentally focus the fullscreen window.
--
-- Note: we deliberately do NOT use hs.window.get() or hs.spaces.windowSpaces()
-- here. Those APIs don't return fullscreen-space info for windows that are in
-- them. The reliable direction is inverse: ask each fullscreen-typed space
-- which window-ids it contains via hs.spaces.windowsForSpace(), and cross-
-- reference with aerospace's full window list.
local function getWorkspaceNavInfo()
    local blocked = {}
    local visitableWindow = {}

    -- Collect window IDs currently residing in any fullscreen space across
    -- all screens. macOS fullscreen spaces span displays when "Displays have
    -- separate Spaces" is off, so we iterate all screens just to be safe.
    local fsWins = {}
    for _, screen in ipairs(hs.screen.allScreens()) do
        local spaces = hs.spaces.spacesForScreen(screen)
        if spaces then
            for _, sid in ipairs(spaces) do
                if hs.spaces.spaceType(sid) == "fullscreen" then
                    local wins = hs.spaces.windowsForSpace(sid)
                    if wins then
                        for _, wid in ipairs(wins) do
                            fsWins[wid] = true
                        end
                    end
                end
            end
        end
    end

    local out = aerospaceExec("list-windows --all --format '%{workspace} %{window-id}'")
    if not out then return blocked, visitableWindow end

    -- Group aerospace windows by workspace, counting total vs. fullscreen-held.
    local perWs = {} -- workspace -> { total, fs, firstVisitable }
    for line in out:gmatch("[^\r\n]+") do
        local ws, widStr = line:match("^(%S+)%s+(%S+)")
        if ws and widStr then
            local wid = tonumber(widStr)
            local entry = perWs[ws] or { total = 0, fs = 0, firstVisitable = nil }
            entry.total = entry.total + 1
            if wid and fsWins[wid] then
                entry.fs = entry.fs + 1
            elseif wid and not entry.firstVisitable then
                entry.firstVisitable = wid
            end
            perWs[ws] = entry
        end
    end

    for ws, e in pairs(perWs) do
        if e.total > 0 and e.total == e.fs then
            blocked[ws] = true
        elseif e.firstVisitable then
            visitableWindow[ws] = e.firstVisitable
        end
    end

    return blocked, visitableWindow
end

-- Navigate to the adjacent macOS space (any type - user, fullscreen, tiled)
-- in the requested direction. This is used both as the aerospace-edge fallback
-- (last workspace + Right = enter the next fullscreen space) and as the
-- in-fullscreen navigator (Ctrl+Left from inside a fullscreen space = hop back
-- to the user space sitting next to it). Does nothing at the absolute edge.
local function switchSpace(direction)
    local screen = getActiveScreen()
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

-- Build the ordered navigation chain for a given screen:
--   1. Aerospace workspaces in sorted order, excluding blocked ones
--   2. macOS fullscreen spaces on that screen, in macOS's space-list order
-- Each entry is a table describing how to navigate to that target.
local function buildNavChain(screen)
    local chain = {}

    local workspaces = getMonitorWorkspaces()
    local blocked, visitableWindow = getWorkspaceNavInfo()
    for _, ws in ipairs(workspaces) do
        if not blocked[ws] then
            chain[#chain + 1] = {
                kind = "aerospace",
                workspace = ws,
                visitableWid = visitableWindow[ws],
            }
        end
    end

    local screenSpaces = hs.spaces.spacesForScreen(screen) or {}
    for _, sid in ipairs(screenSpaces) do
        if hs.spaces.spaceType(sid) == "fullscreen" then
            chain[#chain + 1] = { kind = "macos-fullscreen", spaceId = sid }
        end
    end

    return chain
end

-- Locate the current position in the navigation chain based on the active
-- macOS space and (when in a user space) aerospace's focused workspace.
-- Returns the chain index or nil if unable to resolve.
local function findCurrentChainIndex(chain, screen)
    local active = hs.spaces.activeSpaceOnScreen(screen)
    local activeType = active and hs.spaces.spaceType(active) or nil

    if activeType == "fullscreen" then
        for i, e in ipairs(chain) do
            if e.kind == "macos-fullscreen" and e.spaceId == active then
                return i
            end
        end
    elseif activeType == "user" then
        local focused = getFocusedWorkspace()
        if focused then
            for i, e in ipairs(chain) do
                if e.kind == "aerospace" and e.workspace == focused then
                    return i
                end
            end
        end
    end

    return nil
end

-- All aerospace workspaces share a single macOS user Space on a given screen.
-- Return its space-id so we can drive a macOS-level transition back into it
-- when leaving a fullscreen Space.
local function getAerospaceUserSpaceId(screen)
    local spaces = hs.spaces.spacesForScreen(screen) or {}
    for _, sid in ipairs(spaces) do
        if hs.spaces.spaceType(sid) == "user" then
            return sid
        end
    end
    return nil
end

local function runAerospaceFocus(entry)
    if entry.visitableWid then
        hs.execute(string.format("%s focus --window-id %d", AEROSPACE, entry.visitableWid))
    else
        hs.execute(AEROSPACE .. " workspace " .. entry.workspace)
    end
end

local function navigateToChainEntry(entry, screen)
    if entry.kind == "aerospace" then
        -- If macOS is currently displaying a non-user Space (fullscreen), we
        -- must drive the OS-level transition ourselves before asking aerospace
        -- to focus a workspace. `aerospace workspace N` and
        -- `aerospace focus --window-id N` both return success from inside a
        -- fullscreen Space but do NOT pull macOS out of it - verified against
        -- a Safari YouTube fullscreen - so the user stays trapped.
        -- hs.spaces.gotoSpace _does_ cross the fullscreen boundary, so we run
        -- it first to land back on the aerospace user Space, then let aerospace
        -- focus the intended workspace within it.
        local active = hs.spaces.activeSpaceOnScreen(screen)
        if active and hs.spaces.spaceType(active) ~= "user" then
            local userSpace = getAerospaceUserSpaceId(screen)
            if userSpace then
                hs.spaces.gotoSpace(userSpace)
            end
        end
        runAerospaceFocus(entry)
    elseif entry.kind == "macos-fullscreen" then
        hs.spaces.gotoSpace(entry.spaceId)
    end
end

local function navigateWorkspace(direction)
    local screen = getActiveScreen()
    if not screen then return end

    local chain = buildNavChain(screen)
    local currentIdx = findCurrentChainIndex(chain, screen)

    if not currentIdx then
        -- Could not locate current position in the chain (e.g. aerospace
        -- reports a focused workspace we filtered out as blocked). Fall back
        -- to native macOS space navigation so the user at least has an escape.
        switchSpace(direction)
        return
    end

    local step = (direction == "left") and -1 or 1
    local targetIdx = currentIdx + step
    if targetIdx < 1 or targetIdx > #chain then
        return
    end

    navigateToChainEntry(chain[targetIdx], screen)
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
