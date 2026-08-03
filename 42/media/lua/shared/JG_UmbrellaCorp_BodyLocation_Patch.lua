-- JG_UmbrellaCorp_BodyLocation_Patch.lua
-- Part of MrTheSteve_Patches
--
-- Patches: [J&G] Umbrella Corp Uniform (Workshop: 3675741487)
--
-- Carried over 2026-08-02 from HellDrinx - Bug Fixes (workshop 3667630656), whose
-- author is semi-retiring. Confirmed still needed: Umbrella_Corp_Uniform.txt still
-- declares BodyLocation = JacketHat (no namespace) on Umbrella_Corp_Jacket_Winter_Up
-- and Umbrella_Corp_Jacket_Winter_Open_Up, unchanged across every version folder on
-- disk. This location is never registered by KATTAJ1 or Jordanals_ExtraBodyLocations,
-- so BodyLocationGroup.getLocation() returns null. On zombie kill the engine calls
-- isMultiItem() on null -> NullPointerException at BodyLocationGroup.java:119.
--
-- Fix: register "JacketHat" as an ItemBodyLocation enum, then add to Human group.
-- B42: getOrCreateLocation/getLocation require ItemBodyLocation, not a raw String.

local HD_JG_JacketHat = ItemBodyLocation.register("JG:JacketHat")

local function JG_UmbrellaCorp_RegisterJacketHat()
    if BodyLocations then
        local group = BodyLocations.getGroup("Human")
        if group and not group:getLocation(HD_JG_JacketHat) then
            group:getOrCreateLocation(HD_JG_JacketHat)
        end
    end
end

Events.OnGameBoot.Add(JG_UmbrellaCorp_RegisterJacketHat)
