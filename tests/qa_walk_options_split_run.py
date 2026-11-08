#!/usr/bin/env python3
"""The Options split's in-game QA walkthrough (XayaUI_DevAssist 0.7.56, QAWalks-options-split.lua, QA H13; platform split P3; standing
rule V22, Xaya 2026-11-07: "make sure every feature or significant change to the codebase / bug report fixes have an in game qa test
walk through with pre-fill confirmation options or data capturing").
Checks, on the real addons (Dev Assist on) in the stand-in game:
- both parts are registered with prefill = true;
- part 1: the window opens (verdict Pass, rows drawn); every top tab and every page of the feature tabs, Settings and Profiles is
  shown and draws rows (verdict Pass, the note lists at least the six top tabs); the test rule's Spell ID is changed through the
  editor's own box (verdict Pass); the undo step reads Fail until the spell is back and Pass once it is (Ctrl+Z is pressed by her;
  here the undo is called as the key would); the window closes (verdict Pass);
- the Nameplates step switches XayaUI Nameplates off for the next /reload (enable state 0);
- part 2's last step removes the test group and rule and switches Nameplates back on.
Negative control: on the code before P3 (Options 0.6.82) the walkthrough does not exist (the registration checks fail).
Run: python3 tests/qa_walk_options_split_run.py   (Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

# XayaUI_Nameplates is a QA-branch module, absent on main: presence is read from the folder
ROOT = os.path.dirname(HERE)
HAS_NP = os.path.isdir(os.path.join(ROOT, "XayaUI_Nameplates"))

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local HAS_NP = __HAS_NP__
local function skip(name) R[#R + 1] = { "SKIP (QA-branch module absent: XayaUI_Nameplates) " .. name, true, true } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local QA, ns = rawget(_G, "XayaUI_DevQA"), rawget(_G, "XayaUI_NS")
if not QA then check("Dev Assist QA framework", false); return R end
for _, id in ipairs({ "options-split", "options-split-reload" }) do
  local d = QA.walks[id]
  check(id .. ": registered with prefill", d ~= nil and d.prefill == true and #d.steps >= 2, d and d.prefill)
end
if not QA.walks["options-split"] then return R end
local function Run(id, i)
  local st = QA.walks[id].steps[i]
  local okS, errS = true, nil
  if st.setup then okS, errS = pcall(st.setup); W.tick(0.05, 2) end
  if not st.check then return okS, errS, true, nil, nil end
  local okC, v, note = pcall(st.check)
  return okS, errS, okC, v, note
end
local okS, errS, okC, v, n = Run("options-split", 1)
check("step 1: the window opens, rows drawn, no new error (verdict Pass)", okS and okC and v == true, tostring(errS) .. " " .. tostring(n))
okS, errS, okC, v, n = Run("options-split", 2)
local tops = 0
for _, k in ipairs({ "cooldowns=", "qol=", "bonus=", "reskin=", "profiles=", "set=" }) do if tostring(n):find(k, 1, true) then tops = tops + 1 end end
check("step 2: every top tab and page drew rows (verdict Pass)", okS and okC and v == true, tostring(errS) .. " " .. tostring(n))
check("  ...the note lists the six top tabs", tops == 6, n)
if HAS_NP then
  check("  ...and pages inside the feature tabs (QoL > Nameplates, Settings > Debugging)", tostring(n):find("qol>nameplates=", 1, true) and tostring(n):find("set>debug=", 1, true), n)
else
  skip("  ...and pages inside the feature tabs: QoL > Nameplates")
  -- absent-case: the module's page is not drawn at all, the others still are
  check("  ...and pages inside the feature tabs without XayaUI Nameplates (Settings > Debugging; no QoL > Nameplates page)", tostring(n):find("set>debug=", 1, true) and not tostring(n):find("qol>nameplates=", 1, true), n)
end
okS, errS, okC, v, n = Run("options-split", 3)
check("step 3: the test rule is open in the editor, selected in the left pane (verdict Pass)", okS and okC and v == true, tostring(errS) .. " " .. tostring(n))
W.tick(0.1, 3)
okS, errS, okC, v, n = Run("options-split", 4)
check("step 4: the test rule's Spell ID changed through the editor (verdict Pass)", okS and okC and v == true, tostring(errS) .. " " .. tostring(n))
local _, _, okU, vU, nU = Run("options-split", 5)
check("step 5 before the undo: verdict Fail (the spell is still the new one)", okU and vU == false, nU)
W.tick(0.6, 2)   -- the undo journal closes an edit's step half a second after it
local undid = ns.UndoKey and ns.UndoKey(false)
W.tick(0.05, 2)
_, _, okU, vU, nU = Run("options-split", 5)
check("step 5 after Ctrl+Z: the old spell is back (verdict Pass)", undid and okU and vU == true, tostring(undid) .. " " .. tostring(nU))
okS, errS, okC, v, n = Run("options-split", 6)
check("step 6: the window closes (verdict Pass)", okS and okC and v == true, tostring(errS) .. " " .. tostring(n))
okS, errS, okC, v, n = Run("options-split", 7)
if HAS_NP then
  check("step 7: XayaUI Nameplates is set to off for the next /reload", okS and okC and v == true and C_AddOns.GetAddOnEnableState("XayaUI_Nameplates") == 0, tostring(errS) .. " " .. tostring(n))
else
  skip("step 7: XayaUI Nameplates is set to off for the next /reload")
  -- absent-case (the step's own text: "if it is not installed ... this step says so"): the step refuses with that message and gives no verdict
  check("step 7 without XayaUI Nameplates: Do it for me says it is not loaded, and the check gives no verdict", okS == false and tostring(errS):find("XayaUI Nameplates is not loaded", 1, true) ~= nil and okC and v == nil, tostring(okS) .. " " .. tostring(errS) .. " " .. tostring(v))
end
local last = #QA.walks["options-split-reload"].steps
okS, errS, okC, v, n = Run("options-split-reload", last)
local left = 0
for _, r in ipairs(ns.rules or {}) do if r.qaOptSplit then left = left + 1 end end
for _, f in ipairs(ns.folders or {}) do if f.qaOptSplit then left = left + 1 end end
if HAS_NP then
  check("part 2 last step: test data gone and Nameplates switched back on (verdict Pass)", okS and okC and v == true and left == 0, tostring(errS) .. " " .. tostring(n))
else
  skip("part 2 last step: ...and Nameplates switched back on (verdict Pass)")
  check("part 2 last step without XayaUI Nameplates: the test group and rule are gone", okS and okC and left == 0 and tostring(n):find("test data gone", 1, true) ~= nil, tostring(errS) .. " " .. tostring(n))
end
return R
end
'''


def main():
    folders = H.find_addons()
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in folders}, "saved": {}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA.replace("__HAS_NP__", str(HAS_NP).lower()), world, loader)
    bad = 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        if res[i][3]:
            print(str(name))
            continue
        print(("PASS " if ok else "FAIL ") + str(name)[:900])
        if not ok:
            bad += 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
