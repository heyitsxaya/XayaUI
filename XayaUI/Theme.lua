-------------------------------------------------------------------------------
-- Theme.lua : the XayaUI style sheet.
--
-- Two layers:
--   TOKENS  = the palette (accent, label, text, window / pane / border, button, tab, tree colors ...).
--   CLASSES = general element classes (xui-window, xui-pane, xui-tab, xui-button, xui-heading ...). Each class says which token
--             supplies its background / border / text color. Every class can be overridden on its own, so a user can recolor
--             "all buttons" or "all headings" without touching anything else.
-- Plus a font and a size (S / M / L). A theme is plain data (numbers and strings), so import / export never runs code.
--
-- Base themes:  "default" (XUI purple)  |  "class" (follows the character's class color, or a class picked by hand)  |  a built-in preset  |  "custom" (your own: starts from
-- th.under, with your color changes on top)  |  a saved theme.
-- Saved in CueRulesDB.theme (the active one) and CueRulesDB.themes[name] (saved ones).
-------------------------------------------------------------------------------
local addonName, ns = ...

local T = {}
ns.Theme = T

local floor, max, min = math.floor, math.max, math.min

-- key, label, group, default {r,g,b,a}, hint
T.TOKENS = {
    { "accent",        "Accent",              "Highlights", { 0.75, 0.25, 1.00, 1.00 }, "Selection highlight, glows, the info (i) panel border" },
    { "accentText",    "Selected row text",   "Highlights", { 0.78, 0.62, 1.00, 1.00 }, "Text of the selected row in the rule list" },
    { "gradStart",     "Parent group glow",   "Highlights", { 0.30, 0.08, 0.45, 1.00 }, "Dark end of the highlight behind a selected rule's top parent group" },
    { "label",         "Labels and headings", "Text",       { 1.00, 0.82, 0.00, 1.00 }, "Window title, headings, field labels" },
    { "text",          "Body text",           "Text",       { 0.96, 0.96, 0.98, 1.00 }, "Checkbox text, rule names in the list" },
    { "textMuted",     "Muted text",          "Text",       { 0.60, 0.60, 0.65, 1.00 }, "Hints and disabled items" },
    { "windowBg",      "Window",              "Surfaces",   { 0.06, 0.06, 0.06, 1.00 }, "Window background (opacity follows /xuiskin alpha)" },
    { "paneBg",        "Panes",               "Surfaces",   { 0.04, 0.04, 0.04, 1.00 }, "Sidebar, option panes, and group boxes" },
    { "border",        "Borders",             "Surfaces",   { 0.30, 0.30, 0.30, 1.00 }, "Window and pane outlines" },
    { "titleBar",      "Title bar",           "Surfaces",   { 0.13, 0.13, 0.13, 1.00 }, "The strip behind the window title" },
    { "buttonBg",      "Button",              "Buttons",    { 0.04, 0.04, 0.04, 0.70 }, "Ordinary buttons" },
    { "buttonBorder",  "Button outline",      "Buttons",    { 0.25, 0.25, 0.25, 1.00 }, "Ordinary button outline" },
    { "buttonText",    "Button text",         "Buttons",    { 1.00, 0.82, 0.00, 1.00 }, "Text on buttons" },
    { "primaryBg",     "Primary button",      "Buttons",    { 0.42, 0.04, 0.04, 0.95 }, "The red 'Add ...' buttons" },
    { "primaryBorder", "Primary outline",     "Buttons",    { 0.65, 0.12, 0.12, 1.00 }, "Outline of the primary buttons" },
    { "tabBg",         "Tab",                 "Tabs",       { 0.03, 0.03, 0.03, 0.70 }, "Unselected tab" },
    { "tabBorder",     "Tab outline",         "Tabs",       { 0.22, 0.22, 0.22, 1.00 }, "Unselected tab outline" },
    { "tabSelBg",      "Selected tab",        "Tabs",       { 0.22, 0.10, 0.30, 0.90 }, "Selected tab" },
    { "tabSelBorder",  "Selected tab outline","Tabs",       { 0.80, 0.50, 1.00, 1.00 }, "Selected tab outline" },
    { "treeBar",       "Tree bars",           "Rule list",  { 0.34, 0.34, 0.40, 1.00 }, "Vertical tree guide bars (when switched on)" },
    { "danger",        "Danger",              "Status",     { 1.00, 0.12, 0.12, 1.00 }, "Delete / remove marks" },
}
-- Tokens parked for review (not offered in the Theme page for now; they keep their default / base-theme values and still work in code).
-- See the project doc "XAYAUI-THEME-REVIEW-LATER".
T.SHOW_OVERRIDES = false
T.PARKED = { tabBg = true, tabBorder = true, tabSelBg = true, tabSelBorder = true, treeBar = true }   -- windowBg, paneBg, text un-parked 2026-11-01 (light mode / custom themes)
T.TOKEN = {}
for _, t in ipairs(T.TOKENS) do T.TOKEN[t[1]] = t end

-- class -> { bg = token, border = token, text = token }
T.CLASSES = {
    { "xui-window",         "Window",                { bg = "windowBg", border = "border" } },
    { "xui-titlebar",       "Title bar",             { bg = "titleBar", text = "label" } },
    { "xui-pane",           "Pane / group box",      { bg = "paneBg", border = "border" } },
    { "xui-tab",            "Tab",                   { bg = "tabBg", border = "tabBorder", text = "label" } },
    { "xui-tab-selected",   "Selected tab",          { bg = "tabSelBg", border = "tabSelBorder", text = "text" } },
    { "xui-button",         "Button",                { bg = "buttonBg", border = "buttonBorder", text = "buttonText" } },
    { "xui-button-primary", "Primary button",        { bg = "primaryBg", border = "primaryBorder", text = "buttonText" } },
    { "xui-heading",        "Heading",               { text = "text" } },
    { "xui-label",          "Field label",           { text = "label" } },
    { "xui-text",           "Body text",             { text = "text" } },
    { "xui-text-muted",     "Muted text",            { text = "textMuted" } },
    { "xui-list-row",       "Rule list row",         { text = "text" } },
    { "xui-list-selected",  "Selected rule list row",{ text = "accentText", bg = "accent" } },
    { "xui-list-parent",    "Parent group glow",     { bg = "gradStart" } },
    { "xui-popup",          "Info popup",            { bg = "windowBg", border = "accent" } },
    { "xui-danger",         "Danger mark",           { text = "danger" } },
}
T.CLASS = {}
for _, c in ipairs(T.CLASSES) do T.CLASS[c[1]] = c end

T.SIZES = { S = 0.88, M = 1.0, L = 1.15 }
T.SIZE_NAMES = { S = "Small", M = "Medium", L = "Large" }

local function Copy4(c) return { c[1], c[2], c[3], c[4] or 1 } end
local function Clamp01(v) v = tonumber(v) or 0; if v < 0 then return 0 elseif v > 1 then return 1 end return v end
local function Mix(a, b, t) return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, a[4] or 1 } end

local function DB()
    if not CueRulesDB then return nil end
    CueRulesDB.theme = CueRulesDB.theme or {}
    local th = CueRulesDB.theme
    th.base = th.base or "class"   -- never adjusted: class colors, class read from the logged-in character (Xaya, 2026-11-01)
    th.tokens = th.tokens or {}
    th.classes = th.classes or {}
    th.font = th.font or "none"
    th.size = th.size or "M"
    CueRulesDB.themes = CueRulesDB.themes or {}
    -- A preset with color changes on top IS a custom theme: say so in the selector (nothing visibly changes).
    if th.base ~= "custom" and (next(th.tokens) or next(th.classes)) then
        th.under = (th.base ~= "custom" and th.base) or "default"
        th.base = "custom"
    end
    return th
end
T.DB = DB

-------------------------------------------------------------------------------
-- Palettes
-------------------------------------------------------------------------------
function T.PlayerClass()
    local ok, _, file = pcall(UnitClass, "player")
    return ok and file or nil
end
function T.ClassColor(file)
    local c = file and RAID_CLASS_COLORS and RAID_CLASS_COLORS[file]
    if c then return { c.r, c.g, c.b, 1 } end
    return { 0.75, 0.25, 1, 1 }
end

-- The "class" base: the XUI structure with the class color driving every accent-like token.
function T.ClassPalette(file)
    local c = T.ClassColor(file)
    local light = Mix(c, { 1, 1, 1, 1 }, 0.35)
    local pal = {}
    pal.accent = Copy4(c)
    pal.accentText = light
    pal.gradStart = { c[1] * 0.40, c[2] * 0.40, c[3] * 0.40, 1 }
    pal.label = Mix(c, { 1, 1, 1, 1 }, 0.25)
    pal.buttonText = Mix(c, { 1, 1, 1, 1 }, 0.25)
    pal.tabSelBg = { c[1] * 0.28, c[2] * 0.28, c[3] * 0.28, 0.9 }
    pal.tabSelBorder = Copy4(c)
    pal.primaryBg = { c[1] * 0.45, c[2] * 0.45, c[3] * 0.45, 0.95 }
    pal.primaryBorder = { c[1] * 0.85, c[2] * 0.85, c[3] * 0.85, 1 }
    pal.buttonBorder = Mix({ 0.25, 0.25, 0.25, 1 }, c, 0.25)
    pal.border = Mix({ 0.30, 0.30, 0.30, 1 }, c, 0.15)
    return pal
end

-- Built-in bases besides "default" and "class" (Xaya, 2026-11-01). Tokens not listed keep the XUI default.
--  light:      dark text on white surfaces; same translucency as the dark theme (Xaya 2026-11-01). Untested in game; some hard-coded white text in the skin may still show.
--  colorblind: Okabe-Ito colors (sky blue / yellow / orange); nothing relies on a red-vs-green difference.
T.BUILTIN = {
    light = { name = "Light mode", pal = {
        windowBg = { 1.00, 1.00, 1.00, 1 }, paneBg = { 1.00, 1.00, 1.00, 1 }, border = { 0.45, 0.46, 0.52, 1 }, titleBar = { 0.82, 0.84, 0.92, 1 },
        text = { 0.08, 0.08, 0.10, 1 }, textMuted = { 0.20, 0.20, 0.26, 1 }, label = { 0.10, 0.20, 0.55, 1 },
        accent = { 0.15, 0.35, 0.85, 1 }, accentText = { 0.04, 0.12, 0.50, 1 }, gradStart = { 0.72, 0.80, 0.98, 1 },
        buttonBg = { 1, 1, 1, 0.90 }, buttonBorder = { 0.45, 0.46, 0.52, 1 }, buttonText = { 0.10, 0.20, 0.55, 1 },
        primaryBg = { 0.15, 0.35, 0.85, 0.95 }, primaryBorder = { 0.10, 0.25, 0.65, 1 },
        tabBg = { 0.90, 0.90, 0.94, 0.9 }, tabBorder = { 0.45, 0.46, 0.52, 1 }, tabSelBg = { 0.72, 0.80, 0.98, 0.95 }, tabSelBorder = { 0.15, 0.35, 0.85, 1 },
        danger = { 0.80, 0.10, 0.10, 1 } } },
    colorblind = { name = "Color blind safe (blue / yellow / orange)", pal = {
        accent = { 0.337, 0.706, 0.914, 1 }, accentText = { 0.70, 0.88, 0.98, 1 }, gradStart = { 0.06, 0.18, 0.28, 1 },
        label = { 0.941, 0.894, 0.259, 1 }, buttonText = { 0.941, 0.894, 0.259, 1 },
        buttonBorder = { 0.40, 0.40, 0.45, 1 }, border = { 0.35, 0.38, 0.42, 1 },
        primaryBg = { 0.00, 0.30, 0.47, 0.95 }, primaryBorder = { 0.00, 0.447, 0.698, 1 },
        tabSelBg = { 0.00, 0.20, 0.32, 0.9 }, tabSelBorder = { 0.337, 0.706, 0.914, 1 },
        danger = { 1.00, 0.55, 0.10, 1 } } },
}
-- More color vision types. Prevalence (StatPearls, "Color Vision", NBK470227): protan/deutan anomalies ~7% of males, protanopia + deuteranopia
-- ~1% of males, tritan defects ~0.01% of males and females. All three palettes are built from Okabe-Ito / Wong hues (not simulated or
-- tested by a user with these conditions).
T.BUILTIN.protan = { name = "Colorblind: red-weak / red-blind (protanopia / protanomaly)", pal = {
    accent = { 0.337, 0.706, 0.914, 1 }, accentText = { 0.80, 0.92, 1.00, 1 }, gradStart = { 0.06, 0.18, 0.28, 1 },
    label = { 0.95, 0.90, 0.40, 1 }, buttonText = { 0.95, 0.90, 0.40, 1 },
    buttonBorder = { 0.45, 0.45, 0.50, 1 }, border = { 0.38, 0.40, 0.45, 1 },
    primaryBg = { 0.00, 0.32, 0.50, 0.95 }, primaryBorder = { 0.30, 0.65, 0.90, 1 },
    tabSelBg = { 0.00, 0.20, 0.32, 0.9 }, tabSelBorder = { 0.337, 0.706, 0.914, 1 },
    danger = { 1.00, 0.80, 0.20, 1 } } }   -- bright, not red: reds read as dark to protan viewers
T.BUILTIN.tritan = { name = "Colorblind: blue-yellow (tritanopia / tritanomaly)", pal = {
    accent = { 0.90, 0.35, 0.50, 1 }, accentText = { 1.00, 0.80, 0.85, 1 }, gradStart = { 0.30, 0.08, 0.14, 1 },
    label = { 0.70, 0.95, 0.95, 1 }, buttonText = { 0.70, 0.95, 0.95, 1 },
    buttonBorder = { 0.40, 0.45, 0.45, 1 }, border = { 0.35, 0.40, 0.40, 1 },
    primaryBg = { 0.45, 0.10, 0.20, 0.95 }, primaryBorder = { 0.90, 0.35, 0.50, 1 },
    tabSelBg = { 0.30, 0.08, 0.14, 0.9 }, tabSelBorder = { 0.90, 0.35, 0.50, 1 },
    danger = { 1.00, 0.25, 0.25, 1 } } }
T.BUILTIN.colorblind.name = "Colorblind: green-weak / green-blind (deuteranopia / deuteranomaly)"
T.BUILTIN_ORDER = { "light", "colorblind", "protan", "tritan" }
function T.IsLight()
    local th = CueRulesDB and CueRulesDB.theme
    if not th then return false end
    if th.base == "light" or (th.base == "custom" and th.under == "light") then return true end
    local sv = CueRulesDB.themes and CueRulesDB.themes[th.base]
    return sv and (sv.base == "light" or (sv.base == "custom" and sv.under == "light")) or false
end
function T.IsBase(b) return b == "default" or b == "class" or b == "custom" or T.BUILTIN[b] ~= nil end
-- the preset a Custom theme starts from (never "custom" itself)
local function CleanUnder(u) if u and u ~= "custom" and T.IsBase(u) then return u end return "default" end
function T.Under() local th = CueRulesDB and CueRulesDB.theme; return CleanUnder(th and th.under) end
-- the base that decides the palette and the class color source ("custom" looks through to what it starts from)
function T.EffBase() local th = CueRulesDB and CueRulesDB.theme; if not th then return "default" end; if th.base == "custom" then return T.Under() end; return th.base end

function T.BasePalette(base, classPick)
    if base == "custom" then base = T.Under() end
    if base == "class" then return T.ClassPalette(classPick or T.PlayerClass()) end
    if T.BUILTIN[base] then local pal = {} for k, v in pairs(T.BUILTIN[base].pal) do pal[k] = Copy4(v) end return pal end
    local saved = CueRulesDB and CueRulesDB.themes and CueRulesDB.themes[base]
    if saved then return T.SavedPalette(saved) end
    return {}
end

function T.SavedPalette(saved)
    local pal = {}
    local sb = (saved.base == "custom") and CleanUnder(saved.under) or saved.base
    local under = (sb == "class") and T.ClassPalette(saved.classPick or T.PlayerClass()) or (T.BUILTIN[sb] and T.BasePalette(sb)) or {}
    for k, v in pairs(under) do pal[k] = v end
    for k, v in pairs(saved.tokens or {}) do if T.TOKEN[k] and type(v) == "table" then pal[k] = Copy4(v) end end
    return pal
end

-------------------------------------------------------------------------------
-- Resolve: palette + overrides -> T.cur, then push into every bound table
-------------------------------------------------------------------------------
T.cur = {}
for _, t in ipairs(T.TOKENS) do T.cur[t[1]] = Copy4(t[4]) end
T.binds = {}
T.listeners = {}
function T.OnResolve(fn) T.listeners[#T.listeners + 1] = fn end

function T.Bind(key, tbl)
    T.binds[#T.binds + 1] = { key, tbl }
    local c = T.cur[key]
    if c then tbl[1], tbl[2], tbl[3], tbl[4] = c[1], c[2], c[3], c[4] end
end

function T.Resolve()
    local th = DB()
    local pal = {}
    if th then pal = T.BasePalette(th.base, th.classPick) end
    local cur = {}
    for _, t in ipairs(T.TOKENS) do
        local k = t[1]
        local v = (th and not T.PARKED[k] and th.tokens[k]) or pal[k] or t[4]
        cur[k] = Copy4(v)
    end
    T.cur = cur
    for _, b in ipairs(T.binds) do
        local c = cur[b[1]]
        if c then b[2][1], b[2][2], b[2][3], b[2][4] = c[1], c[2], c[3], c[4] end
    end
    for _, fn in ipairs(T.listeners) do pcall(fn) end   -- widgets that were painted once (toolbar buttons ...) repaint here
end

-- color of a class property: the class override, else the token the class points at. Always returns a fresh {r,g,b,a}.
function T.Col(class, prop, fallback)
    local th = CueRulesDB and CueRulesDB.theme
    local def = T.CLASS[class]
    local tok = def and def[3][prop]
    local o = th and th.classes and th.classes[class] and th.classes[class][prop]
    if type(o) == "table" and not (tok and T.PARKED[tok]) then return Copy4(o) end
    if tok and T.cur[tok] then return Copy4(T.cur[tok]) end
    return fallback and Copy4(fallback) or { 1, 1, 1, 1 }
end

-------------------------------------------------------------------------------
-- Font and size
-------------------------------------------------------------------------------
function T.FontKey() local th = DB(); return th and th.font or "none" end
function T.FontPath()
    local key = T.FontKey()
    if key == "none" then return nil end
    return ns.FontPath and ns.FontPath(key) or nil
end
function T.Scale() local th = DB(); return T.SIZES[th and th.size or "M"] or 1 end
function T.Size(n) return floor((tonumber(n) or 12) * T.Scale() * 10 + 0.5) / 10 end

local probe
local function FontWorks(path)
    probe = probe or UIParent:CreateFontString(nil, "OVERLAY")
    local ok, res = pcall(probe.SetFont, probe, path, 12, "")
    return ok and res and true or false
end

-- Paint a fontstring with the theme: remember its original font / size / color so Restore can undo it.
function T.Style(fs, class, opts)
    if not (fs and fs.SetFont and fs.GetFont) then return end
    if not fs.xuiTheme then
        local f, s, fl = fs:GetFont()
        local r, g, b, a = fs:GetTextColor()
        fs.xuiTheme = { f, s, fl, r, g, b, a }
    end
    local o = fs.xuiTheme
    local path = T.FontPath()
    if path and not FontWorks(path) then path = nil end   -- file missing (new fonts need a full game restart): keep the game font
    if not (opts and opts.keepFont) then
        fs:SetFont(path or o[1], T.Size(o[2]), o[3])
    end
    if class and not (opts and opts.keepColor) then
        local c = T.Col(class, "text", { o[4], o[5], o[6], o[7] })
        fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
    end
end
function T.Restore(fs)
    local o = fs and fs.xuiTheme
    if not o then return end
    fs:SetFont(o[1], o[2], o[3])
    fs:SetTextColor(o[4], o[5], o[6], o[7])
    fs.xuiTheme = nil
end

-------------------------------------------------------------------------------
-- Changing the theme
-------------------------------------------------------------------------------
-- While the color picker is open (scrubbing the wheel fires a change on every mouse move) the options window must NOT be rebuilt:
-- AceGUI recycles its widgets on a rebuild, and the picker keeps calling the old widget, which by then belongs to a different option,
-- so the color lands on the wrong setting. Repaints are queued and run once the picker closes.
local queue, qticker = {}, nil
function T.Defer(fn)
    if not (ColorPickerFrame and ColorPickerFrame.IsShown and ColorPickerFrame:IsShown() and C_Timer) then fn(); return end
    queue[fn] = true
    T.liveDirty = true
    if qticker then return end
    -- live preview: repaint the windows that are already open IN PLACE (no rebuild, so no widget is recycled under the picker),
    -- at most ~8 times a second; the full rebuild waits for the picker to close
    qticker = C_Timer.NewTicker(0.12, function(t)
        if T.liveDirty then T.liveDirty = false; ns.Fire("THEME_CHANGED") end
        if ColorPickerFrame:IsShown() then return end
        t:Cancel(); qticker = nil
        local q = queue; queue = {}
        for f in pairs(q) do pcall(f) end
    end)
end
function T.UINotify()
    ns.Fire("CONFIG_CHANGED")
    ns.Fire("THEME_CHANGED")
end
function T.Changed()
    T.Resolve()
    T.Defer(T.UINotify)
    if ns.MarkDirty then ns.MarkDirty() end
end

-- Switch to Custom: the current look stays exactly as it is (the old base becomes "Start from", color changes are kept).
local function ToCustom(th)
    if th.base == "custom" then return end
    th.under = T.IsBase(th.base) and th.base or "default"
    th.base = "custom"
end
function T.MakeCustom() local th = DB(); if not th then return end; ToCustom(th); T.Changed() end
function T.SetUnder(u)
    local th = DB(); if not th then return end
    th.under = CleanUnder(u)
    th.base = "custom"
    if th.under ~= "class" then th.classPick = nil end
    T.Changed()
end
function T.ClearCustom() local th = DB(); if th then th.tokens, th.classes = {}, {}; T.Changed() end end
function T.SetBase(base, classPick)
    if base == "custom" then return T.MakeCustom() end
    local th = DB(); if not th then return end
    th.base = base
    th.under = nil
    th.classPick = classPick
    th.tokens = {}   -- a new base starts clean; individual colors are re-picked on top of it
    th.classes = {}
    T.Changed()
end
function T.SetToken(key, c)
    local th = DB(); if not (th and T.TOKEN[key]) then return end
    ToCustom(th)
    th.tokens[key] = { Clamp01(c[1]), Clamp01(c[2]), Clamp01(c[3]), Clamp01(c[4] == nil and 1 or c[4]) }
    T.Changed()
end
function T.ResetToken(key) local th = DB(); if th then th.tokens[key] = nil; T.Changed() end end
function T.SetClassColor(class, prop, c)
    local th = DB(); if not (th and T.CLASS[class] and T.CLASS[class][3][prop]) then return end
    ToCustom(th)
    th.classes[class] = th.classes[class] or {}
    th.classes[class][prop] = { Clamp01(c[1]), Clamp01(c[2]), Clamp01(c[3]), Clamp01(c[4] == nil and 1 or c[4]) }
    T.Changed()
end
function T.ResetClass(class) local th = DB(); if th then th.classes[class] = nil; T.Changed() end end
function T.SetFont(key) local th = DB(); if th then th.font = key or "none"; T.Changed() end end
function T.SetSize(sz) local th = DB(); if th and T.SIZES[sz] then th.size = sz; T.Changed() end end
function T.ResetAll()
    local th = DB(); if not th then return end
    th.base, th.under, th.classPick, th.tokens, th.classes, th.font, th.size = "class", nil, nil, {}, {}, "none", "M"
    T.Changed()
end

-------------------------------------------------------------------------------
-- Saved themes
-------------------------------------------------------------------------------
local function CleanColors(src, known)
    local out = {}
    if type(src) ~= "table" then return out end
    for k, v in pairs(src) do
        if type(k) == "string" and known(k) and type(v) == "table" then
            out[k] = { Clamp01(v[1]), Clamp01(v[2]), Clamp01(v[3]), Clamp01(v[4] == nil and 1 or v[4]) }
        end
    end
    return out
end
local function Snapshot()
    local th = DB()
    local classes = {}
    for cls, props in pairs(th.classes) do
        if T.CLASS[cls] and type(props) == "table" then
            local p = {}
            for prop, c in pairs(props) do if T.CLASS[cls][3][prop] and type(c) == "table" then p[prop] = Copy4(c) end end
            classes[cls] = p
        end
    end
    local toks = {}
    for k, c in pairs(th.tokens) do if T.TOKEN[k] then toks[k] = Copy4(c) end end
    return { base = T.IsBase(th.base) and th.base or "default", under = (th.base == "custom") and CleanUnder(th.under) or nil, classPick = th.classPick,
        tokens = toks, classes = classes, font = th.font, size = th.size }
end

function T.SavedNames()
    local n = {}
    for name in pairs(CueRulesDB and CueRulesDB.themes or {}) do n[#n + 1] = name end
    table.sort(n)
    return n
end
function T.Save(name)
    name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" or T.IsBase(name) or #name > 40 then return false, "Pick a name (1-40 characters, not a built-in theme name)." end
    local th = DB(); if not th then return false end
    CueRulesDB.themes[name] = Snapshot()
    th.base = th.base
    return true
end
function T.Load(name)
    local s = CueRulesDB and CueRulesDB.themes and CueRulesDB.themes[name]
    local th = DB()
    if not (s and th) then return false end
    th.base, th.classPick = s.base or "default", s.classPick
    th.under = (th.base == "custom") and CleanUnder(s.under) or nil
    th.tokens, th.classes = CleanColors(s.tokens, function(k) return T.TOKEN[k] ~= nil end), {}
    for cls, props in pairs(s.classes or {}) do
        if T.CLASS[cls] then th.classes[cls] = CleanColors(props, function(p) return T.CLASS[cls][3][p] ~= nil end) end
    end
    th.font = (type(s.font) == "string") and s.font or "none"
    th.size = T.SIZES[s.size] and s.size or "M"
    T.Changed()
    return true
end
function T.Delete(name)
    if CueRulesDB and CueRulesDB.themes then CueRulesDB.themes[name] = nil end
end

-------------------------------------------------------------------------------
-- Import / export: share kind "theme",  XUITHEME1:<checksum>:<base64 of JSON>  (Share.lua; data only: never runs code)
-------------------------------------------------------------------------------
local function CheckTheme(data)
    if type(data) ~= "table" then return nil, "The theme string is damaged (not readable)." end
    local clean = { base = T.IsBase(data.base) and data.base or "default", tokens = CleanColors(data.tokens, function(k) return T.TOKEN[k] ~= nil end), classes = {} }
    if clean.base == "custom" then clean.under = CleanUnder(data.under) end
    if type(data.classPick) == "string" and RAID_CLASS_COLORS and RAID_CLASS_COLORS[data.classPick] then clean.classPick = data.classPick end
    if type(data.classes) == "table" then
        for cls, props in pairs(data.classes) do
            if type(cls) == "string" and T.CLASS[cls] then
                clean.classes[cls] = CleanColors(props, function(p) return T.CLASS[cls][3][p] ~= nil end)
            end
        end
    end
    clean.font = (type(data.font) == "string" and #data.font <= 60) and data.font or "none"
    clean.size = T.SIZES[data.size] and data.size or "M"
    return clean
end

-- apply a checked theme; opts.saveAs (optional) also keeps it under that name. Returns true or false, message.
local function ApplyTheme(data, opts)
    local th = DB(); if not th then return false, "Not ready yet." end
    th.base, th.under, th.classPick, th.tokens, th.classes, th.font, th.size = data.base, data.under, data.classPick, data.tokens, data.classes, data.font, data.size
    local saveAs = type(opts) == "table" and opts.saveAs or nil
    if saveAs and saveAs ~= "" then
        local ok, e2 = T.Save(saveAs)
        if not ok then T.Changed(); return false, e2 end
    end
    T.Changed()
    return true
end

ns.Share.RegisterKind({
    kind = "theme", prefix = "XUITHEME1", version = 1, label = "a theme",
    where = "Themes are imported under Settings > UI Options > Theme.",
    Check = CheckTheme,
    Describe = function(d) return ("Theme based on %s, font %s, size %s."):format(tostring(d.base), tostring(d.font), tostring(d.size)) end,
    Apply = ApplyTheme,
})

function T.Export()
    local th = DB(); if not th then return "" end
    return ns.Share.Encode("theme", Snapshot()) or ""
end

function T.Decode(str) return ns.Share.Read(str, "theme") end

-- Applies an imported theme; saveAs (optional) also keeps it under that name.
function T.Import(str, saveAs)
    local data, err = ns.Share.Read(str, "theme")
    if not data then return false, err end
    return ApplyTheme(data, { saveAs = saveAs })
end

-------------------------------------------------------------------------------
-- Boot: resolve once the saved variables exist, and again when the class is known
-------------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function() pcall(T.Resolve) end)

-- shared with the settings window's editor (ThemeEditor.lua); read-only
ns.ThemeShared = { DB = DB, T = T, floor = floor, max = max, min = min }
