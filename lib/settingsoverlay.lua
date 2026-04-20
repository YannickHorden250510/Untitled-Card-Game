local scaling = require("lib.scaling")
local ui = require("lib.ui")
local animation = require("lib.animation")
local background = require("lib.background")
local cards = require("lib.cards")
local audio = require("lib.audio")
local gameconfig = require("lib.gameconfig")

local overlay = {}

local function hit(px, py, x, y, w, h)
    return px >= x and px <= x + w and py >= y and py <= y + h
end

function overlay.create(opts)
    opts = opts or {}
    local panelInset = 24
    local bgOptions = {"classic", "art"}
    local cardOptions = {
        {name = "classic", sheet = "classic", back = "classic"},
        {name = "classicDark", sheet = "classicDark", back = "classicDark"}
    }

    local self = {}
    local settingsBtn
    local settingsPanel
    local bgCycleBtn
    local cardCycleBtn
    local sfxSlider
    local musicSlider
    local speedSlider
    local activeSlider = nil
    local bgIndex = 1
    local cardIndex = 1

    local function sync()
        bgCycleBtn.x = settingsPanel.x + settingsPanel.w - bgCycleBtn.w - panelInset
        bgCycleBtn.y = settingsPanel.y + 72
        cardCycleBtn.x = settingsPanel.x + settingsPanel.w - cardCycleBtn.w - panelInset
        cardCycleBtn.y = settingsPanel.y + 152
        sfxSlider.x = settingsPanel.x + panelInset
        sfxSlider.y = settingsPanel.y + 252
        sfxSlider.w = settingsPanel.w - panelInset * 2
        musicSlider.x = settingsPanel.x + panelInset
        musicSlider.y = settingsPanel.y + 312
        musicSlider.w = settingsPanel.w - panelInset * 2
        speedSlider.x = settingsPanel.x + panelInset
        speedSlider.y = settingsPanel.y + 372
        speedSlider.w = settingsPanel.w - panelInset * 2
    end

    local function sliderPos(slider)
        local t = (slider.get() - slider.min) / (slider.max - slider.min)
        t = math.max(0, math.min(1, t))
        return slider.x + (t * slider.w)
    end

    local function setSliderFromMouse(slider, gx)
        local t = (gx - slider.x) / slider.w
        t = math.max(0, math.min(1, t))
        local raw = slider.min + (slider.max - slider.min) * t
        local snapped = math.floor((raw / slider.step) + 0.5) * slider.step
        snapped = math.max(slider.min, math.min(slider.max, snapped))
        slider.set(snapped)
    end

    local btnX = 20
    local btnY = scaling.getHeight() - 72
    if opts.buttonPosition == "topLeft" then
        btnY = 20
    elseif opts.buttonPosition == "topRight" then
        btnY = 20
    end
    settingsBtn = ui.makeButton("Settings", btnX, btnY, {
        font = "small",
        color = {0.2, 0.2, 0.5, 0.9},
        padding = 16
    })
    if opts.buttonPosition == "topRight" then
        settingsBtn.x = scaling.getWidth() - settingsBtn.w - 20
    end
    settingsPanel = ui.makePanel(620, 560)
    bgCycleBtn = ui.makeButton("Cycle", settingsPanel.x + 230, settingsPanel.y + 72, {
        font = "small",
        color = {0.2, 0.45, 0.6, 0.95},
        padding = 12
    })
    cardCycleBtn = ui.makeButton("Cycle", settingsPanel.x + 230, settingsPanel.y + 152, {
        font = "small",
        color = {0.35, 0.3, 0.6, 0.95},
        padding = 12
    })
    sfxSlider = {min = 0, max = 1, step = 0.05, get = audio.getSfxVolume, set = audio.setSfxVolume, x = 0, y = 0, w = 200, h = 12}
    musicSlider = {min = 0, max = 1, step = 0.05, get = audio.getMusicVolume, set = audio.setMusicVolume, x = 0, y = 0, w = 200, h = 12}
    speedSlider = {min = 0.5, max = 1.5, step = 0.05, get = gameconfig.getGameSpeed, set = gameconfig.setGameSpeed, x = 0, y = 0, w = 200, h = 12}
    sync()

    function self.update(dt)
        sync()
        ui.updateButtonHover(settingsBtn, animation)
        if settingsPanel.open then
            ui.updateButtonHover(bgCycleBtn, animation)
            ui.updateButtonHover(cardCycleBtn, animation)
        end
        if activeSlider then
            local mx, my = love.mouse.getPosition()
            local gx, _ = scaling.screenToGame(mx, my)
            setSliderFromMouse(activeSlider, gx)
        end
    end

    function self.draw()
        ui.drawButton(settingsBtn)
        ui.drawPanel(settingsPanel)
        if not settingsPanel.open then return end
        ui.drawText("Settings", settingsPanel.x + panelInset, settingsPanel.y + 24, "small")
        ui.drawText("Background Theme", settingsPanel.x + panelInset, settingsPanel.y + 82, "small")
        ui.drawText(bgOptions[bgIndex], settingsPanel.x + panelInset, settingsPanel.y + 116, "small", {0.85, 0.95, 1, 1})
        ui.drawButton(bgCycleBtn)
        ui.drawText("Card Theme", settingsPanel.x + panelInset, settingsPanel.y + 162, "small")
        ui.drawText(cardOptions[cardIndex].name, settingsPanel.x + panelInset, settingsPanel.y + 196, "small", {0.92, 0.9, 1, 1})
        ui.drawButton(cardCycleBtn)
        ui.drawText("SFX: " .. tostring(math.floor(audio.getSfxVolume() * 100)) .. "%", sfxSlider.x, sfxSlider.y - 28, "small")
        ui.drawText("Music: " .. tostring(math.floor(audio.getMusicVolume() * 100)) .. "%", musicSlider.x, musicSlider.y - 28, "small")
        ui.drawText("Game Speed: " .. tostring(math.floor(gameconfig.getGameSpeed() * 100)) .. "%", speedSlider.x, speedSlider.y - 28, "small")

        local function drawSlider(slider, color)
            love.graphics.setColor(0.15, 0.15, 0.15, 0.95)
            love.graphics.rectangle("fill", slider.x, slider.y, slider.w, slider.h, 6, 6)
            local knobX = sliderPos(slider)
            love.graphics.setColor(color[1], color[2], color[3], 0.95)
            love.graphics.rectangle("fill", slider.x, slider.y, knobX - slider.x, slider.h, 6, 6)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.circle("fill", knobX, slider.y + slider.h / 2, 10)
        end

        drawSlider(sfxSlider, {0.3, 0.7, 1})
        drawSlider(musicSlider, {0.5, 0.8, 0.9})
        drawSlider(speedSlider, {0.75, 0.85, 0.35})

        if opts.showPreview then
            local previewScale = 2.2
            local frontCard = {type = "aceHearts", suit = "hearts", value = 1, faceUp = true, rotation = 0, scaleX = 1, alpha = 1}
            local backCard = {type = "damage", suit = "spades", value = 6, faceUp = false, rotation = 0, scaleX = 1, alpha = 1}
            local cardW = cards.cardWidth * previewScale
            local previewY = settingsPanel.y + settingsPanel.h - (cards.cardHeight * previewScale) - 24
            local frontX = settingsPanel.x + panelInset
            local backX = frontX + cardW + 18
            cards.draw(frontCard, frontX, previewY, previewScale, true)
            cards.draw(backCard, backX, previewY, previewScale, false)
        end
    end

    function self.mousepressed(x, y, button)
        local gx, gy = scaling.screenToGame(x, y)
        if settingsPanel.open then
            if ui.pointInRect(gx, gy, bgCycleBtn) then
                audio.playSound("uiClick")
                bgIndex = (bgIndex % #bgOptions) + 1
                background.set(bgOptions[bgIndex])
                return true
            elseif ui.pointInRect(gx, gy, cardCycleBtn) then
                audio.playSound("uiClick")
                cardIndex = (cardIndex % #cardOptions) + 1
                cards.setSheet(cardOptions[cardIndex].sheet)
                cards.setBack(cardOptions[cardIndex].back)
                return true
            elseif hit(gx, gy, sfxSlider.x, sfxSlider.y - 8, sfxSlider.w, sfxSlider.h + 16) then
                activeSlider = sfxSlider
                setSliderFromMouse(sfxSlider, gx)
                return true
            elseif hit(gx, gy, musicSlider.x, musicSlider.y - 8, musicSlider.w, musicSlider.h + 16) then
                activeSlider = musicSlider
                setSliderFromMouse(musicSlider, gx)
                return true
            elseif hit(gx, gy, speedSlider.x, speedSlider.y - 8, speedSlider.w, speedSlider.h + 16) then
                activeSlider = speedSlider
                setSliderFromMouse(speedSlider, gx)
                return true
            elseif ui.pointInRect(gx, gy, settingsBtn) or not ui.pointInRect(gx, gy, settingsPanel) then
                audio.playSound("uiClick")
                ui.togglePanel(settingsPanel, animation)
                return true
            end
            return true
        end
        if ui.pointInRect(gx, gy, settingsBtn) then
            audio.playSound("uiClick")
            ui.togglePanel(settingsPanel, animation)
            return true
        end
        return false
    end

    function self.mousereleased(x, y, button)
        if button == 1 then
            activeSlider = nil
        end
    end

    function self.isOpen()
        return settingsPanel.open
    end

    return self
end

return overlay
