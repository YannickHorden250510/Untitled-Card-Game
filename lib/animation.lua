local flux = require("flux")

local animation = {}

function animation.update(dt)
    flux.update(dt)
end

function animation.slideTo(obj, duration, x, y, easing)
    local target = {}
    if x then target.x = x end
    if y then target.y = y end
    return flux.to(obj, duration or 0.4, target):ease(easing or "cubicout")
end

function animation.rotateTo(obj, duration, targetRotation, delay, easing)
    local tween = flux.to(obj, duration or 0.3, {rotation = targetRotation or 0}):ease(easing or "cubicout")
    if delay and delay > 0 then
        tween:delay(delay)
    end
    return tween
end

function animation.pop(obj, duration, targetScale, easing)
    targetScale = targetScale or 1.2
    duration = duration or 0.3
    return flux.to(obj, duration / 2, {scale = targetScale}):ease(easing or "backout")
        :oncomplete(function()
            flux.to(obj, duration / 2, {scale = 1}):ease("cubicout")
        end)
end

function animation.hoverIn(obj, duration)
    duration = duration or 0.3
    return flux.to(obj, duration, {scale = 1.1, rotation = 0.02}):ease("backout")
end

function animation.hoverOut(obj, duration)
    duration = duration or 0.3
    return flux.to(obj, duration, {scale = 1, rotation = 0}):ease("cubicout")
end

function animation.shake(obj, duration, intensity)
    intensity = intensity or 5
    duration = duration or 0.3
    local origX = obj.x
    return flux.to(obj, duration / 4, {x = origX + intensity}):ease("sinein")
        :oncomplete(function()
            flux.to(obj, duration / 4, {x = origX - intensity}):ease("sineinout")
                :oncomplete(function()
                    flux.to(obj, duration / 4, {x = origX + intensity / 2}):ease("sineinout")
                        :oncomplete(function()
                            flux.to(obj, duration / 4, {x = origX}):ease("sineout")
                        end)
                end)
        end)
end

function animation.fade(obj, duration, targetAlpha, easing)
    return flux.to(obj, duration or 0.3, {alpha = targetAlpha or 0}):ease(easing or "linear")
end

function animation.cardFlip(card, duration, onMiddle, onComplete)
    duration = duration or 0.4
    card.scaleX = card.scaleX or 1
    local fullScale = card.scaleX

    return flux.to(card, duration / 2, {scaleX = 0}):ease("cubicin")
        :oncomplete(function()
            if onMiddle then onMiddle() end
            flux.to(card, duration / 2, {scaleX = fullScale}):ease("cubicout")
                :oncomplete(function()
                    if onComplete then onComplete() end
                end)
        end)
end

function animation.dealCard(card, targetX, targetY, delay, duration)
    duration = duration or 0.4
    delay = delay or 0
    card.alpha = 0
    card.y = targetY + 100

    return flux.to(card, duration, {x = targetX, y = targetY, alpha = 1})
        :ease("cubicout")
        :delay(delay)
end

function animation.burnCard(card, delay, duration)
    delay = delay or 0
    duration = duration or 0.28
    local targetY = (card.y or 0) - 26
    local tween = flux.to(card, duration, {alpha = 0, y = targetY, rotation = (card.rotation or 0) + 0.18})
        :ease("quadin")
    if delay > 0 then
        tween:delay(delay)
    end
    return tween
end

function animation.sequence(steps)
    if #steps == 0 then return end

    local function run(i)
        if i > #steps then return end
        local step = steps[i]
        step(function()
            run(i + 1)
        end)
    end

    run(1)
end

return animation
