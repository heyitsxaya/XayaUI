"""XayaUI Dev Assist 0.7.0: the developer addon renamed from XayaUI_GameDump ("XayaUI Game Data Capture") to XayaUI_DevAssist
(Xaya, 2026-11-04: "Is it possible to rename the 'game dump' module into 'dev assist'?").

Checks what a player and a tester meet after the rename:
  - /xuidev opens the same command as before, and /xuidump (the old command, used by the run sheets) still does;
  - an old XayaUI_GameDump copy left in AddOns is switched off from the next /reload, with one message saying where its captures are;
    nothing happens when it is not there;
  - XayaUI finds the addon only through its service (window, name, saved file for "What to send"), never by its global;
  - the toc's file list is the folder's Lua files, its saved table is XayaUIDevAssistDB;
  - the tools read a capture saved under either name (XayaUIDevAssistDB, or XayaUIGameDumpDB from before the rename);
  - no other file still points at the old folder, except the places that must (the guard, "formerly" notes, the tools' fallback).
Run: python3 tests/devassist_rename_run.py   (needs: pip install lupa)"""
import os, re, subprocess, sys, tempfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
DA = os.path.join(ROOT, "XayaUI_DevAssist")
fails = []
def check(name, ok, extra=""):
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  [" + str(extra) + "]"))
    if not ok: fails.append(name)

def stand_in(old_loaded, can_disable=True):
    L = LuaRuntime()
    L.execute(r'''
SAID = {}
print = function(...) local t = {} for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end; SAID[#SAID + 1] = table.concat(t, " ") end
EV = {}
local function mk()
  local f = { events = {} }
  local m = { Hide = function() end, Show = function() end, SetPoint = function() end, SetSize = function() end,
    RegisterEvent = function(self, e) self.events[e] = true; EV[#EV + 1] = { f = self, e = e } end,
    UnregisterEvent = function(self, e) self.events[e] = nil end,
    SetScript = function(self, k, fn) self["_" .. k] = fn end }
  return setmetatable(f, { __index = m })
end
CreateFrame = function() return mk() end
function FIRE(e, ...) for _, x in ipairs(EV) do if x.e == e and x.f.events[e] and x.f._OnEvent then x.f._OnEvent(x.f, e, ...) end end end
date = function() return "2026-11-04 15:00" end
GetTime = function() return 100 end
issecretvalue = function() return false end
InCombatLockdown = function() return false end
C_Timer = { After = function() end }
UISpecialFrames = {}
tinsert = table.insert
SlashCmdList = {}
DISABLED = {}
''')
    L.execute("OLD_LOADED = %s; CAN_DISABLE = %s" % ("true" if old_loaded else "false", "true" if can_disable else "false"))
    L.execute(r'''
C_AddOns = { IsAddOnLoaded = function(n) if n == "XayaUI_GameDump" and OLD_LOADED then return true, true end return false, false end }
if CAN_DISABLE then C_AddOns.DisableAddOn = function(n, ch) DISABLED[#DISABLED + 1] = n end end
''')
    path = os.path.join(DA, "DevAssist.lua").replace("\\", "/")
    L.execute("assert(loadfile('%s'))('XayaUI_DevAssist')" % path)
    return L

# 1. commands
L = stand_in(False)
check("/xuidev is the command", L.eval("SLASH_XAYAUIDEV1") == "/xuidev")
check("/xuidump still works: it is the same command (the run sheets use it)", L.eval("SLASH_XAYAUIDEV2") == "/xuidump" and L.eval("type(SlashCmdList.XAYAUIDEV)") == "function")
check("no command is left on the old key", L.eval("SlashCmdList.XAYAUIDUMP") is None)
L.execute("SAID = {}; SlashCmdList.XAYAUIDEV('help')")
check("its help says /xuidev and the new name", "XayaUI Dev Assist" in (L.eval("SAID[1]") or "") and "/xuidev" in (L.eval("SAID[1]") or ""), L.eval("SAID[1]"))
check("the window's global is the new name, the old one is gone", L.eval("type(XayaUIDevAssist)") == "table" and L.eval("XayaUIGameDump") is None)

# 2. an old copy left in AddOns
L.execute("SAID = {}; FIRE('PLAYER_LOGIN')")
check("no old copy: nothing switched off, nothing said", L.eval("#DISABLED") == 0 and L.eval("#SAID") == 0)
L = stand_in(True)
L.execute("SAID = {}; FIRE('PLAYER_LOGIN'); FIRE('PLAYER_LOGIN')")
check("old copy loaded: it is switched off (from the next /reload)", L.eval("#DISABLED") == 1 and L.eval("DISABLED[1]") == "XayaUI_GameDump")
msg = L.eval("SAID[1]") or ""
check("  ...one message, once: it says what happened, to delete the folder, and where the old captures are",
      L.eval("#SAID") == 1 and "switched off from your next /reload" in msg and "Delete the XayaUI_GameDump folder" in msg and "XayaUI_GameDump.lua" in msg, msg)
L = stand_in(True, can_disable=False)
L.execute("SAID = {}; FIRE('PLAYER_LOGIN')")
check("  ...a client without DisableAddOn: the message asks to switch it off in the AddOns list instead",
      "Switch it off in the AddOns list" in (L.eval("SAID[1]") or ""), L.eval("SAID[1]"))

# 3. the service XayaUI uses (Probe.lua), Settings uses it, core never names the addon
probe = open(os.path.join(DA, "Probe.lua"), encoding="utf-8").read()
check("the service says the new saved file, the name, and opens the window",
      'savedFile = "XayaUI_DevAssist.lua"' in probe and 'name = "XayaUI Dev Assist"' in probe and "Open = function() if GD and GD.Toggle then GD.Toggle() end end" in probe)
opts = open(os.path.join(ROOT, "XayaUI_Options", "Options.lua"), encoding="utf-8").read()
check("Settings opens it through the service, not through the old global", "_G.XayaUIGameDump" not in opts and "svc.Open()" in opts and 'name = "Open Dev Assist"' in opts)
import re
core = "".join(open(os.path.join(ROOT, "XayaUI", f), encoding="utf-8").read() for f in os.listdir(os.path.join(ROOT, "XayaUI")) if f.endswith(".lua"))
# (core 0.6.56: comments may say where a moved command went, XayaUI_DevAssist/CoreDebug.lua, and the error-code table maps an error
# raised in that folder to XUI-E007; neither calls the addon. Comments and that one data line are left out of this check.)
code = re.sub(r"--[^\n]*", "", core).replace('folder = "XayaUI_DevAssist"', "")
check("core names neither the old nor the new folder in its code (it uses the service)", "XayaUI_GameDump" not in core and "XayaUI_DevAssist" not in code and "XayaUIDevAssist" not in code)

# 4. the toc
toc = open(os.path.join(DA, "XayaUI_DevAssist.toc"), encoding="utf-8").read()
listed = [l.strip() for l in toc.splitlines() if l.strip() and not l.startswith("#")]
on_disk = sorted(f for f in os.listdir(DA) if f.endswith(".lua"))
# (Dev Assist 0.7.5: QAWalks-*.lua are walkthroughs for the shared QA framework, QAWalk.lua, on another branch; until that file is here
# they stay out of the toc on purpose, so the game never reads them)
if "QAWalk.lua" not in on_disk:
    on_disk = [f for f in on_disk if not f.startswith("QAWalks-")]
_ver = re.search(r"^## Version: (\d+)\.(\d+)\.(\d+)\s*$", toc, re.M)   # 0.7.0 or later (0.7.1: instance, stats, tooltips)
check("toc: title, version 0.7.0 or later, saved table XayaUIDevAssistDB", "## Title: XayaUI Dev Assist" in toc and _ver is not None
      and tuple(int(x) for x in _ver.groups()) >= (0, 7, 0) and "## SavedVariables: XayaUIDevAssistDB" in toc)
check("toc: lists exactly the folder's Lua files, DevAssist.lua first", sorted(listed) == on_disk and listed[0] == "DevAssist.lua", (listed, on_disk))
check("the old folder is gone from the repository", not os.path.exists(os.path.join(ROOT, "XayaUI_GameDump")))

# 5. the tools read a capture saved under either name
with tempfile.TemporaryDirectory() as d:
    for var in ("XayaUIDevAssistDB", "XayaUIGameDumpDB"):
        f = os.path.join(d, var + ".lua")
        open(f, "w", encoding="utf-8").write(var + " = { formula = { loadouts = {} } }\n")
        r = subprocess.run([sys.executable, "-c", "import sys; sys.path.insert(0, %r); sys.path.insert(0, %r); import formula_fit as F; "
                            "print(type(F.load_saved(%r)).__name__)" % (os.path.join(ROOT, "tests"), os.path.join(ROOT, "tools"), f)],
                           capture_output=True, text=True)
        check("tools/formula_fit.py reads a capture saved as " + var, r.returncode == 0 and r.stdout.strip() != "", (r.stdout + r.stderr)[-300:])
br = open(os.path.join(ROOT, "docs", "reference", "build_reference.py"), encoding="utf-8").read()
check("docs/reference/build_reference.py reads either name", "env.XayaUIDevAssistDB or env.XayaUIGameDumpDB" in br)

# 6. nothing else still points at the old folder (history in debug-log/ and the RETROSPECTIVE stays as written)
allowed = {"XayaUI_DevAssist/DevAssist.lua", "XayaUI_DevAssist/ApiInventory.lua", "XayaUI_DevAssist/AuraCatalogue.lua", "XayaUI_DevAssist/Probe.lua",
           "XayaUI_DevAssist/FormulaCapture.lua", "XayaUI_DevAssist/XayaUI_DevAssist.toc", "XayaUI_Bonus/Tooltips.lua", "tools/formula_fit.py",
           "docs/reference/build_reference.py", "tests/devassist_rename_run.py"}
out = subprocess.run(["git", "grep", "-l", "XayaUI_GameDump", "--", ".", ":!debug-log", ":!docs/process/RETROSPECTIVE.md", ":!MANIFEST.md5"],
                     cwd=ROOT, capture_output=True, text=True).stdout.split()
stray = [p for p in out if p not in allowed and not p.endswith(".md") and p != ".gitignore"]
check("no code file outside the expected places names XayaUI_GameDump", not stray, stray)
for p in [p for p in out if p in allowed and p.endswith(".lua")]:
    txt = open(os.path.join(ROOT, p), encoding="utf-8").read()
    bad = [l for l in txt.splitlines() if "XayaUI_GameDump" in l and not ("formerly" in l or "OLD" in l or "XayaUI_GameDump.lua" in l
           or "XayaUI_GameDump folder" in l or "XayaUI_GameDump (" in l or "before 0.7.0" in l or "XayaUI_GameDump\")" in l
           or "(folder XayaUI_GameDump," in l)]
    check("%s names the old folder only as history or for the guard" % p, not bad, bad[:2])

print("FAILS: %d" % len(fails))
sys.exit(1 if fails else 0)
