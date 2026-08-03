-- FR_RequirePaths_Patch.lua
-- Part of MrTheSteve_Patches
--
-- Patches: Filibuster Rhymes' Used Cars (Workshop: 3683878228, folder B42FRUsedCarsAnimAlpha)
--
-- Carried over 2026-08-02 from HellDrinx - Bug Fixes (workshop 3667630656), whose
-- author is semi-retiring. Confirmed still needed against the current FR mod source
-- on disk before porting -- all four require() paths below are still wrong there:
--   "Vehicle/ISVehiclePartMenu"           -> should be Vehicles/ISUI/ISVehiclePartMenu
--   "ISUI/ISVehicleMechanics"             -> should be Vehicles/ISUI/ISVehicleMechanics
--   "Vehicles/ISUI/ISVehicleTrailerUtils" -> should be Vehicles/ISVehicleTrailerUtils (NOT in ISUI/)
--   "ISUnlockVehicleDoor"                 -> should be Vehicles/TimedActions/ISUnlockVehicleDoor
-- The require() calls run at file load time, so all FR patches are silently
-- skipped. The target modules are global tables -- we re-apply the patches
-- manually on OnGameBoot, after all mod Lua has finished loading.

if not getActivatedMods():contains("B42FRUsedCarsAnimAlpha") then return end

Events.OnGameBoot.Add(function()
    -- FR_VehicleTrailerUtils patch: extends getTowableVehicleNear search to 7 tiles
    -- for FR semi-trailers and vehicles with FRFifthWheelHitch; skips walk requirement.
    if ISVehicleTrailerUtils and not ISVehicleTrailerUtils._HD_FR_patched then
        local orig_getTowable = ISVehicleTrailerUtils.getTowableVehicleNear
        function ISVehicleTrailerUtils.getTowableVehicleNear(square, ignoreVehicle, attachmentA, attachmentB)
            if string.find(ignoreVehicle:getScriptName(), "^Base.Trailer_fr_semi_")
               or ignoreVehicle:getPartById("FRFifthWheelHitch") then
                for y = square:getY() - 7, square:getY() + 7 do
                    for x = square:getX() - 7, square:getX() + 7 do
                        local sq2 = getCell():getGridSquare(x, y, square:getZ())
                        if sq2 then
                            for i = 1, sq2:getMovingObjects():size() do
                                local obj = sq2:getMovingObjects():get(i - 1)
                                if instanceof(obj, "BaseVehicle") and obj ~= ignoreVehicle
                                   and ignoreVehicle:canAttachTrailer(obj, attachmentA, attachmentB) then
                                    return obj
                                end
                            end
                        end
                    end
                end
                return nil
            end
            return orig_getTowable(square, ignoreVehicle, attachmentA, attachmentB)
        end

        local orig_walkToTrailer = ISVehicleTrailerUtils.walkToTrailer
        function ISVehicleTrailerUtils.walkToTrailer(playerObj, vehicle, attachment, nextAction)
            if string.find(vehicle:getScriptName(), "^Base.Trailer_fr_semi_")
               or vehicle:getPartById("FRFifthWheelHitch") then
                ISTimedActionQueue.add(nextAction)
                return true
            end
            return orig_walkToTrailer(playerObj, vehicle, attachment, nextAction)
        end

        ISVehicleTrailerUtils._HD_FR_patched = true
    end

    -- FR_UnlockedVehicleDoor patch: handles FR vehicle door unlocking
    -- (keyless entry, convertible roof, sounds).
    if ISUnlockVehicleDoor and not ISUnlockVehicleDoor._HD_FR_patched then
        local FR_tableStorage = require("FR_Tables")
        local FR_roofTypes = (FR_tableStorage and FR_tableStorage.FR_roofTypes) or {}

        local orig_start = ISUnlockVehicleDoor.start
        function ISUnlockVehicleDoor.start(self)
            if self.vehicle and string.find(self.vehicle:getScriptName(), "fr_") then
                if not self.character:getVehicle() then
                    self.character:faceThisObject(self.vehicle)
                end
                self.vehicle:toggleLockedDoor(self.part, self.character, false)
                if self.part:getDoor():isLocked() then
                    local partRoof
                    for _, v in ipairs(FR_roofTypes) do
                        if self.vehicle:getPartById(v) then
                            partRoof = self.vehicle:getPartById(v)
                            break
                        end
                    end
                    if not self.vehicle:getPartById("FR_keyless")
                       and not (partRoof and (not partRoof:getInventoryItem()
                           or (partRoof:getId() == "FRConRoof" and partRoof:getDoor():isOpen()))) then
                        if self.part:getDoor():isLockBroken() then
                            self.character:Say(getText("IGUI_PlayerText_VehicleLockIsBroken"))
                        end
                        self.vehicle:playPartSound(self.part, self.character, "IsLocked")
                        self:forceStop()
                        return
                    end
                end
                self.vehicle:playPartSound(self.part, self.character, "Unlock")
                if isClient() then
                    local args = { vehicle = self.vehicle:getId(), part = self.part:getId(), locked = false }
                    sendClientCommand(self.character, 'vehicle', 'setDoorLocked', args)
                end
                self.forceValid = true
                self:forceComplete()
            else
                orig_start(self)
            end
        end

        ISUnlockVehicleDoor._HD_FR_patched = true
    end

    -- FR_PropaneTank_ISVehiclePartMenu patch: extends propane tank handling
    -- for Hydrocraft compatibility.
    if ISVehiclePartMenu and not ISVehiclePartMenu._HD_FR_patched then
        function ISVehiclePartMenu.getPropaneTankNotFull(playerObj, typeToItem)
            local equipped = playerObj:getPrimaryHandItem()
            if equipped and equipped:getType() == "PropaneTank" and equipped:getUsedDelta() < 1 then
                return equipped
            elseif equipped and equipped:getType() == "HCPropanetankempty" then
                return equipped
            end
            if typeToItem["Base.PropaneTank"] then
                local gasCan, usedDelta = nil, -1
                for _, item in ipairs(typeToItem["Base.PropaneTank"]) do
                    if item:getUsedDelta() < 1 and item:getUsedDelta() > usedDelta then
                        gasCan = item
                        usedDelta = gasCan:getUsedDelta()
                    end
                end
                if gasCan then return gasCan end
            end
            if typeToItem["Hydrocraft.HCPropanetankempty"] then
                return typeToItem["Hydrocraft.HCPropanetankempty"][1]
            end
            return nil
        end

        function ISVehiclePartMenu.onTakePropane(playerObj, part)
            if playerObj:getVehicle() then ISVehicleMenu.onExit(playerObj) end
            local typeToItem = VehicleUtils.getItems(playerObj:getPlayerNum())
            local item = ISVehiclePartMenu.getPropaneTankNotFull(playerObj, typeToItem)
            if item then
                ISVehiclePartMenu.toPlayerInventory(playerObj, item)
                ISTimedActionQueue.add(ISPathFindAction:pathToVehicleArea(playerObj, part:getVehicle(), part:getArea()))
                ISInventoryPaneContextMenu.equipWeapon(item, false, false, playerObj:getPlayerNum())
                ISTimedActionQueue.add(ISTakeGasolineFromVehicle:new(playerObj, part, item, 50))
            end
        end

        if not getActivatedMods():contains("Hydrocraft") then
            local tank = ScriptManager.instance:getItem("Base.PropaneTank")
            if tank then
                tank:DoParam("KeepOnDeplete = TRUE")
                tank:DoParam("StaticModel = PropaneTank")
            end
        end

        ISVehiclePartMenu._HD_FR_patched = true
    end
end)
