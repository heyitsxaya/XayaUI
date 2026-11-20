"""XayaUI Dev Assist 0.7.0: the developer addon renamed from XayaUI_GameDump ("XayaUI Game Data Capture") to XayaUI_DevAssist
(Xaya, 2026-11-04: "Is it possible to rename the 'game dump' module into 'dev assist'?").

XayaUI Dev Assist itself is not on this branch (it lives on another branch). What is checked here is the kept code's side of the rename:
  - XayaUI never finds the addon by its global; (round 8) Settings no longer opens it (its "gameDataProbe" groups are removed), and
    core names neither the old nor the new folder in its code;
  - the old XayaUI_GameDump folder is gone;
  - docs/reference/build_reference.py reads a capture saved under either name (XayaUIDevAssistDB, or XayaUIGameDumpDB from before the rename);
  - no other file still points at the old folder, except the places that must (the reference builder's fallback, this test).
Run: python3 tests/devassist_rename_run.py"""
import os, re, subprocess, sys
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
fails = []
checked = []   # (round 11 repair, SD-138 / V35: a test fails if it prints no result count) every check() made, for the last line "N checks, M failed" tests/run_all.py reads
def check(name, ok, extra=""):
    checked.append(name)
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  [" + str(extra) + "]"))
    if not ok: fails.append(name)

# 1. XayaUI finds Dev Assist (on another branch) only through its service: Settings uses it, core never names the addon
opts = open(os.path.join(ROOT, "XayaUI_Options", "Options.lua"), encoding="utf-8").read()
# (bundle 1 round 8, V34 audit; intended change) Settings > Debugging's "Dev Assist (separate tool)" group, which opened it through the
# service, is removed with the other code that served only the retired addon: Settings names it neither way now
check("Settings no longer opens Dev Assist at all, and never through the old global", "_G.XayaUIGameDump" not in opts
      and 'name = "Open Dev Assist"' not in opts and 'ns.Service("gameDataProbe")' not in opts)
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

# 4. nothing else still points at the old folder
allowed = {"docs/reference/build_reference.py", "tests/devassist_rename_run.py"}
# (bundle 1 round 9, REQUEST-LOG A23 SD-72, her answer "Remove from main, keep on QA (Recommended)": MANIFEST.md5 is gone from main,
# so its exclusion here was dropped; qa-installer-branch keeps the file and its own copy of this test)
# (round 11a, SD-140: the RETROSPECTIVE, a working doc, left this repo, so its pathspec exclusion went with it; .md files are
# skipped below in any case)
out = subprocess.run(["git", "grep", "-l", "XayaUI_GameDump", "--", "."],
                     cwd=ROOT, capture_output=True, text=True).stdout.split()
stray = [p for p in out if p not in allowed and not p.endswith(".md") and p != ".gitignore"]
check("no code file outside the expected places names XayaUI_GameDump", not stray, stray)

print("%d checks, %d failed" % (len(checked), len(fails)))
sys.exit(1 if fails else 0)
