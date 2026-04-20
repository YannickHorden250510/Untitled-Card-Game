local audio = {}

local sounds = {}
local music = {}
local pools = {}
local currentMusic = nil
local lastVoiceTickAt = 0

local sfxVolume = 1
local musicVolume = 0.5

function audio.loadSound(name, path)
    local ok, src = pcall(love.audio.newSource, path, "static")
    if ok and src then
        sounds[name] = src
        return true
    end
    return false
end

function audio.loadMusic(name, path)
    local ok, src = pcall(love.audio.newSource, path, "stream")
    if ok and src then
        music[name] = src
        music[name]:setLooping(true)
        return true
    end
    return false
end

function audio.playSound(name, volume, pitch)
    local pool = pools[name]
    if pool and #pool > 0 then
        local idx = love.math.random(1, #pool)
        local pooledName = pool[idx]
        return audio.playSound(pooledName, volume, pitch)
    end

    local s = sounds[name]
    if not s then return end
    local clone = s:clone()
    clone:setVolume((volume or 1) * sfxVolume)
    clone:setPitch(pitch or 1)
    clone:play()
end

function audio.definePool(name, soundNames)
    pools[name] = soundNames or {}
end

function audio.playVoiceTick(intervalSeconds)
    intervalSeconds = intervalSeconds or 0.03
    local now = love.timer.getTime()
    if now - lastVoiceTickAt < intervalSeconds then
        return
    end
    lastVoiceTickAt = now
    audio.playSound("voiceTick", 0.45, 0.95 + (love.math.random() * 0.12))
end

function audio.playMusic(name, volume)
    audio.stopMusic()
    local m = music[name]
    if not m then return end
    m:setVolume((volume or 1) * musicVolume)
    m:play()
    currentMusic = name
end

function audio.stopMusic()
    if currentMusic and music[currentMusic] then
        music[currentMusic]:stop()
    end
    currentMusic = nil
end

function audio.pauseMusic()
    if currentMusic and music[currentMusic] then
        music[currentMusic]:pause()
    end
end

function audio.resumeMusic()
    if currentMusic and music[currentMusic] then
        music[currentMusic]:play()
    end
end

function audio.setSfxVolume(v)
    sfxVolume = math.max(0, math.min(1, v))
end

function audio.setMusicVolume(v)
    musicVolume = math.max(0, math.min(1, v))
    if currentMusic and music[currentMusic] then
        music[currentMusic]:setVolume(musicVolume)
    end
end

function audio.getSfxVolume()
    return sfxVolume
end

function audio.getMusicVolume()
    return musicVolume
end

return audio
