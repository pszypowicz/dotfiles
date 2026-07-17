require("hs.ipc")

local TMUX = "/opt/homebrew/bin/tmux"

-- Claude Code pager: callable via `hs -c "claudePage(session, window, msg)"`
-- from Claude Code's page hook (claude/hooks/bell.sh). Posts a clickable
-- notification that switches the tmux client to the session/window where
-- Claude is waiting - something a terminal-emitted notification can't do: a
-- Ghostty surface maps to a whole tmux client rather than a tmux window,
-- and escape sequences never reach the emulator while the session has no
-- attached client. Pages for the currently-viewed window are suppressed so
-- only background work pages the user.
local claudePageNotifs = {}

-- Sound played for pages (Claude is waiting on the user).
-- hs.notify.defaultNotificationSound is the macOS default alert sound; any
-- basename from /System/Library/Sounds also works, and nil means silent.
local CLAUDE_PAGE_SOUND = hs.notify.defaultNotificationSound

function claudePage(session, window, msg)
    msg = msg or ""
    local target = session .. ":" .. window

    -- Suppress only when the user is literally staring at the paging window.
    -- Three conditions must hold: (a) Ghostty is the frontmost macOS app,
    -- (b) the focused Ghostty window's title prefix matches the paging
    -- session (one tmux client per Ghostty window, titles set via tmux's
    -- set-titles-string "#S / #W"), and (c) that session's client is on the
    -- paging window. Anything else - different app focused, different
    -- Ghostty window focused, different tmux window within the right session
    -- - means the user can't see Claude waiting, so we should notify.
    --
    -- hs.execute notes:
    --   * Omitting the second arg keeps it on /bin/sh; passing `true` switches
    --     to the user's $SHELL, and `fish -l -i -c` eats `#` as a comment even
    --     inside double quotes, silently truncating tmux format strings.
    --   * `list-clients -t <session>` reads concrete attached state instead
    --     of relying on `display-message -p` picking the right default
    --     client.
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

    -- Coalesce: if a prior page for this target is still pending, withdraw
    -- it so repeated pages don't stack up in Notification Center.
    if claudePageNotifs[target] then claudePageNotifs[target]:withdraw() end

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
            -- No Ghostty window is attached to the paging session - Ghostty
            -- is closed, or open on other sessions only. There is no client
            -- to switch-client, and a fresh Ghostty window would run the
            -- shell's MRU tmux-attach, which lands on whichever session was
            -- last viewed - not necessarily the one that paged. So set the
            -- session's current window directly (select-window works with
            -- zero clients attached) and open a Ghostty window bound straight
            -- to that session with `-e`. `-n` is required: without it `open`
            -- won't pass `-e` to an already-running Ghostty, so when Ghostty
            -- is already up this spawns a second instance - consistent with
            -- the one-tmux-client-per-Ghostty-window model.
            hs.execute(TMUX .. " select-window -t '=" .. target .. "'")
            hs.execute("open -na Ghostty --args -e " .. TMUX .. " attach -t '=" .. session .. "'")
        end
        claudePageNotifs[target] = nil
    end, {
        title = "Claude needs you",
        subTitle = session .. " / window " .. window,
        -- msg carries the reason for the page - the permission prompt text,
        -- or for idle waits an excerpt of Claude's last reply (bell.sh falls
        -- back to the pane title when neither is available).
        informativeText = msg,
        soundName = CLAUDE_PAGE_SOUND,
        autoWithdraw = true,
        -- Hammerspoon's withdrawAfter only controls its own auto-withdraw
        -- timer; the on-screen persistence is governed by the macOS alert
        -- style (banner vs alert) in System Settings > Notifications >
        -- Hammerspoon. With "Alerts" selected and withdrawAfter=0, the
        -- notification sticks on screen until clicked or dismissed.
        withdrawAfter = 0,
    })
    n:send()
    claudePageNotifs[target] = n
end

-- Withdraw any pending page for the given session/window when the user
-- visits it. Called from tmux's after-select-window and
-- client-session-changed hooks so notifications self-clean instead of
-- piling up in Notification Center after the user has already seen the
-- relevant tmux window.
function claudeClearPage(session, window)
    local target = session .. ":" .. window
    if claudePageNotifs[target] then
        claudePageNotifs[target]:withdraw()
        claudePageNotifs[target] = nil
    end
end

-- The tmux-side self-clean hooks can't see macOS-level focus changes: when
-- the user Cmd-Tabs back to a Ghostty window that is already sitting on the
-- paged tmux window, no tmux hook fires and the notification would linger
-- in Notification Center. Watch Ghostty window focus and withdraw any
-- pending page for the focused session's current window. The pending-page
-- guard keeps the common case (no pages outstanding) free of tmux
-- subprocess calls.
local ghosttyPageWf = hs.window.filter.new(function(w)
    local app = w:application()
    return app ~= nil and app:bundleID() == "com.mitchellh.ghostty"
end)
ghosttyPageWf:subscribe(hs.window.filter.windowFocused, function(w)
    -- set-titles-string is "#S / #W"; session names can't contain " / ".
    local session = (w:title() or ""):match("^(.-) / ")
    if not session or session == "" then return end
    local pending = false
    for target in pairs(claudePageNotifs) do
        if target:sub(1, #session + 1) == session .. ":" then
            pending = true
            break
        end
    end
    if not pending then return end
    local view = (hs.execute(TMUX .. " list-clients -t '=" .. session .. "' -F '#{session_name}:#{window_index}'") or "")
        :match("([^\r\n]+)") or ""
    local window = view:match(":(%d+)%s*$")
    if window then claudeClearPage(session, window) end
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

-- Space navigation: Ctrl+Left/Right lives natively in Cyclist
-- (github.com/pszypowicz/cyclist), which walks the native macOS Spaces
-- (desktops and fullscreen) with instant, animation-free switching; its
-- event tap consumes the keys. 3-finger horizontal swipe is macOS's own
-- animated Space switch, left on its default (see macos/defaults).
-- Aerospace workspace switching stays with aerospace's own bindings.
-- Nothing to do here.

-- Pop-up application menu (Ctrl+Alt+Cmd+M, or `hs -c "popupAppMenu()"`):
-- shows the frontmost app's entire menu bar as a contextual menu at the
-- mouse pointer so any menu item can be invoked without traveling to the
-- top of the screen (what the MenuWhere app does). The menu tree is read
-- via accessibility with hs.application:getMenuItems, rebuilt as an
-- hs.menubar menu table, and shown with popupMenu().
--
-- getMenuItems tree shape: the top level is a plain array of menu-bar-item
-- dicts with the Apple menu already filtered out, and AXMenu wrapper
-- elements are flattened to a single nested array, so a submenu's item list
-- is item.AXChildren[1], not item.AXChildren. Attributes that fail to read
-- come back as "" rather than nil, so AXEnabled must be compared to false
-- explicitly.
--
-- Known limitations: menus an app populates on open (Open Recent, Services)
-- can be stale or missing in the AX snapshot; large menu trees take seconds
-- to read and Hammerspoon hitches during the read and while the popup is
-- open (popupMenu blocks); selectMenuItem matches the first title per level,
-- so a duplicate-named sibling is unselectable.

-- Canonical macOS modifier display order.
local MENU_MOD_GLYPHS = { ctrl = "⌃", alt = "⌥", shift = "⇧", cmd = "⌘" }
local MENU_MOD_ORDER = { "ctrl", "alt", "shift", "cmd" }

-- Shortcut display text ("⇧⌘S") for a menu item, or nil if it has none.
-- Rendered into the item title rather than through the menu table's
-- `shortcut` key: hs.menubar installs `shortcut` with an empty modifier
-- mask, which draws no modifier symbol and lets the bare keypress fire the
-- item while the popup is open. AXMenuItemCmdModifiers arrives pre-decoded
-- as a list of modifier names; AXMenuItemCmdChar is empty for keys like
-- ⌫ and ↩, which are exposed as a numeric glyph id instead.
local function menuShortcutText(item)
    local key = item.AXMenuItemCmdChar
    if not key or key == "" then
        local glyph = item.AXMenuItemCmdGlyph
        key = type(glyph) == "number" and hs.application.menuGlyphs[glyph] or nil
    end
    if not key then return nil end
    local mods = ""
    if type(item.AXMenuItemCmdModifiers) == "table" then
        local has = {}
        for _, m in ipairs(item.AXMenuItemCmdModifiers) do has[m] = true end
        for _, m in ipairs(MENU_MOD_ORDER) do
            if has[m] then mods = mods .. MENU_MOD_GLYPHS[m] end
        end
    end
    return mods .. key
end

-- Convert one flattened AXMenu item array into an hs.menubar menu table.
-- `path` holds the ancestor titles starting at the top-level menu title;
-- a clicked leaf replays it through selectMenuItem, which resolves the path
-- against the live menu tree at click time and presses the item.
local function axItemsToMenuTable(items, path, app)
    local out = {}
    for _, it in ipairs(items) do
        local title = it.AXTitle
        if title == nil or title == "" then
            out[#out + 1] = { title = "-" }
        else
            local entry = { title = title }
            if it.AXEnabled == false then entry.disabled = true end
            local mark = it.AXMenuItemMarkChar
            if mark ~= nil and mark ~= "" then
                entry.state = (mark == "-") and "mixed" or "on"
            end
            -- Submenus of disabled items are unreachable in the popup, so
            -- don't waste time building them.
            local sub = not entry.disabled and type(it.AXChildren) == "table"
                and it.AXChildren[1] or nil
            if sub and #sub > 0 then
                local subPath = { table.unpack(path) }
                subPath[#subPath + 1] = title
                entry.menu = axItemsToMenuTable(sub, subPath, app)
            else
                if not entry.disabled then
                    local itemPath = { table.unpack(path) }
                    itemPath[#itemPath + 1] = title
                    entry.fn = function()
                        if app:isRunning() then app:selectMenuItem(itemPath) end
                    end
                end
                -- Em space between title and shortcut; itemPath keeps the raw
                -- title so selectMenuItem still matches.
                local sc = menuShortcutText(it)
                if sc then entry.title = title .. "\u{2003}" .. sc end
            end
            out[#out + 1] = entry
        end
    end
    return out
end

local function menuBarToMenuTable(menus, app)
    local out = {}
    for _, m in ipairs(menus) do
        local items = type(m.AXChildren) == "table" and m.AXChildren[1] or nil
        if m.AXTitle and m.AXTitle ~= "" and items and #items > 0 then
            out[#out + 1] = {
                title = m.AXTitle,
                menu = axItemsToMenuTable(items, { m.AXTitle }, app),
            }
        end
    end
    return out
end

-- One hidden menubar item is reused for every popup. popupMenu() blocks
-- until the menu is dismissed, and the timing of a clicked item's fn
-- relative to popupMenu returning is undocumented, so a create-per-popup
-- item could be deleted before the click lands. The module-level reference
-- also protects the item from garbage collection.
local menuPopup = hs.menubar.new(false)
local menuPopupBusy = false

function popupAppMenu()
    if menuPopupBusy or not menuPopup then return end
    local app = hs.application.frontmostApplication()
    if not app then return end
    -- Capture the pointer before the tree read so the menu opens where the
    -- pointer was at trigger time, not wherever it drifted during a slow read.
    local pos = hs.mouse.absolutePosition()
    menuPopupBusy = true
    -- Async form: the AX walk is deferred to the main queue rather than
    -- backgrounded, but the trigger callback returns immediately instead of
    -- stalling inside it. The busy flag stops a second trigger from starting
    -- a parallel read.
    app:getMenuItems(function(menus)
        menuPopupBusy = false
        if not menus or #menus == 0 then
            -- nil also covers missing Accessibility permission.
            hs.alert.show("No menus for " .. (app:name() or "app"))
            return
        end
        menuPopup:setMenu(menuBarToMenuTable(menus, app))
        menuPopup:popupMenu(pos)
    end)
end

hs.hotkey.bind({ "ctrl", "alt", "cmd" }, "m", popupAppMenu)
