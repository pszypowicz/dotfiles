require("hs.ipc")

local swipe = hs.loadSpoon("Swipe")

local TMUX = "/opt/homebrew/bin/tmux"
local TERMINAL_BUNDLE_ID = "com.apple.Terminal"
local DEBOUNCE_SECONDS = 0.3
local lastSwipeTime = 0

swipe:start(2, function(direction, distance, id)
    local now = hs.timer.secondsSinceEpoch()
    if now - lastSwipeTime < DEBOUNCE_SECONDS then return end

    local app = hs.application.frontmostApplication()
    if not app or app:bundleID() ~= TERMINAL_BUNDLE_ID then return end

    if direction == "right" then
        hs.execute(TMUX .. " next-window")
        lastSwipeTime = now
    elseif direction == "left" then
        hs.execute(TMUX .. " previous-window")
        lastSwipeTime = now
    end
end)
