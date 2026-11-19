#!/usr/bin/env python3
"""Every offline check, in one go (all in Lua 5.1, like the game):
  1. the unit tests (tests/*_run.py)
  2. the whole-addon harness (tests/harness/run.py): every combination of feature addons, fresh install
  3. optionally, the harness on a real SavedVariables file:  --saved PATH   (never commit that file)
Exit code 0 only when everything passes.
Usage: python3 tests/run_all.py [--saved PATH] [--quick] [--json PATH] [--time-limit S] [--only NAME ...]
  --quick       the harness runs everything-on only
  --json PATH   also write every verdict, with its reasons, as JSON (for tools; the printed report is unchanged in shape)
  --time-limit  the default time limit of one test in seconds (default 600; TIME_LIMITS below raises it for the long tests)
  --only        run only these tests (file names, with or without _run.py) and skip the harness

THE LAST LINE. A test passes only when it exits 0 AND its last line passes line_passes(): every failure count the line prints
("N failed", "FAILS: N") must be 0; a line with no count must say PASS / passed. (Fix plan f1-9: the old substring test read "10 failed"
as a pass because it contains "0 failed"; tests/run_all_markers_run.py checks this.)

THE HONEST-RESULT GUARD (round 11; SD-129 "Yes, in round 11 (Recommended)"; SD-138 "Amended version (Recommended)", mechanism M1 of
the test-efficacy review, VERIFICATION.md V35, her approved wording: "Every test run: a test fails if it checked nothing, if something it
needs is missing (it must say what), if it prints no result count, or if an engine error happened that it did not expect. A test that
runs too long is marked HUNG, not passed."). On top of the last-line rule, a test FAILS (never ok) when:
  NO COUNT LINE    its last line does not say how many things it checked (COUNT_PATTERNS: "N checks", "N passed, M failed",
                   "all N passed", "N <things> checked"). "FAILS: 0" or "ALL PASSED" alone count failures, not checks, so a run that
                   checked nothing cannot be told from one that checked a hundred.
  CHECKED NOTHING  that count is 0.
  MISSING INPUT    something it needs is not there. The test says so on a line holding "MISSING INPUT: <what>", or the guard sees it:
                   the test ran git in a folder that is not a git checkout (or git is not installed), so a "git ls-files" came back
                   empty and the test could pass on nothing (test audit: american_spelling, key_propagation, devassist_rename).
                   The suite itself also needs the API index (XUI_API_INDEX, else tests/harness/api_index.json) and a git checkout:
                   without either it prints MISSING INPUT and fails as a whole.
  ERROR RECORD     the addons' error record had entries the test did not declare. Every stand-in run (every Lua 5.1 runtime the
                   test makes) is read at its end: CueRulesDB.errorLog (XayaUI/DebugRecord.lua, SD-139: every error and warning
                   XayaUI reports is saved there, Advanced Debugging on or off; an engine step error caught by SafeStep is XUI-E011).
                   A test that causes an error on purpose declares it on a line of its output: "EXPECT_ERRORS <code> <n>", for
                   example "EXPECT_ERRORS XUI-E011 2"; n is exact (a declared error that did not happen fails too, as
                   EXPECTED ERROR NOT SEEN). Counting: one entry per code and message with a repeat count n (DebugRecord.lua); an
                   entry a later runtime of the same test loaded from saved data (same code, message and first time) counts once,
                   at its highest n; entries of separate runtimes add up.
  GUARD BLIND      the test process ended without the guard's report (it left through os._exit, or crashed the interpreter), so
                   nothing above could be read: a run the guard could not see is not a pass.
  HUNG             it ran past its time limit (its own state, printed "HUNG", never ok); it and every process it started are stopped.
How the guard reads a test from the outside, without any change to the test: run_all starts each test as
"python3 tests/run_all.py --m1-child REPORT.json TEST.py": that child replaces lupa.lua51.LuaRuntime with a subclass that registers each
runtime (and reads its record when the runtime is freed, and of every runtime still alive at the exit), and watches subprocess.Popen for
git; then it runs the test as __main__ (runpy) and writes REPORT.json at its exit. Limits (stated, not hidden): Lua runtimes inside
processes the test starts itself (worker processes, a python3 subprocess) are not read here; the harness reads its own sessions'
records (tests/harness/run.py run_combo). An entry a test seeds itself (saved data that already holds errorLog entries) is read like any
other: such a test declares it.
Report format (unchanged in shape, read by people and tools): one line per test, "ok   <test>  <last line>", "FAIL <test>  <last line>"
or "HUNG <test>  <last line>", each FAIL or HUNG followed by its reasons on lines starting "     M1 "; then the harness; the final line is
"ALL CHECKS PASS" or "N CHECK GROUP(S) FAILED" (with the HUNG count in brackets when there is one)."""
import glob, json, os, re, signal, subprocess, sys, tempfile, time
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

# ---------------------------------------------------------------------------------------------------------------------------------
# the honest-result guard (SD-138 M1): what a result line must say, and the limits
# ---------------------------------------------------------------------------------------------------------------------------------
# How many things a test checked, read from its last line (the first pattern that matches wins). Each is a count of checks made, never
# a count of failures alone: "FAILS: N" and "N violation(s)" do not qualify.
COUNT_PATTERNS = (
    (re.compile(r"\b(\d+)\s+passed,\s*(\d+)\s+failed\b", re.I), lambda m: int(m.group(1)) + int(m.group(2))),   # "4 passed, 0 failed"
    (re.compile(r"\b(\d+)\s+checks?\b", re.I), lambda m: int(m.group(1))),                                     # "58 checks, 0 failed"
    (re.compile(r"\ball\s+(\d+)\s+passed\b", re.I), lambda m: int(m.group(1))),                                 # "all 12 passed"
    (re.compile(r"\b(\d+)\s+(?:[A-Za-z]+\s+)?(?:texts?|files?|cases?|tests?|items?|runs?|lines?|rules?)\s+checked\b", re.I),
     lambda m: int(m.group(1))),                                                                             # "83 Lua files checked"
)
MISSING_INPUT = re.compile(r"MISSING INPUT:\s*(.*)")
EXPECT_ERRORS = re.compile(r"^\s*EXPECT_ERRORS\s+(?:XUI-)?([EW]\d{3})\s+(\d+)\s*$")
DEFAULT_TIME_LIMIT = 600   # seconds; the slowest ordinary test took about 100 s in the round-10 timing run (TEST-AUDIT section 3)
# the tests that play the V27 gate's scenario (fresh, without the shared cached result, gate_keyboard took 756 s and fix_r10_gate_bonus
# 764 s in the round-10 timing run on a loaded machine): about three times that
TIME_LIMITS = {n: 2400 for n in ("gate_performance_run.py", "gate_mouse_run.py", "gate_keyboard_run.py", "fix_r10_gate_bonus_run.py",
                                 "fix_r9_gate_scenario_run.py", "fix_r8_gate_scenario_run.py", "fix_r8_gate_probe_run.py",
                                 "v33_budget_teeth_run.py", "harness")}
# a test may raise its own limit with a line "# XUI_TIME_LIMIT: <seconds>" in its source (the larger of the two wins)
SOURCE_LIMIT = re.compile(r"^#\s*XUI_TIME_LIMIT:\s*(\d+)\s*$", re.M)


def line_passes(last):
    """True when a test's last output line reports no failure (see the module docstring)."""
    counts = [int(c) for c in FAILED_COUNT.findall(last)] + [int(c) for c in FAILS_COUNT.findall(last)]
    if counts:
        return all(c == 0 for c in counts)
    return bool(NO_COUNT_PASS.search(last)) and not FAIL_WORD.search(last)


def checked_count(last):
    """How many things the last line says were checked, or None when it says no such count (NO COUNT LINE)."""
    for rx, value in COUNT_PATTERNS:
        m = rx.search(last)
        if m:
            return value(m)
    return None


def time_limit(path, default=DEFAULT_TIME_LIMIT):
    name = os.path.basename(path)
    limit = max(default, TIME_LIMITS.get(name, 0))
    try:
        m = SOURCE_LIMIT.search(open(path, encoding="utf-8", errors="replace").read())
        if m:
            limit = max(limit, int(m.group(1)))
    except OSError:
        pass
    return limit


def tally_record(entries):
    """{code: occurrences} from the record entries the child read: per (code, message, first time) the highest n (one entry a later
    runtime loaded from saved data), summed per code over the rest."""
    best = {}
    for e in entries:
        key = (e.get("code"), e.get("msg"), e.get("first"))
        best[key] = max(best.get(key, 0), int(e.get("n") or 1))
    out = {}
    for (code, _msg, _first), n in best.items():
        out[code] = out.get(code, 0) + n
    return out


def judge(stdout, returncode, report, hung=False):
    """Every reason a finished test is not ok (an empty list: ok). report: the child's guard report (None when it wrote none)."""
    lines = stdout.strip().splitlines()
    last = (lines or [""])[-1]
    why = []
    if hung:
        why.append(("HUNG", "no result within its time limit; stopped with every process it started"))
    elif returncode != 0:
        why.append(("EXIT", "exit code %s" % returncode))
    if not hung and not line_passes(last):
        why.append(("LAST LINE", "the last line reports a failure or no result: %r" % last[:200]))
    n = checked_count(last)
    if not hung and n is None:
        why.append(("NO COUNT LINE", "the last line does not say how many things it checked (\"N checks, M failed\"): %r" % last[:120]))
    elif not hung and n == 0:
        why.append(("CHECKED NOTHING", "it checked 0 things: %r" % last[:120]))
    for l in lines:
        m = MISSING_INPUT.search(l)
        if m:
            why.append(("MISSING INPUT", m.group(1).strip()[:300] or "(the test did not say what)"))
    declared = {}
    for l in lines:
        m = EXPECT_ERRORS.match(l)
        if m:
            code = "XUI-" + m.group(1)
            declared[code] = declared.get(code, 0) + int(m.group(2))
    if report is None:
        if not hung:
            why.append(("GUARD BLIND", "the test process ended without the guard's report (os._exit or a crash), so its error record and "
                                       "inputs could not be read"))
        return why
    for x in report.get("missing", []):
        why.append(("MISSING INPUT", x))
    seen = tally_record(report.get("entries", []))
    sample = {}
    for e in report.get("entries", []):
        sample.setdefault(e.get("code"), e.get("msg"))
    for code in sorted(set(seen) | set(declared)):
        got, want = seen.get(code, 0), declared.get(code, 0)
        if got == want:
            continue
        if want == 0:
            why.append(("ERROR RECORD", "%s x%d not declared (EXPECT_ERRORS %s %d): %s" % (code, got, code, got, str(sample.get(code))[:200])))
        elif got == 0:
            why.append(("EXPECTED ERROR NOT SEEN", "declared EXPECT_ERRORS %s %d, the record has none" % (code, want)))
        else:
            why.append(("ERROR RECORD", "%s x%d, declared %d: %s" % (code, got, want, str(sample.get(code))[:200])))
    for x in report.get("guardErrors", []):
        why.append(("GUARD BLIND", x))
    return why


def run_one(path, args=(), limit=None, cwd=None):
    """Run one test under the guard. Returns (state "ok" / "FAIL" / "HUNG", last line, reasons [(code, text)], stdout, seconds)."""
    limit = limit if limit is not None else time_limit(path)
    fd, rpath = tempfile.mkstemp(prefix="xui-m1-", suffix=".json")
    os.close(fd)
    os.unlink(rpath)   # (the child writes it; its absence afterwards means the child never got to write it)
    cmd = [sys.executable, os.path.abspath(__file__), "--m1-child", rpath, os.path.abspath(path)] + list(args)
    t0 = time.time()
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, errors="replace",
                         cwd=cwd or os.path.dirname(HERE), start_new_session=True)
    hung = False
    try:
        out, err = p.communicate(timeout=limit)
    except subprocess.TimeoutExpired:
        hung = True
        try:
            os.killpg(p.pid, signal.SIGKILL)   # the test and every process it started (its own session)
        except (ProcessLookupError, PermissionError):
            p.kill()
        out, err = p.communicate()
    secs = time.time() - t0
    report = None
    if os.path.isfile(rpath):
        try:
            with open(rpath, encoding="utf-8") as f:
                report = json.load(f)
        except (OSError, ValueError):
            report = None
        finally:
            os.unlink(rpath)
        if report is not None and not report.get("complete") and not hung:
            report.setdefault("guardErrors", []).append("the test process ended before the guard's exit handler ran (os._exit or a crash)")
    why = judge(out or "", p.returncode, report, hung)
    last = ((out or "").strip().splitlines() or [""])[-1]
    state = "HUNG" if hung else ("ok" if not why else "FAIL")
    return state, last, why, out or "", secs, err or ""


# ---------------------------------------------------------------------------------------------------------------------------------
# the child: runs one test with the guard's eyes on it (python3 tests/run_all.py --m1-child REPORT.json TEST.py [args])
# ---------------------------------------------------------------------------------------------------------------------------------
# reads CueRulesDB.errorLog with rawget only (the stand-in's _G reports every unknown global it is asked for: tests/harness/world.lua)
HARVEST_LUA = r'''function()
  local db = rawget(_G, "CueRulesDB")
  if type(db) ~= "table" then return nil end
  local log = rawget(db, "errorLog")
  if type(log) ~= "table" then return nil end
  local out, i = {}, 1
  while i <= 200 do
    local e = rawget(log, i)
    if e == nil then break end
    if type(e) == "table" then
      local msg = tostring(rawget(e, "msg")):gsub("[\t\n\r]", " ")
      out[#out + 1] = tostring(rawget(e, "code")) .. "\t" .. tostring(rawget(e, "kind")) .. "\t" .. tostring(rawget(e, "n")) .. "\t" ..
        tostring(rawget(e, "first")) .. "\t" .. msg:sub(1, 300)
    end
    i = i + 1
  end
  return table.concat(out, "\n")
end'''
NO_REPO_GIT = {"init", "clone", "version", "help", "--version", "--help", "-h"}


def _child(rpath, test, argv):
    import atexit, runpy, shlex, weakref
    state = {"entries": [], "runtimes": 0, "missing": [], "guardErrors": [], "complete": False}
    seen_rt = weakref.WeakSet()

    def harvest(rt):
        if getattr(rt, "_xui_m1_read", False):
            return
        try:
            rt._xui_m1_read = True
            text = rt.eval(HARVEST_LUA)()
        except Exception as e:   # (a runtime closed or broken by the test: its record cannot be read)
            state["guardErrors"].append("a Lua runtime's error record could not be read: %s" % str(e)[:200])
            return
        for row in str(text or "").split("\n"):
            if not row:
                continue
            code, kind, n, first, msg = (row.split("\t", 4) + ["", "", "", "", ""])[:5]
            try:
                n = int(float(n))
            except ValueError:
                n = 1
            state["entries"].append({"code": code, "kind": kind, "n": n, "first": first, "msg": msg})

    def write():
        try:
            with open(rpath, "w", encoding="utf-8") as f:
                json.dump(state, f)
        except OSError:
            pass

    try:
        import lupa.lua51 as l51

        class GuardedLuaRuntime(l51.LuaRuntime):
            """lupa's Lua 5.1 runtime, registered so the guard can read its error record (its own __cinit__ takes the arguments)."""

            def __init__(self, *a, **kw):
                state["runtimes"] += 1
                seen_rt.add(self)

            def __del__(self):   # (runs while the runtime is still whole: its Lua state closes after this)
                harvest(self)

        l51.LuaRuntime = GuardedLuaRuntime
    except ImportError:
        pass   # (a test without Lua: nothing to read)

    repo_cache = {}
    OrigPopen = subprocess.Popen

    def note_git(args, cwd, shell):
        try:
            argv_ = shlex.split(args) if isinstance(args, str) else [str(a) for a in args]
        except (ValueError, TypeError):
            return
        if not argv_ or os.path.basename(argv_[0]) != "git":
            return
        d, i, sub = cwd or os.getcwd(), 1, None
        while i < len(argv_):
            a = argv_[i]
            if a == "-C" and i + 1 < len(argv_):
                d = os.path.join(d, argv_[i + 1]); i += 2; continue
            if a in ("-c", "--git-dir", "--work-tree") and i + 1 < len(argv_):
                i += 2; continue
            if a.startswith("-") and sub is None and a not in NO_REPO_GIT:
                i += 1; continue
            sub = a
            break
        if sub is None or sub in NO_REPO_GIT or "--no-index" in argv_:
            return
        d = os.path.abspath(str(d))
        if d not in repo_cache:
            try:
                rc = OrigPopen(["git", "-C", d, "rev-parse", "--git-dir"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).wait()
                repo_cache[d] = None if rc == 0 else "%s is not inside a git checkout" % d
            except OSError:
                repo_cache[d] = "git is not installed"
        if repo_cache[d]:
            msg = "git (%s; the test ran: %s)" % (repo_cache[d], " ".join(argv_[:6])[:160])
            if msg not in state["missing"]:
                state["missing"].append(msg)
                sys.stderr.write("MISSING INPUT: " + msg + "\n")

    class GuardedPopen(OrigPopen):
        def __init__(self, args, *a, **kw):
            note_git(args, kw.get("cwd"), kw.get("shell"))
            super().__init__(args, *a, **kw)

    subprocess.Popen = GuardedPopen

    def at_exit():
        for rt in list(seen_rt):
            harvest(rt)
        state["complete"] = True
        write()

    atexit.register(at_exit)
    write()   # (a first report, incomplete: if the process is cut off, run_all sees GUARD BLIND, not an empty pass)
    sys.argv = [test] + list(argv)
    sys.path[0] = os.path.dirname(test)
    runpy.run_path(test, run_name="__main__")


# ---------------------------------------------------------------------------------------------------------------------------------
def suite_inputs():
    """MISSING INPUT lines for what the whole suite needs: the API index and a git checkout (SD-138: it must say what)."""
    out = []
    p = os.environ.get("XUI_API_INDEX", os.path.join(HERE, "harness", "api_index.json"))
    try:
        ok = bool(json.load(open(p)).get("functions"))
    except (OSError, ValueError):
        ok = False
    if not ok:
        out.append("the stand-in's API index (%s; set XUI_API_INDEX or build it: python3 tests/harness/api_index_from_docs.py)" % p)
    try:
        r = subprocess.run(["git", "-C", ROOT, "ls-files", "XayaUI"], capture_output=True, text=True)
        if r.returncode != 0 or not r.stdout.strip():
            out.append("a git checkout of this repository (%s: git ls-files lists nothing)" % ROOT)
    except OSError:
        out.append("git (not installed)")
    return out


def show(name, state, last, why):
    print(("ok   " if state == "ok" else "%-4s " % state) + name + "  " + last[:90])
    for code, text in why:
        print("     M1 %s: %s" % (code, text))


def main(args):
    saved = args[args.index("--saved") + 1] if "--saved" in args else None
    quick = "--quick" in args
    jpath = args[args.index("--json") + 1] if "--json" in args else None
    default_limit = int(args[args.index("--time-limit") + 1]) if "--time-limit" in args else DEFAULT_TIME_LIMIT
    only = None
    if "--only" in args:
        only = []
        for a in args[args.index("--only") + 1:]:
            if a.startswith("--"):
                break
            only.append(a if a.endswith(".py") else a + "_run.py")
    bad = hung = 0
    results = []
    for x in suite_inputs():
        print("MISSING INPUT: " + x)
        bad += 1
        results.append({"test": "(suite)", "state": "FAIL", "reasons": [["MISSING INPUT", x]]})
    tests = sorted(glob.glob(os.path.join(HERE, "*_run.py")))
    if only is not None:
        tests = [t for t in tests if os.path.basename(t) in only]
    for t in tests:
        state, last, why, _out, secs, _err = run_one(t, limit=time_limit(t, default_limit))
        bad += 0 if state == "ok" else 1
        hung += 1 if state == "HUNG" else 0
        show(os.path.basename(t), state, last, why)
        results.append({"test": os.path.basename(t), "state": state, "last": last, "seconds": round(secs, 1), "reasons": why})
    if only is None:
        harness = [os.path.join(HERE, "harness", "run.py"), "--fresh-only"]
        runs = [(harness + (["--only"] + FEATURES if quick else []))]
        if saved:
            runs.append([os.path.join(HERE, "harness", "run.py"), "--saved", saved, "--only"] + FEATURES)
        for h in runs:
            state, last, why, out, secs, err = run_one(h[0], args=h[1:], limit=max(default_limit, TIME_LIMITS["harness"]))
            sys.stdout.write(out)
            sys.stderr.write(err)
            bad += 0 if state == "ok" else 1
            hung += 1 if state == "HUNG" else 0
            show("harness " + " ".join(h[1:]), state, last, why)
            results.append({"test": "harness " + " ".join(h[1:]), "state": state, "last": last, "seconds": round(secs, 1), "reasons": why})
    if jpath:
        with open(jpath, "w", encoding="utf-8") as f:
            json.dump(results, f, indent=1)
    print("ALL CHECKS PASS" if bad == 0 else ("%d CHECK GROUP(S) FAILED" % bad) + (" (%d HUNG)" % hung if hung else ""))
    return 1 if bad else 0


if __name__ == "__main__":
    if len(sys.argv) > 3 and sys.argv[1] == "--m1-child":
        _child(sys.argv[2], sys.argv[3], sys.argv[4:])
    else:
        sys.exit(main(sys.argv[1:]))
