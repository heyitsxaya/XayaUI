#!/usr/bin/env python3
"""Round 5, the right-click tracker: /xui debug mouse on | off (REQUEST-LOG A23 SD-33 / SD-34; Xaya 2026-11-10, her answer "Yes, in
bundle 1 (Recommended)"). Standards: V14 (off costs nothing), V26 (read-only, exempt from the combat lock), V27 (no loops, the mouse
and keys untouched). What is checked, as the player sees or gets it:
  A. Off at login: no frame of the tracker exists and nothing listens to mouse presses; a right-click on another addon's frame over
     the world prints nothing.
  B. /xui debug lists "/xui debug mouse on|off".
  C. /xui debug mouse on: one line says it is on; a right-click that lands on a stand-in frame over the world (another addon's,
     made in Interface/AddOns/OtherAddon/Blocker.lua:12) prints one line naming it, that it takes clicks and where it was made.
  D. A right-click with the game world on top prints nothing; a left-click on the stand-in frame prints nothing.
  E. A frame the game gives no source for: the line says the game does not say where it was made; a frame whose name the game hides
     (a secret value): the line says so and shows no guess; a frame that does not take clicks: "Takes clicks: no".
  F. In combat: /xui debug mouse off and on work at once (no "can't ... during combat" line, nothing waits for combat to end) and a
     right-click on the stand-in frame in combat prints its line; the command's key is in core's single exemption list.
  G. /xui debug mouse off: one line with the count ("N right-clicks checked, M caught by other frames"); the press listener is
     released, and a right-click afterward prints nothing.
  H. The tracker never takes the mouse or the keyboard: its one frame is hidden, takes no mouse and no keys, and has no OnUpdate.
  I. After a /reload (a second session on what the first saved, with the tracker left on at logout): it is off, nothing listens to
     mouse presses, and a right-click on the stand-in frame prints nothing.
Stand-in limits (V25): GetMouseFoci, GetSourceLocation and IsMouseClickEnabled are set by this test on the stand-in game (the
harness's GetMouseFoci returns an empty list); a passing test is not proof of in-game behavior (UNVERIFIED IN GAME).
Checks marked "(control)" pass on the old code too; every other check fails on the files before this change.
Run: python3 tests/fix_r5_tracker_run.py   (Lua 5.1 via lupa; loads XayaUI, XayaUI_Rules and XayaUI_Options in the stand-in game)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

COMMON = r'''
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local function section(name, fn) local ok, err = pcall(fn); if not ok then check(name .. ": ran to its end (a Lua error stopped it)", false, err) end end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
local lines = {}
local function mark() return #lines end
local function since(m) local t = {}; for i = m + 1, #lines do t[#t + 1] = lines[i] end; return t end
local function joined(list) return table.concat(list, " / ") end
local function has(list, pat) for _, l in ipairs(list) do if l:lower():find(pat:lower(), 1, true) then return true end end; return false end
-- every frame listening to mouse presses right now
local function listeners()
  local n, list = 0, {}
  for _, o in ipairs(W.objects) do if o._events and o._events.GLOBAL_MOUSE_DOWN then n = n + 1; list[#list + 1] = o end end
  return n, list
end
-- the stand-in frame of another addon, over the world: what the game would answer for it (docs/reference/api/widgets.md:22, 173, 211)
local blocker = CreateFrame("Frame", "OtherAddonBlocker", UIParent)
blocker:SetSize(400, 300); blocker:SetPoint("CENTER")
rawset(blocker, "GetSourceLocation", function() return "Interface/AddOns/OtherAddon/Blocker.lua:12" end)
rawset(blocker, "IsMouseClickEnabled", function() return true end)
local underCursor = { WorldFrame }
GetMouseFoci = function() local t = {}; for i, f in ipairs(underCursor) do t[i] = f end; return t end
local function rightClick(top) underCursor = top and { top, WorldFrame } or { WorldFrame }; W.fire("GLOBAL_MOUSE_DOWN", "RightButton"); W.fire("GLOBAL_MOUSE_UP", "RightButton") end
local function leftClick(top) underCursor = top and { top, WorldFrame } or { WorldFrame }; W.fire("GLOBAL_MOUSE_DOWN", "LeftButton"); W.fire("GLOBAL_MOUSE_UP", "LeftButton") end
local slash = function(s) SlashCmdList.XAYAUI(s); W.tick(0.05, 2) end
'''

LUA1 = r'''
return function(W, L)
''' + COMMON + r'''
check("(control) XayaUI loaded", ns ~= nil and SlashCmdList.XAYAUI ~= nil)
if not ns then return R end
CueRulesDB.ui = CueRulesDB.ui or {}; CueRulesDB.ui.consoleAutoOpen = false
ns.Print = function(...) local t = {}; for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end; lines[#lines + 1] = table.concat(t, " ") end

section("A", function()
  local n = listeners()
  check("(control) A1 off at login: nothing listens to mouse presses", n == 0, n)
  local m = mark(); rightClick(blocker)
  check("(control) A2 off: a right-click on another addon's frame prints nothing", #since(m) == 0, joined(since(m)))
end)

section("B", function()
  local m = mark(); slash("debug")
  check("B1 /xui debug lists /xui debug mouse on|off", has(since(m), "/xui debug mouse on||off"), joined(since(m)))
end)

section("C", function()
  local m = mark(); slash("debug mouse on")
  local got = since(m)
  check("C1 /xui debug mouse on: one line says the tracker is on", #got == 1 and has(got, "right-click tracker is on"), joined(got))
  local n = listeners()
  check("C2 on: one frame listens to mouse presses", n == 1, n)
  m = mark(); rightClick(blocker); got = since(m)
  check("C3 a right-click on another addon's frame prints one line", #got == 1, joined(got))
  check("C4 the line names the frame", has(got, "right-click went to OtherAddonBlocker, not the game world"), joined(got))
  check("C5 the line says it takes clicks", has(got, "Takes clicks: yes"), joined(got))
  check("C6 the line says where it was made", has(got, "made in Interface/AddOns/OtherAddon/Blocker.lua:12"), joined(got))
end)

section("D", function()
  local m = mark(); rightClick(nil)
  check("(control) D1 on: a right-click with the game world on top prints nothing", #since(m) == 0, joined(since(m)))
  m = mark(); leftClick(blocker)
  check("(control) D2 on: a left-click on another addon's frame prints nothing", #since(m) == 0, joined(since(m)))
  m = mark(); underCursor = {}; W.fire("GLOBAL_MOUSE_DOWN", "RightButton")
  check("(control) D3 on: a right-click with nothing under the cursor prints nothing", #since(m) == 0, joined(since(m)))
end)

section("E", function()
  local plain = CreateFrame("Frame", "NoSourceFrame", UIParent)
  rawset(plain, "GetSourceLocation", function() return nil end)
  rawset(plain, "IsMouseClickEnabled", function() return false end)
  local m = mark(); rightClick(plain); local got = since(m)
  check("E1 a frame with no source: the line says the game does not say where it was made",
    #got == 1 and has(got, "NoSourceFrame") and has(got, "the game does not say where it was made"), joined(got))
  check("E2 a frame that does not take clicks: 'Takes clicks: no'", has(got, "Takes clicks: no"), joined(got))
  local hidden = CreateFrame("Frame", nil, UIParent)
  local secretName = W.MarkSecret("secret-frame-name-1")
  rawset(hidden, "GetDebugName", function() return secretName end)
  rawset(hidden, "GetSourceLocation", function() return "Interface/AddOns/Hidden/Hidden.lua:3" end)
  rawset(hidden, "IsMouseClickEnabled", function() return true end)
  m = mark(); rightClick(hidden); got = since(m)
  check("E3 a frame whose name the game hides: the line says so and shows no guess",
    #got == 1 and has(got, "a frame whose name the game hides") and not has(got, "secret-frame-name-1"), joined(got))
  local prot = CreateFrame("Frame", "ProtectedThing", UIParent)
  rawset(prot, "IsForbidden", function() return true end)
  rawset(prot, "GetDebugName", function() error("Attempt to access forbidden object") end)
  m = mark(); rightClick(prot); got = since(m)
  check("E4 a frame the game protects: one line says addons can't read it, no Lua error",
    #got == 1 and has(got, "a frame the game protects") and #W.errors == 0, joined(got))
end)

section("F", function()
  check("F1 the command's key is in core's single combat-lock exemption list", ns.CombatLockExempt and ns.CombatLockExempt("mouse") ~= nil)
  W.enterCombat(); W.tick(0.05, 2)
  local m = mark(); slash("debug mouse off"); slash("debug mouse on"); local got = since(m)
  check("F2 in combat: off and on run at once (no 'can't ... during combat' line)",
    has(got, "right-click tracker is off") and has(got, "right-click tracker is on") and not has(got, "during combat"), joined(got))
  m = mark(); rightClick(blocker); got = since(m)
  check("F3 in combat: a right-click on another addon's frame prints its line", #got == 1 and has(got, "OtherAddonBlocker"), joined(got))
  m = mark(); W.leaveCombat(); W.tick(0.1, 6); got = since(m)
  check("(control) F4 combat ends: nothing was waiting to run (no second on / off line)", not has(got, "right-click tracker"), joined(got))
end)

section("H", function()
  local _, list = listeners()
  local f = list[1]
  check("H1 the tracker's one frame is hidden, takes no mouse and no keys, and has no OnUpdate",
    f ~= nil and not f:IsShown() and not f._mouse and not f._keyboard and f._scripts.OnUpdate == nil)
  local before = #W.objects
  for _ = 1, 20 do rightClick(nil) end
  for _ = 1, 5 do rightClick(blocker) end
  check("(control) H2 25 right-clicks (20 on the world, 5 on another addon's frame) make no frame", #W.objects == before, #W.objects - before)
end)

section("G", function()
  rightClick(nil); rightClick(nil)   -- two more on the world
  local m = mark(); slash("debug mouse off"); local got = since(m)
  -- since F2 turned it on again: F3 1 on the frame; H2 20 on the world and 5 on the frame; 2 more on the world = 28 checked, 6 caught
  check("G1 off: one line with the count", #got == 1 and has(got, "right-click tracker is off. 28 right-clicks checked, 6 caught by other frames."), joined(got))
  local n = listeners()
  check("G2 off: nothing listens to mouse presses", n == 0, n)
  m = mark(); rightClick(blocker)
  check("G3 off: a right-click on another addon's frame prints nothing", #since(m) == 0, joined(since(m)))
  m = mark(); slash("debug mouse off")
  check("G4 off again: says it is already off", has(since(m), "already off"), joined(since(m)))
end)

slash("debug mouse on")   -- left on at logout: a /reload must turn it off
local saved = L.logout()
check("(control) no Lua errors in the stand-in game", #W.errors == 0, W.errors[1])
return R, saved
end
'''

LUA2 = r'''
return function(W, L)
''' + COMMON + r'''
check("(control) XayaUI loaded after the /reload", ns ~= nil)
if not ns then return R end
ns.Print = function(...) local t = {}; for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end; lines[#lines + 1] = table.concat(t, " ") end
section("I", function()
  local n = listeners()
  check("(control) I1 after a /reload: nothing listens to mouse presses", n == 0, n)
  local m = mark(); rightClick(blocker)
  check("(control) I2 after a /reload: a right-click on another addon's frame prints nothing", #since(m) == 0, joined(since(m)))
  m = mark(); slash("debug mouse")
  check("I3 after a /reload: /xui debug mouse says the tracker is off", has(since(m), "right-click tracker is off"), joined(since(m)))
end)
return R
end
'''


def session(lua, folders, enabled, saved):
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    sv = H.savedvars(L)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    opts = H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}})
    opts["saved"] = sv.Load(saved) if saved else L.table()
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(os.path.join(H.HERE, "loader.lua"), world, opts)
    out = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(lua, world, loader)
    if isinstance(out, tuple):
        res, savedOut = out[0], out[1]
    else:
        res, savedOut = out, None
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    return res, (sv.Serialize(savedOut) if savedOut is not None else None), errs


def main():
    folders = H.find_addons()
    enabled = [n for n in folders if n in ("XayaUI", "XayaUI_Rules", "XayaUI_Options")]
    bad, n, allErrs = 0, 0, []
    saved = None
    for lua in (LUA1, LUA2):
        res, out, errs = session(lua, folders, enabled, saved)
        saved = out if out is not None else saved
        allErrs += errs
        for i in range(1, len(res) + 1):
            name, good = res[i][1], res[i][2]
            print(("PASS " if good else "FAIL ") + name)
            n += 1
            bad += 0 if good else 1
    for e in allErrs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (n, bad, len(allErrs)))
    sys.exit(1 if bad or allErrs else 0)


if __name__ == "__main__":
    main()
