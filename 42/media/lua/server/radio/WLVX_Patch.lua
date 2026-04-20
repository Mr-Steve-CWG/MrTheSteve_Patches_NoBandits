-- WLVX_Patch.lua
-- Adds a second EveryHours handler that re-fires the three WLVX scheduled
-- shows (GMKC, Evening Report, Kentucky Tonight) on a repeating 14-day
-- cycle after the original content windows have expired.
--
-- The upstream OnEveryHour is NOT wrapped or modified. It continues to
-- handle FEMA and weather entirely on its own. It also handles the shows
-- on worldage days 0-8/0-5/0-3 (cycle 0). Our handler takes over from
-- cycle 1 onward (worldage >= 14), so there is no double-firing.
--
-- Show windows within each 14-day cycle (cycle 1+):
--   GMKC             — 7am,  cycle days 0-8   (content: gmkcDay 1-9)
--   Evening Report   — 5pm,  cycle days 0-5   (content: evrDay 1-6)
--   Kentucky Tonight — 10pm, cycle days 0-3   (content: kytDay 1-4)
--   Days 9-13: no scheduled shows (FEMA loop from upstream continues)
--
-- Per-day deduplication uses separate modData keys (WX_PATCH_*) so we
-- never interfere with the upstream keys the original handler uses.

local CYCLE_LENGTH = 14

local function installPatch()
    if not WXStationBroadcast then
        print("[WLVX_Patch] WXStationBroadcast not found — patch not applied")
        return
    end

    local function getChannel()
        return WXStation and WXStation.cache and WXStation.cache["TV-WXCH01"]
    end

    local function onEveryHour()
        -- Only active from cycle 1 onward; upstream handles cycle 0.
        local worldage = WXStationBroadcast.getWorldAgeDays()
        if worldage < CYCLE_LENGTH then return end

        local channel = getChannel()
        if not channel then return end

        local gt = getGameTime()
        if not gt then return end

        local hour     = gt:getHour()
        local cycleDay = worldage % CYCLE_LENGTH
        local modData  = gt:getModData()
        local rg       = newrandom()
        local radio    = getZomboidRadio()

        local sandbox = WXStationBroadcast.getSandbox and WXStationBroadcast.getSandbox() or {}
        local broadcastMode = sandbox.BroadcastMode
        if broadcastMode == nil then broadcastMode = 3 end
        if broadcastMode ~= 3 then return end

        -- Initialise patch-specific deduplication keys.
        if modData.WX_PATCH_GMKC_LastDay == nil then modData.WX_PATCH_GMKC_LastDay = -1    end
        if modData.WX_PATCH_EVR_LastDay  == nil then modData.WX_PATCH_EVR_LastDay  = -1    end
        if modData.WX_PATCH_KYT_LastDay  == nil then modData.WX_PATCH_KYT_LastDay  = -1    end
        if modData.WX_PATCH_Alert6       == nil then modData.WX_PATCH_Alert6       = false  end
        if modData.WX_PATCH_LastCycle    == nil then modData.WX_PATCH_LastCycle    = -1    end

        -- Reset per-day flags at cycle boundary.
        local cycleIndex = math.floor(worldage / CYCLE_LENGTH)
        if cycleIndex > modData.WX_PATCH_LastCycle then
            modData.WX_PATCH_GMKC_LastDay = -1
            modData.WX_PATCH_EVR_LastDay  = -1
            modData.WX_PATCH_KYT_LastDay  = -1
            modData.WX_PATCH_Alert6       = false
            modData.WX_PATCH_LastCycle    = cycleIndex
            print(string.format(
                "[WLVX_Patch] Cycle %d (worldage=%d, cycleDay=%d) — flags reset",
                cycleIndex, worldage, cycleDay
            ))
        end

        -- SLOT 1: Good Morning Knox County — 7am, cycle days 0-8
        if hour == 7 and cycleDay >= 0 and cycleDay <= 8
            and modData.WX_PATCH_GMKC_LastDay ~= cycleDay then

            modData.WX_PATCH_GMKC_LastDay = cycleDay
            local gmkcDay = cycleDay + 1
            local bc = RadioBroadCast.new("GMKC-P-" .. tostring(rg:random(100000, 999999)), -1, -1)
            WXStationBroadcast.addGMKCBroadcast(bc, gmkcDay, gt)
            channel:setAiringBroadcast(bc)
            WXStationBroadcast.PlaySound(radio, "GMKIntro")
            return
        end

        -- SLOT 2: The Evening Report — 5pm, cycle days 0-5
        if hour == 17 and cycleDay >= 0 and cycleDay <= 5
            and modData.WX_PATCH_EVR_LastDay ~= cycleDay then

            modData.WX_PATCH_EVR_LastDay = cycleDay
            local evrDay = cycleDay + 1
            local bc = RadioBroadCast.new("EVR-P-" .. tostring(rg:random(100000, 999999)), -1, -1)
            WXStationBroadcast.addEVRBroadcast(bc, evrDay)
            channel:setAiringBroadcast(bc)
            WXStationBroadcast.PlaySound(radio, "EveningReport")
            return
        end

        -- SLOT 3: Kentucky Tonight — 10pm, cycle days 0-3
        if hour == 22 and cycleDay >= 0 and cycleDay <= 3
            and modData.WX_PATCH_KYT_LastDay ~= cycleDay then

            modData.WX_PATCH_KYT_LastDay = cycleDay
            local kytDay = cycleDay + 1
            local bc = RadioBroadCast.new("KYT-P-" .. tostring(rg:random(100000, 999999)), -1, -1)
            WXStationBroadcast.addKYTBroadcast(bc, kytDay)
            channel:setAiringBroadcast(bc)
            WXStationBroadcast.PlaySound(radio, "KentuckyTonight")
            return
        end

        -- SLOT 4: Day 6 Alert — fires once between 10am-4pm on cycle day 6
        if cycleDay == 6 and not modData.WX_PATCH_Alert6
            and hour >= 10 and hour <= 16 then

            if rg:random(7) == 1 then
                modData.WX_PATCH_Alert6 = true
                local bc = RadioBroadCast.new("GMKC-ALT-P-" .. tostring(rg:random(100000, 999999)), -1, -1)
                WXStationBroadcast.addGMKCAlert(bc)
                local wxLevel = WXStationBroadcast.getWeatherDegradationLevel(worldage)
                WXStationBroadcast.addWeatherSegment(bc, gt, radio, wxLevel, true)
                channel:setAiringBroadcast(bc)
                if sandbox.PlayTone ~= false then
                    WXStationBroadcast.PlaySound(radio, "EmergencyAlertSystem")
                end
                return
            end
        end
    end

    Events.EveryHours.Add(onEveryHour)
    print("[WLVX_Patch] Installed — scheduled shows loop every " .. CYCLE_LENGTH .. " days from cycle 1 onward")
end

Events.OnLoadRadioScripts.Add(installPatch)
