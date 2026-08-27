-- GoM_VanillaConverter_Patch.lua
-- Part of MrTheSteve_Patches
--
-- Patches: Guns of Marz (Workshop: 3722134990)
--
-- ============================================================
-- PURPOSE
--
-- GoM removes vanilla weapons and ammo from all loot tables at
-- load time via Distribution.RemoveMany. Other mods (airdrops,
-- military units, zone mods) can still inject vanilla items at
-- runtime outside GoM's reach. This patch adds right-click
-- context menu options on vanilla items so the player can
-- convert them to GoM equivalents.
--
-- All conversions: consume the vanilla item, produce GoM item(s).
-- Guard: options only appear when GoM (mod id "MarzGuns") is in the
-- active mod list. Inventory items only (not ground items).
--
-- FIX: gomActive() checked mod id "GunsOfMarz", but GoM's actual
-- mod.info id is "MarzGuns" ("GunsOfMarz" is only the workshop
-- folder/display name). getActivatedMods():contains() matches on
-- id, so this check always returned false and the entire context
-- menu hook below was a no-op regardless of whether GoM was active.
-- ============================================================

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function gomActive()
    -- GoM's workshop item (3722134990) ships two mutually-incompatible mod
    -- id variants: "MarzGuns" (Old Version) and "GunsOfMarz" (current).
    -- Exactly one can be active at a time, so check both and let whichever
    -- one is enabled satisfy the gate. Item fullTypes stay "MarzGuns.*" in
    -- both variants, so nothing else here needs to change.
    local mods = getActivatedMods()
    return mods:contains("MarzGuns") or mods:contains("GunsOfMarz")
end

-- Remove one instance of fullType from the player's inventory.
local function removeItem(player, fullType)
    local inv = player:getInventory()
    local item = inv:getFirstTypeRecurse(fullType)
    if item then
        inv:Remove(item)
    end
end

-- Add one item by fullType into the player's inventory.
local function addItem(player, fullType)
    player:getInventory():AddItem(fullType)
end

-- Pick one entry at random from a table (equal weight).
local function pick(options)
    return options[ZombRand(#options) + 1]
end

-- Unwrap an inventory context-menu item entry.
-- Vanilla passes either the InventoryItem directly, or a wrapper table whose
-- "items" field is a Java ArrayList. Some other mods that build their own
-- context menu entries (observed: TwisTonFire QoL Modpack) instead put a
-- plain Lua table in "items", which has no :get() method and previously
-- crashed this hook with "Object tried to call nil".
local function unwrapItemEntry(entry)
    local item = entry
    if type(entry) == "table" and entry.items then
        if type(entry.items) == "table" then
            item = entry.items[1]
        else
            item = entry.items:get(0)
        end
    end
    return item
end

-- ---------------------------------------------------------------------------
-- Condition transfer for gun conversions
-- ---------------------------------------------------------------------------

local function transferCondition(vanillaGun, gomGun)
    local vanillaMax = vanillaGun:getConditionMax()
    if vanillaMax == nil or vanillaMax == 0 then return end
    local gomMax = gomGun:getConditionMax()
    if gomMax == nil or gomMax == 0 then return end
    local fraction = vanillaGun:getCondition() / vanillaMax
    gomGun:setCondition(math.floor(fraction * gomMax))
end

-- ---------------------------------------------------------------------------
-- Ammo conversion tables
-- ---------------------------------------------------------------------------

-- Single-option calibers.
-- van/vanBox/vanCrate: vanilla fullTypes.
-- gom: MarzGuns prefix; suffixed with _Bullet / _Box / _Crate at use time.
local AMMO_SINGLE = {
    { van = "Base.Bullets9mm",  vanBox = "Base.Bullets9mmBox",  vanCrate = "Base.Bullets9mmCarton",  gom = "MarzGuns.9x19" },
    { van = "Base.Bullets45",   vanBox = "Base.Bullets45Box",   vanCrate = "Base.Bullets45Carton",   gom = "MarzGuns.45" },
    { van = "Base.Bullets38",   vanBox = "Base.Bullets38Box",   vanCrate = "Base.Bullets38Carton",   gom = "MarzGuns.38" },
    { van = "Base.Bullets357",  vanBox = "Base.Bullets357Box",  vanCrate = "Base.Bullets357Carton",  gom = "MarzGuns.357" },
    { van = "Base.Bullets44",   vanBox = "Base.Bullets44Box",   vanCrate = "Base.Bullets44Carton",   gom = "MarzGuns.44" },
    { van = "Base.3030Bullets", vanBox = "Base.3030Box",        vanCrate = "Base.3030Carton",        gom = "MarzGuns.3030" },
}

-- Multi-option calibers: present a submenu so the player chooses the GoM variant.
-- suffixed=true: GoM items named <prefix>_Bullet / _Box / _Crate.
-- suffixed=false (shotgun): full item names given per variant per tier.
local AMMO_MULTI = {
    {
        van = "Base.556Bullets", vanBox = "Base.556Box", vanCrate = "Base.556Carton",
        label = "5.56 Ammo",
        gomPrefixes = { "MarzGuns.556x45", "MarzGuns.223" },
        suffixed = true,
    },
    {
        van = "Base.308Bullets", vanBox = "Base.308Box", vanCrate = "Base.308Carton",
        label = ".308 Ammo",
        gomPrefixes = { "MarzGuns.308", "MarzGuns.762x51" },
        suffixed = true,
    },
    {
        van = "Base.ShotgunShells", vanBox = "Base.ShotgunShellsBox", vanCrate = "Base.ShotgunShellsCarton",
        label = "12ga Shells",
        -- FIX: GoM only has one generic MarzGuns.12Gauge_Crate; there is no
        -- buckshot/slug split at the crate tier (unlike loose/box). Both
        -- variants point at the same generic crate item.
        gomVariants = {
            { label = "Buckshot", loose = "MarzGuns.12Gauge_Shell_Buckshot", box = "MarzGuns.12Gauge_Box_Buckshot", crate = "MarzGuns.12Gauge_Crate" },
            { label = "Slug",     loose = "MarzGuns.12Gauge_Shell_Slug",     box = "MarzGuns.12Gauge_Box_Slug",     crate = "MarzGuns.12Gauge_Crate" },
        },
        suffixed = false,
    },
}

-- ---------------------------------------------------------------------------
-- Attachment conversion table
-- ---------------------------------------------------------------------------

-- produces entries prefixed "PICK:A:B" are resolved at click time by
-- resolveProduces() -- picks one of MarzGuns.A or MarzGuns.B randomly.

local ATTACHMENT_MAP = {
    ["Base.x2Scope"]           = { produces = { "PICK:ElcanX2_Scope:TA28_Scope",   "MarzGuns.Picatinny_Rail" } },
    ["Base.x4Scope"]           = { produces = { "MarzGuns.LR4X_Scope",             "MarzGuns.Picatinny_Rail" } },
    ["Base.x8Scope"]           = { produces = { "PICK:LR10X_Scope:LRX12X_Scope",   "MarzGuns.Picatinny_Rail" } },
    ["Base.RedDot"]            = { produces = { "PICK:ReflexS2_Sight:EXPS1_Sight", "MarzGuns.Picatinny_Rail" } },
    ["Base.TritiumSights"]     = { produces = { "MarzGuns.Aimpoint_Sight",          "MarzGuns.Picatinny_Rail" } },
    ["Base.Laser"]             = { produces = { "PICK:PJ-3_Laser:PX1_Laser",       "MarzGuns.Picatinny_Rail" } },
    ["Base.GunLight"]          = { produces = { "PICK:LP_Light:TL_Light",           "MarzGuns.Picatinny_Rail" } },
    ["Base.RecoilPad"]         = { produces = { "MarzGuns.Bipod_Folded",            "MarzGuns.Picatinny_Rail" } },
    ["Base.AmmoStraps"]        = { produces = { "MarzGuns.Shellholder" } },
    ["Base.ChokeTubeFull"]     = { produces = { "Base.ScrapMetal" } },
    ["Base.ChokeTubeImproved"] = { produces = { "Base.ScrapMetal" } },
}

-- Resolve a produces list: "PICK:A:B" -> randomly pick MarzGuns.A or MarzGuns.B.
local function resolveProduces(produces)
    local resolved = {}
    for _, entry in ipairs(produces) do
        if entry:sub(1, 5) == "PICK:" then
            local parts = {}
            for p in entry:sub(6):gmatch("[^:]+") do
                parts[#parts + 1] = "MarzGuns." .. p
            end
            resolved[#resolved + 1] = pick(parts)
        else
            resolved[#resolved + 1] = entry
        end
    end
    return resolved
end

-- ---------------------------------------------------------------------------
-- Magazine / clip conversion table
-- ---------------------------------------------------------------------------

local CLIP_MAP = {
    ["Base.556Clip"]   = "MarzGuns.556x45Magazine30_STANAG",
    ["Base.JS14_Clip"] = "MarzGuns.556x45Magazine20_STANAG",
    ["Base.M14Clip"]   = "MarzGuns.3006Clip8",
    ["Base.9mmClip"]   = "MarzGuns.9x19Magazine10_P226",
    ["Base.45Clip"]    = "MarzGuns.45Magazine7_M1911",
    ["Base.44Clip"]    = "MarzGuns.50Magazine8_DEAGLE",
}

-- ---------------------------------------------------------------------------
-- Gun conversion table
-- ---------------------------------------------------------------------------

local GUN_MAP = {
    ["Base.AssaultRifle"]               = { gom = "MarzGuns.M4A1",          mount = "MarzGuns.Picatinny_Rail" },
    ["Base.AssaultRifle2"]              = { gom = "MarzGuns.M1_GARAND",     mount = "MarzGuns.Picatinny_Rail" },
    ["Base.JS14_Rifle"]                 = { gom = "MarzGuns.AR15",          mount = "MarzGuns.Picatinny_Rail" },
    ["Base.HuntingRifle"]               = { gom = "MarzGuns.MOSIN",         mount = "MarzGuns.Sniper_Mount" },
    ["Base.MSR7T_Rifle"]                = { gom = "MarzGuns.M24",           mount = "MarzGuns.Picatinny_Rail" },
    ["Base.L92_Carbine"]                = { gom = "MarzGuns.W1873_CARBINE", mount = nil },
    ["Base.L94_Rifle"]                  = { gom = "MarzGuns.W1873",         mount = nil },
    ["Base.Shotgun"]                    = { gom = "MarzGuns.W1887",         mount = nil },
    ["Base.JS3T_Shotgun"]               = { gom = "MarzGuns.MOSSBERG_590",  mount = nil },
    ["Base.DoubleBarrelShotgun"]        = { gom = "MarzGuns.STEVENS_555",   mount = nil },
    ["Base.DoubleBarrelShotgunSawnoff"] = { gom = "MarzGuns.DOUBLEBARREL",  mount = nil },
    ["Base.Pistol"]                     = { gom = "MarzGuns.P226",          mount = "MarzGuns.Picatinny_Rail" },
    ["Base.Pistol2"]                    = { gom = "MarzGuns.M1911",         mount = "MarzGuns.Colt_Mount" },
    ["Base.Pistol3"]                    = { gom = "MarzGuns.DEAGLE",        mount = "MarzGuns.Heavy_Pistol_Rail" },
    ["Base.Revolver"]                   = { gom = "MarzGuns.RHINO",         mount = nil },
    ["Base.Revolver_Short"]             = { gom = "MarzGuns.MP412",         mount = nil },
    ["Base.Revolver_Long"]              = { gom = "MarzGuns.PYTHON",        mount = nil },
    -- Base.VarmintRifle: intentionally excluded.
}

-- ---------------------------------------------------------------------------
-- Context menu hook
-- ---------------------------------------------------------------------------

local function onFillInventoryObjectContextMenu(playerNum, context, items)
    if not gomActive() then return end

    local player = getSpecificPlayer(playerNum)
    if not player then return end

    -- Collect all unique fullTypes present in the item list.
    -- items entries can be InventoryItem directly or a wrapper table.
    local typesPresent = {}
    for _, entry in ipairs(items) do
        local item = unwrapItemEntry(entry)
        if item and instanceof(item, "InventoryItem") then
            typesPresent[item:getFullType()] = true
        end
    end

    -- -----------------------------------------------------------------------
    -- Ammo: single-option calibers
    -- -----------------------------------------------------------------------
    for _, cfg in ipairs(AMMO_SINGLE) do
        if typesPresent[cfg.van] then
            local label = "Convert " .. cfg.van:match("%.(.+)$") .. " -> GoM"
            local vanType, gomType = cfg.van, cfg.gom .. "_Bullet"
            context:addOption(label, player, function(p)
                removeItem(p, vanType) ; addItem(p, gomType)
            end)
        end
        if typesPresent[cfg.vanBox] then
            local label = "Convert " .. cfg.vanBox:match("%.(.+)$") .. " -> GoM"
            local vanType, gomType = cfg.vanBox, cfg.gom .. "_Box"
            context:addOption(label, player, function(p)
                removeItem(p, vanType) ; addItem(p, gomType)
            end)
        end
        if typesPresent[cfg.vanCrate] then
            local label = "Convert " .. cfg.vanCrate:match("%.(.+)$") .. " -> GoM"
            local vanType, gomType = cfg.vanCrate, cfg.gom .. "_Crate"
            context:addOption(label, player, function(p)
                removeItem(p, vanType) ; addItem(p, gomType)
            end)
        end
    end

    -- -----------------------------------------------------------------------
    -- Ammo: multi-option calibers (submenu per tier)
    -- -----------------------------------------------------------------------
    local function addAmmoSubMenu(vanType, tierKey)
        for _, cfg in ipairs(AMMO_MULTI) do
            local van = cfg[tierKey == "loose" and "van" or (tierKey == "box" and "vanBox" or "vanCrate")]
            if typesPresent[van] then
                local subOpt = context:addOption("Convert " .. van:match("%.(.+)$") .. " -> GoM", player, nil)
                local sub = context:getNew(subOpt)
                context:addSubMenu(subOpt, sub)
                if cfg.suffixed then
                    for _, prefix in ipairs(cfg.gomPrefixes) do
                        local lbl = prefix:match("%.(.+)$")
                        local vt = van
                        local gt = prefix .. (tierKey == "loose" and "_Bullet" or (tierKey == "box" and "_Box" or "_Crate"))
                        sub:addOption(lbl, player, function(p)
                            removeItem(p, vt) ; addItem(p, gt)
                        end)
                    end
                else
                    for _, v in ipairs(cfg.gomVariants) do
                        local lbl = v.label
                        local vt = van
                        local gt = v[tierKey == "loose" and "loose" or (tierKey == "box" and "box" or "crate")]
                        sub:addOption(lbl, player, function(p)
                            removeItem(p, vt) ; addItem(p, gt)
                        end)
                    end
                end
            end
        end
    end

    addAmmoSubMenu(nil, "loose")
    addAmmoSubMenu(nil, "box")
    addAmmoSubMenu(nil, "crate")

    -- -----------------------------------------------------------------------
    -- Attachments
    -- -----------------------------------------------------------------------
    for vanType, cfg in pairs(ATTACHMENT_MAP) do
        if typesPresent[vanType] then
            local label = "Convert " .. vanType:match("%.(.+)$") .. " -> GoM"
            local produces = cfg.produces
            context:addOption(label, player, function(p)
                removeItem(p, vanType)
                for _, ft in ipairs(resolveProduces(produces)) do
                    addItem(p, ft)
                end
            end)
        end
    end

    -- -----------------------------------------------------------------------
    -- Magazines / clips
    -- -----------------------------------------------------------------------
    for vanType, gomType in pairs(CLIP_MAP) do
        if typesPresent[vanType] then
            local label = "Convert " .. vanType:match("%.(.+)$") .. " -> GoM"
            context:addOption(label, player, function(p)
                removeItem(p, vanType) ; addItem(p, gomType)
            end)
        end
    end

    -- -----------------------------------------------------------------------
    -- Guns
    -- -----------------------------------------------------------------------
    for vanType, cfg in pairs(GUN_MAP) do
        if typesPresent[vanType] then
            -- Locate the actual item object to inspect magazine and attachment state.
            local vanItem = nil
            for _, entry in ipairs(items) do
                local item = unwrapItemEntry(entry)
                if item and instanceof(item, "InventoryItem") and item:getFullType() == vanType then
                    vanItem = item
                    break
                end
            end
            if vanItem ~= nil then
                local hasMag = vanItem:getMagazine() ~= nil
                local hasAttachment = false
                local attachSlots = vanItem:getAttachmentSlotList()
                if attachSlots ~= nil then
                    for i = 0, attachSlots:size() - 1 do
                        local slot = attachSlots:get(i)
                        if slot ~= nil and slot:getItem() ~= nil then
                            hasAttachment = true
                            break
                        end
                    end
                end

                local label = "Convert " .. vanType:match("%.(.+)$") .. " -> GoM"

                if hasMag or hasAttachment then
                    local blockMsg = "[GoM Converter] Remove "
                    if hasMag and hasAttachment then
                        blockMsg = blockMsg .. "magazine and all attachments"
                    elseif hasMag then
                        blockMsg = blockMsg .. "the magazine"
                    else
                        blockMsg = blockMsg .. "all attachments"
                    end
                    blockMsg = blockMsg .. " from " .. vanType:match("%.(.+)$") .. " before converting."
                    context:addOption(label .. " [BLOCKED]", player, function(p)
                        p:Say(blockMsg)
                    end)
                else
                    local gomType = cfg.gom
                    local mountType = cfg.mount
                    context:addOption(label, player, function(p)
                        local inv = p:getInventory()
                        local srcItem = inv:getFirstTypeRecurse(vanType)
                        if srcItem == nil then return end
                        inv:Remove(srcItem)
                        local newItem = inv:AddItem(gomType)
                        if newItem ~= nil and instanceof(newItem, "HandWeapon") then
                            transferCondition(srcItem, newItem)
                        end
                        if mountType ~= nil then
                            addItem(p, mountType)
                        end
                    end)
                end
            end
        end
    end
end

Events.OnFillInventoryObjectContextMenu.Add(onFillInventoryObjectContextMenu)
