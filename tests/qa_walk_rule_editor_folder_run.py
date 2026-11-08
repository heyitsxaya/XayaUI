#!/usr/bin/env python3
"""The rule editor folder's in-game QA walkthrough (XayaUI_DevAssist 0.7.58, QAWalks-rule-editor-folder.lua, QA H15; platform split
P4b; standing rule V22, Xaya 2026-11-07: "make sure every feature or significant change to the codebase / bug report fixes have an in
game qa test walk through with pre-fill confirmation options or data capturing").
Runs both parts on the real addons (Dev Assist on) in the stand-in game, with the saved variables carried over the /reload:
- both parts are registered with prefill = true;
- part 1 (XayaUI Rules on): the AddOns entry reads XayaUI Rules Options (Pass); the window opens with the rule editor loaded and the
  Rules tab built (Pass); the QA rule opens selected in the Rules tab (Pass); its trigger spell changes (Pass); Ctrl+Z (the Do it for
  me undo) puts the spell back (Pass); the window closes, the QA rule is removed and XayaUI Rules is set to off (Pass);
- part 2 (after a /reload with XayaUI Rules off): the window opens without the Rules tab and neither XayaUI Rules nor XayaUI Rules
  Options is loaded (Pass); the tick-box step only reports what it counts (no verdict); XayaUI Rules set back on and the editor was
  never loaded (Pass).
Negative control: on the code before P4b the walkthrough does not exist (the registration checks fail) and there is no
XayaUI_Rules_Options addon.
Run: python3 tests/qa_walk_rule_editor_folder_run.py   (Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

COMMON = r'''
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
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
for _, id in ipairs({ "rule-editor-folder", "rule-editor-folder-off" }) do
  local d = QA.walks[id]
  check(id .. ": registered with prefill", d ~= nil and d.prefill == true and #d.steps >= 2, d and d.prefill)
end
if not QA.walks["rule-editor-folder"] then return R end
local okS, errS, okC, v, n = Run("rule-editor-folder", 1)
check("part 1 step 1: AddOns entry XayaUI Rules Options, not loaded before the window opened (verdict Pass)", okC and v == true and tostring(n):find("loaded now: false", 1, true), n)
okS, errS, okC, v, n = Run("rule-editor-folder", 2)
check("part 1 step 2: the window opens, the rule editor is loaded, the Rules tab is built (verdict Pass)", okS and okC and v == true, tostring(errS) .. " " .. tostring(n))
okS, errS, okC, v, n = Run("rule-editor-folder", 3)
check("part 1 step 3: the QA rule opens selected in the Rules tab (verdict Pass)", okS and okC and v == true, tostring(errS) .. " " .. tostring(n))
okS, errS, okC, v, n = Run("rule-editor-folder", 4)
check("part 1 step 4: the trigger spell changes (verdict Pass)", okS and okC and v == true, tostring(errS) .. " " .. tostring(n))
W.tick(0.1, 10)   -- the undo journal closes an edit's step half a second after it
okS, errS, okC, v, n = Run("rule-editor-folder", 5)
check("part 1 step 5: Ctrl+Z puts the trigger spell back (verdict Pass)", okS and okC and v == true, tostring(errS) .. " " .. tostring(n))
if ns.ToggleUI then pcall(ns.ToggleUI) end; W.tick(0.1, 3)   -- the player closes the window
okS, errS, okC, v, n = Run("rule-editor-folder", 6)
local left = 0
for _, r in ipairs(ns.rules or {}) do if r.qaRuleEditor then left = left + 1 end end
check("part 1 step 6: window closed, no error, QA rule removed, XayaUI Rules set to off (verdict Pass)",
  okS and okC and v == true and left == 0 and C_AddOns.GetAddOnEnableState("XayaUI_Rules") == 0, tostring(errS) .. " " .. tostring(n))
local _, errP = Run("rule-editor-folder-off", 1)
check("part 2 step 1 before the /reload: it asks for the /reload", tostring(errP):find("not reloaded yet", 1, true), errP)
return R
end
'''

PART2 = r'''
return function(W, L)
''' + COMMON + r'''
if not QA then check("Dev Assist QA framework", false); return R end
local okS, errS, okC, v, n = Run("rule-editor-folder-off", 1)
check("part 2 step 1: no Rules tab, neither XayaUI Rules nor its editor loaded (verdict Pass)", okS and okC and v == true, tostring(errS) .. " " .. tostring(n))
okS, errS, okC, v, n = Run("rule-editor-folder-off", 2)
check("part 2 step 2: the tick-box step reports without a verdict", okC and v == nil and tostring(n):find("tick boxes shown", 1, true), n)
okS, errS, okC, v, n = Run("rule-editor-folder-off", 3)
check("part 2 step 3: XayaUI Rules set back on, the editor never loaded (verdict Pass)", okS and okC and v == true and C_AddOns.GetAddOnEnableState("XayaUI_Rules") ~= 0, tostring(errS) .. " " .. tostring(n))
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
    r2, e2, _ = session(folders, every - {"XayaUI_Rules"}, s1, PART2)
    bad = 0
    for tag, res, errs in (("[part 1] ", r1, e1), ("[part 2] ", r2, e2)):
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
