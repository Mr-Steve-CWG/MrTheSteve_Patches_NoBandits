-- PSC_Patch.lua
-- Project Summer Car (Workshop ID 3564950449)
-- Fixes two related bugs that cause vehicles to spawn with zero engine condition
-- and dead batteries until the player enters the vehicle for the first time.
--
-- Root cause: PSC overrides Vehicles.CheckEngine.Engine and Vehicles.Update.Battery
-- but neither function checks whether PSC has actually populated the engine item
-- container yet. Until the player enters a vehicle (or opens its mechanic menu),
-- the container is empty. CheckEngine then hard-sets engine condition to 0 because
-- it finds fewer than the required 5 EngineCritical-tagged parts, and Update.Battery
-- returns zero alternator output because GetPartCondition("EngineAlternator") finds
-- nothing. Both conditions resolve permanently the first time the player enters.
--
-- Fix: wrap both functions. If the EnginePartInitMarker item (PSC's own "I have
-- initialised this engine" flag) is absent from the container, bail out and call
-- the original function instead.
--
-- Safe without PSC: the wrappers check that Vehicles.CheckEngine.Engine and
-- Vehicles.Update.Battery exist and are non-nil before installing themselves.
-- If PSC is not loaded those slots are never populated, the wrappers are never
-- registered, and vanilla behaviour is untouched.

local function isEngineInitialised(vehicle)
    local engine = vehicle:getPartById("Engine")
    if not engine then return false end
    local container = engine:getItemContainer()
    if not container then return false end
    return container:containsTag("EnginePartInitMarker")
end

-- Wrap Vehicles.CheckEngine.Engine
-- PSC installs this in Project_Summer_Car_Server.lua. Without the guard it
-- returns false (stall) for any vehicle whose engine container is empty.
if Vehicles and Vehicles.CheckEngine and Vehicles.CheckEngine.Engine then
    local originalCheckEngine = Vehicles.CheckEngine.Engine
    Vehicles.CheckEngine.Engine = function(vehicle, part)
        if not isEngineInitialised(vehicle) then
            -- Engine not yet set up by PSC. Delegate to the function that was
            -- registered before PSC overwrote the slot, which is vanilla's
            -- Vehicles.CheckEngine.Engine. If vanilla never set one, part
            -- condition is the correct fallback: a non-zero value keeps the
            -- engine running, matching vanilla behaviour for an unmodified car.
            local vanillaCondition = part:getCondition()
            return vanillaCondition > 0
        end
        return originalCheckEngine(vehicle, part)
    end
end

-- Wrap Vehicles.Update.Battery
-- PSC installs this in Project_Summer_Car_Server.lua. Without the guard it
-- runs the full alternator/draw simulation but GetPartCondition("EngineAlternator")
-- returns 0 (part absent), so alternatorAmps = 0 and the battery drains with
-- nothing to offset it.
if Vehicles and Vehicles.Update and Vehicles.Update.Battery then
    local originalUpdateBattery = Vehicles.Update.Battery
    Vehicles.Update.Battery = function(vehicle, part, elapsedMinutes)
        if not isEngineInitialised(vehicle) then
            -- Engine not yet set up. Skip PSC's battery simulation entirely so
            -- the battery is not silently drained before the alternator exists.
            -- Vanilla's Update.Battery was overwritten by PSC, so we replicate
            -- the one safe action vanilla would take: transmit charge if it
            -- changed. Since we are doing nothing here, charge does not change,
            -- so there is nothing to transmit. This is a true no-op, which is
            -- correct: a parked uninitialised car should sit still.
            return
        end
        return originalUpdateBattery(vehicle, part, elapsedMinutes)
    end
end
