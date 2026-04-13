-- Patch for Lifestyle mod (3403870858)
-- TVRADIOTraits_ISRadioInteractions.lua calls _interactCodes:len() before nil-checking it.
-- Java null objects from the radio system pass == nil but crash on method calls.
-- This replaces the file wholesale with identical logic plus safe nil guards.
-- Patch points marked with -- PATCH:

require "RadioCom/ISRadioInteractions"

Events.OnGameBoot.Remove(function() ISRadioInteractions:getInstance(); end)

local DEBUG = false
local statsHalo = true

local function doSkill(_player, _amount, _name, _perk)
    if _amount == nil or _amount <= 0 then return end
    if SandboxVars and (_player:getPerkLevel(_perk) >= SandboxVars.LevelForMediaXPCutoff) then return end
    local amount = 50*_amount
    if _player:hasTrait(CharacterTrait.COUCHPOTATO) then
        amount = 75*_amount
    elseif _player:hasTrait(CharacterTrait.DISCIPLINED) then
        amount = 25*_amount
    end
    local oldXp = _player:getXp():getXP(_perk)
    addXp(_player, _perk, amount)
    amount = _player:getXp():getXP(_perk) - oldXp
    if oldXp ~= _player:getXp():getXP(_perk) then
        ISRadioInteractions:getInstance().addHalo(_name, amount, true)
    end
end

local function applyBoredom(_player, _amount, _isSet)
    if _player:getStats() ~= nil then
        if _isSet then
            if _player:hasTrait(CharacterTrait.COUCHPOTATO) then _amount = 2*_amount
            elseif _player:hasTrait(CharacterTrait.DISCIPLINED) then _amount = 0.2*_amount end
        elseif _player:hasTrait(CharacterTrait.COUCHPOTATO) then _amount = _amount*10
        elseif _player:hasTrait(CharacterTrait.DISCIPLINED) then _amount = _amount*2
        else _amount = _amount*5 end
        local valueChanged = _player:getStats():add(CharacterStat.BOREDOM, _amount)
        if DEBUG then
            _player:setHaloNote("Boredom " .. tostring(_player:getStats():get(CharacterStat.BOREDOM)))
        elseif statsHalo and not _isSet and valueChanged then
            ISRadioInteractions:getInstance().addHalo(getText("IGUI_HaloNote_Boredom"), _amount)
        end
    end
end

local function applyUnhappiness(_player, _amount, _isSet)
    if _player:getStats() ~= nil then
        if _isSet then
            if _player:hasTrait(CharacterTrait.COUCHPOTATO) then _amount = 2*_amount
            elseif _player:hasTrait(CharacterTrait.DISCIPLINED) then _amount = 0.2*_amount end
        elseif _player:hasTrait(CharacterTrait.COUCHPOTATO) then _amount = _amount*10
        elseif _player:hasTrait(CharacterTrait.DISCIPLINED) then _amount = _amount*2
        else _amount = _amount*5 end
        local valueChanged = _player:getStats():add(CharacterStat.UNHAPPINESS, _amount)
        if DEBUG then
            _player:setHaloNote("Unhappiness " .. tostring(_player:getStats():get(CharacterStat.UNHAPPINESS)))
        elseif statsHalo and not _isSet and valueChanged then
            ISRadioInteractions:getInstance().addHalo(getText("IGUI_HaloNote_Unhappiness"), _amount)
        end
    end
end

local function doStat(_statStr, _player, _amount, _isSet)
    if _statStr == "Boredom" then applyBoredom(_player, _amount, _isSet); return
    elseif _statStr == "Unhappiness" then applyUnhappiness(_player, _amount, _isSet); return end
    local stats = _player:getStats()
    if stats["get".._statStr] ~= nil then
        local val = stats["get".._statStr](stats)
        local valCache = val
        local range100 = _statStr == "Panic"
        if _isSet then val = _amount
        else val = val + _amount * (range100 and 5 or 0.05) end
        if val < 0 then val = 0 end
        if (not range100) and val > 1 then val = 1 end
        if range100 and val > 100 then val = 100 end
        stats["set".._statStr](stats, val)
        if DEBUG then
            _player:setHaloNote(getText("IGUI_HaloNote_".._statStr).." "..tostring(stats["get".._statStr](stats)))
        elseif statsHalo and not _isSet and valCache ~= stats["get".._statStr](stats) then
            ISRadioInteractions:getInstance().addHalo(getText("IGUI_HaloNote_".._statStr), _amount)
        end
    end
end

local Interactions = {}
Interactions.ANG = function(p,a,s) doStat("Anger",p,a,s) end
Interactions.BOR = function(p,a,s) doStat("Boredom",p,a,s) end
Interactions.END = function(p,a,s) doStat("Endurance",p,a,s) end
Interactions.FAT = function(p,a,s) doStat("Fatigue",p,a,s) end
Interactions.FIT = function(p,a,s) doStat("Fitness",p,a,s) end
Interactions.HUN = function(p,a,s) doStat("Hunger",p,a,s) end
Interactions.MOR = function(p,a,s) doStat("Morale",p,a,s) end
Interactions.STS = function(p,a,s) doStat("Stress",p,a,s) end
Interactions.FEA = function(p,a,s) doStat("Fear",p,a,s) end
Interactions.PAN = function(p,a,s) doStat("Panic",p,a,s) end
Interactions.SAN = function(p,a,s) doStat("Sanity",p,a,s) end
Interactions.SIC = function(p,a,s) doStat("Sickness",p,a,s) end
Interactions.PAI = function(p,a,s) doStat("Pain",p,a,s) end
Interactions.DRU = function(p,a,s) doStat("Intoxication",p,a,s) end
Interactions.THI = function(p,a,s) doStat("Thirst",p,a,s) end
Interactions.UHP = function(p,a,s) doStat("Unhappiness",p,a,s) end
Interactions.SPR = function(p,a) doSkill(p,a,getText("IGUI_perks_Sprinting"),Perks.Sprinting) end
Interactions.LFT = function(p,a) doSkill(p,a,getText("IGUI_perks_Lightfooted"),Perks.Lightfoot) end
Interactions.NIM = function(p,a) doSkill(p,a,getText("IGUI_perks_Nimble"),Perks.Nimble) end
Interactions.SNE = function(p,a) doSkill(p,a,getText("IGUI_perks_Sneaking"),Perks.Sneak) end
Interactions.BAA = function(p,a) doSkill(p,a,getText("IGUI_perks_Axe"),Perks.Axe) end
Interactions.BUA = function(p,a) doSkill(p,a,getText("IGUI_perks_Blunt"),Perks.Blunt) end
Interactions.CRP = function(p,a) doSkill(p,a,getText("IGUI_perks_Carpentry"),Perks.Woodwork) end
Interactions.COO = function(p,a) doSkill(p,a,getText("IGUI_perks_Cooking"),Perks.Cooking) end
Interactions.FRM = function(p,a) doSkill(p,a,getText("IGUI_perks_Farming"),Perks.Farming) end
Interactions.DOC = function(p,a) doSkill(p,a,getText("IGUI_perks_Doctor"),Perks.Doctor) end
Interactions.ELC = function(p,a) doSkill(p,a,getText("IGUI_perks_Electricity"),Perks.Electricity) end
Interactions.MTL = function(p,a) doSkill(p,a,getText("IGUI_perks_Metalworking"),Perks.MetalWelding) end
Interactions.FKN = function(p,a) doSkill(p,a,getText("IGUI_perks_FlintKnapping"),Perks.FlintKnapping) end
Interactions.CRV = function(p,a) doSkill(p,a,getText("IGUI_perks_Carving"),Perks.Carving) end
Interactions.AIM = function(p,a) doSkill(p,a,getText("IGUI_perks_Aiming"),Perks.Aiming) end
Interactions.REL = function(p,a) doSkill(p,a,getText("IGUI_perks_Reloading"),Perks.Reloading) end
Interactions.FIS = function(p,a) doSkill(p,a,getText("IGUI_perks_Fishing"),Perks.Fishing) end
Interactions.TRA = function(p,a) doSkill(p,a,getText("IGUI_perks_Trapping"),Perks.Trapping) end
Interactions.FOR = function(p,a) doSkill(p,a,getText("IGUI_perks_Foraging"),Perks.PlantScavenging) end
Interactions.TAI = function(p,a) doSkill(p,a,getText("IGUI_perks_Tailoring"),Perks.Tailoring) end
Interactions.MEC = function(p,a) doSkill(p,a,getText("IGUI_perks_Mechanics"),Perks.Mechanics) end
Interactions.CMB = function(p,a) doSkill(p,a,getText("IGUI_perks_Combat"),Perks.Combat) end
Interactions.SPE = function(p,a) doSkill(p,a,getText("IGUI_perks_Spear"),Perks.Spear) end
Interactions.SBU = function(p,a) doSkill(p,a,getText("IGUI_perks_SmallBlunt"),Perks.SmallBlunt) end
Interactions.LBA = function(p,a) doSkill(p,a,getText("IGUI_perks_LongBlade"),Perks.LongBlade) end
Interactions.SBA = function(p,a) doSkill(p,a,getText("IGUI_perks_SmallBlade"),Perks.SmallBlade) end
Interactions.MAS = function(p,a) doSkill(p,a,getText("IGUI_perks_Masonry"),Perks.Masonry) end
Interactions.POT = function(p,a) doSkill(p,a,getText("IGUI_perks_Pottery"),Perks.Pottery) end
Interactions.DNC = function(p,a) doSkill(p,a,getText("IGUI_perks_Dancing"),Perks.Dancing) end
Interactions.ART = function(p,a) doSkill(p,a,getText("IGUI_perks_Art"),Perks.Art) end

local instance = nil

ISRadioInteractions = {}

function ISRadioInteractions:getInstance()
    if instance ~= nil then return instance end

    local cooldowns = {}
    local self = {}
    local noHalo = {}
    local currentPlayer

    function self.split(str, sep)
        -- PATCH: guard against nil/non-string (Java null passes == nil but crashes on gsub)
        if not str or type(str) ~= "string" then return {} end
        local fields = {}
        local pattern = string.format("([^%s]+)", sep or ":")
        str:gsub(pattern, function(c) fields[#fields+1] = c end)
        return fields
    end

    function self.playerInRange(_player, _x, _y, _z)
        if math.floor(_player:getZ()) == math.floor(_z) then
            if _player:getX() >= _x-5 and _player:getX() <= _x+5 and _player:getY() >= _y-5 and _player:getY() <= _y+5 then
                return true
            end
        end
        return false
    end

    function self.checkPlayer(player, _guid, _interactCodes, _x, _y, _z, _line)
        local source = (not (_x==-1 and _y==-1 and _z==-1)) and getCell():getGridSquare(_x,_y,_z) or nil
        local plrsquare = player:getSquare()
        if source and source:isOutside() ~= plrsquare:isOutside() then return end
        if player:isAsleep() then return end
        if _guid ~= nil and _guid ~= "" then
            if player:isKnownMediaLine(_guid) then return end
            player:addKnownMediaLine(_guid)
        end

        -- PATCH: safe nil/Java-null check; tostring() coerces safely, "null" catches Java nulls
        if not _interactCodes or not _line then return end
        local codeStr = tostring(_interactCodes)
        if codeStr == "" or codeStr == "null" then return end

        currentPlayer = player
        local playerNum = player:getPlayerNum()+1
        local stats = player:getStats()
        local xp = player:getXp()

        if stats ~= nil and xp ~= nil then
            local codes = self.split(codeStr, ",")
            for _,_v in ipairs(codes) do
                if _v:len() > 4 then
                    local code = string.sub(_v, 1, 3)
                    local op = string.sub(_v, 4, 4)
                    local amount = code ~= "RCP" and tonumber(string.sub(_v, 5, _v:len())) or nil
                    if amount ~= nil and code ~= "RCP" then
                        amount = op == "-" and amount*-1 or amount
                        if Interactions[code] ~= nil then
                            if not cooldowns[playerNum] or not cooldowns[playerNum][code] or cooldowns[playerNum][code] <= 0 then
                                Interactions[code](player, amount, op == "=")
                                cooldowns[playerNum] = cooldowns[playerNum] or {}
                                cooldowns[playerNum][code] = 30
                            end
                        end
                    end
                    if code == "RCP" then
                        local recipe = string.sub(_v, 5, _v:len())
                        if recipe then
                            local learned = player:learnRecipe(recipe)
                            if learned then
                                local index = string.find(recipe, "%.")
                                if index then
                                    recipe = string.sub(recipe, index+1, recipe:len())
                                end
                                HaloTextHelper.addGoodText(player, getText("IGUI_HaloNote_LearnedRecipe", getRecipeDisplayName(tostring(recipe))))
                            end
                        end
                    end
                end
            end
            local moodles = player:getMoodles()
            if moodles ~= nil then moodles:Update() end
        end
    end

    function self.OnDeviceText(_guid, _interactCodes, _x, _y, _z, _line)
        for playerNum=1,4 do
            local player = getSpecificPlayer(playerNum-1)
            if player and player:isDead() then player = nil end
            if player ~= nil and ((_x==-1 and _y==-1 and _z==-1) or self.playerInRange(player, _x, _y, _z)) then
                self.checkPlayer(player, _guid, _interactCodes, _x, _y, _z, _line)
            end
        end
    end

    function self.OnTick()
        for playerNum=1,4 do
            local tbl = cooldowns[playerNum]
            if tbl then
                for code,value in pairs(tbl) do
                    if value > 0 then
                        tbl[code] = value - (1*getGameTime():getMultiplier())
                    end
                end
            end
        end
    end

    function self.addHalo(_str, _amount, _inverseCols)
        if noHalo[_str] or not currentPlayer then return end
        local color = HaloTextHelper.getGoodColor()
        local doArrow = 0
        if _amount and type(_amount) == "number" then
            if _amount < 0 then
                color = _inverseCols and HaloTextHelper.getBadColor() or HaloTextHelper.getGoodColor()
                doArrow = -1
            elseif _amount > 0 then
                color = _inverseCols and HaloTextHelper.getGoodColor() or HaloTextHelper.getBadColor()
                doArrow = 1
            end
        end
        if doArrow ~= 0 then
            HaloTextHelper.addTextWithArrow(currentPlayer, _str, "[br/]", doArrow==1 and true or false, color)
        else
            HaloTextHelper.addText(currentPlayer, _str, "[br/]", color)
        end
    end

    function self.setNoHalo(_type, _b)
        noHalo[_type] = _b
    end

    local function Init()
        Events.OnDeviceText.Add(self.OnDeviceText)
        Events.OnTick.Add(self.OnTick)
        instance = self
        return self
    end

    return Init()
end

Events.OnGameBoot.Add(function() ISRadioInteractions:getInstance() end)
