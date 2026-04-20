-- AZAS_FrequencyConflict_Patch.lua
-- Resolves frequency collisions between AZAS Frequency Index stations.
-- Injects pre-assigned entries into AZAS_FrequencyIndex.mapping before FI.apply()
-- processes AZAS_STATIONS, so conflicting stations each get a unique frequency.
--
-- Stations that are not loaded (mod not active) simply have no AZAS_STATIONS entry,
-- so the pre-seeded mapping entries are harmless no-ops in that case.
--
-- Conflict map (original -> patched):
--   SURVIVOR_RADIO_4_Just_Music_SURVIVOR_RADIO          88000 -> 87800
--   SURVIVOR_RADIO_4_GALLATIN_UNDERGROUND_...           88000 -> 87600
--   SURVIVOR_RADIO_4_Just_Music_KM_FM_ALL_COUNTRY_...   88200 -> 87400
--   SURVIVOR_RADIO_4_Classical_For_The_Dead_...        140000 -> 140200
--
-- NMR Legacy (88000) and Echo Station (88200) keep their original frequencies.
-- Reverend Dan (140000) keeps its original frequency.

local function applyFrequencyOverrides()
    if not AZAS_FrequencyIndex then
        return
    end

    local FI = AZAS_FrequencyIndex
    FI.mapping  = FI.mapping  or {}
    FI.assigned = FI.assigned or {}

    -- Helper: pre-seed a station key to a specific frequency.
    -- Only assigns if the target frequency is not already taken.
    local function seed(stationId, freq)
        if FI.mapping[stationId] then
            return  -- already resolved, don't stomp
        end
        if FI.assigned[freq] then
            print("[MrTheSteve_Patches] AZAS frequency " .. freq ..
                  " already taken when seeding " .. stationId ..
                  " — skipping. Manual RFM config update may be needed.")
            return
        end
        FI.mapping[stationId]  = freq
        FI.assigned[freq]      = true
    end

    -- Survivor Radio 4 - Just Music: SURVIVOR RADIO (conflicts with NMR at 88000)
    seed("SURVIVOR_RADIO_4_Just_Music_SURVIVOR_RADIO", 87800)

    -- Gallatin Underground (conflicts with NMR at 88000)
    seed("SURVIVOR_RADIO_4_GALLATIN_UNDERGROUND_The_Gallatin_Underground", 87600)

    -- Just Music: KM-FM All Country (conflicts with Echo Station at 88200)
    seed("SURVIVOR_RADIO_4_Just_Music_KM_FM_ALL_COUNTRY_ALL_THE_TIME", 87400)

    -- Classical for the Dead (conflicts with Reverend Dan at 140000)
    seed("SURVIVOR_RADIO_4_Classical_For_The_Dead_Classical_for_the_Dead", 140200)
end

-- AZAS_FrequencyIndex.lua runs its bottom-of-file FI.apply() before this file loads
-- (we load after AZASFrequencyIndex_RefactorTest per loadModAfter). That means
-- FI.mapping is already populated by the time we get here, but it doesn't matter:
-- getStationFrequency() in the RadioController calls FI.getFrequency() live on every
-- tune, and FI.getFrequency() checks FI.mapping first. So as long as our seeds are
-- in FI.mapping before any device tunes, the correct frequencies are returned.
-- OnGameStart fires before the player can interact with any device, so hooking there
-- is sufficient and correct.
if Events and Events.OnGameStart then
    Events.OnGameStart.Add(applyFrequencyOverrides)
end
