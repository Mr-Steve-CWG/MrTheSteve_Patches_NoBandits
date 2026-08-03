-- TrueMusicRadio_Patch.lua
-- True Music Radio (Workshop ID 3631572046)
-- Fixes a nil crash in TMRadio.prettyName when getItemNameFromFullType() returns
-- nil for a song whose item type does not exist (e.g., a content pack that is not
-- installed). The original function passes the result directly to displayName:gsub()
-- which crashes with "attempted index: gsub of non-table: null" because you cannot
-- call string methods on nil.
--
-- Fix: wrap prettyName so that a nil displayName returns an empty string instead of
-- crashing. The UI code downstream handles empty/blank strings cleanly.
--
-- This fires on every UI update tick while a radio is playing a song from a missing
-- content pack, so the error accumulates rapidly. The wrap eliminates the spam.

Events.OnGameBoot.Add(function()
    if not (TMRadio and TMRadio.prettyName) then return end

    local originalPrettyName = TMRadio.prettyName
    TMRadio.prettyName = function(displayName)
        if not displayName then
            -- Item type does not exist in this install (content pack not loaded).
            -- Return empty string so the radio UI displays nothing rather than crashing.
            return ""
        end
        return originalPrettyName(displayName)
    end
end)
