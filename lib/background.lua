local scaling = require("lib.scaling")

local background = {}

local backgrounds = {}
local currentBg = nil
local offsetX, offsetY = 0, 0
local speed = 50

function background.load(name, path)
    local img = love.graphics.newImage(path)
    img:setWrap("repeat", "repeat")
    backgrounds[name] = img
    if not currentBg then
        currentBg = name
    end
end

function background.set(name)
    currentBg = name
end

function background.setSpeed(s)
    speed = s
end

function background.update(dt)
    local img = backgrounds[currentBg]
    if not img then return end
    local iw, ih = img:getDimensions()
    offsetX = (offsetX + speed * dt) % iw
    offsetY = (offsetY + speed * dt) % ih
end

function background.draw()
    local img = backgrounds[currentBg]
    if not img then return end
    local iw, ih = img:getDimensions()
    local gw, gh = scaling.getWidth(), scaling.getHeight()

    love.graphics.setColor(1, 1, 1, 1)
    for x = -iw, gw, iw do
        for y = -ih, gh, ih do
            love.graphics.draw(img, x + offsetX, y + offsetY)
        end
    end
end

function background.getCurrent()
    return currentBg
end

return background
