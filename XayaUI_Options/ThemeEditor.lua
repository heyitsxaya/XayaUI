-------------------------------------------------------------------------------
-- ThemeEditor.lua : Settings > UI Options > Theme (part of the settings window, XayaUI_Options; 0.6.0).
-- Moved out of Theme.lua, which keeps the style sheet itself (tokens, classes, fonts, saved themes, import / export). This file
-- only builds the option rows of the Theme page. Own code. UNTESTED in game.
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns
local PlatS = ns.Settings("platform")   -- (Options 0.6.82, P2 settings seam: the same CueRulesDB keys as before; Modules.lua section 0b)
local S = ns.ThemeShared
local DB, T, floor, max, min = S.DB, S.T, S.floor, S.max, S.min

-------------------------------------------------------------------------------
-- Ask dialog (Options 0.6.69): one small window with up to three buttons, in the order given (left to right), so the choices read
-- exactly as decided. Used for FA-4 / FA-13 (Xaya: "Ask first": switching or resetting throws your own colors away) and FA-8 (her
-- answer for a name that is already saved: "Replace, Save As Copy, Cancel"). Esc and the last button close it doing nothing.
-------------------------------------------------------------------------------
local askDlg
function T.Ask(text, buttons)   -- buttons = { { "Label", fn or nil }, ... } (up to 3; a nil fn just closes)
    if not askDlg then
        local f = CreateFrame("Frame", "XayaUIThemeAsk", UIParent, "BackdropTemplate")
        f:SetSize(420, 130); f:SetPoint("CENTER"); f:SetFrameStrata("TOOLTIP"); f:EnableMouse(true)
        if f.SetBackdrop then f:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32, insets = { left = 11, right = 12, top = 12, bottom = 11 } }) end
        f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.text:SetPoint("TOP", 0, -24); f.text:SetWidth(370)
        f.btns = {}
        for i = 1, 3 do
            local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
            b:SetSize(120, 24)
            b:SetScript("OnClick", function(self) f:Hide(); local fn = self.fn; self.fn = nil; if fn then fn() end end)
            if ns.FlatButton then ns.FlatButton(b, i == 1) end
            f.btns[i] = b
        end
        if UISpecialFrames then tinsert(UISpecialFrames, "XayaUIThemeAsk") end
        askDlg = f
    end
    local f = askDlg
    f.text:SetText(text or "")
    local n = math.min(3, #buttons)
    local w, gap = 120, 8
    local x0 = -((n * w + (n - 1) * gap) / 2) + w / 2
    for i = 1, 3 do
        local b = f.btns[i]
        if i <= n then
            b:SetText(buttons[i][1]); b.fn = buttons[i][2]
            b:ClearAllPoints(); b:SetPoint("BOTTOM", f, "BOTTOM", x0 + (i - 1) * (w + gap), 20); b:Show()
        else b.fn = nil; b:Hide() end
    end
    f:Show()
    return f
end
-- run go now, or after "Discard" when your own colors would be thrown away (FA-4 / FA-13)
local function AskDiscard(what, go)
    if not T.UnsavedColors() then go(); return end
    T.Ask(("Discard your custom colors? %s replaces the colors you set (save them first with a Name and Save to keep them)."):format(what),
        { { "Discard", go }, { CANCEL or "Cancel" } })
end
-- a name that is already saved: Replace / Save As Copy / Cancel (FA-8)
local function AskExisting(name, replace, copy)
    T.Ask(('A theme called "%s" is already saved.'):format(name), { { "Replace", replace }, { "Save As Copy", copy }, { CANCEL or "Cancel" } })
end
T.AskDiscard, T.AskExisting = AskDiscard, AskExisting   -- (tests)

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
        desc = "Picks a built-in, saved or imported theme, or Custom to set every color yourself. Changing any color below switches to Custom.",
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
            local th = DB(); if th and th.base == v then return end
            local n = v:match("^saved:(.+)$")
            if v == "custom" then T.SetBase(v); refresh(); return end   -- Custom keeps your colors: nothing to ask
            AskDiscard(n and ("The saved theme '" .. n .. "'") or "Another theme", function()
                if n then T.Load(n) else T.SetBase(v, v == "class" and (DB() and DB().classPick) or nil) end
                refresh()
            end)
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
    -- (#460, Options 0.6.101; Xaya 2026-11-06: "this gradient should be reversible in direction"; her answer 2026-11-07: its own switch,
    -- not the cursor trail's "Reverse colors"). Shown while the theme has a gradient (a cursor trail theme's borders, or one set below).
    args.gradRev = { type = "toggle", order = nx(), width = "full", name = "Reverse gradient direction",
        desc = "Runs this theme's gradients (the window, pane, button and tab borders of a cursor trail theme) the other way round. Separate from the cursor trail's own Reverse colors.",
        hidden = function() return not T.HasGradient() end,
        get = function() return T.GradReversed() end,
        set = function(_, v) T.SetGradReverse(v); refresh() end }

    -- Custom: shown only while Custom is the selected theme. The addon background (window, panes, title bar, borders) and the window
    -- opacity live here; the Palette below keeps the rest of the colors.
    local function notCustom() local th = DB(); return not (th and th.base == "custom") end
    local cust = { type = "group", order = nx(), name = "Custom theme", inline = true, hidden = notCustom, args = {} }
    local co = 0
    local function cx() co = co + 1; return co end
    cust.args.info = { type = "description", order = cx(), width = "full", fontSize = "medium",
        name = "This is your own theme. Set the addon background and window below, then pick any other color in the Palette. Name and Save it at the bottom to keep it, or Export it to share." }
    cust.args.under = { type = "select", order = cx(), width = "double", name = "Start from",
        desc = "Sets the theme your colors sit on top of. Your changed colors are kept; 'Clear my colors' removes them.",
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
        get = function() local u = PlatS.ui; return tonumber(u and u.skinAlpha) or 0.62 end,
        set = function(_, v)
            if not ns.SettingsReady() then return end
            PlatS.ui = PlatS.ui or {}
            PlatS.ui.skinAlpha = math.max(0.1, math.min(1, v))
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
    args.advanced = { type = "toggle", order = nx(), width = "full", name = "Advanced customization",
        desc = "Offers more theme options: tab colors, tree bars, per-class color overrides and the gradient as a color. Off by default.",
        get = function() return T.Advanced() end,
        set = function(_, v)
            if not ns.SettingsReady() then return end
            PlatS.ui = PlatS.ui or {}
            PlatS.ui.themeAdvanced = v and true or nil
            T.Changed(); refresh()
        end }

    -- palette
    args.palHdr = { type = "header", order = nx(), name = "Palette" }
    local lastGroup
    for _, t in ipairs(T.TOKENS) do
        local key, label, grp, _, hint = t[1], t[2], t[3], t[4], t[5]
        do   -- (UI-50) a parked token is listed but hidden until Advanced customization is on
        local parked = T.PARKED[key]
        if grp ~= lastGroup then
            lastGroup = grp
            args["grp_" .. grp] = { type = "description", order = nx(), width = "full", fontSize = "medium", hidden = function()
                    local open = false   -- (UI-50) a group whose colours are all parked shows no heading until Advanced customization is on
                    for _, t2 in ipairs(T.TOKENS) do if t2[3] == grp and not T.Parked(t2[1]) then open = true; break end end
                    if not open then return true end
                    local th = DB(); return grp == "Surfaces" and th and th.base == "custom" or false end, name = function() local c = T.Col("xui-label", "text", { 1, 0.82, 0, 1 }); return ("|cff%02x%02x%02x"):format(floor(c[1] * 255 + 0.5), floor(c[2] * 255 + 0.5), floor(c[3] * 255 + 0.5)) .. grp .. "|r" end }
        end
        args["tok_" .. key] = { type = "color", order = nx(), width = "normal", name = label, desc = hint, hasAlpha = true,
            hidden = function() if parked and T.Parked(key) then return true end local th = DB(); return grp == "Surfaces" and th and th.base == "custom" or false end,
            get = function() local c = T.cur[key]; return c[1], c[2], c[3], c[4] end,
            set = function(_, r, g, b, a)
                local th = DB(); local was = th and th.base ~= "custom"
                T.SetToken(key, { r, g, b, a })
                if was then msg = "Switched to Custom: your colors are kept on top of the previous theme." end
                refresh()
            end }
        end
    end
    -- (#460, Options 0.6.101; Xaya 2026-11-07: "allow in advance settings the user to apply the gradient as a set "color" option to all
    -- elements") Advanced customization only: each palette colour can be set to the theme's gradient (T.SetTokenGradient).
    args.gradTokens = { type = "multiselect", order = nx(), width = "full", name = "Use the gradient as the color of",
        desc = "Sets a palette color to this theme's gradient (a cursor trail theme's trail colors, any other theme's light-to-dark accent colors). Window, pane, button and tab borders draw it as a gradient, anything else shows the color's own solid color, and unticking makes it solid again.",
        hidden = function() return not T.Advanced() end,
        values = function() local v = {}; for _, t in ipairs(T.TOKENS) do v[t[1]] = t[2] end; return v end,
        get = function(_, k) return T.curGrad[k] ~= nil end,
        set = function(_, k, v) T.SetTokenGradient(k, v); refresh() end }
    -- FA-13 (Options 0.6.69; Xaya: "Reword to Class colors (Recommended)"): it resets to Class colors, the theme a new install starts with
    args.resetPal = { type = "execute", order = nx(), width = "full", name = "Reset everything",
        desc = "Back to Class colors (the starting theme), game font, Medium size, and no class overrides.",
        func = function() AskDiscard("Reset everything", function() T.ResetAll(); refresh() end) end }

    -- class overrides
    -- (#471: the table row's cells; together 0.99 of the box. Safe only because each class is its own box, one row per box: in a
    -- container of several rows, a row must add up to 1 (Skin.lua table cells; Options 0.6.105))
    local OV_SWATCH_W, OV_RESET_W, OV_CELL, OV_RESET = 0.27, 0.18, { xuiCell = true }, { xuiCell = true, xuiWide = true }
    local ov = { type = "group", order = nx(), name = "Class overrides", inline = true, args = {
        info = { type = "description", order = 0, width = "full",
            name = "Every element belongs to a general class. By default a class takes its color from the palette above; pick a color here to change only that class. 'Reset' returns it to the palette." } } }
    local po = 1
    for _, c in ipairs(T.CLASSES) do
        local cls, label, map = c[1], c[2], c[3]
        local a = { type = "group", order = po, name = label .. "  |cff888888(" .. cls .. ")|r", inline = true, args = {} }
        -- #471 item 2 (Options 0.6.97; her "correct on all fronts" to "Fix: one fixed Reset column inside the box for every row"): every
        -- box is one table row of four cells (Skin.lua arg.xuiCell): Background, Border, Text, Reset. A colour the class does not have
        -- (or a parked one) leaves its cell empty instead of moving Reset left, so Reset sits at the same x in every box, and the cells
        -- add up to the box's width, so it stays inside it. (Before, Reset followed the last swatch: past the box's right edge after two.)
        local io = 0
        for k, prop in ipairs({ "bg", "border", "text" }) do
            local tok = map[prop]
            if tok then
                io = io + 1
                local pname = (prop == "bg") and "Background" or (prop == "border" and "Border" or "Text")
                a.args[prop] = { type = "color", order = k, width = "relative", relWidth = OV_SWATCH_W, arg = OV_CELL, name = pname, hasAlpha = true,
                    hidden = function() return T.Parked(tok) end,
                    get = function() local col = T.Col(cls, prop); return col[1], col[2], col[3], col[4] end,
                    set = function(_, r, g, b, al) T.SetClassColor(cls, prop, { r, g, b, al }); refresh() end }
            end
            a.args[prop .. "_cell"] = { type = "description", order = k + 0.5, width = "relative", relWidth = OV_SWATCH_W, arg = OV_CELL, name = "",
                hidden = function() return tok ~= nil and not T.Parked(tok) end }
        end
        if io > 0 then
            po = po + 1
            a.args.reset = { type = "execute", order = 9, width = "relative", relWidth = OV_RESET_W, arg = OV_RESET, name = "Reset", func = function() T.ResetClass(cls); refresh() end }
            ov.args[cls] = a
        end
    end
    -- Class overrides are parked (Xaya, 2026-11-01): every box duplicated a palette swatch. The code and any saved overrides stay
    -- (they still apply); only the editor is hidden. Flip T.SHOW_OVERRIDES to bring the editor back for the redesign.
    -- (UI-50) Advanced customization offers them again ("opens up them and more as options")
    ov.hidden = function() return not (T.SHOW_OVERRIDES or T.Advanced()) end
    args.overrides = ov

    -- save / import / export
    args.shareHdr = { type = "header", order = nx(), name = "Save, import, and export" }
    local saveName = ""
    args.saveName = { type = "input", order = nx(), width = "normal", name = "Name", get = function() return saveName end, set = function(_, v) saveName = v end }
    args.save = { type = "execute", order = nx(), width = "half", name = "Save",
        func = function()
            local ok, e = T.Save(saveName)
            if ok then say("Saved '" .. e .. "'."); return end
            if e ~= "exists" then say(e); return end
            local n = T.CheckName(saveName)
            AskExisting(n, function() local ok2, n2 = T.Save(n, true); say(ok2 and ("Replaced '" .. n2 .. "'.") or n2) end,
                function() local c = T.CopyName(n); local ok2, n2 = T.Save(c); say(ok2 and ("Saved as '" .. n2 .. "'.") or n2) end)
        end }
    -- #471 item 3 (Options 0.6.97): the row ends one margin (ns.Style.margin) before the page's right edge (Skin.lua arg.xuiEndMargin);
    -- "Delete saved" was the row's last control and was laid flush against that edge
    args.delete = { type = "execute", order = nx(), width = "half", name = "Delete saved", arg = { xuiEndMargin = true },
        desc = "Deletes the saved theme with the name typed in the box.",
        func = function() if PlatS.themes[saveName] then T.Delete(saveName); say("Deleted '" .. saveName .. "'.") else say("No saved theme called '" .. saveName .. "'.") end end }
    local exportText = ""
    args.export = { type = "execute", order = nx(), width = "normal", name = "Export current theme",
        func = function() exportText = T.Export(); say("Copy the text from the box below (Ctrl+A, Ctrl+C).") end }
    args.exportBox = { type = "input", order = nx(), width = "full", multiline = 4, name = "Theme string",
        desc = "Export fills this; to import, paste a theme string here and press Import.",
        get = function() return exportText end, set = function(_, v) exportText = v end }
    args.import = { type = "execute", order = nx(), width = "normal", name = "Import theme from box",
        desc = "Applies the pasted theme (and saves it under the Name above if one is typed). Theme strings contain colors, a font name, and a size only.",
        func = function()
            local name = saveName ~= "" and saveName or nil
            if name then   -- audit D5: the name is checked before anything changes
                local n, why = T.CheckName(name); if not n then say(why); return end
                name = n
            end
            local data, err = T.Decode(exportText); if not data then say(err); return end
            local function run(asName, replace)
                AskDiscard("Importing this theme", function()
                    local ok, e = T.Import(exportText, asName, replace)
                    say(ok and (asName and ("Theme imported and saved as '" .. asName .. "'.") or "Theme imported.") or e)
                end)
            end
            if name and T.SavedExists(name) then
                AskExisting(name, function() run(name, true) end, function() run(T.CopyName(name)) end)
            else run(name) end
        end }
    args.status = { type = "description", order = nx(), width = "full", fontSize = "medium", name = function() return msg end }
    return args
end
