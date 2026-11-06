-------------------------------------------------------------------------------
-- AutoPicker.lua : auto-populate as a table you fill in before anything is made (XayaUI_Options 0.6.44; every cue type 0.6.45; exactly her spec 0.6.46). Own code. UNTESTED in game.
-- Xaya, 2026-11-05 (first version, 0.6.42): "Auto-populate rules should also provide support for target debuffs - you should be able to
-- also customize auto-populate rule behavior to auto-populate with only specific, selected auto rules and choose their primary cue type
-- (speech to text, icon, progress texture, progress bar) on a case-by-case basis".
-- Xaya, 2026-11-05 (this version): "Clicking auto-populate should pre-load into a frame below all rules that will load in a table view.
-- Columns will be (Checkbox - clicking the header row will select all; clicking again will deselect all) | name | type (spell cd, aura,
-- debuff) | trigger (when available / when ready (for CD); at max stacks (for CD); when present (aura / debuff); when missing (aura /
-- debuff) | cue type | combat load (any, in combat, out of combat) ... By default, rules will be populated into the following groups:
-- class >> specialization >> cue type (icon/progress bar/texture/etc) >> name. Users can also click 'advanced' button at the bottom to
-- further add customization to pre-configured rules". Her answers (same day): the table sits in the pane where the class / spec rule
-- creation is; Advanced = extra cues; the list is the spec of the button pressed, and the class button lists every spec.
--
-- Candidates, all read from the game:
--   * cooldowns: the spec's learned list (ClassLearn.lua, ns.CLASS_AURA_DATA[spec]); before it is learned, the spellbook of the spec you
--     are in (ns.CollectCooldownSpells). Any spec of your class you have played once.
--   * auras on you and target debuffs: the Cooldown Manager's catalogue (C_CooldownViewer.GetCooldownViewerCategorySet(category, true)
--     and GetCooldownViewerCooldownInfo; docs/reference/api/namespaces.md:1370-1371, structures.md:1798). An entry with hasAura = true is
--     an aura: selfAura = true on you, selfAura = false on your target. INFERENCE (the documentation lists these fields without
--     describing them). Its aura ID is its first linkedSpellIDs entry (else its spellID). The Cooldown Manager answers for the spec you
--     are in now only, so auras and debuffs are listed for that spec only.
-- Choices per spec and row (CueRulesDB.ui.auto.picks[specID][key]): ticked, trigger, main cue, combat load, extra cues (Advanced).
-- Nothing is made until "Make the ticked rules" is pressed. Rules go into <Class> > <Spec> > <cue type>, named after the spell (her
-- "class >> specialization >> cue type >> name"; that the last step is the rule's name is waiting for her confirmation). A rule already in
-- that group with the same trigger (same spell / aura and the same state) is skipped, so pressing Make again adds only what is new.
-- V16 (Xaya, 2026-11-05: "do not guess and implement without providing proposals around that guess with confirmation"): her columns,
-- labels and order are built exactly; every addition is a proposal listed in debug-log/2026-11-06-*-auto-populate-*.md, not built.
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns
local issecret = issecretvalue or function() return false end

local AP = {}
ns.AutoPicker = AP

AP.TYPE = { cd = "Spell CD", aura = "Aura", debuff = "Debuff" }
-- trigger choices per type
AP.TRIG = {
    cd = { values = { ready = "When available / when ready", max = "At max stacks" }, order = { "ready", "max" } },   -- her labels, verbatim (V16)
    aura = { values = { present = "When present", missing = "When missing" }, order = { "present", "missing" } },
}
AP.TRIG.debuff = AP.TRIG.aura
local CD_STATE = { ready = "hasCharge", max = "ready" }   -- Conditions.lua CheckCooldownState: hasCharge = a charge is up, ready = all of them
-- Every cue type the addon has (Xaya, 2026-11-06: "ALL cue types that are supported by the addon need to be included in this dropdown
-- menu"): the cue kinds (Cues.lua ns.CUE_KINDS: sound, speech, text, texture, icon, custom) and the "+ New rule" types built on them
-- (Progress Texture = a texture cue with fill; Progress Bar). Two are listed but not made, and say so: Progress bar (its display, the
-- buff bars, is shelved: shelved/Bars.lua) and Custom (a custom cue does nothing yet: OutcomesEditor.lua, "not available yet").
AP.CUES = { values = { icon = "Icon", progtex = "Progress texture", bar = "Progress bar (not yet)", texture = "Texture", text = "Text",
                       speech = "Speech", sound = "Sound", custom = "Custom (not yet)" },
            order = { "icon", "progtex", "bar", "texture", "text", "speech", "sound", "custom" } }
AP.NOT_MADE = { bar = true, custom = true }
AP.EXTRA = { values = { icon = "Icon", progtex = "Progress texture", texture = "Texture", text = "Text", speech = "Speech", sound = "Sound" },
             order = { "icon", "progtex", "texture", "text", "speech", "sound" } }
AP.COMBAT = { values = { any = "Any", yes = "In combat", no = "Out of combat" }, order = { "any", "yes", "no" } }
-- the group each main cue goes in (the Smart Categories names where there is one: Options.lua ns.SMART_CATS)
AP.CUE_FOLDER = { icon = "Icons", progtex = "Progress Textures", texture = "Textures", text = "Text", speech = "Speech", sound = "Sounds" }
local CUE_TYPE = { icon = "icon", progtex = "progresstex", texture = "texture", text = "text", speech = "speech", sound = "sound" }   -- ns.NewTypedCue

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
local function SpecName(specID)
    local ok, _, name = pcall(GetSpecializationInfoByID, specID or 0)   -- pcall: ok, id, name, ...
    if ok and type(name) == "string" and not issecret(name) then return name end
    return "spec " .. tostring(specID)
end
AP.SpecName = SpecName

-------------------------------------------------------------------------------
-- Candidates
-------------------------------------------------------------------------------
-- auras from the Cooldown Manager's catalogue for the current spec: { aura = { {id, cdmID, name}, ... }, debuff = { ... } }
function AP.CdmAuras()
    local out, seen = { aura = {}, debuff = {} }, { aura = {}, debuff = {} }
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
                local kind = okI and type(info) == "table" and info.hasAura == true
                    and ((info.selfAura == true and "aura") or (info.selfAura == false and "debuff")) or nil
                if kind then
                    local spell = Readable(info.spellID) and tonumber(info.spellID) or nil
                    local linked = type(info.linkedSpellIDs) == "table" and info.linkedSpellIDs[1]
                    local aura = (Readable(linked) and tonumber(linked)) or spell
                    if aura and aura > 0 and not seen[kind][aura] then
                        seen[kind][aura] = true
                        local list = out[kind]
                        list[#list + 1] = { id = aura, cdmID = (spell and spell ~= aura) and spell or nil, name = SpellName(aura) or (spell and SpellName(spell)) }
                    end
                end
            end
        end
    end
    return out
end
function AP.CdmDebuffs() return AP.CdmAuras().debuff end

-- every candidate for one spec: { key, kind = "cd" | "aura" | "debuff", id, cdmID, name, icon, talent, spec }. Auras and debuffs only
-- for the spec you are in now. includeUnpicked = false leaves out talent cooldowns the game reads as not picked, for every spec, as the
-- one-click auto-populate did. (Reading it for the current spec only is a proposal waiting for Xaya, V16: the game answers "known" for
-- the spec you are in, so another spec's talents all read as not picked.)
function AP.Candidates(specID, includeUnpicked)
    local out, seen = {}, {}
    local function add(c)
        if seen[c.key] or not c.name then return end
        seen[c.key] = true
        c.spec = specID
        out[#out + 1] = c
    end
    local current = ns.CurrentSpecID and ns.CurrentSpecID()
    local isCurrent = specID ~= nil and specID == current
    local function talentOff(id, talent)
        return talent and includeUnpicked == false and ns.ReadTalentKnown and ns.ReadTalentKnown(id) == false
    end
    local data = specID and ns.CLASS_AURA_DATA and ns.CLASS_AURA_DATA[specID]
    if data and type(data.entries) == "table" then
        for _, e in ipairs(data.entries) do
            local id = tonumber(e.id)
            if e.kind == "cd" and id and not talentOff(id, e.talent) then   -- a spell the game no longer has (no name) is left out
                add({ key = "cd:" .. id, kind = "cd", id = id, name = SpellName(id), icon = SpellIcon(id), talent = e.talent and true or nil })
            end
        end
    elseif isCurrent and ns.CollectCooldownSpells then
        local ok, list = pcall(ns.CollectCooldownSpells, 0, includeUnpicked ~= false)
        if ok and type(list) == "table" then
            for _, sp in ipairs(list) do
                local id = tonumber(sp.id)
                if id then add({ key = "cd:" .. id, kind = "cd", id = id, name = sp.name or SpellName(id), icon = SpellIcon(id), talent = sp.talent and true or nil }) end
            end
        end
    end
    if isCurrent then
        local cat = AP.CdmAuras()
        for _, kind in ipairs({ "aura", "debuff" }) do
            for _, d in ipairs(cat[kind]) do
                add({ key = (kind == "aura" and "au:" or "db:") .. d.id, kind = kind, id = d.id, cdmID = d.cdmID, name = d.name,
                      icon = SpellIcon(d.id) or (d.cdmID and SpellIcon(d.cdmID)) })
            end
        end
    end
    local rank = { cd = 1, aura = 2, debuff = 3 }
    table.sort(out, function(a, b)
        if a.kind ~= b.kind then return rank[a.kind] < rank[b.kind] end
        if a.name ~= b.name then return tostring(a.name) < tostring(b.name) end
        return a.id < b.id
    end)
    return out
end

-- the rows of a list: one spec, or "all" = every spec of your class in the game's order
function AP.BuildRows(spec)
    local inc = not (ns.AutoCfg and ns.AutoCfg().talents == false)
    if spec ~= "all" then return AP.Candidates(spec, inc), { spec } end
    local rows, specs, seen = {}, {}, {}
    for i = 1, (GetNumSpecializations and GetNumSpecializations() or 0) do
        local sid = GetSpecializationInfo(i)
        if sid and not seen[sid] then
            seen[sid] = true
            specs[#specs + 1] = sid
            for _, c in ipairs(AP.Candidates(sid, inc)) do rows[#rows + 1] = c end
        end
    end
    return rows, specs
end

-- the list shown in the pane (this session only): { spec = specID | "all", rows, specs }. Read once when a button is pressed, not on
-- every redraw.
function AP.Load(spec)
    local rows, specs = AP.BuildRows(spec)
    AP.view = { spec = spec, rows = rows, specs = specs }
    AP.msg = nil
    return AP.view
end
function AP.Close() AP.view, AP.msg = nil, nil end

-------------------------------------------------------------------------------
-- Choices (per spec and row, saved)
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
-- one row's choices, filled with defaults: not ticked, and the first choice of each of her columns (When available / when ready or
-- When present; Icon; Any); no extra cues. Other defaults are proposals waiting for Xaya (V16). 0.6.42 saved a debuff's "when"
-- (on / missing): still read.
function AP.Choice(c)
    local p = Picks(c.spec)[c.key] or {}
    local cue = AP.CUES.values[p.cue or ""] and p.cue or "icon"
    local tv = AP.TRIG[c.kind].values
    local trig = tv[p.trig or ""] and p.trig or nil
    if not trig and c.kind == "debuff" and (p.when == "missing" or p.when == "on") then trig = (p.when == "missing") and "missing" or "present" end
    if not trig then trig = AP.TRIG[c.kind].order[1] end
    local combat = AP.COMBAT.values[p.combat or ""] and p.combat or "any"
    return p.on == true, trig, cue, combat, (type(p.xc) == "table") and p.xc or nil
end
function AP.SetChoice(c, field, value)
    local p = Picks(c.spec)
    p[c.key] = p[c.key] or {}
    p[c.key][field] = value
end
function AP.SetExtra(c, kind, on)
    local p = Picks(c.spec)
    p[c.key] = p[c.key] or {}
    local x = p[c.key].xc or {}
    x[kind] = on and true or nil
    p[c.key].xc = next(x) and x or nil
end
-- every row of the list ticked?
function AP.AllTicked(rows)
    if not rows or #rows == 0 then return false end
    for _, c in ipairs(rows) do if not AP.Choice(c) then return false end end
    return true
end
function AP.TickAll(rows, on)
    for _, c in ipairs(rows or {}) do AP.SetChoice(c, "on", on and true or nil) end
end

-------------------------------------------------------------------------------
-- Making the rules
-------------------------------------------------------------------------------
local function TopFolder(name)
    for _, f in ipairs(ns.folders or {}) do if not f.parent and f.name == name then return f end end
    return ns.NewFolder(name)
end
local function SubFolder(parent, name)
    for _, f in ipairs(ns.folders or {}) do if f.parent == parent.id and f.name == name then return f end end
    return ns.NewFolder(name, parent.id)
end
-- the trigger, read from a rule's own settings (so a rule renamed or moved inside the group still counts)
local function RuleKey(r)
    if r.useCooldown and (tonumber(r.spellID) or 0) ~= 0 then return "cd:" .. tonumber(r.spellID) .. ":" .. tostring(r.cdState) end
    if r.useBuff and (tonumber(r.buffID) or 0) ~= 0 then return "aura:" .. tonumber(r.buffID) .. ":" .. tostring(r.buffState) end
    local row = type(r.extra) == "table" and type(r.extra.list) == "table" and r.extra.list[1]
    if type(row) == "table" and row.type == "targetDebuff" and tonumber(row.spellID) then return "debuff:" .. tonumber(row.spellID) .. ":" .. tostring(row.state) end
end
-- the engine value a trigger choice sets
local function EngineState(kind, trig)
    if kind == "cd" then return CD_STATE[trig] end
    if kind == "aura" then return trig end              -- buffState present / missing
    return (trig == "missing") and "no" or "yes"        -- Target Debuff row: state yes / no
end
AP.EngineState = EngineState
-- the trigger keys of the rules already in a group (and its nested groups), and how many shown cues it holds
local function Have(folder)
    local inGroup = {}
    local function mark(fid, guard)
        if not fid or guard > 32 or inGroup[fid] then return end
        inGroup[fid] = true
        for _, f in ipairs(ns.folders or {}) do if f.parent == fid then mark(f.id, guard + 1) end end
    end
    mark(folder.id, 0)
    local keys, shown = {}, 0
    for _, r in ipairs(ns.rules or {}) do
        if r.folder and inGroup[r.folder] then
            if r.isCue then
                if r.visual and r.visual.enabled then shown = shown + 1 end
            else
                local k = RuleKey(r)
                if k then keys[k] = true end
            end
        end
    end
    return keys, shown
end

-- one cue of a rule, set up exactly as "+ New rule" sets up that type (Options.lua ns.NewTypedCue) and nothing more (V16). What a
-- speech cue says, a sound cue's sound, a texture's art, where shown cues sit and the cues' names are proposals waiting for Xaya.
local function AddCue(r, kind)
    if not ns.NewTypedCue then return nil end
    local cue = ns.NewTypedCue(r, CUE_TYPE[kind] or "icon")
    if cue then pcall(ns.RefreshVisual, cue) end
    return cue
end

-- Makes the ticked rows of a list. Returns made, skipped (already there), notMade (progress bar / custom: not available yet), message.
function AP.Make(view)
    view = view or AP.view
    if not view then return 0, 0, 0, "Press an Auto-populate button first." end
    local made, skipped, notMade = 0, 0, 0
    local todo = {}
    for _, c in ipairs(view.rows or {}) do
        local on, trig, cue, combat, xc = AP.Choice(c)
        if on then todo[#todo + 1] = { c = c, trig = trig, cue = cue, combat = combat, xc = xc } end
    end
    if #todo == 0 then return 0, 0, 0, "Nothing is ticked: tick the rules you want, then press Make." end
    local className = tostring((UnitClass and UnitClass("player")) or "Class")
    local classF
    local perSpec, specOrder = {}, {}
    for _, t in ipairs(todo) do
        local c, trig, cue = t.c, t.trig, t.cue
        if AP.NOT_MADE[cue] then
            notMade = notMade + 1
        else
            classF = classF or TopFolder(className)
            local ps = perSpec[c.spec]
            if not ps then
                local specF = SubFolder(classF, SpecName(c.spec))
                ps = { folder = specF, made = 0, cueF = {} }
                perSpec[c.spec] = ps
                specOrder[#specOrder + 1] = c.spec
            end
            local cf = ps.cueF[cue]
            if not cf then
                local f = SubFolder(ps.folder, AP.CUE_FOLDER[cue])
                cf = { folder = f, keys = (Have(f)) }
                ps.cueF[cue] = cf
            end
            local state = EngineState(c.kind, trig)
            local key = c.kind .. ":" .. c.id .. ":" .. tostring(state)
            if cf.keys[key] then
                skipped = skipped + 1
            else
                local r = ns.NewRule()
                r.name = c.name
                r.folder = cf.folder.id
                r.load = r.load or {}
                r.load.specs = { [tostring(c.spec)] = true }
                if t.combat == "yes" or t.combat == "no" then r.load.combat = t.combat end
                r.autoKind, r.autoSrc = c.kind, "auto-populate table"
                r.sound.enabled, r.visual.enabled = false, false   -- the rule's cues carry what you see / hear
                r.talentMode = "none"
                if c.kind == "cd" then
                    r.useCooldown, r.spellID, r.cdState, r.buffState = true, c.id, state, "none"
                    if c.talent then r.talents, r.talentMode = { { id = c.id, state = "known" } }, "all" end
                elseif c.kind == "aura" then
                    r.useBuff, r.buffID, r.buffState, r.cdState = true, c.id, state, "none"
                else
                    r.cdState, r.buffState = "none", "none"
                    r.extra = { list = { { type = "targetDebuff", spellID = c.id, cdmID = c.cdmID, unit = "target", state = state, cdmAbsent = "yes" } } }
                end
                ns.rules[#ns.rules + 1] = r
                local kinds = { cue }
                for _, k in ipairs(AP.EXTRA.order) do
                    if t.xc and t.xc[k] and k ~= cue then kinds[#kinds + 1] = k end
                end
                for _, k in ipairs(kinds) do AddCue(r, k) end
                cf.keys[key] = true
                made = made + 1
                ps.made = ps.made + 1
            end
        end
    end
    if made > 0 then
        if ns.MarkDirty then ns.MarkDirty() end
        if ns.Fire then pcall(ns.Fire, "CONFIG_CHANGED") end
    end
    local where = {}
    for _, sid in ipairs(specOrder) do
        if perSpec[sid].made > 0 then where[#where + 1] = ("%s > %s (%d)"):format(className, SpecName(sid), perSpec[sid].made) end
    end
    local msg = ("Made %d rule(s)%s."):format(made, (#where > 0) and (" in " .. table.concat(where, ", ")) or "")
    if skipped > 0 then msg = msg .. (" %d already there with the same trigger were skipped."):format(skipped) end
    if notMade > 0 then msg = msg .. (" %d ticked with \"Progress bar\" or \"Custom\" were not made: those are not available yet."):format(notMade) end
    return made, skipped, notMade, msg
end

-------------------------------------------------------------------------------
-- The table on the Class/Spec Rule Creator page (Options.lua BuildClassCreator merges these args)
-------------------------------------------------------------------------------
-- column widths: shares of the pane that add up to 1, so a row is one table row (Skin.lua arg.xuiCell: narrow gutters taken out of the
-- cells, and the next row starts on a new line while the tick box column, 0.08, is wider than the gutters). Advanced adds Extra cues.
local COLS = {
    { "on", 0.08 }, { "nm", 0.24 }, { "ty", 0.11 }, { "tr", 0.20 }, { "cu", 0.19 }, { "cb", 0.18 } }
local COLS_ADV = {
    { "on", 0.08 }, { "nm", 0.18 }, { "ty", 0.09 }, { "tr", 0.16 }, { "cu", 0.15 }, { "cb", 0.16 }, { "xc", 0.18 } }
AP.COLS, AP.COLS_ADV = COLS, COLS_ADV
local CELL = { xuiCell = true }
local CELL_DD = { xuiCell = true, xuiTextLeft = true }
local function Gold(s) return "|cffffd100" .. s .. "|r" end

-- notify: a change that adds or removes controls (Advanced, Make). keep: a change that shows only in controls already there (a tick, a
-- choice); the redraw that follows reuses the options tree (Options.lua Tree.Keep), so a click does not rebuild every rule list.
-- Built exactly as Xaya specified (V16): a frame below the buttons; a header row (tick box | Name | Type | Trigger | Cue type | Combat
-- load); one row per rule offered; at the bottom an Advanced button (Extra cues). Beyond that only what the table cannot work without:
-- the button that makes the ticked rows and its result line, and a line when there is nothing to list. Everything else (paging, a
-- title, help text, reload / close buttons, spec names in the all-specs list) is a proposal waiting for her.
function AP.Args(notify, keep)
    notify = notify or function() end
    keep = keep or function() end
    local args = {}
    local view = AP.view
    if not view then return args end
    local rows = view.rows or {}
    local adv = AP.adv and true or false
    local cols = adv and COLS_ADV or COLS
    local W = {}
    for _, cdef in ipairs(cols) do W[cdef[1]] = cdef[2] end
    local T = {}
    -- the frame: a one-space name, because AceConfigDialog draws a group with an empty name as a plain group with no box
    -- (AceConfigDialog-3.0.lua:1135-1140); a space keeps the box and shows no title text
    args.apTable = { type = "group", inline = true, order = 0.7, name = " ", args = T }
    if #rows == 0 then
        T.none = { type = "description", order = 1, width = "full", fontSize = "medium",
            name = "Nothing to list yet: play this spec once (its cooldown list is read from your spellbook), and add your auras and debuffs to the Cooldown Manager." }
        return args
    end
    -- header row: the tick box ticks every row; pressed again it unticks them all
    T.hOn = { type = "toggle", order = 1, width = "relative", relWidth = W.on, name = "", arg = CELL,
        desc = "Tick every row. Click again to untick them all.",
        get = function() return AP.AllTicked(rows) end,
        set = function(_, v) AP.TickAll(rows, v); keep() end }
    local heads = { nm = "Name", ty = "Type", tr = "Trigger", cu = "Cue type", cb = "Combat load", xc = "Extra cues" }
    for k, cdef in ipairs(cols) do
        if cdef[1] ~= "on" then
            T["h" .. cdef[1]] = { type = "description", order = 1 + k * 0.01, width = "relative", relWidth = cdef[2], fontSize = "medium",
                name = Gold(heads[cdef[1]]), arg = CELL }
        end
    end
    for i, c in ipairs(rows) do
        local o = 2 + i * 0.001
        T["r" .. i .. "on"] = { type = "toggle", order = o, width = "relative", relWidth = W.on, name = "", arg = CELL,
            desc = AP.TYPE[c.kind] .. ", " .. ((c.kind == "cd") and "spell " or "aura ") .. c.id
                .. ((c.cdmID and (" (Cooldown Manager: " .. c.cdmID .. ")")) or "")
                .. (c.talent and ". A talent: the rule loads only while you have it." or ""),
            get = function() local on = AP.Choice(c); return on end,
            set = function(_, v) AP.SetChoice(c, "on", v and true or nil); keep() end }
        T["r" .. i .. "nm"] = { type = "description", order = o + 0.0001, width = "relative", relWidth = W.nm, fontSize = "medium", arg = CELL,
            name = (c.icon and ("|T" .. c.icon .. ":16|t ") or "") .. c.name }
        T["r" .. i .. "ty"] = { type = "description", order = o + 0.0002, width = "relative", relWidth = W.ty, fontSize = "medium", arg = CELL,
            name = "|cffaaaaaa" .. AP.TYPE[c.kind] .. "|r" }
        local tdef = AP.TRIG[c.kind]
        T["r" .. i .. "tr"] = { type = "select", order = o + 0.0003, width = "relative", relWidth = W.tr, name = "", arg = CELL_DD,
            values = tdef.values, sorting = tdef.order,
            desc = (c.kind == "cd") and "When available / when ready: a charge is up (the spell can be cast). At max stacks: every charge is back. For a spell without charges both are the same."
                or ("When present: the rule is true while the " .. ((c.kind == "aura") and "aura is on you." or "debuff is on your target.") .. " When missing: while it is not."),
            get = function() local _, trig = AP.Choice(c); return trig end,
            set = function(_, v) AP.SetChoice(c, "trig", v); keep() end }
        T["r" .. i .. "cu"] = { type = "select", order = o + 0.0004, width = "relative", relWidth = W.cu, name = "", arg = CELL_DD,
            values = AP.CUES.values, sorting = AP.CUES.order,
            desc = "The rule's main cue, and the group it goes in. Progress bar and Custom are not available yet: a row ticked with one is not made.",
            get = function() local _, _, cue = AP.Choice(c); return cue end,
            set = function(_, v) AP.SetChoice(c, "cue", v); keep() end }
        T["r" .. i .. "cb"] = { type = "select", order = o + 0.0005, width = "relative", relWidth = W.cb, name = "", arg = CELL_DD,
            values = AP.COMBAT.values, sorting = AP.COMBAT.order,
            desc = "When the rule loads: any time, only in combat, or only out of combat.",
            get = function() local _, _, _, cb = AP.Choice(c); return cb end,
            set = function(_, v) AP.SetChoice(c, "combat", v); keep() end }
        if adv then
            T["r" .. i .. "xc"] = { type = "multiselect", dialogControl = "Dropdown", order = o + 0.0006, width = "relative", relWidth = W.xc, name = "", arg = CELL_DD,
                values = AP.EXTRA.values, sorting = AP.EXTRA.order,
                desc = "More cues for this rule beside its main one (the main cue is not added twice).",
                get = function(_, k) local _, _, _, _, xc = AP.Choice(c); return (xc and xc[k]) and true or false end,
                set = function(_, k, v) AP.SetExtra(c, k, v); keep() end }
        end
    end
    T.adv = { type = "execute", order = 9, name = "Advanced", arg = { xuiCenter = true },
        desc = "Shows or hides the Extra cues column: more cues for a rule beside its main one.",
        func = function() AP.adv = not AP.adv; notify() end }
    T.make = { type = "execute", order = 9.01, name = "Make the ticked rules", arg = { xuiCenter = true },
        func = function()
            local _, _, _, m = AP.Make(view)
            AP.msg = m
            if ns.Print then ns.Print("auto-populate: " .. m) end
            notify()
        end }
    T.msg = { type = "description", order = 9.1, width = "full", fontSize = "medium",
        hidden = function() return not AP.msg end, name = function() return AP.msg or "" end }
    return args
end
