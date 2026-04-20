local scaling = require("lib.scaling")
local ui = require("lib.ui")
local animation = require("lib.animation")
local background = require("lib.background")
local cards = require("lib.cards")
local deck = require("lib.deck")
local gamestate = require("lib.gamestate")
local audio = require("lib.audio")
local gameconfig = require("lib.gameconfig")
local settingsOverlay = require("lib.settingsoverlay")
local screen = require("lib.screen")

local game = {}

local state
local cardScale = 3.4
local tutorialEnabled = false
local startBtn
local playBtn
local discardBtn
local deckZone
local opponentDeckZone
local gameStarted = false
local dealing = false
local resolvingPlay = false
local draggedCard = nil
local draggedIndex = nil
local dragOffsetX = 0
local dragOffsetY = 0
local dragInsertIndex = nil
local hoveredCard = nil
local opponentState = {deck = {}, hand = {}, playTable = {}, burnPile = {}}
local playUsedThisTurn = false
local turnNumber = 1
local encounterIndex = 1
local runGold = 20
local enemyHP = 120
local enemyMaxHP = 120
local queenBlockActive = false
local queenPassiveUsedThisTurn = false
local combatLog = {}
local beginNextTurn
local animateHandToLayout
local damagePopups = {}
local enemyShake = {x = 0}
local playerShake = {x = 0}
local turnActionStep = 0
local revealOpponentCards = false
local encounterEnded = false
local currentEncounterProfile = nil
local phaseLabel = "Player Turn"
local settingsUI
local tutorialMascot = nil
local tutorialFlow = {
    active = false,
    step = 0,
    awaitingClick = false,
    settingsWasOpen = false,
    turn2DrawTriggered = false
}

local function parseTutorialRichText(raw)
    local plain = {}
    local styles = {}
    local function parseMods(mods)
        local s = {color = nil, shaking = false, floating = false}
        for token in string.gmatch(string.lower(mods or ""), "[^,%s]+") do
            if token == "red" then
                s.color = {1, 0.35, 0.35, 1}
            elseif token == "green" then
                s.color = {0.45, 1, 0.45, 1}
            elseif token == "blue" then
                s.color = {0.45, 0.75, 1, 1}
            elseif token == "yellow" then
                s.color = {1, 0.92, 0.35, 1}
            elseif token == "purple" then
                s.color = {0.85, 0.45, 1, 1}
            elseif token == "shaking" then
                s.shaking = true
            elseif token == "floating" then
                s.floating = true
            end
        end
        return s
    end

    local i = 1
    while i <= #raw do
        local ch = raw:sub(i, i)
        if ch == "(" then
            local closeParen = raw:find(")", i + 1, true)
            if closeParen and raw:sub(closeParen + 1, closeParen + 1) == "[" then
                local closeBracket = raw:find("]", closeParen + 2, true)
                if closeBracket then
                    local word = raw:sub(i + 1, closeParen - 1)
                    local style = parseMods(raw:sub(closeParen + 2, closeBracket - 1))
                    for j = 1, #word do
                        table.insert(plain, word:sub(j, j))
                        styles[#plain] = style
                    end
                    i = closeBracket + 1
                else
                    table.insert(plain, ch)
                    i = i + 1
                end
            else
                table.insert(plain, ch)
                i = i + 1
            end
        else
            table.insert(plain, ch)
            i = i + 1
        end
    end
    return table.concat(plain), styles
end

local function setTutorialMessage(raw)
    if not tutorialMascot then return end
    tutorialMascot.rawText = raw
    tutorialMascot.fullText, tutorialMascot.styles = parseTutorialRichText(raw)
    tutorialMascot.visibleCount = 0
    tutorialMascot.charAcc = 0
    tutorialMascot.nextDelay = tutorialMascot.charDelay
    tutorialMascot.bounces = {}
    tutorialMascot.visible = true
end

local function resetTutorialMascot()
    if not tutorialEnabled then
        tutorialMascot = nil
        return
    end
    tutorialMascot = {
        jokerCard = {
            type = deck.types.joker,
            name = "Joker",
            faceUp = true,
            jokerIndex = 0,
            alpha = 1,
            scaleX = 1,
            rotation = 0.12
        },
        rawText = "",
        fullText = "",
        styles = {},
        charDelay = 0.036,
        nextDelay = 0.036,
        charAcc = 0,
        visibleCount = 0,
        bounces = {},
        talkTime = 0,
        visible = true
    }
    setTutorialMessage("Hey! Welcome to Untitled Card Game, I'm Jo and I'll be teaching you how to play today. Whenever you're ready, just hit start encounter!")
    tutorialFlow.awaitingClick = false
    tutorialFlow.settingsWasOpen = false
    tutorialFlow.turn2DrawTriggered = false
end

local function tutorialTypewriterDone()
    return tutorialMascot and tutorialMascot.visible and tutorialMascot.visibleCount >= #tutorialMascot.fullText
end

local function tutorialBlocksUiClick(gx, gy)
    if not tutorialFlow.active then return false end
    if settingsUI and settingsUI.isOpen and settingsUI:isOpen() then return true end
    if not gameStarted and ui.pointInRect(gx, gy, startBtn) then return true end
    if gameStarted and ui.pointInRect(gx, gy, playBtn) then return true end
    if gameStarted and ui.pointInRect(gx, gy, discardBtn) then return true end
    return false
end

local function updateTutorialMascot(dt)
    if not tutorialMascot then return end
    local m = tutorialMascot
    local len = #m.fullText
    m.talkTime = (m.talkTime or 0) + dt
    if m.visibleCount < len then
        m.charAcc = m.charAcc + dt
        while m.charAcc >= (m.nextDelay or m.charDelay) and m.visibleCount < len do
            m.charAcc = m.charAcc - (m.nextDelay or m.charDelay)
            m.visibleCount = m.visibleCount + 1
            local ch = m.fullText:sub(m.visibleCount, m.visibleCount)
            if ch ~= " " and ch ~= "\n" and ch ~= "\t" then
                if love.math.random() < 0.42 then
                    audio.playSound("voiceTick", 0.4, 0.95 + (love.math.random() * 0.12))
                end
            end
            m.bounces[m.visibleCount] = 1
            local extraPause = 0
            if ch == "," then
                extraPause = 0.12
            elseif ch == "." or ch == "!" or ch == "?" then
                extraPause = 0.28
            end
            m.nextDelay = m.charDelay + extraPause
        end
    end
    for i, b in pairs(m.bounces) do
        if b > 0 then
            m.bounces[i] = math.max(0, b - dt * 6.5)
        end
    end
end

local function drawTutorialMascot()
    if not tutorialMascot or tutorialMascot.visible == false then return end
    local gw = scaling.getWidth()
    local gh = scaling.getHeight()
    local m = tutorialMascot
    local mascotScale = 2.75
    local cw = cards.cardWidth * mascotScale
    local jokerX = 22
    local baseJokerY = gh * 0.34
    local t = m.talkTime or 0
    local bob
    local tilt
    if m.visibleCount < #m.fullText then
        -- Punchier "talking" bounce: quick up-hit and settle.
        local phase = math.sin(t * 13.0)
        bob = -math.max(0, phase) * 6.0 + (math.sin(t * 26.0) * 0.7)
        tilt = 0.12 + (math.sin(t * 9.2) * 0.09)
    else
        bob = math.sin(t * 3.0) * 1.2
        tilt = 0.12 + (math.sin(t * 2.4) * 0.02)
    end
    local jokerY = baseJokerY + bob
    m.jokerCard.rotation = tilt

    local panelX = jokerX + cw + 18
    local panelY = baseJokerY - 8
    local panelW = math.max(280, gw - panelX - 24)
    local panelH = 168

    love.graphics.setColor(0.07, 0.08, 0.12, 0.92)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 10, 10)
    love.graphics.setColor(0.35, 0.45, 0.65, 0.95)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 10, 10)
    love.graphics.setLineWidth(1)

    local font = ui.getFont("small")
    love.graphics.setFont(font)
    local padding = 14
    local innerX = panelX + padding
    local innerY = panelY + padding
    local lineH = font:getHeight()
    local maxW = panelW - padding * 2
    local cx, cy = innerX, innerY
    love.graphics.setColor(0.95, 0.96, 1, 1)
    for idx = 1, m.visibleCount do
        local c = m.fullText:sub(idx, idx)
        if c == "\n" then
            cx = innerX
            cy = cy + lineH + 4
        else
            local prev = (idx > 1) and m.fullText:sub(idx - 1, idx - 1) or ""
            local isWordStart = prev == "" or prev == " " or prev == "\n" or prev == "\t"
            if isWordStart and c ~= " " and c ~= "\t" then
                local wordEnd = idx
                while wordEnd <= m.visibleCount do
                    local wc = m.fullText:sub(wordEnd, wordEnd)
                    if wc == " " or wc == "\n" or wc == "\t" then
                        break
                    end
                    wordEnd = wordEnd + 1
                end
                local word = m.fullText:sub(idx, wordEnd - 1)
                local wordW = font:getWidth(word)
                if cx + wordW > innerX + maxW and cx > innerX then
                    cx = innerX
                    cy = cy + lineH + 4
                end
            end
            local w = font:getWidth(c)
            if c == " " and cx == innerX then
                w = 0
            elseif cx + w > innerX + maxW and cx > innerX then
                cx = innerX
                cy = cy + lineH + 4
            end
            local bounce = m.bounces[idx] or 0
            local dy = -math.sin(bounce * math.pi) * 6
            local style = m.styles and m.styles[idx] or nil
            local color = (style and style.color) or {0.95, 0.96, 1, 1}
            if style and style.floating then
                dy = dy + (math.sin((m.talkTime or 0) * 6 + idx * 0.4) * 1.8)
            end
            local dx = 0
            if style and style.shaking then
                dx = math.sin((m.talkTime or 0) * 32 + idx * 2) * 0.9
            end
            if w > 0 then
                love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
                love.graphics.print(c, cx + dx, cy + dy)
            end
            cx = cx + w
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
    cards.draw(m.jokerCard, jokerX, jokerY, mascotScale, true)

    if tutorialFlow.awaitingClick and tutorialTypewriterDone() then
        ui.drawTextCentered("Click anywhere to continue", panelY + panelH + 22, "small", {0.82, 0.92, 1, 0.92})
    end
end

local function getEncounterProfile(idx)
    if idx == 1 then
        return {
            enemyHP = 80,
            rewardGold = 8,
            extraPlayChance = 0.0,
            preferredLeadType = nil
        }
    elseif idx == 2 then
        return {
            enemyHP = 110,
            rewardGold = 12,
            extraPlayChance = 0.25,
            preferredLeadType = deck.types.king
        }
    end
    return {
        enemyHP = 140,
        rewardGold = 16,
        extraPlayChance = 0.45,
        preferredLeadType = deck.types.joker
    }
end


local function playSoundDelayed(name, volume, pitch, delay)
    delay = delay or 0
    if delay <= 0 then
        audio.playSound(name, volume, pitch)
        return
    end
    local marker = {x = 0}
    animation.slideTo(marker, 0.01, 1, nil):delay(delay):oncomplete(function()
        audio.playSound(name, volume, pitch)
    end)
end

local function ensureCardVisual(card, x, y)
    card.x = card.x or x
    card.y = card.y or y
    card.targetX = card.targetX or x
    card.targetY = card.targetY or y
    card.alpha = card.alpha or 1
end

local function resetTransientCardState(card)
    card.consumed = nil
    card.burned = nil
    card.pendingDamage = nil
    card.damageBonus = nil
    card.fxLabels = nil
    card.storedDamage = 0
end

local function getHandPosition(index, count)
    local cw = cards.cardWidth * cardScale
    local spacing = math.max(34, math.min(cw * 0.74, 68))
    local centerX = scaling.getWidth() / 2
    local baseY = scaling.getHeight() - 168
    local middle = (count + 1) / 2
    local x = centerX + (index - middle) * spacing - (cw / 2)

    local distance = index - middle
    local yCurve = (distance * distance) * 2.1
    local y = baseY + yCurve

    return x, y
end

local function getOpponentHandPosition(index, count)
    local cw = cards.cardWidth * cardScale
    local spacing = math.max(30, math.min(cw * 0.66, 60))
    local centerX = scaling.getWidth() / 2
    local baseY = 78
    local middle = (count + 1) / 2
    local x = centerX + (index - middle) * spacing - (cw / 2)

    local distance = index - middle
    local yCurve = -(distance * distance) * 1.8
    local y = baseY + yCurve

    return x, y
end

local function getCardTooltip(card)
    local effectByType = {
        damage = "Deal damage equal to card value.",
        jack = "+2 play cards this turn.",
        queen = "Blocks first damage while leftmost.",
        king = "Buff all table damage cards by +5.",
        aceHearts = "Opponent discards their next card.",
        aceSpades = "Copies the card played before it.",
        aceClubs = "Permanently destroy 3 from burn pile.",
        aceDiamonds = "Copy opponent's most recent action.",
        joker = "Consume table damage and double it."
    }
    local title = card.name or "Card"
    local effect = effectByType[card.type] or "No effect."
    return title, effect
end

local function getHandRotation(index, count)
    if count <= 1 then
        return 0
    end

    local middle = (count + 1) / 2
    local normalized = (index - middle) / math.max(1, (count - 1) / 2)
    return normalized * 0.14
end

local function queueOpponentCardToHand(card, index, count, delay)
    resetTransientCardState(card)
    local targetX, targetY = getOpponentHandPosition(index, count)
    ensureCardVisual(card, opponentDeckZone.x, opponentDeckZone.y)
    card.alpha = 1
    card.faceUp = false
    card.targetX = targetX
    card.targetY = targetY
    card.rotation = card.rotation or 0
    card.revealFaceUp = revealOpponentCards == true
    card.targetRotation = -getHandRotation(index, count)
    playSoundDelayed("cardMove", 0.6, 0.98 + (love.math.random() * 0.05), delay or 0)
    local speed = gameconfig.getGameSpeed()
    animation.dealCard(card, targetX, targetY, (delay or 0) / speed, 0.45 / speed)
    animation.rotateTo(card, 0.45 / speed, card.targetRotation, (delay or 0) / speed)
end

local function queueCardToHand(card, index, count, delay)
    resetTransientCardState(card)
    local targetX, targetY = getHandPosition(index, count)
    ensureCardVisual(card, deckZone.x, deckZone.y)
    card.alpha = 1

    card.targetX = targetX
    card.targetY = targetY
    card.rotation = card.rotation or 0
    card.targetRotation = getHandRotation(index, count)
    playSoundDelayed("cardMove", 0.75, 0.98 + (love.math.random() * 0.05), delay or 0)
    local speed = gameconfig.getGameSpeed()
    animation.dealCard(card, targetX, targetY, (delay or 0) / speed, 0.45 / speed)
    animation.rotateTo(card, 0.45 / speed, card.targetRotation, (delay or 0) / speed)
end

local function makeTutorialCard(cardType, suit, value, jokerIndex)
    local c = deck.createCard(cardType, suit, value)
    if cardType == deck.types.damage then
        c.name = tostring(value) .. " of " .. tostring(suit)
    elseif cardType == deck.types.jack then
        c.name = "Jack of " .. tostring(suit)
    elseif cardType == deck.types.king then
        c.name = "King of " .. tostring(suit)
    elseif cardType == deck.types.joker then
        c.name = "Joker"
        c.jokerIndex = jokerIndex or 0
        c.storedDamage = 0
    end
    return c
end

local function buildTutorialOpeningDeck()
    local d = deck.build()
    local opening = {
        makeTutorialCard(deck.types.jack, "hearts"),
        makeTutorialCard(deck.types.damage, "hearts", 6),
        makeTutorialCard(deck.types.damage, "spades", 8),
        makeTutorialCard(deck.types.damage, "clubs", 9),
        makeTutorialCard(deck.types.damage, "diamonds", 10),
        makeTutorialCard(deck.types.king, "spades"),
        makeTutorialCard(deck.types.joker, nil, nil, 0),
        makeTutorialCard(deck.types.joker, nil, nil, 1)
    }
    for i = #opening, 1, -1 do
        table.insert(d, opening[i])
    end
    return d
end

local function reorderOpponentTutorialJack68(hand)
    local picked = {}
    local function take(pred)
        for i = 1, #hand do
            if pred(hand[i]) then
                table.insert(picked, table.remove(hand, i))
                return true
            end
        end
        return false
    end
    take(function(c) return c.type == deck.types.jack end)
    take(function(c) return c.type == deck.types.damage and c.value == 6 end)
    take(function(c) return c.type == deck.types.damage and c.value == 8 end)
    local newHand = {}
    for _, c in ipairs(picked) do
        table.insert(newHand, c)
    end
    for _, c in ipairs(hand) do
        table.insert(newHand, c)
    end
    for i = 1, #newHand do
        hand[i] = newHand[i]
    end
    for j = #newHand + 1, #hand do
        hand[j] = nil
    end
end

local function getPlayTablePosition(index, count)
    local cw = cards.cardWidth * cardScale
    local spacing = cw + 14
    local totalWidth = (count * cw) + ((count - 1) * 14)
    local startX = (scaling.getWidth() - totalWidth) / 2
    local y = scaling.getHeight() * 0.53
    return startX + (index - 1) * spacing, y
end

local function getOpponentPlayTablePosition(index, count)
    local cw = cards.cardWidth * cardScale
    local spacing = cw + 14
    local totalWidth = (count * cw) + ((count - 1) * 14)
    local startX = (scaling.getWidth() - totalWidth) / 2
    local y = scaling.getHeight() * 0.31
    return startX + (index - 1) * spacing, y
end

local function animatePlayTableLayout()
    for i, card in ipairs(state.playTable) do
        local x, y = getPlayTablePosition(i, #state.playTable)
        ensureCardVisual(card, x, y)
        animation.slideTo(card, 0.22, x, y)
        animation.rotateTo(card, 0.22, 0)
    end
end

local function animateOpponentPlayTableLayout()
    for i, card in ipairs(opponentState.playTable) do
        local x, y = getOpponentPlayTablePosition(i, #opponentState.playTable)
        ensureCardVisual(card, x, y)
        animation.slideTo(card, 0.22, x, y)
        animation.rotateTo(card, 0.22, 0)
    end
end

local function animateOpponentHandToLayout()
    local count = #opponentState.hand
    for i, card in ipairs(opponentState.hand) do
        local x, y = getOpponentHandPosition(i, count)
        ensureCardVisual(card, x, y)
        card.targetX = x
        card.targetY = y
        card.targetRotation = -getHandRotation(i, count)
        animation.slideTo(card, 0.22, x, y)
        animation.rotateTo(card, 0.22, card.targetRotation)
    end
end

local function pacedDuration(base)
    local speed = gameconfig.getGameSpeed()
    turnActionStep = turnActionStep + 1
    local factor = math.max(0.45, 1.35 - ((turnActionStep - 1) * 0.08))
    return (base * factor) / speed
end

local function logCombat(text)
    table.insert(combatLog, 1, text)
    while #combatLog > 7 do
        table.remove(combatLog)
    end
end

local function addDamagePopup(text, x, y, color)
    table.insert(damagePopups, {
        text = text,
        x = x,
        y = y,
        alpha = 1,
        color = color or {1, 0.2, 0.2, 1}
    })
    local popup = damagePopups[#damagePopups]
    animation.slideTo(popup, 0.55, nil, y - 42)
    animation.fade(popup, 0.55, 0)
end

local function addCardEffect(card, text, color, rotation, centered)
    if not card then return end
    card.fxLabels = card.fxLabels or {}
    local fx = {
        text = text,
        y = 0,
        alpha = 1,
        color = color or {1, 1, 1, 1},
        rotation = rotation or 0,
        centered = centered == true
    }
    table.insert(card.fxLabels, fx)
    local rise = centered and -6 or -24
    animation.slideTo(fx, 0.55, nil, rise)
    animation.fade(fx, 0.55, 0)
end

local function damageEnemy(amount, reason)
    if amount <= 0 then return end
    enemyHP = math.max(0, enemyHP - amount)
    audio.playSound("hit", 0.9)
    if amount >= 12 then
        audio.playSound("highDamage", 0.92)
    end
    addDamagePopup("-" .. tostring(amount), scaling.getWidth() * 0.5, 100, {1, 0.25, 0.25, 1})
    animation.shake(enemyShake, 0.25, 10)
    logCombat("Enemy takes " .. tostring(amount) .. " (" .. reason .. ").")
end

local function damagePlayer(amount, reason)
    if amount <= 0 then return end
    if not queenPassiveUsedThisTurn and #state.hand > 0 then
        local leftmost = state.hand[1]
        if leftmost and leftmost.type == deck.types.queen then
            queenPassiveUsedThisTurn = true
            table.remove(state.hand, 1)
            ensureCardVisual(leftmost, leftmost.x or deckZone.x, leftmost.y or deckZone.y)
            audio.playSound("queenBlock", 0.95)
            animation.burnCard(leftmost, 0, 0.25)
            resetTransientCardState(leftmost)
            gamestate.burnCard(state, leftmost)
            animateHandToLayout()
            logCombat("Left-most Queen blocks incoming damage and burns.")
            return
        end
    end
    if queenBlockActive then
        queenBlockActive = false
        audio.playSound("queenBlock", 0.95)
        logCombat("Queen blocks incoming damage.")
        return
    end
    gamestate.damagePlayer(state, amount)
    audio.playSound("hit", 0.9)
    if amount >= 12 then
        audio.playSound("highDamage", 0.92)
    end
    addDamagePopup("-" .. tostring(amount), scaling.getWidth() * 0.5, scaling.getHeight() - 210, {1, 0.4, 0.4, 1})
    animation.shake(playerShake, 0.25, 10)
    logCombat("Player takes " .. tostring(amount) .. " (" .. reason .. ").")
end

local function queueDrawToHand(count, delayOffset)
    count = count or 0
    delayOffset = delayOffset or 0
    for i = 1, count do
        if #state.deck == 0 then break end
        local card = table.remove(state.deck)
        table.insert(state.hand, card)
        queueCardToHand(card, #state.hand, #state.hand, delayOffset + ((i - 1) * 0.08))
    end
end

local function queueDrawOpponentToHand(count, delayOffset)
    count = count or 0
    delayOffset = delayOffset or 0
    for i = 1, count do
        if #opponentState.deck == 0 then break end
        local card = table.remove(opponentState.deck)
        table.insert(opponentState.hand, card)
        queueOpponentCardToHand(card, #opponentState.hand, #opponentState.hand, delayOffset + ((i - 1) * 0.08))
    end
end

animateHandToLayout = function()
    local count = #state.hand
    local layoutCards = {}

    if draggedCard and dragInsertIndex then
        for i, card in ipairs(state.hand) do
            if i ~= draggedIndex then
                table.insert(layoutCards, card)
            end
        end
        table.insert(layoutCards, dragInsertIndex, draggedCard)
    else
        for _, card in ipairs(state.hand) do
            table.insert(layoutCards, card)
        end
    end

    local visualIndexByCard = {}
    for i, card in ipairs(layoutCards) do
        visualIndexByCard[card] = i
    end

    for i, card in ipairs(state.hand) do
        if card ~= draggedCard then
            local visualIndex = visualIndexByCard[card] or i
            local targetX, targetY = getHandPosition(visualIndex, count)
            ensureCardVisual(card, targetX, targetY)
            card.targetX = targetX
            card.targetY = targetY
            card.targetRotation = getHandRotation(visualIndex, count)
            animation.slideTo(card, 0.22, targetX, targetY)
            animation.rotateTo(card, 0.22, card.targetRotation)
        end
    end
end

local function canPlayFromHand()
    return gameStarted
        and (not dealing)
        and (not draggedCard)
        and (not resolvingPlay)
        and (not playUsedThisTurn)
        and (not encounterEnded)
        and #state.hand > 0
end

local function collectFullPlayerDeck()
    local all = {}
    local seen = {}
    local function addUnique(cardsList)
        for _, c in ipairs(cardsList) do
            local key = c.id
            if key == nil or not seen[key] then
                if key ~= nil then
                    seen[key] = true
                end
                table.insert(all, c)
            end
        end
    end

    addUnique(state.deck)
    addUnique(state.hand)
    addUnique(state.playTable)
    addUnique(state.burnPile)
    return deck.copy(all)
end

local function copyCardSnapshot(card)
    if not card then return nil end
    local snap = {}
    for k, v in pairs(card) do
        if type(v) ~= "table" then
            snap[k] = v
        end
    end
    return snap
end

local function buildEffectivePlayedSnapshot(card, effectiveType)
    local snap = copyCardSnapshot(card)
    if not snap then return nil end
    if effectiveType then
        snap.type = effectiveType
    end
    if effectiveType == deck.types.damage then
        snap.value = card.value or snap.value or 0
        snap.damageBonus = card.damageBonus or snap.damageBonus or 0
    elseif effectiveType == deck.types.joker then
        snap.storedDamage = card.storedDamage or snap.storedDamage or 0
    end
    return snap
end

local function checkEncounterOutcome()
    if encounterEnded then return true end
    if enemyHP <= 0 then
        encounterEnded = true
        phaseLabel = "Store"
        audio.playSound("win", 1.0)
        screen.switch("store", {
            deck = collectFullPlayerDeck(),
            gold = runGold + (currentEncounterProfile and currentEncounterProfile.rewardGold or 8),
            encounter = encounterIndex
        })
        return true
    end
    local noCardsLeft = (#state.deck == 0 and #state.hand == 0 and #state.playTable == 0)
    if state.playerHP <= 0 or noCardsLeft then
        encounterEnded = true
        local reason = state.playerHP <= 0 and "Your HP reached 0." or "You ran out of cards."
        phaseLabel = "Defeat"
        audio.playSound("negative", 1.0)
        screen.switch("death", {title = "Defeat", reason = reason})
        return true
    end
    return false
end

local function setRevealOpponentCards(enabled)
    revealOpponentCards = enabled == true
end

local function animateRevealCard(card, targetFaceUp, delay)
    local marker = {x = 0}
    animation.slideTo(marker, 0.01, 1, nil):delay(delay or 0):oncomplete(function()
        local currentFace = card.revealFaceUp
        if currentFace == nil then
            currentFace = card.faceUp == true
        end
        if currentFace == targetFaceUp then
            card.revealFaceUp = targetFaceUp
            return
        end
        animation.cardFlip(card, 0.28, function()
            card.revealFaceUp = targetFaceUp
        end)
    end)
end

local function animateSetRevealOpponentCards(enabled)
    setRevealOpponentCards(enabled)
    local delay = 0
    local step = 0.07

    for _, card in ipairs(opponentState.hand) do
        animateRevealCard(card, revealOpponentCards, delay)
        delay = delay + step
    end

    for _, card in ipairs(opponentState.playTable) do
        local targetFace = revealOpponentCards or (card.faceUp == true)
        animateRevealCard(card, targetFace, delay)
        delay = delay + step
    end
end

local function applyImmediateOnPlayEffects(card, effectiveType)
    effectiveType = effectiveType or card.type
    if effectiveType == deck.types.jack then
        state.playCards = state.playCards + 2
        audio.playSound("jackActivate", 0.9, 1.08)
        animation.shake(card, 0.2, 7)
        addCardEffect(card, "+2", {0.35, 0.65, 1, 1}, 0)
    end
end

local function cardDamageValue(card)
    return (card.value or 0) + (card.damageBonus or 0)
end

local function resolveAceSpadesCopy(card, previousCard)
    if not previousCard then
        return card.type
    end

    if previousCard.type == deck.types.damage then
        card.type = deck.types.damage
        card.value = previousCard.value or 0
        card.damageBonus = previousCard.damageBonus or 0
        card.pendingDamage = (card.value or 0) + (card.damageBonus or 0)
        return deck.types.damage
    end

    if previousCard.type == deck.types.joker then
        card.type = deck.types.joker
        card.storedDamage = previousCard.storedDamage or 0
        return deck.types.joker
    end

    -- Face cards copy as face behavior in immediate-on-play logic.
    return previousCard.type
end

local function applyMirroredEnemyCardToPlayer(mirrored, hostCard, sourceTable)
    if not mirrored then
        logCombat("Ace of Diamonds had no enemy card to mirror.")
        return
    end

    if mirrored.type == deck.types.jack then
        state.playCards = state.playCards + 2
        addCardEffect(hostCard, "+2", {0.35, 0.65, 1, 1}, 0)
        logCombat("Ace of Diamonds mirrored Jack (+2 play cards).")
        return
    end

    if mirrored.type == deck.types.king then
        for _, tableCard in ipairs(sourceTable) do
            if tableCard.type == deck.types.damage and not tableCard.consumed and not tableCard.burned then
                tableCard.damageBonus = (tableCard.damageBonus or 0) + 5
                addCardEffect(tableCard, "+5", {0.3, 0.95, 0.35, 1}, -0.52, true)
            end
        end
        logCombat("Ace of Diamonds mirrored King (+5 buffs).")
        return
    end

    if mirrored.type == deck.types.queen then
        queenBlockActive = true
        addCardEffect(hostCard, "BLOCK", {0.6, 0.9, 1, 1}, 0)
        logCombat("Ace of Diamonds mirrored Queen (block readied).")
        return
    end

    if mirrored.type == deck.types.aceHearts then
        opponentState.discardNext = true
        addCardEffect(hostCard, "DISCARD", {1, 0.6, 0.8, 1}, 0)
        logCombat("Ace of Diamonds mirrored Ace of Hearts.")
        return
    end

    if mirrored.type == deck.types.aceClubs then
        local removed = gamestate.destroyFromBurnPile(state, 3)
        addCardEffect(hostCard, "x" .. tostring(#removed), {0.7, 1, 0.7, 1}, 0)
        logCombat("Ace of Diamonds mirrored Ace of Clubs.")
        return
    end

    if mirrored.type == deck.types.damage then
        local dmg = (mirrored.value or 0) + (mirrored.damageBonus or 0)
        damageEnemy(dmg, "Ace of Diamonds mirror")
        addCardEffect(hostCard, "-" .. tostring(dmg), {1, 0.2, 0.2, 1}, 0)
        logCombat("Ace of Diamonds mirrored damage card.")
        return
    end

    if mirrored.type == deck.types.joker then
        local dmg = mirrored.storedDamage or 0
        if dmg > 0 then
            damageEnemy(dmg, "Ace of Diamonds mirrored joker")
            addCardEffect(hostCard, "-" .. tostring(dmg), {1, 0.2, 0.2, 1}, 0)
        end
        logCombat("Ace of Diamonds mirrored Joker.")
        return
    end

    logCombat("Ace of Diamonds mirrored " .. (mirrored.name or "a card") .. ".")
end

local function applyFaceActivation(owner, card, index)
    local sourceTable = owner == "player" and state.playTable or opponentState.playTable
    if card.type == deck.types.queen then
        logCombat("Queen on table has no effect (passive in hand).")
    elseif card.type == deck.types.king then
        for _, tableCard in ipairs(sourceTable) do
            if tableCard.type == deck.types.damage and not tableCard.consumed then
                tableCard.damageBonus = (tableCard.damageBonus or 0) + 5
                addCardEffect(tableCard, "+5", {0.3, 0.95, 0.35, 1}, -0.52, true)
            end
        end
        logCombat("King Crown buffs table damage cards by +5.")
    elseif card.type == deck.types.aceHearts then
        if owner == "player" then
            opponentState.discardNext = true
            logCombat("Ace of Hearts set: opponent will discard next card.")
        end
    elseif card.type == deck.types.aceSpades then
        local prev = sourceTable[index - 1]
        local copiedType = resolveAceSpadesCopy(card, prev)
        if copiedType == deck.types.damage then
            logCombat("Ace of Spades copied previous damage card.")
        elseif copiedType == deck.types.joker then
            logCombat("Ace of Spades copied previous joker.")
        elseif prev then
            logCombat("Ace of Spades copied " .. (prev.name or "previous card") .. ".")
        end
    elseif card.type == deck.types.aceClubs then
        if owner == "player" then
            local removed = gamestate.destroyFromBurnPile(state, 3)
            logCombat("Ace of Clubs destroyed " .. tostring(#removed) .. " burnt cards.")
        end
    elseif card.type == deck.types.aceDiamonds then
        if owner == "player" then
            applyMirroredEnemyCardToPlayer(opponentState.lastPlayedCard, card, sourceTable)
        end
    end
end

local function resolveActivationPhases(owner, done)
    local sourceTable = owner == "player" and state.playTable or opponentState.playTable
    local burnPile = owner == "player" and state.burnPile or opponentState.burnPile
    local targetDamage = owner == "player" and damageEnemy or damagePlayer

    local steps = {}
    local function waitStep(seconds)
        table.insert(steps, function(nextStep)
            local marker = {x = 0}
            animation.slideTo(marker, pacedDuration(seconds), 1, nil):oncomplete(nextStep)
        end)
    end

    local function burnCardNow(card, nextStep)
        audio.playSound("burn", 0.8, 1 + (love.math.random() * 0.06))
        animation.burnCard(card, 0, 0.28):oncomplete(function()
            card.burned = true
            card.pendingDamage = nil
            card.damageBonus = nil
            card.storedDamage = 0
            card.fxLabels = nil
            table.insert(burnPile, card)
            nextStep()
        end)
    end

    for _, card in ipairs(sourceTable) do
        card.consumed = false
        card.burned = false
        card.damageBonus = card.damageBonus or 0
        if card.type == deck.types.damage then
            card.pendingDamage = cardDamageValue(card)
        end
    end

    -- Phase 1: face cards burn immediately after resolving.
    for i, card in ipairs(sourceTable) do
        if card.type ~= deck.types.damage and card.type ~= deck.types.joker then
            table.insert(steps, function(nextStep)
                applyFaceActivation(owner, card, i)
                card.consumed = true
                burnCardNow(card, nextStep)
            end)
            waitStep(0.12)
        end
    end

    -- Phase 2: jokers consume.
    for i, card in ipairs(sourceTable) do
        if card.type == deck.types.joker and not card.burned and not card.consumed then
            table.insert(steps, function(nextStep)
                local consumedTotal = 0
                local consumedNow = {}
                for j, other in ipairs(sourceTable) do
                    if i ~= j and not other.consumed and not other.burned then
                        if other.type == deck.types.damage then
                            local dmg = other.pendingDamage or cardDamageValue(other)
                            if dmg > 0 then
                                consumedTotal = consumedTotal + dmg
                                other.consumed = true
                                table.insert(consumedNow, other)
                            end
                        elseif other.type == deck.types.joker and (other.storedDamage or 0) > 0 then
                            consumedTotal = consumedTotal + (other.storedDamage or 0)
                            other.consumed = true
                            table.insert(consumedNow, other)
                        end
                    end
                end
                if consumedTotal > 0 then
                    card.storedDamage = consumedTotal * 2
                    audio.playSound("joker", 0.95)
                    addCardEffect(card, "+" .. tostring(consumedTotal), {0.95, 0.8, 0.2, 1}, 0)
                    logCombat("Joker stores " .. tostring(card.storedDamage) .. " damage.")
                end

                -- Consumed cards burn during phase 2, before any phase-3 damage resolves.
                local burnSteps = {}
                for _, consumedCard in ipairs(consumedNow) do
                    table.insert(burnSteps, function(nextBurn)
                        if consumedCard.burned then
                            nextBurn()
                            return
                        end
                        burnCardNow(consumedCard, nextBurn)
                    end)
                end

                if #burnSteps > 0 then
                    table.insert(burnSteps, function(doneBurns)
                        doneBurns()
                        nextStep()
                    end)
                    animation.sequence(burnSteps)
                else
                    nextStep()
                end
            end)
            waitStep(0.12)
        end
    end

    -- Phase 3: remaining damage + loaded jokers burn after firing.
    for _, card in ipairs(sourceTable) do
        if not card.burned then
            table.insert(steps, function(nextStep)
                if not card.consumed then
                    if card.type == deck.types.damage then
                        local dmg = card.pendingDamage or cardDamageValue(card)
                        addCardEffect(card, "-" .. tostring(dmg), {1, 0.2, 0.2, 1}, 0)
                        targetDamage(dmg, card.name or "damage card")
                    elseif card.type == deck.types.joker and (card.storedDamage or 0) > 0 then
                        addCardEffect(card, "-" .. tostring(card.storedDamage), {1, 0.2, 0.2, 1}, 0)
                        targetDamage(card.storedDamage, "joker")
                    end
                end
                burnCardNow(card, nextStep)
            end)
            waitStep(0.08)
        end
    end

    table.insert(steps, function(nextStep)
        local kept = {}
        for _, card in ipairs(sourceTable) do
            if not card.burned then
                table.insert(kept, card)
            end
        end
        if owner == "player" then
            state.playTable = kept
            animatePlayTableLayout()
        else
            opponentState.playTable = kept
            animateOpponentPlayTableLayout()
        end
        if done then done() end
        nextStep()
    end)

    animation.sequence(steps)
end

local function runEnemyTurn(done)
    phaseLabel = "Enemy Turn"
    local function enemyCardUsefulAsLead(card)
        if not card then return false end
        return card.type == deck.types.damage
            or card.type == deck.types.jack
            or card.type == deck.types.aceHearts
            or card.type == deck.types.aceClubs
    end

    local function moveCard(hand, fromIdx, toIdx, moveCounts)
        if fromIdx == toIdx or fromIdx < 1 or fromIdx > #hand or toIdx < 1 or toIdx > #hand then
            return false
        end
        local card = hand[fromIdx]
        if not card then return false end
        moveCounts[card] = moveCounts[card] or 0
        if moveCounts[card] >= 2 then
            return false
        end
        table.remove(hand, fromIdx)
        table.insert(hand, toIdx, card)
        moveCounts[card] = moveCounts[card] + 1
        return true
    end

    local function reorderEnemyHand()
        local hand = opponentState.hand
        if #hand <= 1 then return end

        -- 1) Random shuffle first.
        for i = #hand, 2, -1 do
            local j = love.math.random(1, i)
            hand[i], hand[j] = hand[j], hand[i]
        end

        local moveCounts = {}

        -- 2) Prioritize Jack into first non-jack slot from the left.
        local jackIdx = nil
        for i, c in ipairs(hand) do
            if c.type == deck.types.jack then
                jackIdx = i
                break
            end
        end
        if jackIdx then
            local target = 1
            while target <= #hand and hand[target] and hand[target].type == deck.types.jack do
                target = target + 1
            end
            if target > #hand then target = #hand end
            moveCard(hand, jackIdx, target, moveCounts)
        end

        -- 2b) Encounter bias: optionally pull a preferred card type forward.
        local preferred = currentEncounterProfile and currentEncounterProfile.preferredLeadType or nil
        if preferred then
            local prefIdx = nil
            for i, c in ipairs(hand) do
                if c.type == preferred then
                    prefIdx = i
                    break
                end
            end
            if prefIdx and prefIdx > 1 then
                local target = 1
                while target <= #hand and hand[target] and (hand[target].type == deck.types.jack or hand[target].type == preferred) do
                    target = target + 1
                end
                if target > #hand then target = #hand end
                moveCard(hand, prefIdx, target, moveCounts)
            end
        end

        -- 3) Spot 1 cannot be a card useless on its own (queen rule generalized).
        local guard = #hand * 3
        while guard > 0 and #hand > 1 do
            guard = guard - 1
            local lead = hand[1]
            if enemyCardUsefulAsLead(lead) then
                break
            end

            local target = nil
            for i = 2, #hand do
                if hand[i].type ~= lead.type then
                    target = i
                    break
                end
            end
            if not target then
                target = math.min(#hand, 2)
            end

            if not moveCard(hand, 1, target, moveCounts) then
                break
            end
        end
    end

    if opponentState.discardNext and #opponentState.hand > 0 then
        local discarded = table.remove(opponentState.hand, 1)
        opponentState.discardNext = false
        animation.burnCard(discarded, 0, 0.2)
        resetTransientCardState(discarded)
        table.insert(opponentState.burnPile, discarded)
        animateOpponentHandToLayout()
        logCombat("Opponent discarded a card from Ace of Hearts.")
    end

    if tutorialFlow.active and tutorialFlow.step == 7 then
        reorderOpponentTutorialJack68(opponentState.hand)
    else
        reorderEnemyHand()
    end
    animateOpponentHandToLayout()

    local enemyPlayCards = 1
    if not (tutorialFlow.active and tutorialFlow.step == 7) and currentEncounterProfile and currentEncounterProfile.extraPlayChance and love.math.random() < currentEncounterProfile.extraPlayChance then
        enemyPlayCards = enemyPlayCards + 1
    end
    local lastEnemyPlayedCard = nil

    local function playNextEnemyCard()
        if enemyPlayCards <= 0 or #opponentState.hand == 0 then
            local marker = {x = 0}
            animation.slideTo(marker, pacedDuration(0.35), 1, nil):oncomplete(function()
                if tutorialFlow.active and tutorialFlow.step == 7 then
                    tutorialFlow.step = 8
                    if tutorialMascot then
                        tutorialMascot.visible = true
                    end
                    setTutorialMessage("If you hadn't figured it out yet, the (Jack)[blue] calls for two more cards to be played.")
                    tutorialFlow.awaitingClick = true
                    tutorialFlow.finishEnemyResolve = function()
                        resolveActivationPhases("opponent", function()
                            opponentState.lastAction = {kind = "attack", amount = 0}
                            tutorialFlow.step = 10
                            tutorialFlow.turn2DrawTriggered = false
                            if tutorialMascot then
                                tutorialMascot.visible = true
                            end
                            setTutorialMessage("Okay, your turn again. You'll first automatically refill your hand back up to 8 cards.")
                        end)
                    end
                    return
                end
                resolveActivationPhases("opponent", function()
                    opponentState.lastAction = {kind = "attack", amount = 0}
                    if done then done() end
                end)
            end)
            return
        end

        local card = table.remove(opponentState.hand, 1)
        table.insert(opponentState.playTable, card)
        ensureCardVisual(card, opponentDeckZone.x, opponentDeckZone.y)
        card.faceUp = false
        card.revealFaceUp = revealOpponentCards and true or false
        audio.playSound("cardMove", 0.7, 0.97 + (love.math.random() * 0.06))
        animateOpponentHandToLayout()
        animateOpponentPlayTableLayout()
        animation.cardFlip(card, pacedDuration(0.3), function()
            audio.playSound("flip", 0.8)
            card.faceUp = true
            if not revealOpponentCards then
                card.revealFaceUp = true
            end
        end)

        local effectiveType = card.type
        if card.type == deck.types.aceSpades and lastEnemyPlayedCard then
            effectiveType = resolveAceSpadesCopy(card, lastEnemyPlayedCard)
        end
        if effectiveType == deck.types.jack then
            enemyPlayCards = enemyPlayCards + 2
            animation.shake(card, 0.2, 7)
            addDamagePopup("+2", card.x or (scaling.getWidth() * 0.5), (card.y or 120) - 24, {0.35, 0.65, 1, 1})
        end
        enemyPlayCards = enemyPlayCards - 1
        lastEnemyPlayedCard = buildEffectivePlayedSnapshot(card, effectiveType)
        opponentState.lastPlayedCard = lastEnemyPlayedCard

        if effectiveType ~= deck.types.damage and effectiveType ~= deck.types.joker then
            local markerFace = {x = 0}
            animation.slideTo(markerFace, pacedDuration(0.24), 1, nil):oncomplete(function()
                animation.burnCard(card, 0, 0.25):oncomplete(function()
                    for i = #opponentState.playTable, 1, -1 do
                        if opponentState.playTable[i] == card then
                            table.remove(opponentState.playTable, i)
                            break
                        end
                    end
                    resetTransientCardState(card)
                    table.insert(opponentState.burnPile, card)
                    animateOpponentPlayTableLayout()
                    local markerNext = {x = 0}
                    animation.slideTo(markerNext, pacedDuration(0.2), 1, nil):oncomplete(playNextEnemyCard)
                end)
            end)
        else
            local markerNext = {x = 0}
            animation.slideTo(markerNext, pacedDuration(0.2), 1, nil):oncomplete(playNextEnemyCard)
        end
    end

    local reorderPause = {x = 0}
    animation.slideTo(reorderPause, pacedDuration(0.28), 1, nil):oncomplete(function()
        playNextEnemyCard()
    end)
end

local function advanceTutorialFromClick()
    if not tutorialFlow.active or not tutorialFlow.awaitingClick then return end
    if not tutorialTypewriterDone() then return end
    local s = tutorialFlow.step
    if s == 4 then
        tutorialFlow.step = 5
        setTutorialMessage("Normally you can't see what your opponent is holding, but I'll let you peek for now.")
    elseif s == 5 then
        tutorialFlow.step = 6
        revealOpponentCards = true
        animateSetRevealOpponentCards(true)
        setTutorialMessage("They will now start their turn by reordering their cards, notice how they put the (Jack)[blue] first.")
    elseif s == 6 then
        tutorialFlow.awaitingClick = false
        tutorialFlow.step = 7
        if tutorialMascot then tutorialMascot.visible = false end
        runEnemyTurn(function()
            if not tutorialFlow.active then
                beginNextTurn()
            end
        end)
    elseif s == 8 then
        tutorialFlow.awaitingClick = false
        if tutorialMascot then tutorialMascot.visible = false end
        if tutorialFlow.finishEnemyResolve then
            local fn = tutorialFlow.finishEnemyResolve
            tutorialFlow.finishEnemyResolve = nil
            fn()
        end
    elseif s == 11 then
        tutorialFlow.step = 12
        setTutorialMessage("The (Joker)[yellow, floating] card absorbs all damage on the table, and doubles it. So alone it's useless, but with a lot of cards on the table it's really strong.")
    elseif s == 12 then
        tutorialFlow.step = 13
        setTutorialMessage("Try playing the following order: (Jack)[blue], any (Damage)[red] card, and a (joker)[yellow, floating].")
    elseif s == 13 then
        tutorialFlow.awaitingClick = false
        tutorialFlow.step = 14
    elseif s == 15 then
        tutorialFlow.awaitingClick = false
        if tutorialMascot then tutorialMascot.visible = false end
        resolveActivationPhases("player", function()
            tutorialFlow.step = 16
            if tutorialMascot then tutorialMascot.visible = true end
            setTutorialMessage("We've just about covered everything, except the discard button. How it works is simple, you get 3 discards per encounter, and pressing it simply removes the left most 4 cards from your hand.")
            tutorialFlow.awaitingClick = true
        end)
    elseif s == 16 then
        tutorialFlow.step = 17
        setTutorialMessage("I think you know all you need to. As a final note, (Aces)[purple, floating] each have their own special effect, you can see any card's effect simply by hovering your cursor over them.")
    elseif s == 17 then
        tutorialFlow.step = 18
        setTutorialMessage("That's all! I hope you enjoy the game!")
    elseif s == 18 then
        tutorialFlow.active = false
        tutorialMascot = nil
        screen.switch("menu")
    end
end

local function resolvePlayChain(lastPlayedCard)
    if state.playCards <= 0 or #state.hand == 0 then
        if tutorialFlow.active and tutorialFlow.step == 14 then
            local dmgN, jokN = 0, 0
            for _, c in ipairs(state.playTable) do
                if not c.burned and c.type == deck.types.damage then
                    dmgN = dmgN + 1
                end
                if not c.burned and c.type == deck.types.joker then
                    jokN = jokN + 1
                end
            end
            if dmgN >= 1 and jokN >= 1 then
                resolvingPlay = false
                phaseLabel = "Resolving"
                animateHandToLayout()
                animatePlayTableLayout()
                tutorialFlow.step = 15
                if tutorialMascot then
                    tutorialMascot.visible = true
                end
                setTutorialMessage("So now you have a (Damage)[red] card and a (Joker)[yellow, floating] on the table, watch what happens. The (Joker)[yellow, floating] will consume the (Damage)[red] card, and double all consumed damage, before dealing it to the opponent.")
                tutorialFlow.awaitingClick = true
                return
            end
        end
        resolvingPlay = false
        phaseLabel = "Resolving"
        animateHandToLayout()
        animatePlayTableLayout()
        resolveActivationPhases("player", function()
            if tutorialFlow.active and tutorialFlow.step == 3 then
                tutorialFlow.step = 4
                if tutorialMascot then
                    tutorialMascot.visible = true
                end
                setTutorialMessage("Okay, so you dealt damage to your opponent, that's a start! Now it's their turn to play.")
                tutorialFlow.awaitingClick = true
                return
            end
            runEnemyTurn(function()
                beginNextTurn()
            end)
        end)
        return
    end

    local played = gamestate.playFromHand(state)
    if not played then
        resolvingPlay = false
        animateHandToLayout()
        animatePlayTableLayout()
        return
    end

    state.playCards = state.playCards - 1
    audio.playSound("cardMove", 0.8, 0.98 + (love.math.random() * 0.05))
    audio.playSound("play", 0.9)
    ensureCardVisual(played, played.x or deckZone.x, played.y or deckZone.y)
    played.rotation = 0

    animateHandToLayout()
    animatePlayTableLayout()

    local effectiveType = played.type
    if played.type == deck.types.aceSpades and lastPlayedCard then
        effectiveType = resolveAceSpadesCopy(played, lastPlayedCard)
        if effectiveType == deck.types.jack then
            logCombat("Ace of Spades copied Jack: +2 play cards.")
        elseif effectiveType == deck.types.damage then
            logCombat("Ace of Spades copied previous damage card.")
        elseif effectiveType == deck.types.joker then
            logCombat("Ace of Spades copied previous joker.")
        else
            logCombat("Ace of Spades copied " .. (lastPlayedCard.name or "previous card") .. ".")
        end
    end

    if effectiveType ~= deck.types.damage and effectiveType ~= deck.types.joker then
        local function triggerImmediateEffectAndBurn()
            if effectiveType == deck.types.jack then
                applyImmediateOnPlayEffects(played, effectiveType)
            elseif effectiveType == deck.types.king then
                for _, tableCard in ipairs(state.playTable) do
                    if tableCard.type == deck.types.damage and not tableCard.burned then
                        tableCard.damageBonus = (tableCard.damageBonus or 0) + 5
                        addCardEffect(tableCard, "+5", {0.3, 0.95, 0.35, 1}, -0.52, true)
                    end
                end
                logCombat("King Crown buffs table damage cards by +5.")
            elseif effectiveType == deck.types.aceHearts then
                opponentState.discardNext = true
                logCombat("Ace of Hearts set: opponent will discard next card.")
            elseif effectiveType == deck.types.aceClubs then
                local removed = gamestate.destroyFromBurnPile(state, 3)
                logCombat("Ace of Clubs destroyed " .. tostring(#removed) .. " burnt cards.")
            elseif effectiveType == deck.types.aceDiamonds then
                applyMirroredEnemyCardToPlayer(opponentState.lastPlayedCard, played, state.playTable)
            elseif effectiveType == deck.types.queen then
                logCombat("Queen played: no active effect (passive in hand).")
            end

            animation.burnCard(played, 0, 0.25):oncomplete(function()
                audio.playSound("burn", 0.8)
                for i = #state.playTable, 1, -1 do
                    if state.playTable[i] == played then
                        table.remove(state.playTable, i)
                        break
                    end
                end
                resetTransientCardState(played)
                gamestate.burnCard(state, played)
                animatePlayTableLayout()

                local marker2 = {x = 0}
                animation.slideTo(marker2, pacedDuration(0.22), 1, nil):oncomplete(function()
                    resolvePlayChain(buildEffectivePlayedSnapshot(played, effectiveType))
                end)
            end)
        end

        local marker1 = {x = 0}
        animation.slideTo(marker1, pacedDuration(0.24), 1, nil):oncomplete(function()
            triggerImmediateEffectAndBurn()
        end)
        return
    end

    local marker = {x = 0}
    animation.slideTo(marker, pacedDuration(0.22), 1, nil):oncomplete(function()
        resolvePlayChain(buildEffectivePlayedSnapshot(played, effectiveType))
    end)
end

local function beginPlayAction()
    if not canPlayFromHand() then
        return
    end

    if tutorialFlow.active and (tutorialFlow.step == 3 or tutorialFlow.step == 14) and tutorialMascot then
        tutorialMascot.visible = false
    end

    playUsedThisTurn = true
    resolvingPlay = true
    phaseLabel = "Play Chain"
    state.playCards = 1
    turnActionStep = 0
    resolvePlayChain(nil)
end

local function beginDiscardAction()
    if not gameStarted or resolvingPlay or dealing or playUsedThisTurn then
        return
    end
    if state.discardsLeft <= 0 or #state.hand == 0 then
        return
    end

    local discardCount = math.min(4, #state.hand)
    local burnTargets = {}
    for i = 1, discardCount do
        local card = state.hand[i]
        if card then
            ensureCardVisual(card, card.x or deckZone.x, card.y or deckZone.y)
            table.insert(burnTargets, card)
        end
    end

    dealing = true
    local completed = 0
    local function finishDiscardPhase()
        state.discardsLeft = state.discardsLeft - 1
        logCombat("Discarded " .. tostring(discardCount) .. " cards.")
        local missing = math.max(0, state.handSize - #state.hand)
        if missing > 0 then
            queueDrawToHand(missing, 0)
            local totalDealTime = (0.45 + math.max(0, missing - 1) * 0.08) / gameconfig.getGameSpeed()
            local marker = {x = 0}
            animation.slideTo(marker, totalDealTime + 0.05, 1, nil):oncomplete(function()
                dealing = false
                animateHandToLayout()
            end)
        else
            dealing = false
            animateHandToLayout()
        end
    end

    for i, card in ipairs(burnTargets) do
        animation.burnCard(card, (i - 1) * 0.05, 0.22):oncomplete(function()
            for idx = #state.hand, 1, -1 do
                if state.hand[idx] == card then
                    table.remove(state.hand, idx)
                    break
                end
            end
            resetTransientCardState(card)
            gamestate.burnCard(state, card)
            completed = completed + 1
            if completed >= #burnTargets then
                finishDiscardPhase()
            end
        end)
    end

end

beginNextTurn = function()
    if not gameStarted or resolvingPlay or dealing then
        return
    end

    turnNumber = turnNumber + 1
    playUsedThisTurn = false
    queenPassiveUsedThisTurn = false
    phaseLabel = "Player Turn"

    local missing = math.max(0, state.handSize - #state.hand)
    local enemyMissing = math.max(0, state.handSize - #opponentState.hand)
    if missing > 0 or enemyMissing > 0 then
        dealing = true
        queueDrawToHand(missing, 0)
        queueDrawOpponentToHand(enemyMissing, 0)
        local maxDraw = math.max(missing, enemyMissing)
        local totalDealTime = (0.45 + math.max(0, maxDraw - 1) * 0.08) / gameconfig.getGameSpeed()
        local marker = {x = 0}
        animation.slideTo(marker, totalDealTime + 0.05, 1, nil):oncomplete(function()
            dealing = false
            animateHandToLayout()
            animateOpponentHandToLayout()
            if tutorialFlow.afterTurnDeal then
                local fn = tutorialFlow.afterTurnDeal
                tutorialFlow.afterTurnDeal = nil
                fn()
            end
        end)
    else
        animateHandToLayout()
        animateOpponentHandToLayout()
        if tutorialFlow.afterTurnDeal then
            local fn = tutorialFlow.afterTurnDeal
            tutorialFlow.afterTurnDeal = nil
            fn()
        end
    end
end

local function getDraggedInsertIndex(mouseX)
    if #state.hand <= 1 then
        return 1
    end

    local count = #state.hand
    local bestIndex = 1
    local bestDistance = math.huge
    for i = 1, count do
        local x = getHandPosition(i, count)
        local center = x + (cards.cardWidth * cardScale) / 2
        local dist = math.abs(mouseX - center)
        if dist < bestDistance then
            bestDistance = dist
            bestIndex = i
        end
    end
    return bestIndex
end

local function cardHit(card, px, py)
    local cw = cards.cardWidth * cardScale
    local ch = cards.cardHeight * cardScale
    return px >= card.x and px <= card.x + cw and py >= card.y and py <= card.y + ch
end

local function getTopHoveredHandCard(px, py)
    for i = #state.hand, 1, -1 do
        local card = state.hand[i]
        if card ~= draggedCard and cardHit(card, px, py) then
            return card
        end
    end
    return nil
end

local function updateDragFromMouse()
    if not draggedCard then return end
    local mx, my = love.mouse.getPosition()
    local gx, gy = scaling.screenToGame(mx, my)

    draggedCard.x = gx - dragOffsetX
    draggedCard.y = gy - dragOffsetY
    draggedCard.rotation = 0

    local nextInsert = getDraggedInsertIndex(gx)
    if nextInsert ~= dragInsertIndex then
        dragInsertIndex = nextInsert
        animateHandToLayout()
    end
end

local function commitDraggedOrder()
    if not draggedCard or not draggedIndex or not dragInsertIndex then
        draggedCard = nil
        draggedIndex = nil
        dragInsertIndex = nil
        return
    end

    local originalIndex = draggedIndex
    table.remove(state.hand, draggedIndex)
    local finalIndex = math.max(1, math.min(dragInsertIndex, #state.hand + 1))
    table.insert(state.hand, finalIndex, draggedCard)

    draggedCard = nil
    draggedIndex = nil
    dragInsertIndex = nil
    animateHandToLayout()

    if tutorialFlow.active and tutorialFlow.step == 2 and finalIndex ~= originalIndex then
        tutorialFlow.step = 3
        setTutorialMessage("Good! Now look at the (play)[green, floating] button, when you press that, the left most card in your hand is played. Now try playing any (number)[red] card.")
    end
end

function game.enter(opts)
    if type(opts) == "boolean" then
        opts = {tutorial = opts}
    end
    opts = opts or {}
    tutorialEnabled = opts.tutorial == true
    if tutorialEnabled then
        tutorialFlow.active = true
        tutorialFlow.step = 0
        tutorialFlow.awaitingClick = false
        tutorialFlow.settingsWasOpen = false
        tutorialFlow.turn2DrawTriggered = false
        tutorialFlow.finishEnemyResolve = nil
        tutorialFlow.afterTurnDeal = nil
        resetTutorialMascot()
    else
        tutorialFlow.active = false
        tutorialFlow.step = 0
        tutorialFlow.awaitingClick = false
        tutorialFlow.settingsWasOpen = false
        tutorialFlow.turn2DrawTriggered = false
        tutorialFlow.finishEnemyResolve = nil
        tutorialFlow.afterTurnDeal = nil
        tutorialMascot = nil
    end
    state = gamestate.new()
    state.deck = opts.deck and deck.copy(opts.deck) or deck.build()
    if tutorialEnabled then
        state.deck = buildTutorialOpeningDeck()
    else
        deck.shuffle(state.deck)
    end
    runGold = opts.gold or runGold
    encounterIndex = opts.encounter or 1
    currentEncounterProfile = getEncounterProfile(encounterIndex)
    -- Tutorial deck rigging will be wired here later for both player and enemy.
    -- if tutorialEnabled then
    --     state.deck = buildRiggedPlayerTutorialDeck()
    --     opponentState.deck = buildRiggedEnemyTutorialDeck()
    -- end

    local gh = scaling.getHeight()
    local gw = scaling.getWidth()
    startBtn = ui.makeButton("Start Encounter", gw - 350, gh - 230, {
        font = "small",
        color = {0.2, 0.5, 0.2, 0.95},
        padding = 16
    })
    playBtn = ui.makeButton("Play", gw - 350, gh - 155, {
        font = "small",
        color = {0.75, 0.3, 0.2, 0.95},
        padding = 16
    })
    discardBtn = ui.makeButton("Discard", gw - 350, gh - 85, {
        font = "small",
        color = {0.28, 0.28, 0.52, 0.95},
        padding = 16
    })
    deckZone = {
        x = gw - 130,
        y = gh - (cards.cardHeight * cardScale) - 30,
        w = cards.cardWidth * cardScale,
        h = cards.cardHeight * cardScale
    }
    opponentDeckZone = {
        x = gw - 130,
        y = 24,
        w = cards.cardWidth * cardScale,
        h = cards.cardHeight * cardScale
    }

    opponentState = {
        deck = tutorialEnabled and buildTutorialOpeningDeck() or deck.build(),
        hand = {},
        playTable = {},
        burnPile = {},
        lastAction = nil,
        lastPlayedCard = nil,
        discardNext = false
    }
    if not tutorialEnabled then
        deck.shuffle(opponentState.deck)
    end

    gameStarted = false
    dealing = false
    resolvingPlay = false
    playUsedThisTurn = false
    turnNumber = 1
    enemyMaxHP = currentEncounterProfile.enemyHP
    enemyHP = enemyMaxHP
    queenBlockActive = false
    queenPassiveUsedThisTurn = false
    combatLog = {}
    damagePopups = {}
    enemyShake.x = 0
    playerShake.x = 0
    draggedCard = nil
    draggedIndex = nil
    dragInsertIndex = nil
    hoveredCard = nil
    revealOpponentCards = false
    encounterEnded = false
    phaseLabel = "Player Turn"
    settingsUI = settingsOverlay.create({showPreview = false})
end

function game.update(dt)
    if checkEncounterOutcome() then return end
    background.update(dt)
    ui.updateButtonHover(startBtn, animation)
    ui.updateButtonHover(playBtn, animation)
    ui.updateButtonHover(discardBtn, animation)
    if settingsUI then settingsUI.update(dt) end
    if tutorialMascot then
        updateTutorialMascot(dt)
    end
    if tutorialFlow.active and tutorialFlow.step == 1 and settingsUI then
        if settingsUI:isOpen() then
            tutorialFlow.settingsWasOpen = true
        elseif tutorialFlow.settingsWasOpen and gameconfig.getGameSpeed() <= 0.75 then
            tutorialFlow.step = 2
            if tutorialMascot then
                tutorialMascot.visible = true
            end
            setTutorialMessage("These are your cards. You can rearrange them by dragging them with your cursor, give it a try.")
        end
    end
    if tutorialFlow.active and tutorialFlow.step == 10 and tutorialTypewriterDone() and not tutorialFlow.turn2DrawTriggered and not dealing and not resolvingPlay then
        tutorialFlow.turn2DrawTriggered = true
        table.insert(state.deck, makeTutorialCard(deck.types.jack, "clubs"))
        tutorialFlow.afterTurnDeal = function()
            tutorialFlow.step = 11
            if tutorialMascot then
                tutorialMascot.visible = true
            end
            setTutorialMessage("That's a good hand, let's make a strong hit! Let's look at the (Joker)[yellow, floating] card.")
            tutorialFlow.awaitingClick = true
        end
        beginNextTurn()
    end
    updateDragFromMouse()

    local kept = {}
    for _, popup in ipairs(damagePopups) do
        if (popup.alpha or 0) > 0.02 then
            table.insert(kept, popup)
        end
    end
    damagePopups = kept

    if not draggedCard then
        local mx, my = love.mouse.getPosition()
        local gx, gy = scaling.screenToGame(mx, my)
        hoveredCard = getTopHoveredHandCard(gx, gy)
    else
        hoveredCard = nil
    end
end

function game.draw()
    background.draw()
    game.drawOpponent()
    game.drawDeck()
    game.drawHand()
    if not gameStarted then
        ui.drawButton(startBtn)
        local subtitle = tutorialEnabled and "Tutorial enabled for this run." or "Tutorial skipped for this run."
        ui.drawText(subtitle, 24, 24, "small", {1, 1, 1, 0.8})
    else
        local hudX = 24
        local hudY = 24
        local hudStep = 34
        ui.drawButton(playBtn)
        ui.drawButton(discardBtn)
        ui.drawText("Turn " .. tostring(turnNumber), hudX, hudY + (hudStep * 0), "small", {1, 1, 1, 0.8})
        ui.drawText("Phase: " .. phaseLabel, hudX, hudY + (hudStep * 1), "small", {0.85, 0.95, 1, 1})
        ui.drawText("Encounter " .. tostring(encounterIndex), hudX, hudY + (hudStep * 2), "small", {0.9, 0.9, 1, 1})
        ui.drawText("Player HP: " .. tostring(state.playerHP) .. "/" .. tostring(state.playerMaxHP), hudX, hudY + (hudStep * 3), "small", {0.85, 1, 0.85, 1})
        ui.drawText("Enemy HP: " .. tostring(enemyHP) .. "/" .. tostring(enemyMaxHP), hudX, hudY + (hudStep * 4), "small", {1, 0.85, 0.85, 1})
        ui.drawText("Discards Left: " .. tostring(state.discardsLeft), hudX, hudY + (hudStep * 5), "small", {0.75, 0.85, 1, 0.95})
        if playUsedThisTurn then
            ui.drawText("Play used this turn", hudX, hudY + (hudStep * 6), "small", {1, 0.8, 0.6, 0.95})
        end
        for i, line in ipairs(combatLog) do
            ui.drawText(line, hudX, hudY + (hudStep * 7) + ((i - 1) * 30), "small", {0.92, 0.92, 0.92, 1})
        end
    end

    for _, popup in ipairs(damagePopups) do
        local c = popup.color
        ui.drawText(popup.text, popup.x, popup.y, "small", {c[1], c[2], c[3], popup.alpha or 1})
    end

    if tutorialMascot then
        drawTutorialMascot()
    end
    game.drawTooltip()
    if settingsUI then settingsUI.draw() end
end

function game.drawDeck()
    local back = cards.getBack()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(back, deckZone.x + playerShake.x, deckZone.y, 0, cardScale, cardScale)

    local deckCount = tostring(#state.deck)
    local font = ui.getFont("small")
    local textX = deckZone.x + playerShake.x + (deckZone.w - font:getWidth(deckCount)) / 2
    ui.drawText(deckCount, textX, deckZone.y + deckZone.h + 6, "small", {1, 1, 1, 0.95})
end

function game.drawOpponent()
    if not opponentState or not opponentState.hand or not opponentState.deck then
        return
    end

    local back = cards.getBack()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(back, opponentDeckZone.x + enemyShake.x, opponentDeckZone.y, 0, cardScale, cardScale)

    for i = 1, #opponentState.hand do
        local card = opponentState.hand[i]
        local x, y = getOpponentHandPosition(i, #opponentState.hand)
        ensureCardVisual(card, x, y)
        card.targetX = x
        card.targetY = y
        card.targetRotation = -getHandRotation(i, #opponentState.hand)
        local faceUp = card.revealFaceUp == true
        cards.draw(card, card.x + enemyShake.x, card.y, cardScale, faceUp)
    end

    local deckCount = tostring(#opponentState.deck)
    local font = ui.getFont("small")
    local textX = opponentDeckZone.x + enemyShake.x + (opponentDeckZone.w - font:getWidth(deckCount)) / 2
    ui.drawText(deckCount, textX, opponentDeckZone.y + opponentDeckZone.h + 6, "small", {1, 1, 1, 0.95})
end

function game.drawTooltip()
    if not hoveredCard then return end
    local mx, my = love.mouse.getPosition()
    local gx, gy = scaling.screenToGame(mx, my)
    local title, effect = getCardTooltip(hoveredCard)
    local font = ui.getFont("small")
    local padding = 10
    local w = math.max(font:getWidth(title), font:getWidth(effect)) + padding * 2
    local h = font:getHeight() * 2 + padding * 2 + 6
    local x = math.min(gx + 18, scaling.getWidth() - w - 8)
    local y = math.max(8, gy - h - 10)

    love.graphics.setColor(0.08, 0.08, 0.08, 0.95)
    love.graphics.rectangle("fill", x, y, w, h, 6, 6)
    love.graphics.setColor(1, 1, 1, 1)
    ui.drawText(title, x + padding, y + padding, "small")
    ui.drawText(effect, x + padding, y + padding + font:getHeight() + 6, "small", {0.85, 0.85, 0.85, 1})
end

function game.drawHand()
    for _, card in ipairs(state.playTable) do
        ensureCardVisual(card, deckZone.x, deckZone.y)
        cards.draw(card, card.x + playerShake.x, card.y, cardScale, true)
    end

    for _, card in ipairs(opponentState.playTable) do
        ensureCardVisual(card, opponentDeckZone.x, opponentDeckZone.y)
        local baseFace = card.faceUp == true
        local faceUp = (card.revealFaceUp == nil) and baseFace or (card.revealFaceUp == true)
        cards.draw(card, card.x + enemyShake.x, card.y, cardScale, faceUp)
    end

    for _, card in ipairs(state.hand) do
        if card ~= draggedCard then
            ensureCardVisual(card, deckZone.x, deckZone.y)
            cards.draw(card, card.x + playerShake.x, card.y, cardScale, card.faceUp)
        end
    end

    if draggedCard then
        cards.draw(draggedCard, draggedCard.x + playerShake.x, draggedCard.y, cardScale, draggedCard.faceUp)
    end
end

function game.mousepressed(x, y, button)
    if encounterEnded then return end
    if settingsUI and settingsUI.mousepressed(x, y, button) then
        return
    end
    local gx, gy = scaling.screenToGame(x, y)

    if tutorialFlow.active and tutorialFlow.awaitingClick and button == 1 and tutorialTypewriterDone() then
        if not tutorialBlocksUiClick(gx, gy) then
            audio.playSound("uiClick", 0.65)
            advanceTutorialFromClick()
            return
        end
    end

    if button == 1 and gameStarted and ui.pointInRect(gx, gy, playBtn) then
        if tutorialFlow.active then
            if tutorialFlow.awaitingClick then
                audio.playSound("invalid", 0.9)
                return
            end
            if tutorialFlow.step ~= 3 and tutorialFlow.step ~= 14 then
                audio.playSound("invalid", 0.9)
                return
            end
        end
        if tutorialFlow.active and tutorialFlow.step == 3 and #state.hand > 0 then
            local leftmost = state.hand[1]
            if leftmost and leftmost.type ~= deck.types.damage then
                audio.playSound("queenBlock", 0.9)
                return
            end
        end
        if tutorialFlow.active and tutorialFlow.step == 14 then
            if #state.hand < 3 then
                audio.playSound("queenBlock", 0.9)
                return
            end
            if state.hand[1].type ~= deck.types.jack
                or state.hand[2].type ~= deck.types.damage
                or state.hand[3].type ~= deck.types.joker then
                audio.playSound("queenBlock", 0.9)
                return
            end
        end
        audio.playSound("uiClick")
        beginPlayAction()
        return
    end

    if button == 1 and gameStarted and ui.pointInRect(gx, gy, discardBtn) then
        if tutorialFlow.active then
            audio.playSound("invalid", 0.9)
            return
        end
        audio.playSound("uiClick")
        beginDiscardAction()
        return
    end

    if button == 1 and gameStarted and not dealing then
        if tutorialFlow.active and tutorialFlow.awaitingClick then
            return
        end
        if tutorialFlow.active and tutorialFlow.step < 2 then
            audio.playSound("invalid", 0.9)
            return
        end
        for i = #state.hand, 1, -1 do
            local card = state.hand[i]
            if cardHit(card, gx, gy) then
                draggedCard = card
                draggedIndex = i
                dragInsertIndex = i
                dragOffsetX = gx - card.x
                dragOffsetY = gy - card.y
                audio.playSound("paper1", 0.65)
                return
            end
        end
    end

    if not gameStarted and ui.pointInRect(gx, gy, startBtn) and not dealing then
        audio.playSound("uiClick")
        if tutorialFlow.active and tutorialMascot then
            tutorialMascot.visible = false
        end
        gameStarted = true
        dealing = true

        local drawCount = math.min(state.handSize, #state.deck)
        for i = 1, drawCount do
            local card = table.remove(state.deck)
            table.insert(state.hand, card)
            queueCardToHand(card, i, drawCount, (i - 1) * 0.08)
        end

        if opponentState and opponentState.deck and opponentState.hand then
            local opponentDrawCount = math.min(state.handSize, #opponentState.deck)
            for i = 1, opponentDrawCount do
                local card = table.remove(opponentState.deck)
                table.insert(opponentState.hand, card)
                queueOpponentCardToHand(card, i, opponentDrawCount, (i - 1) * 0.08)
            end
        end

        local totalDealTime = (0.45 + math.max(0, drawCount - 1) * 0.08) / gameconfig.getGameSpeed()
        local marker = {x = 0}
        animation.slideTo(marker, totalDealTime + 0.05, 1, nil):oncomplete(function()
            dealing = false
            animateHandToLayout()
            animateOpponentHandToLayout()
            if tutorialFlow.active then
                if gameconfig.getGameSpeed() > 0.75 then
                    tutorialFlow.step = 1
                    tutorialFlow.settingsWasOpen = false
                    if tutorialMascot then
                        tutorialMascot.visible = true
                    end
                    setTutorialMessage("Whoa now, that's a little fast isn't it! Try lowering the game speed to 75% in the settings panel.")
                else
                    tutorialFlow.step = 2
                    if tutorialMascot then
                        tutorialMascot.visible = true
                    end
                    setTutorialMessage("These are your cards. You can rearrange them by dragging them with your cursor, give it a try.")
                end
            end
        end)
    end
end

function game.mousereleased(x, y, button)
    if settingsUI then settingsUI.mousereleased(x, y, button) end
    if button == 1 and draggedCard then
        audio.playSound("other1", 0.65)
        commitDraggedOrder()
    end
end

return game
