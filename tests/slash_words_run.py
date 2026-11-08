# Test for XayaUI_Bonus 0.6.17 /notes and /calc (CHAT-6, Xaya 2026-11-05: "Is it possible for /notes /calc to be commands that the
# addon recognizes and accepts in the console to open the notes and calculator respectively?"), run in Lua 5.1 with stand-in game tables.
# What it checks (outcomes: what a typed word reaches, resolved the way the chat box looks a word up in SlashCmdList):
#   - both words free, Notepad on: /notes shows / hides the Notepad, /calc alone toggles the calculator, /calc 2+2 passes the sum on;
#   - Notepad off at login: /notes reaches nothing (V14); ticking the Notepad on makes /notes work at once;
#   - a word another addon (SlashCmdList), a secure command (SecureCmdList) or the chat box's cache (hash_SlashCmdList) already has
#     is left alone: the other owner still gets it, and nothing of ours is written;
#   - running the sync again registers nothing twice; Utilities.lua writes no global beyond the two SLASH_ words;
#   - Notepad.lua's on / off calls the sync (source check).
# Deliberate breaks (MUTATIONS) each must make at least one check fail. The last line carries FAILS: <n>.
# Run from the repo root: python3 tests/slash_words_run.py   Needs: pip install lupa.
import os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SRC = open(os.path.join(ROOT, "XayaUI_Bonus", "Utilities.lua"), encoding="utf-8").read()
NOTEPAD = open(os.path.join(ROOT, "XayaUI_Bonus", "Notepad.lua"), encoding="utf-8").read()

SCENARIO = r'''
RESULTS, ORDER, FAILTXT, SECTION_ERRORS = {}, {}, {}, {}
function check(name, cond, extra)
  if RESULTS[name] ~= nil then error("duplicate check name: " .. name) end
  if cond then RESULTS[name] = true else RESULTS[name] = false; FAILTXT[name] = tostring(extra) end
  ORDER[#ORDER + 1] = name
end
function SECTION(name, f) local ok, err = pcall(f); if not ok then SECTION_ERRORS[#SECTION_ERRORS + 1] = name .. ": " .. tostring(err) end end

-- one fresh world per case: game tables, the namespace stand-ins, then Utilities.lua; returns the namespace and the ready queue
function World(opts)
  for k in pairs(_G) do if type(k) == "string" and k:match("^SLASH_") then _G[k] = nil end end
  SlashCmdList, SecureCmdList, hash_SlashCmdList = {}, {}, {}
  CALLS = {}
  local ready = {}
  XayaUI_NS = {
    notepadDB = { enabled = opts.notesOn },
    Notepad_Toggle = function() CALLS[#CALLS + 1] = "notes" end,
    Calculator_Command = function(msg) CALLS[#CALLS + 1] = "calc:" .. tostring(msg) end,
    RegisterSettingsPage = function() end,
    WhenReady = function(fn) ready[#ready + 1] = fn end,
    WhenSettingsReady = function(_, fn) ready[#ready + 1] = fn end,   -- (P5: Utilities.lua waits for XayaUI Bonus's own store)
  }
  if opts.setup then opts.setup() end
  local before = {}
  for k in pairs(_G) do before[k] = true end
  local f = assert(loadstring(UTIL_SRC, "@Utilities.lua"))
  f("XayaUI_Bonus", XayaUI_NS)
  local newGlobals = {}
  for _, fn in ipairs(ready) do fn() end
  for k in pairs(_G) do if not before[k] then newGlobals[#newGlobals + 1] = tostring(k) end end
  table.sort(newGlobals)
  return XayaUI_NS, newGlobals
end

-- what typing "/word args" reaches: the first SlashCmdList key with that word (any SLASH_<key><n>), called with the rest
function Type(line)
  local word, rest = line:match("^(%S+)%s*(.-)$")
  word = word:lower()
  for key, fn in pairs(SlashCmdList) do
    local i = 1
    while _G["SLASH_" .. key .. i] do
      if _G["SLASH_" .. key .. i]:lower() == word then fn(rest); return key end
      i = i + 1
    end
  end
  return nil
end
function Owners(word)
  local n = 0
  for key in pairs(SlashCmdList) do
    local i = 1
    while _G["SLASH_" .. key .. i] do if _G["SLASH_" .. key .. i]:lower() == word then n = n + 1 end; i = i + 1 end
  end
  return n
end

SECTION("both free, Notepad on", function()
  local ns, globals = World({ notesOn = true })
  Type("/notes"); Type("/calc"); Type("/calc 2+2")
  check("free: /notes toggles the Notepad, /calc toggles, /calc 2+2 passes the sum",
    CALLS[1] == "notes" and CALLS[2] == "calc:" and CALLS[3] == "calc:2+2", table.concat(CALLS, ","))
  check("free: the only globals written are SLASH_XUICALC1 and SLASH_XUINOTES1",
    table.concat(globals, ",") == "SLASH_XUICALC1,SLASH_XUINOTES1", table.concat(globals, ","))
  ns.Utilities_SyncSlash(); ns.Utilities_SyncSlash()
  check("free: syncing again registers nothing twice", Owners("/notes") == 1 and Owners("/calc") == 1 and SLASH_XUINOTES2 == nil)
  check("free: the words are exactly /notes and /calc (no /notepad, /calculator)", Owners("/notepad") == 0 and Owners("/calculator") == 0)
end)

SECTION("Notepad off at login", function()
  local ns = World({ notesOn = false })
  local key = Type("/notes")
  check("off: /notes reaches nothing while the Notepad is off (V14)", key == nil and #CALLS == 0, tostring(key))
  check("off: /calc still works (the Calculator has no on / off)", Type("/calc") == "XUICALC")
  ns.notepadDB.enabled = true; ns.Utilities_SyncSlash()
  CALLS = {}
  check("off: ticking the Notepad on makes /notes work at once", Type("/notes") == "XUINOTES" and CALLS[1] == "notes")
end)

SECTION("word taken by another addon", function()
  World({ notesOn = true, setup = function()
    SLASH_OTHERCALC1 = "/CALC"; SlashCmdList.OTHERCALC = function() CALLS[#CALLS + 1] = "other" end
  end })
  check("taken: another addon's /calc is left alone", Owners("/calc") == 1 and Type("/calc") == "OTHERCALC" and CALLS[1] == "other",
    tostring(Owners("/calc")))
  check("taken: nothing of ours written for it", SLASH_XUICALC1 == nil and SlashCmdList.XUICALC == nil)
  check("taken: /notes, still free, works", Type("/notes") == "XUINOTES")
end)

SECTION("word taken by a secure command", function()
  World({ notesOn = true, setup = function() SLASH_NOTESEC1 = "/notes"; SecureCmdList.NOTESEC = function() end end })
  check("secure: a secure command's /notes is left alone", SLASH_XUINOTES1 == nil and SlashCmdList.XUINOTES == nil)
end)

SECTION("word in the chat box's cache", function()
  World({ notesOn = true, setup = function() hash_SlashCmdList["/CALC"] = function() end end })
  check("cache: a word already in hash_SlashCmdList is left alone", SLASH_XUICALC1 == nil and SlashCmdList.XUICALC == nil)
end)
'''

MUTATIONS = [
    ("no free check", [("    if type(list) ~= \"table\" or WordTaken(word) then return false end", "    if type(list) ~= \"table\" then return false end")]),
    ("no Notepad-on gate", [("    if NotesOn() and ns.Notepad_Toggle then", "    if ns.Notepad_Toggle then")]),
    ("secure list not looked at", [("rawget(_G, \"SlashCmdList\"), rawget(_G, \"SecureCmdList\") }", "rawget(_G, \"SlashCmdList\") }")]),
    ("cache not looked at", [("(hash[word] or hash[word:upper()])", "false")]),
    ("sum not passed on", [("function(msg) ns.Calculator_Command(msg) end", "function() ns.Calculator_Command(\"\") end")]),
]


def run(src):
    lua = LuaRuntime()
    lua.globals().UTIL_SRC = src
    try:
        lua.execute(SCENARIO)
    except Exception as e:
        return None, [], ["scenario: %s" % e], {}
    n = int(lua.eval("#ORDER"))
    order = [lua.eval("ORDER")[i] for i in range(1, n + 1)]
    res = {k: bool(lua.eval("RESULTS")[k]) for k in order}
    errs = [lua.eval("SECTION_ERRORS")[i] for i in range(1, int(lua.eval("#SECTION_ERRORS")) + 1)]
    txt = {k: lua.eval("FAILTXT")[k] for k in order if not res[k]}
    return res, order, errs, txt


started = time.time()
fails = 0
res, order, errs, txt = run(SRC)
if res is None:
    print("scenario failed: %s" % errs); print("0 checks  FAILS: 1"); sys.exit(1)
for k in order:
    if not res[k]:
        fails += 1; print("FAIL  %s  (%s)" % (k, txt.get(k)))
for e in errs:
    fails += 1; print("SECTION ERROR  %s" % e)
# Notepad.lua's on / off must call the sync, or ticking the Notepad on would leave /notes missing until /reload
body = NOTEPAD.split("function ns.Notepad_SetEnabled(v)", 1)[-1].split("\nend", 1)[0]
order.append("Notepad on / off calls Utilities_SyncSlash")
if "ns.Utilities_SyncSlash()" not in body:
    fails += 1; print("FAIL  Notepad on / off calls Utilities_SyncSlash")
for name, edits in MUTATIONS:
    src = SRC
    for old, new in edits:
        if src.count(old) != 1:
            fails += 1; print("BREAK %r: text to cut not found exactly once: %r" % (name, old[:60])); break
        src = src.replace(old, new)
    else:
        r2, o2, e2, _ = run(src)
        if not (r2 is None or e2 or any(not r2[k] for k in o2)):
            fails += 1; print("BREAK %r: no check failed" % name)
print("%d checks, %d deliberate breaks, %.1f s  FAILS: %d" % (len(order), len(MUTATIONS), time.time() - started, fails))
sys.exit(1 if fails else 0)
