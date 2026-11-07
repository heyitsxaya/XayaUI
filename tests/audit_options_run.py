#!/usr/bin/env python3
"""Function audit (UI-60, REQUEST-LOG A11; docs/process/FUNCTION-AUDIT-2026-11-07.md), settings-window fixes (XayaUI_Options) and FA-11.
Loads the real addons in the stand-in game (tests/harness), opens the settings window, builds the real options tree and checks what the
player gets. Each part runs on its own (a Lua error in one part is reported as that part failing; the others still run).
- D20 Load > Instance Options > Instance Type: from unset, click 1 = selected, click 2 = NOT, click 3 = cleared (AceGUI tri-state cycle
      true -> nil -> false, simulated from the box's own get).
- D21 a Sound / Speech cue setting changed, then Ctrl+Z (ns.UndoKey): the setting goes back (needs ns.MarkDirty in the setter).
- D22 Drafts page > Restore while drafts are off asks first, with a message that says it replaces the rule and keeps it.
- D23 just reading a rule's Load tab (every get / name / hidden / values) leaves "unsaved changes" off (drafts on).
- D24 Info > Group: an undo step (EDITED) and the displays refreshed, as right-click > Move To.
- D25 Buff / Aura Remove also clears Seconds left; added again, no old filter.
- D26 / D44 edit lock: Ctrl+Z, Drafts Restore, the header icons and name box of a cue, a condition and a trigger, the Delete key,
      multi-select Delete / Move and double-click rename of a locked group all leave the rule as it was.
- D41 the lock icon on a cue-based rule's sidebar row locks the rule itself.
- D42 a group's Enabled box off / on and "Enable all" leave a condition the player switched off, off.
- D43 a group Display color picker: drag, then Cancel: every display keeps its own color.
- D45 "1o" typed as a condition's compare value or an extra trigger's spell / item ID keeps the old value.
- D46 sidebar rename of a rule to an empty name keeps the old name.
- D47 an error in a save-bar button reaches the error handler.
- FA-11 the red X on a cue, a condition and an extra trigger sends it to the Recycle Bin; Restore puts it back where it was (a cue
      also back in the condition that played it; a trigger back in its place and in the condition row that read it).
Run: python3 tests/audit_options_run.py   (Lua 5.1 via lupa; slow: the stand-in builds the whole settings window)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false }; io.stdout:write((ok and "  pass " or "  FAIL ") .. name .. (ok and "" or ("  [" .. tostring(extra) .. "]")) .. "\n"); io.stdout:flush() end
local function section(name, fn) local ok, err = pcall(fn); if not ok then check(name .. ": ran to its end (a Lua error stopped it)", false, err) end end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
check("settings window addon loaded", ns and ns.BuildOptionsTable ~= nil)
if not (ns and ns.BuildOptionsTable) then return R end
ns.Print = function() end
CueRulesDB.ui = CueRulesDB.ui or {}

-- data -------------------------------------------------------------------------------------------------------------------------
local function NewRule(name, folder)
  local r = ns.NewRule(); r.name = name; r.enabled = true; r.folder = folder; r.uid = ns.NewUID()
  ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
  return r
end
local function NewCondition(p, name)
  local n = ns.NewRule(); n.name = name; n.parentUid = p.uid; n.folder = p.folder; n.uid = ns.NewUID()
  n.sound.enabled, n.visual.enabled = false, false
  n.when = { list = { { ref = "cd", neg = false, op = "and", cmp = "==", num = 0 } } }
  ns.NormalizeRule(n); ns.rules[#ns.rules + 1] = n
  return n
end
local function idx(r) for i, x in ipairs(ns.rules) do if x == r then return i end end end
local function byUid(u) for _, x in ipairs(ns.rules) do if x.uid == u then return x end end end
-- the rule's group in a fresh options tree (key "rule<i>" with tabs), and a leaf found by key anywhere under a node
local function Tree() return ns.BuildOptionsTable() end
local function find(node, key, depth)
  depth = depth or 0
  if type(node) ~= "table" or depth > 18 then return nil end
  local a = node.args
  if type(a) ~= "table" then return nil end
  if a[key] ~= nil then return a[key] end
  for _, c in pairs(a) do local hit = type(c) == "table" and find(c, key, depth + 1); if hit then return hit end end
end
local function RuleNode(T, r) local i = idx(r); local g = i and find(T, "rule" .. i); return g end
local function FolderNode(T, f) return find(T, f.id) end
-- the embedded condition of a rule: key "oc<k>" on its Conditions tab (k counts all of the rule's cues and conditions)
local function findCond(node)
  local c = find(node, "conditions")
  for k, v in pairs(c and c.args or {}) do if tostring(k):match("^oc%d+$") then return v end end
end
local function cycle(v) if v == true then return nil elseif v == nil then return false end return true end   -- AceGUI CheckBox tri-state

local F1 = ns.NewFolder("Audit A"); local F2 = ns.NewFolder("Audit B")
local P = NewRule("Audit parent", F1.id)
P.useCooldown, P.spellID, P.cdState = true, 1001, "ready"
local cue = ns.NewCueRule(P, "sound")
local spk = ns.NewCueRule(P, "speech")
cue.uid, spk.uid = ns.NewUID(), ns.NewUID()   -- (a new cue has no uid of its own; the test finds rows again by uid after Ctrl+Z copies them)
local cond = NewCondition(P, "Audit condition")
cond.thenCues = { cue.cueKey }

-------------------------------------------------------------------------------------------------------------------------------
section("D20", function()
  P.load.instance = "yes"
  local T = Tree()
  local g = find(find(RuleNode(T, P), "load"), "instanceTypes")
  local box = g and g.args and g.args.c1
  check("D20 the Instance Type boxes are there", box ~= nil)
  local set = P.load.instanceTypes or {}
  local id = ns.INSTANCE_TYPE_ORDER[1]
  check("D20 unset: the box draws unticked", box and box.get() == false, box and tostring(box.get()))
  box.set(nil, cycle(box.get()))
  check("D20 click 1: selected", P.load.instanceTypes[id] == true, tostring(P.load.instanceTypes[id]))
  box.set(nil, cycle(box.get()))
  check("D20 click 2: NOT", P.load.instanceTypes[id] == "not", tostring(P.load.instanceTypes[id]))
  box.set(nil, cycle(box.get()))
  check("D20 click 3: cleared", P.load.instanceTypes[id] == nil, tostring(P.load.instanceTypes[id]))
  P.load.instance = nil
end)

-------------------------------------------------------------------------------------------------------------------------------
-- Ctrl+Z works on the rule selected in the sidebar; the undo journal runs while the window counts as open (Drafts.lua)
ns.SelectedRuleForUndo = function() return byUid(P.uid) end
if ns.DraftsOnOpen then pcall(ns.DraftsOnOpen) end
if ns.UndoFirstState then pcall(ns.UndoFirstState) end
local function Settle() W.tick(0.3, 6) end

section("D21", function()
  local cases = {
    { "Sound channel", "snd_channel", function(c) return c.sound.channel end, "Dialog", cue },
    { "Sound (list)", "snd_sound", function(c) return tostring(c.sound.source) .. ":" .. tostring(c.sound.value) end, nil, cue },
    { "Repeat", "snd_repeatSec", function(c) return c.repeatSec end, 2.5, cue },
    { "Speech text", "spk_text", function(c) return c.sound.value end, "audit words", spk },
    { "Speech voice", "spk_voice", function(c) return c.sound.voice end, "7", spk },
    { "Speech speed", "spk_rate", function(c) return c.sound.rate end, 4, spk },
    { "Speech volume", "spk_vol", function(c) return c.sound.ttsVolume end, 35, spk },
    { "Speech repeat", "spk_repeatSec", function(c) return c.repeatSec end, 3.5, spk },
  }
  for _, cs in ipairs(cases) do
    local label, key, read, val, which = cs[1], cs[2], cs[3], cs[4], cs[5]
    local uid = which.uid
    local T = Tree()
    local o = find(find(RuleNode(T, byUid(P.uid)), "cues"), key)
    if not o then check("D21 " .. label .. ": control found", false, key)
    else
      local before = read(byUid(uid))
      local v = val
      if key == "snd_sound" then local vals = o.values(); for k in pairs(vals) do if k ~= "0" and k ~= o.get() then v = k; break end end end
      o.set(nil, v)
      local after = read(byUid(uid))
      Settle()
      ns.UndoKey(false)
      Settle()
      local back = read(byUid(uid))
      check("D21 " .. label .. ": Ctrl+Z puts it back", after ~= before and back == before, tostring(before) .. " -> " .. tostring(after) .. " -> undo " .. tostring(back))
    end
  end
end)

-------------------------------------------------------------------------------------------------------------------------------
section("D23", function()
  CueRulesDB.ui.promptSave = true
  if ns.DraftsApplySetting then ns.DraftsApplySetting() end
  local p = byUid(P.uid)
  p.load.classes, p.load.specs, p.load.roles, p.load.heroes, p.load.instanceTypes = nil, nil, nil, nil, nil
  if ns.DraftsApplySetting then ns.DraftsApplySetting() end
  W.tick(0.05, 2)
  check("D23 before opening: no unsaved changes", not ns.DraftDirty(p))
  local T = Tree()
  W.tick(0.05, 2)
  local load = find(RuleNode(T, p), "load")
  local function read(n, d)
    if type(n) ~= "table" or d > 12 then return end
    for _, k in ipairs({ "get", "name", "hidden", "values", "disabled", "sorting" }) do if type(n[k]) == "function" then pcall(n[k], {}) end end
    for _, c in pairs(n.args or {}) do read(c, d + 1) end
  end
  read(load, 0)
  W.tick(0.05, 2)
  check("D23 after reading every control of the Load tab: still no unsaved changes", not ns.DraftDirty(p),
    "classes=" .. tostring(p.load.classes) .. " specs=" .. tostring(p.load.specs))
  CueRulesDB.ui.promptSave = nil
  if ns.DraftsApplySetting then ns.DraftsApplySetting() end
end)

-------------------------------------------------------------------------------------------------------------------------------
section("D22 + D26 Drafts Restore", function()
  local p = byUid(P.uid)
  CueRulesDB.drafts = { { id = "dq1", uid = p.uid, name = "Audit parent", ts = 1, rules = { ns.Copy(p) } } }
  CueRulesDB.drafts[1].rules[1].spellID = 4242
  local page = ns.BuildDraftsPage()
  local rs = page.args.d1 and page.args.d1.args.restore
  local c = rs and rs.confirm
  local txt = type(c) == "function" and c() or c
  check("D22 drafts off: Restore asks first", type(txt) == "string" and txt ~= "", tostring(txt))
  check("D22 ...and says it replaces the rule and keeps it", type(txt) == "string" and txt:find("replaces", 1, true) and txt:find("keeps", 1, true), tostring(txt))
  local d = rs and rs.desc; if type(d) == "function" then d = d() end
  check("D22 the Restore hover no longer says it waits for Save changes while drafts are off", type(d) == "string" and not d:find("not saved until", 1, true), tostring(d))
  p.editLocked = true
  ns.DraftRestore("dq1")
  check("D26 Restore on a locked rule leaves it as it was", byUid(P.uid).spellID == 1001, byUid(P.uid).spellID)
  byUid(P.uid).editLocked = nil
  CueRulesDB.drafts = {}
end)

section("D26 Ctrl+Z on a locked rule", function()
  local p = byUid(P.uid)
  local T = Tree()
  local o = find(RuleNode(T, p), "spellID")
  o.set(nil, "5151"); Settle()
  p = byUid(P.uid); p.editLocked = true
  ns.UndoKey(false); Settle()
  check("D26 Ctrl+Z does not change a locked rule", byUid(P.uid).spellID == 5151, byUid(P.uid).spellID)
  byUid(P.uid).editLocked = nil
  ns.UndoKey(false); Settle()
  check("D26 unlocked again: Ctrl+Z works", byUid(P.uid).spellID == 1001, byUid(P.uid).spellID)
end)

-------------------------------------------------------------------------------------------------------------------------------
section("D24", function()
  local p = byUid(P.uid)
  local n, rv = 0, 0
  local off = ns.On("EDITED", function() n = n + 1 end)
  local saveR = ns.RefreshAllVisuals; ns.RefreshAllVisuals = function(...) rv = rv + 1; return saveR(...) end
  local T = Tree()
  local o = find(find(RuleNode(T, p), "rule"), "folder")
  o.set(nil, F2.id)
  ns.RefreshAllVisuals = saveR
  check("D24 Info > Group moves the rule", byUid(P.uid).folder == F2.id)
  check("D24 ...records an edit (undo step) and refreshes the displays", n > 0 and rv > 0, "EDITED " .. n .. ", refreshes " .. rv)
  o.set(nil, F1.id)
  Settle()
end)

-------------------------------------------------------------------------------------------------------------------------------
section("D25", function()
  local p = byUid(P.uid)
  p.useBuff, p.buffID, p.buffState, p.buffTimeOp, p.buffTimeSec = true, 2002, "present", "<", 5
  local T = Tree()
  local rm = find(RuleNode(T, p), "buffRemove")
  rm.func()
  p = byUid(P.uid)
  check("D25 Remove clears Seconds left", p.buffTimeOp == nil and p.buffTimeSec == nil, tostring(p.buffTimeOp) .. " " .. tostring(p.buffTimeSec))
  local add = find(RuleNode(Tree(), p), "xAdd")
  add.set(nil, "_buff")
  check("D25 added again: no old Seconds left filter", byUid(P.uid).buffTimeOp == nil)
  p = byUid(P.uid); p.useBuff, p.buffID, p.buffState = nil, 0, nil
  -- (the Remove went to the Recycle Bin: FA-11; empty it so later counts start clean)
  ns.RecycleEmpty()
  Settle()
end)

-------------------------------------------------------------------------------------------------------------------------------
section("D26 / D44 header controls", function()
  local p = byUid(P.uid)
  if not (type(p.extra) == "table") then ns.NormalizeExtra(p) end
  local xtype
  for k, d in pairs(ns.TRIGGER_TYPES or {}) do for _, f in ipairs(d.fields or {}) do if f.kind == "spell" and not xtype then xtype = k end end end
  p.extra.list = { { type = xtype, spellID = 3003 } }
  p.trigOrder = nil
  p.editLocked = true
  local T = Tree()
  local node = RuleNode(T, p)
  local hdrs = {}
  local function scan(n, d)
    if type(n) ~= "table" or d > 16 then return end
    if type(n.arg) == "table" and n.arg.xuiActions then hdrs[#hdrs + 1] = n end
    for _, c in pairs(n.args or {}) do scan(c, d + 1) end
  end
  scan(node, 0)
  local live, n = 0, 0
  for _, h in ipairs(hdrs) do
    local a = h.arg.xuiActions; if type(a) == "function" then a = a() end
    for _, v in pairs(a or {}) do n = n + 1; if v then live = live + 1 end end
  end
  check("D44 locked rule: every Move / Duplicate / Remove icon of its triggers, cues and conditions is grayed out (" .. #hdrs .. " headers)", #hdrs >= 3 and live == 0, live .. " of " .. n .. " still active")
  local cueHdr = find(find(node, "oq1"), "hdr")
  local before = byUid(cue.uid).cueName
  if cueHdr and cueHdr.arg.xuiEdit then cueHdr.arg.xuiEdit.set("renamed while locked") end
  check("D44 locked rule: the cue's name box refuses the edit", byUid(cue.uid).cueName == before, tostring(byUid(cue.uid).cueName))
  -- the red X itself, called anyway: nothing happens
  local nRules = #ns.rules
  for _, h in ipairs(hdrs) do
    local a = h.arg.xuiActions; if type(a) == "function" then a = a() end
  end
  check("D44 locked rule: nothing was removed", #ns.rules == nRules and #p.extra.list == 1)
  byUid(P.uid).editLocked = nil
end)

-------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------
section("D42", function()
  local c = byUid(cond.uid); c.enabled = false
  local T = Tree()
  local g = FolderNode(T, F1)
  local en
  local function findEn(n, d)
    if type(n) ~= "table" or d > 14 or en then return end
    for k, c in pairs(n.args or {}) do
      if k == "enabled" and type(c) == "table" and type(c.desc) == "string" and c.desc:find("every rule in this group", 1, true) then en = c end
      if type(c) == "table" and c.type == "group" and not tostring(k):match("^rule%d") then findEn(c, d + 1) end
    end
  end
  findEn(g, 0)
  check("D42 the group's Enabled box is there", en and en.set ~= nil)
  en.set(nil, false); en.set(nil, true)
  check("D42 Enabled off then on: the condition the player switched off stays off", byUid(cond.uid).enabled == false)
  check("D42 ...and the rule itself is on again", byUid(P.uid).enabled == true)
  c = byUid(cond.uid); c.enabled = false
  check("D42 the Enabled box reads ticked while every rule (not condition) is on", en.get() == true)
end)

-------------------------------------------------------------------------------------------------------------------------------
section("D43", function()
  local G = ns.NewFolder("Audit colors")
  local A = NewRule("Color A", G.id); A.visual.enabled = true; A.visual.border = { enabled = true, size = 1, color = { 1, 0, 0, 1 } }
  local B = NewRule("Color B", G.id); B.visual.enabled = true; B.visual.border = { enabled = true, size = 1, color = { 0, 0, 1, 1 } }
  local T = Tree()
  local col = find(FolderNode(T, G), "bdColor")
  check("D43 the group's Border color picker is there", col ~= nil)
  local r0, g0, b0, a0 = col.get()
  ColorPickerFrame:Show()
  col.set(nil, 0, 1, 0, 1)   -- dragging in the picker
  local dragged = A.visual.border.color[2] == 1 and B.visual.border.color[2] == 1
  ColorPickerFrame:Hide()
  col.set(nil, r0, g0, b0, a0)   -- Cancel: AceGUI sends the swatch's start color
  local ca, cb = A.visual.border.color, B.visual.border.color
  check("D43 while dragging every display follows", dragged)
  check("D43 Cancel: each display keeps its own color", ca[1] == 1 and ca[3] == 0 and cb[1] == 0 and cb[3] == 1,
    ("A %s,%s,%s  B %s,%s,%s"):format(ca[1], ca[2], ca[3], cb[1], cb[2], cb[3]))
  ColorPickerFrame:Show(); col.set(nil, 0.5, 0.5, 0.5, 1); ColorPickerFrame:Hide(); col.set(nil, 0.5, 0.5, 0.5, 1)
  check("D43 OK on a new color: every display gets it", A.visual.border.color[1] == 0.5 and B.visual.border.color[1] == 0.5)
end)

-------------------------------------------------------------------------------------------------------------------------------
section("D45", function()
  local c = byUid(cond.uid)
  c.when.list[1].ref = "n:cd"; c.when.list[1].num = 5
  local T = Tree()
  local n1 = find(findCond(RuleNode(T, byUid(P.uid))), "n1")
  check("D45 the compare value box is there", n1 ~= nil)
  n1.set(nil, "1o")
  check("D45 compare value: '1o' keeps 5", byUid(cond.uid).when.list[1].num == 5, byUid(cond.uid).when.list[1].num)
  n1.set(nil, "7")
  check("D45 compare value: '7' is stored", byUid(cond.uid).when.list[1].num == 7)
  local p = byUid(P.uid)
  local row = p.extra.list[1]
  local id
  for _, f in ipairs(ns.TRIGGER_TYPES[row.type].fields) do if f.kind == "spell" then id = f.key .. "ID" end end
  local box = find(find(RuleNode(Tree(), p), "x1"), id)
  check("D45 the extra trigger's spell ID box is there", box ~= nil, id)
  box.set(nil, "1o")
  check("D45 spell ID: '1o' keeps 3003", byUid(P.uid).extra.list[1].spellID == 3003, byUid(P.uid).extra.list[1].spellID)
  c.when.list[1].ref = "cd"
end)

-------------------------------------------------------------------------------------------------------------------------------
section("D46", function()
  local p = byUid(P.uid)
  local b = CreateFrame("Button", nil, UIParent); b.uniquevalue = "loaded\001rule" .. idx(p)
  ns.SidebarRename(b)
  local eb = b.xuiRenameEB
  check("D46 the name box opens", eb ~= nil)
  eb:SetText("")
  eb:GetScript("OnEditFocusLost")(eb)
  check("D46 an empty name keeps the old one", byUid(P.uid).name == "Audit parent", "'" .. tostring(byUid(P.uid).name) .. "'")
end)

-------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------
section("FA-11", function()
  ns.RecycleEmpty()
  local p = byUid(P.uid)
  -- a second cue so the first one has a place to come back to
  local cue2 = ns.NewCueRule(p, "text")
  local T = Tree()
  local node = RuleNode(T, p)
  local hdr = find(find(node, "oq1"), "hdr")
  local acts = hdr.arg.xuiActions(); acts.del()
  check("FA-11 cue red X: the cue left the rule", byUid(cue.uid) == nil)
  check("FA-11 ...it is in the Recycle Bin", #ns.RecycleItems() == 1 and ns.RecycleItems()[1].kind == "cue", #ns.RecycleItems())
  check("FA-11 ...and the condition no longer plays it", byUid(cond.uid).thenCues == nil)
  local ok, note = ns.RecycleRestore(ns.RecycleItems()[1].id)
  local cs = ns.CuesOf(byUid(P.uid))
  check("FA-11 Restore: the cue is back, first among the rule's cues", ok and cs[1] and cs[1].uid == cue.uid, tostring(note))
  check("FA-11 ...and the condition plays it again", byUid(cond.uid).thenCues and byUid(cond.uid).thenCues[1] == cue.cueKey)
  -- a condition
  hdr = find(findCond(RuleNode(Tree(), byUid(P.uid))), "hdr")
  hdr.arg.xuiActions().del()
  check("FA-11 condition red X: to the Recycle Bin", byUid(cond.uid) == nil and #ns.RecycleItems() == 1 and ns.RecycleItems()[1].kind == "condition")
  ok = ns.RecycleRestore(ns.RecycleItems()[1].id)
  check("FA-11 Restore: the condition is back in its rule", ok and byUid(cond.uid) and byUid(cond.uid).parentUid == P.uid)
  -- an extra trigger read by the condition
  p = byUid(P.uid)
  p.extra.list = { { type = p.extra.list[1].type, spellID = 3003 }, { type = p.extra.list[1].type, spellID = 3004 } }
  p.trigOrder = nil
  byUid(cond.uid).when.list[1].ref = "x1"
  local seqBefore = table.concat(ns.TriggerSequence(p), ",")
  local x1 = find(RuleNode(Tree(), p), "x1")
  local th = x1 and (x1.args.hdr or find(x1, "hdr"))
  if th and th.arg and th.arg.xuiActions then th.arg.xuiActions().del() else local rmv = find(x1, "remove"); rmv.func() end
  p = byUid(P.uid)
  check("FA-11 trigger red X: the trigger left the rule", #p.extra.list == 1 and p.extra.list[1].spellID == 3004)
  check("FA-11 ...it is in the Recycle Bin", #ns.RecycleItems() == 1 and ns.RecycleItems()[1].kind == "trigger")
  ok, note = ns.RecycleRestore(ns.RecycleItems()[1].id)
  p = byUid(P.uid)
  check("FA-11 Restore: the trigger is back as trigger row 1", ok and #p.extra.list == 2 and p.extra.list[1].spellID == 3003 and p.extra.list[2].spellID == 3004, tostring(note))
  check("FA-11 ...in the same place in the trigger order", table.concat(ns.TriggerSequence(p), ",") == seqBefore, table.concat(ns.TriggerSequence(p), ","))
  check("FA-11 ...and the condition row reads it again", byUid(cond.uid).when.list[1].ref == "x1", tostring(byUid(cond.uid).when.list[1].ref))
  check("FA-11 the bin is empty again", #ns.RecycleItems() == 0)
  -- a rule in the bin: its cue cannot come back before it
  hdr = find(find(RuleNode(Tree(), p), "oq1"), "hdr"); hdr.arg.xuiActions().del()
  local cueItem = ns.RecycleItems()[1]
  local ruleItem = ns.RecycleRule(byUid(P.uid))
  ok, note = ns.RecycleRestore(cueItem.id)
  check("FA-11 a cue whose rule is in the bin is not restored (and stays in the bin)", not ok and #ns.RecycleItems() == 2, tostring(note))
  ns.RecycleRestore(ruleItem.id)
  ok = ns.RecycleRestore(cueItem.id)
  check("FA-11 ...after its rule is restored, it is", ok and byUid(cue.uid) ~= nil)
end)

-------------------------------------------------------------------------------------------------------------------------------
-- the real window, opened last: every edit redraws an open window, which is slow in the stand-in
if rawget(_G, "XUI_TEST_NOWINDOW") then return R end
if ns.ToggleUI then pcall(ns.ToggleUI) end
W.tick(0.1, 4)
ns = rawget(_G, "XayaUI_NS"); ns.Print = function() end
section("D44 Delete key, multi-select, group rename", function()
  local saveShow = StaticPopup_Show
  StaticPopup_Show = function(which, a, b, data) if data and data.cb then data.cb() end; return CreateFrame("Frame") end   -- every popup: Yes
  local p = byUid(P.uid)
  p.editLocked = true
  pcall(ns.ReselectRule, p)
  local sel = ns.SelectedRuleForUndo and ns.SelectedRuleForUndo()
  pcall(ns.DeleteKey)
  check("D44 Delete key on a locked rule: the rule stays", byUid(P.uid) ~= nil)
  -- multi-select (Ctrl+click two rows), one of them locked
  local Q = NewRule("Audit other", F1.id)
  local saveCtrl = IsControlKeyDown; IsControlKeyDown = function() return true end
  ns.MultiReset()
  ns.MultiClick({ uniquevalue = "loaded\001rule" .. idx(byUid(P.uid)) }, "LeftButton")
  ns.MultiClick({ uniquevalue = "loaded\001rule" .. idx(Q) }, "LeftButton")
  IsControlKeyDown = saveCtrl
  ns.MultiMove(F2.id)
  check("D44 multi-select Move: the locked rule stays in its group", byUid(P.uid).folder == F1.id and Q.folder == F2.id, tostring(byUid(P.uid).folder) .. " / " .. tostring(Q.folder))
  ns.MultiReset()
  IsControlKeyDown = function() return true end
  ns.MultiClick({ uniquevalue = "loaded\001rule" .. idx(byUid(P.uid)) }, "LeftButton")
  ns.MultiClick({ uniquevalue = "loaded\001rule" .. idx(Q) }, "LeftButton")
  IsControlKeyDown = saveCtrl
  ns.MultiDelete()
  check("D44 multi-select Delete: the locked rule stays, the other goes", byUid(P.uid) ~= nil and idx(Q) == nil)
  ns.RecycleEmpty()
  byUid(P.uid).editLocked = nil
  -- double-click rename of a locked group
  F2.editLocked = true
  local b = CreateFrame("Button", nil, UIParent); b.uniquevalue = "loaded\001" .. F2.id
  ns.SidebarRename(b)
  check("D44 double-click rename: a locked group opens no name box", not (b.xuiRenameEB and b.xuiRenameEB:IsShown()))
  F2.editLocked = nil
  StaticPopup_Show = saveShow
end)

-------------------------------------------------------------------------------------------------------------------------------
section("D41", function()
  local p = byUid(P.uid)
  p.visual.enabled, p.sound.enabled = false, false   -- a cue-based rule: its displays are its cues
  local c = byUid(cue.uid); c.visual.enabled = true
  if ns.UI and ns.UI.Notify then pcall(ns.UI.Notify) end
  W.tick(0.1, 4)
  if ns.DecorateTrees then pcall(ns.DecorateTrees) end
  W.tick(0.1, 2)
  local lockBtn
  local function walk(f, d)
    if not f or d > 60 or lockBtn then return end
    local e = f.xuiEdit
    if type(e) == "table" and e.xuiObjs and e.IsShown and e:IsShown() and not e.xuiFolder then
      for _, o in ipairs(e.xuiObjs) do if o == byUid(cue.uid) or o == byUid(P.uid) then lockBtn = e end end
    end
    for _, ch in ipairs(f.GetChildren and { f:GetChildren() } or {}) do walk(ch, d + 1) end
  end
  walk(UIParent, 0)
  check("D41 the rule's sidebar row has its lock icon", lockBtn ~= nil)
  if lockBtn then
    lockBtn:GetScript("OnClick")(lockBtn)
    check("D41 the lock icon locks the rule itself", ns.IsEditLocked(byUid(P.uid)), tostring(byUid(P.uid).editLocked))
    for _, o in ipairs(lockBtn.xuiObjs or {}) do o.editLocked = nil end
    byUid(P.uid).editLocked = nil
  end
end)

-------------------------------------------------------------------------------------------------------------------------------
section("D47", function()
  CueRulesDB.ui.promptSave = true
  if ns.DraftsApplySetting then ns.DraftsApplySetting() end
  local p = byUid(P.uid)
  pcall(ns.ReselectRule, p)
  ns.SelectedRuleForUndo = function() return byUid(P.uid) end
  p.spellID = 6161; W.tick(0.05, 2)
  local fr = CreateFrame("Frame", nil, UIParent); fr:Show()
  local bar = ns.SaveBarUpdate(fr)
  local got
  local saveEH = geterrorhandler
  geterrorhandler = function() return function(e) got = e end end
  local saveFn = ns.DraftSave
  ns.DraftSave = function() error("audit save failure") end
  if bar and bar.btn and bar.btn.save then bar.btn.save:GetScript("OnClick")(bar.btn.save) end
  ns.DraftSave = saveFn; geterrorhandler = saveEH
  check("D47 the save bar is up for the changed rule", bar ~= nil and bar.rule ~= nil)
  check("D47 an error in Save changes reaches the error handler", got ~= nil and tostring(got):find("audit save failure", 1, true), tostring(got))
  CueRulesDB.ui.promptSave = nil
  if ns.DraftsApplySetting then ns.DraftsApplySetting() end
  p.spellID = 1001
end)


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
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    if os.environ.get("XUI_TEST_NOWINDOW"):
        L.execute("XUI_TEST_NOWINDOW = true")
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    bad = 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        print(("PASS " if ok else "FAIL ") + name)
        if not ok:
            bad += 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
