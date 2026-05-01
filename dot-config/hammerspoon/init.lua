require("hs.ipc")

local TMUX = "/opt/homebrew/bin/tmux"

-- tmux bell router: callable via `hs -c "tmuxBell(session, window, pane_title)"`
-- from the alert-bell hook in tmux.conf. Replaces Ghostty's default bell
-- notification (which has no session context and no useful click target)
-- with a clickable notification that switches the tmux client to the
-- session/window that belled. Notifications for the currently-focused
-- window are suppressed so only background sessions page the user.
local tmuxBellNotifs = {}

function tmuxBell(session, window, paneTitle)
    local target = session .. ":" .. window

    -- Suppress only when the user is literally staring at the belling window.
    -- Three conditions must hold: (a) Ghostty is the frontmost macOS app,
    -- (b) the focused Ghostty window's title prefix matches the belling
    -- session (one tmux client per Ghostty window, titles set via tmux's
    -- set-titles-string "#S / #W"), and (c) that session's client is on the
    -- belling window. Anything else - different app focused, different
    -- Ghostty window focused, different tmux window within the right session
    -- - means the user can't see the bell, so we should notify.
    --
    -- hs.execute notes:
    --   * Omitting the second arg keeps it on /bin/sh; passing `true` switches
    --     to the user's $SHELL, and `fish -l -i -c` eats `#` as a comment even
    --     inside double quotes, silently truncating tmux format strings.
    --   * `list-clients -t <session>` resolves against concrete attached state
    --     and doesn't suffer the default-target race that `display-message -p`
    --     hits during alert-bell hook context.
    local frontApp = hs.application.frontmostApplication()
    if frontApp and frontApp:bundleID() == "com.mitchellh.ghostty" then
        local fw = frontApp:focusedWindow()
        if fw then
            local title = fw:title() or ""
            local prefix = session .. " / "
            if title:sub(1, #prefix) == prefix then
                local view = (hs.execute(TMUX .. " list-clients -t '" .. session .. "' -F '#{session_name}:#{window_index}'") or "")
                    :match("([^\r\n]+)") or ""
                if view == target then return end
            end
        end
    end

    -- Coalesce: if a prior notification for this target is still pending,
    -- withdraw it so a burst of bells doesn't stack the notification center.
    if tmuxBellNotifs[target] then tmuxBellNotifs[target]:withdraw() end

    local n = hs.notify.new(function()
        -- Multi-Ghostty-window setups have one tmux client per Ghostty window.
        -- Tmux's set-titles-string is "#S / #W", so each Ghostty window's title
        -- starts with its session name. Match on that to raise the right window
        -- rather than focus()-ing whichever Ghostty window happens to be
        -- frontmost, and pin switch-client to that session's own client via -c
        -- so we don't hijack a different Ghostty window's client to another
        -- session.
        local app = hs.application.get("com.mitchellh.ghostty")
        local prefix = session .. " / "
        local sessionWin
        if app then
            for _, w in ipairs(app:allWindows()) do
                local t = w:title() or ""
                if t:sub(1, #prefix) == prefix then sessionWin = w; break end
            end
        end

        if sessionWin then
            local clientTty = (hs.execute(TMUX .. " list-clients -t '" .. session .. "' -F '#{client_tty}'") or "")
                :match("([^\r\n]+)")
            if clientTty and clientTty ~= "" then
                hs.execute(TMUX .. " switch-client -c '" .. clientTty .. "' -t '" .. target .. "'")
            end
            sessionWin:focus()
        else
            hs.execute(TMUX .. " switch-client -t '" .. target .. "'")
            hs.application.launchOrFocus("Ghostty")
        end
        tmuxBellNotifs[target] = nil
    end, {
        title = "tmux: " .. session,
        subTitle = "window " .. window,
        informativeText = paneTitle or "",
        autoWithdraw = true,
        -- Hammerspoon's withdrawAfter only controls its own auto-withdraw
        -- timer; the on-screen persistence is governed by the macOS alert
        -- style (banner vs alert) in System Settings > Notifications >
        -- Hammerspoon. With "Alerts" selected and withdrawAfter=0, the
        -- notification sticks on screen until clicked or dismissed.
        withdrawAfter = 0,
    })
    n:send()
    tmuxBellNotifs[target] = n
end

-- Withdraw any pending bell notification for the given session/window when
-- the user visits it. Called from tmux's after-select-window and
-- client-session-changed hooks so notifications self-clean instead of
-- piling up in Notification Center after the user has already seen the
-- relevant tmux window.
function tmuxClearBell(session, window)
    local target = session .. ":" .. window
    if tmuxBellNotifs[target] then
        tmuxBellNotifs[target]:withdraw()
        tmuxBellNotifs[target] = nil
    end
end

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
local MIN_SWIPE_DISTANCE = 0.05 -- 0.0-1.0, increase for longer swipes
local lastSwipeTime = 0
local lastSwipeId = nil

swipe:start(2, function(direction, distance, id)
    if id == lastSwipeId then return end
    if distance < MIN_SWIPE_DISTANCE then return end
    local now = hs.timer.secondsSinceEpoch()
    if now - lastSwipeTime < DEBOUNCE_SECONDS then return end

    -- After unlock/wake, hs.application.frontmostApplication() can lag the real
    -- window focus until an app-activate notification resyncs it. Fall back to
    -- the focused window's application so swipes work immediately post-login
    -- instead of requiring a manual app switch to "unstick" Hammerspoon's view.
    local app = hs.application.frontmostApplication()
    local bundle = app and app:bundleID()
    if bundle ~= TERMINAL_BUNDLE_ID then
        local fw = hs.window.focusedWindow()
        local fwApp = fw and fw:application()
        bundle = fwApp and fwApp:bundleID()
    end
    if bundle ~= TERMINAL_BUNDLE_ID then return end

    -- Natural-scroll convention: swipe left = next tmux window, right = previous.
    -- 30ms key delay so Ghostty latches the Cmd+Shift modifier flags before
    -- keyUp - with delay=0 the keyUp occasionally raced ahead and Ghostty saw
    -- a bare `[`/`]`, dropping through its keybind and emitting `p`/`n`.
    local key
    if direction == "left" then key = "]"
    elseif direction == "right" then key = "["
    else return end

    lastSwipeId = id
    lastSwipeTime = now
    hs.eventtap.keyStroke({ "cmd", "shift" }, key, 30000)
end)

-- Workspace navigation: Ctrl+Left/Right walks an ordered chain of aerospace
-- workspaces on the focused monitor followed by macOS native fullscreen Spaces
-- on the focused screen. A Safari YouTube fullscreen Space is reachable from
-- the last aerospace workspace and can be left by stepping back the way you
-- came. Requires disabling Ctrl+Left/Right in System Settings > Keyboard >
-- Keyboard Shortcuts > Mission Control (macOS grabs them before Hammerspoon).

local AEROSPACE = "/opt/homebrew/bin/aerospace"

local function aerospaceExec(args)
    local output, status, _, rc = hs.execute(AEROSPACE .. " " .. args)
    if status and rc == 0 and output then return output end
    return nil
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

-- For every aerospace workspace with at least one window in the macOS user
-- Space on `screen`, return the ID of the first such window. Workspaces whose
-- every window lives in a fullscreen Space are omitted: aerospace cannot keep
-- focus on them (it reverts to the user-space MRU window within ~500ms), so
-- pressing Ctrl+Right from ws1 to such a workspace would visually no-op. The
-- returned window ID is what navigateToChainEntry focuses directly, bypassing
-- aerospace's MRU which would otherwise pick a fullscreen sibling (e.g. a
-- Safari YouTube video) and drag macOS into that fullscreen Space.
local function firstUserWindowPerWorkspace(screen)
    local userSpaceId
    for _, sid in ipairs(hs.spaces.spacesForScreen(screen) or {}) do
        if hs.spaces.spaceType(sid) == "user" then userSpaceId = sid; break end
    end
    if not userSpaceId then return {} end

    local userWins = {}
    for _, wid in ipairs(hs.spaces.windowsForSpace(userSpaceId) or {}) do
        userWins[wid] = true
    end

    local out = aerospaceExec("list-windows --all --format '%{workspace} %{window-id}'")
    if not out then return {} end

    local firstWid = {}
    for line in out:gmatch("[^\r\n]+") do
        local ws, widStr = line:match("^(%S+)%s+(%S+)")
        local wid = tonumber(widStr or "")
        if ws and wid and userWins[wid] and not firstWid[ws] then
            firstWid[ws] = wid
        end
    end
    return firstWid
end

-- Build the ordered navigation chain on a given screen. Each entry is one of:
--   { kind = "workspace",  id = "<ws>", wid = <user-Space window id> }
--   { kind = "fullscreen", id = <sid> }
local function buildNavChain(screen)
    local chain = {}

    local out = aerospaceExec("list-workspaces --monitor focused")
    if out then
        local firstWid = firstUserWindowPerWorkspace(screen)
        local workspaces = {}
        local seen = {}
        for ws in out:gmatch("%S+") do
            if firstWid[ws] then
                workspaces[#workspaces + 1] = ws
                seen[ws] = true
            end
        end
        -- Include the focused workspace even when empty, so closing the last
        -- window in it doesn't strand navigation: without this the workspace
        -- isn't in the chain, findCurrentChainIndex returns nil, and the swipe
        -- and Ctrl+arrow handlers become no-ops.
        local focused = aerospaceExec("list-workspaces --focused")
        focused = focused and focused:match("%S+") or nil
        if focused and not seen[focused] then
            workspaces[#workspaces + 1] = focused
        end
        table.sort(workspaces, function(a, b) return tonumber(a) < tonumber(b) end)
        for _, ws in ipairs(workspaces) do
            chain[#chain + 1] = { kind = "workspace", id = ws, wid = firstWid[ws] }
        end
    end

    for _, sid in ipairs(hs.spaces.spacesForScreen(screen) or {}) do
        if hs.spaces.spaceType(sid) == "fullscreen" then
            chain[#chain + 1] = { kind = "fullscreen", id = sid }
        end
    end

    return chain
end

local function findCurrentChainIndex(chain, screen)
    local active = hs.spaces.activeSpaceOnScreen(screen)
    if active and hs.spaces.spaceType(active) == "fullscreen" then
        for i, e in ipairs(chain) do
            if e.kind == "fullscreen" and e.id == active then return i end
        end
        return nil
    end
    local focused = aerospaceExec("list-workspaces --focused")
    if not focused then return nil end
    focused = focused:match("%S+")
    for i, e in ipairs(chain) do
        if e.kind == "workspace" and e.id == focused then return i end
    end
    return nil
end

local function navigateToChainEntry(entry, screen)
    if entry.kind == "fullscreen" then
        hs.spaces.gotoSpace(entry.id)
        return
    end
    -- Aerospace's focus command cannot cross macOS Space boundaries. If we
    -- are in a fullscreen Space, land on the aerospace user Space first so
    -- the subsequent focus call actually moves us.
    local active = hs.spaces.activeSpaceOnScreen(screen)
    if active and hs.spaces.spaceType(active) == "fullscreen" then
        for _, sid in ipairs(hs.spaces.spacesForScreen(screen) or {}) do
            if hs.spaces.spaceType(sid) == "user" then
                hs.spaces.gotoSpace(sid)
                break
            end
        end
    end
    -- Focus a known user-Space window in the workspace rather than running
    -- `aerospace workspace <id>`: the bare switch MRU-picks any fullscreen
    -- Safari video sibling in the same workspace and drags us into its Space.
    -- Empty workspaces have no window to focus, so fall back to the plain
    -- workspace switch - there's no fullscreen sibling to worry about.
    if entry.wid then
        hs.execute(AEROSPACE .. " focus --window-id " .. entry.wid)
    else
        hs.execute(AEROSPACE .. " workspace " .. entry.id)
    end
end

local function navigateWorkspace(direction)
    local screen = getActiveScreen()
    if not screen then return end
    local chain = buildNavChain(screen)
    local currentIdx = findCurrentChainIndex(chain, screen)
    if not currentIdx then return end
    local target = chain[currentIdx + ((direction == "left") and -1 or 1)]
    if target then navigateToChainEntry(target, screen) end
end

workspaceTap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(event)
    -- Ctrl+Left/Right only. Fn is ignored because Apple compact keyboards
    -- set it automatically for arrow keys.
    local flags = event:getFlags()
    if not flags.ctrl or flags.cmd or flags.alt or flags.shift then return false end

    local keyCode = event:getKeyCode()
    local direction = (keyCode == 123 and "left") or (keyCode == 124 and "right") or nil
    if not direction then return false end

    navigateWorkspace(direction)
    return true
end):start()

-- Trackpad swipe: 3-finger horizontal swipe navigates the workspace chain.
-- Natural-scroll convention: swipe left = forward, swipe right = back.
local lastNavSwipeTime = 0
local lastNavSwipeId = nil

swipe:start(3, function(direction, distance, id)
    if id == lastNavSwipeId then return end
    if distance < MIN_SWIPE_DISTANCE then return end
    local now = hs.timer.secondsSinceEpoch()
    if now - lastNavSwipeTime < DEBOUNCE_SECONDS then return end

    local nav
    if direction == "left" then nav = "right"
    elseif direction == "right" then nav = "left"
    else return end

    lastNavSwipeId = id
    lastNavSwipeTime = now
    navigateWorkspace(nav)
end)

-- Trackpad swipe: 4-finger swipe up in Ghostty opens tmux's session/window
-- tree (prefix + s). Sends Ctrl+b followed by s as two sequential keystrokes
-- with a small gap between them, so tmux registers the prefix before the
-- second key arrives. Requires 4-finger vertical swipe to be disabled in
-- macOS (TrackpadFourFingerVertSwipeGesture=0 in macos/defaults), otherwise
-- macOS intercepts the gesture for Mission Control.
local lastTreeSwipeTime = 0
local lastTreeSwipeId = nil

swipe:start(4, function(direction, distance, id)
    if direction ~= "up" then return end
    if id == lastTreeSwipeId then return end
    if distance < MIN_SWIPE_DISTANCE then return end
    local now = hs.timer.secondsSinceEpoch()
    if now - lastTreeSwipeTime < DEBOUNCE_SECONDS then return end

    local app = hs.application.frontmostApplication()
    local bundle = app and app:bundleID()
    if bundle ~= TERMINAL_BUNDLE_ID then
        local fw = hs.window.focusedWindow()
        local fwApp = fw and fw:application()
        bundle = fwApp and fwApp:bundleID()
    end
    if bundle ~= TERMINAL_BUNDLE_ID then return end

    lastTreeSwipeId = id
    lastTreeSwipeTime = now
    hs.eventtap.keyStroke({ "ctrl" }, "b", 30000)
    hs.timer.usleep(20000)
    hs.eventtap.keyStroke({}, "s", 30000)
end)
