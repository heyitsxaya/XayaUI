#!/usr/bin/env python3
"""In-game QA walkthrough for debug batches W5 / W6 (XayaUI_DevAssist 0.7.65, XayaUI_DevAssist/QAWalks-debug-w5.lua; QA B291-B292;
issues #485, #479). Xaya's rule V22 (2026-11-07): "make sure every feature or significant change to the codebase / bug report fixes
have an in game qa test walk through with pre-fill confirmation options or data capturing".
Loads the real addons (with XayaUI Dev Assist) in the stand-in game, runs each step as a player would (Do it for me, then the check):
  - registered with pre-fill for B291-B292, the last step a Done step that cleans up;
  - step 1 (#485): the red X on the test cue: Pass, the note has the rule's cues, the bin's item and the condition's THEN list;
    negative: the cue put back in the rule by hand while its bin item stays (the "in both places" result) gives Fail;
  - step 2: before Restore: not tested (nil); after Do it for me (Restore): Pass, the note has the THEN list and "plays it now: yes";
    negative: the condition's THEN list emptied gives Fail;
  - step 3 (#479): Border ticked on the dynamic Centered-row group: Pass with the error counts in the note; negative: an error recorded
    after the tick gives Fail and its text is in the note;
  - Done: every tagged group, rule and bin item is gone (and a sidebar row on a moved place goes back to the list); your own data stays.
Run: python3 tests/qa_walks_debug_w5_run.py"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
local QA = rawget(_G, "XayaUI_DevQA")
local def = QA and QA.walks["debug-w5"]
check("the W5 walkthrough is registered with pre-fill, for B291-B292", def ~= nil and def.prefill == true and def.qa == "B291, B292")
if not def then return R end
check("its last step is a Done step", def.steps[#def.steps].done == true)
ns.Print = function() end
-- one rule and one bin item of her own, which the walkthrough must leave alone
local Mine = ns.NewRule(); Mine.name = "My rule"; Mine.enabled = true; ns.NormalizeRule(Mine); ns.rules[#ns.rules + 1] = Mine
local myItem = ns.RecycleRule((function() local x = ns.NewRule(); x.name = "My deleted rule"; ns.NormalizeRule(x); ns.rules[#ns.rules + 1] = x; return x end)())
local T = QA.DebugW5Test
local function run(i) local st = def.steps[i]; if st.setup then st.setup() end; W.tick(0.05, 8); return st.check() end

-- 1 the red X
local ok1, n1 = run(1)
check("step 1: the cue is only in the bin: Pass", ok1 == true, n1)
check("...the note has the rule's cues, the bin item and the condition's THEN list", tostring(n1):find("the rule's cues: none", 1, true) ~= nil
  and tostring(n1):find("Recycle Bin items of the test rule's cue: 1", 1, true) ~= nil and tostring(n1):find("THEN list: empty", 1, true) ~= nil, n1)
-- negative: the cue in the rule AND in the bin
local b = ns.RecycleDB()
local item; for _, it in ipairs(b.items) do if it.kind == "cue" then item = it end end
ns.rules[#ns.rules + 1] = item.rules[1]
local okN1, nN1 = def.steps[1].check()
check("negative: the cue in the rule and in the bin at once gives Fail", okN1 == false and tostring(nN1):find("Recycle Bin items of the test rule's cue: 1", 1, true) ~= nil, nN1)
table.remove(ns.rules)

-- 2 Restore
local ok0, n0 = def.steps[2].check()
check("step 2 before Restore: not tested yet (no verdict)", ok0 == nil, n0)
local ok2, n2 = run(2)
check("step 2 after Restore: back in the rule and the condition, plays: Pass", ok2 == true, n2)
check("...the note has the THEN list with the cue's key and 'plays it now: yes'", tostring(n2):find("THEN list: q1 (cue key q1)", 1, true) ~= nil
  and tostring(n2):find("plays it now: yes", 1, true) ~= nil, n2)
local k = T.Cond(); local saveThen = k.thenCues; k.thenCues = nil
local okN2, nN2 = def.steps[2].check()
check("negative: the condition no longer lists the cue gives Fail", okN2 == false, nN2)
k.thenCues = saveThen

-- 3 Border
local ok3, n3 = run(3)
local f = T.Folder("QA W5 border")
check("step 3: Border ticked on the dynamic Centered-row group, no error: Pass", ok3 == true and f and f.cType == "dynamic" and f.cGrowth == "HCENTER" and f.cSpacing == 4, n3)
check("...the note has the error counts", tostring(n3):find("error record: 0 before ticking, 0 now", 1, true) ~= nil, n3)
ns.RecordError("QA test error text", nil, "XayaUI_Rules", "XUI-E009")
local okN3, nN3 = def.steps[3].check()
check("negative: an error recorded after the tick gives Fail, with its text in the note", okN3 == false and tostring(nN3):find("QA test error text", 1, true) ~= nil, nN3)

-- Done
local okD = run(4)
local mineLive, mineBin = false, false
for _, r in ipairs(ns.rules) do if r == Mine then mineLive = true end end
for _, it in ipairs(ns.RecycleDB().items) do if it == myItem then mineBin = true end end
check("Done: every test group, rule and bin item is gone", okD == true)
check("Done: your own rule and bin item stay", mineLive and mineBin)
-- a second run starts clean (no second set of test data)
run(1); run(1)
local n = 0; for _, x in ipairs(ns.folders) do if x.name == "QA W5 bin" then n = n + 1 end end
check("a new run removes what an earlier run left (one test group, not two)", n == 1, n)
run(4)
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
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    bad = 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
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
