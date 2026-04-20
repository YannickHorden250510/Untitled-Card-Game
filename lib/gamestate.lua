local deck = require("lib.deck")

local gamestate = {}

function gamestate.new()
    return {
        deck = {},
        hand = {},
        playTable = {},
        burnPile = {},
        destroyedCards = {},
        discardsLeft = 3,
        discardsMax = 3,
        handSize = 8,
        playCards = 0,
        playerHP = 100,
        playerMaxHP = 100
    }
end

function gamestate.drawToHand(state)
    while #state.hand < state.handSize and #state.deck > 0 do
        local card = table.remove(state.deck)
        table.insert(state.hand, card)
    end
end

function gamestate.playFromHand(state)
    if #state.hand == 0 then return nil end
    local card = table.remove(state.hand, 1)
    table.insert(state.playTable, card)
    return card
end

function gamestate.discardFromHand(state, indices)
    if state.discardsLeft <= 0 then return false end

    table.sort(indices, function(a, b) return a > b end)

    local count = 0
    for _, i in ipairs(indices) do
        if i >= 1 and i <= #state.hand and count < 4 then
            local card = table.remove(state.hand, i)
            gamestate.burnCard(state, card)
            count = count + 1
        end
    end

    state.discardsLeft = state.discardsLeft - 1
    return true
end

function gamestate.burnCard(state, card)
    table.insert(state.burnPile, card)
end

function gamestate.destroyFromBurnPile(state, count)
    count = count or 3
    local destroyed = {}
    for i = 1, count do
        if #state.burnPile == 0 then break end
        local card = table.remove(state.burnPile)
        table.insert(state.destroyedCards, card)
        table.insert(destroyed, card)
    end
    return destroyed
end

function gamestate.clearTable(state)
    for _, card in ipairs(state.playTable) do
        gamestate.burnCard(state, card)
    end
    state.playTable = {}
end

function gamestate.isDeckEmpty(state)
    return #state.deck == 0
end

function gamestate.resetEncounter(state)
    for _, card in ipairs(state.burnPile) do
        table.insert(state.deck, card)
    end
    state.burnPile = {}
    state.hand = {}
    state.playTable = {}
    state.playCards = 0
    state.discardsLeft = state.discardsMax
    state.playerHP = state.playerMaxHP
end

function gamestate.startEncounter(state)
    deck.shuffle(state.deck)
    gamestate.drawToHand(state)
end

function gamestate.damagePlayer(state, amount)
    state.playerHP = math.max(0, state.playerHP - amount)
    return state.playerHP <= 0
end

function gamestate.healPlayer(state, amount)
    state.playerHP = math.min(state.playerMaxHP, state.playerHP + amount)
end

function gamestate.isPlayerDead(state)
    return state.playerHP <= 0
end

return gamestate
