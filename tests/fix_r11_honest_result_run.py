#!/usr/bin/env python3
"""Round 11 (11a), the honest-result guard: SD-129 (her answer "Yes, in round 11 (Recommended)") and SD-138 mechanism M1 (her answer
"Amended version (Recommended)"; VERIFICATION.md V35, her approved wording: "Every test run: a test fails if it checked nothing, if
something it needs is missing (it must say what), if it prints no result count, or if an engine error happened that it did not expect.
A test that runs too long is marked HUNG, not passed.").

What the suite (tests/run_all.py) must now say about a test, proved on synthetic tests and on the real ones:
  A  a test that checked nothing FAILS (CHECKED NOTHING); one with no count line FAILS (NO COUNT LINE: "FAILS: 0" and "ALL PASSED" alone);
     one that says what input is missing FAILS (MISSING INPUT); one whose exit code says failure FAILS even with a passing line; one that
     leaves through os._exit FAILS (GUARD BLIND); an honest one is ok.
  E  the error record (CueRulesDB.errorLog, XayaUI/DebugRecord.lua, SD-139) of every Lua runtime the test makes is read at its end: an
     entry it did not declare FAILS the test, a declared one ("EXPECT_ERRORS XUI-E011 1") passes, a declared one that did not happen
     FAILS, a wrong count FAILS; a runtime freed before the end is read too; an entry a later runtime loaded from saved data counts once.
  X  THE EXACT CASE the efficacy review found (TEST-EFFICACY-REVIEW section 2 item 3): an error() put into the real engine
     (XayaUI_Rules/Engine.lua, inside the step SafeStep runs) is caught by SafeStep, which prints to chat only; tests/fix_r9_engine_narrow
     still prints "58 checks, 0 failed" and exits 0, so the old rule called it ok. The guard FAILS it, naming XUI-E011 and the message.
     Declared, the same run passes.
  H  a test past its time limit is HUNG (never ok), and the processes it started are stopped with it.
  G  without git (a copy of this repository with no .git) the tests that read "git ls-files" / "git grep" (american_spelling,
     key_propagation, devassist_rename: the test audit's vacuous passes) FAIL with MISSING INPUT naming git, and the suite itself prints
     MISSING INPUT for the checkout.
  S  skin_button and aura_sources exit non-zero on a failure and print a count line (test audit F4), shown by breaking the addon code
     each checks (a copy): before, both printed "FAILS: N" and exited 0.
  F  memory_report is folded (SD-129; test audit section 2): it is no longer in the suite (tests/memory_report.py is the report tool),
     its checks are in fix_r7_relocate L1 and gate_performance (memory_report_fold), and those checks fail on the conditions it failed on.
     (repair 1) L1's realistic case is memory_report's own long-used install (one shared session A: the gate's rule list plus EXTRAS_LUA),
     proved by the review's fault: rules not loaded when drafts are saved fails L1 as it failed memory_report (F10).
  R  the whole-addon harness reads each session's error record (an entry FAILS the run, an entry carried by saved data once) and its last
     line says how many runs it checked; the report keeps its shape ("ok   ", "FAIL ", "HUNG ", reasons on "     M1 " lines; the final
     line "ALL CHECKS PASS" / "N CHECK GROUP(S) FAILED").
  C  the count grammar reads every count line format the suite prints today, and line_passes is unchanged. (round 11 repair) C3: the
     grammar is NOT widened for the closure scan's "in 83 file(s)" or tooltip_parity's "0 failed": those tests now print "N checks,
     M failed" (a count of checks made); a count of files, sites or failures alone stays no count of checks.
  N  (round 11 repair, R11A final hidden_error_inventory) the 42 tests the guard read as NO COUNT LINE end with an honest count line:
     N1 each test whose checks each print one line ("PASS " / "FAIL " / "ok ") says it made exactly as many checks as it printed, and
     failed exactly as many as it printed FAIL; N2 the scans (closure scan, hover texts, trigger labels) count their items, more than 0;
     N3 the tests that raise errors on purpose (group C) declare exactly those (EXPECT_ERRORS): under the guard no ERROR RECORD and no
     EXPECTED ERROR NOT SEEN reason; N4 gate_mouse and gate_keyboard (played on synthetic results here; the real plays take 15 minutes)
     end with "<gate>: N checks, M failed (...)  FAILS: K", N = their named checks in both variants (counted from judge's source), a
     violation names its check and does not pass, and a clean result passes.
  T  (round 11 repair, the R11A repair-2 review of the stand-in loader's note) T1 tally_record counts each occurrence once, in the session
     where it happened: two loader sessions that started in the same second add up (the old merge on code, message and first time read
     them as one), a carried entry counts once, a seeded one at its seeded count; T2-T4 the guard's limit (a runtime is read once, when
     it is freed) is guarded: two stand-in loader sessions in one runtime are GUARD BLIND, one is ok; T5 every place a test makes the
     loader goes through dofile(path)(W, o), the call the guard counts; T6 a runtime made with encoding=None (it hands the guard
     bytes) is read like any other; T7 (round 11b final fix) a test that kills Lua builtins in its runtime (type, tostring, rawget,
     string.gsub, table.concat) is still read: the guard's reader captured them before the test ran (before: GUARD BLIND).
Fails on the pre-change files (tests/run_all.py, tests/harness/run.py, skin_button, aura_sources, memory_report_run.py, fix_r7_relocate,
gate_performance): there the old rule (exit 0 and a passing last line) is applied, which takes the synthetic dishonest tests as ok.
Stand-in only: UNVERIFIED IN GAME (nothing here runs in the game; the guard judges the offline tests).
Run: XUI_API_INDEX=tests/harness/api_index.json python3 tests/fix_r11_honest_result_run.py"""
# XUI_TIME_LIMIT: 900
import concurrent.futures, contextlib, glob, importlib.util, io, os, re, shutil, signal, subprocess, sys, tempfile, time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "harness"))
spec = importlib.util.spec_from_file_location("run_all_under_test", os.path.join(HERE, "run_all.py"))
R = importlib.util.module_from_spec(spec)
spec.loader.exec_module(R)   # (main() runs only as a script)
NEW = hasattr(R, "run_one")
COUNT_FALLBACK = re.compile(r"\b\d+\s+checks?\b|\b\d+\s+passed\b|\b\d+\s+(?:[A-Za-z]+\s+)?\w+\s+checked\b", re.I)

checks, fails = 0, 0


def check(name, ok, detail=""):
    global checks, fails
    checks += 1
    if not ok:
        fails += 1
    print(("PASS " if ok else "FAIL ") + name + ("" if ok or not detail else "  [" + str(detail)[:500] + "]"))


def verdict(path, limit=60, args=(), cwd=None):
    """The suite's verdict on one test: (state, reasons, last line, stdout). Under a runner without the guard (the pre-change
    tests/run_all.py) the old rule is applied as it ran there: exit 0 and a passing last line, no time limit (a hang is no verdict)."""
    if NEW:
        st, last, why, out, _secs, _err = R.run_one(path, args=args, limit=limit, cwd=cwd)
        return st, why, last, out
    try:
        r = subprocess.run([sys.executable, path] + list(args), capture_output=True, text=True, cwd=cwd or ROOT, timeout=limit,
                           start_new_session=True)
    except subprocess.TimeoutExpired:
        return "NO VERDICT (the old runner has no time limit: it would wait for ever)", [], "", ""
    last = (r.stdout.strip().splitlines() or [""])[-1]
    return ("ok" if r.returncode == 0 and R.line_passes(last) else "FAIL"), [], last, r.stdout


def codes(why):
    return [c for c, _ in why]


def text(why):
    return " | ".join("%s: %s" % (c, t) for c, t in why)


def write(d, name, src):
    p = os.path.join(d, name)
    with open(p, "w", encoding="utf-8") as f:
        f.write(src)
    return p


SEED = '''from lupa.lua51 import LuaRuntime
L = LuaRuntime(unpack_returned_tuples=True)
L.execute('CueRulesDB = { errorLog = { { code = "XUI-E011", kind = "error", msg = "XayaUI engine: Engine.lua:1424: boom", n = %d, first = 100, last = 200 } } }')
'''


def synthetic(d):
    """A and E: synthetic tests, each one way of passing dishonestly (or honestly)."""
    T = {
        "nothing": 'print("0 checks, 0 failed")\n',
        "nocount": 'print("PASS a")\nprint("FAILS: 0")\n',
        "allpassed": 'print("ALL PASSED")\n',
        "missing": 'print("MISSING INPUT: tests/harness/api_index.json (XUI_API_INDEX)")\nprint("3 checks, 0 failed")\n',
        "exit": 'import sys\nprint("3 checks, 0 failed")\nsys.exit(2)\n',
        "osexit": 'import os, sys\nprint("3 checks, 0 failed")\nsys.stdout.flush()\nos._exit(0)\n',
        "honest": 'from lupa.lua51 import LuaRuntime\nL = LuaRuntime()\nL.execute("CueRulesDB = { errorLog = {} }")\nprint("3 checks, 0 failed")\n',
        "seeded": SEED % 38 + 'print("58 checks, 0 failed")\n',
        "declared": SEED % 2 + 'print("EXPECT_ERRORS XUI-E011 2")\nprint("3 checks, 0 failed")\n',
        "declared_short": 'print("EXPECT_ERRORS E011 1")\nprint("3 checks, 0 failed")\n',
        "declared_wrong": SEED % 3 + 'print("EXPECT_ERRORS XUI-E011 1")\nprint("3 checks, 0 failed")\n',
        "freed": 'def f():\n    ' + SEED.replace("\n", "\n    ") % 1 + '\nf()\nimport gc; gc.collect()\nprint("3 checks, 0 failed")\n',
        "carried": SEED % 1 + 'L2 = LuaRuntime(unpack_returned_tuples=True)\n'
                   'L2.execute(\'CueRulesDB = { errorLog = { { code = "XUI-E011", kind = "error", msg = "XayaUI engine: Engine.lua:1424: boom", '
                   'n = 1, first = 100, last = 300 } } }\')\nprint("EXPECT_ERRORS XUI-E011 1")\nprint("3 checks, 0 failed")\n',
        "separate": SEED % 1 + 'L2 = LuaRuntime(unpack_returned_tuples=True)\n'
                    'L2.execute(\'CueRulesDB = { errorLog = { { code = "XUI-E011", kind = "error", msg = "XayaUI engine: Engine.lua:1424: boom", '
                    'n = 1, first = 500, last = 500 } } }\')\nprint("EXPECT_ERRORS XUI-E011 2")\nprint("3 checks, 0 failed")\n',
        "warning": 'from lupa.lua51 import LuaRuntime\nL = LuaRuntime()\n'
                   'L.execute(\'CueRulesDB = { errorLog = { { code = "XUI-W002", kind = "warning", msg = "w", n = 1, first = 1 } } }\')\n'
                   'print("3 checks, 0 failed")\n',
        "gitless": 'import subprocess, tempfile\nd = tempfile.mkdtemp()\n'
                   'files = subprocess.run(["git", "ls-files"], cwd=d, capture_output=True, text=True).stdout.split()\n'
                   'print("%d files checked  FAILS: 0" % (len(files) + 7))\n',
        "gitok": 'import subprocess, os\nr = subprocess.run(["git", "-C", %r, "ls-files", "XayaUI"], capture_output=True, text=True)\n'
                 'print("%%d files checked  FAILS: 0" %% len(r.stdout.split()))\n' % ROOT,
        "hang": 'import subprocess, sys, time\np = subprocess.Popen(["sleep", "300"])\nopen(sys.argv[1], "w").write(str(p.pid))\n'
                'print("1 checks, 0 failed", flush=True)\nwhile True:\n    time.sleep(1)\n',
    }
    paths = {k: write(d, "syn_%s_run.py" % k, v) for k, v in T.items()}

    st, why, last, _ = verdict(paths["nothing"])
    check("A1 a test that checked nothing ('0 checks, 0 failed') FAILS: CHECKED NOTHING", st == "FAIL" and "CHECKED NOTHING" in codes(why),
          "%s %s" % (st, text(why)))
    st, why, last, _ = verdict(paths["nocount"])
    check("A2 a test with no count line ('FAILS: 0' alone) FAILS: NO COUNT LINE", st == "FAIL" and "NO COUNT LINE" in codes(why),
          "%s %s" % (st, text(why)))
    st, why, last, _ = verdict(paths["allpassed"])
    check("A2 ... and 'ALL PASSED' alone FAILS the same way", st == "FAIL" and "NO COUNT LINE" in codes(why), "%s %s" % (st, text(why)))
    st, why, last, _ = verdict(paths["missing"])
    check("A3 a test that prints the missing-input line (MISSING INPUT, a colon, then what) FAILS, and the reason names what is missing",
          st == "FAIL" and any(c == "MISSING INPUT" and "api_index.json" in t for c, t in why), "%s %s" % (st, text(why)))
    st, why, last, _ = verdict(paths["exit"])
    check("A4 a test that exits 2 after '3 checks, 0 failed' FAILS (EXIT)", st == "FAIL" and "EXIT" in codes(why), "%s %s" % (st, text(why)))
    st, why, last, _ = verdict(paths["osexit"])
    check("A5 a test that leaves through os._exit(0) after '3 checks, 0 failed' FAILS: GUARD BLIND (its record could not be read)",
          st == "FAIL" and "GUARD BLIND" in codes(why), "%s %s" % (st, text(why)))
    why = R.judge("3 checks, 0 failed", 0, None) if NEW else []
    check("A5 ... and a run that left no guard report at all (the child never got to write one) FAILS: GUARD BLIND",
          "GUARD BLIND" in codes(why), text(why))
    st, why, last, _ = verdict(paths["honest"])
    check("A6 control: an honest test (3 checks, an empty error record) is ok", st == "ok" and not why, "%s %s" % (st, text(why)))

    st, why, last, _ = verdict(paths["seeded"])
    check("E1 a test whose error record holds XUI-E011 x38 while it prints '58 checks, 0 failed' FAILS: ERROR RECORD names the code, "
          "the count and the message", st == "FAIL" and any(c == "ERROR RECORD" and "XUI-E011 x38" in t and "boom" in t for c, t in why),
          "%s %s" % (st, text(why)))
    st, why, last, _ = verdict(paths["declared"])
    check("E2 the same error declared ('EXPECT_ERRORS XUI-E011 2', the exact count) passes", st == "ok" and not why, "%s %s" % (st, text(why)))
    st, why, last, _ = verdict(paths["declared_short"])
    check("E3 a declared error that did not happen FAILS: EXPECTED ERROR NOT SEEN ('E011' is read as XUI-E011)",
          st == "FAIL" and any(c == "EXPECTED ERROR NOT SEEN" and "XUI-E011 1" in t for c, t in why), "%s %s" % (st, text(why)))
    st, why, last, _ = verdict(paths["declared_wrong"])
    check("E4 a wrong count (3 happened, 1 declared) FAILS", st == "FAIL" and any("x3, declared 1" in t for _, t in why), "%s %s" % (st, text(why)))
    st, why, last, _ = verdict(paths["freed"])
    check("E5 a runtime the test freed before its end is read too (its entry FAILS the test)",
          st == "FAIL" and any(c == "ERROR RECORD" and "XUI-E011 x1" in t for c, t in why), "%s %s" % (st, text(why)))
    st, why, last, _ = verdict(paths["carried"])
    check("E6 an entry a second runtime loaded from saved data (same code, message, first time) counts once: declared 1, ok",
          st == "ok" and not why, "%s %s" % (st, text(why)))
    st, why, last, _ = verdict(paths["separate"])
    check("E7 the same error in two separate runtimes counts twice: declared 2, ok", st == "ok" and not why, "%s %s" % (st, text(why)))
    st, why, last, _ = verdict(paths["warning"])
    check("E8 a warning entry (XUI-W002) is an entry too: undeclared, it FAILS", st == "FAIL" and any("XUI-W002" in t for _, t in why),
          "%s %s" % (st, text(why)))
    st, why, last, _ = verdict(paths["gitless"])
    check("G1 a test that ran 'git ls-files' in a folder that is not a git checkout FAILS: MISSING INPUT names git",
          st == "FAIL" and any(c == "MISSING INPUT" and t.startswith("git") and "not inside a git checkout" in t for c, t in why),
          "%s %s" % (st, text(why)))
    st, why, last, _ = verdict(paths["gitok"])
    check("G2 control: the same git call in this checkout is ok", st == "ok" and not why, "%s %s" % (st, text(why)))

    pidfile = os.path.join(d, "hang.pid")
    t0 = time.time()
    st, why, last, _ = verdict(paths["hang"], limit=3, args=(pidfile,))
    secs = time.time() - t0
    check("H1 a test that never ends is HUNG (its own state, never ok) at its time limit (3 s here: %.1f s)" % secs,
          st == "HUNG" and "HUNG" in codes(why) and secs < 30, "%s %s" % (st, text(why)))
    gone = False
    try:
        pid = int(open(pidfile).read())
        for _ in range(50):
            try:
                os.kill(pid, 0)
            except ProcessLookupError:
                gone = True
                break
            time.sleep(0.1)
        if not gone:
            os.kill(pid, signal.SIGKILL)   # (this test's own sleep 300: never left behind)
    except (OSError, ValueError):
        pass
    check("H2 ... and the process it started (a 300 s sleep) was stopped with it", gone)
    check("H3 a test's own '# XUI_TIME_LIMIT: <s>' line raises its limit, and the gate tests have the long limit",
          NEW and R.time_limit(os.path.abspath(__file__)) >= 900 and R.time_limit(os.path.join(HERE, "gate_keyboard_run.py")) >= 2400
          and R.time_limit(paths["honest"]) == R.DEFAULT_TIME_LIMIT)


# (round 11 repair, counts unit; the R11A repair-2 review of the stand-in loader's note) T: the tally per session and its limit
LOADER = os.path.join(HERE, "harness", "loader.lua")
TWO_IN_ONE = '''from lupa.lua51 import LuaRuntime
L = LuaRuntime(unpack_returned_tuples=True)
L.execute("CueRulesDB = { errorLog = {} }")
mk = L.eval("function(p) return dofile(p) end")(%r)
W = L.eval("{ fire = function() end, safecall = function(f, ...) return pcall(f, ...) end }")
for _ in range(%%d):
    mk(W, L.eval("{ folders = {}, saved = {} }"))
print("3 checks, 0 failed")
''' % LOADER
REDOFILE = '''from lupa.lua51 import LuaRuntime
L = LuaRuntime(unpack_returned_tuples=True)
L.execute("CueRulesDB = { errorLog = {} }")
make = L.eval("function(p, W) return dofile(p)(W, { folders = {}, saved = {} }) end")
W = L.eval("{ fire = function() end, safecall = function(f, ...) return pcall(f, ...) end }")
make(%r, W)
L2 = LuaRuntime(unpack_returned_tuples=True)
L2.execute("CueRulesDB = { errorLog = {} }")
L2.eval("function(p, W) return dofile(p)(W, { folders = {}, saved = {} }) end")(%r, L2.eval("{ fire = function() end, safecall = pcall }"))
make(%r, W)
print("3 checks, 0 failed")
''' % (LOADER, LOADER, LOADER)


def tally_sessions(d):
    """T1-T5: each occurrence counts once, in the session where it happened, also when two sessions start in the same second; the
    guard's limit (a runtime is read once) is guarded: a runtime with more than one stand-in loader session is GUARD BLIND."""
    if not NEW:
        check("T0 the suite's guard is there to test", False, "the old run_all.py has no run_one")
        return
    e = lambda **k: dict({"code": "XUI-W002", "msg": "no container", "first": "1700000000", "n": 1}, **k)   # noqa: E731
    cases = [
        ("two separate loader sessions that started in the same second (same code, message and first time), each made it once",
         [e(carried=0), e(carried=0)], 2),
        ("the second session loaded the first's entry (n 1, noted 1) and it happened there again (n 2)", [e(carried=0), e(n=2, carried=1)], 2),
        ("an entry seeded in saved data (n 3) that two sessions loaded and neither repeated", [e(n=3, carried=3), e(n=3, carried=3)], 3),
        ("a seeded entry (n 3) that the session repeated twice (n 5)", [e(n=5, carried=3)], 5),
        ("two bare runtimes without the loader, same code, message and first time (the old rule: one entry carried)",
         [e(carried=None), e(n=2, carried=None)], 2),
    ]
    bad = [(what, R.tally_record(ent).get("XUI-W002"), want) for what, ent, want in cases if R.tally_record(ent).get("XUI-W002") != want]
    check("T1 tally_record (unit): two same-second loader sessions add up (2, where the old merge read 1), a carried entry counts once, "
          "a seeded one at its seeded count plus what was added, and runtimes without the loader keep the old rule", not bad, bad)
    p1 = write(d, "syn_one_session_run.py", TWO_IN_ONE % 1)
    st, why, last, _ = verdict(p1)
    check("T2 control: one stand-in loader session in its own runtime is ok", st == "ok" and not why, "%s %s" % (st, text(why)))
    p2 = write(d, "syn_two_sessions_run.py", TWO_IN_ONE % 2)
    st, why, last, _ = verdict(p2)
    check("T3 THE LIMIT, guarded: two stand-in loader sessions made in ONE runtime (the record is read once, when it is freed) FAIL: "
          "GUARD BLIND names the 2 sessions", st == "FAIL" and any(c == "GUARD BLIND" and "made 2 stand-in loader sessions" in t
                                                                 for c, t in why), "%s %s" % (st, text(why)))
    p3 = write(d, "syn_redofile_run.py", REDOFILE)
    st, why, last, _ = verdict(p3)
    check("T4 ... also when the loader file is read again for the second session (dofile twice); another runtime's single session "
          "is not counted with it", st == "FAIL" and sum(1 for c, t in why if c == "GUARD BLIND" and "loader sessions" in t) == 1
          and any("made 2 stand-in loader sessions" in t for c, t in why), "%s %s" % (st, text(why)))
    # T6: a runtime made with encoding=None (fix_r8_engine_scope makes one) hands the guard bytes: its entries are read as entries
    p6 = write(d, "syn_bytes_run.py", 'from lupa.lua51 import LuaRuntime\nL = LuaRuntime(encoding=None)\n'
               'L.execute(b\'CueRulesDB = { errorLog = { { code = "XUI-E011", kind = "error", msg = "boom", n = 2, first = 1 } } }\')\n'
               'print("EXPECT_ERRORS XUI-E011 2")\nprint("3 checks, 0 failed")\n')
    st, why, last, _ = verdict(p6)
    check("T6 a runtime made with encoding=None (it returns bytes) is read like any other: its XUI-E011 x2, declared 2, is ok",
          st == "ok" and not why, "%s %s" % (st, text(why)))
    # T7 (round 11b final fix: fix_r11_secret was GUARD BLIND) a test that breaks Lua's own builtins on purpose (fix_r11_secret T1 kills the
    # installed type() with a dead coroutine) must not blind the guard: its reader keeps the builtins it had before the test ran
    KILL = ('L.execute("local co = coroutine.wrap(function() end); co(); for _, k in ipairs({ \'type\', \'tostring\', \'tonumber\', '
            '\'rawget\' }) do rawset(_G, k, co) end; string.gsub, string.sub, table.concat = co, co, co")\n')
    p7 = write(d, "syn_killtype_run.py", SEED % 1 + KILL + 'print("3 checks, 0 failed")\n')
    st, why, last, _ = verdict(p7)
    check("T7 a test that kills type(), tostring(), rawget(), string.gsub and table.concat in its runtime is still read: its undeclared "
          "XUI-E011 FAILS as ERROR RECORD, never GUARD BLIND", st == "FAIL" and "ERROR RECORD" in codes(why) and "GUARD BLIND" not in codes(why),
          "%s %s" % (st, text(why)))
    p7b = write(d, "syn_killtype_declared_run.py", SEED % 1 + KILL + 'print("EXPECT_ERRORS XUI-E011 1")\nprint("3 checks, 0 failed")\n')
    st, why, last, _ = verdict(p7b)
    check("T7 ... and the same run with the entry declared is ok (the record was read whole)", st == "ok" and not why, "%s %s" % (st, text(why)))
    # T5: every place a test makes the stand-in's loader goes through dofile(".../loader.lua")(W, opts), which the guard counts
    sites, blind = 0, []
    for p in sorted(glob.glob(os.path.join(HERE, "*.py")) + glob.glob(os.path.join(HERE, "harness", "*.py"))):
        if os.path.abspath(p) == os.path.abspath(__file__):
            continue   # (this test: its T2-T4 cases make the loader through dofile on purpose, one way and the other)
        src = open(p, encoding="utf-8").read()
        for m in re.finditer(r'"loader\.lua"', src):
            line = src[src.rfind("\n", 0, m.start()) + 1:src.find("\n", m.end())]
            if line.lstrip().startswith("#") or "V33_STANDIN_FILES" in line or "_LOADER_SRC" in line:
                continue   # (a comment; the gate's fingerprint of the stand-in files; fix_r11_standin reads the file's text)
            sites += 1
            if not re.search(r"dofile\(path\)\(W, o\)", src[max(0, m.start() - 300):m.start()]):
                blind.append("%s: %s" % (os.path.relpath(p, ROOT), line.strip()[:100]))
    check("T5 every place a test makes the stand-in's loader (%d) does it through dofile(path)(W, o), the call the guard counts" % sites,
          sites >= 50 and not blind, blind)


def copy_repo(dst):
    """This repository's addon folders, docs and tests, without .git (a copy with no git history, as the test audit's snapshot was)."""
    for name in os.listdir(ROOT):
        if (name.startswith("XayaUI") or name == "docs") and os.path.isdir(os.path.join(ROOT, name)):
            shutil.copytree(os.path.join(ROOT, name), os.path.join(dst, name))
    shutil.copytree(HERE, os.path.join(dst, "tests"), ignore=shutil.ignore_patterns("__pycache__", "reports", "*.pyc"))
    return dst


ANCHOR = "    -- the checks were built again: the rules just re-checked note the answers they saw"


def exact_case(copy):
    """X: an error() put into the real engine's step, in a copy; tests/fix_r9_engine_narrow_run.py run there."""
    eng = os.path.join(copy, "XayaUI_Rules", "Engine.lua")
    src = open(eng, encoding="utf-8").read()
    if src.count(ANCHOR) != 1:
        check("X0 the place in Engine.lua the efficacy review broke is found (MISSING INPUT: the anchor line %r)" % ANCHOR[:60], False)
        return
    with open(eng, "w", encoding="utf-8") as f:
        f.write(src.replace(ANCHOR, '    error("M1 probe: an engine step error put here on purpose")\n' + ANCHOR))
    narrow = os.path.join(copy, "tests", "fix_r9_engine_narrow_run.py")
    r = subprocess.run([sys.executable, narrow], capture_output=True, text=True, cwd=copy)
    last = (r.stdout.strip().splitlines() or [""])[-1]
    check("X1 the hole: with the engine broken, fix_r9_engine_narrow still prints 'N checks, 0 failed' and exits 0 (the old rule's ok)",
          r.returncode == 0 and R.line_passes(last) and re.search(r"\b0 failed\b", last) is not None, "%s rc=%s" % (last, r.returncode))
    st, why, last2, _ = verdict(narrow, limit=300, cwd=copy)
    check("X2 the guard FAILS that run: ERROR RECORD XUI-E011 with the message SafeStep printed to chat only",
          st == "FAIL" and any(c == "ERROR RECORD" and "XUI-E011" in t and "M1 probe" in t for c, t in why), "%s %s" % (st, text(why)))
    # declared: a wrapper that says what it expects, then runs the same test (the counts the guard saw above)
    seen = {}
    for c, t in why:
        m = re.match(r"(XUI-[EW]\d{3}) x(\d+)", t)
        if c == "ERROR RECORD" and m:
            seen[m.group(1)] = int(m.group(2))
    wrap = write(os.path.join(copy, "tests"), "x_declared_run.py",
                 "".join('print("EXPECT_ERRORS %s %d")\n' % kv for kv in sorted(seen.items())) +
                 "import runpy, sys\nsys.argv = [%r]\nrunpy.run_path(%r, run_name='__main__')\n" % (narrow, narrow))
    st, why, last3, _ = verdict(wrap, limit=300, cwd=copy)
    check("X3 the same broken run with its errors declared (%s) passes: a deliberate error is allowed once it is said"
          % ", ".join("%s %d" % kv for kv in sorted(seen.items())), bool(seen) and st == "ok" and not why, "%s %s" % (st, text(why)))


def no_git(copy):
    """G: the tests the test audit found passing on 0 files without git, run in the copy (no .git)."""
    for name, rx in (("american_spelling_run.py", "git"), ("key_propagation_run.py", "git"), ("devassist_rename_run.py", "git")):
        st, why, last, _ = verdict(os.path.join(copy, "tests", name), limit=300, cwd=copy)
        check("G3 without git, %s FAILS with MISSING INPUT naming git (before: it passed on 0 files)" % name,
              st == "FAIL" and any(c == "MISSING INPUT" and t.startswith(rx) for c, t in why), "%s %s | %s" % (st, text(why), last))
    if NEW:
        # (in a process of its own: its git call in a folder with no checkout is the point here, not a missing input of this test)
        r = subprocess.run([sys.executable, "-c", "import sys; sys.path.insert(0, 'tests'); import run_all; "
                            "print(chr(10).join(run_all.suite_inputs()))"], cwd=copy, capture_output=True, text=True)
        miss = [l for l in r.stdout.splitlines() if l.strip()]
        check("G4 the suite itself, in a copy with no git checkout, prints MISSING INPUT for the checkout", any("git" in m for m in miss), miss)
        check("G5 ... and in this checkout (git, API index) it has nothing missing", R.suite_inputs() == [], R.suite_inputs())
    else:
        check("G4 the suite itself, in a copy with no git checkout, prints MISSING INPUT for the checkout", False, "no suite_inputs()")


def exit_codes(copy):
    """S: break what skin_button and aura_sources check, in the copy; each must exit non-zero with a count line."""
    for test, f, old, new in (("skin_button_run.py", "XayaUI/Core.lua", "local FLAT_GOLD = { 1, 0.82, 0, 1 }", "local FLAT_GOLD = { 1, 0.5, 0, 1 }"),
                              ("aura_sources_run.py", "XayaUI_Options/RuleEditor/AuraSources.lua", "function AS.Label(auraID)\n",
                               "function AS.Label(auraID)\n    do return \"broken\" end\n")):
        p = os.path.join(copy, f)
        s = open(p, encoding="utf-8").read()
        if s.count(old) != 1:
            check("S0 the line %s checks is found in %s (MISSING INPUT: %r)" % (test, f, old[:50]), False)
            continue
        with open(p, "w", encoding="utf-8") as fh:
            fh.write(s.replace(old, new))
        r = subprocess.run([sys.executable, os.path.join(copy, "tests", test)], capture_output=True, text=True, cwd=copy)
        last = (r.stdout.strip().splitlines() or [""])[-1]
        m = re.search(r"(\d+) checks, (\d+) failed", last)
        check("S1 %s with %s broken exits non-zero (exit %s) and its last line counts the checks and the failures (%r)" % (test, f, r.returncode, last),
              r.returncode != 0 and m is not None and int(m.group(2)) > 0)
        with open(p, "w", encoding="utf-8") as fh:
            fh.write(s)
        r = subprocess.run([sys.executable, os.path.join(copy, "tests", test)], capture_output=True, text=True, cwd=copy)
        last = (r.stdout.strip().splitlines() or [""])[-1]
        check("S2 ... unbroken it exits 0 with '%s'" % last, r.returncode == 0 and re.search(r"\d+ checks, 0 failed", last) is not None)


def memory_fold():
    """F: memory_report folded into fix_r7_relocate L1 and gate_performance."""
    check("F1 memory_report is no longer a suite test (no tests/memory_report_run.py) and its report is the tool tests/memory_report.py",
          not os.path.exists(os.path.join(HERE, "memory_report_run.py")) and os.path.isfile(os.path.join(HERE, "memory_report.py")))
    try:
        sp = importlib.util.spec_from_file_location("fix_r7_relocate_t", os.path.join(HERE, "fix_r7_relocate_run.py"))
        FR = importlib.util.module_from_spec(sp)
        sp.loader.exec_module(FR)
        got = FR.memory_report_checks()
    except Exception as e:   # (the pre-change file has no memory_report_checks)
        check("F2 fix_r7_relocate L1 has memory_report's checks (memory_report_checks)", False, "%s: %s" % (type(e).__name__, str(e)[:200]))
        got = []
    names = " | ".join(n for n, _ in got)
    want = ("a fresh install, every addon folder switched on: at login no file XayaUI Rules gave to XayaUI Options is read",   # C2 fresh
            "a fresh install, every addon folder switched on: at login none of the functions only the moved code defines exists",  # C3
            "the realistic ~300-rule profile: at login no file XayaUI Rules gave to XayaUI Options is read",                     # C2 realistic
            "with XayaUI Options loaded still no file XayaUI Rules gave to it is read",                                          # C2 + Options
            "the realistic profile's rules are loaded at login",                                                                 # C1
            "the realistic profile session A made has about 300 rules",                                                          # C4
            # (repair 1) the realistic case is memory_report's long-used install (the gate's rule list plus EXTRAS_LUA), not the rule list alone
            "session A made the long-used install's extras",
            "the long-used install's saved extras are there at login")
    if got and hasattr(FR, "SEEDED_ERRORS"):
        # the error-log entries memory_report's session A seeds on purpose ran in this process too (the guard reads them): declared exactly
        print("EXPECT_ERRORS %s %d" % FR.SEEDED_ERRORS)
    if got:
        check("F2 fix_r7_relocate L1 holds each of memory_report's checks (C1, C2 fresh / realistic / with Options, C3, C4)",
              all(w in names for w in want), [w for w in want if w not in names])
        check("F3 ... and they pass on this tree (%d checks)" % len(got), all(ok for _, ok in got), [n for n, ok in got if not ok])
        MR = set(FR.MOVED_NAMES)
        check("F4 fix_r7_relocate's list of moved functions holds all of memory_report's (none dropped by the fold)",
              {"AuraSetup_Open", "AuraSetup_WithSettings", "ScanAllTalents", "AuraSources", "TextureList", "BuildMinimapTab",
               "ElementWindowShown", "ElementMenu", "ElementRightClick", "DraftsMax", "RuleEditorFiles"} <= MR)
    try:
        import gate_performance_run as GP
        fold = GP.memory_report_fold
    except Exception as e:
        check("F5 gate_performance judges memory_report's rule counts (memory_report_fold)", False, "%s: %s" % (type(e).__name__, str(e)[:200]))
        return
    import gate_common as GCm

    def run(data):
        rep = GCm.Report("t")
        fold(data, rep)
        return " | ".join(w for w in (f[1] for f in rep.fails))
    good = {"rules": 307, "profile": {"entries": 307, "errorsA": []}}
    check("F5 gate_performance memory_report_fold: a good result has no finding", run(good) == "", run(good))
    check("F6 ... a profile of 200 rules FAILS [memory_report C4]", "[memory_report C4]" in run({"rules": 200, "profile": {"entries": 200}}))
    check("F7 ... no rules loaded FAILS [memory_report C1]", "[memory_report C1]" in run({"rules": 0, "profile": {"entries": 307}}))
    check("F8 ... a Lua error in session A FAILS", "session A" in run({"rules": 307, "profile": {"entries": 307, "errorsA": ["x.lua:1: boom"]}}))
    import inspect
    check("F9 ... and the gate's judge calls it on every variant", "memory_report_fold(data, rep)" in inspect.getsource(GP.judge))


DRAFTS_ANCHOR = "    ns.rules = CoreS.rules\n    if ns.MigrateCues then"


def memory_fold_long_used(copy):
    """F10 (repair 1; the review's proof that the first fold lost memory_report's long-used install): a fault that shows only on an install
    with saved drafts (XayaUI_Rules/RuleDefaults.lua InitRules: 'if CoreS.drafts and #CoreS.drafts > 0 then ns.rules = {} end') made
    memory_report fail 'realistic: no rules loaded'. Put into the copy, fix_r7_relocate must fail L1's C1 too; unbroken it passes."""
    p = os.path.join(copy, "XayaUI_Rules", "RuleDefaults.lua")
    s = open(p, encoding="utf-8").read()
    if s.count(DRAFTS_ANCHOR) != 1:
        check("F10 the place in RuleDefaults.lua InitRules is found (MISSING INPUT: the anchor %r)" % DRAFTS_ANCHOR[:40], False)
        return
    with open(p, "w", encoding="utf-8") as fh:
        fh.write(s.replace(DRAFTS_ANCHOR, "    ns.rules = CoreS.rules\n    if CoreS.drafts and #CoreS.drafts > 0 then ns.rules = {} end\n"
                                          "    if ns.MigrateCues then"))
    test = os.path.join(copy, "tests", "fix_r7_relocate_run.py")
    r = subprocess.run([sys.executable, test], capture_output=True, text=True, cwd=copy)
    last = (r.stdout.strip().splitlines() or [""])[-1]
    hit = [l for l in r.stdout.splitlines() if l.startswith("FAIL ") and "the realistic profile's rules are loaded at login" in l]
    check("F10 rules not loaded when drafts are saved (memory_report: 'FAIL realistic: no rules loaded'): fix_r7_relocate FAILS L1 C1 "
          "(exit %s, %r)" % (r.returncode, last), r.returncode != 0 and bool(hit), hit or last)
    with open(p, "w", encoding="utf-8") as fh:
        fh.write(s)
    r = subprocess.run([sys.executable, test], capture_output=True, text=True, cwd=copy)
    last = (r.stdout.strip().splitlines() or [""])[-1]
    check("F11 ... unbroken, fix_r7_relocate passes in the same copy (%r)" % last, r.returncode == 0 and re.search(r"\d+ checks, 0 failed", last) is not None)


def harness_checks():
    """R: the harness reads each session's error record; its count line; the report's shape."""
    import run as H
    folders = H.find_addons()
    seeded = {"XayaUI": {"CueRulesDB": {"errorLog": [{"code": "XUI-E011", "kind": "error", "msg": "XayaUI engine: seeded for the test",
                                                      "n": 4, "first": 77, "last": 78}]}}}
    res = H.run_combo(folders, {"XayaUI"}, seeded, "XUI_TEST")
    # (the seeded entry is in this process's runtimes on purpose: declared for tests/run_all.py, SD-138 M1)
    print("EXPECT_ERRORS XUI-E011 4")
    hits = [f for f in res["fails"] if "error record" in f and "XUI-E011" in f]
    check("R1 the harness FAILS a run whose error record holds an entry (XUI-E011 x4), once though three sessions carried it",
          len(hits) == 1 and "x4" in hits[0], hits or res["fails"][:3])
    res = H.run_combo(folders, {"XayaUI"}, None, "XUI_TEST")
    check("R2 control: a fresh install of core alone has no error-record finding",
          not [f for f in res["fails"] if "error record" in f], res["fails"][:3])
    st, why, last, out = verdict(os.path.join(HERE, "harness", "run.py"), limit=600, args=("--fresh-only", "--only", "--report",
                                                                                          tempfile.mkdtemp(prefix="xui-m1-rep-")))
    n = R.checked_count(last) if NEW else (1 if COUNT_FALLBACK.search(last) else None)
    check("R3 the harness's last line says how many runs it checked (%r) and the suite judges it ok" % last, st == "ok" and bool(n),
          "%s %s" % (st, text(why)))
    if NEW:
        import io, contextlib
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            R.show("a_run.py", "ok", "3 checks, 0 failed", [])
            R.show("b_run.py", "FAIL", "FAILS: 0", [("NO COUNT LINE", "x")])
            R.show("c_run.py", "HUNG", "", [("HUNG", "y")])
        lines = buf.getvalue().splitlines()
        check("R4 the report keeps its shape: 'ok   <test>  <last>', 'FAIL <test>  <last>', 'HUNG <test>', reasons on '     M1 ' lines",
              lines[0] == "ok   a_run.py  3 checks, 0 failed" and lines[1] == "FAIL b_run.py  FAILS: 0" and lines[2] == "     M1 NO COUNT LINE: x"
              and lines[3].startswith("HUNG c_run.py") and lines[4] == "     M1 HUNG: y", lines)
    else:
        check("R4 the report keeps its shape and has a HUNG state", False, "no show()")


def grammar():
    """C: the count grammar on the count lines the suite prints today; line_passes unchanged."""
    if not NEW:
        check("C1 the suite reads how many things a test checked from its last line", False, "no checked_count()")
        return
    cases = [("58 checks, 0 failed", 58), ("18 checks, 0 failed, 0 Lua errors", 18), ("8 checks, 2 deliberate breaks  FAILS: 0", 8),
             ("4 passed, 0 failed", 4), ("all 12 passed", 12), ("25204 texts checked, 0 British spellings, 0 other problems  FAILS: 0", 25204),
             ("83 Lua files checked  FAILS: 0", 83), ("harness: 31 runs checked (93 sessions), 0 failure(s)  FAILS: 0", 31),
             ("1 checks, 1 failed", 1), ("0 checks, 0 failed", 0),
             ("FAILS: 0", None), ("ALL PASSED", None), ("ALL CHECKS PASS", None), ("gate_mouse: 0 violation(s), 4 warning(s)  FAILS: 0", None),
             ("closure scan: 0 site(s) making a new function per timer call in 83 file(s)  FAILS: 0", None), ("2 failed", None), ("", None)]
    bad = [(l, want, R.checked_count(l)) for l, want in cases if R.checked_count(l) != want]
    check("C1 the count grammar reads the %d count line formats as stated (None: no count of checks)" % len(cases), not bad, bad)
    check("C2 line_passes is unchanged (tests/run_all_markers_run.py holds it)", R.line_passes("18 checks, 0 failed") and
          not R.line_passes("18 checks, 10 failed") and not R.line_passes("FAILS: 03") and R.line_passes("ALL CHECKS PASS"))
    # (round 11 repair) the R11A concern on COUNT_PATTERNS, decided as a technical choice (SD-145): the tests print a count of checks; the
    # grammar is not widened. Each line below must read as stated: the old lines and counts of something else read None, the new ones
    # read the checks they count.
    pin = [("closure scan: 0 site(s) making a new function per timer call in 83 file(s)  FAILS: 0", None), ("0 failed", None),
           ("10 failed", None), ("scanned 83 file(s)  FAILS: 0", None), ("closure scan: 0 site(s) in 0 file(s)  FAILS: 0", None),
           ("12 file(s) skipped  FAILS: 0", None), ("244 hover texts, 0 longer  FAILS: 0", None), ("78 field labels  FAILS: 0", None),
           ("gate_keyboard: 0 violation(s), 0 warning(s)  FAILS: 0", None),
           ("closure scan: 0 site(s) making a new function per timer call in 83 file(s); 108 checks, 0 failed  FAILS: 0", 108),
           ("closure scan: 0 site(s) making a new function per timer call in 0 file(s); 25 checks, 1 failed  FAILS: 1", 25),
           ("10 checks, 0 failed", 10), ("245 checks, 0 failed (the scan, and 244 hover texts)", 245),
           ("gate_mouse: 16 checks, 0 failed (variant default: 8; variant debug: 8; 0 violation(s), 4 warning(s))  FAILS: 0", 16)]
    bad = [(l, want, R.checked_count(l)) for l, want in pin if R.checked_count(l) != want]
    check("C3 COUNT_PATTERNS is not widened: a count of files, sites, texts or failures alone is no count of checks (the old closure-scan "
          "and tooltip_parity lines stay NO COUNT LINE); the tests' new lines read the checks they made", not bad, bad)



# (round 11 repair) N: the tests the R11A final run read as NO COUNT LINE (gate_performance has its own checks in fix_r8_gate_probe)
LINE_TESTS = ("art_picker art_rows aspect aura_display aura_gaps build_content build_set_auras charges_combat compact_button_width "
              "count_gcd cue_volume devassist_rename engine_garbage_229 engine_garbage engine_text error_handler_cost externals_in_combat "
              "fix_r5_gate4 fix_r6_routing_replay flat_buttons flex_dropdown group_anchors layout_parity load_alloc load_class load_first "
              "load_ids log_gate options_click_cost options_open_cost rule_click_cost sidebar_name_room switch_reload timing tooltip_parity "
              "tracked_buff ui_gutter debug_record").split()
SCAN_TESTS = ("fix_r10_closure_scan", "hover_brevity", "trigger_labels")
# group C: the errors each test raises on purpose (the line that raises each is quoted beside its EXPECT_ERRORS line in the test)
DECLARED = {"console_commands": {"XUI-E001": 2}, "devassist_debug_tools": {"XUI-E001": 50}, "fix_r7_debug_tools": {"XUI-E001": 1},
            "key_propagation": {"XUI-E001": 1}, "rule_editor_load": {"XUI-E001": 18, "XUI-E016": 1}, "fix_r6_backups": {"XUI-E018": 1},
            "fix_r8_carryovers": {"XUI-E018": 2}, "fix_r6_deadlogs": {"XUI-E010": 3, "XUI-W001": 1}, "debug_record": {"XUI-W001": 1},
            "settings_migration": {"XUI-W006": 1}, "audit_core": {"XUI-W008": 1, "XUI-E002": 1}}
CHECK_LINE = re.compile(r"(PASS |FAIL |ok    |ok  |FAIL  |FAIL:)")
FAIL_LINE = re.compile(r"(FAIL |FAIL  |FAIL:)")
RECORD_CODES = ("ERROR RECORD", "EXPECTED ERROR NOT SEEN")


def scan_want(name, out):
    """N2: how many checks a scan made, from its own report lines (and, for the field labels, from Triggers.lua itself)."""
    if name == "fix_r10_closure_scan":
        a = re.search(r"scanner self-check: (\d+) snippet", out)
        b = re.search(r"files scanned: (\d+)", out)
        return int(a.group(1)) + 2 + int(b.group(1)) if a and b else None
    if name == "hover_brevity":
        a = re.search(r"the scan found the hover texts \((\d+)\)", out)
        return 1 + int(a.group(1)) if a else None
    src = open(os.path.join(ROOT, "XayaUI_Rules", "Triggers.lua"), encoding="utf-8").read()
    n = len(re.findall(r'\{\s*key\s*=\s*"\w+",\s*kind\s*=\s*"\w+"[^\n]*?label\s*=\s*"', src))
    return n or None


def run_many(names):
    """Each test under the suite's guard (4 at a time: separate processes), {name: (state, reasons, last line, stdout)}."""
    def one(n):
        return n, verdict(os.path.join(HERE, n + "_run.py"), limit=600)
    with concurrent.futures.ThreadPoolExecutor(4) as ex:
        return dict(ex.map(one, names))


def count_lines():
    """N1-N3: the count lines and the declared errors, read from each test's own run under the guard."""
    got = run_many(sorted(set(LINE_TESTS) | set(SCAN_TESTS) | set(DECLARED)))
    bad1 = []
    for n in LINE_TESTS:
        st, why, last, out = got[n]
        m = re.search(r"\b(\d+) checks?, (\d+) failed\b", last)
        lines = out.splitlines()
        nl = sum(1 for l in lines if CHECK_LINE.match(l))
        fl = sum(1 for l in lines if FAIL_LINE.match(l))
        if not m or R.checked_count(last) != nl or int(m.group(2)) != fl or nl == 0:
            bad1.append("%s: last line %r; printed %d check lines, %d FAIL" % (n, last[:100], nl, fl))
    check("N1 the %d tests that print one line per check end with 'N checks, M failed': N = the check lines they printed, M = the FAIL "
          "lines" % len(LINE_TESTS), not bad1, "; ".join(bad1))
    bad2 = []
    for n in SCAN_TESTS:
        st, why, last, out = got[n]
        k = R.checked_count(last)
        want = scan_want(n, out)
        if not k or k != want or "NO COUNT LINE" in codes(why) or not re.search(r"\b\d+ failed\b", last):
            bad2.append("%s: %r, want %s checks (%s)" % (n, last[:140], want, text(why)))
    check("N2 the scans end with a count of the items they checked and of those that failed: the closure scan its self-check snippets, "
          "the mutation, files found and each file scanned; hover_brevity the scan and each hover text; trigger_labels each field label "
          "(counted again here from XayaUI_Rules/Triggers.lua)", not bad2, "; ".join(bad2))
    bad3 = []
    for n, want in sorted(DECLARED.items()):
        st, why, last, out = got[n]
        rec = [(c, t) for c, t in why if c in RECORD_CODES]
        said = {}
        for l in out.splitlines():
            m = R.EXPECT_ERRORS.match(l) if NEW else None
            if m:
                said["XUI-" + m.group(1)] = said.get("XUI-" + m.group(1), 0) + int(m.group(2))
        if rec or said != want:
            bad3.append("%s: declared %s, want %s; %s" % (n, said, want, text(rec)))
    check("N3 the %d tests that raise errors on purpose declare exactly those (EXPECT_ERRORS) and the guard finds no other record entry"
          % len(DECLARED), not bad3, "; ".join(bad3))


def gate_count_lines():
    """N4: gate_mouse and gate_keyboard's last line, on synthetic results (GC.result replaced; the real plays take 15 minutes each)."""
    try:
        import gate_common as GC
        import gate_mouse_run as GM
        import gate_keyboard_run as GK
    except Exception as e:   # (a gate that does not import is a failure, said as one)
        check("N4 the gates import", False, e)
        return

    def play(mod, data, quiet_integrity=False):
        saved = (GC.result, GC.integrity)
        GC.result = lambda variant="default", *a, **k: (dict(data, variant=variant), 0, True)
        if quiet_integrity:
            GC.integrity = lambda d, rep: None   # (a synthetic result cannot hold the whole scenario; the scenario check is the gate's)
        buf = io.StringIO()
        try:
            with contextlib.redirect_stdout(buf):
                rc = mod.main()
        finally:
            GC.result, GC.integrity = saved
        return rc, (buf.getvalue().strip().splitlines() or [""])[-1]

    variants = 2 if os.path.isdir(os.path.join(GC.ROOT, GC.DEBUG_ADDON)) else 1
    cp = lambda **k: dict({"label": "x", "combat": False}, **k)   # noqa: E731
    mm = {"button": True, "opened": True, "closedByClick": True, "escCloses": True, "closedAtEnd": True}
    keys = [{"key": k, "reached": True} for k in ("PRINTSCREEN", "W", "SPACE")]
    clean = {"checkpoints": [cp(label="a", keys=keys), cp(label="b", combat=True, keys=keys)], "minimap": mm, "hoverList": []}
    clicks = dict(clean, checkpoints=[cp(label="a", keys=keys, mouse=[{"by": "X.lua:1", "where": "X.lua:1", "w": 10, "h": 10}]),
                                      cp(label="b", combat=True, keys=keys)])
    held = dict(clean, checkpoints=[cp(label="a", keys=[{"key": "W", "reached": False, "by": "X.lua:2"}]), cp(label="b", combat=True, keys=keys)])
    for mod, broken, what in ((GM, clicks, "1 no shown XayaUI frame takes mouse clicks"), (GK, held, "keys were pressed, and PRINTSCREEN")):
        src = open(mod.__file__, encoding="utf-8").read()
        body = src[src.index("\ndef judge("):src.index("\ndef main(")]
        named = len(re.findall(r"\n\s*begin\(rep, ", body))
        rc, last = play(mod, clean, True)
        want = "%s: %d checks, 0 failed (" % (mod.GATE, named * variants)
        check("N4 %s on a clean result: the last line reads %r and passes run_all's guard (named checks counted from judge's source: %d "
              "per variant)" % (mod.GATE, want + "...", named), named >= 5 and rc == 0 and last.startswith(want) and
              R.checked_count(last) == named * variants and R.line_passes(last), last)
        rc, last = play(mod, broken, True)
        check("N4 %s: one violation names its check as failed in each variant and the line does not pass" % mod.GATE,
              rc == 1 and ("%d failed" % variants) in last and last.count(what) == variants and not R.line_passes(last)
              and R.checked_count(last) == named * variants, last)


def main():
    base = "/dev/shm" if os.path.isdir("/dev/shm") and os.access("/dev/shm", os.W_OK) else None
    work = tempfile.mkdtemp(prefix="xui-m1-", dir=base)
    try:
        syn = os.path.join(work, "syn")
        os.makedirs(syn)
        synthetic(syn)
        tally_sessions(syn)
        grammar()
        count_lines()
        gate_count_lines()
        memory_fold()
        harness_checks()
        copy = copy_repo(os.path.join(work, "copy"))
        no_git(copy)
        exit_codes(copy)
        memory_fold_long_used(copy)
        exact_case(copy)
    except Exception as e:   # (a crash is a failure, said as one)
        import traceback
        traceback.print_exc()
        check("the test ran to its end", False, "%s: %s" % (type(e).__name__, str(e)[:300]))
    finally:
        shutil.rmtree(work, ignore_errors=True)
    print("%d checks, %d failed" % (checks, fails))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
