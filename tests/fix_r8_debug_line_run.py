#!/usr/bin/env python3
"""Bundle 1 round 8, Advanced Debugging: off by default, its Settings text true and plain, and the login line in her exact words.
Her answers (REQUEST-LOG A23): SD-61 "Off by default (Recommended)"; SD-64 "any time a user has debugging on, logging in or reloading should
print to the chat pane ..."; SD-70 "Short with path (Recommended)": the line is exactly
"XayaUI: Advanced Debugging is on. Turn it off in /xui > Settings > Debugging.", once per login or /reload.
What the player gets, on the real addons in the stand-in game ([new] = fails on the pre-change files):
  F  a fresh install: Advanced Debugging is off (the Settings switch reads off, nothing saved for it), and no such line at the login.
  L  [new] a saved "on": at the login exactly one chat line, and it is exactly her line (colour codes aside); a loading screen, combat and
     a zone change after it print it no more.
  P  [new] a /reload (a new session from the saved files) prints it once again, exactly; turned off in Settings, the next /reload prints
     nothing.
  T  [new] the Settings > Debugging switch's tooltip no longer says "On by default; it does nothing while nothing goes wrong" (false since
     SD-61): it says "Off by default." and that it loads the debug tools from the next login or /reload (two sentences: the hover rule).
UNVERIFIED IN GAME.
Run: python3 tests/fix_r8_debug_line_run.py   (Lua 5.1 via lupa)"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LINE = "XayaUI: Advanced Debugging is on. Turn it off in /xui > Settings > Debugging."

LUA = r'''
return function(W, L, step, LINE)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. ((ok or extra == nil) and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local function plain(l) return (tostring(l):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function lines(from, pat) local t = {}; for i = from + 1, #W.printed do local p = plain(W.printed[i]); if p:lower():find(pat, 1, true) then t[#t + 1] = p end end; return t end
local okAll, errAll = pcall(function()
L.startup(); W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local ns = rawget(_G, "XayaUI_NS")
local atLogin = lines(0, "debugging is on")
if step == "fresh" then
  check("F a fresh install: Advanced Debugging is off and nothing is saved for it", ns.AdvancedDebugOn() == false and CueRulesDB.ui.advancedDebug == nil,
    tostring(CueRulesDB.ui.advancedDebug))
  check("F ... and no 'Advanced Debugging is on' line at the login", #atLogin == 0, table.concat(atLogin, " / "))
  ns.LoadOptions(); W.tick(0.1, 3); ns = rawget(_G, "XayaUI_NS")
  local T = ns.BuildOptionsTable()
  local sw = T.args.set and T.args.set.args.debug and T.args.set.args.debug.args.advancedDebug
  check("F the Settings switch reads off", sw ~= nil and sw.get({}) == false)
  local desc = sw and tostring(sw.desc) or ""
  check("[new] T its tooltip no longer says 'On by default' nor 'it does nothing while nothing goes wrong'",
    desc ~= "" and not desc:find("On by default", 1, true) and not desc:find("does nothing while nothing goes wrong", 1, true), desc)
  check("[new] T ... it says 'Off by default.' and that it loads the debug tools from the next login or /reload",
    desc:find("Off by default.", 1, true) ~= nil and desc:find("from your next login or /reload, loads the debug tools", 1, true) ~= nil, desc)
elseif step == "off" then
  check("P turned off in Settings, the next /reload prints no line and it reads off", #atLogin == 0 and ns.AdvancedDebugOn() == false,
    table.concat(atLogin, " / "))
else
  check("[new] " .. (step == "reload" and "P" or "L") .. " (" .. step .. ") exactly one line at the login, and it is exactly her words", #atLogin == 1 and atLogin[1] == LINE, table.concat(atLogin, " / "))
  local n = #W.printed
  W.fire("PLAYER_ENTERING_WORLD", false, false); W.enterCombat(); W.tick(0.1, 3); W.leaveCombat(); W.fire("ZONE_CHANGED_NEW_AREA"); W.tick(0.2, 5)
  local after = lines(n, "debugging is on")
  check("L (" .. step .. ") ... and not again after a loading screen, a fight and a zone change", #after == 0, table.concat(after, " / "))
  if step == "reload" then   -- turn it off in Settings for the next /reload
    ns.LoadOptions(); W.tick(0.1, 3); ns = rawget(_G, "XayaUI_NS")
    local T = ns.BuildOptionsTable()
    T.args.set.args.debug.args.advancedDebug.set({}, false)
  end
end
check("no Lua error (" .. step .. ")", #W.errors == 0, W.errors[1])
end)
if not okAll then R[#R + 1] = { "the run itself finished (" .. step .. ")  [" .. tostring(errAll) .. "]", false } end
return R
end
'''


def session(step, saved):
    folders = H.find_addons()
    enabled = [n for n in folders if n in ("XayaUI", "XayaUI_Rules", "XayaUI_Options", "XayaUI_Debug")]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": H.to_lua(L, saved)}))
    res = L.eval("function(src, W, Ld, ...) return loadstring(src)()(W, Ld, ...) end")(LUA, world, loader, step, LINE)
    out = [(res[i][1], bool(res[i][2])) for i in range(1, len(res) + 1)]
    sv, _issues = loader.logout()
    return out, H.lua_to_py(sv)


def main():
    results = []
    r, _ = session("fresh", {})
    results += r
    r, sv = session("login", {"XayaUI": {"CueRulesDB": {"version": 1, "ui": {"advancedDebug": True, "msgDest": "console"}}}})
    results += r
    r, sv = session("reload", sv)        # a /reload: a new session from the files the logout wrote; it is turned off in Settings there
    results += r
    r, sv = session("off", sv)
    results += r
    failed = 0
    for name, ok in results:
        print(("PASS " if ok else "FAIL ") + name)
        failed += 0 if ok else 1
    print("%d checks, %d failed" % (len(results), failed))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
