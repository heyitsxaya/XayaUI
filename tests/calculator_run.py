# Test for XayaUI_Bonus 0.6.8 Calculator.lua ("a little calculator", Xaya 2026-11-04), run in Lua 5.1 with stand-in game functions.
# What it checks (outcomes: the answer or the reason shown, what chat prints, what the keypad does):
#   - sums: + - * / ^ with the usual order, brackets, a leading minus (-2^2 = -4), x and the multiply / divide / minus signs,
#     commas between groups of three, k / m / b, % after a number;
#   - answers written with commas and at most 6 decimals (expected values worked out in Python, not by the code under test);
#   - every way a sum can be wrong gives a reason, never a Lua error, and typed text is never run as code;
#   - /xui calc <sum> prints "sum = answer"; /xui calc alone shows / hides the window; the keypad builds a sum and = works it out;
#   - the keypad fits inside the window (V11); history keeps the last 10; Escape closes it; no global written by Calculator.lua.
# Deliberate breaks (MUTATIONS) each must make at least one check fail. The last line carries FAILS: <n>.
# Run from the repo root: python3 tests/calculator_run.py   Needs: pip install lupa.
import os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SRC_PATH = os.path.join(ROOT, "XayaUI_Bonus", "Calculator.lua")
SRC = open(SRC_PATH, encoding="utf-8").read() if os.path.exists(SRC_PATH) else None

WORLD = r'''
RESULTS, ORDER, FAILTXT, SECTION_ERRORS = {}, {}, {}, {}
function check(name, cond, extra)
  if RESULTS[name] ~= nil then error("duplicate check name: " .. name) end
  if cond then RESULTS[name] = true else RESULTS[name] = false; FAILTXT[name] = tostring(extra) end
  ORDER[#ORDER + 1] = name
end
function SECTION(name, f) local ok, err = pcall(f); if not ok then SECTION_ERRORS[#SECTION_ERRORS + 1] = name .. ": " .. tostring(err) end end

-- frames: every method is accepted; the ones the calculator reads back keep their state
local FM = {}
FM.__index = function(t, k)
  local f = rawget(FM, k)
  if f then return f end
  if type(k) == "string" and k:match("^%u") then return function() end end   -- any other frame method: accepted, does nothing
  return nil                                                                    -- plain fields (text, shown, w...) stay nil until set
end
function FM:SetText(s) self.text = s end
function FM:GetText() return self.text or "" end
function FM:Show() self.shown = true end
function FM:Hide() self.shown = false end
function FM:IsShown() return self.shown == true end
function FM:SetScript(k, f) self.scripts[k] = f end
function FM:SetSize(w, h) self.w, self.h = w, h end
function FM:SetPoint(...) self.points[#self.points + 1] = { ... } end
function FM:GetPoint() local p = self.points[1] or {}; return p[1], nil, nil, p[4], p[5] end
function FM:SetTextColor(r, g, b) self.color = { r, g, b } end
function FM:CreateFontString() return setmetatable({ scripts = {}, points = {} }, FM) end
function FM:CreateTexture() return setmetatable({ scripts = {}, points = {} }, FM) end
FRAMES = {}
CreateFrame = function(kind, name, parent, template)
  local f = setmetatable({ kind = kind, name = name, parent = parent, template = template, scripts = {}, points = {} }, FM)
  FRAMES[#FRAMES + 1] = f
  return f
end
UIParent = CreateFrame("Frame")
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
UISpecialFrames = {}
CueRulesDB = {}

-- XayaUI core's module API (Modules.lua) as stand-ins
PRINTED, COMMANDS, LAUNCHERS = {}, {}, {}
XayaUI_NS = {
  Print = function(...) local t = {} for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end; PRINTED[#PRINTED + 1] = table.concat(t, " ") end,
  RegisterCommand = function(names, fn) for _, n in ipairs(type(names) == "table" and names or { names }) do COMMANDS[n] = fn end end,
  RegisterLauncher = function(e) LAUNCHERS[e[1]] = e end,
}
LOADSTRING_CALLS = 0
local realLoadstring = loadstring
loadstring = function(...) LOADSTRING_CALLS = LOADSTRING_CALLS + 1; return realLoadstring(...) end
RunScript = function() LOADSTRING_CALLS = LOADSTRING_CALLS + 1 end

CALC_GLOBALS = {}
setmetatable(_G, { __newindex = function(t, k, v)
  local info = debug.getinfo(2, "S")
  if info and info.source and info.source:find("Calculator.lua", 1, true) then CALC_GLOBALS[#CALC_GLOBALS + 1] = tostring(k) end
  rawset(t, k, v)
end })
'''

CHECKS = r'''
SECTION("load", function()
  local chunk = assert(loadstring_real_for_test(CALC_SRC, "@Calculator.lua"))
  chunk("XayaUI_Bonus", XayaUI_NS)
  check("load: /xui calc and /xui calculator registered", type(COMMANDS.calc) == "function" and COMMANDS.calculator == COMMANDS.calc)
  check("load: Calculator in the minimap button's list", LAUNCHERS.calc ~= nil and LAUNCHERS.calc[2] == "Calculator")
end)
local ns = XayaUI_NS
local function ans(s) local v, err = ns.CalcEval(s); if v then return ns.CalcFormat(v) end; return "ERR: " .. tostring(err) end

SECTION("sums", function()
  local cases = {
    { "2+2", "4" }, { "23,249 / 3,472", "6.696141" }, { "-2^2", "-4" }, { "2^-1", "0.5" }, { "2^3^2", "512" },
    { "(1+2)*3", "9" }, { "1+2*3", "7" }, { "10 x 3", "30" }, { "12k / 4", "3,000" }, { "1.5m", "1,500,000" }, { "2b", "2,000,000,000" },
    { "15%", "0.15" }, { "200*15%", "30" }, { "7 \195\183 2", "3.5" }, { "6 \195\151 7", "42" }, { "3 \226\136\146 1", "2" },
    { ".5+.25", "0.75" }, { "0.1+0.2", "0.3" }, { "1234567.5", "1,234,567.5" }, { "-1234", "-1,234" }, { "  8 - 10 ", "-2" },
    { "1e3", "ERR: e3 is not something a sum can hold" },
  }
  for _, c in ipairs(cases) do check("sum: " .. c[1] .. " = " .. c[2], ans(c[1]) == c[2], ans(c[1])) end
  check("answer: very large in e-notation", ans("10^16") == "1e+16", ans("10^16"))
end)

SECTION("wrong sums", function()
  local cases = {
    { "1/0", "cannot divide by zero" }, { "1,23", "commas in 1,23 must separate groups of three digits" },
    { "1,2345", "commas in 1,2345 must separate groups of three digits" }, { "2+", "the sum ends too soon" },
    { "(2+3", "a closing bracket is missing" }, { "abc", "abc is not something a sum can hold" },
    { "2 3", "a number cannot go there" }, { "", "nothing to work out" }, { "   ", "nothing to work out" },
    { "10^400", "the answer is too large" }, { ")", ") cannot go there" }, { "12kg", "kg is not something a sum can hold" },
  }
  for _, c in ipairs(cases) do check("wrong: '" .. c[1] .. "' says " .. c[2], ans(c[1]) == "ERR: " .. c[2], ans(c[1])) end
  check("wrong: a sum over 200 characters is refused", ans(string.rep("1+", 101) .. "1"):find("at most 200", 1, true) ~= nil)
  local before = LOADSTRING_CALLS
  local v = ns.CalcEval("os.exit() + RunScript('x')")
  check("typed text is never run as code", v == nil and LOADSTRING_CALLS == before)
  check("the file never calls loadstring, load or RunScript", not CALC_SRC:find("loadstring%(") and not CALC_SRC:find("RunScript%(") and not CALC_SRC:find("[^%w_]load%("))
end)

SECTION("chat command", function()
  PRINTED = {}
  COMMANDS.calc("23,249 / 3,472")
  check("/xui calc <sum> prints sum = answer", PRINTED[1] == "23,249 / 3,472 = 6.696141", PRINTED[1])
  COMMANDS.calc("1/0")
  check("/xui calc with a wrong sum prints the reason", PRINTED[2] == "calc: cannot divide by zero (1/0)", PRINTED[2])
  check("chat sums go into the history", CueRulesDB.calculator.history[#CueRulesDB.calculator.history] == "23,249 / 3,472 = 6.696141")
  COMMANDS.calc("")
  local f = _G.__calcFrame or nil
  for _, fr in ipairs(FRAMES) do if fr.name == "XayaUICalculator" then f = fr end end
  CALCFRAME = f
  check("/xui calc alone shows the window", f ~= nil and f:IsShown())
  COMMANDS.calc("  ")
  check("/xui calc alone again hides it", f ~= nil and not f:IsShown())
  check("Escape closes it", UISpecialFrames[1] == "XayaUICalculator")
end)

SECTION("keypad", function()
  local f = CALCFRAME
  for _, k in ipairs({ "1", "2", "+", "3", "=" }) do ns.Calculator_Press(k) end
  check("keypad: 1 2 + 3 = shows 15", f.result.text == "15", f.result.text)
  check("keypad: the answer becomes the next sum", f.edit:GetText() == "15")
  check("keypad: the history lists the sum", (f.history.text or ""):find("12+3 = 15", 1, true) ~= nil, f.history.text)
  for _, k in ipairs({ "\195\151", "2", "=" }) do ns.Calculator_Press(k) end
  check("keypad: the multiply key builds on the answer (15 x 2 = 30)", f.result.text == "30", f.result.text)
  ns.Calculator_Press("C")
  check("keypad: C clears the line and the answer", f.edit:GetText() == "" and f.result.text == "")
  for _, k in ipairs({ "8", "\195\183", "0", "=" }) do ns.Calculator_Press(k) end
  check("keypad: 8 / 0 shows the reason in the answer line", f.result.text == "cannot divide by zero", f.result.text)
  check("keypad: a wrong sum keeps the line for fixing", f.edit:GetText() == "8\195\1830")
  -- layout (V11): 20 keys in 4 columns, every key inside the window's width
  local keys, maxRight = 0, 0
  for _, b in ipairs(f.keys) do
    keys = keys + 1
    local p = b.points[1]
    maxRight = math.max(maxRight, (p and p[4] or 0) + (b.w or 0))
  end
  check("layout: 20 keys", keys == 20, keys)
  check("layout: the keypad fits inside the window with its margins", maxRight + 2 * 10 <= f.w, tostring(maxRight) .. " / " .. tostring(f.w))
  for i = 1, 15 do COMMANDS.calc(i .. "+0") end
  check("history keeps the last 10", #CueRulesDB.calculator.history == 10 and CueRulesDB.calculator.history[10] == "15+0 = 15")
end)

SECTION("safety", function()
  check("no global written by Calculator.lua", #CALC_GLOBALS == 0, table.concat(CALC_GLOBALS, ","))
end)
'''

MUTATIONS = [
    ("no divide-by-zero check", [('                if r == 0 then error({ msg = "cannot divide by zero" }) end\n', "")]),
    ("minus binds tighter than ^", [("        local v = postfix()\n        if peek() == \"^\" then take(); v = v ^ unary() end",
                                     "        local v = postfix()\n        if peek() == \"^\" then take(); v = v ^ postfix() end")]),
    ("commas not checked", [("        if not okGroups then return", "        if false then return")]),
    ("no k / m / b", [("    if SUFFIX[suf] and", "    if false and SUFFIX[suf] and")]),
    ("percent ignored", [("        while peek() == \"%\" do take(); v = v / 100 end", "        while peek() == \"%\" do take() end")]),
    ("answer not reused", [("    frame.edit:SetText((answer:gsub(\",\", \"\")))", "    frame.edit:SetText(\"\")")]),
    ("history not capped", [("local HISTORY_LINES, HISTORY_KEPT = 3, 10", "local HISTORY_LINES, HISTORY_KEPT = 3, 1000")]),
    ("no grouping commas", [("    return Group(int) .. frac", "    return int .. frac")]),
]


def run(src):
    lua = LuaRuntime()
    g = lua.globals()
    g.CALC_SRC = src
    try:
        lua.execute("loadstring_real_for_test = loadstring\n" + WORLD + CHECKS)
    except Exception as e:
        return None, [], ["scenario: %s" % e], {}
    order = [lua.eval("ORDER")[i] for i in range(1, int(lua.eval("#ORDER")) + 1)]
    res = {n: bool(lua.eval("RESULTS")[n]) for n in order}
    errs = [lua.eval("SECTION_ERRORS")[i] for i in range(1, int(lua.eval("#SECTION_ERRORS")) + 1)]
    txt = {n: lua.eval("FAILTXT")[n] for n in order if not res[n]}
    return res, order, errs, txt


started = time.time()
if SRC is None:
    print("XayaUI_Bonus/Calculator.lua is missing  FAILS: 1")
    sys.exit(1)
fails = 0
res, order, errs, txt = run(SRC)
if res is None:
    print("scenario failed: %s" % errs)
    print("0 checks  FAILS: 1")
    sys.exit(1)
for n in order:
    if not res[n]:
        fails += 1
        print("FAIL  %s  (%s)" % (n, txt.get(n)))
for e in errs:
    fails += 1
    print("SECTION ERROR  %s" % e)
for name, edits in MUTATIONS:
    src = SRC
    for old, new in edits:
        if src.count(old) != 1:
            fails += 1
            print("BREAK %r: text to cut not found exactly once: %r" % (name, old[:60]))
            break
        src = src.replace(old, new)
    else:
        r2, o2, e2, _ = run(src)
        caught = r2 is None or bool(e2) or any(not r2[n] for n in o2) or len(o2) < len(order)
        if not caught:
            fails += 1
            print("BREAK %r: no check failed" % name)
print("%d checks, %d deliberate breaks, %.1f s  FAILS: %d" % (len(order), len(MUTATIONS), time.time() - started, fails))
