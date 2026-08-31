---@diagnostic disable
-- MrTheSteve_Patches: Fix #1 — nil guard on window in doesWindowBreak (window branch lacked check,
--   door branch had one; getWindow() returns nil if window smashed/removed since phantom was created)
-- MrTheSteve_Patches: Fix #3 — SandboxVars fallback defaults (all six vars read without fallback;
--   nil flows into ZombRand numeric comparisons in didZombieGetBored and crashes)
-- MrTheSteve_Patches: Fix #4 — door:ToggleDoorActual(source) replaced with door:ToggleDoorSilent();
--   ToggleDoorActual requires a real IsoPlayer and NPEs when passed the zombie source once bust succeeds
-- Source: workshop 3684834906, ZombieProofDW/42/media/lua/client/ZPWD/zombieThump.lua

local SB_windowsEnabled
local SB_doorsEnabled
local SB_bustDoorChance
local SB_smashWindowChance
local SB_wanderWindowChance
local SB_wanderDoorChance

local function setSandboxVals()
-- FIX #3: fallback defaults match sandbox-options.txt defaults
SB_wanderWindowChance = SandboxVars.CloudyZPWD.wanderWindowChance or 0
SB_wanderDoorChance = SandboxVars.CloudyZPWD.wanderDoorChance or 0
SB_smashWindowChance = SandboxVars.CloudyZPWD.smashWindowChance or 0
SB_windowsEnabled = SandboxVars.CloudyZPWD.windowsEnabled
SB_bustDoorChance = SandboxVars.CloudyZPWD.bustDoorChance or 0
SB_doorsEnabled = SandboxVars.CloudyZPWD.doorsEnabled
end

local function forceZombieUpdate(zombie)
        zombie:preupdate()
        zombie:update()
        zombie:postupdate()
end

local function zombieGotBored(zombie, zombData)
        zombData.lastRun = nil
        zombie:setTarget(nil)
        zombie:setThumpTarget(nil)
        zombie:clearAggroList()
        forceZombieUpdate(zombie)
        zombie:WanderFromWindow()
end

local function didZombieGetBored(zombie, zombData, targetobj)
    if not zombie then return end
    --this func runs every 10 in-game minutes as long as the zombie is thumping
    if zombie:getTarget() and zombie:isTargetVisible() then return end
   
    if targetobj == "window" and SB_wanderWindowChance ~= 0 then
        if ZombRand(100) < SB_wanderWindowChance then
            zombieGotBored(zombie, zombData)
        end
    elseif targetobj == "door" and SB_wanderDoorChance ~= 0 then
        if ZombRand(100) < SB_wanderDoorChance then
            zombieGotBored(zombie, zombData)
        end

    --quick barricade check
    elseif ZombRand(100) < (SB_wanderWindowChance * 2) then
            zombieGotBored(zombie, zombData)
    end
end

--FOR WINDOWS/DOORS
local function OnZombieThump(zombie)
if isClient() and zombie:getOwnerPlayer() ~= getPlayer() then return end
local thumpTarget = zombie:getThumpTarget()
local target = zombie:getTarget()
local invisTarget

    --redirect zombie to invuln window and if there isnt one, create one
    local door = instanceof(thumpTarget, "IsoDoor")
    local window = instanceof(thumpTarget, "IsoWindow")
    if thumpTarget and (door or window) then
        
        local phantomString
        if door then 
            if not SB_doorsEnabled then return end
            phantomString = "door" 
        else
            if not SB_windowsEnabled then return end
            phantomString = "window" 
        end

        local square = thumpTarget:getSquare()
        if not square then return end

        local objects = square:getObjects()
        for i = 0, objects:size() - 1 do
            local obj = objects:get(i)
            
            if instanceof(obj, "IsoThumpable") and obj:getModData().isPhantomWindow then
                invisTarget = obj
                break
            end
        end

        if not invisTarget then
            sendClientCommand("ZPWD", "addPhantom", {phantomString = phantomString, north = thumpTarget:getNorth(), x=square:getX(), y=square:getY(), z=square:getZ()})
            return 
        end
    
    
    if invisTarget then 
    zombie:setThumpTarget(invisTarget)
    end


    --check and do stuff if hitting the new invuln window/door
    elseif thumpTarget and instanceof(thumpTarget, "IsoThumpable") and thumpTarget:getModData().isPhantomWindow then
    local phantomString = thumpTarget:getModData().isPhantomWindow 
    --check if normal window is open or broken and reset thumptarget if so
    local square = thumpTarget:getSquare()
    local door = square:getDoor(thumpTarget:getNorth())
    local window = square:getWindow(thumpTarget:getNorth())


    if phantomString == "window" then
        if window and (window:IsOpen() or window:isSmashed()) then
            zombie:setThumpTarget(nil)
        return
        end

    elseif phantomString == "door" then
        
        if door and (door:IsOpen() or door:isDestroyed()) then
            zombie:setThumpTarget(nil)
        return
        end
    end
    

    --if not open or broken do this 
    
        local zombData = zombie:getModData()
        local worldHours = getGameTime():getWorldAgeHours()
        if zombData.lastThumpTarget ~= thumpTarget then zombData.lastRun = worldHours zombData.lastThumpTarget = thumpTarget end 
        if not zombData.lastRun or zombData.lastRun and worldHours - zombData.lastRun >= (12/60) then zombData.lastRun = worldHours end
        
        if worldHours - zombData.lastRun >= (10 / 60) then
            thumpTarget:setHealth(999999)
            zombData.lastRun = worldHours
            didZombieGetBored(zombie, zombData, phantomString)
        end

    --barricades
    elseif instanceof(thumpTarget, "IsoBarricade") then 
     local zombData = zombie:getModData()
        local worldHours = getGameTime():getWorldAgeHours()
        if not zombData.lastRun then zombData.lastRun = worldHours end 
        if worldHours - zombData.lastRun >= (10 / 60) then
            zombData.lastRun = worldHours
            didZombieGetBored(zombie, zombData)
        end
    
    
    end
end


local fakeHit = HandWeapon.new("ZPWD", "fakeHit", "None", "");
                fakeHit:setDoorDamage(0)
                fakeHit:setDoorHitSound("")

local function doesWindowBreak(x, y, z, radius, volume, source)
if not instanceof(source, "IsoZombie") then return end
if isClient() and source:getOwnerPlayer() ~= getPlayer() then return end
if source:getCurrentStateName() ~= "ThumpState" then return end
local thumpTarget = source:getThumpTarget()
if not instanceof(thumpTarget, "IsoThumpable") then return end
if thumpTarget:getModData().isPhantomWindow == "window" and not SB_windowsEnabled then return end
if thumpTarget:getModData().isPhantomWindow == "door" and not SB_doorsEnabled then return end

        local square = thumpTarget:getSquare()
            if thumpTarget:getModData().isPhantomWindow == "window" then
                -- FIX #1: guard against nil window (may have been smashed/removed since phantom was created)
                local window = square:getWindow(thumpTarget:getNorth())
                if not window then return end
                if not window:getBarricadeForCharacter(source) and not window:isInvincible() then 
                    if SB_smashWindowChance > 0 and (ZombRand(100) * 100) < (SB_smashWindowChance * 100) then
                        window:smashWindow()
                    end
                elseif window:getBarricadeForCharacter(source) then 
                        local barricade = window:getBarricadeForCharacter(source)
                        source:setThumpTarget(barricade)
                end
            elseif thumpTarget:getModData().isPhantomWindow == "door" then
            --doors
                local door = square:getDoor(thumpTarget:getNorth())
                if door then
                local barricade = door:getBarricadeForCharacter(source)
                if barricade then
                    source:setThumpTarget(barricade) 
                    return
                end

                local dmd = door:getModData()
                --quick fix for WorldSound loop on the door:WeaponHit
                dmd.forwardedThumps = dmd.forwardedThumps or 0
                if dmd.forwardedThumps > 0 then
                    dmd.forwardedThumps = dmd.forwardedThumps - 1
                    return
                end
                dmd.forwardedThumps = dmd.forwardedThumps + 1
                
                door:WeaponHit(source, fakeHit)
                
                if not door:isBarricaded() and not door:isLocked() then
                    if SB_bustDoorChance > 0 and (ZombRand(100) * 100) < (SB_bustDoorChance * 100) then
                        -- FIX #4: ToggleDoorActual(source) crashes -- it casts source to IsoPlayer
                        -- internally and dereferences it unconditionally once the door state flips.
                        -- source here is always a zombie (checked at function entry), so that cast is
                        -- always null -> guaranteed NullPointerException at IsoDoor.java:1611 the moment
                        -- the bust roll succeeds. ToggleDoorSilent() needs no character and does the same
                        -- open/close + sprite/LOS update. Note: it skips IsoDoor's own sync() call, so in
                        -- multiplayer this may not replicate to other clients -- fine for solo.
                        door:ToggleDoorSilent()
                        source:getEmitter():playSound("BreakBarricadePlank")
                    end
                end
                end
            end
end

Events.OnGameStart.Add(setSandboxVals)
Events.OnServerStarted.Add(setSandboxVals)
Events.OnWorldSound.Add(doesWindowBreak)
Events.OnZombieUpdate.Add(OnZombieThump)
