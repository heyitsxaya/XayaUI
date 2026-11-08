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
-- th.under, with your color changes on top)  |  a saved theme. Since core 0.6.46 the built-ins include one theme per Gradient Cursor Trail
-- gradient ("cursor_<preset key>"; the gradients live here, see "Cursor trail colors <-> UI themes" below).
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
    { "windowBg",      "Window",              "Surfaces",   { 0.06, 0.06, 0.06, 1.00 }, "Window background (opacity follows Window opacity)" },
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
-- (core 0.6.61; REQUEST-LOG UI-50, her answer: "Advanced customization opens up them and more as options, but by default they are
-- not offered") the Theme page's Advanced customization switch (CueRulesDB.ui.themeAdvanced, off by default): on, the parked tokens
-- and the class overrides are offered and a parked token's own colour applies; off, they are neither offered nor applied.
function T.Advanced() local u = CueRulesDB and CueRulesDB.ui; return (u and u.themeAdvanced) == true end
function T.Parked(key) return (key and T.PARKED[key] and not T.Advanced()) and true or false end
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
local function IsCol(c) return type(c) == "table" and type(c[1]) == "number" and type(c[2]) == "number" and type(c[3]) == "number" end
local function CleanCol(c) return { Clamp01(c[1]), Clamp01(c[2]), Clamp01(c[3]), Clamp01(c[4] == nil and 1 or c[4]) } end

-- (#460, core 0.6.81) A palette colour can also be a GRADIENT: { stops = { {r,g,b,a}, ... 2 to 8 }, dir = "V" or nil (nil = "H") }.
-- Kept next to the solid colours, never inside them (the share codec writes a table with both list and named keys as its named keys
-- only), so a colour that has a gradient still has its solid colour, and every T.Col caller keeps getting a solid colour:
--   th.tokens[k] = {r,g,b,a}   your solid colour (as before)        th.grads[k] = gradient | false   your gradient, or false = "solid here"
--   T.BUILTIN[b].pal[k]        the theme's solid colour (as before)  T.BUILTIN[b].grads[k] = gradient   the theme's own gradient
-- A theme without gradients stores and exports nothing new (no grads / gradRev keys), so its strings are byte-for-byte what they were.
local GRAD_MAX = 8
local function CleanGrad(g)
    if type(g) ~= "table" or type(g.stops) ~= "table" then return nil end
    local stops = {}
    for i = 1, math.min(#g.stops, GRAD_MAX) do
        local c = g.stops[i]
        if not IsCol(c) then return nil end
        stops[i] = CleanCol(c)
    end
    if #stops < 2 then return nil end
    return { stops = stops, dir = (g.dir == "V") and "V" or nil }
end
T.CleanGrad = CleanGrad

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
    if th.base ~= "custom" and (next(th.tokens) or next(th.classes) or (type(th.grads) == "table" and next(th.grads))) then
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

-------------------------------------------------------------------------------
-- Cursor trail colors <-> UI themes (core 0.6.46; Xaya, 2026-11-05: "map cursor theme colors to UI themes and provide them as theming
-- options as well")
-------------------------------------------------------------------------------
-- The Gradient Cursor Trail's ready-made gradients, head of the trail (next to the cursor) first, 3 to 6 colors each. Moved here from
-- XayaUI_QoL/CursorTrail.lua with the same keys, names and colors, so the themes below work with XayaUI_QoL switched off; the trail
-- reads this same table (ns.Theme.CURSOR_PRESETS), it keeps no copy. The colors were chosen for XayaUI when the trail was written
-- (CursorTrail.lua, 2026-11-01: "Claude's choices, not taken from any other addon").
T.CURSOR_PRESETS = {
    fel      = { "Fel",        { {0.35,1.00,0.25}, {0.15,0.80,0.45}, {0.55,0.20,0.85} } },
    fire     = { "Fire",       { {1.00,0.95,0.40}, {1.00,0.55,0.10}, {0.85,0.15,0.05}, {0.25,0.05,0.05} } },
    ocean    = { "Ocean",      { {0.70,1.00,1.00}, {0.15,0.75,0.95}, {0.10,0.35,0.85}, {0.05,0.10,0.45} } },
    aurora   = { "Aurora",     { {0.30,1.00,0.60}, {0.20,0.85,0.95}, {0.45,0.45,1.00}, {0.75,0.30,0.95} } },
    sunset   = { "Sunset",     { {1.00,0.90,0.45}, {1.00,0.55,0.30}, {0.95,0.30,0.50}, {0.55,0.25,0.75}, {0.20,0.15,0.50} } },
    vapor    = { "Vaporwave",  { {1.00,0.45,0.85}, {0.75,0.50,1.00}, {0.35,0.75,1.00}, {0.30,1.00,0.90} } },
    rainbow  = { "Rainbow",    { {1.00,0.20,0.20}, {1.00,0.70,0.10}, {0.95,1.00,0.20}, {0.25,0.90,0.35}, {0.25,0.55,1.00}, {0.65,0.30,0.95} } },
    gold     = { "Gold",       { {1.00,0.98,0.75}, {1.00,0.82,0.25}, {0.80,0.50,0.10} } },
    ice      = { "Frost",      { {1.00,1.00,1.00}, {0.65,0.90,1.00}, {0.30,0.55,1.00} } },
}
T.CURSOR_PRESET_ORDER = { "fel", "fire", "ocean", "aurora", "sunset", "vapor", "rainbow", "gold", "ice" }

-- WCAG 2.x contrast ratio (www.w3.org/TR/WCAG22, "contrast ratio" and "relative luminance"): (L1 + 0.05) / (L2 + 0.05), L1 the lighter;
-- L = 0.2126 R + 0.7152 G + 0.0722 B of the linear values, each sRGB value v -> v / 12.92 when v <= 0.04045, else ((v + 0.055) / 1.055) ^ 2.4.
local function Lin(v) v = Clamp01(v); if v <= 0.04045 then return v / 12.92 end return ((v + 0.055) / 1.055) ^ 2.4 end
function T.Luminance(c) return 0.2126 * Lin(c[1]) + 0.7152 * Lin(c[2]) + 0.0722 * Lin(c[3]) end
function T.Contrast(a, b)
    local la, lb = T.Luminance(a), T.Luminance(b)
    if la < lb then la, lb = lb, la end
    return (la + 0.05) / (lb + 0.05)
end
T.MIN_TEXT_CONTRAST = 4.5   -- WCAG 2.x level AA for normal-size text
local WHITE = { 1, 1, 1, 1 }
local function Over(c, bg) local a = c[4] or 1; return { c[1] * a + bg[1] * (1 - a), c[2] * a + bg[2] * (1 - a), c[3] * a + bg[3] * (1 - a), 1 } end
-- c mixed toward white in 5 % steps until it reads at MIN_TEXT_CONTRAST on bg (unchanged when it already does)
local function Lighten(c, bg)
    for i = 0, 20 do
        local m = Mix(c, WHITE, i * 0.05)
        if T.Contrast(m, bg) >= T.MIN_TEXT_CONTRAST then return m end
    end
    return Copy4(WHITE)
end
-- c scaled so its brightest channel is `top`, then darkened in 5 % steps until every color in `texts` reads at MIN_TEXT_CONTRAST on
-- it, drawn at alpha `a` over bg (the color the eye gets: Over)
local function DarkFor(c, top, a, bg, texts)
    local k0 = top / max(c[1], c[2], c[3], 0.001)
    for i = 0, 20 do
        local k = k0 * (1 - i * 0.05)
        local d = { c[1] * k, c[2] * k, c[3] * k, a }
        local seen, ok = Over(d, bg), true
        for _, t in ipairs(texts) do if T.Contrast(t, seen) < T.MIN_TEXT_CONTRAST then ok = false; break end end
        if ok then return d end
    end
    return { 0, 0, 0, a }
end

-- A UI palette from a trail gradient (stops: head first). The derivation rule:
--   * Only the highlight tokens come from the gradient: accent, accentText, gradStart, tabSelBg, tabSelBorder, and the accent-like
--     label, buttonText, primaryBg, primaryBorder (the tokens every other colored built-in, Class colors included, also tints).
--     Surfaces (window, panes, title bar, borders, buttons, tabs), body and muted text, tree bars and Danger keep the XUI default, so
--     every theme made this way is dark with near-white body text.
--   * "main" = the gradient's second color (the first step away from the head; in seven of the nine presets the head is the pale end
--     and the second color is the gradient's own hue: Fire orange, Ocean blue, Gold gold).
--     accent and tabSelBorder = main; accentText = main mixed 35 % toward white (the same lighter tint Class colors uses).
--   * label and buttonText = the gradient's lightest color (highest relative luminance): the most readable color goes to the most
--     read text (headings, field labels, button text).
--   * gradStart (the parent-group glow) = the gradient's last color (the trail's tail), scaled so its brightest channel is 0.45 (the
--     XUI default glow's); tabSelBg = main scaled to 0.30 (the default selected tab's), alpha 0.9; primaryBg = main scaled to 0.45,
--     alpha 0.95; primaryBorder = main x 0.85 (as Class colors).
--   * Readability: accent, accentText, label and buttonText (all drawn as text somewhere: accent is the footer's version text) are
--     mixed toward white until they read at 4.5:1 or better on the window background (windowBg); gradStart and tabSelBg are darkened
--     until body text and accentText read at 4.5:1 on them, primaryBg until buttonText does (alpha blended over windowBg).
--     The ratios for the nine presets are in debug-log/2026-11-05-1532-cursor-ui-themes-core-0.6.46-qol-0.7.17.md.
function T.CursorPalette(stops)
    local win, body = T.TOKEN.windowBg[4], T.TOKEN.text[4]
    local main = stops[2] or stops[1]
    local lightest = stops[1]
    for i = 2, #stops do if T.Luminance(stops[i]) > T.Luminance(lightest) then lightest = stops[i] end end
    local pal = {}
    pal.accent = Lighten(main, win)
    pal.tabSelBorder = Copy4(pal.accent)
    pal.accentText = Lighten(Mix(main, WHITE, 0.35), win)
    pal.label = Lighten(lightest, win)
    pal.buttonText = Copy4(pal.label)
    pal.gradStart = DarkFor(stops[#stops], 0.45, 1, win, { body, pal.accentText })
    pal.tabSelBg = DarkFor(main, 0.30, 0.90, win, { body, pal.accentText })
    pal.primaryBg = DarkFor(main, 0.45, 0.95, win, { pal.buttonText })
    pal.primaryBorder = { main[1] * 0.85, main[2] * 0.85, main[3] * 0.85, 1 }
    return pal
end
-- (#460, core 0.6.81; Xaya 2026-11-06: "all cursor trail based themes should have gradient borders that reflect the cursor gradient.
-- this gradient should be reversible in direction."; her answer 2026-11-07, which borders: "Window frame, Panes, Buttons, Tabs")
-- A cursor trail theme's border colours are the trail's own gradient, all its stops, head of the trail first: "border" (the window
-- frame and the panes), "buttonBorder" and "primaryBorder" (buttons), "tabBorder" and "tabSelBorder" (tabs). Their solid colours (what
-- a T.Col caller gets, and every element that does not draw gradients) stay what they were (CursorPalette above). Direction: left to
-- right ("H"; INFERENCE, her words do not say: question G1 in debug-log 2026-11-08 debug-w9a).
T.GRAD_BORDER_TOKENS = { "border", "buttonBorder", "primaryBorder", "tabBorder", "tabSelBorder" }
function T.CursorBorderGrads(stops)
    local out = {}
    for _, k in ipairs(T.GRAD_BORDER_TOKENS) do
        local g = { stops = {} }
        for i, s in ipairs(stops) do g.stops[i] = { s[1], s[2], s[3], 1 } end
        out[k] = g
    end
    return out
end
-- one built-in theme per gradient, offered after the color blind ones (the Theme page lists T.BUILTIN_ORDER)
for _, key in ipairs(T.CURSOR_PRESET_ORDER) do
    local p = T.CURSOR_PRESETS[key]
    -- (core 0.6.54) the gradient's name alone (Xaya 2026-11-06: "theme names should drop "cursor theme:" prefix", her screenshot of
    -- the Theme list showing "Cursor trail: Fel" ... "Cursor trail: Frost")
    T.BUILTIN["cursor_" .. key] = { name = p[1], pal = T.CursorPalette(p[2]), cursorPreset = key, grads = T.CursorBorderGrads(p[2]) }
    T.BUILTIN_ORDER[#T.BUILTIN_ORDER + 1] = "cursor_" .. key
end

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

-- UI theme -> cursor trail: the gradient of the trail's "Match the UI theme" choice (XayaUI_QoL), head of the trail first, fresh tables.
--   * A theme made from a trail gradient (picked as the theme, or the "Start from" of a Custom theme that keeps that theme's accent,
--     accentText and gradStart): exactly that gradient's colors.
--   * Any other theme: accentText -> accent -> gradStart as resolved now (T.cur): light at the cursor, the accent in the middle, the
--     dark glow color at the tail, the same light-to-dark order the presets run in.
local TRAIL_TOKENS = { "accentText", "accent", "gradStart" }
function T.TrailStops()
    local th = CueRulesDB and CueRulesDB.theme
    local own = th and type(th.tokens) == "table" and th.tokens or {}
    local b = T.BUILTIN[T.EffBase()]
    local p = b and b.cursorPreset and T.CURSOR_PRESETS[b.cursorPreset]
    local out = {}
    if p and not (own.accent or own.accentText or own.gradStart) then
        for i, s in ipairs(p[2]) do out[i] = { s[1], s[2], s[3] } end
        return out
    end
    for i, k in ipairs(TRAIL_TOKENS) do local c = T.cur[k] or T.TOKEN[k][4]; out[i] = { c[1], c[2], c[3] } end
    return out
end

function T.SavedPalette(saved)
    local pal = {}
    local sb = (saved.base == "custom") and CleanUnder(saved.under) or saved.base
    local under = (sb == "class") and T.ClassPalette(saved.classPick or T.PlayerClass()) or (T.BUILTIN[sb] and T.BasePalette(sb)) or {}
    for k, v in pairs(under) do pal[k] = v end
    for k, v in pairs(saved.tokens or {}) do if T.TOKEN[k] and type(v) == "table" then pal[k] = Copy4(v) end end
    return pal
end

-- (#460) the gradients of a theme, by token: the built-in theme's own (a cursor trail theme's borders), then for a saved theme its
-- own colours on top (a solid colour of its own replaces the gradient it started from; its own gradient, or false = solid, wins).
local NOGRADS = {}
function T.SavedGrads(saved)
    local out = {}
    local sb = (type(saved) == "table" and saved.base == "custom") and CleanUnder(saved.under) or (type(saved) == "table" and saved.base)
    local b = T.BUILTIN[sb]
    if b and b.grads then for k, v in pairs(b.grads) do out[k] = v end end
    for k in pairs(type(saved.tokens) == "table" and saved.tokens or NOGRADS) do if T.TOKEN[k] then out[k] = nil end end
    for k, v in pairs(type(saved.grads) == "table" and saved.grads or NOGRADS) do
        if T.TOKEN[k] then if v == false then out[k] = nil else out[k] = CleanGrad(v) or out[k] end end
    end
    return out
end
function T.BaseGrads(base)
    if base == "custom" then base = T.Under() end
    local b = T.BUILTIN[base]
    if b then return b.grads or NOGRADS end
    local saved = CueRulesDB and CueRulesDB.themes and CueRulesDB.themes[base]
    if type(saved) == "table" then return T.SavedGrads(saved) end
    return NOGRADS
end

-------------------------------------------------------------------------------
-- Resolve: palette + overrides -> T.cur, then push into every bound table
-------------------------------------------------------------------------------
T.cur = {}
for _, t in ipairs(T.TOKENS) do T.cur[t[1]] = Copy4(t[4]) end
T.curGrad = {}   -- (#460) token -> gradient of the resolved theme (T.Resolve)
T.binds = {}
T.listeners = {}
function T.OnResolve(fn) T.listeners[#T.listeners + 1] = fn end
-- (core 0.6.46) take a listener out again, so a feature that is switched off leaves nothing to run on a theme change (rule V14).
-- Builds a new list: a Resolve that is calling the listeners at this moment finishes over the old one.
function T.OffResolve(fn)
    local keep = {}
    for _, f in ipairs(T.listeners) do if f ~= fn then keep[#keep + 1] = f end end
    T.listeners = keep
end

-- (#472, core 0.6.82) scope = an element's theme scope (T.RegisterScope): the bound table follows that element's colour for the token
-- (its own override or chosen theme, else the global one). Without a scope: exactly as before.
function T.Bind(key, tbl, scope)
    T.binds[#T.binds + 1] = { key, tbl, type(scope) == "string" and scope or nil }
    local c = T.cur[key]
    if type(scope) == "string" and T.TokCol then c = T.TokCol(key, scope) end
    if c then tbl[1], tbl[2], tbl[3], tbl[4] = c[1], c[2], c[3], c[4] end
end

function T.Resolve()
    if T.DropScopeCache then T.DropScopeCache() end   -- (#472) scoped binds below read the scopes' answers fresh
    local th = DB()
    local pal = {}
    if th then pal = T.BasePalette(th.base, th.classPick) end
    local cur = {}
    for _, t in ipairs(T.TOKENS) do
        local k = t[1]
        local v = (th and not T.Parked(k) and th.tokens[k]) or pal[k] or t[4]
        cur[k] = Copy4(v)
    end
    T.cur = cur
    -- (#460) the gradients, worked out once here (T.Grad reads them; nothing is worked out per frame): your own gradient (false = you
    -- set it solid), else the theme's own one unless you picked a solid colour of your own for it. Parked tokens: as their colours.
    local grads, base = {}, th and T.BaseGrads(th.base) or NOGRADS
    local own = th and type(th.grads) == "table" and th.grads or NOGRADS
    for _, t in ipairs(T.TOKENS) do
        local k = t[1]
        local open = not T.Parked(k)
        local g
        if open and own[k] ~= nil then g = own[k] or nil
        elseif not (th and open and th.tokens[k]) then g = base[k] end
        grads[k] = CleanGrad(g)
    end
    T.curGrad = grads
    for _, b in ipairs(T.binds) do
        local c = cur[b[1]]
        if b[3] and T.TokCol then c = T.TokCol(b[1], b[3]) end
        if c then b[2][1], b[2][2], b[2][3], b[2][4] = c[1], c[2], c[3], c[4] end
    end
    for _, fn in ipairs(T.listeners) do pcall(fn) end   -- widgets that were painted once (toolbar buttons ...) repaint here
    if ns.RepaintFlatButtons then pcall(ns.RepaintFlatButtons) end   -- core's flat buttons (Core.lua; UI-77, core 0.6.68)
end

-- color of a class property: the class override, else the token the class points at. Always returns a fresh {r,g,b,a}.
function T.Col(class, prop, fallback)
    local th = CueRulesDB and CueRulesDB.theme
    local def = T.CLASS[class]
    local tok = def and def[3][prop]
    local o = th and th.classes and th.classes[class] and th.classes[class][prop]
    if type(o) == "table" and not (tok and T.Parked(tok)) then return Copy4(o) end
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
    local R = ns.Service and ns.Service("rules"); if R then R.MarkDirty() end   -- (P4) the displays redraw (XayaUI Rules, when on)
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
function T.ClearCustom() local th = DB(); if th then th.tokens, th.classes, th.grads = {}, {}, nil; T.Changed() end end
function T.SetBase(base, classPick)
    if base == "custom" then return T.MakeCustom() end
    local th = DB(); if not th then return end
    th.base = base
    th.under = nil
    th.classPick = classPick
    th.tokens = {}   -- a new base starts clean; individual colors are re-picked on top of it
    th.classes = {}
    th.grads = nil   -- (#460) your gradients too; the Reverse switch stays, like the font and size
    T.Changed()
end
function T.SetToken(key, c)
    local th = DB(); if not (th and T.TOKEN[key]) then return end
    ToCustom(th)
    th.tokens[key] = { Clamp01(c[1]), Clamp01(c[2]), Clamp01(c[3]), Clamp01(c[4] == nil and 1 or c[4]) }
    -- (#460) a solid colour picked for it replaces a gradient of your own (the theme's own gradient gives way to it in T.Resolve)
    if type(th.grads) == "table" then th.grads[key] = nil; if next(th.grads) == nil then th.grads = nil end end
    T.Changed()
end
function T.ResetToken(key)
    local th = DB(); if not th then return end
    th.tokens[key] = nil
    if type(th.grads) == "table" then th.grads[key] = nil; if next(th.grads) == nil then th.grads = nil end end   -- (#460) back to the theme's own
    T.Changed()
end

-- (#460, core 0.6.81) Xaya 2026-11-07, Advanced customization: "allow in advance settings the user to apply the gradient as a set
-- "color" option to all elements". The gradient = the theme's gradient (T.TrailStops: a cursor trail theme's own trail gradient, else
-- the light-to-dark accentText -> accent -> gradStart that the trail's "Match the UI theme" uses), copied in, so it travels in the
-- theme's share string. on = false: the colour is solid again (false is kept only where the theme it starts from has a gradient).
function T.SetTokenGradient(key, on)
    local th = DB(); if not (th and T.TOKEN[key]) then return end
    ToCustom(th)
    local own = type(th.grads) == "table" and th.grads or {}
    if on then
        local stops = {}
        for i, s in ipairs(T.TrailStops()) do stops[i] = { Clamp01(s[1]), Clamp01(s[2]), Clamp01(s[3]), 1 } end
        if #stops >= 2 then own[key] = { stops = stops } end
    else
        if T.BaseGrads(th.base)[key] and not th.tokens[key] then own[key] = false else own[key] = nil end
    end
    th.grads = next(own) ~= nil and own or nil
    T.Changed()
end
-- (#460) Xaya 2026-11-06: "this gradient should be reversible in direction"; her answer 2026-11-07: its own switch, independent of the
-- cursor trail's "Reverse colors". One switch for the theme: every gradient of it runs the other way. Stored only while on.
function T.GradReversed() local th = CueRulesDB and CueRulesDB.theme; return type(th) == "table" and th.gradRev == true end
function T.SetGradReverse(on)
    local th = DB(); if not th then return end
    th.gradRev = on and true or nil
    T.Changed()
end
-- does the resolved theme have any gradient (the Theme page shows the Reverse switch only then)
function T.HasGradient() for _ in pairs(T.curGrad or {}) do return true end return false end
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
    th.grads, th.gradRev = nil, nil
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
-- (#460) your gradients, checked: known tokens only, each a gradient (2-8 colours) or false (= solid here)
local function CleanGrads(src)
    local out = {}
    if type(src) ~= "table" then return out end
    for k, v in pairs(src) do
        if type(k) == "string" and T.TOKEN[k] then
            if v == false then out[k] = false else out[k] = CleanGrad(v) end
        end
    end
    return out
end
T.CleanGrads = CleanGrads
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
    local snap = { base = T.IsBase(th.base) and th.base or "default", under = (th.base == "custom") and CleanUnder(th.under) or nil, classPick = th.classPick,
        tokens = toks, classes = classes, font = th.font, size = th.size }
    -- (#460) only when there is something: a theme without gradients saves and exports exactly what it did before
    local grads = CleanGrads(th.grads)
    if next(grads) then snap.grads = grads end
    if th.gradRev == true then snap.gradRev = true end
    return snap
end

function T.SavedNames()
    local n = {}
    for name in pairs(CueRulesDB and CueRulesDB.themes or {}) do n[#n + 1] = name end
    table.sort(n)
    return n
end
-- A name a theme can be saved under (1-40 characters, not a built-in theme's key). Returns the trimmed name, or nil and why.
function T.CheckName(name)
    name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" or T.IsBase(name) or #name > 40 then return nil, "Pick a name (1-40 characters, not a built-in theme name)." end
    return name
end
function T.SavedExists(name) local n = T.CheckName(name); return n ~= nil and CueRulesDB and CueRulesDB.themes and CueRulesDB.themes[n] ~= nil end
-- FA-8 (core 0.6.67; Xaya 2026-11-07: "1 or add as name (1) name (2) etc", then "Replace, Save As Copy, Cancel"): the first free
-- "Name (1)", "Name (2)", ... (the base is shortened so the result stays within 40 characters)
function T.CopyName(name)
    local n = T.CheckName(name) or "Theme"
    local themes = CueRulesDB and CueRulesDB.themes or {}
    for i = 1, 999 do
        local suf = (" (%d)"):format(i)
        local c = n:sub(1, 40 - #suf) .. suf
        if not themes[c] then return c end
    end
    return nil
end
-- audit D6 (core 0.6.67): a name that is already saved is refused unless replace is true (before: it was replaced silently and the
-- message said "Saved"). The Theme page asks first: Replace / Save As Copy / Cancel.
function T.Save(name, replace)
    local n, why = T.CheckName(name)
    if not n then return false, why end
    local th = DB(); if not th then return false end
    if CueRulesDB.themes[n] and not replace then return false, "exists" end
    CueRulesDB.themes[n] = Snapshot()
    th.base = th.base
    return true, n
end
-- FA-4 (core 0.6.67; Xaya: "Ask first"): are there colors of your own that switching or resetting would throw away? Colors identical
-- to a theme you saved are not "unsaved" (picking a saved theme copies its colors in).
local function Same(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for k, v in pairs(a) do if not Same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
function T.UnsavedColors()
    local th = DB(); if not th then return false end
    if not (next(th.tokens or {}) or next(th.classes or {}) or (type(th.grads) == "table" and next(th.grads))) then return false end
    local now = Snapshot()
    for _, sv in pairs(CueRulesDB and CueRulesDB.themes or {}) do
        if type(sv) == "table" and Same(now.tokens or {}, sv.tokens or {}) and Same(now.classes or {}, sv.classes or {})
            and Same(now.grads or {}, type(sv.grads) == "table" and sv.grads or {}) then return false end
    end
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
    local g = CleanGrads(s.grads)   -- (#460)
    th.grads = next(g) and g or nil
    th.gradRev = (s.gradRev == true) or nil
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
    -- (#460) gradients and the Reverse switch: absent in strings made before core 0.6.81, which import exactly as before
    local g = CleanGrads(data.grads)
    if next(g) then clean.grads = g end
    if data.gradRev == true then clean.gradRev = true end
    return clean
end

-- apply a checked theme; opts.saveAs (optional) also keeps it under that name. Returns true or false, message.
-- audit D5 (core 0.6.67): the name is checked BEFORE anything changes; a refused name or (without opts.replace) a name already saved
-- leaves the current theme and the saved one as they were (before: the current theme was replaced first, then the save could fail,
-- or silently replace a saved theme of that name). Returns true or false, message ("exists" for a name already saved).
local function ApplyTheme(data, opts)
    local th = DB(); if not th then return false, "Not ready yet." end
    local saveAs = type(opts) == "table" and opts.saveAs or nil
    if saveAs == "" then saveAs = nil end
    if saveAs then
        local n, why = T.CheckName(saveAs)
        if not n then return false, why end
        if CueRulesDB.themes[n] and not opts.replace then return false, "exists" end
        saveAs = n
    end
    th.base, th.under, th.classPick, th.tokens, th.classes, th.font, th.size = data.base, data.under, data.classPick, data.tokens, data.classes, data.font, data.size
    th.grads, th.gradRev = data.grads, data.gradRev   -- (#460) nil for a theme without them
    if saveAs then T.Save(saveAs, true) end
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
function T.Import(str, saveAs, replace)
    local data, err = ns.Share.Read(str, "theme")
    if not data then return false, err end
    return ApplyTheme(data, { saveAs = saveAs, replace = replace })
end

-------------------------------------------------------------------------------
-- Scopes (core 0.6.74; docs/plans/PLATFORM-SPLIT-2026-11-07.md section 6.6, PS-24, Xaya 2026-11-07: "I think we also need to enable
-- individual element themeing and overrides somewhere -- let's make that part of our rebuild as we configure proper plumbing. ... The
-- XayaUI Settings Theme can be the initial fallback but users can customize at different levels of granularity?"). Plumbing only:
-- (#472, core 0.6.82) the restyled elements now paint with their scope and Blizzard Reskin > Theme edits them (XayaUI_Options/ScopeEditor.lua).
--   T.RegisterScope{ id, label, parent }      an element ("reskin.tooltips") or a module ("reskin") that can carry its own theme
--   T.Col(class, prop, scope [, fallback])    first match wins:
--       1. the element's own overrides (a class colour, then a token colour)
--       2. the element's chosen theme (a built-in or saved theme's name), if it picked one instead of inheriting
--       3. the same two for its parent (the module), and so on up
--       4. the global theme (Settings > Theme): exactly today's T.Col
--     T.Col(class, prop) and T.Col(class, prop, fallbackTable) are today's calls and give today's answer.
-- Stored sparse: only what a scope overrides, CueRulesDB.theme.scopes[id] = { theme = name or nil, tokens = {...}, classes = {...} };
-- nothing is written for a scope with no override, so a profile or theme without scopes is byte-for-byte what it was. They travel in
-- the Themes profile part (it holds CueRulesDB.theme). Resolved scope colours are cached and the cache is dropped on every Resolve.
-------------------------------------------------------------------------------
T.scopes, T.scopeList = {}, {}
local scopeCache = {}
function T.DropScopeCache() scopeCache = {} end   -- (#472) T.Resolve calls it first, so scoped binds read fresh answers
function T.RegisterScope(def)
    local ok, err = pcall(function()
        if type(def) ~= "table" or type(def.id) ~= "string" or def.id == "" then return end
        if not T.scopes[def.id] then T.scopeList[#T.scopeList + 1] = def.id end
        -- (#472, core 0.6.82) page = the settings page key of the element's own page (its "Theme" row goes there); own = a function
        -- answering true while the element draws colours of its own instead of the theme (the Theme page's "Comes from" says so)
        T.scopes[def.id] = { id = def.id, label = type(def.label) == "string" and def.label or def.id,
            parent = (type(def.parent) == "string" and def.parent ~= def.id) and def.parent or nil,
            page = type(def.page) == "string" and def.page or nil, own = type(def.own) == "function" and def.own or nil,
            rowOrder = tonumber(def.rowOrder) }
        scopeCache = {}
    end)
    if not ok then local h = geterrorhandler and geterrorhandler(); if h then h(err) end end
end
function T.Scope(id) return T.scopes[id] end
T.OnResolve(function() scopeCache = {} end)

local function ScopeData(id, make)
    local th = CueRulesDB and CueRulesDB.theme
    if type(th) ~= "table" then if not make then return nil end th = DB(); if not th then return nil end end
    local all = th.scopes
    if type(all) ~= "table" then if not make then return nil end all = {}; th.scopes = all end
    local s = all[id]
    if type(s) ~= "table" then if not make then return nil end s = {}; all[id] = s end
    return s
end
T.ScopeData = function(id) return ScopeData(id, false) end
-- a scope's chosen theme as a palette (built-in, class or saved; "custom" means nothing on its own here)
-- (#472, core 0.6.82) complete: a colour the theme does not list is the XUI default, as when that theme is picked in Settings > Theme
-- (T.Resolve: own colour > palette > default). Before, an unlisted colour fell through to the global theme, so an element given
-- "Class colors" under a global Light mode kept Light's window colour.
local function ScopePalette(name)
    local key = "\2pal\1" .. name
    local pal = scopeCache[key]
    if pal == nil then
        pal = (name ~= "custom" and T.IsBase(name) or (CueRulesDB and CueRulesDB.themes and CueRulesDB.themes[name])) and T.BasePalette(name) or false
        if pal then for _, t in ipairs(T.TOKENS) do if not IsCol(pal[t[1]]) then pal[t[1]] = Copy4(t[4]) end end end
        scopeCache[key] = pal
    end
    return pal or nil
end
local function FromScope(id, class, prop, tok)
    local s = ScopeData(id, false)
    if not s then return nil end
    local parked = tok and T.Parked(tok)
    local cl = type(s.classes) == "table" and type(s.classes[class]) == "table" and s.classes[class][prop]
    if IsCol(cl) and not parked then return cl end
    local tk = tok and type(s.tokens) == "table" and s.tokens[tok]
    if IsCol(tk) and not parked then return tk end
    if type(s.theme) == "string" and s.theme ~= "" then
        local saved = CueRulesDB and CueRulesDB.themes and CueRulesDB.themes[s.theme]
        local sc = type(saved) == "table" and type(saved.classes) == "table" and type(saved.classes[class]) == "table" and saved.classes[class][prop]
        if IsCol(sc) and not parked then return sc end
        local pal = tok and ScopePalette(s.theme)
        if pal and IsCol(pal[tok]) then return pal[tok] end
    end
end

-- today's T.Col (global theme only)
local function GlobalCol(class, prop, fallback)
    local th = CueRulesDB and CueRulesDB.theme
    local def = T.CLASS[class]
    local tok = def and def[3][prop]
    local o = th and th.classes and th.classes[class] and th.classes[class][prop]
    if type(o) == "table" and not (tok and T.Parked(tok)) then return Copy4(o) end
    if tok and T.cur[tok] then return Copy4(T.cur[tok]) end
    return fallback and Copy4(fallback) or { 1, 1, 1, 1 }
end
T.GlobalCol = GlobalCol
function T.Col(class, prop, scope, fallback)
    if type(scope) ~= "string" then return GlobalCol(class, prop, scope) end   -- no scope: exactly as before 0.6.74
    local key = scope .. "\1" .. tostring(class) .. "\1" .. tostring(prop)
    local c = scopeCache[key]
    if c == nil then
        local def = T.CLASS[class]
        local tok = def and def[3][prop]
        local id, seen = scope, {}
        while id and not seen[id] do
            seen[id] = true
            local hit = FromScope(id, class, prop, tok)
            if hit then c = Copy4(hit); break end
            local s = T.scopes[id]
            id = s and s.parent
        end
        scopeCache[key] = c or false
    end
    if c then return Copy4(c) end
    return GlobalCol(class, prop, fallback)
end
-------------------------------------------------------------------------------
-- (#460, core 0.6.81) T.Grad(class, prop [, scope]): the gradient of a class property, or nil when its colour is solid. Resolved the
-- same way as T.Col, first match wins: a class colour of your own (solid) > your gradient for the token (false = solid) > your solid
-- colour for the token > the theme's own gradient; in a scope, its own overrides, then its chosen theme, then its parent's, then the
-- global theme. Returns a fresh { stops = { {r,g,b,a}, ... }, dir = "H" | "V" }, already turned round when the Reverse switch is on.
-- Global answers come from T.curGrad (worked out in T.Resolve); scope answers are cached with the colours and dropped on every Resolve.
-------------------------------------------------------------------------------
local function Oriented(g)
    if not g then return nil end
    local n, rev, stops = #g.stops, T.GradReversed(), {}
    for i = 1, n do stops[i] = Copy4(g.stops[rev and (n + 1 - i) or i]) end
    return { stops = stops, dir = g.dir or "H" }
end
local function GlobalGrad(class, prop)
    local th = CueRulesDB and CueRulesDB.theme
    local def = T.CLASS[class]
    local tok = def and def[3][prop]
    if not tok then return nil end
    local o = th and th.classes and th.classes[class] and th.classes[class][prop]
    if type(o) == "table" and not T.Parked(tok) then return nil end   -- your class colour: solid
    return T.curGrad[tok]
end
local function ScopeGrads(name)
    local key = "\3grads\1" .. name
    local g = scopeCache[key]
    if g == nil then
        g = (name ~= "custom" and T.IsBase(name) or (CueRulesDB and CueRulesDB.themes and CueRulesDB.themes[name])) and T.BaseGrads(name) or false
        scopeCache[key] = g
    end
    return g or NOGRADS
end
-- one scope's own say: decided (true / false), gradient or nil
local function GradFromScope(id, class, prop, tok)
    local s = ScopeData(id, false)
    if not s then return false end
    local parked = tok and T.Parked(tok)
    local cl = type(s.classes) == "table" and type(s.classes[class]) == "table" and s.classes[class][prop]
    if IsCol(cl) and not parked then return true, nil end
    local sg
    if tok and type(s.grads) == "table" then sg = s.grads[tok] end   -- (nil = inherit; false = solid here)
    if sg ~= nil and not parked then return true, CleanGrad(sg) end
    local tk = tok and type(s.tokens) == "table" and s.tokens[tok]
    if IsCol(tk) and not parked then return true, nil end
    if type(s.theme) == "string" and s.theme ~= "" then
        local saved = CueRulesDB and CueRulesDB.themes and CueRulesDB.themes[s.theme]
        local sc = type(saved) == "table" and type(saved.classes) == "table" and type(saved.classes[class]) == "table" and saved.classes[class][prop]
        if IsCol(sc) and not parked then return true, nil end
        local g = tok and ScopeGrads(s.theme)[tok]
        if g then return true, g end
        local pal = tok and ScopePalette(s.theme)
        if pal and IsCol(pal[tok]) then return true, nil end
    end
    return false
end
function T.Grad(class, prop, scope)
    if type(scope) ~= "string" then return Oriented(GlobalGrad(class, prop)) end
    local key = "\3g\1" .. scope .. "\1" .. tostring(class) .. "\1" .. tostring(prop)
    local g = scopeCache[key]
    if g == nil then
        local def = T.CLASS[class]
        local tok = def and def[3][prop]
        local id, seen, hit = scope, {}, false
        while id and not seen[id] do
            seen[id] = true
            local decided, sg = GradFromScope(id, class, prop, tok)
            if decided then hit = true; g = sg or false; break end
            local sc = T.scopes[id]
            id = sc and sc.parent
        end
        if not hit then g = GlobalGrad(class, prop) or false end
        scopeCache[key] = g
    end
    return Oriented(g or nil)
end
T.GlobalGrad = GlobalGrad

-------------------------------------------------------------------------------
-- (#460, core 0.6.81) Drawing a gradient outline. Game API (docs/reference/api/widgets.md, Texture, 12.1.5):
--   SetGradient(orientation: Orientation, minColor: colorRGBA (ColorMixin), maxColor: colorRGBA (ColorMixin)) ·
--     SecretArguments=AllowedWhenUntainted · SimpleTextureBaseAPI
--   SetColorTexture(colorR: number, colorG: number, colorB: number, a: SingleColorValue?) · ChecksForbiddenAspects=[{'Argument':
--     'self', 'Aspect': 'ForbiddenAspect.SetTexture'}], SecretArguments=AllowedWhenTainted · SimpleTextureBaseAPI
--   SetVertexColor(colorR: number, colorG: number, colorB: number, a: SingleColorValue?) · SecretArguments=AllowedWhenTainted,
--     SecretArgumentsAddAspect=[SecretAspect.VertexColor, SecretAspect.Alpha] · SimpleRegionAPI
-- Our colours are plain numbers from the theme (never secret values), on our own textures. CreateColor is Blizzard's ColorMixin
-- constructor (FrameXML, not in the generated documentation; XayaUI already passes it to SetGradient in GameMenuButton.lua and
-- TreePaint.lua, as Blizzard's own nameplate and private aura code does). The same call pattern as those: a white colour texture,
-- then SetGradient. One SetGradient spans two colours, so a gradient of n stops is drawn as n - 1 pieces along the edge.
-- INFERENCE (not documented): "HORIZONTAL" puts minColor on the left; "VERTICAL" puts minColor at the BOTTOM; SetVertexColor sets all
-- four corners and so clears a gradient (a texture going back to a solid colour gets SetVertexColor(1, 1, 1, 1) first).
-- Drawn only when the theme changes or the element is painted (no OnUpdate); a frame whose pieces depend on its size (3 or more stops)
-- lays them out again from an OnSizeChanged hook, which returns at once once the frame is solid again.
-------------------------------------------------------------------------------
local CLEAR = { 0, 0, 0, 0 }
local function GradOn(tex, orient, a, b)
    tex:SetColorTexture(1, 1, 1, 1)
    tex:SetGradient(orient, CreateColor(a[1], a[2], a[3], a[4] or 1), CreateColor(b[1], b[2], b[3], b[4] or 1))
    tex.xuiGrad = { orient, a, b }   -- what was drawn (the walkthrough reads it back; GetVertexColor cannot tell a gradient's ends apart)
end
local function SolidOn(tex, c)
    if tex.xuiGrad then tex:SetVertexColor(1, 1, 1, 1); tex.xuiGrad = nil end
    tex:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
end
-- stops drawn along region R (axis "H": left to right, "V": top to bottom) by pieces made on host (layer / sublevel as the edge's)
local function Strip(host, list, R, axis, stops, layer, sub)
    local n = #stops - 1
    local len
    if axis == "H" then len = R:GetWidth() else len = R:GetHeight() end
    len = tonumber(len) or 0
    for i = 1, n do
        local s = list[i]
        if not s then s = host:CreateTexture(nil, layer or "BACKGROUND", nil, sub); s.xuiOwn = true; list[i] = s end
        s:ClearAllPoints()
        local a0, a1 = len * (i - 1) / n, len * i / n
        if axis == "H" then
            s:SetPoint("TOPLEFT", R, "TOPLEFT", a0, 0)
            if i == n then s:SetPoint("BOTTOMRIGHT", R, "BOTTOMRIGHT", 0, 0) else s:SetPoint("BOTTOMRIGHT", R, "BOTTOMLEFT", a1, 0) end
            GradOn(s, "HORIZONTAL", stops[i], stops[i + 1])
        else
            s:SetPoint("TOPLEFT", R, "TOPLEFT", 0, -a0)
            if i == n then s:SetPoint("BOTTOMRIGHT", R, "BOTTOMRIGHT", 0, 0) else s:SetPoint("BOTTOMRIGHT", R, "TOPRIGHT", 0, -a1) end
            GradOn(s, "VERTICAL", stops[i + 1], stops[i])   -- (INFERENCE above: VERTICAL's minColor is the bottom)
        end
        s:Show()
    end
    for i = n + 1, #list do list[i]:Hide() end
end
local function HideList(list) for _, s in ipairs(list or NOGRADS) do s:Hide() end end
-- one OnSizeChanged hook per host frame, running the relays registered on it (set only while a 3+ stop gradient is drawn there)
local function Relay(host, key, fn)
    host.xuiGradRelay = host.xuiGradRelay or {}
    host.xuiGradRelay[key] = fn
    if fn and not host.xuiGradHooked and host.HookScript then
        host.xuiGradHooked = true
        host:HookScript("OnSizeChanged", function(self)
            local r = self.xuiGradRelay
            if r then for _, f in pairs(r) do pcall(f) end end
        end)
    end
end

-- A 1-px box outline on f: edges = { top, bottom, left, right } (textures the caller anchored), solid = {r,g,b,a}, grad = T.Grad(...)
-- or nil. Solid: exactly the calls the outline always had (SetColorTexture, Show). Gradient "H": top and bottom edges carry it from
-- left to right, the left edge is the first colour and the right edge the last; "V": the same turned a quarter (top to bottom).
function T.PaintEdges(f, edges, solid, grad, layer, sub)
    local st = f.xuiGradE
    if not grad then
        for _, e in ipairs(edges) do SolidOn(e, solid); e:Show() end
        if st then st.on = nil; for _, l in ipairs(st.segs) do HideList(l) end; Relay(f, "box", nil) end
        return
    end
    if not st then st = { segs = { {}, {}, {}, {} } }; f.xuiGradE = st end
    st.on = true
    local stops, axis = grad.stops, (grad.dir == "V") and "V" or "H"
    local first, last = stops[1], stops[#stops]
    local function lay()
        if not st.on then return end
        if axis == "H" then
            Strip(f, st.segs[1], edges[1], "H", stops, layer, sub); Strip(f, st.segs[2], edges[2], "H", stops, layer, sub)
            HideList(st.segs[3]); HideList(st.segs[4])
        else
            Strip(f, st.segs[3], edges[3], "V", stops, layer, sub); Strip(f, st.segs[4], edges[4], "V", stops, layer, sub)
            HideList(st.segs[1]); HideList(st.segs[2])
        end
    end
    if axis == "H" then
        SolidOn(edges[1], CLEAR); SolidOn(edges[2], CLEAR); SolidOn(edges[3], first); SolidOn(edges[4], last)
    else
        SolidOn(edges[3], CLEAR); SolidOn(edges[4], CLEAR); SolidOn(edges[1], first); SolidOn(edges[2], last)
    end
    for _, e in ipairs(edges) do e:Show() end
    lay()
    Relay(f, "box", (#stops > 2) and lay or nil)
end
-- the pieces of a box outline hidden (the element was released or its box hidden)
function T.HideGrad(f)
    local st = f and f.xuiGradE
    if st then st.on = nil; for _, l in ipairs(st.segs) do HideList(l) end; Relay(f, "box", nil) end
    local own = f and f.xuiGradBox
    if own then for _, e in ipairs(own) do e:Hide() end end
end
-- four 1-px edges of f's own (for a frame whose outline is a backdrop, which cannot take a gradient: the window frame)
function T.EdgeBox(f, layer, sub)
    local e = f.xuiGradBox
    if not e then
        e = {}
        for i = 1, 4 do e[i] = f:CreateTexture(nil, layer or "BORDER", nil, sub); e[i].xuiOwn = true end
        e[1]:SetPoint("TOPLEFT", 0, 0); e[1]:SetPoint("TOPRIGHT", 0, 0); e[1]:SetHeight(1)
        e[2]:SetPoint("BOTTOMLEFT", 0, 0); e[2]:SetPoint("BOTTOMRIGHT", 0, 0); e[2]:SetHeight(1)
        e[3]:SetPoint("TOPLEFT", 0, 0); e[3]:SetPoint("BOTTOMLEFT", 0, 0); e[3]:SetWidth(1)
        e[4]:SetPoint("TOPRIGHT", 0, 0); e[4]:SetPoint("BOTTOMRIGHT", 0, 0); e[4]:SetWidth(1)
        f.xuiGradBox = e
    end
    return e
end
-- A line (a pane divider, a group's top line): the gradient runs along its own length (axis "H" for a horizontal line, "V" for a
-- vertical one), first colour at its left / top. Call it after the line is placed and shown; solid = exactly SetColorTexture.
function T.PaintLine(host, tex, solid, grad, axis, layer, sub)
    local st = tex.xuiGradL
    if not grad then
        SolidOn(tex, solid)
        if st then st.on = nil; HideList(st.segs); Relay(host, tex, nil) end
        return
    end
    if not st then st = { segs = {} }; tex.xuiGradL = st end
    st.on = true
    SolidOn(tex, CLEAR)
    local stops = grad.stops
    local function lay() if st.on and tex:IsShown() then Strip(host, st.segs, tex, axis, stops, layer, sub) else HideList(st.segs) end end
    lay()
    Relay(host, tex, (#stops > 2) and lay or nil)
end
function T.HideLineGrad(host, tex)
    local st = tex and tex.xuiGradL
    if st then st.on = nil; HideList(st.segs); if host then Relay(host, tex, nil) end end
end

-- where a scope's colour comes from: the scope id that decided it, or "global" (for tests and the later "Comes from" column)
function T.ColFrom(class, prop, scope)
    local def = T.CLASS[class]
    local tok = def and def[3][prop]
    local id, seen = scope, {}
    while type(id) == "string" and not seen[id] do
        seen[id] = true
        if FromScope(id, class, prop, tok) then return id end
        local s = T.scopes[id]
        id = s and s.parent
    end
    return "global"
end

-- writing a scope's overrides (sparse: emptied tables are removed again)
local function Tidy(id)
    local th = CueRulesDB and CueRulesDB.theme
    local all = type(th) == "table" and th.scopes
    if type(all) ~= "table" then return end
    local s = all[id]
    if type(s) == "table" then
        if type(s.classes) == "table" then
            for cls, props in pairs(s.classes) do if type(props) ~= "table" or next(props) == nil then s.classes[cls] = nil end end
            if next(s.classes) == nil then s.classes = nil end
        end
        if type(s.tokens) == "table" and next(s.tokens) == nil then s.tokens = nil end
        if type(s.grads) == "table" and next(s.grads) == nil then s.grads = nil end
        if s.theme == nil and s.tokens == nil and s.classes == nil and s.grads == nil then all[id] = nil end
    end
    if next(all) == nil then th.scopes = nil end
end
function T.SetScopeTheme(id, name)
    if type(id) ~= "string" then return end
    if name ~= nil and type(name) ~= "string" then return end
    local s = ScopeData(id, name ~= nil)
    if s then s.theme = name end
    Tidy(id); T.Changed()
end
function T.SetScopeToken(id, key, c)
    if type(id) ~= "string" or not T.TOKEN[key] then return end
    local s = ScopeData(id, c ~= nil)
    if s then
        if IsCol(c) then s.tokens = type(s.tokens) == "table" and s.tokens or {}; s.tokens[key] = CleanCol(c)
        elseif type(s.tokens) == "table" then s.tokens[key] = nil end
    end
    Tidy(id); T.Changed()
end
-- (#472) several palette colours of a scope at once, one repaint (the Esc Menu's "Use my own colors" fold): { [token] = colour }
function T.SetScopeTokens(id, toks)
    if type(id) ~= "string" or type(toks) ~= "table" then return end
    local s
    for key, c in pairs(toks) do
        if T.TOKEN[key] and IsCol(c) then
            s = s or ScopeData(id, true)
            if s then s.tokens = type(s.tokens) == "table" and s.tokens or {}; s.tokens[key] = CleanCol(c) end
        end
    end
    Tidy(id); T.Changed()
end
-- (#460) a scope's gradient for a token: a gradient, false (solid here) or nil (inherit)
function T.SetScopeTokenGradient(id, key, g)
    if type(id) ~= "string" or not T.TOKEN[key] then return end
    local s = ScopeData(id, g ~= nil)
    if s then
        local v
        if g == false then v = false else v = CleanGrad(g) end
        if v ~= nil then s.grads = type(s.grads) == "table" and s.grads or {}; s.grads[key] = v
        elseif type(s.grads) == "table" then s.grads[key] = nil end
    end
    Tidy(id); T.Changed()
end
function T.SetScopeClassColor(id, class, prop, c)
    if type(id) ~= "string" or not (T.CLASS[class] and T.CLASS[class][3][prop]) then return end
    local s = ScopeData(id, c ~= nil)
    if s then
        if IsCol(c) then
            s.classes = type(s.classes) == "table" and s.classes or {}
            s.classes[class] = type(s.classes[class]) == "table" and s.classes[class] or {}
            s.classes[class][prop] = CleanCol(c)
        elseif type(s.classes) == "table" and type(s.classes[class]) == "table" then s.classes[class][prop] = nil end
    end
    Tidy(id); T.Changed()
end
function T.ResetScope(id)
    local th = CueRulesDB and CueRulesDB.theme
    if type(th) == "table" and type(th.scopes) == "table" then th.scopes[id] = nil end
    Tidy(id); T.Changed()
end

-------------------------------------------------------------------------------
-- (#472, core 0.6.82) Element scopes in use: helpers for the elements' paint code and the Blizzard Reskin > Theme page.
--   T.ScopeCol(class, prop, scope)   the colour only when a scope decides it (its own override or chosen theme), else nil: an element
--                                    whose look today is not the theme's (fixed colours, its own settings) keeps it unless overridden
--   T.ScopeTok(tok, scope)           the same for a palette colour (token) on its own; T.TokCol(tok, scope) falls back to the global one
--   T.ScopeOverrides(id)             how many single colours the element itself overrides (palette colours, class colours, gradients)
--   T.ScopeComesFrom(id)             who decides the element's look: the scope id (its own overrides or theme, or a parent's), "own"
--                                    (the element draws colours of its own: def.own), or "global"
--   T.ResetAllScopes()               every element's overrides and theme gone (the Theme page's "Reset all overrides"); Settings >
--                                    Theme's "Reset everything" (T.ResetAll) leaves them (open question C15; recommended "global only")
-------------------------------------------------------------------------------
local function TokFromScope(id, tok)
    local s = ScopeData(id, false)
    if not s then return nil end
    local tk = type(s.tokens) == "table" and s.tokens[tok]
    if IsCol(tk) and not T.Parked(tok) then return tk end
    if type(s.theme) == "string" and s.theme ~= "" then
        local pal = ScopePalette(s.theme)
        if pal and IsCol(pal[tok]) then return pal[tok] end
    end
end
function T.ScopeTok(tok, scope)
    if type(scope) ~= "string" or not T.TOKEN[tok] then return nil end
    local id, seen = scope, {}
    while type(id) == "string" and not seen[id] do
        seen[id] = true
        local hit = TokFromScope(id, tok)
        if hit then return Copy4(hit) end
        local sc = T.scopes[id]
        id = sc and sc.parent
    end
    return nil
end
function T.TokCol(tok, scope)
    local c = T.ScopeTok(tok, scope)
    if c then return c end
    local g = T.cur[tok]
    return g and Copy4(g) or nil
end
function T.ScopeCol(class, prop, scope)
    if type(scope) ~= "string" or T.ColFrom(class, prop, scope) == "global" then return nil end
    return T.Col(class, prop, scope)
end
local function HasData(s)
    return type(s) == "table" and ((type(s.theme) == "string" and s.theme ~= "") or (type(s.tokens) == "table" and next(s.tokens) ~= nil)
        or (type(s.classes) == "table" and next(s.classes) ~= nil) or (type(s.grads) == "table" and next(s.grads) ~= nil)) and true or false
end
function T.ScopeOverrides(id)
    local s = ScopeData(id, false)
    if type(s) ~= "table" then return 0 end
    local n = 0
    if type(s.tokens) == "table" then for k, c in pairs(s.tokens) do if T.TOKEN[k] and IsCol(c) then n = n + 1 end end end
    if type(s.classes) == "table" then
        for cls, props in pairs(s.classes) do
            if T.CLASS[cls] and type(props) == "table" then for prop, c in pairs(props) do if T.CLASS[cls][3][prop] and IsCol(c) then n = n + 1 end end end
        end
    end
    if type(s.grads) == "table" then for k in pairs(s.grads) do if T.TOKEN[k] then n = n + 1 end end end
    return n
end
function T.ScopeComesFrom(id)
    local cur, seen = id, {}
    while type(cur) == "string" and not seen[cur] do
        seen[cur] = true
        if HasData(ScopeData(cur, false)) then return cur end
        local sc = T.scopes[cur]
        cur = sc and sc.parent
    end
    local def = T.scopes[id]
    if def and def.own then local ok, v = pcall(def.own); if ok and v then return "own" end end
    return "global"
end
function T.HasScopes()
    local th = CueRulesDB and CueRulesDB.theme
    return type(th) == "table" and type(th.scopes) == "table" and next(th.scopes) ~= nil
end
function T.ResetAllScopes()
    local th = CueRulesDB and CueRulesDB.theme
    if type(th) == "table" then th.scopes = nil end
    T.Changed()
end

-- The Platform's own scopes: the Blizzard Reskin tab as a whole (the parent of its pages; the tab and its switch are the Platform's,
-- Modules.lua ns.ReskinTabOn, so the parent exists whichever module adds a page) and the settings window. The pages register their
-- own scopes from the module that owns each page. (#472) "reskin" is the module level: nothing writes it until open question B5 / Q7
-- (module then element, or element only) is answered; the Blizzard Reskin > Theme page lists the elements only.
T.RegisterScope({ id = "reskin", label = "Blizzard Reskin" })
T.RegisterScope({ id = "settings", label = "Settings window" })

-- (core 0.6.74; plan 6.1) the profile part "Themes": the active theme (with its scopes) and the saved themes
if ns.RegisterProfilePart then
    ns.RegisterProfilePart({ key = "themes", label = "Themes", module = "XayaUI", order = 20, version = 1, db = { "theme", "themes" } })
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
