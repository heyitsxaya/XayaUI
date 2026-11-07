#!/usr/bin/env python3
"""The in-game QA walkthroughs for the settings-window audit fixes and FA-11 (XayaUI_DevAssist/QAWalks-audit-options.lua; standing rule
V22, Xaya 2026-11-07: "make sure every feature or significant change to the codebase / bug report fixes have an in game qa test walk
through with pre-fill confirmation options or data capturing").
On the real addons (Dev Assist on) in the stand-in game: the file is loaded the way the game would load it once it is in the toc (the
parent session adds it), every walkthrough is registered with prefill, every step runs in order without a Lua error, the verdicts the
stand-in can answer are Pass on the fixed code, and each last step leaves no QA test rule or group behind.
Run: python3 tests/qa_walks_audit_options_run.py   (Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L, path)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local QA, ns = rawget(_G, "XayaUI_DevQA"), rawget(_G, "XayaUI_NS")
if not QA then check("Dev Assist QA framework", false); return R end
local f, err = loadfile(path)
check("the walkthrough file loads", f ~= nil, err)
if not f then return R end
f("XayaUI_DevAssist", {})
ns.Print = function() end
local ids = { "audit-opt-load", "audit-opt-lock", "audit-opt-group", "audit-opt-bin", "audit-opt-inputs" }
local want = { ["audit-opt-load"] = { [1] = true, [3] = true }, ["audit-opt-group"] = { [1] = true, [2] = true, [3] = true },
  ["audit-opt-bin"] = { [1] = true, [2] = true, [3] = true, [4] = true }, ["audit-opt-inputs"] = { [1] = true, [2] = true, [3] = true, [4] = true },
  ["audit-opt-lock"] = { [4] = true } }
local mine = 0
for _, r in ipairs(ns.rules or {}) do mine = mine + 1 end
for _, id in ipairs(ids) do
  local d = QA.walks[id]
  check(id .. ": registered with prefill", d ~= nil and d.prefill == true and #d.steps >= 2, d and d.prefill)
  if d then
    for i, st in ipairs(d.steps) do
      local okS, errS = true, nil
      if st.setup then okS, errS = pcall(st.setup); W.tick(0.05, 2) end
      local okC, v, note = pcall(st.check)
      check(("%s step %d: Do it for me and the check run"):format(id, i), okS and okC, (not okS and errS) or (not okC and v) or "")
      if want[id] and want[id][i] then check(("%s step %d: verdict Pass"):format(id, i), okC and v == true, note) end
    end
  end
end
local left = 0
for _, r in ipairs(ns.rules or {}) do if r.qaAuditOpt then left = left + 1 end end
for _, fo in ipairs(ns.folders or {}) do if fo.qaAuditOpt then left = left + 1 end end
check("no QA test rule or group is left", left == 0, left)
check("the player's own rules are untouched (same count)", #ns.rules == mine, #ns.rules .. " vs " .. mine)

-- (Dev Assist 0.7.53, issue #485) audit-opt-bin across a /reload and with leftovers of an earlier run
local d = QA.walks["audit-opt-bin"]
local function S(i) local st = d.steps[i]; local okS, e = true, nil; if st.setup then okS, e = pcall(st.setup); W.tick(0.05, 2) end; local okC, v, n = pcall(st.check); return okS and okC, v, (not okS and e) or n end
-- leftovers: a tagged group and rule an earlier run left, a tagged Recycle Bin item, and the player's OWN group of the same name
local old = ns.NewFolder("QA audit options"); old.qaAuditOpt = true
local oldR = ns.NewRule(); oldR.name = "QA audit options rule"; oldR.folder = old.id; oldR.qaAuditOpt = true; ns.NormalizeRule(oldR); ns.rules[#ns.rules + 1] = oldR
local binR = ns.NewRule(); binR.name = "QA audit options rule"; binR.qaAuditOpt = true; ns.NormalizeRule(binR); ns.rules[#ns.rules + 1] = binR; ns.RecycleRule(binR)
local mineF = ns.NewFolder("QA audit options")
local mineR = ns.NewRule(); mineR.name = "my rule in a group with that name"; mineR.folder = mineF.id; ns.NormalizeRule(mineR); ns.rules[#ns.rules + 1] = mineR
local binN0 = #ns.RecycleItems()
local ok1, v1, n1 = S(1)
local tagged, oldLive, mineLive, mineRuleLive = 0, false, false, false
for _, fo in ipairs(ns.folders) do if fo.qaAuditOpt then tagged = tagged + 1 end; if fo == old then oldLive = true end; if fo == mineF then mineLive = true end end
for _, r in ipairs(ns.rules) do if r == mineR and r.folder == mineF.id then mineRuleLive = true end end
local oldInBin = false
for _, it in ipairs(ns.RecycleDB().items) do for _, r in ipairs(it.rules or {}) do if r.qaAuditOpt and r ~= nil and it.kind == "rule" then oldInBin = true end end end
check("#485 step 1 starts by removing an earlier run's tagged group, rule and Recycle Bin items: one test group, no old one", ok1 and v1 == true and tagged == 1 and not oldLive and not oldInBin, ("verdict %s; tagged groups %d; old live %s; old in bin %s; %s"):format(tostring(v1), tagged, tostring(oldLive), tostring(oldInBin), tostring(n1)))
check("#485 ...the player's own group of the same name and its rule are untouched (D35)", mineLive and mineRuleLive)
-- a /reload: the walkthrough file is read again (its memory is gone); every later step finds the test data by its tag
f("XayaUI_DevAssist", {}); d = QA.walks["audit-opt-bin"]
local ok2, v2, n2 = S(2)
check("#485 after a /reload, step 2 finds the cue in the Recycle Bin by its tag and restores it: Pass", ok2 and v2 == true, n2)
local ok3, v3, n3 = S(3)
check("#485 after a /reload, step 3 finds the test rule by its tag: Pass", ok3 and v3 == true, n3)
check("#485 step 2's text says Profiles > Recycle Bin (where the bin is now)", d.steps[2].text:find("Profiles > Recycle Bin", 1, true) ~= nil and not d.steps[2].text:find("Rules > Recycle Bin", 1, true))
check("#485 the last step is a clean-up step (Done, no verdict)", d.steps[4].done == true)
local ok4, v4, n4 = S(4)
local anyTagged = false
for _, it in ipairs(ns.RecycleDB().items) do for _, r in ipairs(it.rules or {}) do if r.qaAuditOpt then anyTagged = true end end; for _, fo in ipairs(it.folders or {}) do if fo.qaAuditOpt then anyTagged = true end end end
check("#485 after a /reload the clean-up still removes the test data and its Recycle Bin items (found by tag)", ok4 and v4 == true and not anyTagged, n4)
check("#485 ...the player's own group is still there", (function() for _, fo in ipairs(ns.folders) do if fo == mineF then return true end end return false end)())
-- a manual delete: the cue removed by hand (the red X) instead of Do it for me: step 1's check still reads it by tag
f("XayaUI_DevAssist", {}); d = QA.walks["audit-opt-bin"]
S(1)
local T = QA.AuditOptTest
check("#485 ...the test data is found by tag after step 1 (rule, condition; the cue in the bin)", T.Rule() ~= nil and T.Cond() ~= nil and T.Cue() == nil and T.BinCue() ~= nil)
T.Cleanup()
-- stale menu paths: no walkthrough text names a place that moved
local stale = {}
for _, id in ipairs(QA.list) do
  for i, st in ipairs(QA.walks[id].steps) do
    local t = tostring(st.text or "")
    for _, bad in ipairs({ "Rules > Recycle Bin", "Settings > Import / Export", "Settings > Chat)", "toolbar's Settings button" }) do
      if t:find(bad, 1, true) then stale[#stale + 1] = id .. " " .. i .. ": " .. bad end
    end
  end
end
check("no walkthrough text names Rules > Recycle Bin, Settings > Import / Export or other places that moved", #stale == 0, table.concat(stale, "; "))
return R
end
'''


def main():
    folders = H.find_addons()
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in folders}, "saved": {}}))
    path = os.path.join(os.path.dirname(HERE), "XayaUI_DevAssist", "QAWalks-audit-options.lua")
    res = L.eval("function(src, W, Ld, p) return loadstring(src)()(W, Ld, p) end")(LUA, world, loader, path)
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
