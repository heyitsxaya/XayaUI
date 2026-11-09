-------------------------------------------------------------------------------
-- AutoPicker.lua : auto-populate as a table you fill in before anything is made (XayaUI_Options 0.6.44; every cue type 0.6.45; exactly her
-- spec 0.6.46; rebuilt to her answers 0.6.53; Generate buttons 0.6.54). Own code. UNTESTED in game.
-- Xaya, 2026-11-05: "Clicking auto-populate should pre-load into a frame below all rules that will load in a table view. Columns will be
-- (Checkbox - clicking the header row will select all; clicking again will deselect all) | name | type (spell cd, aura, debuff) | trigger
-- (when available / when ready (for CD); at max stacks (for CD); when present (aura / debuff); when missing (aura / debuff) | cue type |
-- combat load (any, in combat, out of combat) ... By default, rules will be populated into the following groups: class >> specialization
-- >> cue type (icon/progress bar/texture/etc) >> name. Users can also click 'advanced' button at the bottom to further add customization".
-- Her answers (docs/process/QUESTIONS-engine-session.md, "Her answers" and "Round 2 answers", 2026-11-06), each built as given (V16):
--   A3 a title and help text; A4 Reload list and Close; A5 a Spec column (all-specs list); A11 "Type, then A-Z, with clear headers and the
--   ability to full deselect full buckets"; a Cue set-up column (Speech: "[x] Customize", which opens a small typing window; Sound: a sound
--   picker; Texture / Progress texture: a picture picker); A6 speech text: cooldown = its name, When missing = "<name> ended", When present
--   = the name; Sound / Texture / Progress texture must be chosen ("request customization" / "force choice from drop down list"); rows not
--   finished are not made, stay in the table and a popup says "error issue making the following rules: [...]. Please finish configuring
--   them to create them."; A7 debuff + Speech / Sound = When missing; A8 the talent switch applies to the spec you are in, another spec
--   shows all its talent cooldowns; A9 "Populate"; A10 cue names "<spell> (<cue type>)"; A12 widths fit their contents; A14 made rows
--   leave the table; A16 icon + name in the table only; A17 "(soonTM)"; placement "3 across, offset down, 3 across, return to center and
--   offset up" (rows of 3 centred on the screen centre; unmoved auto-placed cues re-laid out together); "Hide / Show already generated rules (can potentially cause duplicates)": hidden by default, shown rows start unticked.
--   Extra cues with a set-up get their own controls in the Cue set-up cell ("1 for now, flag for potential revision pending feedback").
-- 0.6.54 (Xaya, 2026-11-06): "change auto-populate buttons to say "Generate Rules for {spec}"", "clicking these buttons should THEN generate
--   a list below. no rules should be auto-shown without a button being clicked first", "four buttons per specialization auto-generation:
--   "Generate All Rules for {Spec}" "Generate CD Tracking Rules for {Spec}" "Generate Aura Tracking Rules for {Spec}" "Generate Target
--   Debuff Tracking Rules for {Spec}"; these buttons filter out what rules display below", "missing select all tick box option to select
--   all". Her answers: built on this table; the class button gets the same four ("... for my class"); one "Select all" tick box at the
--   top of the list (the header-row tick box stays: her earlier column spec). AP.FILTERS / AP.ButtonLabel / AP.Load(spec, filter).
--
-- Candidates, all read from the game:
--   * cooldowns: the spec's learned list (ClassLearn.lua, ns.CLASS_AURA_DATA[spec]; it holds every talent cooldown, picked or not); before
--     it is learned, the spellbook of the spec you are in (ns.CollectCooldownSpells).
--   * auras on you and target debuffs: the Cooldown Manager's catalogue (C_CooldownViewer.GetCooldownViewerCategorySet(category, true)
--     and GetCooldownViewerCooldownInfo; docs/reference/api/namespaces.md:1370-1371, structures.md:1798). An entry with hasAura = true is
--     an aura: selfAura = true on you, selfAura = false on your target. INFERENCE (the documentation lists these fields without
--     describing them). Its aura ID is its first linkedSpellIDs entry (else its spellID). The Cooldown Manager answers for the spec you
--     are in now only; another spec's auras and debuffs come from what the learner read while you last played it (C1, core 0.6.56).
-- Choices per spec and row (XayaUI Rules' store: auto.picks[specID][key]; CueRulesDB.ui.auto before P5): ticked, trigger, main cue, combat load, extra cues (Advanced), cue
-- set-up (su: speech text, sound, art). Nothing is made until "Populate" is pressed.
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns
-- (Rules 0.7.0, REQUEST-LOG A23 SD-6) This file is part of XayaUI Rules (it was the load-on-demand addon XayaUI_Rules_Options). The game
-- reads it at login with Rules; everything below only runs when the settings window first opens with Rules on: it is one set-up
-- function, run once by XayaUI_Options (Options.lua ns.OptionsApi.LoadRuleEditor) in the .toc order. Nothing is built before then.
local function EditorFileInit()
local issecret = issecretvalue or function() return false end

local AP = {}
ns.AutoPicker = AP
if ns.OptionsApi then ns.OptionsApi.AutoPicker = AP end   -- (P4b) published for Dev Assist's QA walkthrough (QAWalks-generate.lua, V22); was Options.lua's, which now loads before this file

AP.TYPE = { cd = "Spell CD", aura = "Aura", debuff = "Debuff" }
AP.BUCKETS = { "cd", "aura", "debuff" }   -- A11: type, then A-Z
-- trigger choices per type
AP.TRIG = {
    cd = { values = { ready = "When available / when ready", max = "At max stacks" }, order = { "ready", "max" } },   -- her labels, verbatim (V16)
    aura = { values = { present = "When present", missing = "When missing" }, order = { "present", "missing" } },
}
AP.TRIG.debuff = AP.TRIG.aura
local CD_STATE = { ready = "hasCharge", max = "ready" }   -- Conditions.lua CheckCooldownState: hasCharge = a charge is up, ready = all of them
-- Every cue type the addon has (Xaya: "ALL cue types that are supported by the addon need to be included in this dropdown menu"). Two
-- are listed but never made, marked "(soonTM)" (A17): Progress bar (shelved: shelved/Bars.lua) and Custom (does nothing yet).
AP.CUES = { values = { icon = "Icon", progtex = "Progress texture", bar = "Progress bar (soonTM)", texture = "Texture", text = "Text",
                       speech = "Speech", sound = "Sound", custom = "Custom (soonTM)" },
            order = { "icon", "progtex", "bar", "texture", "text", "speech", "sound", "custom" } }
AP.NOT_MADE = { bar = true, custom = true }
AP.EXTRA = { values = { icon = "Icon", progtex = "Progress texture", texture = "Texture", text = "Text", speech = "Speech", sound = "Sound" },
             order = { "icon", "progtex", "texture", "text", "speech", "sound" } }
AP.COMBAT = { values = { any = "Any", yes = "In combat", no = "Out of combat" }, order = { "any", "yes", "no" } }
-- the four buttons per spec (and for the class), her labels verbatim (V16): the filter decides which rows the list below shows
AP.FILTERS = {
    { filter = "all",    name = "All" },
    { filter = "cd",     name = "CD Tracking" },
    { filter = "aura",   name = "Aura Tracking" },
    { filter = "debuff", name = "Target Debuff Tracking" },
}
-- "Generate All Rules for Vengeance" / "Generate CD Tracking Rules for my class" ...: target = a spec's name, or "my class"
function AP.ButtonLabel(filter, target)
    for _, f in ipairs(AP.FILTERS) do
        if f.filter == filter then
            return "Generate " .. f.name .. " Rules for " .. tostring(target)
        end
    end
end
-- which rows a filter lets through: "all" (or nil) everything; else the rows of that kind
function AP.FilterRows(rows, filter)
    if filter == nil or filter == "all" then return rows end
    local out = {}
    for _, c in ipairs(rows or {}) do if c.kind == filter then out[#out + 1] = c end end
    return out
end
-- the group each main cue goes in (the Smart Categories names: Options.lua ns.SMART_CATS; A13 OK as built)
AP.CUE_FOLDER = { icon = "Icons", progtex = "Progress Textures", texture = "Textures", text = "Text", speech = "Speech", sound = "Sounds" }
-- A10: a cue is named "<spell> (<cue type>)"
AP.CUE_NAME = { icon = "icon", progtex = "progress texture", texture = "texture", text = "text", speech = "speech", sound = "sound" }
local CUE_TYPE = { icon = "icon", progtex = "progresstex", texture = "texture", text = "text", speech = "speech", sound = "sound" }   -- ns.NewTypedCue
-- cue kinds that have a set-up in the Cue set-up column; NEEDS_PICK = must be chosen before the row can be made
AP.SETUP = { speech = true, sound = true, texture = true, progtex = true }
AP.NEEDS_PICK = { sound = true, texture = true, progtex = true }
-- her alert, verbatim
AP.ALERT = "error issue making the following rules: [%s]. Please finish configuring them to create them."
-- her switch label, verbatim
AP.SHOW_MADE_LABEL = "Hide / Show already generated rules (can potentially cause duplicates)"
-- placement (Xaya, 2026-11-06: "3 across, offset down, 3 across, return to center and offset up"; her answers "Rows centred on C" and "Re-laid
-- out together"): rows of 3 centred on the screen centre, in the order centre, below, above, further below, further above
AP.GRID_GAP = 4

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
local function ClassName() return tostring((UnitClass and UnitClass("player")) or "Class") end

-------------------------------------------------------------------------------
-- Candidates
-------------------------------------------------------------------------------
-- auras from the Cooldown Manager's catalogue for the current spec: core's reader (ClassLearn.lua ns.CdmAuraCatalogue, shared with the
-- per-spec learner, C1)
function AP.CdmAuras() return (ns.CdmAuraCatalogue and ns.CdmAuraCatalogue()) or { aura = {}, debuff = {} } end
function AP.CdmDebuffs() return AP.CdmAuras().debuff end

-- every candidate for one spec: { key, kind = "cd" | "aura" | "debuff", id, cdmID, name, icon, talent, spec }. Auras and debuffs: live
-- for the spec you are in now, learned for another spec (C1). A8 (Xaya: "depends on the button pressed -- spec or all dependent"; for another spec: show them all):
-- includeUnpicked = false leaves out the talent cooldowns the game reads as not picked, for the spec you are in only. Another spec's
-- talents are all listed (the game answers "known" for the active spec only, so they would all read as not picked).
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
        return talent and isCurrent and includeUnpicked == false and ns.ReadTalentKnown and ns.ReadTalentKnown(id) == false
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
    -- C1 (core 0.6.56): another spec's auras and debuffs, as learned while you last played it (ClassLearn.lua); the spec you are in is
    -- read live below
    if not isCurrent and data and type(data.entries) == "table" then
        for _, e in ipairs(data.entries) do
            local id = tonumber(e.id)
            if id and (e.kind == "aura" or e.kind == "debuff") then
                add({ key = (e.kind == "aura" and "au:" or "db:") .. id, kind = e.kind, id = id, cdmID = tonumber(e.cdmID), name = SpellName(id) or e.name,
                      icon = SpellIcon(id) or (e.cdmID and SpellIcon(e.cdmID)) })
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
    return out
end

local RANK = { cd = 1, aura = 2, debuff = 3 }
-- A11: by type (Spell CD, Aura, Debuff), then A-Z by name; the same name in two specs follows the game's spec order
function AP.SortRows(rows, specs)
    local specRank = {}
    for i, sid in ipairs(specs or {}) do specRank[sid] = i end
    table.sort(rows, function(a, b)
        if a.kind ~= b.kind then return RANK[a.kind] < RANK[b.kind] end
        local an, bn = tostring(a.name):lower(), tostring(b.name):lower()
        if an ~= bn then return an < bn end
        local sa, sb = specRank[a.spec] or 99, specRank[b.spec] or 99
        if sa ~= sb then return sa < sb end
        return a.id < b.id
    end)
    return rows
end

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
local function Pick(c) return Picks(c.spec)[c.key] or {} end
-- one row's choices, filled with defaults: not ticked; When available / when ready or When present (a debuff whose main cue is Speech or
-- Sound: When missing, A7); Icon; Any; no extra cues. 0.6.42 saved a debuff's "when" (on / missing): still read.
function AP.Choice(c)
    local p = Pick(c)
    local cue = AP.CUES.values[p.cue or ""] and p.cue or "icon"
    local tv = AP.TRIG[c.kind].values
    local trig = tv[p.trig or ""] and p.trig or nil
    if not trig and c.kind == "debuff" and (p.when == "missing" or p.when == "on") then trig = (p.when == "missing") and "missing" or "present" end
    if not trig and c.kind == "debuff" and (cue == "speech" or cue == "sound") then trig = "missing" end
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
-- cue set-up (su): speech = { custom = true, text = "..." }, sound = { source, value }, texture / progtex = art key
function AP.Setup(c, kind)
    local su = Pick(c).su
    return type(su) == "table" and su[kind] or nil
end
function AP.SetSetup(c, kind, value)
    local p = Picks(c.spec)
    p[c.key] = p[c.key] or {}
    local su = p[c.key].su or {}
    su[kind] = value
    p[c.key].su = next(su) and su or nil
end
-- A6: what a speech cue says by default: a cooldown its name; an aura / debuff "When missing" "<name> ended"; "When present" its name
function AP.DefaultSay(c, trig)
    if trig == nil then local _; _, trig = AP.Choice(c) end
    if c.kind ~= "cd" and trig == "missing" then return tostring(c.name) .. " ended" end
    return tostring(c.name)
end
function AP.SayText(c)
    local s = AP.Setup(c, "speech")
    if type(s) == "table" and s.custom and type(s.text) == "string" and s.text:match("%S") then return s.text end
    return AP.DefaultSay(c)
end
-- the cue kinds a row makes: its main cue, then its extra cues (the main cue is not added twice)
function AP.Kinds(c)
    local _, _, cue, _, xc = AP.Choice(c)
    if AP.NOT_MADE[cue] then return {} end
    local kinds = { cue }
    for _, k in ipairs(AP.EXTRA.order) do
        if xc and xc[k] and k ~= cue then kinds[#kinds + 1] = k end
    end
    return kinds
end
-- the cue kinds of a row that have a control in the Cue set-up column (main first)
function AP.SetupKinds(c)
    local out = {}
    for _, k in ipairs(AP.Kinds(c)) do if AP.SETUP[k] then out[#out + 1] = k end end
    return out
end
-- a row is unfinished while a sound or a picture it needs is not chosen
function AP.Unfinished(c)
    for _, k in ipairs(AP.Kinds(c)) do
        if AP.NEEDS_PICK[k] then
            local v = AP.Setup(c, k)
            if k == "sound" then
                if not (type(v) == "table" and type(v.value) == "string" and v.value ~= "") then return true end
            elseif not (type(v) == "string" and v ~= "" and v ~= "0") then return true end
        end
    end
    return false
end
-- every row of a list ticked?
function AP.AllTicked(rows)
    if not rows or #rows == 0 then return false end
    for _, c in ipairs(rows) do if not AP.Choice(c) then return false end end
    return true
end
function AP.TickAll(rows, on)
    for _, c in ipairs(rows or {}) do AP.SetChoice(c, "on", on and true or nil) end
end
function AP.BucketRows(rows, kind)
    local out = {}
    for _, c in ipairs(rows or {}) do if c.kind == kind then out[#out + 1] = c end end
    return out
end

-------------------------------------------------------------------------------
-- Groups and the rules already made
-------------------------------------------------------------------------------
local function FindTop(name)
    for _, f in ipairs(ns.folders or {}) do if not f.parent and f.name == name then return f end end
end
local function FindSub(parent, name)
    if not parent then return nil end
    for _, f in ipairs(ns.folders or {}) do if f.parent == parent.id and f.name == name then return f end end
end
local function TopFolder(name) return FindTop(name) or ns.NewFolder(name) end
local function SubFolder(parent, name) return FindSub(parent, name) or ns.NewFolder(name, parent.id) end
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
local function InGroups(folder)
    local inGroup = {}
    local function mark(fid, guard)
        if not fid or guard > 32 or inGroup[fid] then return end
        inGroup[fid] = true
        for _, f in ipairs(ns.folders or {}) do if f.parent == fid then mark(f.id, guard + 1) end end
    end
    if folder then mark(folder.id, 0) end
    return inGroup
end
-- the trigger keys of the rules already in a group (and its nested groups), and how many shown cues it holds
local function Have(folder)
    local inGroup = InGroups(folder)
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
-- the row's trigger key, as RuleKey reads it from a rule
function AP.RowKey(c)
    local _, trig = AP.Choice(c)
    return c.kind .. ":" .. c.id .. ":" .. tostring(EngineState(c.kind, trig))
end
-- a rule with this row's trigger already in <Class> > <Spec> (any cue-type group under it)?
function AP.Generated(c, cache)
    cache = cache or {}
    if cache[c.spec] == nil then
        local specF = FindSub(FindTop(ClassName()), SpecName(c.spec))
        cache[c.spec] = specF and (Have(specF)) or false
    end
    return cache[c.spec] and cache[c.spec][AP.RowKey(c)] and true or false
end

-------------------------------------------------------------------------------
-- The list shown in the pane (this session only)
-------------------------------------------------------------------------------
-- the rows of a list: one spec, or "all" = every spec of your class in the game's order. Rows whose rule already exists are left out
-- unless "Hide / Show already generated rules" is on; then they are listed unticked (Xaya: "on repopulated without selecting them").
function AP.BuildRows(spec, filter)
    local inc = not (ns.AutoCfg and ns.AutoCfg().talents == false)
    local rows, specs = {}, {}
    if spec ~= "all" then
        rows, specs = AP.Candidates(spec, inc), { spec }
    else
        local seen = {}
        for i = 1, (GetNumSpecializations and GetNumSpecializations() or 0) do
            local sid = GetSpecializationInfo(i)
            if sid and not seen[sid] then
                seen[sid] = true
                specs[#specs + 1] = sid
                for _, c in ipairs(AP.Candidates(sid, inc)) do rows[#rows + 1] = c end
            end
        end
    end
    local out, cache = {}, {}
    for _, c in ipairs(AP.FilterRows(rows, filter)) do
        if AP.Generated(c, cache) then
            if AP.showMade then
                c.generated = true
                AP.SetChoice(c, "on", nil)
                out[#out + 1] = c
            end
        else
            out[#out + 1] = c
        end
    end
    return AP.SortRows(out, specs), specs
end

-- read once when a button is pressed (or Reload list), not on every redraw
function AP.Load(spec, filter)
    filter = filter or "all"
    local rows, specs = AP.BuildRows(spec, filter)
    AP.view = { spec = spec, filter = filter, rows = rows, specs = specs }
    AP.msg = nil
    return AP.view
end
function AP.Close() AP.view, AP.msg = nil, nil end

-------------------------------------------------------------------------------
-- Popups (the small typing window for Speech, and her alert)
-------------------------------------------------------------------------------
-- every popup goes through here (the tests read AP.lastPopup); the settings window is FULLSCREEN_DIALOG, so the popup sits above it
function AP.ShowPopup(which, text, data)
    AP.lastPopup = { which = which, text = text, data = data }
    if not StaticPopup_Show then return end
    local dlg = StaticPopup_Show(which, text, nil, data)
    if dlg and dlg.SetFrameStrata then dlg:SetFrameStrata("TOOLTIP") end
    return dlg
end
local function PopupEditBox(self) return self.editBox or (self.GetEditBox and self:GetEditBox()) end
if StaticPopupDialogs then
    StaticPopupDialogs["XAYAUI_AP_SAY"] = {
        text = "%s", button1 = ACCEPT, button2 = CANCEL, hasEditBox = true, maxLetters = 120, timeout = 0, whileDead = true,
        hideOnEscape = true, preferredIndex = 3,
        OnShow = function(self, data)
            local eb = PopupEditBox(self)
            if eb then eb:SetText((data and data.current) or ""); eb:HighlightText() end
        end,
        OnAccept = function(self, data)
            local eb = PopupEditBox(self)
            if data and data.cb then data.cb(eb and eb:GetText() or "") end
        end,
        EditBoxOnEnterPressed = function(eb)
            local p = eb:GetParent()
            local t, data = eb:GetText(), p.data
            p:Hide()
            if data and data.cb then data.cb(t or "") end
        end,
        EditBoxOnEscapePressed = function(eb) eb:GetParent():Hide() end,
    }
    StaticPopupDialogs["XAYAUI_AP_ALERT"] = {
        text = "%s", button1 = OKAY, timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    }
end
-- Speech "Customize" ticked: the typing window, filled with what the cue says now. OK with text = customized; Cancel or an empty box
-- leaves it as it was.
function AP.AskSay(c, done)
    AP.ShowPopup("XAYAUI_AP_SAY", "Speech text for " .. tostring(c.name), { current = AP.SayText(c), cb = function(t)
        t = tostring(t or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if t ~= "" then AP.SetSetup(c, "speech", { custom = true, text = t }) end
        if done then done() end
    end })
end

-------------------------------------------------------------------------------
-- Making the rules
-------------------------------------------------------------------------------
-- one cue of a rule, set up as "+ New rule" sets up that type (Options.lua ns.NewTypedCue), then the row's set-up and her name
local function AddCue(r, kind, c)
    if not ns.NewTypedCue then return nil end
    local cue = ns.NewTypedCue(r, CUE_TYPE[kind] or "icon")
    if not cue then return nil end
    cue.cueName = tostring(c.name) .. " (" .. (AP.CUE_NAME[kind] or kind) .. ")"
    cue.name = cue.cueName
    if kind == "speech" then
        cue.sound.source, cue.sound.value = "tts", AP.SayText(c)
    elseif kind == "sound" then
        local s = AP.Setup(c, "sound")
        if type(s) == "table" then cue.sound.source, cue.sound.value = s.source, s.value end
    elseif kind == "texture" or kind == "progtex" then
        local k = AP.Setup(c, kind)
        if ns.ApplyArtPick then ns.ApplyArtPick(cue.visual, k) else cue.visual.kind, cue.visual.tex = "file", k end
    end
    return cue
end
-- her placement: the n-th cue (0-based): rows of 3, each centred on the screen centre (the 2nd cue of a row sits on it); row 1 at the
-- centre, row 2 below, row 3 above, row 4 further below, row 5 further above, ...
function AP.GridPos(n, stride)
    local k, col = math.floor(n / 3), n % 3
    local y = 0
    if k % 2 == 1 then y = -((k + 1) / 2) * stride elseif k > 0 then y = (k / 2) * stride end
    return (col - 1) * stride, y
end
-- the cues this table placed and nobody has moved since (their position is still the one it gave them); "This applies only to rules
-- auto populated that have not yet been manually moved"
function AP.UnmovedPlaced()
    local out = {}
    for _, r in ipairs(ns.rules or {}) do
        local v = r.isCue and r.visual
        local a = v and v.enabled and v.autoPos
        if type(a) == "table" and a.x == v.x and a.y == v.y then out[#out + 1] = r end
    end
    return out
end

-- Makes the ticked rows of a list. Returns made, skipped (already there), notMade (soonTM), message, unfinished names.
function AP.Make(view)
    view = view or AP.view
    if not view then return 0, 0, 0, "Press an Auto-populate button first.", {} end
    local made, skipped, notMade = 0, 0, 0
    local todo, unfinished = {}, {}
    for _, c in ipairs(view.rows or {}) do
        local on, trig, cue, combat = AP.Choice(c)
        if on then
            if AP.NOT_MADE[cue] then notMade = notMade + 1
            elseif AP.Unfinished(c) then unfinished[#unfinished + 1] = c
            else todo[#todo + 1] = { c = c, trig = trig, cue = cue, combat = combat } end
        end
    end
    if #todo == 0 and #unfinished == 0 and notMade == 0 then return 0, 0, 0, "Nothing is ticked: tick the rules you want, then press Populate.", {} end
    local className = ClassName()
    local classF
    local perSpec, specOrder = {}, {}
    local madeRows, newShown = {}, {}
    local earlier = AP.UnmovedPlaced()   -- read before anything new is made
    for _, t in ipairs(todo) do
        local c, trig, cue = t.c, t.trig, t.cue
        classF = classF or TopFolder(className)
        local ps = perSpec[c.spec]
        if not ps then
            ps = { folder = SubFolder(classF, SpecName(c.spec)), made = 0, cueF = {} }
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
        if cf.keys[key] and not AP.showMade then   -- shown on purpose (Hide / Show already generated rules): a duplicate is made
            skipped = skipped + 1
        else
            local r = ns.NewRule()
            r.name = c.name   -- A16: the icon is in the table only, never in the rule's name
            r.folder = cf.folder.id
            r.load = r.load or {}
            r.load.specs = { [tostring(c.spec)] = true }
            if t.combat == "yes" or t.combat == "no" then r.load.combat = t.combat end
            r.autoKind, r.autoSrc = c.kind, "auto-populate table"
            r.sound.enabled, r.visual.enabled = false, false   -- the rule's cues carry what you see / hear
            r.talentMode = "none"
            if c.kind == "cd" then
                r.useCooldown, r.spellID, r.cdState, r.buffState = true, c.id, state, "none"
                if c.talent then r.talents, r.talentMode = { { id = c.id, state = "known" } }, "all" end   -- loads only while the talent is picked
            elseif c.kind == "aura" then
                r.useBuff, r.buffID, r.buffState, r.cdState = true, c.id, state, "none"
            else
                r.cdState, r.buffState = "none", "none"
                r.extra = { list = { { type = "targetDebuff", spellID = c.id, cdmID = c.cdmID, unit = "target", state = state, cdmAbsent = "yes" } } }
            end
            ns.rules[#ns.rules + 1] = r
            for _, k in ipairs(AP.Kinds(c)) do
                local cueR = AddCue(r, k, c)
                if cueR and cueR.visual and cueR.visual.enabled then newShown[#newShown + 1] = cueR end
            end
            cf.keys[key] = true
            made = made + 1
            ps.made = ps.made + 1
            madeRows[c] = true
        end
    end
    -- placement: the cues placed earlier and not moved since, then the new ones, laid out again together in one pattern ("Re-laid out
    -- together"); a cue she moved keeps its place and is left out. The step is the largest of them + the gap.
    if #newShown > 0 then
        local all = {}
        for _, cue in ipairs(earlier) do all[#all + 1] = cue end
        for _, cue in ipairs(newShown) do all[#all + 1] = cue end
        local size = 0
        for _, cue in ipairs(all) do size = math.max(size, tonumber(cue.visual.w) or 0, tonumber(cue.visual.h) or 0) end
        local stride = size + AP.GRID_GAP
        for i, cue in ipairs(all) do
            local x, y = AP.GridPos(i - 1, stride)
            cue.visual.x, cue.visual.y = x, y
            cue.visual.autoPos = { x = x, y = y }
            if ns.RefreshVisual then pcall(ns.RefreshVisual, cue) end
        end
    end
    -- A14: made rows leave the table (and are not ticked if they are shown again)
    if made > 0 then
        local keep = {}
        for _, c in ipairs(view.rows) do
            if madeRows[c] then AP.SetChoice(c, "on", nil) else keep[#keep + 1] = c end
        end
        view.rows = keep
        if ns.MarkDirty then ns.MarkDirty() end
        if ns.Fire then pcall(ns.Fire, "CONFIG_CHANGED") end
    end
    local where = {}
    for _, sid in ipairs(specOrder) do
        if perSpec[sid].made > 0 then where[#where + 1] = ("%s > %s (%d)"):format(className, SpecName(sid), perSpec[sid].made) end
    end
    local msg = ("Made %d rule(s)%s."):format(made, (#where > 0) and (" in " .. table.concat(where, ", ")) or "")
    if skipped > 0 then msg = msg .. (" %d already there with the same trigger were skipped."):format(skipped) end
    if notMade > 0 then msg = msg .. (" %d ticked with \"Progress bar\" or \"Custom\" were not made: those are (soonTM)."):format(notMade) end
    local names = {}
    for _, c in ipairs(unfinished) do names[#names + 1] = tostring(c.name) end
    if #names > 0 then AP.ShowPopup("XAYAUI_AP_ALERT", AP.ALERT:format(table.concat(names, ", "))) end
    return made, skipped, notMade, msg, names
end

-------------------------------------------------------------------------------
-- The table on the Class/Spec Rule Creator page (Options.lua BuildClassCreator merges these args)
-------------------------------------------------------------------------------
local CELL = { xuiCell = true }
local CELL_DD = { xuiCell = true, xuiTextLeft = true }
local CELL_ART = { xuiCell = true, xuiTextLeft = true, xuiTexPick = true }
local function Gold(s) return "|cffffd100" .. s .. "|r" end
local function Plain(s) return (tostring(s or ""):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
AP.HEADS = { nm = "Name", sp = "Spec", ty = "Type", tr = "Trigger", cu = "Cue type", su = "Cue set-up", cb = "Combat load", xc = "Extra cues" }
local NOT_PICKED = "0"
local function SoundValues()
    local list, values, sorting = {}, { [NOT_PICKED] = "" }, { NOT_PICKED }
    if ns.SoundChoices then
        local l, v, s = ns.SoundChoices()
        list, values, sorting = l or {}, {}, {}
        for k, lab in pairs(v or {}) do values[k] = lab end
        for i, k in ipairs(s or {}) do sorting[i] = k end
    end
    values[NOT_PICKED] = "|cffff5555Choose a sound|r"
    return list, values, sorting
end
local function ArtValues()
    local values, sorting = {}, { NOT_PICKED }
    if ns.TexChoices then
        local v, s = ns.TexChoices()
        for k, lab in pairs(v or {}) do values[k] = lab end
        sorting = {}
        for i, k in ipairs(s or {}) do sorting[i] = k end
    end
    values[NOT_PICKED] = "|cffff5555Choose a picture|r"
    return values, sorting
end
AP.SoundValues, AP.ArtValues = SoundValues, ArtValues

-- A12 (Xaya: "fit contents"): each column's share of the row follows its longest text (header or value; character count, the font is not
-- measured), plus room for a dropdown's button or a tick box. Shares add up to 1, so a table row is one line (Skin.lua arg.xuiCell).
local PAD = { on = 0, nm = 1, sp = 1, ty = 1, tr = 5, cu = 5, su = 5, cb = 5, xc = 5 }
local CAP = 32
function AP.Widths(rows, cols)
    local len = {}
    local function fit(k, s) local n = math.min(CAP, #Plain(s)); if n > (len[k] or 0) then len[k] = n end end
    for _, k in ipairs(cols) do if AP.HEADS[k] then fit(k, AP.HEADS[k]) end end
    for _, b in ipairs(AP.BUCKETS) do fit("nm", AP.TYPE[b]) end
    local sv = select(2, SoundValues())
    local av = ArtValues()
    local suN = 1
    for _, c in ipairs(rows or {}) do
        fit("nm", "xxx " .. tostring(c.name))   -- the icon takes about 3 characters
        fit("sp", SpecName(c.spec)); fit("ty", AP.TYPE[c.kind])
        local _, trig, cue = AP.Choice(c)
        fit("tr", AP.TRIG[c.kind].values[trig]); fit("cu", AP.CUES.values[cue])
        fit("cb", "Out of combat"); fit("xc", "Progress texture")
        local sk = AP.SetupKinds(c)
        if #sk > suN then suN = #sk end
        for _, k in ipairs(sk) do
            if k == "speech" then fit("su", "xx " .. ((AP.Setup(c, "speech") or {}).custom and AP.SayText(c) or "Customize"))
            elseif k == "sound" then local s = AP.Setup(c, "sound"); fit("su", (type(s) == "table" and ns.SoundLabel and ns.SoundLabel(s)) or sv[NOT_PICKED])
            else local a = AP.Setup(c, k); fit("su", (a and av[a]) or av[NOT_PICKED]) end
        end
    end
    local w, sum = {}, 0
    for _, k in ipairs(cols) do
        local n = (k == "on") and 4 or ((len[k] or 4) + PAD[k])
        if k == "su" then n = n * suN end   -- extra cues' controls sit side by side in the cell
        w[k] = n; sum = sum + n
    end
    for _, k in ipairs(cols) do w[k] = w[k] / sum end
    if w.on < 0.06 then   -- the tick box column stays wider than the row's gutters, so the next row starts on its own line
        local short = 0.06 - w.on
        w.on = 0.06
        for _, k in ipairs(cols) do if k ~= "on" then w[k] = w[k] * (1 - 0.06) / (1 - 0.06 + short) end end
    end
    return w
end
function AP.Cols(view, adv)
    local cols = { "on", "nm" }
    if view and view.spec == "all" then cols[#cols + 1] = "sp" end   -- A5: the Spec column, in the all-specs list
    for _, k in ipairs({ "ty", "tr", "cu", "su", "cb" }) do cols[#cols + 1] = k end
    if adv then cols[#cols + 1] = "xc" end
    return cols
end
function AP.Title(view)
    if not view then return "" end
    if view.spec == "all" then return "Auto-populate: " .. ClassName() .. " (all specs)" end
    return "Auto-populate: " .. SpecName(view.spec)
end
AP.HELP = "Tick the rules you want and set each one up. Rows marked in the Cue set-up column need a choice before they can be made.\n"
    .. "Populate makes the ticked rows into rules in Class > Spec > cue type; made rows leave the table."

-- what the table says when the button pressed lists nothing. Auras and debuffs are read for the spec you are in now only, so for another
-- spec's Aura / Target Debuff button the useful hint is to switch to it
function AP.NoneText(view)
    local current = ns.CurrentSpecID and ns.CurrentSpecID()
    local f = view and view.filter
    if (f == "aura" or f == "debuff") and view.spec ~= "all" and view.spec ~= current then
        return "Auras and target debuffs are read from your Cooldown Manager for the spec you are in now. Switch to " .. SpecName(view.spec) .. ", then press the button again."
    end
    if f == "cd" then
        return "Nothing to list yet: play this spec once (its cooldown list is read from your spellbook)."
    end
    if f == "aura" or f == "debuff" then
        return "Nothing to list yet: add your auras and debuffs to the Cooldown Manager."
    end
    return "Nothing to list yet: play this spec once (its cooldown list is read from your spellbook), and add your auras and debuffs to the Cooldown Manager."
end

-- notify: a change that adds or removes controls (Advanced, Populate, a cue type, a set-up choice). keep: a change that shows only in
-- controls already there (a tick, a trigger); the redraw that follows reuses the options tree (Options.lua Tree.Keep).
function AP.Args(notify, keep)
    notify = notify or function() end
    keep = keep or function() end
    local args = {}
    local view = AP.view
    if not view then return args end
    local rows = view.rows or {}
    local adv = AP.adv and true or false
    local cols = AP.Cols(view, adv)
    local W = AP.Widths(rows, cols)
    local T = {}
    -- A3: the frame's title is the list's name
    args.apTable = { type = "group", inline = true, order = 0.7, name = AP.Title(view), args = T }
    local ord = 0
    local function O() ord = ord + 1; return ord end
    T.help = { type = "description", order = O(), width = "full", fontSize = "medium", name = AP.HELP,
        arg = { xuiKeep = true } }   -- shown as text, as she accepted (not folded into an info icon: Options.lua info pass)
    T.showMade = { type = "toggle", order = O(), width = "full", name = AP.SHOW_MADE_LABEL,
        desc = "Lists rows that already have a rule again, unticked; Populate makes a ticked one anyway. Off by default.",
        get = function() return AP.showMade and true or false end,
        set = function(_, v) AP.showMade = v and true or nil; AP.Load(view.spec, view.filter); notify() end }
    if #rows == 0 then
        T.none = { type = "description", order = O(), width = "full", fontSize = "medium", name = AP.NoneText(view),
            arg = { xuiKeep = true } }   -- shown as text, not folded into an info icon: it says what to do next
    else
        -- "Select all" (Xaya, 2026-11-06: "missing select all tick box option to select all"): one tick box at the top of the list; it
        -- ticks, then unticks, the rows shown (so a filtered list selects only its own rows)
        T.selAll = { type = "toggle", order = O(), width = "full", name = "Select all",
            desc = "Tick every row listed below. Click again to untick them all.",
            get = function() return AP.AllTicked(rows) end,
            set = function(_, v) AP.TickAll(rows, v); keep() end }
        -- header row: the tick box ticks every row; pressed again it unticks them all
        T.hOn = { type = "toggle", order = O(), width = "relative", relWidth = W.on, name = "", arg = CELL,
            desc = "Tick every row. Click again to untick them all.",
            get = function() return AP.AllTicked(rows) end,
            set = function(_, v) AP.TickAll(rows, v); keep() end }
        for _, k in ipairs(cols) do
            if k ~= "on" then
                T["h" .. k] = { type = "description", order = O(), width = "relative", relWidth = W[k], fontSize = "medium",
                    name = Gold(AP.HEADS[k]), arg = CELL }
            end
        end
        local sv, svv, svs = SoundValues()
        local avv, avs = ArtValues()
        local i = 0
        for _, b in ipairs(AP.BUCKETS) do
            local brows = AP.BucketRows(rows, b)
            if #brows > 0 then
                -- A11: the bucket's header, with its own tick box (ticks / unticks the whole bucket)
                T["b" .. b .. "On"] = { type = "toggle", order = O(), width = "relative", relWidth = W.on, name = "", arg = CELL,
                    desc = "Tick every " .. AP.TYPE[b] .. " row. Click again to untick them all.",
                    get = function() return AP.AllTicked(brows) end,
                    set = function(_, v) AP.TickAll(brows, v); keep() end }
                T["b" .. b .. "Nm"] = { type = "description", order = O(), width = "relative", relWidth = 1 - W.on, fontSize = "large",
                    name = Gold(AP.TYPE[b]), arg = CELL }
                for _, c in ipairs(brows) do
                    i = i + 1
                    local id = "r" .. i
                    T[id .. "on"] = { type = "toggle", order = O(), width = "relative", relWidth = W.on, name = "", arg = CELL,
                        desc = AP.TYPE[c.kind] .. ", " .. ((c.kind == "cd") and "spell " or "aura ") .. c.id
                            .. ((c.cdmID and (" (Cooldown Manager: " .. c.cdmID .. ")")) or "")
                            .. (c.talent and ". A talent: the rule loads only while you have it." or "")
                            .. (c.generated and ". Already made: Populate makes it again (a duplicate)." or ""),
                        get = function() local on = AP.Choice(c); return on end,
                        set = function(_, v) AP.SetChoice(c, "on", v and true or nil); keep() end }
                    -- A16: the spell's icon beside its name, in the table only
                    T[id .. "nm"] = { type = "description", order = O(), width = "relative", relWidth = W.nm, fontSize = "medium", arg = CELL,
                        name = (c.icon and ("|T" .. tostring(c.icon) .. ":16:16|t ") or "") .. tostring(c.name) }
                    if view.spec == "all" then
                        T[id .. "sp"] = { type = "description", order = O(), width = "relative", relWidth = W.sp, fontSize = "medium", arg = CELL,
                            name = SpecName(c.spec) }
                    end
                    T[id .. "ty"] = { type = "description", order = O(), width = "relative", relWidth = W.ty, fontSize = "medium", arg = CELL,
                        name = "|cffaaaaaa" .. AP.TYPE[c.kind] .. "|r" }
                    local tdef = AP.TRIG[c.kind]
                    T[id .. "tr"] = { type = "select", order = O(), width = "relative", relWidth = W.tr, name = "", arg = CELL_DD,
                        values = tdef.values, sorting = tdef.order,
                        desc = (c.kind == "cd") and "When available / when ready: a charge is up. At max stacks: every charge is back (the same for a spell without charges)."
                            or ("When present: the rule is true while the " .. ((c.kind == "aura") and "aura is on you." or "debuff is on your target.") .. " When missing: while it is not."),
                        get = function() local _, trig = AP.Choice(c); return trig end,
                        set = function(_, v) AP.SetChoice(c, "trig", v); notify() end }   -- notify: the default speech text follows it
                    T[id .. "cu"] = { type = "select", order = O(), width = "relative", relWidth = W.cu, name = "", arg = CELL_DD,
                        values = AP.CUES.values, sorting = AP.CUES.order,
                        desc = "Sets the rule's main cue and the group it goes in. Progress bar and Custom are not ready yet; a row ticked with one is not made.",
                        get = function() local _, _, cue = AP.Choice(c); return cue end,
                        set = function(_, v) AP.SetChoice(c, "cue", v); notify() end }
                    -- the Cue set-up cell: one control per cue that has a set-up (main cue first, then extra cues)
                    local sk = AP.SetupKinds(c)
                    if #sk == 0 then
                        T[id .. "su"] = { type = "description", order = O(), width = "relative", relWidth = W.su, fontSize = "medium", arg = CELL, name = "" }
                    end
                    for j, k in ipairs(sk) do
                        local key, rw = id .. "su" .. j, W.su / #sk
                        local function A(base)   -- the 2nd+ control shares the cell: no gutter before it (Skin.lua arg.xuiSubCell)
                            if j == 1 then return base end
                            local t = {}
                            for kk, vv in pairs(base) do t[kk] = vv end
                            t.xuiSubCell = true
                            return t
                        end
                        if k == "speech" then
                            T[key] = { type = "toggle", order = O(), width = "relative", relWidth = rw, arg = A(CELL),
                                name = function()
                                    local s = AP.Setup(c, "speech")
                                    if type(s) == "table" and s.custom then return AP.SayText(c) end
                                    return "Customize"
                                end,
                                desc = function() return "What the Speech cue says. Now: \"" .. AP.SayText(c) .. "\". Untick Customize to go back to \"" .. AP.DefaultSay(c) .. "\"." end,
                                get = function() local s = AP.Setup(c, "speech"); return type(s) == "table" and s.custom and true or false end,
                                set = function(_, v)
                                    if v then AP.AskSay(c, notify) else AP.SetSetup(c, "speech", nil); notify() end
                                end }
                        elseif k == "sound" then
                            T[key] = { type = "select", order = O(), width = "relative", relWidth = rw, name = "", arg = A(CELL_DD),
                                values = svv, sorting = svs,
                                desc = "The Sound cue's sound. It must be chosen before the row can be made.",
                                get = function()
                                    local s = AP.Setup(c, "sound")
                                    if type(s) == "table" then
                                        for idx, it in ipairs(sv) do if it.source == s.source and it.value == s.value then return tostring(idx) end end
                                    end
                                    return NOT_PICKED
                                end,
                                set = function(_, v)
                                    local it = sv[tonumber(v) or 0]
                                    AP.SetSetup(c, "sound", (v ~= NOT_PICKED and it) and { source = it.source, value = it.value } or nil)
                                    notify()
                                end }
                        else
                            T[key] = { type = "select", order = O(), width = "relative", relWidth = rw, name = "", arg = A(CELL_ART),
                                values = avv, sorting = avs,
                                desc = "The " .. AP.CUES.values[k] .. " cue's picture. It must be chosen before the row can be made.",
                                get = function() local a = AP.Setup(c, k); return (type(a) == "string" and avv[a]) and a or NOT_PICKED end,
                                set = function(_, v) AP.SetSetup(c, k, (v ~= NOT_PICKED) and v or nil); notify() end }
                        end
                    end
                    T[id .. "cb"] = { type = "select", order = O(), width = "relative", relWidth = W.cb, name = "", arg = CELL_DD,
                        values = AP.COMBAT.values, sorting = AP.COMBAT.order,
                        desc = "When the rule loads: any time, only in combat, or only out of combat.",
                        get = function() local _, _, _, cb = AP.Choice(c); return cb end,
                        set = function(_, v) AP.SetChoice(c, "combat", v); keep() end }
                    if adv then
                        T[id .. "xc"] = { type = "multiselect", dialogControl = "Dropdown", order = O(), width = "relative", relWidth = W.xc, name = "", arg = CELL_DD,
                            values = AP.EXTRA.values, sorting = AP.EXTRA.order,
                            desc = "More cues for this rule beside its main one (the main cue is not added twice).",
                            get = function(_, k) local _, _, _, _, xc = AP.Choice(c); return (xc and xc[k]) and true or false end,
                            set = function(_, k, v) AP.SetExtra(c, k, v); notify() end }
                    end
                end
            end
        end
    end
    -- the buttons, in one row at the bottom: Advanced | Populate | Reload list | Close
    T.adv = { type = "execute", order = O(), name = "Advanced", arg = { xuiCenter = true },
        desc = "Shows or hides the Extra cues column: more cues for a rule beside its main one.",
        func = function() AP.adv = not AP.adv; notify() end }
    T.make = { type = "execute", order = O(), name = "Populate", arg = { xuiCenter = true },
        func = function()
            local _, _, _, m = AP.Make(view)
            AP.msg = m
            if ns.Print then ns.Print("auto-populate: " .. m) end
            notify()
        end }
    T.reload = { type = "execute", order = O(), name = "Reload list", arg = { xuiCenter = true },
        desc = "Reads the list again from the game (your choices are kept).",
        func = function() AP.Load(view.spec, view.filter); notify() end }
    T.close = { type = "execute", order = O(), name = "Close", arg = { xuiCenter = true },
        desc = "Hides the table (your choices are kept).",
        func = function() AP.Close(); notify() end }
    T.msg = { type = "description", order = O(), width = "full", fontSize = "medium",
        hidden = function() return not AP.msg end, name = function() return AP.msg or "" end }
    return args
end
end
ns.RuleEditorFiles = ns.RuleEditorFiles or {}
ns.RuleEditorFiles[#ns.RuleEditorFiles + 1] = EditorFileInit
