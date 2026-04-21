local helibladeRound = 0
local helibladeRoundSmall = 0

local DISTANCE_RANGES = {{0, 10}, {10, 20}, {20, 30}, {30, 40}}
local SOUND_NAMES = {"HeliSound_Type1_1", "HeliSound_Type1_2", "HeliSound_Type1_3", "HeliSound_Type1_4"}
local function stopSoundExcept(emi, exception)
    for _, soundName in ipairs(SOUND_NAMES) do
        if soundName ~= exception and emi:isPlaying(soundName) then
            emi:stopSoundByName(soundName)
        end
    end
end

local function updateHelicopterSound(vehicle, player)
    local dist = IsoUtils.DistanceTo(player:getX(), player:getY(), vehicle:getX(), vehicle:getY())
    local emi = vehicle:getEmitter()
    if not vehicle:isEngineRunning() or dist > DISTANCE_RANGES[#DISTANCE_RANGES][2] then
        stopSoundExcept(emi, "NONE")
    else
        emi:setPos(0, 0, 0)
        local soundName
        local Type = HeliList[GetHeliType(vehicle)].HeliSoundType
        if Type then
            local Origin = "HeliSound_Type" .. Type
            SOUND_NAMES = {Origin .. "_1", Origin .. "_2", Origin .. "_3", Origin .. "_4"}
        end
        if player:getVehicle() == vehicle then
            soundName = SOUND_NAMES[2]
        else
            for i, range in ipairs(DISTANCE_RANGES) do
                if dist >= range[1] and dist < range[2] then
                    soundName = SOUND_NAMES[i]
                    break
                end
            end
        end

        stopSoundExcept(emi, soundName)
        if not emi:isPlaying(soundName) then
            emi:playSound(soundName, vehicle)
        end
    end
    vehicle:update()
end

local function rotateBlades(vehicle)
    helibladeRound = (helibladeRound + 30) % 360
    helibladeRoundSmall = (helibladeRoundSmall + 120) % 360

    local type = GetHeliType(vehicle)
    local part = vehicle:getPartById(type .. "_blade")
    if part then
        part:setAllModelsVisible(false)
        part:setModelVisible(type .. "_blade" .. helibladeRound, true)
    end

    local partSmall = vehicle:getPartById(type .. "_bladeSmall")
    if partSmall then
        partSmall:setAllModelsVisible(false)
        partSmall:setModelVisible(type .. "_bladeSmall" .. helibladeRoundSmall, true)
    end

    vehicle:update()
end

local function helicopterVisualSoundUpdate(playerObj)
    local cell = playerObj:getCell()
    if not cell then return end
    local vehicleList = cell:getVehicles()
    for i = 0, vehicleList:size() - 1 do
        local vehicle = vehicleList:get(i)
        if GetHeliType(vehicle) and vehicle:getSquare() then
            if vehicle:isEngineRunning() then
                rotateBlades(vehicle)
            else
                local type = GetHeliType(vehicle)
                local part = vehicle:getPartById(type .. "_blade")
                if part then
                    part:setAllModelsVisible(false)
                    part:setModelVisible(type .. "_blade0", true)
                end

                local partSmall = vehicle:getPartById(type .. "_bladeSmall")
                if partSmall then
                    partSmall:setAllModelsVisible(false)
                    partSmall:setModelVisible(type .. "_bladeSmall0", true)
                end
            end
            updateHelicopterSound(vehicle, playerObj)
        end
    end
end

Events.OnPlayerUpdate.Add(helicopterVisualSoundUpdate)
