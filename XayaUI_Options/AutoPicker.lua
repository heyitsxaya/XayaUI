-------------------------------------------------------------------------------
-- AutoPicker.lua : auto-populate, but you choose which rules to make and each one's main cue (XayaUI_Options 0.6.42). Own code.
-- UNTESTED in game.
-- Xaya, 2026-11-05: "Auto-populate rules should also provide support for target debuffs - you should be able to also customize
-- auto-populate rule behavior to auto-populate with only specific, selected auto rules and choose their primary cue type (speech to
-- text, icon, progress texture, progress bar) on a case-by-case basis".
--
-- Candidates, for the spec you are in now, all read from the game:
--   * cooldowns: the spec's learned list (ClassLearn.lua, ns.CLASS_AURA_DATA[spec]); before it is learned, the spellbook
--     (ns.CollectCooldownSpells);
--   * target debuffs: the Cooldown Manager's catalogue for this spec (C_CooldownViewer.GetCooldownViewerCategorySet(category, true) and
--     GetCooldownViewerCooldownInfo; docs/reference/api/namespaces.md:1370-1371, structures.md:1798): an entry with hasAura = true and
--     selfAura = false. INFERENCE (the documentation lists these fields without describing them): its aura is not on you, so it is a
--     debuff you put on a target. Its aura ID is its first linkedSpellIDs entry (else its spellID); the Cooldown Manager files it under
--     the entry's spellID, which the Target Debuff trigger uses in combat (the game hides enemy auras there).
-- Choices per spec (CueRulesDB.ui.auto.picks[specID][key]): ticked or not, the main cue (speech / icon / progress texture; a progress
-- bar waits on Xaya's decision, backlog A), and for a debuff when the rule is true (on the target / missing from the target).
-- Nothing is made until "Make the ticked rules" is pressed. A rule already made for the same spell (cooldown) or debuff in the spec's
-- "<Class> <Spec> - autorule population" group is skipped, so pressing it again only adds what is new.
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns
local issecret = issecretvalue or function() return false end

local AP = {}
ns.AutoPicker = AP

AP.CUES = { values = { speech = "Speech (text-to-speech)", icon = "Icon", progtex = "Progress texture", bar = "Progress bar (not yet)" },
            order = { "speech", "icon", "progtex", "bar" } }
AP.WHEN = { values = { on = "On the target", missing = "Missing from target" }, order = { "on", "missing" } }

local function Readable(v) return v ~= nil and not issecret(v) end
local function SpellName(id)
    if not (C_Spell and C_Spell.GetSpellName) then return nil end
    local ok, n = pcall(C_Spell.GetSpellName, id)
    if ok and type(n) == "string" and not issecret(n) and n ~= "" then return n end
end
local function SpellIcon(id)
    if not (C_Spell and C_Spell.GetSpellTexture) then return nil end
    local ok, t = pcall(C_Spell.GetSpellTexture, id)
    if ok and Readable(t) then return t end
end

-------------------------------------------------------------------------------
-- Candidates
-------------------------------------------------------------------------------
-- target debuffs from the Cooldown Manager's catalogue for the current spec: { id = aura ID, cdmID = the entry's spell (or nil), name }
function AP.CdmDebuffs()
    local out, seen = {}, {}
    local CV = C_CooldownViewer
    if not (CV and CV.GetCooldownViewerCategorySet and CV.GetCooldownViewerCooldownInfo) then return out end
    local cats = (Enum and Enum.CooldownViewerCategory) or { Essential = 0, Utility = 1, TrackedBuff = 2, TrackedBar = 3 }
    local values = {}
    for _, v in pairs(cats) do if type(v) == "number" then values[#values + 1] = v end end
    table.sort(values)
    for _, cat in ipairs(values) do
        local ok, ids = pcall(CV.GetCooldownViewerCategorySet, cat, true)
        if ok and type(ids) == "table" and not issecret(ids) then
            for _, cid in ipairs(ids) do
                local okI, info = pcall(CV.GetCooldownViewerCooldownInfo, cid)
                if okI and type(info) == "table" and info.hasAura == true and info.selfAura == false then
                    local spell = Readable(info.spellID) and tonumber(info.spellID) or nil
                    local linked = type(info.linkedSpellIDs) == "table" and info.linkedSpellIDs[1]
                    local aura = (Readable(linked) and tonumber(linked)) or spell
                    if aura and aura > 0 and not seen[aura] then
                        seen[aura] = true
                        out[#out + 1] = { id = aura, cdmID = (spell and spell ~= aura) and spell or nil, name = SpellName(aura) or (spell and SpellName(spell)) }
                    end
                end
            end
        end
    end
    return out
end

-- every candidate for a spec: { key, kind = "cd" | "debuff", id, cdmID, name, icon, talent }. Debuffs only for the spec you are in now
-- (the Cooldown Manager answers for the current spec only).
function AP.Candidates(specID)
    local out, seen = {}, {}
    local function add(c)
        if seen[c.key] or not c.name then return end
        seen[c.key] = true
        out[#out + 1] = c
    end
    local current = ns.CurrentSpecID and ns.CurrentSpecID()
    local data = specID and ns.CLASS_AURA_DATA and ns.CLASS_AURA_DATA[specID]
    if data and type(data.entries) == "table" then
        for _, e in ipairs(data.entries) do
            if e.kind == "cd" and tonumber(e.id) then
                local nm = SpellName(e.id)   -- a spell the game no longer has is left out
                add({ key = "cd:" .. e.id, kind = "cd", id = tonumber(e.id), name = nm, icon = SpellIcon(e.id), talent = e.talent and true or nil })
            end
        end
    elseif specID and specID == current and ns.CollectCooldownSpells then
        local ok, list = pcall(ns.CollectCooldownSpells, 0, true)
        if ok and type(list) == "table" then
            for _, sp in ipairs(list) do
                if tonumber(sp.id) then add({ key = "cd:" .. sp.id, kind = "cd", id = tonumber(sp.id), name = sp.name or SpellName(sp.id), icon = SpellIcon(sp.id), talent = sp.talent and true or nil }) end
            end
        end
    end
    if specID and specID == current then
        for _, d in ipairs(AP.CdmDebuffs()) do
            add({ key = "db:" .. d.id, kind = "debuff", id = d.id, cdmID = d.cdmID, name = d.name, icon = SpellIcon(d.id) or (d.cdmID and SpellIcon(d.cdmID)) })
        end
    end
    table.sort(out, function(a, b)
        if a.kind ~= b.kind then return a.kind == "cd" end
        if a.name ~= b.name then return tostring(a.name) < tostring(b.name) end
        return a.id < b.id
    end)
    return out
end

-------------------------------------------------------------------------------
-- Choices (per spec, saved)
-------------------------------------------------------------------------------
local function Picks(specID)
    local a = ns.AutoCfg and ns.AutoCfg()
    if not a then return {} end
    a.picks = a.picks or {}
    local k = tostring(specID or 0)
    a.picks[k] = a.picks[k] or {}
    return a.picks[k]
end
AP.Picks = Picks
-- the choice for one candidate, filled with defaults: not ticked; icon; a debuff is true while it is on the target, except a speech
-- cue, which defaults to "missing" (a reminder to put it back up)
function AP.Choice(specID, c)
    local p = Picks(specID)[c.key] or {}
    local cue = AP.CUES.values[p.cue] and p.cue or "icon"
    local when = p.when
    if c.kind == "debuff" and not AP.WHEN.values[when or ""] then when = (cue == "speech") and "missing" or "on" end
    return p.on == true, cue, when
end
local function SetChoice(specID, c, field, value)
    local p = Picks(specID)
    p[c.key] = p[c.key] or {}
    p[c.key][field] = value
end
AP.SetChoice = SetChoice

-------------------------------------------------------------------------------
-- Making the rules
-------------------------------------------------------------------------------
local function GroupFor(specID)
    local className = UnitClass and UnitClass("player") or "Class"
    local okS, _, specName = pcall(GetSpecializationInfoByID, specID or 0)
    if not okS or not specName then specName = "spec " .. tostring(specID) end
    local parentName = tostring(className) .. " " .. tostring(specName) .. " - autorule population"
    local parent
    for _, f in ipairs(ns.folders or {}) do if not f.parent and f.name == parentName then parent = f; break end end
    parent = parent or ns.NewFolder(parentName)
    local function Sub(name)
        for _, f in ipairs(ns.folders or {}) do if f.parent == parent.id and f.name == name then return f end end
        return ns.NewFolder(name, parent.id)
    end
    return parent, Sub
end
-- the cooldown spells and debuff IDs that already have a rule in the spec's group (and its nested groups)
local function Have(parent)
    local inGroup = {}
    local function mark(fid, guard)
        if not fid or guard > 32 or inGroup[fid] then return end
        inGroup[fid] = true
        for _, f in ipairs(ns.folders or {}) do if f.parent == fid then mark(f.id, guard + 1) end end
    end
    mark(parent.id, 0)
    local have = { cd = {}, debuff = {} }
    for _, r in ipairs(ns.rules or {}) do
        if not r.isCue and r.folder and inGroup[r.folder] then
            if (tonumber(r.spellID) or 0) ~= 0 then have.cd[tonumber(r.spellID)] = true end
            for _, row in ipairs((type(r.extra) == "table" and type(r.extra.list) == "table") and r.extra.list or {}) do
                if type(row) == "table" and row.type == "targetDebuff" and tonumber(row.spellID) then have.debuff[tonumber(row.spellID)] = true end
            end
        end
    end
    return have
end

-- what a speech cue says (Xaya can change the text on the cue afterwards)
local function SpeechText(c, when)
    if c.kind == "cd" then return c.name .. " ready" end
    if when == "missing" then return c.name .. " missing" end
    return c.name
end

-- Makes the ticked rules for a spec. Returns made, skipped (already there), notMade (progress bar: not available yet), message.
function AP.Make(specID)
    local made, skipped, notMade = 0, 0, 0
    local todo = {}
    for _, c in ipairs(AP.Candidates(specID)) do
        local on, cue, when = AP.Choice(specID, c)
        if on then todo[#todo + 1] = { c = c, cue = cue, when = when } end
    end
    if #todo == 0 then return 0, 0, 0, "Nothing is ticked: tick the rules you want, then press Make." end
    local parent, Sub = GroupFor(specID)
    local have = Have(parent)
    for _, t in ipairs(todo) do
        local c, cue, when = t.c, t.cue, t.when
        if cue == "bar" then
            notMade = notMade + 1
        elseif (c.kind == "cd" and have.cd[c.id]) or (c.kind == "debuff" and have.debuff[c.id]) then
            skipped = skipped + 1
        else
            local r = ns.NewRule()
            r.name = c.name
            r.folder = Sub(c.kind == "cd" and "Cooldowns" or "Target Debuffs").id
            r.load = r.load or {}
            r.load.specs = { [tostring(specID)] = true }
            r.autoKind, r.autoSrc = c.kind, "picker"
            r.sound.enabled, r.visual.enabled = false, false   -- the rule's cue carries what you see / hear
            r.talentMode = "none"
            if c.kind == "cd" then
                r.useCooldown, r.spellID, r.cdState, r.buffState = true, c.id, "ready", "none"
                if c.talent then r.talents, r.talentMode = { { id = c.id, state = "known" } }, "all" end
            else
                r.cdState, r.buffState = "none", "none"
                r.extra = { list = { { type = "targetDebuff", spellID = c.id, cdmID = c.cdmID, unit = "target",
                                       state = (when == "missing") and "no" or "yes", cdmAbsent = "yes" } } }
            end
            ns.rules[#ns.rules + 1] = r
            local cue1 = ns.NewCueRule and ns.NewCueRule(r, cue == "speech" and "speech" or "icon")
            if cue1 then
                cue1.name = c.name .. ((cue == "speech") and " (speech)" or ((cue == "progtex") and " (progress texture)" or " (icon)"))
                if cue == "speech" then
                    cue1.sound.value = SpeechText(c, when)
                else
                    local v = cue1.visual
                    v.w, v.h = 48, 48
                    v.x, v.y = ((made % 8) - 3.5) * 52, -120 - 52 * math.floor(made / 8)
                    if cue == "progtex" then
                        if type(v.fill) ~= "table" then v.fill = { enabled = false, reverse = false, min = 0, max = 1 } end
                        v.fill.enabled = true
                    end
                    pcall(ns.RefreshVisual, cue1)
                end
            end
            if c.kind == "cd" then have.cd[c.id] = true else have.debuff[c.id] = true end
            made = made + 1
        end
    end
    if ns.MarkDirty then ns.MarkDirty() end
    if ns.Fire then pcall(ns.Fire, "CONFIG_CHANGED") end
    local msg = ("Made %d rule(s) in \"%s\"."):format(made, parent.name)
    if skipped > 0 then msg = msg .. (" %d already there were skipped."):format(skipped) end
    if notMade > 0 then msg = msg .. (" %d ticked with \"Progress bar\" were not made: that display does not exist yet."):format(notMade) end
    return made, skipped, notMade, msg
end

-------------------------------------------------------------------------------
-- The picker on the Class/Spec Rule Creator page (Options.lua BuildClassCreator merges these args)
-------------------------------------------------------------------------------
local lastMsg
function AP.Args(notify)
    notify = notify or function() end
    local args = {}
    local specID = ns.CurrentSpecID and ns.CurrentSpecID()
    local okS, _, specName = pcall(GetSpecializationInfoByID, specID or 0)
    args.apPickHdr = { type = "header", order = 0.7, name = "Choose which rules to make" }
    args.apPickInfo = { type = "description", order = 0.701, width = "full", fontSize = "medium",
        name = "For " .. ((okS and specName) or "your spec") .. ": tick the cooldowns and target debuffs you want, pick each one's main cue, then press "
            .. "Make the ticked rules. Only the ticked ones are made. Target debuffs come from your Cooldown Manager; in combat the game hides "
            .. "enemy auras, so a debuff rule works in combat only while that debuff is in your Cooldown Manager. Progress bar is not available yet." }
    local cands = AP.Candidates(specID)
    if #cands == 0 then
        args.apPickNone = { type = "description", order = 0.702, width = "full", fontSize = "medium",
            name = "Nothing to list yet: play this spec once (the cooldown list is learned from your spellbook), and add your debuffs to the Cooldown Manager." }
    end
    for i, c in ipairs(cands) do
        local o = 0.71 + i * 0.0001
        args["apPick" .. i] = { type = "toggle", order = o, width = 1.5,
            name = (c.icon and ("|T" .. c.icon .. ":16|t ") or "") .. c.name .. (c.kind == "debuff" and "  |cffaaaaaa(target debuff)|r" or ""),
            desc = (c.kind == "cd" and "Cooldown, spell " or "Target debuff, aura ") .. c.id .. ((c.cdmID and (" (Cooldown Manager: " .. c.cdmID .. ")")) or "")
                .. (c.talent and ". A talent: the rule loads only while you have it." or ""),
            get = function() local on = AP.Choice(specID, c); return on end,
            set = function(_, v) SetChoice(specID, c, "on", v and true or nil); notify() end }
        args["apCue" .. i] = { type = "select", order = o + 0.00002, width = 0.9, name = "",
            values = AP.CUES.values, sorting = AP.CUES.order,
            desc = "This rule's main cue. Progress bar is not available yet: a rule ticked with it is not made.",
            get = function() local _, cue = AP.Choice(specID, c); return cue end,
            set = function(_, v) SetChoice(specID, c, "cue", v); notify() end }
        if c.kind == "debuff" then
            args["apWhen" .. i] = { type = "select", order = o + 0.00004, width = 0.9, name = "",
                values = AP.WHEN.values, sorting = AP.WHEN.order,
                desc = "On the target: the rule is true while your debuff is on your target. Missing from target: true while it is not (a reminder).",
                get = function() local _, _, when = AP.Choice(specID, c); return when end,
                set = function(_, v) SetChoice(specID, c, "when", v); notify() end }
        end
        args["apBr" .. i] = { type = "description", order = o + 0.00006, width = "full", fontSize = "small", name = "" }
    end
    if #cands > 0 then
        args.apTickAll = { type = "execute", order = 0.79, width = 0.8, name = "Tick all",
            func = function() for _, c in ipairs(cands) do SetChoice(specID, c, "on", true) end; notify() end }
        args.apTickNone = { type = "execute", order = 0.791, width = 0.8, name = "Untick all",
            func = function() for _, c in ipairs(cands) do SetChoice(specID, c, "on", nil) end; notify() end }
        args.apMake = { type = "execute", order = 0.792, width = 1.4, name = "Make the ticked rules",
            func = function()
                local _, _, _, m = AP.Make(specID)
                lastMsg = m
                if ns.Print then ns.Print("auto-populate: " .. m) end
                notify()
            end }
        args.apMsg = { type = "description", order = 0.793, width = "full", fontSize = "medium",
            hidden = function() return not lastMsg end, name = function() return lastMsg or "" end }
    end
    return args
end
