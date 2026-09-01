if isClient() then return end

MoreCarFeatures = MoreCarFeatures or {}

local activatedMods = getActivatedMods()
local hasOpenVehiclePartsMod = activatedMods:contains("DG_MIVehicles")	--3162566044
local hasSemiTrailerMod = activatedMods:contains("rSemiTruck")	--3409472393

local excludedParts = {
	Engine = true,
	Heater = true,
	GloveBox = true,
	TruckBed = true,
	PassengerCompartment = true,
	SeatFrontLeft = true
}

local rearWindowCandidates = {
	"RearWindshield",
	"RearWindshield1",
	"RearWindshield2",
	"RearWindshield3",
	"WindshieldRear",
	"WindowTrunk",
	"WindowTrunkRear",
	"WindowRear",
	"WindowRearLeft",
	"WindowRearRight",
	"WindowBack",
	"RearWindow"
}

local function removeBrokenParts(vehicle, part)
	if not instanceof(part, "VehiclePart") then return end
	local item = part:getInventoryItem()
	part:setInventoryItem(nil)
	if item then
		item:setItemCapacity(part:getContainerContentAmount())
	end
	vehicle:transmitPartItem(part)
end

local function scheduleVehicleRemoval(vehicle)
	if not vehicle then return end
	local delay = 2
	local function delayProcessRemoval()
		delay = delay - 1
		if delay > 0 then return end
		if vehicle then
			vehicle:permanentlyRemove()
		end
		Events.OnTick.Remove(delayProcessRemoval)
	end
	Events.OnTick.Add(delayProcessRemoval)
end

local function specialExceptions(vehicleName)
	if string.contains(vehicleName, "trailer") or string.contains(vehicleName, "tow") or string.contains(vehicleName, "wrecker") then
		return true
	end
	return false
end

local vZoneToFlip
local function getVZoneToFlip()
	vZoneToFlip = getVehicleZoneAt(7716, 11883, 0)
end
Events.OnLoadedMapZones.Add(getVZoneToFlip)


local function GamestaOnSpawnVehicleEndActions(vehicle)
	if not vehicle then return end

	local SandboxFuelPumps = SandboxVars.GamestaVehicleZones.autoVehicleFuelPumps

	local chunk = vehicle:getChunk()
	if not chunk or not chunk:isNewChunk() then

		if SandboxFuelPumps then
			local vehicleMD = vehicle:getModData().statusFuelPumpNozzle or {}
			if #vehicleMD > 0 then		--update patching for handling multiple fuel holding vehicle parts, will probably remove this block in the next save breaking update
				vehicle:getModData().statusFuelPumpNozzle = {}
				for i = 0, vehicle:getPartCount() - 1 do
					local part = vehicle:getPartByIndex(i)
					if part:isContainer() and part:getContainerContentType() == "Gasoline" then	--old if check used for only the previously working parts
						vehicle:getModData().statusFuelPumpNozzle[part:getId()] = vehicleMD		--to attempt to re-add the old data safely
						break
					end
				end
			end

			for i = 0, vehicle:getPartCount() - 1 do
				local part = vehicle:getPartByIndex(i)
				if part:isContainer() and part:getContainerContentType() and part:getContainerContentType():contains("Gasoline") then
					local partID = part:getId()
					local VehiclePerPartMD = vehicleMD[partID] or {}
					if VehiclePerPartMD[1] and not VehiclePerPartMD[2] then
						local fuelStation = ISVehiclePartMenu.getNearbyFuelPump(vehicle, part)
						local vehicleID = vehicle:getId()
						if fuelStation then
							if isServer() then
								local args = { stationSquare = { VehiclePerPartMD[4][1], VehiclePerPartMD[4][2], vehicle:getZ() }, pumpSide = VehiclePerPartMD[3] }
								sendServerCommand("MoreCarFeatures", "FuelPumpTransmitSoundOff", args)
							end
							MoreCarFeatures.attachedFuelPump(vehicleID, fuelStation, partID)
						else	--Happens when the vehicle loads before the pump because they're in different chunks
							local unknownSquare = true
							local function monitorVehiclePerChunk(chunk)
								vehicle = getVehicleById(vehicleID)
								if vehicle then
									local sq = getCell():getGridSquare(VehiclePerPartMD[4][1], VehiclePerPartMD[4][2], vehicle:getZ())
									if sq then
										fuelStation = ISVehiclePartMenu.getNearbyFuelPump(vehicle, part)
										unknownSquare = false
									else
										unknownSquare = true
									end
								end
							end
							Events.LoadChunk.Add(monitorVehiclePerChunk)
							local function monitorVehiclePerTick()
								if fuelStation then
									if isServer() then	--No duplicate sounds backup, just in case ya know
										local args = { stationSquare = { VehiclePerPartMD[4][1], VehiclePerPartMD[4][2], vehicle:getZ() }, pumpSide = VehiclePerPartMD[3] }
										sendServerCommand("MoreCarFeatures", "FuelPumpTransmitSoundOff", args)
									end
									MoreCarFeatures.attachedFuelPump(vehicleID, fuelStation, partID)
								elseif vehicle then
									if (not vehicle:getController() or vehicle:isStopped()) and unknownSquare then return end
									vehicle:getModData().statusFuelPumpNozzle[partID] = { VehiclePerPartMD[1], true, VehiclePerPartMD[3], VehiclePerPartMD[4], false }
									vehicle:transmitModData()
									if fuelStation then
										local pumps = fuelStation:getModData().FuelPumpsInUseOrBroken or {}
										for i = #pumps, 1, -1 do
											if pumps[i][1] == VehiclePerPartMD[3] then
												fuelStation:getModData().FuelPumpsInUseOrBroken[i][2] = true
												fuelStation:transmitModData()
												break
											end
										end
									end
								end
								Events.LoadChunk.Remove(monitorVehiclePerChunk)
								Events.OnTick.Remove(monitorVehiclePerTick)
							end
							Events.OnTick.Add(monitorVehiclePerTick)
						end
					end
				end
			end
		end

		return
	end

	if vehicle:isGoodCar() and SandboxVars.GamestaVehicleZones.noGoodCars then
		scheduleVehicleRemoval(vehicle)
		return
	end

	local pos = vehicle:getSquare()
	local zone = getVehicleZoneAt(pos:getX(), pos:getY(), 0)

	if zone then
		local zoneName = string.lower(zone:getName())

		if zoneName == "junkyard" or zoneName:contains("trafficjam") or zoneName == "modified_trfjm" then

		-- Remove Good Vehicles From These Zones
			if vehicle:isGoodCar() and not specialExceptions(string.lower(vehicle:getScriptName())) then
				scheduleVehicleRemoval(vehicle)
				return

			elseif zoneName == "junkyard" then
			-- Junkyard Handler

				if not specialExceptions(string.lower(vehicle:getScriptName())) then
					if not (vehicle:isGoodCar() or vehicle:isBurnt()) then
						local battery = vehicle:getBattery()
						if not battery then return end
						local batteryInvItem = battery:getInventoryItem()
						if not batteryInvItem then return end
						batteryInvItem:setCurrentUsesFloat(0.0)
					end

					for i = vehicle:getPartCount() - 1, 0, -1 do
						local part = vehicle:getPartByIndex(i)
						if part and part:getCategory() ~= "nodisplay" then
							local partName = part:getId()
							if (part:getCondition() == 0 or part:getCondition() > 45) and not excludedParts[partName] then
								if string.sub(partName, 1, 4) == "Door" then
									local doorSide = string.sub(partName, 5)
									local windowPart = vehicle:getPartById("Window" .. doorSide)
									removeBrokenParts(vehicle, part)
									if windowPart then removeBrokenParts(vehicle, windowPart) end
								elseif partName == "TrunkDoor" or partName == "DoorRear" or string.find(partName, "Trunk") or string.find(partName, "Boot") then
									removeBrokenParts(vehicle, part)
									for _, rearId in ipairs(rearWindowCandidates) do
										local rearPart = vehicle:getPartById(rearId)
										if rearPart then removeBrokenParts(vehicle, rearPart) end
									end
								elseif string.sub(partName, 1, 10) == "Suspension" or string.sub(partName, 1, 5) == "Brake" then
									removeBrokenParts(vehicle, part)
									local side = nil
									if string.sub(partName, 1, 10) == "Suspension" then
										side = string.sub(partName, 11)
									else
										side = string.sub(partName, 6)
									end
									if side and side ~= "" then
										local tirePart = vehicle:getPartById("Tire" .. side)
										if tirePart then
											removeBrokenParts(vehicle, tirePart)
										end
									end
								else
									removeBrokenParts(vehicle, part)
								end
							end
						end
					end
				elseif not SandboxVars.GamestaVehicleZones.noGoodCars then		--exceptions made for some vehicles in junkyards
					vehicle:setGoodCar(true)
				end
			
			else
			--ALL TRAFFIC JAMS

				local rand = newrandom()

				local spawnRateMTJ = SandboxVars.GamestaVehicleZones.spawnRateModifiedTrafficJams
				if spawnRateMTJ ~= -1 and rand:random(1, 100) > spawnRateMTJ then
					scheduleVehicleRemoval(vehicle)
					return
				end

			-- Car Angles
				if rand:random(0, 10) ~= 0 then
					if zoneName == "modified_trfjm" then
						local randDirYNS = rand:random(-10, 10)
						local randDirYEW = randDirYNS + 90
						--Downtown
						if zone == getVehicleZoneAt(12599, 1274, 0) then vehicle:setAngles(180, randDirYNS, 180)
						elseif zone == getVehicleZoneAt(12593, 1274, 0) then vehicle:setAngles(0, randDirYNS, 0)
						elseif zone == getVehicleZoneAt(12506, 1241, 0) then vehicle:setAngles(180, randDirYNS, 180)
						elseif zone == getVehicleZoneAt(12501, 1241, 0) then vehicle:setAngles(0, randDirYNS, 0)
						--Southern Highway
						elseif zone == getVehicleZoneAt(12635, 3442, 0) then vehicle:setAngles(180, -randDirYEW, 180)
						elseif zone == getVehicleZoneAt(12635, 3452, 0) then vehicle:setAngles(0, randDirYEW, 0)
						elseif zone == getVehicleZoneAt(15303, 3322, 0) then vehicle:setAngles(180, -randDirYEW, 180)
						elseif zone == getVehicleZoneAt(15311, 3332, 0) then vehicle:setAngles(0, randDirYEW, 0)
						end
					else
						if zoneName == "trafficjamn" then
							vehicle:setAngles(180, (rand:random(-40, 40)), 180)
						elseif zoneName == "trafficjams" then
							vehicle:setAngles(0, (rand:random(-40, 40)), 0)
						elseif zoneName == "trafficjame" then
							vehicle:setAngles(0, (rand:random(50, 130)), 0)
						elseif zoneName == "trafficjamw" then
							vehicle:setAngles(0, -(rand:random(50, 130)), 0)
						end
					end
				end

			-- Doors/Windows Open Random
				if not hasOpenVehiclePartsMod and not vehicle:isBurntOrSmashed() then
					for i=0, vehicle:getPartCount() do
						local part = vehicle:getPartByIndex(i)
						if part and part:getInventoryItem() then		--Damaging, Removing, and Placing Parts
						--	local partItem = part:getInventoryItem()
						--	local partId = part:getId()
						--	local partArea = vehicle:getAreaCenter(part:getArea())
							local door = part:getDoor()
							local window = part:getWindow()
							if door then
								if not door:isLockBroken() and not door:isLocked() then
									local doOpen = false
									if part:getId() == "EngineDoor" then
										if rand:random(1, 10) == 1 and (vehicle:getBatteryCharge() < 0.1 or not vehicle:isEngineWorking()) then
											doOpen = true
										end
								--	elseif trunk?
									elseif rand:random(1, 10) <= 3 then
										doOpen = true
									end
									if doOpen then
										door:setOpen(true)
										vehicle:transmitPartItem(part)
									end
								end
							elseif window then
								if not window:isDestroyed() and window:isOpenable() and rand:random(1, 10) <= 2 then
									window:setOpen(true)
									vehicle:transmitPartItem(part)
								end
							end
						end
					end
				end

			end

	--Gas Stations
		elseif zoneName:contains("gasstation") then
			if SandboxFuelPumps then
				vehicle:getModData().statusFuelPumpNozzle = {}
				for i = 0, vehicle:getPartCount() - 1 do
					local part = vehicle:getPartByIndex(i)
					if part:isContainer() and part:getContainerContentType() and part:getContainerContentType():contains("Gasoline") then
						local partID = part:getId()
						local fuelStation = ISVehiclePartMenu.getNearbyFuelPump(vehicle, part)
						if fuelStation then
							local areaCenter = vehicle:getAreaCenter(part:getArea())
							local square = fuelStation:getSquare()
							local dir = fuelStation:getFacing()
							local pumpSide
							if dir == IsoDirections.E then
								if areaCenter:getX() < square:getX()+0.5 then
									pumpSide = "W"
								else
									pumpSide = "E"
								end
							elseif dir == IsoDirections.S then
								if areaCenter:getY() < square:getY()+0.5 then
									pumpSide = "N"
								else
									pumpSide = "S"
								end
							end
							fuelStation:getModData().FuelPumpsInUseOrBroken = fuelStation:getModData().FuelPumpsInUseOrBroken or {}
							table.insert(fuelStation:getModData().FuelPumpsInUseOrBroken, {pumpSide, false})
							fuelStation:transmitModData()
							vehicle:getModData().statusFuelPumpNozzle[partID] = { true, false, pumpSide, {math.floor(square:getX()), math.floor(square:getY())}, false }
							MoreCarFeatures.attachedFuelPump(vehicle:getId(), fuelStation, partID)
					--	else
					--		turn the vehicle, try again?
					--		vehicle:getModData().statusFuelPumpNozzle[partID] = { false, false, nil, {}, false }
						end
					end
				end
				vehicle:transmitModData()
			end

	-- Car Flipper (add new zone for B42.20 Stable, new prison looks cool)
		elseif zone == vZoneToFlip then		--(PRISON BUS, ROSEWOOD)
			vehicle:setDebugZ(.4)		--So it doesn't clip into the ground, raise it! 
			vehicle:setAngles(180, 120, -90)		--Flipped on right side facing SE into the guard room near the front entrance
		end

		-- Remove/Replace Oversized Vehicles Indoors (current work around is using custom zones, should use set script instead anyways)
	--	if zoneName == "firegarage" then
	--		if vehicle:getScriptName() == ("Base.90pierceArrow" or "Base.pzkFireTruckFlatLadder") then
	--			local vDir = vehicle:getForwardIsoDirection()
	--			scheduleVehicleRemoval(vehicle)
	--			if not SandboxVars.GamestaVehicleZones.noVanillaVehicles then
	--				local fireVehicles = {"Base.PickUpVanLightsFire", "Base.PickUpTruckLightsFire"}
	--				local fire = fireVehicles[ZombRand(1, #fireVehicles + 1)]
	--				if pos:getX() and pos:getY() then
	--					vehicle = addVehicle(fire, pos:getX(), pos:getY(), 0)
	--					if vehicle then
	--						if vDir == IsoDirections.N then vehicle:setAngles(0, 180, 0)
	--						elseif vDir == IsoDirections.S then vehicle:setAngles(0, 0, 0)
	--						elseif vDir == IsoDirections.E then vehicle:setAngles(0, 90, 0)
	--						elseif vDir == IsoDirections.W then vehicle:setAngles(0, -90, 0)
	--						end
	--					end
	--				end
	--			end
	--		end
	--	end

--	else is vehicle events?

	end

--	if vehicle:checkIfGoodVehicleForKey() and not vehicles:isBurntOrSmashed()
--		and not string.contains(string.lower(vehicles:getScriptName()), "trailer")
--		and vehicle:getSeats() > 0 and vehicle:isSeatInstalled(0)
--		and not (vehicle:getKeySpawned() or vehicle:isKeysInIgnition())
--	then
--		local seat = vehicle:getPartForSeatContainer(0)
--		if seat then
--			local cont = seat:getItemContainer()
--			if cont and cont:containsHumanCorpse() then	--cont:findHumanCorpseItem() returns the corpse as an InventoryItem
--				local item = vehicle:createVehicleKey()
--				if item then
--					cont:AddItem(item)
--					sendAddItemToContainer(cont, item)
--				end
--			end
--		end
--	end
end
Events.OnSpawnVehicleEnd.Add(GamestaOnSpawnVehicleEndActions)
--random note: wtf is a windowlight


local function loadGamestaNoVanillaVehicles()	--most of the removal of no vanilla vehicles is handled shared\VZonesAddon\RebalancedVehicleZoneDefinitions.lua (removing most vanilla vehicles from the spawn tablese entirely, events are the issues solved below)
	if SandboxVars.GamestaVehicleZones.noVanillaVehicles then
		--local vehicleScripts = getScriptManager():getAllVehicleScripts(); for i=0, vehicleScripts:size()-1 do print(i) print(vehicleScripts:get(i):getFullName()) end
		local VanillaVehicleScripts = {}
		local ReplacementVehicles = {}
		do
			VanillaVehicleScripts["Base.PickUpVanYingsWood"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.PickUpTruckLightsSmashedRight"] = { mechanicType = 2, zoneType = "carpenter" }
			VanillaVehicleScripts["Base.StepVan_LouisvilleSWAT"] = { mechanicType = 2, zoneType = "police" }
			VanillaVehicleScripts["Base.CarTaxi2"] = { mechanicType = 1, zoneType = "transit" }
			VanillaVehicleScripts["Base.PickUpTruckLightsFossoil"] = { mechanicType = 2, zoneType = "fossoil" }
			VanillaVehicleScripts["Base.VanKnoxCom"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.CarLuxurySmashedLeft"] = { mechanicType = 3, zoneType = "sport" }
			VanillaVehicleScripts["Base.ModernCar02SmashedRight"] = { mechanicType = 3, zoneType = "good" }
			VanillaVehicleScripts["Base.TrailerAdvert"] = { mechanicType = 0, zoneType = "advertising" }
			VanillaVehicleScripts["Base.PickUpVanSmashedFront"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.CarLightsSmashedFront"] = { mechanicType = 1, zoneType = "police" }
			VanillaVehicleScripts["Base.Van_Leather"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.SportsCar"] = { mechanicType = 3, zoneType = "sport" }
		--	VanillaVehicleScripts["Base.PickupBurnt"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.CarStationWagonSmashedRight"] = { mechanicType = 1, zoneType = "medium" }
			VanillaVehicleScripts["Base.OffRoadSmashedFront"] = { mechanicType = 1, zoneType = "good" }
			VanillaVehicleScripts["Base.VanSeats_Trippy"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.PickUpVanMccoy"] = { mechanicType = 2, zoneType = "mccoy" }
			VanillaVehicleScripts["Base.StepVan_Citr8"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.StepVan_CompleteRepairShop"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.VanMicheles"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.PickUpTruckLightsRanger"] = { mechanicType = 2, zoneType = "ranger" }
			VanillaVehicleScripts["Base.StepVanMailSmashedRear"] = { mechanicType = 2, zoneType = "postal" }
			VanillaVehicleScripts["Base.Van_Charlemange_Beer"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.TrailerCover"] = { mechanicType = 0, zoneType = "trailerpark" }
		--	VanillaVehicleScripts["Base.SmallCarBurnt"] = { mechanicType = 1, zoneType = "bad" }
			VanillaVehicleScripts["Base.SUV"] = { mechanicType = 1, zoneType = "good" }
			VanillaVehicleScripts["Base.StepVan_LouisvilleMotorShop"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.CarLightsBulletinSheriff"] = { mechanicType = 1, zoneType = "police" }
			VanillaVehicleScripts["Base.VanOldMill"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.ModernCar02SmashedRear"] = { mechanicType = 3, zoneType = "good" }
			VanillaVehicleScripts["Base.PickUpVanLightsSmashedFront"] = { mechanicType = 2, zoneType = "carpenter" }
			VanillaVehicleScripts["Base.VanMooreMechanics"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.ModernCarLightsCityLouisvillePD"] = { mechanicType = 3, zoneType = "police" }
			VanillaVehicleScripts["Base.Van_CraftSupplies"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.Van_Transit"] = { mechanicType = 2, zoneType = "transit" }
			VanillaVehicleScripts["Base.VanMail"] = { mechanicType = 2, zoneType = "postal" }
			VanillaVehicleScripts["Base.SUVSmashedLeft"] = { mechanicType = 1, zoneType = "good" }
			VanillaVehicleScripts["Base.ModernCarSmashedLeft"] = { mechanicType = 3, zoneType = "good" }
			VanillaVehicleScripts["Base.PickUpTruckLightsAirportSecurity"] = { mechanicType = 2, zoneType = "airportservice" }
			VanillaVehicleScripts["Base.VanMetalworker"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.StepVan_SmartKut"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.StepVanMailSmashedFront"] = { mechanicType = 2, zoneType = "postal" }
			VanillaVehicleScripts["Base.StepVan_HuangsLaundry"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.VanMeltingPointMetal"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.CarSmallSmashedFront"] = { mechanicType = 1, zoneType = "bad" }
			VanillaVehicleScripts["Base.PickUpTruckMccoy"] = { mechanicType = 2, zoneType = "mccoy" }
			VanillaVehicleScripts["Base.CarLuxurySmashedRight"] = { mechanicType = 3, zoneType = "sport" }
			VanillaVehicleScripts["Base.StepVan_Blacksmith"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.CarLightsKST"] = { mechanicType = 1, zoneType = "police" }
			VanillaVehicleScripts["Base.VanMetalheads"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.CarLightsLouisvilleCounty"] = { mechanicType = 1, zoneType = "police" }
			VanillaVehicleScripts["Base.StepVanSmashedFront"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.VanSeats_Mural"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.Van_VoltMojo"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.PickUpVanLightsStatePolice"] = { mechanicType = 2, zoneType = "police" }
			VanillaVehicleScripts["Base.VanPennSHam"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.StepVan_Butchers"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.PickUpVanLightsPolice"] = { mechanicType = 2, zoneType = "police" }
		--	VanillaVehicleScripts["Base.SportsCarBurnt"] = { mechanicType = 3, zoneType = "sport" }
			VanillaVehicleScripts["Base.Van_BugWipers"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.RaceCar58"] = { mechanicType = 3, zoneType = "racecar" }
			VanillaVehicleScripts["Base.StepVan_Glass"] = { mechanicType = 2, zoneType = nil }
		--	VanillaVehicleScripts["Base.ModernCar_Martin"] = { mechanicType = 3, zoneType = "good" }
			VanillaVehicleScripts["Base.CarNormalSmashedRight"] = { mechanicType = 1, zoneType = "medium" }
			VanillaVehicleScripts["Base.VanKorshunovs"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.ModernCar02SmashedLeft"] = { mechanicType = 3, zoneType = "good" }
			VanillaVehicleScripts["Base.VanJonesFabrication"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.PickUpTruckSmashedFront"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.Trailer"] = { mechanicType = 0, zoneType = "trailerpark" }
			VanillaVehicleScripts["Base.VanDeerValley"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.PickUpTruck"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.VanSeats_Space"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.CarLuxurySmashedRear"] = { mechanicType = 3, zoneType = "sport" }
			VanillaVehicleScripts["Base.CarLightsPolice"] = { mechanicType = 1, zoneType = "police" }
			VanillaVehicleScripts["Base.VanSeats"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.VanPluggedInElectrics"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.SmallCar02"] = { mechanicType = 1, zoneType = "bad" }
			VanillaVehicleScripts["Base.StepVan_MarineBites"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.StepVanMailSmashedRight"] = { mechanicType = 2, zoneType = "postal" }
			VanillaVehicleScripts["Base.PickUpVanLightsRanger"] = { mechanicType = 2, zoneType = "ranger" }
			VanillaVehicleScripts["Base.PickUpVanBuilder"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.Van_HeritageTailors"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.PickUpTruckLightsSmashedLeft"] = { mechanicType = 2, zoneType = "fire" }
			VanillaVehicleScripts["Base.StepVan_SouthEasternHosp"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.VanSeats_Creature"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.OffRoadSmashedRight"] = { mechanicType = 1, zoneType = "good" }
			VanillaVehicleScripts["Base.StepVan_Propane"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.CarStationWagonSmashedRear"] = { mechanicType = 1, zoneType = "medium" }
		--	VanillaVehicleScripts["Base.ModernCarBurnt"] = { mechanicType = 3, zoneType = "good" }
			VanillaVehicleScripts["Base.VanSchwabSheetMetal"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.VanUncloggers"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.StepVan_Florist"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.PickUpVanLightsLouisvilleCounty"] = { mechanicType = 2, zoneType = "police" }
			VanillaVehicleScripts["Base.CarStationWagon"] = { mechanicType = 1, zoneType = "medium" }
		--	VanillaVehicleScripts["Base.OffRoadBurnt"] = { mechanicType = 1, zoneType = "good" }
			VanillaVehicleScripts["Base.ModernCarSmashedRear"] = { mechanicType = 3, zoneType = "good" }
			VanillaVehicleScripts["Base.Van_KnoxDisti"] = { mechanicType = 2, zoneType = "knoxdisti" }
			VanillaVehicleScripts["Base.StepVan"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.PickUpVanWeldingbyCamille"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.PickUpVanMarchRidgeConstruction"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.StepVanAirportCatering"] = { mechanicType = 2, zoneType = "airportservice" }
			VanillaVehicleScripts["Base.StepVan_Zippee"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.StepVan_Genuine_Beer"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.ModernCarSmashedFront"] = { mechanicType = 3, zoneType = "good" }
			VanillaVehicleScripts["Base.ModernCar02SmashedFront"] = { mechanicType = 3, zoneType = "good" }
			VanillaVehicleScripts["Base.SmallCar"] = { mechanicType = 1, zoneType = "bad" }
		--	VanillaVehicleScripts["Base.PickUpVanBurnt"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.PickUpTruckSmashedLeft"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.PickUpVanKimbleKonstruction"] = { mechanicType = 2, zoneType = nil }
		--	VanillaVehicleScripts["Base.AmbulanceBurnt"] = { mechanicType = 2, zoneType = "ambulance" }
			VanillaVehicleScripts["Base.StepVanMail"] = { mechanicType = 2, zoneType = "postal" }
			VanillaVehicleScripts["Base.VanTreyBaines"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.CarLuxury"] = { mechanicType = 3, zoneType = "sport" }
			VanillaVehicleScripts["Base.CarLuxurySmashedFront"] = { mechanicType = 3, zoneType = "sport" }
			VanillaVehicleScripts["Base.StepVan_Heralds"] = { mechanicType = 2, zoneType = "kyheralds" }
			VanillaVehicleScripts["Base.StepVanSmashedRear"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.VanCarpenter"] = { mechanicType = 2, zoneType = "carpenter" }
			VanillaVehicleScripts["Base.Van"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.CarSmall02SmashedRear"] = { mechanicType = 1, zoneType = "bad" }
			VanillaVehicleScripts["Base.Van_Masonry"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.VanGardenGods"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.CarStationWagonSmashedLeft"] = { mechanicType = 1, zoneType = "medium" }
			VanillaVehicleScripts["Base.VanGreenes"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.PickUpVanSmashedLeft"] = { mechanicType = 2, zoneType = nil }
		--	VanillaVehicleScripts["Base.PickUpVanLightsBurnt"] = { mechanicType = 2, zoneType = "carpenter" }
			VanillaVehicleScripts["Base.StepVan_SouthEasternPaint"] = { mechanicType = 2, zoneType = nil }
		--	VanillaVehicleScripts["Base.VanRadioBurnt"] = { mechanicType = 2, zoneType = "radio" }
			VanillaVehicleScripts["Base.VanBeckmans"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.StepVan_MobileLibrary"] = { mechanicType = 2, zoneType = nil }
		--	VanillaVehicleScripts["Base.VanBurnt"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.PickUpTruckLightsSmashedRear"] = { mechanicType = 2, zoneType = "fire" }
			VanillaVehicleScripts["Base.VanCoastToCoast"] = { mechanicType = 2, zoneType = nil }
		--	VanillaVehicleScripts["Base.SportsCar_ez"] = { mechanicType = 3, zoneType = "sport" }
			VanillaVehicleScripts["Base.VanLouisvilleLandscaping"] = { mechanicType = 2, zoneType = "carpenter" }
			VanillaVehicleScripts["Base.PickUpTruckSmashedRight"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.VanOvoFarm"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.VanRiversideFabrication"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.VanGardener"] = { mechanicType = 2, zoneType = nil }
		--	VanillaVehicleScripts["Base.LuxuryCarBurnt"] = { mechanicType = 3, zoneType = "sport" }
			VanillaVehicleScripts["Base.StepVan_Jorgensen"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.PickUpTruckSmashedRear"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.VanPlattAuto"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.Trailer_Horsebox"] = { mechanicType = 0, zoneType = "farm" }
			VanillaVehicleScripts["Base.PickUpVanSmashedRight"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.SUVSmashedRight"] = { mechanicType = 1, zoneType = "good" }
			VanillaVehicleScripts["Base.PickUpVanLightsSmashedRight"] = { mechanicType = 2, zoneType = "fire" }
			VanillaVehicleScripts["Base.PickUpVanCallowayLandscaping"] = { mechanicType = 2, zoneType = "carpenter" }
			VanillaVehicleScripts["Base.VanMobileMechanics"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.CarStationWagonSmashedFront"] = { mechanicType = 1, zoneType = "medium" }
			VanillaVehicleScripts["Base.VanBuilder"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.VanUtility"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.StepVan_Plonkies"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.Van_Glass"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.PickUpTruckLightsSmashedFront"] = { mechanicType = 2, zoneType = "fire" }
			VanillaVehicleScripts["Base.Van_MassGenFac"] = { mechanicType = 2, zoneType = "massgenfac" }
			VanillaVehicleScripts["Base.Van_LectroMax"] = { mechanicType = 2, zoneType = "lectromax" }
			VanillaVehicleScripts["Base.StepVanSmashedLeft"] = { mechanicType = 2, zoneType = nil }
		--	VanillaVehicleScripts["Base.VanSeatsBurnt"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.CarNormalSmashedFront"] = { mechanicType = 1, zoneType = "medium" }
			VanillaVehicleScripts["Base.VanSpiffo"] = { mechanicType = 2, zoneType = "spiffo" }
		--	VanillaVehicleScripts["Base.TaxiBurnt"] = { mechanicType = 1, zoneType = "transit" }
			VanillaVehicleScripts["Base.CarLightsSmashedRight"] = { mechanicType = 1, zoneType = "police" }
			VanillaVehicleScripts["Base.CarSmall02SmashedLeft"] = { mechanicType = 1, zoneType = "bad" }
			VanillaVehicleScripts["Base.OffRoadSmashedRear"] = { mechanicType = 1, zoneType = "good" }
			VanillaVehicleScripts["Base.PickUpVanLightsSmashedLeft"] = { mechanicType = 2, zoneType = "fire" }
			VanillaVehicleScripts["Base.VanRadio_3N"] = { mechanicType = 2, zoneType = "network3" }
		--	VanillaVehicleScripts["Base.NormalCarBurntPolice"] = { mechanicType = 1, zoneType = "police" }
			VanillaVehicleScripts["Base.StepVan_Mechanic"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.PickUpVanHeltonMetalWorking"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.VanKnobCreekGas"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.PickUpVan_Camo"] = { mechanicType = 2, zoneType = "farm" }
			VanillaVehicleScripts["Base.VanFossoil"] = { mechanicType = 2, zoneType = "fossoil" }
		--	VanillaVehicleScripts["Base.CarNormalBurnt"] = { mechanicType = 1, zoneType = "medium" }
			VanillaVehicleScripts["Base.StepVan_Masonry"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.ModernCarSmashedRight"] = { mechanicType = 3, zoneType = "good" }
			VanillaVehicleScripts["Base.CarSmallSmashedRight"] = { mechanicType = 1, zoneType = "bad" }
			VanillaVehicleScripts["Base.CarSmallSmashedRear"] = { mechanicType = 1, zoneType = "bad" }
			VanillaVehicleScripts["Base.PickUpVanLightsSmashedRear"] = { mechanicType = 2, zoneType = "fire" }
			VanillaVehicleScripts["Base.VanSeatsAirportShuttle"] = { mechanicType = 2, zoneType = "airportshuttle" }
			VanillaVehicleScripts["Base.StepVanMailSmashedLeft"] = { mechanicType = 2, zoneType = "postal" }
			VanillaVehicleScripts["Base.VanRosewoodworking"] = { mechanicType = 2, zoneType = nil }
		--	VanillaVehicleScripts["Base.ModernCar02Burnt"] = { mechanicType = 3, zoneType = "good" }
			VanillaVehicleScripts["Base.Van_Perfick_Potato"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.CarNormal"] = { mechanicType = 1, zoneType = "medium" }
			VanillaVehicleScripts["Base.CarSmall02SmashedFront"] = { mechanicType = 1, zoneType = "bad" }
			VanillaVehicleScripts["Base.SUVSmashedFront"] = { mechanicType = 1, zoneType = "good" }
			VanillaVehicleScripts["Base.StepVan_Cereal"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.VanSeats_LadyDelighter"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.ModernCar02"] = { mechanicType = 3, zoneType = "good" }
			VanillaVehicleScripts["Base.PickUpVanMetalworker"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.CarNormalSmashedRear"] = { mechanicType = 1, zoneType = "medium" }
		--	VanillaVehicleScripts["Base.RaceCarBurnt"] = { mechanicType = 3, zoneType = "racecar" }
			VanillaVehicleScripts["Base.PickUpVanBrickingIt"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.VanSeats_Valkyrie"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.Van_Locksmith"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.ModernCarLightsWestPoint"] = { mechanicType = 3, zoneType = "police" }
			VanillaVehicleScripts["Base.PickUpVanSmashedRear"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.Trailer_Livestock"] = { mechanicType = 0, zoneType = "farm" }
			VanillaVehicleScripts["Base.CarStationWagon2"] = { mechanicType = 1, zoneType = "medium" }
			VanillaVehicleScripts["Base.PickUpTruckJPLandscaping"] = { mechanicType = 2, zoneType = "carpenter" }
			VanillaVehicleScripts["Base.CarLightsSmashedRear"] = { mechanicType = 1, zoneType = "police" }
			VanillaVehicleScripts["Base.VanKerrHomes"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.CarLightsRanger"] = { mechanicType = 1, zoneType = "ranger" }
			VanillaVehicleScripts["Base.RaceCar34"] = { mechanicType = 3, zoneType = "racecar" }
			VanillaVehicleScripts["Base.PickUpVanLightsFire"] = { mechanicType = 2, zoneType = "fire" }
		--	VanillaVehicleScripts["Base.SUVBurnt"] = { mechanicType = 1, zoneType = "good" }
			VanillaVehicleScripts["Base.PickUpTruck_Camo"] = { mechanicType = 2, zoneType = "farm" }
			VanillaVehicleScripts["Base.CarNormalSmashedLeft"] = { mechanicType = 1, zoneType = "medium" }
			VanillaVehicleScripts["Base.CarLightsSmashedLeft"] = { mechanicType = 1, zoneType = "police" }
			VanillaVehicleScripts["Base.OffRoadSmashedLeft"] = { mechanicType = 1, zoneType = "good" }
			VanillaVehicleScripts["Base.CarTaxi"] = { mechanicType = 1, zoneType = "transit" }
			VanillaVehicleScripts["Base.PickUpVanLightsKentuckyLumber"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.SUVSmashedRear"] = { mechanicType = 1, zoneType = "good" }
			VanillaVehicleScripts["Base.CarSmall02SmashedRight"] = { mechanicType = 1, zoneType = "bad" }
			VanillaVehicleScripts["Base.StepVan_USL"] = { mechanicType = 2, zoneType = "postal" }
			VanillaVehicleScripts["Base.PickUpTruckLightsFire"] = { mechanicType = 2, zoneType = "fire" }
			VanillaVehicleScripts["Base.PickUpVanLightsFossoil"] = { mechanicType = 2, zoneType = "fossoil" }
			VanillaVehicleScripts["Base.VanWPCarpentry"] = { mechanicType = 2, zoneType = "carpenter" }
			VanillaVehicleScripts["Base.VanMechanic"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.OffRoad"] = { mechanicType = 1, zoneType = "good" }
			VanillaVehicleScripts["Base.VanAmbulance"] = { mechanicType = 2, zoneType = "ambulance" }
			VanillaVehicleScripts["Base.PickUpVanLightsCarpenter"] = { mechanicType = 2, zoneType = "carpenter" }
			VanillaVehicleScripts["Base.ModernCarLightsMeadeSheriff"] = { mechanicType = 1, zoneType = "police" }
			VanillaVehicleScripts["Base.VanSeats_Prison"] = { mechanicType = 2, zoneType = "prison" }
			VanillaVehicleScripts["Base.Van_Blacksmith"] = { mechanicType = 2, zoneType = nil }
		--	VanillaVehicleScripts["Base.PickupSpecialBurnt"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.CarSmallSmashedLeft"] = { mechanicType = 1, zoneType = "bad" }
			VanillaVehicleScripts["Base.ModernCar"] = { mechanicType = 3, zoneType = "good" }
			VanillaVehicleScripts["Base.VanBrewsterHarbin"] = { mechanicType = 2, zoneType = nil }
		--	VanillaVehicleScripts["Base.SmallCar02Burnt"] = { mechanicType = 1, zoneType = "bad" }
			VanillaVehicleScripts["Base.PickUpTruckLightsAirport"] = { mechanicType = 2, zoneType = "airportservice" }
			VanillaVehicleScripts["Base.StepVanSmashedRight"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.VanMccoy"] = { mechanicType = 2, zoneType = "mccoy" }
			VanillaVehicleScripts["Base.PickUpVan"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.RaceCar12"] = { mechanicType = 3, zoneType = "racecar" }
			VanillaVehicleScripts["Base.CarLightsMuldraughPolice"] = { mechanicType = 1, zoneType = "police" }
			VanillaVehicleScripts["Base.StepVan_RandisPlants"] = { mechanicType = 2, zoneType = nil }
			VanillaVehicleScripts["Base.StepVan_Scarlet"] = { mechanicType = 2, zoneType = "scarlet" }
			VanillaVehicleScripts["Base.VanJohnMcCoy"] = { mechanicType = 2, zoneType = "mccoy" }
			VanillaVehicleScripts["Base.VanRadio"] = { mechanicType = 2, zoneType = "radio" }

		--	VanillaVehicleScripts["Base.VanRadioJJ"] = { mechanicType = 2, zoneType = nil }
			--maybe add others of choice?

			ReplacementVehicles["0"] = {}
			ReplacementVehicles["1"] = {}
			ReplacementVehicles["2"] = {}
			ReplacementVehicles["3"] = {}
			ReplacementVehicles.parkingstall = {}
			ReplacementVehicles.farm = {}
			ReplacementVehicles.trailerpark = {}
			ReplacementVehicles.bad = {}
			ReplacementVehicles.medium = {}
			ReplacementVehicles.good = {}
			ReplacementVehicles.sport = {}
			ReplacementVehicles.racecar = {}
			ReplacementVehicles.ranger = {}
			ReplacementVehicles.police = {}
			ReplacementVehicles.prison = {}
			ReplacementVehicles.fire = {}
			ReplacementVehicles.ambulance = {}
			ReplacementVehicles.mccoy = {}
			ReplacementVehicles.carpenter = {}
			ReplacementVehicles.postal = {}
			ReplacementVehicles.spiffo = {}
			ReplacementVehicles.fossoil = {}
			ReplacementVehicles.radio = {}
			ReplacementVehicles.network3 = {}
			ReplacementVehicles.kyheralds = {}
			ReplacementVehicles.scarlet = {}
			ReplacementVehicles.massgenfac = {}
			ReplacementVehicles.lectromax = {}
			ReplacementVehicles.knoxdisti = {}
			ReplacementVehicles.transit = {}
			ReplacementVehicles.airportshuttle = {}
			ReplacementVehicles.airportservice = {}
		end

		local function GamestaOnSpawnVehicleStartActions(vehicle)
			if not vehicle then return end
			local chunk = vehicle:getChunk()
			if not vehicle:isCreated() or (chunk and chunk:isNewChunk()) then
				local origVSName = vehicle:getScriptName()
				if not origVSName then return end
				local VVehicle = VanillaVehicleScripts[origVSName]
				if not VVehicle then return end

				local vzoneTable
				local VVMechanicType = string.format("%.0f", VVehicle.mechanicType)
				local VVZoneType = VVehicle.zoneType
			--	print(origVSName, ": ", VVMechanicType, " ", VVZoneType)

				if VVMechanicType == "0" then
					vzoneTable = ReplacementVehicles[VVMechanicType]
					if #vzoneTable > 0 then
					--	print("test replace 1")
						vehicle:setScriptName(vzoneTable[ZombRand(#vzoneTable)+1])
						vehicle:scriptReloaded(true)
					--	print(vehicle:getScriptName())
						return
					end
				end

				if VVZoneType then
					vzoneTable = ReplacementVehicles[VVZoneType]
					if #vzoneTable > 0 then
					--	print("test replace 2")
						vehicle:setScriptName(vzoneTable[ZombRand(#vzoneTable)+1])
						vehicle:scriptReloaded(true)
					--	print(vehicle:getScriptName())
						return
					end
				end

				vzoneTable = ReplacementVehicles[VVMechanicType]
				if #vzoneTable > 0 then
				--	print("test replace 3")
					vehicle:setScriptName(vzoneTable[ZombRand(#vzoneTable)+1])
					vehicle:scriptReloaded(true)
				--	print(vehicle:getScriptName())
					return
				end

				vzoneTable = ReplacementVehicles.parkingstall	--backup
				if #vzoneTable > 0 then
				--	print("test replace 4")
					vehicle:setScriptName(vzoneTable[ZombRand(#vzoneTable)+1])
					vehicle:scriptReloaded(true)
				--	print(vehicle:getScriptName())
					return
				end

				print("MCF Failure: Failed to Find Modded Vehicle to Replace ", origVSName)
			end
		end

		local function fillEventVehiclesTable()
			VehicleZoneDistribution.military = VehicleZoneDistribution.military or {}
			VehicleZoneDistribution.military.vehicles = VehicleZoneDistribution.military.vehicles or {}
			VehicleZoneDistribution.bigtrailerparkinglot = VehicleZoneDistribution.bigtrailerparkinglot or {}
			VehicleZoneDistribution.bigtrailerparkinglot.vehicles = VehicleZoneDistribution.bigtrailerparkinglot.vehicles or {}

			local vehicleScripts = getScriptManager():getAllVehicleScripts()
			for i=0, vehicleScripts:size()-1 do
				local vScript = vehicleScripts:get(i)
				local vsName = vScript:getFullName()
				if vsName and not VanillaVehicleScripts[vsName] then
					local mechanicType = string.format("%.0f", vScript:getMechanicType())
					local lowerName = string.lower(vsName)
					if string.contains(lowerName, "trailer") then
						if not (VehicleZoneDistribution.military.vehicles[vsName]
							or VehicleZoneDistribution.bigtrailerparkinglot.vehicles[vsName])
						then
							table.insert(ReplacementVehicles["0"], vsName)
						end
					elseif mechanicType and
						not (string.contains(lowerName, "burnt")
						or string.contains(lowerName, "airport")
						or string.contains(lowerName, "heli")
						or string.contains(lowerName, "plane")
						or string.contains(lowerName, "boat")
						or string.contains(lowerName, "ship")
						or string.contains(lowerName, "raft")) and
						not (VehicleZoneDistribution.military.vehicles[vsName]
						or VehicleZoneDistribution.racecar.vehicles[vsName]
						or VehicleZoneDistribution.ranger.vehicles[vsName]
						or VehicleZoneDistribution.police.vehicles[vsName]
						or VehicleZoneDistribution.prison.vehicles[vsName]
						or VehicleZoneDistribution.fire.vehicles[vsName]
						or VehicleZoneDistribution.ambulance.vehicles[vsName]
						or VehicleZoneDistribution.mccoy.vehicles[vsName]
						or VehicleZoneDistribution.carpenter.vehicles[vsName]
						or VehicleZoneDistribution.postal.vehicles[vsName]
						or VehicleZoneDistribution.spiffo.vehicles[vsName]
						or VehicleZoneDistribution.fossoil.vehicles[vsName]
						or VehicleZoneDistribution.radio.vehicles[vsName]
						or VehicleZoneDistribution.network3.vehicles[vsName]
						or VehicleZoneDistribution.kyheralds.vehicles[vsName]
						or VehicleZoneDistribution.scarlet.vehicles[vsName]
						or VehicleZoneDistribution.massgenfac.vehicles[vsName]
						or VehicleZoneDistribution.lectromax.vehicles[vsName]
						or VehicleZoneDistribution.knoxdisti.vehicles[vsName]
						or VehicleZoneDistribution.transit.vehicles[vsName])
					then
						if ReplacementVehicles[mechanicType] then
							table.insert(ReplacementVehicles[mechanicType], vsName)
						else
							print("MCF Warning: Vehicle script '" .. tostring(vsName) .. "' has unmapped mechanicType '" .. tostring(mechanicType) .. "' (MCF only defines zones for 0-3). Skipping it for zone replacement; report this vehicle script to its mod author.")
						end
					end
				end
			end

			for zoneName, zoneData in pairs(ReplacementVehicles) do
				if not (zoneName == "0" or zoneName == "1" or zoneName == "2" or zoneName == "3") then
					local zoneVehicles = VehicleZoneDistribution[zoneName].vehicles
					for vsName, vsData in pairs(zoneVehicles) do
						for x=1, vsData.spawnChance do
							table.insert(zoneData, vsName)
						end
					end
					if #zoneData == 0 then
						print("MCF Warning: No Modded Vehicles Found to Replace Vanilla Vehicles for Zone: ", zoneName)
					end
				end
			end

			if #ReplacementVehicles.parkingstall == 0 then
				print("MCF Warning: No Default Backup Vehicles Defined To Use in Replacement of Vanilla Vehicles if No Other Modded Vehicle is Found to Replace it Normally.")
			end

			Events.OnSpawnVehicleStart.Add(GamestaOnSpawnVehicleStartActions)
		end
		Events.OnLoadedMapZones.Add(fillEventVehiclesTable)
	end
end
Events.OnInitGlobalModData.Add(loadGamestaNoVanillaVehicles)
