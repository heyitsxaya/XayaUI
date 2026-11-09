"""XayaUI Dev Assist 0.7.0: the developer addon renamed from XayaUI_GameDump ("XayaUI Game Data Capture") to XayaUI_DevAssist
(Xaya, 2026-11-04: "Is it possible to rename the 'game dump' module into 'dev assist'?").

XayaUI Dev Assist itself is not on this branch (it lives on another branch). What is checked here is the kept code's side of the rename:
  - XayaUI finds the addon only through its service ("gameDataProbe"), never by its global: Settings opens it through the service,
    and core names neither the old nor the new folder in its code;
  - the old XayaUI_GameDump folder is gone;
  - docs/reference/build_reference.py reads a capture saved under either name (XayaUIDevAssistDB, or XayaUIGameDumpDB from before the rename);
  - no other file still points at the old folder, except the places that must (the reference builder's fallback, this test).
Run: python3 tests/devassist_rename_run.py"""
import os, re, subprocess, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
fails = []
def check(name, ok, extra=""):
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  [" + str(extra) + "]"))
    if not ok: fails.append(name)

# 1. XayaUI finds Dev Assist (on another branch) only through its service: Settings uses it, core never names the addon
opts = open(os.path.join(ROOT, "XayaUI_Options", "Options.lua"), encoding="utf-8").read()
check("Settings opens it through the service, not through the old global", "_G.XayaUIGameDump" not in opts and "svc.Open()" in opts and 'name = "Open Dev Assist"' in opts)
core = "".join(open(os.path.join(ROOT, "XayaUI", f), encoding="utf-8").read() for f in os.listdir(os.path.join(ROOT, "XayaUI")) if f.endswith(".lua"))
# (core 0.6.56: comments may say where a moved command went, XayaUI_DevAssist/CoreDebug.lua, and the error-code table maps an error
# raised in that folder to XUI-E007; neither calls the addon. Comments and that one data line are left out of this check.)
code = re.sub(r"--[^\n]*", "", core).replace('folder = "XayaUI_DevAssist"', "")
check("core names neither the old nor the new folder in its code (it uses the service)", "XayaUI_GameDump" not in core and "XayaUI_DevAssist" not in code and "XayaUIDevAssist" not in code)

# 2. the old folder is gone
check("the old folder is gone from the repository", not os.path.exists(os.path.join(ROOT, "XayaUI_GameDump")))

# 3. the reference builder reads a capture saved under either name
br = open(os.path.join(ROOT, "docs", "reference", "build_reference.py"), encoding="utf-8").read()
check("docs/reference/build_reference.py reads either name", "env.XayaUIDevAssistDB or env.XayaUIGameDumpDB" in br)

# 4. nothing else still points at the old folder (history in the RETROSPECTIVE stays as written)
allowed = {"docs/reference/build_reference.py", "tests/devassist_rename_run.py"}
out = subprocess.run(["git", "grep", "-l", "XayaUI_GameDump", "--", ".", ":!docs/process/RETROSPECTIVE.md", ":!MANIFEST.md5"],
                     cwd=ROOT, capture_output=True, text=True).stdout.split()
stray = [p for p in out if p not in allowed and not p.endswith(".md") and p != ".gitignore"]
check("no code file outside the expected places names XayaUI_GameDump", not stray, stray)

print("FAILS: %d" % len(fails))
sys.exit(1 if fails else 0)
