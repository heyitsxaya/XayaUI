#!/usr/bin/env python3
"""The settings window's two halves are 60% opaque (Options 0.6.114). Xaya, 2026-11-24 (REQUEST-LOG SD-154): "rules pane should have
more opacity in the core rule box"; her answers (SD-155): "60%" and "Both left and right hand sides (center of the addon)".
Before: each half's own fill was the window opacity x 0.6 (37% at the default 62%), so the game showed clearly through the rule list.
Loads the real addons in the stand-in game, opens the settings window and reads what the game would draw: the fill colour of the
left half (the sidebar list) and the right half (the page) of every sidebar tree on screen. Checks:
  1. at the default window opacity both halves are filled at 60%, the same on each side, and the window itself stays at 62%;
  2. the fill follows the window opacity in the same proportion (Theme > window opacity, /xuiskin alpha, SD-152's slider):
     window 31% -> halves 30%; window 100% -> halves 97% (100 x 60 / 62); an out-of-range saved 150% -> capped at 100%;
  3. a released tree widget goes back to AceGUI's own colors (nothing of the skin leaks into another addon's AceGUI window).
Negative control: on Options 0.6.113 (A() x 0.6) check 1 fails (0.372); a half drawn in another color (the independent
reviewer's break: the left half white) fails its near-black check.
Run: python3 tests/pane_fill_opacity_run.py   (slow: each redraw of the stand-in window takes many seconds here)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local function near(a, b) return type(a) == "number" and math.abs(a - b) < 0.001 end
local okAll, errAll = pcall(function()
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
check("settings window addon loaded", ns and ns.BuildOptionsTable ~= nil)
if not (ns and ns.BuildOptionsTable) then return end
CueRulesDB.ui = CueRulesDB.ui or {}; CueRulesDB.ui.consoleAutoOpen = false
local reg, ACD = LibStub("AceConfigRegistry-3.0"), LibStub("AceConfigDialog-3.0")
local function root() return ACD.OpenFrames and ACD.OpenFrames["CueRules"] end
local function trees(w, out)
  out = out or {}
  if not w then return out end
  if w.type == "TreeGroup" then out[#out + 1] = w end
  for _, c in ipairs(w.children or {}) do trees(c, out) end
  return out
end
local function settle() W.tick(0.05, 6) end
local function halves(label, want)
  local ts = trees(root())
  check(label .. ": a sidebar tree is on screen", #ts > 0, #ts)
  for i, t in ipairs(ts) do
    local lr, lg, lb, la = t.treeframe:GetBackdropColor()
    local rr, rg, rb, ra = t.border:GetBackdropColor()
    -- (review, V35 c: a white half passed when only the alpha was read) the colors stay the skin's near-black
    check(("%s: tree %d left half is near-black (0.03)"):format(label, i), near(lr, 0.03) and near(lg, 0.03) and near(lb, 0.03),
          ("%s %s %s"):format(tostring(lr), tostring(lg), tostring(lb)))
    check(("%s: tree %d right half is near-black (0.04)"):format(label, i), near(rr, 0.04) and near(rg, 0.04) and near(rb, 0.04),
          ("%s %s %s"):format(tostring(rr), tostring(rg), tostring(rb)))
    check(("%s: tree %d left half (the list) filled at %d%%"):format(label, i, math.floor(want * 100 + 0.5)), near(la, want), la)
    check(("%s: tree %d right half (the page) filled at %d%%"):format(label, i, math.floor(want * 100 + 0.5)), near(ra, want), ra)
  end
  return ts
end
local function windowA() local _, _, _, a = root().frame:GetBackdropColor(); return a end

pcall(ns.ToggleUI); settle()
ACD:SelectGroup("CueRules", "set", "ui"); settle()
check("the window is open", root() ~= nil)
if not root() then return end
CueRulesDB.ui.skinAlpha = nil
reg:NotifyChange("CueRules"); settle()
halves("1 default", 0.60)
check("1 default: the window itself stays at 62%", near(windowA(), 0.62), windowA())

CueRulesDB.ui.skinAlpha = 0.31
ACD:Close("CueRules"); settle(); pcall(ns.ToggleUI); settle(); ACD:SelectGroup("CueRules", "set", "ui"); settle()
halves("2 window opacity 31%", 0.30)
CueRulesDB.ui.skinAlpha = 1
ACD:Close("CueRules"); settle(); pcall(ns.ToggleUI); settle(); ACD:SelectGroup("CueRules", "set", "ui"); settle()
halves("2 window opacity 100%", 0.6 / 0.62)
CueRulesDB.ui.skinAlpha = 1.5   -- not reachable from the slider (it clamps to 1); a hand-edited saved file could hold it
ACD:Close("CueRules"); settle(); pcall(ns.ToggleUI); settle(); ACD:SelectGroup("CueRules", "set", "ui"); settle()
halves("2 saved 150% (out of range)", 1)
CueRulesDB.ui.skinAlpha = nil
ACD:Close("CueRules"); settle(); pcall(ns.ToggleUI); settle()
ACD:SelectGroup("CueRules", "cooldowns"); settle()
halves("1 the Rules tab", 0.60)

local t = trees(root())[1]
ACD:Close("CueRules"); W.tick(0.05, 3)
if t then
  local _, _, _, la = t.treeframe:GetBackdropColor(); local _, _, _, ra = t.border:GetBackdropColor()
  check("3 released tree: both halves back to AceGUI's own 50%", near(la, 0.5) and near(ra, 0.5), ("%s / %s"):format(tostring(la), tostring(ra)))
end
end)
if not okAll then check("the test ran to its end (a Lua error stopped it)", false, errAll) end
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
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
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
