-------------------------------------------------------------------------------
-- XayaUI_Rules/Editor/ShelvedElements.lua : The shelved QoL Elements' pages (stats text boxes and buff bars; their files are in shelved/, not loaded, so nothing here is
-- drawn today: ns.QoLOn and ns.BarsOn are nil). Kept beside the rules tree, which lists them.
-- Part of the rule editor, moved out of Options.lua unchanged in the platform split P3 (Options 0.6.83;
-- docs/plans/PLATFORM-SPLIT-2026-11-07.md section 7, Q1: the rule module owns its editor). This folder talks to the rest of the
-- settings window only through ns.OptionsApi: ns.OptionsApi.Shared (what Options.lua lends it) in, ns.OptionsApi.RuleEditor (what
-- Options.lua asks of it) out; its files share their own parts through ns.OptionsApi.RuleEditorParts.
-------------------------------------------------------------------------------
local addonName, ns = ...
ns = _G.XayaUI_NS or ns   -- one namespace with XayaUI core (XayaUI Rules depends on it: ## Dependencies: XayaUI)
-- (Rules 0.7.0, REQUEST-LOG A23 SD-6) This file is part of XayaUI Rules (it was the load-on-demand addon XayaUI_Rules_Options). The game
-- reads it at login with Rules; everything below only runs when the settings window first opens with Rules on: it is one set-up
-- function, run once by XayaUI_Options (Options.lua ns.OptionsApi.LoadRuleEditor) in the .toc order. Nothing is built before then.
local function EditorFileInit()
local function QoLBoxes() local s = ns.Service and ns.Service("statsText"); return s and s.Boxes() end   -- (P5) XayaUI QoL's stats-text boxes (XayaUI_QoL/StatsText.lua), nil while it is off
if not (ns.OptionsApi and ns.OptionsApi.Shared) then return end   -- Options.lua stopped early (its Ace3 libraries are missing)
local O = ns.OptionsApi.Shared
local APP, AceConfigDialog, Notify, Col, Rng, Tog = O.APP, O.AceConfigDialog, O.Notify, O.Col, O.Rng, O.Tog
local Sel = O.Sel
local P = ns.OptionsApi.RuleEditorParts
local BAR_ANCHOR, BAR_ANCHOR_ORDER, BAR_ICON, BAR_ICON_ORDER, BAR_NAME, BAR_NAME_ORDER = P.BAR_ANCHOR, P.BAR_ANCHOR_ORDER, P.BAR_ICON, P.BAR_ICON_ORDER, P.BAR_NAME, P.BAR_NAME_ORDER
local BAR_SHOW, BAR_SHOW_ORDER, FontSel, JUSTIFY, JUSTIFY_ORDER, SHOW_COMBAT = P.BAR_SHOW, P.BAR_SHOW_ORDER, P.FontSel, P.JUSTIFY, P.JUSTIFY_ORDER, P.SHOW_COMBAT
local SHOW_COMBAT_ORDER, SearchBox, SpellName, TEXT_OUTLINE, TEXT_OUTLINE_ORDER, TRI_ORDER = P.SHOW_COMBAT_ORDER, P.SearchBox, P.SpellName, P.TEXT_OUTLINE, P.TEXT_OUTLINE_ORDER, P.TRI_ORDER


local function TokenHelp()
    local t = { "Tokens you can use (case-insensitive):" }
    for _, k in ipairs(ns.QOL_STAT_ORDER) do t[#t + 1] = "{" .. k .. "}  " .. ns.QOL_STATS[k].desc end
    t[#t + 1] = "WoW color codes also work in the format, e.g. typing |cffffd100||cffffd100gold||r|r shows |cffffd100gold|r."
    t[#t + 1] = "Blizzard hides stats while auras are restricted (combat, M+, encounters): a stat then keeps its last readable value, or shows ? if it was never readable."
    return table.concat(t, "\n")
end

local function BuildBox(i, box)
    return {
        type = "group", order = 10 + i,
        name = function() return (box.enabled and "" or "|cff888888") .. box.name end,
        args = {
            name = { type = "input", name = "Name", order = 1, width = "double",
                get = function() return box.name end,
                set = function(_, v) if v ~= "" then box.name = v end; Notify() end },
            enabled = { type = "toggle", name = "Enabled", order = 2,
                get = function() return box.enabled end,
                set = function(_, v) box.enabled = v; ns.QoL_Refresh(box); Notify() end },
            format = { type = "input", name = "Format", order = 3, width = "full", multiline = 5,
                get = function() return box.format end,
                set = function(_, v) box.format = v; ns.QoL_Refresh(box); Notify() end },
            preview = { type = "description", order = 4, width = "full", fontSize = "large",
                name = function() return "Preview:\n" .. ns.QoL_Preview(box) end },
            tokens = { type = "description", order = 5, width = "full", fontSize = "small", name = TokenHelp },
            lookHeader = { type = "header", name = "Look", order = 10 },
            font = { type = "select", name = "Font", order = 10.5,
                values = function() local v = ns.FontList(); return v end,
                sorting = function() local _, o = ns.FontList(); return o end,
                get = function() return box.font end, set = function(_, v) box.font = v; ns.QoL_Refresh(box) end },
            size = { type = "range", name = "Text size", order = 11, min = 6, max = 64, step = 1,
                get = function() return box.size end, set = function(_, v) box.size = v; ns.QoL_Refresh(box) end },
            outline = { type = "select", name = "Outline", order = 12, values = TEXT_OUTLINE, sorting = TEXT_OUTLINE_ORDER,
                get = function() return box.outline end, set = function(_, v) box.outline = v; ns.QoL_Refresh(box) end },
            justify = { type = "select", name = "Alignment", order = 13, values = JUSTIFY, sorting = JUSTIFY_ORDER,
                get = function() return box.justify end, set = function(_, v) box.justify = v; ns.QoL_Refresh(box) end },
            color = { type = "color", name = "Color", order = 14, hasAlpha = true,
                get = function() local c = box.color or { 1, 1, 1, 1 }; return c[1], c[2], c[3], c[4] or 1 end,
                set = function(_, r, g, b, a) box.color = { r, g, b, a }; ns.QoL_Refresh(box) end },
            alpha = { type = "range", name = "Opacity", order = 15, min = 0.05, max = 1, step = 0.05,
                get = function() return box.alpha end, set = function(_, v) box.alpha = v; ns.QoL_Refresh(box) end },
            decimals = { type = "range", name = "Decimals on percentages", order = 16, min = 0, max = 2, step = 1,
                get = function() return box.decimals end, set = function(_, v) box.decimals = v; ns.QoL_Refresh(box) end },
            showCombat = { type = "select", name = "Show", order = 17, values = SHOW_COMBAT, sorting = SHOW_COMBAT_ORDER,
                get = function() return box.showCombat end, set = function(_, v) box.showCombat = v; ns.QoL_Refresh(box) end },
            posHeader = { type = "header", name = "Position (Offset From Screen Center)", order = 20 },
            x = { type = "range", name = "X", order = 21, min = -1500, max = 1500, step = 1,
                get = function() return box.x end, set = function(_, v) box.x = v; ns.QoL_Refresh(box) end },
            y = { type = "range", name = "Y", order = 22, min = -900, max = 900, step = 1,
                get = function() return box.y end, set = function(_, v) box.y = v; ns.QoL_Refresh(box) end },
            unlock = { type = "execute", order = 23, width = "double",
                name = function() return ns.unlocked and "Lock (stop dragging)" or "Unlock (drag on screen)" end,
                func = function() ns.ToggleUnlock(); Notify() end },
            delete = { type = "execute", name = "Delete this box", order = 30, confirm = true, confirmText = "Delete this stats box?",
                func = function()
                    for idx, b in ipairs(QoLBoxes()) do
                        if b == box then table.remove(QoLBoxes(), idx); break end
                    end
                    ns.QoL_Drop(box)
                    Notify()
                    pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "qol", "allqol")
                end },
        },
    }
end

-------------------------------------------------------------------------------
-- Buff bars
-------------------------------------------------------------------------------
local function BuildBar(i, bar)
    local function on() ns.Bars_Refresh(bar); ns.MarkDirty() end
    local function onN() on(); Notify() end
    local barTab = {
        type = "group", name = "Bar", order = 1, args = {
            name = { type = "input", name = "Name", order = 1, width = "double",
                get = function() return bar.name end, set = function(_, v) if v ~= "" then bar.name = v end; Notify() end },
            enabled = Tog(bar, "enabled", "Enabled", 2, onN),
            buffSearch = SearchBox(2.9, function(id) bar.buffID = id; on(); Notify() end, nil, "aura"),
            buffID = { type = "input", name = "Aura spell ID", order = 3, width = "half",
                get = function() return tostring(bar.buffID) end,
                set = function(_, v) bar.buffID = tonumber(v) or 0; on(); Notify() end },
            buffName = { type = "description", order = 4, width = "double", fontSize = "medium", name = function() return SpellName(bar.buffID) end },
            showWhen = Sel(bar, "showWhen", "Show", 5, BAR_SHOW, BAR_SHOW_ORDER, on, { width = "double" }),
            combat = Sel(bar, "combat", "Combat", 6, { none = "(none - any)", yes = "Only in combat", no = "Only out of combat" }, TRI_ORDER, on, { width = "double" }),
            icon = Sel(bar, "icon", "Icon", 7, BAR_ICON, BAR_ICON_ORDER, on, { width = "double" }),
            note = { type = "description", order = 8, fontSize = "small", width = "full",
                name = "Buff bars are display-only. While Blizzard hides aura times (combat), the bar uses an experimental Blizzard duration object and may show full or empty. Use the eye icon in the sidebar to preview." },
            delete = { type = "execute", name = "Delete this bar", order = 20, confirm = true, confirmText = "Delete this buff bar?",
                func = function()
                    for idx, b in ipairs(ns.bars) do if b == bar then table.remove(ns.bars, idx); break end end
                    ns.Bars_Drop(bar); ns.MarkDirty(); Notify()
                    pcall(AceConfigDialog.SelectGroup, AceConfigDialog, APP, "qol", "allbars")
                end },
        },
    }
    local look = {
        type = "group", name = "Look", order = 2, args = {
            sizeH = { type = "header", name = "Size & Orientation", order = 1 },
            width = Rng(bar, "width", "Width", 2, 8, 800, 1, on),
            height = Rng(bar, "height", "Height", 3, 4, 300, 1, on),
            vertical = Tog(bar, "vertical", "Vertical orientation", 4, on),
            reverse = Tog(bar, "reverse", "Fill up as time passes (instead of draining)", 5, on, { width = "double" }),
            alpha = Rng(bar, "alpha", "Opacity", 6, 0, 1, 0.05, on),
            colH = { type = "header", name = "Texture & Colors", order = 10 },
            texture = Sel(bar, "texture", "Bar texture", 11, function() local v = ns.BarTextureList(); return v end,
                function() local _, o = ns.BarTextureList(); return o end, on, { width = "double" }),
            fill = Col(bar, "fillColor", "Fill color", 12, on),
            bg = Col(bar, "bgColor", "Background color", 13, on),
            spark = Tog(bar, "spark", "Show spark", 14, on),
            borderH = { type = "header", name = "Border", order = 20 },
            borderSize = Rng(bar, "borderSize", "Border size (px, 0 = none)", 21, 0, 8, 1, on),
            borderColor = Col(bar, "borderColor", "Border color", 22, on),
            posH = { type = "header", name = "Position (Used When the Group Layout Is Manual)", order = 30 },
            x = Rng(bar, "x", "X", 31, -1500, 1500, 1, on),
            y = Rng(bar, "y", "Y", 32, -900, 900, 1, on),
            unlock = { type = "execute", order = 33, width = "double",
                name = function() return ns.unlocked and "Lock (stop dragging)" or "Unlock (drag on screen)" end,
                func = function() ns.ToggleUnlock(); Notify() end },
        },
    }
    local text = {
        type = "group", name = "Text", order = 3, args = {
            font = FontSel(bar, 1, on),
            nameH = { type = "header", name = "Name", order = 10 },
            showName = Tog(bar, "showName", "Show name", 11, on),
            nameMode = Sel(bar, "nameMode", "Name text", 12, BAR_NAME, BAR_NAME_ORDER, on),
            customName = { type = "input", name = "Custom text", order = 13, width = "double",
                disabled = function() return ns.Val(bar.nameMode) ~= "custom" end,
                get = function() return bar.customName or "" end, set = function(_, v) bar.customName = v; on() end },
            nameSize = Rng(bar, "nameSize", "Name size", 14, 6, 48, 1, on),
            nameAnchor = Sel(bar, "nameAnchor", "Name position", 15, BAR_ANCHOR, BAR_ANCHOR_ORDER, on),
            timerH = { type = "header", name = "Timer", order = 20 },
            showTimer = Tog(bar, "showTimer", "Show remaining time", 21, on),
            timerSize = Rng(bar, "timerSize", "Timer size", 22, 6, 48, 1, on),
            timerAnchor = Sel(bar, "timerAnchor", "Timer position", 23, BAR_ANCHOR, BAR_ANCHOR_ORDER, on),
            decimals = Tog(bar, "decimals", "Show tenths (decimals)", 24, on),
            decimalBelow = Rng(bar, "decimalBelow", "Show tenths only below (seconds)", 25, 1, 30, 1, on,
                { width = "double", disabled = function() return not bar.decimals end }),
            stackH = { type = "header", name = "Stacks", order = 30 },
            showStacks = Tog(bar, "showStacks", "Show stacks", 31, on),
            stackSize = Rng(bar, "stackSize", "Stacks size", 32, 6, 48, 1, on),
            stackAnchor = Sel(bar, "stackAnchor", "Stacks position", 33, BAR_ANCHOR, BAR_ANCHOR_ORDER, on),
        },
    }
    do   -- name / timer / stacks options are drawn only while that element is switched on
        local a, cn = text.args, text.args.customName
        ns.GatePane(bar, a, "decimals", "Tenths options", 24.5, function() return bar.decimals end, { "decimalBelow" })
        ns.GatePane(bar, a, "name", "Name options", 11.5, function() return bar.showName end, { "nameMode", "customName", "nameSize", "nameAnchor" })
        cn.disabled = function() return ns.Val(bar.nameMode) ~= "custom" end   -- a choice inside the pane, not an on/off switch
        ns.GatePane(bar, a, "timer", "Timer options", 21.5, function() return bar.showTimer end, { "timerSize", "timerAnchor", "decimals", "pane_decimals" })
        ns.GatePane(bar, a, "stacks", "Stacks options", 31.5, function() return bar.showStacks end, { "stackSize", "stackAnchor" })
    end
    return {
        type = "group", childGroups = "tab", order = 10 + i,
        name = function() return (bar.enabled and "" or "|cff888888") .. bar.name end,
        args = { bar = barTab, look = look, text = text },
    }
end


-- for the other files of this folder (ns.OptionsApi.RuleEditorParts)
P.BuildBar, P.BuildBox, P.TokenHelp = BuildBar, BuildBox, TokenHelp
end
ns.RuleEditorFiles = ns.RuleEditorFiles or {}
ns.RuleEditorFiles[#ns.RuleEditorFiles + 1] = EditorFileInit
