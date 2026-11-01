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
    b:SetScript("OnLeave", function(self) self.text:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) end)
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
        local lk = ToolButton(bar, "Interface\\PetBattles\\PetBattle-LockIcon", "Lock Positions", function()
            if ns.ToggleUnlock then ns.ToggleUnlock() end
            if ns.UI and ns.UI.Notify then ns.UI.Notify() end
        end)
        lk:SetPoint("LEFT", im, "RIGHT", 14, 0)
        bar.lock = lk
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
            if f.xuiToolbar then f.xuiToolbar:Hide() end
            local c2 = self.content
            c2:ClearAllPoints()
            for _, p in ipairs(self.xuiOrigContent or {}) do c2:SetPoint(p[1], p[2], p[3], p[4], p[5]) end
            local o = self.xuiOrigTitle
            if o and o[1] then self.titletext:ClearAllPoints(); self.titletext:SetPoint(o[1], o[2], o[3], o[4], o[5]) end
            self.titletext:SetTextColor(1, 0.82, 0)
        end)
    end
    if not collapsed then
        if not fr.xuiBDset then
            fr.xuiBDset = true
            fr:SetBackdrop({ bgFile = WHITE8, edgeFile = WHITE8, edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
        end
        fr:SetBackdropColor(0.06, 0.06, 0.06, A())
        fr:SetBackdropBorderColor(0.32, 0.32, 0.32, 1)
    end
    -- title strip
    for _, rg in ipairs({ fr:GetRegions() }) do
        if rg.GetObjectType and rg:GetObjectType() == "Texture" and rg:GetTexture() == 131080 then rg:SetAlpha(0); rg.xuiWasTitle = true end
    end
    if not fr.xuiTitleBar then
        fr.xuiTitleBar = fr:CreateTexture(nil, "ARTWORK")
        fr.xuiTitleBar:SetColorTexture(0.13, 0.13, 0.13, 1)
    end
    fr.xuiTitleBar:ClearAllPoints()
    fr.xuiTitleBar:SetPoint("TOPLEFT", 1, -1); fr.xuiTitleBar:SetPoint("TOPRIGHT", -1, -1); fr.xuiTitleBar:SetHeight(28)
    fr.xuiTitleBar:SetShown(not collapsed)
    of.titletext:ClearAllPoints(); of.titletext:SetPoint("TOP", fr, "TOP", 0, -9)
    of.titletext:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    -- toolbar (content moves down to make room)
    local bar = EnsureToolbar(of)
    bar:ClearAllPoints(); bar:SetPoint("TOPLEFT", fr, "TOPLEFT", 17, -34); bar:SetPoint("TOPRIGHT", fr, "TOPRIGHT", -17, -34)
    bar:SetShown(not collapsed)
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

local function SkinTabGroup(w)
    PaneColors(w.border, { 0.04, 0.04, 0.04, A() * 0.6 }, { 0.3, 0.3, 0.3 })
    for _, tab in ipairs(w.tabs or {}) do
        if tab:IsShown() then
            for _, k in ipairs({ "Left", "Middle", "Right", "LeftDisabled", "MiddleDisabled", "RightDisabled" }) do
                if tab[k] then tab[k]:SetAlpha(0) end
            end
            if tab.HighlightTexture then tab.HighlightTexture:SetAlpha(0) end
            local sel = tab.selected and true or false
            -- AceGUI tabs overlap by ~10px (the Blizzard art has transparent edges), so the box is inset to keep each border whole
            Flat(tab, sel and { 0.22, 0.1, 0.3, 0.9 } or { 0.03, 0.03, 0.03, 0.7 }, sel and { 0.8, 0.5, 1, 1 } or { 0.22, 0.22, 0.22, 1 }, { 9, 9, 6, 3 })
            local fs = tab:GetFontString()
            if fs then if sel then fs:SetTextColor(1, 1, 1) else fs:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) end end
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
-- the rule tree (the one that has the All Rules row) carries the search box at its top
local function EnsureTreeSearch(w)
    local has = false
    for _, b in ipairs(w.buttons or {}) do if b:IsShown() and tostring(b.uniquevalue or "") == "all" then has = true; break end end
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
    PaneColors(w.treeframe, { 0.03, 0.03, 0.03, A() * 0.6 }, { 0.3, 0.3, 0.3 })
    if not w.xuiPartHooked then   -- re-partition inside every refresh (outermost wrapper: runs after Options.lua's row decorating)
        w.xuiPartHooked = true
        local origRefresh = w.RefreshTree
        w.RefreshTree = function(self, ...)
            -- AceGUI sizes its scroll window assuming 18px rows; our rows are taller, so rows ran past the bottom of the sidebar
            -- (over Addon Info). While it refreshes, report a proportionally shorter height so the visible-line count matches the
            -- real row height, then clip anything left over.
            local tf = self.treeframe
            local avg = self.xuiAvgH
            local scaled = false
            if SkinOn() and tf and avg and avg > 19 and not rawget(tf, "GetHeight") then
                local real = tf.GetHeight
                tf.GetHeight = function(f) return real(f) * 18 / avg end
                scaled = true
            end
            local ok, err = pcall(origRefresh, self, ...)
            if scaled then tf.GetHeight = nil end
            if not ok then error(err, 0) end
            if tf and tf.SetClipsChildren then tf:SetClipsChildren(SkinOn()) end
            local sum, cnt = 0, 0
            for _, b in ipairs(self.buttons or {}) do if b:IsShown() then sum = sum + b:GetHeight(); cnt = cnt + 1 end end
            self.xuiAvgH = cnt > 0 and (sum / cnt) or nil
            pcall(PartitionAllRules, self)
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
        end
    end
    OnRelease(w, function(self)
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
            if ht and b.xuiHT then ht:SetTexture(b.xuiHT[1]); ht:SetVertexColor(unpack(b.xuiHT[2])); ht:SetBlendMode(b.xuiHT[3]); b.xuiHT = nil end
        end
    end)
end

-- Row action icons on a header button (arg.xuiActions = function returning { up, down, copy, del }; a function runs on click,
-- false shows the icon greyed out, nil leaves the slot empty). Slots are fixed so icons line up from row to row.
local ACT_SLOTS = { { "up", -76 }, { "down", -52 }, { "copy", -28 }, { "del", -4 } }
local ACT_TIP = { up = "Move up", down = "Move down", copy = "Duplicate", del = "Remove" }
local function MakeAction(f, key)
    local b = CreateFrame("Button", nil, f)
    b:SetSize(20, 20)
    b:SetFrameLevel(f:GetFrameLevel() + 3)
    if key == "del" then
        b.label = b:CreateFontString(nil, "OVERLAY")
        b.label:SetFont("Fonts\\FRIZQT__.TTF", 18, "OUTLINE")
        b.label:SetPoint("CENTER"); b.label:SetText("X"); b.label:SetTextColor(1, 0.12, 0.12)
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
            fs:SetFont(font, 15, flags)
            fs:SetTextColor(1, 1, 1)
        end
        if arg and type(arg.xuiArrow) == "function" then
            if fs and w.xuiFont then fs:SetFont(w.xuiFont[1], 18, w.xuiFont[3]) end   -- h2
            if not f.xuiArrowTex then f.xuiArrowTex = f:CreateTexture(nil, "OVERLAY"); f.xuiArrowTex:SetSize(16, 16) end
            local at = f.xuiArrowTex
            local okOpen, open = pcall(arg.xuiArrow)
            at:ClearAllPoints(); at:SetPoint("RIGHT", f, "RIGHT", -8, 0)
            at:SetTexture((okOpen and open) and "Interface\\Buttons\\Arrow-Down-Up" or "Interface\\ChatFrame\\ChatFrameExpandArrow")
            at:SetVertexColor(0.8, 0.5, 1); at:Show()
        elseif f.xuiArrowTex then f.xuiArrowTex:Hide() end
    else
        HideRegions(f, f:GetHighlightTexture())
        Flat(f, { 0.04, 0.04, 0.04, 0.7 }, { 0.25, 0.25, 0.25, 1 })
        if arg and arg.xuiRed then Flat(f, { 0.42, 0.04, 0.04, 0.95 }, { 0.65, 0.12, 0.12, 1 }) end   -- WeakAuras-style red "Add ..." button
        if fs then
            if f:IsEnabled() then fs:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) else fs:SetTextColor(0.5, 0.5, 0.5) end
        end
    end
    PaintActions(w, arg)
    OnRelease(w, function(self)
        if self.frame.xuiArrowTex then self.frame.xuiArrowTex:Hide() end
        HideActions(self.frame)
        ShowRegions(self.frame)
        FlatHide(self.frame)
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
        PaneColors(w.border, { 0.04, 0.04, 0.04, A() * 0.5 }, { 0.25, 0.25, 0.25 })
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
            lab:ClearAllPoints(); lab:SetPoint("LEFT", img, "RIGHT", 18, 0)
            lab:SetWidth(math.max(60, fw - 8 - iw - 18 - 16))
            lab:SetJustifyV("MIDDLE")
            if not f.xuiSep then f.xuiSep = f:CreateTexture(nil, "BORDER"); f.xuiSep:SetColorTexture(0.3, 0.3, 0.3, 1); f.xuiSep:SetWidth(1) end
            f.xuiSep:ClearAllPoints()
            f.xuiSep:SetPoint("TOP", f, "TOP", 0, -6); f.xuiSep:SetPoint("BOTTOM", f, "BOTTOM", 0, 6)
            f.xuiSep:SetPoint("LEFT", img, "RIGHT", 8, 0)
            f.xuiSep:Show()
        end
        Place()
        local need = math.max(ih, math.ceil(lab:GetStringHeight()) + 2) + 20   -- the extra pixels are the gap between rows now that the outline is gone
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
    elseif lab then
        lab:SetJustifyV("MIDDLE")
    end
    OnRelease(w, function(self)
        if self.frame.xuiSep then self.frame.xuiSep:Hide() end
        self.xuiRowKey = nil
        self.frame.xuiMinH = nil; self.frame.SetHeight = nil
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
ns.TYPE_ICONS.stgroup = 1120185   -- static groups use this game icon (file ID) instead of the shipped crop
ns.TYPE_ICONS.progressbar = ICON_DIR .. "progresstex"   -- the old progress-texture crop now marks progress bars
ns.TYPE_ICONS.progresstex = ICON_DIR .. "sttexture"      -- the old texture crop now marks progress textures
ns.TYPE_ICONS.sttexture = 1323036                         -- textures use this game icon (file ID)
ns.TYPE_ICONS.sound = ICON_DIR .. "stgroup"                -- the red rune crop now marks sound cues
ns.TYPE_ICONS.import = 252269                             -- import uses this game icon (file ID)
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
-- left-of-text icon on sidebar rows of the rule trees; returns the width the row text must leave free
function ns.PaintTypeIcon(button, x)
    local uv = tostring(button.uniquevalue or "")
    local root = uv:match("^([^\001]+)")
    local level = button.level or 1
    local slot = SkinOn() and level >= 2 and (root == "all" or root == "loaded" or root == "notloaded")
    local key
    if slot then
        local last = uv:match("([^\001]+)$") or ""
        local n = last:match("^rule(%d+)$")
        if n then
            local r = ns.rules and ns.rules[tonumber(n)]
            key = r and ns.TypeKey(r)
        elseif last:match("^f%d") then
            local f = ns.FolderById and ns.FolderById(last)
            if f and f.default ~= "cursor" and ns.KindHas and ns.KindHas({ folder = f.id }, "visual") then key = (f.cType == "dynamic") and "dyngroup" or "stgroup" end
        end
    end
    if not slot then if button.xuiType then button.xuiType:Hide() end return 0 end
    if key then
        if not button.xuiType then
            button.xuiType = button:CreateTexture(nil, "ARTWORK")
            button.xuiType:SetSize(16, 16)
        end
        button.xuiType:ClearAllPoints(); button.xuiType:SetPoint("LEFT", button, "LEFT", x, 0)
        button.xuiType:SetTexture(ns.TYPE_ICONS[key]); button.xuiType:Show()
    elseif button.xuiType then
        button.xuiType:Hide()
    end
    return 20
end

local function Walk(w, depth)
    if not w or depth > 14 then return end
    local t = w.type
    if t == "TabGroup" then SkinTabGroup(w)
    elseif t == "TreeGroup" then SkinTree(w)
    elseif t == "Button" then SkinButton(w)
    elseif t == "InlineGroup" then SkinInline(w)
    elseif t == "Dropdown" or t == "Dropdown-Pullout" then
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
        pcall(Walk, root, 0)
    end
end
