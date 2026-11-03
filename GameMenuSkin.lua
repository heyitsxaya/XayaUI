-------------------------------------------------------------------------------
-- GameMenuSkin.lua : XayaUI's own look for the Game Menu (ESC menu). Own code, Blizzard's GameMenuFrame only (no other addon's code).
--
-- Why a replacement and not a restyle: Blizzard recycles the menu's buttons from a pool and other UI addons (EllesmereUI) restyle those
-- pooled buttons too, so two skins fight over the same buttons (0.5.37-0.5.40 showed that). This file never writes to a pooled button.
--   * GameMenuFrame stays the real menu: it builds its entries, owns ESC, and runs every entry's action. We only fade it out (frame alpha).
--   * Our own frame (child of UIParent, never pooled) is drawn over it: one row per ACTIVE Blizzard entry, in Blizzard's order, with the
--     entry's own text and enabled state. Clicking a row calls that entry's :Click(), so the Blizzard action runs exactly as before.
--   * A row is added for XayaUI (after Macros by default). All sizes come from the settings (Settings > UI Options > Display), not from the siblings.
-- Safety: default OFF. Any error while building turns the skin off for the session and gives Blizzard's menu back (alpha 1).
-- Group gaps (Options / Shop | addons | ... | Log Out / Exit | Return) are read from where Blizzard laid its entries out.
-- UNTESTED in game: the first check is /xui gamemenu (it lists what the menu exposes).
-------------------------------------------------------------------------------
local addonName, ns = ...
ns = _G.XayaUI_NS or ns

local LABEL = "XayaUI"
local diag = { built = 0, rows = 0, groups = 0, lastError = nil, failed = false, titleFound = false }
ns.GameMenuSkinDiag = diag

local DEFAULTS = {
    skin = false,                 -- master switch (off until chosen)
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

local function Ui() CueRulesDB = CueRulesDB or {}; CueRulesDB.ui = CueRulesDB.ui or {}; return CueRulesDB.ui end
local function Cfg()
    local ui = Ui()
    ui.gm = ui.gm or {}
    for k, v in pairs(DEFAULTS) do
        if ui.gm[k] == nil then ui.gm[k] = (type(v) == "table") and {} or v end
    end
    return ui.gm
end
ns.GameMenuSkin_Cfg = Cfg

function ns.GameMenuSkin_Active() return Cfg().skin and not diag.failed end

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
    return match or r.src
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
            if not src then diag.lastError = "no real button found for '" .. tostring(self.label) .. "'"; return end
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

local function Build()
    local menu = GameMenuFrame
    if not menu then return end
    local c = Cfg()
    if not ns.GameMenuSkin_Active() then
        if panel then panel:Hide() end
        if menu.SetAlpha then menu:SetAlpha(1) end
        return
    end
    local list = ReadEntries(menu)
    if #list == 0 then diag.lastError = "no menu entries found"; if panel then panel:Hide() end; menu:SetAlpha(1); return end
    MarkGroups(list)
    local entries = Place(LABEL, c.xuiRow, list)
    local p = Panel()
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
        r.src, r.srcIdx, r.isXui, r.label, r.disabled = e.src, e.idx, e.isXui, e.text, not e.enabled
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
    menu:SetAlpha(0)
    p:Show()
    diag.built, diag.rows = diag.built + 1, used
end

local function SafeBuild()
    local ok, err = pcall(Build)
    if not ok then
        diag.failed, diag.lastError = true, tostring(err)
        if panel then panel:Hide() end
        if GameMenuFrame and GameMenuFrame.SetAlpha then GameMenuFrame:SetAlpha(1) end    -- give Blizzard's menu back
        if ns.CaptureError then ns.CaptureError(err) end
    end
end
function ns.GameMenuSkin_Refresh() if GameMenuFrame and GameMenuFrame:IsShown() then SafeBuild() end end

local hooked
local function Hook()
    if hooked or not GameMenuFrame then return end
    hooked = true
    local function later() SafeBuild(); if C_Timer then C_Timer.After(0, SafeBuild) end end   -- again next frame: layout may settle after us
    if type(GameMenuFrame.InitButtons) == "function" then hooksecurefunc(GameMenuFrame, "InitButtons", later) end
    GameMenuFrame:HookScript("OnShow", later)
    GameMenuFrame:HookScript("OnHide", function() if panel then panel:Hide() end end)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", Hook)
ns.GameMenuSkin_Hook = Hook

function ns.GameMenuSkin_Diagnostics()
    local c = Cfg()
    ns.Print(("game menu skin: on=%s failed=%s built=%d rows=%d title found=%s lastError=%s"):format(
        tostring(c.skin), tostring(diag.failed), diag.built, diag.rows, tostring(diag.titleFound), tostring(diag.lastError)))
    for i, r in ipairs(rows) do
        if r:IsShown() then
            if r.isXui then ns.Print(("  row %d '%s' -> XayaUI (opens the settings)"):format(i, tostring(r.label)))
            else
                local b = ResolveSource(r)
                local okT, t = pcall(function() return b and b:GetText() end)
                local okP, top = pcall(function() return b and b:GetTop() end)
                ns.Print(("  row %d '%s' -> real '%s' layoutIndex=%s top=%s"):format(i, tostring(r.label), okT and tostring(t) or "?", tostring(b and b.layoutIndex), okP and tostring(top and math.floor(top)) or "?"))
            end
        end
    end
    if GameMenuFrame and GameMenuFrame.buttonPool and GameMenuFrame.buttonPool.EnumerateActive then
        local n, names = 0, {}
        for b in GameMenuFrame.buttonPool:EnumerateActive() do
            n = n + 1; local ok, t = pcall(b.GetText, b); names[#names + 1] = ok and tostring(t) or "?"
        end
        ns.Print(("Blizzard entries (%d): %s"):format(n, table.concat(names, " | ")))
    else
        ns.Print("the Game Menu exposes no button pool on this client: the skin cannot read its entries.")
    end
end

-- Settings > UI Options > Display (Game Menu look) ----------------------------------------------------------------------------------------------------------
function ns.GameMenuSkin_Options(Notify)
    local function re() diag.failed = false; ns.GameMenuSkin_Refresh(); if Notify then Notify() end end
    local function g(k) return function() return Cfg()[k] end end
    local function s(k) return function(_, v) Cfg()[k] = v; re() end end
    local off = function() return not Cfg().skin end
    local function rng(name, k, order, lo, hi, desc) return { type = "range", name = name, order = order, min = lo, max = hi, step = 1, desc = desc, get = g(k), set = s(k), disabled = off } end
    local function ColorOpt(name, order, kr, kg, kb, desc)
        return { type = "color", order = order, name = name, desc = desc, hasAlpha = false,
            disabled = function() return off() or not Cfg().useColors end,
            get = function() local c = Cfg(); return c[kr], c[kg], c[kb] end,
            set = function(_, r, gg, b) local c = Cfg(); c[kr], c[kg], c[kb] = r, gg, b; re() end }
    end
    local args = {
        note = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "XayaUI's own look for the ESC menu. It draws its own panel over Blizzard's menu and clicks Blizzard's entries for you, so it does not edit the buttons other UI addons restyle. If something goes wrong the skin turns itself off and Blizzard's menu comes back. Off by default; /xui gamemenu shows what the menu exposes." },
        skin = { type = "toggle", order = 1, width = "full", name = "Use the XayaUI Game Menu look", get = g("skin"), set = s("skin") },
        look = { type = "group", order = 10, inline = true, name = "Look", args = {
            w = rng("Button width", "w", 1, 120, 480), h = rng("Button height", "h", 2, 20, 70),
            gap = rng("Space between buttons", "gap", 3, 0, 30), groupGap = rng("Space between groups", "groupGap", 4, 0, 60),
            pad = rng("Panel padding", "pad", 5, 4, 60), scale = rng("Scale (%)", "scale", 6, 50, 200),
            bgA = rng("Panel opacity (%)", "bgA", 7, 0, 100), btnA = rng("Button opacity (%)", "btnA", 8, 0, 100),
            border = { type = "toggle", order = 9, name = "Panel border", get = g("border"), set = s("border"), disabled = off },
            hoverAccent = { type = "toggle", order = 10, name = "Hover uses the theme accent", get = g("hoverAccent"), set = s("hoverAccent"), disabled = off },
            title = { type = "toggle", order = 11, name = "Show the title", get = g("title"), set = s("title"), disabled = off },
            titleSize = rng("Title size", "titleSize", 12, 8, 30),
        } },
        colors = { type = "group", order = 15, inline = true, name = "Colors", args = {
            use = { type = "toggle", order = 1, width = "full", name = "Use my own colors (off: follow the theme and class color)", disabled = off,
                desc = "Off: the panel border, buttons, hover color and title follow the addon theme or your class color. On: the colors below are used.",
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
                sorting = { "AFTER_MACROS", "TOP", "BOTTOM", "HIDE" }, get = g("xuiRow"), set = s("xuiRow") },
            style = { type = "select", order = 2, name = "Style", disabled = off,
                values = { gradient = "Gradient button, solid text", standard = "Standard button, accent text" }, sorting = { "gradient", "standard" },
                get = g("xuiStyle"), set = s("xuiStyle") },
        } },
        hide = { type = "group", order = 40, inline = true, name = "Leave out of this menu", args = {
            n = { type = "description", order = 0, width = "full", name = "Hides the entry from the XayaUI look only; Blizzard's own menu is unchanged. Names are Blizzard's, in your game language." },
            shop = { type = "toggle", order = 1, name = "Shop", get = function() return Cfg().hide[BLIZZARD_STORE or "Shop"] and true or false end,
                set = function(_, v) Cfg().hide[BLIZZARD_STORE or "Shop"] = v or nil; re() end, disabled = off },
            whatsnew = { type = "toggle", order = 2, name = "What's New", get = function() return Cfg().hide[GAMEMENU_NEW_BUTTON or "What's New"] and true or false end,
                set = function(_, v) Cfg().hide[GAMEMENU_NEW_BUTTON or "What's New"] = v or nil; re() end, disabled = off },
            support = { type = "toggle", order = 3, name = "Support", get = function() return Cfg().hide[GAMEMENU_SUPPORT or "Support"] and true or false end,
                set = function(_, v) Cfg().hide[GAMEMENU_SUPPORT or "Support"] = v or nil; re() end, disabled = off },
        } },
        reset = { type = "execute", order = 50, name = "Reset Game Menu settings", disabled = off,
            func = function() Ui().gm = nil; Cfg().skin = true; re() end },
    }
    return { type = "group", name = "Game Menu", order = 3, args = args }
end
