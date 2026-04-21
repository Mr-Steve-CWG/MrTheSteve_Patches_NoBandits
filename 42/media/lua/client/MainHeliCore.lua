local function localUpdateHeliTurret(player)
    local cell = getPlayer():getCell()
    if not cell then return end
    local allVehicles = cell:getVehicles()
    for i = 0, allVehicles:size() - 1 do
        local vehicle = allVehicles:get(i)
        if (vehicle and GetHeliType(vehicle)) then
            local name = (luautils.split(vehicle:getScriptName(), "."))[2]
            local Type = GetHeliType(vehicle)
            if not Type then
                return
            end
            local MaxCount = HeliList[Type].EquipmentMaxCount
            if not MaxCount then
                return
            end
            for i = 1, MaxCount do
                local RocketTable = vehicle:getPartById(HeliList[Type].EquipmentName .. i)
                if RocketTable and RocketTable:getInventoryItem() then
                    for k, v in pairs(HeliList[Type].EquipmentAmmoType) do
                        if RocketTable:getInventoryItem():getType() == v then
                            RocketTable:setModelVisible(Type .. "_" .. k .. i, true)
                        else
                            RocketTable:setModelVisible(Type .. "_" .. k .. i, false)
                        end
                    end
                end
            end
        end
    end
end

local function inHeliHangler(player)
    localUpdateHeliTurret(player)
    -- PlayerTurretRoatingSound(player)
end

local start = false
local hasPanzerNearBy = false
local function BetterFPS()
    local cell = getPlayer():getCell()
    if not cell then return end
    local allVehicles = cell:getVehicles()
    for i = 0, allVehicles:size() - 1 do
        local vehicle = allVehicles:get(i)
        if (vehicle and GetHeliType(vehicle)) then
            hasPanzerNearBy = true
            break
        end
        hasPanzerNearBy = false
    end
    if hasPanzerNearBy and not start then
        start = true
        Events.OnPlayerUpdate.Add(inHeliHangler)
    end
    if not hasPanzerNearBy and start then
        start = false
        Events.OnPlayerUpdate.Remove(inHeliHangler)
    end
end

Events.EveryOneMinute.Add(BetterFPS)

