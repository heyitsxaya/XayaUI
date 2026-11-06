#!/usr/bin/env python3
"""Offline test (XayaUI_Options 0.6.44-0.6.45; rebuilt to her answers 0.6.53): auto-populate as a table (AutoPicker.lua, Skin.lua table cells). Xaya, 2026-11-05:
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
local function check(name, ok, extra) R[#R + 1] = { name .. ((ok or extra == nil) and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
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
local function keys(list) local t = {}; for _, c in ipairs(list) do t[#t + 1] = c.key .. "@" .. tostring(c.spec) end; return table.concat(t, " ") end
check("A11: rows by type (Spell CD, Aura, Debuff), then A-Z by name", keys(rows) ==
  "cd:187827@581 cd:204021@581 cd:6789@581 au:187827@581 au:203819@581 db:204596@581 db:207771@581", keys(rows))
local other = AP.BuildRows(577)
check("another spec lists its cooldowns only (the Cooldown Manager answers for the spec you are in)", #other == 2 and other[1].kind == "cd" and other[2].kind == "cd")
local all = AP.BuildRows("all")
check("all specs: both specs' rows in one list, by type then A-Z (the Spec column tells them apart)", keys(all) ==
  "cd:187827@581 cd:195072@577 cd:204021@581 cd:258920@577 cd:6789@581 au:187827@581 au:203819@581 db:204596@581 db:207771@581", keys(all))
ns.AutoCfg().talents = false
local noTal = AP.BuildRows(SPEC)
local noTalOther = AP.BuildRows(577)
local noTalAll = AP.BuildRows("all")
check("A8: 'Include talents I have not picked' off leaves out the unpicked talent cooldowns of the spec you are in only; another spec's button shows all of its talent cooldowns",
  #noTal == 6 and by["cd:204021"] and (function() for _, c in ipairs(noTal) do if c.key == "cd:204021" then return false end end return true end)()
  and #noTalOther == 2 and #noTalAll == 8, #noTal .. "/" .. #noTalOther .. "/" .. #noTalAll)
ns.AutoCfg().talents = true

-- defaults
local on, trig, cue, combat, xc = AP.Choice(by["cd:187827"])
check("defaults: not ticked, 'When available / when ready', Icon, Any; no extra cues", on == false and trig == "ready" and cue == "icon" and combat == "any" and xc == nil)
check("defaults: an aura and a debuff are 'When present'", select(2, AP.Choice(by["au:187827"])) == "present" and select(2, AP.Choice(by["db:207771"])) == "present")
AP.SetChoice(by["db:204596"], "cue", "speech")
local dSpeech = select(2, AP.Choice(by["db:204596"]))
AP.SetChoice(by["db:204596"], "cue", "sound")
local dSound = select(2, AP.Choice(by["db:204596"]))
AP.SetChoice(by["au:203819"], "cue", "speech")
local aSpeech = select(2, AP.Choice(by["au:203819"]))
AP.SetChoice(by["db:204596"], "trig", "present")
local dChosen = select(2, AP.Choice(by["db:204596"]))
AP.SetChoice(by["db:204596"], "trig", nil); AP.SetChoice(by["db:204596"], "cue", nil); AP.SetChoice(by["au:203819"], "cue", nil)
check("A7: a debuff with a Speech or Sound cue defaults to 'When missing' (an aura does not; a trigger she picked is kept)",
  dSpeech == "missing" and dSound == "missing" and aSpeech == "present" and dChosen == "present")
AP.Picks(SPEC)["db:207771"] = { when = "missing" }
check("a debuff's 'missing' saved by the 0.6.42 picker is still read", select(2, AP.Choice(by["db:207771"])) == "missing")
AP.Picks(SPEC)["db:207771"] = nil
check("A6 speech text: a cooldown says its name; an aura / debuff 'When missing' says '<name> ended'; 'When present' says its name",
  AP.DefaultSay(by["cd:187827"], "max") == "Spell 187827" and AP.DefaultSay(by["au:187827"], "missing") == "Spell 187827 ended"
  and AP.DefaultSay(by["db:207771"], "missing") == "Spell 207771 ended" and AP.DefaultSay(by["au:187827"], "present") == "Spell 187827")

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
check("the table is a frame below the buttons", a.apTable and a.apTable.inline == true and a.apTable.order > a.apClass.order)
check("A3: the frame's title and her accepted two-line help text", a.apTable.name == "Auto-populate: Vengeance" and T.help
  and T.help.name == "Tick the rules you want and set each one up. Rows marked in the Cue set-up column need a choice before they can be made.\nPopulate makes the ticked rows into rules in Class > Spec > cue type; made rows leave the table." and T.help.arg and T.help.arg.xuiKeep == true, tostring(a.apTable.name) .. " | " .. tostring(T.help and T.help.name) .. " | " .. tostring(T.help and T.help.type))
local extras = {}
for k in pairs(T) do
  if not (k:match("^r%d+%a%a$") or k:match("^r%d+su%d$") or k == "hOn" or k:match("^h%a%a$") or k:match("^b%a+On$") or k:match("^b%a+Nm$")
          or k == "adv" or k == "make" or k == "reload" or k == "close" or k == "msg" or k == "help" or k == "showMade") then extras[#extras + 1] = k end
end
table.sort(extras)
check("nothing she did not ask for is in the table (V16): title, help, her Hide / Show switch, header, bucket headers, rows, Advanced | Populate | Reload list | Close and the result line only",
  #extras == 0, table.concat(extras, ","))
check("A4 / A9: the buttons in one row at the bottom: Advanced | Populate | Reload list | Close", T.adv.name == "Advanced" and T.make.name == "Populate"
  and T.reload.name == "Reload list" and T.close.name == "Close" and T.adv.order < T.make.order and T.make.order < T.reload.order and T.reload.order < T.close.order
  and T.adv.order > T.r7cb.order)
check("her switch, exactly: 'Hide / Show already generated rules (can potentially cause duplicates)', off by default",
  T.showMade.name == "Hide / Show already generated rules (can potentially cause duplicates)" and T.showMade.get() == false)
check("header row: a tick box and Name | Type | Trigger | Cue type | Cue set-up | Combat load (no Spec column in a one-spec list)",
  T.hOn and T.hOn.type == "toggle" and T.hnm.name:find("Name", 1, true) and T.hty.name:find("Type", 1, true) and T.htr.name:find("Trigger", 1, true)
  and T.hcu.name:find("Cue type", 1, true) and T.hsu.name:find("Cue set-up", 1, true) and T.hcb.name:find("Combat load", 1, true) and T.hxc == nil and T.hsp == nil
  and T.hnm.order < T.hty.order and T.hty.order < T.htr.order and T.htr.order < T.hcu.order and T.hcu.order < T.hsu.order and T.hsu.order < T.hcb.order)
check("A11: bucket headers 'Spell CD', 'Aura', 'Debuff', each with its own tick box, above their rows", T.bcdOn and T.bcdOn.type == "toggle"
  and T.bcdNm.name:find("Spell CD", 1, true) and T.bauraNm.name:find("Aura", 1, true) and T.bdebuffNm.name:find("Debuff", 1, true)
  and T.bcdNm.order < T.r1on.order and T.r3cb.order < T.bauraOn.order and T.bauraNm.order < T.r4on.order and T.r5cb.order < T.bdebuffOn.order)
local function rowSum(i)
  local s = 0
  for k, o in pairs(T) do if (k:match("^r" .. i .. "%a%a$") or k:match("^r" .. i .. "su%d$")) and o.relWidth then s = s + o.relWidth end end
  return s
end
local hs = 0
for k, o in pairs(T) do if (k == "hOn" or k:match("^h%a%a$")) and o.relWidth then hs = hs + o.relWidth end end
check("every row is one table row: its cells add up to the pane's width; the header's and a bucket header's too", math.abs(rowSum(1) - 1) < 1e-6 and math.abs(rowSum(7) - 1) < 1e-6
  and math.abs(hs - 1) < 1e-6 and math.abs(T.bauraOn.relWidth + T.bauraNm.relWidth - 1) < 1e-6 and T.r1on.arg.xuiCell and T.r1tr.arg.xuiCell)
check("A16: the Name cell shows the spell's icon and its name", T.r1nm.name == "|T136243:16:16|t Spell 187827", T.r1nm.name)
check("A12: widths fit their contents: the Name column (spell names) is wider than the Type column", T.hnm.relWidth > T.hty.relWidth and T.r1on.relWidth >= 0.06)
check("row cells: type (Spell CD / Aura / Debuff), trigger, cue, combat load", T.r1on.type == "toggle" and T.r1ty.name:find("Spell CD", 1, true)
  and T.r4ty.name:find("Aura", 1, true) and T.r6ty.name:find("Debuff", 1, true) and T.r1tr.type == "select" and T.r1cu.type == "select" and T.r1cb.type == "select" and T.r1xc == nil)
check("trigger choices in her words", T.r1tr.values.ready == "When available / when ready" and T.r1tr.values.max == "At max stacks" and T.r1tr.values.present == nil
  and T.r4tr.values.present == "When present" and T.r4tr.values.missing == "When missing" and T.r6tr.values.missing == "When missing")
local nCue = 0
for _ in pairs(T.r1cu.values) do nCue = nCue + 1 end
local kindsListed = true
for _, k in ipairs(ns.CUE_KINDS) do if not T.r1cu.values[k] then kindsListed = false end end
check("cue choices: every cue kind plus Progress texture and Progress bar; A17: Progress bar and Custom marked '(soonTM)'",
  kindsListed and nCue == 8 and T.r1cu.values.bar == "Progress bar (soonTM)" and T.r1cu.values.custom == "Custom (soonTM)" and #T.r1cu.sorting == 8 and T.r1cu.sorting[1] == "icon")
check("Cue set-up: an Icon row has nothing to set up (an empty cell)", T.r1su and T.r1su.type == "description" and T.r1su.name == "" and T.r1su1 == nil)
-- header tick box: ticks every row; again: unticks them all
check("header box starts unticked", T.hOn.get() == false)
T.hOn.set(nil, true)
local allOn = true
for _, c in ipairs(AP.view.rows) do if not AP.Choice(c) then allOn = false end end
check("clicking the header ticks every row", allOn and T.hOn.get() == true and T.r3on.get() == true and T.bauraOn.get() == true)
T.hOn.set(nil, false)
local anyOn = false
for _, c in ipairs(AP.view.rows) do if AP.Choice(c) then anyOn = true end end
check("clicking it again unticks them all", not anyOn and T.hOn.get() == false)
T.bauraOn.set(nil, true)
local onKeys = {}
for _, c in ipairs(AP.view.rows) do if AP.Choice(c) then onKeys[#onKeys + 1] = c.key end end
check("A11: a bucket's tick box ticks that whole bucket only", table.concat(onKeys, " ") == "au:187827 au:203819" and T.bauraOn.get() == true and T.bcdOn.get() == false)
T.bauraOn.set(nil, false)
check("... and clicked again deselects the whole bucket", T.bauraOn.get() == false and not AP.Choice(by["au:187827"]) and not AP.Choice(by["au:203819"]))
-- a tick / combat load reuses the window's tree (keep); a cue type or trigger rebuilds it (the Cue set-up cell and speech text follow)
local nKeep, nNotify = 0, 0
local T2 = AP.Args(function() nNotify = nNotify + 1 end, function() nKeep = nKeep + 1 end).apTable.args
T2.r2on.set(nil, true); T2.r2tr.set(nil, "max"); T2.r2cu.set(nil, "speech"); T2.r2cb.set(nil, "yes")
local p2 = AP.Picks(581)["cd:204021"] or {}
check("ticking a row and changing its choices saves them for the spec", p2.on == true and p2.trig == "max" and p2.cue == "speech" and p2.combat == "yes" and nKeep == 2 and nNotify == 2)
T2 = AP.Args(function() nNotify = nNotify + 1 end, function() nKeep = nKeep + 1 end).apTable.args
check("Cue set-up, Speech: a '[ ] Customize' tick box", T2.r2su1 and T2.r2su1.type == "toggle" and T2.r2su1.name() == "Customize" and T2.r2su1.get() == false)
AP.lastPopup = nil
T2.r2su1.set(nil, true)
local pop = AP.lastPopup
check("ticking Customize opens the small typing window, filled with what it says now", pop and pop.which == "XAYAUI_AP_SAY" and pop.data and pop.data.current == "Spell 204021"
  and StaticPopupDialogs.XAYAUI_AP_SAY and StaticPopupDialogs.XAYAUI_AP_SAY.hasEditBox == true)
if pop and pop.data then pop.data.cb("Brand is up") end
check("after typing, the cell shows the text and the box is ticked", T2.r2su1.name() == "Brand is up" and T2.r2su1.get() == true and AP.SayText(by["cd:204021"]) == "Brand is up")
T2.adv.func()
check("Advanced rebuilds the window", AP.adv == true)
a = creator(); T = a.apTable.args
check("Advanced adds an Extra cues column (header and every row), and the rows still add up to the pane's width", T.hxc and T.hxc.name:find("Extra cues", 1, true)
  and T.r1xc and T.r1xc.type == "multiselect" and T.r1xc.values.speech and T.r1xc.values.sound and T.r1xc.values.bar == nil and T.r1xc.values.custom == nil
  and math.abs(rowSum(1) - 1) < 1e-6 and T.hxc.order > T.hcb.order)
check("Advanced shows every row (no paging)", T.r1on and T.r7on and T.r8on == nil)

-- choices per row
for _, c in ipairs(AP.view.rows) do by[c.key] = c end
local function set(key, field, v) AP.SetChoice(by[key], field, v) end
set("cd:187827", "on", true)                                                          -- icon, When ready, any
                                                                                      -- cd:204021: speech "Brand is up", At max stacks, in combat (above)
set("au:187827", "on", true); set("au:187827", "trig", "missing"); set("au:187827", "cue", "progtex"); set("au:187827", "combat", "no")
set("au:203819", "on", true); set("au:203819", "cue", "texture")
set("db:207771", "on", true); set("db:207771", "trig", "missing"); AP.SetExtra(by["db:207771"], "speech", true); AP.SetExtra(by["db:207771"], "icon", true)
AP.SetExtra(by["db:207771"], "text", true); AP.SetExtra(by["db:207771"], "sound", true)
set("db:204596", "on", true); set("db:204596", "cue", "sound")
set("cd:6789", "on", true); set("cd:6789", "cue", "bar")
a = creator(); T = a.apTable.args
check("Cue set-up, Sound / Texture / Progress texture: a picker that starts on a red 'Choose ...' (nothing picked)", T.r6su1 and T.r6su1.type == "select" and T.r6su1.get() == "0"
  and tostring(T.r6su1.values["0"]):find("Choose a sound", 1, true) and T.r5su1.get() == "0" and tostring(T.r5su1.values["0"]):find("Choose a picture", 1, true)
  and T.r5su1.arg.xuiTexPick == true and T.r4su1 and T.r4su1.arg.xuiTexPick == true)
check("Advanced extras with a set-up get their own control in the cell (debuff 207771: speech then sound, sharing the cell)", T.r7su1 and T.r7su1.type == "toggle" and T.r7su2 and T.r7su2.type == "select"
  and T.r7su3 == nil and math.abs(T.r7su1.relWidth + T.r7su2.relWidth - T.hsu.relWidth) < 1e-9)
local made, skipped, notMade, msg, names = AP.Make()
pop = AP.lastPopup
check("Populate with set-ups missing: the finished rows are made, the progress bar row is not, and the rest are named in her alert",
  made == 2 and notMade == 1 and #names == 4, made .. "/" .. notMade .. "/" .. #names)
check("her alert, verbatim, in a popup with OK", pop and pop.which == "XAYAUI_AP_ALERT"
  and pop.text == "error issue making the following rules: [Spell 187827, Spell 203819, Spell 204596, Spell 207771]. Please finish configuring them to create them."
  and StaticPopupDialogs.XAYAUI_AP_ALERT and StaticPopupDialogs.XAYAUI_AP_ALERT.button1 == OKAY and StaticPopupDialogs.XAYAUI_AP_ALERT.button2 == nil, pop and pop.text)
check("A14: made rows leave the table; unfinished ones stay (in the tray), still ticked", keys(AP.view.rows) ==
  "cd:6789@581 au:187827@581 au:203819@581 db:204596@581 db:207771@581" and AP.Choice(by["au:187827"]), keys(AP.view.rows))
-- finish them: pick the sounds and pictures
local sl = AP.SoundValues()
local art1, art2 = tostring(ns.TextureList[1][1]), tostring(ns.TextureList[2][1])
AP.SetSetup(by["db:204596"], "sound", { source = sl[1].source, value = sl[1].value })
AP.SetSetup(by["db:207771"], "sound", { source = sl[2].source, value = sl[2].value })
AP.SetSetup(by["au:187827"], "progtex", art1)
AP.SetSetup(by["au:203819"], "texture", art2)
made, skipped, notMade, msg, names = AP.Make()
check("once finished they are made; the progress bar row stays (soonTM) and the message says why", made == 4 and #names == 0 and notMade == 1 and tostring(msg):find("soonTM", 1, true))
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
check("6 rules, named after the spell (A16: no icon in the rule's name), none for unticked rows or the progress bar row", #parents == 6 and meta and brand and aura and dMiss and dOn and tex
  and meta.name == "Spell 187827" and find(function(r) return r.spellID == 6789 end) == nil)
if not (meta and brand and aura and dMiss and dOn and tex) then return R end
check("'When ready' is the cooldown state 'has a charge'; 'At max stacks' is 'fully ready'", meta.cdState == "hasCharge" and brand.cdState == "ready" and meta.useCooldown == true)
check("combat load: Any leaves it blank, In combat = yes, Out of combat = no", meta.load.combat == nil and brand.load.combat == "yes" and aura.load.combat == "no")
check("every rule loads only on its spec; a talent cooldown only while the talent is known", meta.load.specs["581"] == true and brand.talentMode == "all" and brand.talents[1].id == 204021)
check("aura 'When missing': a Buff / Aura trigger for the aura, state missing", aura.buffState == "missing" and aura.cdState == "none")
check("debuff triggers: Target Debuff on the target with the Cooldown Manager ID; Sound on a debuff defaulted to 'When missing' (A7)", row1(dMiss).type == "targetDebuff" and row1(dMiss).state == "no"
  and row1(dMiss).cdmID == 204021 and row1(dMiss).unit == "target" and row1(dOn).state == "no")
local function kinds(r) local t = {}; for _, c in ipairs(cues[r.uid] or {}) do t[#t + 1] = (c.cueKind == "texture" and c.visual.fill and c.visual.fill.enabled) and "progtex" or c.cueKind end; table.sort(t); return table.concat(t, ",") end
local function cueOf(r, kind) for _, c in ipairs(cues[r.uid] or {}) do if c.cueKind == kind then return c end end end
check("main cues: icon / speech / progress texture / texture / sound", kinds(meta) == "icon" and kinds(brand) == "speech"
  and kinds(aura) == "progtex" and kinds(tex) == "texture" and kinds(dOn) == "sound")
check("cue set-up carried into the cues: the typed speech text, the default '<name> ended', the picked sounds and pictures",
  cueOf(brand, "speech").sound.source == "tts" and cueOf(brand, "speech").sound.value == "Brand is up"
  and cueOf(dMiss, "speech").sound.value == "Spell 207771 ended" and cueOf(dOn, "sound").sound.value == sl[1].value and cueOf(dOn, "sound").sound.source == sl[1].source
  and cueOf(dMiss, "sound").sound.value == sl[2].value and cueOf(aura, "texture").visual.kind == "file" and cueOf(aura, "texture").visual.tex == art1
  and cueOf(tex, "texture").visual.tex == art2)
check("A10: cues are named '<spell> (<cue type>)'", cueOf(meta, "icon").cueName == "Spell 187827 (icon)" and cueOf(brand, "speech").cueName == "Spell 204021 (speech)"
  and cueOf(aura, "texture").cueName == "Spell 187827 (progress texture)" and cueOf(tex, "texture").cueName == "Spell 203819 (texture)"
  and cueOf(dOn, "sound").cueName == "Spell 204596 (sound)" and cueOf(dMiss, "text").cueName == "Spell 207771 (text)" and ns.CueLabel(cueOf(meta, "icon")) == "Spell 187827 (icon)")
local ic, pt = cueOf(meta, "icon"), cueOf(aura, "texture")
check("each cue starts as '+ New rule' starts that type (icon = spell icon 64 x 64; progress texture fills with its overlay, base 0.35)", ic and ic.visual.kind == "spellicon" and ic.visual.w == 64
  and ic.visual.desatOnCD == true and pt.visual.fill.enabled == true and pt.visual.overlay.enabled == true and pt.visual.texAlpha == 0.35)
check("extra cues (Advanced) beside the main one, the main one not twice: icon + sound + speech + text", kinds(dMiss) == "icon,sound,speech,text")
-- placement: 3 across, then 3 down; the second Populate continues after the first
local function xy(c) return tostring(c.visual.x) .. "," .. tostring(c.visual.y) end
-- her placement: rows of 3 centred on the screen centre, in the order centre, below, above. The first Populate placed the icon of 187827
-- alone (step 64 + 4: the left place of row 1); the second laid it out again with the new ones (it was not moved): icon, progress texture,
-- texture on the centre row, the debuff's icon and text on the row below (step = the largest, 128, + the gap)
local s2 = 128 + AP.GRID_GAP
check("her placement: rows of 3 centred on the screen centre; unmoved cues re-laid out together with the new ones",
  xy(ic) == (-s2) .. ",0" and xy(pt) == "0,0" and xy(cueOf(tex, "texture")) == s2 .. ",0"
  and xy(cueOf(dMiss, "icon")) == (-s2) .. "," .. (-s2) and xy(cueOf(dMiss, "text")) == "0," .. (-s2),
  xy(ic) .. " " .. xy(pt) .. " " .. xy(cueOf(tex, "texture")) .. " " .. xy(cueOf(dMiss, "icon")) .. " " .. xy(cueOf(dMiss, "text")))
local order = {}
for n = 0, 14 do local x, y = AP.GridPos(n, 100); order[#order + 1] = x .. "," .. y end
check("the row order: centre, below, above, further below, further above (each row centred: its 2nd cue on the centre)",
  table.concat(order, " ") == "-100,0 0,0 100,0 -100,-100 0,-100 100,-100 -100,100 0,100 100,100 -100,-200 0,-200 100,-200 -100,200 0,200 100,200",
  table.concat(order, " "))
-- a cue moved by hand keeps its place on the next Populate; the unmoved ones are laid out again without it
cueOf(tex, "texture").visual.x, cueOf(tex, "texture").visual.y = 500, 300
local unmoved = AP.UnmovedPlaced()
local hasTex = false
for _, c in ipairs(unmoved) do if c == cueOf(tex, "texture") then hasTex = true end end
check("a cue moved by hand is no longer counted as auto-placed (it keeps the place you gave it)", #unmoved == 4 and not hasTex, #unmoved)
-- groups: class > spec > cue type
local function F(id) for _, f in ipairs(ns.folders) do if f.id == id then return f end end end
local function path(r) local t, f = {}, F(r.folder); while f do table.insert(t, 1, f.name); f = f.parent and F(f.parent) end; return table.concat(t, " > ") end
check("rules sit in Class > Spec > cue type", path(meta) == "Demon Hunter > Vengeance > Icons" and path(brand) == "Demon Hunter > Vengeance > Speech"
  and path(aura) == "Demon Hunter > Vengeance > Progress Textures" and path(dOn) == "Demon Hunter > Vengeance > Sounds" and path(dMiss) == "Demon Hunter > Vengeance > Icons"
  and path(tex) == "Demon Hunter > Vengeance > Textures")
local ctx = ns.ReadContext()
local ok1, r1 = pcall(ns.Evaluate, dMiss, ctx)
check("engine: with no target, a debuff 'When missing' rule is true", ok1 and r1 == true)
-- Reload list and her Hide / Show switch
a = creator(); T = a.apTable.args
T.reload.func()
check("Reload list: rows whose rule already exists are left out (the switch is off)", keys(AP.view.rows) == "cd:6789@581", keys(AP.view.rows))
a = creator(); T = a.apTable.args
T.showMade.set(nil, true)
local shownAgain = AP.view.rows
local anyTicked = false
local nGen = 0
for _, c in ipairs(shownAgain) do if c.generated then nGen = nGen + 1; if AP.Choice(c) then anyTicked = true end end end
check("switch on: the 6 already generated rows are listed again, none of them ticked", #shownAgain == 7 and nGen == 6 and not anyTicked)
a = creator(); T = a.apTable.args
check("... and the header tick box selects them all again", (function() T.hOn.set(nil, true); for _, c in ipairs(AP.view.rows) do if not AP.Choice(c) then return false end end; return true end)())
T.hOn.set(nil, false)
for _, c in ipairs(AP.view.rows) do if c.key == "cd:187827" then AP.SetChoice(c, "on", true) end end
local n0 = #ns.rules
made = AP.Make()
local metas = 0
for _, r in ipairs(ns.rules) do if r.spellID == 187827 and r.useCooldown and not r.isCue then metas = metas + 1 end end
check("a row ticked by hand while the switch is on is made again (a duplicate, as her label warns)", made == 1 and metas == 2 and #ns.rules == n0 + 2)
check("that Populate left the cue moved by hand where it was, and laid out the 4 unmoved ones and the new icon from the centre again",
  xy(cueOf(tex, "texture")) == "500,300" and #AP.UnmovedPlaced() == 5 and xy(pt) == "0,0", xy(cueOf(tex, "texture")) .. " " .. #AP.UnmovedPlaced() .. " " .. xy(pt))
T.showMade.set(nil, false)
-- all specs: one button, every spec's list, rules in each spec's group
a = creator(); a.apClass.func()
a = creator(); T = a.apTable.args
check("the class button loads every spec's list (rows already made left out) with a Spec column after Name, and its own title", AP.view.spec == "all" and #AP.view.rows == 3
  and T.hsp and T.hsp.name:find("Spec", 1, true) and T.hnm.order < T.hsp.order and T.hsp.order < T.hty.order and T.r1sp and a.apTable.name == "Auto-populate: Demon Hunter (all specs)",
  #AP.view.rows)
for _, c in ipairs(AP.view.rows) do if c.spec == 577 and c.id == 195072 then AP.SetChoice(c, "on", true) end end
made = AP.Make()
local rush
for _, r in ipairs(ns.rules) do if r.spellID == 195072 and not r.isCue then rush = r end end
check("a rule from another spec goes into that spec's group and loads on that spec", made == 1 and rush and path(rush) == "Demon Hunter > Havoc > Icons" and rush.load.specs["577"] == true)
T.close.func()
check("Close removes the table", creator().apTable == nil and AP.view == nil)
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
