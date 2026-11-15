#!/usr/bin/env python3
"""Every offline check, in one go (all in Lua 5.1, like the game):
  1. the unit tests (tests/*_run.py)
  2. the whole-addon harness (tests/harness/run.py): every combination of feature addons, fresh install
  3. optionally, the harness on a real SavedVariables file:  --saved PATH   (never commit that file)
Exit code 0 only when everything passes. Usage: python3 tests/run_all.py [--saved PATH] [--quick]  (--quick = everything-on only)

A test passes only when it exits 0 AND its last line passes line_passes(): every failure count the line prints ("N failed",
"FAILS: N") must be 0; a line with no count must say PASS / passed. (Fix plan f1-9: the old substring test read "10 failed" as
a pass because it contains "0 failed"; tests/run_all_markers_run.py checks this.)"""
import glob, os, re, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))

FAILED_COUNT = re.compile(r"\b(\d+)\s+failed\b", re.I)    # "18 checks, 0 failed"
FAILS_COUNT = re.compile(r"\bFAILS:\s*(\d+)\b")             # "FAILS: 0", "FAILS:  0"
NO_COUNT_PASS = re.compile(r"\bPASS(?:ED)?\b|\bpassed\b")  # "ALL CHECKS PASS", "all 12 passed" (no failure count printed)
FAIL_WORD = re.compile(r"\bFAIL(?:S|ED|URES?)?\b", re.I)
# the feature addons present in this checkout (main holds XayaUI, XayaUI_Options and XayaUI_Rules: REQUEST-LOG A23; and XayaUI_Bonus
# with only the Stat Calculator since Bonus 0.6.45: REQUEST-LOG A24 #10)
ROOT = os.path.dirname(HERE)
# (Bonus 0.6.46, A24 #12 / #13) and XayaUI_Bonus_StatCalculator, the Stat Calculator's load-on-demand addon (the harness also runs every
# combination with the Stat Calculator switched on, its built-in data set "Stat Calculator on", beside the fresh install where it is off)
FEATURES = [a for a in ("XayaUI_Rules", "XayaUI_Bonus", "XayaUI_Bonus_StatCalculator", "XayaUI_Options")
            if os.path.isdir(os.path.join(ROOT, a))]


def line_passes(last):
    """True when a test's last output line reports no failure (see the module docstring)."""
    counts = [int(c) for c in FAILED_COUNT.findall(last)] + [int(c) for c in FAILS_COUNT.findall(last)]
    if counts:
        return all(c == 0 for c in counts)
    return bool(NO_COUNT_PASS.search(last)) and not FAIL_WORD.search(last)


def main(args):
    saved = args[args.index("--saved") + 1] if "--saved" in args else None
    quick = "--quick" in args
    bad = 0
    for t in sorted(glob.glob(os.path.join(HERE, "*_run.py"))):
        r = subprocess.run([sys.executable, t], capture_output=True, text=True, cwd=os.path.dirname(HERE))
        last = (r.stdout.strip().splitlines() or [""])[-1]
        ok = r.returncode == 0 and line_passes(last)
        bad += 0 if ok else 1
        print(("ok   " if ok else "FAIL ") + os.path.basename(t) + "  " + last[:90])
    harness = [sys.executable, os.path.join(HERE, "harness", "run.py"), "--fresh-only"]
    if quick:
        harness += ["--only"] + FEATURES
    r = subprocess.run(harness)
    bad += 0 if r.returncode == 0 else 1
    if saved:
        r = subprocess.run([sys.executable, os.path.join(HERE, "harness", "run.py"), "--saved", saved, "--only"] + FEATURES)
        bad += 0 if r.returncode == 0 else 1
    print("ALL CHECKS PASS" if bad == 0 else "%d CHECK GROUP(S) FAILED" % bad)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
