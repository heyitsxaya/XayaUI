#!/usr/bin/env python3
"""Offline test (core 0.6.56): D7, a switched-off rule costs nothing. Xaya, 2026-11-06 (question prompt): "Accept 1-3" =
(1) the engine skips disabled rules entirely after a one-time switch-off clean-up; (2) a disabled rule (and its cues) never gets a display
frame, and its frame is freed when you switch it off; (3) the Disabled tab still lists them; and the sidebar preview of a disabled rule
"Still works" (its frame exists only while previewed).
Checks: a rule saved off makes no runtime record, no frame and no evaluation over many steps (its cues neither); a rule switched off while
its display is up has the display gone and its frame freed at the next step and is then never evaluated again; the unlock / mover view
draws no switched-off rule; previewing a switched-off rule draws it, ending the preview frees it again; switching it back on works as
before; the rule still reads as "disabled" (the Disabled tab's list) and is still in ns.rules.
Run: python3 tests/disabled_costs_nothing_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
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
if ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 2)   -- the Disabled tab's list (ns.RuleScope) lives in the settings addon
ns = rawget(_G, "XayaUI_NS")
ns.rules, ns.runtime = {}, ns.runtime or {}
for k in pairs(ns.runtime) do ns.runtime[k] = nil end
local function rule(name, on)
  local r = ns.NewRule(); r.name = name; r.enabled = on
  -- "my debuff is missing from the target": true in the stand-in (no target), so the rule fires while it is on
  r.cdState, r.buffState = "none", "none"
  r.extra = { list = { { type = "targetDebuff", spellID = 207771, unit = "target", state = "no" } } }
  r.visual.enabled, r.sound.enabled = false, false
  ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
  local c = ns.NewCueRule(r, "texture"); c.visual.kind, c.visual.tex = "file", "Interface\\Icons\\INV_Misc_QuestionMark"
  return r, c
end
local ON, con = rule("On rule", true)
local OFF, coff = rule("Saved off", false)
local evals = {}
local E0 = ns.Evaluate
ns.Evaluate = function(r, ...) evals[r] = (evals[r] or 0) + 1; return E0(r, ...) end
local function frames(r) return #ns.VisualFramesOf(r) end
local function shown(r) for _, f in ipairs(ns.VisualFramesOf(r)) do if f:IsShown() then return true end end return false end
pcall(ns.RefreshAllVisuals)
for _ = 1, 20 do ns.Step() end
local okE, rE = pcall(E0, ON, ns.ReadContext())
local okC, rC = pcall(E0, con, ns.ReadContext())
check("the rule that is on works: its cue's display is shown", shown(con), tostring(rE) .. " " .. tostring(rC) .. " rt=" .. tostring(ns.runtime[con] and ns.runtime[con].visualWanted) .. " frames=" .. frames(con))
check("saved off: no display frame for the rule or its cue", frames(OFF) == 0 and frames(coff) == 0)
check("saved off: never evaluated over 20 steps, no runtime record made", (evals[OFF] or 0) == 0 and (evals[coff] or 0) == 0
  and ns.runtime[OFF] == nil and ns.runtime[coff] == nil, tostring(evals[coff]) .. " " .. tostring(ns.runtime[coff]))
check("the rule that is on is evaluated each step", (evals[ON] or 0) >= 20 and (evals[con] or 0) >= 20)
-- switch the on rule off while its display is up
ON.enabled = false
pcall(ns.RefreshVisual, con)
ns.Step()
check("switched off: its display is gone and its frame freed", not shown(con) and frames(con) == 0)
local n0 = evals[con] or 0
for _ = 1, 20 do ns.Step() end
check("then never evaluated again (20 more steps)", (evals[con] or 0) == n0, (evals[con] or 0) - n0)
pcall(ns.RefreshAllVisuals)
check("a full display refresh builds no frame for it", frames(con) == 0 and frames(coff) == 0)
-- unlock / mover view: switched-off rules are not drawn
ns.ToggleUnlock(); pcall(ns.RefreshAllVisuals); ns.Step()
check("unlock / mover view: no switched-off display drawn", frames(coff) == 0 and frames(con) == 0)
ns.ToggleUnlock()
-- preview still works, and ending it frees the frame again
ns.SetPreview({ coff }, "visual", true); pcall(ns.RefreshVisual, coff); ns.Step()
check("previewing a switched-off rule's cue draws it", shown(coff))
ns.SetPreview({ coff }, "visual", false); ns.Step(); ns.Step()
check("ending the preview hides it and frees its frame", not shown(coff) and frames(coff) == 0)
local n1 = evals[coff] or 0
for _ = 1, 10 do ns.Step() end
check("... and it is skipped again afterwards", (evals[coff] or 0) == n1)
-- back on
ON.enabled = true; pcall(ns.RefreshAllVisuals)
for _ = 1, 3 do ns.Step() end
check("switched back on: its display shows again", shown(con))
-- the Disabled tab still lists it
local okS, sc = pcall(ns.RuleScope, OFF, ns.ReadContext())
local inList = false
for _, r in ipairs(ns.rules) do if r == OFF then inList = true end end
check("the switched-off rule is kept and reads as Disabled (the Disabled tab's list)", inList and okS and sc == "disabled", tostring(sc))
ns.Evaluate = E0
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
