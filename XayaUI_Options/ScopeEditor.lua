-------------------------------------------------------------------------------
-- ScopeEditor.lua : Blizzard Reskin > Theme (part of the settings window, XayaUI_Options; Options 0.6.104, #472).
-- Xaya, 2026-11-07 (her words, docs/plans/PLATFORM-SPLIT-2026-11-07.md section 6.6): "I think we also need to enable individual element
-- themeing and overrides somewhere -- let's make that part of our rebuild as we configure proper plumbing. Perhaps Blizzard Reskin has
-- a theme selector that compiles all elements that are overhauled and each has a theme override? The XayaUI Settings Theme can be the
-- initial fallback but users can customize at different levels of granularity?"
-- The page as the plan describes it: "a table of every restyled element with the columns Element | Theme (Inherit / any built-in or
-- saved theme) | Overrides (count, Edit) | Comes from (Global / Blizzard Reskin / this element) | Reset. Each element's own page also
-- gets one 'Theme' row linking to it." Her answers: Q8 "Both" (pick a whole theme and/or edit single colours), Q9 "Both" (the table and a
-- row on each element's page). Plan risk R9: one "Reset all overrides".
-- Element level only: the module level ("all of Blizzard Reskin in theme X") waits for open question B5 / Q7, so "Comes from" shows
-- Global or this element ("Blizzard Reskin" exists only at module level).
-- The elements are the theme scopes the modules registered (core Theme.lua T.RegisterScope): a module that is off registered none, and
-- with no restyled element at all there is no page. Storage, resolution and the paint plumbing: core Theme.lua (scopes section).
-- Settings > Theme stays the global fallback; its "Reset everything" leaves these (open question C15, recommended "global only").
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns
local S = ns.ThemeShared
if not S then return end
local T, floor = S.T, S.floor

local SE = { editing = nil }   -- the element whose editor is open (session only)
ns.OptionsApi = ns.OptionsApi or {}
ns.OptionsApi.ScopeEditor = SE
SE.PAGE = "rsktheme"
-- the cells of one table row (Skin.lua arg.xuiCell / xuiSubCell): Element | Theme | Overrides (count, Edit) | Comes from | Reset.
-- Together 0.99 of the page, as the Theme page's class table (rounding never pushes Reset past the edge).
local W = { el = 0.24, theme = 0.30, n = 0.07, edit = 0.12, from = 0.14, reset = 0.12 }
SE.WIDTHS = W
local CELL, SUB, BTN = { xuiCell = true }, { xuiCell = true, xuiSubCell = true, xuiWide = true }, { xuiCell = true, xuiWide = true }

-- the restyled elements: every registered scope but the module level ("reskin": B5), by label
function SE.Elements()
    local out = {}
    for _, id in ipairs(T.scopeList or {}) do
        local d = T.scopes[id]
        if d and id ~= "reskin" then out[#out + 1] = d end
    end
    table.sort(out, function(a, b) local x, y = a.label:lower(), b.label:lower(); if x ~= y then return x < y end; return a.id < b.id end)
    return out
end
local function HasElements()
    for _, id in ipairs(T.scopeList or {}) do local d = T.scopes[id]; if d and d.parent == "reskin" then return true end end
    return false
end

-- Theme column: Inherit, then every built-in theme, then the saved ones (as Settings > Theme lists them)
function SE.ThemeValues()
    local v = { inherit = "Inherit", default = "XUI default (purple)", class = "Class colors" }
    for _, k in ipairs(T.BUILTIN_ORDER) do v[k] = T.BUILTIN[k].name end
    for _, n in ipairs(T.SavedNames()) do v["saved:" .. n] = "Saved: " .. n end
    return v
end
function SE.ThemeSorting()
    local s = { "inherit", "default", "class" }
    for _, k in ipairs(T.BUILTIN_ORDER) do s[#s + 1] = k end
    for _, n in ipairs(T.SavedNames()) do s[#s + 1] = "saved:" .. n end
    return s
end
function SE.GetTheme(id)
    local d = T.ScopeData(id)
    local n = type(d) == "table" and d.theme
    if type(n) ~= "string" or n == "" then return "inherit" end
    if T.IsBase(n) then return n end
    return "saved:" .. n
end
function SE.SetTheme(id, v)
    if v == "inherit" or v == nil then T.SetScopeTheme(id, nil); return end
    local saved = type(v) == "string" and v:match("^saved:(.+)$")
    T.SetScopeTheme(id, saved or v)
end
-- Comes from column
function SE.ComesFrom(id)
    local f = T.ScopeComesFrom(id)
    if f == "global" then return "Global" end
    if f == id or f == "own" then return "this element" end
    local d = T.scopes[f]
    return d and d.label or tostring(f)   -- a parent's data (only from an imported profile until B5): named as it is
end
local function HasOwn(id)
    local d = T.ScopeData(id)
    return type(d) == "table" and next(d) ~= nil
end
function SE.Open(id, Notify)
    SE.editing = id
    if Notify then Notify() end
end
function SE.OpenFromPage(id)
    SE.editing = id
    if ns.OpenSettingsPage then ns.OpenSettingsPage("reskin", SE.PAGE) end
end

-- the per-element editor (Q8 "Both"): its theme, then single colours, the way Settings > Theme edits the global ones (palette; class
-- overrides with Advanced customization). A colour shows what the element draws now (its own, its theme's, else the global one).
local function Editor(Notify)
    local function shut() return SE.editing == nil or T.scopes[SE.editing] == nil end
    local g = { type = "group", order = 100, inline = true, hidden = shut, args = {},
        name = function() local d = SE.editing and T.scopes[SE.editing]; return d and d.label or "" end }
    local a = g.args
    local o = 0
    local function nx() o = o + 1; return o end
    a.theme = { type = "select", order = nx(), width = "double", name = "Theme",
        desc = "Inherit follows Settings > Theme; any other theme applies to this element only.",
        values = SE.ThemeValues, sorting = SE.ThemeSorting,
        get = function() return SE.editing and SE.GetTheme(SE.editing) or "inherit" end,
        set = function(_, v) if SE.editing then SE.SetTheme(SE.editing, v) end end }
    a.palHdr = { type = "header", order = nx(), name = "Palette" }
    local lastGroup
    for _, t in ipairs(T.TOKENS) do
        local key, label, grp, hint = t[1], t[2], t[3], t[5]
        if grp ~= lastGroup then
            lastGroup = grp
            a["grp_" .. grp] = { type = "description", order = nx(), width = "full", fontSize = "medium",
                hidden = function()
                    for _, t2 in ipairs(T.TOKENS) do if t2[3] == grp and not T.Parked(t2[1]) then return false end end
                    return true
                end,
                name = function() local c = T.Col("xui-label", "text", { 1, 0.82, 0, 1 }); return ("|cff%02x%02x%02x"):format(floor(c[1] * 255 + 0.5), floor(c[2] * 255 + 0.5), floor(c[3] * 255 + 0.5)) .. grp .. "|r" end }
        end
        a["tok_" .. key] = { type = "color", order = nx(), width = "normal", name = label, desc = hint, hasAlpha = true,
            hidden = function() return T.Parked(key) end,
            get = function() local c = SE.editing and T.TokCol(key, SE.editing) or T.cur[key]; c = c or { 1, 1, 1, 1 }; return c[1], c[2], c[3], c[4] end,
            set = function(_, r, gg, b, al) if SE.editing then T.SetScopeToken(SE.editing, key, { r, gg, b, al }) end end }
    end
    -- class overrides (Advanced customization, as on Settings > Theme): one table row per class, Background | Border | Text | Reset
    local SW, RW = 0.27, 0.18
    local ov = { type = "group", order = nx(), name = "Class overrides", inline = true, hidden = function() return not (T.SHOW_OVERRIDES or T.Advanced()) end, args = {} }
    local po = 0
    for _, c in ipairs(T.CLASSES) do
        local cls, label, map = c[1], c[2], c[3]
        local box = { type = "group", order = po + 1, name = label .. "  |cff888888(" .. cls .. ")|r", inline = true, args = {} }
        local io = 0
        for k, prop in ipairs({ "bg", "border", "text" }) do
            local tok = map[prop]
            if tok then
                io = io + 1
                box.args[prop] = { type = "color", order = k, width = "relative", relWidth = SW, arg = CELL, hasAlpha = true,
                    name = (prop == "bg") and "Background" or (prop == "border" and "Border" or "Text"),
                    hidden = function() return T.Parked(tok) end,
                    get = function() local col = T.Col(cls, prop, SE.editing or "settings"); return col[1], col[2], col[3], col[4] end,
                    set = function(_, r, gg, b, al) if SE.editing then T.SetScopeClassColor(SE.editing, cls, prop, { r, gg, b, al }) end end }
            end
            box.args[prop .. "_cell"] = { type = "description", order = k + 0.5, width = "relative", relWidth = SW, arg = CELL, name = "",
                hidden = function() return tok ~= nil and not T.Parked(tok) end }
        end
        if io > 0 then
            po = po + 1
            box.args.reset = { type = "execute", order = 9, width = "relative", relWidth = RW, arg = BTN, name = "Reset",
                func = function()
                    if not SE.editing then return end
                    for prop in pairs(map) do T.SetScopeClassColor(SE.editing, cls, prop, nil) end
                end }
            ov.args[cls] = box
        end
    end
    a.overrides = ov
    a.close = { type = "execute", order = nx(), name = "Close", desc = "Closes this editor; what you set stays.",
        func = function() SE.editing = nil; if Notify then Notify() end end }
    return g
end

-- the page
function SE.Build(Notify)
    if not HasElements() then return nil end   -- no module restyles anything: no page (V14)
    local args = {}
    local o = 0
    local function nx() o = o + 1; return o end
    local function head(key, name, w)
        args[key] = { type = "description", order = nx(), width = "relative", relWidth = w, arg = CELL, fontSize = "medium",
            name = function() local c = T.Col("xui-label", "text", "settings", { 1, 0.82, 0, 1 }); return ("|cff%02x%02x%02x"):format(floor(c[1] * 255 + 0.5), floor(c[2] * 255 + 0.5), floor(c[3] * 255 + 0.5)) .. name .. "|r" end }
    end
    head("h_el", "Element", W.el); head("h_theme", "Theme", W.theme); head("h_n", "Overrides", W.n + W.edit)
    head("h_from", "Comes from", W.from); head("h_reset", "Reset", W.reset)
    for _, d in ipairs(SE.Elements()) do
        local id = d.id
        local k = id:gsub("[^%w]", "_")
        args["el_" .. k] = { type = "description", order = nx(), width = "relative", relWidth = W.el, arg = CELL, fontSize = "medium", name = d.label }
        args["th_" .. k] = { type = "select", order = nx(), width = "relative", relWidth = W.theme, arg = CELL, name = "",
            desc = "Inherit follows Settings > Theme; any other theme applies to " .. d.label .. " only.",
            values = SE.ThemeValues, sorting = SE.ThemeSorting,
            get = function() return SE.GetTheme(id) end, set = function(_, v) SE.SetTheme(id, v) end }
        args["n_" .. k] = { type = "description", order = nx(), width = "relative", relWidth = W.n, arg = CELL, fontSize = "medium",
            name = function() return tostring(T.ScopeOverrides(id)) end }
        args["ed_" .. k] = { type = "execute", order = nx(), width = "relative", relWidth = W.edit, arg = SUB, name = "Edit",
            desc = "Opens " .. d.label .. "'s own theme and colors below.", func = function() SE.Open(id, Notify) end }
        args["cf_" .. k] = { type = "description", order = nx(), width = "relative", relWidth = W.from, arg = CELL, fontSize = "medium",
            name = function() return SE.ComesFrom(id) end }
        args["rs_" .. k] = { type = "execute", order = nx(), width = "relative", relWidth = W.reset, arg = BTN, name = "Reset",
            desc = "Removes " .. d.label .. "'s own theme and colors: it follows Settings > Theme again.",
            disabled = function() return not HasOwn(id) end,
            func = function() T.ResetScope(id) end }
    end
    args.resetAll = { type = "execute", order = nx(), name = "Reset all overrides",
        desc = "Removes every element's own theme and colors on this page. Settings > Theme is not changed.",
        confirm = function() return "Reset every element on this page to Settings > Theme?" end,
        disabled = function() return not T.HasScopes() end,
        func = function() SE.editing = nil; T.ResetAllScopes() end }
    args.editor = Editor(Notify)
    return { type = "group", name = "Theme", args = args }
end

-- (Q9 "Both") one "Theme" row on each element's own page, opening its editor on this page. Added by the settings window to the pages
-- of the Blizzard Reskin tab whose element registered its page key (T.RegisterScope page = ...).
function SE.AddRows(args)
    if type(args) ~= "table" or not args[SE.PAGE] then return end
    for _, id in ipairs(T.scopeList or {}) do
        local d = T.scopes[id]
        local page = d and d.page and args[d.page]
        if page and type(page.args) == "table" then
            page.args.xuiTheme = { type = "execute", order = d.rowOrder or 0.5, name = "Theme",
                desc = "Opens this page's theme and colors on Blizzard Reskin > Theme.",
                func = function() SE.OpenFromPage(id) end }
        end
    end
end

ns.RegisterSettingsPage("reskin", SE.PAGE, SE.Build)
