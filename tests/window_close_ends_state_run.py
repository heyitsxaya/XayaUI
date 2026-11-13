#!/usr/bin/env python3
"""Offline test (core 0.6.56, Options 0.6.55): closing the settings window ends everything it started on screen. Xaya, 2026-11-06:
"typing /xui and closing the menu does not turn off previews -- this is a high priority issue, as it indicates that the addon is still
running its options pane indirectly in some way. this should not happen" and "re-opening also does not detect that the preview is even
still present. review the code and determine why both of these things are happening."
Cause found: the displays left on screen were the sidebar's per-rule movement unlock (sample displays with boxes and names); closing the
window ended only the eye / headphone previews. Checks what is on screen after /xui (open), the sidebar unlock / preview / group unlock /
Lock Positions, then /xui again (close): no display of those rules is shown, nothing is left unlocked or previewed, the window's driver is
stopped; reopening shows every row locked and every preview off. (Bundle 1 round 7, SD-58 / SD-64: /xui unlock with the window closed
opens the window with the mover on, and closing the window closes the mover; before, such an unlock stayed through an open / close.)
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
check("Lock Positions while open unlocks everything", ns.unlocked == true)
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
-- (bundle 1 round 7, REQUEST-LOG A23 SD-58, her words: "mover view only available when settings window is open"; SD-64 option 1; V28)
-- Before round 7 an unlock typed as /xui unlock with the window closed stayed through an open / close of the window. Now /xui unlock
-- with the window closed opens the window with the mover on, and closing the window closes the mover.
SlashCmdList.XAYAUI("unlock"); W.tick(0.1, 4)
check("/xui unlock with the window closed opens the settings window with the mover on", ns.unlocked == true and ns.WindowOpen())
pcall(ns.ToggleUI); W.tick(0.1, 4)
check("... and closing the window closes the mover (nothing was moved: nothing is kept)", not ns.unlocked and not ns.WindowOpen()
  and ns.Settings("core").moverDraft == nil)
-- reopening shows a clean state: every row locked, every preview off
pcall(ns.ToggleUI); W.tick(0.1, 4)
check("reopened: the mover stays closed (it had no unsaved move)", not ns.unlocked and ns.WindowOpen())
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
