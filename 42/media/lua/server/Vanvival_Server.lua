local Vanvival_VehicleManager = require("Vanvival_VehicleManager")
local Vanvival_VehicleRegistry = require("Vanvival_VehicleRegistry")

local function onClientCommand(module, command, player, args)
    if module == "Vanvival" and command == "SpawnVehicle" then
        local modData = player:getModData()

        if modData.carSpawned then
            return
        end

        Vanvival_VehicleRegistry.populateValidVehicles()

        local vehicle = Vanvival_VehicleManager.spawnVehicle(player)

        if vehicle then
            local key = vehicle:createVehicleKey()

            if key then
                local item = player:getInventory():AddItem(key)

                if item then
                    sendAddItemToContainer(player:getInventory(), item)
                end
            end

            modData.carSpawned = true
            player:transmitModData()
        end
    end
end

Events.OnClientCommand.Add(onClientCommand)

local function onGameStart()
    print("[Vanvival] Server module loaded.")
end

Events.OnGameStart.Add(onGameStart)