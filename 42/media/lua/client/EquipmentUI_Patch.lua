-- EquipmentUI_Patch.lua
-- Part of MrTheSteve_Patches
--
-- Patches: Equipment UI (Workshop: 2950902979)
-- File:    42.13/media/lua/client/EquipmentUI/ClothingItemExtraService.lua
--
-- ============================================================
-- FIX #1: getExtraItemBodyLocation nil item crash [CRASH]
--
-- instanceItem() returns nil when the requested item type does not exist
-- in the B42 item registry (e.g. "Base.Lumberjack_Shirt_11" from a mod
-- that adds clothing variants not registered via B42 scripting). The
-- original code stores nil in _extraItemCache and then immediately calls
-- item:getBodyLocation() on nil, throwing a Java RuntimeException every
-- render frame. Under sustained load this eventually kills the session.
--
-- Two issues:
--   1. The cache stores nil for missing items, so the `if not item` guard
--      never short-circuits on subsequent calls -- instanceItem() is called
--      again every frame, then nil-deref crashes again every frame.
--   2. getBodyLocationsForItem (the caller) does:
--        bodyLocationsMap[extraBodyLocation] = true
--      If extraBodyLocation is nil, Lua raises "table index is nil".
--
-- Fix: replace both functions via the shared require table.
--   - getExtraItemBodyLocation: if instanceItem() returns nil, the item
--     type is unresolvable -- this means a clothing mod has a bad or missing
--     item script (likely outdated or broken). We cache a false sentinel to
--     avoid re-running instanceItem every frame, then call error() so
--     ErrorMagnifier surfaces the offending item type and mod.
--   - getBodyLocationsForItem: nil-check extraBodyLocation before assignment.
-- ============================================================

local ClothingItemExtraService = require("EquipmentUI/ClothingItemExtraService")

-- Per-session cache for this patched version. Uses false as a sentinel for
-- items confirmed missing from the registry so we don't keep calling instanceItem.
local _patchedCache = {}

function ClothingItemExtraService.getExtraItemBodyLocation(module, extra)
    local cached = _patchedCache[extra]
    -- false sentinel = confirmed missing, already reported via error() once this session.
    -- Subsequent calls return nil silently to avoid spamming ErrorMagnifier every frame.
    if cached == false then
        return nil
    end
    if cached then
        return cached:getBodyLocation()
    end
    local item = instanceItem(module .. "." .. extra)
    if not item then
        _patchedCache[extra] = false
        error("[MrTheSteve_Patches] EquipmentUI: unresolvable BodyLocation item '" .. module .. "." .. extra .. "' -- a clothing mod has a bad or missing item script (likely outdated). Check your clothing mods.")
        return nil
    end
    _patchedCache[extra] = item
    return item:getBodyLocation()
end

ClothingItemExtraService.getBodyLocationsForItem = function(item)
    local bodyLocationsMap = {}

    local defaultBodyLocation = ClothingItemExtraService.getDefaultBodyLocation(item)
    if not defaultBodyLocation then
        return bodyLocationsMap
    end

    bodyLocationsMap[defaultBodyLocation] = true

    local extraOptions = item:getClothingItemExtra()
    if extraOptions then
        local module = item:getModule()
        for i=0, extraOptions:size()-1 do
            local extra = extraOptions:get(i)
            local extraBodyLocation = ClothingItemExtraService.getExtraItemBodyLocation(module, extra)
            if extraBodyLocation then
                bodyLocationsMap[extraBodyLocation] = true
            end
        end
    end

    return bodyLocationsMap
end
