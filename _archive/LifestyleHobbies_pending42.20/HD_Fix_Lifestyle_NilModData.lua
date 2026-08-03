-- Carried over from HellDrinx - Bug Fixes (workshop 3667630656), archived 2026-08-02.
-- HellDrinx author is semi-retiring and won't be maintaining this further.
-- Original fix, unmodified below. Lifestyle: Hobbies is currently subscribed but
-- NOT in the active 42.20 mod list (mod not yet updated for 42.20). Not deployed --
-- move to 42\media\lua\client\ in both repos if/when Lifestyle: Hobbies is re-enabled,
-- AND only after confirming the bug below still exists in whatever version is current then.
-- CAVEAT: this file uses pcall (LSEveryMinute wrapper below) -- against our own house
-- rule that pcall isn't reliably exposed in B42 Kahlua. Replace with explicit nil/method
-- guards before actually deploying this, don't just copy-paste it back in as-is.
--
-- Fix: Lifestyle: Hobbies (3403870858) crashes when LSMoodles entries lack .Value/.Level
-- LSCreation:218, LSPerMinute:265, LSPerHour:241 access LSMoodles[x].Value directly
-- without going through LSMoodleManager, so uninitialised entries cause __index nil crash.
-- Fix: call LSMoodleManager.init() before each Lifestyle time handler.

local _patched = false

local _hdxInited = setmetatable({}, { __mode = "k" })

local function ensureInit(player)
    if player and not player:isDead() then
        local pd = player:getModData()
        if _hdxInited[player] and pd.LSMoodles and pd.Ambitions and pd.hygieneNeed ~= nil then
            return
        end
        if not pd.Ambitions then pd.Ambitions = {} end
        if pd.hygieneNeed == nil then pd.hygieneNeed = 0 end
        if LSMoodleManager and LSMoodleManager.init then
            LSMoodleManager.init(player)
        else
            if not pd.LSMoodles then pd.LSMoodles = {} end
        end
        _hdxInited[player] = true
    end
end

local function patchLifestyle()
    if _patched then return end

    if LSEveryHour then
        local orig = LSEveryHour
        LSEveryHour = function()
            ensureInit(getPlayer())
            orig()
        end
        Events.EveryHours.Remove(orig)
        Events.EveryHours.Add(LSEveryHour)
    end

    if LSEveryTenMinutes then
        local orig = LSEveryTenMinutes
        LSEveryTenMinutes = function()
            ensureInit(getPlayer())
            orig()
        end
        Events.EveryTenMinutes.Remove(orig)
        Events.EveryTenMinutes.Add(LSEveryTenMinutes)
    end

    if LSEveryMinute then
        local orig = LSEveryMinute
        LSEveryMinute = function()
            local player = getPlayer()
            if not player then return end
            ensureInit(player)
            local pn = player.getPlayerNum and player:getPlayerNum() or 0
            local ok1, inv = pcall(function() return getPlayerInventory(pn) end)
            local ok2, loot = pcall(function() return getPlayerLoot(pn) end)
            if not ok1 or not inv or not inv.inventoryPane then return end
            if not ok2 or not loot or not loot.inventoryPane then return end
            local ok, err = pcall(orig)
            if not ok then end
        end
        Events.EveryOneMinute.Remove(orig)
        Events.EveryOneMinute.Add(LSEveryMinute)
    end

    _patched = true
end

Events.OnGameStart.Add(patchLifestyle)
