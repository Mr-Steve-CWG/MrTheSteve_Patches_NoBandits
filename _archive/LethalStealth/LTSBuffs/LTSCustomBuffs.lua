require "LTSCustomEvents"

RET_LTS = RET_LTS or {}

RET_LTS.Buffs = RET_LTS.Buffs or {}

-- Definición de los buffs personalizados.
-- Nota: Deben ser numeros enteros positivos.
RET_LTS.Buffs.SneakingBonus = 2;
RET_LTS.Buffs.ProneBonus = 4;

local playerBuffs = {};

RET_LTS.Buffs.UpdateBuffs = function(player, isLTSProne, isSneaking)
    if isLTSProne or isSneaking then
        -- Modo agregar buffs.
        if RET_LTS.Buffs.ExistsPlayerBuffs(player) then
            return;  -- Si ya existen los buffs, no hacemos nada.
        end
    else
        -- Modo quitar buffs.
        if not RET_LTS.Buffs.ExistsPlayerBuffs(player) then
            return;  -- Si no existen los buffs, no hacemos nada.
        end
    end

    local pBuffs = RET_LTS.Buffs.GetPlayerBuffs(player);
    pBuffs.sneaking = isSneaking;
    pBuffs.prone = isLTSProne;

    if isLTSProne or isSneaking then

        local modifier = 0;
        if isLTSProne then
            modifier = RET_LTS.ProneAimBonus();
        elseif isSneaking then
            modifier = RET_LTS.CrouchAimBonus();
        end

        local originalPerkLevelAim = player:getPerkLevel(Perks.Aiming);
        local newPerkLevelAim = math.min(originalPerkLevelAim + modifier, 10); -- Limitar el nivel máximo a 10.

        pBuffs.originalPerkLevelAim = originalPerkLevelAim;
        pBuffs.actualPerkLevelAim = newPerkLevelAim;
        pBuffs.actualAimBonus = modifier;

        if newPerkLevelAim ~= originalPerkLevelAim then
            player:setPerkLevelDebug(Perks.Aiming, newPerkLevelAim);
            RET_LTS.Buffs.SaveBuffs(player, pBuffs, isLTSProne, isSneaking);
        end
    else
        local actualPerkLevelAim = player:getPerkLevel(Perks.Aiming);
        local diffLevels = actualPerkLevelAim - pBuffs.actualPerkLevelAim
        local newPerkLevelAim = pBuffs.originalPerkLevelAim + diffLevels;

        print("newPerkLevelAim: "..tostring(newPerkLevelAim));
        if newPerkLevelAim ~= actualPerkLevelAim then
            player:setPerkLevelDebug(Perks.Aiming, newPerkLevelAim);

            if newPerkLevelAim < 10 then
                local xp = RET_LTS.Buffs.getPerkXp(player, PerkFactory.getPerk(Perks.Aiming), newPerkLevelAim);
                local xpForLvl = PerkFactory.getPerk(Perks.Aiming):getXpForLevel(newPerkLevelAim + 1);


                if xp >= xpForLvl then
                    -- Recalcular el nivel del perk.
                    print("xp: "..tostring(xp).." xpForLvl: "..tostring(xpForLvl));
                    local perkRecalc = newPerkLevelAim;
                    repeat
                        player:LevelPerk(Perks.Aiming);

                        perkRecalc = perkRecalc + 1;

                        if perkRecalc >= 10 then
                            break; -- Máximo lvl 10.
                        end

                        xp = RET_LTS.Buffs.getPerkXp(player, PerkFactory.getPerk(Perks.Aiming), perkRecalc);
                        xpForLvl = PerkFactory.getPerk(Perks.Aiming):getXpForLevel(perkRecalc + 1);

                        print(tostring(perkRecalc).." Nivel del perk recalculado: "..tostring(player:getPerkLevel(Perks.Aiming)));
                        print("→ Comprobando salida: "
                        .. "xp="..xp..", xpForLvl="..xpForLvl
                        .. " → salir? " .. tostring(not (xp >= xpForLvl)))

                    until not (xp >= xpForLvl)
                end
            end

        end

        RET_LTS.Buffs.DeleteBuffs(player, pBuffs)
    end
end


RET_LTS.Buffs.getPerkXp = function(player, perk, level)
    if level == 0 then
		return player:getXp():getXP(perk:getType());
	end
	level = level - 1;
	local previousXp = perk:getXp1();
	if level >= 1 then
		previousXp = previousXp + perk:getXp2();
	end
	if level >= 2 then
		previousXp = previousXp + perk:getXp3();
	end
	if level >= 3 then
		previousXp = previousXp + perk:getXp4();
	end
	if level >= 4 then
		previousXp = previousXp + perk:getXp5();
    end
    if level >= 5 then
        previousXp = previousXp + perk:getXp6();
    end
    if level >= 6 then
        previousXp = previousXp + perk:getXp7();
    end
    if level >= 7 then
        previousXp = previousXp + perk:getXp8();
    end
    if level >= 8 then
        previousXp = previousXp + perk:getXp9();
    end
    if level >= 9 then
        previousXp = previousXp + perk:getXp10();
    end
    
    local xpTot = player:getXp():getXP(perk:getType()) - previousXp;

	return xpTot
end

RET_LTS.Buffs.RestoreBuffs = function(player, ignoreSync)
    local modData = player:getModData();
    if modData.ltsBuffs then
        local playerID = RET_LTS.GetPlayerID(player);
        playerBuffs[playerID] = {
            id = playerID,
            originalPerkLevelAim = modData.ltsBuffs.originalPerkLevelAim,
            actualPerkLevelAim = modData.ltsBuffs.actualPerkLevelAim,
            actualAimBonus = modData.ltsBuffs.actualAimBonus,
            sneaking = modData.ltsBuffs.sneaking,
            prone = modData.ltsBuffs.prone,
        };
        -- print("Restored buffs for player ID "..tostring(RET_LTS.GetPlayerID(player))..":");
        -- RET_LTS_Utils.printTable(modData.ltsBuffs);
        player:setSneaking(modData.ltsBuffs.sneaking); -- Restaurar el estado anterior.
    end
end

RET_LTS.Buffs.DeleteBuffs = function(player, pBuffs)
    local modData = player:getModData();
    if modData.ltsBuffs then
        modData.ltsBuffs = nil;
    end
    playerBuffs[pBuffs.id] = nil
    -- FIX #2: removed RET_LTS_Utils.printTable(modData.ltsBuffs) -- debug leftover, was printing nil on every buff removal
end

RET_LTS.Buffs.SaveBuffs = function(player, pBuffs, isLTSProne, isSneaking)
    local modData = player:getModData();
    if not modData.ltsBuffs then
        modData.ltsBuffs = {};
    end
    modData.ltsBuffs.originalPerkLevelAim = pBuffs.originalPerkLevelAim;
    modData.ltsBuffs.actualPerkLevelAim = pBuffs.actualPerkLevelAim;
    modData.ltsBuffs.actualAimBonus = pBuffs.actualAimBonus;
    modData.ltsBuffs.sneaking = isSneaking;
    modData.ltsBuffs.prone = isLTSProne;
    -- if not isServer() then
    --     player:transmitModData();
    -- end
    -- print("Saved buffs for player ID "..tostring(RET_LTS.GetPlayerID(player))..":");
    -- RET_LTS_Utils.printTable(modData.ltsBuffs);
end

RET_LTS.Buffs.GetPlayerBuffs = function(player)
    local playerID = RET_LTS.GetPlayerID(player);
    if not playerBuffs[playerID] then
        local playerPerkLevelAim = player:getPerkLevel(Perks.Aiming);
        playerBuffs[playerID] = {
            id = playerID,
            originalPerkLevelAim = playerPerkLevelAim,
            actualPerkLevelAim = playerPerkLevelAim,
            actualAimBonus = 0,
            sneaking = player:isSneaking(),
            prone = RET_LTS.isPronePosition(player),
        };
    else
        -- comprobar datos corruptos.
        -- solo si están corruptos, se corrigen.
        local pBuffs = playerBuffs[playerID];
        local isValid = true;
        if pBuffs.id == nil then
            isValid = false;
            pBuffs.id = playerID;
            print("Error 01: Stealth Mod Invalid \"ID\" data");
        end
        if pBuffs.originalPerkLevelAim == nil then
            isValid = false;
            pBuffs.originalPerkLevelAim = player:getPerkLevel(Perks.Aiming);
            print("Error 01: Stealth Mod Invalid \"originalPerkLevelAim\" data");
        end
        if pBuffs.actualPerkLevelAim == nil then
            isValid = false;
            pBuffs.actualPerkLevelAim = player:getPerkLevel(Perks.Aiming);
            print("Error 01: Stealth Mod Invalid \"actualPerkLevelAim\" data");
        end
        if pBuffs.actualAimBonus == nil then
            isValid = false;
            pBuffs.actualAimBonus = 0;
            print("Error 01: Stealth Mod Invalid \"actualAimBonus\" data");
        end
        if pBuffs.sneaking == nil then
            isValid = false;
            pBuffs.sneaking = player:isSneaking();
            print("Error 01: Stealth Mod Invalid \"prone\" data");
        end
        if pBuffs.prone == nil then
            isValid = false;
            pBuffs.prone = RET_LTS.isPronePosition(player);
            print("Error 01: Stealth Mod Invalid \"prone\" data");
        end
        if not isValid then
            -- Mostrar mensaje de datos corruptos.
            player:setHaloNote(getText("UI_LTS_Error01"), 200, 60, 30, 300)
        end
    end
    return playerBuffs[playerID];
end

RET_LTS.Buffs.ExistsPlayerBuffs = function(player)
    if playerBuffs[RET_LTS.GetPlayerID(player)] then
        return true;
    end
    return false;
end

RET_LTS.Buffs.OnProneAction = function(player, isLTSProne)
    RET_LTS.Buffs.UpdateBuffs(player, isLTSProne, player:isSneaking());
end

RET_LTS.Buffs.OnSneakAction = function(player, isSneaking)
    RET_LTS.Buffs.UpdateBuffs(player, RET_LTS.isPronePosition(player), isSneaking);
end

Events.OnLTSProneAction.Add(RET_LTS.Buffs.OnProneAction)
Events.OnLTSSneakAction.Add(RET_LTS.Buffs.OnSneakAction)