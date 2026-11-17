#!/usr/bin/env python3
"""Bundle 1 round 10, calculator unit (REQUEST-LOG SD-95 "Arithmetic, own part (Recommended)", SD-115 "Inside Bonus (Recommended)",
SD-116 "2 but the chat calls only become available if individual components are enabled", SD-117 "600, same as core (Recommended)",
SD-118 "All parts, say how (Recommended)", SD-99 (her words: "XUI windows that are actively opened and have the mouse over them should
accept clicks"), V27, V29): the project's own arithmetic Calculator (qa-installer-branch XayaUI_Bonus/Calculator.lua) is back INSIDE
XayaUI_Bonus (XayaUI_Bonus/Calculator.lua, listed in its .toc), with its own switch in Bonus Features, on by default.
This test loads the REAL addons in the stand-in game (tests/harness) and checks what the player sees and gets:
  A  login (fresh install): XayaUI Bonus Features reads Calculator.lua, and it makes no frame, no event, no OnUpdate, no timer and writes
     no saved table (the keypad is made only at its first open).
  B  chat sums: "/xui calc 23,249 / 3,472" prints exactly "XayaUI: 23,249 / 3,472 = 6.696141" (23249 / 3472 = 6.69614055..., six
     decimals); "/xui calculator 2+2" prints "XayaUI: 2+2 = 4"; a wrong sum prints its reason; /xui help lists /xui calc and /xui
     calculator (on by default).
  C  the keypad: "/xui calc" alone opens the window, the first time making its frames; the cursor is in its line and typed keys go there
     (it is open and focused); a click on keys builds a sum and "=" works it out; the minimap list has a Calculator row that opens and
     closes it; everything that takes the mouse sits inside the window (SD-99).
  D  keys given back (V29): Enter works the sum out and lets go (the screenshot key and W reach the game); Esc lets go, a second Esc
     closes the window (the game's Esc list); a click outside lets go; combat start lets go; closed, no key is kept.
  E  combat (V26 exempt, V29): opened in combat it shows without taking the keyboard; a fight starting with the cursor in its line lets
     go; nothing of the Calculator runs at combat start or end.
  F  per event (SD-117: at most 600 for XayaUI_Bonus): with the keypad closed, open, and open with the cursor in its line, a batch of
     game events runs 0 Lua instructions in Calculator.lua (stand-in count).
  G  whole pixels (V27): a drag that ends at a fraction saves and draws whole pixels.
  H  the settings window: Bonus Features has a Calculator page whose row carries the tick box (ticked: on by default); the REAL tick box
     clicked off: saved off at once (no "Reload now?" question), the open keypad closes, "/xui calc" and "/xui calc 2+2" print exactly
     "XayaUI: The Calculator is off. Turn it on in /xui > Bonus Features." and nothing else, /xui help leaves both words out, the minimap
     row is gone, the page's Open button is greyed; clicked on again: all back, no /reload.
  I  the element menu (QA #495): with the settings window shown, a right-click on the keypad offers Element options, which opens Bonus
     Features > Calculator.
  J  saved off at login: no frame of it whichever way it is asked for, the words print the one line, help lists none, no row.
  K  profiles: the Bonus Features part carries the Calculator's switch (not its sums or place, as on QA); importing "off" closes an open
     keypad and turns its words off at once.
Negative control: on the pre-change files (no Calculator.lua in XayaUI_Bonus) nearly every check fails (the words are never
registered; core's line says so). In-game behaviour is UNVERIFIED IN GAME (V25: the harness is a stand-in). Instruction counts are
stand-in numbers.
Run: python3 tests/fix_r10_calculator_run.py   (Lua 5.1 via lupa; the settings window part takes a few seconds)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

COMMON = r'''
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local function section(name, fn) local ok, err = pcall(fn); if not ok then check(name .. ": ran to its end (a Lua error stopped it)", false, err) end end
local CALC_FILE = "@Interface/AddOns/XayaUI_Bonus/Calculator.lua"   -- (the chunk name the game stand-in gives the file)
local function fromCalc()
  for lv = 3, 60 do
    local info = debug.getinfo(lv, "S")
    if not info then break end
    if info.source == CALC_FILE then return true end
  end
  return false
end
local read = false
local rawLoadstring = loadstring
loadstring = function(src, name)
  if name == CALC_FILE then read = true end
  return rawLoadstring(src, name)
end
local timers = 0
local rawCreate = CreateFrame
CreateFrame = function(...) local f = rawCreate(...); if fromCalc() then rawset(f, "_calc", true) end; return f end
for _, k in ipairs({ "After", "NewTimer", "NewTicker" }) do
  local raw = C_Timer[k]
  C_Timer[k] = function(...) if fromCalc() then timers = timers + 1 end; return raw(...) end
end
local asked = {}
local rawShow = StaticPopup_Show
StaticPopup_Show = function(which, a1, ...) asked[#asked + 1] = { which, a1 }; return rawShow(which, a1, ...) end
local function mine() local t = {}; for _, o in ipairs(W.objects) do if rawget(o, "_calc") then t[#t + 1] = o end end; return t end
local function eventsAndUpdates()
  local ev, upd = {}, 0
  for _, o in ipairs(mine()) do
    for e in pairs(o._events) do ev[#ev + 1] = e end
    if o._scripts.OnUpdate then upd = upd + 1 end
  end
  table.sort(ev)
  return table.concat(ev, ","), upd
end
local function plain(l) return (tostring(l):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function chat(s)
  local before = #W.printed
  SlashCmdList.XAYAUI(s); W.tick(0.1, 2)
  local out = {}
  for i = before + 1, #W.printed do out[#out + 1] = plain(W.printed[i]) end
  return out
end
local function helpHas(needle) local h = chat("help"); for i = 2, #h do if h[i]:find(needle, 1, true) then return true end end return false end
local function kp() return rawget(_G, "XayaUICalculator") end
local function shown() local f = kp(); return f ~= nil and f:IsShown() end
local function line() local f = kp(); return f and f.edit end
local function focused() local e = line(); return e ~= nil and e:HasFocus() end
local function launcher()
  local ns0 = rawget(_G, "XayaUI_NS")
  for _, e in ipairs(ns0.Launchers and ns0.Launchers() or {}) do if e[1] == "calc" then return e end end
end
local function rowAvailable() local e = launcher(); return e ~= nil and (type(e.available) ~= "function" or (e.available() and true or false)) end
-- Esc as the game does it: a text box with the cursor takes it first; else the game's Esc closes the shown frames of its Esc list
local function esc()
  local got = W.pressKey("ESCAPE")
  if got == "game" then for _, n in ipairs(UISpecialFrames) do local f = rawget(_G, n); if f and f.IsShown and f:IsShown() then f:Hide() end end end
  W.tick(0.05, 2)
  return got
end
local function key(k) local f = kp(); for _, b in ipairs(f.keys) do if b.calcKey == k then W.click(b) end end end
-- Lua instructions run inside Calculator.lua while fn runs (stand-in count)
local function calcCost(fn)
  local n = 0
  debug.sethook(function()
    local info = debug.getinfo(2, "S")
    if info and info.source == CALC_FILE then n = n + 1 end
  end, "", 1)
  local ok, err = pcall(fn)
  debug.sethook()
  if not ok then error(err, 0) end
  return n
end
local BATCH = { { "PLAYER_REGEN_DISABLED" }, { "PLAYER_REGEN_ENABLED" }, { "UNIT_AURA", "player" }, { "SPELL_UPDATE_COOLDOWN" },
  { "PLAYER_TARGET_CHANGED" }, { "GLOBAL_MOUSE_DOWN", "LeftButton" }, { "BAG_UPDATE_DELAYED" }, { "UNIT_POWER_FREQUENT", "player" } }
local function batch() for _, e in ipairs(BATCH) do W.fire(e[1], e[2]) end; W.tick(0.05, 3) end
local OFF = "XayaUI: The Calculator is off. Turn it on in /xui > Bonus Features."
'''

LOGIN = r'''
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.2, 10)
local ns = rawget(_G, "XayaUI_NS")
'''

WINDOW = r'''
local reg, ACD
local function root() return ACD and ACD.OpenFrames and ACD.OpenFrames["CueRules"] end
local function findW(w, pred)
  if not w then return nil end
  if pred(w) then return w end
  for _, c in ipairs(w.children or {}) do local f = findW(c, pred); if f then return f end end
end
local function tree(tab) return findW(root(), function(w) local u = w.type == "TreeGroup" and w:GetUserDataTable(); return u and u.path and u.path[1] == tab and #u.path == 1 end) end
local function row(tab, uv) local t = tree(tab); for _, b in ipairs(t and t.buttons or {}) do if b:IsShown() and b.uniquevalue == uv then return b end end end
local function box(tab, uv) local b = row(tab, uv); local x = b and b.xuiSwitchBox; return (x and x:IsShown()) and x or nil end
local function settle(steps)
  W.tick(0.05, steps or 6)
  local t = tree("bonus"); local f = t and t.treeframe and t.treeframe:GetScript("OnSizeChanged")
  if f then t.xuiLines = nil; f(t.treeframe) end
end
local function openWindow()
  ns.LoadOptions(); W.tick(0.1, 3)
  ns = rawget(_G, "XayaUI_NS")
  reg, ACD = LibStub("AceConfigRegistry-3.0"), LibStub("AceConfigDialog-3.0")
  CueRulesDB.ui = CueRulesDB.ui or {}; CueRulesDB.ui.consoleAutoOpen = false
  if not root() then pcall(ns.ToggleUI) end; settle()
  ACD:SelectGroup("CueRules", "bonus", "calculator"); settle()
end
local function click(v)   -- the game flips the check box's tick, then runs its OnClick; then the next frames
  local x = box("bonus", "calculator"); if not x then return false end
  x:SetChecked(v); x:Click("LeftButton")
  settle()
  return true
end
local function optName(w) local o = w.GetUserData and w:GetUserData("option"); return o and o.name end
local function button(text) return findW(root(), function(w) return w.type == "Button" and optName(w) == text end) end
'''

S_FRESH = r'''
return function(W, L)
''' + COMMON + LOGIN + WINDOW + r'''
section("A", function()
  local ev, upd = eventsAndUpdates()
  check("A login: XayaUI Bonus Features read Calculator.lua (inside XayaUI_Bonus, no folder of its own: SD-115)", read and C_AddOns.IsAddOnLoaded("XayaUI_Bonus"))
  check("A ...it made no frame (the keypad is made at its first open), no event, no OnUpdate, no timer", #mine() == 0 and ev == "" and upd == 0 and timers == 0,
    #mine() .. " frames, events " .. ev .. ", " .. upd .. " OnUpdate, " .. timers .. " timers")
  check("A ...and wrote no saved table (nothing until it is used)", type(XayaUIBonusDB) ~= "table" or XayaUIBonusDB.calculator == nil)
end)
section("B", function()
  local o = chat("calc 23,249 / 3,472")
  check("B /xui calc 23,249 / 3,472 prints exactly 'XayaUI: 23,249 / 3,472 = 6.696141'", #o == 1 and o[1] == "XayaUI: 23,249 / 3,472 = 6.696141", table.concat(o, " / "))
  local o2 = chat("calculator 2+2")
  check("B /xui calculator 2+2 prints exactly 'XayaUI: 2+2 = 4'", #o2 == 1 and o2[1] == "XayaUI: 2+2 = 4", table.concat(o2, " / "))
  local o3 = chat("calc 1/0")
  check("B a wrong sum prints its reason: 'XayaUI: calc: cannot divide by zero (1/0)'", #o3 == 1 and o3[1] == "XayaUI: calc: cannot divide by zero (1/0)", table.concat(o3, " / "))
  check("B ...a chat sum made no window", #mine() == 0 and kp() == nil, #mine())
  check("B /xui help lists /xui calc [sum] and /xui calculator [sum] (on by default, SD-116 / SD-118)", helpHas("/xui calc [sum]") and helpHas("/xui calculator [sum]"))
end)
section("C", function()
  local o = chat("calc")
  check("C /xui calc alone prints nothing and opens the keypad (its frames made now, the first open)", #o == 0 and shown() and #mine() > 0, table.concat(o, " / "))
  check("C ...the window is in the game's Esc list, once", (function() local n = 0; for _, x in ipairs(UISpecialFrames) do if x == "XayaUICalculator" then n = n + 1 end end; return n end)() == 1)
  check("C ...the cursor is in its line (open and focused): typed keys go there, not to the game", focused() and W.pressKey("W") == line(), tostring(focused()))
  -- every frame of it that takes the mouse sits inside the window (SD-99)
  local f = kp()
  local L0, B0, Wd, Ht = f:GetRect()
  local outside
  for _, o2 in ipairs(mine()) do
    -- (a Button or an EditBox takes clicks unless told not to, as in the game; the gate reads it the same way)
    local takes = o2._mouse or (not o2._mouseSet and (o2._kind == "Button" or o2._kind == "EditBox" or o2._kind == "CheckButton"))
    if o2:IsVisible() and takes then
      local l, b, w, h = o2:GetRect()
      if l and (l < L0 - 0.01 or b < B0 - 0.01 or l + w > L0 + Wd + 0.01 or b + h > B0 + Ht + 0.01) then outside = tostring(o2._name or o2._kind) end
    end
  end
  check("C everything of it that takes the mouse sits inside the window (SD-99)", outside == nil, outside)
  -- the keypad by mouse
  key("C"); key("1"); key("2"); key("+"); key("3"); key("=")
  check("C clicks on 1 2 + 3 = show 15, and the line keeps 15 for the next sum", f.result:GetText() == "15" and f.edit:GetText() == "15", tostring(f.result:GetText()))
  check("C ...the sum is in the history above", (f.history:GetText() or ""):find("12+3 = 15", 1, true) ~= nil, f.history:GetText())
  key("\195\151"); key("2"); key("=")
  check("C the multiply key builds on the answer: 15 x 2 = 30", f.result:GetText() == "30", f.result:GetText())
  W.click(f.close)
  check("C its x button closes it", not shown())
  check("C the minimap list has a Calculator row (just the name: O-100)", launcher() ~= nil and launcher()[2] == "Calculator" and rowAvailable())
  launcher()[4]()
  check("C ...the row opens it", shown())
  launcher()[4]()
  check("C ...and closes it", not shown())
end)
section("D", function()
  chat("calc")
  check("D setup: open, the cursor in its line", shown() and focused())
  local e = line()
  e:SetText("6*7")
  W.pressKey("ENTER"); W.tick(0.05, 2)
  check("D Enter works the sum out (42) and lets go of the keyboard", kp().result:GetText() == "42" and not focused(), tostring(kp().result:GetText()) .. " " .. tostring(focused()))
  check("D ...the screenshot key and W reach the game", W.pressKey("PRINTSCREEN") == "game" and W.pressKey("W") == "game")
  W.click(e)
  check("D a click in the line gives it the cursor again", focused())
  local g1 = esc()
  check("D Esc lets go of the keyboard (the window stays open)", g1 == e and not focused() and shown())
  esc()
  check("D a second Esc closes the window (the game's Esc list)", not shown())
  check("D closed: the screenshot key, Esc's own use and W reach the game", W.pressKey("PRINTSCREEN") == "game" and W.pressKey("W") == "game")
  chat("calc")
  check("D reopened with the cursor in its line", focused())
  W.click(UIParent)
  check("D a click outside the window lets go (the screenshot key reaches the game)", not focused() and W.pressKey("PRINTSCREEN") == "game")
  W.click(e)
  chat("calc")
  check("D closed with the cursor in its line: it lets go as it hides; keys reach the game", not shown() and not focused() and W.pressKey("PRINTSCREEN") == "game")
end)
section("E", function()
  chat("calc")
  check("E setup: open with the cursor in its line", focused())
  W.enterCombat(); W.tick(0.05, 2)
  check("E a fight starting lets go of the keyboard; the window stays (it reads only its own state: V26 exempt)", not focused() and shown()
    and W.pressKey("PRINTSCREEN") == "game" and W.pressKey("W") == "game")
  chat("calc")
  check("E (closed in combat)", not shown())
  chat("calc")
  check("E opened in combat: shown, without taking the keyboard (V29); keys reach the game", shown() and not focused() and W.pressKey("W") == "game")
  key("C"); key("9"); key("="); W.tick(0.05, 1)
  check("E ...its keys still work by mouse in combat (9)", kp().result:GetText() == "9", kp().result:GetText())
  local o = chat("calc 5*5")
  check("E a chat sum in combat answers", #o == 1 and o[1] == "XayaUI: 5*5 = 25", table.concat(o, " / "))
  W.leaveCombat(); W.tick(0.05, 2)
  chat("calc")
  check("E (closed)", not shown())
end)
section("F", function()
  local ev, upd = eventsAndUpdates()
  check("F the keypad, once made, listens to no event, has no OnUpdate, made no timer", ev == "" and upd == 0 and timers == 0, ev .. " " .. upd .. " " .. timers)
  local closedN = calcCost(batch)
  chat("calc"); W.click(UIParent)
  local openN = calcCost(batch)
  W.click(line())
  local focusN = calcCost(function() W.fire("GLOBAL_MOUSE_DOWN", "LeftButton"); W.enterCombat(); W.tick(0.05, 2); W.leaveCombat(); W.tick(0.05, 2) end)
  chat("calc")
  local sumN = calcCost(function() chat("calc 1+1") end)
  check("F (control: the count sees Calculator.lua when it does run: a chat sum costs " .. sumN .. " instructions there)", sumN > 0, sumN)
  check("F per event (SD-117, cap 600 for XayaUI_Bonus): a batch of " .. #BATCH .. " game events runs 0 instructions in Calculator.lua with the keypad closed, open, and open with the cursor in its line (combat start and end included)",
    closedN == 0 and openN == 0 and focusN == 0, closedN .. " / " .. openN .. " / " .. focusN)
end)
section("G", function()
  chat("calc")
  local f = kp()
  f:ClearAllPoints(); f:SetPoint("CENTER", UIParent, "CENTER", 12.6, -7.4)
  f.bar:GetScript("OnDragStop")(f.bar)
  local d = XayaUIBonusDB.calculator
  local p, _, _, x, y = f:GetPoint(1)
  check("G a drag that ends at (12.6, -7.4) saves and draws whole pixels (13, -7): V27", d.point == "CENTER" and d.x == 13 and d.y == -7 and x == 13 and y == -7,
    tostring(d.x) .. "," .. tostring(d.y) .. " drawn " .. tostring(x) .. "," .. tostring(y))
  chat("calc")
end)
section("H/I window", function()
  openWindow()
  check("H the settings window shows Bonus Features > Calculator with the tick box on its row, ticked (on by default)",
    row("bonus", "calculator") ~= nil and box("bonus", "calculator") ~= nil and box("bonus", "calculator"):GetChecked() == true)
  -- I: the element menu on the keypad while the settings window is shown
  chat("calc")
  local opened = {}
  local rawOpen = ns.OpenSettingsPage
  ns.OpenSettingsPage = function(...) opened[#opened + 1] = table.concat({ ... }, "/"); return rawOpen(...) end
  local defs = ns.ElementDefs and ns.ElementDefs() or {}
  check("I the keypad registered its element (made at its first open)", defs.calculator ~= nil and defs.calculator.page[1] == "bonus" and defs.calculator.page[2] == "calculator")
  local menuUp = ns.ElementRightClick and ns.ElementRightClick(kp(), "OnMouseUp")
  local m = ns.ElementMenu and ns.ElementMenu()
  check("I with the settings window shown, a right-click on the keypad opens the element menu", menuUp == true and m ~= nil and m:IsShown(), tostring(menuUp))
  if m and m.options then W.click(m.options) end
  ns.OpenSettingsPage = rawOpen
  check("I ...its Element options opens Bonus Features > Calculator", opened[1] == "bonus/calculator", table.concat(opened, ","))
  settle()
  -- H: the real tick box, off
  local nAsk = #asked
  check("H the real tick box on the Calculator's row is clickable", click(false))
  check("H ticked off: saved off at once, no 'Reload now?' question (SD-86)", XayaUIBonusDB.calculator.enabled == false and #asked == nAsk, #asked - nAsk)
  check("H ...the open keypad closed", not shown())
  local o1, o2, o3 = chat("calc"), chat("calc 2+2"), chat("calculator")
  check("H off: /xui calc, /xui calc 2+2 and /xui calculator each print exactly '" .. OFF .. "'",
    #o1 == 1 and o1[1] == OFF and #o2 == 1 and o2[1] == OFF and #o3 == 1 and o3[1] == OFF and not shown(),
    table.concat(o1, " / ") .. " | " .. table.concat(o2, " / ") .. " | " .. table.concat(o3, " / "))
  check("H off: /xui help leaves /xui calc and /xui calculator out (SD-118)", not helpHas("/xui calc"))
  check("H off: no Calculator row in the minimap list", not rowAvailable())
  local open = button("Open calculator")
  check("H off: the page's Open calculator button is greyed", open ~= nil and open.disabled == true, open and tostring(open.disabled))
  check("H off: the box shows it unticked", box("bonus", "calculator") and box("bonus", "calculator"):GetChecked() == false)
  -- on again
  check("H the tick box clicked on again", click(true))
  local o4 = chat("calc 2+2")
  check("H on again at once (no /reload, no question): /xui calc 2+2 answers, help lists it, the row is back",
    #asked == nAsk and #o4 == 1 and o4[1] == "XayaUI: 2+2 = 4" and helpHas("/xui calc [sum]") and rowAvailable(), table.concat(o4, " / "))
  local open2 = button("Open calculator")
  if open2 then open2.frame:Click("LeftButton"); W.tick(0.05, 2) end
  check("H on: the page's Open calculator button opens the keypad", open2 ~= nil and not open2.disabled and shown())
  chat("calc")
end)
return R
end
'''

S_OFF = r'''
return function(W, L)
''' + COMMON + LOGIN + r'''
section("J", function()
  local o1, o2 = chat("calc"), chat("calculator 3*3")
  launcher()[4]()
  if ns.Calculator_Open then ns.Calculator_Open() end
  check("J saved off at login: /xui calc and /xui calculator 3*3 each print exactly the one line", #o1 == 1 and o1[1] == OFF and #o2 == 1 and o2[1] == OFF,
    table.concat(o1, " / ") .. " | " .. table.concat(o2, " / "))
  check("J ...no frame of it, whichever way it is asked for (the row's action, the Open button's call)", #mine() == 0 and kp() == nil, #mine())
  check("J .../xui help lists none of its words; no minimap row", not helpHas("/xui calc") and not rowAvailable())
  check("J ...its saved sums are kept", #XayaUIBonusDB.calculator.history == 1 and XayaUIBonusDB.calculator.history[1] == "1+1 = 2")
end)
return R
end
'''

S_PROFILE = r'''
return function(W, L)
''' + COMMON + LOGIN + r'''
section("K", function()
  chat("calc 4+4"); chat("calc")
  local by = ns.ProfilePartsByKey()
  local part = by.bonus
  local snap = part and part.snapshot("") or {}
  local c = snap.calculator
  check("K the Bonus Features profile part carries the Calculator's switch, not its sums or place (as on QA)",
    type(c) == "table" and c.history == nil and c.point == nil and c.x == nil and c.y == nil and XayaUIBonusDB.calculator.history[1] == "4+4 = 8",
    c and (tostring(c.enabled) .. " history " .. tostring(c.history)))
  check("K (setup) the keypad is open", shown())
  local clean = part.check({ calculator = { enabled = false, history = { "9 = 9" } } })
  part.apply(clean, "merge", 2); W.tick(0.05, 2)
  local o = chat("calc 1+1")
  check("K importing it off: the keypad closes at once and its words print the one line; her sums are untouched",
    not shown() and XayaUIBonusDB.calculator.enabled == false and #o == 1 and o[1] == OFF and XayaUIBonusDB.calculator.history[1] == "4+4 = 8",
    table.concat(o, " / "))
  part.apply(part.check({ calculator = { enabled = true } }), "merge", 2); W.tick(0.05, 2)
  local o2 = chat("calc 1+1")
  check("K importing it on: its words work at once", #o2 == 1 and o2[1] == "XayaUI: 1+1 = 2", table.concat(o2, " / "))
end)
return R
end
'''


def session(src, saved):
    folders = H.find_addons()
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    opts = H.to_lua(L, {"folders": folders, "enabled": {k: True for k in folders}})
    opts["saved"] = H.to_lua(L, saved or {})
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(os.path.join(H.HERE, "loader.lua"), world, opts)
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(src, world, loader)
    results = [(res[i][1], res[i][2]) for i in range(1, len(res) + 1)]
    errs = [str(world.errors[i]) for i in range(1, len(world.errors) + 1)]
    return results, errs


OFF_SAVED = {"XayaUI_Bonus": {"XayaUIBonusDB": {"storeVersion": 1, "calculator": {"enabled": False, "history": ["1+1 = 2"]}}}}


def main():
    bad = n = 0
    errs = []
    for tag, src, saved in (("fresh install", S_FRESH, {}), ("saved off", S_OFF, OFF_SAVED), ("profile", S_PROFILE, {})):
        r, e = session(src, saved)
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
