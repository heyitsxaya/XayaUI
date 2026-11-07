#!/usr/bin/env python3
"""Every offline check, in one go (all in Lua 5.1, like the game):
  1. the unit tests (tests/*_run.py)
  2. the whole-addon harness (tests/harness/run.py): every combination of feature addons, fresh install
  3. optionally, the harness on a real SavedVariables file:  --saved PATH   (never commit that file)
Exit code 0 only when everything passes. Usage: python3 tests/run_all.py [--saved PATH] [--quick]  (--quick = everything-on only)"""
import glob, os, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
args = sys.argv[1:]
saved = args[args.index("--saved") + 1] if "--saved" in args else None
quick = "--quick" in args
bad = 0
for t in sorted(glob.glob(os.path.join(HERE, "*_run.py"))):
    r = subprocess.run([sys.executable, t], capture_output=True, text=True, cwd=os.path.dirname(HERE))
    last = (r.stdout.strip().splitlines() or [""])[-1]
    ok = r.returncode == 0 and any(s in last for s in ("0 failed", "PASS", "passed", "FAILS: 0"))
    bad += 0 if ok else 1
    print(("ok   " if ok else "FAIL ") + os.path.basename(t) + "  " + last[:90])
harness = [sys.executable, os.path.join(HERE, "harness", "run.py"), "--fresh-only"]
if quick:
    harness += ["--only", "XayaUI_Rules", "XayaUI_Chat", "XayaUI_QoL", "XayaUI_Bonus", "XayaUI_Reskin", "XayaUI_Options"]
r = subprocess.run(harness)
bad += 0 if r.returncode == 0 else 1
if saved:
    r = subprocess.run([sys.executable, os.path.join(HERE, "harness", "run.py"), "--saved", saved, "--only",
                        "XayaUI_Rules", "XayaUI_Chat", "XayaUI_QoL", "XayaUI_Bonus", "XayaUI_Reskin", "XayaUI_Options"])
    bad += 0 if r.returncode == 0 else 1
print("ALL CHECKS PASS" if bad == 0 else "%d CHECK GROUP(S) FAILED" % bad)
sys.exit(1 if bad else 0)
