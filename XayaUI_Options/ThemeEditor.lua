-------------------------------------------------------------------------------
-- ThemeEditor.lua : Settings > UI Options > Theme (part of the settings window, XayaUI_Options; 0.6.0).
-- Moved out of Theme.lua, which keeps the style sheet itself (tokens, classes, fonts, saved themes, import / export). This file
-- only builds the option rows of the Theme page. Own code. UNTESTED in game.
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns
local S = ns.ThemeShared
local DB, T, floor, max, min = S.DB, S.T, S.floor, S.max, S.min

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
        name = "The style sheet: one palette, plus general classes (window, pane, tab, button, heading, text, rule list ...) that each take their colors from it. Change a color once and everything of that class follows." }

    args.baseHdr = { type = "header", order = nx(), name = "Base theme" }
    args.base = { type = "select", order = nx(), width = "double", name = "Theme",
        desc = "XUI default (purple), Class colors (follows your character's class), Light mode, a color blind safe palette, a theme you saved or imported, or Custom: your own theme, with the addon background and every color yours to set. Changing any color below switches you to Custom automatically.",
        values = function()
            local v = { default = "XUI default (purple)", class = "Class colors", custom = "Custom (make your own)" }
            for _, k in ipairs(T.BUILTIN_ORDER) do v[k] = T.BUILTIN[k].name end
            for _, n in ipairs(T.SavedNames()) do v["saved:" .. n] = "Saved: " .. n end
            return v
        end,
        sorting = function()
            local s = { "default", "class" }
            for _, k in ipairs(T.BUILTIN_ORDER) do s[#s + 1] = k end
            s[#s + 1] = "custom"
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
        hidden = function() return T.EffBase() ~= "class" end,
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

    -- Custom: shown only while Custom is the selected theme. The addon background (window, panes, title bar, borders) and the window
    -- opacity live here; the Palette below keeps the rest of the colors.
    local function notCustom() local th = DB(); return not (th and th.base == "custom") end
    local cust = { type = "group", order = nx(), name = "Custom theme", inline = true, hidden = notCustom, args = {} }
    local co = 0
    local function cx() co = co + 1; return co end
    cust.args.info = { type = "description", order = cx(), width = "full", fontSize = "medium",
        name = "This is your own theme. Set the addon background and window below, then pick any other color in the Palette. Name and Save it at the bottom to keep it, or Export it to share." }
    cust.args.under = { type = "select", order = cx(), width = "double", name = "Start from",
        desc = "The theme your colors sit on top of. Colors you have changed are kept when you pick a different one; 'Clear my colors' removes them.",
        values = function()
            local v = { default = "XUI default (purple)", class = "Class colors" }
            for _, k in ipairs(T.BUILTIN_ORDER) do v[k] = T.BUILTIN[k].name end
            return v
        end,
        sorting = function() local s = { "default", "class" }; for _, k in ipairs(T.BUILTIN_ORDER) do s[#s + 1] = k end; return s end,
        get = function() return T.Under() end,
        set = function(_, v) T.SetUnder(v); refresh() end }
    cust.args.bgHdr = { type = "header", order = cx(), name = "Addon background" }
    local function surf(key, label, hint, alpha)
        cust.args["bg_" .. key] = { type = "color", order = cx(), width = "normal", name = label, desc = hint, hasAlpha = alpha and true or false,
            get = function() local c = T.cur[key]; return c[1], c[2], c[3], c[4] end,
            set = function(_, r, g, b, a) T.SetToken(key, { r, g, b, alpha and a or 1 }); refresh() end }
    end
    surf("windowBg", "Addon background", "Background color of the XayaUI window. How see-through it is comes from Window opacity below.", false)
    surf("paneBg", "Panel background", "Sidebar, option panes, and group boxes.", true)
    surf("titleBar", "Title bar", "The strip behind the window title.", false)
    surf("border", "Borders", "Window and pane outlines.", true)
    cust.args.opacity = { type = "range", order = cx(), width = "double", name = "Window opacity", min = 0.1, max = 1, step = 0.01, isPercent = true,
        desc = "How solid the window background is. Takes effect when the window is next redrawn or reopened.",
        get = function() local u = CueRulesDB and CueRulesDB.ui; return tonumber(u and u.skinAlpha) or 0.62 end,
        set = function(_, v)
            if not CueRulesDB then return end
            CueRulesDB.ui = CueRulesDB.ui or {}
            CueRulesDB.ui.skinAlpha = math.max(0.1, math.min(1, v))
            T.Changed(); refresh()
        end }
    cust.args.clear = { type = "execute", order = cx(), width = "normal", name = "Clear my colors",
        desc = "Removes every color you changed and stays in Custom, starting again from the 'Start from' theme.",
        func = function() T.ClearCustom(); say("Cleared your colors.") end }
    args.custom = cust

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
            args["grp_" .. grp] = { type = "description", order = nx(), width = "full", fontSize = "medium", hidden = function() local th = DB(); return grp == "Surfaces" and th and th.base == "custom" or false end, name = function() local c = T.Col("xui-label", "text", { 1, 0.82, 0, 1 }); return ("|cff%02x%02x%02x"):format(floor(c[1] * 255 + 0.5), floor(c[2] * 255 + 0.5), floor(c[3] * 255 + 0.5)) .. grp .. "|r" end }
        end
        args["tok_" .. key] = { type = "color", order = nx(), width = "normal", name = label, desc = hint, hasAlpha = true,
            hidden = function() local th = DB(); return grp == "Surfaces" and th and th.base == "custom" or false end,
            get = function() local c = T.cur[key]; return c[1], c[2], c[3], c[4] end,
            set = function(_, r, g, b, a)
                local th = DB(); local was = th and th.base ~= "custom"
                T.SetToken(key, { r, g, b, a })
                if was then msg = "Switched to Custom: your colors are kept on top of the previous theme." end
                refresh()
            end }
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
    -- Class overrides are parked (Xaya, 2026-11-01): every box duplicated a palette swatch. The code and any saved overrides stay
    -- (they still apply); only the editor is hidden. Flip T.SHOW_OVERRIDES to bring the editor back for the redesign.
    if T.SHOW_OVERRIDES then args.overrides = ov end

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
