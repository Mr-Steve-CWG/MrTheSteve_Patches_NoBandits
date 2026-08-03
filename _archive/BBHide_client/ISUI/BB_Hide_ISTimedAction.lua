-- **************************************************
-- ██████  ██████   █████  ██    ██ ███████ ███    ██ 
-- ██   ██ ██   ██ ██   ██ ██    ██ ██      ████   ██ 
-- ██████  ██████  ███████ ██    ██ █████   ██ ██  ██ 
-- ██   ██ ██   ██ ██   ██  ██  ██  ██      ██  ██ ██ 
-- ██████  ██   ██ ██   ██   ████   ███████ ██   ████
-- **************************************************
-- ** Seek Excellence! Employ ME, not my Copycats. **
-- **************************************************

require "TimedActions/ISBaseTimedAction"
BB_Hide_ISTimedAction = ISBaseTimedAction:derive("BB_Hide_ISTimeAction")

BB_Hide_ISTimedAction.isValid = function(self)
    return true
end

BB_Hide_ISTimedAction.update = function(self)

end

BB_Hide_ISTimedAction.start = function(self)

    if self.typeTimeAction == "hide" then
        self:setActionAnim("loot")
        self:setAnimVariable("LootPosition", "Mid")

        BravensUtilsO5.DelayFunction(function()
            BravensUtilsO5.TryPlaySoundClip(self.playerObj, "hide01", false)
        end, 35)
    end
end

BB_Hide_ISTimedAction.stop = function(self)
    ISBaseTimedAction.stop(self)

    if self.typeTimeAction == "hide" then
        BravensUtilsO5.TryStopSoundClip(self.playerObj, "hide01")
    end

    if self.typeTimeAction == "hiding" then
        if self.playerObj:getModData().hiding then
            BB_Hide.RevealPlayer(self.playerObj, self.playerObj:getModData().lastCoordsZ)
            self.playerObj:getModData().bbStatusEffect = nil
            self.playerObj:getModData().hiding = nil
        end
    end
end

BB_Hide_ISTimedAction.perform = function(self)

    if self.typeTimeAction == "hide" then
        BravensUtilsO5.TirePlayer(self.playerObj, 0.07)
        self.playerObj:getModData().lastCoordsZ = self.playerObj:getZ()
        self.playerObj:getModData().hiding = true
        BB_Hide.HidePlayer(self.playerObj)
        BravensUtilsO5.TryStopSoundClip(self.playerObj, "hide01")
        ISTimedActionQueue.add(BB_Hide_ISTimedAction:Hiding(self.playerObj))
    end

    ISBaseTimedAction.perform(self)
end

BB_Hide_ISTimedAction.Hide = function(self, playerObj, time)
    local action = ISBaseTimedAction.new(self, playerObj)
    action.typeTimeAction = "hide"
    action.playerObj = playerObj
    action.stopOnWalk = true
    action.stopOnRun = true
    action.maxTime = time
    action.fromHotbar = false

    if action.playerObj:isTimedActionInstant() then action.maxTime = 1 end
    return action
end

BB_Hide_ISTimedAction.Hiding = function(self, playerObj)
    local action = ISBaseTimedAction.new(self, playerObj)
    action.typeTimeAction = "hiding"
    action.playerObj = playerObj
    action.stopOnWalk = true
    action.stopOnRun = true
    action.maxTime = 999999999
    action.fromHotbar = false

    if action.playerObj:isTimedActionInstant() then action.maxTime = 1 end
    return action
end