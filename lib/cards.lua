local cards = {}

cards.spriteSheets = {}
cards.currentSheet = nil

cards.backs = {}
cards.currentBack = nil

cards.cardWidth = 23
cards.cardHeight = 35
cards.gap = 1

cards.suitRow = {
    hearts = 0,
    spades = 1,
    clubs = 2,
    diamonds = 3
}

local columnMap = {
    damage = function(card) return card.value - 1 end,
    jack = function() return 10 end,
    queen = function() return 11 end,
    king = function() return 12 end,
    aceHearts = function() return 0 end,
    aceSpades = function() return 0 end,
    aceClubs = function() return 0 end,
    aceDiamonds = function() return 0 end,
}

function cards.getColumn(card)
    local fn = columnMap[card.type]
    return fn and fn(card) or 0
end

function cards.loadSheet(name, path, jokerPath)
    local sheet = {
        image = love.graphics.newImage(path),
        jokerImage = love.graphics.newImage(jokerPath),
        quads = {},
        jokerQuads = {}
    }
    sheet.image:setFilter("nearest", "nearest")
    sheet.jokerImage:setFilter("nearest", "nearest")

    local iw, ih = sheet.image:getDimensions()
    local jw, jh = sheet.jokerImage:getDimensions()

    for row = 0, 3 do
        for col = 0, 12 do
            local x = col * (cards.cardWidth + cards.gap)
            local y = row * (cards.cardHeight + cards.gap)
            local key = row .. "_" .. col
            sheet.quads[key] = love.graphics.newQuad(x, y, cards.cardWidth, cards.cardHeight, iw, ih)
        end
    end

    for i = 0, 2 do
        local x = i * (cards.cardWidth + cards.gap)
        sheet.jokerQuads[i] = love.graphics.newQuad(x, 0, cards.cardWidth, cards.cardHeight, jw, jh)
    end

    cards.spriteSheets[name] = sheet
    if not cards.currentSheet then
        cards.currentSheet = name
    end
end

function cards.loadBack(name, path)
    local back = love.graphics.newImage(path)
    back:setFilter("nearest", "nearest")
    cards.backs[name] = back
    if not cards.currentBack then
        cards.currentBack = name
    end
end

function cards.setSheet(name)
    cards.currentSheet = name
end

function cards.setBack(name)
    cards.currentBack = name
end

function cards.getQuad(card)
    local sheet = cards.spriteSheets[cards.currentSheet]
    if card.type == "joker" then
        return sheet.jokerImage, sheet.jokerQuads[card.jokerIndex or 0]
    end
    local row = cards.suitRow[card.suit]
    local col = cards.getColumn(card)
    local key = row .. "_" .. col
    return sheet.image, sheet.quads[key]
end

function cards.getBack()
    return cards.backs[cards.currentBack]
end

function cards.draw(card, x, y, cardScale, faceUp)
    faceUp = faceUp == nil and true or faceUp
    local scaleX = card.scaleX or 1
    local alpha = card.alpha or 1
    local cw = cards.cardWidth * cardScale
    local ch = cards.cardHeight * cardScale
    local rotation = card.rotation or 0

    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.push()
    love.graphics.translate(x + cw / 2, y + ch / 2)
    love.graphics.rotate(rotation)

    if faceUp and scaleX > 0 then
        local image, quad = cards.getQuad(card)
        love.graphics.draw(image, quad, 0, 0, 0, cardScale * scaleX, cardScale, cards.cardWidth / 2, cards.cardHeight / 2)
    elseif scaleX > 0 then
        local back = cards.getBack()
        love.graphics.draw(back, 0, 0, 0, cardScale * scaleX, cardScale, cards.cardWidth / 2, cards.cardHeight / 2)
    end

    if card.fxLabels then
        local font = love.graphics.getFont()
        for _, fx in ipairs(card.fxLabels) do
            local a = (fx.alpha or 1) * alpha
            local c = fx.color or {1, 1, 1, 1}
            local text = fx.text or ""
            love.graphics.push()
            love.graphics.rotate(fx.rotation or 0)
            love.graphics.setColor(c[1], c[2], c[3], c[4] * a)
            local tw = font:getWidth(text)
            local yy
            if fx.centered then
                yy = -(font:getHeight() / 2) + (fx.y or 0)
            else
                yy = -((cards.cardHeight * cardScale) / 2) - 18 + (fx.y or 0)
            end
            love.graphics.print(text, -tw / 2, yy)
            love.graphics.pop()
        end
    end

    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

return cards
