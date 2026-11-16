#!/usr/bin/env python3
"""SD-118 (bundle 1 round 10; REQUEST-LOG SD-118, a STANDING RULE, her answer "All parts, say how (Recommended)"): a part's chat words
work only while that part is switched on. Typing a switched-off part's word prints ONE line naming the part and where to turn it on
(her example: "The Calculator is off. Turn it on in /xui > Bonus Features."), and /xui help lists a part's words only while it is on.

The mechanism is core's (XayaUI/Modules.lua section 2): ns.RegisterCommand(names, fn, help, part) with part = { name, isOn, where }.
This test loads the real addons in the stand-in game and registers stand-in parts through that call (the real parts, the Calculator and
the Stat Calculator inside XayaUI_Bonus, are other units' files; stand-in words, so nothing here depends on their state).
What the player sees, checked here:
  OFF  1. a switched-off part's word (and its other spelling) prints exactly one line in chat, "XayaUI: The Test Part is off. Turn it on
          in /xui > Bonus Features.", and nothing of the part runs (its handler is never called).
       2. /xui help leaves the switched-off part's line out (and its count says so).
       3. a part whose switch fails with an error counts as off: the same one line, the error goes to the game's error handler, nothing
          of the part runs.
       4. a word two handlers share, one with a switched-off part and one with no switch: the one with no switch runs, no "is off" line.
       5. a part handed in without where it is turned on is refused: its word does nothing of the part and prints /xui help.
  ON   6. switched on (no /reload), the same words run the part with what was typed after them and print no "is off" line; /xui help
          lists its line; switched off again, the one line is back and the help line is gone (the switch is read each time).
  NOT LOADED
       7. a part whose own code is load-on-demand and not loaded (stand-in: its handler would load XayaUI_Bonus_StatCalculator): while
          switched off, typing its word leaves that folder unloaded (nothing of it is read, SD-105) and prints the one line; switched on,
          it runs and loads it.
       8. with XayaUI Bonus Features switched off in the AddOns list (its parts not loaded at all): /xui calc and /xui calculator name
          XayaUI Bonus Features and the AddOns list (core's list, audit_core D8), /xui stats still names XayaUI QoL (SD-89, her answer
          "Keep naming QoL"), /xui help lists none of them, and no "The ... is off" line appears.
Negative control: on the pre-change files (Modules.lua and Core.lua before round 10, the part argument ignored) 18 of the 31 checks
fail: in 1, 2, 3, 4, 5, 6 (the part ran while off, so its run count and help count are off by the time it is switched on) and the off
half of 7. What the mechanism must keep passes before and after (setup lines, the on half of 7, all of 8: a part that is not loaded
behaves as on round 9, SD-89); those are proved by mutations instead (Bonus row without calc, stats leaving the QoL row, unknown words
swallowed, the switch always off).
Run: python3 tests/fix_r10_part_words_run.py   (Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L, bonusOn)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local ns = rawget(_G, "XayaUI_NS")
local function plain(l) return (tostring(l):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
-- what one /xui command prints in the chat window (the game's print)
local function chat(s)
  local before = #W.printed
  SlashCmdList.XAYAUI(s); W.tick(0.1, 2)
  local out = {}
  for i = before + 1, #W.printed do out[#out + 1] = plain(W.printed[i]) end
  return out
end
local function helpHas(out, needle) for i = 2, #out do if out[i]:find(needle, 1, true) then return true end end return false end
local function headerOk(out) return out[1] ~= nil and out[1] == ("XayaUI: commands (%d):"):format(#out - 1) end
local loaded = C_AddOns.IsAddOnLoaded("XayaUI_Bonus") and true or false
check("setup: XayaUI Bonus Features is " .. (bonusOn and "loaded" or "not loaded (switched off in the AddOns list)"), loaded == bonusOn, loaded)

if bonusOn then
  local WHERE = "/xui > Bonus Features"
  local OFF_LINE = "XayaUI: The Test Part is off. Turn it on in /xui > Bonus Features."
  local partOn, calls, lastArg = false, 0, nil
  local part = { name = "Test Part", where = WHERE, isOn = function() return partOn end }
  ns.RegisterCommand({ "testpart", "tpart" }, function(a) calls = calls + 1; lastArg = a; ns.Print("test part ran: " .. tostring(a)) end,
    "/xui testpart [words] (the stand-in part)", part)
  local help0 = chat("help")

  -- 1. OFF: one line, nothing of the part runs
  local out = chat("testpart 2+2")
  check("OFF 1: /xui testpart while the part is off prints exactly one line", #out == 1, #out .. " lines: " .. table.concat(out, " / "))
  check("OFF 1: that line is '" .. OFF_LINE .. "'", out[1] == OFF_LINE, out[1])
  check("OFF 1: nothing of the part runs (its handler is never called)", calls == 0, calls)
  local out2 = chat("tpart")
  check("OFF 1: its other spelling /xui tpart prints the same one line, nothing runs", #out2 == 1 and out2[1] == OFF_LINE and calls == 0, table.concat(out2, " / "))
  -- 2. help leaves it out
  check("OFF 2: /xui help has a header with its count", headerOk(help0), help0[1])
  check("OFF 2: /xui help leaves the switched-off part's line out", not helpHas(help0, "/xui testpart"), table.concat(help0, " / "))

  -- 3. a switch that fails counts as off
  local errs = {}
  local saveEH = geterrorhandler
  geterrorhandler = function() return function(e) errs[#errs + 1] = tostring(e) end end
  local bcalls, broken = 0, true
  ns.RegisterCommand("brokenpart", function() bcalls = bcalls + 1 end, "/xui brokenpart (a part whose switch fails)",
    { name = "Broken Part", where = WHERE, isOn = function() if broken then error("switch boom") end return false end })
  local ob = chat("brokenpart")
  local hb = chat("help")
  geterrorhandler = saveEH
  broken = false   -- (its switch answers "off" from here on, so later commands report nothing)
  check("OFF 3: a part whose switch errors: one line 'The Broken Part is off. Turn it on in /xui > Bonus Features.'",
    #ob == 1 and ob[1] == "XayaUI: The Broken Part is off. Turn it on in /xui > Bonus Features.", table.concat(ob, " / "))
  check("OFF 3: ... nothing of it runs", bcalls == 0, bcalls)
  check("OFF 3: ... the error goes to the game's error handler", #errs >= 1 and errs[1]:find("switch boom", 1, true) ~= nil, table.concat(errs, " / "))
  check("OFF 3: ... /xui help leaves its line out", not helpHas(hb, "/xui brokenpart"), table.concat(hb, " / "))

  -- 4. a shared word: the handler with no switch runs, no "is off" line
  local sharedPart, sharedPlain = 0, 0
  ns.RegisterCommand("sharedword", function() sharedPart = sharedPart + 1 end, nil, { name = "Shared Part", where = WHERE, isOn = function() return false end })
  ns.RegisterCommand("sharedword", function() sharedPlain = sharedPlain + 1; ns.Print("shared plain ran") end)
  local os_ = chat("sharedword")
  check("OFF 4: a word shared with a handler that has no switch: that one runs, the switched-off part's does not",
    sharedPlain == 1 and sharedPart == 0, sharedPlain .. "/" .. sharedPart)
  check("OFF 4: ... and no 'is off' line is printed", #os_ == 1 and os_[1] == "XayaUI: shared plain ran", table.concat(os_, " / "))

  -- 5. a part handed in without where it is turned on is refused
  local errs5 = {}
  geterrorhandler = function() return function(e) errs5[#errs5 + 1] = tostring(e) end end
  local ncalls = 0
  local ok5 = ns.RegisterCommand("nowherepart", function() ncalls = ncalls + 1 end, "/xui nowherepart (no where)",
    { name = "Nowhere Part", isOn = function() return true end })
  geterrorhandler = saveEH
  local on5 = chat("nowherepart")
  check("OFF 5: a part without 'where' is refused: its word runs nothing of it and prints /xui help",
    ncalls == 0 and headerOk(on5) and not helpHas(on5, "/xui nowherepart"), ncalls .. " calls; " .. tostring(on5[1]))
  check("OFF 5: ... the refusal is reported to the game's error handler", ok5 == false and #errs5 == 1 and errs5[1]:find("SD-118", 1, true) ~= nil,
    tostring(ok5) .. " " .. table.concat(errs5, " / "))

  -- 6. ON: switched on without a reload
  partOn = true
  local on = chat("testpart 7*6")
  check("ON 6: switched on, /xui testpart runs the part with what was typed after it", calls == 1 and lastArg == "7*6", calls .. " " .. tostring(lastArg))
  check("ON 6: ... and prints only the part's own line, no 'is off' line", #on == 1 and on[1] == "XayaUI: test part ran: 7*6", table.concat(on, " / "))
  local on2 = chat("tpart")
  check("ON 6: its other spelling runs it too", calls == 2 and #on2 == 1 and on2[1] == "XayaUI: test part ran: ", table.concat(on2, " / "))
  local h1 = chat("help")
  check("ON 6: /xui help lists its line while it is on", helpHas(h1, "/xui testpart [words]") and headerOk(h1) and #h1 == #help0 + 1, #h1 .. " vs " .. #help0)
  partOn = false
  local off2 = chat("testpart 1")
  local h2 = chat("help")
  check("ON 6: switched off again: the one line is back and nothing runs", #off2 == 1 and off2[1] == OFF_LINE and calls == 2, table.concat(off2, " / "))
  check("ON 6: switched off again: /xui help leaves its line out again", not helpHas(h2, "/xui testpart") and #h2 == #help0, #h2 .. " vs " .. #help0)

  -- 7. NOT LOADED: a part whose own code is load-on-demand
  local LOD = "XayaUI_Bonus_StatCalculator"
  local lodOn = false
  ns.RegisterCommand("lodpart", function() C_AddOns.LoadAddOn(LOD) end, "/xui lodpart (a load-on-demand stand-in)",
    { name = "Load Part", where = WHERE, isOn = function() return lodOn end })
  local was = C_AddOns.IsAddOnLoaded(LOD) and true or false
  check("NOT LOADED 7: setup: the load-on-demand folder is not loaded (a fresh install has the Stat Calculator off)", was == false, was)
  local ol = chat("lodpart")
  check("NOT LOADED 7: switched off, its word leaves the folder unloaded (nothing of it is read)", not C_AddOns.IsAddOnLoaded(LOD), "loaded")
  check("NOT LOADED 7: ... and prints the one line 'The Load Part is off. Turn it on in /xui > Bonus Features.'",
    #ol == 1 and ol[1] == "XayaUI: The Load Part is off. Turn it on in /xui > Bonus Features.", table.concat(ol, " / "))
  lodOn = true
  chat("lodpart")
  check("NOT LOADED 7: switched on, its word runs and loads it", C_AddOns.IsAddOnLoaded(LOD) and true or false, "not loaded")
else
  -- 8. NOT LOADED: XayaUI Bonus Features switched off in the AddOns list
  local help = chat("help")
  for _, w in ipairs({ "calc", "calculator" }) do
    local out = chat(w)
    check(("NOT LOADED 8: /xui %s prints one line naming XayaUI Bonus Features and the AddOns list"):format(w),
      #out == 1 and out[1] == ("XayaUI: /xui %s is part of XayaUI Bonus Features, which is switched off. Turn it on in the game's AddOns list, then /reload."):format(w),
      table.concat(out, " / "))
  end
  local st = chat("stats")
  check("NOT LOADED 8: /xui stats still names XayaUI QoL (SD-89, 'Keep naming QoL')",
    #st == 1 and st[1] == "XayaUI: /xui stats is part of XayaUI QoL, which is not installed (or its files failed to load; /xui bug shows errors).", table.concat(st, " / "))
  check("NOT LOADED 8: /xui help lists none of calc, calculator, stats", headerOk(help) and not helpHas(help, "/xui calc") and not helpHas(help, "/xui stats"),
    table.concat(help, " / "))
  local anyOff
  for _, w in ipairs({ "calc", "calculator", "stats" }) do for _, l in ipairs(chat(w)) do if l:find(" is off. Turn it on in /xui", 1, true) then anyOff = l end end end
  check("NOT LOADED 8: no 'The ... is off' line (a part that is not loaded registered nothing)", anyOff == nil, anyOff)
end
return R
end
'''


def run_once(bonus_on):
    folders = H.find_addons()
    enabled = [f for f in folders if bonus_on or not f.startswith("XayaUI_Bonus")]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    res = L.eval("function(src, W, Ld, b) return loadstring(src)()(W, Ld, b) end")(LUA, world, loader, bonus_on)
    bad = 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        print(("PASS " if ok else "FAIL ") + name)
        if not ok:
            bad += 1
    errs = [str(world.errors[i]) for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", e[:600])
    return len(res), bad, len(errs)


def main():
    folders = H.find_addons()
    if "XayaUI_Bonus" not in folders or "XayaUI_Bonus_StatCalculator" not in folders:
        print("FAIL XayaUI_Bonus and XayaUI_Bonus_StatCalculator must be in this tree")
        print("1 checks, 1 failed")
        sys.exit(1)
    n1, b1, e1 = run_once(True)
    n2, b2, e2 = run_once(False)
    print("%d checks, %d failed, %d Lua errors" % (n1 + n2, b1 + b2, e1 + e2))
    sys.exit(1 if (b1 + b2 + e1 + e2) else 0)


if __name__ == "__main__":
    main()
