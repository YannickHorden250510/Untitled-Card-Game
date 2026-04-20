local scaling = require("lib.scaling")

local ui = {}

local fonts = {}

function ui.loadFont(name, path, size)
    fonts[name] = love.graphics.newFont(path, size)
end

function ui.getFont(name)
    return fonts[name]
end

function ui.setFont(name)
    love.graphics.setFont(fonts[name])
end

function ui.pointInRect(px, py, rect)
    return px >= rect.x and px <= rect.x + rect.w
       and py >= rect.y and py <= rect.y + rect.h
end

function ui.makeButton(text, x, y, opts)
    opts = opts or {}
    local font = opts.font and fonts[opts.font] or love.graphics.getFont()
    local padding = opts.padding or 8

    return {
        text = text,
        x = x,
        y = y,
        w = font:getWidth(text) + padding * 2,
        h = font:getHeight() + padding * 2,
        padding = padding,
        font = font,
        color = opts.color or {0.2, 0.2, 0.2, 0.8},
        textColor = opts.textColor or {1, 1, 1, 1},
        cornerRadius = opts.cornerRadius or 4,
        scale = 1,
        rotation = 0,
        hovered = false
    }
end

function ui.drawButton(btn)
    local cx = btn.x + btn.w / 2
    local cy = btn.y + btn.h / 2

    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(btn.rotation)
    love.graphics.scale(btn.scale)
    love.graphics.translate(-cx, -cy)

    love.graphics.setColor(btn.color)
    love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, btn.cornerRadius, btn.cornerRadius)
    love.graphics.setColor(btn.textColor)
    love.graphics.setFont(btn.font)
    love.graphics.print(btn.text, btn.x + btn.padding, btn.y + btn.padding)

    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

function ui.updateButtonHover(btn, animation)
    if not btn then return end
    local mx, my = love.mouse.getPosition()
    local gx, gy = scaling.screenToGame(mx, my)
    local isHovered = ui.pointInRect(gx, gy, btn)

    if isHovered and not btn.hovered then
        btn.hovered = true
        animation.slideTo(btn, 0.3, nil, nil, "backout")
        animation.hoverIn(btn)
    elseif not isHovered and btn.hovered then
        btn.hovered = false
        animation.hoverOut(btn)
    end
end

function ui.makePanel(w, h, opts)
    opts = opts or {}
    return {
        x = (scaling.getWidth() - w) / 2,
        y = scaling.getHeight(),
        w = w,
        h = h,
        color = opts.color or {0.1, 0.1, 0.1, 0.9},
        cornerRadius = opts.cornerRadius or 8,
        open = false
    }
end

function ui.drawPanel(panel)
    love.graphics.setColor(panel.color)
    love.graphics.rectangle("fill", panel.x, panel.y, panel.w, panel.h, panel.cornerRadius, panel.cornerRadius)
    love.graphics.setColor(1, 1, 1, 1)
end

function ui.togglePanel(panel, animation)
    panel.open = not panel.open
    local targetY = panel.open and (scaling.getHeight() - panel.h) / 2 or scaling.getHeight()
    animation.slideTo(panel, 0.4, nil, targetY)
end

function ui.drawText(text, x, y, fontName, color)
    if fontName then ui.setFont(fontName) end
    love.graphics.setColor(color or {1, 1, 1, 1})
    love.graphics.print(text, x, y)
    love.graphics.setColor(1, 1, 1, 1)
end

function ui.drawTextCentered(text, y, fontName, color)
    local font = fontName and fonts[fontName] or love.graphics.getFont()
    local tw = font:getWidth(text)
    if fontName then ui.setFont(fontName) end
    love.graphics.setColor(color or {1, 1, 1, 1})
    love.graphics.print(text, (scaling.getWidth() - tw) / 2, y)
    love.graphics.setColor(1, 1, 1, 1)
end

return ui
