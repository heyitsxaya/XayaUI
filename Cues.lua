-- XayaUI: Cues. A CUE is a named thing that happens (sound, text, texture, icon, custom). A rule that has conditions owns its cues;
-- each condition's THEN lists cue keys. Under the hood a cue is a hidden child rule (rule.isCue, rule.parentUid, rule.cueKey, rule.cueKind),
-- so the existing sound / display engine and editors are reused. A cue fires while ANY enabled condition that lists it is true.
local addonName, ns = ...

ns.CUE_KINDS = { "sound", "speech", "text", "texture", "icon", "custom" }
local KIND_OK = {}
for _, k in ipairs(ns.CUE_KINDS) do KIND_OK[k] = true end
ns.CUE_KIND_LABEL = { sound = "Sound", speech = "Speech", text = "Text", texture = "Texture", icon = "Icon", custom = "Custom" }
local MAX_CUES = 40
-- Frame strata a condition may give a cue (low to high). TOOLTIP is left out on purpose: art there would sit above every window.
ns.MOD_STRATA = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG" }
ns.MOD_STRATA_OK = {}
for _, k in ipairs(ns.MOD_STRATA) do ns.MOD_STRATA_OK[k] = true end

function ns.CuesOf(p)
    local idx = ns.StepChildrenOf(p, "cues")
    if idx then return idx end
    local out = {}
    if type(p.uid) ~= "string" then return out end
    for _, r in ipairs(ns.rules or {}) do
        if r ~= p and r.parentUid == p.uid and r.isCue then out[#out + 1] = r end
    end
    return out
end
function ns.ConditionsOf(p)
    local idx = ns.StepChildrenOf(p, "conds")
    if idx then return idx end
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
-- Header title in the Cues tab, same pattern as "Trigger 1:  Cooldown": "Cue 1:  Sound 1" (position among the rule's cues, then the kind and its own count).
function ns.CueHeaderTitle(cue)
    local p = ns.FindParentRule(cue)
    local pos = 1
    if p then for i, c in ipairs(ns.CuesOf(p)) do if c == cue then pos = i; break end end end
    return "Cue " .. pos .. ":  " .. ns.CueDefaultLabel(cue)
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
    n.sound.enabled = (kind == "sound" or kind == "speech")
    n.visual.enabled = (kind ~= "sound" and kind ~= "speech" and kind ~= "custom")
    if kind == "speech" then n.sound.source, n.sound.value = "tts", "" end   -- a speech cue is a sound whose source is text-to-speech
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
            if type(c.thenMods) == "table" then
                c.thenMods[cue.cueKey] = nil
                if next(c.thenMods) == nil then c.thenMods = nil end
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
    -- Every true condition that lists this cue switches it on. Their modifiers (glow / desaturate / opacity) are merged in the
    -- conditions' list order; when two true conditions set the same modifier, the LATER one in the list wins.
    local hit, by, mods = false, nil, nil
    for _, c in ipairs(ns.ConditionsOf(p)) do
        if c.enabled ~= false and type(c.thenCues) == "table" then
            for _, k in ipairs(c.thenCues) do
                if k == key then
                    if ns.Evaluate(c, ctx) then
                        if not hit then by = c.name end
                        hit = true
                        local m = type(c.thenMods) == "table" and c.thenMods[key] or nil
                        if type(m) == "table" and m.on ~= false then   -- on == false: the "modify this cue" box is unticked, values are kept but ignored
                            mods = mods or {}
                            if m.glow ~= nil then mods.glow = m.glow end
                            if m.desat ~= nil then mods.desat = m.desat end
                            if m.alpha ~= nil then mods.alpha = m.alpha end
                            if m.tint ~= nil then mods.tint = m.tint end
                            if m.strata ~= nil then mods.strata = m.strata end
                        end
                    end
                    break
                end
            end
        end
    end
    info.result, info.by, info.mods = hit, by, mods
    return hit, info
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
    -- per-cue modifiers of a condition: only for cues it lists; on = the 'modify this cue' box; glow / desat are true or false (absent = leave the cue as it is), alpha is 0 to 1, tint is {r,g,b,a}, strata is a frame strata name
    if type(r.thenMods) == "table" and not r.isCue and r.thenCues then
        local out = {}
        for _, k in ipairs(r.thenCues) do
            local m = r.thenMods[k]
            if type(m) == "table" then
                local n = {}
                if m.on == false then n.on = false elseif m.on == true then n.on = true end
                if type(m.tint) == "table" then
                    local r, g, b, a = tonumber(m.tint[1]), tonumber(m.tint[2]), tonumber(m.tint[3]), tonumber(m.tint[4]) or 1
                    if r and g and b then n.tint = { math.max(0, math.min(1, r)), math.max(0, math.min(1, g)), math.max(0, math.min(1, b)), math.max(0, math.min(1, a)) } end
                end
                if type(m.strata) == "string" and ns.MOD_STRATA_OK[m.strata] then n.strata = m.strata end
                if type(m.glow) == "boolean" then n.glow = m.glow end
                if type(m.desat) == "boolean" then n.desat = m.desat end
                if type(m.alpha) == "number" and m.alpha == m.alpha then n.alpha = math.max(0, math.min(1, m.alpha)) end
                if next(n) then out[k] = n end
            end
        end
        r.thenMods = next(out) and out or nil
    else r.thenMods = nil end
end

-- Version 2 (one time): every enabled sound / display of a condition becomes a cue of its parent; the condition now points at them.
function ns.MigrateCues()
    local DB = CueRulesDB
    if not DB or not ns.rules or (DB.cuesVer or 0) >= 2 then return 0 end
    if not DB.backupPreCues then DB.backupPreCues = ns.Copy(DB.rules) end   -- full in-game copy of every rule before the first migration
    -- repair cue keys that normalization cleared
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

-- /xui mods: for every cue that a condition lists, print each step: which conditions list it and whether they are TRUE / FALSE / UNKNOWN right now,
-- the modifiers each one stores, the merged result the engine hands to the visual, and what the cue's frame actually shows.
function ns.ProbeMods()
    local function P(...) print("|cff9966ffXayaUI mods|r", ...) end
    local function TF(v) return v == true and "|cff55ff55TRUE|r" or v == false and "|cffff5555FALSE|r" or "|cffffd100UNKNOWN|r" end
    local function M(m)
        if type(m) ~= "table" then return "no modifiers stored" end
        local t = {}
        t[#t + 1] = "box " .. ((m.on == false) and "UNTICKED" or "ticked")
        if m.tint then t[#t + 1] = ("tint %.2f/%.2f/%.2f/%.2f"):format(m.tint[1] or 0, m.tint[2] or 0, m.tint[3] or 0, m.tint[4] or 0) end
        if m.desat ~= nil then t[#t + 1] = "desat " .. tostring(m.desat) end
        if m.glow ~= nil then t[#t + 1] = "glow " .. tostring(m.glow) end
        if m.alpha ~= nil then t[#t + 1] = ("opacity %.0f%%"):format(m.alpha * 100) end
        if m.strata then t[#t + 1] = "strata " .. m.strata end
        return table.concat(t, ", ")
    end
    local ctx = ns.ReadContext()
    local any = false
    for _, p in ipairs(ns.rules or {}) do
        if not p.parentUid then
            for _, cue in ipairs(ns.CuesOf(p)) do
                local listed = {}
                for _, c in ipairs(ns.ConditionsOf(p)) do
                    for _, k in ipairs(type(c.thenCues) == "table" and c.thenCues or {}) do if k == cue.cueKey then listed[#listed + 1] = c end end
                end
                if #listed > 0 then
                    any = true
                    P(("rule '%s' > cue '%s' (%s, key %s, rule %s, cue %s)"):format(tostring(p.name), tostring(cue.cueName or cue.name), tostring(cue.cueKind), tostring(cue.cueKey), p.enabled and "on" or "OFF", cue.enabled and "on" or "OFF"))
                    for _, c in ipairs(listed) do
                        local okc, res = pcall(ns.Evaluate, c, ctx)
                        P(("   condition '%s' (%s): %s;  %s"):format(tostring(c.name), c.enabled == false and "DISABLED" or "enabled", okc and TF(res) or "ERROR", M(type(c.thenMods) == "table" and c.thenMods[cue.cueKey] or nil)))
                    end
                    local ok, hit, info = pcall(ns.EvaluateCue, cue, ctx)
                    P(("   engine result for the cue: %s;  merged modifiers: %s"):format(ok and TF(hit) or "ERROR", (ok and info and info.mods) and M(info.mods) or "none"))
                    local fs = ns.VisualDebug and ns.VisualDebug(cue)
                    if fs then
                        P(("   frame now: %s, alpha %s, strata %s, color %s, desaturation %s, glow %s"):format(fs.shown and "shown" or "hidden", tostring(fs.alpha and ("%.2f"):format(fs.alpha)), tostring(fs.strata),
                            fs.color and ("%.2f/%.2f/%.2f/%.2f"):format(fs.color[1], fs.color[2], fs.color[3], fs.color[4]) or "?", tostring(fs.desat), tostring(fs.glow)))
                    else P("   frame now: none yet (the cue has never been shown this session)") end
                end
            end
        end
    end
    if not any then P("no condition lists a cue yet (a condition's THEN row must list a display cue for modifiers to matter)") end
end
