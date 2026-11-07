#!/usr/bin/env python3
"""In-game QA walkthrough for the settings window's new top level (XayaUI_DevAssist 0.7.31, QAWalks-profiles.lua; Options 0.6.71,
REQUEST-LOG UI-23 to UI-27; QA H6 to H9). Standing rule V22 (Xaya 2026-11-07): every change lands with an in-game walkthrough with
pre-fill. Checks, on the real addons in the stand-in game: the walkthrough is registered with prefill on and every step has a check or is
a question (noVerdict); its checks give the right verdict: the top tabs and no toolbar (Rules open, then Settings open), + New Rule at
the left end of the Rules row, the Profiles sub-tabs, the Settings-only profile round trip (the changed Selection style comes back), the
Recycle Bin sub-tab; the last step puts the Selection style back. Negative control: QAWalks-profiles.lua does not exist on main 7b830cf.
Run: python3 tests/qa_walks_profiles_run.py   (Lua 5.1 via lupa; slow)."""
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
local QA = rawget(_G, "XayaUI_DevQA")
local ns = rawget(_G, "XayaUI_NS")
check("Dev Assist has the QA walkthroughs", QA and QA.walks ~= nil)
if not QA then return R end
local w = QA.walks["settings-toplevel"]
local okSteps = w ~= nil
for _, st in ipairs(w and w.steps or {}) do if not (type(st.check) == "function" or st.noVerdict) then okSteps = false end end
check("settings-toplevel: registered, pre-fill on, every step has a check or is a question", w ~= nil and w.prefill == true and okSteps)
if not w then return R end
local function step(i, setup)
  local st = w.steps[i]
  if not st then return false, "no step" end
  if setup and st.setup then st.setup(); W.tick(0.2, 4) end
  if not st.check then return nil, "question" end
  local ok, a, b = pcall(st.check)
  if not ok then return false, "error: " .. tostring(a) end
  return a, b
end
local function stepCheck(name, i, want)
  local v, note = step(i, true)
  check(name .. "  (" .. tostring(note) .. ")", (v and true or false) == (want ~= false), note)
end
local db = CueRulesDB
db.ui = db.ui or {}
db.ui.selStyle = "text"
stepCheck("1: Rules open: the six top tabs, no toolbar", 1)
stepCheck("2: Settings open: the six top tabs stay", 2)
stepCheck("3: + New Rule at the left end of the Rules row", 3)
check("4: clicking + New Rule is a question for her", w.steps[4].noVerdict == true)
stepCheck("5: Profiles: Import, Export, Recycle Bin; six components", 5)
stepCheck("6: a Settings-only profile brings the Selection style back", 6)
check("  ...it really is back", db.ui.selStyle == "text", db.ui.selStyle)
stepCheck("7: Profiles > Recycle Bin opens", 7)
db.ui.selStyle = "bar"
w.steps[8].setup()
check("8: the last step puts the Selection style back", db.ui.selStyle == "text", db.ui.selStyle)
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
