local scaling = require("lib.scaling")
local background = require("lib.background")
local animation = require("lib.animation")
local ui = require("lib.ui")
local cards = require("lib.cards")
local audio = require("lib.audio")
local screen = require("lib.screen")

function love.load()
    -- scaling
    scaling.init(1280, 720)

    -- fonts
    ui.loadFont("small", "assets/fonts/BoldPixels.ttf", 32)
    ui.loadFont("menu", "assets/fonts/BoldPixels.ttf", 48)
    ui.loadFont("title", "assets/fonts/BoldPixels.ttf", 80)
    ui.setFont("small")

    -- backgrounds
    background.load("classic", "assets/backgrounds/ClassicBackground.png")
    background.load("art", "assets/backgrounds/ArtDecoBackground.png")

    -- card spritesheets
    cards.loadSheet("classic", "assets/cards/front/ClassicCards.png", "assets/cards/front/ClassicJokers.png")
    cards.loadBack("classic", "assets/cards/back/LightClassic.png")

    cards.loadSheet("classicDark", "assets/cards/front/ClassicCardsDark.png", "assets/cards/front/ClassicDarkJokers.png")
    cards.loadBack("classicDark", "assets/cards/back/DarkClassic.png")

    -- audio (safe-load: missing files are ignored)
    audio.loadSound("button", "assets/audio/button.ogg")
    audio.loadSound("card1", "assets/audio/card1.ogg")
    audio.loadSound("card3", "assets/audio/card3.ogg")
    audio.loadSound("foil2", "assets/audio/foil2.ogg")
    audio.loadSound("cancel", "assets/audio/cancel.ogg")
    audio.loadSound("cardFan2", "assets/audio/cardFan2.ogg")
    audio.loadSound("multihit1", "assets/audio/multhit1.ogg")
    audio.loadSound("multhit2", "assets/audio/multhit2.ogg")
    audio.loadSound("negative", "assets/audio/negative.ogg")
    audio.loadSound("win", "assets/audio/win.ogg")
    audio.loadSound("paper1", "assets/audio/paper1.ogg")
    audio.loadSound("other1", "assets/audio/other1.ogg")
    for i = 1, 6 do
        audio.loadSound("glass" .. i, "assets/audio/glass" .. i .. ".ogg")
    end

    for i = 1, 5 do
        audio.loadSound("crumple" .. i, "assets/audio/crumple" .. i .. ".ogg")
    end
    for i = 1, 2 do
        audio.loadSound("cardslide" .. i, "assets/audio/cardslide" .. i .. ".ogg")
    end
    for i = 1, 7 do
        audio.loadSound("coin" .. i, "assets/audio/coin" .. i .. ".ogg")
    end
    for i = 1, 11 do
        audio.loadSound("voice" .. i, "assets/audio/voice" .. i .. ".ogg")
    end

    audio.definePool("uiClick", {"button"})
    audio.definePool("cardMove", {"card1", "card3"})
    audio.definePool("play", {"multihit1"})
    audio.definePool("jackActivate", {"multhit2"})
    audio.definePool("flip", {"cardFan2"})
    audio.definePool("burn", {"crumple1", "crumple2", "crumple3", "crumple4", "crumple5"})
    audio.definePool("joker", {"foil2"})
    audio.definePool("hit", {"cardslide1", "cardslide2"})
    audio.definePool("buy", {"coin1", "coin2", "coin3", "coin4", "coin5", "coin6", "coin7"})
    audio.definePool("invalid", {"negative"})
    audio.definePool("queenBlock", {"cancel"})
    audio.definePool("highDamage", {"glass1", "glass2", "glass3", "glass4", "glass5", "glass6"})
    audio.definePool("voiceTick", {"voice1", "voice2", "voice3", "voice4", "voice5", "voice6", "voice7", "voice8", "voice9", "voice10", "voice11"})

    -- register screens
    screen.register("menu", require("screens.menu"))
    screen.register("game", require("screens.game"))
    screen.register("store", require("screens.store"))
    screen.register("death", require("screens.death"))

    -- start at menu
    screen.switch("menu")
end

function love.resize(w, h)
    scaling.update()
end

function love.update(dt)
    animation.update(dt)
    screen.update(dt)
end

function love.draw()
    scaling.beginDraw()
    screen.draw()
    scaling.endDraw()
end

function love.mousepressed(x, y, button)
    screen.mousepressed(x, y, button)
end

function love.mousereleased(x, y, button)
    screen.mousereleased(x, y, button)
end

function love.keypressed(key)
    screen.keypressed(key)
end

function love.keyreleased(key)
    screen.keyreleased(key)
end
