-- TrueSmoking_Patch.lua
-- Part of MrTheSteve_Patches
--
-- Patches: True Smoking (Workshop: 3423984426)
-- File:    42.15/media/lua/client/TS_Hooks.lua
--
-- ============================================================
-- FIX #1: TrueSmoking:adjustShemagh colon/dot call mismatch [CRASH]
--
-- adjustShemagh is defined as TrueSmoking.adjustShemagh (dot = plain
-- function, first arg is player). TS_Hooks.lua calls it with colon
-- syntax (TrueSmoking:adjustShemagh), which injects TrueSmoking as the
-- implicit first arg, shifting all real args by one. Inside the function,
-- item:getFullType() is called on what is actually the player object and
-- crashes: "Object tried to call nil in adjustShemagh".
-- Triggered whenever the player eats while wearing a shemagh.
--
-- We cannot reliably capture vanilla getEatingMask before TS_Hooks wraps
-- it (load order not guaranteed). Instead we replicate the vanilla mask
-- logic inline so there is no dependency on any prior wrapper state.
-- ============================================================

local function getVanillaMask(playerObj, removeMask)
    local mask = false
    local locations = {
        ItemBodyLocation.MASK,
        ItemBodyLocation.MASK_EYES,
        ItemBodyLocation.MASK_FULL,
        ItemBodyLocation.FULL_HAT,
        ItemBodyLocation.FULL_SUIT_HEAD,
        ItemBodyLocation.SCBA,
        ItemBodyLocation.SCBANOTANK,
    }
    for _, loc in ipairs(locations) do
        local item = playerObj:getWornItem(loc)
        if item and not item:hasTag(ItemTag.CAN_EAT) then
            mask = item
            break
        end
    end
    if mask and removeMask then
        ISTimedActionQueue.add(ISUnequipAction:new(playerObj, mask, 50))
    end
    return mask
end

local function applyTrueSmokingPatch()
    if not TrueSmoking or not TrueSmoking.adjustShemagh then
        print("[TrueSmoking_Patch] WARNING: TrueSmoking.adjustShemagh not found, patch not applied.")
        return
    end

    ISInventoryPaneContextMenu.getEatingMask = function(playerObj, removeMask)
        local o = playerObj:getModData().TrueSmoking
        if not o then
            return getVanillaMask(playerObj, removeMask)
        end

        local mask = getVanillaMask(playerObj, false)

        if mask and mask:getFullType():contains('Shemagh') and mask:hasTag(TrueSmoking.registries.tag) and o.CheckMaskSmoking then
            o.shemagh = mask
            o.mask = false
            TrueSmoking.adjustShemagh(playerObj, mask, true)  -- FIX: dot, not colon
        else
            mask = getVanillaMask(playerObj, removeMask)
            o.mask = mask
            o.shemagh = false
        end

        sendClientCommand(playerObj, 'TrueSmoking', 'updatePlayerData', { { mask = o.mask, shemagh = o.shemagh } })

        if o.CheckMaskSmoking then
            return false
        end
        return mask
    end

    print("[TrueSmoking_Patch] ISInventoryPaneContextMenu.getEatingMask patched: colon->dot for adjustShemagh")
end

Events.OnGameStart.Add(applyTrueSmokingPatch)
