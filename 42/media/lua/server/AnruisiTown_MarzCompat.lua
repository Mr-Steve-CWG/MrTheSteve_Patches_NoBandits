--[[
    AnruisiTown x Guns of Marz Compatibility
    =========================================
    Marz's Distribution.Insert/RemoveMany only iterates one level into each loot
    table, checking data.items directly. AnruisiTown rooms use a nested structure
    (room -> container_type -> items), so Marz never sees them. This mod handles
    the substitution directly for all AnruisiTown weapon/ammo/attachment rooms.

    For each vanilla item found in an AnruisiTown container, GoM equivalents are
    inserted at (vanilla_weight * marz_chance), mirroring Marz's own behaviour.
    Sandbox flags are respected using the same Enable_<WeaponName> check Marz uses.

    Runs on OnPostDistributionMerge, same as Marz.

    Rooms covered:
        GUNxxx          - ammo warehouse (all calibres, carton format)
        A625GUNXXX      - .357 ammo room
        A625GUNXXX2     - .357 ammo room (secondary)
        AM16GUNXXX      - 5.56 ammo room
        A12GUNXXX       - shotgun shell room
        GUNKK           - main gun vault (weapons + clips)
        armyBarracks    - surface barracks (weapons + ammo + attachments)
        dabaokkk        - command locker room
        SSS             - special storage
        qiangxiepeijia  - attachments room
]]

require "Items/Distributions"

-- ============================================================================
-- Helpers
-- ============================================================================

local sandboxWeapons = (SandboxVars and SandboxVars.MarzGuns) or {}

local function sandboxEnabled(gomItemName)
    -- gomItemName is "MarzGuns.WeaponName"; strip the module prefix to get the key
    -- Marz checks Enable_<WeaponName>; disabled only if explicitly set to false
    local shortName = gomItemName:match("^MarzGuns%.(.+)$") or gomItemName
    return sandboxWeapons["Enable_" .. shortName] ~= false
end

-- Walk a single container's flat items array (name, weight, name, weight, ...)
-- and for each vanilla item that matches a key in substitutions, insert GoM
-- equivalents then remove the vanilla entry.
-- substitutions format: { ["VanillaItem"] = { {"GomItem", chance}, ... }, ... }
local function substituteItems(itemsArray, substitutions)
    if not itemsArray then return end
    local i = 1
    while i <= #itemsArray - 1 do
        local itemName = itemsArray[i]
        local itemWeight = itemsArray[i + 1]
        local subs = substitutions[itemName]
        if subs then
            -- insert GoM replacements before the current position
            for _, sub in ipairs(subs) do
                local gomItem, chance = sub[1], sub[2]
                if sandboxEnabled(gomItem) then
                    table.insert(itemsArray, i, gomItem)
                    table.insert(itemsArray, i + 1, itemWeight * chance)
                    i = i + 2  -- skip past what we just inserted
                end
            end
            -- remove the vanilla entry (now at position i)
            table.remove(itemsArray, i + 1)
            table.remove(itemsArray, i)
            -- don't advance i; re-check this position in case of multiple matches
        else
            i = i + 2
        end
    end
end

-- Apply substitutions to every container type within a SuburbsDistributions room.
local function patchRoom(roomName, substitutions)
    local room = SuburbsDistributions[roomName]
    if not room then return end
    for _, containerData in pairs(room) do
        if containerData and containerData.items then
            substituteItems(containerData.items, substitutions)
        end
    end
end


-- ============================================================================
-- Substitution tables
-- Mirroring Marz's ItemInsertion.lua mappings.
-- Keys are vanilla item names as they appear in AnruisiTownDistributions (no module prefix).
-- GoM item names use "MarzGuns.ItemName" format, same as Marz uses in distributions.
-- ============================================================================

-- Weapons: keyed by vanilla weapon, values are GoM equivalents with Marz's chance
local weaponSubs = {
    ["AssaultRifle"]          = { {"MarzGuns.M16A1",0.3},{"MarzGuns.M16A2",0.3},{"MarzGuns.M16A2_M203",0.3},{"MarzGuns.M16A3",0.3},{"MarzGuns.FNC",0.2},{"MarzGuns.M4A1",0.3},{"MarzGuns.CAR15",0.3},{"MarzGuns.XM177",0.3},{"MarzGuns.G36C",0.35},{"MarzGuns.AK74",0.3},{"MarzGuns.AK47",0.2},{"MarzGuns.AKS74U",0.3},{"MarzGuns.ASVAL",0.25},{"MarzGuns.FAMAS",0.1},{"MarzGuns.FAL",0.2},{"MarzGuns.G3",0.2},{"MarzGuns.M79",0.1},{"MarzGuns.M60",0.1},{"MarzGuns.M203",0.25} },
    ["AssaultRifle2"]         = { {"MarzGuns.AR15",0.8},{"MarzGuns.FNC",0.05},{"MarzGuns.AK74",0.08},{"MarzGuns.AK47",0.05},{"MarzGuns.AKS74U",0.08},{"MarzGuns.FAMAS",0.05},{"MarzGuns.M14",0.5},{"MarzGuns.M1_GARAND",0.25},{"MarzGuns.FAL",0.5},{"MarzGuns.G3",0.5},{"MarzGuns.M79",0.1},{"MarzGuns.BAR",0.15},{"MarzGuns.SVD",0.25},{"MarzGuns.SKS",0.25},{"MarzGuns.PSG1",0.25} },
    ["JS14_Rifle"]            = { {"MarzGuns.AR15",0.8},{"MarzGuns.M4",0.01},{"MarzGuns.FNC",0.05},{"MarzGuns.FAMAS",0.05},{"MarzGuns.THOMPSON",0.2},{"MarzGuns.MP5",0.1} },
    ["Pistol"]                = { {"MarzGuns.M92FS",1},{"MarzGuns.M93R",0.2},{"MarzGuns.HIPOWER",0.7},{"MarzGuns.P226",0.7} },
    ["Pistol2"]               = { {"MarzGuns.M1911",1},{"MarzGuns.USP",0.5},{"MarzGuns.TEC9",0.3} },
    ["Pistol3"]               = { {"MarzGuns.DEAGLE",1},{"MarzGuns.MP5K",0.2} },
    ["Revolver"]              = { {"MarzGuns.COLT_SINGLE",0.7},{"MarzGuns.RHINO",0.5} },
    ["Revolver_Short"]        = { {"MarzGuns.MP412",0.3},{"MarzGuns.DETECTIVE_38",0.3} },
    ["Revolver_Long"]         = { {"MarzGuns.SW629",0.5},{"MarzGuns.PYTHON",0.5} },
    ["Shotgun"]               = { {"MarzGuns.MOSSBERG_590",0.5},{"MarzGuns.TRENCHGUN",0.2},{"MarzGuns.BENELLI_M4",0.1},{"MarzGuns.SPAS12",0.05},{"MarzGuns.REMINGTON_870",0.3},{"MarzGuns.W1887",0.2} },
    ["DoubleBarrelShotgun"]   = { {"MarzGuns.STEVENS_555",0.5},{"MarzGuns.DOUBLEBARREL",1},{"MarzGuns.W1887",0.2} },
    ["JS3T_Shotgun"]          = { {"MarzGuns.MOSSBERG_590",0.5},{"MarzGuns.TRENCHGUN",0.05},{"MarzGuns.BENELLI_M4",0.5},{"MarzGuns.SPAS12",0.5},{"MarzGuns.AA12",0.2},{"MarzGuns.REMINGTON_870",0.2} },
    ["HuntingRifle"]          = { {"MarzGuns.MOSIN",0.5},{"MarzGuns.M1903",0.5} },
    ["MSR7T_Rifle"]           = { {"MarzGuns.M24",0.1},{"MarzGuns.M1903",0.1},{"MarzGuns.SVD",0.15},{"MarzGuns.SKS",0.15},{"MarzGuns.PSG1",0.15} },
    ["L92_Carbine"]           = { {"MarzGuns.W1894",0.6},{"MarzGuns.M1895",0.1},{"MarzGuns.W1873",0.3},{"MarzGuns.W1873_CARBINE",0.1} },
    ["L94_Rifle"]             = { {"MarzGuns.W1894",0.2},{"MarzGuns.M1895",0.6},{"MarzGuns.W1873",0.6},{"MarzGuns.W1873_CARBINE",0.6} },
}

-- Clips/magazines
local clipSubs = {
    ["9mmClip"]   = {},  -- no direct GoM mag equivalent; vanilla clips stripped, nothing added
    ["45Clip"]    = {},
    ["556Clip"]   = {},
    ["44Clip"]    = {},
    ["M14Clip"]   = {},
    ["JS14_Clip"] = {},
}

-- Ammo boxes (Box variants)
local ammoBoxSubs = {
    ["Bullets9mmBox"]       = { {"MarzGuns.9x19_Box",1} },
    ["Bullets45Box"]        = { {"MarzGuns.45_Box",1} },
    ["556Box"]              = { {"MarzGuns.223_Box",1},{"MarzGuns.556x45_Box",0.5},{"MarzGuns.545x39_Box",0.5},{"MarzGuns.762x39_Box",0.5},{"MarzGuns.9x39_Box",0.3} },
    ["308Box"]              = { {"MarzGuns.308_Box",1},{"MarzGuns.762x51_Box",0.5},{"MarzGuns.762x54_Box",0.5},{"MarzGuns.3006_Box",0.3} },
    ["3030Box"]             = { {"MarzGuns.3030_Box",1},{"MarzGuns.4570_Box",0.3} },
    ["Bullets357Box"]       = { {"MarzGuns.357_Box",1} },
    ["Bullets38Box"]        = { {"MarzGuns.38_Box",1} },
    ["Bullets44Box"]        = { {"MarzGuns.44_Box",1},{"MarzGuns.50_Box",0.5} },
    ["ShotgunShellsBox"]    = { {"MarzGuns.12Gauge_Box_Buckshot",1} },
}

-- Ammo cartons (Carton variants) - same GoM mappings as Box equivalents
local ammoCartonSubs = {
    ["Bullets9mmCarton"]    = { {"MarzGuns.9x19_Box",1} },
    ["Bullets45Carton"]     = { {"MarzGuns.45_Box",1} },
    ["556Carton"]           = { {"MarzGuns.223_Box",1},{"MarzGuns.556x45_Box",0.5},{"MarzGuns.545x39_Box",0.5},{"MarzGuns.762x39_Box",0.5},{"MarzGuns.9x39_Box",0.3} },
    ["308Carton"]           = { {"MarzGuns.308_Box",1},{"MarzGuns.762x51_Box",0.5},{"MarzGuns.762x54_Box",0.5},{"MarzGuns.3006_Box",0.3} },
    ["3030Carton"]          = { {"MarzGuns.3030_Box",1},{"MarzGuns.4570_Box",0.3} },
    ["Bullets357Carton"]    = { {"MarzGuns.357_Box",1} },
    ["Bullets38Carton"]     = { {"MarzGuns.38_Box",1} },
    ["Bullets44Carton"]     = { {"MarzGuns.44_Box",1},{"MarzGuns.50_Box",0.5} },
    ["Bullets45Carton"]     = { {"MarzGuns.45_Box",1} },
    ["ShotgunShellsCarton"] = { {"MarzGuns.12Gauge_Box_Buckshot",1} },
}

-- Loose rounds
local ammoLooseSubs = {
    ["Bullets9mm"]      = { {"MarzGuns.9x19_Box",0.2} },
    ["Bullets45"]       = { {"MarzGuns.45_Box",0.2} },
    ["556Bullets"]      = { {"MarzGuns.223_Box",0.2},{"MarzGuns.556x45_Box",0.1} },
    ["308Bullets"]      = { {"MarzGuns.308_Box",0.2} },
    ["3030Bullets"]     = { {"MarzGuns.3030_Box",0.2} },
    ["Bullets357"]      = { {"MarzGuns.357_Box",0.2} },
    ["Bullets38"]       = { {"MarzGuns.38_Box",0.2} },
    ["Bullets44"]       = { {"MarzGuns.44_Box",0.2} },
    ["ShotgunShells"]   = { {"MarzGuns.12Gauge_Box_Buckshot",0.2} },
}

-- Attachments
local attachmentSubs = {
    ["Laser"]           = { {"MarzGuns.AR_Muzzle_Mount_Device",0.1},{"MarzGuns.AK_Muzzle_Mount_Device",0.1},{"MarzGuns.Pistol_Muzzle_Mount_Device",0.1},{"MarzGuns.LR2_Compensator",0.2},{"MarzGuns.LX_Flashhider",0.2},{"MarzGuns.Trix42_Muzzlebreak",0.2},{"MarzGuns.MKI_Suppressor",0.2},{"MarzGuns.NDR_Suppressor",0.2},{"MarzGuns.PBS-1_Suppressor",0.2},{"MarzGuns.Shh9_Suppressor",0.2},{"MarzGuns.M&P_Suppressor",0.2} },
    ["RedDot"]          = { {"MarzGuns.AR_Muzzle_Mount_Device",0.1},{"MarzGuns.AK_Muzzle_Mount_Device",0.1},{"MarzGuns.Pistol_Muzzle_Mount_Device",0.1},{"MarzGuns.LR2_Compensator",0.2},{"MarzGuns.LX_Flashhider",0.2},{"MarzGuns.Trix42_Muzzlebreak",0.2},{"MarzGuns.MKI_Suppressor",0.2},{"MarzGuns.NDR_Suppressor",0.2},{"MarzGuns.PBS-1_Suppressor",0.2},{"MarzGuns.Shh9_Suppressor",0.2},{"MarzGuns.M&P_Suppressor",0.2} },
    ["GunLight"]        = { {"MarzGuns.AR_Muzzle_Mount_Device",0.1},{"MarzGuns.AK_Muzzle_Mount_Device",0.1},{"MarzGuns.Pistol_Muzzle_Mount_Device",0.1},{"MarzGuns.LR2_Compensator",0.2},{"MarzGuns.LX_Flashhider",0.2},{"MarzGuns.Trix42_Muzzlebreak",0.2},{"MarzGuns.MKI_Suppressor",0.2},{"MarzGuns.NDR_Suppressor",0.2},{"MarzGuns.PBS-1_Suppressor",0.2},{"MarzGuns.Shh9_Suppressor",0.2},{"MarzGuns.M&P_Suppressor",0.2} },
    ["RecoilPad"]       = { {"MarzGuns.Bipod_Folded",0.5} },
    ["AmmoStraps"]      = { {"MarzGuns.Shellholder",0.5} },
    ["x2Scope"]         = { {"MarzGuns.Booster_Scope",0.25} },
    ["x4Scope"]         = {},   -- no GoM equivalent; strip only
    ["x8Scope"]         = {},
    ["TritiumSights"]   = {},
    ["ChokeTubeFull"]   = {},   -- no GoM equivalent; strip chokes
    ["ChokeTubeImproved"] = {},
}


-- ============================================================================
-- Merged substitution maps per room type
-- ============================================================================

-- Everything: weapons + clips + all ammo + attachments
local function allSubs()
    local t = {}
    for k,v in pairs(weaponSubs)      do t[k] = v end
    for k,v in pairs(clipSubs)        do t[k] = v end
    for k,v in pairs(ammoBoxSubs)     do t[k] = v end
    for k,v in pairs(ammoCartonSubs)  do t[k] = v end
    for k,v in pairs(ammoLooseSubs)   do t[k] = v end
    for k,v in pairs(attachmentSubs)  do t[k] = v end
    return t
end

-- Ammo only (cartons + boxes + loose)
local function ammoOnlySubs()
    local t = {}
    for k,v in pairs(ammoBoxSubs)     do t[k] = v end
    for k,v in pairs(ammoCartonSubs)  do t[k] = v end
    for k,v in pairs(ammoLooseSubs)   do t[k] = v end
    return t
end

-- Weapons + clips only
local function weaponsAndClipsSubs()
    local t = {}
    for k,v in pairs(weaponSubs) do t[k] = v end
    for k,v in pairs(clipSubs)   do t[k] = v end
    return t
end

-- Attachments only
local function attachmentsOnlySubs()
    local t = {}
    for k,v in pairs(attachmentSubs) do t[k] = v end
    return t
end

-- ============================================================================
-- Main pass
-- ============================================================================

local function applyAnruisiTownPass()
    if not SuburbsDistributions then
        print("[AnruisiTownMarzCompat] SuburbsDistributions not found, aborting.")
        return
    end

    -- Ammo warehouses (carton-heavy rooms)
    patchRoom("GUNxxx",       ammoOnlySubs())
    patchRoom("A625GUNXXX",   ammoOnlySubs())
    patchRoom("A625GUNXXX2",  ammoOnlySubs())
    patchRoom("AM16GUNXXX",   ammoOnlySubs())
    patchRoom("A12GUNXXX",    ammoOnlySubs())

    -- Gun vaults and barracks (weapons + clips + ammo + attachments)
    patchRoom("GUNKK",        allSubs())
    patchRoom("armyBarracks", allSubs())
    patchRoom("dabaokkk",     allSubs())
    patchRoom("SSS",          allSubs())

    -- Attachments room
    patchRoom("qiangxiepeijia", attachmentsOnlySubs())
end

Events.OnPostDistributionMerge.Add(applyAnruisiTownPass)

