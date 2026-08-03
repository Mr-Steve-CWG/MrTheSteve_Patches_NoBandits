-- ISWearClothing_NilItem_Patch.lua
-- Part of MrTheSteve_Patches
--
-- Patches: vanilla ISWearClothing (shared/TimedActions/ISWearClothing.lua), B42 MP
--
-- Carried over 2026-08-02 from HellDrinx - Bug Fixes (workshop 3667630656), whose
-- author is semi-retiring. Confirmed still needed against current 42.20 vanilla source:
-- ISWearClothing:start() re-fetches self.item by ID from inventory, then immediately
-- calls self:isAlreadyEquipped(self.item), which does self.item:hasTag(...) with no
-- nil guard. If the item was moved out of inventory during the ISInventoryTransferAction
-- perform chain (several active mods patch perform -- SOTO, ETW among them), the
-- re-fetch returns Java null and isAlreadyEquipped crashes on null:hasTag().
--
-- Fix: abort cleanly when self.item is nil after the inventory re-fetch.

local _isAlreadyEquipped = ISWearClothing.isAlreadyEquipped
function ISWearClothing:isAlreadyEquipped(item)
    if self.item == nil then return true end
    return _isAlreadyEquipped(self, item)
end
