local gameconfig = {}

local gameSpeed = 1.0

function gameconfig.setGameSpeed(v)
    gameSpeed = math.max(0.5, math.min(1.5, v))
end

function gameconfig.getGameSpeed()
    return gameSpeed
end

return gameconfig
