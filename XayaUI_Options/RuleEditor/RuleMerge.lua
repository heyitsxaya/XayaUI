-------------------------------------------------------------------------------
-- XayaUI_Options/RuleEditor/RuleMerge.lua : "Merge N Selected" in the Rules sidebar's right-click menu (XayaUI_Rules_Options 0.6.82).
-- Her words (REQUEST-LOG-session-014bN6tUDLJ6T742DewZDg1s.md row 19, 2026-11-08): "I want to be able to merge these into one rule that
-- tracks all of these auras and fires based if any are found by right clicking on them when multi-selected and choose \"merge rules\"".
-- Her answers (row 27): kept rule: "The one I right-click (Recommended)"; the others: "Bin, one item each"; rules that differ in more than
-- their aura: "for now, only allow merging of triggers"; 'missing' rules: "depends on the individual triggers; if the triggers differ in
-- detection, missing ones consolidate with missing; present consolidate with present -- two triggers attach to one tracker and \"any
-- trigger\" fires".
-- So, with several rules selected, right-click one of them > Merge N Selected:
--   - the right-clicked rule is kept with its own name, displays, sounds, cues, load settings, talents and conditions; only triggers move;
--   - the other rules' "aura present" triggers join ONE present trigger of the kept rule (its aura and its extra aura IDs: present =
--     ANY of them is on you; XayaUI_Rules/Conditions.lua ns.AuraPresentList), their "aura missing" triggers ONE missing trigger (missing
--     = ALL of them absent); the kept rule's own present / missing trigger is that one when it has it;
--   - their other triggers (a cooldown, a buff with "seconds left", an item count, a target debuff, ...) are added as further triggers
--     (Triggers.lua rows: a rule holds up to 12 beside its built-in Cooldown and Buff / Aura);
--   - the kept rule then fires when ANY of its triggers is true ("This rule is activated by" = ANY trigger: Triggers.lua CombineTriggers);
--   - the other rules go to the Recycle Bin, one item each, with their own settings (XayaUI_Rules/RuleBin.lua ns.RecycleRules).
-- Refused, with a chat line naming the rule: a rule whose triggers must ALL be true (or where one trigger decides alone) when it has more
-- than one (merging would change what it does), a cue or condition row (no triggers of its own), a built-in trigger without an aura ID,
-- a kept rule whose built-in trigger has no state chosen (with ANY it would count as always true), a merged aura trigger over 30 extra
-- IDs, more than 12 additional triggers. Edit-locked rules are left out, with the count (as Delete (N) does).
-------------------------------------------------------------------------------
local addonName, ns = ...
ns = _G.XayaUI_NS or ns   -- one namespace with XayaUI core (XayaUI Options depends on it: ## Dependencies: XayaUI)
-- (bundle 1 round 7, REQUEST-LOG A23 SD-57, her words: "editor is an 'options' pane so 3"; V34) This file is part of XayaUI Options
-- (it was XayaUI_Rules/Editor/, read at login with Rules). The game reads it only when the settings window's code loads, after the
-- window's own files (XayaUI_Options.toc). With XayaUI Rules switched off it stops on the next line and builds nothing.
if not (ns.OptionsApi and ns.Service and ns.Service("rules")) then return end   -- (and nothing while the window's code could not load: Options.lua)
if not (ns.OptionsApi and ns.OptionsApi.Shared) then return end   -- Options.lua stopped early (its Ace3 libraries are missing)
local Notify = ns.OptionsApi.Shared.Notify

local M = {}
ns.RuleMerge = M   -- (tests and Dev Assist's walkthrough "merge-rules" read M.Plan / M.Text)

local CD_STATES = { ready = true, hasCharge = true, notReady = true, empty = true }
local function Quote(r) return "'" .. tostring((type(r.name) == "string" and r.name ~= "") and r.name or "Rule") .. "'" end
local function NoTime(op) return op == nil or op == "any" end
local function MaxRows() return (ns.TriggerShared and ns.TriggerShared.MAX_ROWS) or 12 end
local function IDs(main, alt)
    local t = { tonumber(main) or 0 }
    for _, v in ipairs(type(alt) == "table" and alt or {}) do t[#t + 1] = v end
    return t
end
local function IsPresentRow(t) return t.type == "buffAura" and (tonumber(t.spellID) or 0) ~= 0 and t.state == "yes" and NoTime(t.timeOp) end
local function IsMissingRow(t) return t.type == "buffAura" and (tonumber(t.spellID) or 0) ~= 0 and t.state == "no" end

-- What one rule brings to a merge: { present = { id lists }, missing = { id lists }, rows = { new additional trigger rows }, n = its
-- triggers, ignored = the name of a built-in trigger that is in use with no state chosen }, or nil and why (naming the rule).
function M.Triggers(r)
    if r.parentUid or r.isCue then
        return nil, Quote(r) .. " is a cue or condition of another rule: it has no triggers of its own. Take it out of the selection to merge."
    end
    local out, j = { present = {}, missing = {}, rows = {}, n = 0 }, 0
    local list = type(r.extra) == "table" and type(r.extra.list) == "table" and r.extra.list or {}
    for _, tok in ipairs(ns.TriggerSequence(r)) do
        if tok == "cd" then
            if CD_STATES[r.cdState] then   -- the built-in Cooldown as a "Cooldown (any spell)" row: the same reader and the same fields
                out.n = out.n + 1
                out.rows[#out.rows + 1] = { type = "cooldown", spellID = tonumber(r.spellID) or 0, state = r.cdState, maxCharges = tonumber(r.maxCharges) or 0,
                    countGCD = r.countGCD and true or nil, countLOC = r.countLOC and true or nil, exactSpell = r.exactSpell and true or nil,
                    cdTimeOp = r.cdTimeOp, cdTimeSec = r.cdTimeSec, cdChargeOp = r.cdChargeOp, cdChargeVal = r.cdChargeVal, name = r.cdName }
            else out.ignored = "Cooldown" end
        elseif tok == "buff" then
            if r.buffState == "present" or r.buffState == "missing" then
                if (tonumber(r.buffID) or 0) == 0 then
                    return nil, Quote(r) .. " has a Buff / Aura trigger without an aura ID. Set its aura (Trigger tab) or remove that trigger, then merge."
                end
                out.n = out.n + 1
                if r.buffState == "missing" then out.missing[#out.missing + 1] = IDs(r.buffID, r.buffAlt)
                elseif NoTime(r.buffTimeOp) then out.present[#out.present + 1] = IDs(r.buffID, r.buffAlt)
                else   -- present with "seconds left": not a plain present trigger, so it is added as its own "Buff / Aura (another)" row
                    local row = { type = "buffAura", spellID = tonumber(r.buffID), state = "yes",
                        alt = (type(r.buffAlt) == "table" and #r.buffAlt > 0) and ns.Copy(r.buffAlt) or nil,
                        timeOp = r.buffTimeOp, timeSec = r.buffTimeSec, name = r.buffName }
                    if r.buffEstimate == false then row.estimate = false end   -- the time estimate switched off stays off (a row's t.estimate)
                    out.rows[#out.rows + 1] = row
                end
            else out.ignored = "Buff / Aura" end
        else
            j = j + 1
            local t = list[j]
            if type(t) == "table" then
                out.n = out.n + 1
                if IsMissingRow(t) then out.missing[#out.missing + 1] = IDs(t.spellID, t.alt)
                elseif IsPresentRow(t) then out.present[#out.present + 1] = IDs(t.spellID, t.alt)
                else out.rows[#out.rows + 1] = ns.Copy(t) end
            end
        end
    end
    if out.n > 1 and r.trigMode ~= "any" then
        return nil, Quote(r) .. " has " .. out.n .. " triggers and 'This rule is activated by' is not ANY trigger (they must all be true, or one decides"
            .. " alone). A merged rule fires when any one trigger is true, so merging would change what it does. Set it to ANY trigger (Trigger tab), or"
            .. " take the rule out of the selection."
    end
    return out
end

-- the kept rule's own present / missing aura trigger: "buff" (the built-in) or the row, or nil
local function OwnAura(T, want)
    if ns.BuffUsed(T) and (tonumber(T.buffID) or 0) ~= 0 then
        if want == "missing" and T.buffState == "missing" then return "buff" end
        if want == "present" and T.buffState == "present" and NoTime(T.buffTimeOp) then return "buff" end
    end
    for _, t in ipairs(T.extra.list) do
        if (want == "missing" and IsMissingRow(t)) or (want == "present" and IsPresentRow(t)) then return t end
    end
end

-- Merge the others' triggers (infos from M.Triggers) into rule T. T is changed; on a refusal it may be half changed, so callers try a copy
-- first (M.Plan). Returns true, or nil and why.
function M.Apply(T, infos)
    if type(T.extra) ~= "table" then T.extra = { list = {} } end
    if type(T.extra.list) ~= "table" then T.extra.list = {} end
    local add = {}
    for _, want in ipairs({ "present", "missing" }) do
        local ids = {}
        for _, inf in ipairs(infos) do for _, l in ipairs(inf[want]) do for _, id in ipairs(l) do ids[#ids + 1] = id end end end
        if #ids > 0 then
            local own = OwnAura(T, want)
            local main, alt
            if own == "buff" then main, alt = T.buffID, T.buffAlt
            elseif own then main, alt = own.spellID, own.alt
            else main, alt = ids[1], nil end
            local list, over = ns.AuraIDList(main, alt, ids)   -- the editor's list rule (TreeHelpers.lua): no repeats, at most 30 extra
            if over > 0 then
                return nil, "the merged " .. want .. " aura trigger would watch " .. (1 + #list + over) .. " auras; one trigger watches its own aura and"
                    .. " at most " .. ns.AURA_ALT_MAX .. " more. Merge fewer rules."
            end
            if own == "buff" then T.buffAlt = list
            elseif own then own.alt = list
            elseif not ns.BuffUsed(T) then   -- the kept rule's built-in Buff / Aura is free: it becomes this trigger
                T.useBuff, T.buffID, T.buffState, T.buffAlt, T.buffTimeOp, T.buffTimeSec = true, tonumber(main), want, list, nil, nil
            else
                add[#add + 1] = { type = "buffAura", spellID = tonumber(main), state = (want == "present") and "yes" or "no", alt = list }
            end
        end
    end
    for _, inf in ipairs(infos) do for _, t in ipairs(inf.rows) do add[#add + 1] = t end end
    if #T.extra.list + #add > MaxRows() then
        return nil, Quote(T) .. " would hold " .. (#T.extra.list + #add) .. " additional triggers; a rule holds at most " .. MaxRows() .. ". Merge fewer rules."
    end
    for _, t in ipairs(add) do T.extra.list[#T.extra.list + 1] = t end
    if #ns.TriggerSequence(T) >= 2 then T.trigMode = "any" end
    return true
end

-- Check a merge without changing anything. Returns { kept, others, infos, preview = the kept rule as it would be }, or nil and why.
function M.Plan(kept, others)
    local own, err = M.Triggers(kept)
    if not own then return nil, err end
    if own.ignored then
        return nil, Quote(kept) .. " has a " .. own.ignored .. " trigger with no state chosen: in a merged rule (any trigger fires) it would count as"
            .. " always true. Choose its state or remove it (Trigger tab), then merge."
    end
    local infos = {}
    for _, o in ipairs(others) do
        local inf, why = M.Triggers(o)
        if not inf then return nil, why end
        infos[#infos + 1] = inf
    end
    local preview = ns.Copy(kept)
    local ok, why = M.Apply(preview, infos)
    if not ok then return nil, why end
    return { kept = kept, others = others, infos = infos, preview = preview }
end

-- the confirm's words for one aura trigger
local SHOWN = 8
local function SpellText(id)
    id = tonumber(id) or 0
    local ok, n = pcall(C_Spell.GetSpellName, id)
    if ok and type(n) == "string" and n ~= "" then return n .. " (" .. id .. ")" end
    return "aura " .. id
end
local function AuraLine(state, main, alt, timeOp, timeSec)
    local ids, names = IDs(main, alt), {}
    for i = 1, math.min(#ids, SHOWN) do names[i] = SpellText(ids[i]) end
    local s = table.concat(names, ", ") .. ((#ids > SHOWN) and (", and " .. (#ids - SHOWN) .. " more") or "")
    if state == "missing" or state == "no" then
        return (#ids > 1) and ("Aura MISSING (all " .. #ids .. " absent): " .. s) or ("Aura MISSING: " .. s)
    end
    local t = NoTime(timeOp) and "" or (", seconds left " .. tostring(timeOp) .. " " .. tostring(timeSec))
    return ((#ids > 1) and ("Aura PRESENT (any one of " .. #ids .. "): ") or "Aura PRESENT: ") .. s .. t
end
-- The triggers a rule has, in its trigger order, one line each (aura triggers with every aura they watch; the rest as the Drafts page
-- words them: Drafts.lua ns.DraftTriggerItems).
function M.TriggerLines(T)
    local items = ns.DraftTriggerItems and ns.DraftTriggerItems(T) or {}
    local out, j = {}, 0
    for i, tok in ipairs(ns.TriggerSequence(T)) do
        local line = items[i]
        if tok == "buff" and (T.buffState == "present" or T.buffState == "missing") then
            line = AuraLine(T.buffState, T.buffID, T.buffAlt, T.buffState == "present" and T.buffTimeOp or nil, T.buffTimeSec)
        elseif tok == "x" then
            j = j + 1
            local t = T.extra.list[j]
            if type(t) == "table" and t.type == "buffAura" then line = AuraLine(t.state, t.spellID, t.alt, t.state == "yes" and t.timeOp or nil, t.timeSec) end
        end
        out[#out + 1] = i .. ". " .. tostring(line or "Trigger")
    end
    return out
end
function M.Text(plan)
    local K, lines = plan.kept, M.TriggerLines(plan.preview)
    local names = {}
    for _, o in ipairs(plan.others) do names[#names + 1] = Quote(o) end
    return ("Merge %d selected rules into %s (the rule you right-clicked)?\n\nOnly triggers are merged: %s keeps its own name, displays, sounds,"
        .. " cues, load settings and conditions, and fires when %s:\n%s\n\nThe other %d rule(s) go to the Recycle Bin for %s, one item each, with"
        .. " their own settings: %s."):format(#plan.others + 1, Quote(K), Quote(K), (#lines > 1) and "ANY of these triggers is true" or "this trigger is true",
        table.concat(lines, "\n"), #plan.others, ns.RecycleKeepLabel and ns.RecycleKeepLabel() or "a while", table.concat(names, ", "))
end

-- Right-click > Merge N Selected on `kept` (one of the selected rules)
function ns.MultiMerge(kept)
    if type(kept) ~= "table" then return end
    if ns.IsEditLocked(kept) then ns.Print(Quote(kept) .. " is edit-locked: unlock it in the sidebar to merge into it."); return end
    local others, skipped = {}, 0
    for _, r in ipairs(ns.MultiSelected()) do
        if r ~= kept then
            if ns.IsEditLocked(r) then skipped = skipped + 1 else others[#others + 1] = r end   -- audit D44, as Delete (N)
        end
    end
    if skipped > 0 then ns.Print(("%d edit-locked rule(s) are left out of the merge (unlock them in the sidebar to merge them)."):format(skipped)) end
    if #others == 0 then ns.Print("nothing to merge: select at least one more rule that is not edit-locked."); return end
    local plan, err = M.Plan(kept, others)
    if not plan then ns.Print("Merge: " .. tostring(err)); return end
    local dlg = StaticPopup_Show("XAYAUI_CONFIRM", M.Text(plan), nil, { cb = function()
        local p2, err2 = M.Plan(kept, others)   -- again on Yes: the rules may have changed while the question was open
        if not p2 then ns.Print("Merge: " .. tostring(err2)); return end
        M.Apply(kept, p2.infos)
        if ns.NormalizeExtra then pcall(ns.NormalizeExtra, kept) end
        local n = ns.RecycleRules(others)
        ns.MultiReset()
        pcall(ns.RefreshVisual, kept)
        ns.MarkDirty(); Notify()
        ns.MultiPrune(); ns.GoHomeKeepScroll()   -- as after a delete: the list keeps its place (TreeHelpers.lua)
        ns.Print(("merged %d rule(s) into %s; they are in the Recycle Bin, one item each."):format(n, Quote(kept)))
    end })
    if dlg and dlg.SetFrameStrata then dlg:SetFrameStrata("TOOLTIP") end   -- the options window is FULLSCREEN_DIALOG; keep the question above it
end
