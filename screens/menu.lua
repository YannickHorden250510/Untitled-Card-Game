local scaling = require("lib.scaling")
local ui = require("lib.ui")
local animation = require("lib.animation")
local background = require("lib.background")
local cards = require("lib.cards")
local audio = require("lib.audio")
local gameconfig = require("lib.gameconfig")
local screen = require("lib.screen")

local menu = {}

local playBtn
local quitBtn
local settingsBtn
local settingsPanel
local tutorialPopup
local tutorialYesBtn
local tutorialNoBtn
local bgCycleBtn
local cardCycleBtn
local previewFrontCard
local previewBackCard
local sfxSlider
local musicSlider
local speedSlider
local activeSlider = nil
local bgOptions = {"classic", "art"}
local cardOptions = {
    {name = "classic", sheet = "classic", back = "classic"},
    {name = "classicDark", sheet = "classicDark", back = "classicDark"}
}
local bgIndex = 1
local cardIndex = 1
local panelInset = 24

local function cardHit(px, py, x, y, w, h)
    return px >= x and px <= x + w and py >= y and py <= y + h
end

local function syncSettingsControls()
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

local function sliderValueToPos(slider)
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

function menu.enter()
    local gw = scaling.getWidth()

    local playFont = ui.getFont("menu")
    local playW = playFont:getWidth("Play") + 40
    local quitW = playFont:getWidth("Quit") + 40
    playBtn = ui.makeButton("Play", (gw - playW) / 2, 350, {
        font = "menu",
        color = {0.2, 0.6, 0.2, 0.9},
        padding = 20
    })

    quitBtn = ui.makeButton("Quit", (gw - quitW) / 2, 450, {
        font = "menu",
        color = {0.6, 0.2, 0.2, 0.9},
        padding = 20
    })

    settingsBtn = ui.makeButton("Settings", 20, scaling.getHeight() - 72, {
        font = "small",
        color = {0.2, 0.2, 0.5, 0.9},
        padding = 16
    })
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
    sfxSlider = {
        label = "SFX",
        min = 0,
        max = 1,
        step = 0.05,
        get = audio.getSfxVolume,
        set = audio.setSfxVolume,
        x = settingsPanel.x + panelInset,
        y = settingsPanel.y + 252,
        w = settingsPanel.w - panelInset * 2,
        h = 12
    }
    musicSlider = {
        label = "Music",
        min = 0,
        max = 1,
        step = 0.05,
        get = audio.getMusicVolume,
        set = audio.setMusicVolume,
        x = settingsPanel.x + panelInset,
        y = settingsPanel.y + 312,
        w = settingsPanel.w - panelInset * 2,
        h = 12
    }
    speedSlider = {
        label = "Game Speed",
        min = 0.5,
        max = 1.5,
        step = 0.05,
        get = gameconfig.getGameSpeed,
        set = gameconfig.setGameSpeed,
        x = settingsPanel.x + panelInset,
        y = settingsPanel.y + 372,
        w = settingsPanel.w - panelInset * 2,
        h = 12
    }

    tutorialPopup = {
        open = false,
        x = (gw - 560) / 2,
        y = 230,
        w = 560,
        h = 240
    }

    tutorialYesBtn = ui.makeButton("Tutorial", tutorialPopup.x + 50, tutorialPopup.y + 145, {
        font = "small",
        color = {0.2, 0.6, 0.2, 0.95},
        padding = 16
    })

    tutorialNoBtn = ui.makeButton("Skip Tutorial", tutorialPopup.x + 290, tutorialPopup.y + 145, {
        font = "small",
        color = {0.6, 0.4, 0.2, 0.95},
        padding = 16
    })

    previewFrontCard = {
        type = "aceHearts",
        suit = "hearts",
        value = 1,
        faceUp = true,
        rotation = 0,
        scaleX = 1,
        alpha = 1
    }
    previewBackCard = {
        type = "damage",
        suit = "spades",
        value = 6,
        faceUp = false,
        rotation = 0,
        scaleX = 1,
        alpha = 1
    }
end

function menu.update(dt)
    background.update(dt)
    syncSettingsControls()
    ui.updateButtonHover(playBtn, animation)
    ui.updateButtonHover(quitBtn, animation)
    ui.updateButtonHover(settingsBtn, animation)
    if settingsPanel.open then
        ui.updateButtonHover(bgCycleBtn, animation)
        ui.updateButtonHover(cardCycleBtn, animation)
    end
    if tutorialPopup.open then
        ui.updateButtonHover(tutorialYesBtn, animation)
        ui.updateButtonHover(tutorialNoBtn, animation)
    end

    if activeSlider then
        local mx, my = love.mouse.getPosition()
        local gx, gy = scaling.screenToGame(mx, my)
        setSliderFromMouse(activeSlider, gx)
    end
end

function menu.draw()
    background.draw()
    ui.drawTextCentered("Untitled Card Game", 150, "title")
    ui.drawButton(playBtn)
    ui.drawButton(quitBtn)
    ui.drawButton(settingsBtn)
    ui.drawPanel(settingsPanel)
    if settingsPanel.open then
        ui.drawText("Settings", settingsPanel.x + panelInset, settingsPanel.y + 24, "small")
        ui.drawText("Background Theme", settingsPanel.x + panelInset, settingsPanel.y + 82, "small")
        ui.drawText(bgOptions[bgIndex], settingsPanel.x + panelInset, settingsPanel.y + 116, "small", {0.85, 0.95, 1, 1})
        ui.drawButton(bgCycleBtn)
        ui.drawText("Card Theme", settingsPanel.x + panelInset, settingsPanel.y + 162, "small")
        ui.drawText(cardOptions[cardIndex].name, settingsPanel.x + panelInset, settingsPanel.y + 196, "small", {0.92, 0.9, 1, 1})
        ui.drawButton(cardCycleBtn)

        local sfxPct = math.floor(audio.getSfxVolume() * 100)
        local musicPct = math.floor(audio.getMusicVolume() * 100)
        local speedPct = math.floor(gameconfig.getGameSpeed() * 100)
        ui.drawText("SFX: " .. tostring(sfxPct) .. "%", sfxSlider.x, sfxSlider.y - 28, "small")
        ui.drawText("Music: " .. tostring(musicPct) .. "%", musicSlider.x, musicSlider.y - 28, "small")
        ui.drawText("Game Speed: " .. tostring(speedPct) .. "%", speedSlider.x, speedSlider.y - 28, "small")

        local function drawSlider(slider, color)
            love.graphics.setColor(0.15, 0.15, 0.15, 0.95)
            love.graphics.rectangle("fill", slider.x, slider.y, slider.w, slider.h, 6, 6)
            local knobX = sliderValueToPos(slider)
            love.graphics.setColor(color[1], color[2], color[3], 0.95)
            love.graphics.rectangle("fill", slider.x, slider.y, knobX - slider.x, slider.h, 6, 6)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.circle("fill", knobX, slider.y + slider.h / 2, 10)
        end

        drawSlider(sfxSlider, {0.3, 0.7, 1})
        drawSlider(musicSlider, {0.5, 0.8, 0.9})
        drawSlider(speedSlider, {0.75, 0.85, 0.35})

        local previewScale = 2.2
        local cardW = cards.cardWidth * previewScale
        local previewY = settingsPanel.y + settingsPanel.h - (cards.cardHeight * previewScale) - 24
        local frontX = settingsPanel.x + panelInset
        local backX = frontX + cardW + 18
        cards.draw(previewFrontCard, frontX, previewY, previewScale, true)
        cards.draw(previewBackCard, backX, previewY, previewScale, false)
    end

    if tutorialPopup.open then
        love.graphics.setColor(0, 0, 0, 0.55)
        love.graphics.rectangle("fill", 0, 0, scaling.getWidth(), scaling.getHeight())

        love.graphics.setColor(0.08, 0.08, 0.08, 0.96)
        love.graphics.rectangle("fill", tutorialPopup.x, tutorialPopup.y, tutorialPopup.w, tutorialPopup.h, 10, 10)
        love.graphics.setColor(1, 1, 1, 1)

        ui.drawTextCentered("Start with tutorial?", tutorialPopup.y + 26, "menu")
        ui.drawTextCentered("You can skip for now and add it later.", tutorialPopup.y + 94, "small", {0.8, 0.8, 0.8, 1})
        ui.drawButton(tutorialYesBtn)
        ui.drawButton(tutorialNoBtn)
    end
end

function menu.mousepressed(x, y, button)
    local gx, gy = scaling.screenToGame(x, y)

    if tutorialPopup.open then
        if ui.pointInRect(gx, gy, tutorialYesBtn) then
            tutorialPopup.open = false
            screen.switch("game", true)
        elseif ui.pointInRect(gx, gy, tutorialNoBtn) then
            tutorialPopup.open = false
            screen.switch("game", false)
        end
        return
    end

    if settingsPanel.open then
        if ui.pointInRect(gx, gy, bgCycleBtn) then
            audio.playSound("uiClick")
            bgIndex = (bgIndex % #bgOptions) + 1
            background.set(bgOptions[bgIndex])
        elseif ui.pointInRect(gx, gy, cardCycleBtn) then
            audio.playSound("uiClick")
            cardIndex = (cardIndex % #cardOptions) + 1
            cards.setSheet(cardOptions[cardIndex].sheet)
            cards.setBack(cardOptions[cardIndex].back)
        elseif cardHit(gx, gy, sfxSlider.x, sfxSlider.y - 8, sfxSlider.w, sfxSlider.h + 16) then
            activeSlider = sfxSlider
            setSliderFromMouse(sfxSlider, gx)
        elseif cardHit(gx, gy, musicSlider.x, musicSlider.y - 8, musicSlider.w, musicSlider.h + 16) then
            activeSlider = musicSlider
            setSliderFromMouse(musicSlider, gx)
        elseif cardHit(gx, gy, speedSlider.x, speedSlider.y - 8, speedSlider.w, speedSlider.h + 16) then
            activeSlider = speedSlider
            setSliderFromMouse(speedSlider, gx)
        elseif ui.pointInRect(gx, gy, settingsBtn) then
            audio.playSound("uiClick")
            ui.togglePanel(settingsPanel, animation)
        elseif not ui.pointInRect(gx, gy, settingsPanel) then
            audio.playSound("uiClick")
            ui.togglePanel(settingsPanel, animation)
        end
        return
    end

    if ui.pointInRect(gx, gy, playBtn) then
        audio.playSound("uiClick")
        tutorialPopup.open = true
    elseif ui.pointInRect(gx, gy, quitBtn) then
        audio.playSound("uiClick")
        love.event.quit()
    elseif ui.pointInRect(gx, gy, settingsBtn) then
        audio.playSound("uiClick")
        tutorialPopup.open = false
        ui.togglePanel(settingsPanel, animation)
    end
end

function menu.mousereleased(x, y, button)
    if button == 1 then
        activeSlider = nil
    end
end

return menu
