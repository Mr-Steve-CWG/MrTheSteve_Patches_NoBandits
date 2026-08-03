require 'LTSProneTimedAction'
require 'LTSPlayerProneStates'

RET_LTS = RET_LTS or {}

local lastFailTriggerProneActionTime = 0
RET_LTS.triggerFailProneActionCooldown = 5 -- En segundos
RET_LTS.syncCreatedPlayerDelay = 400 -- 0.4 segundos (en milisegundos)

-- FIX #4: removed getSquareDelta() -- dead code, never called, referenced undefined global PLAYER_SQR

RET_LTS.TriggerProneAction = function(player)
    -- FIX #2: removed unconditional print("Triggered prone action") -- fired every prone toggle
    local baseValidation = player and not player:isDead() and not player:hasTimedActions();
    local acostadoValdiation = not RET_LTS.isGettingUpFromPronePosition(player) and not RET_LTS.isGettingDownForPronePosition(player);
    if baseValidation and acostadoValdiation then
        --if isClient() then
            -- Envía comando al servidor para que los demás jugadores vean la animación
            --sendClientCommand(player, 'RET_LTS', 'StartProne', { time = RET_LTS.get_GetUpTime() })
        --else
            -- Solo local (single-player o servidor local)
    
            -- local action = RET_LTS.ProneAction:new(player);
            -- ISTimedActionQueue.add(action);
            local accelerate = player:IsRunning() or player:isSprinting();
            local action = LTSProneTimedAction:new(player, accelerate);
            ISTimedActionQueue.add(action);

        --end
    else
        if not baseValidation then
            -- Este comportamiento es normal, ya que el jugador no cumple la validación base (que no se desincroniza).
            return;
        end
        -- Verificar si ocurrió una desincronización en el cliente (puede ocurrir si se desconecta justo cuando el 
        -- jugador está levantandose o acostandose, no ocurre cuando el jugador está completamente acostado).
        local currentTime = getTimestamp()  -- Obtiene el tiempo actual en segundos
        if lastFailTriggerProneActionTime == 0 then
            lastFailTriggerProneActionTime = currentTime
        else
            -- Verificar si ha pasado suficiente tiempo desde la última llamada
            if currentTime - lastFailTriggerProneActionTime >= RET_LTS.triggerFailProneActionCooldown then
                lastFailTriggerProneActionTime = 0
                -- En este punto sabemos que es imposible que la animación dure más de "RET_LTS.triggerFailProneActionCooldown" segundos.
                -- Por lo tanto cambiamos los estados para sincronizar y volvemos a intentar hacer la llamada.

                RET_LTS.setGettingDownForPronePosition(player, false);
                RET_LTS.setGettingUpFromPronePosition(player, false);

                if isDebugEnabled() then
                    print("Se aplicó una sincronización del Player.")
                end

                RET_LTS.TriggerProneAction(player);

            end
        end

    end
end

RET_LTS.TriggerProneVehicleCrawlAction = function(player, vehicle)
    --if isClient() then
        -- Envía comando al servidor para que los demás jugadores vean la animación
        --sendClientCommand(player, 'RET_LTS', 'VehicleCrawl', { vehicle = vehicle })
    --else
        -- Solo local (single-player o servidor local)
        local action = LTSProneVehicleCrawlAction:new(player, vehicle);
        ISTimedActionQueue.add(action);
    --end
end

RET_LTS.OnCreatePlayer = function(playerNum, player)
    if not player:isLocal() then
        return;
    end
    -- De esta forma la animación será la misma que antes de desconectarse.
    if RET_LTS.isPronePosition(player) then
        RET_LTS.setPronePosition(player, true, true);  -- Ignoramos el evento de trigger para evitar conflictos al iniciar el juego.
    end
    -- Cargamos la configuración del estado anterior del jugador al iniciar el juego.
    -- if not isClient() then
        RET_LTS.Buffs.RestoreBuffs(player);
    -- end
    RET_LTS.CheckPerks(player, Perks.Fitness, 0, false, true);
    if isClient() then
        -- Solo para el MP
        local timeOutID = "OnCreatePlayer_"..player:getID(); -- Le pongo cualquier cosa, lo importante es que sea único por jugador.
        --Ejecutar la función 7 segundos después para asegurar que el jugador esté completamente cargado, porque sucede que en MP no se pueden enviar comandos nada más carga el juego.
        RET_LTS.setTimeout(timeOutID, 
            function()
                local senderPlayer = getSpecificPlayer(playerNum);
                RET_LTS.LTSSyncPlayerProneState(senderPlayer);
                RET_LTS.CheckPerks(senderPlayer, Perks.Fitness, 0, false, false);
                RET_LTS.RestoreBuffsServer(senderPlayer);
            end, 
        RET_LTS.syncCreatedPlayerDelay);
    
    end 
end

RET_LTS.OnPlayerDeath = function(player)
    if player and player:isLocal() then
        -- Al morir le decimos al servidor que el jugador murió para evitar problemas de sincronización.
        RET_LTS.PlayerDeathSync(player);
    end
end

Events.OnPlayerDeath.Add(RET_LTS.OnPlayerDeath);

Events.OnCreatePlayer.Add(RET_LTS.OnCreatePlayer)