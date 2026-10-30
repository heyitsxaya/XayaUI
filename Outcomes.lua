-------------------------------------------------------------------------------
-- Outcomes.lua : several outcomes per rule.
--
-- A rule keeps its own sound / display, driven by all of its triggers ANDed together (unchanged). It can also own
-- OUTCOMES: extra rules, linked by rule.parentUid, that read the parent's trigger results and fire their OWN sound
-- and display when their own combination (rule.when) is true. An outcome is a normal rule in every other way
-- (Conditions tab, Load tab, folder, preview icons), so nothing about sounds or displays is duplicated here.
--
-- Combination = a list of conditions built with rows. Each condition checks one of the parent's triggers
-- (Cooldown, Buff / Aura, Talents, Trigger 1..n, or "the parent rule fires"), optionally NOT, and is joined to the
-- previous one with AND or OR. AND binds tighter than OR, so  A AND B OR C  means  (A AND B) OR C.
-- Three-valued like the rest of the engine: an unknown input keeps the answer unknown, and unknown never fires.
--
-- Saved data: plain strings / booleans only (no code), so profile import stays data-only.
-------------------------------------------------------------------------------
local addonName, ns = ...

local MAX_TERMS = 24

function ns.NewUID() return "u" .. tostring(time()) .. tostring(math.random(100000, 999999)) end

-- The rule an outcome follows (nil if missing). Outcomes cannot own outcomes, so there is no chain and no cycle.
function ns.FindParentRule(rule)
    local uid = rule.parentUid
    if type(uid) ~= "string" or uid == "" then return nil end
    for _, r in ipairs(ns.rules or {}) do
        if r ~= rule and r.uid == uid and not r.parentUid then return r end
    end
end

function ns.OutcomesOf(parent)
    local out = {}
    if type(parent.uid) ~= "string" then return out end
    for _, r in ipairs(ns.rules or {}) do
        if r ~= parent and r.parentUid == parent.uid then out[#out + 1] = r end
    end
    return out
end

-- Clean saved / imported data. Unknown refs are kept (they evaluate to unknown and never fire).
function ns.NormalizeWhen(r)
    if type(r.parentUid) ~= "string" or r.parentUid == "" then r.parentUid = nil end
    if type(r.uid) ~= "string" or r.uid == "" then r.uid = nil end
    if type(r.when) ~= "table" then r.when = { list = {} } end
    local clean = {}
    if type(r.when.list) == "table" then
        for _, t in ipairs(r.when.list) do
            if type(t) == "table" and #clean < MAX_TERMS then
                clean[#clean + 1] = { ref = (type(t.ref) == "string" and #t.ref <= 12) and t.ref or nil,
                                      neg = t.neg == true, op = (t.op == "or") and "or" or "and" }
            end
        end
    end
    r.when.list = clean
    -- display-only extras for the bundled view (plain data)
    if type(r.note) ~= "string" or r.note == "" then r.note = nil else r.note = r.note:sub(1, 200) end
    if r.ocCollapsed ~= true then r.ocCollapsed = nil end
end

-------------------------------------------------------------------------------
-- Evaluation
-------------------------------------------------------------------------------
-- tri-state value of one of the parent's triggers; nil = unknown / not in use
local function RefValue(ref, p, pr, pi)
    if ref == "cd" then
        if ns.CooldownUsed(p) then return pi.cdOK end
    elseif ref == "buff" then
        if ns.BuffUsed(p) then return pi.buffOK end
    elseif ref == "talents" then
        if p.talentMode == "all" or p.talentMode == "any" then return pi.talentOK end
    elseif ref == "parent" then
        if pr == true then return true end
        if pi.cdOK == false or pi.buffOK == false or pi.talentOK == false or pi.extraOK == false or pi.ctxOK == false then return false end
        return nil
    elseif type(ref) == "string" then
        local n = tonumber(ref:match("^x(%d+)$"))
        if n and pi.extraRows then return pi.extraRows[n] end
    end
    return nil
end

-- true / false / nil, detail. (A AND B) OR (C) ... with per-condition NOT.
local function EvalWhen(list, p, pr, pi)
    if #list == 0 then return nil, "no conditions added" end
    local groups, cur = {}, nil
    local why
    for i, t in ipairs(list) do
        local v = RefValue(t.ref, p, pr, pi)
        if v == nil then why = why or ("condition " .. i .. (t.ref and " is unknown or its trigger was removed" or " has nothing chosen")) end
        if v ~= nil and t.neg then v = not v end
        if i == 1 or t.op == "or" then cur = { anyFalse = false, anyNil = false }; groups[#groups + 1] = cur end
        if v == false then cur.anyFalse = true elseif v == nil then cur.anyNil = true end
    end
    local anyTrue, anyNil = false, false
    for _, g in ipairs(groups) do
        if g.anyFalse then
            -- this AND-group is false
        elseif g.anyNil then anyNil = true
        else anyTrue = true end
    end
    if anyTrue then return true, "matched" end
    if anyNil then return nil, why or "unknown" end
    return false, "no combination matched"
end

function ns.EvaluateOutcome(rule, ctx)
    local info = { ctx = ctx, missing = {}, outcome = true }
    local p = ns.FindParentRule(rule)
    if not p then
        info.missing[1] = "parent rule not found"
        info.result = false
        return false, info
    end
    local pr, pi = ns.Evaluate(p, ctx)
    -- inherit what the parent read, so this outcome's own display (buff time, charges, absorb text) works
    info.cd, info.present, info.buffSource, info.buffRef = pi.cd, pi.present, pi.buffSource, pi.buffRef
    if rule.spellID ~= p.spellID then rule.spellID = p.spellID end
    if rule.buffID ~= p.buffID then rule.buffID = p.buffID end
    if rule.maxCharges ~= p.maxCharges then rule.maxCharges = p.maxCharges end
    info.cdOK, info.buffOK, info.extraOK = true, true, true
    info.ctxOK, info.ctxFail = ns.CheckContext(rule, ctx)
    info.talentOK, info.talentDetail = ns.CheckTalents(rule)
    local list = (type(rule.when) == "table" and type(rule.when.list) == "table") and rule.when.list or {}
    info.whenOK, info.whenDetail = EvalWhen(list, p, pr, pi)
    info.result = (info.ctxOK == true) and (info.talentOK == true) and (info.whenOK == true)
    return info.result, info
end

-------------------------------------------------------------------------------
-- Options UI (called from Options.lua BuildRule; H = ns.UI)
-------------------------------------------------------------------------------
local function RefChoices(p)
    local v, o = {}, {}
    local function add(k, label) v[k] = label; o[#o + 1] = k end
    if p then
        if ns.CooldownUsed(p) then add("cd", "Cooldown trigger") end
        if ns.BuffUsed(p) then add("buff", "Buff / Aura trigger") end
        if p.talentMode == "all" or p.talentMode == "any" then add("talents", "Talents requirement") end
        local list = type(p.extra) == "table" and p.extra.list or {}
        for i, t in ipairs(list) do
            local d = ns.TRIGGER_TYPES and ns.TRIGGER_TYPES[t.type]
            add("x" .. i, "Trigger " .. i .. ":  " .. (d and d.label or "unknown type"))
        end
        add("parent", "The parent rule fires (all it requires)")
    end
    return v, o
end

-- On the parent: list its outcomes and add new ones.
function ns.BuildOutcomeArgs(rule, H)
    local args = {}
    args.oHeader = { type = "header", name = "Outcomes", order = 60 }
    args.oHelp = { type = "description", order = 60.1, width = "full", fontSize = "medium",
        name = "This rule's own sound and display fire when ALL of its triggers match (unchanged). An outcome is an extra rule that follows these triggers but fires its OWN sound and display when its own combination is true, "
            .. "for example 'Cooldown ready AND NOT Totem active'. Each outcome appears below as 'Condition 1', 'Condition 2' ... with its own combination, sound, display and load conditions, so everything for this rule stays on this page." }
    args.oAdd = { type = "execute", name = "Add an outcome", order = 60.2, width = "double",
        desc = "Creates a new rule next to this one, linked to it. Turn on its sound or display on its Conditions tab.",
        func = function()
            rule.uid = rule.uid or ns.NewUID()
            local n = ns.NewRule()
            n.name = tostring(rule.name) .. " - outcome " .. (#ns.OutcomesOf(rule) + 1)
            n.parentUid = rule.uid
            n.folder = rule.folder
            ns.rules[#ns.rules + 1] = n
            pcall(ns.RefreshVisual, n)
            ns.MarkDirty()
            H.Notify()
        end }
    for i, o in ipairs(ns.OutcomesOf(rule)) do
        args["o" .. i] = { type = "description", order = 61 + i, width = "full", fontSize = "medium",
            name = function()
                local ok, res = pcall(ns.Evaluate, o, ns.ReadContext())
                local word = (not ok and "|cffffd100error|r") or (res and "|cff55ff55true|r") or "|cffff5555false|r"
                return "|cffffd100" .. tostring(o.name) .. "|r  -  now " .. word .. (o.enabled and "" or "  (disabled)")
            end }
    end
    return args
end

-- On an outcome: the row builder.
function ns.BuildWhenArgs(rule, H)
    local args = {}
    if type(rule.when) ~= "table" then ns.NormalizeWhen(rule) end
    local W = rule.when
    local p = ns.FindParentRule(rule)
    local function on() H.Changed(rule) end
    local function onN() H.Changed(rule); H.Notify() end

    args.wHeader = { type = "header", name = "Combination", order = 0 }
    args.wParent = { type = "description", order = 0.1, width = "full", fontSize = "medium",
        name = function()
            local pp = ns.FindParentRule(rule)
            if not pp then return "|cffff5555The parent rule was not found (deleted?). This outcome cannot fire.|r" end
            return "Follows the triggers of:  |cffffd100" .. tostring(pp.name) .. "|r" end }
    args.wExpr = { type = "description", order = 0.2, width = "full", fontSize = "medium",
        name = function()
            local pp = ns.FindParentRule(rule)
            local vals = RefChoices(pp)
            if #W.list == 0 then return "Add conditions below. AND is evaluated before OR." end
            local parts = {}
            for i, t in ipairs(W.list) do
                local lbl = (t.ref and vals[t.ref]) or "(nothing chosen)"
                parts[#parts + 1] = (i > 1 and (t.op == "or" and "  |cff88ccffOR|r  " or "  |cff88ccffAND|r  ") or "") .. (t.neg and "|cffff8040NOT|r " or "") .. lbl
            end
            return "Fires when:  " .. table.concat(parts) .. "\n|cff888888AND is evaluated before OR.|r"
        end }
    args.wAdd = { type = "execute", name = "Add a condition", order = 0.3, width = "double",
        func = function()
            if #W.list >= MAX_TERMS then ns.Print("an outcome can hold at most " .. MAX_TERMS .. " conditions"); return end
            W.list[#W.list + 1] = { op = "and", neg = false }
            onN()
        end }
    for j, t in ipairs(W.list) do
        local row = {}
        if j > 1 then
            row.op = H.Sel(t, "op", "Joined to the previous with", 1, { ["and"] = "AND", ["or"] = "OR" }, { "and", "or" }, onN, { width = "double" })
        end
        row.ref = { type = "select", name = "Check", order = 2, width = "double",
            values = function() local v = RefChoices(ns.FindParentRule(rule)); return v end,
            sorting = function() local _, o = RefChoices(ns.FindParentRule(rule)); return o end,
            get = function() return t.ref end, set = function(_, v) t.ref = v; onN() end }
        row.neg = H.Tog(t, "neg", "NOT (invert this condition)", 3, onN, { width = "double" })
        row.status = { type = "description", order = 4, width = "double", fontSize = "medium",
            name = function()
                local pp = ns.FindParentRule(rule)
                if not pp then return "Right now: |cffffd100unknown|r" end
                local ok, pr, pi = pcall(function() local a, b = ns.Evaluate(pp, ns.ReadContext()); return a, b end)
                if not ok then return "Right now: |cffffd100unknown|r" end
                local v = RefValue(t.ref, pp, pr, pi)
                if v ~= nil and t.neg then v = not v end
                return "Right now: " .. ((v == true and "|cff55ff55true|r") or (v == false and "|cffff5555false|r") or "|cffffd100unknown|r")
            end }
        row.remove = { type = "execute", name = "Remove", order = 5, width = "half",
            func = function() table.remove(W.list, j); onN() end }
        args["w" .. j] = { type = "group", inline = true, order = 1 + j, name = "Condition " .. j, args = row }
    end
    return args
end


-------------------------------------------------------------------------------
-- Bundling: outcomes are shown inside their parent rule instead of as separate list entries.
-------------------------------------------------------------------------------
-- Put an outcome's settings (its own combination, sound / display, load conditions, name) on the parent's Conditions tab.
function ns.EmbedOutcome(pg, og, rule, k)
    local host = pg.args and pg.args.actions and pg.args.actions.args
    if not host or not og.args then return end
    local function sub(g, order, name)
        if not g then return nil end
        return { type = "group", inline = true, order = order, name = name, args = g.args }
    end
    host["oc" .. k] = { type = "group", inline = true, order = 100 + k,
        name = function() return "Condition " .. k .. ":  " .. tostring(rule.name) .. (rule.enabled and "" or "  (disabled)") end,
        args = {
            toggle = { type = "execute", order = 0.1, width = "half",
                name = function() return rule.ocCollapsed and "Expand" or "Collapse" end,
                desc = "Show or hide this condition's settings. The note below stays visible.",
                func = function() rule.ocCollapsed = (not rule.ocCollapsed) or nil; ns.MarkDirty(); ns.UI.Notify() end },
            note = { type = "input", order = 0.2, width = "double",
                name = "Note (what this condition fires for)",
                desc = "Free text for you. Stays visible while the condition is collapsed.",
                get = function() return rule.note or "" end,
                set = function(_, v) v = tostring(v or ""):sub(1, 200); rule.note = (v ~= "") and v or nil; ns.MarkDirty() end,
                disabled = function() return ns.IsEditLocked and ns.IsEditLocked(rule) end },
            summary = { type = "description", order = 0.3, width = "full", fontSize = "medium",
                hidden = function() return not rule.ocCollapsed end,
                name = function()
                    local ok, res = pcall(ns.Evaluate, rule, ns.ReadContext())
                    local word = (not ok and "|cffffd100error|r") or (res and "|cff55ff55true|r") or "|cffff5555false|r"
                    return (rule.note and ("|cffffffff" .. rule.note .. "|r  -  ") or "|cff888888(no note)|r  -  ") .. "now " .. word
                end },
            when = sub(og.args.trigger, 1, "When this condition fires"),
            act  = sub(og.args.actions, 2, "Sound and display"),
            load = sub(og.args.load, 3, "Load conditions"),
            rule = sub(og.args.rule, 4, "Name, enable and delete"),
        } }
    for _, key in ipairs({ "when", "act", "load", "rule" }) do
        local g = host["oc" .. k].args[key]
        if g then g.hidden = function() return rule.ocCollapsed == true end end
    end
end

function ns.DeleteOutcomesOf(parent)
    for _, o in ipairs(ns.OutcomesOf(parent)) do
        for idx, r in ipairs(ns.rules) do if r == o then table.remove(ns.rules, idx); break end end
        pcall(ns.DropVisual, o)
    end
end

-- Duplicating a parent: the copy gets its own uid and its own copies of the outcomes.
function ns.CloneOutcomes(src, copy)
    if src.parentUid then copy.uid = nil; return end
    if type(src.uid) ~= "string" then return end
    copy.uid = ns.NewUID()
    for _, o in ipairs(ns.OutcomesOf(src)) do
        local c = ns.Copy(o)
        c.uid = nil
        c.parentUid = copy.uid
        ns.rules[#ns.rules + 1] = c
        pcall(ns.RefreshVisual, c)
    end
end

-- Duplicating a folder: new uids for copied parents, outcomes re-pointed at their copied parent.
local copies
function ns.RememberCopy(src, c)
    copies = copies or {}
    copies[#copies + 1] = { src = src, c = c }
end
function ns.RemapCopies()
    if not copies then return end
    local map = {}
    for _, e in ipairs(copies) do
        if type(e.src.uid) == "string" and not e.src.parentUid then
            e.c.uid = ns.NewUID()
            map[e.src.uid] = e.c.uid
        end
    end
    for _, e in ipairs(copies) do
        if e.src.parentUid then
            e.c.uid = nil
            e.c.parentUid = map[e.src.parentUid] or e.src.parentUid
        end
    end
    copies = nil
end
