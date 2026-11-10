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
local addonName, ns = ...; ns = XayaUI_NS or ns -- (P4) XayaUI Rules shares the Platform's namespace (XayaUI/Core.lua)

local MAX_TERMS = 24
local issecret = issecretvalue or function() return false end   -- (was missing: numeric checks on cooldowns / stacks threw)

function ns.NewUID() return "u" .. tostring(time()) .. tostring(math.random(100000, 999999)) end

-- The rule an outcome follows (nil if missing). Outcomes cannot own outcomes, so there is no chain and no cycle.
function ns.FindParentRule(rule)
    local p, indexed = nil, false
    if ns.StepParentOf then p, indexed = ns.StepParentOf(rule) end
    if indexed then return p end
    local uid = rule.parentUid
    if type(uid) ~= "string" or uid == "" then return nil end
    for _, r in ipairs(ns.rules or {}) do
        if r ~= rule and r.uid == uid and not r.parentUid then return r end
    end
end

-- Rewrite the "x<N>" references of this rule's outcomes. fn(N) returns the new ref string, or nil to drop the reference.
function ns.RemapOutcomeRefs(parent, fn)
    local tm = type(parent.trigMode) == "string" and parent.trigMode:match("^x(%d+)$")   -- the "activates when" choice follows its trigger too
    if tm then parent.trigMode = fn(tonumber(tm)) end
    for _, o in ipairs(ns.OutcomesOf(parent)) do
        if type(o.when) == "table" and type(o.when.list) == "table" then
            for _, t in ipairs(o.when.list) do
                local n = type(t.ref) == "string" and t.ref:match("^x(%d+)$")
                local nn, suf
                if not n and type(t.ref) == "string" then nn, suf = t.ref:match("^n:x(%d+)(%a?)$") end   -- "n:x3", "n:x3s" (stacks), "n:x3t" (seconds left)
                if n then t.ref = fn(tonumber(n))
                elseif nn then local r = fn(tonumber(nn)); t.ref = r and ("n:" .. r .. (suf or "")) or nil end
            end
        end
    end
end

function ns.OutcomesOf(parent)
    local idx = ns.StepChildrenOf and ns.StepChildrenOf(parent, "all")
    if idx then return idx end
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
        if pi.trigMode and pi.trigMode ~= "all" then   -- "activates when ANY / one trigger": the triggers' combined value, not each one alone
            if pi.trigTri == false or pi.ctxOK == false or pi.talentOK == false then return false end
            return nil
        end
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
        -- the parent's cooldown reading holds the count: exact out of combat; in combat built from anchors and your casts
        -- (Conditions.lua, "Charges in combat"). nil = not known, never a guess.
        local cdi = pi.cd
        if not (cdi and cdi.known) then return nil end
        return cdi.count
    elseif ref == "n:cdRemain" then
        local id = SpellID(); if not id then return nil end
        -- a talent that replaces the spell: the one on the bar (gap 4), unless the trigger reads the exact ID (B4)
        local readID = ns.CooldownReadID and ns.CooldownReadID(p, id) or (ns.SpellOnBar and ns.SpellOnBar(id)) or id
        local ok, cd = pcall(C_Spell.GetSpellCooldown, readID)
        if not ok or type(cd) ~= "table" then return nil end
        local st, du, act, gcd = cd.startTime, cd.duration, cd.isActive, cd.isOnGCD
        -- SpellCooldownInfo.isActive and .isOnGCD are NeverSecret (12.1.5): they decide "ready" even when the times are hidden
        -- (retrospective gap 11; before, a hidden time always went to the estimate)
        if act == false and not issecret(act) then return 0 end
        if gcd == true and not issecret(gcd) then return 0 end   -- only the global cooldown: the spell itself is ready
        if issecret(st) or issecret(du) or issecret(act) or issecret(gcd) then
            -- hidden (combat), still on cooldown: the duration engine's estimate (Timing.lua). An estimate that has already run
            -- out while the game still says "on cooldown" is unknown, not 0 (gap 11).
            local ready = ns.Timing and ns.Timing.CooldownEstimate(id)
            if ready and ready > now then return ready - now end
            return nil
        end
        if not act or gcd or type(du) ~= "number" or du <= 0 or type(st) ~= "number" then return 0 end
        return math.max(0, st + du - now)
    elseif ref == "n:buffStacks" then
        if pi.present == false then return 0 end
        -- only a READ stack count counts: a reference without one (the aura was found through the Cooldown Manager or estimated
        -- in combat, where the game hides stacks) is unknown, not 1 stack (that answer made "stacks >= 3" false in combat)
        if pi.present == true and pi.buffRef then
            local a = pi.buffRef.applications
            if type(a) == "number" and not issecret(a) then return math.max(a, 1) end
        end
        return nil
    elseif ref == "n:buffRemain" then
        -- an absent aura has no time left to show (decision D1, Xaya 2026-11-04); CheckValue makes any comparison on it NOT met
        if pi.present == false then return nil end
        if pi.present == true and pi.buffRef and type(pi.buffRef.expiration) == "number" and pi.buffRef.expiration > 0 then
            return math.max(0, pi.buffRef.expiration - now)
        end
        return nil
    end
    local ns_, suf = ref:match("^n:x(%d+)(%a?)$")
    local n = tonumber(ns_)
    if n and type(p.extra) == "table" and type(p.extra.list) == "table" and ns.TriggerNumber then
        return ns.TriggerNumber(p.extra.list[n], (suf ~= "") and suf or nil)
    end
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
-- time-left checks register the moments they will change (the threshold, and zero) so the engine steps on that exact frame
local TIME_LEFT = { ["n:buffRemain"] = true, ["n:cdRemain"] = true }
-- Decision D1 (Xaya, 2026-11-04): "an absent buff shows no icon and no number, and any time condition on it is NOT met". So a
-- seconds-left comparison on an aura that is known to be absent is false (before 0.6.13 it read 0, and "seconds left <= 2" fired
-- while the buff was missing, #173). Unknown stays unknown.
local function AuraTimeRefAbsent(ref, p, pi)
    if ref == "n:buffRemain" then return pi ~= nil and pi.present == false end
    local n = tonumber(ref:match("^n:x(%d+)t$"))
    if n and type(p) == "table" and type(p.extra) == "table" and type(p.extra.list) == "table" and ns.TriggerAuraPresent then
        return ns.TriggerAuraPresent(p.extra.list[n]) == false
    end
    return false
end
ns.AuraTimeRefAbsent = AuraTimeRefAbsent
local function CheckValue(t, p, pr, pi)
    if IsNumRef(t.ref) and AuraTimeRefAbsent(t.ref, p, pi) then return false end
    if IsNumRef(t.ref) then
        local v, num = NumRef(t.ref, p, pi), tonumber(t.num) or 0
        if (TIME_LEFT[t.ref] or t.ref:match("^n:x%d+t$")) and type(v) == "number" and ns.Timing then
            local now = GetTime()
            if v > num then ns.Timing.Deadline(now + (v - num)) end
            if v > 0 then ns.Timing.Deadline(now + v) end
        end
        return CmpNum(t.cmp, v, num)
    end
    local v = RefValue(t.ref, p, pr, pi)
    if v ~= nil and t.neg then v = not v end
    return v
end
ns.CheckValue = CheckValue

-- true / false / nil, detail. (A AND B) OR (C) ... with per-condition NOT.
local function EvalWhen(list, p, pr, pi)
    if #list == 0 then return nil, "no conditions added" end
    -- checks joined by AND form a group; "or" starts the next group. Groups are folded as they close (no tables).
    local anyTrue, anyNil = false, false
    local gFalse, gNil = false, false
    local why
    for i, t in ipairs(list) do
        if i > 1 and t.op == "or" then
            if not gFalse then if gNil then anyNil = true else anyTrue = true end end
            gFalse, gNil = false, false
        end
        local v = CheckValue(t, p, pr, pi)
        if v == nil then why = why or ("check " .. i .. (t.ref and " is unknown or its trigger was removed" or " has nothing chosen")) end
        if v == false then gFalse = true elseif v == nil then gNil = true end
    end
    if not gFalse then if gNil then anyNil = true else anyTrue = true end end
    if anyTrue then return true, "matched" end
    if anyNil then return nil, why or "unknown" end
    return false, "no combination matched"
end

function ns.EvaluateOutcome(rule, ctx)
    if rule.isCue and ns.EvaluateCue then return ns.EvaluateCue(rule, ctx) end
    local info = ns.InfoFor and ns.InfoFor(rule) or { missing = {} }
    info.ctx, info.outcome = ctx, true
    local p = ns.FindParentRule(rule)
    if not p then
        info.missing[1] = "parent rule not found"
        info.result = false
        return false, info
    end
    if not p.enabled then   -- a switched-off rule switches off its conditions too (0.6.14; nil counts as off, as in Engine.lua StepRule)
        info.missing[1] = "the rule is switched off"
        info.result = false
        return false, info
    end
    local pr, pi = ns.Evaluate(p, ctx)
    -- inherit what the parent read, so this outcome's own display (buff time, charges, absorb text) works
    info.cd, info.present, info.buffSource, info.buffRef, info.auraRef = pi.cd, pi.present, pi.buffSource, pi.buffRef, pi.auraRef
    if rule.spellID ~= p.spellID then rule.spellID = p.spellID end
    if rule.buffID ~= p.buffID then rule.buffID = p.buffID end
    if rule.maxCharges ~= p.maxCharges then rule.maxCharges = p.maxCharges end
    info.cdOK, info.buffOK, info.extraOK = true, true, true
    -- load conditions live in ONE place: the parent rule's Load tab. An outcome never has its own.
    -- (the parent was just evaluated with the same context: reuse its answers instead of checking again)
    info.ctxOK, info.ctxFail, info.talentOK, info.talentDetail = pi.ctxOK, pi.ctxFail, pi.talentOK, pi.talentDetail
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
        -- stacks only where the aura can stack (#300, ns.TriggerMayStack); a check that already uses one keeps it listed
        local used = {}
        for _, o in ipairs(ns.OutcomesOf(p)) do
            local wl = type(o.when) == "table" and type(o.when.list) == "table" and o.when.list or {}
            for _, t in ipairs(wl) do if type(t.ref) == "string" then used[t.ref] = true end end
        end
        local function MayStack(row) if not ns.TriggerMayStack then return true end; local ok, v = pcall(ns.TriggerMayStack, p, row); return not ok or v ~= false end
        if ns.BuffUsed(p) then
            if used["n:buffStacks"] or MayStack(nil) then add("n:buffStacks", "Buff / Aura: stacks  (number)") end
            add("n:buffRemain", "Buff / Aura: seconds left  (number)")
        end
        for i, t in ipairs(list) do
            local pos = "Trigger " .. ((P and P.xs[i]) or i) .. ":  "
            if t.type == "itemCount" or t.type == "resource" then
                add("n:x" .. i, pos .. ((t.type == "itemCount") and "item count" or "resource amount") .. "  (number)")
            elseif t.type == "buffAura" or t.type == "targetDebuff" then
                if used["n:x" .. i .. "s"] or MayStack(t) then add("n:x" .. i .. "s", pos .. "stacks  (number)") end
                add("n:x" .. i .. "t", pos .. "seconds left  (number)")
            elseif t.type == "lossOfControl" then
                add("n:x" .. i .. "t", pos .. "loss of control, seconds left  (number)")
            end
        end
    end
    return v, o
end

-- On the parent: list its outcomes and add new ones.
function ns.RefChoicesFor(p) return RefChoices(p) end


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

-- Does this rule have outcomes? (review R18 follow-up) During an engine step the step index answers (RuleDefaults.lua, kept between
-- steps). Outside a step (the options window) one table is refilled when the rule list, a setting or the step changed. Before, a new
-- table of every rule's outcomes was built on every engine step, routed re-checks included.
local hasOut, hasList, hasN, hasVer, hasTick = {}, nil, -1, nil, nil
function ns.HasOutcomes(rule)
    if rule.parentUid or type(rule.uid) ~= "string" then return false end
    local conds = ns.StepChildrenOf and ns.StepChildrenOf(rule, "conds")
    if conds then return #conds > 0 end
    local list = ns.rules
    if not list then return false end
    local n, ver, tick = #list, ns.configVersion or 0, ns.tickID
    if list ~= hasList or n ~= hasN or ver ~= hasVer or tick ~= hasTick or tick == nil then
        for k in pairs(hasOut) do hasOut[k] = nil end
        for i = 1, n do
            local r = list[i]
            if type(r.parentUid) == "string" and not r.isCue then hasOut[r.parentUid] = true end
        end
        hasList, hasN, hasVer, hasTick = list, n, ver, tick
    end
    return hasOut[rule.uid] == true
end


-- One line saying WHY a rule or outcome does / does not fire right now (used by /xui debug status).
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
    local hidden = ns.HiddenAuraNote and ns.HiddenAuraNote(p, pi)   -- the game hides the aura: what the player sees (externals, 2026-11-07)
    if hidden then s = s .. "  | " .. hidden end
    if rule.parentUid then
        local _, oi = ns.Evaluate(rule, ctx)
        s = s .. "  | combination=" .. tv(oi and oi.whenOK) .. " (" .. tostring(oi and oi.whenDetail) .. ")"
        s = s .. "  | sound plays=" .. tostring(ns.KindHas(rule, "sound") and rule.sound and rule.sound.enabled == true)
    end
    return s
end

-- shared with the settings window's editor (OutcomesEditor.lua); read-only
ns.OutcomeShared = { CheckValue = CheckValue, EvalWhen = EvalWhen, IsNumRef = IsNumRef, MAX_TERMS = MAX_TERMS, NumRef = NumRef, RefChoices = RefChoices }
