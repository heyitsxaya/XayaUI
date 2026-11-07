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
-- one built-in theme per gradient, offered after the color blind ones (the Theme page lists T.BUILTIN_ORDER)
for _, key in ipairs(T.CURSOR_PRESET_ORDER) do
    local p = T.CURSOR_PRESETS[key]
    -- (core 0.6.54) the gradient's name alone (Xaya 2026-11-06: "theme names should drop "cursor theme:" prefix", her screenshot of
    -- the Theme list showing "Cursor trail: Fel" ... "Cursor trail: Frost")
    T.BUILTIN["cursor_" .. key] = { name = p[1], pal = T.CursorPalette(p[2]), cursorPreset = key }
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

-------------------------------------------------------------------------------
-- Resolve: palette + overrides -> T.cur, then push into every bound table
-------------------------------------------------------------------------------
T.cur = {}
for _, t in ipairs(T.TOKENS) do T.cur[t[1]] = Copy4(t[4]) end
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
        local v = (th and not T.Parked(k) and th.tokens[k]) or pal[k] or t[4]
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
-- A name a theme can be saved under (1-40 characters, not a built-in theme's key). Returns the trimmed name, or nil and why.
function T.CheckName(name)
    name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" or T.IsBase(name) or #name > 40 then return nil, "Pick a name (1-40 characters, not a built-in theme name)." end
    return name
end
function T.SavedExists(name) local n = T.CheckName(name); return n ~= nil and CueRulesDB and CueRulesDB.themes and CueRulesDB.themes[n] ~= nil end
-- FA-8 (core 0.6.62; Xaya 2026-11-07: "1 or add as name (1) name (2) etc", then "Replace, Save As Copy, Cancel"): the first free
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
-- audit D6 (core 0.6.62): a name that is already saved is refused unless replace is true (before: it was replaced silently and the
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
-- FA-4 (core 0.6.62; Xaya: "Ask first"): are there colors of your own that switching or resetting would throw away? Colors identical
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
    if not (next(th.tokens or {}) or next(th.classes or {})) then return false end
    local now = Snapshot()
    for _, sv in pairs(CueRulesDB and CueRulesDB.themes or {}) do
        if type(sv) == "table" and Same(now.tokens or {}, sv.tokens or {}) and Same(now.classes or {}, sv.classes or {}) then return false end
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
-- audit D5 (core 0.6.62): the name is checked BEFORE anything changes; a refused name or (without opts.replace) a name already saved
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
-- Boot: resolve once the saved variables exist, and again when the class is known
-------------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function() pcall(T.Resolve) end)

-- shared with the settings window's editor (ThemeEditor.lua); read-only
ns.ThemeShared = { DB = DB, T = T, floor = floor, max = max, min = min }
