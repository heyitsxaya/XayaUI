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
    for i, k in ipairs(ADD_KINDS) do
        args["add_" .. k[1]] = { type = "execute", order = 1.2 + i / 100, width = "normal", name = "+ " .. k[2],
            desc = "Adds a new " .. k[2]:lower() .. " cue to this rule. It takes this tab's settings (such as the hover tooltip) and is edited on the Cues tab. A new cue plays only when a condition on the Conditions tab lists it.",
            func = function()
                local before = list()
                local allTip = #before > 0 and CountOn(before, "hoverTip") == #before
                local c = ns.NewCueRule and ns.NewCueRule(rule, k[1])
                if c and allTip then c.visual.hoverTip = true end
                if c then done({ c }) end
            end }
    end

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
