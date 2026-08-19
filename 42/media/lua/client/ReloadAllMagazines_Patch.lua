-- ReloadAllMagazines_Patch.lua
-- Part of MrTheSteve_Patches
--
-- Patches: Reload All Magazines (Workshop: 2920899878)
-- File:    media/lua/client/ISUI/ReloadAllMagazines_ISInventoryPaneContextMenu.lua
--
-- ============================================================
-- FIX: negative ammoCount not clamped in onLoadBulletsInAllMagazines [CRASH]
--
-- Both loops in onLoadBulletsInAllMagazines (player inventory, then
-- containers) compute:
--     ammoCount = magazine:getMaxAmmo() - magazine:getCurrentAmmoCount()
-- and only guard against ammoCount == 0. If a magazine's current ammo
-- exceeds its base max ammo (e.g. GoM attachment-modified capacity),
-- this goes negative. The negative value is folded into the running
-- ammoIndex tracker (ammoIndex = ammoIndex + ammoCount), which drives
-- ammoIndex negative for later magazines in the same click. getUniqueBullets
-- then calls allAmmoItems:get(i) with a negative index, throwing
-- java.lang.IndexOutOfBoundsException and flooding the log once per
-- magazine in the stack.
--
-- Fix: clamp ammoCount to 0 whenever the subtraction goes negative, in
-- both loops. A magazine already holding more than its nominal max
-- needs 0 bullets loaded, so skipping it is correct behavior, not
-- suppression of an unrelated error.
-- ============================================================

local function applyReloadAllMagazinesPatch()
    if not ISInventoryPaneContextMenu or not ISInventoryPaneContextMenu.onLoadBulletsInAllMagazines then
        print("[ReloadAllMagazines_Patch] WARNING: ISInventoryPaneContextMenu.onLoadBulletsInAllMagazines not found, patch not applied.")
        return
    end

    ISInventoryPaneContextMenu.onLoadBulletsInAllMagazines = function(playerObj, magazine)
        local allAmmoCount = playerObj:getInventory():getItemCountRecurse(magazine:getAmmoType());
        local magazineCount = playerObj:getInventory():getItemCountRecurse(magazine:getType());
        local maxAmmo = magazine:getMaxAmmo();

        local ammoToGet = magazineCount * maxAmmo;
        if magazineCount * maxAmmo > allAmmoCount then
            ammoToGet = allAmmoCount;
        end

        local allAmmoItems = playerObj:getInventory():getSomeTypeRecurse(magazine:getAmmoType(), allAmmoCount)

        local ammoIndex = 0;
        local containers = {};
        for i = 0, playerObj:getInventory():getItems():size() -1 do
            local item = playerObj:getInventory():getItems():get(i);
            if instanceof(item, "InventoryContainer") then
                table.insert(containers, item)
            end
            if item:getType() == magazine:getType() then
                local magazine = item;
                local ammoCount = playerObj:getInventory():getItemCountRecurse(magazine:getAmmoType());
                if ammoCount > magazine:getMaxAmmo() then
                    ammoCount = magazine:getMaxAmmo();
                end
                if ammoCount > magazine:getMaxAmmo() - magazine:getCurrentAmmoCount() then
                    ammoCount = magazine:getMaxAmmo() - magazine:getCurrentAmmoCount();
                end
                if ammoCount < 0 then  -- FIX: overfilled magazine, nothing to load
                    ammoCount = 0;
                end
                if ammoCount ~= 0 then
                    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, magazine)
                    local ammoToLoad = ISInventoryPaneContextMenu.getUniqueBullets(allAmmoItems, allAmmoCount, ammoIndex, ammoCount)
                    ammoIndex = ammoIndex + ammoCount
                    ISInventoryPaneContextMenu.transferIfNeeded(playerObj, ammoToLoad)
                    ISTimedActionQueue.add(ISLoadBulletsInMagazine:new(playerObj, magazine, ammoCount))
                end
            end
        end

        for k, v in pairs(containers) do
            local container = v:getInventory():getItems();
            for i = 0, container:size() -1 do
                local item = container:get(i);
                if item:getType() == magazine:getType() then
                    local magazine = item;
                    local ammoCount = playerObj:getInventory():getItemCountRecurse(magazine:getAmmoType());
                    if ammoCount > magazine:getMaxAmmo() then
                        ammoCount = magazine:getMaxAmmo();
                    end
                    if ammoCount > magazine:getMaxAmmo() - magazine:getCurrentAmmoCount() then
                        ammoCount = magazine:getMaxAmmo() - magazine:getCurrentAmmoCount();
                    end
                    if ammoCount < 0 then  -- FIX: overfilled magazine, nothing to load
                        ammoCount = 0;
                    end
                    if ammoCount ~= 0 then
                        ISInventoryPaneContextMenu.transferIfNeeded(playerObj, magazine)
                        local ammoToLoad = ISInventoryPaneContextMenu.getUniqueBullets(allAmmoItems, allAmmoCount, ammoIndex, ammoCount)
                        ammoIndex = ammoIndex + ammoCount
                        ISInventoryPaneContextMenu.transferIfNeeded(playerObj, ammoToLoad)
                        ISTimedActionQueue.add(ISLoadBulletsInMagazine:new(playerObj, magazine, ammoCount))
                    end
                end
            end
        end
    end

    print("[ReloadAllMagazines_Patch] ISInventoryPaneContextMenu.onLoadBulletsInAllMagazines patched: clamp negative ammoCount from overfilled magazines")
end

Events.OnGameStart.Add(applyReloadAllMagazinesPatch)
