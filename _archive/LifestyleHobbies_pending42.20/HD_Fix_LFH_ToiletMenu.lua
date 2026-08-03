-- Carried over from HellDrinx - Bug Fixes (workshop 3667630656), archived 2026-08-02.
-- HellDrinx author is semi-retiring and won't be maintaining this further.
-- Original fix, unmodified below. Lifestyle: Hobbies is currently subscribed but
-- NOT in the active 42.20 mod list (mod not yet updated for 42.20). Not deployed --
-- move to 42\media\lua\client\ in both repos if/when Lifestyle: Hobbies is re-enabled,
-- AND only after confirming the bug below still exists in whatever version is current then.
--
-- HellDrinx Bug Fix: Lifestyle Hobbies - ToiletGroundContextMenu BladderNeed nil crash
-- Fix for mod 3403870858 (Lifestyle: Hobbies)
--
-- ToiletGroundContextMenu.doBuildMenu (ToiletGroundContextMenu.lua:117) accesses
-- playerdata.LSMoodles["BladderNeed"].Value directly without a nil guard.
-- In B42.16 MP, LSMoodles is not initialized yet when the player right-clicks,
-- causing a crash on every right-click until LSMoodleManager.init() runs.
--
-- Fix: wrap doBuildMenu with a guard that checks LSMoodles before calling original.
-- ToiletGroundContextMenu is a table so this is safe (no global function issue).

local _patched = false

local function PatchToiletMenu()
    if _patched then return end
    if not (ToiletGroundContextMenu and ToiletGroundContextMenu.doBuildMenu) then return end

    local original = ToiletGroundContextMenu.doBuildMenu

    ToiletGroundContextMenu.doBuildMenu = function(player, context, worldobjects, DebugBuildOption)
        local thisPlayer = getSpecificPlayer(player)
        if not thisPlayer then return end
        local playerData = thisPlayer:getModData()
        if not playerData.LSMoodles then
            if LSMoodleManager and LSMoodleManager.init then
                LSMoodleManager.init(thisPlayer)
            end
            if not playerData.LSMoodles then return end
        end
        original(player, context, worldobjects, DebugBuildOption)
    end

    _patched = true
    print("[HD_Fix] LFH ToiletGroundContextMenu patched: LSMoodles nil guard added")
end

Events.OnPostMapLoad.Add(PatchToiletMenu)
