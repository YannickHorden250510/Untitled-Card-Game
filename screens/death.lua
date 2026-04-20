local scaling = require("lib.scaling")
local ui = require("lib.ui")
local animation = require("lib.animation")
local background = require("lib.background")
local settingsOverlay = require("lib.settingsoverlay")
local screen = require("lib.screen")

local death = {}

local titleText = "You Died"
local subText = "Out of cards."
local menuBtn
local restartBtn
local settingsUI

function death.enter(context)
    context = context or {}
    titleText = context.title or "You Died"
    subText = context.reason or "Out of cards."

    local gw = scaling.getWidth()
    local menuW = ui.getFont("small"):getWidth("Return to Menu") + 32
    local restartW = ui.getFont("small"):getWidth("Start Over") + 32

    menuBtn = ui.makeButton("Return to Menu", (gw - menuW) / 2, 360, {
        font = "small",
        color = {0.25, 0.25, 0.35, 0.95},
        padding = 16
    })

    restartBtn = ui.makeButton("Start Over", (gw - restartW) / 2, 440, {
        font = "small",
        color = {0.6, 0.25, 0.2, 0.95},
        padding = 16
    })
    settingsUI = settingsOverlay.create({showPreview = false})
end

function death.update(dt)
    background.update(dt)
    if settingsUI then settingsUI.update(dt) end
    ui.updateButtonHover(menuBtn, animation)
    ui.updateButtonHover(restartBtn, animation)
end

function death.draw()
    background.draw()
    ui.drawTextCentered(titleText, 180, "menu")
    ui.drawTextCentered(subText, 260, "small", {0.9, 0.9, 0.9, 1})
    ui.drawButton(menuBtn)
    ui.drawButton(restartBtn)
    if settingsUI then settingsUI.draw() end
end

function death.mousepressed(x, y, button)
    if settingsUI and settingsUI.mousepressed(x, y, button) then
        return
    end
    local gx, gy = scaling.screenToGame(x, y)
    if ui.pointInRect(gx, gy, menuBtn) then
        screen.switch("menu")
    elseif ui.pointInRect(gx, gy, restartBtn) then
        screen.switch("game", {tutorial = false, freshRun = true})
    end
end

function death.mousereleased(x, y, button)
    if settingsUI then settingsUI.mousereleased(x, y, button) end
end

return death
