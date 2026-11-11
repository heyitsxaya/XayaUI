-------------------------------------------------------------------------------
-- CharacterReskin.lua : Character Reskin (XayaUI QoL 0.7.14). Blizzard's character window in XayaUI's LOOK: the solid background, the
-- clean window (border, theme colors, tabs), the stat list's art, the wider window and the extra height. Own code, Blizzard's frames
-- only. Off by default; while off nothing is created, hooked or changed. Its settings page is the settings window's Blizzard UI Reskin
-- tab > Character Reskin (module "reskin"; Xaya 2026-11-05: every reskin in one tab).
-- (Stat Calculator V25 step R2; REQUEST-LOG A24 #3-#6) this file is the look only. Everything that adds to or draws on the character
-- window (one item level per slot, the enchant / embellishment / gem blocks, the full stat list, the slot marks, the Stat Calc button)
-- is Improved Character Display's (QoL > Improved Character Display, XayaUI_QoL/ImprovedCharacterDisplay.lua). The two halves run on
-- their own; the only seam between them is below ("The seam"): this file tells listeners when the window's size changes and when the
-- look was laid out (ns.CharReskin_OnWindowSize), and answers the extra height's slot gap (ns.CharReskin_TallGap) and the look switch's
-- saved value for Improved Character Display's one-time settings merge (ns.CharReskin_LookSavedOn). Map of the split: docs/plans/
-- STAT-CALCULATOR-BOUNDARY-MAP-2026-11-10.md section 5.
-- (V27 gate G-029) one read goes the other way, and it is diagnostic only: the "characterReskin" service's Drawn() (below, for XayaUI
-- Dev Assist's QAWalks-character-split.lua) asks Improved Character Display's "charDisplay" service for its counts, read only, inside a
-- pcall, zero when that addon part is not loaded. Nothing this file draws or decides depends on it.
--
-- Xaya, 2026-11-04: "also create a QoL Character Reskin option to toggle on or off"; "I want a reskin OF THE CHARACTER MENU AND NOTHING
-- ELSE"; "GIVE ME A PRETTY VERSION OF THE CHARACTER SHEET"; "THIS window needs to look beautiful and CLEAN"; "prettify the character
-- window". Requirements: docs/plans/STAT-CALCULATOR-REQUIREMENTS-2026-11-04.md, rows A1-A7 (A6, the wider window, built in QoL 0.7.22
-- after her /xui debug widthprobe result).
-- Xaya, 2026-11-05 (QoL 0.7.22): "complete the entire character pane issue now and make sure the reskin of the character pane is also
-- solved -- the current invisible background is not good".
--
-- How (the frames are Blizzard's, live 12.1.5 source, read 2026-11-05: CharacterFrame.xml, PaperDollFrame.xml, and
-- SharedUIPanelTemplates.xml for ButtonFrameTemplate / PortraitFrameBaseTemplate / InsetFrameTemplate / PanelTabButtonTemplate):
--   * Restyle: Blizzard's art is faded (alpha 0) and ours is drawn on its own textures and font strings. Switching off puts every alpha
--     and text color back. The only size and anchor changes are the wider window's (below), made out of combat only.
--   * Background (QoL 0.7.22): a solid fill in the theme's window color under the whole window (the stats pane and the wider area
--     too) whenever the reskin is on, at its own "Background opacity" (default 95%, never below 50%). With Clean window off Blizzard's
--     own art is drawn over it; with Clean window on Blizzard's art goes and ours (border, pane fills) is drawn.
--   * Window (Clean window): the frame art (NineSlice, Bg, TopTileStreaks), the portrait, the paper-doll background, the insets' art, the
--     model's backgrounds and inner border, the stats pane's class background, the tab art, and the slot frame art and the slots' bevel;
--     then a thin border, the theme's pane color behind the stats pane, a softer fill behind the model, theme-colored title and tabs.
--   * Wider window (QoL 0.7.22, requirement A6; on by default with the reskin): the room between the slot columns and the model that
--     Improved Character Display's blocks use (notes at "The wider window" below).
--   * Stat list colors (Blizzard's own stat list): the row and header art goes; theme-colored headers with a thin rule, labels, values
--     and a faint stripe on every other row (where Blizzard shows its own).
--   * Safety (as the Game Menu skin): any error while applying turns the reskin off for the session and gives Blizzard's look back.
-- NOT RUN IN GAME when written: QA E1z6 (E1z40-E1z44 for QoL 0.7.22). The split itself is UNVERIFIED IN GAME.
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns
local QolS = ns.Settings("qol")   -- (QoL 0.7.47, P2 settings seam; QoL 0.7.49, P5: QoL's own XayaUIQoLDB; Modules.lua section 0b)
if ns.SettingsDeclareStore then ns.SettingsDeclareStore("qol", "XayaUI_QoL", "XayaUIQoLDB") end   -- (P5) this addon's own saved variable (its .toc; Modules.lua section 0b)
local CM = ns.StatModel

-- booleans are switches; numbers are the wider window's extra width (px), the extra height (px) and the background's opacity (0.5 - 1)
-- (QoL 0.7.24) extra width 42 px by default (Xaya 2026-11-06: "Push to 380px before stats pane and request feedback confirmation":
-- Blizzard's PANEL_DEFAULT_WIDTH 338 -> 380 without the stats pane, CHARACTERFRAME_EXPANDED_WIDTH 540 -> 582 with it); the setting
-- now reaches 0 (it started at 120); a saved number is kept as it is.
-- (QoL 0.7.31) tallPx: the Extra height (Xaya 2026-11-06: "character pane option should also allow for extra height"; her answer "either
-- one", built as "Spread the slots"; REQUEST-LOG #72-#73), 0 by default: nothing changes until she moves it.
-- (V25 R2) the item level, enchant, gem and full stat list keys are Improved Character Display's (ns.CHARDISPLAY_DEFAULTS).
local DEFAULTS = { enabled = false, chrome = true, stats = true, wide = true, widePx = 42, bgAlpha = 0.95, tallPx = 0 }
local LIMITS = { widePx = { 0, 300 }, bgAlpha = { 0.5, 1 }, tallPx = { 0, 300 } }
ns.CHARRESKIN_DEFAULTS = DEFAULTS
-- (P5, Xaya PS-53: "Character ui *reskin* is a blizzard change. Functionality changes or enhancements are separate.") The look's
-- settings (LOOK below: the switch, chrome, the stat list's art, background opacity, the wider window, the extra height) are Blizzard
-- Reskin's (XayaUIReskinDB.characterReskin); the rest of that key (QoL's half, XayaUIQoLDB.characterReskin) is Improved Character
-- Display's and this file never reads it (V25 R2). While Blizzard Reskin's settings are not open (XayaUI Blizzard Reskin switched off)
-- the look is this session's defaults with the switch off: nothing is drawn and nothing is saved for it. (Modules.lua sections 0b /
-- 0c; the split is LEGACY_SPLIT there.)
local ReskinS = ns.Settings("reskin")
local lookT, lookOff, lookEpoch
-- (QoL 0.7.54; REQUEST-LOG TRI-4 / TRI-8, 2026-11-08) XayaUI Blizzard Reskin not installed at all (main holds no Blizzard Reskin since
-- 2026-11-08: tools/qa-only-paths.txt; it lives on qa-installer-branch). Xaya: the character reskin "should follow the same logic as
-- improved chat: if no reskin is present, reskin it; otherwise let the current reskin run and only run the other components". So
-- without that addon the look half is kept in QoL's own settings (XayaUIQoLDB.characterReskinLook) and its switch works; an installed
-- but switched-off Blizzard Reskin still keeps the look off, as before. Only "missing" counts (core ns.ModuleState).
local function ReskinMissing()
    if type(ns.ModuleState) ~= "function" then return false end
    local ok, state = pcall(ns.ModuleState, "XayaUI_Reskin")
    return ok and state == "missing" or false
end
-- The look half without that addon: reads XayaUIQoLDB.characterReskinLook when it exists; until a setting is changed from its default
-- (Cfg fills the defaults in on every read) nothing is saved, so an install that never touches the reskin keeps no new key.
local lookMain
local function MainLook()
    if lookMain then return lookMain end
    local session = {}
    lookMain = setmetatable({}, {
        __index = function(_, k)
            local sv = QolS.characterReskinLook
            if type(sv) == "table" and sv[k] ~= nil then return sv[k] end
            return session[k]
        end,
        __newindex = function(_, k, v)
            local sv = QolS.characterReskinLook
            if type(sv) ~= "table" then
                if DEFAULTS[k] == nil or v == DEFAULTS[k] or v == session[k] then session[k] = v; return end
                sv = {}
                for kk, vv in pairs(session) do sv[kk] = vv end
                QolS.characterReskinLook = sv
            end
            sv[k] = v
        end,
    })
    return lookMain
end
local function LookTable()
    if lookEpoch == ns.settingsEpoch and lookT then return end
    local l
    if ns.SettingsReady("reskin") then
        l = ReskinS.characterReskin
        if type(l) ~= "table" then l = {}; ReskinS.characterReskin = l end
    elseif ReskinMissing() then
        l = MainLook()
    else
        lookOff = lookOff or {}
        l = lookOff
    end
    lookT, lookEpoch = l, ns.settingsEpoch
end
local function Cfg()
    if not ns.SettingsReady("qol") then return nil end
    LookTable()
    local c = lookT
    -- (QoL 0.7.27) once per install: QoL 0.7.21-0.7.23 saved their default extra width, 240, into the settings, so the 0.7.24 default
    -- (42: 380 / 582) never reached an install that had run them (Xaya 2026-11-06: "surely this isn't 380px?", REQUEST-LOG #58-#59;
    -- her answer: a saved 240, the old default, becomes 42 once; any other saved number stays; a 240 picked after this stays too)
    if c.widePxTo42 == nil then
        if tonumber(c.widePx) == 240 then c.widePx = 42 end
        c.widePxTo42 = true
    end
    for k, v in pairs(DEFAULTS) do
        if type(v) == "boolean" then
            if c[k] == nil then c[k] = v end
            c[k] = c[k] == true
        else
            local n, lim = tonumber(c[k]), LIMITS[k]
            if not n or n ~= n then n = v end
            c[k] = math.max(lim[1], math.min(lim[2], n))
        end
    end
    if lookT == lookOff then lookOff.enabled = false end   -- (Blizzard Reskin off: the reskin stays off)
    return c
end
ns.CharReskin_Cfg = Cfg

-- (V25 R2, the seam) the look switch's saved value as it is in effect (a switch saved for the next /reload counts after it), or nil
-- while it cannot be read yet (XayaUI Blizzard Reskin installed but its settings not open: before its ADDON_LOADED, or switched off).
-- Read once by Improved Character Display's one-time settings merge: before V25 its item level / enchant / gem / stat list parts
-- took this switch's value until they had a saved switch of their own (QoL 0.7.53 `features`).
function ns.CharReskin_LookSavedOn()
    if not ns.SettingsReady("qol") then return nil end
    LookTable()
    if lookT == lookOff then return nil end
    return ns.SwitchInEffect("reskin.charreskin", lookT.enabled)
end

local diag = { applied = false, failed = false, lastError = nil, faded = 0, wide = "off" }
ns.CharReskinDiag = diag

local function num(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end
-- (QoL 0.7.52, #472) the character window's theme scope: its own theme or colors from Blizzard Reskin > Theme, else the global theme as before
local SCOPE = "reskin.charreskin"
local function TC(class, prop, fb)
    local T = ns.Theme
    if T and T.Col then local ok, c = pcall(T.Col, class, prop, SCOPE, fb); if ok and type(c) == "table" then return c end end
    return fb
end
ns.CharReskin_ThemeCol = TC   -- (tests: the color every part of the window is painted with)

-- Blizzard regions faded by us, with the alpha they had; and text colors we changed, with the color they had
local faded, recolored = {}, {}
local function Fade(r)
    if type(r) ~= "table" or type(r.SetAlpha) ~= "function" or faded[r] ~= nil then return end
    local a = r.GetAlpha and r:GetAlpha()
    faded[r] = num(a) and a or 1
    r:SetAlpha(0)
    diag.faded = diag.faded + 1
end
local function Recolor(fs, col)
    if type(fs) ~= "table" or type(fs.SetTextColor) ~= "function" or not col then return end
    if recolored[fs] == nil then
        local r, g, b, a = nil, nil, nil, nil
        if fs.GetTextColor then r, g, b, a = fs:GetTextColor() end
        recolored[fs] = { num(r) and r or 1, num(g) and g or 1, num(b) and b or 1, num(a) and a or 1 }
    end
    fs:SetTextColor(col[1], col[2], col[3], col[4] or 1)
end
local function RestoreAll()
    for r, a in pairs(faded) do pcall(r.SetAlpha, r, a) end
    for fs, c in pairs(recolored) do pcall(fs.SetTextColor, fs, c[1], c[2], c[3], c[4]) end
    faded, recolored, diag.faded = {}, {}, 0
end

-- our own pieces (made once, shown while the reskin is on)
local own = { all = {} }
ns.CharReskinParts = own   -- (for the tests)
local function Own(t) own.all[#own.all + 1] = t; return t end
-- (own data, keyed by Blizzard's frame; V25 standard: never a field on Blizzard's frames) tab / stat category / stat row -> our texture
-- on it: bg (a tab's background), rule (a category's line), stripe (a row's stripe)
local extra = setmetatable({}, { __mode = "k" })
local function XT(f)
    local d = extra[f]
    if not d then d = {}; extra[f] = d end
    return d
end
ns.CharReskin_Extra = function(f) return extra[f] end   -- (tests: read only; nil when nothing was made on it)
local function SetOwnShown(on) for _, t in ipairs(own.all) do if t.SetShown then t:SetShown(on) end end end

local LookActive, Guard   -- (defined in "On / off" below)

-- (V25 R2, the seam) who wants to know when the window's size changes ("size": the slots' positions read right after it may still be
-- the old ones) and when the look has been laid out ("applied": the wider window and the extra height are in place, or put back).
-- Improved Character Display registers here, once, when it is first switched on; nothing else does. Each listener runs in a pcall.
local sizeListeners = {}
function ns.CharReskin_OnWindowSize(fn) if type(fn) == "function" then sizeListeners[#sizeListeners + 1] = fn end end
local function Tell(what) for _, fn in ipairs(sizeListeners) do pcall(fn, what) end end
local function SizeChanged() Tell("size") end
-------------------------------------------------------------------------------
-- The window
-------------------------------------------------------------------------------
local MODEL_REGIONS = { "CharacterModelFrameBackgroundTopLeft", "CharacterModelFrameBackgroundTopRight", "CharacterModelFrameBackgroundBotLeft",
    "CharacterModelFrameBackgroundBotRight", "CharacterModelFrameBackgroundOverlay", "PaperDollInnerBorderTopLeft", "PaperDollInnerBorderTopRight",
    "PaperDollInnerBorderBottomLeft", "PaperDollInnerBorderBottomRight", "PaperDollInnerBorderLeft", "PaperDollInnerBorderRight",
    "PaperDollInnerBorderTop", "PaperDollInnerBorderBottom", "PaperDollInnerBorderBottom2" }

local function StyleTabs()
    local cf = _G.CharacterFrame
    if not cf then return end
    for i = 1, 3 do
        local tab = _G["CharacterFrameTab" .. i]
        if type(tab) == "table" then
            for _, t in ipairs(type(tab.TabTextures) == "table" and tab.TabTextures or {}) do Fade(t) end
            local x = XT(tab)
            if not x.bg and tab.CreateTexture then
                x.bg = Own(tab:CreateTexture(nil, "BACKGROUND"))
                x.bg:SetPoint("TOPLEFT", tab, "TOPLEFT", 3, -3)
                x.bg:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -3, 3)
            end
            if x.bg then
                local on = cf.selectedTab == i
                local c = TC(on and "xui-tab-selected" or "xui-tab", "bg", on and { 0.22, 0.1, 0.3, 0.9 } or { 0.03, 0.03, 0.03, 0.7 })
                x.bg:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
                x.bg:Show()
            end
        end
    end
end

-- (QoL 0.7.22) the solid background, whenever the reskin is on: the theme's window colour (xui-window bg = token windowBg) at the page's
-- "Background opacity", on the window's own BACKGROUND layer at the lowest sublevel, so Blizzard's art (when Clean window is off) and
-- every child frame draw over it. It covers the whole window, the stats pane and the wider area too (all points on the window).
-- Root cause of her "invisible background" (QoL 0.7.14 - 0.7.20): every re-apply (each time the window opened) hid our pieces
-- (SetOwnShown(false)) and the window part never showed its background, border and fill again, while Blizzard's art stayed faded.
-- Each piece is now shown each time it is painted.
local function PaintBackground(c)
    local cf = _G.CharacterFrame
    if type(cf) ~= "table" or not cf.CreateTexture then return end
    if not own.bg then
        own.bg = Own(cf:CreateTexture(nil, "BACKGROUND", nil, -8))
        own.bg:SetAllPoints(cf)
    end
    local bg = TC("xui-window", "bg", { 0.06, 0.06, 0.06, 1 })
    own.bg:SetColorTexture(bg[1], bg[2], bg[3], c.bgAlpha)
    own.bg:Show()
end

-- (V25 R2: was in the slot drawing, which is Improved Character Display's now) Clean window: a slot's frame art and its bevel go
local function WindowShown() local cf = _G.CharacterFrame; return (type(cf) == "table" and cf.IsShown and cf:IsShown()) and true or false end
local function FadeSlot(btn)
    if type(btn) ~= "table" then return end
    local slot = btn.GetID and btn:GetID()
    local name
    if num(slot) then for _, s in ipairs(CM.SLOTS) do if s[1] == slot then name = s[4] end end end
    if not name then return end
    Fade(_G["Character" .. name .. "Frame"]); Fade(btn.GetNormalTexture and btn:GetNormalTexture() or nil)
end

local function StyleWindow(c)
    local cf = _G.CharacterFrame
    if type(cf) ~= "table" then return end
    for _, k in ipairs({ "NineSlice", "Bg", "TopTileStreaks", "PortraitContainer", "Background" }) do Fade(cf[k]) end
    for _, inset in ipairs({ cf.Inset, cf.InsetRight }) do
        if type(inset) == "table" then Fade(inset.Bg); Fade(inset.NineSlice) end
    end
    local pane = _G.CharacterStatsPane
    if type(pane) == "table" then Fade(pane.ClassBackground) end
    for _, name in ipairs(MODEL_REGIONS) do Fade(_G[name]) end
    if not own.edges then
        own.edges = {}
        for i, pts in ipairs({ { "TOPLEFT", "TOPRIGHT", 0 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0 }, { "TOPLEFT", "BOTTOMLEFT", 1 }, { "TOPRIGHT", "BOTTOMRIGHT", 1 } }) do
            local e = Own(cf:CreateTexture(nil, "BORDER"))
            e:SetPoint(pts[1], cf, pts[1]); e:SetPoint(pts[2], cf, pts[2])
            if pts[3] == 1 then e:SetWidth(1) else e:SetHeight(1) end
            own.edges[i] = e
        end
        if type(cf.Inset) == "table" then
            own.inset = Own(cf:CreateTexture(nil, "BACKGROUND", nil, -7))
            own.inset:SetPoint("TOPLEFT", cf.Inset, "TOPLEFT", 2, -2)
            own.inset:SetPoint("BOTTOMRIGHT", cf.Inset, "BOTTOMRIGHT", -2, 2)
        end
        if type(cf.InsetRight) == "table" then
            own.stats = Own(cf:CreateTexture(nil, "BACKGROUND", nil, -7))
            own.stats:SetPoint("TOPLEFT", cf.InsetRight, "TOPLEFT", 2, -2)
            own.stats:SetPoint("BOTTOMRIGHT", cf.InsetRight, "BOTTOMRIGHT", -2, 2)
        end
    end
    local bc = TC("xui-window", "border", { 0.35, 0.35, 0.4, 1 })
    for _, e in ipairs(own.edges) do e:SetColorTexture(bc[1], bc[2], bc[3], bc[4] or 1); e:Show() end
    if own.inset then own.inset:SetColorTexture(1, 1, 1, 0.03); own.inset:Show() end   -- a faint lift behind the model and the slots
    if own.stats then
        local p = TC("xui-pane", "bg", { 0.04, 0.04, 0.04, 1 })
        own.stats:SetColorTexture(p[1], p[2], p[3], c.bgAlpha); own.stats:Show()
    end
    local title = type(cf.TitleContainer) == "table" and cf.TitleContainer.TitleText or _G.CharacterFrameTitleText
    Recolor(title, TC("xui-titlebar", "text", { 1, 0.82, 0, 1 }))
    StyleTabs()
    for _, s in ipairs(CM.SLOTS) do FadeSlot(_G["Character" .. s[4]]) end
end

-------------------------------------------------------------------------------
-- The wider window (QoL 0.7.22, requirement A6; Xaya's in-game /xui debug widthprobe of 2026-11-05: "width probe: on, 120 px wider (540
-- -> 660). window width ok, inset edge ok, model width ok, main hand slot ok, panel placement ok", no ADDON_ACTION line)
-------------------------------------------------------------------------------
-- The same calls the probe made (CharacterWidthProbe.lua), out of combat only, with the character window open on its Character tab:
--   CharacterFrame:SetWidth(Blizzard's width + px); the Inset's BOTTOMRIGHT at the window's BOTTOMLEFT + (PANEL_DEFAULT_WIDTH +
--   PANEL_INSET_RIGHT_OFFSET + px, PANEL_INSET_BOTTOM_OFFSET) (the right slot column and the stats pane hang from the Inset, so they
--   move out); UpdateUIPanelPositions(CharacterFrame) (as Blizzard's UpdateSize does when the width changed).
-- Different from the probe: the model scene keeps its width (231) and moves right by px / 2, so it stays whole and centred and the
-- added room is between each slot column and the model; the main hand slot moves right by px / 2 as in the probe.
-- Widget calls (widgets.md): SetWidth(width: uiUnit) · IsProtectedFunction (:314); GetNumPoints() → numPoints (:150);
-- GetPointByName(point: FramePoint, resolveCollapsed: bool = false) → point, relativeTo, relativePoint, offsetX, offsetY ·
-- ConstSecretAccessor, MayReturnNothing, SecretWhenAnchoringSecret (:158); IsProtected() → isProtected, isProtectedExplicitly ·
-- SecretReturnsForAspect=[ObjectSecurity] (:221). The model's and the main hand's anchors are Blizzard's (PaperDollFrame.xml: the model
-- TOPLEFT 52, -66; the main hand BOTTOMLEFT 130, 16), read once before anything moves; a frame with another number of anchors, or one
-- that says it is protected (or a secret answer), is left alone and the window stays at Blizzard's width (fail safe).
-- Blizzard's own CharacterFrame:UpdateSize (on opening, switching tabs, opening or closing the stats pane) puts its width back; a
-- post-hook (hooksecurefunc on the window's UpdateSize, placed only once the wider window is first on) widens it again on the
-- Character tab. INFERENCE (not in the files read): CharacterFrame.activeSubframe names the shown tab's frame; when it is not a string,
-- PaperDollFrame:IsShown() decides. In combat nothing of the window is changed: when Blizzard put its width back in combat, the model
-- and the main hand go back to Blizzard's places (they are not protected frames: checked with IsProtected), and the window widens
-- again when combat ends (PLAYER_REGEN_ENABLED, events.md:1207, registered only while that waits).
local wide = { applied = false, moved = false, hooked = false }
ns.CharReskinWide = wide   -- (for the tests)
local function NotProtected(f)
    if type(f) ~= "table" or type(f.IsProtected) ~= "function" then return true end
    local p = f:IsProtected()
    if CM.IsSecret(p) then return false end
    return not p
end
local function PointOf(f, point)
    if type(f) ~= "table" or type(f.GetNumPoints) ~= "function" or type(f.GetPointByName) ~= "function" then return nil end
    local n = f:GetNumPoints()
    if CM.IsSecret(n) or n ~= 1 then return nil end
    local p, rel, rp, x, y = f:GetPointByName(point)
    if p ~= point or CM.IsSecret(x) or CM.IsSecret(y) or not num(x) or not num(y) then return nil end
    return { p, rel, rp, x, y }
end
local function WideFrames()
    local cf, m, mh = _G.CharacterFrame, _G.CharacterModelScene, _G.CharacterMainHandSlot
    local DW, RO, BO = _G.PANEL_DEFAULT_WIDTH, _G.PANEL_INSET_RIGHT_OFFSET, _G.PANEL_INSET_BOTTOM_OFFSET
    if not (type(cf) == "table" and type(cf.Inset) == "table" and cf.Inset.SetPoint and type(m) == "table" and type(mh) == "table"
        and num(DW) and num(RO) and num(BO)) then return nil end
    return cf, m, mh, DW, RO, BO
end
local function OnCharacterTab(cf)
    local sub = cf.activeSubframe
    if type(sub) == "string" then return sub == "PaperDollFrame" end
    local pd = _G.PaperDollFrame
    return (type(pd) == "table" and pd.IsShown and pd:IsShown()) and true or false
end
local function InCombat() return (InCombatLockdown and InCombatLockdown()) and true or false end
local function PutBack(m, mh)
    if wide.mp and NotProtected(m) then m:ClearAllPoints(); m:SetPoint(wide.mp[1], wide.mp[2], wide.mp[3], wide.mp[4], wide.mp[5]) end
    if wide.hp and NotProtected(mh) then mh:ClearAllPoints(); mh:SetPoint(wide.hp[1], wide.hp[2], wide.hp[3], wide.hp[4], wide.hp[5]) end
    wide.moved = false
end

local WideRegen
local function WaitForCombatEnd(on)
    if on then
        wide.ev = wide.ev or CreateFrame("Frame")
        wide.ev:SetScript("OnEvent", WideRegen)
        wide.ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    elseif wide.ev then wide.ev:UnregisterAllEvents() end
    wide.pending = on or nil
end

-- The extra height (QoL 0.7.31; Xaya 2026-11-06: "character pane option should also allow for extra height"; her answer "either one", built
-- as "Spread the slots"; REQUEST-LOG #72-#73). With the wider window on and Extra height above 0, out of combat only (as the width): the
-- window is that much taller (CharacterFrame:SetHeight, widgets.md SetHeight(height: uiUnit)); each slot of the two columns after the
-- first hangs from the one above it (PaperDollFrame.xml: TOPLEFT of the slot above's BOTTOMLEFT, 0, -4), so each of the 7 gaps of a
-- column grows by about px / 7 and the columns spread evenly over the added height. (V27 gate G-009, whole pixels) the added height is
-- shared out in whole pixels: every gap gets math.floor(px / 7), and the first px % 7 gaps of each column (from the top) one pixel more,
-- so the 7 gaps add up to px exactly and no slot is anchored at a fraction of a pixel. Each slot hangs from the one above it, so its own
-- y offset is Blizzard's plus its own gap (the offsets add up down the column). The slider keeps its 0-300 range in 1 px steps; the
-- model scene is px taller (its width stays: the game
-- fits the character inside it, INFERENCE); the weapon row hangs from the bottom (BOTTOMLEFT 130, 16), so it moves down with the window.
-- A slot anchored otherwise, or a protected frame (or a secret answer), is left alone and nothing of the height changes (fail safe).
-- 0 gives Blizzard's layout exactly (every anchor and size put back).
local TALL_COLS = { { "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "ShirtSlot", "TabardSlot", "WristSlot" },
    { "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot" } }
local tall = { applied = false, gap = 0 }
ns.CharReskinTall = tall   -- (for the tests)
-- (G-009) tall.gap is the whole-pixel gap EVERY pair of slots has at least (math.floor(px / 7)); a gap given the extra pixel is one more.
-- Improved Character Display halves it for its blocks' room above and below a slot and rounds that half itself.
function ns.CharReskin_TallGap() return tall.applied and tall.gap or 0 end
-- the extra room of gap i (1-7, from the top of a column): whole pixels that add up to px
local function TallGapAt(px, i) local base, rem = math.floor(px / 7), px % 7; return (i <= rem) and (base + 1) or base end
ns.CharReskin_TallGapAt = TallGapAt   -- (tests: read only)
local function TallAnchors()
    if tall.pts then return tall.pts end
    local pts = {}
    for _, col in ipairs(TALL_COLS) do
        for i = 2, #col do
            local b, prev = _G["Character" .. col[i]], _G["Character" .. col[i - 1]]
            local pt = PointOf(b, "TOPLEFT")
            if not (pt and pt[2] == prev and pt[3] == "BOTTOMLEFT" and NotProtected(b)) then return nil end
            pts[col[i]] = pt
        end
    end
    tall.pts = pts
    return pts
end
local function RestoreTall()
    if not tall.applied then return end
    local cf, m = _G.CharacterFrame, _G.CharacterModelScene
    for name, pt in pairs(tall.pts or {}) do
        local b = _G["Character" .. name]
        if type(b) == "table" and NotProtected(b) then b:ClearAllPoints(); b:SetPoint(pt[1], pt[2], pt[3], pt[4], pt[5]) end
    end
    if tall.baseH and type(cf) == "table" then cf:SetHeight(tall.baseH) end
    if tall.modelH and type(m) == "table" and m.SetHeight then m:SetHeight(tall.modelH) end
    tall.applied, tall.gap, tall.px = false, 0, 0
    SizeChanged()
end
-- the Extra height the setting asks for, as ApplyTall stores it in tall.px: the saved value, or 0 when it rounds to 0 px (off)
local function TallWanted(c) local v = (c and c.tallPx) or 0; return (math.floor(v + 0.5) > 0) and v or 0 end
local function ApplyTall(c, cf, m)
    local saved = (c and c.tallPx) or 0   -- (kept as tall.px: ApplyWide compares it with the setting to see whether anything changed)
    -- (Cfg keeps it inside 0-300; a typed or saved fraction is laid out in whole pixels; rounded BEFORE the off test, so 0.3 is off)
    local px = math.floor(saved + 0.5)
    if px <= 0 then RestoreTall(); diag.tall = "off (0)"; return end
    local pts = TallAnchors()
    if not (pts and NotProtected(cf) and NotProtected(m)) then diag.tall = "the slots are anchored differently or protected: Blizzard's height"; return end
    if not tall.applied then
        local h, mh = cf:GetHeight(), m:GetHeight()
        if CM.IsSecret(h) or CM.IsSecret(mh) or not num(h) or not num(mh) then return end
        tall.baseH, tall.modelH = h, mh
    end
    local gap, rem = math.floor(px / 7), px % 7
    for _, col in ipairs(TALL_COLS) do
        for i = 2, #col do
            local pt, b = pts[col[i]], _G["Character" .. col[i]]
            b:ClearAllPoints(); b:SetPoint(pt[1], pt[2], pt[3], pt[4], pt[5] - TallGapAt(px, i - 1))
        end
    end
    cf:SetHeight(tall.baseH + px)
    m:SetHeight(tall.modelH + px)
    if tall.px ~= saved or not tall.applied then SizeChanged() end
    tall.applied, tall.gap, tall.px = true, gap, saved
    diag.tall = (rem > 0 and "on, %d px taller (%d -> %d); each gap between two slots %d px wider (the top %d of each column %d px)"
        or "on, %d px taller (%d -> %d); each gap between two slots %d px wider"):format(px, math.floor(tall.baseH + 0.5),
        math.floor(tall.baseH + px + 0.5), gap, rem, gap + 1)
end

local function RestoreWide()
    if not (wide.applied or wide.moved or tall.applied) then return end
    local cf, m, mh = WideFrames()
    if not cf then wide.applied, wide.moved = false, false; return end
    if InCombat() then WaitForCombatEnd(true); return end
    PutBack(m, mh)
    RestoreTall()
    wide.applied = false
    SizeChanged()
    -- Blizzard's own sizing puts the width and the Inset back (as the probe's "off"); without it, the width the window had before
    if ns.MapTrace then ns.MapTrace("Character Reskin: CharacterFrame:UpdateSize (wider window off)") end
    if type(cf.UpdateSize) == "function" then pcall(cf.UpdateSize, cf)
    else
        local DW, RO, BO = _G.PANEL_DEFAULT_WIDTH, _G.PANEL_INSET_RIGHT_OFFSET, _G.PANEL_INSET_BOTTOM_OFFSET
        if wide.base then cf:SetWidth(wide.base) end
        cf.Inset:SetPoint("BOTTOMRIGHT", cf, "BOTTOMLEFT", DW + RO, BO)
        if type(UpdateUIPanelPositions) == "function" then pcall(UpdateUIPanelPositions, cf) end
    end
    diag.wide = "off"
end

local HookWide
local function ApplyWide(c)
    if not (c and LookActive() and c.wide) then RestoreWide(); return end
    local cf, m, mh, DW, RO, BO = WideFrames()
    if not cf then diag.wide = "the game's character window is not built as expected: Blizzard's width"; return end
    HookWide()
    if not (cf.IsShown and cf:IsShown() and OnCharacterTab(cf)) then return end   -- (another tab: Blizzard's width; the model is hidden)
    local w = cf:GetWidth()
    if CM.IsSecret(w) or not num(w) then return end
    local reset = wide.reset or not wide.applied or math.abs(w - (wide.setW or -1)) > 0.5
    wide.reset = false
    if InCombat() then
        if reset then
            if wide.moved then PutBack(m, mh) end
            wide.applied = false
            WaitForCombatEnd(true)
            diag.wide = "waits for the end of combat"
        elseif wide.px ~= c.widePx or (tall.applied and tall.px or 0) ~= TallWanted(c) then
            WaitForCombatEnd(true)   -- (QoL 0.7.31) a width or height set in combat: applied when the fight ends
            diag.tall = "waits for the end of combat"
        end
        return
    end
    if not (NotProtected(cf) and NotProtected(m) and NotProtected(mh)) then diag.wide = "a frame is protected: Blizzard's width"; return end
    wide.mp = wide.mp or PointOf(m, "TOPLEFT")
    wide.hp = wide.hp or PointOf(mh, "BOTTOMLEFT")
    if not (wide.mp and wide.hp) then diag.wide = "the model or the main hand is anchored differently: Blizzard's width"; return end
    local px = c.widePx
    local half = math.floor(px / 2)
    local base = reset and w or wide.base
    local changed = reset or wide.px ~= px
    if changed then cf:SetWidth(base + px); SizeChanged() end
    cf.Inset:SetPoint("BOTTOMRIGHT", cf, "BOTTOMLEFT", DW + RO + px, BO)
    m:ClearAllPoints(); m:SetPoint(wide.mp[1], wide.mp[2], wide.mp[3], wide.mp[4] + half, wide.mp[5])
    mh:ClearAllPoints(); mh:SetPoint(wide.hp[1], wide.hp[2], wide.hp[3], wide.hp[4] + half, wide.hp[5])
    wide.applied, wide.moved, wide.base, wide.px, wide.setW = true, true, base, px, base + px
    if changed and type(UpdateUIPanelPositions) == "function" then
        if ns.MapTrace then ns.MapTrace("Character Reskin: UpdateUIPanelPositions(CharacterFrame) (wider window)") end
        pcall(UpdateUIPanelPositions, cf)
    end
    diag.wide = ("on, %d px wider (%d -> %d)"):format(px, math.floor(base + 0.5), math.floor(base + px + 0.5))
    ApplyTall(c, cf, m)
end

-- (V25 R2) after the wider window is applied or put back, Improved Character Display lays its slot blocks out again (the seam: "applied")
local function WideApplied()
    ApplyWide(Cfg())
    Tell("applied")
end
WideRegen = function()
    WaitForCombatEnd(false)
    local c = Cfg()
    if c and LookActive() and c.wide then Guard(WideApplied) else pcall(RestoreWide); Tell("applied") end
end
HookWide = function()
    if wide.hooked then return end
    wide.hooked = true
    local cf, pd = _G.CharacterFrame, _G.PaperDollFrame
    -- post-hooks; they return at once while the reskin or the wider window is off (a /reload removes them)
    if type(hooksecurefunc) == "function" and type(cf.UpdateSize) == "function" then
        hooksecurefunc(cf, "UpdateSize", function()
            if not LookActive() then return end
            if ns.MapTrace then ns.MapTrace("Character Reskin: hook after CharacterFrame:UpdateSize") end
            wide.reset = true
            SizeChanged()
            local c = Cfg()
            if c and c.wide then Guard(WideApplied) end
        end)
    end
    if type(pd) == "table" and pd.HookScript then
        pd:HookScript("OnShow", function() if not LookActive() then return end; local c = Cfg(); if c and c.wide then Guard(WideApplied) end end)
    end
end
function ns.CharReskin_WideOn() return (wide.applied or wide.moved) and true or false end
-- (QoL 0.7.33) XayaUI Dev Assist's /xui debug widthprobe asks this (it refuses while the wider window is on), through the service list
-- (QoL 0.7.53, character pane split stage 1) read-only answers for XayaUI Dev Assist's walkthrough (QAWalks-character-split.lua): what is
-- drawn on the character window now. (V25 R2) the item level, enchant, gem and stat list counts are Improved Character Display's: they
-- are read from its own "charDisplay" service (read only, for this diagnostic; zero when it is not loaded).
ns.Provide("characterReskin", { WideOn = function() return ns.CharReskin_WideOn() end,
    Drawn = function()
        local d = { ilvl = 0, enchants = 0, sockets = 0, statList = false, features = false }
        local icd = ns.Service and ns.Service("charDisplay")
        if icd and icd.Drawn then
            local ok, f = pcall(icd.Drawn)
            if ok and type(f) == "table" then for k, v in pairs(f) do d[k] = v end end
        end
        d.look, d.reskinLoaded, d.tabOn, d.faded = LookActive() == true, ns.SettingsReady("reskin"), ns.ReskinTabOn() == true, diag.faded or 0
        return d
    end })
-------------------------------------------------------------------------------
-- The stat list (Blizzard's CharacterStatsPane)
-------------------------------------------------------------------------------
local function StyleStats()
    local pane = _G.CharacterStatsPane
    if type(pane) ~= "table" then return end
    local label = TC("xui-label", "text", { 1, 0.82, 0, 1 })
    local muted = TC("xui-text-muted", "text", { 0.75, 0.75, 0.8, 1 })
    local text = TC("xui-text", "text", { 0.96, 0.96, 0.98, 1 })
    local line = TC("xui-window", "border", { 0.35, 0.35, 0.4, 1 })
    for _, k in ipairs({ "ItemLevelCategory", "AttributesCategory", "EnhancementsCategory" }) do
        local cat = pane[k]
        if type(cat) == "table" then
            Fade(cat.Background)
            Recolor(cat.Title, label)
            local x = XT(cat)
            if not x.rule and cat.CreateTexture then
                x.rule = Own(cat:CreateTexture(nil, "ARTWORK"))
                x.rule:SetPoint("BOTTOMLEFT", cat, "BOTTOMLEFT", 4, 2)
                x.rule:SetPoint("BOTTOMRIGHT", cat, "BOTTOMRIGHT", -4, 2)
                x.rule:SetHeight(1)
            end
            if x.rule then x.rule:SetColorTexture(line[1], line[2], line[3], 0.8); x.rule:Show() end
        end
    end
    if type(pane.ItemLevelFrame) == "table" then Fade(pane.ItemLevelFrame.Background) end
    local pool = pane.statsFramePool
    if type(pool) == "table" and type(pool.EnumerateActive) == "function" then
        for sf in pool:EnumerateActive() do
            if type(sf) == "table" then
                local stripe = sf.Background and sf.Background.IsShown and sf.Background:IsShown()
                Fade(sf.Background)
                local x = XT(sf)
                if not x.stripe and sf.CreateTexture then
                    x.stripe = Own(sf:CreateTexture(nil, "BACKGROUND"))
                    x.stripe:SetAllPoints(sf)
                end
                if x.stripe then x.stripe:SetColorTexture(1, 1, 1, 0.04); x.stripe:SetShown(stripe and true or false) end
                Recolor(sf.Label, muted)
                Recolor(sf.Value, text)
            end
        end
    end
end
-------------------------------------------------------------------------------
-- On / off
-------------------------------------------------------------------------------
local hooked = false
-- on = its own switch AND the Blizzard UI Reskin tab's switch (QoL 0.7.32, S1 #48: off there turns every reskin off)
-- (QoL 0.7.50; PS-57, #480) the switch takes effect on reload: this session runs with the value in effect (Modules.lua section 5c)
local function On(c) return c and ns.SwitchInEffect("reskin.charreskin", c.enabled) and ns.ReskinTabOn() and true or false end
-- (QoL 0.7.54; TRI-8, as Improved Chat does beside another chat skin: Chat Core.lua C.BlockedReason) another addon that skins the
-- character window (the two registered as conflicts at the end of this file): the look stays out of its way (Improved Character
-- Display still runs: it is not this file's).
-- Read once per session like Chat's (the other addon's own switch changes only with a reload); an answer that cannot be read yet (the
-- other addon's settings not set up) is not kept, and counts as that addon skinning the window (fail safe: nothing drawn over it).
local otherSkin
local function OtherSkin()
    if otherSkin ~= nil then return otherSkin end
    local A = C_AddOns
    local function loaded(n)
        if not (A and A.IsAddOnLoaded) then return false end
        local ok, l = pcall(A.IsAddOnLoaded, n)   -- namespaces.md: C_AddOns.IsAddOnLoaded(name) -> loadedOrLoading, loaded
        return ok and l and true or false
    end
    if loaded("EllesmereUIBlizzardSkin") then otherSkin = "EllesmereUIBlizzardSkin"; return otherSkin end
    if loaded("ElvUI") then
        -- INFERENCE (ElvUI's code not checked here): ElvUI keeps its Blizzard skin switches in E.private.skins.blizzard (enable, and
        -- character for this window). Only an explicit false there lets the reskin run.
        local ok, known, off = pcall(function()
            local E = _G.ElvUI and _G.ElvUI[1]
            local b = E and E.private and E.private.skins and E.private.skins.blizzard
            if type(b) ~= "table" then return false end
            return true, (b.enable == false or b.character == false)
        end)
        if not (ok and known) then return "ElvUI" end
        otherSkin = (not off) and "ElvUI" or false
        return otherSkin
    end
    otherSkin = false
    return otherSkin
end
ns.CharReskin_OtherSkin = function() return OtherSkin() or nil end
LookActive = function() local c = Cfg(); return On(c) and not OtherSkin() and not diag.failed end
-- (V27 gate G-021) the answer the two lasting redraw hooks below read: worked out once (ns.CharReskin_Apply, every settings page change
-- and the Reskin tab's switch go through it; a Guard error and a new settings epoch forget it) and then one upvalue read, so a slot or
-- stat redraw never runs Cfg()'s normalising loop. diag.lookReads counts the times it was worked out (Dev Assist's check). Settings not
-- open yet: nothing is kept. INFERENCE: nothing else changes the answer within a settings epoch: the look's switch and the Reskin tab's
-- take effect on /reload (ns.SwitchInEffect), and another skin addon is read once per session (OtherSkin; an ElvUI answer that cannot
-- be read yet counts as "skinned", the same fail-safe answer, until the next Apply).
local lookOn, lookOnC, lookOnEpoch = false, nil, nil
local function LookCached()
    if lookOnEpoch ~= nil and lookOnEpoch == ns.settingsEpoch then return lookOn, lookOnC end
    local c = Cfg()
    lookOn = (On(c) and not OtherSkin() and not diag.failed) and true or false
    lookOnC, lookOnEpoch = c, (c and ns.settingsEpoch or nil)
    diag.lookReads = (diag.lookReads or 0) + 1
    return lookOn, lookOnC
end
local function ForgetLook() lookOnEpoch = nil end
-- (V25 R2) the look is all this file draws: Active and LookActive are the same answer (both names stay for the tests and Dev Assist)
function ns.CharReskin_Active() return LookActive() == true end
function ns.CharReskin_LookActive() return LookActive() == true end

Guard = function(fn, ...)
    local ok, err = pcall(fn, ...)
    if ok then return true end
    diag.failed, diag.lastError = true, tostring(err)
    ForgetLook()
    RestoreAll(); SetOwnShown(false)
    pcall(RestoreWide)
    Tell("applied")
    if ns.Print then ns.Print("Character Reskin hit an error and is off until /reload: " .. tostring(err)) end
    return false
end

-- a theme change repaints the window; the listener is there only while the reskin is on (V14)
local function OnTheme() if LookActive() then Guard(function() ns.CharReskin_Apply() end) end end
local function SetThemeListener(on)
    local T = ns.Theme
    if not (T and T.OnResolve) then return end
    if on and not own.themeOn then T.OnResolve(OnTheme); own.themeOn = true
    elseif not on and own.themeOn and T.OffResolve then T.OffResolve(OnTheme); own.themeOn = false end
end

local function ApplyNow()
    local c = Cfg()
    if not c then return end
    if not LookActive() then
        RestoreAll(); SetOwnShown(false); diag.applied = false; SetThemeListener(false)
        RestoreWide()
        Tell("applied")
        return
    end
    -- a part switched off gives its pieces back: start from Blizzard's look, then apply the parts that are on
    RestoreAll(); SetOwnShown(false)
    PaintBackground(c)
    if c.chrome then StyleWindow(c) end
    ApplyWide(c)
    if c.stats then StyleStats() end
    SetThemeListener(true)
    diag.applied = true
    Tell("applied")
end

-- the hooks: placed the first time the look is on; each returns at once while it is off (a /reload removes them)
local function Hook()
    if hooked then return end
    hooked = true
    local cf = _G.CharacterFrame
    if type(cf) == "table" and cf.HookScript then cf:HookScript("OnShow", function() if LookActive() then Guard(ApplyNow) end end) end
    -- (QoL 0.7.51; #495, REQUEST-LOG PS-59) while the settings window is shown, a right-click on the Character window opens the element
    -- menu (core Modules.lua section 11) with "Element options" only (Blizzard Reskin > Character Reskin): it is Blizzard's own window,
    -- restyled, so its place is not XayaUI's to set (no X / Y; #495 proposal 4). A post-hook (blizzard = true: Blizzard's own handler
    -- always runs), put on at the first opening of the window out of combat, never on a protected frame. Registered only while the
    -- reskin is on (this function runs only then: V14).
    if ns.RegisterElement then
        ns.RegisterElement({ key = "characterPane", label = "Character window", blizzard = true, page = { "reskin", "charreskin" },
            targets = function(add) local cf2 = _G.CharacterFrame; if LookActive() and type(cf2) == "table" then add(cf2, "OnMouseUp") end end })
    end
    if type(hooksecurefunc) == "function" then
        -- Clean window: a slot Blizzard redraws keeps its frame art faded (V25 R2: before, the slot drawing did this). Window closed: it
        -- returns at once (equipment changes redraw the slots then too); the window's OnShow above fades every slot when it opens.
        if type(_G.PaperDollItemSlotButton_Update) == "function" then
            hooksecurefunc("PaperDollItemSlotButton_Update", function(btn)
                if not WindowShown() then return end   -- (G-021) the cheap test first: window closed, nothing else is read
                local on, c = LookCached()
                if on and c and c.chrome then Guard(FadeSlot, btn) end
            end)
        end
        if type(_G.PaperDollFrame_UpdateStats) == "function" then
            hooksecurefunc("PaperDollFrame_UpdateStats", function()
                if not WindowShown() then return end   -- (G-021) as above
                local on, c = LookCached()
                if on and c and c.stats then Guard(StyleStats) end
            end)
        end
        if type(_G.PanelTemplates_SetTab) == "function" then
            hooksecurefunc("PanelTemplates_SetTab", function(frame)
                if frame ~= _G.CharacterFrame or not LookActive() then return end
                local c = Cfg()
                if c and c.chrome then Guard(StyleTabs) end
            end)
        end
    end
end

function ns.CharReskin_Apply()
    ForgetLook()
    local c = Cfg()
    if not c then return end
    LookCached()   -- (G-021) the redraw hooks' answer, worked out once here
    if LookActive() then Hook() end
    if hooked then Guard(ApplyNow) end
end
-- (P5) once both halves of the settings are open: QoL's at this addon's load, Blizzard Reskin's at that addon's load (it loads after
-- this one); and at the login, when every addon that loads has loaded (XayaUI Blizzard Reskin not installed: the look in QoL's settings)
ns.WhenSettingsReady("qol", function()
    ns.WhenSettingsReady("reskin", function() if LookActive() then ns.CharReskin_Apply() end end)
    if ns.AtLogin then ns.AtLogin(function() if LookActive() then ns.CharReskin_Apply() end end) end
end)
ns.RegisterReskin("charreskin", function() ns.CharReskin_Apply() end)   -- (the Reskin tab's switch: core ns.SetReskinTab walks these)

-------------------------------------------------------------------------------
-- Settings page: Blizzard UI Reskin > Character Reskin (V25 R2: was titled Character Pane; Xaya A24 #5). The look only: the item level,
-- enchant, gem and stat list controls are on QoL > Improved Character Display.
-------------------------------------------------------------------------------
function ns.BuildCharReskinPage(Notify)
    local function C() return Cfg() or DEFAULTS end
    local function T(key, order, name, desc, width, disabled)
        return { type = "toggle", order = order, name = name, desc = desc, width = width, disabled = disabled,
            get = function() return C()[key] end, set = function(_, v) C()[key] = v and true or false; ns.CharReskin_Apply(); if Notify then Notify() end end }
    end
    local function R(key, order, name, desc, min, max, step, pct, disabled)
        return { type = "range", order = order, name = name, desc = desc, min = min, max = max, step = step, isPercent = pct, width = "full",
            disabled = disabled, get = function() return C()[key] end,
            set = function(_, v) local lim = LIMITS[key]; C()[key] = math.max(lim[1], math.min(lim[2], tonumber(v) or DEFAULTS[key])); ns.CharReskin_Apply(); if Notify then Notify() end end }
    end
    local function isOff() return not C().enabled end
    -- its on / off is the tick box on this page's row in the left pane (xuiSwitch; QoL 0.7.32, S1 #48: "individual toggles for
    -- individual reskins"), greyed while the Blizzard UI Reskin tab's own switch is off
    local switch = T("enabled", 1, "Character Reskin", "Turns the reskin on; takes effect after a reload. Off gives Blizzard's look and width back. Greyed while Blizzard Reskin is off (this tab's Overview).")
    switch.tip = "Restyles the character window: a clean border, theme colors and a wider window."
    switch.disabled = function() return not ns.ReskinTabOn() end
    -- (QoL 0.7.50; PS-57, #480) saves the choice and asks for a reload; before, ns.CharReskin_Apply ran at once
    switch.set = function(_, v)
        ns.SwitchSaveForReload("reskin.charreskin", C().enabled, function() C().enabled = v and true or false end, "Character Reskin")
        if Notify then Notify() end
    end
    return {
        type = "group", name = "Character Reskin", order = 4, childGroups = "tree", xuiSwitch = switch,
        args = {
            intro = { type = "description", order = 0, width = "full", fontSize = "medium",
                name = "Blizzard's character window in XayaUI's look: a solid background, a clean flat window, a wider window that gives the item details room beside the model, and a tidy stat list. The item level, enchant and gem details and the full stat list are in QoL > Improved Character Display. The window works as before, in and out of combat. Off by default." },
            chrome = T("chrome", 2, "Clean window", "Removes Blizzard's frame art for a thin border and theme colors. Off keeps Blizzard's art over the solid background.", "full", isOff),
            -- (SC-103) "Stat list colors", not "Stat list": Improved Character Display has a page named Stat list (XayaUI's own full list)
            stats = T("stats", 6, "Stat list colors", "Colors Blizzard's stat list with the theme and a faint stripe on every other row (not seen under Improved Character Display's full stat list).", "full", isOff),
            wide = T("wide", 7, "Wider window (room for the enchant names)", "Widens the Character tab so the enchant and gem lines sit between the slots and the model. Changes out of combat only.", "full", isOff),
            widePx = R("widePx", 8, "Extra width", "Sets how much wider than Blizzard's window, in pixels (default 42). Each side of the model gets half.", 0, 300, 1, false,
                function() return isOff() or not C().wide end),
            -- (QoL 0.7.31; Xaya: "character pane option should also allow for extra height"; her answer "either one": spread the slots)
            tallPx = R("tallPx", 8.5, "Extra height", "Sets how much taller than Blizzard's window, in pixels (default 0); the slots spread out to fill it. Changes out of combat only.", 0, 300, 1, false,
                function() return isOff() or not C().wide end),
            bgAlpha = R("bgAlpha", 9, "Background opacity", "How solid the window's background is (50% to 100%).", 0.5, 1, 0.05, true, isOff),
        },
    }
end
-- module "reskin": the page is the Blizzard UI Reskin tab's Character Reskin (Xaya 2026-11-05: "Take all reskins and put them into a new
-- tab: Blizzard UI Reskin. Currently applies to: chat, character pane, Esc menu")
ns.RegisterSettingsPage("reskin", "charreskin", ns.BuildCharReskinPage)
-- (QoL 0.7.50; PS-56, #469) other addons that change the character window (Modules.lua section 5d): a flag only, nothing changes here.
-- ElvUI: folder "ElvUI" (https://github.com/tukui-org/ElvUI : ElvUI/ElvUI.toc; Shared\Skins\Character.lua in ElvUI/Game/load_mainline.xml).
-- EllesmereUI: folder "EllesmereUIBlizzardSkin" (https://github.com/EllesmereGaming/EllesmereUI : EllesmereUIBlizzardSkin.toc,
-- EllesmereUIBlizzardSkin_CharacterSheet.lua). (all read 2026-11-08)
if ns.RegisterConflict then
    ns.RegisterConflict({ part = "charreskin", label = "Character Reskin", addons = { "ElvUI", "EllesmereUIBlizzardSkin" }, what = "the character window",
        on = function() return ns.CharReskin_LookActive() end })
end
-- (QoL 0.7.46; docs/plans/PLATFORM-SPLIT-2026-11-07.md section 6.6) theme scope of the character window (page Character Reskin), under the Blizzard Reskin tab's scope (core Theme.lua).
-- (QoL 0.7.52, #472) the window paints with it (TC above); page = where its "Theme" row goes. (Improved Character Display's colors use it too.)
local TS = ns.Theme and ns.Theme.RegisterScope
if TS then
    TS({ id = SCOPE, label = "Character Reskin", parent = "reskin", page = "charreskin" })
end

-- /xui reskin: on / off / options, and status for the look. (V25 R2) Improved Character Display adds its own status lines to this
-- command (ns.RegisterCommand keeps every handler of a name; ImprovedCharacterDisplay.lua).
ns.RegisterCommand("reskin", function(arg)
    arg = tostring(arg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local c = Cfg()
    if not c then return end
    if arg == "on" and not ns.SettingsReady("reskin") and not ReskinMissing() then   -- (P5) the switch is Blizzard Reskin's setting (QoL's own without that addon: 0.7.54)
        ns.Print(("/xui reskin on: the Character Reskin's look is kept by %s, which is switched off. Turn it on in the game's AddOns list, then /reload."):format(ns.AddonTitle and ns.AddonTitle("XayaUI_Reskin") or "XayaUI Blizzard Reskin"))
        return
    end
    -- (QoL 0.7.50; PS-57) on / off go the way of the settings switch: saved, the reload question, in effect after the /reload (5c)
    if arg == "on" or arg == "off" then
        local on = arg == "on"
        local line = ns.SwitchCommand("reskin.charreskin", c.enabled, function() c.enabled = on end, "Character Reskin", on)
        ns.Print(line .. ((on and not ns.ReskinTabSaved()) and " It shows once Blizzard Reskin is on again (Blizzard Reskin > Overview, then /reload)." or ""))
        return
    end
    if arg == "status" or arg == "" then
        ns.Print(("Character Reskin: %s%s%s; %d Blizzard regions faded%s."):format(c.enabled and "on" or "off",
            ns.ReskinTabOn() and "" or " (Blizzard Reskin is off: Blizzard Reskin > Overview, so it does not show)",
            diag.failed and " (stopped after an error)" or "", diag.faded, diag.lastError and (", last error: " .. diag.lastError) or ""))
        ns.Print(("Wider window: %s."):format(c.wide and tostring(diag.wide) or "switched off"))
        ns.Print(("Extra height: %s."):format((c.wide and c.tallPx > 0) and tostring(diag.tall or "waits for the window") or "off"))
        return
    end
    if arg == "options" or arg == "settings" then ns.OpenSettingsPage("reskin", "charreskin"); return end
end, "/xui reskin [on|off|status|options] (QoL Character Reskin)")
