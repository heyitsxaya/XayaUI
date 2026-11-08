#!/usr/bin/env python3
"""Recycle Bin: a cue, a condition, a trigger or a whole rule deleted in the rule editor, then restored (issue #485, Debug W5;
docs/process/audits/debug-triage-2026-11-08.md row #485). Xaya's walkthrough (2026-11-07, main f3fbc4b) read "cue still in the rule: true; in
the Recycle Bin: true" after the red X, then "the cue is back but the condition does not play it" after Restore.
Runs the real addons in the stand-in game across real /reloads (the stand-in logs out, the saved files are written, a new session loads
them, as the game does), on the real delete paths (the editor's red X on a cue / condition header, an additional trigger's red X, the
Cooldown trigger's Remove, the rule page's "Delete this rule") and the real Restore (ns.RecycleRestore, what the bin page's Restore runs).
Test data: rule P (Buff / Aura trigger) with sound cues A, B, C and two conditions made with the editor's "Add a condition" (no uid, as
in her data): K1 plays A and B (A with a modifier), K2 plays C and A. Rule Q: a Cooldown trigger, two additional triggers and a condition
that reads x2 and the Cooldown. Rule R: a cue and a condition. Every row carries a test tag (w5tag) so it is found again after a /reload.
Checked (each in one session and again across a /reload, with the rules in XayaUI Rules' own store XayaUIRulesDB, chain A: a fresh
install; chain B: saved data laid out as before P5 (rules in CueRulesDB), copied into XayaUIRulesDB at the first load):
  a  after a delete the item is in exactly one place, under the name it had in the rule: not in the rules (ns.rules, which is XayaUIRulesDB.rules), once in the bin
     (CueRulesDB.recycleBin); no condition of the rule still names a deleted cue (thenCues / thenMods); also in the saved files
  b  after Restore the rule's rows deep-equal what they were before the delete (the same rows in the same order, the conditions' THEN
     lists and modifiers as they were, a trigger back in its place and read by the same condition terms); the engine plays the restored
     cue (its sound fires when the buff is gained); the bin no longer holds it
  c  delete, /reload, the item is still only in the bin; Restore after the /reload: as b; one more /reload: still as before the delete
  d  a whole rule deleted and restored, in one session and across a /reload
Deep-equal compares every saved field of every row, with two exceptions that the delete itself (not the bin) makes and that change no
behaviour: a child row's uid (a condition gets one the first time the bin has to remember it) and a trigger order equal to the default
(an explicit trigOrder list is compared by what ns.TriggerSequence reads from it).
Also shown: why the walkthrough before Dev Assist 0.7.53 (c00811e) read "cue still in the rule: true": it looked the cue up by the uid
step 1 remembered, and a cue made by ns.NewCueRule has no uid, so the lookup matched the first rule that has none.
On 0f2cea4 (Rules 0.6.79) every check passes (regression guards: no data defect) except "the bin lists it under the name it had in the
rule": found while writing this test, the first of three sound cues went into the bin named "Sound 2" (fixed in Rules 0.6.80, RuleBin.lua
RecycleChild names the item before taking it out of the rules).
Run: python3 tests/recycle_bin_child_reload_run.py   (Lua 5.1 via lupa)."""
import copy, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

COMMON = r'''
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
ns.Print = function() end
-- the buff of rule P's trigger: present or not (stand-in aura reads)
AURAS = {}
C_UnitAuras.GetPlayerAuraBySpellID = function(id) return AURAS[id] end
C_UnitAuras.GetUnitAuraBySpellID = function(u, id) return AURAS[id] end
local function Buff(on) AURAS[5001] = on and { spellId = 5001, auraInstanceID = 51, applications = 0, expirationTime = 0, duration = 0 } or nil end
-- what plays when the buff is gained: the sounds the engine fires (W.sounds), counted per file
local function Plays()
  Buff(false); W.tick(0.2, 4); W.sounds = {}
  Buff(true); W.tick(0.2, 5)
  local n = {}
  for _, s in ipairs(W.sounds) do n[s] = (n[s] or 0) + 1 end
  return n
end
local function Tagged(tag) for _, r in ipairs(ns.rules) do if r.w5tag == tag then return r end end end
local function Rule(tag) local r = Tagged(tag); return r end
-- where a tagged row is: count in the rules (also read through the saved variable's own table) and in the bin
local function Where(tag)
  local live, saved, bin = 0, 0, 0
  for _, r in ipairs(ns.rules) do if r.w5tag == tag then live = live + 1 end end
  local SV = rawget(_G, "XayaUIRulesDB")
  for _, r in ipairs(SV and SV.rules or {}) do if r.w5tag == tag then saved = saved + 1 end end
  local b = ns.RecycleDB and ns.RecycleDB()
  for _, it in ipairs(b and b.items or {}) do for _, r in ipairs(it.rules or {}) do if r.w5tag == tag then bin = bin + 1 end end end
  return live, saved, bin
end
local function BinItem(kind, pred)
  local b = ns.RecycleDB and ns.RecycleDB()
  for _, it in ipairs(b and b.items or {}) do if it.kind == kind and pred(it) then return it end end
end
local function BinHasTag(tag) return function(it) for _, r in ipairs(it.rules or {}) do if r.w5tag == tag then return true end end; return false end end
local function BinW5Count()
  local b = ns.RecycleDB and ns.RecycleDB(); local n = 0
  for _, it in ipairs(b and b.items or {}) do
    local mine = it.kind == "trigger" and tostring(it.owner):find("^W5 ") ~= nil
    for _, r in ipairs(it.rules or {}) do if r.w5tag then mine = true end end
    if mine then n = n + 1 end
  end
  return n
end
-- every condition of rule p that still names cue key k (THEN list or modifier)
local function Refs(p, k)
  local n = 0
  for _, c in ipairs(ns.rules) do
    if c.parentUid == p.uid and not c.isCue then
      for _, x in ipairs(type(c.thenCues) == "table" and c.thenCues or {}) do if x == k then n = n + 1 end end
      if type(c.thenMods) == "table" and c.thenMods[k] ~= nil then n = n + 1 end
    end
  end
  return n
end
-- the rule's rows (the rule, then its cues and conditions in list order), written out with sorted keys
local function ser(v, out, skip)
  local t = type(v)
  if t == "table" then
    local keys = {}
    for k in pairs(v) do if not (skip and skip[k]) then keys[#keys + 1] = k end end
    table.sort(keys, function(a, b) return tostring(type(a)) .. tostring(a) < tostring(type(b)) .. tostring(b) end)
    out[#out + 1] = "{"
    for _, k in ipairs(keys) do out[#out + 1] = tostring(k) .. "="; ser(v[k], out); out[#out + 1] = "," end
    out[#out + 1] = "}"
  elseif t == "string" then out[#out + 1] = string.format("%q", v)
  else out[#out + 1] = tostring(v) end
end
local function Snap(tag)
  local p = Rule(tag); if not p then return "(no rule " .. tag .. ")" end
  local out = {}
  ser(p, out, { trigOrder = true }); out[#out + 1] = " trig=" .. table.concat(ns.TriggerSequence(p), ",") .. "\n"
  for _, r in ipairs(ns.rules) do
    if r.parentUid == p.uid then ser(r, out, { uid = true }); out[#out + 1] = "\n" end
  end
  return table.concat(out)
end
local function firstDiff(a, b)
  a, b = tostring(a), tostring(b)
  for i = 1, math.max(#a, #b) do if a:sub(i, i) ~= b:sub(i, i) then return ("at %d: was ...%s... now ...%s..."):format(i, a:sub(math.max(1, i - 60), i + 60), b:sub(math.max(1, i - 60), i + 60)) end end
  return "equal"
end
-- the settings window's tree: a rule's page, a node found by key, and the k-th cue / condition of a rule (k counts both, in list order)
local function find(node, key, depth)
  depth = depth or 0
  if type(node) ~= "table" or depth > 18 then return nil end
  local a = node.args
  if type(a) ~= "table" then return nil end
  if a[key] ~= nil then return a[key] end
  for _, c in pairs(a) do local hit = type(c) == "table" and find(c, key, depth + 1); if hit then return hit end end
end
local function RuleNode(r) local T = ns.BuildOptionsTable(); for i, x in ipairs(ns.rules) do if x == r then return find(T, "rule" .. i) end end end
local function ChildK(p, row) local k = 0; for _, r in ipairs(ns.rules) do if r.parentUid == p.uid then k = k + 1; if r == row then return k end end end end
-- the red X on a cue's / condition's header (OutcomesEditor.lua RemoveOutcome)
local function RedX(ptag, tag)
  local p, row = Rule(ptag), Tagged(tag)
  local k = ChildK(p, row)
  local node = find(RuleNode(p), (row.isCue and "oq" or "oc") .. k)
  local hdr = node and find(node, "hdr")
  assert(hdr and hdr.arg and hdr.arg.xuiActions, "the header of " .. tag .. " was not found")
  hdr.arg.xuiActions().del()
end
-- an additional trigger's red X (TriggersEditor.lua removeFn) and the Cooldown trigger's Remove (Editor.lua cdRemove)
local function TriggerX(ptag, j)
  local x = find(RuleNode(Rule(ptag)), "x" .. j)
  local th = x and (x.args.hdr or find(x, "hdr"))
  if th and th.arg and th.arg.xuiActions then th.arg.xuiActions().del() else find(x, "remove").func() end
end
local function CdRemove(ptag) find(RuleNode(Rule(ptag)), "cdRemove").func() end
-- the rule page's "Delete this rule" (Editor.lua; the sidebar's Delete runs the same ns.RecycleRule)
local function DeleteRule(ptag)
  local d = find(RuleNode(Rule(ptag)), "delete")
  assert(d and d.name == "Delete this rule", "the rule page's Delete was not found")
  d.func()
end
local function Restore(it) local ok, note = ns.RecycleRestore(it.id); W.tick(0.1, 2); return ok, note end
-- the Recycle Bin page's own Restore button for an item (XayaUI_Options/Options.lua, Profiles > Recycle Bin: one row per item, named
-- after it), in a fresh options tree
local function PageRestore(it)
  local T = ns.BuildOptionsTable()
  local page = T.args.profiles and T.args.profiles.args.bin
  local rows = 0
  local hit
  for _, row in pairs(page and page.args or {}) do
    if type(row) == "table" and row.args and row.args.restore then rows = rows + 1; if row.name == tostring(it.name) then hit = row.args.restore end end
  end
  assert(hit and rows == 1, "the bin page has no single row for " .. tostring(it.name) .. " (" .. rows .. " rows)")
  hit.func(); W.tick(0.1, 2)
end
'''

# session 0: make the test data (as the editor makes it), then /reload
S0 = r'''
return function(W, L)
''' + COMMON + r'''
local G = ns.NewFolder("W5 bin group")
local function NewRule(name, tag)
  local r = ns.NewRule(); r.name = name; r.folder = G.id; r.enabled = true; r.uid = ns.NewUID(); r.w5tag = tag
  r.load = { mode = "always" }
  ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
  return r
end
local function Cue(p, tag, file) local c = ns.NewCueRule(p, "sound"); c.sound.source, c.sound.value = "file", file; c.w5tag = tag; return c end
-- "Add a condition" on the rule's Conditions tab (OutcomesEditor.lua oAdd): the editor's own button
local function Cond(p, tag)
  local before = #ns.rules
  find(RuleNode(p), "oAdd").func()
  local c = ns.rules[#ns.rules]
  assert(#ns.rules == before + 1 and c.parentUid == p.uid, "Add a condition made no condition")
  c.w5tag = tag
  return c
end
local P = NewRule("W5 rule P", "P")
P.useBuff, P.buffID, P.buffState = true, 5001, "present"
local A, B, C = Cue(P, "A", "A.ogg"), Cue(P, "B", "B.ogg"), Cue(P, "C", "C.ogg")
local K1, K2 = Cond(P, "K1"), Cond(P, "K2")
K1.thenCues = { A.cueKey, B.cueKey }; K1.thenMods = { [A.cueKey] = { on = true, alpha = 0.5 } }
K2.thenCues = { C.cueKey, A.cueKey }
local Q = NewRule("W5 rule Q", "Q")
Q.useCooldown, Q.spellID, Q.cdState = true, 1001, "ready"
Q.extra = { list = { { type = "spellKnown", spellID = 3003, state = "yes" }, { type = "spellKnown", spellID = 3004, state = "yes" } } }
local QK = Cond(Q, "QK")
QK.when = { list = { { ref = "x2", neg = false, op = "and", cmp = "==", num = 0 }, { ref = "cd", neg = false, op = "and", cmp = "==", num = 0 } } }
local Rr = NewRule("W5 rule R", "R")
Rr.useBuff, Rr.buffID, Rr.buffState = true, 5001, "present"
local RC = Cue(Rr, "RC", "R.ogg"); local RK = Cond(Rr, "RK"); RK.thenCues = { RC.cueKey }
for _, r in ipairs(ns.rules) do if r.w5tag then ns.NormalizeRule(r) end end
ns.MarkDirty(); W.tick(0.1, 3)
local n = Plays()
check("(the test data: P's three cues and R's cue play when the buff is gained)", n["A.ogg"] == 1 and n["B.ogg"] == 1 and n["C.ogg"] == 1 and n["R.ogg"] == 1,
  ("A %s B %s C %s R %s"):format(tostring(n["A.ogg"]), tostring(n["B.ogg"]), tostring(n["C.ogg"]), tostring(n["R.ogg"])))
check("(the conditions made by Add a condition have no uid, as in her data)", K1.uid == nil and K2.uid == nil)
-- the old walkthrough's check (before c00811e): the cue looked up by the uid remembered in step 1
local remembered = A.uid
local function OldLive(list, uid) for _, r in ipairs(list) do if r.uid == uid then return r end end end
local without = {}; for _, r in ipairs(ns.rules) do if r ~= A then without[#without + 1] = r end end   -- the rules as they are once A is gone
check("why the old walkthrough read 'cue still in the rule: true': a cue made by ns.NewCueRule has no uid ...", remembered == nil)
local hit = OldLive(without, remembered)
check("  ...so with the cue gone, its lookup by that uid still finds a row (another row with no uid: here cue B)", hit ~= nil and hit == B, tostring(hit and hit.w5tag))
return R, {}
end
'''

# session 1: in one session (a, b, d), then the deletes that cross the /reload (c)
S1 = r'''
return function(W, L, PRE)
''' + COMMON + r'''
local SV = rawget(_G, "XayaUIRulesDB")
check("the rules are XayaUI Rules' own store (ns.rules is XayaUIRulesDB.rules)", SV and ns.rules == SV.rules)
check("(the test data is there after the /reload)", Rule("P") and Rule("Q") and Rule("R") and Tagged("A") and Tagged("K2"))
check("(the bin starts without test items)", BinW5Count() == 0, BinW5Count())
local preP, preQ, preR = Snap("P"), Snap("Q"), Snap("R")
local OUT = { P = preP, Q = preQ, R = preR }
local keyA = Tagged("A").cueKey

-- a / b: a cue
local labelA = ns.CueLabel(Tagged("A"))
RedX("P", "A")
local live, saved, bin = Where("A")
-- (found while writing this test) the bin item's name is the label the cue had in the rule: "Sound 1" for the first of three sound cues
-- (Rules 0.6.79 named it after the cue was already out of the rule, so the count ran over the other sound cues: "Sound 2")
local itA = BinItem("cue", BinHasTag("A"))
check("a cue red X: the bin lists it under the name it had in the rule (" .. tostring(labelA) .. ")", itA and itA.name == labelA, itA and itA.name)
check("a cue red X: not in the rules, not in XayaUIRulesDB, once in the bin", live == 0 and saved == 0 and bin == 1, ("live %d saved %d bin %d"):format(live, saved, bin))
check("a cue red X: no condition still names it (THEN list or modifier)", Refs(Rule("P"), keyA) == 0, Refs(Rule("P"), keyA))
local n = Plays()
check("a cue red X: it no longer plays (the other cues still do)", (n["A.ogg"] or 0) == 0 and n["B.ogg"] == 1 and n["C.ogg"] == 1, ("A %s B %s C %s"):format(tostring(n["A.ogg"]), tostring(n["B.ogg"]), tostring(n["C.ogg"])))
PageRestore(BinItem("cue", BinHasTag("A")))   -- (this one through the bin page's own Restore button)
live, saved, bin = Where("A")
check("b cue Restore (the bin page's Restore button): back in the rules, out of the bin", live == 1 and saved == 1 and bin == 0, ("live %d saved %d bin %d"):format(live, saved, bin))
check("b cue Restore: the rule deep-equals what it was before the delete (both conditions' THEN lists and the modifier)", Snap("P") == preP, firstDiff(preP, Snap("P")))
n = Plays()
check("b cue Restore: it plays again", n["A.ogg"] == 1, tostring(n["A.ogg"]))

-- a / b: a condition
RedX("P", "K1")
live, saved, bin = Where("K1")
check("a condition red X: in exactly one place (the bin)", live == 0 and saved == 0 and bin == 1, ("live %d saved %d bin %d"):format(live, saved, bin))
ok, note = Restore(BinItem("condition", BinHasTag("K1")))
check("b condition Restore: the rule deep-equals what it was before", ok and Snap("P") == preP, tostring(note) .. " " .. firstDiff(preP, Snap("P")))
n = Plays()
check("b condition Restore: its cues play", n["A.ogg"] == 1 and n["B.ogg"] == 1, ("A %s B %s"):format(tostring(n["A.ogg"]), tostring(n["B.ogg"])))

-- a / b: triggers
TriggerX("Q", 1)
local q = Rule("Q")
check("a trigger red X (additional trigger 1): it left the rule, the condition now reads the old x2 as x1", #q.extra.list == 1 and q.extra.list[1].spellID == 3004
  and Tagged("QK").when.list[1].ref == "x1", tostring(Tagged("QK").when.list[1].ref))
check("a trigger red X: once in the bin", BinItem("trigger", function(it) return it.owner == "W5 rule Q" end) ~= nil)
ok, note = Restore(BinItem("trigger", function(it) return it.owner == "W5 rule Q" end))
check("b trigger Restore: the rule deep-equals what it was before (trigger rows, order, the condition reads x2 again)", ok and Snap("Q") == preQ, tostring(note) .. " " .. firstDiff(preQ, Snap("Q")))
CdRemove("Q")
check("a Cooldown trigger Remove: the rule has no Cooldown trigger", not ns.CooldownUsed(Rule("Q")))
ok, note = Restore(BinItem("trigger", function(it) return it.owner == "W5 rule Q" and it.tok == "cd" end))
check("b Cooldown trigger Restore: the rule deep-equals what it was before", ok and Snap("Q") == preQ, tostring(note) .. " " .. firstDiff(preQ, Snap("Q")))

-- d: a whole rule
DeleteRule("R")
local l1, s1, b1 = Where("R"); local l2, s2, b2 = Where("RC"); local l3, s3, b3 = Where("RK")
check("d rule Delete: the rule, its cue and its condition are only in the bin", l1 + l2 + l3 + s1 + s2 + s3 == 0 and b1 == 1 and b2 == 1 and b3 == 1,
  ("rule %d/%d/%d cue %d/%d/%d cond %d/%d/%d"):format(l1, s1, b1, l2, s2, b2, l3, s3, b3))
n = Plays()
check("d rule Delete: its cue no longer plays", (n["R.ogg"] or 0) == 0)
ok, note = Restore(BinItem("rule", BinHasTag("R")))
check("d rule Restore: the rule deep-equals what it was before", ok and Snap("R") == preR, tostring(note) .. " " .. firstDiff(preR, Snap("R")))
n = Plays()
check("d rule Restore: its cue plays", n["R.ogg"] == 1, tostring(n["R.ogg"]))
check("(the bin holds no test items again)", BinW5Count() == 0, BinW5Count())

-- c: deletes that stay in the bin over the /reload (restored in the next session)
RedX("P", "A")
RedX("P", "K2")
TriggerX("Q", 1)
DeleteRule("R")
check("c four deletes are in the bin before the /reload", BinW5Count() == 4, BinW5Count())
return R, OUT
end
'''

# session 2: after the /reload: still only in the bin; Restore (the last delete first, as the bin lists them newest first)
S2 = r'''
return function(W, L, PRE)
''' + COMMON + r'''
local live, saved, bin = Where("A")
check("c after the /reload the cue is only in the bin", live == 0 and saved == 0 and bin == 1, ("live %d saved %d bin %d"):format(live, saved, bin))
live, saved, bin = Where("K2")
check("c after the /reload the condition is only in the bin", live == 0 and saved == 0 and bin == 1, ("live %d saved %d bin %d"):format(live, saved, bin))
live, saved, bin = Where("R")
check("c after the /reload the deleted rule is only in the bin", live == 0 and saved == 0 and bin == 1, ("live %d saved %d bin %d"):format(live, saved, bin))
check("c after the /reload no condition names the deleted cue", Refs(Rule("P"), "q1") == 0, Refs(Rule("P"), "q1"))
local n = Plays()
check("c after the /reload the deleted cues stay silent", (n["A.ogg"] or 0) == 0 and (n["R.ogg"] or 0) == 0 and n["B.ogg"] == 1)
local ok1 = Restore(BinItem("rule", BinHasTag("R")))
local ok2 = Restore(BinItem("trigger", function(it) return it.owner == "W5 rule Q" end))
local ok3 = Restore(BinItem("condition", BinHasTag("K2")))
local ok4, note4 = Restore(BinItem("cue", BinHasTag("A")))
check("c Restore after the /reload: all four ok", ok1 and ok2 and ok3 and ok4, tostring(note4))
check("c Restore after the /reload: rule P deep-equals what it was before the deletes", Snap("P") == PRE.P, firstDiff(PRE.P, Snap("P")))
check("c Restore after the /reload: rule Q deep-equals what it was before", Snap("Q") == PRE.Q, firstDiff(PRE.Q, Snap("Q")))
check("c Restore after the /reload: rule R deep-equals what it was before", Snap("R") == PRE.R, firstDiff(PRE.R, Snap("R")))
live, saved, bin = Where("A")
check("c Restore after the /reload: the cue is in the rules once, the bin has none of the test items", live == 1 and saved == 1 and bin == 0 and BinW5Count() == 0, BinW5Count())
n = Plays()
check("c Restore after the /reload: the restored cues play", n["A.ogg"] == 1 and n["C.ogg"] == 1 and n["R.ogg"] == 1,
  ("A %s C %s R %s"):format(tostring(n["A.ogg"]), tostring(n["C.ogg"]), tostring(n["R.ogg"])))
return R, {}
end
'''

# session 3: one more /reload: the restore was saved
S3 = r'''
return function(W, L, PRE)
''' + COMMON + r'''
check("c one more /reload: rule P still deep-equals what it was before the deletes", Snap("P") == PRE.P, firstDiff(PRE.P, Snap("P")))
check("c one more /reload: rule Q too", Snap("Q") == PRE.Q, firstDiff(PRE.Q, Snap("Q")))
check("c one more /reload: rule R too", Snap("R") == PRE.R, firstDiff(PRE.R, Snap("R")))
check("c one more /reload: no test item in the bin", BinW5Count() == 0, BinW5Count())
local n = Plays()
check("c one more /reload: the restored cue plays", n["A.ogg"] == 1, tostring(n["A.ogg"]))
return R, {}
end
'''


def session(src, saved, pre):
    folders = H.find_addons()
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in folders if k != "XayaUI_DevAssist"}, "saved": H.to_lua(L, saved)}))
    res, out = L.eval("function(src, W, Ld, pre) return loadstring(src)()(W, Ld, pre) end")(src, world, loader, H.to_lua(L, pre))
    sv, issues = loader.logout()
    results = [(res[i][1], res[i][2]) for i in range(1, len(res) + 1)]
    results.append(("the saved files can be written by the game" + ("" if len(issues) == 0 else "  [%s]" % issues[1]), len(issues) == 0))
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    return results, H.lua_to_py(sv), H.lua_to_py(out) if out else {}, errs


def rows(saved, addon, var):
    t = ((saved or {}).get(addon) or {}).get(var) or {}
    r = t.get("rules") if isinstance(t, dict) else None
    if isinstance(r, dict):
        r = [r[k] for k in sorted(r, key=lambda x: int(x))]
    return r or []


def bin_tags(saved):
    b = (((saved or {}).get("XayaUI") or {}).get("CueRulesDB") or {}).get("recycleBin") or {}
    items = b.get("items") or []
    if isinstance(items, dict):
        items = [items[k] for k in sorted(items, key=lambda x: int(x))]
    out = []
    for it in items:
        rs = it.get("rules") or []
        if isinstance(rs, dict):
            rs = list(rs.values())
        out += [r.get("w5tag") for r in rs if isinstance(r, dict) and r.get("w5tag")]
    return out


def pre_p5(saved):
    """The same saved data laid out as before P5: XayaUI Rules' keys inside CueRulesDB, no XayaUIRulesDB."""
    s = copy.deepcopy(saved)
    store = (s.get("XayaUI_Rules") or {}).pop("XayaUIRulesDB", None) or {}
    cdb = s.setdefault("XayaUI", {}).setdefault("CueRulesDB", {})
    for k in ("rules", "folders", "cuesVer", "bars", "barGroup"):
        if k in store:
            cdb[k] = store[k]
    return s


def main():
    bad, n, errs = 0, 0, []

    def report(label, results):
        nonlocal bad, n
        for name, ok in results:
            n += 1
            print(("PASS " if ok else "FAIL ") + label + ": " + name)
            if not ok:
                bad += 1

    def extra(label, ok, detail=""):
        report(label, [(detail if ok else detail, ok)])

    res, saved0, _, e = session(S0, {}, {})
    errs += e
    report("data", res)
    for chain, start in (("A fresh install", saved0), ("B pre-P5 saved data", pre_p5(saved0))):
        res, s1, pre, e = session(S1, start, {})
        errs += e
        report(chain + " session 1", res)
        if chain.startswith("B"):
            st = ((s1.get("XayaUI_Rules") or {}).get("XayaUIRulesDB") or {})
            extra(chain, st.get("migratedFrom") == "CueRulesDB" and len(rows(s1, "XayaUI_Rules", "XayaUIRulesDB")) > 0,
                  "the first load copied the rules from CueRulesDB into XayaUIRulesDB (migratedFrom = CueRulesDB)")
            old = [r.get("w5tag") for r in rows(s1, "XayaUI", "CueRulesDB")]
            extra(chain, old.count("A") == 1, "the old place (CueRulesDB.rules) is never written: it still holds the cue as before P5 (nothing reads it)")
        live = [r.get("w5tag") for r in rows(s1, "XayaUI_Rules", "XayaUIRulesDB")]
        tags = bin_tags(s1)
        for tag in ("A", "K2", "R", "RC", "RK"):
            extra(chain, live.count(tag) == 0 and tags.count(tag) == 1,
                  "the saved files after the deletes: %s is not in XayaUIRulesDB.rules and once in CueRulesDB.recycleBin (%d / %d)" % (tag, live.count(tag), tags.count(tag)))
        res, s2, _, e = session(S2, s1, pre)
        errs += e
        report(chain + " session 2 (after the /reload)", res)
        live = [r.get("w5tag") for r in rows(s2, "XayaUI_Rules", "XayaUIRulesDB")]
        extra(chain, all(live.count(t) == 1 for t in ("A", "K2", "R", "RC", "RK")) and not [t for t in bin_tags(s2) if t],
              "the saved files after Restore: each restored row once in XayaUIRulesDB.rules, none in the bin")
        res, s3, _, e = session(S3, s2, pre)
        errs += e
        report(chain + " session 3 (one more /reload)", res)
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (n, bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
