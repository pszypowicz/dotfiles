require("hs.ipc")

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
