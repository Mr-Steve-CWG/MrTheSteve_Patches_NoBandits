-- **************************************************
-- ██████  ██████   █████  ██    ██ ███████ ███    ██ 
-- ██   ██ ██   ██ ██   ██ ██    ██ ██      ████   ██ 
-- ██████  ██████  ███████ ██    ██ █████   ██ ██  ██ 
-- ██   ██ ██   ██ ██   ██  ██  ██  ██      ██  ██ ██ 
-- ██████  ██   ██ ██   ██   ████   ███████ ██   ████
-- **************************************************
-- ** Seek Excellence! Employ ME, not my Copycats. **
-- **************************************************

local tileListNormal = {
    "appliances_refrigeration_01_38","appliances_refrigeration_01_39","carpentry_02_52","crafted_01_24","crafted_01_28","furniture_storage_01_0","furniture_storage_01_1",
    "furniture_storage_01_2","furniture_storage_01_3","furniture_storage_01_4","furniture_storage_01_5","furniture_storage_01_6","furniture_storage_01_7","furniture_storage_01_16",
    "furniture_storage_01_17","furniture_storage_01_18","furniture_storage_01_19","furniture_storage_01_20","furniture_storage_01_21","furniture_storage_01_22","furniture_storage_01_23",
    "furniture_storage_01_24","furniture_storage_01_25","furniture_storage_01_26","furniture_storage_01_27","furniture_storage_01_28","furniture_storage_01_29","furniture_storage_01_30",
    "furniture_storage_01_31","furniture_storage_01_36","furniture_storage_01_37","furniture_storage_01_38","furniture_storage_01_39","furniture_tables_high_01_30","furniture_storage_01_56",
    "furniture_storage_01_57","furniture_storage_01_58","furniture_storage_01_59","furniture_storage_01_60","furniture_storage_01_61","furniture_storage_01_62","furniture_storage_01_63",
    "furniture_storage_02_16","furniture_storage_02_17","furniture_storage_02_18","furniture_storage_02_19","furniture_storage_02_20","furniture_storage_02_21","furniture_storage_02_22",
    "furniture_storage_02_23","furniture_storage_02_24","furniture_storage_02_25","furniture_storage_02_26","furniture_storage_02_27","furniture_storage_02_40","furniture_storage_02_41",
    "furniture_storage_02_42","furniture_storage_02_43","furniture_storage_02_44","furniture_storage_02_45","furniture_storage_02_46","furniture_storage_02_47","furniture_tables_high_01_24",
    "furniture_tables_high_01_25","furniture_tables_high_01_26","furniture_tables_high_01_27","furniture_tables_high_01_28","furniture_tables_high_01_29","furniture_tables_high_01_30","furniture_tables_high_01_31",
    "location_business_distillery_01_8","location_business_office_generic_01_0","location_business_office_generic_01_1","location_business_office_generic_01_2","location_business_office_generic_01_3","location_business_office_generic_01_4","location_business_office_generic_01_5",
    "location_business_office_generic_01_6","location_business_office_generic_01_8","location_business_office_generic_01_9","location_business_office_generic_01_10","location_business_office_generic_01_11","location_business_office_generic_01_12","location_business_office_generic_01_13",
    "location_business_office_generic_01_14","location_business_office_generic_01_40","location_business_office_generic_01_41","location_business_office_generic_01_42","location_business_office_generic_01_43","location_business_office_generic_01_44","location_business_office_generic_01_45",
    "location_business_office_generic_01_46","location_business_office_generic_01_47","location_community_church_small_01_48","location_community_church_small_01_49","location_community_church_small_01_50","location_community_church_small_01_51","location_community_church_small_01_52",
    "location_community_church_small_01_53","location_community_church_small_01_56","location_community_church_small_01_57","location_community_church_small_01_58","location_community_church_small_01_59","location_community_church_small_01_60","location_community_church_small_01_61",
    "recreational_01_2","recreational_01_3","recreational_01_6","recreational_01_7","furniture_storage_02_0","furniture_storage_02_1","furniture_storage_02_2",
    "furniture_storage_02_3","furniture_storage_02_4","furniture_storage_02_5","furniture_storage_02_6","furniture_storage_02_7","furniture_storage_02_12","furniture_storage_02_13",
    "furniture_storage_02_14","furniture_storage_02_15","furniture_storage_02_16","furniture_storage_02_17","furniture_storage_02_18","furniture_storage_02_19","furniture_storage_02_20",
    "furniture_storage_02_21","furniture_storage_02_22","furniture_storage_02_23","furniture_storage_02_24","furniture_storage_02_25","furniture_storage_02_26","furniture_storage_02_27",
    "furniture_storage_02_40","furniture_storage_02_41","furniture_storage_02_42","furniture_storage_02_43","furniture_storage_02_44","furniture_storage_02_45","furniture_storage_02_46","furniture_storage_02_47",
}

local tileListSickness = {
    "trashcontainers_01_0","trashcontainers_01_1","trashcontainers_01_2",
    "trashcontainers_01_3","trashcontainers_01_8","trashcontainers_01_9","trashcontainers_01_10","trashcontainers_01_11","trashcontainers_01_12","trashcontainers_01_13",
    "trashcontainers_01_14","trashcontainers_01_15","trashcontainers_01_16","trashcontainers_01_17",
}

local tileListCold = {
    "appliances_refrigeration_01_20","appliances_refrigeration_01_21",
    "appliances_refrigeration_01_38","appliances_refrigeration_01_39",
}

local distanceBetween = function(firstObj, secondObj)
        local distanceVector = {0, 0, 0}

        distanceVector.X = firstObj:getX() - secondObj:getX()
        distanceVector.Y = firstObj:getY() - secondObj:getY()
        distanceVector.Z = firstObj:getZ() - secondObj:getZ()

        local distance = math.abs(distanceVector.X) + math.abs(distanceVector.Y) -- FIX #1: signed sum gave wrong results when player was SW of target

        if distanceVector.Z ~= 0 then
            distance = 9999
        end

        return distance
end

local onGameStart = function()
    local playerObj = getPlayer()
    if not playerObj then return end

    if playerObj:getModData().hiding then
        BB_Hide.RevealPlayer(playerObj, playerObj:getModData().lastCoordsZ)
    end
end

local hide = function(playerObj, targetObj)
    if distanceBetween(playerObj, targetObj) > 2.5 then
        local targetSq = AdjacentFreeTileFinder.FindClosest(targetObj:getSquare(), playerObj) or targetObj:getSquare()
        luautils.walkAdjWindowOrDoor(playerObj, targetSq, targetObj)
    end

    local primaryHandItem = playerObj:getPrimaryHandItem()
    if primaryHandItem then
        ISTimedActionQueue.add(ISUnequipAction:new(playerObj, primaryHandItem, 20))
    end

    ISTimedActionQueue.add(BB_Hide_ISTimedAction:Hide(playerObj, SandboxVars.Hide.HidingSpeed))
end

local function onFillWorldObjectContextMenu(player, context, worldobjects, test)
    if getCore():getGameMode() == 'LastStand' then return; end
    if test then return; end

    local playerObj = getSpecificPlayer(player)
    if not playerObj or playerObj:getVehicle() then return; end
    if playerObj:getModData().hiding == true then return end
    if playerObj:getZ() == 6 then return end
    
    local square = clickedSquare
    if not square and worldobjects and #worldobjects > 0 then
        square = worldobjects[1]:getSquare()
    end
    
    if not square or type(square.getObjects) ~= "function" then return end

    local objs = square:getObjects()
    if not objs then return end

    local targetObj = nil
    local objCount = 0

    if type(objs) == "table" then
        objCount = #objs
    elseif type(objs.size) == "function" then
        objCount = objs:size()
    end

    for i = 0, objCount - 1 do
        local obj
        if type(objs) == "table" then
            obj = objs[i + 1]
        elseif type(objs.get) == "function" then
            obj = objs:get(i)
        end

        if obj and instanceof(obj, "IsoObject") then
            local isHidingSpot = false
            local effectType = "Boredom"
            local sprite = obj:getSprite()
            
            if sprite then
                local spriteName = sprite:getName()
                local props = sprite:getProperties()
                
                -- Bed Logic (Unified for B41 and B42)
                local isBed = false
                if props then
                    if type(props.Is) == "function" and IsoFlagType and IsoFlagType.bed then
                        isBed = props:Is(IsoFlagType.bed)
                    elseif type(props.is) == "function" and IsoFlagType and IsoFlagType.bed then
                        isBed = props:is(IsoFlagType.bed)
                    elseif type(props.hasFlags) == "function" and IsoFlagType and IsoFlagType.bed then
                        isBed = props:hasFlags(IsoFlagType.bed)
                    end
                end
                
                -- String search fallback for new B42 bedding tiles
                if not isBed and spriteName then
                    local sNameLower = string.lower(tostring(spriteName))
                    if string.find(sNameLower, "bed_") or string.find(sNameLower, "bedding") or string.find(sNameLower, "mattress") then
                        isBed = true
                    end
                end
                
                if isBed then
                    isHidingSpot = true
                elseif spriteName then
                    local sNameStr = tostring(spriteName)
                    local sNameLower = string.lower(sNameStr)

                    -- Normal Items
                    for x = 1, #tileListNormal do
                        if sNameStr == tileListNormal[x] then
                            isHidingSpot = true
                            break
                        end
                    end
                    
                    if not isHidingSpot and (string.find(sNameLower, "furniture_tables") or string.find(sNameLower, "desk") or string.find(sNameLower, "furniture_storage") or string.find(sNameLower, "wardrobe") or string.find(sNameLower, "cabinet") or string.find(sNameLower, "location_business_office_generic")) then
                        isHidingSpot = true
                    end

                    -- Trash Cans
                    if not isHidingSpot then
                        for l = 1, #tileListSickness do
                            if sNameStr == tileListSickness[l] then
                                isHidingSpot = true
                                effectType = "Sickness"
                                break
                            end
                        end
                        
                        if not isHidingSpot and (string.find(sNameLower, "trashcontainer") or string.find(sNameLower, "dumpster") or string.find(sNameLower, "wheeliebin") or string.find(sNameLower, "bin_")) then
                            isHidingSpot = true
                            effectType = "Sickness"
                        end
                    end

                    -- Refrigerators
                    if not isHidingSpot then
                        for n = 1, #tileListCold do
                            if sNameStr == tileListCold[n] then
                                isHidingSpot = true
                                effectType = "Cold" -- FIX #2: was "Sickness", making the Cold branch in everyTenMinutes dead code
                                break
                            end
                        end
                        
                        if not isHidingSpot and (string.find(sNameLower, "appliances_refrigeration") or string.find(sNameLower, "fridge") or string.find(sNameLower, "freezer")) then
                            isHidingSpot = true
                            effectType = "Cold" -- FIX #2: was "Sickness"
                        end
                    end
                end
            end

            -- Container Weight Check
            if isHidingSpot then
                local objContainer = obj:getContainer()
                if objContainer then
                    local currentWeight = 0
                    if type(objContainer.getCapacityWeight) == "function" then
                        currentWeight = objContainer:getCapacityWeight()
                    elseif type(objContainer.getContentsWeight) == "function" then
                        currentWeight = objContainer:getContentsWeight()
                    end

                    local maxCapacity = 0
                    if type(objContainer.getCapacity) == "function" then
                        maxCapacity = objContainer:getCapacity()
                    elseif type(objContainer.getMaxWeight) == "function" then
                        maxCapacity = objContainer:getMaxWeight()
                    end

                    if maxCapacity > 0 and currentWeight >= (maxCapacity / 1.7) then
                        isHidingSpot = false
                    end
                end
            end

            if isHidingSpot == true then
                if not playerObj:getModData().bbStatusEffect then
                    playerObj:getModData().bbStatusEffect = effectType
                end
                targetObj = obj
            end
        end
    end

    if targetObj then
        -- Fix Context Menu label with fallback to "Hide"
        local hideLabel = getText("ContextMenu_Hide")
        if not hideLabel or hideLabel == "ContextMenu_Hide" then
            hideLabel = "Hide"
        end
        context:addOptionOnTop(hideLabel, playerObj, hide, targetObj, player)
    end
end

local everyTenMinutes = function()
    local playerObj = getPlayer()
    if not playerObj or not playerObj:getModData() then return end
    if not playerObj:getModData().hiding then return end

    local statusEffect = playerObj:getModData().bbStatusEffect
    local bodyDamage = playerObj:getBodyDamage()
    if not bodyDamage then return end

    if statusEffect == "Boredom" then
        local currentBoredom = 0
        if type(bodyDamage.getBoredomLevel) == "function" then currentBoredom = bodyDamage:getBoredomLevel() end
        
        local decreaseVal = 0.001
        if ZomboidGlobals and type(ZomboidGlobals.BoredomDecrease) == "number" then decreaseVal = ZomboidGlobals.BoredomDecrease end

        if type(bodyDamage.setBoredomLevel) == "function" then bodyDamage:setBoredomLevel(currentBoredom + (decreaseVal * 120)) end
    elseif statusEffect == "Sickness" then
        if type(bodyDamage.getFoodSicknessLevel) == "function" and type(bodyDamage.setFoodSicknessLevel) == "function" then
            bodyDamage:setFoodSicknessLevel(bodyDamage:getFoodSicknessLevel() + 4)
        end
    elseif statusEffect == "Cold" then
        if type(playerObj.getTemperature) == "function" and type(playerObj.setTemperature) == "function" then
            playerObj:setTemperature(playerObj:getTemperature() - 2)
        end
    end
end

-- B42 aggressive player protection
local function onPlayerUpdate(playerObj)
    if not playerObj or not playerObj:getModData() then return end
    
    local isHiding = playerObj:getModData().hiding
    local wasHiding = playerObj:getModData().bbWasHidingLastTick
    
    if isHiding then
        -- Backup original states and apply immediate force protection
        if not wasHiding then
            if type(playerObj.isGhostMode) == "function" then playerObj:getModData().bbOriginalGhost = playerObj:isGhostMode() end
            if type(playerObj.isGodMod) == "function" then playerObj:getModData().bbOriginalGod = playerObj:isGodMod() end
            if type(playerObj.isNoTarget) == "function" then playerObj:getModData().bbOriginalNoTarget = playerObj:isNoTarget() end
            if type(playerObj.isNoClip) == "function" then playerObj:getModData().bbOriginalNoClip = playerObj:isNoClip() end
        end
        
        -- Force Invisible, Ghost, and NoClip every tick while hiding
        if type(playerObj.setInvisible) == "function" then playerObj:setInvisible(true) end
        if type(playerObj.setGhostMode) == "function" then playerObj:setGhostMode(true) end
        if type(playerObj.setNoTarget) == "function" then playerObj:setNoTarget(true) end
        if type(playerObj.setGodMod) == "function" then playerObj:setGodMod(true) end
        if type(playerObj.setTargetedByZombie) == "function" then playerObj:setTargetedByZombie(false) end
        if type(playerObj.setNoClip) == "function" then playerObj:setNoClip(true) end
        
        -- Force alpha to 0.0
        if type(playerObj.setAlpha) == "function" then playerObj:setAlpha(0.0) end

        -- Aggressively force nearby zombies to forget the player
        local cell = playerObj:getCell()
        if cell then
            local zombies = cell:getZombieList()
            if zombies then
                for i = 0, zombies:size() - 1 do
                    local zed = zombies:get(i)
                    if zed then
                        local target = zed:getTarget()
                        if target == playerObj then
                            if type(zed.setTarget) == "function" then zed:setTarget(nil) end
                            if type(zed.setForceTarget) == "function" then zed:setForceTarget(nil) end
                            if type(zed.setTargetSeenTime) == "function" then zed:setTargetSeenTime(0) end
                            if type(zed.setAttacking) == "function" then zed:setAttacking(false) end
                            if type(zed.clearWalkTo) == "function" then zed:clearWalkTo() end
                            if type(zed.setPath2) == "function" then zed:setPath2(nil) end
                            if type(zed.setEatBodyTarget) == "function" then zed:setEatBodyTarget(nil, false) end
                            
                            -- Force wander mode to break the pathfinding loop
                            if type(zed.setUseless) == "function" and zed:isUseless() then zed:setUseless(false) end
                        end
                    end
                end
            end
        end
        
        playerObj:getModData().bbWasHidingLastTick = true
    elseif wasHiding then
        -- Exit protocol: Force everything back to normal for B42
        if type(playerObj.setInvisible) == "function" then playerObj:setInvisible(false) end
        if type(playerObj.setAlpha) == "function" then playerObj:setAlpha(1.0) end
        if type(playerObj.setTargetedByZombie) == "function" then playerObj:setTargetedByZombie(true) end
        
        -- Restore original states or set to default (false)
        if type(playerObj.setGhostMode) == "function" then 
            local val = playerObj:getModData().bbOriginalGhost
            playerObj:setGhostMode(val == true) 
        end
        
        if type(playerObj.setNoTarget) == "function" then 
            local val = playerObj:getModData().bbOriginalNoTarget
            playerObj:setNoTarget(val == true) 
        end
        
        if type(playerObj.setGodMod) == "function" then 
            local val = playerObj:getModData().bbOriginalGod
            playerObj:setGodMod(val == true) 
        end

        if type(playerObj.setNoClip) == "function" then 
            local val = playerObj:getModData().bbOriginalNoClip
            playerObj:setNoClip(val == true) 
        end
        
        -- Double check visibility flags
        if playerObj:isInvisible() then playerObj:setInvisible(false) end
        
        playerObj:getModData().bbWasHidingLastTick = false
    end
end

Events.OnPlayerUpdate.Add(onPlayerUpdate)
Events.EveryTenMinutes.Add(everyTenMinutes)
Events.OnGameStart.Add(onGameStart)
Events.OnFillWorldObjectContextMenu.Add(onFillWorldObjectContextMenu)