-------------------------------------------------------------------------------
-- Skin.lua : WeakAuras-style look for the XayaUI options window (flat dark panes, gold tabs, toolbar + search).
-- Pure cosmetics layered on top of Options.lua through ns.DecorateTrees. Every change is undone when the AceGUI widget is
-- released (AceGUI recycles widgets across addons). Turn it off with /xuiskin (then /reload).
-------------------------------------------------------------------------------
local addonName, ns = ...
local APP = "CueRules"
local ACD = LibStub and LibStub("AceConfigDialog-3.0", true)
if not ACD then return end

local WHITE8 = "Interface\\Buttons\\WHITE8X8"
local GOLD = { 1, 0.82, 0, 1 }
local TH = ns.Theme
if TH then TH.Bind("label", GOLD) end
-- style-sheet color for a class property ({r,g,b,a}); falls back to the given color when Theme.lua is missing
local function TC(class, prop, fb) if TH then return TH.Col(class, prop, fb) end return fb end
-- theme font + size on a fontstring (color is set by the caller)
local function TF(fs) if TH and fs then pcall(TH.Style, fs, nil) end end
local function TR(fs) if TH and fs then pcall(TH.Restore, fs) end end
local function SkinOn() return not (CueRulesDB and CueRulesDB.ui and CueRulesDB.ui.skinOff) end
-- window opacity (0.1 - 1). /xuiskin alpha 0.4 changes it; takes effect on the next redraw / reopen.
local function Pad() local u = CueRulesDB and CueRulesDB.ui; return math.max(0, math.min(30, tonumber(u and u.skinPad) or 8)) end
local function A() local u = CueRulesDB and CueRulesDB.ui; return (u and tonumber(u.skinAlpha)) or 0.62 end

SLASH_XUISKIN1 = "/xuiskin"
SlashCmdList["XUISKIN"] = function(msg)
    if not CueRulesDB then return end
    CueRulesDB.ui = CueRulesDB.ui or {}
    local pd = tostring(msg or ""):match("pad%s+(%d+)")
    if pd then
        CueRulesDB.ui.skinPad = math.max(0, math.min(30, tonumber(pd)))
        print("|cffffd100XayaUI|r right-pane gutter " .. CueRulesDB.ui.skinPad .. "px (reopen the window to apply).")
        return
    end
    local v = tostring(msg or ""):match("alpha%s+([%d%.]+)")
    if v then
        v = math.max(0.1, math.min(1, tonumber(v) or 0.5))
        CueRulesDB.ui.skinAlpha = v
        print("|cffffd100XayaUI|r window opacity " .. v .. " (reopen the window to apply).")
        return
    end
    CueRulesDB.ui.skinOff = (not CueRulesDB.ui.skinOff) or nil
    print("|cffffd100XayaUI|r window skin " .. (CueRulesDB.ui.skinOff and "OFF" or "ON") .. " - type /reload to apply.")
end

-- flat 1px-bordered box drawn with plain textures (inset = { l, r, t, b })
local function Flat(f, bg, border, inset)
    local t = f.xuiFlat
    if not t then
        t = { bg = f:CreateTexture(nil, "BACKGROUND", nil, -3), e = {} }
        for i = 1, 4 do t.e[i] = f:CreateTexture(nil, "BACKGROUND", nil, -2) end
        f.xuiFlat = t
    end
    local l, r, tp, b = 0, 0, 0, 0
    if inset then l, r, tp, b = inset[1], inset[2], inset[3], inset[4] end
    t.bg:ClearAllPoints(); t.bg:SetPoint("TOPLEFT", l, -tp); t.bg:SetPoint("BOTTOMRIGHT", -r, b)
    t.e[1]:ClearAllPoints(); t.e[1]:SetPoint("TOPLEFT", l, -tp); t.e[1]:SetPoint("TOPRIGHT", -r, -tp); t.e[1]:SetHeight(1)
    t.e[2]:ClearAllPoints(); t.e[2]:SetPoint("BOTTOMLEFT", l, b); t.e[2]:SetPoint("BOTTOMRIGHT", -r, b); t.e[2]:SetHeight(1)
    t.e[3]:ClearAllPoints(); t.e[3]:SetPoint("TOPLEFT", l, -tp); t.e[3]:SetPoint("BOTTOMLEFT", l, b); t.e[3]:SetWidth(1)
    t.e[4]:ClearAllPoints(); t.e[4]:SetPoint("TOPRIGHT", -r, -tp); t.e[4]:SetPoint("BOTTOMRIGHT", -r, b); t.e[4]:SetWidth(1)
    t.bg:SetColorTexture(bg[1], bg[2], bg[3], bg[4] or 1); t.bg:Show()
    for _, e in ipairs(t.e) do e:SetColorTexture(border[1], border[2], border[3], border[4] or 1); e:Show() end
end
local function FlatHide(f)
    local t = f and f.xuiFlat
    if not t then return end
    t.bg:Hide(); for _, e in ipairs(t.e) do e:Hide() end
end

-- hide every texture of a frame except the ones listed in keep (remembered, so it can be undone)
local function HideRegions(f, keep)
    if f.xuiHidden then return end
    f.xuiHidden = {}
    for _, rg in ipairs({ f:GetRegions() }) do
        if rg.GetObjectType and rg:GetObjectType() == "Texture" and rg ~= keep and not (f.xuiFlat and (rg == f.xuiFlat.bg)) then
            local isEdge
            if f.xuiFlat then for _, e in ipairs(f.xuiFlat.e) do if e == rg then isEdge = true end end end
            if not isEdge then f.xuiHidden[#f.xuiHidden + 1] = { rg, rg:GetAlpha() }; rg:SetAlpha(0) end
        end
    end
end
local function ShowRegions(f)
    if not f.xuiHidden then return end
    for _, p in ipairs(f.xuiHidden) do p[1]:SetAlpha(p[2]) end
    f.xuiHidden = nil
end

-- run restoreFn once when the widget is released (the wrapper is installed only once per widget)
local function OnRelease(w, restoreFn)
    w.xuiRestore = restoreFn
    if w.xuiRelWrapped then return end
    w.xuiRelWrapped = true
    local orig = w.OnRelease
    w.OnRelease = function(self, ...)
        local r = self.xuiRestore
        self.xuiRestore = nil
        if r then pcall(r, self) end
        if orig then return orig(self, ...) end
    end
end

-- several independent restore functions per widget (the helper above keeps only one, and SkinInline re-registers it every pass)
local function AddRest(w, key, fn)
    w.xuiRest = w.xuiRest or {}
    w.xuiRest[key] = fn
    if w.xuiRestWrapped then return end
    w.xuiRestWrapped = true
    local orig = w.OnRelease
    w.OnRelease = function(self, ...)
        local r = self.xuiRest
        self.xuiRest = nil
        if r then for _, f in pairs(r) do pcall(f, self) end end
        if orig then return orig(self, ...) end
    end
end

-------------------------------------------------------------------------------
-- Toolbar: New Rule / Import / Lock Positions + search box (filters the rule list by name)
-------------------------------------------------------------------------------
ns.treeFilter = ""
local filterStamp = 0

local function ToolButton(parent, icon, label, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(20)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetSize(16, 16); b.icon:SetPoint("LEFT", 0, 0); b.icon:SetTexture(icon)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.text:SetPoint("LEFT", b.icon, "RIGHT", 4, 0)
    b.text:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", function(self) self.text:SetTextColor(1, 1, 1) end)
    b:SetScript("OnLeave", function(self) if self.active then self.text:SetTextColor(1, 1, 1) else self.text:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) end end)
    function b:SetActive(on)
        self.active = on and true or false
        -- lit = the same boxed look as a selected tab (color alone was lost under the theme's text color)
        if self.active then
            Flat(self, TC("xui-tab-selected", "bg", { 0.12, 0.05, 0.2, 0.9 }), TC("xui-tab-selected", "border", { 0.75, 0.4, 1, 1 }), { -5, -5, -2, -2 })
            self.text:SetTextColor(1, 1, 1)
        else
            FlatHide(self)
            self.text:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        end
    end
    function b:SetLabel(t) self.text:SetText(t); self:SetWidth(20 + self.text:GetStringWidth() + 6) end
    b:SetLabel(label)
    return b
end

-- Rule search box: nested at the top of the All Rules sidebar, above the Loaded row. Typing filters the rule lists (ns.treeFilter).
local function MakeSearchBox(parent)
    local sb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    sb:SetAutoFocus(false); sb:SetHeight(20)
    sb:SetFontObject("ChatFontNormal")
    sb.hint = sb:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sb.hint:SetPoint("LEFT", 6, 0); sb.hint:SetText("Search rules")
    local function refreshHint(self) sb.hint:SetShown(self:GetText() == "" and not self:HasFocus()) end
    sb:SetScript("OnEditFocusGained", refreshHint)
    sb:SetScript("OnEditFocusLost", refreshHint)
    sb:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    sb:SetScript("OnTextChanged", function(self)
        refreshHint(self)
        local q = (self:GetText() or ""):lower()
        if q == ns.treeFilter then return end
        ns.treeFilter = q
        ns.treeFilterOpen = (q ~= "") or nil
        filterStamp = filterStamp + 1
        local stamp = filterStamp
        C_Timer.After(0.25, function() if stamp == filterStamp and ns.UI and ns.UI.Notify then ns.UI.Notify() end end)
    end)
    sb:SetText(ns.treeFilter or "")
    refreshHint(sb)
    return sb
end

local function EnsureToolbar(of)
    local fr = of.frame
    local bar = fr.xuiToolbar
    if not bar then
        bar = CreateFrame("Frame", nil, fr)
        bar:SetFrameLevel(fr:GetFrameLevel() + 5)
        bar:SetHeight(22)
        local nr = ToolButton(bar, "Interface\\Buttons\\UI-PlusButton-Up", "New Rule", function() if ns.UI and ns.UI.NewRule then ns.UI.NewRule() end end)
        nr:SetPoint("LEFT", bar, "LEFT", 0, 0)
        local im = ToolButton(bar, "Interface\\Icons\\INV_Scroll_03", "Import", function() if ns.UI and ns.UI.Import then ns.UI.Import() end end)
        im:SetPoint("LEFT", nr, "RIGHT", 14, 0)
        local cr = ToolButton(bar, "Interface\\Icons\\INV_Misc_Book_09", "Class/Spec Rule Creator", function() if ns.UI and ns.UI.Creator then ns.UI.Creator() end end)
        cr:SetPoint("LEFT", im, "RIGHT", 14, 0)
        local ex = ToolButton(bar, 132763, "Export", function() if ns.UI and ns.UI.Export then ns.UI.Export() end end)
        ex:SetPoint("LEFT", cr, "RIGHT", 14, 0)
        -- no Cursor button here: the Cursor options live only on the QoL UI Updates tab (Xaya, 2026-11-01)
        local lk = ToolButton(bar, "Interface\\PetBattles\\PetBattle-LockIcon", "Lock Positions", function()
            if ns.ToggleUnlock then ns.ToggleUnlock() end
            if ns.UI and ns.UI.Notify then ns.UI.Notify() end
        end)
        lk:SetPoint("LEFT", ex, "RIGHT", 14, 0)
        bar.lock = lk
        lk:Hide()   -- the Unlock Positions button is gone from the top bar (every level has its own in-line unlock); the object stays so nothing that sets its label breaks
        -- Settings sits at the far right of the same line, cog icon on its left
        local st = ToolButton(bar, "Interface\\Icons\\INV_Misc_Gear_01", "Settings", function() if ns.UI and ns.UI.Settings then ns.UI.Settings() end end)
        st:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
        bar.settingsBtn = st
        fr.xuiToolbar = bar
    end
    return bar
end

-------------------------------------------------------------------------------
-- Per-widget skins
-------------------------------------------------------------------------------
local function SkinFrame(of)
    local fr = of.frame
    if not fr or not fr.SetBackdrop then return end
    local collapsed = of.xuiChrome and of.xuiChrome.collapsed
    if not of.xuiSkinFrame then
        of.xuiSkinFrame = true
        of.xuiOrigBackdrop = fr:GetBackdrop()
        local c = of.content
        of.xuiOrigContent = {}
        for i = 1, c:GetNumPoints() do of.xuiOrigContent[i] = { c:GetPoint(i) } end
        of.xuiOrigTitle = { of.titletext:GetPoint(1) }
        OnRelease(of, function(self)
            self.xuiSkinFrame = nil
            local f = self.frame
            f.xuiBDset = nil
            if self.xuiOrigBackdrop then f:SetBackdrop(self.xuiOrigBackdrop) end
            f:SetBackdropColor(0, 0, 0, 1); f:SetBackdropBorderColor(1, 1, 1, 1)
            for _, rg in ipairs({ f:GetRegions() }) do if rg.xuiWasTitle then rg:SetAlpha(1); rg.xuiWasTitle = nil end end
            if f.xuiTitleBar then f.xuiTitleBar:Hide() end
            if f.xuiDrag then f.xuiDrag:Hide() end
            if f.xuiToolbar then f.xuiToolbar:Hide() end
            local c2 = self.content
            c2:ClearAllPoints()
            for _, p in ipairs(self.xuiOrigContent or {}) do c2:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
            local o = self.xuiOrigTitle
            if o and o[1] then self.titletext:ClearAllPoints(); self.titletext:SetPoint(o[1], o[2], o[3], o[4], o[5]) end
            self.titletext:SetTextColor(1, 0.82, 0); TR(self.titletext)
        end)
    end
    if not collapsed then
        if not fr.xuiBDset then
            fr.xuiBDset = true
            fr:SetBackdrop({ bgFile = WHITE8, edgeFile = WHITE8, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
        end
        local wb, wbd = TC("xui-window", "bg", { 0.06, 0.06, 0.06, 1 }), TC("xui-window", "border", { 0.32, 0.32, 0.32, 1 })
        fr:SetBackdropColor(wb[1], wb[2], wb[3], A())
        fr:SetBackdropBorderColor(wbd[1], wbd[2], wbd[3], 1)
    end
    -- title strip
    for _, rg in ipairs({ fr:GetRegions() }) do
        if rg.GetObjectType and rg:GetObjectType() == "Texture" and rg:GetTexture() == 131080 then rg:SetAlpha(0); rg.xuiWasTitle = true end
    end
    if not fr.xuiTitleBar then
        fr.xuiTitleBar = fr:CreateTexture(nil, "ARTWORK")
        fr.xuiTitleBar:SetColorTexture(0.13, 0.13, 0.13, 1)
    end
    do local tb = TC("xui-titlebar", "bg", { 0.13, 0.13, 0.13, 1 }); fr.xuiTitleBar:SetColorTexture(tb[1], tb[2], tb[3], tb[4] or 1) end
    fr.xuiTitleBar:ClearAllPoints()
    fr.xuiTitleBar:SetPoint("TOPLEFT", 1, -1); fr.xuiTitleBar:SetPoint("TOPRIGHT", -1, -1); fr.xuiTitleBar:SetHeight(28)
    fr.xuiTitleBar:SetShown(not collapsed)
    -- the whole ribbon moves the window (AceGUI's own handle is only as wide as the "XayaUI" text)
    if not fr.xuiDrag then
        local d = CreateFrame("Frame", nil, fr)
        fr.xuiDrag = d
        d:EnableMouse(true)
        d:SetScript("OnMouseDown", function(self) self:GetParent():StartMoving(); local g = LibStub and LibStub("AceGUI-3.0", true); if g then g:ClearFocus() end end)
        d:SetScript("OnMouseUp", function(self)
            local f = self:GetParent()
            f:StopMovingOrSizing()
            local st = f.obj and (f.obj.status or f.obj.localstatus)
            if st then st.width, st.height, st.top, st.left = f:GetWidth(), f:GetHeight(), f:GetTop(), f:GetLeft() end
        end)
    end
    fr.xuiDrag:ClearAllPoints()
    fr.xuiDrag:SetPoint("TOPLEFT", fr, "TOPLEFT", 1, -1); fr.xuiDrag:SetPoint("TOPRIGHT", fr, "TOPRIGHT", -1, -1); fr.xuiDrag:SetHeight(28)
    fr.xuiDrag:SetFrameLevel(fr:GetFrameLevel() + 2)   -- under the close / collapse buttons (+10)
    fr.xuiDrag:SetShown(not collapsed)
    of.titletext:ClearAllPoints(); of.titletext:SetPoint("TOP", fr, "TOP", 0, -9)
    do local tt = TC("xui-titlebar", "text", GOLD); of.titletext:SetTextColor(tt[1], tt[2], tt[3]); TF(of.titletext) end
    -- bottom banner: the status container becomes a flat full-width band (no box), the Close button sits inside it
    do
        local sb = of.statusbg
        if sb then
            if sb.SetBackdrop then sb:SetBackdrop(nil) end
            sb:ClearAllPoints(); sb:SetPoint("BOTTOMLEFT", fr, "BOTTOMLEFT", 1, 1); sb:SetPoint("BOTTOMRIGHT", fr, "BOTTOMRIGHT", -1, 1); sb:SetHeight(36)
            if not sb.xuiBand then
                sb.xuiBand = sb:CreateTexture(nil, "BACKGROUND")
                sb.xuiBandLine = sb:CreateTexture(nil, "BORDER")
            end
            local tb = TC("xui-titlebar", "bg", { 0.13, 0.13, 0.13, 1 })
            local bd = TC("xui-window", "border", { 0.32, 0.32, 0.32, 1 })
            sb.xuiBand:SetAllPoints(); sb.xuiBand:SetColorTexture(tb[1], tb[2], tb[3], tb[4] or 1)
            sb.xuiBandLine:ClearAllPoints(); sb.xuiBandLine:SetPoint("TOPLEFT"); sb.xuiBandLine:SetPoint("TOPRIGHT"); sb.xuiBandLine:SetHeight(1)
            sb.xuiBandLine:SetColorTexture(bd[1], bd[2], bd[3], 1)
            sb:SetShown(not collapsed)
            local cb = of.closebutton
            if cb then cb:ClearAllPoints(); cb:SetPoint("RIGHT", sb, "RIGHT", -30, 0) end
        end
    end
    -- toolbar (content moves down to make room)
    local bar = EnsureToolbar(of)
    bar:ClearAllPoints(); bar:SetPoint("TOPLEFT", fr, "TOPLEFT", 17, -34); bar:SetPoint("TOPRIGHT", fr, "TOPRIGHT", -17, -34)
    bar:SetShown(not collapsed)
    if bar.cursorBtn then bar.cursorBtn:SetActive(ns.pageOpen == "cursor") end
    if bar.settingsBtn then bar.settingsBtn:SetActive(ns.pageOpen == "settings") end   -- the Settings button is lit while the settings pages are open
    bar.lock:SetLabel(ns.unlocked and "Lock Positions" or "Unlock Positions")
    local c = of.content
    local p1 = { c:GetPoint(1) }
    if p1[5] ~= -62 then
        c:ClearAllPoints(); c:SetPoint("TOPLEFT", fr, "TOPLEFT", 17, -62); c:SetPoint("BOTTOMRIGHT", fr, "BOTTOMRIGHT", -17, 40)
    end
end

local function PaneColors(frame, bg, border)
    if frame and frame.SetBackdropColor then frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4]); frame:SetBackdropBorderColor(border[1], border[2], border[3], 1) end
end

-- /xui perf: time every pane / tab switch (OnGroupSelected) so the slow or late step can be named
local function TraceGroupFire(w, what)
    if w.xuiFireTraced then return end
    w.xuiFireTraced = true
    local orig = w.Fire
    w.Fire = function(self, ev, ...)
        if ev ~= "OnGroupSelected" or not (ns.perf and ns.perf.show) then return orig(self, ev, ...) end
        ns.Trace("click"); ns.Trace(what .. " switch -> " .. tostring((...)))
        local t0 = debugprofilestop()
        local r1, r2 = orig(self, ev, ...)
        ns.Trace(string.format("%s switch built in %.0f ms", what, debugprofilestop() - t0))
        if C_Timer then C_Timer.After(0, function() ns.Trace("next frame after " .. what .. " switch (anything below this ran late)") end) end
        return r1, r2
    end
    AddRest(w, "firetrace", function(self) rawset(self, "Fire", nil); self.xuiFireTraced = nil end)
end

local function SkinTabGroup(w)
    TraceGroupFire(w, "tab")
    do local pb, pd = TC("xui-pane", "bg", { 0.04, 0.04, 0.04, 1 }), TC("xui-pane", "border", { 0.3, 0.3, 0.3, 1 }); PaneColors(w.border, { pb[1], pb[2], pb[3], A() * 0.6 }, pd) end
    for _, tab in ipairs(w.tabs or {}) do
        if tab:IsShown() then
            for _, k in ipairs({ "Left", "Middle", "Right", "LeftDisabled", "MiddleDisabled", "RightDisabled" }) do
                if tab[k] then tab[k]:SetAlpha(0) end
            end
            if tab.HighlightTexture then tab.HighlightTexture:SetAlpha(0) end
            local sel = tab.selected and true or false
            -- AceGUI tabs overlap by ~10px (the Blizzard art has transparent edges), so the box is inset to keep each border whole
            local tcl = sel and "xui-tab-selected" or "xui-tab"
            Flat(tab, TC(tcl, "bg", { 0.03, 0.03, 0.03, 0.7 }), TC(tcl, "border", { 0.22, 0.22, 0.22, 1 }), { 9, 9, 6, 3 })
            local fs = tab:GetFontString()
            if fs then local c = TC(tcl, "text", GOLD); fs:SetTextColor(c[1], c[2], c[3]); TF(fs) end
        end
    end
    OnRelease(w, function(self)
        PaneColors(self.border, { 0.1, 0.1, 0.1, 0.5 }, { 0.4, 0.4, 0.4 })
        for _, tab in ipairs(self.tabs or {}) do
            for _, k in ipairs({ "Left", "Middle", "Right", "LeftDisabled", "MiddleDisabled", "RightDisabled" }) do
                if tab[k] then tab[k]:SetAlpha(1) end
            end
            if tab.HighlightTexture then tab.HighlightTexture:SetAlpha(1) end
            FlatHide(tab)
        end
    end)
end

-- All Rules band: the All Rules block (its row, its folders / rules when expanded, and Auto-Populate) is its own band at the
-- bottom of the same tree frame. AceGUI chains every row to the row above it, so the band is cut loose from that chain and
-- anchored to the frame's bottom edge instead (its position depends only on its own height, never on the rows above it);
-- the rows above keep AceGUI's chain. The band is laid out inside RefreshTree, right after the rows are rebuilt and resized,
-- so no frame is ever drawn in the old position, and every refresh first puts the rows back on AceGUI's own chain so a
-- recycled row can never keep a stale offset.
local SEARCH_PAD = 36   -- room kept above the first row for the search box
local function TopPad(w)
    local shown = (w.xuiSearchBox and w.xuiSearchBox:IsShown()) or (w.xuiSelBar and w.xuiSelBar:IsShown())
    return shown and SEARCH_PAD or 10
end
local function ResetChain(w)
    local tf, btns = w.treeframe, w.buttons
    if not tf or not btns then return end
    local r = w.showscroll and -22 or 0
    local pad = TopPad(w)
    for i, b in ipairs(btns) do
        b:ClearAllPoints()
        if i == 1 then
            b:SetPoint("TOPRIGHT", tf, "TOPRIGHT", r, -pad)
            b:SetPoint("TOPLEFT", tf, "TOPLEFT", 0, -pad)
        else
            b:SetPoint("TOPRIGHT", btns[i - 1], "BOTTOMRIGHT", 0, 0)
            b:SetPoint("TOPLEFT", btns[i - 1], "BOTTOMLEFT", 0, 0)
        end
    end
end
-- Smooth scrolling for the sidebar: AceGUI scrolls the tree by whole ROWS (each notch of the wheel / step of the scrollbar redraws the
-- list one row further), which feels like paging. After a refresh that moved the list by a few rows, slide the first row (the rest are
-- chained to it) from where the old top row was back to its slot over ~0.1 s. The text is already in its final place, only the
-- anchor offset of the first row is animated, and ResetChain puts the real anchors back at the end (and on every refresh).
local SCROLL_ANIM = 0.10
local function SmoothScroll(w)
    local tf, btns = w.treeframe, w.buttons
    if not (tf and btns and btns[1] and w.showscroll and SkinOn()) then return end
    local st = w.status or w.localstatus
    local v = st and st.scrollvalue
    if not v then return end
    local last = w.xuiLastScroll
    w.xuiLastScroll = v
    if last == nil or last == v or math.abs(v - last) > 4 then return end
    local b1 = btns[1]
    if not b1:IsShown() then return end
    local off0 = b1:GetHeight() * math.min(math.abs(v - last), 3) * ((v > last) and -1 or 1)   -- down: start one row lower; up: one row higher
    local drv = w.xuiSmoothDrv
    if not drv then
        drv = CreateFrame("Frame", nil, tf)
        w.xuiSmoothDrv = drv
        drv:Hide()
    end
    local t = 0
    local function Put(off)
        local pad, r = TopPad(w), w.showscroll and -22 or 0
        b1:ClearAllPoints()
        b1:SetPoint("TOPRIGHT", tf, "TOPRIGHT", r, -pad + off)
        b1:SetPoint("TOPLEFT", tf, "TOPLEFT", 0, -pad + off)
    end
    if tf.SetClipsChildren then tf:SetClipsChildren(true) end
    Put(off0)
    drv:SetScript("OnUpdate", function(self, dt)
        t = t + (dt or 0)
        if t >= SCROLL_ANIM or not b1:IsShown() or not tf:IsVisible() then
            self:SetScript("OnUpdate", nil); self:Hide()
            pcall(ResetChain, w)
            return
        end
        local k = 1 - t / SCROLL_ANIM
        Put(off0 * k * k)   -- ease out
    end)
    drv:Show()
end

-- the rule tree (the one that has the All Rules row) carries the search box at its top
local function EnsureTreeSearch(w)
    local has = false
    for _, b in ipairs(w.buttons or {}) do local uvb = tostring(b.uniquevalue or ""); if b:IsShown() and (uvb == "all" or uvb == "loaded") then has = true; break end end
    if not has then   -- the All Rules row may be scrolled out of view or not drawn yet: look at the tree data itself
        for _, t in ipairs(w.tree or {}) do if type(t) == "table" and (t.value == "all" or t.value == "loaded") then has = true; break end end
    end
    has = has and SkinOn()
    local sb = w.xuiSearchBox
    if has and not sb and w.treeframe then
        sb = MakeSearchBox(w.treeframe)
        sb:SetFrameLevel(w.treeframe:GetFrameLevel() + 3)
        sb:SetPoint("TOPLEFT", w.treeframe, "TOPLEFT", 12, -8)
        sb:SetPoint("TOPRIGHT", w.treeframe, "TOPRIGHT", -12, -8)
        w.xuiSearchBox = sb
    end
    -- multi-select bar: while rules are selected it replaces the search box with "Delete N" / "Clear" right where the list is
    local nSel = (has and ns.MultiCount and ns.MultiCount()) or 0
    local bar = w.xuiSelBar
    if has and not bar and w.treeframe then
        bar = CreateFrame("Frame", nil, w.treeframe)
        bar:SetHeight(22)
        bar:SetFrameLevel(w.treeframe:GetFrameLevel() + 4)
        bar:SetPoint("TOPLEFT", w.treeframe, "TOPLEFT", 12, -7)
        bar:SetPoint("TOPRIGHT", w.treeframe, "TOPRIGHT", -12, -7)
        bar.clr = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
        bar.clr:SetSize(58, 22); bar.clr:SetPoint("RIGHT", 0, 0); bar.clr:SetText("Clear")
        bar.clr:SetScript("OnClick", function() if ns.MultiClear then ns.MultiClear() end end)
        bar.mv = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
        bar.mv:SetSize(64, 22); bar.mv:SetPoint("RIGHT", bar.clr, "LEFT", -4, 0); bar.mv:SetText("Move to...")
        bar.mv:SetScript("OnClick", function(self) if ns.MultiMoveMenu then ns.MultiMoveMenu(self) end end)
        bar.del = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
        bar.del:SetHeight(22); bar.del:SetPoint("LEFT", 0, 0); bar.del:SetPoint("RIGHT", bar.mv, "LEFT", -4, 0)
        bar.del:SetScript("OnClick", function() if ns.MultiDelete then ns.MultiDelete() end end)
        w.xuiSelBar = bar
    end
    if bar then
        -- same flat look as every other button (the red Blizzard art is hidden); Delete keeps the red primary tint
        for _, key in ipairs({ "del", "mv", "clr" }) do
            local b = bar[key]
            if b then
                if not b.xuiFlatBtn then
                    b.xuiFlatBtn = true
                    HideRegions(b, nil)
                    local ht = b:GetHighlightTexture(); if ht then ht:SetAlpha(0) end
                    local fs = b:GetFontString(); if fs then fs:ClearAllPoints(); fs:SetPoint("CENTER") end
                    b:HookScript("OnEnter", function(self) local f = self:GetFontString(); if f then f:SetTextColor(1, 1, 1) end end)
                    b:HookScript("OnLeave", function(self) local f = self:GetFontString(); if f then f:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) end end)
                end
                local cl = (key == "del") and "xui-button-primary" or "xui-button"
                Flat(b, TC(cl, "bg", { 0.04, 0.04, 0.04, 0.7 }), TC(cl, "border", { 0.25, 0.25, 0.25, 1 }))
                local fs = b:GetFontString()
                if fs then local c = TC(cl, "text", GOLD); fs:SetTextColor(c[1], c[2], c[3]); TF(fs) end
            end
        end
        bar:SetShown(nSel > 0)
        if nSel > 0 then bar.del:SetText(("Delete %d"):format(nSel)) end
    end
    if sb then sb:SetShown(has and nSel == 0) end
end

local function PartitionAllRules(w)
    local tf = w.treeframe
    if not tf or not w.buttons then return end
    EnsureTreeSearch(w)
    local pad = TopPad(w)
    if w.xuiPart or pad ~= 10 or w.xuiTopApplied then ResetChain(w); w.xuiPart = nil; w.xuiTopApplied = (pad ~= 10) and pad or nil end
    if not SkinOn() or w.showscroll then return end   -- scrolling list: rows stay in AceGUI's own order
    local btns = {}
    for _, b in ipairs(w.buttons) do if b:IsShown() then btns[#btns + 1] = b end end
    local idx
    for i, b in ipairs(btns) do if tostring(b.uniquevalue or "") == "all" then idx = i end end
    if not idx or idx == 1 then return end
    local topH, botH = pad, 0
    for i, b in ipairs(btns) do if i < idx then topH = topH + b:GetHeight() else botH = botH + b:GetHeight() end end
    if topH + botH + 8 >= tf:GetHeight() then return end   -- no spare room: the band simply follows the rows above it
    local first = btns[idx]
    first:ClearAllPoints()
    first:SetPoint("TOPRIGHT", tf, "BOTTOMRIGHT", 0, botH + 8)
    first:SetPoint("TOPLEFT", tf, "BOTTOMLEFT", 0, botH + 8)
    w.xuiPart = true
end

local function SkinTree(w)
    TraceGroupFire(w, "tree")
    PaneColors(w.treeframe, { 0.03, 0.03, 0.03, A() * 0.6 }, { 0.3, 0.3, 0.3 })
    -- Dragging the sidebar separator blanked the whole window. Run AceGUI's release handler guarded: an error is printed (so it can be
    -- reported) and the options window is rebuilt, instead of leaving the half-laid-out blank window.
    do
        local dr = w.dragger
        if dr and not dr.xuiSafe then
            dr.xuiSafe = true
            local orig = dr:GetScript("OnMouseUp")
            if orig then
                dr:SetScript("OnMouseUp", function(f, ...)
                    local ok, err = pcall(orig, f, ...)
                    if not ok then
                        ns.Print("sidebar resize error (please report): " .. tostring(err))
                        if ns.UI and ns.UI.Notify then pcall(ns.UI.Notify) end
                    end
                end)
            end
        end
    end
    if not w.xuiSelHooked then
        w.xuiSelHooked = true
        -- AceConfigDialog re-selects the current row after EVERY change (rebuild). The stock Select also opens every group on the way
        -- to it and scrolls to it. Re-selecting the row that is already selected now keeps the sidebar exactly as the user left it:
        -- open groups stay as they are (All Rules does not pop open) and the list does not jump.
        local origSelect = w.Select
        w.Select = function(self, uv, ...)
            local st = self.status or self.localstatus
            if SkinOn() and st and st.selected ~= nil and st.selected == uv then
                self.filter = false
                local moved = self.xuiLastSelUV ~= uv   -- a genuinely new selection still scrolls into view; a rebuild does not
                self.xuiLastSelUV = uv
                self:RefreshTree(moved and true or nil)
                if ns.Trace then ns.Trace("tree re-select, pane rebuild") end
                self:Fire("OnGroupSelected", uv)
                return
            end
            self.xuiLastSelUV = uv
            if ns.Trace then ns.Trace("tree new selection") end
            return origSelect(self, uv, ...)
        end
        AddRest(w, "sel", function(self) self.Select = origSelect; self.xuiSelHooked = nil end)
    end
    if not w.xuiPartHooked then   -- re-partition inside every refresh (outermost wrapper: runs after Options.lua's row decorating)
        w.xuiPartHooked = true
        local origRefresh = w.RefreshTree
        w.RefreshTree = function(self, ...)
            if ns.Trace then ns.Trace("tree RefreshTree") end
            -- AceGUI sizes its scroll window assuming 18px rows, but ours are taller and of different heights. So we choose the number
            -- of visible lines ourselves: refresh with a pretend height, measure the rows that really got drawn, and adjust until they
            -- fit between the top of the list and the Addon Info link. The scrollbar then always covers every row (the last rows can
            -- be scrolled into view because the line count is a fit for the rows actually on screen).
            local tf = self.treeframe
            local args = { ... }
            if not (SkinOn() and tf and tf:GetBottom()) then
                local ok, err = pcall(origRefresh, self, ...)
                if not ok then error(err, 0) end
                pcall(PartitionAllRules, self)
                return
            end
            local realH = tf:GetHeight() or 0
            local floorY = tf:GetBottom()
            local lk = ns.infoLink
            if lk and lk:IsShown() and lk:GetTop() then floorY = math.max(floorY, lk:GetTop() + 8) end
            local reserve = math.max(0, floorY - tf:GetBottom())
            local function run(lines)
                tf.GetHeight = function() return lines * 18 + 20.5 end
                local ok, err = pcall(origRefresh, self, unpack(args))
                tf.GetHeight = nil
                if not ok then error(err, 0) end
                local total, cnt = 0, 0
                for _, b in ipairs(self.buttons or {}) do
                    if b:IsShown() then total = total + b:GetHeight(); cnt = cnt + 1 end
                end
                return total, cnt
            end
            if realH <= 60 then
                local ok, err = pcall(origRefresh, self, ...)
                if not ok then error(err, 0) end
                pcall(PartitionAllRules, self)
                return
            end
            local avail = realH - reserve - TopPad(self) - 6
            local lines = math.max(1, self.xuiLines or math.floor((avail - 10) / 18))
            local total, cnt = run(lines)
            -- grow while there is spare room and more rows exist than are drawn (a scrollbar max above 0 means rows are left over)
            for _ = 1, 3 do
                local _, mx = self.scrollbar and self.scrollbar:GetMinMaxValues()
                if cnt > 0 and total < avail - 40 and (mx or 0) > 0 then
                    lines = lines + math.max(1, math.floor((avail - total) / (total / cnt)))
                    total, cnt = run(lines)
                else break end
            end
            -- shrink until what is drawn fits
            for _ = 1, 8 do
                if total > avail and lines > 1 then
                    lines = math.max(1, math.min(lines - 1, cnt - 1))
                    total, cnt = run(lines)
                else break end
            end
            self.xuiLines = lines
            if tf.SetClipsChildren then tf:SetClipsChildren(true) end
            pcall(PartitionAllRules, self)
            pcall(SmoothScroll, self)
        end
    end
    pcall(PartitionAllRules, w)
    -- wider gutter between the right pane's border and its text / controls (AceGUI's default is 10px)
    local pad = Pad()
    if w.xuiPadApplied ~= pad and w.content and w.border then
        w.content:ClearAllPoints()
        w.content:SetPoint("TOPLEFT", w.border, "TOPLEFT", 10 + pad, -(10 + pad))
        w.content:SetPoint("BOTTOMRIGHT", w.border, "BOTTOMRIGHT", -(10 + pad), 10 + pad)
        w.xuiPadApplied = pad
    end
    PaneColors(w.border, { 0.04, 0.04, 0.04, A() * 0.6 }, { 0.3, 0.3, 0.3 })
    for _, b in ipairs(w.buttons or {}) do
        local ht = b:GetHighlightTexture()
        if ht then
            if not b.xuiHT then b.xuiHT = { ht:GetTexture(), { ht:GetVertexColor() }, ht:GetBlendMode() } end
            ht:SetTexture(WHITE8); ht:SetVertexColor(0.75, 0.25, 1, 0.35); ht:SetBlendMode("BLEND")
            -- AceGUI's highlight texture is both the mouse-over and the "selected" bar: neither is wanted (the selected row gets
            -- its own gradient or text color from Options.lua)
            ht:SetAlpha(0)
        end
    end
    OnRelease(w, function(self)
        self.xuiFadeTok = nil; self.xuiLastSel = nil
        if self.xuiFadeFrame then self.xuiFadeFrame:SetScript("OnUpdate", nil) end
        if self.content and self.content.SetAlpha then self.content:SetAlpha(1) end
        if self.xuiSearchBox then self.xuiSearchBox:Hide() end
        if self.xuiSelBar then self.xuiSelBar:Hide() end
        if self.xuiPart or self.xuiTopApplied then pcall(ResetChain, self); self.xuiPart = nil; self.xuiTopApplied = nil end
        if self.xuiPadApplied and self.content and self.border then
            self.content:ClearAllPoints()
            self.content:SetPoint("TOPLEFT", self.border, "TOPLEFT", 10, -10)
            self.content:SetPoint("BOTTOMRIGHT", self.border, "BOTTOMRIGHT", -10, 10)
            self.xuiPadApplied = nil
        end
        PaneColors(self.treeframe, { 0.1, 0.1, 0.1, 0.5 }, { 0.4, 0.4, 0.4 })
        PaneColors(self.border, { 0.1, 0.1, 0.1, 0.5 }, { 0.4, 0.4, 0.4 })
        for _, b in ipairs(self.buttons or {}) do
            local ht = b:GetHighlightTexture()
            if ht and b.xuiHT then ht:SetTexture(b.xuiHT[1]); ht:SetVertexColor(unpack(b.xuiHT[2])); ht:SetBlendMode(b.xuiHT[3]); ht:SetAlpha(1); b.xuiHT = nil end
        end
    end)
end

-- Row action icons on a header button (arg.xuiActions = function returning { up, down, copy, del }; a function runs on click,
-- false shows the icon grayed out, nil leaves the slot empty). Slots are fixed so icons line up from row to row.
local ACT_SLOTS = { { "up", -76 }, { "down", -52 }, { "copy", -28 }, { "del", -4 } }
local ACT_TIP = { up = "Move up", down = "Move down", copy = "Duplicate", del = "Remove" }
local function MakeAction(f, key)
    local b = CreateFrame("Button", nil, f)
    b:SetSize(20, 20)
    b:SetFrameLevel(f:GetFrameLevel() + 3)
    if key == "del" then
        b.label = b:CreateFontString(nil, "OVERLAY")
        b.label:SetFont("Fonts\\FRIZQT__.TTF", 18, "OUTLINE")
        b.label:SetPoint("CENTER"); b.label:SetText("X"); do local dc = TC("xui-danger", "text", { 1, 0.12, 0.12, 1 }); b.label:SetTextColor(dc[1], dc[2], dc[3]) end
    else
        b.tex = b:CreateTexture(nil, "ARTWORK")
        b.tex:SetPoint("CENTER")
        if key == "up" then b.tex:SetTexture("Interface\\Buttons\\Arrow-Up-Up"); b.tex:SetSize(22, 22)
        elseif key == "down" then b.tex:SetTexture("Interface\\Buttons\\Arrow-Down-Up"); b.tex:SetSize(22, 22)
        else b.tex:SetTexture("Interface\\Buttons\\UI-GuildButton-PublicNote-Up"); b.tex:SetSize(16, 16) end
    end
    b:SetScript("OnClick", function(self) if self.fn then self.fn() end end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText(ACT_TIP[key]); GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end
local function HideActions(f)
    if f.xuiAct then for _, b in pairs(f.xuiAct) do b:Hide(); b.fn = nil end end
end
local function PaintActions(w, arg)
    local f = w.frame
    local spec = arg and arg.xuiActions
    if type(spec) == "function" then local ok, r = pcall(spec); spec = ok and r or nil end
    if type(spec) ~= "table" then HideActions(f) return end
    f.xuiAct = f.xuiAct or {}
    for _, s in ipairs(ACT_SLOTS) do
        local key, x = s[1], s[2]
        local fn = spec[key]
        local b = f.xuiAct[key]
        if fn == nil then
            if b then b:Hide(); b.fn = nil end
        else
            if not b then b = MakeAction(f, key); f.xuiAct[key] = b end
            b.fn = fn or nil
            b:SetEnabled(fn ~= false)
            local a = (fn ~= false) and 1 or 0.3
            if b.tex then b.tex:SetDesaturated(fn == false); b.tex:SetAlpha(a) end
            if b.label then b.label:SetAlpha(a) end
            b:ClearAllPoints(); b:SetPoint("RIGHT", f, "RIGHT", x, 0)
            b:Show()
        end
    end
end

-- Header title you can click and rename (arg.xuiEdit = { get, set, hint }): a borderless text box in the header; the hint (dark gray) sits to its right.
local function PaintNameEdit(w, arg)
    local f = w.frame
    local ed = arg and arg.xuiEdit
    if not ed then
        if f.xuiNameEB then f.xuiNameEB:Hide(); f.xuiNameHint:Hide(); if f.xuiNamePH then f.xuiNamePH:Hide() end end
        return
    end
    local eb = f.xuiNameEB
    if not eb then
        eb = CreateFrame("EditBox", nil, f)
        eb:SetAutoFocus(false); eb:SetHeight(22); eb:SetTextInsets(6, 6, 0, 0); eb:SetMaxLetters(60)
        eb:SetFontObject(GameFontHighlight)
        eb.bg = eb:CreateTexture(nil, "BACKGROUND"); eb.bg:SetAllPoints(); eb.bg:SetColorTexture(0, 0, 0, 0)
        eb.line = eb:CreateTexture(nil, "ARTWORK"); eb.line:SetPoint("BOTTOMLEFT"); eb.line:SetPoint("BOTTOMRIGHT"); eb.line:SetHeight(1)
        eb.line:SetColorTexture(0.35, 0.35, 0.35, 0.8)
        eb:SetScript("OnEnter", function(self) self.bg:SetColorTexture(0.1, 0.1, 0.1, 0.9) end)
        eb:SetScript("OnLeave", function(self) if not self:HasFocus() then self.bg:SetColorTexture(0, 0, 0, 0) end end)
        eb:SetScript("OnEditFocusGained", function(self) self.bg:SetColorTexture(0, 0, 0, 1); self:HighlightText() end)
        eb:SetScript("OnEscapePressed", function(self) self.xuiCancel = true; self:ClearFocus() end)
        eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
        eb:SetScript("OnEditFocusLost", function(self)
            self.bg:SetColorTexture(0, 0, 0, 0)
            local spec = self.xuiSpec
            if self.xuiCancel then self.xuiCancel = nil; self:SetText(spec and tostring(spec.get() or "") or ""); return end
            if spec and self:GetText() ~= tostring(spec.get() or "") then spec.set(self:GetText()) end
        end)
        f.xuiNameEB = eb
        f.xuiNameHint = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        f.xuiNameHint:SetTextColor(0.45, 0.45, 0.45)
    end
    eb.xuiSpec = ed
    eb:SetFrameLevel(f:GetFrameLevel() + 3)
    eb:ClearAllPoints()
    if ed.title then   -- number is the header title; this box (the optional name) goes beneath it, smaller and gray
        eb:SetHeight(16); eb:SetFontObject(GameFontNormalSmall); eb:SetTextColor(0.65, 0.65, 0.65)
        eb:SetPoint("TOPLEFT", f, "TOPLEFT", 20 - (tonumber(arg and arg.xuiHeadOut) or 0), -(3 + ns.H3_SIZE + 3)); eb:SetWidth(220)
        if not f.xuiNamePH then
            f.xuiNamePH = eb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            f.xuiNamePH:SetPoint("LEFT", eb, "LEFT", 6, 0); f.xuiNamePH:SetTextColor(0.4, 0.4, 0.4); f.xuiNamePH:SetText("name (optional)")
            eb:HookScript("OnTextChanged", function(self) if f.xuiNamePH then f.xuiNamePH:SetShown(self:GetText() == "" and not self:HasFocus()) end end)
            eb:HookScript("OnEditFocusGained", function() f.xuiNamePH:Hide() end)
            eb:HookScript("OnEditFocusLost", function(self) f.xuiNamePH:SetShown(self:GetText() == "") end)
        end
    else
        eb:SetHeight(22); eb:SetFontObject(GameFontHighlight); eb:SetTextColor(1, 1, 1)
        eb:SetPoint("LEFT", f, "LEFT", 30 - (tonumber(arg and arg.xuiHeadOut) or 0), 0); eb:SetWidth(220)
        if f.xuiNamePH then f.xuiNamePH:Hide() end
    end
    if not eb:HasFocus() then eb:SetText(tostring(ed.get() or "")); eb:SetCursorPosition(0) end
    if ed.title and f.xuiNamePH then f.xuiNamePH:SetShown(eb:GetText() == "" and not eb:HasFocus()) end
    eb:Show()
    local h = f.xuiNameHint
    h:ClearAllPoints(); h:SetPoint("LEFT", eb, "RIGHT", 8, 0)
    h:SetText(ed.hint and ed.hint() or ""); h:Show()
end

local function SkinButton(w)
    local f = w.frame
    local opt = w.GetUserData and w:GetUserData("option")
    local isHeader = opt and type(opt.arg) == "table" and opt.arg.xuiLeft
    local arg = opt and type(opt.arg) == "table" and opt.arg or nil
    local fs = w.text
    if isHeader then
        -- collapsible section header (arrow + title): no box, bigger text, like WeakAuras' "Icon Settings"
        HideRegions(f, f:GetHighlightTexture())
        FlatHide(f)
        if fs and not w.xuiFont then
            local font, size, flags = fs:GetFont()
            w.xuiFont = { font, size, flags }
            fs:SetFont(font, ns.H3_SIZE, flags)
            fs:SetTextColor(1, 1, 1)
        end
        local arrowL = arg and arg.xuiArrowLeft and type(arg.xuiArrow) == "function"
        local subTxt = arg and type(arg.xuiSub) == "function" and select(2, pcall(arg.xuiSub)) or nil
        if type(subTxt) ~= "string" or subTxt == "" then subTxt = nil end
        local out = tonumber(arg and arg.xuiHeadOut) or 0   -- header hangs out into the margin its group's body is indented by (arg.xuiIndent)
        local lx = ((arrowL and out <= 0) and 22 or 0) - out
        if fs then
            fs:ClearAllPoints()
            if subTxt then fs:SetPoint("TOPLEFT", f, "TOPLEFT", lx, -3) else fs:SetPoint("LEFT", f, "LEFT", lx, 0) end
            fs:SetPoint("RIGHT", f, "RIGHT", -30, 0); fs:SetJustifyH("LEFT"); w.xuiTextMoved = true
        end
        -- gray second line (e.g. "Trigger 1" under a renamed trigger)
        if subTxt then
            if not f.xuiSubFS then f.xuiSubFS = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall") end
            local sf = f.xuiSubFS
            sf:ClearAllPoints(); sf:SetPoint("TOPLEFT", f, "TOPLEFT", lx, -3 - ns.H3_SIZE - 4)
            sf:SetTextColor(0.6, 0.6, 0.6); sf:SetJustifyH("LEFT"); sf:SetText(subTxt); sf:Show()
        elseif f.xuiSubFS then f.xuiSubFS:Hide() end
        local wantH = subTxt and (ns.H3_SIZE + 26) or 24
        if math.abs((f:GetHeight() or 0) - wantH) > 0.5 and (subTxt or w.xuiSubH) then
            f:SetHeight(wantH); f.height = wantH; w.xuiSubH = subTxt and true or nil
            if w.parent and w.parent.DoLayout then w.parent:DoLayout() end
        end
        if arg and type(arg.xuiArrow) == "function" then
            if fs and w.xuiFont then fs:SetFont(w.xuiFont[1], ns.H3_SIZE, w.xuiFont[3]) end   -- same size as every other header
            if not f.xuiArrowTex then f.xuiArrowTex = f:CreateTexture(nil, "OVERLAY"); f.xuiArrowTex:SetSize(16, 16) end
            local at = f.xuiArrowTex
            local okOpen, open = pcall(arg.xuiArrow)
            at:ClearAllPoints()
            if arrowL then at:SetPoint("LEFT", f, "LEFT", 2, 0) else at:SetPoint("RIGHT", f, "RIGHT", -8, 0) end
            at:SetTexture((okOpen and open) and "Interface\\Buttons\\Arrow-Down-Up" or "Interface\\ChatFrame\\ChatFrameExpandArrow")
            at:SetVertexColor(0.8, 0.5, 1); at:Show()
        elseif f.xuiArrowTex then f.xuiArrowTex:Hide() end
    elseif arg and arg.xuiDel then
        -- remove-this-row "X": no box, the same red X as the header's remove icon
        HideRegions(f, f:GetHighlightTexture())
        FlatHide(f)
        if fs then
            if not w.xuiFont then local font, size, flags = fs:GetFont(); w.xuiFont = { font, size, flags } end
            fs:SetFont("Fonts\\FRIZQT__.TTF", 18, "OUTLINE")
            local dc = TC("xui-danger", "text", { 1, 0.12, 0.12, 1 })
            if f:IsEnabled() then fs:SetTextColor(dc[1], dc[2], dc[3]) else fs:SetTextColor(dc[1] * 0.4, dc[2] * 0.4, dc[3] * 0.4) end
        end
    else
        HideRegions(f, f:GetHighlightTexture())
        local bcl = (arg and arg.xuiRed) and "xui-button-primary" or "xui-button"   -- WeakAuras-style red "Add ..." button = primary
        Flat(f, TC(bcl, "bg", { 0.04, 0.04, 0.04, 0.7 }), TC(bcl, "border", { 0.25, 0.25, 0.25, 1 }))
        if fs then
            TF(fs)
            if f:IsEnabled() then local c = TC(bcl, "text", GOLD); fs:SetTextColor(c[1], c[2], c[3]) else fs:SetTextColor(0.5, 0.5, 0.5) end
        end
    end
    do local o = (isHeader and tonumber(arg and arg.xuiHeadOut)) or 0; f:SetHitRectInsets(-o, 0, 0, 0) end
    PaintActions(w, arg)
    PaintNameEdit(w, arg)
    OnRelease(w, function(self)
        self.frame:SetHitRectInsets(0, 0, 0, 0)
        if self.frame.xuiNameEB then self.frame.xuiNameEB:Hide(); self.frame.xuiNameHint:Hide() end
        if self.frame.xuiArrowTex then self.frame.xuiArrowTex:Hide() end
        if self.frame.xuiSubFS then self.frame.xuiSubFS:Hide() end
        if self.xuiSubH then self.frame:SetHeight(24); self.frame.height = 24; self.xuiSubH = nil end
        HideActions(self.frame)
        ShowRegions(self.frame)
        FlatHide(self.frame)
        TR(self.text)
        if self.text and self.xuiTextMoved then
            self.text:ClearAllPoints(); self.text:SetPoint("TOPLEFT", 15, -1); self.text:SetPoint("BOTTOMRIGHT", -15, 1); self.text:SetJustifyH("CENTER")
            self.xuiTextMoved = nil
        end
        if self.xuiFont and self.text then self.text:SetFont(unpack(self.xuiFont)); self.text:SetTextColor(1, 0.82, 0); self.xuiFont = nil end
    end)
end

local function SkinInline(w)
    local opt = w.GetUserData and w:GetUserData("option")
    local oa = opt and type(opt.arg) == "table" and opt.arg or nil
    local flat, box = oa and oa.xuiFlat, oa and oa.xuiBox   -- xuiFlat: no box at all; xuiBox: square 1px box, 10% more opaque (Addon Info tab)
    if (flat or box) and w.border and w.border.SetBackdropColor then
        w.border:SetBackdropColor(0, 0, 0, 0); w.border:SetBackdropBorderColor(0, 0, 0, 0)   -- hide AceGUI's rounded border
        if box then Flat(w.border, { 0.04, 0.04, 0.04, math.min(1, A() * 0.5 + 0.10) }, { 0.3, 0.3, 0.3, 1 }) else FlatHide(w.border) end
    else
        if w.border then FlatHide(w.border) end
        do local pb, pd = TC("xui-pane", "bg", { 0.04, 0.04, 0.04, 1 }), TC("xui-pane", "border", { 0.25, 0.25, 0.25, 1 }); PaneColors(w.border, { pb[1], pb[2], pb[3], A() * 0.5 }, pd) end
    end
    local title = w.titletext and w.titletext:GetText()
    if opt and opt.xuiInfo and title and title ~= "" and ns.GetInfoIcon then
        local ic = ns.GetInfoIcon(w.frame)
        ic.xuiText = opt.xuiInfo; ic.xuiTitle = title
        ic:ClearAllPoints()
        ic:SetPoint("LEFT", w.frame, "TOPLEFT", 14 + w.titletext:GetStringWidth() + 4, -9)
        ic:Show()
        AddRest(w, "info", function(self) if self.frame.xuiInfoIcon then self.frame.xuiInfoIcon:Hide() end end)
    elseif w.frame.xuiInfoIcon then
        w.frame.xuiInfoIcon:Hide()
    end
    -- arg.xuiIndent: everything inside this group moves right by that many pixels (its own header row hangs back out, see xuiHeadOut)
    local ind = tonumber(oa and oa.xuiIndent) or 0
    if ind > 0 and w.content and w.xuiIndent ~= ind then
        if not w.xuiIndent then
            w.xuiOrigWidthSet = w.OnWidthSet
            AddRest(w, "indent", function(self)
                self.OnWidthSet = self.xuiOrigWidthSet; self.xuiOrigWidthSet = nil; self.xuiIndent = nil
                if self.content then
                    self.content:ClearAllPoints()
                    self.content:SetPoint("TOPLEFT", 10, -10); self.content:SetPoint("BOTTOMRIGHT", -10, 10)
                end
            end)
        end
        w.xuiIndent = ind
        local orig = w.xuiOrigWidthSet
        w.OnWidthSet = function(self, width)
            if orig then orig(self, width) end
            local cw = math.max(0, (self.content.width or 0) - (self.xuiIndent or 0))
            self.content:SetWidth(cw); self.content.width = cw
        end
        w.content:ClearAllPoints()
        w.content:SetPoint("TOPLEFT", 10 + ind, -10); w.content:SetPoint("BOTTOMRIGHT", -10, 10)
        local fw = w.frame.width or w.frame:GetWidth() or 0
        if fw > 0 then w:OnWidthSet(fw) end
        if w.xuiFlexed and w.DoLayout then pcall(w.DoLayout, w) end   -- not flexed yet: FlexOn runs right after this and lays it out
    end
    OnRelease(w, function(self) if self.border then FlatHide(self.border) end; PaneColors(self.border, { 0.1, 0.1, 0.1, 0.5 }, { 0.4, 0.4, 0.4 }) end)
end

-- clickable list row (a Label whose option carries arg.xuiRow = function): flat box, hover highlight, click runs the function
local function SkinRow(w, fn)
    local f = w.frame
    f:EnableMouse(true)
    f:SetScript("OnMouseUp", function(_, btn) if btn == "LeftButton" then fn() end end)
    if not f.xuiHL then
        f.xuiHL = f:CreateTexture(nil, "HIGHLIGHT")
        f.xuiHL:SetAllPoints(); f.xuiHL:SetColorTexture(1, 0.82, 0, 0.12)
    end
    f.xuiHL:Show()
    Flat(f, { 0.04, 0.04, 0.04, 0.35 + A() * 0.4 }, { 0, 0, 0, 0 })   -- fill only: no outline around each row
    -- icon in its own column (left), thin divider, then the title + description text
    local img, lab = w.image, w.label
    if img and lab and w.imageshown then
        local iw, ih = img:GetWidth(), img:GetHeight()
        local function Place()   -- icon column, divider, text column (AceGUI re-anchors these on every layout, so this runs again after one)
            local fw = f:GetWidth() or 0   -- the real width now (AceGUI's cached f.width goes stale when the scrollbar appears)
            img:ClearAllPoints(); img:SetPoint("LEFT", f, "LEFT", 8, 0)
            if ns.TypeIconCoords then img:SetTexCoord(ns.TypeIconCoords()) end   -- zoomed, square-edged icon
            lab:ClearAllPoints(); lab:SetPoint("LEFT", img, "RIGHT", 18, 0)
            lab:SetWidth(math.max(60, fw - 8 - iw - 18 - 16))
            lab:SetJustifyV("MIDDLE")
            if f.xuiSep then f.xuiSep:Hide() end   -- divider removed (2026-10-31): fully invisible
        end
        Place()
        -- before the first real layout the row is 0 px wide, so the text would measure as a very tall 60 px column: use the icon height then
        local textH = ((f:GetWidth() or 0) >= 150) and math.ceil(lab:GetStringHeight()) + 2 or 0
        local need = math.max(ih, textH) + 40   -- the extra pixels are the gap between rows now that the outline is gone (was 20, doubled on request)
        f.xuiMinH = need   -- floor: AceGUI's Label resets its frame height to the unwrapped text height on layout
        if not rawget(f, "SetHeight") then
            local real = f.SetHeight
            f.SetHeight = function(self, h) real(self, math.max(h or 0, self.xuiMinH or 0)) end
        end
        if math.abs(f:GetHeight() - need) > 0.5 then
            f:SetHeight(need); f.height = need
            if w.parent and w.parent.DoLayout then w.parent:DoLayout() end
            Place()
        end
        f.height = need
        -- The text only wraps correctly once the row has its real width (a 3-line description measured too early left the row
        -- too short, and the next heading / button drew over it). Measure again whenever the row's width changes.
        if not f.xuiRowSized then
            f.xuiRowSized = true
            f:HookScript("OnSizeChanged", function(self, nw)
                if not self.xuiMinH or self.xuiRowBusy or not nw or nw < 150 then return end
                if self.xuiLastW and math.abs(self.xuiLastW - nw) < 1 then return end
                self.xuiLastW = nw
                self.xuiRowBusy = true
                if C_Timer and C_Timer.After then
                    C_Timer.After(0, function()
                        self.xuiRowBusy = nil
                        if ns.Trace then ns.Trace("row re-measure (runs a frame LATE)") end
                        if not (w.frame == self and w.label and w.image and self.xuiMinH) then return end
                        Place()
                        local th = math.ceil(w.label:GetStringHeight()) + 2
                        local nn = math.max(ih, th) + 40
                        if math.abs(nn - self.xuiMinH) > 0.5 then
                            self.xuiMinH = nn; self.height = nn
                            self:SetHeight(nn)
                            if w.parent and w.parent.DoLayout then w.parent:DoLayout() end
                        end
                    end)
                else self.xuiRowBusy = nil end
            end)
        end
    elseif lab then
        lab:SetJustifyV("MIDDLE")
    end
    OnRelease(w, function(self)
        if self.frame.xuiSep then self.frame.xuiSep:Hide() end
        if self.image then self.image:SetTexCoord(0, 1, 0, 1) end   -- recycled label: undo the icon crop
        self.xuiRowKey = nil
        self.frame.xuiMinH = nil; self.frame.SetHeight = nil
        self.frame.xuiLastW = nil; self.frame.xuiRowBusy = nil
        self.frame:EnableMouse(false); self.frame:SetScript("OnMouseUp", nil)
        if self.frame.xuiHL then self.frame.xuiHL:Hide() end
        FlatHide(self.frame)
        if self.label then self.label:SetJustifyV("TOP") end
    end)
end

-------------------------------------------------------------------------------
-- Type icons (new-rule picker and the sidebar): your own icon crops, shipped as Media\\UI\\xui_*.tga
-- (new texture files need a full game restart, not just /reload).
-------------------------------------------------------------------------------
local ICON_DIR = "Interface\\AddOns\\XayaUI\\Media\\UI\\xui_"
ns.TYPE_ICONS = {}
for _, key in ipairs({ "text", "progresstex", "icon", "dyngroup", "stgroup", "sttexture", "import" }) do ns.TYPE_ICONS[key] = ICON_DIR .. key end
ns.TYPE_ICONS.stgroup = 252272    -- static groups: game icon file ID
ns.TYPE_ICONS.progressbar = 237538                           -- progress bars: game icon file ID
ns.TYPE_ICONS.progresstex = 252267                        -- progress textures: game icon file ID
ns.TYPE_ICONS.sttexture = 1323036                         -- textures use this game icon (file ID)
ns.TYPE_ICONS.sound = 252268                              -- sound cues: game icon file ID
ns.TYPE_ICONS.import = 252269                             -- import: game icon file ID
ns.TYPE_ICONS.icon = 252270                               -- icon type: game icon file ID
ns.TYPE_ICONS.dyngroup = 252271                           -- dynamic groups: game icon file ID
-- Type icons are cropped by a fixed fraction per edge (set directly, not via the Visual.lua zoom formula).
-- A square crop also removes the rounded corners of the game icons.
ns.TYPE_ICON_CROP = 0.12   -- fraction cropped from each edge (12%)
ns.TYPE_ICON_SIDEBAR_ALPHA = 0.5   -- sidebar icons: 50% opacity
ns.TYPE_ICON_SIDEBAR_W = 32        -- square thumbnail on sidebar rows (W = H)
ns.TYPE_ICON_SIDEBAR_H = 32
function ns.TypeIconCoords(w, h)   -- with a width and height, the square source is cropped (not stretched) to that box
    local z = ns.TYPE_ICON_CROP
    local u0, u1, v0, v1 = z, 1 - z, z, 1 - z
    if w and h and w > 0 and h > 0 then
        local span = (1 - 2 * z) * math.min(1, h / w)   -- visible fraction of the height when the box is wider than tall
        local c = 0.5
        v0, v1 = c - span / 2, c + span / 2
    end
    return u0, u1, v0, v1
end
function ns.TypeIcon(key, fallback)
    if SkinOn() and ns.TYPE_ICONS[key] then return ns.TYPE_ICONS[key] end
    return fallback
end
-- which icon a rule or folder gets (nil = none, e.g. a sound-only rule)
function ns.TypeKey(rule)
    local v = type(rule.visual) == "table" and rule.visual or nil
    if not v or not v.enabled then
        if type(rule.sound) == "table" and rule.sound.enabled then return "sound" end
        return nil
    end
    if type(v.fill) == "table" and v.fill.enabled then return "progresstex" end
    if v.kind == "spellicon" then return "icon" end
    if type(v.text) == "table" and v.text.enabled and (tonumber(v.texAlpha) or 1) == 0 then return "text" end
    return "sttexture"
end
-- Sidebar icon of a rule: its tracked spell / buff icon (Automatic), the type icon, or a custom ID. nil = use the type icon.
function ns.RuleListIcon(r)
    local mode = r.listIcon or "auto"
    if mode == "type" then return nil end
    if mode == "custom" then return tonumber(r.listIconID) end   -- a texture file ID
    if ns.SidebarSpellIcons and not ns.SidebarSpellIcons() then return nil end
    local sid = tonumber(r.spellID) or 0
    if sid == 0 then sid = tonumber(r.buffID) or 0 end
    if sid == 0 then return nil end
    local ok, t = pcall(C_Spell.GetSpellTexture, sid)
    return ok and t or nil
end
-- Texture rules (progress textures and plain textures) show their own art in the thumbnail. Returns the visual settings to paint
-- (a copy with the zoom crop removed so nothing is clipped), or nil when the rule is not a file / atlas texture.
function ns.RuleListArt(r)
    local mode = r.listIcon or "auto"
    if mode ~= "auto" then return nil end
    local v = type(r.visual) == "table" and r.visual or nil
    if not v or not v.enabled then return nil end
    local kind = ns.Val and ns.Val(v.kind)
    if (kind ~= "file" and kind ~= "atlas") or not v.tex or v.tex == "" then return nil end
    local c = {}
    for kk, vv in pairs(v) do c[kk] = vv end
    c.zoom = 0
    return c
end
-- left-of-text icon on sidebar rows of the rule trees; returns the width the row text must leave free
function ns.PaintTypeIcon(button, x)
    local uv = tostring(button.uniquevalue or "")
    local root = uv:match("^([^\001]+)")
    local level = button.level or 1
    local slot = SkinOn() and not (ns.CondensedOn and ns.CondensedOn()) and level >= 2 and (root == "all" or root == "loaded" or root == "notloaded")
    local key, ruleObj
    if slot then
        local last = uv:match("([^\001]+)$") or ""
        local n = last:match("^rule(%d+)$")
        if n then
            local r = ns.rules and ns.rules[tonumber(n)]
            key = r and ns.TypeKey(r)
            ruleObj = r
        elseif uv:match("^all\001smart\001smart_[^\001]+$") then
            -- Smart Categories type rows carry the matching type icon (same size and row height as the rule rows)
            key = ({ smart_icon = "icon", smart_progtex = "progresstex", smart_bar = "progressbar", smart_tex = "sttexture", smart_text = "text", smart_sound = "sound" })[last]
        elseif last:match("^f%d") then
            local f = ns.FolderById and ns.FolderById(last)
            if f and f.default ~= "cursor" and ns.KindHas and ns.KindHas({ folder = f.id }, "visual") then key = (f.cType == "dynamic") and "dyngroup" or "stgroup" end
        end
    end
    if not slot then if button.xuiType then button.xuiType:Hide() end if button.xuiType2 then button.xuiType2:Hide() end return 0 end
    if key then
        if not button.xuiType then
            button.xuiType = button:CreateTexture(nil, "ARTWORK")
        end
        local T, S = button.xuiType, ns.TYPE_ICON_SIDEBAR_W   -- square thumbnail box
        local tex = ns.TYPE_ICONS[key]
        local art = ruleObj and ns.RuleListArt and ns.RuleListArt(ruleObj)
        pcall(T.SetAtlas, T, nil)
        T:ClearAllPoints()
        if art then
            -- the rule's own art, scaled to fit the square without clipping (aspect = the rule's display width : height)
            local aw, ah = tonumber(art.w) or 1, tonumber(art.h) or 1
            if aw <= 0 or ah <= 0 then aw, ah = 1, 1 end
            local w, h = S, S
            if aw >= ah then h = S * ah / aw else w = S * aw / ah end
            T:SetSize(w, h); T:SetPoint("LEFT", button, "LEFT", x + (S - w) / 2, 0)
            ns.ApplyTexture(T, art)
            -- the rule's own look: base desaturate / tint / blend, then the overlay layer on top with its own
            local tint = art.tint or { 1, 1, 1, 1 }
            local ov = type(art.overlay) == "table" and art.overlay or nil
            local progLocked = type(art.fill) == "table" and art.fill.enabled and not (ov and ov.advanced)
            local desat = progLocked and art.recolor or art.desaturate
            pcall(T.SetDesaturation, T, desat and 1 or 0)
            if art.recolor then T:SetVertexColor(tint[1] or 1, tint[2] or 1, tint[3] or 1, 1) else T:SetVertexColor(1, 1, 1, 1) end
            T:SetBlendMode(art.additive and "ADD" or "BLEND")
            local T2 = button.xuiType2
            if ov and ov.enabled then
                if not T2 then T2 = button:CreateTexture(nil, "ARTWORK", nil, 1); button.xuiType2 = T2 end
                T2:ClearAllPoints(); T2:SetAllPoints(T)
                local src = ns.Val(ov.source)
                local oart = art
                if src == "other" and ns.Val(ov.kind) and ov.tex and ov.tex ~= "" then
                    oart = { kind = ov.kind, tex = ov.tex, zoom = 0, rotation = art.rotation, flipH = art.flipH, flipV = art.flipV, w = art.w, h = art.h }
                end
                pcall(T2.SetAtlas, T2, nil)
                ns.ApplyTexture(T2, oart)
                local ot = ov.tint or { 1, 1, 1, 1 }
                T2:SetVertexColor(ot[1] or 1, ot[2] or 1, ot[3] or 1, 1)
                pcall(T2.SetDesaturation, T2, ((not progLocked) and ov.desaturate) and 1 or 0)
                T2:SetBlendMode(ov.additive and "ADD" or "BLEND")
                T2:SetAlpha(ns.TYPE_ICON_SIDEBAR_ALPHA * math.max(0, math.min(1, tonumber(ov.alpha) or 1)))
                T2:Show()
            elseif T2 then T2:Hide() end
            T:SetAlpha(ns.TYPE_ICON_SIDEBAR_ALPHA * math.max(0, math.min(1, tonumber(art.texAlpha) or 1)))
        else
            T:SetSize(S, S); T:SetPoint("LEFT", button, "LEFT", x, 0)
            if ruleObj and ns.RuleListIcon then tex = ns.RuleListIcon(ruleObj) or tex end
            T:SetTexture(tex); T:SetTexCoord(ns.TypeIconCoords(S, S))
            pcall(T.SetDesaturation, T, 0); T:SetVertexColor(1, 1, 1, 1); T:SetBlendMode("BLEND")
            if button.xuiType2 then button.xuiType2:Hide() end
            T:SetAlpha(ns.TYPE_ICON_SIDEBAR_ALPHA)
        end
        T:Show()
    elseif button.xuiType then
        button.xuiType:Hide()
        if button.xuiType2 then button.xuiType2:Hide() end
    end
    return key and (ns.TYPE_ICON_SIDEBAR_W + 4) or 0   -- 0 = this row has no type icon
end

-------------------------------------------------------------------------------
-- UI pass 2 (2026-10-31): info icons, slider arrows, rows that flex to the pane, window minimum width
-------------------------------------------------------------------------------
local AceGUI = LibStub("AceGUI-3.0", true)

-- (i) icon: hover shows the explanation, click pins it in a small panel (click again, click the panel or press Esc to close)
local infoPop
local function HideInfoPop() if infoPop then infoPop:Hide(); infoPop.owner = nil end end
local function ToggleInfoPop(ic)
    if not infoPop then
        infoPop = CreateFrame("Frame", "XayaUIInfoPopup", UIParent, "BackdropTemplate")
        infoPop:SetFrameStrata("TOOLTIP"); infoPop:SetClampedToScreen(true); infoPop:EnableMouse(true)
        infoPop:SetBackdrop({ bgFile = WHITE8, edgeFile = WHITE8, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
        infoPop:SetBackdropColor(0.04, 0.04, 0.05, 0.97); infoPop:SetBackdropBorderColor(0.8, 0.5, 1, 1)
        infoPop.title = infoPop:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        infoPop.title:SetPoint("TOPLEFT", 10, -8); infoPop.title:SetJustifyH("LEFT")
        infoPop.text = infoPop:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        infoPop.text:SetPoint("TOPLEFT", infoPop.title, "BOTTOMLEFT", 0, -6)
        infoPop.text:SetWidth(340); infoPop.text:SetJustifyH("LEFT"); infoPop.text:SetJustifyV("TOP")
        infoPop:SetScript("OnMouseDown", function(self) self:Hide(); self.owner = nil end)
        if UISpecialFrames then table.insert(UISpecialFrames, "XayaUIInfoPopup") end
    end
    if infoPop:IsShown() and infoPop.owner == ic then HideInfoPop() return end
    infoPop.owner = ic
    infoPop.title:SetText(ic.xuiTitle or "")
    infoPop.text:SetText(ic.xuiText or "")
    infoPop:SetSize(362, infoPop.title:GetStringHeight() + infoPop.text:GetStringHeight() + 30)
    infoPop:ClearAllPoints(); infoPop:SetPoint("TOPLEFT", ic, "BOTTOMRIGHT", 4, 4)
    infoPop:Show()
end
function ns.GetInfoIcon(host)
    local ic = host.xuiInfoIcon
    if not ic then
        ic = CreateFrame("Button", nil, host)
        ic:SetSize(26, 26); ic:SetFrameLevel(host:GetFrameLevel() + 6)
        ic.tex = ic:CreateTexture(nil, "ARTWORK"); ic.tex:SetAllPoints()
        ic.tex:SetTexture("Interface\\common\\help-i"); ic.tex:SetAlpha(0.75)
        ic:SetScript("OnEnter", function(self)
            self.tex:SetAlpha(1)
            if infoPop and infoPop:IsShown() and infoPop.owner == self then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.xuiTitle or "", 1, 0.82, 0)
            GameTooltip:AddLine(self.xuiText or "", 1, 1, 1, true)
            GameTooltip:Show()
        end)
        ic:SetScript("OnLeave", function(self) self.tex:SetAlpha(0.75); GameTooltip:Hide() end)
        ic:SetScript("OnClick", function(self) GameTooltip:Hide(); ToggleInfoPop(self) end)
        ic:SetScript("OnHide", function(self) if infoPop and infoPop.owner == self then HideInfoPop() end end)
        host.xuiInfoIcon = ic
    end
    return ic
end

-- slider arrows: a small arrow at each end moves the value one step (hold to repeat)
local function SkinSlider(w)
    local f, sl = w.frame, w.slider
    if not (f and sl and w.label) then return end
    if not w.xuiArrows then
        local pts = {}
        for i = 1, sl:GetNumPoints() do pts[i] = { sl:GetPoint(i) } end
        w.xuiSlPts = pts
        local arrows = {}
        for _, dir in ipairs({ -1, 1 }) do
            local b = CreateFrame("Button", nil, f)
            b:SetSize(18, 18); b:SetFrameLevel(f:GetFrameLevel() + 3)
            b.tex = b:CreateTexture(nil, "ARTWORK"); b.tex:SetAllPoints()
            b.tex:SetTexture(dir < 0 and "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up" or "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
            b.dir = dir
            local function step()
                if w.disabled then return end
                local lo, hi = sl:GetMinMaxValues()
                local st = w.step or sl:GetValueStep() or 1
                if st <= 0 then st = 1 end
                local v = (sl:GetValue() or lo) + dir * st
                if v < lo then v = lo elseif v > hi then v = hi end
                sl:SetValue(v)
            end
            local function stop()
                if b.xuiT1 then b.xuiT1:Cancel(); b.xuiT1 = nil end
                if b.xuiT2 then b.xuiT2:Cancel(); b.xuiT2 = nil end
            end
            b:SetScript("OnMouseDown", function()
                step(); stop()
                b.xuiT1 = C_Timer.NewTimer(0.4, function() b.xuiT2 = C_Timer.NewTicker(0.07, step) end)
            end)
            b:SetScript("OnMouseUp", stop); b:SetScript("OnLeave", stop); b:SetScript("OnHide", stop)
            b.xuiStop = stop
            arrows[dir < 0 and "left" or "right"] = b
        end
        w.xuiArrows = arrows
        sl:ClearAllPoints()
        sl:SetPoint("TOP", w.label, "BOTTOM")
        sl:SetPoint("LEFT", f, "LEFT", 20, 0)
        sl:SetPoint("RIGHT", f, "RIGHT", -20, 0)
        arrows.left:SetPoint("RIGHT", sl, "LEFT", 1, 0)
        arrows.right:SetPoint("LEFT", sl, "RIGHT", -1, 0)
        AddRest(w, "slider", function(self)
            local a = self.xuiArrows
            if a then for _, b in pairs(a) do b.xuiStop(); b:Hide() end end
            self.xuiArrows = nil
            if self.xuiSlPts and self.slider then
                self.slider:ClearAllPoints()
                for _, pt in ipairs(self.xuiSlPts) do self.slider:SetPoint(pt[1], pt[2], pt[3], pt[4], pt[5]) end
            end
        end)
    end
    local lo, hi = sl:GetMinMaxValues()
    local v = sl:GetValue() or lo
    for dir, b in pairs({ [-1] = w.xuiArrows.left, [1] = w.xuiArrows.right }) do
        local can = (not w.disabled) and ((dir < 0 and v > lo) or (dir > 0 and v < hi))
        b:SetEnabled(can); b.tex:SetDesaturated(not can); b.tex:SetAlpha(can and 1 or 0.35); b:Show()
    end
end

-- text width of a string as a dropdown draws it (used for dropdown minimum widths)
local mfs
local function TextW(s)
    if not mfs then
        mfs = UIParent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        mfs:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -4000, 4000); mfs:SetAlpha(0)
    end
    s = tostring(s or "")
    local extra = 0
    s = s:gsub("|T.-|t", function() extra = extra + 18; return "" end)
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    mfs:SetText(s)
    return (mfs:GetStringWidth() or 0) + extra
end
local function DDMin(ch)
    local list = ch.list
    if type(list) ~= "table" then return 0 end
    local m = 0
    for _, txt in pairs(list) do
        local tw = TextW(txt)
        if tw > m then m = tw end
    end
    return m + 40   -- the dropdown's own text insets
end

-- rows flex to the pane: controls on one row share the leftover width; a control alone on its row spans the pane. A dropdown is
-- never narrower than its longest option. Runs before AceGUI's Flow layout, which then places everything; ApplyGaps adds the
-- column gutter afterwards.
ns.H3_SIZE = 16   -- the single header size (Heading widgets and collapsible section headers)
ns.BODY_INDENT = 20   -- trigger / cue / condition panes: the header sits flush left and everything under it is indented by this much
local NOFLEX = { Icon = true, Label = true, InteractiveLabel = true, Heading = true, ColorPicker = true, Image = true }
local GAP = 10        -- gutter between free-flowing controls
local GRID_GAP = 30   -- gutter between the two columns of the grid (WeakAuras uses a wide column gap)
local function BaseW(ch)
    local fr = ch.frame
    local fw = fr.width or fr:GetWidth() or 0
    if not (ch.xuiFlexW and ch.xuiBaseW and math.abs(fw - ch.xuiFlexW) < 0.6) then ch.xuiBaseW = fw end
    local b = ch.xuiBaseW
    if ch.type == "Dropdown" then local m = DDMin(ch); if m > b then b = m end end
    return b
end
function ns.FlexPrepass(content, children, bw)
    local width = content.width or content:GetWidth() or 0
    if width < 120 then return end
    local grid = ns.GridOn and ns.GridOn()
    local gap = grid and GRID_GAP or GAP
    local colW = math.floor((width - GRID_GAP) / 2)
    local row, used = {}, 0
    local function flush()
        local n = #row
        if n == 0 then return end
        local flex = {}
        for _, e in ipairs(row) do if e.flex then flex[#flex + 1] = e end end
        local extra = math.max(0, math.floor(width - gap * (n - 1) - used - 0.05))
        local each, rem = 0, 0
        if #flex > 0 then each = math.floor(extra / #flex); rem = extra - each * #flex end
        for k, e in ipairs(flex) do
            local nw = e.base + each + ((k == #flex) and rem or 0)
            if math.abs((e.ch.frame.width or 0) - nw) > 0.4 then e.ch:SetWidth(nw) end
            e.ch.xuiFlexW = nw
        end
        for i, e in ipairs(row) do e.ch.xuiGapX = (i > 1 and #flex > 0) and gap or nil end
        row, used = {}, 0
    end
    for _, ch in ipairs(children) do
        if ch.width == "fill" then
            flush()
        else
            local w, flex
            if ch.width == "relative" then
                if ch.type == "Dropdown" then   -- arg.xuiFitText: never narrower than the longest option (AND / OR were cut to "A...")
                    local o = ch.GetUserData and ch:GetUserData("option")
                    if o and type(o.arg) == "table" and o.arg.xuiFitText then
                        local m = DDMin(ch)
                        if m > width * (ch.relWidth or 1) then ch.relWidth = math.min(1, m / width) end
                    end
                end
                w = width * (ch.relWidth or 1); flex = false
            else
                w = (bw or BaseW)(ch); flex = not NOFLEX[ch.type]
                -- two-column grid: a control is either one column wide or spans both (when it cannot fit in a column)
                if grid and flex then w = (w > colW + 0.5) and width or colW end
            end
            if #row > 0 and used + gap + w > width then flush() end
            row[#row + 1] = { ch = ch, base = w, flex = flex }
            used = used + w
        end
    end
    flush()
end
local function ApplyGaps(children)
    for i = 2, #children do
        local ch = children[i]
        local g = ch.xuiGapX
        if g then
            local p, rel, rp, _, y = ch.frame:GetPoint(1)
            if rel == children[i - 1].frame and rp == "TOPRIGHT" then
                ch.frame:ClearAllPoints()
                ch.frame:SetPoint(p, rel, rp, g, y)
            end
        end
    end
end
local FlowFn = AceGUI and AceGUI:GetLayout("Flow")
local XUIFlowFn
if FlowFn then
    XUIFlowFn = function(content, children)
        local ok, err = pcall(ns.FlexPrepass, content, children)
        if not ok and not ns.flexErr then ns.flexErr = err; if geterrorhandler then geterrorhandler()(err) end end
        -- Breathing room between sections: every section heading and every nested box (except the first thing in a pane) is pushed down,
        -- and everything under it with it, then the pane is told it is that much taller. Re-done from scratch on every layout.
        local obj = content.obj
        local own = obj and rawget(obj, "LayoutFinished")
        local lw, lh
        if obj and SkinOn() then obj.LayoutFinished = function(_, w, h) lw, lh = w, h end end
        FlowFn(content, children)
        if obj and SkinOn() then
            obj.LayoutFinished = own
            local okS, extra = pcall(function()
                local acc = 0
                for i, ch in ipairs(children) do
                    if i > 1 and (ch.type == "Heading" or ch.type == "InlineGroup") then acc = acc + (ch.type == "Heading" and 14 or 12) end
                    if acc > 0 and ch.frame then
                        local p, rel, rp, x, y = ch.frame:GetPoint(1)
                        if rel == content then ch.frame:ClearAllPoints(); ch.frame:SetPoint(p, rel, rp, x, (y or 0) - acc) end
                    end
                end
                return acc
            end)
            if obj.LayoutFinished then pcall(obj.LayoutFinished, obj, lw, (lh or 0) + (okS and extra or 0)) end
        end
        pcall(ApplyGaps, children)
        -- A nested box can change height AFTER its parent has already flowed (its own layout runs later, from the content's size-change
        -- event, or a row re-measures), and the parent never heard about it: the sections below drew over the grown box (Cues > Texture
        -- Options overlapping Color & Transparency until the window was widened). Compare with the height the parent last measured
        -- (xuiSeenH, recorded at the end of the parent's own flow) and make the parent flow again. Climbs the same way, one level per
        -- layout, and only fires when the height really changed, so it cannot loop.
        if obj and SkinOn() and obj.frame and obj.parent and obj.parent.DoLayout and (obj.type == "InlineGroup" or obj.type == "SimpleGroup") then
            local seen, par = obj.xuiSeenH, obj.parent
            if seen and math.abs(seen - (obj.frame:GetHeight() or 0)) > 0.5 and not par.xuiRelaying then
                par.xuiRelaying = true
                pcall(par.DoLayout, par)
                par.xuiRelaying = nil
            end
        end
        -- Nested boxes (a group inside a group) measure their children before text has wrapped, so the box can end up shorter than
        -- its contents. One more layout pass fixes it. It runs RIGHT NOW (same frame): a pass on the next frame made every pane
        -- visibly jump after it drew, which is part of the "blink". The second pass is marked so it never schedules a third.
        -- PERF (2026-11-01): the second pass used to run for EVERY container, so each nesting level doubled the work and opening a big
        -- pane froze the window (the old pane stayed on screen meanwhile). Now it only runs when the pane holds nested boxes AND its
        -- size signature changed since the last finished layout.
        if content.xuiSecond then content.xuiSecond = nil
        elseif content.obj and content.obj.DoLayout then
            local nested = false
            local hsum = 0
            for _, ch in ipairs(children) do
                local ty = ch.type
                if ty == "InlineGroup" or ty == "SimpleGroup" then nested = true end
                hsum = hsum + (ch.frame and ch.frame:GetHeight() or 0)
            end
            local sig = math.floor(content.width or content:GetWidth() or 0) .. ":" .. #children .. ":" .. math.floor(hsum)
            if nested and content.xuiSig ~= sig then
                content.xuiSecond = true
                pcall(content.obj.DoLayout, content.obj)
                content.xuiSecond = nil
                local h2 = 0
                for _, ch in ipairs(children) do h2 = h2 + (ch.frame and ch.frame:GetHeight() or 0) end
                content.xuiSig = math.floor(content.width or content:GetWidth() or 0) .. ":" .. #children .. ":" .. math.floor(h2)
            end
        end
        for _, ch in ipairs(children) do   -- remember what height this flow measured for each box (see the check above)
            if ch.frame then ch.xuiSeenH = ch.frame:GetHeight() end
        end
    end
    AceGUI:RegisterLayout("XUIFlow", XUIFlowFn)
end
local function FlexOn(w)
    if not XUIFlowFn or w.xuiFlexed or w.LayoutFunc ~= FlowFn then return end
    w.xuiFlexed = true
    w.LayoutFunc = XUIFlowFn
    AddRest(w, "flex", function(self) if self.LayoutFunc == XUIFlowFn then self.LayoutFunc = FlowFn end; self.xuiFlexed = nil; if self.content then self.content.xuiSig = nil end end)
    pcall(w.DoLayout, w)
end

-- window minimum width: the widest option of ANY dropdown in the addon (scanned from the options table once per window) plus the
-- fixed chrome around the rule pane. The window cannot be dragged narrower; the collapse toggle still shrinks it.
local function ScanDropdowns()
    if not ns.BuildOptionsTable then return 0 end
    local ok, root = pcall(ns.BuildOptionsTable)
    if not ok or type(root) ~= "table" then return 0 end
    local seen, mx = {}, 0
    local function walk(g, depth)
        if type(g) ~= "table" or seen[g] or depth > 30 then return end
        seen[g] = true
        if g.type == "select" then
            local vals = g.values
            if type(vals) == "function" then local ok2, r = pcall(vals, {}); vals = ok2 and r or nil end
            if type(vals) == "table" then
                for _, txt in pairs(vals) do
                    if type(txt) == "string" then local tw = TextW(txt) + 40; if tw > mx then mx = tw end end
                end
            end
        end
        if type(g.args) == "table" then for _, v in pairs(g.args) do walk(v, depth + 1) end end
    end
    walk(root, 0)
    return math.min(mx, 520)
end
function ns.UpdateMinWidth(of)
    local fr = of.frame
    if not (fr and fr.SetResizeBounds) then return end
    if of.xuiChrome and of.xuiChrome.collapsed then return end
    if not of.xuiDD then of.xuiDD = ScanDropdowns() end
    local function find(w, d)
        if not w or d > 8 then return nil end
        if w.type == "ScrollFrame" and w.parent and w.parent.type == "TreeGroup" then return w end
        for _, c in ipairs(w.children or {}) do local r = find(c, d + 1); if r then return r end end
    end
    local sc = find(of, 0)
    if sc and sc.content then
        local cw, fw = sc.content:GetWidth(), fr:GetWidth()
        if cw and cw > 50 and fw then
            local slack = fw - cw
            if slack > (of.xuiSlack or 0) and slack < fw then of.xuiSlack = slack end
        end
    end
    local need = math.max(400, math.floor((of.xuiDD or 0) + (of.xuiSlack or 390) + 4))
    if of.xuiMinW ~= need then
        of.xuiMinW = need
        fr:SetResizeBounds(need, 200)
        AddRest(of, "minw", function(self)
            if self.frame then self.frame:SetResizeBounds(400, 200) end
            self.xuiDD = nil; self.xuiSlack = nil; self.xuiMinW = nil
        end)
    end
    if fr:GetWidth() < need - 0.5 then fr:SetWidth(need) end
end

-- arg.xuiSide = true: the label sits to the LEFT of the box instead of above it (text boxes and dropdowns).
local function SideLabel(w, kind)
    local opt = w.GetUserData and w:GetUserData("option")
    if not (opt and type(opt.arg) == "table" and opt.arg.xuiSide) then return end
    local f, lab = w.frame, w.label
    local box = (kind == "EditBox") and w.editbox or w.dropdown
    if not (f and lab and box) then return end
    local function Apply()
        if not w.xuiSideOn then return end
        local fw = f:GetWidth() or 300
        local lw = math.max(70, math.min(190, math.floor(fw * 0.36)))
        lab:ClearAllPoints(); lab:SetPoint("LEFT", f, "LEFT", 0, 0); lab:SetWidth(lw); lab:SetHeight(18); lab:SetJustifyH("LEFT")
        box:ClearAllPoints()
        if kind == "EditBox" then
            box:SetPoint("LEFT", f, "LEFT", lw + 6, 0); box:SetPoint("RIGHT", f, "RIGHT", -2, 0)
        else
            box:SetPoint("TOPLEFT", f, "TOPLEFT", lw - 9, 0); box:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 17, 0)
        end
        lab:Show()
    end
    if not w.xuiSideOn then
        w.xuiSideOn = true
        f:HookScript("OnSizeChanged", function() if w.xuiSideOn then Apply() end end)
        AddRest(w, "side", function(self)
            self.xuiSideOn = nil
            local l, b = self.label, (kind == "EditBox") and self.editbox or self.dropdown
            if l then l:ClearAllPoints(); l:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, kind == "EditBox" and -2 or 0); l:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", 0, kind == "EditBox" and -2 or 0) end
            if b then
                b:ClearAllPoints()
                if kind == "EditBox" then b:SetPoint("BOTTOMLEFT", 6, 0); b:SetPoint("BOTTOMRIGHT")
                else b:SetPoint("TOPLEFT", self.frame, "TOPLEFT", -15, 0); b:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", 17, 0) end
            end
        end)
    end
    if w.SetHeight then w:SetHeight(28) end
    Apply()
end

local function Walk(w, depth)
    if not w or depth > 14 then return end
    local t = w.type
    if t == "TabGroup" then SkinTabGroup(w)
    elseif t == "TreeGroup" then SkinTree(w)
    elseif t == "Button" then SkinButton(w)
    elseif t == "InlineGroup" then SkinInline(w)
    elseif t == "EditBox" then SideLabel(w, "EditBox")
    elseif t == "Dropdown" or t == "Dropdown-Pullout" then
        if t == "Dropdown" then
            SideLabel(w, "Dropdown")
            local opt = w.GetUserData and w:GetUserData("option")
            if w.text and opt and type(opt.arg) == "table" and opt.arg.xuiTextLeft then   -- selected text on the left instead of the right
                w.text:SetJustifyH("LEFT")
                if not w.xuiTextLeft then
                    w.xuiTextLeft = true
                    AddRest(w, "textleft", function(self) self.xuiTextLeft = nil; if self.text then self.text:SetJustifyH("RIGHT") end end)
                end
            end
        end
        -- open list as wide as its longest entry (AceGUI cuts entries off at the closed box's width, so "Trigger 2 (Sigil of Flame De..." was
        -- unreadable). Rows cannot wrap (fixed height), so the list grows to the right instead; capped so it never fills the screen.
        if t == "Dropdown" and w.pullout and not w.pullout.xuiWideOpen then
            local po = w.pullout
            po.xuiWideOpen = true
            local origOpen = po.Open
            po.Open = function(self, ...)
                origOpen(self, ...)
                pcall(function()
                    local need = 0
                    for _, item in pairs(self.items) do
                        local txt = item.text and item.text:GetText()
                        if txt then local tw = TextW(txt); if tw > need then need = tw end end
                    end
                    local want = math.min(need + 64, 640)   -- 64 = check mark, side margins, scroll bar
                    if want > (self.frame:GetWidth() or 0) then self.frame:SetWidth(want) end
                end)
            end
        end
        -- texture pickers (opt.arg.xuiTexPick): big preview rows. AceGUI's pullout lays rows out at a fixed 16 px, so re-space them after it opens;
        -- the closed box keeps a small icon so it doesn't outgrow its line.
        if t == "Dropdown" and w.pullout and not w.xuiTexPick then
            local o2 = w.GetUserData and w:GetUserData("option")
            if o2 and type(o2.arg) == "table" and o2.arg.xuiTexPick then
                w.xuiTexPick = true
                local po, origOpen, origSetText = w.pullout, w.pullout.Open, w.SetText
                local ROW = ns.TEX_PICK_ROW or 60
                po.Open = function(self, ...)
                    origOpen(self, ...)
                    local height = 8
                    for i, item in pairs(self.items) do
                        item.frame:SetHeight(ROW)
                        if item.highlight then item.highlight:SetHeight(ROW - 2) end
                        item:SetPoint("TOP", self.itemFrame, "TOP", 0, -2 - (i - 1) * ROW)
                        height = height + ROW
                    end
                    self.itemFrame:SetHeight(height)
                    self.frame:SetHeight(math.min(height + 26, self.maxHeight or height + 26))
                    if self.FixScroll then self:FixScroll() end
                end
                local function small(s) return s and (s:gsub("(|T[^|:]+):%d+:%d+|t", "%1:22:22|t")) end
                w.SetText = function(self, s) return origSetText(self, small(s)) end
                if w.text then w.text:SetText(small(w.text:GetText())) end
                AddRest(w, "texpick", function(self) self.xuiTexPick = nil; self.SetText = origSetText; if self.pullout then self.pullout.Open = origOpen end end)
            end
        end
        -- the open list was see-through (text over the page): give every dropdown list a solid dark panel
        local pf = (t == "Dropdown") and w.pullout and w.pullout.frame or w.frame
        if pf and not pf.xuiDD then
            pf.xuiDD = true
            pf:SetFrameStrata("TOOLTIP")
            if pf.SetBackdrop then pf:SetBackdrop(nil) end
            local bg = pf:CreateTexture(nil, "BACKGROUND", nil, -8)
            bg:SetAllPoints(); bg:SetColorTexture(0.05, 0.05, 0.06, 1)
            local edge = CreateFrame("Frame", nil, pf, "BackdropTemplate")
            edge:SetAllPoints(); edge:SetFrameLevel(pf:GetFrameLevel())
            edge:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
            edge:SetBackdropBorderColor(0.4, 0.4, 0.45, 1)
        end
    elseif t == "Heading" then
        -- ONE header size across the whole UI (section titles between the lines, collapsible headers, "Description" etc.)
        if w.label and not w.xuiH3 then
            local f1, f2, f3 = w.label:GetFont()
            w.xuiH3 = { f1, f2, f3 }
            w.label:SetFont(f1, ns.H3_SIZE, f3)
            if w.frame and w.frame:GetHeight() < ns.H3_SIZE + 6 then w.frame:SetHeight(ns.H3_SIZE + 6); w.frame.height = ns.H3_SIZE + 6 end
            OnRelease(w, function(self) if self.xuiH3 and self.label then self.label:SetFont(unpack(self.xuiH3)) end; self.xuiH3 = nil end)
        end
    elseif t == "Label" then
        local opt = w.GetUserData and w:GetUserData("option")
        local fn = opt and type(opt.arg) == "table" and opt.arg.xuiRow
        if fn then SkinRow(w, fn) end
        local h1 = opt and type(opt.arg) == "table" and tonumber(opt.arg.xuiH1)
        if h1 and w.label then
            if not w.xuiH1Font then local a1, a2, a3 = w.label:GetFont(); w.xuiH1Font = { a1, a2, a3 } end
            w.label:SetFont(w.xuiH1Font[1], h1, w.xuiH1Font[3])
            local need = w.label:GetStringHeight() + 6
            local key = math.floor(h1) .. "x" .. math.floor(need)
            if math.abs(w.frame:GetHeight() - need) > 0.5 and w.xuiH1Key ~= key then
                w.xuiH1Key = key
                w.frame:SetHeight(need); w.frame.height = need
                if w.parent and w.parent.DoLayout then w.parent:DoLayout() end
            end
            OnRelease(w, function(self) if self.xuiH1Font and self.label then self.label:SetFont(unpack(self.xuiH1Font)) end; self.xuiH1Key = nil end)
        end
    end
    if t == "Slider" then pcall(SkinSlider, w)
    elseif t == "ScrollFrame" or t == "InlineGroup" or t == "SimpleGroup" then pcall(FlexOn, w) end
    for _, c in ipairs(w.children or {}) do Walk(c, depth + 1) end
end

function ns.SkinRows() return SkinOn() end   -- Options.lua builds the list-row version of the New Rule picker only while the skin is on
local origDecorate = ns.DecorateTrees
function ns.DecorateTrees(root, ...)
    if origDecorate then origDecorate(root, ...) end
    if not SkinOn() then return end
    root = root or (ACD.OpenFrames and ACD.OpenFrames[APP])
    if root then
        pcall(SkinFrame, root)
        pcall(ns.UpdateMinWidth, root)
        pcall(Walk, root, 0)
    end
end
