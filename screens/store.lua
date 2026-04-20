local scaling = require("lib.scaling")
local ui = require("lib.ui")
local animation = require("lib.animation")
local background = require("lib.background")
local cards = require("lib.cards")
local deck = require("lib.deck")
local audio = require("lib.audio")
local settingsOverlay = require("lib.settingsoverlay")
local screen = require("lib.screen")

local store = {}

local deckCards = {}
local gold = 20
local encounter = 1
local continueBtn
local buyButtons = {}
local shopItems = {}
local hoveredCard = nil
local storeFeedback = ""
local storeFeedbackTimer = 0
local settingsUI

local suitRow = {
    hearts = 1,
    spades = 2,
    clubs = 3,
    diamonds = 4
}

local function sanitizeCardVisual(card)
    card.x = nil
    card.y = nil
    card.targetX = nil
    card.targetY = nil
    card.rotation = 0
    card.alpha = 1
    card.scaleX = 1
    card.fxLabels = nil
    card.faceUp = true
    card.revealFaceUp = nil
    card.consumed = nil
    card.burned = nil
    card.pendingDamage = nil
    card.damageBonus = nil
end

local function randomShopItems(count)
    local pool = deck.build()
    local items = {}
    for i = 1, count do
        if #pool == 0 then break end
        local idx = love.math.random(1, #pool)
        local card = table.remove(pool, idx)
        local cost = 5
        if card.type == deck.types.damage then
            cost = 4 + math.max(0, (card.value or 6) - 6)
        elseif card.type == deck.types.joker then
            cost = 14
        elseif card.type == deck.types.aceHearts or card.type == deck.types.aceSpades or card.type == deck.types.aceClubs or card.type == deck.types.aceDiamonds then
            cost = 12
        elseif card.type == deck.types.king then
            cost = 11
        elseif card.type == deck.types.queen then
            cost = 9
        elseif card.type == deck.types.jack then
            cost = 8
        end
        table.insert(items, {card = card, cost = cost, sold = false})
    end
    return items
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
    return card.name or "Card", effectByType[card.type] or "No effect."
end

local function cardHit(x, y, w, h, px, py)
    return px >= x and px <= x + w and py >= y and py <= y + h
end

local function cardRow(card)
    if card.type == deck.types.joker then
        return 5
    end
    return suitRow[card.suit] or 6
end

local function cardCol(card)
    if card.type == deck.types.joker then
        return (card.jokerIndex or 0) + 1
    elseif card.type == deck.types.damage then
        return math.max(1, math.min(13, card.value or 1))
    elseif card.type == deck.types.jack then
        return 11
    elseif card.type == deck.types.queen then
        return 12
    elseif card.type == deck.types.king then
        return 13
    elseif card.type == deck.types.aceHearts or card.type == deck.types.aceSpades or card.type == deck.types.aceClubs or card.type == deck.types.aceDiamonds then
        return 1
    end
    return 13
end

local function sortedDeckView()
    local copy = deck.copy(deckCards)
    table.sort(copy, function(a, b)
        local ar, br = cardRow(a), cardRow(b)
        if ar ~= br then return ar < br end
        local ac, bc = cardCol(a), cardCol(b)
        if ac ~= bc then return ac < bc end
        return (a.name or "") < (b.name or "")
    end)
    return copy
end

local function getDeckLayout()
    local view = sortedDeckView()
    local scale = 1.25
    local cw = cards.cardWidth * scale
    local ch = cards.cardHeight * scale
    local colSpacing = cw + 6
    local rowSpacing = ch + 10
    local deckX = 700
    local deckY = 120
    local deckWidth = scaling.getWidth() - deckX - 30
    local cols = math.max(1, math.floor((deckWidth + 6) / colSpacing))
    local grouped = {
        hearts = {},
        spades = {},
        clubs = {},
        diamonds = {},
        jokers = {},
        other = {}
    }
    for _, card in ipairs(view) do
        if card.type == deck.types.joker then
            table.insert(grouped.jokers, card)
        elseif card.suit == "hearts" or card.suit == "spades" or card.suit == "clubs" or card.suit == "diamonds" then
            table.insert(grouped[card.suit], card)
        else
            table.insert(grouped.other, card)
        end
    end

    local function sortRow(rowCards)
        table.sort(rowCards, function(a, b)
            local ac, bc = cardCol(a), cardCol(b)
            if ac ~= bc then return ac < bc end
            return (a.name or "") < (b.name or "")
        end)
    end
    sortRow(grouped.hearts)
    sortRow(grouped.spades)
    sortRow(grouped.clubs)
    sortRow(grouped.diamonds)
    sortRow(grouped.jokers)
    sortRow(grouped.other)

    local slots = {}
    local visualRow = 0
    local function appendPackedRow(rowCards)
        if #rowCards == 0 then
            return
        end
        for i, card in ipairs(rowCards) do
            local rowOffset = math.floor((i - 1) / cols)
            local col = (i - 1) % cols
            table.insert(slots, {
                card = card,
                row = visualRow + rowOffset,
                col = col
            })
        end
        visualRow = visualRow + math.ceil(#rowCards / cols)
    end

    appendPackedRow(grouped.hearts)
    appendPackedRow(grouped.spades)
    appendPackedRow(grouped.clubs)
    appendPackedRow(grouped.diamonds)
    appendPackedRow(grouped.jokers)
    appendPackedRow(grouped.other)

    local rows = math.max(1, visualRow)
    local blockHeight = rows * rowSpacing
    return {
        view = view,
        slots = slots,
        scale = scale,
        cw = cw,
        ch = ch,
        colSpacing = colSpacing,
        rowSpacing = rowSpacing,
        deckX = deckX,
        deckY = deckY,
        cols = cols,
        rows = rows,
        blockHeight = blockHeight
    }
end

function store.enter(context)
    context = context or {}
    deckCards = context.deck or {}
    for _, c in ipairs(deckCards) do
        sanitizeCardVisual(c)
    end
    gold = context.gold or gold
    encounter = context.encounter or encounter
    shopItems = randomShopItems(5)

    local gw = scaling.getWidth()
    continueBtn = ui.makeButton("Continue", gw - 260, scaling.getHeight() - 90, {
        font = "small",
        color = {0.2, 0.5, 0.2, 0.95},
        padding = 14
    })

    buyButtons = {}
    for i = 1, #shopItems do
        local y = 0
        buyButtons[i] = ui.makeButton("Buy", 480, y, {
            font = "small",
            color = {0.45, 0.35, 0.18, 0.95},
            padding = 12
        })
    end
    settingsUI = settingsOverlay.create({showPreview = false, buttonPosition = "topRight"})
end

function store.update(dt)
    background.update(dt)
    ui.updateButtonHover(continueBtn, animation)
    if settingsUI then settingsUI.update(dt) end
    if storeFeedbackTimer > 0 then
        storeFeedbackTimer = math.max(0, storeFeedbackTimer - dt)
        if storeFeedbackTimer == 0 then
            storeFeedback = ""
        end
    end

    local layout = getDeckLayout()
    local shopY = layout.deckY + layout.blockHeight + 28
    for i, btn in ipairs(buyButtons) do
        btn.x = 320
        btn.y = shopY + ((i - 1) * 62)
        ui.updateButtonHover(btn, animation)
    end

    hoveredCard = nil
    local mx, my = love.mouse.getPosition()
    local gx, gy = scaling.screenToGame(mx, my)

    local layout = getDeckLayout()
    for _, slot in ipairs(layout.slots) do
        local x = layout.deckX + (slot.col * layout.colSpacing)
        local y = layout.deckY + (slot.row * layout.rowSpacing)
        if cardHit(x, y, layout.cw, layout.ch, gx, gy) then hoveredCard = slot.card end
    end

    local shopY = layout.deckY + layout.blockHeight + 28
    local shopScale = 1.6
    local shopW = cards.cardWidth * shopScale
    local shopH = cards.cardHeight * shopScale
    for i, item in ipairs(shopItems) do
        local y = shopY + ((i - 1) * 62)
        local x = 40
        if cardHit(x, y, shopW, shopH, gx, gy) then
            hoveredCard = item.card
        end
    end
end

function store.draw()
    background.draw()
    ui.drawTextCentered("Store", 24, "menu")
    ui.drawText("Gold: " .. tostring(gold), 40, 30, "small", {1, 0.9, 0.5, 1})
    ui.drawText("Encounter " .. tostring(encounter) .. " complete", 40, 70, "small", {0.85, 0.95, 1, 1})
    if storeFeedback ~= "" then
        ui.drawText(storeFeedback, 40, 96, "small", {1, 0.85, 0.6, 1})
    end

    local layout = getDeckLayout()
    ui.drawText("Deck", layout.deckX, layout.deckY - 36, "small", {1, 1, 1, 1})
    for _, slot in ipairs(layout.slots) do
        local x = layout.deckX + (slot.col * layout.colSpacing)
        local y = layout.deckY + (slot.row * layout.rowSpacing)
        cards.draw(slot.card, x, y, layout.scale, true)
    end

    local shopY = layout.deckY + layout.blockHeight + 28
    ui.drawText("Shop", 40, shopY - 36, "small", {1, 1, 1, 1})
    for i, item in ipairs(shopItems) do
        local y = shopY + ((i - 1) * 62)
        cards.draw(item.card, 40, y, 1.6, true)
        ui.drawText("$" .. tostring(item.cost), 145, y + 14, "small", {1, 0.9, 0.6, 1})
        if item.sold then
            ui.drawText("SOLD", 320, y + 14, "small", {1, 0.4, 0.4, 1})
        else
            buyButtons[i].x = 320
            buyButtons[i].y = y
            if gold < item.cost then
                buyButtons[i].color = {0.25, 0.25, 0.25, 0.6}
            else
                buyButtons[i].color = {0.45, 0.35, 0.18, 0.95}
            end
            ui.drawButton(buyButtons[i])
        end
    end

    ui.drawButton(continueBtn)

    if hoveredCard then
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
    if settingsUI then settingsUI.draw() end
end

function store.mousepressed(x, y, button)
    if settingsUI and settingsUI.mousepressed(x, y, button) then
        return
    end
    local gx, gy = scaling.screenToGame(x, y)

    for i, btn in ipairs(buyButtons) do
        if ui.pointInRect(gx, gy, btn) then
            local item = shopItems[i]
            if item and (not item.sold) and gold >= item.cost then
                audio.playSound("buy")
                gold = gold - item.cost
                local copy = deck.copy({item.card})[1]
                sanitizeCardVisual(copy)
                table.insert(deckCards, copy)
                item.sold = true
                storeFeedback = "Purchased " .. (item.card.name or "card")
                storeFeedbackTimer = 1.2
            else
                audio.playSound("invalid")
                if item and item.sold then
                    storeFeedback = "Already purchased."
                else
                    storeFeedback = "Not enough gold."
                end
                storeFeedbackTimer = 1.2
            end
            return
        end
    end

    if ui.pointInRect(gx, gy, continueBtn) then
        audio.playSound("uiClick")
        screen.switch("game", {
            tutorial = false,
            deck = deck.copy(deckCards),
            gold = gold,
            encounter = encounter + 1
        })
    end
end

function store.mousereleased(x, y, button)
    if settingsUI then settingsUI.mousereleased(x, y, button) end
end

return store
