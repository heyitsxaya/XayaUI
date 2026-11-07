-- XayaUI: Cues. A CUE is a named thing that happens (sound, text, texture, icon, custom). A rule that has conditions owns its cues;
-- each condition's THEN lists cue keys. Under the hood a cue is a hidden child rule (rule.isCue, rule.parentUid, rule.cueKey, rule.cueKind),
-- so the existing sound / display engine and editors are reused. A cue fires while ANY enabled condition that lists it is true.
local addonName, ns = ...; ns = XayaUI_NS or ns -- (P4) XayaUI Rules shares the Platform's namespace (XayaUI/Core.lua)
local CoreS = ns.Settings("core")   -- (core 0.6.75, P2 settings seam: the same CueRulesDB keys as before; Modules.lua section 0b)

ns.CUE_KINDS = { "sound", "speech", "text", "texture", "icon", "bar", "custom" }   -- bar: BarCue.lua (RM-BARS, Xaya 2026-11-06)
local KIND_OK = {}
for _, k in ipairs(ns.CUE_KINDS) do KIND_OK[k] = true end
ns.CUE_KIND_LABEL = { sound = "Sound", speech = "Speech", text = "Text", texture = "Texture", icon = "Icon", bar = "Bar", custom = "Custom" }
local MAX_CUES = 40
-- Frame strata a condition may give a cue (low to high). TOOLTIP is left out on purpose: art there would sit above every window.
ns.MOD_STRATA = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG" }
ns.MOD_STRATA_OK = {}
for _, k in ipairs(ns.MOD_STRATA) do ns.MOD_STRATA_OK[k] = true end

-- A cue or condition sits in its parent rule's group: the group the RULE is in (moved by drag, arrows or "Move to") is the only
-- truth. A child keeps a copy in .folder (older saves and exports read it), refreshed here before anything lays groups out
-- (Visual.lua RefreshAllVisuals, the engine's AuraDisplay Build). Before 0.6.6 the copy was set at creation and refreshed only
-- while the settings window rebuilt its rule tree, after the displays had already been placed (triage C-L2, #344).
function ns.SyncCueFolders()
    local rules = ns.rules
    if type(rules) ~= "table" then return 0 end
    local parentFolder, fixed = {}, 0
    for _, r in ipairs(rules) do
        if type(r.uid) == "string" and not r.parentUid then parentFolder[r.uid] = r.folder or false end
    end
    for _, r in ipairs(rules) do
        local pf = r.parentUid and parentFolder[r.parentUid]
        if pf ~= nil then
            pf = pf or nil
            if r.folder ~= pf then r.folder = pf; fixed = fixed + 1 end
        end
    end
    return fixed
end

function ns.CuesOf(p)
    local idx = ns.StepChildrenOf and ns.StepChildrenOf(p, "cues")
    if idx then return idx end
    local out = {}
    if type(p.uid) ~= "string" then return out end
    for _, r in ipairs(ns.rules or {}) do
        if r ~= p and r.parentUid == p.uid and r.isCue then out[#out + 1] = r end
    end
    return out
end
function ns.ConditionsOf(p)
    local idx = ns.StepChildrenOf and ns.StepChildrenOf(p, "conds")
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
    -- D3 / #375 (core 0.6.56; Xaya: "allow sounds to be set to their own channel (generally SFX)"): a new Sound cue starts on the SFX
    -- channel (changeable on the cue); speech has no channel (C_VoiceChat.SpeakText takes none). Cues made before keep theirs (blank = Master).
    if kind == "sound" then n.sound.channel = "SFX" end
    n.visual.trigger = "condition"
    if kind == "icon" then n.visual.kind = "spellicon" end
    if kind == "bar" and ns.InitBarCue then ns.InitBarCue(n) end   -- 220 x 22, background 20 %, 1 px border, flat, drains right to left
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

-- Which conditions of rule p name cue key `key` in their THEN list. A cue that NO condition names is decided by the rule's own triggers
-- alone (0.6.14, Xaya 2026-11-04: "the cues tab fires based on triggers if no additional conditions are specified"); before 0.6.14
-- such a cue never fired once the rule had any condition. A condition that is switched off still names its cues and keeps them
-- silent (the condition's On switch: "An off condition never plays its cues"), so switching off a condition never turns its cue into
-- one that plays on every trigger. Returns the switched-on ones and the switched-off ones.
function ns.CueConditions(p, key)
    local on, off = {}, {}
    if not (p and key) then return on, off end
    for _, c in ipairs(ns.ConditionsOf(p)) do
        if type(c.thenCues) == "table" then
            for _, k in ipairs(c.thenCues) do
                if k == key then
                    if c.enabled ~= false then on[#on + 1] = c else off[#off + 1] = c end
                    break
                end
            end
        end
    end
    return on, off
end
-- Does any condition (on or off) decide this cue? false: the cue follows the rule's triggers.
function ns.CueGated(p, cue)
    if not (p and cue and cue.cueKey) then return false end
    for _, c in ipairs(ns.ConditionsOf(p)) do
        if type(c.thenCues) == "table" then
            for _, k in ipairs(c.thenCues) do if k == cue.cueKey then return true end end
        end
    end
    return false
end
-- "Fires ..." for the Cues tab: what decides this cue now.
function ns.CueFiresNote(cue)
    local p = cue and ns.FindParentRule and ns.FindParentRule(cue)
    if not p then return nil end
    local on, off = ns.CueConditions(p, cue.cueKey)
    local function names(list) local t = {}; for i, c in ipairs(list) do t[i] = tostring(c.name or ("Condition " .. i)) end; return table.concat(t, " or ") end
    if #on == 0 and #off == 0 then
        local any = #ns.ConditionsOf(p) > 0
        return "Fires with the rule's triggers" .. (any and " (no condition lists this cue; list it in a condition's THEN to make it wait for that condition)." or ".")
    end
    if #on == 0 then
        return "|cffffd100Silent:|r only " .. names(off) .. " list" .. (#off == 1 and "s" or "") .. " this cue, and " .. (#off == 1 and "it is" or "they are") ..
            " switched off. Switch it on, or take the cue out of its THEN list to let the cue follow the rule's triggers."
    end
    return "Fires while " .. names(on) .. " is true (" .. (#on == 1 and "that condition lists" or "those conditions list") .. " this cue)."
end

local modsPool = setmetatable({}, { __mode = "k" })
-- A cue is "on" while any switched-on condition that lists it is true; a cue no condition lists follows the rule's triggers.
function ns.EvaluateCue(rule, ctx)
    local info = ns.InfoFor and ns.InfoFor(rule) or { missing = {} }
    info.ctx, info.outcome, info.cue = ctx, true, true
    local p = ns.FindParentRule(rule)
    if not p then info.missing[1] = "parent rule not found"; info.result = false; return false, info end
    -- a switched-off rule switches off its cues too (before 0.6.14 they kept playing from the rule's triggers)
    if not p.enabled then info.missing[1] = "the rule is switched off"; info.result = false; return false, info end
    local pr, pi = ns.Evaluate(p, ctx)
    info.cd, info.present, info.buffSource, info.buffRef, info.auraRef = pi.cd, pi.present, pi.buffSource, pi.buffRef, pi.auraRef
    if rule.spellID ~= p.spellID then rule.spellID = p.spellID end
    if rule.buffID ~= p.buffID then rule.buffID = p.buffID end
    if rule.maxCharges ~= p.maxCharges then rule.maxCharges = p.maxCharges end
    local key = rule.cueKey
    -- no condition lists this cue (or the rule has no conditions at all): it simply follows the rule's own triggers
    if not ns.CueGated(p, rule) then
        info.result = pr and true or false
        info.by = "the rule's triggers"
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
                            if not mods then   -- (one table per cue, reused every step)
                                mods = ns.InStep and ns.InStep() and modsPool[rule]
                                if mods then for k in pairs(mods) do mods[k] = nil end
                                else mods = {}; if ns.InStep and ns.InStep() then modsPool[rule] = mods end end
                            end
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
    local DB = ns.SettingsReady() and CoreS
    if not DB or not ns.rules or (DB.cuesVer or 0) >= 2 then return 0 end
    if not DB.backupPreCues then DB.backupPreCues = ns.Copy(DB.rules) end   -- full in-game copy of every rule before the first migration
    -- repair cue keys that normalization cleared
    for _, r in ipairs(ns.rules) do
        if r.isCue and not r.cueKey then local p = ns.FindParentRule(r); if p then r.cueKey = ns.CueKey(p) end end
    end
    local made = 0
    local snapshot = {}
    for _, r in ipairs(ns.rules) do snapshot[#snapshot + 1] = r end
    -- audit D57 (core 0.6.67): each child is moved under its own guard: one that fails is recorded (XUI-E011) and left exactly as it
    -- was, the others go on, and the migration is marked done once, so it does not run again at every login (a child half moved before
    -- an error could gain its cue a second time).
    local failed = 0
    for _, child in ipairs(snapshot) do
        local nBefore, prevThen = #ns.rules, child.thenCues
        local okChild, errChild = pcall(function()
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
    
        end)
        if not okChild then
            failed = failed + 1
            for k = #ns.rules, nBefore + 1, -1 do table.remove(ns.rules, k) end   -- the cues it made before the error go again (NewCueRule appends)
            child.thenCues = prevThen
            if ns.RecordError then pcall(ns.RecordError, "XayaUI cue migration, condition '" .. tostring(child.name) .. "': " .. tostring(errChild), nil, "XayaUI", "XUI-E011") end
        end
    end
    if failed > 0 and ns.Print then ns.Print(failed .. " condition(s) could not be moved into Cues and were left as they were (see /xui report).") end
    DB.cuesVer = 2
    return made
end

-- /xui debug mods moved to XayaUI Dev Assist (core 0.6.56; REQUEST-LOG #81, XayaUI_DevAssist/CoreDebug.lua)
