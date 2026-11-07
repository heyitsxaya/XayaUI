#!/usr/bin/env python3
"""Function audit (UI-60, REQUEST-LOG A11; docs/process/FUNCTION-AUDIT-2026-11-07.md), core fixes in core 0.6.62.
- D18: a static group's saved arrangement re-applied 5 times leaves X / Y unchanged ("applying again changes nothing", Visual.lua).
  Old code: the centre was rounded, then X / Y rounded again: X, Y grew by 1 per apply (1, 2, 3, 4, 5) for 37x37 TOPLEFT displays.
- D19: Snap Target to a frame that does not exist keeps the display's X / Y and saves no snap ("the aura keeps its own position").
  Old code: X / Y were set to 0, 0 and the snap saved before the check.
Run: python3 tests/audit_core_run.py   (Lua 5.1 via lupa; the stand-in game in tests/harness)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local ns = rawget(_G, "XayaUI_NS")
local function mk(f, name, x, y, w, h, point)
  local r = ns.NewRule(); r.name = name; r.folder = f.id; r.enabled = true
  r.visual = r.visual or {}; r.visual.enabled = true; r.visual.x, r.visual.y = x, y; r.visual.w, r.visual.h = w, h
  r.visual.point = point
  ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
  return r
end
-- D18: three shapes that put a centre on a half pixel
local cases = {
  { "37x37 TOPLEFT, Align left + top, set 200x200 box", 37, 37, "TOPLEFT", 200, 200, "left", "top" },
  { "40x40 CENTER, Align right + bottom, set 201x201 box", 40, 40, nil, 201, 201, "right", "bottom" },
  { "37x41 TOPLEFT, Distribute + Space, set 300x100 box", 37, 41, "TOPLEFT", 300, 100, "distribute", "space" },
}
for _, c in ipairs(cases) do
  local f = ns.NewFolder("Arr " .. c[1]); f.cW, f.cH = c[5], c[6]
  local A, B, C = mk(f, "A", 0, 0, c[2], c[3], c[4]), mk(f, "B", 60, -10, c[2], c[3], c[4]), mk(f, "C", 130, 5, c[2], c[3], c[4])
  f.cArrX, f.cArrY = c[7], c[8]
  ns.ApplyGroupArrangement(f)
  local x1 = { A.visual.x, A.visual.y, B.visual.x, B.visual.y, C.visual.x, C.visual.y }
  local trail = {}
  for i = 1, 5 do ns.ApplyGroupArrangement(f); trail[#trail + 1] = A.visual.x .. "," .. A.visual.y .. "/" .. B.visual.x .. "," .. B.visual.y end
  local same = A.visual.x == x1[1] and A.visual.y == x1[2] and B.visual.x == x1[3] and B.visual.y == x1[4] and C.visual.x == x1[5] and C.visual.y == x1[6]
  check("D18 " .. c[1] .. ": 5 more applies change nothing", same, table.concat(trail, " "))
  check("D18 " .. c[1] .. ": X / Y stay whole numbers", A.visual.x % 1 == 0 and A.visual.y % 1 == 0 and C.visual.x % 1 == 0, x1[1] .. "," .. x1[2])
end
-- D18: Align left still lines up the left edges (the arrangement itself still works)
do
  local f = ns.NewFolder("Edges"); f.cW, f.cH = 200, 200
  local A, B = mk(f, "A", 3, 0, 37, 37, "TOPLEFT"), mk(f, "B", 40, -50, 37, 37, "TOPLEFT")
  f.cArrX = "left"; ns.ApplyGroupArrangement(f)
  check("D18 Align left: both left edges in line", A.visual.x == B.visual.x, A.visual.x .. " vs " .. B.visual.x)
end
-- D19: snap to a frame missing in this client
do
  local f = ns.NewFolder("Snap")
  local r = mk(f, "S", 37, -12, 40, 40)
  local saved = ns.Print; local said; ns.Print = function(m) said = m end
  ns.SnapToTarget(r, "nosuchframe_key", "TOP_CENTER")
  ns.Print = saved
  check("D19 missing frame: X / Y kept", r.visual.x == 37 and r.visual.y == -12, tostring(r.visual.x) .. "," .. tostring(r.visual.y))
  check("D19 missing frame: no snap saved", not (r.visual.snap and r.visual.snap.target), r.visual.snap and r.visual.snap.target)
  check("D19 missing frame: chat says it keeps its position", said and said:find("keeps its own position", 1, true), said)
end
-- D9 / D10: the talent scan
do
  local saveCT, saveTr, saveC = rawget(_G, "C_ClassTalents"), rawget(_G, "C_Traits"), rawget(_G, "Constants")
  C_ClassTalents = { InitializeViewLoadout = function() error("api changed") end, ViewLoadout = function() error("api changed") end }
  C_Traits = C_Traits or {}
  Constants = Constants or {}; Constants.TraitConsts = Constants.TraitConsts or { VIEW_TRAIT_CONFIG_ID = -3 }
  local good = { built = "old", classes = { [1] = { specs = {}, nodes = {} } }, errors = {} }
  XayaUITalentDB = good
  PlayerSpellsFrame = CreateFrame("Frame", "PlayerSpellsFrame", UIParent); PlayerSpellsFrame:Show()
  local ok, why = ns.ScanAllTalents()
  check("D9 talent window (PlayerSpellsFrame) open: the scan refuses", ok == false and tostring(why):find("Close the talent window", 1, true), why)
  PlayerSpellsFrame:Hide()
  local said; local sp = ns.Print; ns.Print = function(m) said = m end
  ok = ns.ScanAllTalents()
  W.tick(0.05, 30)
  ns.Print = sp
  check("D10 every class failed: the last good scan is kept", XayaUITalentDB == good, XayaUITalentDB and XayaUITalentDB.built)
  check("D10 the chat line says the previous scan is kept", said and said:find("previous scan is kept", 1, true), said)
  C_ClassTalents, C_Traits, Constants = saveCT, saveTr, saveC
end
-- D11 / FA-12: the minimap list row is "XayaUI Settings" and says it opens or closes
do
  local row
  for _, e in ipairs(ns.Launchers and ns.Launchers() or {}) do if e[1] == "settings" then row = e end end
  if not row and ns.launchers then for _, e in ipairs(ns.launchers) do if e[1] == "settings" then row = e end end end
  check("D11 minimap row named XayaUI Settings, tooltip says open or close", row and row[2] == "XayaUI Settings" and tostring(row[3]):find("Open or close", 1, true), row and row[2])
end
-- D54: On Initialization waits for the talent requirement and runs again after the player's own spec change
do
  local f = ns.NewFolder("Init")
  local r = mk(f, "InitRule", 0, 0, 40, 40)
  r.talentMode = "all"; r.talents = { { id = 987654 } }   -- a talent nobody knows: the requirement fails
  local inits = 0
  local orig = ns.RunActions
  ns.RunActions = function(rule, phase) if rule == r and phase == "init" then inits = inits + 1 end end
  local saveKnown = ns.ReadTalentKnown; ns.ReadTalentKnown = function(id) if id == 987654 then return false end return saveKnown and saveKnown(id) end
  if ns.InvalidateContext then ns.InvalidateContext() end
  W.tick(0.2, 10)
  check("D54 talent requirement fails: On Initialization does not run", inits == 0, inits)
  ns.ReadTalentKnown = function(id) if id == 987654 then return true end return saveKnown and saveKnown(id) end
  if ns.InvalidateContext then ns.InvalidateContext() end
  W.fire("SPELLS_CHANGED"); W.tick(0.2, 10)
  check("D54 talent requirement met: On Initialization runs once", inits == 1, inits)
  W.fire("PLAYER_SPECIALIZATION_CHANGED", "party1"); W.tick(0.2, 10)
  check("D54 a party member's spec change does not run it again", inits == 1, inits)
  W.fire("PLAYER_SPECIALIZATION_CHANGED", "player"); W.tick(0.2, 10)
  check("D54 the player's own spec change runs it again", inits == 2, inits)
  ns.RunActions = orig; ns.ReadTalentKnown = saveKnown
  r.enabled = false
end
-- D55: deleting a group on its own and restoring it brings back a rule that had no uid
do
  local g = ns.NewFolder("BinGroup")
  local r = ns.NewRule(); r.name = "plain"; r.folder = g.id; r.uid = nil; ns.rules[#ns.rules + 1] = r
  local it = ns.RecycleFolder(g)
  check("D55 the group's rule moved up a level", r.folder == g.parent, r.folder)
  local ok = it and ns.RecycleRestore(it.id)
  local back
  for _, x in ipairs(ns.folders) do if x.name == "BinGroup" then back = x end end
  check("D55 Restore brings the rule (no cue, no condition) back into the group", back and r.folder == back.id, tostring(r.folder) .. " / " .. tostring(back and back.id))
end
-- D27: the mover view's group name tab: a click selects the group for arrow-key nudges; a group locked for now does not drag
do
  local f = ns.NewFolder("TabTest"); f.cX, f.cY = 100, 50
  local A, B = mk(f, "TA", -60, 0, 40, 40), mk(f, "TB", 60, 0, 40, 40)
  ns.runtime = ns.runtime or {}; ns.runtime[A] = { active = true, lastPlay = 0, visualWanted = true }; ns.runtime[B] = { active = true, lastPlay = 0, visualWanted = true }
  ns.SetPreview({ A, B }, "visual", true); ns.RefreshAllVisuals(); W.tick(0.1, 2)
  ns.ToggleUnlock(); W.tick(0.1, 3)
  local tag = ns.GroupTagFor and ns.GroupTagFor(f.id)
  check("D27 the group has a name tab in the mover view", tag ~= nil)
  if tag then
    local other = A; ns.MoverSelect("display", other)
    tag:GetScript("OnMouseDown")(tag, "LeftButton")
    local saveDown = rawget(_G, "IsMouseButtonDown"); IsMouseButtonDown = function() return false end
    tag:GetScript("OnUpdate")(tag); IsMouseButtonDown = saveDown
    local y0, ax0 = f.cY, A.visual.y
    ns.MoverNudge(0, 1)
    check("D27 clicking the tab then nudging moves the group, not the display clicked before", f.cY == y0 + 1 and A.visual.y == ax0, f.cY .. " / " .. tostring(A.visual.y))
    ns.SetMoverTempLock(f, true)
    local x0 = f.cX
    local saveCur = GetCursorPosition
    tag:GetScript("OnMouseDown")(tag, "LeftButton")
    GetCursorPosition = function() return 1200, 700 end
    IsMouseButtonDown = function() return true end
    tag:GetScript("OnUpdate")(tag)
    IsMouseButtonDown = function() return false end
    tag:GetScript("OnUpdate")(tag)
    GetCursorPosition = saveCur; IsMouseButtonDown = saveDown
    check("D27 a group locked for now does not move when its tab is dragged", f.cX == x0, tostring(x0) .. " -> " .. tostring(f.cX))
    ns.SetMoverTempLock(f, false)
  end
  if ns.unlocked then ns.MoverExit("cancel") end
  ns.SetPreview({ A, B }, "visual", false)
  A.enabled, B.enabled = false, false
end
-- D8: every /xui word of a feature addon is listed, so with that addon off the command says which addon to turn on
do
  local want = { stats = "XayaUI_QoL", shop = "XayaUI_QoL", reskin = "XayaUI_QoL", releaseguard = "XayaUI_QoL", calc = "XayaUI_Bonus", calculator = "XayaUI_Bonus" }
  local bad = {}
  for w, a in pairs(want) do local m = ns.ModuleOfCommand and ns.ModuleOfCommand(w); if not (m and m.addon == a) then bad[#bad + 1] = w end end
  check("D8 /xui stats, shop, reskin, releaseguard, calc, calculator name their addon", #bad == 0, table.concat(bad, ","))
end
-- O-100 / FA-15 (Bonus 0.6.25, QoL 0.7.40; her answer "No word at all"): Notes, Calculator, Stat Calculator rows carry no on / off text;
-- the data panels row is named "Data Panels"
do
  local by = {}
  for _, e in ipairs(ns.Launchers()) do by[e[1]] = e end
  for _, k in ipairs({ "notes", "calc", "stats" }) do
    local e = by[k]
    check("O-100 minimap row '" .. k .. "' has no on / off text", e ~= nil and e[5] == nil, e and (e[5] and tostring(e[5]()) or "nil") or "no row")
  end
  check("O-100 minimap row 'data' is named Data Panels", by.data and by.data[2] == "Data Panels", by.data and by.data[2])
end
-- D57: a rule whose evaluation fails is recorded for /xui report; a cue migration that fails on one condition leaves it as it was
do
  local recs = {}
  local origRec = ns.RecordError
  ns.RecordError = function(msg, st, folder, code) recs[#recs + 1] = code .. " " .. tostring(msg) end
  local f = ns.NewFolder("ErrTest")
  local r = mk(f, "Broken", 0, 0, 40, 40)
  local origEval = ns.Evaluate
  ns.Evaluate = function(rule, ...) if rule == r then error("boom") end return origEval(rule, ...) end
  W.tick(0.2, 6)
  ns.Evaluate = origEval
  local got = false; for _, x in ipairs(recs) do if x:find("XUI-E010", 1, true) and x:find("Broken", 1, true) then got = true end end
  check("D57 an evaluation error is recorded (XUI-E010) for /xui report", got, table.concat(recs, " | "))
  r.enabled = false
  -- migration: a condition with both a sound and a display; the display's cue fails
  local parent = mk(f, "Parent", 0, 0, 40, 40); parent.uid = parent.uid or ns.NewUID()
  local child = ns.NewRule(); child.name = "Cond"; child.parentUid = parent.uid; child.sound = { enabled = true, file = "x" }; child.visual = { enabled = true }
  child.thenCues = { "keep" }
  ns.rules[#ns.rules + 1] = child
  local n0 = #ns.rules
  CueRulesDB.cuesVer = nil
  local origNew = ns.NewCueRule
  ns.NewCueRule = function(p, kind) if kind == "texture" then error("no texture") end return origNew(p, kind) end
  local ok = pcall(ns.MigrateCues)
  ns.NewCueRule = origNew
  local rec = false; for _, x in ipairs(recs) do if x:find("XUI-E011", 1, true) then rec = true end end
  check("D57 migration: the failing condition is recorded (XUI-E011) and the migration finishes once", ok and rec and CueRulesDB.cuesVer == 2, tostring(ok) .. " " .. tostring(CueRulesDB.cuesVer))
  check("D57 migration: the failing condition is left as it was (no new cue, its sound on, its THEN list back)", #ns.rules == n0 and child.sound.enabled == true and child.thenCues and child.thenCues[1] == "keep", #ns.rules - n0)
  ns.RecordError = origRec
end
-- D28: with "Estimate buffs the game hides in combat" off, the tracker leaves a hidden buff unknown (no seeded / linked estimate)
do
  local T, M = ns.AuraTracker, ns.AuraModel
  if T and M and T.Resolve and M.SetSetting then
    local was = M.PresenceEnabled()
    -- an exact read before combat: present, 60 s left (what step 3 of Resolve seeds from)
    T.Observe(987001, true, "test", { expiration = GetTime() + 60, duration = 60, instanceID = 4242 })
    local hOn, pOn = T.Resolve(987001)
    check("D28 (guard) with the estimate on, the seeded read answers present", hOn == true and pOn == true, tostring(hOn) .. "/" .. tostring(pOn))
    M.SetSetting("presence", false)
    local handled = T.Resolve(987001)
    check("D28 presence estimate off: Resolve leaves the buff unknown (no seeded estimate)", handled == false, handled)
    M.SetSetting("presence", was)
  else
    check("D28 tracker and model are loaded", false)
  end
end
-- D56: a rule taken out while active finishes what it started (After It Ends actions run, a During glow stops)
do
  local f = ns.NewFolder("EndTest")
  local r = mk(f, "Active", 0, 0, 40, 40)
  ns.runtime = ns.runtime or {}; ns.runtime[r] = { active = true, lastPlay = 0 }
  local fin = {}
  local orig = ns.RunActions
  ns.RunActions = function(rule, phase) if phase == "finish" then fin[rule] = (fin[rule] or 0) + 1 end end
  ns.RecycleRule(r)
  check("D56 deleting an active rule to the Recycle Bin runs its finish actions once", fin[r] == 1, fin[r])
  local r2 = mk(f, "Active2", 0, 0, 40, 40); ns.runtime[r2] = { active = true, lastPlay = 0 }
  ns.Share_ApplyRules({ v = 1, rules = {}, folders = {} }, "replace")
  check("D56 Load (replace) runs the finish actions of an active rule it swaps out", fin[r2] == 1, fin[r2])
  ns.RunActions = orig
end
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
