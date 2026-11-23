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
                   EXPECTED ERROR NOT SEEN). Counting: one entry per code and message with a repeat count n (DebugRecord.lua),
                   and each occurrence counts once, in the runtime where it happened. A runtime made with the stand-in's loader
                   (tests/harness/loader.lua) has the loader's note of every entry it handed over from saved data and its count then
                   (Lua registry "XayaUI.harness.loadedErrorLog"): such a runtime counts what it added (n minus the noted count), so
                   an entry carried from one session into the next counts once and two separate sessions add up even when they
                   started in the same second (round 11 repair 2; before, entries were merged on code, message and first time, and
                   the stand-in's time() is the host's clock: fix_r10_display counted "W002 x1" for five sessions). An entry the test
                   seeded in saved data (noted, but made by no runtime of the test) counts once, at its seeded count. A runtime
                   without the loader (a test's own bare LuaRuntime) keeps the old rule: same code, message and first time count
                   once, at the highest n.
                   THE LIMIT of this count (round 11 repair, the R11A repair-2 review): a runtime is read ONCE, when it is freed
                   (or at the exit), and what is read is the last session's CueRulesDB. So several stand-in loader sessions made in
                   ONE runtime, each handing its saved data to the next, would be read as the last one only: the earlier sessions'
                   occurrences are subtracted as "carried" but never read, which undercounts and could hide an error. No test does
                   this today (every loader is made in a fresh runtime). The guard watches for it: in each runtime it counts the
                   loader sessions made there (the stand-in's loader is always made through dofile(".../harness/loader.lua")(W,
                   opts); the guard's dofile counts each call of the function that returns), and a runtime with more than one is
                   GUARD BLIND, never a pass
                   (tests/fix_r11_honest_result_run.py T2-T4; T5 checks that every place a test makes the loader goes through
                   that dofile). A loader made any other way (loadfile, loadstring) would not be counted: T5 fails on such a site.
  LINE HOOK        the stand-in's line hook or key scan (tests/harness/loader.lua, round 11b: a misuse of a hidden value that Lua 5.1
                   cannot raise, such as '==' against a plain value of the same type) found a misuse the test did not declare. Every
                   runtime's findings are read at its end, per site (rule and place, from S.lineHook.sites; the count is never capped),
                   whether or not the addon's own pcall swallowed the raise: such a raise reaches neither the world's error list nor the
                   error record, so ERROR RECORD alone would pass it (round 11b repair 1: XayaUI_Rules/Triggers.lua TDList in
                   fix_r6_aura_routing). A test that misuses a hidden value on purpose declares each site on a line of its output:
                   "EXPECT_LINEHOOK <rule> <site> <n>", for example "EXPECT_LINEHOOK eq XayaUI_LineProbe/probe.lua:9 1"; n is exact
                   and a declared finding that did not happen fails (EXPECTED LINE HOOK FINDING NOT SEEN). Rules: eq, neg, bool, key
                   (site "<addon>/<file>:<line>") and keyscan (site "<addon>"). A fault of the line hook itself (a bug in the stand-in,
                   so lines went unchecked) is LINE HOOK FAULT, never a pass; a test that causes one on purpose (to check that a fault
                   never reaches the addon) declares the exact number: "EXPECT_LINEHOOK_FAULTS <n>".
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
EXPECT_LINEHOOK = re.compile(r"^\s*EXPECT_LINEHOOK\s+(eq|neg|bool|key|keyscan)\s+(\S+)\s+(\d+)\s*$")
EXPECT_LINEHOOK_FAULTS = re.compile(r"^\s*EXPECT_LINEHOOK_FAULTS\s+(\d+)\s*$")
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
    """{code: occurrences} from the record entries the child read (see ERROR RECORD in the module docstring). An entry with "carried"
    (its runtime had the stand-in's loader; the count the loader handed over from saved data, 0 when it came from none) adds what its
    runtime added; a noted entry that no runtime of the test made (seeded in saved data) adds its seeded count once. An entry without it
    (a runtime without the loader): per (code, message, first time) the highest n, summed per code over the rest."""
    out, made, seeded, legacy = {}, set(), {}, {}
    for e in entries:
        code, key, n = e.get("code"), (e.get("code"), e.get("msg"), e.get("first")), int(e.get("n") or 1)
        carried = e.get("carried")
        if carried is None:
            legacy[key] = max(legacy.get(key, 0), n)
            continue
        out[code] = out.get(code, 0) + max(n - carried, 0)
        if carried == 0:
            made.add(key)
        else:
            seeded[key] = min(seeded.get(key, carried), carried)
    for key, n in seeded.items():
        if key not in made:   # (noted, but made by no runtime of this test: seeded in saved data, counted once at its seeded count)
            out[key[0]] = out.get(key[0], 0) + n
    for key, n in legacy.items():
        out[key[0]] = out.get(key[0], 0) + n
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
    # (round 11b repair 1) the line hook's findings per site, and its own faults (LINE HOOK in the module docstring)
    lh_declared, lh_seen, lh_text = {}, {}, {}
    for l in lines:
        m = EXPECT_LINEHOOK.match(l)
        if m:
            key = (m.group(1), m.group(2))
            lh_declared[key] = lh_declared.get(key, 0) + int(m.group(3))
    for f in report.get("lineHook", []):
        key = (f.get("rule"), f.get("site"))
        lh_seen[key] = lh_seen.get(key, 0) + int(f.get("n") or 0)
        lh_text.setdefault(key, f.get("text"))
    for key in sorted(set(lh_seen) | set(lh_declared)):
        got, want = lh_seen.get(key, 0), lh_declared.get(key, 0)
        if got == want:
            continue
        if want == 0:
            why.append(("LINE HOOK", "%s at %s x%d not declared (EXPECT_LINEHOOK %s %s %d): %s"
                        % (key[0], key[1], got, key[0], key[1], got, str(lh_text.get(key))[:200])))
        elif got == 0:
            why.append(("EXPECTED LINE HOOK FINDING NOT SEEN", "declared EXPECT_LINEHOOK %s %s %d, the line hook found none" % (key[0], key[1], want)))
        else:
            why.append(("LINE HOOK", "%s at %s x%d, declared %d: %s" % (key[0], key[1], got, want, str(lh_text.get(key))[:200])))
    if report.get("lineHookDropped"):
        why.append(("LINE HOOK", "the line hook found misuses at %d more sites than it keeps (200)" % report["lineHookDropped"]))
    faults_declared = sum(int(m.group(1)) for m in (EXPECT_LINEHOOK_FAULTS.match(l) for l in lines) if m)
    faults_seen = int(report.get("lineHookFaultCount") or 0)
    if faults_seen != faults_declared:
        if faults_seen == 0:
            why.append(("EXPECTED LINE HOOK FAULT NOT SEEN", "declared EXPECT_LINEHOOK_FAULTS %d, the line hook had none" % faults_declared))
        else:
            for x in report.get("lineHookFaults", []):
                why.append(("LINE HOOK FAULT", x + ("" if not faults_declared else " (declared EXPECT_LINEHOOK_FAULTS %d)" % faults_declared)))
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
# (round 11 repair) the guard's count of stand-in loader sessions per runtime (see THE LIMIT under ERROR RECORD): installed in every
# runtime the child registers, before the test runs any Lua. dofile is wrapped so that the function tests/harness/loader.lua returns
# counts each call (each call is one session). Kept in the Lua registry (no global the addons see; dofile itself stays the same name).
# A runtime without the debug library or dofile is not counted ("-").
SESSIONS_KEY = "XayaUI.runall.loaderSessions"
# (round 11b final fix) the guard's own reader of the runtime's record (HARVEST_LUA, below) is made and kept in the Lua registry before the
# test runs any Lua, and it captures every builtin it calls (type, tostring, rawget, string.gsub ...) as its own locals then. A test that
# breaks a builtin on purpose (fix_r11_secret T1 kills the installed type()) no longer blinds the guard: before this, the harvest called
# the test's type() when the runtime was freed and the group failed as GUARD BLIND. The dofile counter below captures its builtins the same
# way. Held in the registry, not on the Python side: a Python handle to a Lua function keeps its runtime alive (lupa), and a runtime
# that is freed only by the cyclic collector would hold its whole Lua state (megabytes) for an unknown time.
HARVEST_KEY = "XayaUI.runall.harvest"
SESSIONS_LUA = r"""function(harvester)
  local dbg = rawget(_G, "debug")
  local getreg = type(dbg) == "table" and rawget(dbg, "getregistry") or nil
  if type(getreg) ~= "function" then return false end
  local reg = getreg()
  if type(harvester) == "function" then rawset(reg, "__HKEY__", harvester) end
  local df = rawget(_G, "dofile")
  if type(df) ~= "function" then return false end
  local type, select, rawget, rawset, match, KEY = type, select, rawget, rawset, string.match, "__KEY__"
  rawset(reg, KEY, 0)
  local function counted(f)
    return function(...) rawset(reg, KEY, (rawget(reg, KEY) or 0) + 1); return f(...) end
  end
  local function pass(path, ...)
    if type(path) == "string" and match(path, "[/\\]loader%.lua$") and type((...)) == "function" then return counted((...)), select(2, ...) end
    return ...
  end
  rawset(_G, "dofile", function(path) return pass(path, df(path)) end)
  return true
end""".replace("__KEY__", SESSIONS_KEY).replace("__HKEY__", HARVEST_KEY)
# the call that runs the kept reader: it touches only the global 'debug' table, its getregistry and the registry (no metatable); nil when
# the runtime has no kept reader (then the reader is made now, from whatever builtins the runtime has left)
HARVEST_CALL_LUA = r"""function()
  local reg = debug.getregistry()
  local h = reg["__HKEY__"]
  if h then return h() end
  return nil
end""".replace("__HKEY__", HARVEST_KEY)
# makes the reader: reads CueRulesDB.errorLog with rawget only (the stand-in's _G reports every unknown global it is asked for:
# tests/harness/world.lua). Its first row is "#sessions\t<n>": the loader sessions counted in this runtime ("-": not counted)
HARVEST_LUA = r"""function()
  local type, tostring, tonumber, rawget, G = type, tostring, tonumber, rawget, _G
  local gsub, sub, concat = string.gsub, string.sub, table.concat
  local dbg0 = rawget(G, "debug")
  local getreg = type(dbg0) == "table" and rawget(dbg0, "getregistry") or nil
  if type(getreg) ~= "function" then getreg = nil end
  local function flat(v, n) return sub((gsub(tostring(v), "[\t\n\r]", " ")), 1, n) end
  return function()
    local reg0 = getreg and getreg() or nil
    local sessions = "#sessions\t" .. tostring(type(reg0) == "table" and rawget(reg0, "__KEY__") or "-")
    local out = { sessions }
    -- (round 11b repair 1) the stand-in line hook's findings per site and its own faults (tests/harness/loader.lua; one per Lua state,
    -- kept in the registry): "#linehook\t<rule>\t<site>\t<n>\t<message>", "#lhdropped\t<n>", "#lhfault\t<n>\t<first faults>"
    local LH = type(reg0) == "table" and rawget(reg0, "XayaUI.harness.lineHook") or nil
    if type(LH) == "table" then
      local sites = rawget(LH, "sites")
      if type(sites) == "table" then
        for i = 1, 200 do
          local x = rawget(sites, i)
          if x == nil then break end
          if type(x) == "table" then
            out[#out + 1] = "#linehook\t" .. tostring(rawget(x, "rule")) .. "\t" .. tostring(rawget(x, "site")) .. "\t" .. tostring(rawget(x, "n"))
              .. "\t" .. flat(rawget(x, "text"), 300)
          end
        end
      end
      local st = rawget(LH, "stats")
      local dropped = type(st) == "table" and tonumber(rawget(st, "sitesDropped")) or 0
      if dropped > 0 then out[#out + 1] = "#lhdropped\t" .. dropped end
      local nf = type(st) == "table" and tonumber(rawget(st, "faults")) or 0
      if nf > 0 then
        local f, first = rawget(LH, "faults"), {}
        for i = 1, 3 do local x = type(f) == "table" and rawget(f, i) or nil; if x == nil then break end; first[#first + 1] = tostring(x) end
        out[#out + 1] = "#lhfault\t" .. nf .. "\t" .. flat(concat(first, " | "), 400)
      end
    end
    local db = rawget(G, "CueRulesDB")
    if type(db) ~= "table" then return concat(out, "\n") end
    local log = rawget(db, "errorLog")
    if type(log) ~= "table" then return concat(out, "\n") end
    -- the stand-in loader's note of what came from saved data (tests/harness/loader.lua); "-": this runtime had no loader
    local note = type(reg0) == "table" and rawget(reg0, "XayaUI.harness.loadedErrorLog") or nil
    local i = 1
    while i <= 200 do
      local e = rawget(log, i)
      if e == nil then break end
      if type(e) == "table" then
        out[#out + 1] = tostring(rawget(e, "code")) .. "\t" .. tostring(rawget(e, "kind")) .. "\t" .. tostring(rawget(e, "n")) .. "\t" ..
          tostring(rawget(e, "first")) .. "\t" .. (type(note) == "table" and tostring(rawget(note, e) or 0) or "-") .. "\t" .. flat(rawget(e, "msg"), 300)
      end
      i = i + 1
    end
    return concat(out, "\n")
  end
end""".replace("__KEY__", SESSIONS_KEY)
NO_REPO_GIT = {"init", "clone", "version", "help", "--version", "--help", "-h"}


def _child(rpath, test, argv):
    import atexit, runpy, shlex, weakref
    state = {"entries": [], "runtimes": 0, "missing": [], "guardErrors": [], "complete": False,
             "lineHook": [], "lineHookFaults": [], "lineHookFaultCount": 0, "lineHookDropped": 0}
    seen_rt = weakref.WeakSet()

    def harvest(rt):
        if getattr(rt, "_xui_m1_read", False):
            return
        try:
            rt._xui_m1_read = True
            try:   # (the reader kept before the test ran: its builtins are the runtime's own, whatever the test did to them)
                text = rt.eval(HARVEST_CALL_LUA)()
            except Exception:
                text = None
            if text is None:   # (no kept reader: a runtime the guard could not prepare)
                text = rt.eval(HARVEST_LUA)()()
        except Exception as e:   # (a runtime closed or broken by the test: its record cannot be read)
            state["guardErrors"].append("a Lua runtime's error record could not be read: %s" % str(e)[:200])
            return
        if isinstance(text, bytes):   # (a runtime made with encoding=None returns bytes: read them as text, not as their repr)
            text = text.decode("utf-8", "replace")
        for row in str(text or "").split("\n"):
            if not row:
                continue
            if row.startswith("#sessions\t"):
                try:
                    k = int(float(row.split("\t", 1)[1]))
                except ValueError:
                    k = None   # ("-": this runtime's sessions were not counted)
                if k is not None and k > 1:
                    state["guardErrors"].append(
                        "one Lua runtime made %d stand-in loader sessions: its error record is read once, when the runtime is freed, "
                        "so the earlier sessions' entries could not be counted (make each session in a fresh runtime)" % k)
                continue
            if row.startswith("#linehook\t"):   # (round 11b repair 1) one line-hook site of this runtime
                _, rule, site, n, text = (row.split("\t", 4) + ["", "", "", "", ""])[:5]
                try:
                    n = int(float(n))
                except ValueError:
                    n = 1
                state["lineHook"].append({"rule": rule, "site": site, "n": n, "text": text})
                continue
            if row.startswith("#lhdropped\t"):
                try:
                    state["lineHookDropped"] += int(float(row.split("\t", 1)[1]))
                except ValueError:
                    state["lineHookDropped"] += 1
                continue
            if row.startswith("#lhfault\t"):
                _, nf, text = (row.split("\t", 2) + ["", "", ""])[:3]
                try:
                    state["lineHookFaultCount"] += int(float(nf))
                except ValueError:
                    state["lineHookFaultCount"] += 1
                state["lineHookFaults"].append("the stand-in's line hook had %s fault(s) of its own (a bug in tests/harness/loader.lua, so lines "
                                               "went unchecked): %s" % (nf, text[:300]))
                continue
            code, kind, n, first, carried, msg = (row.split("\t", 5) + ["", "", "", "", "", ""])[:6]
            try:
                n = int(float(n))
            except ValueError:
                n = 1
            try:
                carried = None if carried == "-" else int(float(carried))
            except ValueError:
                carried = None
            state["entries"].append({"code": code, "kind": kind, "n": n, "first": first, "carried": carried, "msg": msg})

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
                try:   # (round 11 repair) count the stand-in loader sessions made in this runtime (SESSIONS_LUA)
                    self.eval(SESSIONS_LUA)(self.eval(HARVEST_LUA)())
                except Exception as e:   # (a runtime the guard cannot prepare: said, not hidden)
                    state["guardErrors"].append("a Lua runtime could not be prepared to count its loader sessions: %s" % str(e)[:200])

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
