-- MapSpawnSelectScroll_Patch.lua
-- Part of MrTheSteve_Patches
--
-- Patches: vanilla MapSpawnSelect (character-creation map/spawn picker UI)
--
-- Carried over 2026-08-02 from HellDrinx - Bug Fixes (workshop 3667630656), whose
-- author is semi-retiring. Relevant given the size of the map mod list here --
-- MapSpawnSelect.recalculateMapSize() sizes the map listbox as itemheight * total
-- items, growing it past the screen once enough map mods are installed.
-- ISScrollingListBox only enables scrolling when getScrollHeight() > getHeight(),
-- but since height == scrollHeight here, scroll never activates.
--
-- Fix: cap listbox height, set scrollHeight to the real total, and reposition
-- elements below it accordingly.

local _original_recalculateMapSize = MapSpawnSelect.recalculateMapSize

function MapSpawnSelect:recalculateMapSize()
    _original_recalculateMapSize(self)

    local itemCount = #self.listbox.items
    if itemCount == 0 then return end

    local totalH = self.listbox.itemheight * itemCount

    local spacing = UI_BORDER_SPACING or 10
    local bottomBoundary = self.backButton:getY() - spacing
    local availableH = bottomBoundary - self.listbox:getY()

    local maxListH = math.floor(availableH * 0.45)
    local minListH = self.listbox.itemheight * 3
    local newListH = math.max(maxListH, minListH)

    if totalH <= newListH then
        local newRichY = self.listbox:getBottom() + spacing
        self.richText:setY(newRichY)
        if not MainScreen.instance.inGame then
            if self.seedPanel then
                self.richText:setHeight(math.max(self.seedPanel:getY() - newRichY - spacing, 40))
            end
        else
            self.richText:setHeight(math.max(self.mapPanel:getBottom() - newRichY, 40))
        end
        return
    end

    self.listbox:setHeight(newListH)
    self.listbox:setScrollHeight(totalH)

    -- anchorBottom=true makes the Java side recalculate Y incorrectly when the
    -- listbox has setHeight called on it -- disable it before forcing Y=0.
    if self.listbox.vscroll then
        local vs = self.listbox.vscroll
        vs.anchorBottom = false
        vs.javaObject:setAnchorBottom(false)
        vs.y = 0
        vs.height = newListH
        vs.javaObject:setY(0)
        vs.javaObject:setHeight(newListH)
    end

    local newRichY = self.listbox:getBottom() + spacing
    self.richText:setY(newRichY)

    if not MainScreen.instance.inGame then
        if self.seedPanel then
            self.richText:setHeight(math.max(self.seedPanel:getY() - newRichY - spacing, 40))
        end
    else
        self.richText:setHeight(math.max(self.mapPanel:getBottom() - newRichY, 40))
    end
end
