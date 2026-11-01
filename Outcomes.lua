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

-- Rewrite the "x<N>" references of this rule's outcomes. fn(N) returns the new ref string, or nil to drop the reference.
function ns.RemapOutcomeRefs(parent, fn)
    for _, o in ipairs(ns.OutcomesOf(parent)) do
        if type(o.when) == "table" and type(o.when.list) == "table" then
            for _, t in ipairs(o.when.list) do
                local n = type(t.ref) == "string" and t.ref:match("^x(%d+)$")
                local nn = (not n) and type(t.ref) == "string" and t.ref:match("^n:x(%d+)$")
                if n then t.ref = fn(tonumber(n))
                elseif nn then local r = fn(tonumber(nn)); t.ref = r and ("n:" .. r) or nil end
            end
        end
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
                local cmp = t.cmp
                if cmp ~= ">" and cmp ~= ">=" and cmp ~= "<=" and cmp ~= "<" then cmp = "==" end
                clean[#clean + 1] = { ref = (type(t.ref) == "string" and #t.ref <= 12) and t.ref or nil,
                                      neg = t.neg == true, op = (t.op == "or") and "or" or "and", cmp = cmp, num = tonumber(t.num) or 0 }
            end
        end
    end
    r.when.list = clean
    -- display-only extras for the bundled view (plain data)
    if type(r.note) ~= "string" or r.note == "" then r.note = nil else r.note = r.note:sub(1, 200) end
    if type(r.description) ~= "string" or r.description == "" then r.description = nil else r.description = r.description:sub(1, 500) end
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

local function IsNumRef(ref) return type(ref) == "string" and ref:sub(1, 2) == "n:" end
ns.IsNumRef = IsNumRef

-- The number behind a numeric check, or nil when the game will not tell us (secret in combat etc.): nil makes the check unknown, never a guess.
local function NumRef(ref, p, pi)
    local now = GetTime()
    local function SpellID() local id = tonumber(p.spellID) or 0; return id ~= 0 and id or nil end
    if ref == "n:cdCharges" then
        local id = SpellID(); if not id then return nil end
        local ok, ch = pcall(C_Spell.GetSpellCharges, id)
        if ok and type(ch) == "table" then
            local c = ch.currentCharges
            if type(c) == "number" and not issecret(c) then return c end
            return nil
        end
        if pi.cd and pi.cd.known then return pi.cd.onCd and 0 or 1 end
        return nil
    elseif ref == "n:cdRemain" then
        local id = SpellID(); if not id then return nil end
        local ok, cd = pcall(C_Spell.GetSpellCooldown, id)
        if not ok or type(cd) ~= "table" then return nil end
        local st, du, act, gcd = cd.startTime, cd.duration, cd.isActive, cd.isOnGCD
        if issecret(st) or issecret(du) or issecret(act) or issecret(gcd) then return nil end
        if not act or gcd or type(du) ~= "number" or du <= 0 or type(st) ~= "number" then return 0 end
        return math.max(0, st + du - now)
    elseif ref == "n:buffStacks" then
        if pi.present == false then return 0 end
        if pi.present == true and pi.buffRef then
            local a = pi.buffRef.applications
            if type(a) == "number" and not issecret(a) then return math.max(a, 1) end
            if a == nil then return 1 end
        end
        return nil
    elseif ref == "n:buffRemain" then
        if pi.present == false then return 0 end
        if pi.present == true and pi.buffRef and type(pi.buffRef.expiration) == "number" and pi.buffRef.expiration > 0 then
            return math.max(0, pi.buffRef.expiration - now)
        end
        return nil
    end
    local n = tonumber(ref:match("^n:x(%d+)$"))
    if n and type(p.extra) == "table" and type(p.extra.list) == "table" and ns.TriggerNumber then return ns.TriggerNumber(p.extra.list[n]) end
    return nil
end
ns.NumRef = NumRef

local function CmpNum(op, a, b)
    if type(a) ~= "number" or type(b) ~= "number" then return nil end
    if op == ">" then return a > b elseif op == ">=" then return a >= b elseif op == "<=" then return a <= b
    elseif op == "<" then return a < b end
    return a == b
end

-- One check: true / false / nil (unknown).
local function CheckValue(t, p, pr, pi)
    if IsNumRef(t.ref) then return CmpNum(t.cmp, NumRef(t.ref, p, pi), tonumber(t.num) or 0) end
    local v = RefValue(t.ref, p, pr, pi)
    if v ~= nil and t.neg then v = not v end
    return v
end
ns.CheckValue = CheckValue

-- true / false / nil, detail. (A AND B) OR (C) ... with per-condition NOT.
local function EvalWhen(list, p, pr, pi)
    if #list == 0 then return nil, "no conditions added" end
    local groups, cur = {}, nil
    local why
    for i, t in ipairs(list) do
        local v = CheckValue(t, p, pr, pi)
        if v == nil then why = why or ("check " .. i .. (t.ref and " is unknown or its trigger was removed" or " has nothing chosen")) end
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
    if rule.isCue and ns.EvaluateCue then return ns.EvaluateCue(rule, ctx) end
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
    -- load conditions live in ONE place: the parent rule's Load tab. An outcome never has its own.
    info.ctxOK, info.ctxFail = ns.CheckContext(p, ctx)
    info.talentOK, info.talentDetail = ns.CheckTalents(p)
    local list = (type(rule.when) == "table" and type(rule.when.list) == "table") and rule.when.list or {}
    info.whenOK, info.whenDetail = EvalWhen(list, p, pr, pi)
    info.result = (info.ctxOK == true) and (info.talentOK == true) and (info.whenOK == true)
    return info.result, info
end

-------------------------------------------------------------------------------
-- Options UI (called from Options.lua BuildRule; H = ns.UI)
-------------------------------------------------------------------------------
local function RefChoices(p)  -- also exported below
    local v, o = {}, {}
    local function add(k, label) v[k] = label; o[#o + 1] = k end
    if p then
        local P = ns.TriggerPositions and ns.TriggerPositions(p)
        if ns.CooldownUsed(p) then add("cd", ns.TriggerChoiceLabel(p, "cd", nil, (P and P.cd) or 1, "Cooldown")) end
        if ns.BuffUsed(p) then add("buff", ns.TriggerChoiceLabel(p, "buff", nil, (P and P.buff) or 1, "Buff / Aura")) end
        if p.talentMode == "all" or p.talentMode == "any" then add("talents", "Talents requirement") end
        local list = type(p.extra) == "table" and p.extra.list or {}
        for i, t in ipairs(list) do
            local d = ns.TRIGGER_TYPES and ns.TRIGGER_TYPES[t.type]
            add("x" .. i, ns.TriggerChoiceLabel(p, "x", i, (P and P.xs[i]) or i, d and d.label or "unknown type"))
        end
        add("parent", "The parent rule fires (all it requires)")
        if ns.CooldownUsed(p) then
            add("n:cdCharges", "Cooldown: charges  (number)")
            add("n:cdRemain", "Cooldown: seconds left  (number)")
        end
        if ns.BuffUsed(p) then
            add("n:buffStacks", "Buff / Aura: stacks  (number)")
            add("n:buffRemain", "Buff / Aura: seconds left  (number)")
        end
        for i, t in ipairs(list) do
            if t.type == "itemCount" or t.type == "resource" then
                add("n:x" .. i, "Trigger " .. ((P and P.xs[i]) or i) .. ":  " .. ((t.type == "itemCount") and "item count" or "resource amount") .. "  (number)")
            end
        end
    end
    return v, o
end

-- On the parent: list its outcomes and add new ones.
function ns.RefChoicesFor(p) return RefChoices(p) end

-- On the parent (Conditions tab): the intro and the Add button. Each condition itself is added by EmbedOutcome below.
function ns.BuildOutcomeArgs(rule, H)
    local args = {}
    args.oHeader = { type = "header", name = "Conditions", order = 60 }
    args.oHelp = { type = "description", order = 60.1, width = "full", fontSize = "medium",
        name = "A condition is  IF  checks are met  THEN  cues play. Make the cues on the Cues tab, then pick them under THEN. Load conditions come from the Load tab." }
    args.oAdd = { type = "execute", name = "Add a condition", order = 60.2, width = "double", arg = { xuiRed = true },
        desc = "Creates a new condition for this rule. It starts as: IF the first trigger is true.",
        func = function()
            rule.uid = rule.uid or ns.NewUID()
            local n = ns.NewRule()
            n.name = "Condition " .. (#ns.ConditionsOf(rule) + 1)
            n.parentUid = rule.uid
            n.folder = rule.folder
            n.sound.enabled, n.visual.enabled = false, false
            local _, pk = ns.RefChoicesFor(rule)
            n.when = { list = { { ref = pk and pk[1] or nil, neg = false, op = "and", cmp = "==", num = 0 } } }
            ns.rules[#ns.rules + 1] = n
            ns.MarkDirty()
            ;(H.NotifyTwice or H.Notify)()
        end }
    return args
end

-- On the parent (Cues tab): intro and the "Add a cue" dropdown.
function ns.BuildCueArgs(rule, H)
    local args = {}
    args.cHeader = { type = "header", name = "Cues", order = 60 }
    args.cHelp = { type = "description", order = 60.1, width = "full", fontSize = "medium",
        name = "A cue is something that happens: a sound, text, a texture or an icon. Create them here, then choose when they happen on the Conditions tab." }
    local vals = {}
    for _, k in ipairs(ns.CUE_KINDS) do vals[k] = ns.CUE_KIND_LABEL[k] end
    args.cAdd = { type = "select", order = 60.2, width = "double", name = "Add a cue", values = vals, sorting = ns.CUE_KINDS,
        desc = "Pick what kind of cue to create. It is added below.",
        get = function() return nil end,
        set = function(_, v)
            rule.uid = rule.uid or ns.NewUID()
            if ns.NewCueRule(rule, v) then (H.NotifyTwice or H.Notify)() end
        end }
    return args
end

function ns.BuildWhenArgs(rule, H) return {} end

local CMP_VALUES = { ["=="] = "=", [">"] = ">", [">="] = ">=", ["<="] = "<=", ["<"] = "<" }
local CMP_ORDER = { "==", ">", ">=", "<=", "<" }
local ONLY_EQ, ONLY_EQ_ORDER = { ["=="] = "=" }, { "==" }
local TF_VALUES = { ["true"] = "TRUE", ["false"] = "FALSE" }
local TF_ORDER = { "true", "false" }

-- The IF rows, the THEN picker and the live status of one condition. Returns an args table.
local function ConditionBody(rule, H)
    local args = {}
    if type(rule.when) ~= "table" then ns.NormalizeWhen(rule) end
    local W = rule.when
    local function onN() H.Changed(rule); (H.NotifyTwice or H.Notify)() end
    local function collapsed() return rule.ocCollapsed == true end
    local function locked() return ns.IsEditLocked and ns.IsEditLocked(rule) end
    local function refChoices() return RefChoices(ns.FindParentRule(rule)) end
    args.ifLabel = { type = "description", order = 10, width = "full", fontSize = "medium", hidden = collapsed, name = "|cffffd100IF|r" }
    for j, t in ipairs(W.list) do
        local o = 10 + j
        if j > 1 then
            args["j" .. j] = { type = "select", order = o, width = "relative", relWidth = 0.14, name = "", arg = { xuiTextLeft = true }, hidden = collapsed,
                values = { ["and"] = "AND", ["or"] = "OR" }, sorting = { "and", "or" },
                get = function() return t.op end,
                set = function(_, v) t.op = v; onN() end, disabled = locked }
        end
        args["r" .. j] = { type = "select", order = o + 0.01, width = "relative", relWidth = (j == 1) and 0.48 or 0.34, name = "", arg = { xuiTextLeft = true }, hidden = collapsed,
            desc = "What to check.",
            values = function() local v = refChoices(); return v end,
            sorting = function() local _, od = refChoices(); return od end,
            get = function() return t.ref end,
            set = function(_, v) t.ref = v; if IsNumRef(v) then t.neg = false end; onN() end,
            disabled = locked }
        args["c" .. j] = { type = "select", order = o + 0.02, width = "relative", relWidth = 0.16, name = "", arg = { xuiTextLeft = true }, hidden = collapsed,
            values = function() return IsNumRef(t.ref) and CMP_VALUES or ONLY_EQ end,
            sorting = function() return IsNumRef(t.ref) and CMP_ORDER or ONLY_EQ_ORDER end,
            get = function() return IsNumRef(t.ref) and (t.cmp or "==") or "==" end,
            set = function(_, v) t.cmp = v; onN() end,
            disabled = function() return not IsNumRef(t.ref) or locked() end }
        args["b" .. j] = { type = "select", order = o + 0.03, width = "relative", relWidth = 0.2, name = "", arg = { xuiTextLeft = true }, values = TF_VALUES, sorting = TF_ORDER,
            hidden = function() return collapsed() or IsNumRef(t.ref) end,
            get = function() return t.neg and "false" or "true" end,
            set = function(_, v) t.neg = (v == "false"); onN() end, disabled = locked }
        args["n" .. j] = { type = "input", order = o + 0.03, width = "relative", relWidth = 0.2, name = "",
            hidden = function() return collapsed() or not IsNumRef(t.ref) end,
            get = function() return tostring(t.num or 0) end,
            set = function(_, v) t.num = tonumber(v) or 0; onN() end, disabled = locked }
        args["s" .. j] = { type = "description", order = o + 0.035, width = "relative", relWidth = 0.04, fontSize = "medium", hidden = collapsed,
            name = function()
                local p = ns.FindParentRule(rule)
                local v
                if p and t.ref then
                    local ok, r = pcall(function()
                        local pr, pi = ns.Evaluate(p, ns.ReadContext())
                        return ns.CheckValue(t, p, pr, pi)
                    end)
                    if ok then v = r end
                end
                local tex = (v == true and "Indicator-Green") or (v == false and "Indicator-Red") or "Indicator-Yellow"
                return "|TInterface\\COMMON\\" .. tex .. ":16:16:0:-4|t"
            end }
        args["x" .. j] = { type = "execute", order = o + 0.04, width = "relative", relWidth = 0.06, name = "X", hidden = collapsed, arg = { xuiDel = true },
            desc = "Remove this check.",
            func = function() table.remove(W.list, j); onN() end, disabled = locked }
    end
    args.add = { type = "select", order = 60, width = "relative", relWidth = 0.34, name = "", arg = { xuiTextLeft = true }, hidden = collapsed,
        desc = "Add another check to this condition. AND needs both, OR needs either (AND is evaluated before OR).",
        values = { none = "+ add check...", ["and"] = "AND", ["or"] = "OR" }, sorting = { "none", "and", "or" },
        get = function() return "none" end,
        set = function(_, v)
            if v == "and" or v == "or" then
                if #W.list >= MAX_TERMS then ns.Print("a condition can hold at most " .. MAX_TERMS .. " checks"); return end
                W.list[#W.list + 1] = { op = v, neg = false, cmp = "==", num = 0 }
                onN()
            end
        end, disabled = locked }
    local function hasCues() local p = ns.FindParentRule(rule); return p and #ns.CuesOf(p) > 0 end
    args.thenNone = { type = "description", order = 70, width = "full", fontSize = "medium",
        hidden = function() return collapsed() or hasCues() end,
        name = "|cffffd100THEN|r  |cff888888no cues yet. Create one on the Cues tab.|r" }
    args.thenPick = { type = "multiselect", dialogControl = "Dropdown", order = 70, width = "full", name = "THEN", arg = { xuiSide = true },
        hidden = function() return collapsed() or not hasCues() end,
        desc = "The cues that play while this condition is true.",
        values = function()
            local v, p = {}, ns.FindParentRule(rule)
            if p then for _, c in ipairs(ns.CuesOf(p)) do v[c.cueKey or "?"] = ns.CueLabel(c) .. "  (" .. (ns.CUE_KIND_LABEL[c.cueKind] or "") .. ")" end end
            return v
        end,
        get = function(_, key) for _, k in ipairs(rule.thenCues or {}) do if k == key then return true end end return false end,
        set = function(_, key, val)
            local list, out = rule.thenCues or {}, {}
            for _, k in ipairs(list) do if k ~= key then out[#out + 1] = k end end
            if val then out[#out + 1] = key end
            rule.thenCues = (#out > 0) and out or nil
            if not val and rule.thenMods then   -- a cue that is no longer listed loses its modifiers
                rule.thenMods[key] = nil
                if next(rule.thenMods) == nil then rule.thenMods = nil end
            end
            ns.MarkDirty(); H.Changed(rule)
        end, disabled = locked }

    -- Modifiers: while this condition is true, change how a listed display cue looks (glow, desaturate, opacity).
    -- One picker chooses which listed cue the three controls edit. Sounds and speech have no look, so they are not offered.
    local VIS_KIND = { text = true, texture = true, icon = true }
    local function listed(key) for _, k in ipairs(rule.thenCues or {}) do if k == key then return true end end return false end
    local function modChoices()
        local vals, order = {}, {}
        local p = ns.FindParentRule(rule)
        if p then
            for _, c in ipairs(ns.CuesOf(p)) do
                if VIS_KIND[c.cueKind] and c.cueKey and listed(c.cueKey) then
                    vals[c.cueKey] = ns.CueLabel(c); order[#order + 1] = c.cueKey
                end
            end
        end
        return vals, order
    end
    local function modKey()
        local vals, order = modChoices()
        ns.modPick = ns.modPick or setmetatable({}, { __mode = "k" })
        local k = ns.modPick[rule]
        if k and vals[k] then return k end
        return order[1]
    end
    local function noMods() local _, order = modChoices(); return collapsed() or #order == 0 end
    local function modGet(field)
        local k = modKey()
        local m = k and type(rule.thenMods) == "table" and rule.thenMods[k] or nil
        return m and m[field]
    end
    local function modSet(field, v)
        local k = modKey()
        if not k then return end
        rule.thenMods = rule.thenMods or {}
        local m = rule.thenMods[k] or {}
        m[field] = v
        rule.thenMods[k] = next(m) and m or nil
        if next(rule.thenMods) == nil then rule.thenMods = nil end
        ns.MarkDirty(); onN()
    end
    local function tri(field, onWord, offWord, keepWord)
        return {
            values = { keep = keepWord, on = onWord, off = offWord }, sorting = { "keep", "on", "off" },
            get = function() local v = modGet(field); if v == true then return "on" elseif v == false then return "off" end return "keep" end,
            set = function(_, v) modSet(field, (v == "on") and true or (v == "off") and false or nil) end,
        }
    end
    args.modLabel = { type = "description", order = 71, width = "full", fontSize = "medium", hidden = noMods,
        name = "|cffffd100AND CHANGE|r  |cff888888while this condition is true (the later condition wins if two disagree):|r" }
    args.modCue = { type = "select", order = 71.1, width = "relative", relWidth = 0.48, name = "", arg = { xuiTextLeft = true }, hidden = noMods,
        desc = "Which of the cues listed under THEN the three settings next to it apply to.",
        values = function() local v = modChoices(); return v end,
        sorting = function() local _, o = modChoices(); return o end,
        get = function() return modKey() end,
        set = function(_, v) ns.modPick = ns.modPick or setmetatable({}, { __mode = "k" }); ns.modPick[rule] = v; onN() end, disabled = locked }
    local g = tri("glow", "Glow: on", "Glow: off", "Glow: no change")
    args.modGlow = { type = "select", order = 71.2, width = "relative", relWidth = 0.24, name = "", arg = { xuiTextLeft = true }, hidden = noMods,
        desc = "Turn the cue's pulsing glow on or off while this condition is true. No change keeps the cue's own Display setting.",
        values = g.values, sorting = g.sorting, get = g.get, set = g.set, disabled = locked }
    local d = tri("desat", "Desaturate", "Full color", "Color: no change")
    args.modDesat = { type = "select", order = 71.3, width = "relative", relWidth = 0.26, name = "", arg = { xuiTextLeft = true }, hidden = noMods,
        desc = "Gray the cue out (or force full color) while this condition is true. No change keeps the cue's own Display setting.",
        values = d.values, sorting = d.sorting, get = d.get, set = d.set, disabled = locked }
    args.modAlpha = { type = "select", order = 71.4, width = "relative", relWidth = 0.34, name = "", arg = { xuiTextLeft = true }, hidden = noMods,
        desc = "Replace the cue's opacity while this condition is true. No change keeps the cue's own Display setting.",
        values = { keep = "Opacity: no change", set = "Opacity: set to..." }, sorting = { "keep", "set" },
        get = function() return modGet("alpha") ~= nil and "set" or "keep" end,
        set = function(_, v) modSet("alpha", (v == "set") and (modGet("alpha") or 0.5) or nil) end, disabled = locked }
    args.modAlphaN = { type = "input", order = 71.5, width = "relative", relWidth = 0.2, name = "", hidden = function() return noMods() or modGet("alpha") == nil end,
        desc = "Opacity in percent, 0 (invisible) to 100 (solid).",
        get = function() return tostring(math.floor((modGet("alpha") or 0.5) * 100 + 0.5)) end,
        set = function(_, v) local n = tonumber(v); if n then modSet("alpha", math.max(0, math.min(100, n)) / 100) end end, disabled = locked }
    args.status = { type = "description", order = 80, width = "full", fontSize = "medium", hidden = collapsed,
        name = function()
            local ok, res = pcall(ns.Evaluate, rule, ns.ReadContext())
            local word = (not ok and "|cffffd100error|r") or (res and "|cff55ff55TRUE|r") or "|cffff5555FALSE|r"
            return "Right now: " .. word .. "     |cff888888Each check's light:  |r|cff55ff55green|r|cff888888 = met,  |r|cffff5555red|r|cff888888 = not met,  |r|cffffd100yellow|r|cff888888 = unknown.|r"
        end }
    return args
end

-------------------------------------------------------------------------------
-- Bundling: conditions are shown on their parent's Conditions tab, cues on its Cues tab.
-------------------------------------------------------------------------------
local function SiblingList(rule)
    local par = ns.FindParentRule(rule)
    if not par then return {} end
    return rule.isCue and ns.CuesOf(par) or ns.ConditionsOf(par)
end
local function MoveOutcome(rule, dir)
    local list, pos = SiblingList(rule), nil
    for i, r in ipairs(list) do if r == rule then pos = i end end
    local other = pos and list[pos + dir]
    if not other then return end
    local ia, ib
    for i, r in ipairs(ns.rules) do if r == rule then ia = i elseif r == other then ib = i end end
    if not (ia and ib) then return end
    ns.rules[ia], ns.rules[ib] = ns.rules[ib], ns.rules[ia]
    ns.MarkDirty(); (ns.UI.NotifyTwice or ns.UI.Notify)()
end
local function CopyOutcome(rule)
    local c = ns.Copy(rule)
    c.uid = nil
    if rule.isCue then
        local par = ns.FindParentRule(rule)
        if par then c.cueKey = ns.CueKey(par) end
        c.cueName = ns.CueLabel(rule) .. " copy"
    else
        c.name = ((rule.name and rule.name ~= "") and rule.name or "Condition") .. " Copy"
    end
    for i, r in ipairs(ns.rules) do if r == rule then table.insert(ns.rules, i + 1, c); break end end
    pcall(ns.RefreshVisual, c)
    ns.MarkDirty(); (ns.UI.NotifyTwice or ns.UI.Notify)()
end
local function RemoveOutcome(rule)
    local parent = ns.FindParentRule(rule)   -- only this cue / condition goes; its rule stays and stays open
    if rule.isCue then ns.DeleteCue(rule)
    else
        for i, r in ipairs(ns.rules) do if r == rule then table.remove(ns.rules, i); break end end
        pcall(ns.DropVisual, rule)
    end
    ns.MarkDirty()
    if parent and ns.ReselectRule then ns.ReselectRule(parent) end   -- before the rebuild, so the pane does not fall back to another page
    (ns.UI.NotifyTwice or ns.UI.Notify)()
end

local OPEN = "|TInterface\\Buttons\\Arrow-Down-Up:16:16|t"
local CLOSED = "|TInterface\\ChatFrame\\ChatFrameExpandArrow:16:16|t"
local function Header(rule, titleFn, edit)
    return { type = "execute", order = 0.05, width = "full",
        arg = { xuiLeft = true, xuiHeadOut = ns.BODY_INDENT or 20, xuiEdit = edit, xuiSub = (edit and edit.title) and function() return " " end or nil, xuiActions = function()
            local list, pos = SiblingList(rule), nil
            for i, r in ipairs(list) do if r == rule then pos = i end end
            return {
                up = (pos and pos > 1) and function() MoveOutcome(rule, -1) end or false,
                down = (pos and pos < #list) and function() MoveOutcome(rule, 1) end or false,
                copy = function() CopyOutcome(rule) end,
                del = function() RemoveOutcome(rule) end,
            }
        end },
        name = function() return (rule.ocCollapsed and CLOSED or OPEN) .. ((edit and not edit.title) and "" or ("  " .. ((edit and edit.title) and edit.title() or titleFn()))) end,
        desc = "Expand or collapse.",
        func = function() rule.ocCollapsed = (not rule.ocCollapsed) or nil; ns.MarkDirty(); ns.UI.Notify() end }
end

local function EmbedCondition(pg, rule, k)
    local host = pg.args and pg.args.conditions and pg.args.conditions.args
    if not host then return end
    local function locked() return ns.IsEditLocked and ns.IsEditLocked(rule) end
    local g = { type = "group", inline = true, order = 100 + k, name = "", arg = { xuiIndent = ns.BODY_INDENT or 20 }, args = {} }
    local function dot()
        local ok, res = pcall(ns.Evaluate, rule, ns.ReadContext())
        return (not ok and "|cffffd100o|r") or (res and "|cff55ff55o|r") or "|cffff5555o|r"
    end
    local function condPos() local list = SiblingList(rule); for i, r in ipairs(list) do if r == rule then return i end end return 1 end
    local function autoName(n) return type(n) ~= "string" or n:match("^%s*$") or n:match("^Condition %d+$") end   -- "Condition 3" was the auto name, not a chosen one
    g.args.hdr = Header(rule, function() return tostring(rule.name) end, {
        title = function() return "Condition " .. condPos() end,   -- the number is the title; the name is typed beneath it
        get = function() if autoName(rule.name) then return "" end return tostring(rule.name) end,
        set = function(v) v = tostring(v or ""):sub(1, 60); rule.name = v:match("%S") and v or ("Condition " .. condPos()); ns.MarkDirty(); ns.UI.Notify() end,
        hint = function() return dot() .. (rule.enabled == false and "  (off)" or "") end,
    })
    g.args.enabled = { type = "toggle", order = 0.2, width = "half", name = "On",
        desc = "Turn this condition on or off. An off condition never plays its cues.",
        get = function() return rule.enabled ~= false end,
        set = function(_, v) rule.enabled = v and true or false; ns.MarkDirty(); ns.UI.Notify() end, disabled = locked }
    for key, a in pairs(ConditionBody(rule, ns.UI)) do g.args[key] = a end
    host["oc" .. k] = g
end

local function EmbedCue(pg, og, rule, k)
    local host = pg.args and pg.args.cues and pg.args.cues.args
    if not host then return end
    local function locked() return ns.IsEditLocked and ns.IsEditLocked(rule) end
    local function collapsed() return rule.ocCollapsed == true end
    local g = { type = "group", inline = true, order = 100 + k, name = "", arg = { xuiIndent = ns.BODY_INDENT or 20 }, args = {} }
    g.args.hdr = Header(rule, function() return ns.CueLabel(rule) end, {
        title = function() return ns.CueDefaultLabel(rule) end,   -- e.g. "Sound 1": the number is the title; the name is typed beneath it
        get = function() return (type(rule.cueName) == "string" and rule.cueName:match("%S")) and rule.cueName or "" end,
        set = function(v)
            v = tostring(v or ""):sub(1, 60)
            if v:match("%S") and v ~= ns.CueDefaultLabel(rule) then rule.cueName = v else rule.cueName = nil end
            ns.MarkDirty(); ns.UI.Notify()
        end,
        hint = function() return "" end,
    })
    g.args.descH = { type = "header", order = 0.15, name = "Description", hidden = collapsed }
    g.args.descGap = { type = "description", order = 0.25, width = "full", name = " ", fontSize = "large", hidden = collapsed }
    g.args.desc = { type = "input", order = 0.2, width = "full", name = "", hidden = collapsed,
        get = function() return rule.cueDesc or "" end,
        set = function(_, v) v = tostring(v or ""):sub(1, 300); rule.cueDesc = (v:match("%S")) and v or nil; ns.MarkDirty() end, disabled = locked }
    local acts = (og.args.actions and og.args.actions.args) or {}
    local function put(key, src)
        if not src then return end
        local orig = src.hidden
        src.hidden = function(...) if collapsed() then return true end; if type(orig) == "function" then return orig(...) end; return orig end
        g.args[key] = src
    end
    local parts = og.args.actions and og.args.actions.xuiParts
    local function box(key, order, title, args)
        local grp = { type = "group", inline = true, order = order, name = title or "", args = args }
        put(key, grp); grp.order = order
    end
    local function sub(key, order, node) if node then put(key, node); node.order = order end end
    -- the cue's own header already names it ("Sound 1"), so its options sit directly under it: no second box titled "Sound"
    local function flat(prefix, base, body)
        for key, node in pairs(body or {}) do
            put(prefix .. "_" .. key, node)
            node.order = base + (tonumber(node.order) or 0) / 1000
        end
    end
    if parts and (rule.cueKind == "sound" or rule.cueKind == "speech" or rule.cueKind == "text" or rule.cueKind == "texture" or rule.cueKind == "icon") then
        -- a cue is always on: no "Show ..." tick box, no Options +/- and no "Show when" menu (that is what Conditions decides)
        if rule.cueKind == "sound" then
            rule.sound.enabled = true
            flat("snd", 3, parts.soundBody)
        elseif rule.cueKind == "speech" then
            rule.sound.enabled = true; rule.sound.source = "tts"
            flat("spk", 3, parts.speechBody)
        else
            rule.visual.enabled = true; rule.visual.trigger = "condition"
            if rule.cueKind == "text" then
                parts.ensureText()
                flat("txt", 3, parts.textBody)
            else
                box("tex", 3, (rule.cueKind == "icon") and "Icon Options" or "Texture Options", parts.tex)
                sub("color", 4, parts.colorSub)
                sub("pos", 5, parts.posSub)
                sub("anim", 6, parts.animSub)
                local tx = acts.text
                if tx then put("text", tx); tx.order = 7 end
            end
        end
    else
        g.args.custom = { type = "description", order = 5, width = "full", fontSize = "medium", hidden = collapsed,
            name = "|cff888888Custom cues will run your own Lua. This is not available yet: it will be off by default, switched on per rule, and never run from an imported rule without your consent.|r" }
    end
    host["oq" .. k] = g
end

-- Put a child rule on its parent: a condition on the Conditions tab, a cue on the Cues tab.
function ns.EmbedOutcome(pg, og, rule, k)
    if rule.isCue then return EmbedCue(pg, og, rule, k) end
    return EmbedCondition(pg, rule, k)
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

-- Does this rule have outcomes? (cached once per engine tick; the options window recomputes on demand)
local hasOut, hasTick = {}, nil
function ns.HasOutcomes(rule)
    if rule.parentUid or type(rule.uid) ~= "string" then return false end
    if ns.tickID == nil or hasTick ~= ns.tickID then
        hasOut = {}
        for _, r in ipairs(ns.rules or {}) do
            if type(r.parentUid) == "string" and not r.isCue then hasOut[r.parentUid] = true end
        end
        hasTick = ns.tickID
    end
    return hasOut[rule.uid] == true
end


-- One line saying WHY a rule or outcome does / does not fire right now (used by /xui status).
function ns.ExplainRule(rule, ctx)
    local function tv(v) return v == true and "true" or (v == false and "false" or "UNKNOWN") end
    local p = rule.parentUid and ns.FindParentRule(rule) or rule
    if not p then return "parent rule not found" end
    local _, pi = ns.Evaluate(p, ctx)
    local parts = {}
    if ns.CooldownUsed(p) then parts[#parts + 1] = "cd=" .. tv(pi.cdOK) end
    if ns.BuffUsed(p) then parts[#parts + 1] = "buff=" .. tv(pi.buffOK) end
    local list = type(p.extra) == "table" and type(p.extra.list) == "table" and p.extra.list or {}
    for i, t in ipairs(list) do
        parts[#parts + 1] = "x" .. i .. "(" .. tostring(t.type) .. ")=" .. tv(pi.extraRows and pi.extraRows[i]) .. ((pi.extraWhys and pi.extraWhys[i]) and (" [" .. tostring(pi.extraWhys[i]) .. "]") or "")
    end
    parts[#parts + 1] = "load=" .. tv(pi.ctxOK) .. ((pi.ctxOK ~= true and pi.ctxFail) and (" [" .. tostring(pi.ctxFail) .. "]") or "")
    parts[#parts + 1] = "talents=" .. tv(pi.talentOK)
    local s = (rule.parentUid and "outcome of '" .. tostring(p.name) .. "': " or "triggers: ") .. table.concat(parts, "  ")
    if pi.extraDetail and pi.extraOK ~= true then s = s .. "  | extra: " .. tostring(pi.extraDetail) end
    if rule.parentUid then
        local _, oi = ns.Evaluate(rule, ctx)
        s = s .. "  | combination=" .. tv(oi and oi.whenOK) .. " (" .. tostring(oi and oi.whenDetail) .. ")"
        s = s .. "  | sound plays=" .. tostring(ns.KindHas(rule, "sound") and rule.sound and rule.sound.enabled == true)
    end
    return s
end
