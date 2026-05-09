-- TrueMusicRadio_Patch.lua
-- Part of MrTheSteve_Patches
--
-- Patches: True Music Radio (Workshop: 3631572046)
-- Patched against: version 42.15 (file TMRadio.lua)
--
-- ISSUES FIXED (file-scope replacements):
--
--   1. [CRASH] TMRadio.prettyName: called from PlaySound (line 354) and
--      setInfoLines (lines 815, 861) with the result of
--      getItemNameFromFullType("Tsarcraft." .. songName). When a content
--      pack does not declare "module Tsarcraft" in its item scripts,
--      items register under Base instead and the lookup returns null.
--      prettyName then calls null:gsub() and throws "attempted index:
--      gsub of non-table: null". Guarding prettyName against nil stops
--      the crash in all three call sites.
--
--   2. [DISPLAY NAME] PlaySound and setInfoLines hardcode
--      "Tsarcraft." .. songName. Content packs that omit "module Tsarcraft"
--      register items under Base (e.g. True Moozic Mixtape Megapack,
--      Workshop: 3633882960), so display names resolve to nil for all
--      megapack tracks. TMRadio.getDisplayName tries Tsarcraft first,
--      then Base, then falls back to the raw songName string.
--      PlaySound is rewritten to use getDisplayName. The setInfoLines
--      closures are anonymous and not externally addressable; the
--      prettyName nil guard covers the crash there, and those paths
--      will display the raw songName (after prettyName gsub cleanup)
--      as a fallback for megapack tracks, which is acceptable.

TMRadio.getDisplayName = function(songName)
    if songName == nil then return "" end
    local name = getItemNameFromFullType("Tsarcraft." .. songName)
    if name == nil then
        name = getItemNameFromFullType("Base." .. songName)
    end
    if name == nil then
        name = songName
    end
    return name
end

local _prettyName_orig = TMRadio.prettyName
TMRadio.prettyName = function(displayName)
    if displayName == nil or type(displayName) ~= "string" then
        return ""
    end
    return _prettyName_orig(displayName)
end

-- Rewrite of TMRadio.PlaySound. Identical to the original except the
-- hardcoded "Tsarcraft." .. songName lookup is replaced with
-- TMRadio.getDisplayName(songName) so Base-module content packs resolve
-- correctly. All other logic (sound setup, playlist init, channel
-- tracking, soundCache, volume) is preserved verbatim.
-- PATCH: replaces TMRadio.PlaySound defined at TMRadio.lua:163
TMRadio.PlaySound = function(number, device)
    if not number or not device then
        return
    end

    local sound = nil
    local deviceData = device:getDeviceData()
    local t = TMRadio.getData(deviceData)

    if t then
        sound = t.sound
    else
        sound = TMRSound:new()
    end

    if deviceData:isInventoryDevice() then
        sound:set3D(false)
        sound:setVolumeModifier(0.6)
    elseif deviceData:isIsoDevice() then
        sound:setPosAtObject(device)
        sound:setVolumeModifier(0.4)
    elseif deviceData:isVehicleDevice() then
        local vehiclePart = deviceData:getParent()
        if vehiclePart then
            local vehicle = vehiclePart:getVehicle()
            if vehicle then
                sound:setEmitter(vehicle:getEmitter())
                if vehicle == getPlayer():getVehicle() then
                    sound:set3D(false)
                    sound:setVolumeModifier(0.8)
                elseif not TMRadio.VehicleWindowsIntact(vehicle) then
                    sound:set3D(true)
                    sound:setVolumeModifier(0.4)
                else
                    sound:set3D(true)
                    sound:setVolumeModifier(0.2)
                end
            end
        end
    end

    sound:setVolume(deviceData:getDeviceVolume())

    if isClient() then
        if TMRadioClient.PlaylistTerminalA ~= nil and #TMRadioClient.PlaylistTerminalA > 0 then
            TMRadio.PlaylistTerminalA = TMRadioClient.PlaylistTerminalA
        end
        if TMRadioClient.PlaylistTerminalB ~= nil and #TMRadioClient.PlaylistTerminalB > 0 then
            TMRadio.PlaylistTerminalB = TMRadioClient.PlaylistTerminalB
        end
        if TMRadioClient.PlaylistTerminalC ~= nil and #TMRadioClient.PlaylistTerminalC > 0 then
            TMRadio.PlaylistTerminalC = TMRadioClient.PlaylistTerminalC
        end
        if TMRadioClient.PlaylistTerminalD ~= nil and #TMRadioClient.PlaylistTerminalD > 0 then
            TMRadio.PlaylistTerminalD = TMRadioClient.PlaylistTerminalD
        end
        if TMRadioClient.PlaylistTerminalE ~= nil and #TMRadioClient.PlaylistTerminalE > 0 then
            TMRadio.PlaylistTerminalE = TMRadioClient.PlaylistTerminalE
        end
        if TMRadioClient.PlaylistTerminalMTV ~= nil and #TMRadioClient.PlaylistTerminalMTV > 0 then
            TMRadio.PlaylistTerminalMTV = TMRadioClient.PlaylistTerminalMTV
        end
        if TMRadioClient.Blacklist ~= nil and #TMRadioClient.Blacklist > 0 then
            TMRadio.Blacklist = TMRadioClient.Blacklist
        end
    end

    if TMRadio.PlaylistTerminalA == nil or #TMRadio.PlaylistTerminalA == 0 then
        TMRadio.PlaylistTerminalA = ModData.getOrCreate("TMRadioA")
    end
    if TMRadio.PlaylistTerminalB == nil or #TMRadio.PlaylistTerminalB == 0 then
        TMRadio.PlaylistTerminalB = ModData.getOrCreate("TMRadioB")
    end
    if TMRadio.PlaylistTerminalC == nil or #TMRadio.PlaylistTerminalC == 0 then
        TMRadio.PlaylistTerminalC = ModData.getOrCreate("TMRadioC")
    end
    if TMRadio.PlaylistTerminalD == nil or #TMRadio.PlaylistTerminalD == 0 then
        TMRadio.PlaylistTerminalD = ModData.getOrCreate("TMRadioD")
    end
    if TMRadio.PlaylistTerminalE == nil or #TMRadio.PlaylistTerminalE == 0 then
        TMRadio.PlaylistTerminalE = ModData.getOrCreate("TMRadioE")
    end
    if TMRadio.PlaylistTerminalMTV == nil or #TMRadio.PlaylistTerminalMTV == 0 then
        TMRadio.PlaylistTerminalMTV = ModData.getOrCreate("TMRadioMTV")
    end
    if TMRadio.Blacklist == nil or #TMRadio.Blacklist == 0 then
        TMRadio.Blacklist = ModData.getOrCreate("TMRadioBlacklist")
    end

    if TMRadio.PlaylistTerminalA == nil or #TMRadio.PlaylistTerminalA == 0 then
        TMRadio.PlaylistTerminalA = TMRadio.CreatePlaylist()
    end
    if TMRadio.PlaylistTerminalB == nil or #TMRadio.PlaylistTerminalB == 0 then
        TMRadio.PlaylistTerminalB = TMRadio.CreatePlaylist()
    end
    if TMRadio.PlaylistTerminalC == nil or #TMRadio.PlaylistTerminalC == 0 then
        TMRadio.PlaylistTerminalC = TMRadio.CreatePlaylist()
    end
    if TMRadio.PlaylistTerminalD == nil or #TMRadio.PlaylistTerminalD == 0 then
        TMRadio.PlaylistTerminalD = TMRadio.CreatePlaylist()
    end
    if TMRadio.PlaylistTerminalE == nil or #TMRadio.PlaylistTerminalE == 0 then
        TMRadio.PlaylistTerminalE = TMRadio.CreatePlaylist()
    end
    if TMRadio.PlaylistTerminalMTV == nil or #TMRadio.PlaylistTerminalMTV == 0 then
        TMRadio.PlaylistTerminalMTV = TMRadio.CreatePlaylist()
    end

    local songName = nil

    if deviceData:getChannel() == SandboxVars.TrueMusicRadio.TMRChannel1 then
        if #TMRadio.PlaylistTerminalA == 0 then
            print("TMRadio: Error processing requested song, playlist A empty")
            return
        else
            songName = TMRadio.PlaylistTerminalA[number]
        end
    elseif deviceData:getChannel() == SandboxVars.TrueMusicRadio.TMRChannel2 then
        if #TMRadio.PlaylistTerminalB == 0 then
            print("TMRadio: Error processing requested song, playlist B empty")
            return
        else
            songName = TMRadio.PlaylistTerminalB[number]
        end
    elseif deviceData:getChannel() == SandboxVars.TrueMusicRadio.TMRChannel3 then
        if #TMRadio.PlaylistTerminalC == 0 then
            print("TMRadio: Error processing requested song, playlist C empty")
            return
        else
            songName = TMRadio.PlaylistTerminalC[number]
        end
    elseif deviceData:getChannel() == SandboxVars.TrueMusicRadio.TMRChannel4 then
        if #TMRadio.PlaylistTerminalD == 0 then
            print("TMRadio: Error processing requested song, playlist D empty")
            return
        else
            songName = TMRadio.PlaylistTerminalD[number]
        end
    elseif deviceData:getChannel() == SandboxVars.TrueMusicRadio.TMRChannel5 then
        if #TMRadio.PlaylistTerminalE == 0 then
            print("TMRadio: Error processing requested song, playlist E empty")
            return
        else
            songName = TMRadio.PlaylistTerminalE[number]
        end
    elseif deviceData:getChannel() == SandboxVars.TrueMusicRadio.TMRMTV then
        if #TMRadio.PlaylistTerminalMTV == 0 then
            print("TMRadio: Error processing requested song, playlist MTV empty")
            return
        else
            songName = TMRadio.PlaylistTerminalMTV[number]
        end
    else
        return
    end

    TMRadio.Channels[deviceData:getChannel()] = number

    if songName == nil then
        print("TMRadio: Error processing requested song")
        return
    else
        -- PATCH: use getDisplayName instead of hardcoded "Tsarcraft." prefix
        -- so Base-module content packs (e.g. megapack) resolve correctly.
        local displayName = TMRadio.getDisplayName(songName)
        local prettyName = TMRadio.prettyName(displayName)
        if deviceData:getChannel() > 1000 then
            print("TMRadio Channel " .. deviceData:getChannel()/1000 .. "FM: Playing song[" .. number .. "] " .. prettyName)
        else
            print("TMRadio MTV " .. deviceData:getChannel() .. "TV: Playing song[" .. number .. "] " .. prettyName)
        end
        if PZAPI.ModOptions:getOptions("TrueMusicRadio"):getOption("TMRenableRDSDeviceText"):getValue() and SandboxVars.TrueMusicRadio.TMRRadioSongAnnouncements and not isClient() then
            DynamicRadio.OnNewSong(deviceData:getChannel(), prettyName)
        end
        if not PZAPI.ModOptions:getOptions("TrueMusicRadio"):getOption("TMRstopMusic"):getValue() then
            sound:play(songName)
        end
    end

    local position = TMRadio.whereAreYou(device)

    t = t or {}
    t.device = device
    t.deviceData = deviceData
    t.channel = deviceData:getChannel()
    t.sound = sound
    t.muted = false
    t.x = position.x
    t.y = position.y
    t.z = position.z

    tickCounter2 = 200

    if #TMRadio.soundCache > 0 then
        for index,x in ipairs(TMRadio.soundCache) do
            if x.device == device then
                table.remove(TMRadio.soundCache, index)
            end
        end
    end

    table.insert(TMRadio.soundCache, 1, t)
    if #TMRadio.soundCache > TMRadio.cacheSize then
        for i = TMRadio.cacheSize+1, #TMRadio.soundCache do
            table.remove(TMRadio.soundCache, i)
        end
    end

    print("TMRadio: Soundcache counter after new sound: [" .. #TMRadio.soundCache .. "/" .. TMRadio.cacheSize .. "]")

    return t
end
