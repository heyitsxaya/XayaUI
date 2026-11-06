#!/usr/bin/env python3
"""Offline test (XayaUI_Options 0.6.44-0.6.45): auto-populate as a table (AutoPicker.lua, Skin.lua table cells). Xaya, 2026-11-05:
"Clicking auto-populate should pre-load into a frame below all rules that will load in a table view. Columns will be (Checkbox - clicking
the header row will select all; clicking again will deselect all) | name | type (spell cd, aura, debuff) | trigger (when available /
when ready (for CD); at max stacks (for CD); when present (aura / debuff); when missing (aura / debuff) | cue type | combat load (any, in
combat, out of combat) ... By default, rules will be populated into the following groups: class >> specialization >> cue type ... >> name.
Users can also click 'advanced' button at the bottom to further add customization". Her answers: in the Class/Spec Rule Creator pane;
Advanced = extra cues; the list is the spec of the button pressed, the class button lists every spec.
Checks what the player gets: a spec button loads the list and makes nothing; the rows (cooldowns, auras on you, target debuffs; other
specs: cooldowns); the columns and their choices; the header tick box ticks every row, then unticks them; paging; Advanced adds an
Extra cues column; Make turns only the ticked rows into rules with the chosen trigger, cue(s) and combat load in Class > Spec > cue type,
named after the spell, never twice; and the skin lays a table row out on one line that fills the pane, the next row on its own line.
Run: python3 tests/auto_picker_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok) R[#R + 1] = { name, ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 3)
ns = rawget(_G, "XayaUI_NS")
local AP = ns and ns.AutoPicker
check("the auto-populate table is loaded with the settings window", AP ~= nil and AP.Load ~= nil and AP.Make ~= nil and AP.Args ~= nil)
if not (AP and AP.Load) then return R end
local SPEC = ns.CurrentSpecID()
check("stand-in spec is Vengeance (581)", SPEC == 581)
-- the class has two specs here (the stand-in lists 577 twice)
GetNumSpecializations = function() return 2 end
GetSpecializationInfo = function(i) if i == 1 then return 577, "Havoc", "", 1247264, "DAMAGER" end return 581, "Vengeance", "", 1247263, "TANK" end
GetSpecializationInfoByID = function(id) local n = ({ [577] = "Havoc", [581] = "Vengeance" })[id] or ("Spec " .. tostring(id)); return id, n, "", 136243, "DAMAGER", "DEMONHUNTER", "Demon Hunter" end
ns.rules, ns.folders = {}, {}
ns.CLASS_AURA_DATA = {
  [581] = { entries = { { kind = "cd", id = 187827, name = "Metamorphosis" }, { kind = "cd", id = 204021, name = "Fiery Brand", talent = true },
                        { kind = "cd", id = 6789, name = "Third" } } },
  [577] = { entries = { { kind = "cd", id = 195072, name = "Fel Rush" }, { kind = "cd", id = 258920, name = "Talent cd", talent = true } } } }
-- the Cooldown Manager's catalogue for the spec you are in: 11 / 13 debuffs on the target, 12 / 15 auras on you, 14 no aura
local INFO = {
  [11] = { cooldownID = 11, spellID = 204021, linkedSpellIDs = { 207771 }, hasAura = true, selfAura = false, category = 0 },
  [12] = { cooldownID = 12, spellID = 187827, linkedSpellIDs = {}, hasAura = true, selfAura = true, category = 2 },
  [13] = { cooldownID = 13, spellID = 204596, linkedSpellIDs = {}, hasAura = true, selfAura = false, category = 3 },
  [14] = { cooldownID = 14, spellID = 6789, linkedSpellIDs = {}, hasAura = false, selfAura = false, category = 0 },
  [15] = { cooldownID = 15, spellID = 203720, linkedSpellIDs = { 203819 }, hasAura = true, selfAura = true, category = 2 } }
C_CooldownViewer = {
  GetCooldownViewerCategorySet = function(cat) if cat == 0 then return { 11, 14 } elseif cat == 2 then return { 12, 15 } elseif cat == 3 then return { 13, 11 } end return {} end,
  GetCooldownViewerCooldownInfo = function(id) return INFO[id] end,
  IsCooldownViewerAvailable = function() return true, "" end }
IsPlayerSpell = function(id) return id ~= 204021 and id ~= 258920 end   -- two talents not picked

-- the list for one spec
local rows = AP.BuildRows(SPEC)
local by = {}
for _, c in ipairs(rows) do by[c.key] = c end
check("rows: the spec's three cooldowns", by["cd:187827"] and by["cd:204021"] and by["cd:6789"] and by["cd:204021"].talent == true)
check("rows: auras on you from the Cooldown Manager (an aura linked to its ability: aura 203819, Cooldown Manager 203720)",
  by["au:187827"] and by["au:187827"].kind == "aura" and by["au:203819"] and by["au:203819"].cdmID == 203720)
check("rows: target debuffs (207771 via its ability 204021; 204596 on its own)", by["db:207771"] and by["db:207771"].cdmID == 204021 and by["db:204596"] and by["db:204596"].kind == "debuff")
check("rows: 7 in all, ordered Spell CD, Aura, Debuff, each once", #rows == 7 and rows[1].kind == "cd" and rows[3].kind == "cd" and rows[4].kind == "aura"
  and rows[5].kind == "aura" and rows[6].kind == "debuff" and rows[7].kind == "debuff")
local other = AP.BuildRows(577)
check("another spec lists its cooldowns only (the Cooldown Manager answers for the spec you are in)", #other == 2 and other[1].kind == "cd" and other[2].kind == "cd")
local all = AP.BuildRows("all")
check("all specs: every spec's rows, spec by spec", #all == 9 and all[1].spec == 577 and all[3].spec == 581)
ns.AutoCfg().talents = false
local noTal = AP.BuildRows(SPEC)
local noTalOther = AP.BuildRows(577)
check("'Include talents I have not picked' off: an unpicked talent of the spec you are in is left out, another spec's is kept",
  #noTal == 6 and (function() for _, c in ipairs(noTal) do if c.id == 204021 and c.kind == "cd" then return false end end return true end)() and #noTalOther == 2)
ns.AutoCfg().talents = true

-- defaults
local on, trig, cue, combat, xc = AP.Choice(by["cd:187827"])
check("defaults: not ticked, cooldown 'When ready', Icon, combat Any, no extra cues", on == false and trig == "ready" and cue == "icon" and combat == "any" and xc == nil)
check("defaults: an aura and a debuff are 'When present'", select(2, AP.Choice(by["au:187827"])) == "present" and select(2, AP.Choice(by["db:207771"])) == "present")
AP.SetChoice(by["db:204596"], "cue", "speech")
check("defaults: a debuff with a speech cue is 'When missing' (a reminder)", select(2, AP.Choice(by["db:204596"])) == "missing")
AP.Picks(SPEC)["db:207771"] = { when = "missing" }
check("a debuff's 'missing' saved by the 0.6.42 picker is still read", select(2, AP.Choice(by["db:207771"])) == "missing")
AP.Picks(SPEC)["db:207771"] = nil

-- the page: the spec buttons load the list, nothing is made
local function creator()
  local built = ns.BuildOptionsTable()
  local function find(t, depth)
    if type(t) ~= "table" or depth > 30 then return nil end
    if t.type == "group" and t.name == "Class/Spec Rule Creator" then return t end
    for _, v in pairs(t.args or {}) do local f = find(v, depth + 1); if f then return f end end
  end
  local G = find(built, 0)
  return G and G.args or {}
end
local a = creator()
check("no table before a button is pressed", a.apTable == nil and a.apSpec1 ~= nil and a.apSpec2 ~= nil and a.apClass ~= nil)
a.apSpec2.func()
check("a spec button loads that spec's list and makes nothing", AP.view and AP.view.spec == 581 and #AP.view.rows == 7 and #ns.rules == 0)
a.apTalents.set(nil, false)
local nOff = AP.view and #AP.view.rows
a.apTalents.set(nil, true)
check("turning 'Include talents I have not picked' off updates the table shown", nOff == 6 and AP.view and #AP.view.rows == 7)
a = creator()
local T = a.apTable and a.apTable.args or {}
check("the table is a framed box below the buttons, named after the spec", a.apTable and a.apTable.inline == true and a.apTable.order > a.apClass.order
  and tostring(a.apTable.name):find("Vengeance", 1, true) ~= nil)
check("header row: a tick box and Name | Type | Trigger | Cue type | Combat load", T.hOn and T.hOn.type == "toggle" and T.hnm and T.hty and T.htr and T.hcu and T.hcb
  and T.hnm.name:find("Name", 1, true) and T.hty.name:find("Type", 1, true) and T.htr.name:find("Trigger", 1, true)
  and T.hcu.name:find("Cue type", 1, true) and T.hcb.name:find("Combat load", 1, true) and T.hxc == nil)
local function rowSum(i)
  local s = 0
  for _, k in ipairs({ "on", "nm", "ty", "tr", "cu", "cb", "xc" }) do local o = T["r" .. i .. k]; if o then s = s + o.relWidth end end
  return s
end
local hs = (T.hOn and T.hnm and T.hty and T.htr and T.hcu and T.hcb) and (T.hOn.relWidth + T.hnm.relWidth + T.hty.relWidth + T.htr.relWidth + T.hcu.relWidth + T.hcb.relWidth) or 0
check("every row is one table row: its columns add up to the pane's width, the header's too", math.abs(rowSum(1) - 1) < 1e-6 and math.abs(rowSum(7) - 1) < 1e-6 and math.abs(hs - 1) < 1e-6
  and T.r1on.arg.xuiCell and T.r1tr.arg.xuiCell)
check("row cells: tick box, name, type (Spell CD / Aura / Debuff), trigger, cue, combat load", T.r1on.type == "toggle" and T.r1nm.name:find("Spell 187827", 1, true)
  and T.r1ty.name:find("Spell CD", 1, true) and T.r4ty.name:find("Aura", 1, true) and T.r6ty.name:find("Debuff", 1, true)
  and T.r1tr.type == "select" and T.r1cu.type == "select" and T.r1cb.type == "select" and T.r1xc == nil)
check("trigger choices: a cooldown 'When ready' / 'At max stacks'; an aura or debuff 'When present' / 'When missing'",
  T.r1tr.values.ready == "When ready" and T.r1tr.values.max == "At max stacks" and T.r1tr.values.present == nil
  and T.r4tr.values.present == "When present" and T.r4tr.values.missing == "When missing" and T.r6tr.values.missing == "When missing" and T.r4tr.values.ready == nil)
local nCue = 0
for _ in pairs(T.r1cu.values) do nCue = nCue + 1 end
local kindsListed = true
for _, k in ipairs(ns.CUE_KINDS) do   -- every cue kind the addon has (Cues.lua)
  local key = k
  if not T.r1cu.values[key] then kindsListed = false end
end
check("cue choices (Xaya 2026-11-06: ALL cue types the addon supports): every cue kind (sound, speech, text, texture, icon, custom) plus Progress texture and Progress bar",
  kindsListed and nCue == 8 and T.r1cu.values.progtex == "Progress texture" and T.r1cu.values.texture == "Texture" and T.r1cu.values.text == "Text"
  and tostring(T.r1cu.values.bar):find("not yet", 1, true) and tostring(T.r1cu.values.custom):find("not yet", 1, true)
  and #T.r1cu.sorting == 8 and T.r1cu.sorting[1] == "icon")
check("combat load choices: Any, In combat, Out of combat", T.r1cb.values.any == "Any" and T.r1cb.values.yes == "In combat" and T.r1cb.values.no == "Out of combat")
-- header tick box: ticks every row; again: unticks them all
check("header box starts unticked", T.hOn.get() == false)
T.hOn.set(nil, true)
local allOn = true
for _, c in ipairs(AP.view.rows) do if not AP.Choice(c) then allOn = false end end
check("clicking the header ticks every row", allOn and T.hOn.get() == true and T.r3on.get() == true)
T.hOn.set(nil, false)
local anyOn = false
for _, c in ipairs(AP.view.rows) do if AP.Choice(c) then anyOn = true end end
check("clicking it again unticks them all", not anyOn and T.hOn.get() == false)
-- a click in a row reuses the window's tree (keep), Advanced and paging rebuild it (notify)
local nKeep, nNotify = 0, 0
local T2 = AP.Args(function() nNotify = nNotify + 1 end, function() nKeep = nKeep + 1 end).apTable.args
T2.r2on.set(nil, true); T2.r2tr.set(nil, "max"); T2.r2cu.set(nil, "speech"); T2.r2cb.set(nil, "yes")
local p2 = AP.Picks(581)["cd:204021"] or {}
check("ticking a row and changing its choices saves them for the spec, without rebuilding the window",
  p2.on == true and p2.trig == "max" and p2.cue == "speech" and p2.combat == "yes" and nKeep == 4 and nNotify == 0)
T2.adv.func()
check("Advanced rebuilds the window", nNotify == 1 and AP.adv == true)
a = creator(); T = a.apTable.args
check("Advanced adds an Extra cues column (header and every row), and the rows still add up to the pane's width", T.hxc and T.hxc.name:find("Extra cues", 1, true)
  and T.r1xc and T.r1xc.type == "multiselect" and T.r1xc.values.speech and T.r1xc.values.sound and T.r1xc.values.text and T.r1xc.values.texture
  and T.r1xc.values.bar == nil and T.r1xc.values.custom == nil and math.abs(rowSum(1) - 1) < 1e-6)
-- paging
AP.PAGE = 3
a = creator(); T = a.apTable.args
check("a long list is shown a page at a time", T.r1on and T.r3on and T.r4on == nil and T.pgNext and T.pgPrev and T.pgPrev.disabled == true)
if T.pgNext then T.pgNext.func() end
a = creator(); T = a.apTable.args
check("Next shows the next rows", T.r4on and T.r6on and T.r1on == nil and T.r7on == nil)
AP.PAGE = 40

-- make: choices per row
for _, c in ipairs(AP.view.rows) do by[c.key] = c end
local function set(key, field, v) AP.SetChoice(by[key], field, v) end
set("cd:187827", "on", true)                                                          -- icon, When ready, any
set("cd:204021", "on", true)                                                          -- speech, At max stacks, in combat (set above)
set("au:187827", "on", true); set("au:187827", "trig", "missing"); set("au:187827", "cue", "progtex"); set("au:187827", "combat", "no")
set("au:203819", "on", true); set("au:203819", "cue", "texture")
set("db:207771", "on", true); set("db:207771", "trig", "missing"); AP.SetExtra(by["db:207771"], "speech", true); AP.SetExtra(by["db:207771"], "icon", true)
AP.SetExtra(by["db:207771"], "text", true)
set("db:204596", "on", true); set("db:204596", "cue", "sound"); set("db:204596", "trig", "present")   -- (a sound cue alone would default to When missing)
set("cd:6789", "on", true); set("cd:6789", "cue", "bar")
local made, skipped, notMade, msg = AP.Make()
check("made 6 rules; the progress bar row is not made and the message says why", made == 6 and skipped == 0 and notMade == 1 and tostring(msg):find("Progress bar", 1, true))
local parents, cues = {}, {}
for _, r in ipairs(ns.rules) do if r.isCue then cues[r.parentUid] = cues[r.parentUid] or {}; table.insert(cues[r.parentUid], r) else parents[#parents + 1] = r end end
local function find(test) for _, r in ipairs(parents) do if test(r) then return r end end end
local function row1(r) return r and r.extra and r.extra.list and r.extra.list[1] end
local meta = find(function(r) return r.spellID == 187827 and r.useCooldown end)
local brand = find(function(r) return r.spellID == 204021 and r.useCooldown end)
local aura = find(function(r) return r.useBuff and r.buffID == 187827 end)
local dMiss = find(function(r) local x = row1(r); return x and x.spellID == 207771 end)
local dOn = find(function(r) local x = row1(r); return x and x.spellID == 204596 end)
local tex = find(function(r) return r.useBuff and r.buffID == 203819 end)
check("6 rules, named after the spell, and none for unticked rows or the progress bar row", #parents == 6 and meta and brand and aura and dMiss and dOn and tex
  and meta.name == "Spell 187827" and find(function(r) return r.spellID == 6789 end) == nil)
if not (meta and brand and aura and dMiss and dOn and tex) then return R end
check("'When ready' is the cooldown state 'has a charge'; 'At max stacks' is 'fully ready'", meta.cdState == "hasCharge" and brand.cdState == "ready" and meta.useCooldown == true)
check("combat load: Any leaves it blank, In combat = yes, Out of combat = no", meta.load.combat == nil and brand.load.combat == "yes" and aura.load.combat == "no")
check("every rule loads only on its spec; a talent cooldown only while the talent is known", meta.load.specs["581"] == true and brand.talentMode == "all" and brand.talents[1].id == 204021)
check("aura 'When missing': a Buff / Aura trigger for the aura, state missing", aura.buffState == "missing" and aura.cdState == "none")
check("debuff 'When missing': a Target Debuff trigger on the target, not on it, with the Cooldown Manager ID", row1(dMiss).type == "targetDebuff" and row1(dMiss).state == "no"
  and row1(dMiss).cdmID == 204021 and row1(dMiss).unit == "target" and row1(dOn).state == "yes")
local function kinds(r) local t = {}; for _, c in ipairs(cues[r.uid] or {}) do t[#t + 1] = (c.cueKind == "texture" and c.visual.fill and c.visual.fill.enabled) and "progtex" or c.cueKind end; table.sort(t); return table.concat(t, ",") end
local function cueOf(r, kind) for _, c in ipairs(cues[r.uid] or {}) do if c.cueKind == kind then return c end end end
check("main cues: icon / speech '<name> ready' / progress texture / texture / sound with a sound picked", kinds(meta) == "icon" and kinds(brand) == "speech"
  and cues[brand.uid][1].sound.value == brand.name .. " ready" and kinds(aura) == "progtex" and kinds(tex) == "texture" and kinds(dOn) == "sound"
  and cues[dOn.uid][1].sound.source == "kit" and cues[dOn.uid][1].sound.value ~= "")
local ic, pt, tx = cueOf(meta, "icon"), cueOf(aura, "texture"), cueOf(tex, "texture")
check("each cue starts as '+ New rule' starts that type: icon = spell icon 64 x 64, gray on cooldown", ic and ic.visual.kind == "spellicon" and ic.visual.w == 64 and ic.visual.desatOnCD == true)
check("progress texture = a texture cue that fills, with its overlay and the base at 0.35, showing the spell's own icon art",
  pt and pt.visual.fill.enabled == true and pt.visual.overlay.enabled == true and pt.visual.texAlpha == 0.35 and pt.visual.kind == "file" and pt.visual.tex == "136243")
check("texture = a texture cue with the spell's icon art (a file, so it counts as a texture, not an icon)", tx and tx.visual.kind == "file" and tx.visual.tex == "136243"
  and not tx.visual.fill.enabled and ns.SmartMatch(tx, "smart_tex") == true and ns.SmartMatch(tx, "smart_icon") == false)
check("extra cues (Advanced) are added beside the main one, the main one not twice: icon + speech + text", kinds(dMiss) == "icon,speech,text"
  and cueOf(dMiss, "speech").sound.value == dMiss.name .. " missing" and cueOf(dMiss, "text").visual.text.enabled == true and cueOf(dMiss, "text").visual.texAlpha == 0)
-- groups: class > spec > cue type
local function F(id) for _, f in ipairs(ns.folders) do if f.id == id then return f end end end
local function path(r) local t, f = {}, F(r.folder); while f do table.insert(t, 1, f.name); f = f.parent and F(f.parent) end; return table.concat(t, " > ") end
check("rules sit in Class > Spec > cue type", path(meta) == "Demon Hunter > Vengeance > Icons" and path(brand) == "Demon Hunter > Vengeance > Speech"
  and path(aura) == "Demon Hunter > Vengeance > Progress Textures" and path(dOn) == "Demon Hunter > Vengeance > Sounds" and path(dMiss) == "Demon Hunter > Vengeance > Icons"
  and path(tex) == "Demon Hunter > Vengeance > Textures")
-- engine: no target here, so the debuff is not on it
local ctx = ns.ReadContext()
local ok1, r1 = pcall(ns.Evaluate, dMiss, ctx)
local ok2, r2 = pcall(ns.Evaluate, dOn, ctx)
check("engine: with no target, 'When missing' is true and 'When present' is false", ok1 and ok2 and r1 == true and r2 == false)
local n0 = #ns.rules
set("cd:6789", "cue", "custom")
made, skipped, notMade, msg = AP.Make()
check("Make again makes nothing twice (6 skipped); a row ticked with Custom is not made either, and the message says so",
  made == 0 and skipped == 6 and notMade == 1 and #ns.rules == n0 and tostring(msg):find("Custom", 1, true))
-- all specs: one button, every spec's list, rules in each spec's group
a = creator(); a.apClass.func()
check("the class button loads every spec's list", AP.view.spec == "all" and #AP.view.rows == 9)
for _, c in ipairs(AP.view.rows) do if c.spec == 577 and c.id == 195072 then AP.SetChoice(c, "on", true) end end
made = AP.Make()
local rush
for _, r in ipairs(ns.rules) do if r.spellID == 195072 and not r.isCue then rush = r end end
check("a rule from another spec goes into that spec's group and loads on that spec", made == 1 and rush and path(rush) == "Demon Hunter > Havoc > Icons" and rush.load.specs["577"] == true)
AP.Close()
check("Close removes the table", creator().apTable == nil)
-- "+ New rule" > Progress Texture / Icon / Text still set their cue up the same way (the set-up is shared: ns.NewTypedCue)
local function findKey(t, key, depth)
  if type(t) ~= "table" or depth > 30 then return nil end
  if t.args and t.args[key] then return t.args[key] end
  for _, v in pairs(t.args or {}) do local f = findKey(v, key, depth + 1); if f then return f end end
end
local built = ns.BuildOptionsTable()
local newOK, why = true, ""
for key, test in pairs({
    pickProg = function(c) return c.cueKind == "texture" and c.visual.fill.enabled == true and c.visual.overlay.enabled == true and c.visual.texAlpha == 0.35 and c.visual.kind == nil end,
    pickIcon = function(c) return c.cueKind == "icon" and c.visual.kind == "spellicon" and c.visual.w == 64 and c.visual.desatOnCD == true end,
    pickText = function(c) return c.cueKind == "text" and c.visual.text.enabled == true and c.visual.texAlpha == 0 end }) do
  local e = findKey(built, key, 0)
  local before = #ns.rules
  local okF, errF = true, nil
  local run = e and (e.func or (type(e.arg) == "table" and e.arg.xuiRow))   -- a skinned row runs arg.xuiRow (Skin.lua), a plain one its func
  if run then okF, errF = pcall(run) end
  if not run then why = why .. "(no " .. key .. ") " elseif not okF then why = why .. "(" .. key .. " error " .. tostring(errF):sub(1, 120) .. ") " end
  local cue
  for i = before + 1, #ns.rules do if ns.rules[i].isCue then cue = ns.rules[i] end end
  if not (cue and test(cue)) then newOK = false; why = why .. key .. " " end
end
check("'+ New rule' Progress Texture / Icon / Text still start their cue as before (texture cue with fill + overlay at 0.35, no art; spell icon 64 px; text)" .. (newOK and "" or ("  [" .. why .. "]")), newOK)

-- the skin: a table row on one line that fills the pane; the next row starts a new line
local function Cell(rw)
  local opt = { relWidth = rw, arg = { xuiCell = true } }
  return { width = "relative", relWidth = rw, type = "Label", frame = { width = 10, GetWidth = function() return 10 end },
           GetUserData = function(_, k) if k == "option" then return opt end end, SetWidth = function() end }
end
local kids, cols = {}, { 0.08, 0.24, 0.11, 0.20, 0.19, 0.18 }
for _ = 1, 2 do for _, w in ipairs(cols) do kids[#kids + 1] = Cell(w) end end
local content = { width = 436, GetWidth = function() return 436 end }
local okP = pcall(ns.FlexPrepass, content, kids)
local used, gaps = 0, 0
for i = 1, 6 do used = used + kids[i].relWidth * 436; gaps = gaps + (kids[i].xuiGapX or 0) end
check("skin: the cells of a row sit 4 px apart and, with the gutters, fill the pane exactly", okP and kids[1].xuiGapX == nil and kids[2].xuiGapX == 4
  and kids[6].xuiGapX == 4 and math.abs(used + gaps - 436) < 0.01)
check("skin: the next row's first cell does not fit beside a full row (it starts a new line)", kids[7].xuiGapX == nil and used + kids[7].relWidth * 436 > 436)
pcall(ns.FlexPrepass, content, kids)
check("skin: laying out again gives the same widths", math.abs(kids[2].relWidth - 0.24 * (436 - 20) / 436) < 1e-9)
return R
end
'''


def main():
    folders = H.find_addons()
    enabled = [n for n in folders if n != "XayaUI_DevAssist"]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    bad = 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        if not ok:
            bad += 1
            print("FAIL:", name)
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
