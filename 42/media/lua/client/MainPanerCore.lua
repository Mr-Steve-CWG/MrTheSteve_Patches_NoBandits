local currentBearing = 0
local lastBearing = 0
local goalBearing = 0
local locked = false
local TurretRotating = false
local RotatoTick = 10
local footspeed = {25, 25, true} -- {履带转速，数值}
local FlashTable = {}
local SquareTable = {}
local function CheckLight()
    for k, v in pairs(FlashTable) do
        if v.Light and not SquareTable[k] then
            getCell():removeLamppost(v.Light)
            FlashTable[k] = nil
        end
    end
    for k, v in pairs(SquareTable) do
        if not FlashTable[k] then
            FlashTable[k] = {
                SquareName = k,
                Light = nil
            }
            local newlight = IsoLightSource.new(v:getX(), v:getY(), 0, 0.8, 0.6, 0.8, 6)
            FlashTable[k].Light = newlight
            getCell():addLamppost(newlight)
        end
    end
end

Events.OnTick.Add(CheckLight)
local function playerDirection(a)
    if a <= 0 then
        return -a
    else
        return -a + 360
    end
end

local function pMod(a, b)
    if a % b >= 0 then
        return a % b
    else
        return a % b + b
    end
end
ISPanzerAimTime = 0
TurretBarrelOffset = 0
GunMuzzleSet = false
local function vehicleDirection(x, y, z)
    if Math.abs(x) >= 45 and Math.abs(x) >= 45 then
        return 90 - y
    else
        return 270 + y
    end
end

local NowRotato = 0

local function UpdatePanzerTrack(vehicle, PanzerType)
    local HangMax = PanzerList[PanzerType].TrackHangsNum
    local TrackSpeed = math.ceil(1 / (vehicle:getSpeed2D()) * 30)
    if TrackSpeed <= 1 then
        TrackSpeed = 2
    end
    if ISPanzerObjcetUpdate then
        TrackSpeed = 20
    end
    local name = (luautils.split(vehicle:getScriptName(), "."))[2]
    if TrackSpeed > 0 and (vehicle:getSpeed2D() > 0 or ISPanzerObjcetUpdate) then
        footspeed[1] = TrackSpeed
        if footspeed[2] > footspeed[1] then
            footspeed[2] = footspeed[1]
        end
        NowRotato = NowRotato + 10 / TrackSpeed
        if NowRotato >= 360 then
            NowRotato = 0
        end
        if footspeed[1] >= 100000 and footspeed[2] >= 100000 then
            footspeed[2] = 25
            footspeed[1] = 25
        end
        if footspeed[2] == footspeed[1] then
            for i = 1, HangMax do
                vehicle:getScript():Load(name,
                    "vehicle " .. name .. "{part " .. name .. "_Hang" .. i .. " {category = nodisplay,model " .. name ..
                        "_Hang" .. i .. "{file = " .. name .. "_Hang" .. i .. ",rotate = " .. tostring(NowRotato) ..
                        " 0 0,}lua{}}}")
            end
            footspeed[2] = footspeed[2] - 1
            local part = vehicle:getPartById(PanzerType .. "Track")
            if footspeed[3] then
                part:setModelVisible(PanzerType .. "Track1", true)
                part:setModelVisible(PanzerType .. "Track2", false)
                footspeed[3] = not footspeed[3]
            else
                part:setModelVisible(PanzerType .. "Track2", true)
                part:setModelVisible(PanzerType .. "Track1", false)
                footspeed[3] = not footspeed[3]
            end
        elseif footspeed[2] == 0 then
            footspeed[2] = footspeed[1]
        else
            footspeed[2] = footspeed[2] - 1
        end
    else

        for i = 1, HangMax do
            local HangPart = vehicle:getPartById(PanzerType .. "_Hang" .. i)
            if HangPart then
                if vehicle == getPlayer():getVehicle() then
                    HangPart:setModelVisible(PanzerType .. "_Hang" .. i, true)
                    HangPart:setModelVisible(PanzerType .. "_Hang" .. i .. "_Fake", false)
                else
                    HangPart:setModelVisible(PanzerType .. "_Hang" .. i, false)
                    HangPart:setModelVisible(PanzerType .. "_Hang" .. i .. "_Fake", true)
                end
            end
        end
        local part = vehicle:getPartById(PanzerType .. "Track")
        part:setModelVisible(PanzerType .. "Track1", true)
    end
end

local function rotateEnterAim(player, vehicle)
    local modData = player:getModData()
    if not vehicle then
        return
    end
    local type = GetPanzerType(vehicle)

    if type == "Wirbelwind" then
        if isMouseButtonDown(1) and vehicle:getSeat(player) == 2 then
            modData.WirbelwindVehicleId = vehicle:getId()
            player:setVehicle(nil)
        end
    end
    if vehicle ~= nil and vehicle:getSeat(player) == 0 then
        if isMouseButtonDown(1) then
            goalBearing = pMod(math.floor(360 - playerDirection(player:getDirectionAngle()) -
                                              (360 -
                                                  vehicleDirection(vehicle:getAngleX(), vehicle:getAngleY(),
                        vehicle:getAngleZ()) + 0.5)), 360)
            goalBearing = math.floor(goalBearing / 5) * 5
        else
            goalBearing = 0
        end
        -- print(goalBearing)
        if RotatoTick <= 0 then
            if type ~= "TigerII" then
                RotatoTick = getAverageFPS() / 90

            else
                RotatoTick = getAverageFPS() / 10
            end

        else
            RotatoTick = RotatoTick - 1
            return
        end
        if goalBearing > currentBearing then
            TurretRotating = true
            locked = false
            if goalBearing - currentBearing <= 180 then
                currentBearing = pMod(currentBearing + 1, 360)
            else
                currentBearing = pMod(currentBearing - 1, 360)
            end
            ISPanzerAimTime = ISPanzerAimTime + 1
            if ISPanzerAimTime >= 5 then
                ISPanzerAimTime = 5
            end
        elseif goalBearing < currentBearing then
            locked = false
            TurretRotating = true
            if currentBearing - goalBearing <= 180 then
                currentBearing = pMod(currentBearing - 1, 360)
            else
                currentBearing = pMod(currentBearing + 1, 360)
            end
            ISPanzerAimTime = ISPanzerAimTime + 1
            if ISPanzerAimTime >= 5 then
                ISPanzerAimTime = 5
            end
        else
            TurretRotating = false
            locked = true
        end
        local type = GetPanzerType(vehicle)
        local sound = PanzerList[type].TurretRotateSound
        if TurretRotating then
            modData.newBearingServer = currentBearing
            if not vehicle:getEmitter():isPlaying(sound) then
                vehicle:getEmitter():playSound(sound, true)
            end
        else
            if vehicle:getEmitter():isPlaying(sound) then
                vehicle:getEmitter():stopSoundByName(sound)
            end
        end
    end
    SquareTable = {}
    local modData = vehicle:getModData()
    if modData.enableGunLight then
        local CurrentSquare = vehicle:getSquare()
        local dirc = player:getForwardDirection():getDirection()
        local deltX = math.cos(dirc)
        local deltY = math.sin(dirc)
        local currentX = CurrentSquare:getX()
        local currentY = CurrentSquare:getY()
        local currentZ = CurrentSquare:getZ()
        local offsetX = 0
        local offsetY = 0
        local distanceTravelled = 0
        local maxDistance = 20
        local minDistance = 3
        while distanceTravelled < maxDistance do
            offsetX = offsetX + deltX * 1
            offsetY = offsetY + deltY * 1
            distanceTravelled = distanceTravelled + 1
            if distanceTravelled >= minDistance then
                local newSquare = getCell():getGridSquare(currentX + offsetX, currentY + offsetY, currentZ)
                if newSquare then
                    local StringName = currentX + offsetX .. "_" .. currentY + offsetY
                    SquareTable[StringName] = newSquare
                end
                if distanceTravelled >= maxDistance then

                    break
                end
            end
        end
    end
end

local function isInPanzerList(VehicleName)
    for k, v in pairs(PanzerList) do
        if string.find(VehicleName, k) then
            return true
        end
    end
end

local function localUpdatePanzerTurret(player)
    local allVehicles = getPlayer():getCell():getVehicles()
    local vehicle = player:getVehicle()
    for i = 0, allVehicles:size() - 1 do
        local vehicle = allVehicles:get(i)
        if (isInPanzerList(vehicle:getScriptName())) then
            local name = (luautils.split(vehicle:getScriptName(), "."))[2]
            local turret = vehicle:getPartById(name .. "_Turret")
            local Gun = vehicle:getPartById(name .. "_TurretGun")
            local TurretBarrel = vehicle:getPartById(name .. "_TurretBarrel")
            local GunLight = vehicle:getPartById(name .. "_GunLight")
            local PanzerType = GetPanzerType(vehicle)
            local HasTurretGun = true
            local HasTurretBarrel = true
            local HasGunLight = true
            if PanzerList[PanzerType].TrackAnims then
                UpdatePanzerTrack(vehicle, PanzerType)
            end
            if PanzerList[PanzerType].NoTurretGun then
                HasTurretGun = false
            end
            if PanzerList[PanzerType].NoTurretBarrel then
                HasTurretBarrel = false
            end
            if PanzerList[PanzerType].NoGunLight then
                HasGunLight = false
            end

            if vehicle == player:getVehicle() then
                local modDataVehicle = vehicle:getModData()
                local TargetBearing = 0
                TargetBearing = 360 - currentBearing
                if PanzerList[PanzerType].RenderGunMuzzle then
                    local GunMuzzle = vehicle:getPartById("GunMuzzle")
                    if GunMuzzle then
                        local modelScript = GunMuzzle:getScriptPart()
                        local model = modelScript:getModelById("GunMuzzle")
                        model:getRotate():set(0, TargetBearing, 0)
                        if not GunMuzzleSet then
                            GunMuzzle:setModelVisible("GunMuzzle", false)
                            GunMuzzle:setModelVisible("GunMuzzle_Fake", false)

                        else
                            GunMuzzle:setModelVisible("GunMuzzle", true)
                            GunMuzzle:setModelVisible("GunMuzzle_Fake", false)
                        end
                    end
                end

                if TargetBearing ~= lastBearing then
                    -- local Passenger = vehicle:getScript():getPassenger(0)
                    -- local postioin = Passenger:getPosition(0)

                    if HasTurretGun then
                        local modelScript = Gun:getScriptPart()
                        local model = modelScript:getModelById(name .. "_TurretGun")
                        model:getRotate():set(0, TargetBearing, 0)
                        Gun:setModelVisible(name .. "_TurretGun_Fake", false)
                        Gun:setModelVisible(name .. "_TurretGun", true)
                    end
                    if HasGunLight and HasUnlockThisReasearch(vehicle, "TurretLight") then
                        local modelScript = GunLight:getScriptPart()
                        local model = modelScript:getModelById(name .. "_GunLight")
                        model:getRotate():set(0, TargetBearing, 0)
                        GunLight:setModelVisible(name .. "_GunLight_Fake", false)
                        GunLight:setModelVisible(name .. "_GunLight", true)
                    end
                    if HasTurretBarrel then
                        if TurretBarrelOffset < 0 then
                            TurretBarrelOffset = TurretBarrelOffset + 0.005
                            if TurretBarrelOffset >= -0.8 then
                                GunMuzzleSet = false
                            end
                        end
                        -- print(TurretBarrelOffset)
                        if TurretBarrel then
                            local modelScript = TurretBarrel:getScriptPart()
                            local model = modelScript:getModelById(name .. "_TurretBarrel")
                            model:getRotate():set(0, TargetBearing, 0)
                            local offsetX = TurretBarrelOffset * math.sin(math.rad(TargetBearing))
                            local offsetY = TurretBarrelOffset * math.cos(math.rad(TargetBearing))
                            model:getOffset():set(offsetX, 0, offsetY)
                        end
                        TurretBarrel:setModelVisible(name .. "_TurretBarrel_Fake", false)
                        TurretBarrel:setModelVisible(name .. "_TurretBarrel", true)
                    end
                    local modelScript = turret:getScriptPart()
                    local model = modelScript:getModelById(name .. "_Turret")
                    model:getRotate():set(0, TargetBearing, 0)
                    turret:setModelVisible(name .. "_Turret_Fake", false)
                    turret:setModelVisible(name .. "_Turret", true)
                    if PanzerList[PanzerType].TurretPart then
                        for k, v in pairs(PanzerList[PanzerType].TurretPart) do
                            local NowPartName = name .. "_" .. v
                            local part = vehicle:getPartById(NowPartName)
                            if part then
                                local modelScript = part:getScriptPart()
                                local model = modelScript:getModelById(NowPartName)
                                model:getRotate():set(0, TargetBearing, 0)
                                part:setModelVisible(NowPartName .. "_Fake", false)
                                part:setModelVisible(NowPartName, true)
                            end
                        end
                    end
                    lastBearing = currentBearing
                end
            else
                if HasTurretGun then
                    Gun:setModelVisible(name .. "_TurretGun_Fake", true)
                    Gun:setModelVisible(name .. "_TurretGun", false)
                end
                if HasTurretBarrel then
                    TurretBarrel:setModelVisible(name .. "_TurretBarrel_Fake", true)
                    TurretBarrel:setModelVisible(name .. "_TurretBarrel", false)
                end
                turret:setModelVisible(name .. "_Turret_Fake", true)
                turret:setModelVisible(name .. "_Turret", false)
                if PanzerList[PanzerType].TurretPart then
                    for k, v in pairs(PanzerList[PanzerType].TurretPart) do
                        local NowPartName = name .. "_" .. v
                        local part = vehicle:getPartById(NowPartName)
                        if part then
                            part:setModelVisible(NowPartName .. "_Fake", true)
                            part:setModelVisible(NowPartName, false)
                        end
                    end
                end
            end
            if HasUnlockThisReasearch(vehicle, "MoreArmor") then
                local MoreArmor = vehicle:getPartById(name .. "_Armor")
                if MoreArmor then
                    MoreArmor:setModelVisible(name .. "_Armor", true)
                end
            end
            if PanzerList[PanzerType].Shove then
                if HasUnlockThisReasearch(vehicle, PanzerList[PanzerType].Shove) then
                    local Shovel = vehicle:getPartById(PanzerType .. "_Shovel")
                    if Shovel then
                        Shovel:setModelVisible(PanzerType .. "_Shovel", true)
                    end
                end
            end
            if HasUnlockThisReasearch(vehicle, "TurretLight") then
                local modelScript = GunLight:getScriptPart()
                GunLight:setModelVisible(name .. "_GunLight_Fake", false)
                GunLight:setModelVisible(name .. "_GunLight", true)
            end
        end
    end
end

local function LocalPanzerRun(player)
    local vehicle = player:getVehicle() or nil
    if (vehicle and isInPanzerList(vehicle:getScriptName())) then
        rotateEnterAim(player, vehicle)
    end
    localUpdatePanzerTurret(player)
    player:getModData().PanzerReadyToFire = locked
end

local start = false
local hasPanzerNearBy = false
local function BetterFPS()
    local cell = getPlayer():getCell()
    if not cell then return end
    local allVehicles = cell:getVehicles()
    for i = 0, allVehicles:size() - 1 do
        local vehicle = allVehicles:get(i)
        if (vehicle and GetPanzerType(vehicle)) then
            hasPanzerNearBy = true
            break
        end
        hasPanzerNearBy = false
    end
    if hasPanzerNearBy and not start then
        start = true
        Events.OnPlayerUpdate.Add(LocalPanzerRun)
    end
    if not hasPanzerNearBy and start then
        start = false
        Events.OnPlayerUpdate.Remove(LocalPanzerRun)
    end
end

Events.EveryOneMinute.Add(BetterFPS)
local Commands = {}
Commands.PanzerSendSendAll = {}
local onServerCommand = function(module, command, args)
    if Commands[module] and Commands[module][command] then
        Commands[module][command](args)
    end
end

Commands.PanzerSendSendAll.Update = function(args)
    local vehicle = getVehicleById(args.vehicleId)
    if vehicle then
        local modData = vehicle:getModData()
        local CrewLevelNow = args.CrewLevelNow
        local CrewPoint = args.CrewPoint
        local CrewLevel = args.CrewLevel
        local researchTable = args.researchTable
        local researchPoint = args.researchPoint
        local CrewKillNum = args.CrewKillNum

        modData.CrewLevelNow = CrewLevelNow
        modData.CrewPoint = CrewPoint
        modData.CrewLevel = CrewLevel
        modData.researchTable = researchTable
        modData.researchPoint = researchPoint
        modData.CrewKillNum = CrewKillNum
    end
end
