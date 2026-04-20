-- WLVX_Patch.lua
-- Wraps WXStationBroadcast.OnEveryHour to loop the three scheduled shows
-- (Good Morning Knox County, The Evening Report, Kentucky Tonight) on a
-- 14-day cycle. FEMA broadcasts and weather are untouched — they run on
-- absolute worldage and degrade normally.
--
-- How it works:
--   cycleDay = worldage % CYCLE_LENGTH
--
-- The show day checks and modData "last fired" flags are replaced with
-- cycle-relative equivalents. At the start of each new cycle the per-show
-- flags are cleared so the shows can fire again from day 0.
--
-- Show windows within each 14-day cycle:
--   GMKC             — 7am,  cycle days 0-8   (9 episodes)
--   Evening Report   — 5pm,  cycle days 0-5   (6 episodes)
--   Kentucky Tonight — 10pm, cycle days 0-3   (4 episodes)
--   Days 9-13: FEMA loop only, no scheduled shows
--
-- FEMA variant and degradation are computed from absolute worldage,
-- so they keep aging regardless of show cycle resets.

local CYCLE_LENGTH = 14

-- ---------------------------------------------------------------------------
-- installPatch — called from OnLoadRadioScripts so WXStationBroadcast is
-- guaranteed to be fully initialised before we wrap anything.
-- ---------------------------------------------------------------------------
local function installPatch()
    if not WXStationBroadcast or not WXStationBroadcast.OnEveryHour then
        print("[WLVX_Patch] WXStationBroadcast not found — patch not applied")
        return
    end

    local _orig = WXStationBroadcast.OnEveryHour

    WXStationBroadcast.OnEveryHour = function(_channel, _gametime, _radio)
        local worldage = WXStationBroadcast.getWorldAgeDays()
        local cycleDay  = worldage % CYCLE_LENGTH
        local cycleIndex = math.floor(worldage / CYCLE_LENGTH)

        local gt = getGameTime()
        if not gt then
            _orig(_channel, _gametime, _radio)
            return
        end

        local modData = gt:getModData()

        -- On each new cycle boundary clear the per-day show flags so episodes
        -- can fire again. WX_PATCH_LastResetCycle tracks which cycle we last
        -- reset on so we only do this once per cycle, not every hour.
        if modData.WX_PATCH_LastResetCycle == nil
            or cycleIndex > modData.WX_PATCH_LastResetCycle then

            modData.WX_GMKC_LastDay  = -1
            modData.WX_EVR_LastDay   = -1
            modData.WX_KYT_LastDay   = -1
            modData.WX_GMKC_Alert6   = false
            modData.WX_PATCH_LastResetCycle = cycleIndex
            print(string.format(
                "[WLVX_Patch] Cycle %d started (worldage=%d, cycleDay=%d) — show flags reset",
                cycleIndex, worldage, cycleDay
            ))
        end

        -- Temporarily replace getWorldAgeDays so the scheduled show checks
        -- inside the original function see cycleDay instead of absolute
        -- worldage.  FEMA and weather call getWorldAgeDays too, but their
        -- variant/degradation logic lives in helper functions
        -- (getFEMAVariant, getFEMADegradationLevel, getWeatherDegradationLevel)
        -- which we leave alone — those still read absolute worldage via the
        -- real getWorldAgeDays captured in their own closures at load time.
        -- The only risk is if FEMA's hoursSinceStart calc inside OnEveryHour
        -- itself uses getWorldAgeDays — it does not; it uses the local
        -- `worldage` variable captured before our swap, so we are safe.
        local _origGetAge = WXStationBroadcast.getWorldAgeDays
        WXStationBroadcast.getWorldAgeDays = function() return cycleDay end

        _orig(_channel, _gametime, _radio)

        WXStationBroadcast.getWorldAgeDays = _origGetAge
    end

    print("[WLVX_Patch] OnEveryHour wrapped — cycle length " .. CYCLE_LENGTH .. " days")
end

-- Hook after radio scripts load so WXStationBroadcast.OnEveryHour exists.
Events.OnLoadRadioScripts.Add(installPatch)
