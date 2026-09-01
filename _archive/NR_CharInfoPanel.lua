-- NR_CharInfoPanel.lua
-- NeatUI replacement for ISCharacterInfoWindow (character info / C key).
-- Frame: NR_Header + custom tab bar. Sub-panels: vanilla, skinned in place;
-- healthView uses NR_HealthPanel (derived from ISHealthPanel) so any mod adding
-- an ISButton to the health panel is auto-wrapped as a NI_SquareButton.
-- Mod compatibility: third-party mods that add tabs via self.panel:addView()
-- (e.g. AutoCook) work automatically via the ISTabPanel shim.

require "XpSystem/ISUI/ISCharacterInfoWindow"
require "NeatRocco/NR_Utils/NR_BasePanel"
require "NeatRocco/NR_Utils/NR_CollapseUtils"
require "NeatRocco/NR_Utils/NR_TabBar"
require "NeatRocco/NR_Utils/NR_ScrollingList"
require "NeatRocco/NR_Config"
require "NeatRocco/NR_CharInfo/NR_HealthPanel"
require "NeatUI_Framework/NeatTool/NeatTool_3Patch"

NR_CharInfoPanel = ISCharacterInfoWindow:derive("NR_CharInfoPanel")

-- Hooks called by shim.addView(view, name) for every tab added (vanilla or mod).
-- Used by NR_CharInfo/compat/* files to apply mod-specific fixes without polluting
-- this file. Defensive init: order of file load doesn't matter.
NR_CharInfoPanel.addViewHooks = NR_CharInfoPanel.addViewHooks or {}

local NI_SquareButton = require("NeatUI_Framework/UI/NI_SquareButton")

-- Icons for known vanilla tabs; unknown tabs (mods) fall back to Icon_Mechanic.
local VANILLA_ICONS = {
    "media/ui/NeatRocco/ICON/Icon_Info.png",      -- 1: info
    "media/ui/NeatRocco/ICON/Icon_Book.png",      -- 2: skills
    "media/ui/NeatRocco/ICON/Icon_health.png",    -- 3: health
    "media/ui/NeatRocco/ICON/Icon_Armor.png",        -- 4: protection
    "media/ui/NeatRocco/ICON/Icon_Temperature.png", -- 5: clothing insulation
}

-- ----------------------------------------------------------------------------------------------------- --
-- Constructor
-- ----------------------------------------------------------------------------------------------------- --

function NR_CharInfoPanel:new(x, y, width, height, playerNum)
    -- ISCollapsableWindow:new creates the Java-backed object.
    local o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self

    o.backgroundColor.a = 0.9
    o.visibleOnStartup  = false
    o.playerNum         = playerNum
    ISCharacterInfoWindow.instance = o

    o.drawFrame  = false
    o.background = false

    -- Tab infrastructure (populated by shim.addView during createChildren)
    o.tabButtons = {}
    o.subPanels  = {}
    o.tabNames   = {}
    o.tabCount   = 0
    o.activeTab  = 0

    -- pin=true : neutralise l'auto-collapse vanilla (onMouseMoveOutside ne s'active pas)
    o.pin = true

    NR_CollapseUtils.init(o)
    NR_BasePanel.initBase(o)
    return o
end

-- ----------------------------------------------------------------------------------------------------- --
-- Identity
-- ----------------------------------------------------------------------------------------------------- --

function NR_CharInfoPanel:getWindowTitle()
    return ""
end

-- Override vanilla titleBarHeight so uncollapse() and setMaxDrawHeight use our header height.
function NR_CharInfoPanel:titleBarHeight()
    return NR_Config.headerHeight
end

-- ----------------------------------------------------------------------------------------------------- --
-- ISTabPanel shim
-- A lightweight ISPanel with the ISTabPanel API so that vanilla createChildren
-- (and all mod patches such as AutoCook) can call self.panel:addView() as usual.
-- Each addView call creates a NI_SquareButton tab and wires the sub-panel.
-- ----------------------------------------------------------------------------------------------------- --

function NR_CharInfoPanel:_makeShim()
    local outer    = self
    local hh       = NR_Config.headerHeight
    local tabBarH  = NR_Config.tabBarHeight
    local contentW = outer.width
    local contentH = outer.height - hh - tabBarH

    -- Real ISPanel sized to the content area so mods inspecting host.width/height
    -- get sensible values at attach time, not 1×1.
    local shim = ISPanel:new(0, hh + tabBarH, contentW, contentH)
    shim.background = false
    shim.viewList   = {}

    -- Called by vanilla createChildren immediately after ISTabPanel:new()
    shim.initialise      = function(s) ISPanel.initialise(s) end
    shim.setOnTabTornOff = function() end   -- torn-off tabs suppressed in NeatUI
    shim.removeView      = function() end

    -- ISTabPanel API: mods inspect this to size themselves and avoid forcing setWidth.
    shim.getWidthOfAllTabs = function(_)
        local bsz = NR_Config.buttonSize
        local pad = NR_Config.padding
        return pad + outer.tabCount * (bsz + pad)
    end

    shim.addView = function(s, name, view)
        outer.tabCount = outer.tabCount + 1
        local n = outer.tabCount

        -- Position sub-panel below NeatUI header + tab bar. Keep the view's own
        -- dimensions: vanilla views are created at tabTotalWidth, not window width,
        -- and rely on absolute internal layout, so resizing would leave empty space.
        view:setX(0)
        view:setY(hh + tabBarH)
        ISPanel.addChild(outer, view)
        view:setVisible(false)

        -- Tab button: dedicated icon for first vanilla tabs, NeatUI number otherwise
        local texPath = VANILLA_ICONS[n]
        local tex = (texPath and getTexture(texPath))
                    or getTexture("media/ui/NeatRocco/CategoryIcon/Icon_Mechanics.png")
        local btn = NR_TabBar.addButton(outer.tabBar, outer, n, tex, name, false)

        outer.tabButtons[n] = btn
        outer.subPanels[n]  = view
        outer.tabNames[n]   = name
        table.insert(s.viewList, { name = name, view = view })

        -- Run mod compat hooks (see NR_CharInfo/compat/*.lua)
        for _, hook in ipairs(NR_CharInfoPanel.addViewHooks) do
            pcall(hook, view, name, outer)
        end
    end

    shim.getActiveView = function(_)
        return outer.subPanels[outer.activeTab]
    end

    shim.getActiveViewIndex = function(_)
        return outer.activeTab
    end

    shim.getView = function(s, name)
        for _, entry in ipairs(s.viewList) do
            if entry.name == name then return entry.view end
        end
    end

    shim.activateView = function(s, name)
        for i, entry in ipairs(s.viewList) do
            if entry.name == name then outer:switchTab(i); return end
        end
    end

    return shim
end

-- ----------------------------------------------------------------------------------------------------- --
-- Lifecycle
-- ----------------------------------------------------------------------------------------------------- --

function NR_CharInfoPanel:initialise()
    ISCollapsableWindow.initialise(self)
end

function NR_CharInfoPanel:createChildren()
    -- 1. NeatUI header (NR_BasePanel creates self.header)
    NR_BasePanel.createChildren(self)

    local hh      = NR_Config.headerHeight
    local tabBarH = NR_Config.tabBarHeight

    -- 2. Tab bar strip (no vanilla background)
    self.tabBar = NR_TabBar.create(self, hh)

    -- Expose tabHeight so third-party mods that add tabs (PhunMart 2 wallet,
    -- ArmorMakesSense burden panel, etc.) and read self.parent.tabHeight from
    -- their sub-panel prerender get a coherent value.
    self.tabHeight = tabBarH

    -- 3. Shim must exist BEFORE the vanilla chain runs
    self.panel = self:_makeShim()

    -- 4. Intercept ISTabPanel.new for the duration of the vanilla chain.
    --    Vanilla createChildren does: self.panel = ISTabPanel:new(...)
    --    The interceptor returns our shim so that call is a no-op redirect.
    local shimRef = self.panel
    local origNew = ISTabPanel.new
    ISTabPanel.new = function() ISTabPanel.new = origNew; return shimRef end

    -- 4b. Intercept ISHealthPanel.new so vanilla createChildren builds an NR_HealthPanel
    --     as healthView. Same self-restoring pattern as ISTabPanel.new above. NR_HealthPanel
    --     calls ISHealthPanel.createChildren(self) so all mod patches still run.
    local origHealthNew = ISHealthPanel.new
    ISHealthPanel.new = function(_, ...) ISHealthPanel.new = origHealthNew; return NR_HealthPanel:new(...) end

    -- 5. Run vanilla createChildren + all mod patches (AutoCook etc.)
    --    Each self.panel:addView() call goes to shim.addView → wires a tab.
    ISCharacterInfoWindow.createChildren(self)

    ISTabPanel.new = origNew                -- safety restore in case vanilla skipped ISTabPanel:new
    ISHealthPanel.new = origHealthNew       -- safety restore in case vanilla skipped ISHealthPanel:new

    -- 5b. Apply NeatUI scrollbar to the skills sub-panel
    if self.characterView and self.characterView.vscroll then
        NR_ScrollingList.applyNeatStyle(self.characterView.vscroll)
    end

    -- 5c. Replace vanilla collapse/expand ISButton with NI_SquareButton in skills panel.
    --     Preserve the size set by the sub-panel (vanilla or mod-customized, uses a 
    --     smaller button size)
    if self.characterView and self.characterView.buttonList then
        local texDown    = getTexture("media/ui/NeatRocco/ICON/Icon_ArrowDown.png")
        local texRight   = getTexture("media/ui/NeatRocco/ICON/Icon_Arrow_R.png")
        local view       = self.characterView
        for i, oldBtn in ipairs(view.buttonList) do
            local bsz    = oldBtn:getHeight()
            view:removeChild(oldBtn)
            local idx    = i
            local newBtn = NI_SquareButton:new(oldBtn.x, oldBtn.y, bsz, texDown, view, function()
                view.collapse[idx] = not view.collapse[idx]
                view.reloadSkillBar  = true
                view.buttonList[idx]:setIcon(view.collapse[idx] and texRight or texDown)
            end)
            newBtn:initialise()
            newBtn:setActive(true)
            newBtn:setActiveColor(0.95, 0.5, 0.1)
            view:addChild(newBtn)
            view.buttonList[i] = newBtn
        end
    end

    -- 5d. Replace hairButton, beardButton, literatureButton with NI_SquareButtons
    if self.charScreen then
        local view = self.charScreen
        local bsz  = NR_Config.buttonSize

        local function makeNeatBtn(oldBtn, texPath, tipText, cb)
            if not oldBtn then return nil end
            local newBtn = NI_SquareButton:new(oldBtn.x, oldBtn.y, bsz,
                               getTexture(texPath), view, cb)
            newBtn:initialise()
            newBtn:setActive(true)
            newBtn:setActiveColor(0.95, 0.5, 0.1)
            newBtn.tabName = tipText
            view:addChild(newBtn)
            oldBtn:setVisible(false)
            return newBtn
        end

        self._neatHairBtn  = makeNeatBtn(view.hairButton,  "media/ui/NeatRocco/ICON/Icon_Scissors.png",
                                 getText("IGUI_PlayerStats_Change"),
                                 function() ISCharacterScreen.hairMenu(view, self._neatHairBtn) end)
        self._neatBeardBtn = makeNeatBtn(view.beardButton, "media/ui/NeatRocco/ICON/Icon_Razor.png",
                                 getText("IGUI_PlayerStats_Change"),
                                 function() ISCharacterScreen.beardMenu(view, self._neatBeardBtn) end)
        self._neatLitBtn   = makeNeatBtn(view.literatureButton, "media/ui/NeatRocco/ICON/Icon_Book.png",
                                 getText("IGUI_LiteratureUI_Title"),
                                 function() view:onShowLiterature() end)

        -- Hide vanilla buttons before children are drawn each frame
        local origPrerender = view.prerender
        view.prerender = function(v)
            if origPrerender then origPrerender(v) end
            if view.hairButton       then view.hairButton:setVisible(false)       end
            if view.beardButton      then view.beardButton:setVisible(false)      end
            if view.literatureButton then view.literatureButton:setVisible(false) end
        end

        -- Sync NeatUI button positions/visibility after vanilla layout runs
        local origRender = view.render
        view.render = function(v)
            origRender(v)
            if self._neatHairBtn and view.hairButton then
                self._neatHairBtn:setX(view.hairButton.x)
                self._neatHairBtn:setY(view.hairButton.y)
                local hairEnabled = view.hairButton.enable
                self._neatHairBtn.enable  = hairEnabled
                self._neatHairBtn:setActive(hairEnabled)
                self._neatHairBtn.tabName = (not hairEnabled and view.hairButton.tooltip)
                                             or getText("IGUI_PlayerStats_Change")
            end
            if self._neatBeardBtn and view.beardButton then
                self._neatBeardBtn:setX(view.beardButton.x)
                self._neatBeardBtn:setY(view.beardButton.y)
                self._neatBeardBtn:setVisible(view.beardButton:isReallyVisible())
                local beardEnabled = view.beardButton.enable
                self._neatBeardBtn.enable  = beardEnabled
                self._neatBeardBtn:setActive(beardEnabled)
                self._neatBeardBtn.tabName = (not beardEnabled and view.beardButton.tooltip)
                                              or getText("IGUI_PlayerStats_Change")
            end
            if self._neatLitBtn and view.literatureButton then
                self._neatLitBtn:setX(view.literatureButton.x)
                self._neatLitBtn:setY(view.literatureButton.y)
            end
        end
    end

    -- 5e. Apply NeatUI three-patch style to clothingView buttons
    if self.clothingView then
        local view   = self.clothingView
        local btnL   = getTexture("media/ui/NeatUI/Button/Button_FULL_L.png")
        local btnM   = getTexture("media/ui/NeatUI/Button/Button_FULL_M.png")
        local btnR   = getTexture("media/ui/NeatUI/Button/Button_FULL_R.png")
        local fntHgt = getTextManager():getFontHeight(UIFont.Small)

        local function applyThreePatch(btn)
            btn._nrActive = false
            btn._nrTitle  = btn.title or ""
            btn:setTitle("")
            btn:setDisplayBackground(false)
            btn.prerender = function(b)
                local active     = b._nrActive
                local brightness = (b.pressed and 0.3) or (b:isMouseOver() and 0.6) or 0.4
                local r  = active and brightness * 0.5 or brightness
                local g  = active and brightness * 1.6 or brightness
                local bv = active and brightness * 0.5 or brightness
                NeatTool.ThreePatch.drawHorizontal(b, 0, 0, b.width, b.height, btnL, btnM, btnR, 1, r, g, bv)
                local title = b._nrTitle or ""
                local tw    = getTextManager():MeasureStringX(UIFont.Small, title)
                b:drawText(title, math.floor((b.width - tw) / 2), math.floor((b.height - fntHgt) / 2), 1, 1, 1, 1, UIFont.Small)
            end
        end

        for _, btnList in pairs(view.viewButtons) do
            for _, btn in ipairs(btnList) do
                applyThreePatch(btn)
            end
        end
        applyThreePatch(view.toggleAdvBtn)

        -- toggleAdvBtn calls setTitle() when toggling — redirect to _nrTitle
        local origSetTitle = view.toggleAdvBtn.setTitle
        view.toggleAdvBtn.setTitle = function(b, title)
            b._nrTitle = title
            origSetTitle(b, "")
        end

        -- Patch setViewIndex to update _nrActive on view buttons
        local origSetViewIndex = view.setViewIndex
        view.setViewIndex = function(v, index)
            origSetViewIndex(v, index)
            local btnList = view.viewButtons[view.currentViewID]
            if btnList then
                for i, btn in ipairs(btnList) do
                    btn._nrActive = (i == index)
                end
            end
        end

        -- Set initial _nrActive state
        local btnList = view.viewButtons[view.currentViewID]
        if btnList then
            for i, btn in ipairs(btnList) do
                btn._nrActive = (i == view.selectedViewIndex)
            end
        end
    end

    -- 6. Hide vanilla ISCollapsableWindow titlebar children
    if self.resizeWidget   then self.resizeWidget:setVisible(false)   end
    if self.resizeWidget2  then self.resizeWidget2:setVisible(false)  end
    if self.closeButton    then self.closeButton:setVisible(false)    end
    if self.infoButton     then self.infoButton:setVisible(false)     end
    if self.pinButton      then self.pinButton:setVisible(false)      end
    if self.collapseButton then self.collapseButton:setVisible(false) end  -- vanilla button, hidden; NeatUI uses header.collapseButton

    -- 7. Honour vanilla self:setWidth(charScreen.width). Only widen if our NeatUI
    --    icon tab strip is wider than the vanilla layout (rare: icons are narrower
    --    than vanilla text tabs, but possible if many mods add tabs).
    local pad       = NR_Config.padding
    local bsz       = NR_Config.buttonSize
    local tabStripW = pad + self.tabCount * (bsz + pad)
    local initW = math.max(self.width, tabStripW)
    local initH = hh + tabBarH + math.max(self.height, 400)
    self:onResize(initW, initH)

    -- 8. Chain setWidth so header/tabBar follow any width change (sub-panel
    --    setWidthAndParentWidth during render, mod hooks, etc.). Preserve any
    --    existing setWidth (inherited or mod-installed, e.g. ArmorMakesSense's
    --    width clamp) by calling prevSetWidth instead of bypassing to ISUIElement.
    local prevSetWidth = self.setWidth
    self.setWidth = function(panel, w)
        local prevW = panel.width  -- [NR_Patch] capture width before call for change detection
        prevSetWidth(panel, w)
        if NR_CollapseUtils.isBodyVisible(panel) and panel.header and panel.tabBar then
            local actualW = panel.width  -- read after prevSetWidth (may have clamped)
            panel.tabBar:setWidth(actualW)
            panel.header:setWidth(actualW)
            -- [NR_Patch] Fix: ISHealthPanel:update() calls setWidthAndParentWidth() every frame,
            -- which propagates here. calculateLayout() iterates every cell/column/row of the
            -- ISTableLayout and was running every frame on the health tab, causing 1000ms+ spikes.
            -- Only recalculate when the width actually changed.
            if actualW ~= prevW then
                panel.header:calculateLayout(actualW, NR_Config.headerHeight)
            end
        end
    end

    -- 9. Activate first tab
    if self.tabCount > 0 then
        self:switchTab(1)
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Resize (pattern NR_Literature)
-- ----------------------------------------------------------------------------------------------------- --

function NR_CharInfoPanel:onResize(w, h)
    if not NR_CollapseUtils.isBodyVisible(self) then return end
    self:setWidth(w)
    self:setHeight(h)
    self.tabBar:setWidth(w)
    self.header:setWidth(w)
    self.header:calculateLayout(w, NR_Config.headerHeight)
end

-- ----------------------------------------------------------------------------------------------------- --
-- Tab switching
-- ----------------------------------------------------------------------------------------------------- --

function NR_CharInfoPanel:switchTab(n)
    self.activeTab = n
    NR_TabBar.switch(self.tabButtons, self.subPanels, self.tabCount, n)
    self:setInfo(self.subPanels[n] and self.subPanels[n].infoText)
    local jd = getJoypadData(self.playerNum)
    if jd then
        jd.focus = self.subPanels[n]
        updateJoypadFocus(jd)
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Collapse / expand
-- ----------------------------------------------------------------------------------------------------- --

function NR_CharInfoPanel:onClickCollapse() NR_CollapseUtils.onClickCollapse(self) end
function NR_CharInfoPanel:_onHeaderHover()  NR_CollapseUtils.onHeaderHover(self)   end

function NR_CharInfoPanel:update()
    ISPanelJoypad.update(self)
    NR_CollapseUtils.update(self)
end

-- ----------------------------------------------------------------------------------------------------- --
-- Vanilla API preserved
-- toggleView() and isActive() are inherited from ISCharacterInfoWindow.
-- They use self.panel (the shim) so they work without modification.
-- ----------------------------------------------------------------------------------------------------- --

function NR_CharInfoPanel:getInfoText()
    return self._infoText
end

function NR_CharInfoPanel:setInfo(text)
    local newText = (text and text ~= "") and text or nil
    if newText ~= self._infoText then
        if self.header and self.header._infoUI then
            self.header._infoUI:removeFromUIManager()
            self.header._infoUI = nil
        end
        self._infoText = newText
    end
    local btn = self.header and self.header.infoButton
    if btn then
        btn:setVisible(self._infoText ~= nil)
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Layout save / restore (simplified — no torn-off tab support)
-- ----------------------------------------------------------------------------------------------------- --

function NR_CharInfoPanel:SaveLayout(_, layout)
    ISLayoutManager.DefaultSaveWindow(self, layout)
    layout.activeTab = tostring(self.activeTab)
end

function NR_CharInfoPanel:RestoreLayout(_, layout)
    ISLayoutManager.DefaultRestoreWindow(self, layout)
    if layout.activeTab then
        local n = tonumber(layout.activeTab)
        if n and n >= 1 and n <= self.tabCount then
            self:switchTab(n)
        end
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Render
-- ----------------------------------------------------------------------------------------------------- --

function NR_CharInfoPanel:prerender()
    -- NinePatchTexture uses absolute screen coords and bypasses setMaxDrawHeight clipping.
    -- Skip the body background and separator when fully collapsed; header draws its own bg.
    if NR_CollapseUtils.isBodyVisible(self) then
        NR_BasePanel.prerender(self)
        local lineY = NR_Config.headerHeight + NR_Config.tabBarHeight - 1
        self:drawRect(0, lineY, self.width, 1, 1, 0, 0, 0)
    end
end

function NR_CharInfoPanel:render()
    -- Use ISPanelJoypad.render, NOT ISCollapsableWindow.render (which draws the vanilla titlebar)
    ISPanelJoypad.render(self)

    NR_DrawUtils.drawTabTooltips(self, self.tabButtons, self.tabCount)

    -- charScreen button tooltips (hair, beard, literature) — screen-bounded clamping
    local pad = NR_Config.padding
    local function drawBtnTip(btn)
        if not btn or not btn.tabName or not btn:isMouseOver() then return false end
        local tip = btn.tabName
        local tw  = getTextManager():MeasureStringX(UIFont.Small, tip) + 10
        local th  = getTextManager():getFontHeight(UIFont.Small) + 6
        local mx  = self:getMouseX()
        local my  = self:getMouseY()
        local sw  = getCore():getScreenWidth()
        local sh  = getCore():getScreenHeight()
        local ax  = self:getAbsoluteX()
        local ay  = self:getAbsoluteY()
        local tx  = mx + 20
        if ax + tx + tw > sw - pad then tx = math.max(pad, mx - tw - 10) end
        local ty  = my + 20
        if ay + ty + th > sh - pad then ty = math.max(pad, my - th - 10) end
        NR_DrawUtils.drawTooltip(self, tip, tx, ty)
        return true
    end
    if not drawBtnTip(self._neatHairBtn) then
        if not drawBtnTip(self._neatBeardBtn) then
            drawBtnTip(self._neatLitBtn)
        end
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Close
-- ----------------------------------------------------------------------------------------------------- --

function NR_CharInfoPanel:close()
    self:setVisible(false)
    self:removeFromUIManager()
    if JoypadState.players[self.playerNum + 1] then
        if isJoypadFocusOnElementOrDescendant(self.playerNum, self) then
            setJoypadFocus(self.playerNum, nil)
        end
    end
end

-- ----------------------------------------------------------------------------------------------------- --
-- Joypad
-- ----------------------------------------------------------------------------------------------------- --

function NR_CharInfoPanel:onGainJoypadFocus(joypadData)
    self.drawJoypadFocus = true
    if self.subPanels[self.activeTab] then
        joypadData.focus = self.subPanels[self.activeTab]
        updateJoypadFocus(joypadData)
    end
end

function NR_CharInfoPanel:onLoseJoypadFocus(_)
    self.drawJoypadFocus = false
end

function NR_CharInfoPanel:onJoypadDown(button, joypadData)
    if button == Joypad.BButton then self:close(); return end
    ISPanelJoypad.onJoypadDown(self, button, joypadData)
end

function NR_CharInfoPanel:onJoypadDown_Descendant(descendant, button, joypadData)
    if button == Joypad.BButton then self:close(); return end
    if (button == Joypad.LBumper or button == Joypad.RBumper) and self.tabCount >= 2 then
        local n = self.activeTab
        if button == Joypad.LBumper then
            n = (n == 1) and self.tabCount or (n - 1)
        else
            n = (n == self.tabCount) and 1 or (n + 1)
        end
        getSoundManager():playUISound("UIActivateTab")
        self:switchTab(n)
        return
    end
    ISPanelJoypad.onJoypadDown_Descendant(self, descendant, button, joypadData)
end

function NR_CharInfoPanel:isKeyConsumed(_) return false end

function NR_CharInfoPanel:onKeyRelease(key)
    if key == Keyboard.KEY_ESCAPE then self:close(); return true end
end
