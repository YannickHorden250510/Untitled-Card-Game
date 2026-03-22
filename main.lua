local flux = require("flux")

io.stdout:setvbuf('no')

local game_w, game_h = 1280, 720
local scale = 1
local offsetX, offsetY = 0, 0

local backgrounds = {}
local currentBackground

local bgOffsetX, bgOffsetY = 0, 0
local bgSpeed = 50

local gameFont

local settingsPanel = {y = game_h}
local settingsOpen = false
local settingsH = 600
local settingsW = 400


function love.load()
    love.window.setMode(game_w, game_h, {resizable = true, minwidth = 640, minheight = 360})

    backgrounds.classic = love.graphics.newImage("assets/backgrounds/ClassicBackground.png")
    backgrounds.art = love.graphics.newImage("assets/backgrounds/ArtDecoBackground.png")
    
    -- sets wrapping for each image in backgrounds 
    for x, bg in pairs(backgrounds) do
        bg:setWrap("repeat", "repeat")
    end
    currentBackground = backgrounds.classic
    
    updateScale()

    gameFont = love.graphics.newFont("assets/fonts/BoldPixels.ttf", 32)
    love.graphics.setFont(gameFont)

    -- load buttons
    settingsBtn = makeButton("Settings", 10, game_h - 64)
end



-- resize utility
function love.resize(w, h)
    updateScale()
end

-- resized screenlocation utility
function screenToGame(x, y)
    return (x - offsetX) / scale, (y - offsetY) / scale
end

-- generic hit utility
function pointInRect(px, py, rect)
    return px >= rect.x and px <= rect.x + rect.w
       and py >= rect.y and py <= rect.y + rect.h
end

-- button size utility
function makeButton(text, x, y, padding)
    padding = padding or 8
    return {
        text = text,
        x = x,
        y = y,
        w = gameFont:getWidth(text) + padding * 2,
        h = gameFont:getHeight() + padding * 2,
        padding = padding,
        scale = 1,
        rotation = 0,
        hovered = false
    }
end

-- button draw utility
function drawButton(btn)
    local cx = btn.x + btn.w / 2
    local cy = btn.y + btn.h / 2
    
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(btn.rotation)
    love.graphics.scale(btn.scale)
    love.graphics.translate(-cx, -cy)
    
    love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
    love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, 4, 4)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(btn.text, btn.x + btn.padding, btn.y + btn.padding)
    
    love.graphics.pop()
end



-- draw settings
function drawSettings()
    local sx = (game_w - settingsW) / 2

    love.graphics.setColor(0.1, 0.1, 0.1, 0.9)
    love.graphics.rectangle("fill", sx, settingsPanel.y, settingsW, settingsH, 8, 8)
    love.graphics.setColor(1, 1, 1, 1)
end



-- update screendimensions
function updateScale()
    local w, h = love.graphics.getDimensions()
    scale = math.min(w / game_w, h / game_h)
    offsetX = (w - game_w * scale) / 2
    offsetY = (h - game_h * scale) / 2
end

-- update hover
function updateButtonHover(btn)
    local mx, my = love.mouse.getPosition()
    local gx, gy = screenToGame(mx, my)
    local isHovered = pointInRect(gx, gy, btn)
    
    if isHovered and not btn.hovered then
        btn.hovered = true
        flux.to(btn, 0.3, {scale = 1.1, rotation = 0.02}):ease("backout")
    elseif not isHovered and btn.hovered then
        btn.hovered = false
        flux.to(btn, 0.3, {scale = 1, rotation = 0}):ease("cubicout")
    end
end



function love.mousepressed(x, y, button)
    local gx, gy = screenToGame(x, y)
    local settingsTargetY = (game_h - settingsH) / 2

    if pointInRect(gx, gy, settingsBtn) then
        settingsOpen = not settingsOpen
        local target = settingsOpen and settingsTargetY or game_h
        flux.to(settingsPanel, 0.4, {y = target}):ease("cubicout")
    end
end



function love.update(dt)
    -- update libraries
    flux.update(dt)

    updateButtonHover(settingsBtn)


    bgOffsetX = bgOffsetX + bgSpeed * dt
    bgOffsetY = bgOffsetY + bgSpeed * dt


end



function love.draw()
    love.graphics.clear(0, 0, 0)
    love.graphics.setScissor(offsetX, offsetY, game_w * scale, game_h * scale)
    
    love.graphics.translate(offsetX, offsetY)
    love.graphics.scale(scale)

    -- background tiling
    local iw, ih = currentBackground:getDimensions()
    bgOffsetX = bgOffsetX % iw
    bgOffsetY = bgOffsetY % ih
    for x = -iw, game_w, iw do
        for y = -ih, game_h, ih do
            love.graphics.draw(currentBackground, x + bgOffsetX, y + bgOffsetY)
        end
    end

    drawButton(settingsBtn)
    drawSettings()
    
    love.graphics.setScissor()
end