#!/usr/bin/env python3
"""Function audit, Theme page (core 0.6.62, Options 0.6.65). Her answers (REQUEST-LOG A11): FA-4 "Ask first" (switching throws your
own colors away), FA-5 / FA-8 "1 or add as name (1) name (2) etc" then "Replace, Save As Copy, Cancel" (a name already saved),
FA-13 "Reword to Class colors (Recommended)"; audit rows D5 (import with a name changed the theme before checking the name), D6 (Save
replaced a saved theme silently), D7 (picking another theme wiped your colors without a word).
Checks, on the real addons in the stand-in game:
- Save refuses a name that is already saved unless told to replace; Save As Copy names it "Name (1)", then "Name (2)";
- Import with a refused name, or a saved name without replace, changes neither the current theme nor the saved one;
- your own colors count as unsaved until they match a saved theme;
- the Theme page: picking another theme with unsaved colors shows the ask dialog (Discard / Cancel) and changes nothing until Discard;
  Cancel keeps them; Save with an existing name shows Replace / Save As Copy / Cancel in that order and each does what it says;
  Reset everything's text names Class colors.
Old code: no T.CheckName / T.CopyName / T.UnsavedColors / T.Ask: those checks fail; Save replaced silently.
Run: python3 tests/theme_audit_run.py   (Lua 5.1 via lupa)."""
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
local ns = rawget(_G, "XayaUI_NS"); local T = ns.Theme
check("core has the new theme helpers", T.CheckName and T.CopyName and T.UnsavedColors and T.SavedExists)
if not (T.CheckName and T.CopyName and T.UnsavedColors) then return R end
local th = CueRulesDB.theme
-- Save / copy names (D6, FA-8)
T.SetBase("default"); T.SetToken("accent", { 1, 0, 0, 1 })
local ok, n = T.Save("Mine")
check("Save a new name works", ok == true and n == "Mine" and CueRulesDB.themes.Mine ~= nil, n)
local before = CueRulesDB.themes.Mine.tokens.accent[2]
T.SetToken("accent", { 0, 1, 0, 1 })
ok, n = T.Save("Mine")
check("D6 Save with a name already saved is refused (\"exists\") and the saved theme is unchanged", ok == false and n == "exists" and CueRulesDB.themes.Mine.tokens.accent[2] == before, n)
check("FA-8 the copy name is \"Mine (1)\"", T.CopyName("Mine") == "Mine (1)", T.CopyName("Mine"))
T.Save("Mine (1)")
check("FA-8 ...then \"Mine (2)\"", T.CopyName("Mine") == "Mine (2)", T.CopyName("Mine"))
ok = T.Save("Mine", true)
check("Replace saves over it", ok == true and CueRulesDB.themes.Mine.tokens.accent[2] == 1)
-- Import checks the name first (D5)
local str = T.Export()
T.SetToken("accent", { 0, 0, 1, 1 })
local cur = th.tokens.accent[3]
ok, n = T.Import(str, "class")
check("D5 import with a built-in name: refused, current theme unchanged", ok == false and th.tokens.accent[3] == cur, n)
local savedB = CueRulesDB.themes.Mine.tokens.accent[2]
ok, n = T.Import(str, "Mine")
check("D5 import with a saved name and no replace: \"exists\", nothing changed", ok == false and n == "exists" and th.tokens.accent[3] == cur and CueRulesDB.themes.Mine.tokens.accent[2] == savedB, n)
ok = T.Import(str, "Fresh")
check("import with a new name applies and saves", ok == true and CueRulesDB.themes.Fresh ~= nil)
-- unsaved colors (FA-4)
T.Load("Mine")
check("FA-4 colors identical to a saved theme are not unsaved", T.UnsavedColors() == false)
T.SetToken("accent", { 0.3, 0.3, 0.3, 1 })
check("FA-4 a changed color is unsaved", T.UnsavedColors() == true)
-- the Theme page
if ns.LoadOptions then ns.LoadOptions() end
W.tick(0.1, 2)
local args = T.BuildArgs and T.BuildArgs(function() end)
check("the Theme page builds with the ask dialog", args ~= nil and T.Ask ~= nil)
if args and T.Ask then
  local baseNow = th.base
  args.base.set(nil, "light")
  local dlg = rawget(_G, "XayaUIThemeAsk")
  check("FA-4 picking another theme with unsaved colors asks first and changes nothing yet", dlg and dlg:IsShown() and th.base == baseNow and th.tokens.accent[1] == 0.3, th.base)
  check("FA-4 ...the buttons read Discard / Cancel", dlg and dlg.btns[1]:GetText() == "Discard" and dlg.btns[2]:IsShown() and not dlg.btns[3]:IsShown(), dlg and dlg.btns[1]:GetText())
  dlg.btns[2]:GetScript("OnClick")(dlg.btns[2])
  check("FA-4 Cancel keeps your colors and the theme", th.base == baseNow and th.tokens.accent and th.tokens.accent[1] == 0.3 and not dlg:IsShown())
  args.base.set(nil, "light"); dlg.btns[1]:GetScript("OnClick")(dlg.btns[1]); W.tick(0.05, 2)
  check("FA-4 Discard switches", th.base == "light", th.base)
  -- Save with an existing name (FA-8)
  T.SetToken("accent", { 0.9, 0.1, 0.1, 1 })
  args.saveName.set(nil, "Mine"); args.save.func()
  check("FA-8 Save with an existing name asks: Replace / Save As Copy / Cancel, in that order",
    dlg:IsShown() and dlg.btns[1]:GetText() == "Replace" and dlg.btns[2]:GetText() == "Save As Copy" and dlg.btns[3]:IsShown(), dlg.btns[1]:GetText() .. "/" .. dlg.btns[2]:GetText())
  local mineBefore = CueRulesDB.themes.Mine.tokens.accent[1]
  dlg.btns[3]:GetScript("OnClick")(dlg.btns[3])
  check("FA-8 Cancel saves nothing", CueRulesDB.themes.Mine.tokens.accent[1] == mineBefore)
  args.save.func(); dlg.btns[2]:GetScript("OnClick")(dlg.btns[2])
  check("FA-8 Save As Copy saves \"Mine (2)\" and leaves Mine alone", CueRulesDB.themes["Mine (2)"] ~= nil and CueRulesDB.themes.Mine.tokens.accent[1] == mineBefore)
  args.save.func(); dlg.btns[1]:GetScript("OnClick")(dlg.btns[1])
  check("FA-8 Replace saves over Mine", math.abs(CueRulesDB.themes.Mine.tokens.accent[1] - 0.9) < 0.001, CueRulesDB.themes.Mine.tokens.accent[1])
  check("FA-13 Reset everything names Class colors", tostring(args.resetPal.desc):find("Class colors", 1, true) ~= nil, args.resetPal.desc)
  T.SetToken("accent", { 0.2, 0.2, 0.8, 1 })
  args.resetPal.func()
  check("FA-13 Reset with unsaved colors asks first", dlg:IsShown() and th.tokens.accent ~= nil)
  dlg.btns[1]:GetScript("OnClick")(dlg.btns[1])
  check("FA-13 ...Discard resets to Class colors", th.base == "class" and next(th.tokens) == nil, th.base)
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
