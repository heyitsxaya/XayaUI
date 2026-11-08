#!/usr/bin/env python3
"""tests/run_all_markers_run.py: tests/run_all.py reads a test's last line correctly (fix plan f1-9).
The old reader was a substring test (`any(s in last for s in ("0 failed", "PASS", "passed", "FAILS: 0"))`), so "18 checks, 10 failed"
counted as a pass (it contains "0 failed"), as did "FAILS: 03" (it contains "FAILS: 0"), and the three runners chatprobe / drafts /
minimap exited 0 whatever happened. Negative control: OLD below accepts the failing lines.
Run: python3 tests/run_all_markers_run.py"""
import importlib.util, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("run_all", os.path.join(HERE, "run_all.py"))
R = importlib.util.module_from_spec(spec)
spec.loader.exec_module(R)   # main() runs only as a script, so importing runs no test


def OLD(last):   # the reader before the fix, kept here as the negative control
    return any(s in last for s in ("0 failed", "PASS", "passed", "FAILS: 0"))


checks = fails = 0


def check(name, ok, detail=""):
    global checks, fails
    checks += 1
    if not ok:
        fails += 1
        print("FAIL", name, detail)
    else:
        print("ok  ", name)


FAILING = ["18 checks, 10 failed", "120 checks, 20 failed", "FAILS: 10", "FAILS: 3", "precheck: 8 check groups  FAILS: 30",
           "12 checks, 1 failed", "FAILS:  2", "7 passed, 3 failed", "BREAK 'x': no check failed  FAILS: 1",
           "3 tests FAILED", "", "Traceback (most recent call last):", "PASS 4, FAIL 1"]
PASSING = ["18 checks, 0 failed", "FAILS: 0", "FAILS:  0", "36 checks  FAILS: 0", "ALL CHECKS PASS", "all 12 passed",
           "8 checks, 2 deliberate breaks  FAILS: 0", "102 checks, 0 failed", "PASS", "FAILS: 0 (3 warnings)"]
for line in FAILING:
    check("a failing last line is not a pass: %r" % line, not R.line_passes(line))
for line in PASSING:
    check("a passing last line passes: %r" % line, R.line_passes(line))
check("negative control: the old substring reader took '18 checks, 10 failed' as a pass", OLD("18 checks, 10 failed"))
check("negative control: the old reader took 'FAILS: 03' as a pass", OLD("FAILS: 03"))
check("... the new one does not", not R.line_passes("FAILS: 03"))

# the three runners that used to exit 0 on a failure now exit non-zero: each must end in a sys.exit on its fail count
for n in ("chatprobe_run.py", "drafts_run.py", "minimap_run.py"):
    src = open(os.path.join(HERE, n), encoding="utf-8").read()
    check("%s returns its fail count from Lua and exits on it" % n, "return fails\n'''" in src and "exit(1 if fails else 0)" in src)

# end to end: a runner whose last line is "18 checks, 10 failed" (exit 0) is counted as a failure by the same rule run_all uses
probe = "import sys; print('18 checks, 10 failed'); sys.exit(0)"
r = subprocess.run([sys.executable, "-c", probe], capture_output=True, text=True)
last = (r.stdout.strip().splitlines() or [""])[-1]
check("run_all's rule on a runner printing '18 checks, 10 failed' with exit 0: not ok",
      not (r.returncode == 0 and R.line_passes(last)), last)

print("%d checks, %d failed" % (checks, fails))
sys.exit(1 if fails else 0)
