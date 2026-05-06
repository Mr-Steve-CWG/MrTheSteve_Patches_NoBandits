--[[ JUKEBOX LIFESTYLES INTEGRATION DISABLED
pcall(function()
    require "RadioCom/ISTCBoomboxWindow"
end)

local TMJukeboxLSBridge = {
    originalDoBuildMenu = nil,
    wrappedDoBuildMenu = nil,
    originalISContextMenuAddOption = nil,
    wrappedISContextMenuAddOption = nil,
    originalISContextMenuAddOptionOnTop = nil,
    wrappedISContextMenuAddOptionOnTop = nil,
    originalOnPlay = nil,
    wrappedOnPlay = nil,
    originalOnTurnOnOff = nil,
    wrappedOnTurnOnOff = nil,
    originalDanceDoBuildMenu = nil,
    wrappedDanceDoBuildMenu = nil,
    originalDanceOnDancing = nil,
    wrappedDanceOnDancing = nil,
    originalDanceOnDancingPartner = nil,
    wrappedDanceOnDancingPartner = nil,
    lsObjectList = nil,
    lsListInitTried = false,
    blinkTimer = 0,
    blinkLastToggleMs = nil,
    blinkPhase = false,
    cleanupTick = 0,
    hostRegistry = {},
    blockDeviceOptionsFrames = 0,
    blockDeviceOptionsUntilMs = nil,
}

local TXT_PLAY_CASSETTE = "Play Cassette"
local TXT_PLAY_VINYL = "Play Vinyl"
local DEBUG = false
local stopProxyPlaybackForHost
local isPlayerNearActiveTMJukebox
local resolveLSJukeboxHost
local getLSObjectList
local getActiveTMPlaybackForHost
local isLSJukeboxObject
local removeDeviceOptionsOnJukebox
local isJukeboxContext
local getNowMs

local function hostKey(obj)
    if not (obj and obj.getX and obj.getY and obj.getZ) then return nil end
    return tostring(obj:getX()) .. ":" .. tostring(obj:getY()) .. ":" .. tostring(obj:getZ())
end

local function rememberLSHost(obj)
    if not (obj and isLSJukeboxObject and isLSJukeboxObject(obj)) then return end
    local key = hostKey(obj)
    if key then
        TMJukeboxLSBridge.hostRegistry[key] = obj
    end
end

local function getKnownLSHosts()
    local out = {}
    local seen = {}

    local list = getLSObjectList and getLSObjectList() or nil
    if type(list) == "table" then
        for i = 1, #list do
            local host = list[i]
            if host and host.getSquare and isLSJukeboxObject(host) then
                local key = hostKey(host)
                if key and not seen[key] then
                    seen[key] = true
                    out[#out + 1] = host
                    TMJukeboxLSBridge.hostRegistry[key] = host
                end
            end
        end
    end

    for key, host in pairs(TMJukeboxLSBridge.hostRegistry) do
        if host and host.getSquare and isLSJukeboxObject(host) then
            if not seen[key] then
                seen[key] = true
                out[#out + 1] = host
            end
        else
            TMJukeboxLSBridge.hostRegistry[key] = nil
        end
    end

    return out
end

local function isHostNowPlayingTM(host)
    if not (host and host.getX and host.getY and host.getZ) then return false end
    local trueMusicData = ModData.getOrCreate("trueMusicData")
    local nowPlay = trueMusicData and trueMusicData["now_play"] or nil
    if not nowPlay then return false end
    local key = "#" .. tostring(host:getX()) .. "-" .. tostring(host:getY()) .. "-" .. tostring(host:getZ())
    return nowPlay[key] ~= nil
end
local DANCE_STYLES = {
    "disco", "salsa", "rock", "metal", "electronic", "rap", "pop", "tm",
    "customPlaylist", "holiday", "muzak", "country", "classical", "world",
    "jazz", "beach", "reggae", "rbsoul",
}

local function randomDanceStyle()
    return DANCE_STYLES[ZombRand(#DANCE_STYLES) + 1]
end

local function dbg(msg)
    if DEBUG then
        print("[TMJukeLSBridge] " .. tostring(msg))
    end
end

local function isDeviceOptionName(name)
    local n = tostring(name or "")
    return n == tostring(getText("IGUI_DeviceOptions")) or n == "Device Options"
end

local function shouldBlockDeviceOptionNow(name)
    if not isDeviceOptionName(name) then return false end
    local now = getNowMs and getNowMs() or nil
    if TMJukeboxLSBridge.blockDeviceOptionsUntilMs and now then
        if now > TMJukeboxLSBridge.blockDeviceOptionsUntilMs then
            TMJukeboxLSBridge.blockDeviceOptionsUntilMs = nil
            TMJukeboxLSBridge.blockDeviceOptionsFrames = 0
            return false
        end
        return true
    end
    return (TMJukeboxLSBridge.blockDeviceOptionsFrames or 0) > 0
end

local function primePlayerDanceState(playerObj)
    if not playerObj then return end
    local md = playerObj:getModData()
    md.PlayingInstrument = false
    md.PlayingDJBooth = false
    md.IsListeningToJukebox = true
    if md.IsListeningToDJ == nil then md.IsListeningToDJ = false end
    md.IsDancingInit = true
    if not md.IsListeningToMusicStyle then
        md.IsListeningToMusicStyle = randomDanceStyle()
    end
end

local function getProxySpriteName(mode)
    if mode == "vinyl" then
        return (TCMusic and TCMusic.WorldMusicPlayer and TCMusic.WorldMusicPlayer["Tsarcraft.TCVinylplayer"]) or "TrueMoozic_music_01_36"
    end
    return (TCMusic and TCMusic.WorldMusicPlayer and TCMusic.WorldMusicPlayer["Tsarcraft.TCBoombox"]) or "TrueMoozic_music_01_35"
end

local function isProxyForHostMode(obj, hostObj, mode)
    if not (obj and obj.getModData and hostObj and hostObj.getX and hostObj.getY and hostObj.getZ) then
        return false
    end
    local md = obj:getModData()
    local tcm = md and md.tcmusic or nil
    if not (tcm and tcm.isJukeboxProxy and tcm.isJukebox) then
        return false
    end
    local wantMode = (mode == "vinyl") and "vinyl" or "cassette"
    local hx = tonumber(tcm.hostX)
    local hy = tonumber(tcm.hostY)
    local hz = tonumber(tcm.hostZ)
    return hx == tonumber(hostObj:getX()) and hy == tonumber(hostObj:getY()) and hz == tonumber(hostObj:getZ()) and tcm.jukeboxMode == wantMode
end

local function ensureTransientHostForJukebox(jukeboxObj, mode)
    if not jukeboxObj or not jukeboxObj.getSquare then return nil end
    local square = jukeboxObj:getSquare()
    if not square then return nil end
    if square.getObjects then
        local objects = square:getObjects()
        local keep = nil
        for i = 0, objects:size() - 1 do
            local candidate = objects:get(i)
            if isProxyForHostMode(candidate, jukeboxObj, mode) and candidate.getDeviceData and candidate:getDeviceData() then
                if not keep then
                    keep = candidate
                else
                    square:RemoveTileObject(candidate)
                end
            end
        end
        if keep then
            dbg("transient host reuse mode=" .. tostring(mode))
            return keep
        end
        -- Also clear legacy mode-less proxies for this host to reduce cross-mode contamination.
        for i = objects:size() - 1, 0, -1 do
            local candidate = objects:get(i)
            if candidate and candidate.getModData and candidate ~= keep then
                local md = candidate:getModData()
                local tcm = md and md.tcmusic or nil
                if tcm and tcm.isJukeboxProxy and tcm.hostX == jukeboxObj:getX() and tcm.hostY == jukeboxObj:getY() and tcm.hostZ == jukeboxObj:getZ() and not tcm.jukeboxMode then
                    square:RemoveTileObject(candidate)
                end
            end
        end
    end
    local spriteName = getProxySpriteName(mode)
    local sprite = getSprite(spriteName)
    if not sprite then
        dbg("transient host create failed: missing sprite " .. tostring(spriteName))
        return nil
    end
    local radio = IsoRadio.new(getCell(), square, sprite)
    if not radio then
        dbg("transient host create failed: IsoRadio.new returned nil")
        return nil
    end
    square:AddTileObject(radio)
    local md = radio:getModData()
    md.tcmusic = md.tcmusic or {}
    local canonicalRadioItemID = "J:" .. tostring(jukeboxObj:getX()) .. "-" .. tostring(jukeboxObj:getY()) .. "-" .. tostring(jukeboxObj:getZ())
    md.RadioItemID = canonicalRadioItemID
    md.tcmusic.deviceType = "IsoObject"
    md.tcmusic.isJukebox = true
    md.tcmusic.isJukeboxProxy = true
    md.tcmusic.radioItemID = canonicalRadioItemID
    md.tcmusic.hostX = jukeboxObj:getX()
    md.tcmusic.hostY = jukeboxObj:getY()
    md.tcmusic.hostZ = jukeboxObj:getZ()
    md.tcmusic.jukeboxMode = mode == "vinyl" and "vinyl" or "cassette"
    md.tcmusic.jukeboxMedia = md.tcmusic.jukeboxMedia or {}
    md.tcmusic.mediaItem = md.tcmusic.jukeboxMedia[md.tcmusic.jukeboxMode]
    local dd = radio:getDeviceData()
    if dd then
        if dd.setIsTurnedOn then dd:setIsTurnedOn(false) end
        if dd.setPower and (not dd.getPower or dd:getPower() <= 0) then dd:setPower(1) end
        if dd.setDeviceVolume and (not dd.getDeviceVolume or dd:getDeviceVolume() <= 0) then dd:setDeviceVolume(1) end
        if dd.setMediaType then dd:setMediaType(mode == "vinyl" and 1 or 0) end
    end
    if isClient() and radio.transmitCompleteItemToServer then
        radio:transmitCompleteItemToServer()
    elseif radio.transmitModData then
        radio:transmitModData()
    end
    dbg("transient host created sprite=" .. tostring(spriteName))
    return radio
end

local function ensureJukeboxMode(jukeboxObj, mode)
    if not jukeboxObj or not jukeboxObj.getModData then
        dbg("ensureJukeboxMode: invalid jukebox object")
        return false
    end
    local md = jukeboxObj:getModData()
    md.tcmusic = md.tcmusic or {}
    local canonicalRadioItemID = "J:" .. tostring(jukeboxObj:getX()) .. "-" .. tostring(jukeboxObj:getY()) .. "-" .. tostring(jukeboxObj:getZ())
    md.RadioItemID = canonicalRadioItemID
    md.tcmusic.deviceType = "IsoObject"
    md.tcmusic.isJukebox = true
    md.tcmusic.radioItemID = canonicalRadioItemID
    md.tcmusic.jukeboxMode = mode == "vinyl" and "vinyl" or "cassette"
    md.tcmusic.jukeboxMedia = md.tcmusic.jukeboxMedia or {}

    local dd = jukeboxObj.getDeviceData and jukeboxObj:getDeviceData() or nil
    if dd and dd.setMediaType then
        dd:setMediaType(md.tcmusic.jukeboxMode == "vinyl" and 1 or 0)
    end

    if jukeboxObj.transmitModData then
        jukeboxObj:transmitModData()
    end
    return true
end

local function openJukeboxMode(playerObj, jukeboxObj, mode)
    if not playerObj or not jukeboxObj then return end
    rememberLSHost(jukeboxObj)
    local hostAnchor = jukeboxObj
    dbg("open mode=" .. tostring(mode) .. " obj=" .. tostring(hostAnchor))
    local resolved = (resolveLSJukeboxHost and (resolveLSJukeboxHost(hostAnchor, mode) or hostAnchor)) or hostAnchor
    -- Do not bind jukebox UI to unrelated nearby radios; keep host anchored to clicked jukebox square.
    if resolved and hostAnchor and resolved.getX and resolved.getY and resolved.getZ and hostAnchor.getX and hostAnchor.getY and hostAnchor.getZ then
        local sameSquare = (resolved:getX() == hostAnchor:getX() and resolved:getY() == hostAnchor:getY() and resolved:getZ() == hostAnchor:getZ())
        if (not sameSquare) and (not isProxyForHostMode(resolved, hostAnchor, mode)) then
            dbg("resolved host rejected (different square); forcing anchor/proxy")
            resolved = hostAnchor
        end
    end
    dbg("resolved host=" .. tostring(resolved))
    local useProxy = not isProxyForHostMode(resolved, hostAnchor, mode)
    if useProxy then
        local proxy = ensureTransientHostForJukebox(hostAnchor, mode)
        if proxy then
            resolved = proxy
            dbg("resolved host switched to mode-proxy=" .. tostring(resolved))
        end
    elseif not (resolved and resolved.getDeviceData and resolved:getDeviceData()) then
        resolved = ensureTransientHostForJukebox(hostAnchor, mode) or resolved
        dbg("resolved host after transient create=" .. tostring(resolved))
    end
    jukeboxObj = resolved
    if not ensureJukeboxMode(jukeboxObj, mode) then return end
    if not (jukeboxObj and jukeboxObj.getDeviceData and jukeboxObj:getDeviceData()) then
        dbg("open aborted: host has no deviceData")
        return
    end
    dbg("activate window on host")
    if ISTCBoomboxWindow and ISTCBoomboxWindow.activate then
        ISTCBoomboxWindow.activate(playerObj, jukeboxObj)
    end
end

local function getPlayerFromArg(playerArg)
    if instanceof(playerArg, "IsoPlayer") then
        return playerArg
    end
    if type(playerArg) == "number" then
        return getSpecificPlayer(playerArg)
    end
    return getPlayer()
end

local function removeOptionByName(menu, name)
    if not menu or not menu.options then return end
    for i = #menu.options, 1, -1 do
        local opt = menu.options[i]
        if opt and opt.name == name then
            if menu.removeOption then
                menu:removeOption(opt)
            else
                table.remove(menu.options, i)
            end
        end
    end
end

local function resolveSubMenuRef(context, subRef)
    if not subRef then return nil end
    if type(subRef) == "table" then return subRef end
    if type(subRef) ~= "number" then return nil end
    if context and context.instanceMap and context.instanceMap[subRef] then
        return context.instanceMap[subRef]
    end
    if context and context.subOption and context.subOption[subRef] then
        return context.subOption[subRef]
    end
    if context and context.subMenu and context.subMenu[subRef] then
        return context.subMenu[subRef]
    end
    if context and context.subMenus and context.subMenus[subRef] then
        return context.subMenus[subRef]
    end
    return nil
end

local function addOptionCompat(menu, name, target, onSelect, p1, p2)
    if not menu then return nil end
    if menu.addOption then
        return menu:addOption(name, target, onSelect, p1, p2)
    end
    if menu.options then
        local opt = {
            name = name,
            target = target,
            onSelect = onSelect,
            param1 = p1,
            param2 = p2,
        }
        table.insert(menu.options, opt)
        return opt
    end
    return nil
end

local function findJukeboxSubMenu(context)
    if not context or not context.options then return nil end
    local turnOn = getText("ContextMenu_Jukebox_TurnOn")
    local turnOff = getText("ContextMenu_Jukebox_TurnOff")
    local oldies = "oldies jukebox"

    for _, rootOpt in ipairs(context.options) do
        local sub = resolveSubMenuRef(context, rootOpt and rootOpt.subOption or nil)
        local rootName = rootOpt and rootOpt.name and string.lower(tostring(rootOpt.name)) or ""
        if sub and string.find(rootName, oldies, 1, true) then
            dbg("submenu found by oldies name: " .. tostring(rootOpt and rootOpt.name))
            return sub
        end
        if sub and sub.options then
            for _, subOpt in ipairs(sub.options) do
                local n = subOpt and subOpt.name or nil
                if n == turnOn or n == turnOff then
                    dbg("submenu found by turn option: " .. tostring(n))
                    return sub
                end
            end
        end
    end

    dbg("submenu not found")
    return nil
end

local function injectOptions(context, worldobjects, playerObj, jukeboxObj)
    local sub = findJukeboxSubMenu(context)
    if not sub then return end

    removeOptionByName(sub, TXT_PLAY_CASSETTE)
    removeOptionByName(sub, TXT_PLAY_VINYL)

    local cassette = addOptionCompat(sub, TXT_PLAY_CASSETTE, worldobjects, function(_, pl, jb)
        openJukeboxMode(pl, jb, "cassette")
    end, playerObj, jukeboxObj)
    local vinyl = addOptionCompat(sub, TXT_PLAY_VINYL, worldobjects, function(_, pl, jb)
        openJukeboxMode(pl, jb, "vinyl")
    end, playerObj, jukeboxObj)

    local tapeIcon = getTexture("Item_TCTape4") or getTexture("media/textures/Item_TCTape4.png")
    local vinylIcon = getTexture("Item_TCVinylrecord3") or getTexture("media/textures/Item_TCVinylrecord3.png")
    if cassette then cassette.iconTexture = tapeIcon end
    if vinyl then vinyl.iconTexture = vinylIcon end
    dbg("injected options: cassette=" .. tostring(cassette ~= nil) .. " vinyl=" .. tostring(vinyl ~= nil))

end

local function install()
    if not JukeboxMenu or type(JukeboxMenu.doBuildMenu) ~= "function" then
        dbg("install skipped: JukeboxMenu.doBuildMenu unavailable")
        return
    end

    if TMJukeboxLSBridge.wrappedDoBuildMenu and JukeboxMenu.doBuildMenu == TMJukeboxLSBridge.wrappedDoBuildMenu then
        return
    end

    -- Re-wrap whenever Lifestyle reassigns doBuildMenu (load-order safe).
    TMJukeboxLSBridge.originalDoBuildMenu = JukeboxMenu.doBuildMenu
    TMJukeboxLSBridge.wrappedDoBuildMenu = function(player, context, worldobjects, jukeboxObj, spriteName, customName, groupName, debugBuildOption)
        dbg("doBuildMenu hook fired")
        TMJukeboxLSBridge.originalDoBuildMenu(player, context, worldobjects, jukeboxObj, spriteName, customName, groupName, debugBuildOption)
        local playerObj = getPlayerFromArg(player)
        if not playerObj then return end
        if removeDeviceOptionsOnJukebox then
            removeDeviceOptionsOnJukebox(player, context, worldobjects, false)
        end
        injectOptions(context, worldobjects, playerObj, jukeboxObj)
    end

    JukeboxMenu.doBuildMenu = TMJukeboxLSBridge.wrappedDoBuildMenu
    dbg("wrapped JukeboxMenu.doBuildMenu")

    if not TMJukeboxLSBridge.wrappedOnPlay and type(JukeboxMenu.onPlay) == "function" then
        TMJukeboxLSBridge.originalOnPlay = JukeboxMenu.onPlay
        TMJukeboxLSBridge.wrappedOnPlay = function(worldobjects, player, jukebox, ...)
            if jukebox then
                stopProxyPlaybackForHost(jukebox)
            end
            return TMJukeboxLSBridge.originalOnPlay(worldobjects, player, jukebox, ...)
        end
        JukeboxMenu.onPlay = TMJukeboxLSBridge.wrappedOnPlay
    end

    if not TMJukeboxLSBridge.wrappedOnTurnOnOff and type(JukeboxMenu.onTurnOnOff) == "function" then
        TMJukeboxLSBridge.originalOnTurnOnOff = JukeboxMenu.onTurnOnOff
        TMJukeboxLSBridge.wrappedOnTurnOnOff = function(worldobjects, player, jukebox, clickSound, turnSound, state)
            if jukebox and state == "Off" then
                stopProxyPlaybackForHost(jukebox)
            end
            return TMJukeboxLSBridge.originalOnTurnOnOff(worldobjects, player, jukebox, clickSound, turnSound, state)
        end
        JukeboxMenu.onTurnOnOff = TMJukeboxLSBridge.wrappedOnTurnOnOff
    end

    if LSDanceContextMenu and type(LSDanceContextMenu.doBuildMenu) == "function" then
        if (not TMJukeboxLSBridge.wrappedDanceDoBuildMenu) or LSDanceContextMenu.doBuildMenu ~= TMJukeboxLSBridge.wrappedDanceDoBuildMenu then
            TMJukeboxLSBridge.originalDanceDoBuildMenu = LSDanceContextMenu.doBuildMenu
            TMJukeboxLSBridge.wrappedDanceDoBuildMenu = function(player, context, worldobjects, DebugBuildOption)
                local playerObj = getPlayerFromArg(player)
                if playerObj and isPlayerNearActiveTMJukebox(playerObj) then
                    local md = playerObj:getModData()
                    local prev = {
                        PlayingInstrument = md.PlayingInstrument,
                        PlayingDJBooth = md.PlayingDJBooth,
                        IsListeningToJukebox = md.IsListeningToJukebox,
                        IsListeningToDJ = md.IsListeningToDJ,
                        IsDancingInit = md.IsDancingInit,
                        IsListeningToMusicStyle = md.IsListeningToMusicStyle,
                    }

                    md.PlayingInstrument = false
                    md.PlayingDJBooth = false
                    md.IsListeningToJukebox = true
                    if md.IsListeningToDJ == nil then md.IsListeningToDJ = false end
                    md.IsDancingInit = true
                    if not md.IsListeningToMusicStyle then
                        md.IsListeningToMusicStyle = randomDanceStyle()
                    end

                    local ok, err = pcall(TMJukeboxLSBridge.originalDanceDoBuildMenu, player, context, worldobjects, DebugBuildOption)

                    md.PlayingInstrument = prev.PlayingInstrument
                    md.PlayingDJBooth = prev.PlayingDJBooth
                    md.IsListeningToJukebox = prev.IsListeningToJukebox
                    md.IsListeningToDJ = prev.IsListeningToDJ
                    md.IsDancingInit = prev.IsDancingInit
                    md.IsListeningToMusicStyle = prev.IsListeningToMusicStyle

                    if not ok then error(err) end
                    return
                end

                return TMJukeboxLSBridge.originalDanceDoBuildMenu(player, context, worldobjects, DebugBuildOption)
            end

            LSDanceContextMenu.doBuildMenu = TMJukeboxLSBridge.wrappedDanceDoBuildMenu
        end
    end

    if LSDanceContextMenu and type(LSDanceContextMenu.onDancing) == "function" then
        if (not TMJukeboxLSBridge.wrappedDanceOnDancing) or LSDanceContextMenu.onDancing ~= TMJukeboxLSBridge.wrappedDanceOnDancing then
            TMJukeboxLSBridge.originalDanceOnDancing = LSDanceContextMenu.onDancing
            TMJukeboxLSBridge.wrappedDanceOnDancing = function(worldobjects, playerObj, ...)
                if playerObj and isPlayerNearActiveTMJukebox(playerObj) then
                    primePlayerDanceState(playerObj)
                end
                return TMJukeboxLSBridge.originalDanceOnDancing(worldobjects, playerObj, ...)
            end
            LSDanceContextMenu.onDancing = TMJukeboxLSBridge.wrappedDanceOnDancing
        end
    end

    if LSDanceContextMenu and type(LSDanceContextMenu.onDancingPartner) == "function" then
        if (not TMJukeboxLSBridge.wrappedDanceOnDancingPartner) or LSDanceContextMenu.onDancingPartner ~= TMJukeboxLSBridge.wrappedDanceOnDancingPartner then
            TMJukeboxLSBridge.originalDanceOnDancingPartner = LSDanceContextMenu.onDancingPartner
            TMJukeboxLSBridge.wrappedDanceOnDancingPartner = function(worldobjects, playerObj, ...)
                if playerObj and isPlayerNearActiveTMJukebox(playerObj) then
                    primePlayerDanceState(playerObj)
                end
                return TMJukeboxLSBridge.originalDanceOnDancingPartner(worldobjects, playerObj, ...)
            end
            LSDanceContextMenu.onDancingPartner = TMJukeboxLSBridge.wrappedDanceOnDancingPartner
        end
    end
end

isLSJukeboxObject = function(obj)
    if not obj or not obj.getSprite then return false end
    local spr = obj:getSprite()
    local props = spr and spr.getProperties and spr:getProperties() or nil
    return props and props.has and props:has("CustomName") and props:get("CustomName") == "Jukebox"
end

resolveLSJukeboxHost = function(obj, mode)
    if not obj then return nil end
    if isLSJukeboxObject(obj) and obj.getDeviceData and obj:getDeviceData() then
        dbg("resolve host: object itself is LS jukebox host")
        return obj
    end
    if obj.getDeviceData and obj:getDeviceData() then
        dbg("resolve host: object itself has deviceData")
        return obj
    end
    local wantMediaType = (mode == "vinyl") and 1 or 0
    local function scanSquareForHost(square, label)
        if not square or not square.getObjects then return nil end
        local objects = square:getObjects()
        local modeMatched = nil
        local tagMatched = nil
        local anyMatched = nil
        if DEBUG then
            for i = 0, objects:size() - 1 do
                local candidate = objects:get(i)
                local spr = candidate and candidate.getSprite and candidate:getSprite()
                local sprName = spr and spr.getName and spr:getName() or "nil"
                local hasDD = candidate and candidate.getDeviceData and candidate:getDeviceData() ~= nil
                local isLS = isLSJukeboxObject(candidate)
                local mt = nil
                if hasDD then
                    local dd = candidate:getDeviceData()
                    if dd and dd.getMediaType then mt = dd:getMediaType() end
                end
                dbg(string.format("resolve host scan(%s)[%d]: obj=%s sprite=%s hasDeviceData=%s mediaType=%s isLS=%s", tostring(label), i, tostring(candidate), tostring(sprName), tostring(hasDD), tostring(mt), tostring(isLS)))
            end
        end
        for i = 0, objects:size() - 1 do
            local candidate = objects:get(i)
            if isLSJukeboxObject(candidate) and candidate.getDeviceData and candidate:getDeviceData() then
                rememberLSHost(candidate)
                dbg("resolve host: found LS jukebox host on " .. tostring(label))
                return candidate
            end
        end
        for i = 0, objects:size() - 1 do
            local candidate = objects:get(i)
            if candidate and candidate.getDeviceData and candidate:getDeviceData() then
                anyMatched = anyMatched or candidate
                local dd = candidate:getDeviceData()
                local mt = (dd and dd.getMediaType) and dd:getMediaType() or nil
                local md = candidate.getModData and candidate:getModData() or nil
                local tcm = md and md.tcmusic or nil
                if mt == wantMediaType then
                    modeMatched = modeMatched or candidate
                elseif tcm and tcm.isJukebox and tcm.jukeboxMode == mode then
                    tagMatched = tagMatched or candidate
                end
            end
        end
        if modeMatched then
            dbg("resolve host: fallback selected mode-matched deviceData object on " .. tostring(label))
            return modeMatched
        end
        if tagMatched then
            dbg("resolve host: fallback selected jukeboxMode-tagged object on " .. tostring(label))
            return tagMatched
        end
        if anyMatched then
            dbg("resolve host: fallback found generic deviceData object on " .. tostring(label))
            return anyMatched
        end
        return nil
    end

    local sq = obj.getSquare and obj:getSquare() or nil
    if not sq then
        dbg("resolve host: object has no square")
    else
        local host = scanSquareForHost(sq, "same-square")
        if host then return host end

        -- Some LS jukebox interactions target an adjacent tile object.
        local z = sq:getZ()
        for dx = -1, 1 do
            for dy = -1, 1 do
                if not (dx == 0 and dy == 0) then
                    local nsq = getCell() and getCell():getGridSquare(sq:getX() + dx, sq:getY() + dy, z) or nil
                    host = scanSquareForHost(nsq, "neighbor " .. tostring(dx) .. "," .. tostring(dy))
                    if host then
                        return host
                    end
                end
            end
        end
    end

    -- Last fallback: search LS object registry by coordinate match/proximity.
    local list = getLSObjectList()
    if type(list) == "table" and obj.getX and obj.getY and obj.getZ then
        local ox, oy, oz = obj:getX(), obj:getY(), obj:getZ()
        local nearCandidate = nil
        local nearDist = 999
        for i = 1, #list do
            local candidate = list[i]
            if candidate and candidate.getDeviceData and candidate:getDeviceData() then
                local cx, cy, cz = candidate:getX(), candidate:getY(), candidate:getZ()
                if cz == oz then
                    local dx = math.abs(cx - ox)
                    local dy = math.abs(cy - oy)
                    if dx == 0 and dy == 0 then
                        dbg("resolve host: found list host at exact coord")
                        return candidate
                    end
                    local dist = dx + dy
                    if dist < nearDist and dist <= 2 then
                        nearDist = dist
                        nearCandidate = candidate
                    end
                end
            end
        end
        if nearCandidate then
            rememberLSHost(nearCandidate)
            dbg("resolve host: using nearest list host dist=" .. tostring(nearDist))
            return nearCandidate
        end
    end

    dbg("resolve host: no LS jukebox host found")
    return nil
end

getLSObjectList = function()
    if TMJukeboxLSBridge.lsObjectList then
        return TMJukeboxLSBridge.lsObjectList
    end
    if TMJukeboxLSBridge.lsListInitTried then
        return nil
    end
    TMJukeboxLSBridge.lsListInitTried = true
    local ok, list = pcall(require, "Properties/Objects/List")
    if ok and type(list) == "table" then
        TMJukeboxLSBridge.lsObjectList = list
    end
    return TMJukeboxLSBridge.lsObjectList
end

isPlayerNearActiveTMJukebox = function(playerObj)
    if not playerObj then return false end
    local list = getKnownLSHosts()
    if #list == 0 then return false end

    local px, py = playerObj:getX(), playerObj:getY()
    for i = 1, #list do
        local host = list[i]
        if host and host.getSquare and isLSJukeboxObject(host) then
            local hmd = host.getModData and host:getModData() or nil
            if hmd and hmd.OnOff == "on" then
                local dx = math.abs(px - host:getX())
                local dy = math.abs(py - host:getY())
                if dx <= 30 and dy <= 30 then
                    local tmPlaying = getActiveTMPlaybackForHost(host) or isHostNowPlayingTM(host)
                    if tmPlaying then
                        return true
                    end
                end
            end
        end
    end

    return false
end

local function removeOurBlinkLights(square)
    if not square or not square.getObjects then return end
    local objects = square:getObjects()
    for i = objects:size() - 1, 0, -1 do
        local obj = objects:get(i)
        local md = obj and obj.getModData and obj:getModData() or nil
        if md and md.tmJukeBlinkLight then
            square:RemoveTileObject(obj)
        end
    end
end

getActiveTMPlaybackForHost = function(host)
    if not (host and host.getSquare and host.getX and host.getY and host.getZ) then
        return false, nil, nil
    end
    local square = host:getSquare()
    if not (square and square.getObjects) then
        return false, nil, nil
    end
    local hx, hy, hz = tonumber(host:getX()), tonumber(host:getY()), tonumber(host:getZ())
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj and obj.getModData then
            local md = obj:getModData()
            local tcm = md and md.tcmusic or nil
            if tcm and tcm.isJukebox then
                local ox = tonumber(tcm.hostX) or (obj.getX and tonumber(obj:getX())) or nil
                local oy = tonumber(tcm.hostY) or (obj.getY and tonumber(obj:getY())) or nil
                local oz = tonumber(tcm.hostZ) or (obj.getZ and tonumber(obj:getZ())) or nil
                if ox == hx and oy == hy and oz == hz and tcm.isPlaying and tcm.mediaItem then
                    return true, tcm, obj
                end
            end
        end
    end
    return false, nil, nil
end

local function hostUsesNSLights(host)
    local sprite = host and host.getSprite and host:getSprite() or nil
    local props = sprite and sprite.getProperties and sprite:getProperties() or nil
    local facing = props and props.has and props:has("Facing") and props:get("Facing") or nil
    if facing == "S" or facing == "N" then return true end
    if facing == "E" or facing == "W" then return false end
    local name = sprite and sprite.getName and sprite:getName() or ""
    return string.find(name, "recreational_01_1", 1, true) ~= nil
end

local function ensureBlinkLight(square, spriteName)
    if not square or not square.getObjects then return end
    local objects = square:getObjects()
    for i = objects:size() - 1, 0, -1 do
        local obj = objects:get(i)
        local md = obj and obj.getModData and obj:getModData() or nil
        if md and md.tmJukeBlinkLight then
            local current = obj.getSpriteName and obj:getSpriteName() or (obj.getSprite and obj:getSprite():getName())
            if current == spriteName then
                return
            end
            square:RemoveTileObject(obj)
        end
    end

    local lightSprite = getSprite(spriteName)
    if not lightSprite then return end
    local lightObj = IsoObject.new(getCell(), square, lightSprite)
    local md = lightObj:getModData()
    md.tmJukeBlinkLight = true
    square:AddSpecialObject(lightObj)
end

getNowMs = function()
    if type(getTimestampMs) == "function" then
        return tonumber(getTimestampMs())
    end
    if type(getTimestamp) == "function" then
        return math.floor(tonumber(getTimestamp()) * 1000)
    end
    if os and os.time then
        return tonumber(os.time()) * 1000
    end
    return nil
end

local function squareHasLSJukebox(square)
    if not (square and square.getObjects) then return false end
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj and isLSJukeboxObject(obj) then
            return true
        end
    end
    return false
end

local function hasLSJukeboxAt(cell, x, y, z)
    if not (cell and x and y and z) then return false end
    local sq = cell:getGridSquare(x, y, z)
    return squareHasLSJukebox(sq)
end

local function squareHasJukeboxDevice(square)
    if not (square and square.getObjects) then return false end
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj and obj.getModData then
            local md = obj:getModData()
            local tcm = md and md.tcmusic or nil
            if tcm and tcm.isJukebox then
                return true
            end
        end
    end
    return false
end

local function syncProxyPowerForHost(host, hostOn)
    if not (host and host.getSquare and host.getX and host.getY and host.getZ) then return end
    local square = host:getSquare()
    if not (square and square.getObjects) then return end

    local hx = tonumber(host:getX())
    local hy = tonumber(host:getY())
    local hz = tonumber(host:getZ())
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local obj = objects:get(i)
        if obj and obj.getModData then
            local md = obj:getModData()
            local tcm = md and md.tcmusic or nil
            if tcm and tcm.isJukebox then
                local ox = tonumber(tcm.hostX) or (obj.getX and tonumber(obj:getX())) or nil
                local oy = tonumber(tcm.hostY) or (obj.getY and tonumber(obj:getY())) or nil
                local oz = tonumber(tcm.hostZ) or (obj.getZ and tonumber(obj:getZ())) or nil
                if ox == hx and oy == hy and oz == hz then
                    local dd = obj.getDeviceData and obj:getDeviceData() or nil
                    if dd then
                        if hostOn and dd.setPower and (not dd.getPower or dd:getPower() <= 0) then
                            dd:setPower(1)
                        end
                        if hostOn and dd.setDeviceVolume and (not dd.getDeviceVolume or dd:getDeviceVolume() <= 0) then
                            dd:setDeviceVolume(1)
                        end
                        if dd.setIsTurnedOn then
                            dd:setIsTurnedOn(hostOn and true or false)
                        end
                    end
                end
            end
        end
    end
end

local function isOrphanJukeboxProxy(cell, obj)
    if not (obj and obj.getModData) then return false end
    local md = obj:getModData()
    local tcm = md and md.tcmusic or nil
    if not (tcm and tcm.isJukebox) then return false end

    local hx = tonumber(tcm.hostX)
    local hy = tonumber(tcm.hostY)
    local hz = tonumber(tcm.hostZ)
    if not (hx and hy and hz) then
        return true
    end

    return not hasLSJukeboxAt(cell, hx, hy, hz)
end

local function cleanupNearbyOrphanJukeboxProxies()
    local cell = getCell()
    if not cell then return end

    local trueMusicData = ModData.getOrCreate("trueMusicData")
    local nowPlay = trueMusicData and trueMusicData["now_play"] or nil

    for playerNum = 0, getNumActivePlayers() - 1 do
        local playerObj = getSpecificPlayer(playerNum)
        if playerObj then
            local px = math.floor(playerObj:getX())
            local py = math.floor(playerObj:getY())
            local pz = playerObj:getZ()
            for dx = -20, 20 do
                for dy = -20, 20 do
                    local square = cell:getGridSquare(px + dx, py + dy, pz)
                    if square and square.getObjects then
                        if nowPlay then
                            local key = "#" .. tostring(square:getX()) .. "-" .. tostring(square:getY()) .. "-" .. tostring(square:getZ())
                            if nowPlay[key] and (not squareHasLSJukebox(square)) and (not squareHasJukeboxDevice(square)) then
                                nowPlay[key] = nil
                            end
                        end
                        local objects = square:getObjects()
                        for i = objects:size() - 1, 0, -1 do
                            local obj = objects:get(i)
                            if obj and instanceof(obj, "IsoWaveSignal") and isOrphanJukeboxProxy(cell, obj) then
                                local dd = obj.getDeviceData and obj:getDeviceData() or nil
                                local emitter = dd and dd.getEmitter and dd:getEmitter() or nil
                                if emitter and emitter.stopAll then emitter:stopAll() end
                                if nowPlay then
                                    local key = "#" .. tostring(obj:getX()) .. "-" .. tostring(obj:getY()) .. "-" .. tostring(obj:getZ())
                                    nowPlay[key] = nil
                                end
                                square:RemoveTileObject(obj)
                            end
                        end
                    end
                end
            end
        end
    end
end

local function syncProxyBlinkLights()
    if not JukeboxMenu then return end

    TMJukeboxLSBridge.cleanupTick = (TMJukeboxLSBridge.cleanupTick or 0) + 1
    if TMJukeboxLSBridge.cleanupTick >= 120 then
        TMJukeboxLSBridge.cleanupTick = 0
        cleanupNearbyOrphanJukeboxProxies()
    end

    local list = getKnownLSHosts()
    if #list == 0 then return end

    local intervalMs = 650
    local nowMs = getNowMs()
    if nowMs then
        if not TMJukeboxLSBridge.blinkLastToggleMs then
            TMJukeboxLSBridge.blinkLastToggleMs = nowMs
        else
            local elapsed = nowMs - TMJukeboxLSBridge.blinkLastToggleMs
            if elapsed >= intervalMs then
                local steps = math.floor(elapsed / intervalMs)
                if (steps % 2) == 1 then
                    TMJukeboxLSBridge.blinkPhase = not TMJukeboxLSBridge.blinkPhase
                end
                TMJukeboxLSBridge.blinkLastToggleMs = TMJukeboxLSBridge.blinkLastToggleMs + (steps * intervalMs)
            end
        end
    else
        -- Fallback when realtime timestamp helpers are unavailable.
        local dt = 0
        if getGameTime and getGameTime():getRealworldSecondsSinceLastUpdate() then
            dt = getGameTime():getRealworldSecondsSinceLastUpdate()
        elseif getGameTime and getGameTime():getGameWorldSecondsSinceLastUpdate() then
            dt = getGameTime():getGameWorldSecondsSinceLastUpdate()
        end
        TMJukeboxLSBridge.blinkTimer = (TMJukeboxLSBridge.blinkTimer or 0) + dt
        if TMJukeboxLSBridge.blinkTimer >= (intervalMs / 1000) then
            TMJukeboxLSBridge.blinkTimer = 0
            TMJukeboxLSBridge.blinkPhase = not TMJukeboxLSBridge.blinkPhase
        end
    end
    local phaseA = TMJukeboxLSBridge.blinkPhase

    -- Throttle the per-host scan to ~6 ticks (~100ms) instead of every tick.
    -- The blink phase above still updates on real time, so visuals stay smooth.
    TMJukeboxLSBridge._hostScanTick = (TMJukeboxLSBridge._hostScanTick or 0) + 1
    if TMJukeboxLSBridge._hostScanTick < 6 then return end
    TMJukeboxLSBridge._hostScanTick = 0

    for i = 1, #list do
        local host = list[i]
        if host and host.getSquare and isLSJukeboxObject(host) then
            local square = host:getSquare()
            local md = host.getModData and host:getModData() or nil
            local hostOn = md and md.OnOff == "on"
            local hostPlayingLS = md and md.OnPlay and md.OnPlay ~= "nothing"

            syncProxyPowerForHost(host, hostOn)

            local tmPlaying = getActiveTMPlaybackForHost(host) or isHostNowPlayingTM(host)
            if (not hostOn) and tmPlaying then
                stopProxyPlaybackForHost(host)
                tmPlaying = false
            end

            if hostOn and tmPlaying and not hostPlayingLS then
                local ns = hostUsesNSLights(host)
                local spriteA = ns and "LS_JukeboxLight_5" or "LS_JukeboxLight_1"
                local spriteB = ns and "LS_JukeboxLight_6" or "LS_JukeboxLight_2"
                ensureBlinkLight(square, phaseA and spriteA or spriteB)
            else
                removeOurBlinkLights(square)
            end
        end
    end
end

stopProxyPlaybackForHost = function(jukeboxObj)
    local host = jukeboxObj
    host = (resolveLSJukeboxHost and (resolveLSJukeboxHost(host) or host)) or host
    if not host then return end
    local square = host.getSquare and host:getSquare() or nil
    if square and square.getObjects then
        local objs = square:getObjects()
        for i = 0, objs:size() - 1 do
            local obj = objs:get(i)
            if obj and instanceof(obj, "IsoWaveSignal") and obj.getModData then
                local md = obj:getModData()
                local tcm = md and md.tcmusic or nil
                if tcm and tcm.isJukebox then
                    local ox = tostring(tcm.hostX or obj:getX())
                    local oy = tostring(tcm.hostY or obj:getY())
                    local oz = tostring(tcm.hostZ or obj:getZ())
                    if ox == tostring(host:getX()) and oy == tostring(host:getY()) and oz == tostring(host:getZ()) then
                        tcm.deviceType = "IsoObject"
                        tcm.isPlaying = false
                        tcm.startTime = nil
                        local dd = obj.getDeviceData and obj:getDeviceData() or nil
                        local emitter = dd and dd.getEmitter and dd:getEmitter() or nil
                        if emitter and emitter.stopAll then emitter:stopAll() end
                    end
                end
            end
        end
    end

    local trueMusicData = ModData.getOrCreate("trueMusicData")
    local coordMusicId = "#" .. tostring(host:getX()) .. "-" .. tostring(host:getY()) .. "-" .. tostring(host:getZ())
    local canonicalMusicId = "W:J:" .. tostring(host:getX()) .. "-" .. tostring(host:getY()) .. "-" .. tostring(host:getZ())
    local canonicalRadioItemID = "J:" .. tostring(host:getX()) .. "-" .. tostring(host:getY()) .. "-" .. tostring(host:getZ())
    if trueMusicData and trueMusicData["now_play"] then
        trueMusicData["now_play"][coordMusicId] = nil
        trueMusicData["now_play"][canonicalMusicId] = nil
    end
    if TCMusic and TCMusic.stopWorldMusic then
        TCMusic.stopWorldMusic(host:getX(), host:getY(), host:getZ(), canonicalRadioItemID)
    end
    if host.transmitModData then
        host:transmitModData()
    end
    if isClient() then
        sendClientCommand("truemusic", "setWorldDevicePlayback", {
            isJukebox = true,
            isPlaying = false,
            musicId = canonicalMusicId,
            radioItemID = canonicalRadioItemID,
            x = host:getX(),
            y = host:getY(),
            z = host:getZ(),
        })
        sendClientCommand("truemusic", "setWorldDeviceMedia", {
            isJukebox = true,
            isPlaying = false,
            media = nil,
            musicId = canonicalMusicId,
            radioItemID = canonicalRadioItemID,
            x = host:getX(),
            y = host:getY(),
            z = host:getZ(),
        })
        ModData.transmit("trueMusicData")
    end
end

function TMJukeboxLSBridge.TryInstall()
    if (TMJukeboxLSBridge.blockDeviceOptionsFrames or 0) > 0 then
        TMJukeboxLSBridge.blockDeviceOptionsFrames = TMJukeboxLSBridge.blockDeviceOptionsFrames - 1
    end

    -- Throttle the actual install / hook re-binding work to once every ~30
    -- ticks. Per-tick re-installation was ~free per call but adds up when
    -- combined with all the other OnTick handlers in the mod.
    TMJukeboxLSBridge._installTick = (TMJukeboxLSBridge._installTick or 0) + 1
    if TMJukeboxLSBridge._installTick < 30 then return end
    TMJukeboxLSBridge._installTick = 0

    install()
    if removeDeviceOptionsOnJukebox and Events and Events.OnFillWorldObjectContextMenu then
        -- Keep this handler last so it can strip entries added by other context builders.
        Events.OnFillWorldObjectContextMenu.Remove(removeDeviceOptionsOnJukebox)
        Events.OnFillWorldObjectContextMenu.Add(removeDeviceOptionsOnJukebox)
    end

    if ISContextMenu and type(ISContextMenu.addOption) == "function" then
        if (not TMJukeboxLSBridge.wrappedISContextMenuAddOption)
            or ISContextMenu.addOption ~= TMJukeboxLSBridge.wrappedISContextMenuAddOption
        then
            TMJukeboxLSBridge.originalISContextMenuAddOption = ISContextMenu.addOption
            TMJukeboxLSBridge.wrappedISContextMenuAddOption = function(selfObj, name, ...)
                if shouldBlockDeviceOptionNow(name) then
                    dbg("blocked addOption Device Options")
                    return { name = tostring(name or ""), iconTexture = nil }
                end
                return TMJukeboxLSBridge.originalISContextMenuAddOption(selfObj, name, ...)
            end
            ISContextMenu.addOption = TMJukeboxLSBridge.wrappedISContextMenuAddOption
        end
    end

    if ISContextMenu and type(ISContextMenu.addOptionOnTop) == "function" then
        if (not TMJukeboxLSBridge.wrappedISContextMenuAddOptionOnTop)
            or ISContextMenu.addOptionOnTop ~= TMJukeboxLSBridge.wrappedISContextMenuAddOptionOnTop
        then
            TMJukeboxLSBridge.originalISContextMenuAddOptionOnTop = ISContextMenu.addOptionOnTop
            TMJukeboxLSBridge.wrappedISContextMenuAddOptionOnTop = function(selfObj, name, ...)
                if shouldBlockDeviceOptionNow(name) then
                    dbg("blocked addOptionOnTop Device Options")
                    return { name = tostring(name or ""), iconTexture = nil }
                end
                return TMJukeboxLSBridge.originalISContextMenuAddOptionOnTop(selfObj, name, ...)
            end
            ISContextMenu.addOptionOnTop = TMJukeboxLSBridge.wrappedISContextMenuAddOptionOnTop
        end
    end
end

isJukeboxContext = function(worldobjects)
    if not worldobjects then return false end
    for _, obj in ipairs(worldobjects) do
        if obj and isLSJukeboxObject(obj) then
            rememberLSHost(obj)
            return true
        elseif obj and obj.getSquare then
            local sq = obj:getSquare()
            if sq and sq.getObjects then
                local objs = sq:getObjects()
                for i = 0, objs:size() - 1 do
                    local sqObj = objs:get(i)
                    if sqObj and isLSJukeboxObject(sqObj) then
                        rememberLSHost(sqObj)
                        return true
                    end
                    if sqObj and sqObj.getModData then
                        local md = sqObj:getModData()
                        local tcm = md and md.tcmusic or nil
                        if tcm and tcm.isJukebox and tcm.deviceType == "IsoObject" then
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

removeDeviceOptionsOnJukebox = function(_player, context, worldobjects, test)
    if test then return end
    if not context or not context.options then return end
    local jukeCtx = isJukeboxContext(worldobjects)
    if not jukeCtx then return end

    local removed = 0
    local visited = {}

    local function isDeviceOption(opt)
        if not opt then return false end
        if isDeviceOptionName(opt.name) then
            return true
        end
        local candidates = { opt.target, opt.param1, opt.param2 }
        for i = 1, #candidates do
            local c = candidates[i]
            local ct = type(c)
            if c and (ct == "userdata" or ct == "table") and c.getModData then
                local ok, md = pcall(function() return c:getModData() end)
                if ok then
                    local tcm = md and md.tcmusic or nil
                    if tcm and (tcm.isJukeboxProxy == true or tcm.isJukebox == true) then
                        return true
                    end
                end
            end
        end
        return false
    end

    local function stripMenu(menu)
        if not menu or visited[menu] then return end
        visited[menu] = true
        local opts = menu.options
        if not opts then return end

        for i = #opts, 1, -1 do
            local opt = opts[i]
            if isDeviceOption(opt) then
                if menu.removeOption then
                    menu:removeOption(opt)
                else
                    table.remove(opts, i)
                end
                removed = removed + 1
            else
                local sub = resolveSubMenuRef(context, opt and opt.subOption or nil)
                if sub then
                    stripMenu(sub)
                end
            end
        end
    end

    stripMenu(context)
    if removed > 0 then
        TMJukeboxLSBridge.blockDeviceOptionsFrames = 45
        local now = getNowMs and getNowMs() or nil
        TMJukeboxLSBridge.blockDeviceOptionsUntilMs = now and (now + 1200) or nil
        dbg("removed device options count=" .. tostring(removed))
    end
end

Events.OnGameStart.Add(TMJukeboxLSBridge.TryInstall)
Events.OnTick.Add(TMJukeboxLSBridge.TryInstall)
Events.OnTick.Add(syncProxyBlinkLights)
Events.OnFillWorldObjectContextMenu.Add(removeDeviceOptionsOnJukebox)
JUKEBOX LIFESTYLES INTEGRATION DISABLED --]]

