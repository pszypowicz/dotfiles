require("hs.ipc")

local TMUX = "/opt/homebrew/bin/tmux"

-- tmux bell router: callable via `hs -c "tmuxBell(session, window, pane_title)"`
-- from the alert-bell hook in tmux.conf. Replaces Ghostty's default bell
-- notification (which has no session context and no useful click target)
-- with a clickable notification that switches the tmux client to the
-- session/window that belled. Notifications for the currently-focused
-- window are suppressed so only background sessions page the user.
local tmuxBellNotifs = {}

-- Sound played for "notification" pages (Claude is waiting on the user).
-- hs.notify.defaultNotificationSound is the macOS default alert sound; any
-- basename from /System/Library/Sounds also works, and nil means silent.
local CLAUDE_NOTIFICATION_SOUND = hs.notify.defaultNotificationSound

function tmuxBell(session, window, paneTitle, kind, msg)
    kind = kind or ""
    msg = msg or ""
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
                local view = (hs.execute(TMUX .. " list-clients -t '=" .. session .. "' -F '#{session_name}:#{window_index}'") or "")
                    :match("([^\r\n]+)") or ""
                if view == target then return end
            end
        end
    end

    -- Coalesce: if a prior notification for this target is still pending,
    -- withdraw it so a burst of bells doesn't stack the notification center.
    if tmuxBellNotifs[target] then tmuxBellNotifs[target]:withdraw() end

    -- Appearance varies by who rang the bell. `kind` and `msg` come from the
    -- @claude_bell_kind / @claude_bell_msg pane options set by Claude Code's
    -- bell.sh hook (see tmux.conf).
    --   "notification" - Claude Code is waiting on the user (permission
    --                    prompt or idle). Plays a sound because it needs a
    --                    response; msg carries the reason - for idle waits,
    --                    an excerpt of Claude's last reply.
    --   ""             - a plain terminal bell from any other program;
    --                    rendered exactly as before.
    local title, subTitle, infoText, sound
    if kind == "notification" then
        title = "Claude needs you"
        subTitle = session .. " / window " .. window
        infoText = (msg ~= "" and msg) or paneTitle or ""
        sound = CLAUDE_NOTIFICATION_SOUND
    else
        title = "tmux: " .. session
        subTitle = "window " .. window
        infoText = paneTitle or ""
        sound = nil
    end

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
            local clientTty = (hs.execute(TMUX .. " list-clients -t '=" .. session .. "' -F '#{client_tty}'") or "")
                :match("([^\r\n]+)")
            if clientTty and clientTty ~= "" then
                hs.execute(TMUX .. " switch-client -c '" .. clientTty .. "' -t '=" .. target .. "'")
            end
            sessionWin:focus()
        else
            -- No Ghostty window is attached to the belling session - Ghostty
            -- is closed, or open on other sessions only. There is no client
            -- to switch-client, and a fresh Ghostty window would run the
            -- shell's MRU tmux-attach, which lands on whichever session was
            -- last viewed - not necessarily the one that belled. So set the
            -- session's current window directly (select-window works with
            -- zero clients attached) and open a Ghostty window bound straight
            -- to that session with `-e`. `-n` is required: without it `open`
            -- won't pass `-e` to an already-running Ghostty, so when Ghostty
            -- is already up this spawns a second instance - consistent with
            -- the one-tmux-client-per-Ghostty-window model.
            hs.execute(TMUX .. " select-window -t '=" .. target .. "'")
            hs.execute("open -na Ghostty --args -e " .. TMUX .. " attach -t '=" .. session .. "'")
        end
        tmuxBellNotifs[target] = nil
    end, {
        title = title,
        subTitle = subTitle,
        informativeText = infoText,
        soundName = sound,
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

-- The tmux-side self-clean hooks can't see macOS-level focus changes: when
-- the user Cmd-Tabs back to a Ghostty window that is already sitting on the
-- belled tmux window, no tmux hook fires and the notification would linger
-- in Notification Center. Watch Ghostty window focus and withdraw any
-- pending notification for the focused session's current window. The
-- pending-notification guard keeps the common case (no bells outstanding)
-- free of tmux subprocess calls.
local ghosttyBellWf = hs.window.filter.new(function(w)
    local app = w:application()
    return app ~= nil and app:bundleID() == "com.mitchellh.ghostty"
end)
ghosttyBellWf:subscribe(hs.window.filter.windowFocused, function(w)
    -- set-titles-string is "#S / #W"; session names can't contain " / ".
    local session = (w:title() or ""):match("^(.-) / ")
    if not session or session == "" then return end
    local pending = false
    for target in pairs(tmuxBellNotifs) do
        if target:sub(1, #session + 1) == session .. ":" then
            pending = true
            break
        end
    end
    if not pending then return end
    local view = (hs.execute(TMUX .. " list-clients -t '=" .. session .. "' -F '#{session_name}:#{window_index}'") or "")
        :match("([^\r\n]+)") or ""
    local window = view:match(":(%d+)%s*$")
    if window then tmuxClearBell(session, window) end
end)

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

-- Workspace navigation (Ctrl+Left/Right, 3-finger horizontal swipe) lives
-- natively in Cyclist (github.com/pszypowicz/cyclist): it walks aerospace
-- workspaces followed by native fullscreen Spaces with instant, animation-
-- free switching. Nothing to do here - Cyclist's own event tap consumes the
-- keys and reads the trackpad touches directly.

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
