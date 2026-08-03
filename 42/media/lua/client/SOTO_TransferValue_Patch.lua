-- SOTO_TransferValue_Patch.lua
-- Part of MrTheSteve_Patches
--
-- Patches: Simple Overhaul: Traits and Occupations / SOTO (Workshop: 2840805724)
--
-- Carried over 2026-08-02 from HellDrinx - Bug Fixes (workshop 3667630656), whose
-- author is semi-retiring. Confirmed still needed: current SOTOISInventoryTransferAction.lua
-- (42.15 folder) still does raw arithmetic on player ModData fields with no init guard --
-- DisorganizedTransferredValue and AllThumbsTransferredValue are read via "+ value" before
-- ever being set to 0, throwing "__add not defined" (nil + number) the first time a
-- Disorganized or All Thumbs character transfers an item.
--
-- Fix: wrap perform() and update() to ensure both fields are initialized before SOTO's
-- own arithmetic runs.

if not SOTO then return end

Events.OnGameStart.Add(function()
    local oldPerform = ISInventoryTransferAction.perform
    function ISInventoryTransferAction:perform()
        local md = self.character:getModData()
        if md.DisorganizedTransferredValue == nil then
            md.DisorganizedTransferredValue = 0
        end
        oldPerform(self)
    end

    local oldUpdate = ISInventoryTransferAction.update
    function ISInventoryTransferAction:update()
        local md = self.character:getModData()
        if md.AllThumbsTransferredValue == nil then
            md.AllThumbsTransferredValue = 0
        end
        oldUpdate(self)
    end
end)
