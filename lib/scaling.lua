local scaling = {}

local game_w, game_h = 1280, 720
local scale = 1
local offsetX, offsetY = 0, 0

function scaling.init(w, h)
    game_w = w or 1280
    game_h = h or 720
    love.window.setMode(game_w, game_h, {resizable = true, minwidth = 640, minheight = 360})
    scaling.update()
end

function scaling.update()
    local w, h = love.graphics.getDimensions()
    scale = math.min(w / game_w, h / game_h)
    offsetX = (w - game_w * scale) / 2
    offsetY = (h - game_h * scale) / 2
end

function scaling.screenToGame(x, y)
    return (x - offsetX) / scale, (y - offsetY) / scale
end

function scaling.beginDraw()
    love.graphics.clear(0, 0, 0)
    love.graphics.setScissor(offsetX, offsetY, game_w * scale, game_h * scale)
    love.graphics.translate(offsetX, offsetY)
    love.graphics.scale(scale)
end

function scaling.endDraw()
    love.graphics.setScissor()
end

function scaling.getWidth()
    return game_w
end

function scaling.getHeight()
    return game_h
end

function scaling.getScale()
    return scale
end

function scaling.getOffset()
    return offsetX, offsetY
end

return scaling
