-- **************************************************
-- ██████  ██████   █████  ██    ██ ███████ ███    ██ 
-- ██   ██ ██   ██ ██   ██ ██    ██ ██      ████   ██ 
-- ██████  ██████  ███████ ██    ██ █████   ██ ██  ██ 
-- ██   ██ ██   ██ ██   ██  ██  ██  ██      ██  ██ ██ 
-- ██████  ██   ██ ██   ██   ████   ███████ ██   ████
-- **************************************************
-- ** Seek Excellence! Employ ME, not my Copycats. **
-- **************************************************

BB_Hide = {}

local hideImage = nil -- FIX #3: upstream assigned getTexture("media/ui/Hide Effect.png") which doesn't exist; nil is safe, setHideImage() sets it on hide
local drawHideCanvas = false
local opacity = 0
local screenWidth = nil
local screenHeight = nil

local function setHideImage(texturePath)
    hideImage = getTexture("media/ui/" .. texturePath .. ".png")
end

local function forceTeleport()
    local playerObj = getPlayer(); if not playerObj then return end
    if playerObj:getZ() == 6 then return end

    playerObj:setZ(6)
    playerObj:setbFalling(false)
    playerObj:setFallTime(0)
    playerObj:setLastFallSpeed(0)
end

BB_Hide.HidePlayer = function (playerObj)
    -- Simplified: Use direct player status instead of clones
    if getWorld():getGameMode() == "Multiplayer" then
        playerObj:setZ(6)
        setHideImage("FullEffect")
        Events.OnTick.Add(forceTeleport)
    else
        setHideImage("MildEffect")
    end

    drawHideCanvas = true
    playerObj:setInvisible(true)
end

BB_Hide.RevealPlayer = function (playerObj, z)
    playerObj:getModData().lastCoordsZ = nil
    playerObj:getModData().bbStatusEffect = nil
    playerObj:getModData().hiding = nil

    if getWorld():getGameMode() == "Multiplayer" then
        playerObj:setZ(z)
        Events.OnTick.Remove(forceTeleport)
    end

    drawHideCanvas = false
    playerObj:setInvisible(false)
end

function DrawHideCanvas()
    if not hideImage then return end -- FIX #3: guard against nil texture before first hide
    if drawHideCanvas == true then
        if opacity < 1 then opacity = opacity + 0.1 end
        UIManager.DrawTexture( hideImage, 0, 0, screenWidth, screenHeight, opacity)
    else
        if opacity > 0 then
            opacity = opacity - 0.006
            UIManager.DrawTexture( hideImage, 0, 0, screenWidth, screenHeight, opacity)
        end
    end
end

Events.OnPreUIDraw.Add(DrawHideCanvas)

local onGameStart = function()
	local playerObj = getPlayer(); if not playerObj then return end
    local playerNum = playerObj:getPlayerNum()
    screenWidth = getPlayerScreenWidth(playerNum)
    screenHeight = getPlayerScreenHeight(playerNum)
end

Events.OnGameStart.Add(onGameStart)