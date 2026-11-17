#!/usr/bin/env python3
"""Bundle 1 round 10, calculator repair pass 1: the short word /calc (CHAT-6, REQUEST-LOG-CROSS-CHAT.md, her words: "Is it possible
for /notes /calc to be commands that the addon recognizes and accepts in the console to open the notes and calculator respectively?";
built on qa-installer-branch in Bonus 0.6.17 Utilities.lua, QA test slash_words), brought back with the Calculator inside XayaUI_Bonus
(SD-95 / SD-115), under SD-116 ("the chat calls only become available if individual components are enabled") and SD-118 ("All parts,
say how"). Main has no Notepad, so only /calc.
This test loads the REAL addons in the stand-in game (tests/harness) and types /calc the way the chat box looks a word up (its cache
hash_SlashCmdList first, then every SLASH_<KEY><n> word of SlashCmdList). What the player sees and gets:
  A  fresh install (Calculator on by default): /calc 23,249 / 3,472 prints exactly "XayaUI: 23,249 / 3,472 = 6.696141" (23249 / 3472
     = 6.69614055..., six decimals), the same line as /xui calc; /calc alone opens the keypad, again closes it; a wrong sum prints its
     reason; /calc is the only new word (no /calculator, /notes); one owner of /calc; the word is claimed at login, not before.
  B  switched off in the session (its switch): /calc, /calc 2+2 print exactly "XayaUI: The Calculator is off. Turn it on in /xui >
     Bonus Features." and nothing else, no keypad is made; switched on again: /calc 2+2 answers at once, no /reload.
  C  saved off at login: /calc is still there and prints the one line (not the game's "unknown command"); nothing of the keypad made.
  D  another addon already has /calc (in SlashCmdList, registered before XayaUI Bonus loaded): ours is not written; that addon still
     gets the word; /xui calc still works.
  E  another addon that loads AFTER XayaUI Bonus but before login takes /calc: still left alone (the claim waits for login).
  F  a secure command, or the chat box's cache, already has /calc: left alone.
  G  XayaUI Bonus Features switched off in the AddOns list: no /calc of ours at all.
  H  per event: typing /calc adds no event, OnUpdate or timer, and the word's handler is the same function each time (no function made
     per call).
In-game behaviour is UNVERIFIED IN GAME (V25: the harness is a stand-in). The chat box's tables are not in the 12.1.5 API documentation
(INFERENCE, as in Calculator.lua).
Run: python3 tests/fix_r10_calculator_slash_run.py"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

COMMON = r'''
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local function section(name, fn) local ok, err = pcall(fn); if not ok then check(name .. ": ran to its end (a Lua error stopped it)", false, err) end end
local CALC_FILE = "@Interface/AddOns/XayaUI_Bonus/Calculator.lua"
local function fromCalc()
  for lv = 3, 60 do local info = debug.getinfo(lv, "S"); if not info then break end; if info.source == CALC_FILE then return true end end
  return false
end
local timers = 0
local rawCreate = CreateFrame
CreateFrame = function(...) local f = rawCreate(...); if fromCalc() then rawset(f, "_calc", true) end; return f end
for _, k in ipairs({ "After", "NewTimer", "NewTicker" }) do
  local raw = C_Timer[k]
  C_Timer[k] = function(...) if fromCalc() then timers = timers + 1 end; return raw(...) end
end
local function mine() local t = {}; for _, o in ipairs(W.objects) do if rawget(o, "_calc") then t[#t + 1] = o end end; return t end
local function eventsAndUpdates()
  local ev, upd = {}, 0
  for _, o in ipairs(mine()) do for e in pairs(o._events) do ev[#ev + 1] = e end; if o._scripts.OnUpdate then upd = upd + 1 end end
  table.sort(ev); return table.concat(ev, ","), upd
end
local function plain(l) return (tostring(l):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
-- the SlashCmdList keys that own a word (any SLASH_<key><n>)
local function owners(word)
  local t = {}
  for key in pairs(SlashCmdList) do
    local i = 1
    while rawget(_G, "SLASH_" .. key .. i) do if rawget(_G, "SLASH_" .. key .. i):lower() == word then t[#t + 1] = key end; i = i + 1 end
  end
  table.sort(t); return t
end
-- typing "/word rest" in the chat box: its cache first, then the word's owner in SlashCmdList; returns what printed and who took it
local function type_(line)
  local word, rest = line:match("^(%S+)%s*(.-)$")
  local before = #W.printed
  local who
  local h = hash_SlashCmdList[word:upper()]
  if h then who = "cache"; h(rest)
  else
    local o = owners(word:lower())
    if o[1] then who = o[1]; SlashCmdList[o[1]](rest) end
  end
  W.tick(0.1, 2)
  local out = {}
  for i = before + 1, #W.printed do out[#out + 1] = plain(W.printed[i]) end
  return out, who
end
local function chat(s)
  local before = #W.printed
  SlashCmdList.XAYAUI(s); W.tick(0.1, 2)
  local out = {}
  for i = before + 1, #W.printed do out[#out + 1] = plain(W.printed[i]) end
  return out
end
local function kp() return rawget(_G, "XayaUICalculator") end
local function shown() local f = kp(); return f ~= nil and f:IsShown() end
local OFF = "XayaUI: The Calculator is off. Turn it on in /xui > Bonus Features."
local OTHER = {}
local function otherCalc(msg) OTHER[#OTHER + 1] = tostring(msg) end
'''

LOGIN = r'''
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.2, 10)
local ns = rawget(_G, "XayaUI_NS")
'''

S_FRESH = r'''
return function(W, L)
''' + COMMON + r'''
L.startup()
local beforeLogin = rawget(_G, "SLASH_XUICALC1")
''' + LOGIN + r'''
section("A", function()
  check("A /calc is not claimed before login (the claim waits for every addon that loads at login)", beforeLogin == nil, beforeLogin)
  check("A at login /calc is claimed: SLASH_XUICALC1 is exactly '/calc', and it has exactly one owner", rawget(_G, "SLASH_XUICALC1") == "/calc"
    and table.concat(owners("/calc"), ",") == "XUICALC" and rawget(_G, "SLASH_XUICALC2") == nil, table.concat(owners("/calc"), ","))
  check("A it is the only new word: no /calculator or /notes of ours", #owners("/calculator") == 0 and #owners("/notes") == 0)
  local o, who = type_("/calc 23,249 / 3,472")
  check("A /calc 23,249 / 3,472 prints exactly 'XayaUI: 23,249 / 3,472 = 6.696141' (the same line as /xui calc)",
    who == "XUICALC" and #o == 1 and o[1] == "XayaUI: 23,249 / 3,472 = 6.696141", tostring(who) .. ": " .. table.concat(o, " / "))
  local x = chat("calc 23,249 / 3,472")
  check("A ...and /xui calc 23,249 / 3,472 prints the same line", #x == 1 and x[1] == o[1], table.concat(x, " / "))
  local o2 = type_("/CALC 1/0")
  check("A a wrong sum prints its reason (the word in capitals works too): 'XayaUI: calc: cannot divide by zero (1/0)'",
    #o2 == 1 and o2[1] == "XayaUI: calc: cannot divide by zero (1/0)", table.concat(o2, " / "))
  check("A ...a chat sum made no keypad", kp() == nil and #mine() == 0, #mine())
  local o3 = type_("/calc")
  check("A /calc alone prints nothing and opens the keypad", #o3 == 0 and shown(), table.concat(o3, " / "))
  type_("/calc")
  check("A /calc alone again closes it", not shown())
  check("A the sums typed with /calc are kept in its history (as /xui calc's)", XayaUIBonusDB.calculator.history[1] == "23,249 / 3,472 = 6.696141",
    tostring(XayaUIBonusDB.calculator.history[1]))
end)
section("B", function()
  type_("/calc")
  check("B (setup) the keypad is open", shown())
  ns.Calculator_SetEnabled(false)
  local nObj = #W.objects
  local o1, o2 = type_("/calc"), type_("/calc 2+2")
  check("B switched off: /calc and /calc 2+2 each print exactly '" .. OFF .. "' and nothing else",
    #o1 == 1 and o1[1] == OFF and #o2 == 1 and o2[1] == OFF, table.concat(o1, " / ") .. " | " .. table.concat(o2, " / "))
  check("B ...the keypad stays closed and nothing new is made", not shown() and #W.objects == nObj, #W.objects - nObj)
  ns.Calculator_SetEnabled(true)
  local o3 = type_("/calc 2+2")
  check("B switched on again: /calc 2+2 answers at once ('XayaUI: 2+2 = 4'), no /reload", #o3 == 1 and o3[1] == "XayaUI: 2+2 = 4", table.concat(o3, " / "))
end)
section("H", function()
  local fn1 = SlashCmdList.XUICALC
  local ev, upd = eventsAndUpdates()
  local t0 = timers
  type_("/calc 3*3"); type_("/calc"); type_("/calc")
  local ev2, upd2 = eventsAndUpdates()
  check("H /calc adds no event, no OnUpdate and no timer", ev2 == ev and ev2 == "" and upd2 == upd and upd2 == 0 and timers == t0 and t0 == 0,
    ev2 .. " " .. upd2 .. " " .. timers)
  check("H the word's handler is one function, the same on every use (no function made per call)", type(fn1) == "function" and SlashCmdList.XUICALC == fn1)
end)
return R
end
'''

S_OFF = r'''
return function(W, L)
''' + COMMON + r'''
L.startup()
''' + LOGIN + r'''
section("C", function()
  local o1, who = type_("/calc")
  local o2 = type_("/calc 3*3")
  check("C saved off at login: /calc is still ours and prints exactly the one line, for /calc and /calc 3*3",
    who == "XUICALC" and #o1 == 1 and o1[1] == OFF and #o2 == 1 and o2[1] == OFF, tostring(who) .. ": " .. table.concat(o1, " / ") .. " | " .. table.concat(o2, " / "))
  check("C ...nothing of the keypad is made", kp() == nil and #mine() == 0, #mine())
end)
return R
end
'''

S_TAKEN = r'''
return function(W, L)
''' + COMMON + r'''
SLASH_OTHERCALC1 = "/CALC"; SlashCmdList.OTHERCALC = otherCalc
L.startup()
''' + LOGIN + r'''
section("D", function()
  check("D another addon's /calc (there before XayaUI Bonus): ours is not written", rawget(_G, "SLASH_XUICALC1") == nil and SlashCmdList.XUICALC == nil
    and ns.Calculator_SlashClaimed() == false)
  local o, who = type_("/calc 2+2")
  check("D ...that addon still gets /calc (and the sum), one owner", who == "OTHERCALC" and OTHER[1] == "2+2" and #o == 0 and #owners("/calc") == 1,
    tostring(who) .. " " .. tostring(OTHER[1]))
  local x = chat("calc 2+2")
  check("D ...and /xui calc still works: 'XayaUI: 2+2 = 4'", #x == 1 and x[1] == "XayaUI: 2+2 = 4", table.concat(x, " / "))
end)
return R
end
'''

S_LATE = r'''
return function(W, L)
''' + COMMON + r'''
L.startup()
-- an addon that loads after XayaUI Bonus (later in the AddOns list) takes /calc at its own load, before the login
SLASH_LATECALC1 = "/calc"; SlashCmdList.LATECALC = otherCalc
''' + LOGIN + r'''
section("E", function()
  local o, who = type_("/calc 5")
  check("E an addon that loads after XayaUI Bonus and takes /calc keeps it: ours is not written, one owner",
    rawget(_G, "SLASH_XUICALC1") == nil and SlashCmdList.XUICALC == nil and who == "LATECALC" and #owners("/calc") == 1 and OTHER[1] == "5",
    tostring(who) .. " " .. table.concat(owners("/calc"), ","))
end)
return R
end
'''

S_SECURE = r'''
return function(W, L)
''' + COMMON + r'''
SecureCmdList = SecureCmdList or {}
SLASH_SECCALC1 = "/calc"; SecureCmdList.SECCALC = otherCalc
L.startup()
''' + LOGIN + r'''
section("F", function()
  check("F a secure command's /calc is left alone", rawget(_G, "SLASH_XUICALC1") == nil and SlashCmdList.XUICALC == nil)
end)
return R
end
'''

S_CACHE = r'''
return function(W, L)
''' + COMMON + r'''
L.startup()
hash_SlashCmdList["/CALC"] = otherCalc
''' + LOGIN + r'''
section("F", function()
  check("F a word already in the chat box's cache is left alone", rawget(_G, "SLASH_XUICALC1") == nil and SlashCmdList.XUICALC == nil)
end)
return R
end
'''

S_NOBONUS = r'''
return function(W, L)
''' + COMMON + r'''
L.startup()
''' + LOGIN + r'''
section("G", function()
  check("G XayaUI Bonus Features off in the AddOns list: no /calc of ours at all", not C_AddOns.IsAddOnLoaded("XayaUI_Bonus")
    and rawget(_G, "SLASH_XUICALC1") == nil and SlashCmdList.XUICALC == nil and #owners("/calc") == 0)
end)
return R
end
'''


def session(src, saved, disabled=()):
    folders = H.find_addons()
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    opts = H.to_lua(L, {"folders": folders, "enabled": {k: (k not in disabled) for k in folders}})
    opts["saved"] = H.to_lua(L, saved or {})
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(os.path.join(H.HERE, "loader.lua"), world, opts)
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(src, world, loader)
    results = [(res[i][1], res[i][2]) for i in range(1, len(res) + 1)]
    errs = [str(world.errors[i]) for i in range(1, len(world.errors) + 1)]
    return results, errs


OFF_SAVED = {"XayaUI_Bonus": {"XayaUIBonusDB": {"storeVersion": 1, "calculator": {"enabled": False}}}}


def main():
    bad = n = 0
    errs = []
    for tag, src, saved, disabled in (("fresh install", S_FRESH, {}, ()), ("saved off", S_OFF, OFF_SAVED, ()),
                                      ("taken before", S_TAKEN, {}, ()), ("taken after", S_LATE, {}, ()),
                                      ("secure", S_SECURE, {}, ()), ("cache", S_CACHE, {}, ()),
                                      ("Bonus off", S_NOBONUS, {}, ("XayaUI_Bonus",))):
        r, e = session(src, saved, disabled)
        for name, ok in r:
            n += 1
            print(("PASS " if ok else "FAIL ") + "[%s] %s" % (tag, name))
            bad += 0 if ok else 1
        errs.extend("[%s] %s" % (tag, x) for x in e)
    for e in errs:
        print("ERROR in the game stand-in:", e[:600])
    print("%d checks, %d failed, %d Lua errors" % (n, bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
