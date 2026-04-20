local deck = {}
local nextCardId = 1

deck.types = {
    damage = "damage",
    jack = "jack",
    queen = "queen",
    king = "king",
    aceHearts = "aceHearts",
    aceSpades = "aceSpades",
    aceClubs = "aceClubs",
    aceDiamonds = "aceDiamonds",
    joker = "joker"
}

deck.suits = {"hearts", "diamonds", "clubs", "spades"}

function deck.createCard(type, suit, value)
    local card = {
        id = nextCardId,
        type = type,
        suit = suit,
        value = value or 0,
        name = "",
        faceUp = true,
        scaleX = 1,
        alpha = 1
    }
    nextCardId = nextCardId + 1
    return card
end

function deck.build()
    local d = {}

    for _, suit in ipairs(deck.suits) do
        for value = 6, 10 do
            local card = deck.createCard(deck.types.damage, suit, value)
            card.name = value .. " of " .. suit
            table.insert(d, card)
        end
    end

    for _, suit in ipairs(deck.suits) do
        local jack = deck.createCard(deck.types.jack, suit)
        jack.name = "Jack of " .. suit
        table.insert(d, jack)

        local queen = deck.createCard(deck.types.queen, suit)
        queen.name = "Queen of " .. suit
        table.insert(d, queen)

        local king = deck.createCard(deck.types.king, suit)
        king.name = "King of " .. suit
        table.insert(d, king)
    end

    local aceMap = {
        hearts = deck.types.aceHearts,
        diamonds = deck.types.aceDiamonds,
        clubs = deck.types.aceClubs,
        spades = deck.types.aceSpades
    }
    for suit, aceType in pairs(aceMap) do
        local ace = deck.createCard(aceType, suit)
        ace.name = "Ace of " .. suit
        table.insert(d, ace)
    end

    for i = 1, 2 do
        local joker = deck.createCard(deck.types.joker, nil)
        joker.name = "Joker"
        joker.storedDamage = 0
        joker.jokerIndex = i - 1
        table.insert(d, joker)
    end

    return d
end

function deck.shuffle(d)
    for i = #d, 2, -1 do
        local j = love.math.random(1, i)
        d[i], d[j] = d[j], d[i]
    end
end

function deck.copy(d)
    local new = {}
    for i, card in ipairs(d) do
        local c = {}
        for k, v in pairs(card) do
            c[k] = v
        end
        table.insert(new, c)
    end
    return new
end

return deck
