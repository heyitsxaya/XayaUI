-------------------------------------------------------------------------------
-- InfoPane.lua : the version pane (Options 0.6.56). Xaya 2026-11-06: "clicking version number in the bottom right should bring up a
-- standalone pane above XayaUI that has the following tabs" -- Patch Notes (What's New, then one entry per landing) and Info
-- (Version info, Readme, Help (FAQ), Credits + Acknowledgements), each tab with a left-hand list of its sections.
--
-- Opened by the version text in the settings window's bottom-left corner (Options.lua; "keep version number where it is") and by
-- the ? in the title bars ("help icon brings you to its location wherever its nested"; "nest it in the title bar alongside the
-- collapse pane and X close button"): the ? opens Info > Help (FAQ).
-- Window (her pick, 2026-11-06): floats above the settings window (DIALOG strata; the settings window is HIGH), can be dragged by
-- its title bar and remembers where it was left, Esc closes it before the settings window. Title bar: ? | collapse | X.
-- Text: InfoPaneData.lua (generated from PATCH-NOTES.md, docs/README-INGAME.md, docs/HELP-FAQ.md) and AddonInfo.lua (Version info,
-- credits). Nothing here is built until the pane first opens; XayaUI_Options itself loads only when the settings window first opens.
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns

local P = {}
ns.InfoPane = P

local WIDTH, HEIGHT = 720, 520
local TITLE_H, TAB_H, NAV_W, ROW_H = 28, 24, 190, 22
local M = ns.UI_MARGIN or 10
local G = ns.UI_GUTTER or 10
local WHITE8 = "Interface\\Buttons\\WHITE8X8"
local ARROW_OPEN, ARROW_COLLAPSED = "Interface\\Buttons\\Arrow-Up-Up", "Interface\\Buttons\\Arrow-Down-Up"

P.TABS = { { key = "patch", label = "Patch Notes" }, { key = "info", label = "Info" } }
P.INFO = {
    { key = "version", label = "Version info" },
    { key = "readme", label = "Readme" },
    { key = "help", label = "Help (FAQ)" },
    { key = "credits", label = "Credits + Acknowledgements" },
}
P.state = { tab = "patch", sel = { patch = "whatsnew", info = "version" } }   -- session only

-- colours -------------------------------------------------------------------
local function Tok(name, fb)
    local T = ns.Theme
    local c = T and T.cur and T.cur[name]
    return (type(c) == "table" and c) or fb
end
local function Col(class, prop, fb)
    local T = ns.Theme
    if T and T.Col then local ok, c = pcall(T.Col, class, prop, fb); if ok and type(c) == "table" then return c end end
    return fb
end
local function Hex(c) return ("|cff%02x%02x%02x"):format(math.floor(c[1] * 255 + 0.5), math.floor(c[2] * 255 + 0.5), math.floor(c[3] * 255 + 0.5)) end
local function ACCENT() return Tok("accent", { 0.75, 0.25, 1.00, 1 }) end
local function ACCENT_TEXT() return Tok("accentText", { 0.78, 0.62, 1.00, 1 }) end
local function TEXT() return Col("xui-text", "text", { 1, 1, 1, 1 }) end
local function MUTED() return Col("xui-text-muted", "text", { 0.6, 0.6, 0.6, 1 }) end
local DEV = { 0.55, 0.75, 0.95, 1 }   -- Developers' notes: Blizzard sets them apart in italics; the game font has no italic, so a soft blue

-- **bold** in the lighter accent, `commands` in the accent; "|r" returns to the line's own colour
function P.Inline(text)
    text = tostring(text or "")
    local at, a = Hex(ACCENT_TEXT()), Hex(ACCENT())
    text = text:gsub("%*%*(.-)%*%*", function(s) return at .. s .. "|r" end)
    text = text:gsub("`(.-)`", function(s) return a .. s .. "|r" end)
    return text
end

local function Version()
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local ok, v = pcall(get or function() end, ns.name or "XayaUI", "Version")
    return (ok and type(v) == "string" and v ~= "") and v or nil
end

-- what each tab lists on its left side, and what an entry shows -------------
function P.Entries(tab)
    local D = ns.InfoPaneData or {}
    if tab == "patch" then
        local list = { { key = "whatsnew", label = "What's New" } }
        for i, l in ipairs(D.patches or {}) do list[#list + 1] = { key = "p" .. i, label = l.date, sub = l.title } end
        return list
    end
    return P.INFO
end

function P.Blocks(tab, key)
    local D = ns.InfoPaneData or {}
    if tab == "patch" then
        if key == "whatsnew" then
            local out = { { "h1", "What's New" }, { "small", "New features only, newest first, for each addon's current version line. The full notes are the dated entries below What's New." } }
            for _, b in ipairs(D.whatsNew or {}) do out[#out + 1] = b end
            return out
        end
        local l = (D.patches or {})[tonumber(tostring(key):match("^p(%d+)$") or "")]
        if not l then return { { "p", "Nothing here." } } end
        local out = { { "h1", l.title }, { "small", l.date } }
        for _, b in ipairs(l.blocks or {}) do out[#out + 1] = b end
        return out
    end
    if key == "version" then return ns.VersionInfoBlocks and ns.VersionInfoBlocks() or {} end
    if key == "credits" then return ns.CreditsBlocks and ns.CreditsBlocks() or {} end
    local src = key == "readme" and D.readme or key == "help" and D.faq or {}
    local out = { { "h1", key == "readme" and "Readme" or "Help (FAQ)" } }
    for _, b in ipairs(src) do out[#out + 1] = b end
    return out
end

-- drawing ---------------------------------------------------------------------
local W   -- the pane, built on first open

local function Box(parent, layer)
    local b = { bg = parent:CreateTexture(nil, layer or "BACKGROUND"), edge = {} }
    for i = 1, 4 do b.edge[i] = parent:CreateTexture(nil, "BORDER") end
    return b
end
local function PlaceBox(b, l, t, w, h, bg, bd)
    b.bg:ClearAllPoints(); b.bg:SetPoint("TOPLEFT", b.bg:GetParent(), "TOPLEFT", l, -t); b.bg:SetSize(w, h)
    b.bg:SetColorTexture(bg[1], bg[2], bg[3], bg[4] or 1); b.bg:Show()
    local e = b.edge
    e[1]:ClearAllPoints(); e[1]:SetPoint("TOPLEFT", b.bg, "TOPLEFT"); e[1]:SetPoint("TOPRIGHT", b.bg, "TOPRIGHT"); e[1]:SetHeight(1)
    e[2]:ClearAllPoints(); e[2]:SetPoint("BOTTOMLEFT", b.bg, "BOTTOMLEFT"); e[2]:SetPoint("BOTTOMRIGHT", b.bg, "BOTTOMRIGHT"); e[2]:SetHeight(1)
    e[3]:ClearAllPoints(); e[3]:SetPoint("TOPLEFT", b.bg, "TOPLEFT"); e[3]:SetPoint("BOTTOMLEFT", b.bg, "BOTTOMLEFT"); e[3]:SetWidth(1)
    e[4]:ClearAllPoints(); e[4]:SetPoint("TOPRIGHT", b.bg, "TOPRIGHT"); e[4]:SetPoint("BOTTOMRIGHT", b.bg, "BOTTOMRIGHT"); e[4]:SetWidth(1)
    for i = 1, 4 do e[i]:SetColorTexture(bd[1], bd[2], bd[3], bd[4] or 1); e[i]:Show() end
end
local function HideBox(b) b.bg:Hide(); for i = 1, 4 do b.edge[i]:Hide() end end

-- pools: every render hides what the last one used and takes what it needs
local function Pool(make) return { list = {}, n = 0, make = make } end
local function Take(pool)
    pool.n = pool.n + 1
    local o = pool.list[pool.n]
    if not o then o = pool.make(); pool.list[pool.n] = o end
    return o
end
local function ResetPool(pool, hide) for i = 1, #pool.list do hide(pool.list[i]) end; pool.n = 0 end

local FONTS = { h1 = "GameFontNormalLarge", h2 = "GameFontNormalLarge", h3 = "GameFontNormal", grp = "GameFontNormal",
                section = "GameFontNormal", kv = "GameFontHighlight", p = "GameFontHighlight", b = "GameFontHighlight",
                dev = "GameFontHighlight", small = "GameFontHighlightSmall", input = "GameFontHighlightSmall" }

local function Text(kind, s, x, y, w, color)
    local fs = Take(W.fsPool)
    fs:SetFontObject(FONTS[kind] or "GameFontHighlight")
    fs:SetJustifyH("LEFT"); fs:SetWordWrap(true)
    fs:ClearAllPoints(); fs:SetPoint("TOPLEFT", W.child, "TOPLEFT", x, -y); fs:SetWidth(w)
    fs:SetText(P.Inline(s))
    fs:SetTextColor(color[1], color[2], color[3], 1)
    fs:Show()
    return fs, math.max(12, fs:GetStringHeight() or 12)
end

local function Input(label, value, x, y, w)
    local fs, h = Text("input", label, x, y, w, MUTED())
    local e = Take(W.editPool)
    e.value = value
    e:ClearAllPoints(); e:SetPoint("TOPLEFT", W.child, "TOPLEFT", x, -(y + h + 2)); e:SetSize(w, 20)
    e:SetText(value); e:SetCursorPosition(0); e:Show()
    local bg = Tok("paneBg", { 0, 0, 0, 0.6 })
    e.bg:SetColorTexture(0, 0, 0, 0.5); e.edgeColor = bg
    return h + 2 + 20
end

-- (Options 0.6.64, B6: the credits sections no longer collapse, so their arrow rows, ArrowButton and its button pool, are gone)
-- the space after one credits section's box: the gutter plus 10 px (Xaya, ATTR-1: "increase the gutter by 10px"; it was the gutter)
local CREDITS_GUTTER = G + 10
P.CREDITS_GUTTER = CREDITS_GUTTER   -- (tests)

local function Render()
    if not W then return end
    ResetPool(W.fsPool, function(o) o:Hide() end)
    ResetPool(W.editPool, function(o) o:Hide() end)
    ResetPool(W.boxPool, HideBox)
    W.recs = {}   -- (Options 0.6.64) what the credits page placed: its h2s, rows and boxes (the tests and Dev Assist's QA walkthrough read it)
    local width = math.max(200, (W.scroll:GetWidth() or (WIDTH - NAV_W - 3 * M)) - 8)
    W.child:SetWidth(width)
    local y = 4
    local blocks = P.Blocks(P.state.tab, P.state.sel[P.state.tab])
    W.rendered = blocks
    for _, b in ipairs(blocks) do
        local k = b[1]
        if k == "h1" then
            y = y + (y > 4 and 6 or 0)
            local _, h = Text("h1", b[2], 0, y, width, ACCENT_TEXT()); y = y + h + 6
        elseif k == "h2" then
            y = y + 14
            local _, h = Text("h2", b[2], 0, y, width, ACCENT_TEXT()); y = y + h + 3
            local r = Take(W.boxPool); PlaceBox(r, 0, y, width, 1, ACCENT(), ACCENT()); y = y + 6
        elseif k == "rule" then
            local r = Take(W.boxPool); PlaceBox(r, 0, y, width, 1, ACCENT(), ACCENT()); y = y + 8
        elseif k == "h3" then
            y = y + 12
            local _, h = Text("h3", b[2], 0, y, width, ACCENT()); y = y + h + 4
        elseif k == "grp" then
            y = y + 8
            local _, h = Text("grp", b[2], 0, y, width, TEXT()); y = y + h + 3
        elseif k == "p" then
            local _, h = Text("p", b[2], 0, y, width, TEXT()); y = y + h + 8
        elseif k == "small" then
            local _, h = Text("small", b[2], 0, y, width, MUTED()); y = y + h + 8
        elseif k == "kv" then
            local _, h = Text("kv", Hex(ACCENT_TEXT()) .. b[2] .. "|r " .. b[3], 0, y, width, TEXT()); y = y + h + 6
        elseif k == "input" then
            y = y + Input(b[2], b[3], 0, y, width) + 8
        elseif k == "b" or k == "dev" then
            local lvl = tonumber(b[2]) or 1
            local ind = 4 + (lvl - 1) * 16
            if k == "b" then
                local dot = Take(W.fsPool)
                dot:SetFontObject("GameFontHighlight"); dot:ClearAllPoints()
                dot:SetPoint("TOPLEFT", W.child, "TOPLEFT", ind, -y); dot:SetWidth(12); dot:SetJustifyH("LEFT")
                dot:SetText(lvl == 1 and "\226\128\162" or "-")   -- U+2022 bullet
                local c = ACCENT(); dot:SetTextColor(c[1], c[2], c[3], 1); dot:Show()
                local _, h = Text("b", b[3], ind + 14, y, width - ind - 14, TEXT()); y = y + h + 4
            else
                local _, h = Text("dev", b[3], ind + 14, y, width - ind - 14, DEV); y = y + h + 4
            end
        elseif k == "credits" then
            -- (Options 0.6.64; REQUEST-LOG B6 / ATTR-1, reading taken) one credits section: a plain h2 in normal case (no arrow, no
            -- collapsing, no count, no line under it), its sub line, then ONE square (unrounded) box for the whole section, each credit a
            -- row inside it (name, who, note, its copyable links; rows one under the other, no columns), the box's background 10% more
            -- opaque than the pane's; after the box the gutter plus 10 px (her "increase the gutter by 10px")
            local title, sub, entries = b[2], b[3], b[4]
            y = y + 10   -- (the room above a section heading, as before)
            local _, hh = Text("h2", title, 0, y, width, ACCENT_TEXT())
            W.recs[#W.recs + 1] = { kind = "h2", text = title, y = y, h = hh }
            y = y + hh + 3
            if sub and sub ~= "" then local _, h = Text("small", sub, 0, y, width, MUTED()); y = y + h + 8 end
            local box = Take(W.boxPool)
            local top, pad, inner = y, 8, width - 16
            y = y + pad
            for i, e in ipairs(entries or {}) do
                if i > 1 then y = y + pad end   -- (a row's room above the next one)
                W.recs[#W.recs + 1] = { kind = "row", section = title, text = e.name, x = pad, y = y, w = inner }
                local _, h1 = Text("p", e.name, pad, y, inner, ACCENT_TEXT()); y = y + h1 + 3
                local _, h2 = Text("p", e.who, pad, y, inner, TEXT()); y = y + h2 + 3
                if e.note and e.note ~= "" then local _, h3 = Text("p", e.note, pad, y, inner, MUTED()); y = y + h3 + 3 end
                for _, l in ipairs(e.links or {}) do y = y + Input(l[1], l[2], pad, y, inner) + 3 end
            end
            y = y + pad
            local bg = Col("xui-pane", "bg", { 0.1, 0.1, 0.1, 0.6 })
            local alpha = math.min(1, (bg[4] or 0.6) + 0.1)
            PlaceBox(box, 0, top, width, y - top, { bg[1], bg[2], bg[3], alpha }, Col("xui-pane", "border", { 0.3, 0.3, 0.3, 1 }))
            W.recs[#W.recs + 1] = { kind = "box", section = title, x = 0, y = top, w = width, h = y - top, alpha = alpha, paneAlpha = bg[4] or 0.6,
                rows = #(entries or {}) }
            y = y + CREDITS_GUTTER
        end
    end
    W.child:SetHeight(y + M)
    W.contentHeight = y + M
    if W.scroll.UpdateScrollChildRect then W.scroll:UpdateScrollChildRect() end
end
P.Render = Render

local function PaintTab(b, sel)
    local cls = sel and "xui-tab-selected" or "xui-tab"
    local bg = Col(cls, "bg", sel and { 0.30, 0.15, 0.45, 0.9 } or { 0.12, 0.12, 0.12, 0.9 })
    local bd = Col(cls, "border", sel and ACCENT() or { 0.3, 0.3, 0.3, 1 })
    local tx = Col(cls, "text", { 1, 1, 1, 1 })
    PlaceBox(b.box, 0, 0, b:GetWidth(), b:GetHeight(), bg, bd)
    b.text:SetTextColor(tx[1], tx[2], tx[3], 1)
end

local function BuildNav()
    for _, b in ipairs(W.nav) do b:Hide() end
    local list = P.Entries(P.state.tab)
    local y = 0
    for i, e in ipairs(list) do
        local b = W.nav[i]
        if not b then
            b = CreateFrame("Button", nil, W.navChild)
            b.hl = b:CreateTexture(nil, "BACKGROUND"); b.hl:SetAllPoints(); b.hl:SetTexture(WHITE8)
            b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            b.text:SetPoint("TOPLEFT", 6, -4); b.text:SetPoint("RIGHT", -4, 0); b.text:SetJustifyH("LEFT")
            b.sub = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            b.sub:SetPoint("TOPLEFT", b.text, "BOTTOMLEFT", 0, -2); b.sub:SetPoint("RIGHT", -4, 0); b.sub:SetJustifyH("LEFT")
            b.sub:SetWordWrap(false)
            b:SetScript("OnClick", function(self) P.Select(P.state.tab, self.key) end)
            b:SetScript("OnEnter", function(self) self.hover = true; self:Paint() end)
            b:SetScript("OnLeave", function(self) self.hover = false; self:Paint() end)
            b.Paint = function(self)
                local sel = P.state.sel[P.state.tab] == self.key
                local a = ACCENT()
                self.hl:SetColorTexture(a[1], a[2], a[3], sel and 0.35 or (self.hover and 0.15 or 0))
                local t = sel and ACCENT_TEXT() or TEXT()
                self.text:SetTextColor(t[1], t[2], t[3], 1)
                local m = MUTED(); self.sub:SetTextColor(m[1], m[2], m[3], 1)
            end
            W.nav[i] = b
        end
        b.key = e.key
        b.text:SetText(e.label)
        b.sub:SetText(e.sub or ""); b.sub:SetShown(e.sub ~= nil)
        local h = e.sub and 36 or ROW_H
        b:ClearAllPoints(); b:SetPoint("TOPLEFT", W.navChild, "TOPLEFT", 0, -y); b:SetSize(NAV_W - 8, h)
        b:Show(); b:Paint()
        y = y + h + 2
    end
    W.navChild:SetHeight(y)
end

function P.Paint()
    if not W then return end
    local bg = Col("xui-window", "bg", { 0.06, 0.06, 0.06, 0.97 })
    local bd = Col("xui-window", "border", { 0.3, 0.3, 0.3, 1 })
    PlaceBox(W.frameBox, 0, 0, W:GetWidth(), W:GetHeight(), { bg[1], bg[2], bg[3], math.max(0.9, bg[4] or 0.97) }, bd)
    local tb = Col("xui-titlebar", "bg", { 0.12, 0.12, 0.12, 1 })
    W.titleBg:SetColorTexture(tb[1], tb[2], tb[3], tb[4] or 1)
    local lt = Col("xui-titlebar", "text", { 1, 0.82, 0, 1 })
    W.title:SetTextColor(lt[1], lt[2], lt[3], 1)
    for _, t in ipairs(W.tabs) do PaintTab(t, P.state.tab == t.key) end
    for _, b in ipairs(W.nav) do if b:IsShown() then b:Paint() end end
end

-- window ----------------------------------------------------------------------
local function SavePos()
    local cx, cy = W:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if not (cx and ux) then return end
    if type(CueRulesDB) == "table" then
        CueRulesDB.ui = CueRulesDB.ui or {}
        CueRulesDB.ui.infoPanePos = { math.floor(cx - ux + 0.5), math.floor(cy - uy + 0.5) }
    end
end

local function Place()
    W:ClearAllPoints()
    local pos = type(CueRulesDB) == "table" and type(CueRulesDB.ui) == "table" and CueRulesDB.ui.infoPanePos
    if type(pos) == "table" and tonumber(pos[1]) and tonumber(pos[2]) then
        W:SetPoint("CENTER", UIParent, "CENTER", pos[1], pos[2])
        return
    end
    -- first time: centred over the settings window when it is open, else the middle of the screen
    local ACD = LibStub and LibStub("AceConfigDialog-3.0", true)
    local of = ACD and ACD.OpenFrames and ACD.OpenFrames["CueRules"]
    if of and of.frame and of.frame:IsShown() then W:SetPoint("CENTER", of.frame, "CENTER", 0, 0)
    else W:SetPoint("CENTER", UIParent, "CENTER", 0, 40) end
end

local function TitleButton(parent, w)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w or 22, 22)
    b:SetFrameLevel(parent:GetFrameLevel() + 5)
    return b
end

function P.SetCollapsed(v)
    if not W then return end
    W.collapsed = v and true or false
    for _, f in ipairs(W.body) do f:SetShown(not W.collapsed) end
    W:SetHeight(W.collapsed and TITLE_H or HEIGHT)
    W.collapse.tex:SetTexture(W.collapsed and ARROW_COLLAPSED or ARROW_OPEN)
    P.Paint()
end

local function Build()
    local f = CreateFrame("Frame", "XayaUIInfoPane", UIParent)
    W = f
    f:SetSize(WIDTH, HEIGHT)
    f:SetFrameStrata("DIALOG")   -- above the settings window (HIGH); below popups and menus (TOOLTIP) and the game's alerts
    f:SetToplevel(true); f:EnableMouse(true); f:SetMovable(true); f:SetClampedToScreen(true)
    f.frameBox = Box(f)
    f.fsPool = Pool(function() return f.child:CreateFontString(nil, "OVERLAY", "GameFontHighlight") end)
    f.boxPool = Pool(function() return Box(f.child, "BACKGROUND") end)

    -- title bar: drag to move; ? | collapse | X on the right
    f.titleBar = CreateFrame("Frame", nil, f)
    f.titleBar:SetPoint("TOPLEFT", 1, -1); f.titleBar:SetPoint("TOPRIGHT", -1, -1); f.titleBar:SetHeight(TITLE_H - 1)
    f.titleBar:EnableMouse(true); f.titleBar:RegisterForDrag("LeftButton")
    f.titleBar:SetScript("OnDragStart", function() f:StartMoving() end)
    f.titleBar:SetScript("OnDragStop", function() f:StopMovingOrSizing(); SavePos() end)
    f.titleBg = f.titleBar:CreateTexture(nil, "BACKGROUND"); f.titleBg:SetAllPoints()
    f.title = f.titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("LEFT", f.titleBar, "LEFT", M, 0)
    f.title:SetText("XayaUI" .. (Version() and ("  v" .. Version()) or ""))

    f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    f.close:SetSize(22, 22); f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -3)
    f.close:SetFrameLevel(f:GetFrameLevel() + 5)
    f.close:SetScript("OnClick", function() f:Hide() end)
    f.collapse = TitleButton(f)
    f.collapse:SetPoint("RIGHT", f.close, "LEFT", -4, 0)
    f.collapse.tex = f.collapse:CreateTexture(nil, "OVERLAY"); f.collapse.tex:SetSize(14, 14); f.collapse.tex:SetPoint("CENTER")
    f.collapse.tex:SetTexture(ARROW_OPEN)
    f.collapse:SetScript("OnClick", function() P.SetCollapsed(not f.collapsed) end)
    f.collapse:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(f.collapsed and "Expand the pane" or "Collapse to the title bar")
        GameTooltip:Show()
    end)
    f.collapse:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.help = TitleButton(f)
    f.help:SetPoint("RIGHT", f.collapse, "LEFT", -4, 0)
    f.help:SetText("?")
    f.help:SetScript("OnClick", function() P.OpenHelp() end)
    f.help:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:SetText("Help"); GameTooltip:AddLine("Opens Info > Help (FAQ).", 1, 1, 1, true); GameTooltip:Show()
    end)
    f.help:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- tabs
    f.body = {}
    f.tabs = {}
    local x = M
    for _, t in ipairs(P.TABS) do
        local b = CreateFrame("Button", nil, f)
        b.key = t.key
        b.box = Box(b)
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal"); b.text:SetPoint("CENTER"); b.text:SetText(t.label)
        b:SetSize(math.max(96, (b.text:GetStringWidth() or 60) + 28), TAB_H)
        b:SetPoint("TOPLEFT", f, "TOPLEFT", x, -(TITLE_H + 6))
        b:SetScript("OnClick", function(self) P.Select(self.key) end)
        x = x + b:GetWidth() + 4
        f.tabs[#f.tabs + 1] = b
        f.body[#f.body + 1] = b
    end
    local top = TITLE_H + 6 + TAB_H + 6

    -- left: the tab's sections
    f.navScroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    f.navScroll:SetPoint("TOPLEFT", f, "TOPLEFT", M, -top)
    f.navScroll:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", M, M)
    f.navScroll:SetWidth(NAV_W - 18)
    f.navChild = CreateFrame("Frame", nil, f.navScroll)
    f.navChild:SetSize(NAV_W - 8, 10)
    f.navScroll:SetScrollChild(f.navChild)
    f.nav = {}
    f.divider = f:CreateTexture(nil, "BORDER")
    f.divider:SetPoint("TOPLEFT", f, "TOPLEFT", M + NAV_W + 2, -top); f.divider:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", M + NAV_W + 2, M)
    f.divider:SetWidth(1); f.divider:SetColorTexture(0.3, 0.3, 0.3, 1)

    -- right: the section's text
    f.scroll = CreateFrame("ScrollFrame", "XayaUIInfoPaneScroll", f, "UIPanelScrollFrameTemplate")
    f.scroll:SetPoint("TOPLEFT", f, "TOPLEFT", M + NAV_W + 2 + G, -top)
    f.scroll:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(M + 22), M)
    f.child = CreateFrame("Frame", nil, f.scroll)
    f.child:SetSize(WIDTH - NAV_W - 3 * M - 30, 10)
    f.scroll:SetScrollChild(f.child)
    f.editPool = Pool(function()
        local e = CreateFrame("EditBox", nil, f.child)
        e:SetAutoFocus(false); e:SetFontObject("ChatFontNormal"); e:SetTextInsets(6, 6, 2, 2)
        e.bg = e:CreateTexture(nil, "BACKGROUND"); e.bg:SetAllPoints()
        -- read-only copy box: select it, Ctrl+A, Ctrl+C; typing puts the link back
        e:SetScript("OnTextChanged", function(self, user) if user then self:SetText(self.value or ""); self:HighlightText() end end)
        e:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
        e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
        return e
    end)
    for _, k in ipairs({ f.navScroll, f.divider, f.scroll }) do f.body[#f.body + 1] = k end
    f.scroll:SetScript("OnSizeChanged", function() if f:IsShown() then Render() end end)

    -- Esc closes the pane first (Xaya's pick); the settings window stays open until the next Esc. Out of combat the key is kept from
    -- the game, so it does not also close the settings window. In combat the game does not let addons hold keys back
    -- (SetPropagateKeyboardInput HasRestrictions): the pane is in UISpecialFrames, so Esc then closes it with the settings window.
    f:SetScript("OnKeyDown", function(self, key)
        if InCombatLockdown() then return end
        if key == "ESCAPE" then
            self:SetPropagateKeyboardInput(false)
            self:Hide()
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)
    f:SetScript("OnShow", function(self)
        if not InCombatLockdown() then self:EnableKeyboard(true); self:SetPropagateKeyboardInput(true) end
    end)
    f:SetScript("OnHide", function(self)
        if not InCombatLockdown() then self:EnableKeyboard(false) end
        GameTooltip:Hide()
    end)
    if UISpecialFrames then tinsert(UISpecialFrames, "XayaUIInfoPane") end

    if ns.Theme and ns.Theme.OnResolve then
        ns.Theme.OnResolve(function() if W and W:IsShown() then P.Paint(); Render() end end)
    end
    f:Hide()
    return f
end

-- public ----------------------------------------------------------------------
-- P.Select(tab) switches tab (to the section it last showed); P.Select(tab, key) picks a section too.
function P.Select(tab, key)
    if not W then return end
    if tab ~= "patch" and tab ~= "info" then return end
    P.state.tab = tab
    if key then P.state.sel[tab] = key end
    W.scroll:SetVerticalScroll(0)
    BuildNav()
    P.Paint()
    Render()
end

-- P.Open() opens on the tab and section it last showed (Patch Notes > What's New the first time); P.Open(tab, key) goes there.
function P.Open(tab, key)
    local first = not W
    if first then Build(); Place() end
    if W.collapsed then P.SetCollapsed(false) end
    W:Show()
    if W.Raise then W:Raise() end
    P.Select(tab or P.state.tab, key)
end

function P.OpenHelp() P.Open("info", "help") end
function P.Close() if W then W:Hide() end end
function P.IsShown() return W ~= nil and W:IsShown() end
function P.Frame() return W end
-- (Options 0.6.65) the Info pane's texts for XayaUI Dev Assist's spelling walkthrough (QAWalks-audit.lua), through XayaUI's service list
if ns.Provide then ns.Provide("infoPaneData", { Data = function() return ns.InfoPaneData end }) end

-- (Options 0.6.64) the pane through core's service list (Modules.lua ns.Provide), for XayaUI Dev Assist's QA walkthrough of the credits
-- page (QAWalks-statcalc.lua, REQUEST-LOG B6): open a section, read what the last render placed (W.recs), close it. Exists only once
-- this load-on-demand addon has loaded; nothing is built until Open.
if ns.Provide then
    ns.Provide("infoPane", {
        Open = function(tab, key) P.Open(tab, key) end,
        Close = function() P.Close() end,
        IsShown = function() return P.IsShown() end,
        Recs = function() return W and W.recs or nil end,
    })
end
