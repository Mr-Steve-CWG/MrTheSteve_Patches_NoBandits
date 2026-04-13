require "TimedActions/ISBaseTimedAction"

LTSProneTimedAction = ISBaseTimedAction:derive("LTSProneTimedAction");

RET_LTS = RET_LTS or {}

RET_LTS.GetUpTimeBase = 145;

function LTSProneTimedAction:isValid()
    local prone = RET_LTS.isPronePosition(self.character);

    if not prone and not RET_LTS.ProneSystemEnabled() then
        return false; -- Prone system is disabled.
    end

    return not self.character:getVehicle() and not self.character:isPlayerMoving() and
    not self.character:isDead() and not self.character:isSitOnGround() and not self.character:isSittingOnFurniture() and
    ((not prone and not self.character:isAiming()) or prone) 
end

function LTSProneTimedAction:start()
    -- self:updateAccelerate();
    local isAiming = self.character:isAiming();
    if RET_LTS.isPronePosition(self.character) then
        -- Si el jugador está acostado y se quiere levantar, no puede cancelar la acción moviendose, por lo que será un peligro divertido.
        --self.character:setIgnoreMovement(true); -- Bloqueamos el movimiento
        --self.blocked = true;
        self:setActionAnim("ltsgettingupfromproneposition");
        RET_LTS.setGettingUpFromPronePosition(self.character, true);
        if isAiming then
            -- Si está apuntando, lo dejamos de hacer, para evitar un bug que provoca que se junten las 2 animaciones.
            self.character:setIsAiming(false);
        end
    else
        -- Si el jugador está parado y se quiere acostar, sí puede arrepentirse cancelando la acción moviendose, para que tampoco sea muy frustrante.
        self:setActionAnim("ltsgettingdownforproneposition");
        RET_LTS.setGettingDownForPronePosition(self.character, true);
    end

    self.action:setUseProgressBar(false);

    self.primaryItem = self.character:getPrimaryHandItem()
    self.secondaryItem = self.character:getSecondaryHandItem()
    self.character:removeFromHands(self.primaryItem)
    self.character:removeFromHands(self.secondaryItem)

    self.character:setSitOnGround(false);
    self.character:setSittingOnFurniture(false);
    self.character:setSneaking(false);

    local getUpScale = RET_LTS.get_GetUpTimeScale(self.maxTime);
    self.character:setVariable("getUpScale", getUpScale);

end

function LTSProneTimedAction:serverStart()
    if self.accelerate then
        self.character:getStats():remove(CharacterStat.ENDURANCE, RET_LTS.get_EnduraceUseWhenAccelerating());
    end
end

function LTSProneTimedAction:update()
    if not self.blocked then
        if self.maxTime > 0 then
            if self.action:getCurrentTime() > self.maxTime / 4  then
                -- Si ya transcurrió la mitad de la animación no se podrá cancelar moviendose.
                self.blocked = true;
                self.character:setIgnoreMovement(true); -- Bloqueamos el movimiento
                --self.character:Say("Debug: Movimiento Bloqueado")
            end
        end
    end
end

function LTSProneTimedAction:stop()
    self.character:setIgnoreMovement(false);
    RET_LTS.setGettingUpFromPronePosition(self.character, false);
    RET_LTS.setGettingDownForPronePosition(self.character, false);
    if RET_LTS.isPronePosition(self.character) then
        RET_LTS.CheckAllowAttack(self.character, self.character:isPlayerMoving());
    end
    ISBaseTimedAction.stop(self);
end

function LTSProneTimedAction:complete()
    -- Server side or singleplayer
    local stats = self.character:getStats();
    stats:remove(CharacterStat.ENDURANCE, 0.02)
    if isServer() then
        -- Solo si es server porque ya se llamó en el perform
        RET_LTS.setPronePosition(self.character, not self.isProne, false, true);
    end
	return true;
end 

function LTSProneTimedAction:perform()
    RET_LTS.setPronePosition(self.character, not self.isProne);
    ISBaseTimedAction.perform(self);
    -- Client side or singleplayer

    -- Hacemos toggle de acostado
    -- local prone = RET_LTS.isPronePosition(self.character);
    -- prone = not prone;

    --self.character:setIgnoreMovement(prone);
    --self.character:setIgnoreAimingInput(false);

    if not (self.primaryItem == nil) then
        if RET_LTS.isHandEquippableValid(self.primaryItem)  then
            -- Solo autoequipar armas de fuego o manos desnudas, las armas de melee no se pueden equipar mientras está acostado.
            self.character:setPrimaryHandItem(self.primaryItem);
        end
    end
    if not (self.secondaryItem == nil) then
        if RET_LTS.isHandEquippableValid(self.secondaryItem) then
            -- Solo autoequipar armas de fuego o manos desnudas, las armas de melee no se pueden equipar mientras está acostado.
            self.character:setSecondaryHandItem(self.secondaryItem);
        end
    end

    -- local currentEndurance = stats:getEndurance();   
    -- stats:setEndurance(math.max(0, currentEndurance - 0.02))
    
end

-- function LTSProneTimedAction:adjustMaxTime(maxTime)
--     self:updateAccelerate();
--     if self.accelerate then
--         maxTime = RET_LTS.get_GetUpTimeAcceleration(maxTime);
--         -- Penalizar el uso de la aceleración:
--         local stats = self.character:getStats();
--         stats:remove(CharacterStat.ENDURANCE, RET_LTS.get_EnduraceUseWhenAccelerating())
--         -- local currentEndurance = stats:getEndurance();
-- 	    -- stats:setEndurance(math.max(0, currentEndurance - RET_LTS.get_EnduraceUseWhenAccelerating()))
--     end
-- 	return maxTime;
-- end

-- function LTSProneTimedAction:updateAccelerate()
--     if not self.accelerate then
--         self.accelerate = self.character:IsRunning() or self.character:isSprinting();
--         print("accelerate set to " .. tostring(self.accelerate));
--     end
-- end

-- function LTSProneTimedAction:updateAccelerate()
--     if self.accelerate then
--         self.character:getStats():remove(CharacterStat.ENDURANCE, RET_LTS.get_EnduraceUseWhenAccelerating());
--     end
-- end

function LTSProneTimedAction:getDuration()
    local baseTime
    if self.character:isTimedActionInstant() then
        -- Cuando se usan trucos, ir a 800% de velocidad.
		baseTime = RET_LTS.GetUpTimeBase / 8; -- FIX #1: was unconditionally overwritten on next line
	else
	    baseTime = RET_LTS.GetUpTimeBase;
	end
    local maxTime = baseTime
    if self.accelerate then
        maxTime = RET_LTS.get_GetUpTimeAcceleration(baseTime);
    end
    --print("maxTime: " .. tostring(maxTime));
    return maxTime;
end

function LTSProneTimedAction:new (character, accelerate)
	local o = ISBaseTimedAction.new(self, character);
	o.character = character;
    o.accelerate = accelerate;
    o.maxTime = o:getDuration();
    --print(o.accelerate);
    o.primaryItem = nil
    o.secondaryItem = nil
    o.blocked = false;
    o.isProne = RET_LTS.isPronePosition(character);
    return o
end