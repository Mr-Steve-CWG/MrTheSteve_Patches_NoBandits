-- HardwoodsPolicePack_Patch.lua
-- Part of MrTheSteve_Patches
--
-- Fixes broken BodyLocation strings in Hardwood's Police Pack (ID: HardwoodsPolicePack)
-- that cause a Java NullPointerException crash on zombie kill in B42.16.
--
-- Root cause: CopClothing.txt declares items with BodyLocation strings that
-- BodyLocationGroup.getLocation() cannot resolve, returning null and crashing
-- WornItems.setItem when the engine builds loot from a killed zombie's worn items.
--
-- Script file overrides don't work for module Base items (first-loaded wins).
-- We patch the ScriptItem objects directly via ScriptManager after load.
--
-- setBodyLocation() takes a BodyLocation object, not a raw string.
-- We resolve each target location via BodyLocations.getGroup("Human"):getOrCreateLocation().
--
-- Fixes applied:
--   Base.93ElbowpadLeft  : "Elbow_Left"        -> base:elbow_left   (missing base: prefix)
--   Base.93ElbowpadRight : "Elbow_Right"       -> base:elbow_right  (missing base: prefix)
--   Base.RiotShield      : "base:ForeArm_Left" -> base:forearm_left (wrong case)
--   Base.RetroGasMask    : "base:Gorget"       -> base:gorget       (wrong case)
--   Base.RetroSwatJacket : "base:Jacket"       -> base:jacket       (wrong case)
--   Base.93SwatJacket    : "base:Jacket"       -> base:jacket       (wrong case)
--   Base.93SwatSweater   : "base:Sweater"      -> base:sweater      (wrong case)
--   Base.93SwatBalaclava : "base:Scarf"        -> base:scarf        (wrong case)

-- Map of full item type -> correct location name (the part after "base:")
local fixes = {
    ["Base.93ElbowpadLeft"]  = "elbow_left",
    ["Base.93ElbowpadRight"] = "elbow_right",
    ["Base.RiotShield"]      = "forearm_left",
    ["Base.RetroGasMask"]    = "gorget",
    ["Base.RetroSwatJacket"] = "jacket",
    ["Base.93SwatJacket"]    = "jacket",
    ["Base.93SwatSweater"]   = "sweater",
    ["Base.93SwatBalaclava"] = "scarf",
}

local function applyFixes()
    local group = BodyLocations.getGroup("Human")
    for fullType, locationName in pairs(fixes) do
        local scriptItem = ScriptManager.instance:FindItem(fullType)
        if scriptItem then
            local loc = group:getLocation(locationName)
            if loc then
                if scriptItem.setBodyLocation then
                    scriptItem:setBodyLocation(loc)
                    print("[MrTheSteve_Patches] HardwoodsPolicePack: fixed BodyLocation on "
                        .. fullType .. " -> " .. locationName)
                else
                    print("[MrTheSteve_Patches] HardwoodsPolicePack: WARNING setBodyLocation not available on "
                        .. fullType)
                end
            else
                print("[MrTheSteve_Patches] HardwoodsPolicePack: WARNING could not resolve location '"
                    .. locationName .. "' from Human group")
            end
        else
            print("[MrTheSteve_Patches] HardwoodsPolicePack: WARNING item not found: " .. fullType)
        end
    end
end

Events.OnGameBoot.Add(applyFixes)
