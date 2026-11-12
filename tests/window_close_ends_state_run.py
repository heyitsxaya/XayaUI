#!/usr/bin/env python3
"""Offline test (core 0.6.56, Options 0.6.55): closing the settings window ends everything it started on screen. Xaya, 2026-11-06:
"typing /xui and closing the menu does not turn off previews -- this is a high priority issue, as it indicates that the addon is still
running its options pane indirectly in some way. this should not happen" and "re-opening also does not detect that the preview is even
still present. review the code and determine why both of these things are happening."
Cause found: the displays left on screen were the sidebar's per-rule movement unlock (sample displays with boxes and names); closing the
window ended only the eye / headphone previews. Checks what is on screen after /xui (open), the sidebar unlock / preview / group unlock /
Lock Positions, then /xui again (close): no display of those rules is shown, nothing is left unlocked or previewed, the window's driver is
stopped; an unlock typed as /xui unlock while the window was closed is NOT ended by opening and closing the window; reopening shows every
row locked and every preview off.
Run: python3 tests/window_close_ends_state_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. ((ok or extra == nil) and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup(); W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 5)
local ns = rawget(_G, "XayaUI_NS")
ns.folders = { { id = "fH", name = "HUD" } }
ns.rules = {}
local function rule(name, id, folder)
  local r = ns.NewRule(); r.name = name; r.enabled = true; r.useBuff, r.buffID, r.buffState = true, id, "present"
  r.visual.enabled, r.sound.enabled = false, false; r.folder = folder
  ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
  local c = ns.NewCueRule(r, "texture"); c.visual.kind, c.visual.tex = "file", "Interface\\Icons\\INV_Misc_QuestionMark"
  return r, c
end
local A, ca = rule("R - Demon Spikes", 1001)
local B, cb = rule("L - Calcified Spikes", 1002)
local C, cc = rule("T - Metamorphosis", 1003, "fH")
local D, cd = rule("R - Soulmonger", 1004)
local function shown(c) for _, f in ipairs(ns.VisualFramesOf(c)) do if f:IsShown() then return true end end return false end
local function step() ENGINE_STEP(ns); W.tick(0.1, 3) end
step()
check("nothing is shown before (the auras are not up)", not shown(ca) and not shown(cb) and not shown(cc) and not shown(cd))
-- /xui: open the window; unlock A for moving (sidebar lock), preview B (eye), unlock group HUD (C), pause previews
pcall(ns.ToggleUI); W.tick(0.1, 4)
ns.SetMoveUnlocked({ ca }, true)
ns.SetPreview({ cb }, "visual", true)
ns.SetGroupUnlocked(ns.FolderById("fH"), true)
ns.SetPreviewPaused(true)
step()
check("while open: the unlocked, previewed and group-unlocked displays are shown", shown(ca) and shown(cb) and shown(cc), tostring(shown(ca)) .. tostring(shown(cb)) .. tostring(shown(cc)))
-- the window's Lock Positions while open
ns.ToggleUnlock()
check("Lock Positions while open unlocks everything", ns.unlocked == true and ns.unlockedByWindow == true)
-- /xui again: close
pcall(ns.ToggleUI); W.tick(0.1, 4)
local ACD = LibStub("AceConfigDialog-3.0")
local of = ACD.OpenFrames and ACD.OpenFrames["CueRules"]
check("the window is closed", not (of and of.frame and of.frame:IsShown()))
step()
check("after closing: no display of those rules is left on screen", not shown(ca) and not shown(cb) and not shown(cc) and not shown(cd),
  tostring(shown(ca)) .. tostring(shown(cb)) .. tostring(shown(cc)) .. tostring(shown(cd)))
check("after closing: nothing previewed, no rule or group unlocked, not paused, not unlocked", not ns.AnyPreview() and next(ns.moveUnlocked) == nil
  and next(ns.groupUnlocked) == nil and not ns.previewPaused and not ns.unlocked and not ns.WindowOpen())
-- /xui unlock typed with the window closed stays through an open / close
ns.ToggleUnlock()
check("/xui unlock with the window closed unlocks", ns.unlocked == true and not ns.unlockedByWindow)
pcall(ns.ToggleUI); W.tick(0.1, 4); pcall(ns.ToggleUI); W.tick(0.1, 4)
check("... and opening / closing the window does not end it (it was not started there)", ns.unlocked == true)
ns.ToggleUnlock()
-- reopening shows a clean state: every row locked, every preview off
pcall(ns.ToggleUI); W.tick(0.1, 4)
local rowsOK, seen = true, 0
local function walk(f, d)
  if not f or d > 60 then return end
  if f.xuiMove and f.xuiMove:IsShown() and f.xuiMove.tex then
    seen = seen + 1
    if tostring(f.xuiMove.tex:GetTexture()) ~= ns.LOCK_ICON then rowsOK = false end
  end
  if f.xuiEye and f.xuiEye:IsShown() and f.xuiEye.tex then
    if tostring(f.xuiEye.tex:GetTexture()) ~= ns.PreviewIcon("visual", 0) then rowsOK = false end
  end
  for _, c in ipairs(f.GetChildren and { f:GetChildren() } or {}) do walk(c, d + 1) end
end
local okW, errW = pcall(walk, UIParent, 0)
if not okW then rowsOK = false end
check("reopened: every row shows the lock (nothing unlocked) and the eye off", rowsOK and seen > 0, okW and seen or errW)
pcall(ns.ToggleUI); W.tick(0.1, 2)
return R
end
'''

# (round 7 repair) the engine no longer exports ns.Step: one full engine step is reached through tests/engine_bench.py's helper
_BENCH = open(os.path.join(HERE, "engine_bench.py"), encoding="utf-8").read()
ENGINE_STEP_LUA = _BENCH[_BENCH.index("-- [engine-step helper]"):_BENCH.index("-- [/engine-step helper]")]
LUA = LUA.replace("return function(W, L)\n", "return function(W, L)\n" + ENGINE_STEP_LUA, 1)


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
        print(("ok  " if ok else "FAIL: ") + name)
        if not ok:
            bad += 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
