#!/usr/bin/env python3
"""The code move's in-game QA walkthrough (XayaUI_DevAssist 0.7.57, QAWalks-code-move.lua, QA H14; platform split P4; standing rule
V22, Xaya 2026-11-07: "make sure every feature or significant change to the codebase / bug report fixes have an in game qa test walk
through with pre-fill confirmation options or data capturing").
Runs the three parts on the real addons (Dev Assist on) in the stand-in game, with the saved variables carried over each /reload:
- the three parts are registered with prefill = true;
- part 1 (XayaUI Rules on): the AddOns titles read XayaUI Platform / XayaUI Rules (Pass); the QA rule on a buff you have shows its icon
  cue (Pass); the rule shared and imported again gives a second copy with its cue (Pass); deleted to the Recycle Bin and restored
  (Pass); XayaUI Rules set to off for the next /reload;
- part 2 (after a /reload with XayaUI Rules off): not loaded and no XayaUI error since login (Pass); the settings window has no Rules
  tab and no Rule Creation tab and every other tab draws (Pass); /xui status prints "... part of XayaUI Rules, which is switched off"
  (Pass); Profiles offers no "Rules and groups" part and no backups (Pass); XayaUI Rules set back on;
- part 3 (after a /reload with it on): the QA rule is back and its icon shows (Pass); the last step removes the QA data.
- the checks also say Fail when the thing is not there (part 2's first check before the /reload says "not reloaded yet").
Negative control: on the code before P4 the walkthrough does not exist (the registration checks fail), and there is no XayaUI Rules.
Run: python3 tests/qa_walk_code_move_run.py   (Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

COMMON = r'''
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
-- a buff on the player (the stand-in has none): spell 1459, readable out of combat
local BUFF = { spellId = 1459, name = "Arcane Intellect", auraInstanceID = 77, applications = 0, duration = 3600, expirationTime = GetTime() + 3600, icon = 135932 }
C_UnitAuras = C_UnitAuras or {}
C_UnitAuras.GetAuraDataByIndex = function(unit, i, f) if unit == "player" and i == 1 then return BUFF end end
C_UnitAuras.GetPlayerAuraBySpellID = function(id) if id == 1459 then return BUFF end end
local realUnit = C_UnitAuras.GetUnitAuraBySpellID
C_UnitAuras.GetUnitAuraBySpellID = function(unit, id) if unit == "player" and id == 1459 then return BUFF end; return realUnit and realUnit(unit, id) end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local QA, ns = rawget(_G, "XayaUI_DevQA"), rawget(_G, "XayaUI_NS")
local function Run(id, i)
  local st = QA.walks[id].steps[i]
  local okS, errS = true, nil
  if st.setup then okS, errS = pcall(st.setup); W.tick(0.1, 20) end
  if not st.check then return okS, errS, true, nil, nil end
  local okC, v, note = pcall(st.check)
  return okS, errS, okC, v, note
end
'''

PART1 = r'''
return function(W, L)
''' + COMMON + r'''
if not QA then check("Dev Assist QA framework", false); return R end
for _, id in ipairs({ "code-move", "code-move-off", "code-move-on" }) do
  local d = QA.walks[id]
  check(id .. ": registered with prefill", d ~= nil and d.prefill == true and #d.steps >= 2, d and d.prefill)
end
if not QA.walks["code-move"] then return R end
local okS, errS, okC, v, n = Run("code-move", 1)
check("part 1 step 1: AddOns titles XayaUI Platform / XayaUI Rules (verdict Pass)", okC and v == true, n)
okS, errS, okC, v, n = Run("code-move", 2)
check("part 1 step 2: the QA rule on a buff you have shows its icon cue (verdict Pass)", okS and okC and v == true, tostring(errS) .. " " .. tostring(n))
okS, errS, okC, v, n = Run("code-move", 3)
check("part 1 step 3: shared and imported again: a second copy with its cue (verdict Pass)", okS and okC and v == true, tostring(errS) .. " " .. tostring(n))
okS, errS, okC, v, n = Run("code-move", 4)
check("part 1 step 4: the copy deleted to the Recycle Bin and restored (verdict Pass)", okS and okC and v == true, tostring(errS) .. " " .. tostring(n))
okS, errS, okC, v, n = Run("code-move", 5)
check("part 1 step 5: XayaUI Rules set to off for the next /reload", okS and okC and v == true and C_AddOns.GetAddOnEnableState("XayaUI_Rules") == 0, tostring(errS) .. " " .. tostring(n))
local _, _, okP, vP, nP = Run("code-move-off", 1)
check("part 2 step 1 before the /reload: no verdict, it asks for the /reload", okP and vP == nil and tostring(nP):find("not reloaded yet", 1, true), nP)
return R
end
'''

PART2 = r'''
return function(W, L)
''' + COMMON + r'''
if not QA then check("Dev Assist QA framework", false); return R end
check("after the /reload: XayaUI Rules is not loaded", not C_AddOns.IsAddOnLoaded("XayaUI_Rules"))
local okS, errS, okC, v, n = Run("code-move-off", 1)
check("part 2 step 1: not loaded, no XayaUI error since login (verdict Pass)", okC and v == true, tostring(errS) .. " " .. tostring(n))
okS, errS, okC, v, n = Run("code-move-off", 2)
check("part 2 step 2: no Rules tab, no Rule Creation tab, every other tab draws (verdict Pass)", okS and okC and v == true, tostring(errS) .. " " .. tostring(n))
okS, errS, okC, v, n = Run("code-move-off", 3)
check("part 2 step 3: /xui status says it is part of XayaUI Rules, switched off (verdict Pass)", okS and okC and v == true, tostring(errS) .. " " .. tostring(n))
okS, errS, okC, v, n = Run("code-move-off", 4)
check("part 2 step 4: Profiles offers no Rules and groups part and no backups (verdict Pass)", okS and okC and v == true, tostring(errS) .. " " .. tostring(n))
okS, errS, okC, v, n = Run("code-move-off", 5)
check("part 2 step 5: XayaUI Rules set back on", okS and okC and v == true and C_AddOns.GetAddOnEnableState("XayaUI_Rules") ~= 0, tostring(errS) .. " " .. tostring(n))
return R
end
'''

PART3 = r'''
return function(W, L)
''' + COMMON + r'''
if not QA then check("Dev Assist QA framework", false); return R end
local okS, errS, okC, v, n = Run("code-move-on", 1)
check("part 3 step 1: XayaUI Rules back, the QA rule kept and its icon shows (verdict Pass)", okC and v == true, tostring(errS) .. " " .. tostring(n))
okS, errS, okC, v, n = Run("code-move-on", 2)
local left = 0
for _, r in ipairs(ns.rules or {}) do if r.qaCodeMove then left = left + 1 end end
check("part 3 last step: the QA rules are gone (verdict Pass)", okS and okC and v == true and left == 0, tostring(errS) .. " " .. tostring(n))
return R
end
'''


def session(folders, enabled, saved, src):
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": saved}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(src, world, loader)
    out = [(res[i][1], res[i][2]) for i in range(1, len(res) + 1)]
    errs = [str(world.errors[i]) for i in range(1, len(world.errors) + 1)]
    saved_out, _ = loader.logout()
    return out, errs, H.lua_to_py(saved_out)


def main():
    folders = H.find_addons()
    every = set(folders)
    results, errs_all = [], []
    r1, e1, s1 = session(folders, every, {}, PART1)
    r2, e2, s2 = session(folders, every - {"XayaUI_Rules"}, s1, PART2)
    s2 = dict(s2)
    if "XayaUI_Rules" in s1:   # (the game keeps a switched-off addon's saved file as it was)
        s2["XayaUI_Rules"] = s1["XayaUI_Rules"]
    r3, e3, _ = session(folders, every, s2, PART3)
    bad = 0
    for tag, res, errs in (("[part 1] ", r1, e1), ("[part 2] ", r2, e2), ("[part 3] ", r3, e3)):
        for name, ok in res:
            print(("PASS " if ok else "FAIL ") + tag + str(name)[:900])
            if not ok:
                bad += 1
        for e in errs:
            print("ERROR in the game stand-in " + tag + str(e)[:600])
        errs_all += errs
        results += res
    print("%d checks, %d failed, %d Lua errors" % (len(results), bad, len(errs_all)))
    sys.exit(1 if bad or errs_all else 0)


if __name__ == "__main__":
    main()
