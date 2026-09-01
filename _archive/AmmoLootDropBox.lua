require 'Items/SuburbsDistributions'

-- Zombies Drop Ammo Boxes - MP Safe / Boxes Only / Dynamic Ammo Pool
-- Realistic mode: sandbox controls drop chance/quantity, capped at 1-3 boxes per zombie.
-- No cartons. No hard whitelist. Pulls valid ammo BOX items and arrow/bolt PACK boxes from every loaded mod.

local MOD_TAG = "[ZombiesDropAmmoBoxes][MP-Safe-AllBoxes-Arrows] "
local ammoBoxPool = nil

local function log(msg)
    print(MOD_TAG .. tostring(msg))
end

local function safe(fn, fallback)
    local ok, result = pcall(fn)
    if ok then return result end
    return fallback
end

local function getDropRate()
    return tonumber(SandboxVars and SandboxVars.AmmoLootDropBox_Normal) or 1.0
end

local function stringContains(haystack, needle)
    if not haystack or not needle then return false end
    return string.find(string.lower(tostring(haystack)), string.lower(tostring(needle)), 1, true) ~= nil
end

local function itemExists(fullType)
    if not fullType or fullType == "" then return false end
    return safe(function()
        local sm = getScriptManager and getScriptManager()
        if sm and sm.FindItem then return sm:FindItem(fullType) ~= nil end
        return true
    end, true)
end

local function getItemFullName(item)
    if not item then return nil end
    return safe(function()
        if item.getFullName then return item:getFullName() end
        local moduleName = item.getModuleName and item:getModuleName() or "Base"
        local typeName = item.getType and item:getType() or nil
        if typeName then return moduleName .. "." .. typeName end
        return nil
    end, nil)
end

local function getItemType(item)
    return safe(function()
        if item and item.getType then return item:getType() end
        return ""
    end, "") or ""
end

local function getItemDisplayName(item)
    return safe(function()
        if item and item.getDisplayName then return item:getDisplayName() end
        return ""
    end, "") or ""
end

local function getItemDisplayCategory(item)
    return safe(function()
        if item and item.getDisplayCategory then return item:getDisplayCategory() end
        return ""
    end, "") or ""
end

local function isAmmoBoxItem(item)
    local fullName = getItemFullName(item)
    if not fullName or fullName == "" then return false end

    local typeName = getItemType(item)
    local displayName = getItemDisplayName(item)
    local category = getItemDisplayCategory(item)
    local combined = tostring(fullName) .. " " .. typeName .. " " .. displayName .. " " .. category

    -- User asked for boxes/packs only. Never include cartons/crates/cans/magazines/clips or loose ammo/arrows.
    if stringContains(combined, "carton") then return false end
    if stringContains(combined, "crate") then return false end
    if stringContains(combined, "case") then return false end
    if stringContains(combined, "magazine") then return false end
    if stringContains(combined, "clip") then return false end
    if stringContains(combined, "speedloader") then return false end

    -- Must look like a box/pack of ammunition.
    -- This catches vanilla/RF/GGS/VFE/Marz boxes and GGS/Archery Nexus arrow/bolt packs.
    local looksLikeBox = stringContains(typeName, "Box")
        or stringContains(displayName, "Box of")
        or stringContains(displayName, "Ammo Box")
        or stringContains(displayName, "Rounds Box")
        or stringContains(typeName, "BattlePack")
        or stringContains(typeName, "arrow_wood_pack")
        or stringContains(typeName, "arrow_metal_pack")
        or stringContains(typeName, "arrow_carbon_pack")
        or stringContains(typeName, "bolt_wood_pack")
        or stringContains(typeName, "bolt_metal_pack")
        or stringContains(typeName, "bolt_carbon_pack")
        or stringContains(typeName, "ArrowPack")

    if not looksLikeBox then return false end

    -- Must also look ammo-related, so we do not accidentally grab random non-ammo boxes.
    -- Loose arrows/bolts are excluded because only their pack names pass looksLikeBox.
    local ammoLike = stringContains(category, "Ammo")
        or stringContains(displayName, "round")
        or stringContains(displayName, "shell")
        or stringContains(displayName, "ammo")
        or stringContains(displayName, "arrow")
        or stringContains(displayName, "bolt")
        or stringContains(typeName, "Bullet")
        or stringContains(typeName, "Shell")
        or stringContains(typeName, "arrow_")
        or stringContains(typeName, "bolt_")
        or stringContains(typeName, "BattlePack")
        or stringContains(typeName, "ArrowPack")
        or stringContains(typeName, "556")
        or stringContains(typeName, "762")
        or stringContains(typeName, "545")
        or stringContains(typeName, "308")
        or stringContains(typeName, "223")
        or stringContains(typeName, "303")
        or stringContains(typeName, "9x")
        or stringContains(typeName, "30_06")
        or stringContains(typeName, "Marz")

    return ammoLike and itemExists(fullName)
end

local function addUnique(pool, seen, fullType)
    if not fullType or fullType == "" or seen[fullType] then return end
    if not itemExists(fullType) then return end
    seen[fullType] = true
    table.insert(pool, fullType)
end

local function buildAmmoBoxPool()
    if ammoBoxPool then return ammoBoxPool end

    local pool = {}
    local seen = {}

    -- Dynamic scan: catches Vanilla, Real Firearms, Gale's Gun Mod, Gale's Gun Store, and future ammo-box mods.
    safe(function()
        local sm = getScriptManager and getScriptManager()
        if not sm or not sm.getAllItems then return end
        local items = sm:getAllItems()
        if not items then return end
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            if isAmmoBoxItem(item) then
                addUnique(pool, seen, getItemFullName(item))
            end
        end
    end, nil)

    -- Fallback list for common vanilla/RF/Gale box names if a display-category scan misses them.
    local fallbackBoxes = {
        "Base.223Box", "Base.308Box", "Base.Bullets38Box", "Base.Bullets44Box", "Base.Bullets45Box",
        "Base.Bullets9mmBox", "Base.ShotgunShellsBox", "Base.556Box", "Base.762x39Box",
        "Base.9x39Box", "Base.Bullets22LRBox", "Base.Bullets32Box", "Base.Bullets357Box",
        "Base.Bullets50Box", "Base.Bullets50MagnumBox", "Base.545x39Box", "Base.30_06Box",
        "Base.303Box", "Base.762x54rBox", "Base.792x57Box", "Base.308Box150", "Base.556Box150",
        "Base.762x54rBox150", "Base.792x57Box75", "Base.792x57Box97", "Base.GrenadeAmmoBox",
        "Base.RF_127x55Box", "Base.RF_12GaugeBox", "Base.RF_3006Box", "Base.RF_357Box",
        "Base.RF_45Box", "Base.RF_500Box", "Base.RF_545x39Box", "Base.RF_556x45Box",
        "Base.RF_762x25Box", "Base.RF_762x39Box", "Base.RF_762x51Box", "Base.RF_762x54Box",
        "Base.RF_792x33Box", "Base.RF_792x57Box", "Base.RF_9x18Box", "Base.RF_9x19Box",

        -- Big compatibility additions: Guns of Mars / Marz, VFE Redux family, VFR vanilla-compatible boxes, and GGS archery packs.
        "MarzGuns.12Gauge_Box_Buckshot",
        "MarzGuns.12Gauge_Box_Slug",
        "MarzGuns.9x19_Box",
        "MarzGuns.45_Box",
        "MarzGuns.38_Box",
        "MarzGuns.44_Box",
        "MarzGuns.50_Box",
        "MarzGuns.762x51_Box",
        "MarzGuns.308_Box",
        "MarzGuns.762x54_Box",
        "MarzGuns.556x45_Box",
        "MarzGuns.556x45_Box_HollowPoint",
        "MarzGuns.556x45_Box_ArmorPiercing",
        "MarzGuns.556x45_Box_Subsonic",
        "MarzGuns.556x45_Box_Overpressured",
        "MarzGuns.223_Box",
        "MarzGuns.545x39_Box",
        "MarzGuns.762x39_Box",
        "MarzGuns.9x39_Box",
        "MarzGuns.3006_Box",
        "MarzGuns.3030_Box",
        "MarzGuns.357_Box",
        "MarzGuns.4570_Box",
        "MarzGuns.40mm_Box_Buckshot",
        "MarzGuns.40mm_Box_HE",
        "Base.762Box",
        "Base.22Box",
        "Base.308Box",
        "Base.556Box",
        "Base.223Box",
        "Base.ShotgunShellsBox",
        "Base.Bullets9mmBox",
        "Base.Bullets38Box",
        "Base.Bullets44Box",
        "Base.Bullets45Box",
        "Base.3030Box",
        "Base.Bullets357Box",
        "Base.556BattlePack",
        "Base.57Box",
        "Base.46Box",
        "Base.545Box",
        "Base.939Box",
        "Base.76254Box",
        "Base.arrow_wood_pack",
        "Base.arrow_metal_pack",
        "Base.arrow_carbon_pack",
        "Base.bolt_wood_pack",
        "Base.bolt_metal_pack",
        "Base.bolt_carbon_pack",
        "Base.ArrowPack",

        -- Gale's Gun Store / Archery Nexus arrow and bolt boxes/packs.
        -- These are PACKS that open into arrows/bolts, not the loose arrows/bolts themselves.
        "Base.arrow_wood_pack", "Base.arrow_metal_pack", "Base.arrow_carbon_pack",
        "Base.bolt_wood_pack", "Base.bolt_metal_pack", "Base.bolt_carbon_pack",

        -- Legacy Archery Nexus compatibility pack, if loaded.
        "Base.ArrowPack"
    }

    for _, fullType in ipairs(fallbackBoxes) do
        if not stringContains(fullType, "Carton") then addUnique(pool, seen, fullType) end
    end

    ammoBoxPool = pool
    log("Loaded " .. tostring(#ammoBoxPool) .. " valid ammo box/arrow-pack types. Cartons and loose arrows excluded.")
    return ammoBoxPool
end

local function rollAmmoBox()
    local pool = buildAmmoBoxPool()
    if not pool or #pool == 0 then return nil end
    return pool[ZombRand(#pool) + 1]
end

local function rollRealisticBoxCount(rate)
    rate = tonumber(rate) or 0
    if rate <= 0 then return 0 end

    -- Option A / realistic:
    -- 0-100: chance for 1 box.
    -- 101-200: guaranteed 1, chance for 2.
    -- 201-300+: guaranteed 2, chance for 3.
    -- Hard cap: 3 boxes per zombie, no matter how high the sandbox goes.
    local count = 0
    local remaining = rate

    for _ = 1, 3 do
        if remaining >= 100 then
            count = count + 1
        elseif remaining > 0 and ZombRand(100) < remaining then
            count = count + 1
        end
        remaining = remaining - 100
        if remaining <= 0 then break end
    end

    if count > 3 then count = 3 end
    return count
end

local function addBoxToZombie(zombie, fullType)
    if not zombie or not fullType or not itemExists(fullType) then return false end
    return safe(function()
        local inv = zombie:getInventory()
        if not inv then return false end
        local item = inv:AddItem(fullType)
        return item ~= nil
    end, false)
end

local function onZombieDead(zombie)
    -- In multiplayer, only the server should create the corpse loot.
    if isClient and isClient() then return end

    local count = rollRealisticBoxCount(getDropRate())
    if count <= 0 then return end

    for _ = 1, count do
        local fullType = rollAmmoBox()
        if fullType then addBoxToZombie(zombie, fullType) end
    end
end

local function initAmmoBoxDrops()
    buildAmmoBoxPool()
    log("Ready. Sandbox rate=" .. tostring(getDropRate()) .. ". Realistic mode active: 0-3 boxes/packs per zombie. Boxes/packs only, no cartons, no loose arrows.")
end

Events.OnInitGlobalModData.Add(initAmmoBoxDrops)
Events.OnZombieDead.Add(onZombieDead)
