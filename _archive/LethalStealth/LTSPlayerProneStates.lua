RET_LTS = RET_LTS or {}

local playersInProne = nil;
local playersGettingDownForProne = nil;
local playersGettingUpFromProne = nil;

RET_LTS.isGettingUpFromPronePosition = function(player)
    if playersGettingUpFromProne ~= nil then
        if playersGettingUpFromProne[player:getID()] ~= nil then
            return playersGettingUpFromProne[player:getID()]
        end
    end
    return false;
end

RET_LTS.setGettingUpFromPronePosition = function(player, levantandose)
    if playersGettingUpFromProne == nil then
        playersGettingUpFromProne = {}
    end
    playersGettingUpFromProne[player:getID()] = levantandose
end

RET_LTS.isGettingDownForPronePosition = function(player)
    if playersGettingDownForProne ~= nil then
        if playersGettingDownForProne[player:getID()] ~= nil then
            return playersGettingDownForProne[player:getID()]
        end
    end
    return false;
end

RET_LTS.setGettingDownForPronePosition = function(player, acostandose)
    if playersGettingDownForProne == nil then
        playersGettingDownForProne = {}
    end
    playersGettingDownForProne[player:getID()] = acostandose
end

RET_LTS.isPronePosition = function(player)
    if playersInProne ~= nil then
        if playersInProne[player:getID()] ~= nil then
            return playersInProne[player:getID()]
        end
    end
    local md = player:getModData();
    if isServer() then
        return ((md.ret_lts_acostado) or false);
    else
        return ((md.ret_lts_acostado or player:getVariableBoolean("ltsproneposition")) or false);
    end
end

RET_LTS.setPronePosition = function(player, acostado, ignoreTriggerEvent, ignoreBehaviorChanges, ignoreSyncServerChanges)
    if not isServer() or not ignoreBehaviorChanges then
        player:setCanShout(not acostado);
        player:setAuthorizedHandToHand(not acostado);
        --player:setDeferredMovementEnabled(not acostado);

        if not acostado then
            player:setDeferredMovementEnabled(true);
            player:setAuthorizedHandToHandAction(true);
            player:setIgnoreAimingInput(false);
            player:setAllowRun(true);
            player:setAllowSprint(true);
            player:setOnFloor(false);
        else
            RET_LTS.CheckAllowAttack(player, player:isPlayerMoving());
        end

        player:setBlockMovement(false);

        player:setIgnoreContextKey(acostado);
        player:setIgnoreAutoVault(acostado);

        player:setIgnoreMovement(false);
    end
    local md = player:getModData();
    player:setVariable("ltsproneposition", acostado);
    md.ret_lts_acostado = acostado;
    -- if not isServer() then
    --     player:transmitModData();
    -- end
    RET_LTS.setGettingUpFromPronePosition(player, false);
    RET_LTS.setGettingDownForPronePosition(player, false);

    if playersInProne == nil then
        playersInProne = {}
    end
    playersInProne[player:getID()] = acostado

    if not ignoreTriggerEvent then
        triggerEvent("OnLTSProneAction", player, acostado);
    end
    if isServer() and not ignoreSyncServerChanges then
        RET_LTS.LTSSyncPlayerProneState(player);
    end
end

RET_LTS.isPlayerProneInFrontVehicle = function(player, vehicle)
    if RET_LTS.isPronePosition(player) and not RET_LTS.isGettingUpFromPronePosition(player) and not RET_LTS.isGettingDownForPronePosition(player) then -- FIX #3: second condition was duplicate isGettingUpFromPronePosition
        local playerSquare = player:getSquare();
        local vehicleSquare = vehicle:getSquare();
        if playerSquare and vehicleSquare then
            if vehicle:isAtRest() and playerSquare:getZ() == vehicleSquare:getZ() then
                if vehicle:isInBounds(player:getX() + math.cos(player:getAnimAngleRadians()), player:getY() + math.sin(player:getAnimAngleRadians())) then
                    return true;
                end
            end
        end
    end
    return false;
end

RET_LTS.getPlayersInProne = function()
    return playersInProne;
end

RET_LTS.GetPlayerID = function(player)
    if isServer() or isClient() then
        return player:getOnlineID();
        --return player:getUsername();
    else
        return player:getID();
    end
end

