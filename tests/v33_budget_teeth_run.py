#!/usr/bin/env python3
"""V33 / V27 (round 7): the performance gate's new checks have teeth. Each check must FAIL on an older build that has the problem it is
there for; tests/gate_performance_run.py itself shows the current build against them.

V33 (Xaya, REQUEST-LOG A23 SD-50 / SD-51, her words): "Be sure to set a running standard for all addons that their performance
benchmarks should be at under 2% cpu at most (in combat, multiple rules running at once), and generally should aim to be reasonably
under .9%"; how judged: "Proxy gate + your check (Recommended)". The gate's budget is calibrated on her reading SD-38 (XayaUI Rules at 4%
Average CPU on origin/main ad60a051). V27 her answer "No running loops" (nothing polls on a timer); SD-60 her answer "1" (talents are
read only on events, no talent timer); SD-61 her answer "10/s for all, like EUI" (re-check passes at most 10 a second).

What the player gets from these checks: a build that costs her more than her 2% in a fight, that keeps a timer reading talents while she
stands idle, or that re-checks rules every frame at the start of a fight with nothing on screen changing, does not land on main.

The builds, each played in the gate's own scenario (tests/gate_common.py) from a copy of its addon folders (git archive) next to this
checkout's gate files and harness:
  ad60a051  origin/main before bundle 1, the build she measured at 4%: the budget must fail it (2% = 50% of its work);
  89ea79ab  the end of round 5 (its frame script re-checked rules every frame of a fight): the budget must fail it;
  2381c09d  the end of round 6: it keeps review R3's once-a-second talent re-read out of combat (a C_Timer.NewTicker) and round 6's
            PUMP_AFTER first second (one-shot re-check passes every frame for the first second of a fight). The gate scenario now has
            rules with a talent requirement, so the ticker must fail P2; and her pace check must fail the first second's passes.
            (The round-6 gate, without the talent rules and the pace check, passed this build: 'gate_performance: 0 violation(s)'.)
Limits (V25): a stand-in game; the budget's numbers are INFERENCE (linear scaling, the billing, the scenario's likeness to her play).
Run: python3 tests/v33_budget_teeth_run.py  (needs git and the three commits; about ten minutes the first time, seconds when cached)."""
import concurrent.futures, os, re, subprocess, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gate_common as GC  # noqa: E402

CHECKS, FAILED = [0], [0]


def check(ok, what, detail=""):
    CHECKS[0] += 1
    if not ok:
        FAILED[0] += 1
    print(("ok    " if ok else "FAIL: ") + what + (("  [" + detail + "]") if detail else ""))


def fails_of(out):
    """The FAIL entries of a gate's output: [(where, what, numbers)]."""
    res, lines = [], out.splitlines()
    for i, ln in enumerate(lines):
        m = re.match(r"FAIL \d+ \[gate_performance\] (.*)$", ln)
        if m:
            what = lines[i + 1].strip()[len("what:"):].strip() if i + 1 < len(lines) and lines[i + 1].strip().startswith("what:") else ""
            num = lines[i + 2].strip()[len("numbers:"):].strip() if i + 2 < len(lines) and lines[i + 2].strip().startswith("numbers:") else ""
            res.append((m.group(1), what, num))
    return res


def gate_in(tree):
    r = subprocess.run([sys.executable, os.path.join(tree, "tests", "gate_performance_run.py")], capture_output=True, text=True, cwd=tree,
                       env=GC.tree_env(tree), timeout=3600)
    return r.returncode, r.stdout + r.stderr


def main():
    builds = {"main": "ad60a051", "r5": "89ea79ab", "r6": "2381c09d"}
    trees = {}
    for k, c in builds.items():
        try:
            trees[k] = GC.tree_copy(c)
        except RuntimeError as e:
            check(False, "the build %s can be unpacked from git" % c, str(e))
    if len(trees) < len(builds):
        print("%d checks, %d failed" % (CHECKS[0], FAILED[0]))
        return 1
    # the three scenarios first, side by side (each gate below then reads its cached result; the baseline is the main build's)
    with concurrent.futures.ThreadPoolExecutor(3) as ex:
        futs = {k: ex.submit(GC.tree_result, t) for k, t in trees.items()}
        for k, f in futs.items():
            try:
                f.result()
            except Exception as e:  # noqa: BLE001  (reported as a failed check)
                check(False, "the scenario plays on %s" % builds[k], str(e)[-300:])
    outs = {}
    with concurrent.futures.ThreadPoolExecutor(3) as ex:
        futs = {k: ex.submit(gate_in, t) for k, t in trees.items()}
        for k, f in futs.items():
            outs[k] = f.result()
    for k in ("main", "r5", "r6"):
        rc, out = outs[k]
        integ = [f for f in fails_of(out) if "did not run as planned" in f[1] or "V33 calibration" in f[0] or "no calibration" in f[1]]
        check(not integ, "%s: the scenario ran as planned and the budget is calibrated" % builds[k], "; ".join(w for _, w, _ in integ)[:300])
        rules = [ln.strip() for ln in out.splitlines() if ln.strip().startswith("V33 XayaUI Rules:")]
        print("      %s: %s" % (builds[k], rules[0][:260] if rules else "(no V33 XayaUI Rules line)"))
    # 1-2: the budget fails the build she measured at 4%, and the round-5 build
    for k in ("main", "r5"):
        rc, out = outs[k]
        f = [x for x in fails_of(out) if x[0] == "XayaUI_Rules" and x[1].startswith("V33 work budget")]
        check(bool(f) and rc != 0, "V33: the budget FAILS %s (%s): XayaUI Rules works more per fight frame than her 2%% maximum" % (
            builds[k], "her 4% reading" if k == "main" else "round 5"), f[0][2][:200] if f else "no V33 FAIL for XayaUI Rules")
    rc, out = outs["main"]
    m = re.search(r"V33 XayaUI Rules: \d+ instructions per fight frame = ([\d.]+)%", out)
    check(bool(m) and abs(float(m.group(1)) - 4.0) < 0.05, "V33: the calibration build reads 4% (her SD-38 reading), as calibrated",
          m.group(0) if m else "no reading")
    # 3: the talent ticker of round 6 (review R3's safety net) fails P2 now that the scenario has rules with a talent requirement
    rc, out = outs["r6"]
    f = [x for x in fails_of(out) if x[0].startswith("XayaUI_Rules/Engine.lua") and "P2 a repeating timer (C_Timer.NewTicker) every 1 s" in x[1]]
    check(bool(f) and "STILL ARMED" in f[0][2], "P2: round 6's once-a-second talent re-read (a NewTicker while a talent rule is on) FAILS, "
          "still armed after 30 s idle", (f[0][0] + " " + f[0][2][:160]) if f else "no P2 FAIL for a 1 s NewTicker in Engine.lua")
    # 4: round 6's first second of a fight (PUMP_AFTER: one-shot passes every frame) fails her pace
    f = [x for x in fails_of(out) if x[0].startswith("XayaUI_Rules/Engine.lua") and "more than 10 times within one second" in x[1]]
    check(bool(f), "P2 pace: round 6's first second of a fight (one-shot re-check passes every frame, nothing changing) FAILS",
          (f[0][0] + " " + f[0][2][:200]) if f else "no pace FAIL in Engine.lua")
    print("%d checks, %d failed" % (CHECKS[0], FAILED[0]))
    return 1 if FAILED[0] else 0


if __name__ == "__main__":
    sys.exit(main())
