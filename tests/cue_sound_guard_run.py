#!/usr/bin/env python3
"""Insivius (Discord, 2026-11-04): adding a cue to a Blood Boil rule failed, 21 times, with
   "XayaUI_Options/Options.lua:2112: attempt to index field 'AuraSound' (a nil value)", and no new cue was created.
The sound cue's status line ("the game plays this sound ...") read ns.AuraSound.StatusLine inside pcall(...), but the index
ns.AuraSound.StatusLine is evaluated BEFORE pcall runs, so a core without AuraSound.lua (core older than 0.6.13, or new files copied
without a game restart) raised the error outside the pcall and broke the whole settings tree.
Builds the real settings tree in the stand-in game with a sound cue whose game-played sound is on, finds the cue's status line, and
checks it with and without ns.AuraSound.
Run: python3 tests/cue_sound_guard_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
check("settings window addon loaded (ns.BuildOptionsTable)", ns and ns.BuildOptionsTable ~= nil)
if not (ns and ns.BuildOptionsTable) then return R end
-- a Blood Boil rule with a sound cue whose game-played sound is on (the cue being added)
local p = ns.NewRule(); p.name = "Blood Boil"; p.enabled = true; p.useBuff = true; p.buffID = 81141; p.buffState = "present"; ns.NormalizeRule(p)
ns.rules = { p }
local cue = ns.NewCueRule(p, "sound")
check("a sound cue is made", cue ~= nil and cue.cueKind == "sound")
if not cue then return R end
cue.gameSound = { enabled = true, channel = "Ambience", throttle = 1, when = "auto" }
-- every table in the built tree, walked once, looking for the cue's status line (the cue editor names it snd_gameSoundStatus)
local function find(root, key)
  local seen, stack = {}, { root }
  while #stack > 0 do
    local t = table.remove(stack)
    if type(t) == "table" and not seen[t] then
      seen[t] = true
      if type(t[key]) == "table" then return t[key] end
      for _, v in pairs(t) do if type(v) == "table" then stack[#stack + 1] = v end end
    end
  end
end
local function build(withoutCore)
  local saved = ns.AuraSound
  if withoutCore then ns.AuraSound = nil end
  local ok, built = pcall(ns.BuildOptionsTable)
  local gs = ok and find(built, "snd_gameSoundStatus")
  local okN, txt
  if gs then okN, txt = pcall(gs.name) end
  local hid = gs and type(gs.hidden) == "function" and gs.hidden()
  ns.AuraSound = saved
  return ok, built, gs, okN, txt, hid
end
local ok, built, gs, okN, txt, hid = build(false)
check("the settings tree builds", ok, built)
check("the sound cue's game-sound status line is in the tree, shown while the game-played sound is on", gs ~= nil and hid == false, tostring(gs) .. " hidden=" .. tostring(hid))
check("with core's AuraSound: the line is AuraSound's own text (no error)", okN == true and type(txt) == "string" and not txt:find("0.6.13", 1, true), txt)
ok, built, gs, okN, txt = build(true)
check("core without AuraSound.lua: the settings tree still builds", ok, built)
check("core without AuraSound.lua: the status line draws (no error) and says core 0.6.13 or newer is needed",
  okN == true and type(txt) == "string" and txt:find("0.6.13", 1, true) ~= nil, tostring(okN) .. " " .. tostring(txt))
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
