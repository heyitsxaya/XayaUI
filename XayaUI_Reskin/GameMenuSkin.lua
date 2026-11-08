-------------------------------------------------------------------------------
-- GameMenuSkin.lua : XayaUI's own look for the Game Menu (ESC menu). Own code, Blizzard's GameMenuFrame only (no other addon's code).
--
-- Why a replacement and not a restyle: Blizzard recycles the menu's buttons from a pool and other UI addons restyle those
-- pooled buttons too, so two skins fight over the same buttons (0.5.37-0.5.40 showed that). This file never writes to a pooled button.
--   * GameMenuFrame stays the real menu: it builds its entries, owns ESC, and runs every entry's action. We only fade it out (frame alpha).
--   * Our own frame (child of UIParent, never pooled) is drawn over it, one row per Blizzard entry, with the entry's own text and state.
-- Two modes (Blizzard UI Reskin > Esc Menu, "Match Blizzard's button positions", on by default since 0.5.106):
--   * MATCH (default): every row is anchored to its real Blizzard button, so it sits exactly where that button is, and the rows take no
--     mouse: a click lands on the real button under the pointer and runs its own action. No lookup, so no way to run another action.
--     Hover / pressed looks are read from the real button (polled). The XayaUI row is the real slot GameMenu.lua adds to the menu.
--   * OWN LAYOUT (old behavior): our own sizes and spacing; a click finds the real button by its text and calls :Click(). If it cannot
--     be found with the same text, NOTHING is clicked (and /xui debug gamemenu says why) instead of running some other entry.
-- Safety: default OFF. Any error while building turns the skin off for the session and gives Blizzard's menu back (alpha 1).
-- Group gaps (Options / Shop | addons | ... | Log Out / Exit | Return) are read from where Blizzard laid its entries out.
-- UNTESTED in game: the first check is /xui debug gamemenu (it lists what the menu exposes).
-------------------------------------------------------------------------------
local addonName, ns = ...
ns = _G.XayaUI_NS or ns
-- (P5) this addon keeps its settings in its own saved variable (its .toc); the Platform opens it at this addon's ADDON_LOADED
if ns and ns.SettingsDeclareStore then ns.SettingsDeclareStore("reskin", "XayaUI_Reskin", "XayaUIReskinDB") end
local ReskinS = ns.Settings("reskin")   -- (Reskin 0.6.21, P2 settings seam; P5: Reskin's own XayaUIReskinDB; Modules.lua section 0b)

local LABEL = "XayaUI"
local diag = { built = 0, rows = 0, groups = 0, lastError = nil, failed = false, titleFound = false }
ns.GameMenuSkinDiag = diag

local DEFAULTS = {
    skin = false,                 -- master switch (off until chosen)
    matchReal = true,             -- draw on the real buttons' own positions (clicks go to the real buttons); false = our own layout
    w = 240, h = 34, gap = 6, groupGap = 18, pad = 18, scale = 100,
    font = "none", fontSize = 15, outline = "",
    textR = 1, textG = 1, textB = 1, textA = 100,   -- alpha in percent
    hoverAccent = true,           -- hover / pressed colors follow the theme accent (class color)
    bgR = 0.04, bgG = 0.04, bgB = 0.04, bgA = 90,       -- panel fill, percent
    btnA = 70,                    -- row fill opacity, percent
    border = true,
    title = true, titleSize = 14,
    xuiRow = "AFTER_MACROS",      -- AFTER_MACROS | TOP | BOTTOM | HIDE
    xuiStyle = "gradient",        -- gradient | standard (the XayaUI row only)
    hide = {},                    -- [Blizzard entry text] = true : leave that entry out of OUR menu (it still exists in Blizzard's)
    -- colors: off = follow the theme / class color (as before); on = the colors below. The defaults equal the built-in look.
    useColors = false,
    pbR = 0.25, pbG = 0.25, pbB = 0.25,       -- panel border
    btnR = 0.07, btnG = 0.07, btnB = 0.07,    -- button fill
    bbR = 0.25, bbG = 0.25, bbB = 0.25,       -- button border
    accR = 0.75, accG = 0.25, accB = 1,       -- accent: hover border, glow, XayaUI row
    ttR = 0.75, ttG = 0.25, ttB = 1,          -- title
}
ns.GameMenuSkinDefaults = DEFAULTS

local function Cfg()
    local gm = ReskinS.gm   -- (XayaUIReskinDB.gm; CueRulesDB.ui.gm before P5: Modules.lua section 0b)
    if type(gm) ~= "table" then gm = {}; ReskinS.gm = gm end
    for k, v in pairs(DEFAULTS) do
        if gm[k] == nil then gm[k] = (type(v) == "table") and {} or v end
    end
    return gm
end
ns.GameMenuSkin_Cfg = Cfg

-- The saved switch, read without filling in the defaults (Cfg does that): V14, a look that is off builds no data either.
local function Saved() local gm = ReskinS.gm; return type(gm) == "table" and gm or nil end
-- (and the Blizzard UI Reskin tab's own switch: off there turns this look off too; Reskin 0.6.4, S1 #48)
local function SavedOn() local gm = Saved(); return gm and gm.skin and ns.ReskinTabOn() and true or false end
function ns.GameMenuSkin_Active() return SavedOn() and not diag.failed end
function ns.GameMenuSkin_MatchReal() local gm = Saved(); return not (gm and gm.matchReal == false) end
ns.Provide("gameMenuSkin", { Active = function() return ns.GameMenuSkin_Active() end, MatchReal = function() return ns.GameMenuSkin_MatchReal() end })

-- colors -------------------------------------------------------------------------------------------------------------------------
local function Accent()
    local cfg = Cfg()
    if cfg.useColors then return { cfg.accR, cfg.accG, cfg.accB } end
    local c = ns.Theme and ns.Theme.cur and ns.Theme.cur.accent
    if c then return { c[1], c[2], c[3] } end
    local ok, _, file = pcall(UnitClass, "player")
    local rc = ok and file and RAID_CLASS_COLORS and RAID_CLASS_COLORS[file]
    if rc then return { rc.r, rc.g, rc.b } end
    return { 0.75, 0.25, 1 }
end
local function Border()
    local T = ns.Theme
    local c = T and T.Col and T.Col("xui-button", "border", { 0.25, 0.25, 0.25, 1 })
    return c or { 0.25, 0.25, 0.25, 1 }
end

-- panel border / button border / button fill / title / panel fill: the user's colors when "Use my own colors" is on, else the old look
local function Pal()
    local c = Cfg()
    if c.useColors then
        return { panelBorder = { c.pbR, c.pbG, c.pbB, 1 }, btnBorder = { c.bbR, c.bbG, c.bbB, 1 }, btn = { c.btnR, c.btnG, c.btnB },
                 title = { c.ttR, c.ttG, c.ttB }, bg = { c.bgR, c.bgG, c.bgB } }
    end
    local b = Border()
    local ac = Accent()
    return { panelBorder = b, btnBorder = b, btn = { 0.07, 0.07, 0.07 }, title = ac, bg = { DEFAULTS.bgR, DEFAULTS.bgG, DEFAULTS.bgB } }
end

-- our frame and rows -------------------------------------------------------------------------------------------------------------
local panel, rows, title = nil, {}, nil
local faded = false   -- this file set Blizzard's menu to alpha 0 (and has not given it back yet)
local live = false    -- "Use the XayaUI Game Menu look", cached (V14; set by Enable / Disable below)

local function Edges(f)
    f.e = {}
    for i = 1, 4 do f.e[i] = f:CreateTexture(nil, "BORDER") end
    f.e[1]:SetPoint("TOPLEFT"); f.e[1]:SetPoint("TOPRIGHT"); f.e[1]:SetHeight(1)
    f.e[2]:SetPoint("BOTTOMLEFT"); f.e[2]:SetPoint("BOTTOMRIGHT"); f.e[2]:SetHeight(1)
    f.e[3]:SetPoint("TOPLEFT"); f.e[3]:SetPoint("BOTTOMLEFT"); f.e[3]:SetWidth(1)
    f.e[4]:SetPoint("TOPRIGHT"); f.e[4]:SetPoint("BOTTOMRIGHT"); f.e[4]:SetWidth(1)
end

local function Panel()
    if panel then return panel end
    local f = CreateFrame("Frame", "XayaUI_GameMenuPanel", UIParent)
    f:SetFrameStrata("DIALOG"); f:EnableMouse(true)       -- swallow clicks on the panel so nothing behind it is hit
    f.cover = CreateFrame("Frame", nil, f); f.cover:EnableMouse(true)   -- sits over Blizzard's whole menu: its invisible buttons can never be hit
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints(f)
    Edges(f)
    f.title = f:CreateFontString(nil, "OVERLAY")
    f:Hide()
    panel = f
    return f
end

local function FontFile(c) return (ns.FontPath and ns.FontPath(c.font)) or STANDARD_TEXT_FONT end

local function PaintRow(r)
    local c = Cfg()
    local ac = Accent()
    local pal = Pal()
    local bd = pal.btnBorder
    local isXui = r.isXui
    local hov, prs = r.hover, r.pressed
    local a = (c.btnA or 70) / 100
    local bc = pal.btn
    local fill = { bc[1], bc[2], bc[3], a }
    if r.disabled then fill = { bc[1], bc[2], bc[3], a * 0.6 } end
    if isXui and c.xuiStyle ~= "standard" then
        local k = prs and 0.70 or (hov and 0.62 or 0.48)
        r.bg:SetColorTexture(1, 1, 1, 1)
        local ok = pcall(function()
            r.bg:SetGradient("HORIZONTAL", CreateColor(ac[1] * k, ac[2] * k, ac[3] * k, 0.95), CreateColor(fill[1], fill[2], fill[3], fill[4]))
        end)
        if not ok then r.bg:SetColorTexture(ac[1] * k, ac[2] * k, ac[3] * k, 0.95) end
    else
        local lift = prs and 0.10 or (hov and 0.05 or 0)
        r.bg:SetColorTexture(fill[1] + lift, fill[2] + lift, fill[3] + lift, math.max(fill[4], prs and 0.9 or 0))
    end
    local e = (hov and c.hoverAccent) and ac or bd
    for i = 1, 4 do r.e[i]:SetColorTexture(e[1], e[2], e[3], e[4] or 1) end
    r.glow:SetColorTexture(ac[1], ac[2], ac[3], 1); r.glow:SetAlpha((hov and c.hoverAccent and not r.disabled) and 0.22 or 0)
    r.fs:SetFont(FontFile(c), c.fontSize or 15, c.outline or "")
    if r.disabled then r.fs:SetTextColor(0.5, 0.5, 0.5, 1)
    elseif isXui and c.xuiStyle == "standard" then r.fs:SetTextColor(ac[1], ac[2], ac[3], 1)
    else r.fs:SetTextColor(c.textR or 1, c.textG or 1, c.textB or 1, (tonumber(c.textA) or 100) / 100) end
    r.fs:SetText(r.label or "")
end

-- Which real Blizzard button does a drawn row stand for? Looked up by its label (and layout index) at CLICK time, because the menu
-- recycles its buttons from a pool and a button remembered from build time can be a different entry by then (shifted-down mapping).
local function ResolveSource(r)
    local menu = GameMenuFrame
    local match
    if menu and menu.buttonPool and menu.buttonPool.EnumerateActive and r.label then
        for b in menu.buttonPool:EnumerateActive() do
            if not b.xuiGMslot then
                local ok, t = pcall(b.GetText, b)
                if ok and t == r.label then
                    if r.srcIdx and b.layoutIndex == r.srcIdx then return b end
                    match = match or b
                end
            end
        end
    end
    if match then return match end
    -- the remembered button only counts if it still says the same thing (the pool recycles buttons: it may now be another entry)
    if r.src and r.label then
        local ok, t = pcall(r.src.GetText, r.src)
        if ok and t == r.label then return r.src end
    end
    return nil
end

local function GetRow(i)
    local r = rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, Panel())
    r:RegisterForClicks("LeftButtonUp")
    r.bg = r:CreateTexture(nil, "BACKGROUND", nil, -3); r.bg:SetAllPoints(r)
    Edges(r)
    r.glow = r:CreateTexture(nil, "ARTWORK"); r.glow:SetPoint("TOPLEFT", 1, -1); r.glow:SetPoint("BOTTOMRIGHT", -1, 1); r.glow:SetBlendMode("ADD")
    r.fs = r:CreateFontString(nil, "OVERLAY"); r.fs:SetPoint("CENTER")
    r:SetScript("OnEnter", function(self) self.hover = true; PaintRow(self) end)
    r:SetScript("OnLeave", function(self) self.hover, self.pressed = false, false; PaintRow(self) end)
    r:SetScript("OnMouseDown", function(self) self.pressed = true; PaintRow(self) end)
    r:SetScript("OnMouseUp", function(self) self.pressed = false; PaintRow(self) end)
    r:SetScript("OnClick", function(self)
        if self.disabled then return end
        if self.isXui then
            pcall(PlaySound, SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION or 852)
            if GameMenuFrame and GameMenuFrame:IsShown() then pcall(HideUIPanel, GameMenuFrame) end
            if ns.ToggleUI then ns.ToggleUI() end
        else
            local src = ResolveSource(self)
            if not src then
                diag.lastError = "no real button with the text '" .. tostring(self.label) .. "' - nothing was clicked"
                if ns.Print then ns.Print("Game Menu skin: could not find the real '" .. tostring(self.label) .. "' button, so nothing was clicked. Turn on 'Match Blizzard's button positions' (XayaUI settings: Blizzard Reskin > Esc Menu).") end
                return
            end
            local okE, en = pcall(src.IsEnabled, src)
            if okE and en == false then return end
            local ok, err = pcall(src.Click, src)         -- Blizzard's own action, unchanged
            if not ok then diag.lastError = tostring(err) end
        end
    end)
    rows[i] = r
    return r
end

-- reading Blizzard's entries (read only) -----------------------------------------------------------------------------------------
local function ReadEntries(menu)
    local list = {}
    if not (menu.buttonPool and menu.buttonPool.EnumerateActive) then return list end
    for b in menu.buttonPool:EnumerateActive() do
        local okT, text = pcall(b.GetText, b)
        if okT and type(text) == "string" and text ~= "" and not b.xuiGMslot then
            local okTop, top = pcall(b.GetTop, b)
            local okH, h = pcall(b.GetHeight, b)
            local okE, en = pcall(b.IsEnabled, b)
            list[#list + 1] = { src = b, text = text, idx = b.layoutIndex or 0, top = okTop and top or nil,
                h = okH and h or nil, enabled = (okE and en ~= false) }
        end
    end
    table.sort(list, function(a, b)
        if a.top and b.top and a.top ~= b.top then return a.top > b.top end   -- on-screen order first
        return a.idx < b.idx
    end)
    return list
end

-- a group break where Blizzard left a gap clearly larger than its smallest (normal) spacing between neighbours
local function MarkGroups(list)
    local gaps = {}
    for i = 2, #list do
        local p, c = list[i - 1], list[i]
        if p.top and c.top and p.h then gaps[#gaps + 1] = (p.top - p.h) - c.top end
    end
    if #gaps == 0 then return end
    local sorted = {}; for i, v in ipairs(gaps) do sorted[i] = v end; table.sort(sorted)
    local normal = sorted[1]   -- Blizzard's usual spacing between neighbours = the smallest gap seen
    for i = 2, #list do
        local g = gaps[i - 1]
        if g and g > normal + 6 then list[i].groupBreak = true end
    end
end

local function Place(label, xuiRow, list)
    local out = {}
    local macros = MACROS
    local inserted = false
    local function addXui(groupBreak) out[#out + 1] = { isXui = true, text = LABEL, enabled = true, groupBreak = groupBreak }; inserted = true end
    if xuiRow == "TOP" then addXui(true) end
    for _, e in ipairs(list) do
        if not Cfg().hide[e.text] then out[#out + 1] = e end
        if xuiRow == "AFTER_MACROS" and not inserted and macros and e.text == macros then addXui(false) end
    end
    if xuiRow == "AFTER_MACROS" and not inserted then addXui(true) end   -- no Macros entry found: put it at the end of the list
    if xuiRow == "BOTTOM" then addXui(true) end
    return out
end

local function TitleText(menu)
    local t
    pcall(function() t = menu.Header and menu.Header.Text and menu.Header.Text:GetText() end)
    if t and t ~= "" then diag.titleFound = true; return t end
    return "Game Menu"
end

-- MATCH mode ---------------------------------------------------------------------------------------------------------------------
-- Every entry the menu really shows, read only: the pooled Blizzard buttons, our own XayaUI slot (GameMenu.lua), and buttons other
-- addons added to the menu frame as plain children (they have text and are shown). Each gets a drawn row anchored to it.
local function ReadEntriesMatch(menu)
    local list, seen = {}, {}
    local function add(b, isXui)
        if seen[b] then return end
        local okS, shown = pcall(b.IsShown, b)
        if okS and shown == false then return end
        local okT, text = pcall(b.GetText, b)
        if not (okT and type(text) == "string" and text ~= "") then return end
        seen[b] = true
        local okE, en = pcall(b.IsEnabled, b)
        list[#list + 1] = { src = b, text = text, enabled = not (okE and en == false), isXui = isXui and true or false }
    end
    if menu.buttonPool and menu.buttonPool.EnumerateActive then
        for b in menu.buttonPool:EnumerateActive() do add(b, b.xuiGMslot) end
    end
    local okC, kids = pcall(function() return { menu:GetChildren() } end)
    if okC and type(kids) == "table" then
        for _, ch in ipairs(kids) do
            local okN, nm = pcall(ch.GetName, ch)
            local okO, ot = pcall(ch.GetObjectType, ch)
            if ch ~= panel and not (okN and type(nm) == "string" and nm:find("^XayaUI_")) and okO and ot == "Button" then add(ch, false) end
        end
    end
    return list
end

-- Hover and pressed looks come from the real buttons (our rows take no mouse), polled while the menu is up.
local function PollRows(self, dt)
    self.acc = (self.acc or 0) + dt
    if self.acc < 0.03 then return end
    self.acc = 0
    local down = IsMouseButtonDown and IsMouseButtonDown("LeftButton")
    for i = 1, (self.nRows or 0) do
        local r = rows[i]
        local src = r and r.matchSrc
        if src then
            local ok, over = pcall(src.IsMouseOver, src)
            over = (ok and over) and not r.disabled
            local pr = over and down and true or false
            if over ~= (r.hover and true or false) or pr ~= (r.pressed and true or false) then
                r.hover, r.pressed = over, pr
                PaintRow(r)
            end
        end
    end
end

local function BuildMatch(menu, c)
    local list = ReadEntriesMatch(menu)
    if #list == 0 then diag.lastError = "no menu entries found"; if panel then panel:Hide() end; menu:SetAlpha(1); faded = false; return end
    local p = Panel()
    p:SetScale(1)
    p:EnableMouse(false); p.cover:EnableMouse(false); p.cover:Hide()       -- nothing of ours takes a click: the real buttons do
    p:SetFrameStrata((menu.GetFrameStrata and menu:GetFrameStrata()) or "DIALOG")
    p:SetFrameLevel((menu:GetFrameLevel() or 1) + 200)
    local pal = Pal()
    p.bg:SetColorTexture(pal.bg[1], pal.bg[2], pal.bg[3], (c.bgA or 90) / 100)
    local bd = pal.panelBorder
    for i = 1, 4 do p.e[i]:SetColorTexture(bd[1], bd[2], bd[3], c.border and 1 or 0) end
    p:ClearAllPoints()
    p:SetPoint("TOPLEFT", menu, "TOPLEFT"); p:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT")     -- exactly Blizzard's menu rectangle
    if c.title then
        p.title:SetFont(FontFile(c), c.titleSize or 14, c.outline or "")
        p.title:SetTextColor(pal.title[1], pal.title[2], pal.title[3], 1)
        p.title:SetText(TitleText(menu)); p.title:ClearAllPoints()
        local hdr = menu.Header
        if hdr then p.title:SetPoint("CENTER", hdr, "CENTER", 0, 0) else p.title:SetPoint("TOP", p, "TOP", 0, -8) end
        p.title:Show()
    else
        p.title:Hide()
    end
    local used = 0
    for i, e in ipairs(list) do
        local r = GetRow(i)
        r.src, r.srcIdx, r.isXui, r.label, r.disabled, r.matchSrc = e.src, nil, e.isXui, e.text, not e.enabled, e.src
        r.hover, r.pressed = false, false
        r:EnableMouse(false)
        r:SetFrameLevel(p:GetFrameLevel() + 5)
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", e.src, "TOPLEFT"); r:SetPoint("BOTTOMRIGHT", e.src, "BOTTOMRIGHT")     -- on the real button, wherever it is
        r:Show(); PaintRow(r); used = i
    end
    for i = used + 1, #rows do rows[i]:Hide(); rows[i].matchSrc = nil end
    p.nRows = used
    p:SetScript("OnUpdate", PollRows)
    menu:SetAlpha(0); faded = true
    p:Show()
    diag.built, diag.rows = diag.built + 1, used
end

local function Build()
    local menu = GameMenuFrame
    if not menu then return end
    local c = Cfg()
    if not ns.GameMenuSkin_Active() then
        if panel then panel:Hide() end
        if faded and menu.SetAlpha then menu:SetAlpha(1) end   -- (only if this file had faded it; core 0.6.47 / Reskin 0.6.2, V14)
        faded = false
        return
    end
    if c.matchReal ~= false then return BuildMatch(menu, c) end
    local list = ReadEntries(menu)
    if #list == 0 then diag.lastError = "no menu entries found"; if panel then panel:Hide() end; menu:SetAlpha(1); faded = false; return end
    MarkGroups(list)
    local entries = Place(LABEL, c.xuiRow, list)
    local p = Panel()
    p:SetScript("OnUpdate", nil)
    p:EnableMouse(true); p.cover:EnableMouse(true); p.cover:Show()
    p:SetScale((c.scale or 100) / 100)
    p:SetFrameStrata((menu.GetFrameStrata and menu:GetFrameStrata()) or "DIALOG")   -- same strata as Blizzard's menu, far above its buttons
    p:SetFrameLevel((menu:GetFrameLevel() or 1) + 200)
    p.cover:ClearAllPoints(); p.cover:SetPoint("TOPLEFT", menu, "TOPLEFT"); p.cover:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT")
    p.cover:SetFrameLevel(p:GetFrameLevel() + 1)
    local pal = Pal()
    p.bg:SetColorTexture(pal.bg[1], pal.bg[2], pal.bg[3], (c.bgA or 90) / 100)
    local bd = pal.panelBorder
    for i = 1, 4 do p.e[i]:SetColorTexture(bd[1], bd[2], bd[3], c.border and 1 or 0) end
    local y = c.pad
    if c.title then
        p.title:SetFont(FontFile(c), c.titleSize or 14, c.outline or "")
        p.title:SetTextColor(pal.title[1], pal.title[2], pal.title[3], 1)
        p.title:SetText(TitleText(menu)); p.title:ClearAllPoints(); p.title:SetPoint("TOP", p, "TOP", 0, -c.pad)
        p.title:Show()
        y = y + (c.titleSize or 14) + c.groupGap * 0.6
    else
        p.title:Hide()
    end
    local used = 0
    for i, e in ipairs(entries) do
        local r = GetRow(i)
        r.src, r.srcIdx, r.isXui, r.label, r.disabled, r.matchSrc = e.src, e.idx, e.isXui, e.text, not e.enabled, nil
        r:EnableMouse(true)
        r:SetFrameLevel(p:GetFrameLevel() + 5)
        r:SetSize(c.w, c.h)
        if i > 1 then y = y + (e.groupBreak and c.groupGap or c.gap) end
        r:ClearAllPoints(); r:SetPoint("TOP", p, "TOP", 0, -y)
        y = y + c.h
        r:Show(); PaintRow(r); used = i
    end
    for i = used + 1, #rows do rows[i]:Hide() end
    p:SetSize(c.w + c.pad * 2, y + c.pad)
    p:ClearAllPoints(); p:SetPoint("CENTER", menu, "CENTER", 0, 0)
    menu:SetAlpha(0); faded = true
    p:Show()
    diag.built, diag.rows = diag.built + 1, used
end

local function SafeBuild()
    local ok, err = pcall(Build)
    if not ok then
        diag.failed, diag.lastError = true, tostring(err)
        if panel then panel:Hide() end
        if GameMenuFrame and GameMenuFrame.SetAlpha then GameMenuFrame:SetAlpha(1) end    -- give Blizzard's menu back
        faded = false
        if ns.CaptureError then ns.CaptureError(err, nil, "XUI-E014") end
    end
end
function ns.GameMenuSkin_Refresh() if live and GameMenuFrame and GameMenuFrame:IsShown() then SafeBuild() end end

-- V14 (Reskin 0.6.2; Xaya 2026-11-05: "anything that is disabled in the addon through a tick box should NEVER LOAD or contribute to
-- performance cost / demand in any way"). `live` is "Use the XayaUI Game Menu look", cached. Saved off: no frame, no event, no hook, no
-- saved defaults. Saved on: the hooks are placed at PLAYER_LOGIN (as before); ticked later: at once. Unticked: the panel is hidden,
-- Blizzard's menu gets its alpha back if this file had faded it, and the hooks (the game cannot take them back) return at once.
local hooked = false
local function Hook()
    if hooked or not GameMenuFrame then return end
    hooked = true
    local function later()
        if not live then return end
        SafeBuild(); if C_Timer then C_Timer.After(0, SafeBuild) end   -- again next frame: layout may settle after us
    end
    if type(GameMenuFrame.InitButtons) == "function" then hooksecurefunc(GameMenuFrame, "InitButtons", later) end
    GameMenuFrame:HookScript("OnShow", later)
    GameMenuFrame:HookScript("OnHide", function() if live and panel then panel:Hide() end end)
end
local function Enable()
    live = true
    if hooked then return end
    if ns.AtLogin then ns.AtLogin(function() if live then Hook() end end)   -- (core Modules.lua: at PLAYER_LOGIN, or at once after it)
    else Hook() end
end
local function Disable()
    live = false
    if panel then panel:SetScript("OnUpdate", nil); panel:Hide() end
    if faded and GameMenuFrame and GameMenuFrame.SetAlpha then GameMenuFrame:SetAlpha(1) end   -- only if this file had faded it
    faded = false
end
-- the switch (and every other setting on the page) calls this through re() below
local function Apply() if SavedOn() then Enable() elseif live then Disable() end end
ns.RegisterReskin("gamemenu", Apply)                            -- (the Reskin tab's switch: core ns.SetReskinTab walks these)
ns.GameMenuSkin_Hook = function() live = true; Hook() end   -- (tests: place the hooks and let them work, as ticking the switch does)
function ns.GameMenuSkin_Live() return live end              -- (tests)
-- at login: once this addon's own settings are open (P5: XayaUIReskinDB, at this addon's ADDON_LOADED; Modules.lua section 0c)
ns.WhenSettingsReady("reskin", function() if SavedOn() then Enable() end end)

-- /xui debug gamemenu (the skin's half) moved to XayaUI Dev Assist (Reskin 0.6.5; REQUEST-LOG #81, XayaUI_DevAssist/CoreDebug.lua): it
-- reads this
ns.Provide("gameMenuSkinDiag", { State = function() return Cfg(), diag, rows, ResolveSource end })

-- Blizzard UI Reskin > Esc Menu (the Game Menu look) ----------------------------------------------------------------------------------------------------------
function ns.GameMenuSkin_Options(Notify)
    local function re() diag.failed = false; Apply(); ns.GameMenuSkin_Refresh(); if Notify then Notify() end end
    local function g(k) return function() return Cfg()[k] end end
    local function s(k) return function(_, v) Cfg()[k] = v; re() end end
    local off = function() return not Cfg().skin end
    local ownOnly = function() return not Cfg().skin or Cfg().matchReal ~= false end   -- settings that only mean something in own-layout mode
    local function rng(name, k, order, lo, hi, desc, dis) return { type = "range", name = name, order = order, min = lo, max = hi, step = 1, desc = desc, get = g(k), set = s(k), disabled = dis or off } end
    local function ColorOpt(name, order, kr, kg, kb, desc)
        return { type = "color", order = order, name = name, desc = desc, hasAlpha = false,
            disabled = function() return off() or not Cfg().useColors end,
            get = function() local c = Cfg(); return c[kr], c[kg], c[kb] end,
            set = function(_, r, gg, b) local c = Cfg(); c[kr], c[kg], c[kb] = r, gg, b; re() end }
    end
    local args = {
        note = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "XayaUI's own look for the ESC menu. It draws its own look over Blizzard's menu and never edits the buttons other UI addons restyle. If something goes wrong the skin turns itself off and Blizzard's menu comes back. Off by default." },
        match = { type = "toggle", order = 2, width = "full", name = "Match Blizzard's button positions (recommended)", disabled = off,
            desc = "Draws the look over Blizzard's own buttons, so a click always hits the real button. Size, spacing and layout settings apply only when this is off; changes show the next time the menu opens.",
            get = function() return Cfg().matchReal ~= false end, set = s("matchReal") },
        look = { type = "group", order = 10, inline = true, name = "Look", args = {
            w = rng("Button width", "w", 1, 120, 480, nil, ownOnly), h = rng("Button height", "h", 2, 20, 70, nil, ownOnly),
            gap = rng("Space between buttons", "gap", 3, 0, 30, nil, ownOnly), groupGap = rng("Space between groups", "groupGap", 4, 0, 60, nil, ownOnly),
            pad = rng("Panel padding", "pad", 5, 4, 60, nil, ownOnly), scale = rng("Scale (%)", "scale", 6, 50, 200, nil, ownOnly),
            bgA = rng("Panel opacity (%)", "bgA", 7, 0, 100), btnA = rng("Button opacity (%)", "btnA", 8, 0, 100),
            border = { type = "toggle", order = 9, name = "Panel border", get = g("border"), set = s("border"), disabled = off },
            hoverAccent = { type = "toggle", order = 10, name = "Hover uses the theme accent", get = g("hoverAccent"), set = s("hoverAccent"), disabled = off },
            title = { type = "toggle", order = 11, name = "Show the title", get = g("title"), set = s("title"), disabled = off },
            titleSize = rng("Title size", "titleSize", 12, 8, 30),
        } },
        colors = { type = "group", order = 15, inline = true, name = "Colors", args = {
            use = { type = "toggle", order = 1, width = "full", name = "Use my own colors (off: follow the theme and class color)", disabled = off,
                desc = "Uses the colors below. Off follows the addon theme or your class color.",
                get = g("useColors"), set = s("useColors") },
            panel = ColorOpt("Panel fill", 2, "bgR", "bgG", "bgB", "The panel's background color. Its opacity is the Panel opacity slider above."),
            panelBd = ColorOpt("Panel border", 3, "pbR", "pbG", "pbB"),
            btn = ColorOpt("Button fill", 4, "btnR", "btnG", "btnB", "The button background color. Its opacity is the Button opacity slider above."),
            btnBd = ColorOpt("Button border", 5, "bbR", "bbG", "bbB"),
            acc = ColorOpt("Accent (hover, glow, XayaUI row)", 6, "accR", "accG", "accB", "Used for the hover border and glow, and for the XayaUI row."),
            title = ColorOpt("Title", 7, "ttR", "ttG", "ttB"),
            reset = { type = "execute", order = 8, name = "Reset colors", disabled = off,
                func = function()
                    local c = Cfg()
                    for _, k in ipairs({ "bgR", "bgG", "bgB", "pbR", "pbG", "pbB", "btnR", "btnG", "btnB", "bbR", "bbG", "bbB", "accR", "accG", "accB", "ttR", "ttG", "ttB" }) do c[k] = DEFAULTS[k] end
                    re()
                end },
        } },
        text = { type = "group", order = 20, inline = true, name = "Text", args = {
            font = { type = "select", order = 1, name = "Font", disabled = off,
                values = function() local v = ns.FontList(); return v end, sorting = function() local _, o = ns.FontList(); return o end,
                get = g("font"), set = s("font") },
            fontSize = rng("Font size", "fontSize", 2, 8, 30),
            outline = { type = "select", order = 3, name = "Outline", disabled = off, values = { [""] = "None", OUTLINE = "Outline", THICKOUTLINE = "Thick" },
                sorting = { "", "OUTLINE", "THICKOUTLINE" }, get = g("outline"), set = s("outline") },
            color = { type = "color", order = 4, name = "Text color", disabled = off, hasAlpha = true,
                get = function() local c = Cfg(); return c.textR, c.textG, c.textB, (tonumber(c.textA) or 100) / 100 end,
                set = function(_, r, gg, b, a) local c = Cfg(); c.textR, c.textG, c.textB = r, gg, b; if a then c.textA = math.floor(a * 100 + 0.5) end; re() end },
        } },
        xui = { type = "group", order = 30, inline = true, name = "XayaUI button", args = {
            row = { type = "select", order = 1, name = "Position", disabled = off,
                values = { AFTER_MACROS = "After Macros", TOP = "Top of the menu", BOTTOM = "Bottom of the menu", HIDE = "Hidden" },
                sorting = { "AFTER_MACROS", "TOP", "BOTTOM", "HIDE" }, get = g("xuiRow"), set = s("xuiRow"), disabled = ownOnly },
            style = { type = "select", order = 2, name = "Style", disabled = off,
                values = { gradient = "Gradient button, solid text", standard = "Standard button, accent text" }, sorting = { "gradient", "standard" },
                get = g("xuiStyle"), set = s("xuiStyle") },
        } },
        hide = { type = "group", order = 40, inline = true, name = "Leave out of this menu", args = {
            n = { type = "description", order = 0, width = "full", name = "Hides the entry from the XayaUI look only; Blizzard's own menu is unchanged. Names are Blizzard's, in your game language." },
            shop = { type = "toggle", order = 1, name = "Shop", get = function() return Cfg().hide[BLIZZARD_STORE or "Shop"] and true or false end,
                set = function(_, v) Cfg().hide[BLIZZARD_STORE or "Shop"] = v or nil; re() end, disabled = ownOnly },
            whatsnew = { type = "toggle", order = 2, name = "What's New", get = function() return Cfg().hide[GAMEMENU_NEW_BUTTON or "What's New"] and true or false end,
                set = function(_, v) Cfg().hide[GAMEMENU_NEW_BUTTON or "What's New"] = v or nil; re() end, disabled = ownOnly },
            support = { type = "toggle", order = 3, name = "Support", get = function() return Cfg().hide[GAMEMENU_SUPPORT or "Support"] and true or false end,
                set = function(_, v) Cfg().hide[GAMEMENU_SUPPORT or "Support"] = v or nil; re() end, disabled = ownOnly },
        } },
        reset = { type = "execute", order = 50, name = "Reset Game Menu settings", disabled = off,
            func = function() ReskinS.gm = nil; Cfg().skin = true; re() end },
    }
    -- its on / off is the tick box on this page's row in the left pane (xuiSwitch; Reskin 0.6.4, S1 #48: "individual toggles for
    -- individual reskins"), greyed while the Blizzard UI Reskin tab's own switch is off
    local switch = { type = "toggle", name = "Use the XayaUI Game Menu look", tip = "Restyles the Esc menu in the XayaUI look.", get = g("skin"), set = s("skin"),
        disabled = function() return not ns.ReskinTabOn() end,
        desc = "Gives the Esc menu XayaUI's look; off, Blizzard's menu comes back at once. Greyed while Blizzard Reskin is off (this tab's Overview)." }
    return { type = "group", name = "Esc Menu", order = 3, xuiSwitch = switch, args = args }   -- (Reskin 0.6.1: a page of the Blizzard UI Reskin tab)
end

-------------------------------------------------------------------------------
-- Plugs into core through Modules.lua (0.5.108): core never calls this file by name.
-------------------------------------------------------------------------------
ns.RegisterSettingsPage("reskin", "gamemenu", ns.GameMenuSkin_Options)   -- the Blizzard UI Reskin tab's Esc Menu page (Options 0.6.38)
-- (Reskin 0.6.20; docs/plans/PLATFORM-SPLIT-2026-11-07.md section 6.6) theme scope of the Esc Menu page, under the Blizzard Reskin tab's scope (core Theme.lua). Plumbing only:
-- nothing paints with it yet and no page edits it (the UI comes with the module moves).
local TS = ns.Theme and ns.Theme.RegisterScope
if TS then
    TS({ id = "reskin.gamemenu", label = "Esc Menu", parent = "reskin" })
end

