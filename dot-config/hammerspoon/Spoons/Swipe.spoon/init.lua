local Swipe           = {}
Swipe.__index         = Swipe

-- Metadata
Swipe.name            = "Swipe"
Swipe.version         = "0.2"
Swipe.author          = "Michael Mogenson"
Swipe.homepage        = "https://github.com/mogenson/Swipe.spoon"
Swipe.license         = "MIT - https://opensource.org/licenses/MIT"

local gesture <const> = hs.eventtap.event.types.gesture
local doAfter <const> = hs.timer.doAfter

-- Per-finger-count touch cache

local CacheMT = {}
CacheMT.__index = CacheMT

function CacheMT:clear()
    self.touches = {}
    self.size = 0
    self.direction = nil
    self.distance = 0
end

function CacheMT:none(touches)
    local absent = true
    for _, touch in ipairs(touches) do
        absent = absent and (self.touches[touch.identity] == nil)
    end
    return absent
end

function CacheMT:all(touches)
    local present = true
    for _, touch in ipairs(touches) do
        present = present and (self.touches[touch.identity] ~= nil)
    end
    return present
end

function CacheMT:set(touches)
    self:clear()
    for i, touch in ipairs(touches) do
        self.touches[touch.identity] = {
            x = touch.normalizedPosition.x,
            y = touch.normalizedPosition.y,
            dx = 0,
            dy = 0,
        }
        self.size = i
    end
    self.id = self.id + 1
    return self.id
end

function CacheMT:detect(touches)
    local left, right, up, down = true, true, true, true
    local distance = { dx = 0, dy = 0 }
    local size = 0
    for i, touch in ipairs(touches) do
        local id = touch.identity
        local x, y = touch.normalizedPosition.x, touch.normalizedPosition.y
        local dx, dy = x - assert(self.touches[id]).x, y - assert(self.touches[id]).y
        local abs_dx, abs_dy = math.abs(dx), math.abs(dy)
        local moved = (touch.phase == "moved")

        left = left and moved and (dx < 0) and (abs_dx > abs_dy)
        right = right and moved and (dx > 0) and (abs_dx > abs_dy)
        up = up and moved and (dy > 0) and (abs_dy > abs_dx)
        down = down and moved and (dy < 0) and (abs_dy > abs_dx)

        distance = { dx = distance.dx + dx, dy = distance.dy + dy }
        self.touches[id] = { x = x, y = y, dx = dx, dy = dy }
        size = i
    end

    assert(self.size == size)
    distance = { dx = distance.dx / size, dy = distance.dy / size }

    local direction = nil
    if left and not (right or up or down) then
        direction = "left"
        if self.direction == direction then self.distance = self.distance - distance.dx end
    elseif right and not (left or up or down) then
        direction = "right"
        if self.direction == direction then self.distance = self.distance + distance.dx end
    elseif up and not (left or right or down) then
        direction = "up"
        if self.direction == direction then self.distance = self.distance + distance.dy end
    elseif down and not (left or right or up) then
        direction = "down"
        if self.direction == direction then self.distance = self.distance - distance.dy end
    end

    if direction and (self.direction ~= direction) then
        self.direction = direction
        self.distance = 0
    end

    return direction, self.distance, self.id
end

local function newCache()
    return setmetatable({ id = 1, direction = nil, distance = 0, size = 0, touches = {} }, CacheMT)
end

-- fingers: number of fingers for swipe (must be at least 2)
-- callback: function(direction, distance, id) end
--           direction is a string, either "left", "right", "up", "down"
--           distance is accumulated distance for swipe, between 0.0 and 1.0
--           id is a unique integer across callbacks for the same swipe
-- Can be called multiple times with different finger counts.
function Swipe:start(fingers, callback)
    assert(fingers > 1)
    assert(callback)

    if not self._handlers then
        self._handlers = {}
        self._caches = {}
    end

    self._handlers[fingers] = callback
    self._caches[fingers] = newCache()

    -- (Re)create a single eventtap that dispatches by finger count
    if self.watcher then self.watcher:stop() end

    local handlers = self._handlers
    local caches = self._caches

    self.watcher = hs.eventtap.new({ gesture }, function(event)
        if event:getType(true) ~= gesture then return end
        local touches = event:getTouches()
        local n = #touches
        local cache = caches[n]
        local handler = handlers[n]
        if not cache or not handler then return end

        if cache:none(touches) then
            cache:set(touches)
        elseif cache:all(touches) then
            local direction, distance, id = cache:detect(touches)
            if direction then
                doAfter(0, function() handler(direction, distance, id) end)
            end
        end
    end)

    self.watcher:start()
end

function Swipe:stop()
    if self.watcher then
        self.watcher:stop()
        self.watcher = nil
    end
    self._handlers = nil
    self._caches = nil
end

return Swipe
