-- RVInterior_SwitchSeat_Patch.lua
-- Part of MrTheSteve_Patches
--
-- Patches: PROJECT RV Interior (Workshop: 3543229299, folder modPROJECTRVInterior)
-- and vanilla ISVehicleDashboard.
--
-- Carried over 2026-08-02 from HellDrinx - Bug Fixes (workshop 3667630656), whose
-- author is semi-retiring. Confirmed still needed against current source:
--
-- Fix 1: current vanilla ISVehicleDashboard.lua still calls vehicle:isDriver(character)
-- right after character:getVehicle() with no nil check in between. RVClientSP.lua
-- triggers "OnSwitchVehicleSeat" while the player is transitioning between the RV
-- interior and the actual vehicle, when getVehicle() can be nil -- crash.
--
-- Fix 2: current RVClientSP.lua's ReturnPlayerToSeat still searches only a 1-tile
-- radius for getVehicleContainer() with no attempt cap. Large RVs (e.g. the Bounder 86)
-- span many squares, so the center tile often has no container -> doReenterSeat loops
-- forever via OnPlayerUpdate with no timeout, leaving the player stuck near the door
-- until they relog. This patch widens the search to radius 4, adds a 300-tick timeout,
-- and verifies the found vehicle is actually a registered RV type before entering it.
--
-- Note: the original HellDrinx fix also guarded Project Summer Car's
-- VehicleDashboardReplacer for the same crash. PSC is not currently in use here
-- (patch retired, see CLAUDE.md), so that branch is omitted -- add it back if PSC
-- ever returns.

local function applyFix()
    -- Fix 1: vanilla ISVehicleDashboard
    if ISVehicleDashboard and ISVehicleDashboard.onSwitchVehicleSeat and
       not ISVehicleDashboard._HD_SwitchSeat_patched then
        local orig = ISVehicleDashboard.onSwitchVehicleSeat
        ISVehicleDashboard.onSwitchVehicleSeat = function(character)
            if instanceof(character, 'IsoPlayer') and character:isLocalPlayer() then
                if not character:getVehicle() then return end
            end
            orig(character)
        end
        ISVehicleDashboard._HD_SwitchSeat_patched = true
    end

    -- Fix 2: ReturnPlayerToSeat -- wider search radius + timeout (SP only)
    if isServer() or isClient() then return end
    if not RVFunction then return end
    if RVFunction._HD_ReturnToSeat_patched then return end

    local RV = require("RVVehicleTypes")
    local VehicleTypes = RV and RV.VehicleTypes

    RVFunction.ReturnPlayerToSeat = function(player)
        local pmd = player:getModData()
        if not pmd.projectRV_playerId then return end
        local modData = ModData.getOrCreate("modPROJECTRVInterior")
        local playerData = modData.Players and modData.Players[pmd.projectRV_playerId]
        if not playerData then return end
        local Seat = playerData.Seat
        if Seat < 0 then
            modData.Players[pmd.projectRV_playerId] = nil
            return
        end

        local attempts = 0
        local maxAttempts = 300

        local function doReenterSeat()
            attempts = attempts + 1
            if attempts > maxAttempts then
                Events.OnPlayerUpdate.Remove(doReenterSeat)
                if modData.Players then
                    modData.Players[pmd.projectRV_playerId] = nil
                end
                return
            end

            local square = player:getCurrentSquare()
            if not square then return end

            for i = -4, 4 do
                for k = -4, 4 do
                    local sq = getCell():getGridSquare(
                        player:getX() + i,
                        player:getY() + k,
                        player:getZ()
                    )
                    if sq then
                        local vehicle = sq:getVehicleContainer()
                        if vehicle then
                            local isRV = false
                            if VehicleTypes then
                                local scriptName = tostring(vehicle:getScript():getFullName())
                                for _, def in pairs(VehicleTypes) do
                                    if def.scripts then
                                        for _, s in ipairs(def.scripts) do
                                            if s == scriptName then
                                                isRV = true
                                                break
                                            end
                                        end
                                    end
                                    if isRV then break end
                                end
                            else
                                isRV = true
                            end

                            if isRV then
                                vehicle:enter(Seat, player)
                                vehicle:setCharacterPosition(player, Seat, "inside")
                                vehicle:switchSeat(player, Seat)
                                sendSwitchSeat(vehicle, player, 0, Seat)
                                triggerEvent("OnSwitchVehicleSeat", player)
                                modData.Players[pmd.projectRV_playerId] = nil
                                Events.OnPlayerUpdate.Remove(doReenterSeat)
                                return
                            end
                        end
                    end
                end
            end
        end

        Events.OnPlayerUpdate.Add(doReenterSeat)
    end

    RVFunction._HD_ReturnToSeat_patched = true
end

Events.OnGameStart.Add(applyFix)
