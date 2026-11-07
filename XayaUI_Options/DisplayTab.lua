-------------------------------------------------------------------------------
-- DisplayTab.lua : the Display tab of the rule editor (XayaUI_Options 0.6.3). Own code. UNTESTED in game.
-- A rule is the CONTAINER of its cues. The Cues tab edits each cue on its own (art, size, color, text, sound). This tab holds what
-- belongs to the rule as a whole: which display cues it has (and adding more), and the settings that apply to ALL of its display
-- cues at once (hover tooltip, position as a group, opacity). Values stay stored on each display, so the game code is unchanged:
-- a setting here writes the same field on every display of the rule, and shows when the displays disagree.
-- A rule from before cues existed (its own display, no cues) counts as one display.
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns

local ADD_KINDS = { { "icon", "Icon" }, { "texture", "Texture" }, { "text", "Text" } }

-- Xaya 2026-11-05: wherever a limit to aura / debuff tracking can be detected, say so in the display pane / the rule's Display tab
-- (ns.CdmNeeds, Triggers.lua). One red line per aura or debuff the game hides in combat that Blizzard's Cooldown Manager does not track.
function ns.CdmWarnArg(rule, order)
    local function lines()
        local p = rule
        if rule and rule.isCue and ns.FindParentRule then p = ns.FindParentRule(rule) or rule end   -- a cue follows its rule's triggers
        local ok, needs = pcall(ns.CdmNeeds or function() return {} end, p)
        if not ok or type(needs) ~= "table" or #needs == 0 then return nil end
        local t = {}
        for _, e in ipairs(needs) do t[#t + 1] = "|cffff5555" .. ns.CdmNeedText(e) .. "|r" end
        return table.concat(t, "\n")
    end
    return { type = "description", order = order or 0.05, width = "full", fontSize = "medium",
        hidden = function() return lines() == nil end, name = function() return lines() or "" end }
end

local function IsVisualCue(c) return c.cueKind ~= "sound" and c.cueKind ~= "speech" and c.cueKind ~= "custom" end

-- the displays this rule owns: its visual cues; or, for an older rule with no cues, the rule's own display while it is on
function ns.RuleDisplays(rule)
    local out = {}
    if not rule then return out end
    local cues = ns.CuesOf and ns.CuesOf(rule) or {}
    for _, c in ipairs(cues) do if IsVisualCue(c) and type(c.visual) == "table" then out[#out + 1] = c end end
    if #cues == 0 and type(rule.visual) == "table" and rule.visual.enabled then out[#out + 1] = rule end
    return out
end

-- how many of the displays have a true value in visual[key]
local function CountOn(list, key)
    local n = 0
    for _, d in ipairs(list) do if d.visual[key] then n = n + 1 end end
    return n
end

function ns.BuildDisplayTab(rule, Notify, Changed)
    local function refresh(list) for _, d in ipairs(list) do pcall(ns.RefreshVisual, d) end end
    local function done(list) refresh(list); if Changed then Changed(rule) end; ns.MarkDirty(); Notify() end
    local function list() return ns.RuleDisplays(rule) end
    local function none() return #list() == 0 end
    local function inDynamic()
        local id, guard = rule.folder, 0
        while id and guard < 32 do
            local f = ns.FolderById and ns.FolderById(id)
            if not f then return false end
            if f.cType == "dynamic" then return true end
            id, guard = f.parent, guard + 1
        end
        return false
    end
    local args = {
        cdmWarn = ns.CdmWarnArg and ns.CdmWarnArg(rule, -1) or nil,   -- first on the tab
        intro = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "This rule is the container for its cues. Each cue's own look is set on the Cues tab; the settings here apply to every display cue of this rule at once." },

        ---------------------------------------------------------------- what the rule shows
        showsH = { type = "header", order = 1, name = "Display cues in this rule" },
        shows = { type = "description", order = 1.1, width = "full", fontSize = "medium",
            name = function()
                local l = list()
                if #l == 0 then return "|cff999999None yet. This rule shows nothing on screen; add a display cue below.|r" end
                local lines = {}
                for _, d in ipairs(l) do
                    if d == rule then lines[#lines + 1] = "-  This rule's own display (from before cues; convert it on the Actions tab)"
                    else
                        local nm = ns.CueLabel and ns.CueLabel(d) or "Cue"
                        local title = ns.CueHeaderTitle and ns.CueHeaderTitle(d) or nm
                        lines[#lines + 1] = "-  " .. title .. ((nm ~= (ns.CueDefaultLabel and ns.CueDefaultLabel(d))) and ("  |cff999999(" .. nm .. ")|r") or "")
                    end
                end
                return table.concat(lines, "\n")
            end },
    }
    -- adding a display cue is a choice between kinds: one dropdown beside the list (Xaya's rule: no row of big buttons for a choice)
    local ADD_VALUES, ADD_ORDER = {}, {}
    for _, k in ipairs(ADD_KINDS) do ADD_VALUES[k[1]] = k[2]; ADD_ORDER[#ADD_ORDER + 1] = k[1] end
    args.shows.width = "normal"
    args.add = { type = "select", order = 1.2, width = "normal", name = "Add a display cue", values = ADD_VALUES, sorting = ADD_ORDER,
        desc = "Adds a new icon, texture, or text cue to this rule. It takes this tab's settings (such as the hover tooltip) and is edited on the Cues tab. A new cue plays only when a condition on the Conditions tab lists it (or always, while the rule has no conditions).",
        get = function() return nil end,
        set = function(_, kind)
            local before = list()
            local allTip = #before > 0 and CountOn(before, "hoverTip") == #before
            local c = ns.NewCueRule and ns.NewCueRule(rule, kind)
            if c and allTip then c.visual.hoverTip = true end
            if c then done({ c }) end
        end }

    ---------------------------------------------------------------- behavior of all displays
    args.behH = { type = "header", order = 2, name = "All display cues", hidden = none }
    args.hoverTip = { type = "toggle", order = 2.1, width = "double", name = "Show tooltip on hover", hidden = none,
        desc = "Hovering any display of this rule shows the tooltip of the spell or item it is about (a cue's icon source, else the rule's first trigger). While on, the displays see the mouse pointer, but clicks still pass through to what is behind them.",
        get = function() local l = list(); return #l > 0 and CountOn(l, "hoverTip") == #l end,
        set = function(_, v) local l = list(); for _, d in ipairs(l) do d.visual.hoverTip = v and true or false end; done(l) end }
    args.hoverMixed = { type = "description", order = 2.15, width = "full", fontSize = "small",
        hidden = function() local l = list(); local n = CountOn(l, "hoverTip"); return #l == 0 or n == 0 or n == #l end,
        name = function() local l = list(); return "|cff999999On for " .. CountOn(l, "hoverTip") .. " of " .. #l .. " displays. Ticking the box turns it on for all of them.|r" end }

    ---------------------------------------------------------------- position as a group
    -- The first display is the reference: moving it by X / Y moves every display by the same amount, so they keep their spacing.
    local function ref() return list()[1] end
    local function shift(axis, v)
        local l = list()
        local r0 = l[1]
        if not r0 then return end
        local delta = (tonumber(v) or 0) - (tonumber(r0.visual[axis]) or 0)
        if delta == 0 then return end
        for _, d in ipairs(l) do d.visual[axis] = (tonumber(d.visual[axis]) or 0) + delta end
        done(l)
    end
    args.posH = { type = "header", order = 3, name = "Position (all displays together)", hidden = none }
    args.posNote = { type = "description", order = 3.05, width = "full", fontSize = "small", hidden = none,
        name = function()
            if inDynamic() then return "|cffff9900This rule is in a dynamic group: the group places its displays, so these offsets have no visible effect there.|r" end
            local n = #list()
            if n > 1 then return "|cff999999Moves all " .. n .. " displays by the same amount, keeping their spacing. The numbers are those of the first display.|r" end
            return "|cff999999The offset of this rule's display from its anchor.|r"
        end }
    args.posX = { type = "range", order = 3.1, name = "X", min = -1200, max = 1200, step = 1, hidden = none,
        get = function() local d = ref(); return d and tonumber(d.visual.x) or 0 end,
        set = function(_, v) shift("x", v) end }
    args.posY = { type = "range", order = 3.2, name = "Y", min = -800, max = 800, step = 1, hidden = none,
        get = function() local d = ref(); return d and tonumber(d.visual.y) or 0 end,
        set = function(_, v) shift("y", v) end }

    ---------------------------------------------------------------- opacity of all displays
    args.lookH = { type = "header", order = 4, name = "Opacity (all displays)", hidden = none }
    local function same(key, def)
        local l = list()
        local v0
        for i, d in ipairs(l) do
            local v = tonumber(d.visual[key]); if v == nil then v = def end
            if i == 1 then v0 = v elseif math.abs(v - v0) > 0.001 then return false, v0 end
        end
        return true, v0
    end
    local function setAll(key, v) local l = list(); for _, d in ipairs(l) do d.visual[key] = v end; done(l) end
    args.alpha = { type = "range", order = 4.1, name = "Opacity", min = 0, max = 1, step = 0.05, isPercent = true, hidden = none,
        desc = "Overall opacity of every display of this rule (each cue's own setting, written to all of them).",
        get = function() local _, v = same("alpha", 1); return v or 1 end,
        set = function(_, v) setAll("alpha", v) end }
    args.oocAlpha = { type = "range", order = 4.2, name = "Out of combat", min = 0, max = 1, step = 0.05, isPercent = true, hidden = none,
        desc = "Opacity multiplier while you are out of combat (100% = the same as in combat), for every display of this rule.",
        get = function() local _, v = same("oocAlpha", 1); return v or 1 end,
        set = function(_, v) setAll("oocAlpha", v) end }
    args.lookMixed = { type = "description", order = 4.3, width = "full", fontSize = "small",
        hidden = function() if none() then return true end; return (same("alpha", 1)) and (same("oocAlpha", 1)) end,
        name = "|cff999999The displays have different opacities; the sliders show the first display's value, and moving one sets it on all of them.|r" }
    return { type = "group", name = "Display", order = 1, args = args }
end

-------------------------------------------------------------------------------
-- Group Display tab (0.6.4): every display cue of every rule in a group (and its nested groups), edited at once and live. Same model as
-- a group's display in the reference addon (one set of controls, a change applies to every item inside), mapped to the trigger / cue /
-- condition split: a group holds rules, a rule holds cues, and only display cues (icon, texture, text) have a look. Replaces the old
-- "Apply Text Settings to All Rules in This Group" panel (#341): no Apply button, no "leave alone" blanks; each control shows the first
-- display's value, a gray line under each section names the settings that differ between displays, and a change makes them all the same.
-- Controls are the cue editor's own builders (ns.UI), fed a proxy table: reading gives the first display's value, writing sets every
-- display's own field (a table value, such as a color, is copied for each display so no two displays share one table).
-------------------------------------------------------------------------------
local function Sig(v)
    if type(v) ~= "table" then return tostring(v) end
    local p = {}
    for i = 1, 4 do p[i] = tostring(v[i]) end
    return table.concat(p, ",")
end

function ns.GroupDisplayArgs(f, folderRules, Notify)
    local U = ns.UI
    local function locked(r) return ns.IsEditLocked and ns.IsEditLocked(r) or false end   -- an edit-locked rule is never changed from here
    local function list()
        local out = {}
        for _, r in ipairs(folderRules(f.id)) do
            if not r.parentUid and not locked(r) then for _, d in ipairs(ns.RuleDisplays(r)) do out[#out + 1] = d end end
        end
        return out
    end
    local function nRules()
        local n = 0
        for _, r in ipairs(folderRules(f.id)) do if not r.parentUid and not locked(r) and #ns.RuleDisplays(r) > 0 then n = n + 1 end end
        return n
    end
    local function nLocked()
        local n = 0
        for _, r in ipairs(folderRules(f.id)) do if not r.parentUid and locked(r) and #ns.RuleDisplays(r) > 0 then n = n + 1 end end
        return n
    end
    local function none() return #list() == 0 end
    local function on()
        for _, d in ipairs(list()) do pcall(ns.RefreshVisual, d) end
        ns.MarkDirty(); Notify()
    end
    -- sub = nil: the display's visual table; otherwise one of its sub-tables (text, count, absorb, border, bg)
    local function Proxy(sub)
        return setmetatable({}, {
            __index = function(_, k)
                local d = list()[1]
                if not d then return nil end
                local t = d.visual
                if sub then t = t[sub] end
                -- (not `type(t) == "table" and t[k] or nil`: that turns a stored false into nil, i.e. "the default")
                if type(t) == "table" then return t[k] end
                return nil
            end,
            __newindex = function(_, k, v)
                for _, d in ipairs(list()) do
                    local t = d.visual
                    if sub then
                        if type(t[sub]) ~= "table" then t[sub] = {} end
                        t = t[sub]
                    end
                    t[k] = (type(v) == "table" and ns.Copy) and ns.Copy(v) or v
                end
            end })
    end
    -- the labels of the settings that differ between the displays (nil when they all agree)
    local function Differs(sub, keys)
        local l, out = list(), {}
        if #l < 2 then return nil end
        for _, kv in ipairs(keys) do
            local k, label = kv[1], kv[2]
            local first
            for i, d in ipairs(l) do
                local t = sub and d.visual[sub] or d.visual
                local val
                if type(t) == "table" then val = t[k] end
                local s = Sig(val)
                if i == 1 then first = s elseif s ~= first then out[#out + 1] = label; break end
            end
        end
        if #out == 0 then return nil end
        return "|cff999999Differs between displays: " .. table.concat(out, ", ") .. ". The controls show the first display's values; a change makes them all the same.|r"
    end
    local function DiffLine(order, sub, keys)
        return { type = "description", order = order, width = "full", fontSize = "small",
            hidden = function() return Differs(sub, keys) == nil end,
            name = function() return Differs(sub, keys) or "" end }
    end
    local function Section(id, title, order, args) return ns.GatedPane(f, "gdisp_" .. id, title, order, function() return not none() end, args) end

    local V = Proxy(nil)
    local args = {}
    args.scope = { type = "description", order = 0.5, width = "full", fontSize = "small",
        name = function()
            local n = #list()
            if n == 0 then return "|cff999999No rule in this group shows anything on screen yet, so there is nothing to style here. Add a display cue to a rule (its Display or Cues tab).|r" end
            local lk = nLocked()
            return "Every setting below applies right away to every display cue in this group and its nested groups: |cffffd100" .. n .. " display" .. (n == 1 and "" or "s") .. " in " .. nRules() .. " rule" .. (nRules() == 1 and "" or "s") .. "|r. Each cue's other settings stay its own (Cues tab of the rule)."
                .. ((lk > 0) and ("  |cff999999" .. lk .. " edit-locked rule" .. (lk == 1 and " is" or "s are") .. " left out.|r") or "")
        end }

    -- behavior of every display
    local beh = {
        hoverTip = U.Tog(V, "hoverTip", "Show tooltip on hover", 1, on, { width = "double",
            desc = "Hovering a display shows the tooltip of the spell or item it is about. While on, the display sees the mouse pointer, but clicks still pass through to what is behind it." }),
        requireOnBar = U.Tog(V, "requireOnBar", "Only show while on an action bar", 2, on, { width = "double",
            desc = "Hides a display whenever its rule's spell is not placed on any of your action bars." }),
    }
    beh.diff = DiffLine(9, nil, { { "hoverTip", "Show tooltip on hover" }, { "requireOnBar", "Only show while on an action bar" } })
    args.behavior = Section("beh", "Every display: behavior", 2, beh)

    -- size of every display
    local size = {
        w = U.Rng(V, "w", "Display width", 1, 8, 512, 1, on),
        h = U.Rng(V, "h", "Display height", 2, 8, 512, 1, on),
        zoom = U.Rng(V, "zoom", "Zoom / crop edges", 3, 0, 0.3, 0.01, on, { desc = "Spell icons: how much of the icon's edge is cropped away." }),
    }
    size.diff = DiffLine(9, nil, { { "w", "Display width" }, { "h", "Display height" }, { "zoom", "Zoom" } })
    args.size = Section("size", "Every display: size", 3, size)

    -- opacity of every display
    local op = {
        alpha = U.Rng(V, "alpha", "Opacity", 1, 0, 1, 0.05, on, { isPercent = true }),
        oocAlpha = U.Rng(V, "oocAlpha", "Out of combat", 2, 0, 1, 0.05, on, { isPercent = true, def = 1,
            desc = "Opacity multiplier while you are out of combat (100% = the same as in combat)." }),
    }
    op.diff = DiffLine(9, nil, { { "alpha", "Opacity" }, { "oocAlpha", "Out of combat" } })
    args.opacity = Section("op", "Every display: opacity", 4, op)

    -- border and background of every display
    local B, BG = Proxy("border"), Proxy("bg")
    local bd = {
        bdOn = U.Tog(B, "enabled", "Border", 1, on),
        bdSize = U.Rng(B, "size", "Border size (px)", 2, 1, 8, 1, on, { disabled = function() return not B.enabled end }),
        bdColor = U.Col(B, "color", "Border color", 3, on, { disabled = function() return not B.enabled end }),
        bgOn = U.Tog(BG, "enabled", "Background fill", 4, on),
        bgColor = U.Col(BG, "color", "Background color", 5, on, { disabled = function() return not BG.enabled end }),
    }
    bd.diff = DiffLine(9, "border", { { "enabled", "Border" }, { "size", "Border size" }, { "color", "Border color" } })
    bd.diff2 = DiffLine(9.1, "bg", { { "enabled", "Background fill" }, { "color", "Background color" } })
    args.border = Section("bd", "Every display: border and background", 5, bd)

    -- Bar colour style (RM-BARS; Xaya 2026-11-06, REQUEST-LOG S8-10: "Cue sets it, group overrides if forcibly set; otherwise it shows
    -- an indicator that multiple rules will be affected (refer to WA group options)"). Force ticked: the group's own style (f.barStyle,
    -- f.barCustom) wins over every bar inside it (BarCue.lua ns.BarCueStyle). Unticked: a choice here is written to every Bar cue in the
    -- group once, like every other control on this tab, and the label says how many bars it changes.
    local function bars()
        local out = {}
        for _, d in ipairs(list()) do if type(d.visual) == "table" and d.visual.kind == "bar" then out[#out + 1] = d end end
        return out
    end
    local function forced() return f.barStyleForce and true or false end
    local function firstBar() local l = bars(); return l[1] and ns.BarCueSettings(l[1].visual) or nil end
    local function styleNow()
        if forced() then return ns.BAR_STYLE_LABEL[f.barStyle] and f.barStyle or "blizzard" end
        local b = firstBar(); return b and b.style or "blizzard"
    end
    local function customNow() if forced() then return f.barCustom end local b = firstBar(); return b and b.custom end
    local function writeAll(fn)
        for _, d in ipairs(bars()) do fn(ns.BarCueSettings(d.visual)) end
    end
    local function nBars() return #bars() end
    local bst = {
        force = { type = "toggle", order = 1, width = "full", name = "Force on every bar in this group",
            desc = "Ticked: every Bar cue in this group (and its nested groups) uses this group's colour style, whatever its own is set to. Unticked: each bar keeps its own style; a choice below is copied to every bar once.",
            get = function() return forced() end,
            set = function(_, v)
                if v and not ns.BAR_STYLE_LABEL[f.barStyle] then f.barStyle = styleNow() end
                f.barStyleForce = v and true or nil
                on()
            end },
        style = { type = "select", order = 2, width = "double",
            name = function()
                local n = nBars()
                return "Colour style  |cff999999(" .. (forced() and "forced on " or "changes ") .. n .. " bar" .. (n == 1 and "" or "s") .. ")|r"
            end,
            values = ns.BAR_STYLE_LABEL, sorting = ns.BAR_STYLES,
            get = function() return styleNow() end,
            set = function(_, v)
                if forced() then f.barStyle = v else writeAll(function(b) b.style = v end) end
                on()
            end },
    }
    bst.cMagic = { type = "color", order = 3.00, hasAlpha = false, name = "Magic",
        hidden = function() return styleNow() ~= "custom" end,
        get = function() local r, g, b = ns.BarTypeColor("Magic", "custom", customNow()); if not r then local fb = ns.BAR_FALLBACK_COLOR; return fb[1], fb[2], fb[3], 1 end return r, g, b, 1 end,
        set = function(_, r, g, b)
            if forced() then f.barCustom = f.barCustom or {}; f.barCustom["Magic"] = { r, g, b, 1 }
            else writeAll(function(bb) bb.custom = bb.custom or {}; bb.custom["Magic"] = { r, g, b, 1 } end) end
            on()
        end }
    bst.cCurse = { type = "color", order = 3.01, hasAlpha = false, name = "Curse",
        hidden = function() return styleNow() ~= "custom" end,
        get = function() local r, g, b = ns.BarTypeColor("Curse", "custom", customNow()); if not r then local fb = ns.BAR_FALLBACK_COLOR; return fb[1], fb[2], fb[3], 1 end return r, g, b, 1 end,
        set = function(_, r, g, b)
            if forced() then f.barCustom = f.barCustom or {}; f.barCustom["Curse"] = { r, g, b, 1 }
            else writeAll(function(bb) bb.custom = bb.custom or {}; bb.custom["Curse"] = { r, g, b, 1 } end) end
            on()
        end }
    bst.cDisease = { type = "color", order = 3.02, hasAlpha = false, name = "Disease",
        hidden = function() return styleNow() ~= "custom" end,
        get = function() local r, g, b = ns.BarTypeColor("Disease", "custom", customNow()); if not r then local fb = ns.BAR_FALLBACK_COLOR; return fb[1], fb[2], fb[3], 1 end return r, g, b, 1 end,
        set = function(_, r, g, b)
            if forced() then f.barCustom = f.barCustom or {}; f.barCustom["Disease"] = { r, g, b, 1 }
            else writeAll(function(bb) bb.custom = bb.custom or {}; bb.custom["Disease"] = { r, g, b, 1 } end) end
            on()
        end }
    bst.cPoison = { type = "color", order = 3.03, hasAlpha = false, name = "Poison",
        hidden = function() return styleNow() ~= "custom" end,
        get = function() local r, g, b = ns.BarTypeColor("Poison", "custom", customNow()); if not r then local fb = ns.BAR_FALLBACK_COLOR; return fb[1], fb[2], fb[3], 1 end return r, g, b, 1 end,
        set = function(_, r, g, b)
            if forced() then f.barCustom = f.barCustom or {}; f.barCustom["Poison"] = { r, g, b, 1 }
            else writeAll(function(bb) bb.custom = bb.custom or {}; bb.custom["Poison"] = { r, g, b, 1 } end) end
            on()
        end }
    bst.cBleed = { type = "color", order = 3.04, hasAlpha = false, name = "Bleed",
        hidden = function() return styleNow() ~= "custom" end,
        get = function() local r, g, b = ns.BarTypeColor("Bleed", "custom", customNow()); if not r then local fb = ns.BAR_FALLBACK_COLOR; return fb[1], fb[2], fb[3], 1 end return r, g, b, 1 end,
        set = function(_, r, g, b)
            if forced() then f.barCustom = f.barCustom or {}; f.barCustom["Bleed"] = { r, g, b, 1 }
            else writeAll(function(bb) bb.custom = bb.custom or {}; bb.custom["Bleed"] = { r, g, b, 1 } end) end
            on()
        end }
    bst.cPhysical = { type = "color", order = 3.05, hasAlpha = false, name = "Physical",
        hidden = function() return styleNow() ~= "custom" end,
        get = function() local r, g, b = ns.BarTypeColor("Physical", "custom", customNow()); if not r then local fb = ns.BAR_FALLBACK_COLOR; return fb[1], fb[2], fb[3], 1 end return r, g, b, 1 end,
        set = function(_, r, g, b)
            if forced() then f.barCustom = f.barCustom or {}; f.barCustom["Physical"] = { r, g, b, 1 }
            else writeAll(function(bb) bb.custom = bb.custom or {}; bb.custom["Physical"] = { r, g, b, 1 } end) end
            on()
        end }
    bst.cHoly = { type = "color", order = 3.06, hasAlpha = false, name = "Holy",
        hidden = function() return styleNow() ~= "custom" end,
        get = function() local r, g, b = ns.BarTypeColor("Holy", "custom", customNow()); if not r then local fb = ns.BAR_FALLBACK_COLOR; return fb[1], fb[2], fb[3], 1 end return r, g, b, 1 end,
        set = function(_, r, g, b)
            if forced() then f.barCustom = f.barCustom or {}; f.barCustom["Holy"] = { r, g, b, 1 }
            else writeAll(function(bb) bb.custom = bb.custom or {}; bb.custom["Holy"] = { r, g, b, 1 } end) end
            on()
        end }
    bst.cFire = { type = "color", order = 3.07, hasAlpha = false, name = "Fire",
        hidden = function() return styleNow() ~= "custom" end,
        get = function() local r, g, b = ns.BarTypeColor("Fire", "custom", customNow()); if not r then local fb = ns.BAR_FALLBACK_COLOR; return fb[1], fb[2], fb[3], 1 end return r, g, b, 1 end,
        set = function(_, r, g, b)
            if forced() then f.barCustom = f.barCustom or {}; f.barCustom["Fire"] = { r, g, b, 1 }
            else writeAll(function(bb) bb.custom = bb.custom or {}; bb.custom["Fire"] = { r, g, b, 1 } end) end
            on()
        end }
    bst.cNature = { type = "color", order = 3.08, hasAlpha = false, name = "Nature",
        hidden = function() return styleNow() ~= "custom" end,
        get = function() local r, g, b = ns.BarTypeColor("Nature", "custom", customNow()); if not r then local fb = ns.BAR_FALLBACK_COLOR; return fb[1], fb[2], fb[3], 1 end return r, g, b, 1 end,
        set = function(_, r, g, b)
            if forced() then f.barCustom = f.barCustom or {}; f.barCustom["Nature"] = { r, g, b, 1 }
            else writeAll(function(bb) bb.custom = bb.custom or {}; bb.custom["Nature"] = { r, g, b, 1 } end) end
            on()
        end }
    bst.cFrost = { type = "color", order = 3.09, hasAlpha = false, name = "Frost",
        hidden = function() return styleNow() ~= "custom" end,
        get = function() local r, g, b = ns.BarTypeColor("Frost", "custom", customNow()); if not r then local fb = ns.BAR_FALLBACK_COLOR; return fb[1], fb[2], fb[3], 1 end return r, g, b, 1 end,
        set = function(_, r, g, b)
            if forced() then f.barCustom = f.barCustom or {}; f.barCustom["Frost"] = { r, g, b, 1 }
            else writeAll(function(bb) bb.custom = bb.custom or {}; bb.custom["Frost"] = { r, g, b, 1 } end) end
            on()
        end }
    bst.cShadow = { type = "color", order = 3.10, hasAlpha = false, name = "Shadow",
        hidden = function() return styleNow() ~= "custom" end,
        get = function() local r, g, b = ns.BarTypeColor("Shadow", "custom", customNow()); if not r then local fb = ns.BAR_FALLBACK_COLOR; return fb[1], fb[2], fb[3], 1 end return r, g, b, 1 end,
        set = function(_, r, g, b)
            if forced() then f.barCustom = f.barCustom or {}; f.barCustom["Shadow"] = { r, g, b, 1 }
            else writeAll(function(bb) bb.custom = bb.custom or {}; bb.custom["Shadow"] = { r, g, b, 1 } end) end
            on()
        end }
    bst.cArcane = { type = "color", order = 3.11, hasAlpha = false, name = "Arcane",
        hidden = function() return styleNow() ~= "custom" end,
        get = function() local r, g, b = ns.BarTypeColor("Arcane", "custom", customNow()); if not r then local fb = ns.BAR_FALLBACK_COLOR; return fb[1], fb[2], fb[3], 1 end return r, g, b, 1 end,
        set = function(_, r, g, b)
            if forced() then f.barCustom = f.barCustom or {}; f.barCustom["Arcane"] = { r, g, b, 1 }
            else writeAll(function(bb) bb.custom = bb.custom or {}; bb.custom["Arcane"] = { r, g, b, 1 } end) end
            on()
        end }
    bst.diff = { type = "description", order = 9, width = "full", fontSize = "small",
        hidden = function()
            if forced() then return true end
            local l, first = bars(), nil
            for i, d in ipairs(l) do local st = ns.BarCueSettings(d.visual).style; if i == 1 then first = st elseif st ~= first then return false end end
            return true
        end,
        name = "|cff999999Differs between bars: Colour style. The control shows the first bar's style; a change makes them all the same.|r" }
    args.barStyle = ns.GatedPane(f, "gdisp_barstyle", "Every bar: colour style", 5.5, function() return nBars() > 0 end, bst)

    -- the three text elements, each its own section (what to change is the section you open, not a tick list)
    local STYLE = { { "font", "Font" }, { "size", "Text size" }, { "outline", "Outline" }, { "color", "Text color" }, { "place", "Placement" },
        { "anchor", "Position" }, { "x", "X offset" }, { "y", "Y offset" } }
    local function TextSection(id, title, order, sub, head)
        local P = Proxy(sub)
        local a = U.TextStyleArgs(P, on, 10)
        local keys = {}
        for k, o in pairs(head(P)) do a[k] = o end
        for _, kv in ipairs(STYLE) do keys[#keys + 1] = kv end
        local hk = { { "enabled", "Shown" } }
        if sub == "text" then hk[#hk + 1] = { "decimals", "Tenths" }; hk[#hk + 1] = { "decimalBelow", "Tenths below" } end
        if sub == "count" then hk[#hk + 1] = { "source", "Count of" } end
        if sub == "absorb" then hk[#hk + 1] = { "source", "Amount from" }; hk[#hk + 1] = { "abbreviate", "Abbreviate" }; hk[#hk + 1] = { "hideZero", "Hide when zero" } end
        for _, kv in ipairs(keys) do hk[#hk + 1] = kv end
        a.diff = DiffLine(9, sub, hk)
        return Section(id, title, order, a)
    end
    args.textDur = TextSection("dur", "Buff duration text", 6, "text", function(P)
        return {
            enabled = U.Tog(P, "enabled", "Show remaining buff time", 1, on, { width = "double" }),
            decimals = U.Tog(P, "decimals", "Show tenths (decimals)", 2, on),
            decimalBelow = U.Rng(P, "decimalBelow", "Tenths only below (s)", 3, 1, 30, 1, on, { disabled = function() return not P.decimals end }),
        }
    end)
    args.textCnt = TextSection("cnt", "Stacks / charges count", 7, "count", function(P)
        return {
            enabled = U.Tog(P, "enabled", "Show a count", 1, on),
            source = U.Sel(P, "source", "Count of", 2, U.COUNT_SOURCE, U.COUNT_SOURCE_ORDER, on),
        }
    end)
    args.textAbs = TextSection("abs", "Shield / absorb amount", 8, "absorb", function(P)
        return {
            enabled = U.Tog(P, "enabled", "Show shield / absorb amount", 1, on, { width = "double" }),
            source = U.Sel(P, "source", "Amount from", 2, U.ABSORB_SOURCE, U.ABSORB_SOURCE_ORDER, on),
            abbreviate = U.Tog(P, "abbreviate", "Abbreviate (12.3K)", 3, on),
            hideZero = U.Tog(P, "hideZero", "Hide when zero", 4, on),
        }
    end)
    return args
end
