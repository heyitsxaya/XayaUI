-- XayaUI: Cues. A CUE is a named thing that happens (sound, text, texture, icon, custom). A rule that has conditions owns its cues;
-- each condition's THEN lists cue keys. Under the hood a cue is a hidden child rule (rule.isCue, rule.parentUid, rule.cueKey, rule.cueKind),
-- so the existing sound / display engine and editors are reused. A cue fires while ANY enabled condition that lists it is true.
local addonName, ns = ...

ns.CUE_KINDS = { "sound", "text", "texture", "icon", "custom" }
local KIND_OK = {}
for _, k in ipairs(ns.CUE_KINDS) do KIND_OK[k] = true end
ns.CUE_KIND_LABEL = { sound = "Sound", text = "Text", texture = "Texture", icon = "Icon", custom = "Custom" }
local MAX_CUES = 40

function ns.CuesOf(p)
    local out = {}
    if type(p.uid) ~= "string" then return out end
    for _, r in ipairs(ns.rules or {}) do
        if r ~= p and r.parentUid == p.uid and r.isCue then out[#out + 1] = r end
    end
    return out
end
function ns.ConditionsOf(p)
    local out = {}
    if type(p.uid) ~= "string" then return out end
    for _, r in ipairs(ns.rules or {}) do
        if r ~= p and r.parentUid == p.uid and not r.isCue then out[#out + 1] = r end
    end
    return out
end

-- "<Kind> <n>" counting cues of the same kind in list order (what the cue is called while it has no name of its own).
function ns.CueDefaultLabel(cue)
    local p = ns.FindParentRule(cue)
    local n = 0
    if p then
        for _, c in ipairs(ns.CuesOf(p)) do
            if c.cueKind == cue.cueKind then n = n + 1 end
            if c == cue then break end
        end
    end
    return (ns.CUE_KIND_LABEL[cue.cueKind] or "Cue") .. " " .. math.max(n, 1)
end
function ns.CueLabel(cue)
    if type(cue.cueName) == "string" and cue.cueName:match("%S") then return cue.cueName end
    return ns.CueDefaultLabel(cue)
end

function ns.CueKey(p)
    local used = {}
    for _, c in ipairs(ns.CuesOf(p)) do used[c.cueKey or ""] = true end
    local i = 1
    while used["q" .. i] do i = i + 1 end
    return "q" .. i
end

function ns.NewCueRule(parent, kind)
    if not KIND_OK[kind] then return nil end
    if #ns.CuesOf(parent) >= MAX_CUES then ns.Print("a rule can hold at most " .. MAX_CUES .. " cues"); return nil end
    parent.uid = parent.uid or ns.NewUID()
    local n = ns.NewRule()
    n.parentUid = parent.uid
    n.isCue, n.cueKind, n.cueKey = true, kind, ns.CueKey(parent)
    n.folder = parent.folder
    n.name = tostring(parent.name or "") .. " (cue)"
    n.sound.enabled = (kind == "sound")
    n.visual.enabled = (kind ~= "sound" and kind ~= "custom")
    n.visual.trigger = "condition"
    if kind == "icon" then n.visual.kind = "spellicon" end
    ns.rules[#ns.rules + 1] = n
    pcall(ns.RefreshVisual, n)
    ns.MarkDirty()
    return n
end

function ns.DeleteCue(cue)
    local p = ns.FindParentRule(cue)
    for i, r in ipairs(ns.rules) do if r == cue then table.remove(ns.rules, i); break end end
    pcall(ns.DropVisual, cue)
    if p then
        for _, c in ipairs(ns.ConditionsOf(p)) do
            if type(c.thenCues) == "table" then
                for i = #c.thenCues, 1, -1 do if c.thenCues[i] == cue.cueKey then table.remove(c.thenCues, i) end end
                if #c.thenCues == 0 then c.thenCues = nil end
            end
        end
    end
    ns.MarkDirty()
end

-- A cue is "on" while any enabled condition that lists it is true.
function ns.EvaluateCue(rule, ctx)
    local info = { ctx = ctx, missing = {}, outcome = true, cue = true }
    local p = ns.FindParentRule(rule)
    if not p then info.missing[1] = "parent rule not found"; info.result = false; return false, info end
    local pr, pi = ns.Evaluate(p, ctx)
    info.cd, info.present, info.buffSource, info.buffRef = pi.cd, pi.present, pi.buffSource, pi.buffRef
    if rule.spellID ~= p.spellID then rule.spellID = p.spellID end
    if rule.buffID ~= p.buffID then rule.buffID = p.buffID end
    if rule.maxCharges ~= p.maxCharges then rule.maxCharges = p.maxCharges end
    local key = rule.cueKey
    -- a rule with no conditions at all: its cues simply follow the rule's own trigger
    if #ns.ConditionsOf(p) == 0 then
        info.result = pr and true or false
        return info.result, info
    end
    for _, c in ipairs(ns.ConditionsOf(p)) do
        if c.enabled ~= false and type(c.thenCues) == "table" then
            for _, k in ipairs(c.thenCues) do
                if k == key then
                    local res = ns.Evaluate(c, ctx)
                    if res then info.result = true; info.by = c.name; return true, info end
                end
            end
        end
    end
    info.result = false
    return false, info
end

function ns.NormalizeCues(r)
    r.cues = nil   -- phase-B library (dropped)
    if r.isCue ~= true then r.isCue, r.cueKind, r.cueKey, r.cueName, r.cueDesc = nil, nil, nil, nil, nil
    else
        if not KIND_OK[r.cueKind] then r.cueKind = "sound" end
        if type(r.cueKey) ~= "string" or r.cueKey == "" or #r.cueKey > 12 then r.cueKey = nil end   -- repaired on first use below
        r.cueName = (type(r.cueName) == "string" and r.cueName ~= "") and r.cueName:sub(1, 60) or nil
        r.cueDesc = (type(r.cueDesc) == "string" and r.cueDesc ~= "") and r.cueDesc:sub(1, 300) or nil
    end
    if type(r.thenCues) == "table" and not r.isCue then
        local out = {}
        for _, k in ipairs(r.thenCues) do if type(k) == "string" and #k <= 12 and #out < MAX_CUES then out[#out + 1] = k end end
        r.thenCues = (#out > 0) and out or nil
    else r.thenCues = nil end
end

-- Version 2 (one time): every enabled sound / display of a condition becomes a cue of its parent; the condition now points at them.
function ns.MigrateCues()
    local DB = CueRulesDB
    if not DB or not ns.rules or (DB.cuesVer or 0) >= 2 then return 0 end
    if not DB.backupPreCues then DB.backupPreCues = ns.Copy(DB.rules) end   -- full in-game copy of every rule before the first migration
    -- repair cue keys that normalisation cleared
    for _, r in ipairs(ns.rules) do
        if r.isCue and not r.cueKey then local p = ns.FindParentRule(r); if p then r.cueKey = ns.CueKey(p) end end
    end
    local made = 0
    local snapshot = {}
    for _, r in ipairs(ns.rules) do snapshot[#snapshot + 1] = r end
    for _, child in ipairs(snapshot) do
        local parent = (child.parentUid and not child.isCue) and ns.FindParentRule(child)
        if parent then
            child.thenCues = nil
            local keys = {}
            if type(child.sound) == "table" and child.sound.enabled then
                local c = ns.NewCueRule(parent, "sound")
                if c then c.sound = ns.Copy(child.sound); c.repeatSec = child.repeatSec; c.cueName = nil; keys[#keys + 1] = c.cueKey; made = made + 1 end
            end
            if type(child.visual) == "table" and child.visual.enabled then
                local c = ns.NewCueRule(parent, "texture")
                if c then c.visual = ns.Copy(child.visual); c.visual.trigger = "condition"; keys[#keys + 1] = c.cueKey; made = made + 1 end
            end
            if #keys > 0 then
                child.thenCues = keys
                child.sound.enabled = false
                child.visual.enabled = false
            end
        end
    end
    DB.cuesVer = 2
    return made
end
