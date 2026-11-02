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
-- Base themes:  "default" (XUI purple)  |  "class" (follows the character's class color, or a class picked by hand)  |  a saved theme.
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
T.PARKED = { windowBg = true, paneBg = true, tabBg = true, tabBorder = true, tabSelBg = true, tabSelBorder = true, treeBar = true, text = true }
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

function T.BasePalette(base, classPick)
    if base == "class" then return T.ClassPalette(classPick or T.PlayerClass()) end
    local saved = CueRulesDB and CueRulesDB.themes and CueRulesDB.themes[base]
    if saved then return T.SavedPalette(saved) end
    return {}
end

function T.SavedPalette(saved)
    local pal = {}
    local under = (saved.base == "class") and T.ClassPalette(saved.classPick or T.PlayerClass()) or {}
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
        if T.liveDirty and ns.DecorateTrees then T.liveDirty = false; pcall(ns.DecorateTrees) end
        if ColorPickerFrame:IsShown() then return end
        t:Cancel(); qticker = nil
        local q = queue; queue = {}
        for f in pairs(q) do pcall(f) end
    end)
end
function T.UINotify()
    if ns.UI and ns.UI.Notify then ns.UI.Notify() end
    if ns.DecorateTrees then pcall(ns.DecorateTrees) end
end
function T.Changed()
    T.Resolve()
    T.Defer(T.UINotify)
    if ns.MarkDirty then ns.MarkDirty() end
end

function T.SetBase(base, classPick)
    local th = DB(); if not th then return end
    th.base = base
    th.classPick = classPick
    th.tokens = {}   -- a new base starts clean; individual colors are re-picked on top of it
    th.classes = {}
    T.Changed()
end
function T.SetToken(key, c)
    local th = DB(); if not (th and T.TOKEN[key]) then return end
    th.tokens[key] = { Clamp01(c[1]), Clamp01(c[2]), Clamp01(c[3]), Clamp01(c[4] == nil and 1 or c[4]) }
    T.Changed()
end
function T.ResetToken(key) local th = DB(); if th then th.tokens[key] = nil; T.Changed() end end
function T.SetClassColor(class, prop, c)
    local th = DB(); if not (th and T.CLASS[class] and T.CLASS[class][3][prop]) then return end
    th.classes[class] = th.classes[class] or {}
    th.classes[class][prop] = { Clamp01(c[1]), Clamp01(c[2]), Clamp01(c[3]), Clamp01(c[4] == nil and 1 or c[4]) }
    T.Changed()
end
function T.ResetClass(class) local th = DB(); if th then th.classes[class] = nil; T.Changed() end end
function T.SetFont(key) local th = DB(); if th then th.font = key or "none"; T.Changed() end end
function T.SetSize(sz) local th = DB(); if th and T.SIZES[sz] then th.size = sz; T.Changed() end end
function T.ResetAll()
    local th = DB(); if not th then return end
    th.base, th.classPick, th.tokens, th.classes, th.font, th.size = "class", nil, {}, {}, "none", "M"
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
    return { base = (th.base == "default" or th.base == "class") and th.base or "default", classPick = th.classPick,
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
    if name == "" or name == "default" or name == "class" or #name > 40 then return false, "Pick a name (1-40 characters, not 'default' or 'class')." end
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
-- Import / export:  XUITHEME1:<checksum>:<base64 of JSON>   (data only: never runs code)
-------------------------------------------------------------------------------
local FORMAT = "XUITHEME1"

function T.Export()
    local th = DB(); if not th then return "" end
    local snap = Snapshot()
    snap.v = 1
    local json = ns.Json_Encode and ns.Json_Encode(snap)
    if not json then return "" end
    return FORMAT .. ":" .. ns.Checksum(json) .. ":" .. ns.B64Enc(json)
end

function T.Decode(str)
    str = tostring(str or ""):gsub("%s+", "")
    local head, sum, body = str:match("^([^:]+):([^:]+):(.+)$")
    if head ~= FORMAT then return nil, "This is not an XayaUI theme string (it should start with " .. FORMAT .. ":)." end
    local json = ns.B64Dec and ns.B64Dec(body)
    if not json or json == "" then return nil, "The theme string is damaged (could not be decoded)." end
    if ns.Checksum(json) ~= sum then return nil, "The theme string is damaged or was edited (checksum does not match)." end
    local data = ns.Json_Decode and ns.Json_Decode(json)
    if type(data) ~= "table" then return nil, "The theme string is damaged (not readable)." end
    local clean = { base = (data.base == "class") and "class" or "default", tokens = CleanColors(data.tokens, function(k) return T.TOKEN[k] ~= nil end), classes = {} }
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

-- Applies an imported theme; saveAs (optional) also keeps it under that name.
function T.Import(str, saveAs)
    local data, err = T.Decode(str)
    if not data then return false, err end
    local th = DB(); if not th then return false, "Not ready yet." end
    th.base, th.classPick, th.tokens, th.classes, th.font, th.size = data.base, data.classPick, data.tokens, data.classes, data.font, data.size
    if saveAs and saveAs ~= "" then
        local ok, e2 = T.Save(saveAs)
        if not ok then T.Changed(); return false, e2 end
    end
    T.Changed()
    return true
end

-------------------------------------------------------------------------------
-- Boot: resolve once the saved variables exist, and again when the class is known
-------------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function() pcall(T.Resolve) end)

-------------------------------------------------------------------------------
-- Settings > Theme page (AceConfig args). Options.lua puts this under Settings.
-------------------------------------------------------------------------------
function T.BuildArgs(refresh)
    local rawRefresh = refresh or function() end
    refresh = function() T.Defer(rawRefresh) end
    local args = {}
    local o = 0
    local function nx() o = o + 1; return o end
    local msg = ""
    local function say(m) msg = m or ""; refresh() end

    args.intro = { type = "description", order = nx(), width = "full", fontSize = "medium",
        name = "The style sheet: one palette, plus general classes (window, pane, tab, button, heading, text, rule list ...) that each take their colors from it. Change a color once and everything of that class follows. Class overrides below change just one kind of element." }

    args.baseHdr = { type = "header", order = nx(), name = "Base theme" }
    args.base = { type = "select", order = nx(), width = "double", name = "Theme",
        desc = "XUI default (purple), Class colors (follows your character's class), or a theme you saved or imported.",
        values = function()
            local v = { default = "XUI default (purple)", class = "Class colors" }
            for _, n in ipairs(T.SavedNames()) do v["saved:" .. n] = "Saved: " .. n end
            return v
        end,
        sorting = function()
            local s = { "default", "class" }
            for _, n in ipairs(T.SavedNames()) do s[#s + 1] = "saved:" .. n end
            return s
        end,
        get = function()
            local th = DB(); if not th then return "default" end
            return th.base
        end,
        set = function(_, v)
            local n = v:match("^saved:(.+)$")
            if n then T.Load(n) else T.SetBase(v, v == "class" and (DB() and DB().classPick) or nil) end
            refresh()
        end }
    args.classPick = { type = "select", order = nx(), width = "double", name = "Class color source",
        desc = "Which class color drives the theme. Automatic uses the character you are playing.",
        hidden = function() local th = DB(); return not (th and th.base == "class") end,
        values = function()
            local v = { auto = "Automatic (current character)" }
            for _, f in ipairs({ "DEATHKNIGHT", "DEMONHUNTER", "DRUID", "EVOKER", "HUNTER", "MAGE", "MONK", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR" }) do
                local loc = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[f] or f
                v[f] = loc
            end
            return v
        end,
        sorting = { "auto", "DEATHKNIGHT", "DEMONHUNTER", "DRUID", "EVOKER", "HUNTER", "MAGE", "MONK", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR" },
        get = function() local th = DB(); return th and th.classPick or "auto" end,
        set = function(_, v)
            local th = DB(); if not th then return end
            th.classPick = (v ~= "auto") and v or nil
            T.Resolve(); T.Changed(); refresh()
        end }

    args.fontHdr = { type = "header", order = nx(), name = "Font and size" }
    args.font = { type = "select", order = nx(), width = "double", name = "Font",
        desc = "Applies to the window title, tabs, buttons, and the rule list. Fonts added to the Media/Fonts folder need a full game restart before they load.",
        values = function() local v = ns.FontList and ns.FontList() or { none = "(none)" }; return v end,
        sorting = function() local _, ord = ns.FontList(); return ord end,
        get = function() return T.FontKey() end,
        set = function(_, v) T.SetFont(v); refresh() end }
    args.size = { type = "select", order = nx(), width = "normal", name = "Text size",
        values = { S = "Small", M = "Medium", L = "Large" }, sorting = { "S", "M", "L" },
        get = function() local th = DB(); return th and th.size or "M" end,
        set = function(_, v) T.SetSize(v); refresh() end }

    -- palette
    args.palHdr = { type = "header", order = nx(), name = "Palette" }
    local lastGroup
    for _, t in ipairs(T.TOKENS) do
        local key, label, grp, _, hint = t[1], t[2], t[3], t[4], t[5]
        if not T.PARKED[key] then
        if grp ~= lastGroup then
            lastGroup = grp
            args["grp_" .. grp] = { type = "description", order = nx(), width = "full", fontSize = "medium", name = "|cffffd100" .. grp .. "|r" }
        end
        args["tok_" .. key] = { type = "color", order = nx(), width = "normal", name = label, desc = hint, hasAlpha = true,
            get = function() local c = T.cur[key]; return c[1], c[2], c[3], c[4] end,
            set = function(_, r, g, b, a) T.SetToken(key, { r, g, b, a }); refresh() end }
        end
    end
    args.resetPal = { type = "execute", order = nx(), width = "full", name = "Reset everything",
        desc = "Back to the XUI default theme, game font, Medium size, and no class overrides.",
        func = function() T.ResetAll(); refresh() end }

    -- class overrides
    local ov = { type = "group", order = nx(), name = "Class overrides", inline = true, args = {
        info = { type = "description", order = 0, width = "full",
            name = "Every element belongs to a general class. By default a class takes its color from the palette above; pick a color here to change only that class. 'Reset' returns it to the palette." } } }
    local po = 1
    for _, c in ipairs(T.CLASSES) do
        local cls, label, map = c[1], c[2], c[3]
        local a = { type = "group", order = po, name = label .. "  |cff888888(" .. cls .. ")|r", inline = true, args = {} }
        local io = 0
        for _, prop in ipairs({ "bg", "border", "text" }) do
            if map[prop] and not T.PARKED[map[prop]] then
                io = io + 1
                local pname = (prop == "bg") and "Background" or (prop == "border" and "Border" or "Text")
                a.args[prop] = { type = "color", order = io, width = "normal", name = pname, hasAlpha = true,
                    get = function() local col = T.Col(cls, prop); return col[1], col[2], col[3], col[4] end,
                    set = function(_, r, g, b, al) T.SetClassColor(cls, prop, { r, g, b, al }); refresh() end }
            end
        end
        if io > 0 then
            po = po + 1
            a.args.reset = { type = "execute", order = 9, width = "full", name = "Reset", func = function() T.ResetClass(cls); refresh() end }
            ov.args[cls] = a
        end
    end
    args.overrides = ov

    -- save / import / export
    args.shareHdr = { type = "header", order = nx(), name = "Save, import, and export" }
    local saveName = ""
    args.saveName = { type = "input", order = nx(), width = "normal", name = "Name", get = function() return saveName end, set = function(_, v) saveName = v end }
    args.save = { type = "execute", order = nx(), width = "half", name = "Save",
        func = function() local ok, e = T.Save(saveName); say(ok and ("Saved '" .. saveName .. "'.") or e) end }
    args.delete = { type = "execute", order = nx(), width = "half", name = "Delete saved",
        desc = "Deletes the saved theme with the name typed in the box.",
        func = function() if CueRulesDB.themes[saveName] then T.Delete(saveName); say("Deleted '" .. saveName .. "'.") else say("No saved theme called '" .. saveName .. "'.") end end }
    local exportText = ""
    args.export = { type = "execute", order = nx(), width = "normal", name = "Export current theme",
        func = function() exportText = T.Export(); say("Copy the text from the box below (Ctrl+A, Ctrl+C).") end }
    args.exportBox = { type = "input", order = nx(), width = "full", multiline = 4, name = "Theme string",
        desc = "Export fills this; to import, paste a theme string here and press Import.",
        get = function() return exportText end, set = function(_, v) exportText = v end }
    args.import = { type = "execute", order = nx(), width = "normal", name = "Import theme from box",
        desc = "Applies the pasted theme (and saves it under the Name above if one is typed). Theme strings contain colors, a font name, and a size only.",
        func = function()
            local ok, e = T.Import(exportText, saveName ~= "" and saveName or nil)
            say(ok and "Theme imported." or e)
        end }
    args.status = { type = "description", order = nx(), width = "full", fontSize = "medium", name = function() return msg end }
    return args
end
