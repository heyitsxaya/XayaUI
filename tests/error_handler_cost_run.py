"""Core 0.6.65: XayaUI's error handler reads the stack only when it needs it (REQUEST-LOG A15 P-11). Xaya's M+ screenshot showed
another addon's error repeated on every nameplate update ("[Plater] code for Nameplate Updated error: attempt to perform string
conversion on a secret string value"). XayaUI's handler sees every error any addon raises (it wraps the previous handler). Runs the
real XayaUI/Core.lua with a counting debugstack and checks: another addon's located error -> no debugstack, the previous handler still
called with the same message, nothing recorded or shown; XayaUI's own error -> one debugstack, recorded with its stack; a message
with no file -> one debugstack (the stack decides). Negative control: core 0.6.64 reads the stack for every error (first check FAILS).
Run: python3 tests/error_handler_cost_run.py   (needs: pip install lupa)"""
import os, sys
from lupa.lua51 import LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
bench = open(os.path.join(ROOT, "tests", "engine_bench.py")).read()
a = bench.index("L.execute(r'''") + len("L.execute(r'''"); b = bench.index("''')", a)
L = LuaRuntime(unpack_returned_tuples=True)
L.execute("CueRulesDB = { rules = {}, folders = {}, ui = { advancedDebug = true } }")
L.execute(bench[a:b])
L.execute(r'''
PREV = {}
geterrorhandler = function() return function(m) PREV[#PREV + 1] = tostring(m); return "prev" end end
HANDLER = nil
seterrorhandler = function(fn) HANDLER = fn end
STACKS = 0
STACK_TEXT = "[string \"@Interface/AddOns/Plater/Plater.lua\"]:100: in function <...>"
debugstack = function() STACKS = STACKS + 1; return STACK_TEXT end
CHAT = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, s) CHAT[#CHAT + 1] = s end }
''')
load = L.eval("function(src, name, ns) local f, e = loadstring(src, '@' .. name); if not f then error(e) end; return f('XayaUI', ns) end")
ns = L.eval("{}"); L.globals().NS = ns
load(open(os.path.join(ROOT, "XayaUI", "Core.lua"), encoding="utf-8").read(), "XayaUI/Core.lua", ns)
L.execute(r'''
RECORDED = {}
NS.RecordError = function(text, stack, folder) RECORDED[#RECORDED + 1] = { text = text, stack = stack, folder = folder } end
NS.MessageDest = function() return "chat" end
function RESET() STACKS = 0; PREV = {}; RECORDED = {}; CHAT = {} end
''')
fails = []
def check(name, ok):
    print(("ok    " if ok else "FAIL  ") + name)
    if not ok: fails.append(name)
E = lambda s: L.eval(s)
check("XayaUI's handler is installed", E("type(HANDLER) == 'function'"))
PLATER = "Interface/AddOns/Plater/Plater.lua:4512: attempt to perform string conversion on a secret string value"
L.execute("RESET(); for i = 1, 100 do HANDLER(%r) end" % PLATER)
check("another addon's located error, 100 times: no debugstack", E("STACKS") == 0)
check("... the previous handler gets every one, unchanged", E("#PREV") == 100 and E("PREV[1]") == PLATER)
check("... nothing recorded, nothing shown in chat", E("#RECORDED") == 0 and E("#CHAT") == 0)
# (round 7) the count of other addons' errors (ns.otherErrors) served only XayaUI Dev Assist's walkthrough J22 (retired to qa-installer-branch,
# REQUEST-LOG A23 SD-2; V34 audit): it is gone, so XayaUI keeps nothing at all of another addon's error. (Was: "counted as other addons'
# errors (100)".)
check("... and XayaUI keeps nothing of them (no count either: round 7)", E("NS.otherErrors") == None)
MINE = "Interface/AddOns/XayaUI_Chat/Core.lua:12: attempt to index a nil value"
L.execute("RESET(); HANDLER(%r)" % MINE)
check("XayaUI's own error: one debugstack, recorded with the stack and its folder", E("STACKS") == 1 and E("#RECORDED") == 1 and E("RECORDED[1].folder") == "XayaUI_Chat" and E("RECORDED[1].stack") == E("STACK_TEXT"))
check("... shown in chat (Advanced Debugging on) and passed on", E("#CHAT") == 1 and E("#PREV") == 1)
L.execute("RESET(); STACK_TEXT = '[string \"@Interface/AddOns/XayaUI/Engine.lua\"]:40: in function <x>'; HANDLER('custom error with no file')")
check("an error with no file: one debugstack; the stack names XayaUI, so it is recorded as core's", E("STACKS") == 1 and E("#RECORDED") == 1 and E("RECORDED[1].folder") == "XayaUI")
L.execute("RESET(); STACK_TEXT = '[string \"@Interface/AddOns/Plater/Plater.lua\"]:1: in function <x>'; HANDLER('custom error with no file')")
check("an error with no file from another addon: one debugstack, not recorded", E("STACKS") == 1 and E("#RECORDED") == 0 and E("#PREV") == 1)
print("FAILS: %d" % len(fails))
sys.exit(1 if fails else 0)
