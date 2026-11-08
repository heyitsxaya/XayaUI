#!/usr/bin/env python3
"""The character pane split's in-game QA walkthrough (XayaUI_DevAssist 0.7.70, QAWalks-character-split.lua, QA E1z227; standing rule
V22, Xaya 2026-11-07: "make sure every feature or significant change to the codebase / bug report fixes have an in game qa test walk
through with pre-fill confirmation options or data capturing").
On the real addons in the stand-in game:
  - the walkthrough is registered with prefill = true;
  - every module on, XayaUI QoL off, XayaUI Blizzard Reskin off, XayaUI Bonus Features off: every step's check runs without a Lua
    error and says what it reads (with QoL off: "XayaUI QoL is off");
  - (stages 2-3) step 4 opens the Stat Calculator from Bonus Features (Do it for me) and says Pass; step 5 on a new install says nothing
    was copied (no verdict); step 6 (XayaUI QoL off) says Pass with QoL off, and to untick QoL while it is on; with Bonus Features off,
    step 4 says so;
  - the verdicts, on what QoL's count says (the "characterReskin" service's Drawn, set to each case): step 1 Pass with Blizzard Reskin
    off and item levels drawn, Fail with none drawn, no verdict (and what to do) while Blizzard Reskin is on; step 2 Pass with the look
    only, Fail when an item level is drawn; step 3 Pass with item levels back.
Negative control: on f870d78 the walkthrough does not exist (the registration check fails).
Run: python3 tests/qa_walk_character_split_run.py   (Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

LUA = r'''
return function(W, L, MODE)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { "[" .. MODE .. "] " .. name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.5, 10)
local ns = rawget(_G, "XayaUI_NS")
local QA = rawget(_G, "XayaUI_DevQA")
local def = QA and QA.walks and QA.walks["character-split"]
check("the walkthrough is registered, with prefill", def ~= nil and def.prefill == true and #def.steps >= 7, def and #def.steps)
if not def then return R end
for i, st in ipairs(def.steps) do
  if st.check then
    local ok, v, note = pcall(st.check)
    check(("step %d's check runs without an error and says what it reads"):format(i), ok and type(note) == "string" and note ~= "", ok and note or v)
    if MODE == "qol-off" and i <= 4 then check(("  ...step %d: XayaUI QoL off: no verdict, says so"):format(i), ok and v == nil and tostring(note):find("XayaUI QoL is off", 1, true) ~= nil, note) end
    if MODE == "qol-off" and i == 5 then check("  ...step 5: XayaUI QoL off: no verdict (nothing to compare)", ok and v == nil, note) end
    if MODE == "qol-off" and i == 6 then check("  ...step 6: XayaUI QoL off: Pass (no Character Toolkit page in Bonus Features, no Stat Calculator row, no error)", ok and v == true, note) end
    if MODE == "bonus-off" and i == 4 then check("  ...step 4: XayaUI Bonus Features off: no verdict, says so", ok and v == nil and tostring(note):find("XayaUI Bonus Features is off", 1, true) ~= nil, note) end
    if MODE == "all-on" and i == 6 then check("  ...step 6 with XayaUI QoL on: no verdict, says to untick it", ok and v == nil and tostring(note):find("still on", 1, true) ~= nil, note) end
  end
end
if MODE == "p5" then
  local v, note = def.steps[5].check()
  check("step 5 at the first login of a P5 install: Pass; copied from XayaUIQoLDB.characterToolkit, old / new values in the note", v == true
    and tostring(note):find("copied from XayaUIQoLDB.characterToolkit by XayaUI_Bonus", 1, true) ~= nil and tostring(note):find("side left/left", 1, true) ~= nil, note)
  return R
end
if MODE ~= "all-on" then return R end
-- (stage 2) the Stat Calculator opens from Bonus Features (Do it for me), once its switch is on
local sc = ns.Service("statCalc")
check("step 4 with Bonus Features > Character Toolkit off: no verdict, says to tick it", def.steps[4].check() == nil and tostring(select(2, def.steps[4].check())):find("is off", 1, true) ~= nil, select(2, def.steps[4].check()))
sc.Cfg().enabled = true; if ns.CharToolkit_Apply then ns.CharToolkit_Apply() end
def.steps[4].setup()
check("step 4: Do it for me opens the Stat Calculator: Pass, its tab and side in the note", def.steps[4].check() == true and tostring(select(2, def.steps[4].check())):find("panel open; tab stats", 1, true) ~= nil, select(2, def.steps[4].check()))
check("step 5 on a new install: no verdict, says nothing was copied", def.steps[5].check() == nil and tostring(select(2, def.steps[5].check())):find("no copy recorded", 1, true) ~= nil, select(2, def.steps[5].check()))
sc.Close()
-- the verdicts on given counts (QoL's own count stands in for the window: the stand-in game has no character window)
local real = ns.Service("characterReskin")
local D = {}
ns.Provide("characterReskin", { WideOn = real and real.WideOn, Drawn = function() return D end })
rawset(_G, "CharacterFrame", CreateFrame("Frame", "CharacterFrame", UIParent)); CharacterFrame:Show()
local function base(t) local d = { ilvl = 0, enchants = 0, sockets = 0, statList = false, look = false, features = true, reskinLoaded = true, tabOn = true, faded = 0 }
  for k, v in pairs(t) do d[k] = v end; return d end
local function V(i) local v, n = def.steps[i].check(); return v, n end
D = base({ reskinLoaded = false, ilvl = 16, enchants = 9, statList = true })
check("step 1: Blizzard Reskin off, item levels drawn: Pass, the counts in the note", V(1) == true and tostring(select(2, V(1))):find("item levels on 16 slots", 1, true) ~= nil, select(2, V(1)))
D = base({ reskinLoaded = false })
check("step 1: Blizzard Reskin off, nothing drawn: Fail", V(1) == false, select(2, V(1)))
D = base({ ilvl = 16 })
check("step 1: Blizzard Reskin still on: no verdict, says to switch it off", V(1) == nil and tostring(select(2, V(1))):find("still on", 1, true) ~= nil, select(2, V(1)))
D = base({ look = true, features = false, faded = 40 })
check("step 2: the look only: Pass", V(2) == true, select(2, V(2)))
D = base({ look = true, features = false, ilvl = 3 })
check("step 2: an item level drawn with QoL's switch off: Fail", V(2) == false, select(2, V(2)))
D = base({ look = true, features = true, ilvl = 16 })
check("step 3: item levels back: Pass", V(3) == true, select(2, V(3)))
CharacterFrame:Hide()
check("a step with the window closed: no verdict, says to open it", V(3) == nil and tostring(select(2, V(3))):find("open the character window", 1, true) ~= nil, select(2, V(3)))
return R
end
'''


P5 = {"XayaUI": {"CueRulesDB": {"characterToolkit": {"enabled": True, "side": "left", "fontSize": 13, "overlays": True}}},
      "XayaUI_QoL": {"XayaUIQoLDB": {"storeVersion": 1, "characterToolkit": {"enabled": True, "side": "left", "fontSize": 13, "overlays": True}}},
      "XayaUI_Bonus": {"XayaUIBonusDB": {"storeVersion": 1}}}


def run(mode, enabled_filter, saved=None):
    folders = H.find_addons()
    enabled = [n for n in folders if enabled_filter(n)]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": saved or {}}))
    res = L.eval("function(src, W, Ld, m) return loadstring(src)()(W, Ld, m) end")(LUA, world, loader, mode)
    out = [(res[i][1], res[i][2]) for i in range(1, len(res) + 1)]
    errs = [str(world.errors[i]) for i in range(1, len(world.errors) + 1)]
    return out, errs


def main():
    total = bad = 0
    errs_all = []
    for mode, filt in (("all-on", lambda n: True), ("qol-off", lambda n: n != "XayaUI_QoL"),
                       ("reskin-off", lambda n: n != "XayaUI_Reskin"), ("bonus-off", lambda n: n != "XayaUI_Bonus"), ("p5", lambda n: True)):
        out, errs = run(mode, filt, P5 if mode == "p5" else None)
        errs_all += errs
        for name, ok in out:
            total += 1
            bad += 0 if ok else 1
            print(("PASS " if ok else "FAIL ") + name)
    for e in errs_all:
        print("ERROR in the game stand-in:", e[:600])
    print("%d checks, %d failed, %d Lua errors" % (total, bad, len(errs_all)))
    sys.exit(1 if bad or errs_all else 0)


if __name__ == "__main__":
    main()
