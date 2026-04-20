local screen = {}

local current = nil
local screens = {}

function screen.register(name, s)
    screens[name] = s
end

function screen.switch(name, ...)
    if current and current.leave then
        current.leave()
    end
    current = screens[name]
    if current and current.enter then
        current.enter(...)
    end
end

function screen.update(dt)
    if current and current.update then
        current.update(dt)
    end
end

function screen.draw()
    if current and current.draw then
        current.draw()
    end
end

function screen.mousepressed(x, y, button)
    if current and current.mousepressed then
        current.mousepressed(x, y, button)
    end
end

function screen.mousereleased(x, y, button)
    if current and current.mousereleased then
        current.mousereleased(x, y, button)
    end
end

function screen.keypressed(key)
    if current and current.keypressed then
        current.keypressed(key)
    end
end

function screen.keyreleased(key)
    if current and current.keyreleased then
        current.keyreleased(key)
    end
end

function screen.getCurrent()
    return current
end

return screen
