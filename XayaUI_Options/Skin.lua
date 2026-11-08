-------------------------------------------------------------------------------
-- Skin.lua : flat dark look for the XayaUI options window (flat dark panes, gold tabs, toolbar + search).
-- Pure cosmetics layered on top of Options.lua through ns.DecorateTrees. Every change is undone when the AceGUI widget is
-- released (AceGUI recycles widgets across addons). Turn it off with /xuiskin (then /reload).
-------------------------------------------------------------------------------
local addonName, ns = ...
ns = _G.XayaUI_NS or ns   -- one namespace with XayaUI core (this addon depends on it: ## Dependencies: XayaUI)
local PlatS = ns.Settings("platform")   -- (Options 0.6.82, P2 settings seam: the same CueRulesDB keys as before; Modules.lua section 0b)
local APP = "CueRules"
local ACD = LibStub and LibStub("AceConfigDialog-3.0", true)
if not ACD then return end

local WHITE8 = "Interface\\Buttons\\WHITE8X8"
local GOLD = { 1, 0.82, 0, 1 }
local TH = ns.Theme
-- (Options 0.6.104, #472; docs/plans/PLATFORM-SPLIT-2026-11-07.md section 6.6) the settings window's theme scope ("settings", core
-- Theme.lua): its own theme or colours from Blizzard Reskin > Theme, else the global theme exactly as before
local SCOPE = "settings"
ns.OptionsApi.SCOPE = SCOPE
if TH then TH.Bind("label", GOLD, SCOPE) end
-- style-sheet color for a class property ({r,g,b,a}); falls back to the given color when Theme.lua is missing
local function TC(class, prop, fb) if TH then return TH.Col(class, prop, SCOPE, fb) end return fb end
-- (#460, Options 0.6.101) the class property's gradient, or nil when it is solid (core's Theme.lua T.Grad; nil without it)
local function TG(class, prop) if TH and TH.Grad then return TH.Grad(class, prop, SCOPE) end return nil end
-- theme font + size on a fontstring (color is set by the caller)
local function TF(fs) if TH and fs then pcall(TH.Style, fs, nil) end end
local function TR(fs) if TH and fs then pcall(TH.Restore, fs) end end
-- Light themes: a button / tab keeps its text in Blizzard font OBJECTS, which carry a shadow (and sometimes an outline) and put it back on every
-- hover. So the button gets plain font objects (no shadow, no outline) in the theme font and color; RestoreLF puts the originals back.
local lightFonts, lfCount = {}, 0
local function LightFont(b, fs, c)
    if not (b and fs and b.SetNormalFontObject and TH and TH.IsLight and TH.IsLight()) then return end
    local fn, sz = fs:GetFont()
    if not fn then return end
    local key = fn .. "|" .. math.floor((sz or 12) * 10) .. ("|%.2f%.2f%.2f"):format(c[1], c[2], c[3])
    local fo = lightFonts[key]
    if not fo then
        lfCount = lfCount + 1
        fo = CreateFont("XayaUILightFont" .. lfCount)
        fo:SetFont(fn, sz, ""); fo:SetShadowOffset(0, 0); fo:SetTextColor(c[1], c[2], c[3], 1)
        lightFonts[key] = fo
    end
    if not b.xuiLFRest then
        local n, h, d = b:GetNormalFontObject(), b:GetHighlightFontObject(), b:GetDisabledFontObject()
        b.xuiLFRest = function(self)
            if n then self:SetNormalFontObject(n) end
            if h then self:SetHighlightFontObject(h) end
            if d then self:SetDisabledFontObject(d) end
        end
    end
    b:SetNormalFontObject(fo); b:SetHighlightFontObject(fo); b:SetDisabledFontObject(fo)
    fs:SetShadowOffset(0, 0)
end
local function RestoreLF(b) if b and b.xuiLFRest then pcall(b.xuiLFRest, b); b.xuiLFRest = nil end end
local function SkinOn() return not (PlatS.ui and PlatS.ui.skinOff) end
-- window opacity (0.1 - 1). /xuiskin alpha 0.4 changes it; takes effect on the next redraw / reopen.
local function Pad() local u = PlatS.ui; return math.max(0, math.min(30, tonumber(u and u.skinPad) or 8)) end
local function A()
    local u = PlatS.ui
    local a = (u and tonumber(u.skinAlpha)) or 0.62
    if TH and TH.IsLight and TH.IsLight() then a = a * 0.85 end   -- light themes: a further 15% more see-through (Xaya, 2026-11-01)
    return a
end

-- /xuiskin lives in core (Modules.lua) so it works before this addon is loaded.

-- flat 1px-bordered box drawn with plain textures (inset = { l, r, t, b }); grad (#460): the border's gradient (TG), nil = solid
local function Flat(f, bg, border, inset, grad)
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
    if (grad or f.xuiGradE) and TH and TH.PaintEdges then TH.PaintEdges(f, t.e, border, grad, "BACKGROUND", -2); return end   -- (#460)
    for _, e in ipairs(t.e) do e:SetColorTexture(border[1], border[2], border[3], border[4] or 1); e:Show() end
end
local function FlatHide(f)
    local t = f and f.xuiFlat
    if not t then return end
    t.bg:Hide(); for _, e in ipairs(t.e) do e:Hide() end
    if f.xuiGradE and TH and TH.HideGrad then TH.HideGrad(f) end   -- (#460) the gradient pieces too
end

-- hide every texture of a frame except the ones listed in keep (remembered, so it can be undone)
local function HideRegions(f, keep)
    if f.xuiHidden then return end
    f.xuiHidden = {}
    for _, rg in ipairs({ f:GetRegions() }) do
        if rg.GetObjectType and rg:GetObjectType() == "Texture" and rg ~= keep and not (f.xuiFlat and (rg == f.xuiFlat.bg)) and not rg.xuiOwn then   -- (#460: xuiOwn = a gradient piece)
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
-- Flat addon look for a plain Blizzard-template Button (not an AceGUI widget). UI-77 (Options 0.6.67): the look lives in core
-- (Core.lua ns.PaintFlatButton) so core's windows have it without this addon loaded; this name stays for the settings addon's callers.
function ns.SkinPlainButton(b, primary)
    if ns.PaintFlatButton then return ns.PaintFlatButton(b, primary) end
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
-- #351 (Xaya, 2026-11-03: "set a standard gutter and margin so that all elements are not smushed directly into their container bounds"):
-- the space inside every container XayaUI insets (margin) and between two controls on a row (gutter). Defined once, in core
-- (XayaUI/Modules.lua, since #351 phase 2); the 10s here are only for the stand-in tests that load this file without core.
-- AceGUI's own default inset is the same 10 px; release handlers that give a widget back to AceGUI restore AceGUI's literal 10.
local UI_MARGIN, UI_GUTTER = ns.UI_MARGIN or 10, ns.UI_GUTTER or 10

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

-- #468 / #471 / #483 (Options 0.6.97): the Blizzard-template buttons AceGUI makes INSIDE its widgets, which are not AceGUI Button widgets
-- and so never reached the button skin: the window's bottom Close (AceGUI Frame), the "Okay" of a one-line text box (EditBox: the rule
-- option search) and the "Accept" of a multi-line box (MultiLineEditBox: Theme string, export / import boxes). XayaUI's own windows
-- always have the flat look (standing rule in #468), whatever Blizzard Reskin > Buttons says. They get the same look as the window's
-- AceGUI buttons (SkinButton's plain-button branch): theme "xui-button" box, flat hover, theme text. AceGUI hands these widgets to other
-- addons after release, and core's ns.PaintFlatButton has no undo, so the look is put on here and taken off by UnflatInner on release.
-- Only the look changes: size, place, text and what a click does stay AceGUI's.
local function FlatInner(b)
    if not (b and b.GetHighlightTexture and b.GetFontString) then return end
    HideRegions(b, b:GetHighlightTexture())
    Flat(b, TC("xui-button", "bg", { 0.04, 0.04, 0.04, 0.7 }), TC("xui-button", "border", { 0.25, 0.25, 0.25, 1 }), nil, TG("xui-button", "border"))
    local ht = b:GetHighlightTexture()
    if ht then
        if not b.xuiHLOrig then b.xuiHLOrig = { ht:GetTexture(), ht:GetBlendMode() } end
        local hc = TC("xui-button", "border", { 0.75, 0.4, 1, 1 })
        ht:SetTexture(WHITE8); ht:SetTexCoord(0, 1, 0, 1)
        ht:SetBlendMode("ADD"); ht:SetVertexColor(hc[1], hc[2], hc[3]); ht:SetAlpha(0.28)
        ht:ClearAllPoints(); ht:SetAllPoints(b)
    end
    local fs = b:GetFontString()
    if fs then
        TF(fs)
        local on = not b.IsEnabled or b:IsEnabled()
        local c = on and TC("xui-button", "text", GOLD) or TC("xui-text-muted", "text", { 0.5, 0.5, 0.5, 1 })
        fs:SetTextColor(c[1], c[2], c[3])
        LightFont(b, fs, TC("xui-button", "text", GOLD))
    end
    b.xuiInnerFlat = true
end
local function UnflatInner(b)
    if not (b and b.xuiInnerFlat) then return end
    b.xuiInnerFlat = nil
    ShowRegions(b)
    FlatHide(b)
    RestoreLF(b)
    local ht, o = b:GetHighlightTexture(), b.xuiHLOrig
    if ht and o then   -- Blizzard's highlight art back (UIPanelButtonTemplate's, as SkinButton's release does)
        ht:SetTexture(o[1] or "Interface\\Buttons\\UI-Panel-Button-Highlight"); ht:SetTexCoord(0, 0.625, 0, 0.6875)
        ht:SetBlendMode(o[2] or "ADD"); ht:SetVertexColor(1, 1, 1); ht:SetAlpha(1)
        ht:ClearAllPoints(); ht:SetPoint("TOPLEFT", 2, -2); ht:SetPoint("BOTTOMRIGHT", -2, 2)
    end
    b.xuiHLOrig = nil
    local fs = b:GetFontString()
    if fs then
        TR(fs)
        if not b.IsEnabled or b:IsEnabled() then fs:SetTextColor(1, 0.82, 0) else fs:SetTextColor(0.5, 0.5, 0.5) end
    end
end
-- the AceGUI Frame's bottom Close button: AceGUI keeps no field for it (AceGUIContainer-Frame.lua: closebutton.obj = widget, like the
-- status bar's), so it is the frame's child Button that points back at the widget and carries text
local function FrameCloseButton(of)
    local fr = of and of.frame
    if not (fr and fr.GetChildren) then return nil end
    local sb = of.statustext and of.statustext.GetParent and of.statustext:GetParent()
    for _, ch in ipairs({ fr:GetChildren() }) do
        if ch ~= sb and ch.obj == of and ch.GetObjectType and ch:GetObjectType() == "Button" and ch.GetText and ch:GetText() then return ch end
    end
end
ns.OptionsApi.FrameCloseButton = FrameCloseButton   -- (Dev Assist's walkthrough "debug-w3")

-------------------------------------------------------------------------------
-- Rule search box (filters the rule list by name). The toolbar that was here is gone (Options 0.6.72).
-------------------------------------------------------------------------------
ns.treeFilter = ""
local filterStamp = 0

local function HoverCol() return TC("xui-list-selected", "text", { 1, 1, 1, 1 }) end   -- lit / hover text: the theme's selected-text color
-- a theme change also repaints every rule-list row (their text color was set when the row was drawn: dark text from Light mode stayed on a dark theme)
if TH and TH.OnResolve then TH.OnResolve(function() if C_Timer then C_Timer.After(0.05, function() if ns.DecorateTrees then pcall(ns.DecorateTrees) end end) end end) end
ns.On("THEME_CHANGED", function() if ns.DecorateTrees then pcall(ns.DecorateTrees) end end)   -- live theme edits (Theme.lua)

-- Rule search box: nested at the top of the All Rules sidebar, above the Loaded row. Typing filters the rule lists (ns.treeFilter).
-- Filtering ends in Notify(), which rebuilds the tree and can release / hide the box, dropping its keyboard focus (the next letter then
-- fires an action bar keybind). So the debounce notes that the box had focus, and every live box gets it back right after the rebuild.
local searchBoxes = setmetatable({}, { __mode = "k" })
local function RestoreSearchFocus()
    local rf = ns.treeSearchRefocus
    if not rf then return end
    if GetTime() - rf.t > 1 then ns.treeSearchRefocus = nil; return end
    local cur = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
    for sb in pairs(searchBoxes) do
        if sb:IsShown() and sb:IsVisible() then
            if cur and cur ~= sb then ns.treeSearchRefocus = nil; return end   -- she clicked into some other text box: leave it alone
            if not sb:HasFocus() then
                sb:SetFocus()
                sb:SetCursorPosition(math.min(rf.pos or 0, #(sb:GetText() or "")))
                sb:HighlightText(0, 0)
            end
            return
        end
    end
end
local function MakeSearchBox(parent)
    local sb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    sb:SetAutoFocus(false); sb:SetHeight(20)
    searchBoxes[sb] = true
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
        C_Timer.After(0.25, function()
            if stamp ~= filterStamp then return end
            if sb:HasFocus() then ns.treeSearchRefocus = { pos = sb:GetCursorPosition(), t = GetTime() } end
            if ns.UI and ns.UI.Notify then ns.UI.Notify() end
            RestoreSearchFocus()
            C_Timer.After(0, RestoreSearchFocus)     -- the rebuild can finish on the next frame
            C_Timer.After(0.1, RestoreSearchFocus)
        end)
    end)
    sb:SetText(ns.treeFilter or "")
    refreshHint(sb)
    return sb
end

-- (Options 0.6.72; REQUEST-LOG UI-23 to UI-27, Xaya 2026-11-06: "I believe these almost exclusively belong to rules so they should be
-- put under the rules tab and the Rules / QOL / Bonus Features / Reskin / Settings should be at the top level now instad"; "Cog goes")
-- The toolbar above the tabs (New Rule, Import, Export, Recycle Bin, the hidden Lock Positions, the Settings cog) is gone: "+ New Rule"
-- is on the Rules tab's top row (CompactRulesTabs), Import / Export / Recycle Bin are sub-tabs of Profiles, Settings is a top tab.

-------------------------------------------------------------------------------
-- Per-widget skins
-------------------------------------------------------------------------------
local CONTENT_TOP = -34   -- (was -62 under the toolbar)
ns.OptionsContentTop = CONTENT_TOP
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
            if f.xuiGradBox and TH then TH.HideGrad(f) end   -- (#460)
            if self.xuiOrigBackdrop then f:SetBackdrop(self.xuiOrigBackdrop) end
            f:SetBackdropColor(0, 0, 0, 1); f:SetBackdropBorderColor(1, 1, 1, 1)
            for _, rg in ipairs({ f:GetRegions() }) do if rg.xuiWasTitle then rg:SetAlpha(1); rg.xuiWasTitle = nil end end
            if f.xuiTitleBar then f.xuiTitleBar:Hide() end
            if f.xuiDrag then f.xuiDrag:Hide() end
            if f.xuiToolbar then f.xuiToolbar:Hide() end   -- (a window skinned by an older Options before an in-session update)
            UnflatInner(self.xuiCloseBtn); self.xuiCloseBtn = nil   -- #468: the next addon to get this window has AceGUI's own Close
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
        -- (#460) a gradient border: the backdrop's own edge (one colour only) is cleared and the window gets four edges of its own
        local wg = TG("xui-window", "border")
        if wg and TH and TH.EdgeBox then
            fr:SetBackdropBorderColor(0, 0, 0, 0)
            TH.PaintEdges(fr, TH.EdgeBox(fr, "BORDER", 7), wbd, wg, "BORDER", 7)
        else
            fr:SetBackdropBorderColor(wbd[1], wbd[2], wbd[3], 1)
            if fr.xuiGradBox and TH then TH.HideGrad(fr) end
        end
    end
    -- #468: the bottom Close button in the flat look (every pass, so a theme change repaints it)
    of.xuiCloseBtn = of.xuiCloseBtn or FrameCloseButton(of)
    FlatInner(of.xuiCloseBtn)
    -- (#460) the title bar's ? and collapse arrow (core's flat buttons, Options.lua c.flatChrome) on every pass too: before, only when
    -- they were shown again, so a theme change (a gradient border on or off) reached them only after the window was reopened
    do local ch = of.xuiChrome; if ch and ch.flatChrome then pcall(ch.flatChrome, ch.arrow); pcall(ch.flatChrome, ch.help) end end
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
    -- (AceGUI's status bar under the content is hidden by Options.lua EnsureChrome: this window does not use it. A flat "band" that
    -- was meant to replace it here never ran: it looked for of.statusbg, which AceGUI's Frame widget does not keep.)
    -- no toolbar any more (Options 0.6.72): the content starts right under the title strip, where the toolbar was
    if fr.xuiToolbar then fr.xuiToolbar:Hide() end
    local c = of.content
    local p1 = { c:GetPoint(1) }
    if p1[5] ~= CONTENT_TOP then
        c:ClearAllPoints(); c:SetPoint("TOPLEFT", fr, "TOPLEFT", 17, CONTENT_TOP); c:SetPoint("BOTTOMRIGHT", fr, "BOTTOMRIGHT", -17, 40)
    end
end

local function PaneColors(frame, bg, border)
    if frame and frame.SetBackdropColor then frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4]); frame:SetBackdropBorderColor(border[1], border[2], border[3], 1) end
end
-- (Options 0.6.55; REQUEST-LOG UI-6 / UI-7; Xaya 2026-11-06: "we don't need to display double-nested boxes. replace the visual of the
-- two column pane boxed display with a clean divider line and remove the frames otherwise", her answer "Borders go, fills stay".)
-- The left pane, the right pane and the tab row's box keep their fill and lose their border line; one line divides the two panes.
local function PaneFill(frame, bg)
    if frame and frame.SetBackdropColor then frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4]); frame:SetBackdropBorderColor(0, 0, 0, 0) end
end
local function PaneDivider(w)
    local tf = w and w.treeframe
    if not (tf and w.frame and w.frame.CreateTexture) then return end
    local d = w.xuiDivider
    if not d then d = w.frame:CreateTexture(nil, "ARTWORK"); w.xuiDivider = d end
    local c = TC("xui-pane", "border", { 0.3, 0.3, 0.3, 1 })
    local g = TG("xui-pane", "border")   -- (#460)
    if not (g or d.xuiGradL) then d:SetColorTexture(c[1], c[2], c[3], 1) end
    d:ClearAllPoints()
    d:SetPoint("TOPLEFT", tf, "TOPRIGHT", 0, 0)
    d:SetPoint("BOTTOMLEFT", tf, "BOTTOMRIGHT", 0, 0)
    d:SetWidth(ns.Style.divider.size)
    d:Show()
    if (g or d.xuiGradL) and TH and TH.PaintLine then TH.PaintLine(w.frame, d, { c[1], c[2], c[3], 1 }, g, "V", "ARTWORK") end
end

-- /xui debug perf: time every pane / tab switch (OnGroupSelected) so the slow or late step can be named
local function TraceGroupFire(w, what)
    if w.xuiFireTraced then return end
    w.xuiFireTraced = true
    local orig = w.Fire
    w.Fire = function(self, ev, ...)
        if ev ~= "OnGroupSelected" then return orig(self, ev, ...) end
        -- A tab / tree switch builds the new pane's widgets inside this call. They are plain AceGUI widgets until the skin pass runs, and
        -- that pass used to wait for a 0.25 s timer, so the old skin showed for a few frames (the "flash"). Run it here instead: right
        -- after the pane is built, in the same frame, before anything is drawn. Only the OUTERMOST switch does it (a tree click fires
        -- the tab switch inside it), and never from inside the skin pass itself (the pass can re-select the tree, which fires another
        -- switch: without this guard that is a loop).
        local tracing = ns.perf and ns.perf.show
        local t0
        if tracing then ns.Trace("click"); ns.Trace(what .. " switch -> " .. tostring((...))); t0 = debugprofilestop() end
        ns.xuiFireDepth = (ns.xuiFireDepth or 0) + 1
        local okF, r1, r2 = pcall(orig, self, ev, ...)
        ns.xuiFireDepth = ns.xuiFireDepth - 1   -- (pcall: an error in the pane must not leave the counter stuck)
        if ns.xuiFireDepth == 0 and not ns.xuiDecorating and ns.DecorateTrees then
            ns.xuiDecorating = true
            local t1 = tracing and debugprofilestop()
            pcall(ns.DecorateTrees)
            ns.xuiDecorating = nil
            if tracing then ns.Trace(string.format("%s switch built in %.0f ms + skin %.0f ms", what, t1 - t0, debugprofilestop() - t1)) end
        end
        if tracing and C_Timer then C_Timer.After(0, function() ns.Trace("next frame after " .. what .. " switch (anything below this ran late)") end) end
        if not okF then error(r1, 0) end
        return r1, r2
    end
    AddRest(w, "firetrace", function(self) rawset(self, "Fire", nil); self.xuiFireTraced = nil end)
end

-- One tab row drawn by hand (Options 0.6.55 top row; Options 0.6.63 the Rules row): each slot = { tab, x, width }; every tab H px tall,
-- its name in the theme's font at SIZE pt with an outline (a font object per tab, so a hover or a click, which re-applies the button's
-- font objects, keeps it); the box below starts under the row. Restored on release (SkinTabGroup's OnRelease, w.xuiTopRow).
local function LayTabRow(w, slots, H, SIZE)
    -- (Options 0.6.63; REQUEST-LOG UI-50, her answer "Scale with theme": her sizes are the theme's Medium text size; Small / Large
    -- scale the tab's height and its name by the same factor, Theme.Scale(): 0.88 / 1 / 1.15)
    local sc = (TH and TH.Scale and TH.Scale()) or 1
    H = math.floor(H * sc + 0.5)
    SIZE = math.floor(SIZE * sc * 10 + 0.5) / 10
    local hastitle = w.titletext and w.titletext:GetText() and w.titletext:GetText() ~= ""
    local top = hastitle and 14 or 7
    for _, sl in ipairs(slots) do
        local tab, x, each = sl[1], sl[2], sl[3]
        tab:ClearAllPoints()
        tab:SetPoint("TOPLEFT", w.frame, "TOPLEFT", x, -top)
        tab:SetSize(each, H)
        for _, k in ipairs({ "Middle", "MiddleDisabled" }) do if tab[k] then tab[k]:SetWidth(math.max(1, each - 20)) end end
        tab.selectedTextY, tab.deselectedTextY, tab.selectedTextX, tab.deselectedTextX = 0, 0, 0, 0
        local fs = tab:GetFontString()
        if fs then
            if fs.SetWidth then fs:SetWidth(math.max(1, each - 8)) end
            fs:ClearAllPoints(); fs:SetPoint("CENTER", tab, "CENTER", 0, 0)
            -- (Options 0.6.63; UI-49 "theme has to tie into the skin.lua") the theme's font when one is set (Theme > Font), else the font
            -- the tab already has; a theme font file that will not load (new fonts need a game restart) falls back the same way
            local path = TH and TH.FontPath and TH.FontPath()
            if path then local ok, res = pcall(fs.SetFont, fs, path, SIZE, "OUTLINE"); if not ok or res == false then path = nil end end
            path = path or fs:GetFont()
            local c = TC(tab.selected and "xui-tab-selected" or "xui-tab", "text", GOLD)
            local fo = tab.xuiTopFont
            if not fo then fo = CreateFont((tab:GetName() or "XayaUITopTab") .. "XuiTopFont"); tab.xuiTopFont = fo end
            if path then fo:SetFont(path, SIZE, "OUTLINE") end
            fo:SetTextColor(c[1], c[2], c[3], 1)
            tab:SetNormalFontObject(fo); tab:SetHighlightFontObject(fo); tab:SetDisabledFontObject(fo)
            if path then fs:SetFont(path, SIZE, "OUTLINE") end   -- (the shown name at once, before the button re-applies its object)
            fs:SetTextColor(c[1], c[2], c[3])
        end
        local tcl = tab.selected and "xui-tab-selected" or "xui-tab"
        Flat(tab, TC(tcl, "bg", { 0.03, 0.03, 0.03, 0.7 }), TC(tcl, "border", { 0.22, 0.22, 0.22, 1 }), { 1, 1, 0, 0 }, TG(tcl, "border"))
    end
    w.borderoffset = top + H + 3
    if w.border then w.border:SetPoint("TOPLEFT", 1, -w.borderoffset) end
    if w.frame.height and w.OnHeightSet then pcall(w.OnHeightSet, w, w.frame.height) end
    w.xuiTopRow = true
end

-- The Rules sub-tab row (Smart Categories | Enabled | Disabled | Drafts ... Auto-Generate Rules). (Options 0.6.63; REQUEST-LOG UI-43 to
-- UI-45, Xaya 2026-11-06: "rule tabs are too tiny"; "tabs are still not reflecting proposed changes as requested in subsequent
-- comments"; her answers "28 px, 12 pt, outlined" and, for the Creator tab, "2 + call it "Auto-Generate Rules"" (it stays apart at the
-- far right): the other tabs share the rest of the row evenly; Auto-Generate Rules is as wide as its name at 12 pt plus 24 px (at most a
-- third of the row), 16 px after the others. (Before: each tab as wide as its text, Options 0.6.39.)
local SUB_TAB_H, SUB_TAB_FONT, SUB_GAP = ns.Style.tabSub.h, ns.Style.tabSub.font, ns.Style.tabSub.apartGap   -- (core ns.Style, UI-47)
local function CompactRulesTabs(w)
    if not (w and w.tabs and w.frame) then return end
    local creator, others = nil, {}
    for _, tab in ipairs(w.tabs) do
        if tab:IsShown() then if tab.value == "creatorTab" then creator = tab else others[#others + 1] = tab end end
    end
    if not creator then return end
    local width = w.frame.width or w.frame:GetWidth() or 0
    if width <= 0 then return end
    local fs = creator:GetFontString()
    local sw = (fs and fs.GetStringWidth and fs:GetStringWidth()) or 120
    local cur
    if fs then cur = select(2, fs:GetFont()) end
    local tf = SUB_TAB_FONT * ((TH and TH.Scale and TH.Scale()) or 1)   -- (UI-50: the name's size at the theme's text size)
    local cw = math.ceil(sw * tf / math.max(1, tonumber(cur) or tf)) + 24
    cw = math.min(cw, math.floor(width / 3))
    -- (Options 0.6.72; UI-25, her words: New Rule goes on the "Rules tab's top row") "+ New Rule" is a flat button at the left end of
    -- the row, as wide as its name plus 24 px, SUB_GAP before the tabs. (Where on the row was not given by her: left end chosen while she
    -- was away, 2026-11-07; in her QA question flow, key UI-25-newrule.)
    -- (Options 0.6.66; UI-76, O-146: "make these tabs a little narrower and maybe 3-5% smaller") each tab ns.Style.tabSub.share (90%) of
    -- its even share of what is left of the row, the spare width as equal gaps after each tab
    local nb = ns.RulesNewRuleButton(w)
    local nw = 0
    if nb then
        local nfs = nb:GetFontString()
        nw = math.ceil((nfs and nfs.GetStringWidth and nfs:GetStringWidth() or 70)) + 24
        nw = math.min(nw, math.floor(width / 5))
    end
    local left = nb and (nw + SUB_GAP) or 0
    local slot = (#others > 0) and ((width - left - cw - SUB_GAP) / #others) or 0
    local each = slot * (ns.Style.tabSub.share or 1)
    local slots = {}
    for i, tab in ipairs(others) do slots[#slots + 1] = { tab, left + (i - 1) * slot, each } end
    slots[#slots + 1] = { creator, width - cw, cw }
    LayTabRow(w, slots, SUB_TAB_H, SUB_TAB_FONT)
    if nb then
        local sc = (TH and TH.Scale and TH.Scale()) or 1
        local hastitle = w.titletext and w.titletext:GetText() and w.titletext:GetText() ~= ""
        nb:ClearAllPoints()
        nb:SetPoint("TOPLEFT", w.frame, "TOPLEFT", 0, -(hastitle and 14 or 7))
        nb:SetSize(nw, math.floor(SUB_TAB_H * sc + 0.5))
        nb:Show()
    end
end

-- the "+ New Rule" button of the Rules row: one per tab container, made the first time the Rules row is laid out, hidden when the
-- container is released (AceGUI gives it to another tab row) or lays out any other row
function ns.RulesNewRuleButton(w)
    if not (w and w.frame and CreateFrame) then return nil end
    local b = w.xuiNewRule
    if not b then
        b = CreateFrame("Button", nil, w.frame, "UIPanelButtonTemplate")
        b:SetText("+ New Rule")
        b:SetScript("OnClick", function() if ns.UI and ns.UI.NewRule then ns.UI.NewRule() end end)
        b.xuiNewRuleBtn = true
        w.xuiNewRule = b
        AddRest(w, "newrule", function(self) if self.xuiNewRule then self.xuiNewRule:Hide() end end)
    end
    b:SetFrameLevel(w.frame:GetFrameLevel() + 3)
    ns.SkinPlainButton(b, true)
    local fs = b:GetFontString()
    if fs then
        local sc = (TH and TH.Scale and TH.Scale()) or 1
        local path = (TH and TH.FontPath and TH.FontPath()) or fs:GetFont()
        if path then pcall(fs.SetFont, fs, path, math.floor(SUB_TAB_FONT * sc * 10 + 0.5) / 10, "OUTLINE") end
    end
    return b
end

-- (Options 0.6.55; REQUEST-LOG UI-5 / UI-7; Xaya 2026-11-06: "Tabs at the highest level should be evenly distributed across the pane,
-- wider, and thicker. their font should more clearly indicate parent-level functionality"; her answer "32 px, 14 pt, outlined".)
-- The window's top tab row (Rules, QoL, Bonus Features, Blizzard UI Reskin): every tab the same width, side by side with no overlap,
-- filling the row edge to edge; 32 px tall; the name in the theme's font at 14 pt with an outline (one font object per tab, so a hover
-- or a click, which re-applies the button's font objects, keeps it). The box below starts under the taller row.
local TOP_TAB_H, TOP_TAB_FONT = ns.Style.tabTop.h, ns.Style.tabTop.font   -- (core ns.Style, UI-47)
local function IsTopRow(w)
    local K = ns.OptionsApi and ns.OptionsApi.TOP_KEYS
    if not (K and w and w.tabs) then return false end
    -- (Options 0.6.72) the top row holds Rules, the feature tabs, Profiles and Settings; a row whose tabs are all top keys is the top
    -- row (Profiles' own sub-tabs, import / export / bin, are not top keys)
    local any = false
    for _, tab in ipairs(w.tabs) do
        if tab:IsShown() then
            if not K[tab.value] then return false end
            any = true
        end
    end
    return any
end
-- (Options 0.6.63; REQUEST-LOG UI-47 / UI-48, her answer for tabs inside a page: "24 px, 11 pt, even row") every other tab row (a
-- page's section tabs, the rule editor's tabs): even widths, ns.Style.tabSection. A row too crowded for that (under 60 px a tab) keeps
-- AceGUI's own layout, so no name is cut.
local SECTION_MIN_W = ns.Style.tabSection.minW
local function SectionTabs(w)
    if not (w and w.frame and w.tabs) then return end
    local shown = {}
    for _, tab in ipairs(w.tabs) do if tab:IsShown() then shown[#shown + 1] = tab end end
    local n = #shown
    local width = w.frame.width or w.frame:GetWidth() or 0
    if n == 0 or width <= 0 or width / n < SECTION_MIN_W then return end
    local each = width / n
    local slots = {}
    for i, tab in ipairs(shown) do slots[#slots + 1] = { tab, (i - 1) * each, each } end
    LayTabRow(w, slots, ns.Style.tabSection.h, ns.Style.tabSection.font)
end

local function TopTabs(w)
    if not (w and w.frame and IsTopRow(w)) then return end
    local shown = {}
    for _, tab in ipairs(w.tabs) do if tab:IsShown() then shown[#shown + 1] = tab end end
    local n = #shown
    local width = w.frame.width or w.frame:GetWidth() or 0
    if n == 0 or width <= 0 then return end
    local each = width / n
    local slots = {}
    for i, tab in ipairs(shown) do slots[#slots + 1] = { tab, (i - 1) * each, each } end
    LayTabRow(w, slots, TOP_TAB_H, TOP_TAB_FONT)
end

-- which layout a tab row gets: the window's top row, the Rules row (it holds Auto-Generate Rules), or a section row
function ns.SkinTabRow(w)
    local isRules = false
    for _, tab in ipairs(w and w.tabs or {}) do if tab:IsShown() and tab.value == "creatorTab" then isRules = true end end
    if w and w.xuiNewRule and not isRules then w.xuiNewRule:Hide() end   -- the container now holds another tab row
    if IsTopRow(w) then return TopTabs(w) end
    for _, tab in ipairs(w.tabs or {}) do if tab:IsShown() and tab.value == "creatorTab" then return CompactRulesTabs(w) end end
    return SectionTabs(w)
end

local function SkinTabGroup(w)
    TraceGroupFire(w, "tab")
    do local pb = TC("xui-pane", "bg", { 0.04, 0.04, 0.04, 1 }); PaneFill(w.border, { pb[1], pb[2], pb[3], A() * 0.6 }) end
    -- (Options 0.6.63; UI-46 "clicking on a deactivated item should just show the summary without a nested box"; UI-48 "If the item is
    -- not enabled no additional fill should exist") a tab container with no tab shown (a switched-off feature hides its section tabs;
    -- AceConfigDialog still draws the empty container): no fill and no border, so the page shows its summary only
    do
        local any = false
        for _, tab in ipairs(w.tabs or {}) do if tab:IsShown() then any = true; break end end
        if not any then PaneFill(w.border, { 0, 0, 0, 0 }) end
    end
    for _, tab in ipairs(w.tabs or {}) do
        if tab:IsShown() then
            for _, k in ipairs({ "Left", "Middle", "Right", "LeftDisabled", "MiddleDisabled", "RightDisabled" }) do
                if tab[k] then tab[k]:SetAlpha(0) end
            end
            if tab.HighlightTexture then tab.HighlightTexture:SetAlpha(0) end
            local sel = tab.selected and true or false
            -- AceGUI tabs overlap by ~10px (the Blizzard art has transparent edges), so the box is inset to keep each border whole
            local tcl = sel and "xui-tab-selected" or "xui-tab"
            Flat(tab, TC(tcl, "bg", { 0.03, 0.03, 0.03, 0.7 }), TC(tcl, "border", { 0.22, 0.22, 0.22, 1 }), { 9, 9, 6, 3 }, TG(tcl, "border"))
            local fs = tab:GetFontString()
            if fs then local c = TC(tcl, "text", GOLD); fs:SetTextColor(c[1], c[2], c[3]); TF(fs); LightFont(tab, fs, c) end
        end
    end
    -- the Rules sub-tab row keeps one compact layout, laid out again right after every AceGUI layout of it (CompactRulesTabs)
    if w.BuildTabs and not w.xuiCompactOrig then
        local orig = w.BuildTabs
        w.xuiCompactOrig = orig
        w.BuildTabs = function(self, ...)
            local r = orig(self, ...)
            pcall(ns.SkinTabRow, self)
            return r
        end
        AddRest(w, "compacttabs", function(self)
            if self.xuiCompactOrig then self.BuildTabs = self.xuiCompactOrig; self.xuiCompactOrig = nil end
        end)
    end
    pcall(ns.SkinTabRow, w)
    OnRelease(w, function(self)
        if self.xuiTopRow then
            self.xuiTopRow = nil
            for _, tab in ipairs(self.tabs or {}) do
                tab.selectedTextY, tab.deselectedTextY, tab.selectedTextX, tab.deselectedTextX = nil, nil, nil, nil
                if tab.xuiTopFont then
                    tab:SetNormalFontObject(GameFontNormalSmall); tab:SetHighlightFontObject(GameFontHighlightSmall); tab:SetDisabledFontObject(GameFontHighlightSmall)
                    tab:SetHeight(24)
                end
            end
        end
        PaneColors(self.border, { 0.1, 0.1, 0.1, 0.5 }, { 0.4, 0.4, 0.4 })
        for _, tab in ipairs(self.tabs or {}) do
            for _, k in ipairs({ "Left", "Middle", "Right", "LeftDisabled", "MiddleDisabled", "RightDisabled" }) do
                if tab[k] then tab[k]:SetAlpha(1) end
            end
            if tab.HighlightTexture then tab.HighlightTexture:SetAlpha(1) end
            RestoreLF(tab)
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
local SEARCH_PAD = 42   -- room kept above the first row for the search box (6 px of it is the gap between the box and the frame border)
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
    for _, b in ipairs(w.buttons or {}) do local uvb = tostring(b.uniquevalue or ""); if b:IsShown() and (uvb == "all" or uvb == "loaded" or uvb == "notloaded" or uvb == "disabled") then has = true; break end end
    if not has then   -- the All Rules row may be scrolled out of view or not drawn yet: look at the tree data itself
        for _, t in ipairs(w.tree or {}) do if type(t) == "table" and (t.value == "all" or t.value == "loaded" or t.value == "notloaded" or t.value == "disabled") then has = true; break end end
    end
    -- An active search can hide the Loaded / All rows (or every row, when nothing matches). The box must stay then, or there is no way
    -- to edit or clear the text and the whole list stays empty.
    if not has and (ns.treeFilter or "") ~= "" and (w.xuiSearchBox or #(w.tree or {}) == 0) then has = true end
    has = has and SkinOn()
    local sb = w.xuiSearchBox
    if has and not sb and w.treeframe then
        sb = MakeSearchBox(w.treeframe)
        sb:SetFrameLevel(w.treeframe:GetFrameLevel() + 3)
        sb:SetPoint("TOPLEFT", w.treeframe, "TOPLEFT", 12, -14)
        sb:SetPoint("TOPRIGHT", w.treeframe, "TOPRIGHT", -12, -14)
        w.xuiSearchBox = sb
    end
    -- multi-select bar: while rules are selected it replaces the search box with "Delete (N)" / "Move (N)" / "Deselect (N)" right where the list is
    local nSel = (has and ns.OptionsApi.RuleEditor.MultiCount and ns.OptionsApi.RuleEditor.MultiCount()) or 0
    local bar = w.xuiSelBar
    if has and not bar and w.treeframe then
        bar = CreateFrame("Frame", nil, w.treeframe)
        bar:SetHeight(22)
        bar:SetFrameLevel(w.treeframe:GetFrameLevel() + 4)
        bar:SetPoint("TOPLEFT", w.treeframe, "TOPLEFT", 12, -13)
        bar:SetPoint("TOPRIGHT", w.treeframe, "TOPRIGHT", -12, -13)
        bar.clr = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
        bar.clr:SetSize(84, 22); bar.clr:SetPoint("RIGHT", 0, 0)
        bar.clr:SetScript("OnClick", function() if ns.OptionsApi.RuleEditor.MultiClear then ns.OptionsApi.RuleEditor.MultiClear() end end)
        bar.mv = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
        bar.mv:SetSize(70, 22); bar.mv:SetPoint("RIGHT", bar.clr, "LEFT", -4, 0)
        bar.mv:SetScript("OnClick", function(self) if ns.OptionsApi.RuleEditor.MultiMoveMenu then ns.OptionsApi.RuleEditor.MultiMoveMenu(self) end end)
        bar.del = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
        bar.del:SetHeight(22); bar.del:SetPoint("LEFT", 0, 0); bar.del:SetPoint("RIGHT", bar.mv, "LEFT", -4, 0)
        bar.del:SetScript("OnClick", function() if ns.OptionsApi.RuleEditor.MultiDelete then ns.OptionsApi.RuleEditor.MultiDelete() end end)
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
                    b:HookScript("OnEnter", function(self) local f = self:GetFontString(); if f then local c = HoverCol(); f:SetTextColor(c[1], c[2], c[3]) end end)
                    b:HookScript("OnLeave", function(self) local f = self:GetFontString(); if f then f:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) end end)
                end
                local cl = (key == "del") and "xui-button-primary" or "xui-button"
                Flat(b, TC(cl, "bg", { 0.04, 0.04, 0.04, 0.7 }), TC(cl, "border", { 0.25, 0.25, 0.25, 1 }), nil, TG(cl, "border"))
                local fs = b:GetFontString()
                if fs then local c = TC(cl, "text", GOLD); fs:SetTextColor(c[1], c[2], c[3]); TF(fs) end
            end
        end
        bar:SetShown(nSel > 0)
        -- Xaya, 2026-11-06: "clear should be "Deselect (#)"", "Delete should have (#) and Move to should be relabeled to say Move / Move (#)"
        if nSel > 0 then
            bar.del:SetText(("Delete (%d)"):format(nSel))
            bar.mv:SetText(("Move (%d)"):format(nSel))
            bar.clr:SetText(("Deselect (%d)"):format(nSel))
        end
    end
    if sb then sb:SetShown(has and nSel == 0); RestoreSearchFocus() end
end

local function PartitionAllRules(w)
    local tf = w.treeframe
    if not tf or not w.buttons then return end
    EnsureTreeSearch(w)
    local pad = TopPad(w)
    if w.xuiPart or pad ~= 10 or w.xuiTopApplied then ResetChain(w); w.xuiPart = nil; w.xuiTopApplied = (pad ~= 10) and pad or nil end
    do   -- 0.6.4: the scrollbar starts below the search box. AceGUI puts its top 26 px from the frame's top, so once the list was long
         -- enough to scroll, the bar's up arrow sat on the right end of the search box. (The up arrow is 16 px tall, above the bar.)
        local sbar = w.scrollbar
        if sbar then
            local top = (pad ~= 10) and (pad + 16) or 26
            if sbar.xuiTop ~= top then
                sbar:ClearAllPoints()
                sbar:SetPoint("TOPRIGHT", tf, "TOPRIGHT", -10, -top)
                sbar:SetPoint("BOTTOMRIGHT", tf, "BOTTOMRIGHT", -10, 26)
                sbar.xuiTop = top
            end
            AddRest(w, "sbartop", function(self)   -- AceGUI hands this tree to other windows: put AceGUI's own anchors back
                local b2 = self.scrollbar
                if b2 and b2.xuiTop and b2.xuiTop ~= 26 and self.treeframe then
                    b2:ClearAllPoints()
                    b2:SetPoint("TOPRIGHT", self.treeframe, "TOPRIGHT", -10, -26)
                    b2:SetPoint("BOTTOMRIGHT", self.treeframe, "BOTTOMRIGHT", -10, 26)
                end
                if b2 then b2.xuiTop = nil end
            end)
        end
    end
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
    PaneFill(w.treeframe, { 0.03, 0.03, 0.03, A() * 0.6 })
    PaneDivider(w)
    -- Dragging the sidebar separator. AceGUI's own drag (StartSizing on the tree frame, then on release SetHeight(0) + ClearAllPoints +
    -- re-anchor + OnWidthSet + DoLayout) fights the skin: OnSizeChanged runs the skin's multi-pass RefreshTree on EVERY mouse move
    -- (it temporarily swaps tf.GetHeight), and the release re-anchors the frame the skin's band is anchored to. That blanked the window.
    -- This replaces it for every tree (Rules, Smart Categories, Chat, QoL, Bonus Features, ...): nothing is re-anchored and no refresh runs while
    -- dragging; only the width changes (clamped), the sidebar rows follow because they are anchored to the frame. On release, one
    -- deferred pass recomputes the content width, refreshes the rows and lays the pane out. Any error there rebuilds the window.
    do
        local dr, tf = w.dragger, w.treeframe
        if dr and tf and not dr.xuiSafeDrag then
            dr.xuiSafeDrag = true
            local MIN_TREE, MIN_PANE = 180, 360
            local origSize = tf:GetScript("OnSizeChanged")
            local running
            local function Status() return w.status or w.localstatus end
            local function Limits()
                local st = Status()
                local fw = (st and st.fullwidth) or (w.frame and w.frame:GetWidth()) or 0
                return MIN_TREE, math.max(MIN_TREE, math.min(400, fw - MIN_PANE))
            end
            local function Fail(err)
                ns.Print("sidebar resize error (please report): " .. tostring(err))
                if ns.UI and ns.UI.Notify then pcall(ns.UI.Notify) end
            end
            local function Finish()
                if not running then return end
                running = nil
                dr:SetScript("OnUpdate", nil)
                local st = Status()
                local lo, hi = Limits()
                local width = math.max(lo, math.min(hi, tf:GetWidth() or lo))
                tf:SetWidth(width)   -- while OnSizeChanged is still off: the deferred pass below does the single refresh
                tf:SetScript("OnSizeChanged", origSize)
                if st then st.treewidth = width; st.xuiManualWidth = true end   -- (ns.EnsureNameRoom no longer widens it)
                pcall(w.Fire, w, "OnTreeResize", width)
                C_Timer.After(0, function()
                    if w.treeframe ~= tf or not tf:IsVisible() then return end
                    local ok, err = pcall(function()
                        local st2 = Status()
                        if st2 and st2.fullwidth then w:OnWidthSet(st2.fullwidth) end
                        w:RefreshTree()
                        w:DoLayout()
                    end)
                    if not ok then Fail(err) end
                end)
            end
            dr:SetScript("OnMouseDown", function(f, button)
                if button and button ~= "LeftButton" then return end
                if running then Finish() end
                local scale = tf:GetEffectiveScale()
                if not scale or scale <= 0 then return end
                local startX, startW = GetCursorPosition() / scale, tf:GetWidth()
                local lastW = startW
                running = true
                tf:SetScript("OnSizeChanged", nil)   -- no refresh while the width is changing
                dr:SetScript("OnUpdate", function()
                    local ok, err = pcall(function()
                        if not IsMouseButtonDown("LeftButton") then Finish(); return end
                        local lo, hi = Limits()
                        local nw = math.max(lo, math.min(hi, startW + GetCursorPosition() / scale - startX))
                        if math.abs(nw - lastW) >= 1 then lastW = nw; tf:SetWidth(nw) end
                    end)
                    if not ok then
                        running = nil; dr:SetScript("OnUpdate", nil); tf:SetScript("OnSizeChanged", origSize)
                        Fail(err)
                    end
                end)
            end)
            dr:SetScript("OnMouseUp", function() local ok, err = pcall(Finish); if not ok then Fail(err) end end)
            dr:SetScript("OnHide", function() pcall(Finish) end)
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
            if ns.OptionsApi and ns.OptionsApi.OpenOnSelect then pcall(ns.OptionsApi.OpenOnSelect, self, uv) end   -- a feature node shows its parts
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
            -- (Options 0.6.106; request log row 20, Xaya 2026-11-08: "deleting auras shifts the rule sidebar up still") Every pass starts
            -- from the scroll position asked for. AceGUI clamps it to each pass's line count (numlines - lines), so a first pass with
            -- more lines than end up fitting (a recycled tree widget with no remembered count) pulled a list scrolled near its bottom
            -- up for good. A scroll-to-selection that was asked for is asked of every pass, so the last pass (the real fit) decides it.
            local st = self.status or self.localstatus
            local want = st and st.scrollvalue
            if st and st.scrollToSelection and not args[1] then args[1] = true end
            local function run(lines)
                if want ~= nil then st.scrollvalue = want end
                tf.GetHeight = function() return lines * 18 + 20.5 end
                local ok, err = pcall(origRefresh, self, unpack(args))
                tf.GetHeight = nil
                if not ok then error(err, 0) end
                local total, cnt, tallest = 0, 0, 0
                for _, b in ipairs(self.buttons or {}) do
                    if b:IsShown() then local h = b:GetHeight(); total = total + h; cnt = cnt + 1; if h > tallest then tallest = h end end
                end
                return total, cnt, tallest
            end
            if realH <= 60 then
                local ok, err = pcall(origRefresh, self, ...)
                if not ok then error(err, 0) end
                pcall(PartitionAllRules, self)
                return
            end
            local avail = realH - reserve - TopPad(self) - 6
            local lines = math.max(1, self.xuiLines or math.floor((avail - 10) / 18))
            local total, cnt, tallest = run(lines)
            -- grow while there is spare room and more rows exist than are drawn. (Options 0.6.52) Before, this asked the scroll bar
            -- with `local _, mx = self.scrollbar and self.scrollbar:GetMinMaxValues()`: an `and` keeps only a call's first value, so mx
            -- was always nil and this loop never ran. The remembered count could then only shrink: one refresh that measured little
            -- room (the window redrawn after a change in the right-hand pane, a short window) left the sidebar at a few rows for good
            -- (Insivius: "will not show more than 4 lines"; Xaya: "clicking options in the right hand side panel still consistently
            -- drops elements"). self.lines is AceGUI's list of every row the tree has now (RefreshTree builds it first).
            for _ = 1, 3 do
                if cnt > 0 and total < avail - 40 and #(self.lines or {}) > cnt then
                    lines = lines + math.max(1, math.floor((avail - total) / (total / cnt)))
                    total, cnt, tallest = run(lines)
                else break end
            end
            -- shrink until what is drawn fits. (Options 0.6.106; request log row 20) A step drops the rows that surely do not fit: the
            -- height over the room divided by the tallest drawn row, at least one. Each dropped row is at most that tall, so a step never
            -- goes below the largest count that fits and the result is the one the one-row steps reach, in fewer passes. Before, from
            -- the 18 px first guess (a recycled tree widget has no remembered count) the 8 one-row passes ran out on a list of ~38 px
            -- rule rows: the count stayed too high and AceGUI clamped the scroll position to it (a list near its bottom jumped up).
            for _ = 1, 8 do
                if total > avail and lines > 1 then
                    local step = (tallest > 0) and math.max(1, math.floor((total - avail) / tallest)) or 1
                    lines = math.max(1, math.min(lines - step, cnt - 1))
                    total, cnt, tallest = run(lines)
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
        w.content:SetPoint("TOPLEFT", w.border, "TOPLEFT", UI_MARGIN + pad, -(UI_MARGIN + pad))
        w.content:SetPoint("BOTTOMRIGHT", w.border, "BOTTOMRIGHT", -(UI_MARGIN + pad), UI_MARGIN + pad)
        w.xuiPadApplied = pad
    end
    PaneFill(w.border, { 0.04, 0.04, 0.04, A() * 0.6 })
    for _, b in ipairs(w.buttons or {}) do
        local ht = b:GetHighlightTexture()
        if ht then
            if not b.xuiHT then b.xuiHT = { ht:GetTexture(), { ht:GetVertexColor() }, ht:GetBlendMode() } end
            ht:SetTexture(WHITE8); do local c = TC("xui-list-selected", "bg", { 0.75, 0.25, 1, 1 }); ht:SetVertexColor(c[1], c[2], c[3], 0.35) end; ht:SetBlendMode("BLEND")
            -- AceGUI's highlight texture is both the mouse-over and the "selected" bar: neither is wanted (the selected row gets
            -- its own gradient or text color from Options.lua)
            ht:SetAlpha(0)
        end
    end
    OnRelease(w, function(self)
        self.xuiFadeTok = nil; self.xuiLastSel = nil
        self.xuiLines = nil   -- (Options 0.6.52) AceGUI hands this widget to the next tree: it must not start from this tree's row count
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
        if self.xuiDivider then self.xuiDivider:Hide(); if TH and TH.HideLineGrad then TH.HideLineGrad(self.frame, self.xuiDivider) end end   -- (#460)
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
        else
            -- Duplicate (0.6.3, #257): two overlapping squares drawn from flat lines (own art), so it reads as "copy", not as a note
            b.tex:SetTexture(nil); b.tex:SetSize(1, 1)
            b.xuiCopyLines = {}
            local function square(x, y, sz, fill)
                if fill then
                    local f0 = b:CreateTexture(nil, "ARTWORK", nil, 1); do local c = TC("xui-window", "bg", { 0.06, 0.06, 0.06, 1 }); f0:SetColorTexture(c[1], c[2], c[3], 1) end
                    f0:SetPoint("TOPLEFT", b, "CENTER", x, y); f0:SetSize(sz, sz)
                end
                local function line(px, py, w, h)
                    local t = b:CreateTexture(nil, "ARTWORK", nil, 2); do local c = TC("xui-button", "text", GOLD); t:SetColorTexture(c[1], c[2], c[3], 1) end
                    t:SetPoint("TOPLEFT", b, "CENTER", px, py); t:SetSize(w, h)
                    b.xuiCopyLines[#b.xuiCopyLines + 1] = t
                end
                line(x, y, sz, 1.5); line(x, y - sz + 1.5, sz, 1.5); line(x, y, 1.5, sz); line(x + sz - 1.5, y, 1.5, sz)
            end
            square(-7, 7, 10, false)   -- back sheet
            square(-3, 3, 10, true)    -- front sheet, covering the back one where they overlap
        end
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
            if b.xuiCopyLines then for _, t in ipairs(b.xuiCopyLines) do t:SetAlpha(a) end end
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
        do local c = TC("xui-pane", "border", { 0.35, 0.35, 0.35, 1 }); eb.line:SetColorTexture(c[1], c[2], c[3], 0.8) end
        eb:SetScript("OnEnter", function(self) local c = TC("xui-pane", "bg", { 0.1, 0.1, 0.1, 1 }); self.bg:SetColorTexture(c[1], c[2], c[3], 0.9) end)
        eb:SetScript("OnLeave", function(self) if not self:HasFocus() then self.bg:SetColorTexture(0, 0, 0, 0) end end)
        eb:SetScript("OnEditFocusGained", function(self)
            local sp = self.xuiSpec
            if sp and sp.locked and sp.locked() then self.xuiCancel = true; self:ClearFocus(); return end   -- edit-locked (audit D44): no typing
            local c = TC("xui-window", "bg", { 0, 0, 0, 1 }); self.bg:SetColorTexture(c[1], c[2], c[3], 1); self:HighlightText()
        end)
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
        do local c = TC("xui-text-muted", "text", { 0.45, 0.45, 0.45, 1 }); f.xuiNameHint:SetTextColor(c[1], c[2], c[3]) end
    end
    eb.xuiSpec = ed
    eb:SetAlpha((ed.locked and ed.locked()) and 0.5 or 1)   -- grayed while edit-locked
    eb:SetFrameLevel(f:GetFrameLevel() + 3)
    eb:ClearAllPoints()
    if ed.title then   -- number is the header title; this box (the optional name) goes beneath it, smaller and gray
        eb:SetHeight(16); eb:SetFontObject(GameFontNormalSmall); do local c = TC("xui-text-muted", "text", { 0.65, 0.65, 0.65, 1 }); eb:SetTextColor(c[1], c[2], c[3]) end
        -- start under the title TEXT: the title is "<arrow glyph>  Trigger 1:  Cooldown", so measure the glyph and its spaces
        local pre = 0
        do
            local txt = w.text and w.text:GetText() or ""
            local glyph = txt:match("^(|T.-|t%s*)")
            if glyph and w.text.GetFont then
                if not ns.xuiMeasure then
                    ns.xuiMeasure = UIParent:CreateFontString(nil, "OVERLAY")
                    ns.xuiMeasure:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -4000, 4000); ns.xuiMeasure:SetAlpha(0)
                end
                local m = ns.xuiMeasure
                local font, size, flags = w.text:GetFont()
                if font then
                    m:SetFont(font, size, flags)
                    m:SetText("l"); local w0 = m:GetStringWidth() or 0
                    m:SetText(glyph .. "l"); pre = math.max(0, (m:GetStringWidth() or 0) - w0)
                end
            end
        end
        eb:SetTextInsets(0, 6, 0, 0)
        eb:SetPoint("TOPLEFT", f, "TOPLEFT", f.xuiTitleX or (pre - (tonumber(arg and arg.xuiHeadOut) or 0)), -(3 + ns.H3_SIZE + 7)); eb:SetWidth(220)
        if not f.xuiNamePH then
            f.xuiNamePH = eb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            f.xuiNamePH:SetPoint("LEFT", eb, "LEFT", 0, 0); do local c = TC("xui-text-muted", "text", { 0.4, 0.4, 0.4, 1 }); f.xuiNamePH:SetTextColor(c[1], c[2], c[3]) end; f.xuiNamePH:SetText("name (optional)")
            eb:HookScript("OnTextChanged", function(self) if f.xuiNamePH then f.xuiNamePH:SetShown(self:GetText() == "" and not self:HasFocus()) end end)
            eb:HookScript("OnEditFocusGained", function() f.xuiNamePH:Hide() end)
            eb:HookScript("OnEditFocusLost", function(self) f.xuiNamePH:SetShown(self:GetText() == "") end)
        end
    else
        eb:SetHeight(22); eb:SetFontObject(GameFontHighlight); do local c = TC("xui-text", "text", { 1, 1, 1, 1 }); eb:SetTextColor(c[1], c[2], c[3]) end; eb:SetTextInsets(6, 6, 0, 0)
        eb:SetPoint("LEFT", f, "LEFT", f.xuiTitleX or (30 - (tonumber(arg and arg.xuiHeadOut) or 0)), 0); eb:SetWidth(220)
        if f.xuiNamePH then f.xuiNamePH:Hide() end
    end
    if not eb:HasFocus() then eb:SetText(tostring(ed.get() or "")); eb:SetCursorPosition(0) end
    if ed.title and f.xuiNamePH then f.xuiNamePH:SetShown(eb:GetText() == "" and not eb:HasFocus()) end
    eb:Show()
    local h = f.xuiNameHint
    h:ClearAllPoints(); h:SetPoint("LEFT", eb, "RIGHT", 8, 0)
    h:SetText(ed.hint and ed.hint() or ""); h:Show()
end

-- Open / close button at the left of a collapsible header (arg.xuiChevron = function returning true while open). 0.6.2: replaces the
-- arrow that used to sit inside the title text (it hung into a margin the scroll area cuts off, so it never showed) and the red mouse-over
-- glow of the whole row: the row itself no longer reacts to the mouse; only this button opens and closes the section.
local CHEV_X, CHEV_TITLE_X = 2, 26
-- One open / close look everywhere (0.6.4): the chat frame's expand arrow, pointing right while closed and turned to point down while
-- open. Gold, so it never reads as the red "remove" color, and not the Move up / down arrow art. Also used by collapsible headings.
function ns.PaintOpenClose(tex, open)
    tex:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    tex:SetTexCoord(0, 1, 0, 1)
    tex:SetRotation(open and -math.pi / 2 or 0)
end
local function MakeChevron(f)
    local b = CreateFrame("Button", nil, f)
    b:SetSize(20, 20)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetPoint("CENTER"); b.tex:SetSize(16, 16)
    b:SetScript("OnClick", function(self) local w = self.xuiW; if w and w.Fire then w:Fire("OnClick", "LeftButton") end end)
    b:SetScript("OnEnter", function(self)
        do local c = TC("xui-label", "text", { 1, 1, 0.6, 1 }); self.tex:SetVertexColor(c[1], c[2], c[3]) end
        GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText(self.xuiOpen and "Collapse" or "Expand")
        GameTooltip:AddLine("Never changes any setting.", 1, 1, 1, true); GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function(self) self.tex:SetVertexColor(1, 1, 1); GameTooltip:Hide() end)
    f.xuiChevBtn = b
    return b
end

local function SkinButton(w)
    local f = w.frame
    local opt = w.GetUserData and w:GetUserData("option")
    local isHeader = opt and type(opt.arg) == "table" and opt.arg.xuiLeft
    local arg = opt and type(opt.arg) == "table" and opt.arg or nil
    local fs = w.text
    if isHeader then
        -- collapsible section header (arrow + title): no box, bigger text
        HideRegions(f, f:GetHighlightTexture())
        FlatHide(f)
        do   -- no mouse-over glow on header rows (Blizzard's highlight art is red); restored when the widget is released
            local ht = f:GetHighlightTexture()
            if ht then ht:SetAlpha(0); f.xuiHdrHL = true end
        end
        local chev = arg and type(arg.xuiChevron) == "function"
        if fs and not w.xuiFont then
            local font, size, flags = fs:GetFont()
            w.xuiFont = { font, size, flags }
            fs:SetFont(font, ns.H3_SIZE, flags)
            do local c = TC("xui-heading", "text", { 1, 1, 1, 1 }); fs:SetTextColor(c[1], c[2], c[3]) end
        end
        local arrowL = arg and arg.xuiArrowLeft and type(arg.xuiArrow) == "function"
        local subTxt = arg and type(arg.xuiSub) == "function" and select(2, pcall(arg.xuiSub)) or nil
        if type(subTxt) ~= "string" or subTxt == "" then subTxt = nil end
        local out = tonumber(arg and arg.xuiHeadOut) or 0   -- header hangs out into the margin its group's body is indented by (arg.xuiIndent)
        local lx = chev and CHEV_TITLE_X or (((arrowL and out <= 0) and 22 or 0) - out)   -- a chevron header never hangs out of view
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
            do local c = TC("xui-text-muted", "text", { 0.6, 0.6, 0.6, 1 }); sf:SetTextColor(c[1], c[2], c[3]) end; sf:SetJustifyH("LEFT"); sf:SetText(subTxt); sf:Show()
        elseif f.xuiSubFS then f.xuiSubFS:Hide() end
        local wantH = subTxt and (ns.H3_SIZE + 30) or 24
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
            do local c = TC("xui-popup", "border", { 0.8, 0.5, 1, 1 }); at:SetVertexColor(c[1], c[2], c[3]) end; at:Show()
        elseif f.xuiArrowTex then f.xuiArrowTex:Hide() end
        if chev then
            local b = f.xuiChevBtn or MakeChevron(f)
            local okOpen, open = pcall(arg.xuiChevron)
            b.xuiW, b.xuiOpen = w, (okOpen and open) and true or false
            ns.PaintOpenClose(b.tex, b.xuiOpen)
            b.tex:SetVertexColor(1, 1, 1)
            b:SetFrameLevel(f:GetFrameLevel() + 3)
            b:ClearAllPoints()
            if subTxt then b:SetPoint("TOPLEFT", f, "TOPLEFT", CHEV_X, -3 - (ns.H3_SIZE or 14) / 2 + 10)   -- level with the title line
            else b:SetPoint("LEFT", f, "LEFT", CHEV_X, 0) end
            b:Show()
            f:EnableMouse(false)   -- the row is not a click target: only the button opens / closes it
            f.xuiTitleX = CHEV_TITLE_X
        else
            if f.xuiChevBtn then f.xuiChevBtn:Hide(); f.xuiChevBtn.xuiW = nil end
            if f.xuiTitleX then f:EnableMouse(true) end
            f.xuiTitleX = nil
        end
    elseif arg and arg.xuiTab then
        -- #370: a tab drawn as a button where AceConfig cannot make real tabs (a group page: its tree children are its rules and
        -- nested groups). Same flat box and theme colors as a real tab (SkinTabGroup); the picked tab in the selected tab's colors.
        HideRegions(f, f:GetHighlightTexture())
        local okS, sel = pcall(arg.xuiTabSel or function() return false end)
        local tcl = (okS and sel) and "xui-tab-selected" or "xui-tab"
        Flat(f, TC(tcl, "bg", { 0.03, 0.03, 0.03, 0.7 }), TC(tcl, "border", { 0.22, 0.22, 0.22, 1 }), nil, TG(tcl, "border"))
        do
            local ht = f:GetHighlightTexture()
            if ht then
                if not f.xuiHLOrig then f.xuiHLOrig = { ht:GetTexture(), ht:GetBlendMode() } end
                local hc = TC("xui-tab-selected", "border", { 0.75, 0.4, 1, 1 })
                ht:SetTexture("Interface\\Buttons\\WHITE8X8"); ht:SetTexCoord(0, 1, 0, 1)
                ht:SetBlendMode("ADD"); ht:SetVertexColor(hc[1], hc[2], hc[3]); ht:SetAlpha((okS and sel) and 0 or 0.2)
                ht:ClearAllPoints(); ht:SetAllPoints(f)
            end
        end
        if fs then
            TF(fs)
            local c = TC(tcl, "text", GOLD); fs:SetTextColor(c[1], c[2], c[3]); LightFont(f, fs, c)
        end
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
        local bcl = (arg and arg.xuiRed) and "xui-button-primary" or "xui-button"   -- red "Add ..." button = primary
        Flat(f, TC(bcl, "bg", { 0.04, 0.04, 0.04, 0.7 }), TC(bcl, "border", { 0.25, 0.25, 0.25, 1 }), nil, TG(bcl, "border"))
        -- mouse-over glow: Blizzard's own highlight art is red; repaint it flat in the button's theme (class) color
        do
            local ht = f:GetHighlightTexture()
            if ht then
                if not f.xuiHLOrig then
                    f.xuiHLOrig = { ht:GetTexture(), ht:GetBlendMode() }
                end
                local hc = TC(bcl, "border", { 0.75, 0.4, 1, 1 })
                ht:SetTexture("Interface\\Buttons\\WHITE8X8"); ht:SetTexCoord(0, 1, 0, 1)
                ht:SetBlendMode("ADD"); ht:SetVertexColor(hc[1], hc[2], hc[3]); ht:SetAlpha(0.28)
                ht:ClearAllPoints(); ht:SetAllPoints(f)
            end
        end
        if fs then
            TF(fs)
            if f:IsEnabled() then local c = TC(bcl, "text", GOLD); fs:SetTextColor(c[1], c[2], c[3]) else local m = TC("xui-text-muted", "text", { 0.5, 0.5, 0.5, 1 }); fs:SetTextColor(m[1], m[2], m[3]) end
            LightFont(f, fs, TC(bcl, "text", GOLD))
        end
    end
    do local o = (isHeader and tonumber(arg and arg.xuiHeadOut)) or 0; f:SetHitRectInsets(-o, 0, 0, 0) end
    PaintActions(w, arg)
    PaintNameEdit(w, arg)
    OnRelease(w, function(self)
        self.frame:SetHitRectInsets(0, 0, 0, 0)
        if self.frame.xuiNameEB then self.frame.xuiNameEB:Hide(); self.frame.xuiNameHint:Hide() end
        if self.frame.xuiArrowTex then self.frame.xuiArrowTex:Hide() end
        if self.frame.xuiChevBtn then self.frame.xuiChevBtn:Hide(); self.frame.xuiChevBtn.xuiW = nil end
        if self.frame.xuiTitleX then self.frame:EnableMouse(true); self.frame.xuiTitleX = nil end
        if self.frame.xuiHdrHL then local ht = self.frame:GetHighlightTexture(); if ht then ht:SetAlpha(1) end; self.frame.xuiHdrHL = nil end
        if self.frame.xuiSubFS then self.frame.xuiSubFS:Hide() end
        if self.xuiSubH then self.frame:SetHeight(24); self.frame.height = 24; self.xuiSubH = nil end
        HideActions(self.frame)
        ShowRegions(self.frame)
        FlatHide(self.frame)
        RestoreLF(self.frame)
        do   -- put Blizzard's highlight art back (AceGUI reuses the frame)
            local ht, o = self.frame.GetHighlightTexture and self.frame:GetHighlightTexture(), self.frame.xuiHLOrig
            if ht and o then
                ht:SetTexture(o[1] or "Interface\\Buttons\\UI-Panel-Button-Highlight"); ht:SetTexCoord(0, 0.625, 0, 0.6875)
                ht:SetBlendMode(o[2] or "ADD"); ht:SetVertexColor(1, 1, 1); ht:SetAlpha(1)
                ht:ClearAllPoints(); ht:SetPoint("TOPLEFT", 2, -2); ht:SetPoint("BOTTOMRIGHT", -2, 2)
            end
            self.frame.xuiHLOrig = nil
        end
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
        if box then Flat(w.border, { 0.04, 0.04, 0.04, math.min(1, A() * 0.5 + 0.10) }, { 0.3, 0.3, 0.3, 1 }, nil, TG("xui-pane", "border")) else FlatHide(w.border) end
    else
        if w.border then FlatHide(w.border) end
        -- (Options 0.6.63; UI-47 / UI-48, her answer for titled groups inside a page: "First try unbordered boxes (darker blocks) and
        -- dividing lines") the group's darker fill without a border line, and a dividing line along the block's top edge
        do local pb = TC("xui-pane", "bg", { 0.04, 0.04, 0.04, 1 }); PaneFill(w.border, { pb[1], pb[2], pb[3], A() * 0.5 }) end
        if w.border and w.border.CreateTexture then
            local ln = w.xuiTopLine
            if not ln then ln = w.border:CreateTexture(nil, "ARTWORK"); w.xuiTopLine = ln end
            local c = TC("xui-pane", "border", { 0.25, 0.25, 0.25, 1 })
            local g = TG("xui-pane", "border")   -- (#460)
            if not (g or ln.xuiGradL) then ln:SetColorTexture(c[1], c[2], c[3], 1) end
            ln:ClearAllPoints()
            ln:SetPoint("TOPLEFT", w.border, "TOPLEFT", 0, 0); ln:SetPoint("TOPRIGHT", w.border, "TOPRIGHT", 0, 0)
            ln:SetHeight(ns.Style.divider.size)
            ln:Show()
            if (g or ln.xuiGradL) and TH and TH.PaintLine then TH.PaintLine(w.border, ln, { c[1], c[2], c[3], 1 }, g, "H", "ARTWORK") end
            AddRest(w, "topline", function(self) if self.xuiTopLine then self.xuiTopLine:Hide(); if TH and TH.HideLineGrad then TH.HideLineGrad(self.border, self.xuiTopLine) end end end)
        end
    end
    if (flat or box) and w.xuiTopLine then w.xuiTopLine:Hide(); if TH and TH.HideLineGrad then TH.HideLineGrad(w.border, w.xuiTopLine) end end
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
        w.content:SetPoint("TOPLEFT", UI_MARGIN + ind, -UI_MARGIN); w.content:SetPoint("BOTTOMRIGHT", -UI_MARGIN, UI_MARGIN)
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
        f.xuiHL:SetAllPoints(); do local c = TC("xui-label", "text", GOLD); f.xuiHL:SetColorTexture(c[1], c[2], c[3], 0.12) end
    end
    f.xuiHL:Show()
    Flat(f, { 0.04, 0.04, 0.04, 0.35 + A() * 0.4 }, { 0, 0, 0, 0 })   -- fill only: no outline around each row
    -- (Options 0.6.94; #484 / #487, debug W1) Every row keeps AceGUI's own Label layout: the icon at the row's left edge, the title and
    -- description 4 px to its right, and the row as tall as its icon or its text, whichever is taller, measured again by AceGUI each
    -- time the row's width is set. Until 0.6.93 this function moved the icon 8 px in and the text 18 px after it and floored the row at
    -- icon + 40 px, but each row's re-layout of the list (its DoLayout) put every EARLIER row back to AceGUI's layout, so only the last
    -- row (Import) kept the moved icon / text ("import button has wrong alignment", #484), and every row was drawn 76 px tall while the
    -- list stacked them at their AceGUI height (39 px apart in the stand-in), so the rows' boxes overlapped (#487). The icon crop and
    -- the vertically centred text are what every row already showed, so they stay.
    local img, lab = w.image, w.label
    if img and w.imageshown and ns.TypeIconCoords then img:SetTexCoord(ns.TypeIconCoords()) end   -- zoomed, square-edged icon
    if lab then lab:SetJustifyV("MIDDLE") end
    if f.xuiSep then f.xuiSep:Hide() end   -- divider removed (2026-10-31): fully invisible
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
-- A rule that has CUES carries no display or sound of its own (they live in its hidden child cues): its row takes its look from its first
-- display cue, else its first sound cue. Returns the cue to read, or nil when the rule shows / plays something itself or has no cues.
function ns.RuleLookSource(rule)
    if not (rule and rule.uid) or rule.parentUid or rule.isCue or not ns.CuesOf then return nil end
    if (type(rule.visual) == "table" and rule.visual.enabled) or (type(rule.sound) == "table" and rule.sound.enabled) then return nil end
    local cues, snd = ns.CuesOf(rule), nil
    for _, c in ipairs(cues) do
        if c.cueKind ~= "sound" and c.cueKind ~= "speech" and c.cueKind ~= "custom" and type(c.visual) == "table" and c.visual.enabled then return c end
        if not snd and (c.cueKind == "sound" or c.cueKind == "speech") then snd = c end
    end
    return snd
end
function ns.TypeKey(rule)
    local src = ns.RuleLookSource(rule)
    if src then rule = src end
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
    local src = ns.RuleLookSource(r)
    if src then r = src end
    local v = type(r.visual) == "table" and r.visual or nil
    if not v or not v.enabled then return nil end
    local kind = ns.Val and ns.Val(v.kind)
    if (kind ~= "file" and kind ~= "atlas") or not v.tex or v.tex == "" then return nil end
    local c = {}
    for kk, vv in pairs(v) do c[kk] = vv end
    c.zoom = 0
    return c
end
-- #369 (Xaya 2026-11-04, screenshot): nested sidebar rows kept 1-3 characters of their names ("VD...", "A...", "F..."): the indent
-- (8 px a level), the reorder arrows, the open / close arrow and the 32 px type icon on the left, the lock / note icons on the right.
-- After the sidebar is drawn, it is widened just enough that every visible row keeps NAME_ROOM px for its name, never beyond
-- AceGUI's own limit (min(400, window width - 50), AceGUIContainer-TreeGroup.lua:561). It only widens; the full name also shows on
-- mouse-over (AceGUI's tree tooltip). Rows record their text's left / right insets (Options.lua, DecorateButton) as xuiTextL / xuiTextR.
local NAME_ROOM = 80
local ROW_INSET = 22   -- AceGUI's rows end 22 px left of the sidebar's right edge while its scroll bar shows (AceGUIContainer-TreeGroup.lua:481 / 538)
ns.SIDEBAR_NAME_ROOM = NAME_ROOM
-- Xaya 2026-11-04: "clicking tabs force-resizes the left and right panes". The first version measured each row with GetWidth() right
-- after AceGUI rebuilt the tree (every tab click and every edit rebuilds it), when a rebuilt tree has just been set to AceGUI's
-- default 175 px and then to the saved width: a row still measured at the old width looked too narrow, and the sidebar was widened
-- again on every rebuild, up to the cap. Now the width a row needs comes from its own text insets (plus the scroll bar column),
-- so the same rows always ask for the same width and a rebuild changes nothing. A sidebar the user dragged keeps their width.
function ns.EnsureNameRoom(tree)
    if not tree or tree.xuiRoomBusy or not tree.SetTreeWidth then return end
    local status = tree.status or tree.localstatus
    if not status or status.xuiManualWidth then return end   -- dragged by hand: their width stands (full names show on mouse-over)
    local cur = tonumber(status.treewidth) or 0
    local need
    for _, b in ipairs(tree.buttons or {}) do
        local txt = b.text and b.text.GetText and b.text:GetText()
        if b:IsShown() and b.xuiTextL and type(txt) == "string" and txt ~= "" then
            local n = b.xuiTextL + (b.xuiTextR or 4) + NAME_ROOM + ROW_INSET
            if not need or n > need then need = n end
        end
    end
    if not need then return end
    local fw = (tree.frame and tree.frame.GetWidth and tree.frame:GetWidth()) or 0
    local cap = math.min(400, fw - 50)
    local want = math.min(cap, math.ceil(need))
    if want <= cur + 1 then return end
    tree.xuiRoomBusy = true
    pcall(tree.SetTreeWidth, tree, want, status.treesizable ~= false)
    tree.xuiRoomBusy = nil
end

-- left-of-text icon on sidebar rows of the rule trees; returns the width the row text must leave free
function ns.PaintTypeIcon(button, x)
    local uv = tostring(button.uniquevalue or "")
    local root = uv:match("^([^\001]+)")
    local level = button.level or 1
    local slot = SkinOn() and not (ns.CondensedOn and ns.CondensedOn()) and level >= 2 and (root == "all" or root == "loaded" or root == "notloaded" or root == "disabled")
    local key, ruleObj
    if slot then
        local last = uv:match("([^\001]+)$") or ""
        local n = last:match("^rule(%d+)$")
        if n then
            local r = ns.rules and ns.rules[tonumber(n)]
            key = r and (ns.TypeKey(r) or "sttexture")   -- a rule with nothing to show yet still gets an icon (its spell's), so every row has the same layout
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
        do local bg, bd = TC("xui-popup", "bg", { 0.04, 0.04, 0.05, 1 }), TC("xui-popup", "border", { 0.8, 0.5, 1, 1 }); infoPop:SetBackdropColor(bg[1], bg[2], bg[3], 0.97); infoPop:SetBackdropBorderColor(bd[1], bd[2], bd[3], 1) end
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
-- (Debug W7, #467) ScanDropdowns' kept widths (text -> TextW) and the font they were measured with. INFERENCE: the game documents
-- GetStringWidth only as "width: uiUnit" (docs/reference/api/widgets.md, FontString); the key holds everything that could change it
-- for the same text (font file, height, flags, text scale, effective scale), so a change of any of them measures again.
local scanW, scanFont, scanN = {}, nil, 0
local function ScanFontKey()
    if not mfs then return nil end
    local f, h, fl = mfs:GetFont()
    return table.concat({ tostring(f), tostring(h), tostring(fl), tostring(mfs:GetTextScale()), tostring(mfs:GetEffectiveScale()) }, "\001")
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
ns.H2_SIZE = 14   -- inside trigger / cue / condition panes: "Description" and every yellow field label ("Sound", "State", "IF", "THEN") use this size
ns.BODY_INDENT = ns.Style.bodyIndent   -- (core ns.Style, UI-47; trigger / cue / condition panes: the header sits flush left and everything under it is indented by this much
local NOFLEX = { Icon = true, Label = true, InteractiveLabel = true, Heading = true, ColorPicker = true, Image = true }
local GAP = ns.UI_GUTTER or 10   -- gutter between two controls on a row (#351: every row, not only rows that stretch a control)
local GRID_GAP = 30   -- gutter between the two columns of the grid (wide, so the two columns read as separate)
local function BaseW(ch)
    local fr = ch.frame
    local fw = fr.width or fr:GetWidth() or 0
    if not (ch.xuiFlexW and ch.xuiBaseW and math.abs(fw - ch.xuiFlexW) < 0.6) then ch.xuiBaseW = fw end
    local b = ch.xuiBaseW
    if ch.type == "Dropdown" then local m = DDMin(ch); if m > b then b = m end end
    return b
end
-- Compact buttons (0.6.4, Xaya's standing rule for every window): an action button is as wide as its label, never stretched to fill
-- its row and never a whole row by itself. Choices between options belong in a dropdown (with a tick box to its left where it can
-- be switched off), not in a row of buttons. Exceptions: section headers (arg.xuiLeft), the red X (arg.xuiDel), and a button that
-- explicitly asks to stay wide (arg.xuiWide).
-- padding: AceGUI (and Skin.lua's flat button) pin the label 15 px in from each side, so the label's box is the width - 30; 34 leaves
-- the whole label 2 px clear on each side (26 was 4 px short: even a well-measured label was cut by a few pixels, #368)
local COMPACT_PAD, COMPACT_MIN = 34, 64
local TAB_GAP = 2   -- between the tabs drawn as buttons (#370)
-- Table cells (arg.xuiCell, Options 0.6.44: the auto-populate table, AutoPicker.lua). Controls with a relative width whose widths add up
-- to 1 make one table row. They sit CELL_GAP apart instead of the grid's 30 px gutter, and each cell gives up its share of the gutters,
-- so the row fills the pane exactly. A full row also makes AceGUI's Flow start the next table row on a new line (its first cell no
-- longer fits beside it; true while that cell is wider than the row's gutters, e.g. 0.08 of a pane wider than 330 px).
-- A row also ends where the next cell would push it past the whole pane (Options 0.6.105), so a row of 0.99 no longer takes the
-- next row's first cells onto its line and shrinks them all (Blizzard Reskin > Theme, Xaya's screenshot 2026-11-08).
local CELL_GAP = 4
function ns.IsCompactButton(ch)
    if ch.type ~= "Button" or not SkinOn() then return false end
    local o = ch.GetUserData and ch:GetUserData("option")
    if not o or o.type ~= "execute" then return false end
    local a = type(o.arg) == "table" and o.arg or nil
    if a and (a.xuiLeft or a.xuiDel or a.xuiWide or a.xuiRow) then return false end
    return true
end
-- The label's WHOLE width (#368). AceGUI pins a button's label between two anchors, so GetStringWidth gives the width of the text as
-- it fits in the button now (INFERENCE from the in-game result, "Gro..."): measured that way, a button narrower than its label sized
-- itself to the cut text, and lost 4 px on every layout pass (fitted width + 26 vs a box of width - 30) down to the 64 px minimum.
-- GetUnboundedStringWidth is the text's own width (Blizzard sizes text-fitted controls with it: UIDropDownMenu.lua, SecureUtil.lua).
local function LabelWidth(fs)
    if not fs then return 0 end
    local fn = fs.GetUnboundedStringWidth or fs.GetStringWidth
    if not fn then return 0 end
    local ok, w = pcall(fn, fs)
    return (ok and type(w) == "number") and w or 0
end
local function CompactWidth(ch, width)
    local tw = LabelWidth(ch.text)
    return math.min(width, math.max(COMPACT_MIN, math.ceil(tw + COMPACT_PAD)))
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
        -- #352 (Xaya's standing rule): a dropdown never takes a whole row by itself. Alone on its row it keeps its own width: one
        -- grid column, or its longest option when that is wider. It still shares leftover width with other controls on its row.
        local lone = (n == 1 and row[1].ch.type == "Dropdown" and row[1].flex)
        if lone then
            local e = row[1]
            if math.abs((e.ch.frame.width or 0) - e.base) > 0.4 then e.ch:SetWidth(e.base) end
            e.ch.xuiFlexW = e.base
        end
        for _, e in ipairs(row) do if e.flex and not lone then flex[#flex + 1] = e end end
        -- arg.xuiEndMargin (#471, Options 0.6.97: Theme > "Delete saved"): the row's stretched controls leave one margin free at its right
        -- end, so its last control stays that far inside the page's edge
        local endM = 0
        for _, e in ipairs(row) do
            local o = e.ch.GetUserData and e.ch:GetUserData("option")
            if o and type(o.arg) == "table" and o.arg.xuiEndMargin then endM = UI_MARGIN end
        end
        local extra = math.max(0, math.floor(width - gap * (n - 1) - used - endM - 0.05))
        local each, rem = 0, 0
        if #flex > 0 then each = math.floor(extra / #flex); rem = extra - each * #flex end
        for k, e in ipairs(flex) do
            local nw = e.base + each + ((k == #flex) and rem or 0)
            if math.abs((e.ch.frame.width or 0) - nw) > 0.4 then e.ch:SetWidth(nw) end
            e.ch.xuiFlexW = nw
        end
        for i, e in ipairs(row) do
            -- #351: the gutter goes between every two controls on a row. It used to be added only when the row stretched a control
            -- (or held a compact button), so rows of fixed-width controls (icons, labels, colour pickers, relative widths) touched.
            -- The row-wrap check above already counts the gutter, so this never pushes a control past the edge.
            local g = (i > 1) and gap or nil
            if g and e.tab and row[i - 1].tab then g = TAB_GAP end   -- #370: tabs sit side by side like a real tab row
            if g and e.cell and row[i - 1].cell then g = e.sub and 0 or CELL_GAP end   -- a sub-cell (arg.xuiSubCell) shares its cell: no gutter
            e.ch.xuiGapX = g
        end
        row, used = {}, 0
    end
    local cells   -- the table row being collected (arg.xuiCell): { list, nom = the sum of its relative widths }
    local function closeCells()
        if not cells then return end
        local n = 0   -- gutters sit between cells; a sub-cell (arg.xuiSubCell: the 2nd+ control of one table cell) adds none
        for _, e in ipairs(cells.list) do if not e.sub then n = n + 1 end end
        local scale = 1
        if cells.nom > 0 then scale = math.min(1, (width - CELL_GAP * (n - 1)) / (cells.nom * width)) end
        if scale < 0 then scale = 0 end
        for _, e in ipairs(cells.list) do
            e.ch.relWidth = math.max(0.001, e.nom * scale)
            e.base = width * e.ch.relWidth
        end
        cells = nil
    end
    for _, ch in ipairs(children) do
        local oc = ch.GetUserData and ch:GetUserData("option")
        local isCell = ch.width == "relative" and oc and type(oc.arg) == "table" and oc.arg.xuiCell
        if cells and not isCell then closeCells(); flush() end   -- the table row ends: whatever follows starts its own
        if ns.IsCompactButton(ch) then   -- sized to its label, shares the row, never stretched
            if ch.width == "fill" or ch.width == "relative" then ch.width = nil end   -- (AceConfigDialog sets it again on the next build)
            local w = CompactWidth(ch, width)
            if math.abs((ch.frame.width or 0) - w) > 0.4 then ch:SetWidth(w) end
            ch.xuiFlexW = w
            if #row > 0 and used + gap + w > width then flush() end
            local o = ch.GetUserData and ch:GetUserData("option")
            row[#row + 1] = { ch = ch, base = w, flex = false, compact = true, tab = (o and type(o.arg) == "table" and o.arg.xuiTab) and true or nil }
            used = used + w
        elseif ch.width == "fill" then
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
                if isCell then
                    local nom = (type(oc.relWidth) == "number") and oc.relWidth or (ch.relWidth or 0)   -- the option's own width, every pass
                    -- a new table row starts when the row so far is full, or when this cell would push it past the whole pane
                    -- (Options 0.6.105: a row of 0.99 used to take the next row's first cells and shrink them all onto one line,
                    -- Blizzard Reskin > Theme; a sub-cell shares the cell before it and never starts a row)
                    if not cells or cells.nom >= 0.999 or (not oc.arg.xuiSubCell and cells.nom + nom > 1.001) then
                        closeCells(); flush()
                        cells = { list = {}, nom = 0 }
                    end
                    local e = { ch = ch, base = width * nom, flex = false, cell = true, nom = nom, sub = oc.arg.xuiSubCell and true or nil }
                    row[#row + 1] = e
                    cells.list[#cells.list + 1] = e
                    cells.nom = cells.nom + nom
                    used = used + width * nom
                    w = nil
                end
            else
                w = (bw or BaseW)(ch); flex = not NOFLEX[ch.type]
                -- two-column grid: a control is either one column wide or spans both (when it cannot fit in a column)
                if grid and flex then w = (w > colW + 0.5) and width or colW end
            end
            if w then   -- (nil: a table cell, placed above)
                if #row > 0 and used + gap + w > width then flush() end
                row[#row + 1] = { ch = ch, base = w, flex = flex }
                used = used + w
            end
        end
    end
    closeCells()
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
        -- rows of option args flagged xuiCenter (several small buttons in one line) are centered in the pane
        pcall(function()
            local cw = content.width or content:GetWidth() or 0
            local rows, order = {}, {}
            for _, ch in ipairs(children) do
                local o = ch.GetUserData and ch:GetUserData("option")
                if o and type(o.arg) == "table" and o.arg.xuiCenter and ch.frame and ch.frame:IsShown() then
                    local _, rel, _, x, y = ch.frame:GetPoint(1)
                    if rel == content then
                        local key = math.floor((y or 0) + 0.5)
                        if not rows[key] then rows[key] = {}; order[#order + 1] = key end
                        rows[key][#rows[key] + 1] = { ch.frame, x or 0 }
                    end
                end
            end
            for _, key in ipairs(order) do
                local r = rows[key]
                local left, right = math.huge, -math.huge
                for _, e in ipairs(r) do left = math.min(left, e[2]); right = math.max(right, e[2] + (e[1]:GetWidth() or 0)) end
                local shift = math.floor((cw - (right - left)) / 2 - left)
                if shift > 0 then
                    for _, e in ipairs(r) do
                        local p, rel, rp, x, y = e[1]:GetPoint(1)
                        e[1]:ClearAllPoints(); e[1]:SetPoint(p, rel, rp, (x or 0) + shift, y or 0)
                    end
                end
            end
        end)
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
    -- (Options 0.6.68, REQUEST-LOG A15 P-16) the tree the window was just drawn from; a build of its own only when none is kept (it was a
    -- full extra build on every window's first decoration: ~450 ms and ~160 MB in the stand-in with 313 rules)
    local root = ns.OptionsApi and ns.OptionsApi.LastTree and ns.OptionsApi.LastTree()
    if type(root) ~= "table" then
        if not ns.BuildOptionsTable then return 0 end
        local ok, r = pcall(ns.BuildOptionsTable)
        if not ok or type(r) ~= "table" then return 0 end
        root = r
    end
    local seen, mx = {}, 0
    -- (Debug W7, #467) The widths are kept between scans: a scan runs on every redraw that builds a rule's editor (FillRule asks
    -- for one), and measured every option text of every dropdown in the tree each time (with 313 rules in the stand-in: 13,054
    -- texts, 26,108 game calls, the biggest part of the skin pass). A text's width depends only on the text and the measuring
    -- string's font (file, size, flags) and scale; those are read once per scan and the kept widths are dropped when any changed.
    local key = ScanFontKey()
    if key ~= scanFont then scanW = {}; scanN = 0 end
    local texts, measured = 0, 0
    local function W(txt)
        texts = texts + 1
        local tw = scanW[txt]
        if tw == nil then
            tw = TextW(txt); measured = measured + 1
            if scanN >= 20000 then scanW = {}; scanN = 0 end   -- (a cap: texts from rules deleted since are not kept for ever)
            scanW[txt] = tw; scanN = scanN + 1
        end
        return tw
    end
    local function walk(g, depth)
        if type(g) ~= "table" or seen[g] or depth > 30 then return end
        seen[g] = true
        if g.type == "select" then
            local vals = g.values
            if type(vals) == "function" then local ok2, r = pcall(vals, {}); vals = ok2 and r or nil end
            if type(vals) == "table" then
                for _, txt in pairs(vals) do
                    if type(txt) == "string" then local tw = W(txt) + 40; if tw > mx then mx = tw end end
                end
            end
        end
        if type(g.args) == "table" then for _, v in pairs(g.args) do walk(v, depth + 1) end end
    end
    walk(root, 0)
    scanFont = ScanFontKey()   -- (the measuring string is made by the first TextW: the widths kept are for its font)
    -- the last scan's counts, for the Dev Assist walkthrough (QAWalks-debug-w7.lua) and the test (tests/rule_click_cost_run.py)
    local st = ns.OptionsApi.WidthScan or {}
    ns.OptionsApi.WidthScan = st
    st.scans, st.texts, st.measured, st.width = (st.scans or 0) + 1, texts, measured, math.min(mx, 520)
    return math.min(mx, 520)
end
function ns.UpdateMinWidth(of)
    local fr = of.frame
    if not (fr and fr.SetResizeBounds) then return end
    if of.xuiChrome and of.xuiChrome.collapsed then
        -- #478 (Options 0.6.97): a redraw while collapsed re-applies AceGUI's stored width (AceGUIContainer-Frame.lua ApplyStatus), which
        -- can be narrower than the window was (this function widened it to its minimum); the window keeps the width it had when it was
        -- collapsed, so the title-bar buttons, anchored to its right edge, stay where they were
        local keep = of.xuiChrome.openWidth
        if keep and fr:GetWidth() < keep - 0.5 then fr:SetWidth(keep) end
        return
    end
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

-- is this widget inside a trigger / cue / condition pane (a group indented by arg.xuiIndent)?
local function InPane(w)
    local p, n = w.parent, 0
    while p and n < 14 do
        if p.xuiIndent then return true end
        p = p.parent; n = n + 1
    end
    return false
end
local function Walk(w, depth)
    if not w or depth > 14 then return end
    local t = w.type
    if t == "TabGroup" then SkinTabGroup(w)
    elseif t == "TreeGroup" then SkinTree(w)
    elseif t == "Button" then SkinButton(w)
    elseif t == "InlineGroup" then SkinInline(w)
    elseif t == "Icon" then
        -- (UI-53) a page's info icon (core ns.InfoBox): the icon alone, no name under it (the name is its tooltip's title line);
        -- the page is laid out again once, the first time, so no gap stays where the name was
        local o = w.GetUserData and w:GetUserData("option")
        if o and type(o.arg) == "table" and o.arg.xuiInfoToggle and w.label and w.label:IsShown() and w.SetLabel then
            w:SetLabel(nil)
            if w.parent and w.parent.DoLayout then pcall(w.parent.DoLayout, w.parent) end
        end
    elseif t == "EditBox" or t == "MultiLineEditBox" then
        if t == "EditBox" then SideLabel(w, "EditBox") end
        -- #471 / #483: the box's Okay / Accept button in the flat look (AceGUI shows it while the text is changed; Enter does the same)
        if w.button and not w.xuiInnerBtn then
            w.xuiInnerBtn = true
            AddRest(w, "innerbtn", function(self) self.xuiInnerBtn = nil; UnflatInner(self.button) end)
        end
        FlatInner(w.button)
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
                -- AceGUI reuses its list rows and only sets their height once (17, highlight 14). A texture picker makes them 60 tall; if one of
                -- those rows is reused here it stays tall, so rows overlap and the hover bar covers 3 rows. Put every row back to normal; the
                -- texture picker's own Open (wrapped around this one) makes its rows tall again after this runs.
                pcall(function()
                    for _, item in pairs(self.items) do
                        if item.frame then item.frame:SetHeight(17) end
                        if item.highlight then item.highlight:SetHeight(14) end
                    end
                end)
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
                -- the closed box shows a small icon; the list's transparent padding (#336, Options.lua TexPickRow) is dropped there
                local function small(s)
                    if not s then return s end
                    s = s:gsub("|T[^|:]*xui_blank%.tga:%d+:%d+|t", "")
                    return (s:gsub("(|T[^|:]+):%d+:%d+|t", "%1:22:22|t"))
                end
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
            bg:SetAllPoints(); do local c = TC("xui-window", "bg", { 0.05, 0.05, 0.06, 1 }); bg:SetColorTexture(c[1], c[2], c[3], 1) end
            local edge = CreateFrame("Frame", nil, pf, "BackdropTemplate")
            edge:SetAllPoints(); edge:SetFrameLevel(pf:GetFrameLevel())
            edge:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
            do local c = TC("xui-pane", "border", { 0.4, 0.4, 0.45, 1 }); edge:SetBackdropBorderColor(c[1], c[2], c[3], 1) end
        end
    elseif t == "Heading" then
        -- a header with arg.xuiCollapse gets the open / close button at its LEFT, before the title (0.6.4: was a red + / - at the far right),
        -- that hides the options under it (Options.lua: ns.CollapsibleHeaders; the title is moved right by ns.LeftAlign)
        do
            local ho = w.GetUserData and w:GetUserData("option")
            local ha = ho and type(ho.arg) == "table" and ho.arg.xuiCollapse and ho.arg or nil
            if ha and w.frame then
                local b = w.xuiCollBtn
                if not b then
                    b = CreateFrame("Button", nil, w.frame)
                    b:SetSize(20, 20)
                    b:SetPoint("LEFT", w.frame, "LEFT", 0, 0)
                    b.tex = b:CreateTexture(nil, "ARTWORK"); b.tex:SetPoint("CENTER"); b.tex:SetSize(16, 16)
                    b:SetScript("OnClick", function(self) if self.fn then self.fn() end end)
                    b:SetScript("OnEnter", function(self)
                        do local c = TC("xui-label", "text", { 1, 1, 0.6, 1 }); self.tex:SetVertexColor(c[1], c[2], c[3]) end
                        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
                        GameTooltip:SetText("Collapse or expand this section")
                        GameTooltip:AddLine("Only hides the options below; nothing is changed.", 1, 1, 1, true)
                        GameTooltip:Show()
                    end)
                    b:SetScript("OnLeave", function(self) self.tex:SetVertexColor(1, 1, 1); GameTooltip:Hide() end)
                    w.xuiCollBtn = b
                end
                -- (re-registered every pass: the restore list is emptied each time AceGUI releases the widget)
                AddRest(w, "collbtn", function(self) if self.xuiCollBtn then self.xuiCollBtn:Hide(); self.xuiCollBtn.fn = nil end end)
                b.fn = ha.xuiToggle
                local closed = ha.xuiCollapsed and ha.xuiCollapsed()
                ns.PaintOpenClose(b.tex, not closed)
                b:Show()
                if ns.LeftAlign then w.xuiLeftOn = nil; pcall(ns.LeftAlign, w) end   -- title starts right of the button
            end
        end
        -- ONE header size across the whole UI (section titles between the lines, collapsible headers, "Description" etc.)
        if w.label and not w.xuiH3 then
            local f1, f2, f3 = w.label:GetFont()
            w.xuiH3 = { f1, f2, f3 }
            local hs = InPane(w) and ns.H2_SIZE or ns.H3_SIZE
            w.label:SetFont(f1, hs, f3)
            if w.frame and w.frame:GetHeight() < hs + 6 then w.frame:SetHeight(hs + 6); w.frame.height = hs + 6 end
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
    -- yellow field labels inside those panes ("Sound", "State", "Spell ID" ...) share the "Description" heading size
    if (t == "Dropdown" or t == "EditBox" or t == "Slider") and w.label and not w.xuiH2L and InPane(w) then
        local o3 = w.GetUserData and w:GetUserData("option")
        if not (o3 and type(o3.arg) == "table" and o3.arg.xuiSide) then
            local f1, f2, f3 = w.label:GetFont()
            if f1 then
                w.xuiH2L = { f1, f2, f3 }
                w.label:SetFont(f1, ns.H2_SIZE, f3)
                AddRest(w, "h2label", function(self) if self.xuiH2L and self.label then self.label:SetFont(unpack(self.xuiH2L)) end; self.xuiH2L = nil end)
            end
        end
    end
    -- theme text colors on the stock AceGUI labels (they were always game gold / white, so a light theme could not be read)
    do
        local fsList
        if t == "Heading" or t == "Dropdown" or t == "EditBox" or t == "Slider" or t == "MultiLineEditBox" then fsList = { { w.label, "xui-label", { 1, 0.82, 0, 1 } } }
        elseif t == "ColorPicker" then fsList = { { w.text, "xui-text", { 1, 1, 1, 1 } } }
        elseif t == "CheckBox" then fsList = { { w.text, "xui-text", { 1, 1, 1, 1 } } }
        elseif t == "Label" then
            local o4 = w.GetUserData and w:GetUserData("option")
            local oa4 = o4 and type(o4.arg) == "table" and o4.arg or nil
            if not (oa4 and (oa4.xuiRow or oa4.xuiH1)) then fsList = { { w.label, "xui-text", { 1, 1, 1, 1 } } } end   -- clickable rows paint themselves
        end
        if fsList and TH then
            for _, e in ipairs(fsList) do
                local fs, cl, fb = e[1], e[2], e[3]
                local isOpt = w.GetUserData and w:GetUserData("option")
                if fs and fs.SetTextColor and not (t == "CheckBox" and w.disabled) then
                    local c = TC(cl, "text", fb)
                    fs:SetTextColor(c[1], c[2], c[3])
                    if TH.IsLight and TH.IsLight() then fs:SetShadowOffset(0, 0) end
                    AddRest(w, "xuiLblCol" .. cl, function(self)
                        local f2 = (t == "CheckBox" or t == "ColorPicker") and self.text or self.label
                        if f2 and f2.SetTextColor then f2:SetTextColor(fb[1], fb[2], fb[3]); f2:SetShadowOffset(1, -1) end
                    end)
                end
            end
        end
    end
    -- light themes: the dropdown box is Blizzard's dark art; swap it for a flat box in the button colors
    if t == "Dropdown" and w.dropdown and TH and TH.IsLight and TH.IsLight() and not w.xuiLightDD then
        w.xuiLightDD = true
        HideRegions(w.dropdown, nil)
        local bg, bd = TC("xui-button", "bg", { 1, 1, 1, 0.9 }), TC("xui-button", "border", { 0.5, 0.5, 0.55, 1 })
        Flat(w.dropdown, bg, bd, { 15, 17, 2, 2 })
        if w.text then local c = TC("xui-button", "text", { 0.1, 0.2, 0.55, 1 }); w.text:SetTextColor(c[1], c[2], c[3]); w.text:SetShadowOffset(0, 0) end
        AddRest(w, "lightDD", function(self)
            self.xuiLightDD = nil
            if self.dropdown then ShowRegions(self.dropdown); FlatHide(self.dropdown) end
            if self.text then self.text:SetTextColor(1, 1, 1); self.text:SetShadowOffset(1, -1) end
        end)
    end
    if t == "Slider" then pcall(SkinSlider, w)
    elseif t == "ScrollFrame" or t == "InlineGroup" or t == "SimpleGroup" then pcall(FlexOn, w) end
    for _, c in ipairs(w.children or {}) do Walk(c, depth + 1) end
end

-- Light themes: no text shadow and no outline anywhere in the window (dark text with a black shadow is smudgy). Everything touched is recorded
-- on the fontstring (xuiLS) so a later dark theme gets its shadow / outline back.
local function ShadowPass(f, light, depth)
    if not f or depth > 9 then return end
    for _, rg in ipairs({ f:GetRegions() }) do
        if rg.GetObjectType and rg:GetObjectType() == "FontString" then
            if light then
                local fn, sz, fl = rg:GetFont()
                if not rg.xuiLS then local x, y = rg:GetShadowOffset(); rg.xuiLS = { x or 0, y or 0, fl or "" } end
                rg:SetShadowOffset(0, 0)
                if fn and fl and fl:find("OUTLINE") then rg:SetFont(fn, sz, (fl:gsub("THICKOUTLINE", ""):gsub("OUTLINE", ""):gsub("^[, ]+", ""):gsub("[, ]+$", ""))) end
            elseif rg.xuiLS then
                local o = rg.xuiLS; rg.xuiLS = nil
                rg:SetShadowOffset(o[1], o[2])
                local fn, sz = rg:GetFont()
                if fn and o[3] ~= "" then rg:SetFont(fn, sz, o[3]) end
            end
        end
    end
    for _, c in ipairs({ f:GetChildren() }) do ShadowPass(c, light, depth + 1) end
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
        if root.frame then pcall(ShadowPass, root.frame, TH and TH.IsLight and TH.IsLight() or false, 0) end
    end
end
