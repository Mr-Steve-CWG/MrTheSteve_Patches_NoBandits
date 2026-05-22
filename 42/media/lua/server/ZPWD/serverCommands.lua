---@diagnostic disable
-- MrTheSteve_Patches: Fix #2 — nil guard on square in addPhantom (getGridSquare returns nil for
--   unloaded squares; at vehicle speed the square may unload between client send and server receive)
-- Source: workshop 3684834906, ZombieProofDW/media/lua/server/ZPWD/serverCommands.lua

--0.00001985
local function reduceStress(player, args)
local playerStats = player:getStats()
local stressToRemove = args.soundStress * ZomboidGlobals.StressFromSoundsMultiplier
playerStats:set(CharacterStat.STRESS, playerStats:get(CharacterStat.STRESS) - stressToRemove)
end

local function addPhantom(player, args)
local phantomString = args.phantomString
local square = player:getCell():getGridSquare(args.x, args.y, args.z)
-- FIX #2: square is nil when the chunk has unloaded (common at vehicle speed)
if not square then return end

local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        
        if instanceof(obj, "IsoThumpable") and obj:getModData().isPhantomWindow then
           return end
        end

local invisTarget
invisTarget = IsoThumpable.new(square:getCell(), square, "", args.north, nil)
invisTarget:setIsThumpable(true)
invisTarget:setCanPassThrough(true)
invisTarget:setHealth(999999)
invisTarget:setMaxHealth(999999)
if phantomString == "door" then
-- ZombieThumpGeneric
invisTarget:setThumpSound("")
else invisTarget:setThumpSound("ZombieThumpWindow")
end
invisTarget:getModData().isPhantomWindow = phantomString
square:getObjects():add(invisTarget)
invisTarget:transmitCompleteItemToClients()
end

local functions =
{
    reduceStress = reduceStress,
    addPhantom = addPhantom,
}

Events.OnClientCommand.Add(function(module, command, player, args)
if module == "ZPWD" and functions[command] then functions[command](player, args) end
end)
