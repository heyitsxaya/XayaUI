#!/usr/bin/env python3
"""Round 9 gate fixes, proved on the gate's own scenario (REQUEST-LOG A23 SD-77, SD-79, SD-80; round 9 gate items 1, 5 and 7;
tests/gate_common.py, tests/gate_performance_run.py).

Her answers (verbatim, REQUEST-LOG A23): SD-80 "Fix it (Recommended)" (measure cost with call counting off; count calls in a separate
play); SD-77 "Route + narrow (Recommended)" (a narrowed re-check must cover combat-only drawing, boss pulls and combat end); SD-79
"≤30/s, stop if idle (Recommended)" (the gate gets an effects scenario).

What the gate must do now, checked on this checkout's addons:
  hook     (SD-80) the play the gates read counts no call: its Lua instructions, second by second in every fight and combat end, equal
           those of a play in which no call hook can exist at all (every debug.sethook mask stripped of "c"), the call-counting window
           (fight frames 31-45) included; the call counts the gate judges (P3 per dispatch, P6 per cycle) come from the tree play and are
           there (before round 9 the tree play's hook read the caller one level too high and counted nothing);
  scenario (SD-77) every fight has a boss pull and the boss down; each combat end and the second after it are a measured segment of their
           own; the frames right after combat start, the boss pull, the boss down and combat end are each kept and judged against the
           per-event cap; the draw check ran after every load-fact change of the three cycles, the full re-check it compares with ran,
           and the rules that test the narrowing changed at their moments (target debuffs that must be absent, out-of-combat opacity,
           boss rules);
  draw     (SD-77) on this engine nothing differs from a full re-check; a mutant engine whose narrowed re-check leaves out the displays
           with an out-of-combat opacity and the re-read of what combat restricts FAILs the gate on what is drawn (the displays named);
           (round 11b final fix) the absent target debuffs are tested in the draw play's fight out of the key (readable data; inside the
           key they are hidden at every moment); a cooldown display whose own end fell in the check's quiet frames is listed, not counted
           (its wake is still on the way), and a mutant engine whose hidden cooldown ends wake nothing still FAILs the gate;
  effects  (SD-79) the effects part runs every effect display's loop at 144 frames a second, per display;
  memory   the growth per cycle is read in the memory play (the addons' own) and reported next to the measured play's (with the gate's
           records); a mutant addon that keeps 32 KB more on every combat end makes the growth WARNING name the addons' own growth.
Mutants are this checkout's addon folders copied to the temp folder with only that change, played in this checkout's gate scenario.
Run: python3 tests/fix_r9_gate_scenario_run.py   (Lua 5.1 via lupa; the gate's result is read from its cache when there; the reference
play and the mutants about 1-2 minutes each)"""
import concurrent.futures, contextlib, io, json, os, re, shutil, signal, subprocess, sys, tempfile, threading, traceback
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "harness"))
import gate_common as GC          # noqa: E402
import gate_performance_run as GP  # noqa: E402

NOHOOK_PRELUDE = r'''
local _sh = debug.sethook
debug.sethook = function(f, m, c)
  if f == nil then return _sh() end
  if type(m) == "string" then m = (m:gsub("[cr]", "")) end
  return _sh(f, m, c)
end
'''
TOL = 0.01
FIGHTS = ("fight 1", "fight 2", "fight 3")
ENDS = ("end 1", "end 2", "end 3")
DRAW_LABELS = ("mounted", "dismounted", "group joined", "target picked", "combat start", "boss pull", "boss down", "combat end",
               "group left, target dropped")
# (round 11b final fix) the draw play's fight out of the key (readable data, a target selected): the only moments that change the absent
# target debuffs (inside the key they are hidden at every moment)
DRAW_OUT_LABELS = ("target picked, out of the key", "combat start, out of the key", "combat end, out of the key")
# (round 11b final fix) a mutant whose hidden-cooldown wake never comes (OnCooldownDone wakes nothing): the draw check's late-wake list
# (gate_common.py KF.lateWake: a cooldown that ended at most one pace gap and two frames before the read) must not hide it
MUT_WAKE = ("    for i = #l, 1, -1 do\n        local rule = l[i]; l[i] = nil\n        local rt = ns.runtime[rule]\n"
            "        if rt and rt.cdPoll then wakeAt[rule] = now; any = true end\n")
MUT_OOC = "    if combat then NW.Mark(NW.ooc, m) end\n"
MUT_RESTRICT = "    if restrict then\n"
LEAK_LUA = r'''
-- (tests/fix_r9_gate_scenario_run.py mutant) keeps about 32 KB more on every combat end
do
  local keep = {}
  local lf = CreateFrame("Frame")
  lf:RegisterEvent("PLAYER_REGEN_ENABLED")
  lf:SetScript("OnEvent", function() local t = {}; for i = 1, 2000 do t[i] = i end; keep[#keep + 1] = t end)
end
'''


def reference_play(variant="default"):
    """The measured play with no call hook possible (every sethook mask stripped of "c" and "r")."""
    saved = GC.SCENARIO_LUA
    GC.SCENARIO_LUA = NOHOOK_PRELUDE + saved
    try:
        data, _ = GC.run_scenario(perf=True, variant=variant)
    finally:
        GC.SCENARIO_LUA = saved
    return json.loads(json.dumps(data, default=str))


# (round 11) every mutant tree this run makes, removed when it ends (each is about 7.7 MB; before round 11 they stayed in the temp folder,
# one pair per checkout path, and were never removed)
TREES = []
# (round 11) the plays running in their own processes, stopped if this test is stopped
PROCS, PROCS_LOCK = [], threading.Lock()
# (round 11) set when this test is stopped: a mutant tree still being copied in the worker thread stops at its next file, so the copy
# cannot outlive the removal of the trees (seen: two half-copied trees left in the temp folder by a stop during the copy)
STOP = threading.Event()
COPYING = threading.Lock()   # held while a mutant tree is copied


def _copy_file(src, dst):
    if STOP.is_set():
        raise Stopped("stopped while copying a mutant tree")
    return shutil.copy2(src, dst)


def mutant_tree(name, edit):
    # (round 11) a folder of this run's own. Before round 11 the folder was named after the checkout only, so two runs of this test on
    # the same checkout at the same time (a suite while another session ran the same tests) deleted and rewrote each other's mutant
    # addons in the middle of a play.
    with COPYING:
        # (round 11b final fix) a stop that came between two trees makes no new one: the main thread's clean-up takes this lock after the
        # stop and then removes every tree listed, so a tree made after that would be left in the temp folder (fix_r11_harness E1, with
        # the third mutant tree, wakemut)
        if STOP.is_set():
            raise Stopped("stopped before making the %s tree" % name)
        dest = tempfile.mkdtemp(prefix="xui_r9_%s-" % name)
        TREES.append(dest)
        for a in GC.ADDONS + (GC.DEBUG_ADDON,):
            if os.path.isdir(os.path.join(GC.ROOT, a)):
                shutil.copytree(os.path.join(GC.ROOT, a), os.path.join(dest, a), copy_function=_copy_file)
        os.makedirs(os.path.join(dest, "tests"))
        shutil.copytree(os.path.join(HERE, "harness"), os.path.join(dest, "tests", "harness"),
                        ignore=shutil.ignore_patterns("reports", "__pycache__"), copy_function=_copy_file)
        for f in os.listdir(HERE):
            if f.startswith("gate_") and f.endswith(".py"):
                _copy_file(os.path.join(HERE, f), os.path.join(dest, "tests", f))
        # (round 11b final fix) the edit too, under the lock and only while not stopped: an edit that wrote into a tree the clean-up was
        # removing put a file back into it, and the tree was left (fix_r11_harness E1 and E4, wakemut)
        if STOP.is_set():
            raise Stopped("stopped before editing the %s tree" % name)
        ok = edit(dest)
    return dest, ok


def play_in(tree, **kw):
    """One play of this checkout's scenario in a tree copy (its own process: the harness reads the addons next to it)."""
    code = ("import sys, json; sys.path.insert(0, %r); import gate_common as GC; d, s = GC.run_scenario(**%r); "
            "print(json.dumps(d, default=str))" % (os.path.join(tree, "tests"), kw))
    p = subprocess.Popen([sys.executable, "-c", code], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, cwd=tree,
                         env=GC.tree_env(tree))
    with PROCS_LOCK:
        PROCS.append(p)
    try:
        out, err = p.communicate(timeout=1800)
    except subprocess.TimeoutExpired:
        p.kill()
        out, err = p.communicate()
        raise RuntimeError("the play did not end within 1800 s (stopped)")
    if p.returncode != 0:
        raise RuntimeError((err or out)[-400:] or "the play ended with exit code %s and no output" % p.returncode)
    lines = out.strip().splitlines()
    if not lines:
        raise RuntimeError("the play printed nothing (exit code %s)" % p.returncode)
    return json.loads(lines[-1])


def gate_text(data):
    """This checkout's gate_performance judge on one result (default variant only), as text."""
    rep = GC.Report("gate_performance")
    saved = GC.v33_baseline
    GC.v33_baseline = lambda *a, **k: (None, "not played (tests/fix_r9_gate_scenario_run.py)")
    if hasattr(GP, "_BASE"):
        del GP._BASE[:]
    buf = io.StringIO()
    try:
        with contextlib.redirect_stdout(buf):
            GP.judge(data, rep)
            rep.show(data, 0, True)
    finally:
        GC.v33_baseline = saved
        if hasattr(GP, "_BASE"):
            del GP._BASE[:]
    return buf.getvalue()


def secs_of(d, seg, addon="XayaUI_Rules"):
    s = (((d.get("budget") or {}).get(seg) or {}).get("sec") or {}).get(addon)
    if isinstance(s, dict):
        return [s[k] for k in sorted(s, key=lambda x: int(x))]
    return list(s or [])


FAILS, DONE = [], []
# (round 11) one writer at a time, and nothing after the count line: once main() has printed it, a check still running in the worker
# thread prints nothing more (the count line must stay the last line the suite reads). Every line goes to the real standard output
# (OUT), never to the buffer gate_text swaps in for its judge (contextlib.redirect_stdout swaps sys.stdout for every thread).
OUT_LOCK, CLOSED, OUT = threading.Lock(), [], sys.stdout


def _emit(text):
    """One line to the real standard output (called under OUT_LOCK). A reader that is gone (the suite or its time limit stopped) is
    not an error of this test: the line is dropped, so the stop and the clean-up below still run (seen: a write to a closed pipe raised
    BrokenPipeError, which skipped the immediate exit, and the process then waited minutes for the reference play to end)."""
    try:
        print(text, file=OUT)
    except OSError:
        pass


def check(ok, what, detail=""):
    with OUT_LOCK:
        if CLOSED:
            return
        _emit(("ok   " if ok else "FAIL ") + what + (("  [" + detail + "]") if (detail and not ok) else ""))
        DONE.append(what)
        if not ok:
            FAILS.append(what)


def note(text):
    """An information line (not a check), under the same rules as check: one writer at a time, nothing after the count line."""
    with OUT_LOCK:
        if not CLOSED:
            _emit(text)


class Stopped(Exception):
    """The test was stopped from outside (a time limit's SIGTERM, Ctrl+C)."""


def _kill_plays():
    with PROCS_LOCK:
        for p in PROCS:
            if p.poll() is None:
                p.kill()


def _on_term(signum, _frame):
    raise Stopped("stopped by signal %d" % signum)


class _Pool(concurrent.futures.ThreadPoolExecutor):
    """A thread pool that, when the block it serves ends with an error, does not wait for the plays still running (they are stopped,
    and the reference play in this process is abandoned: main() ends the process at once after the count line)."""
    def __exit__(self, et, ev, tb):
        self.shutdown(wait=et is None, cancel_futures=et is not None)
        return False


def _worker(box):
    try:
        _main()
    except BaseException as e:  # noqa: BLE001  (handed to main(), which reports it)
        box.append(e)


def main():
    """(round 11, round 10 final review: inside the suite this test once printed nothing at all) it always ends with its count line.
    Before round 11 every line went to a pipe buffer that only a normal exit wrote out, the gate's own result (GC.result: the scenario
    played, its cache written to the temp folder) came before the first line, and the mutant trees went to a fixed folder per checkout:
    so an error there (a full disk, a cache that cannot be written), a stop from outside (a time limit's SIGTERM) or a second run of
    this test on the same checkout at the same time (deleting this run's mutant addons mid-play) ended it with nothing or no count line
    on its standard output, which is all the suite reads (tests/run_all.py). Now: each line is written out as it is printed; the work
    runs in a worker thread while the main thread only waits, so a SIGTERM or Ctrl+C is handled at once even during a long Lua play;
    an error anywhere or a stop from outside is a named FAIL with its traceback, followed by the count line; the plays running in their
    own processes are stopped and this run's mutant trees removed."""
    OUT.reconfigure(line_buffering=True)
    signal.signal(signal.SIGTERM, _on_term)
    box, err = [], None
    worker = threading.Thread(target=_worker, args=(box,), name="fix_r9_gate_scenario", daemon=True)
    try:
        worker.start()
        while worker.is_alive():
            worker.join(0.25)
        err = box[0] if box else None
    except (Stopped, KeyboardInterrupt) as e:
        err = e
    try:
        if err is not None:
            with OUT_LOCK:
                _emit("".join(traceback.format_exception(type(err), err, err.__traceback__))[-3000:].rstrip())
            check(False, "the test ran to its end", "it stopped at: %s: %s" % (type(err).__name__, str(err)[:300]))
    finally:
        STOP.set()
        _kill_plays()
        if COPYING.acquire(timeout=5):   # (a copy in progress stops at its next file; a play in this process does not write to the trees)
            COPYING.release()
        for t in TREES:
            shutil.rmtree(t, ignore_errors=True)
        if not DONE:
            check(False, "the test checked something (no check ran)")
        with OUT_LOCK:
            _emit("%d checks, %d failed" % (len(DONE), len(FAILS)))
            CLOSED.append(True)
        if err is not None:
            os._exit(1)   # (a thread may still be inside a Lua play: it must not hold the exit back; line buffering wrote every line)
    return 1 if FAILS else 0


def _main():
    data, _, _ = GC.result()
    check(int(data.get("errors") or 0) == 0, "the gate's scenario ran without a Lua error", "; ".join(data.get("errorText") or [])[:300])

    with _Pool(3) as ex:
        f_ref = ex.submit(reference_play)

        def edit_draw(d):
            p = os.path.join(d, "XayaUI_Rules", "Engine.lua")
            s = open(p, encoding="utf-8").read()
            if s.count(MUT_OOC) != 1 or s.count(MUT_RESTRICT) != 1:
                return False
            s = s.replace(MUT_OOC, "    -- (mutant: the out-of-combat opacity displays are not re-checked)\n")
            s = s.replace(MUT_RESTRICT, "    if false then   -- (mutant: what combat restricts is not read again)\n")
            open(p, "w", encoding="utf-8").write(s)
            return True

        def edit_leak(d):
            p = os.path.join(d, "XayaUI_Rules", "Engine.lua")
            with open(p, "a", encoding="utf-8") as fh:
                fh.write(LEAK_LUA)
            return True
        def edit_wake(d):
            p = os.path.join(d, "XayaUI_Rules", "Engine.lua")
            s = open(p, encoding="utf-8").read()
            if s.count(MUT_WAKE) != 1:
                return False
            open(p, "w", encoding="utf-8").write(s.replace(MUT_WAKE, "    for i = #l, 1, -1 do\n        l[i] = nil   -- (mutant: the hidden cooldown's end wakes nothing)\n"))
            return True
        mdraw, mdraw_ok = mutant_tree("drawmut", edit_draw)
        mleak, _ = mutant_tree("leakmut", edit_leak)
        mwake, mwake_ok = mutant_tree("wakemut", edit_wake)
        f_md = ex.submit(play_in, mdraw, perf=False, drawcheck=True) if mdraw_ok else None
        f_ml = ex.submit(play_in, mleak, perf=False, memplay=True)
        f_mw = ex.submit(play_in, mwake, perf=False, drawcheck=True) if mwake_ok else None
        def got(f, what):
            try:
                return f.result() if f else None
            except Exception as e:  # noqa: BLE001  (reported as a failed check)
                check(False, "the %s play ran" % what, str(e)[-300:])
                return None
        ref = got(f_ref, "reference (no call hook)") or {}
        md = got(f_md, "mutant draw")
        ml = got(f_ml, "mutant memory") or {}
        mw = got(f_mw, "mutant wake")

    # ---- hook (SD-80) -----------------------------------------------------------------------------------------------------------
    check(int(ref.get("errors") or 0) == 0, "hook: the reference play (no call hook possible) ran without a Lua error")
    worst, worst_at, n = 0.0, None, 0
    for seg in FIGHTS + ENDS:
        a, b = secs_of(data, seg), secs_of(ref, seg)
        if not a or len(a) != len(b):
            worst, worst_at = 1.0, "%s: %d vs %d seconds" % (seg, len(a), len(b))
            continue
        for i, (x, y) in enumerate(zip(a, b), 1):
            n += 1
            r = abs(x - y) / float(max(y, 1))
            if r > worst:
                worst, worst_at = r, "%s second %d: %d vs %d" % (seg, i, x, y)
    sec2 = [(secs_of(data, s)[1], secs_of(ref, s)[1]) for s in FIGHTS if len(secs_of(data, s)) > 1 and len(secs_of(ref, s)) > 1]
    # (TOL: two plays that both count no call differ only by the order of tables in memory; measured 2026-11-15 on this tree: at most
    # 0.413% in one second (fight 2 second 5: 632,800 vs 630,200), 0.06-0.34% in the window second. The gate before round 9 read the
    # window second 3.2-4.0% off: 563,600 / 568,600 / 568,400 against 587,300 / 586,700 / 587,000.)
    check(n > 0 and worst <= TOL,
          "hook: XayaUI Rules' instructions in every second of every fight and combat end (%d seconds) equal those of a play with no call "
          "hook, within %.0f%% (play-to-play order of tables in memory)" % (n, 100 * TOL), "worst %.3f%% at %s" % (100 * worst, worst_at))
    check(len(sec2) == 3 and all(abs(x - y) <= TOL * y for x, y in sec2),
          "hook: the second that holds the call-counting window (fight frames 31-45) reads the same as with no call hook", "%s" % sec2)
    st = data.get("stats") or {}
    cyc = GP.vals(st.get("cyc"))
    check(data.get("callsFrom") == "tree play" and len(cyc) == 3 and all(len(c or {}) >= 20 for c in cyc),
          "hook: the call counts the gate judges come from the tree play, for each of the three cycles",
          "from %s, functions counted per cycle %s" % (data.get("callsFrom"), [len(c or {}) for c in cyc]))

    # ---- scenario (SD-77) -------------------------------------------------------------------------------------------------------
    fired = data.get("fired") or {}
    check(int(fired.get("ENCOUNTER_START") or 0) == 3 and int(fired.get("ENCOUNTER_END") or 0) == 3,
          "scenario: every fight has a boss pull and the boss down (ENCOUNTER_START / ENCOUNTER_END, 3 each)", "fired %s" % fired)
    B = data.get("budget") or {}
    check(all(int((B.get(s) or {}).get("frames") or 0) == 30 for s in ENDS),
          "scenario: each combat end and the second after it are a measured segment of their own (30 frames each)",
          "%s" % [(s, (B.get(s) or {}).get("frames")) for s in ENDS])
    mom_ok = all(((B.get("fight %d" % c) or {}).get("moments") or {}).get(m, {}).get("XayaUI_Rules") for c in (1, 2, 3)
                 for m in ("combat start", "boss pull", "boss down")) and \
        all(((B.get("end %d" % c) or {}).get("moments") or {}).get("combat end", {}).get("XayaUI_Rules") for c in (1, 2, 3))
    check(mom_ok, "scenario: the frames right after combat start, the boss pull, the boss down and combat end are kept for each cycle")
    text = gate_text(data)
    # (round 11 repair) judged against the cap the gate stores for this scenario (GP.V33_EVENT_CAPS, ad60a051 not played here), not
    # FAILed, and the line is shown under the check as its evidence
    cap_every = ((GP.V33_EVENT_CAPS.get("caps") or {}).get("every") or {}).get("XayaUI_Rules")
    for what in ("a boss pull \\(ENCOUNTER_START\\)", "combat end"):
        mline = re.search(r"V33 XayaUI Rules per event, %s: costliest frame (\d+) instructions \((?:fight|end) \d; cap (\d+) = ad60a051's\)" % what, text)
        check(mline is not None and int(mline.group(2)) == cap_every and int(mline.group(1)) <= cap_every,
              "scenario: the gate judges XayaUI Rules' costliest frame at %s against the cap and prints it" % what.replace("\\", ""),
              "line %s, stored cap %s" % (mline.group(0) if mline else None, cap_every))
        if mline:
            note("      evidence: " + mline.group(0))
    dc = [c for c in GP.vals(data.get("drawCheck")) if isinstance(c, dict)]
    labels = [c.get("label") for c in dc]
    check(all(labels.count(l) == 3 for l in DRAW_LABELS) and all(c.get("ran") for c in dc),
          "scenario: the draw check ran after each of the %d load-fact changes in all three cycles, and its full re-check ran each time" % len(DRAW_LABELS),
          "%s" % {l: labels.count(l) for l in DRAW_LABELS})
    # (round 11b final fix: the key fight hid the target's debuffs at every moment, so the absent target debuffs no longer changed at
    # combat start and end and this guard on SD-77 lost its teeth on them) the draw play's fight out of the key, on readable data
    outk = {l: [((c.get("groups") or {}).get("Absent") or {}).get("shown") for c in dc if c.get("label") == l] for l in DRAW_OUT_LABELS}
    check(all(len(v) == 1 for v in outk.values()) and outk[DRAW_OUT_LABELS[0]][0] and outk[DRAW_OUT_LABELS[1]][0] == 0
          and outk[DRAW_OUT_LABELS[2]][0] == outk[DRAW_OUT_LABELS[0]][0],
          "scenario: in the draw play's fight out of the key (readable, a target selected) the absent target debuffs are shown with the target "
          "picked, not at combat start, shown again at combat end", "%s" % outk)
    check(not re.search(r"the rules that test the narrowed re-check did not change", text),
          "scenario: the absent target debuffs, the out-of-combat opacity and the boss rules changed at their moments")
    # ---- draw (SD-77) -------------------------------------------------------------------------------------------------------------
    check(dc and all(int(c.get("ndiff") or 0) == 0 for c in dc) and not re.search(r"SD-77: after .* display\(s\) show something other", text),
          "draw: on this engine nothing drawn differs from a full re-check of every rule at any of the %d checks" % len(dc),
          "; ".join("%s %s: %s" % (c.get("label"), c.get("phase"), c.get("ndiff")) for c in dc if c.get("ndiff")))
    check(mdraw_ok, "draw: the mutant (no out-of-combat opacity re-check, no re-read of what combat restricts) could be made from Engine.lua")
    if md is not None:
        mt = gate_text(dict(data, drawCheck=md.get("drawCheck"), drawErrors=md.get("errors")))
        hit = re.findall(r"SD-77: after (combat start|combat end|boss pull|boss down)[^\n]*\n\s+numbers:\s+([^\n]*)", mt)
        diffs = " ".join(x for c in GP.vals(md.get("drawCheck")) if isinstance(c, dict) for x in GP.vals(c.get("diffs")))
        names = set(re.findall(r"\d+ (Ooc \d|Absent \d|Boss \d)", diffs))
        check(bool(hit) and any(n.startswith("Ooc") for n in names) and any(n.startswith("Absent") for n in names),
              "draw: the mutant engine FAILs the gate on what is drawn: the out-of-combat opacity displays and the target debuffs that must "
              "be absent differ from a full re-check after combat starts", "findings %s; displays %s" % ([h[0] for h in hit], sorted(names)))
        note("      mutant draw findings: %s; displays named: %s" % (sorted(set(h[0] for h in hit)), sorted(names)))
    late = ["%s %s: %s" % (c.get("label"), c.get("phase"), "; ".join(GP.vals(c.get("late")))) for c in dc if int(c.get("nlate") or 0)]
    if late:
        note("      listed, not counted (a cooldown that ended during the quiet frames, its wake still on the way): %s" % " | ".join(late)[:600])
    check(mwake_ok, "draw: the mutant (a hidden cooldown's end wakes nothing) could be made from Engine.lua")
    if mw is not None:
        wt = gate_text(dict(data, drawCheck=mw.get("drawCheck"), drawErrors=mw.get("errors")))
        wdiffs = " ".join(x for c in GP.vals(mw.get("drawCheck")) if isinstance(c, dict) for x in GP.vals(c.get("diffs")))
        wnames = sorted(set(re.findall(r"\d+ ((?:Cooldown|Hover|Ooc|Boss) \d+)", wdiffs)))
        check(re.search(r"SD-77: after .* display\(s\) show something other", wt) is not None and bool(wnames),
              "draw: a mutant engine whose hidden cooldown ends wake nothing FAILs the gate on what is drawn (the late-wake list does not "
              "hide a wake that never came)", "displays %s" % wnames)
        note("      mutant wake: displays named %s" % wnames[:12])
    # ---- effects (SD-79) ---------------------------------------------------------------------------------------------------------
    # (round 9 repair 1) a display's time-driven parts are drawn by its frame script (the effects loop) or by a redraw timer (Visual.lua's
    # wake at the next moment a part changes, gate_common.py REDRAWS); both are counted per display, together
    disp = [o for o in GP.vals(data.get("owners")) if isinstance(o, dict) and o.get("display") and str(o.get("rule") or "").startswith("Fx")]
    per = {}
    for o in disp:
        e = per.setdefault(str(o.get("rule")), {"loop": 0, "timer": 0, "times": []})
        e["loop"] += int((o.get("runsBy") or {}).get("effects") or 0)
        e["times"] += [float(t) for t in GP.vals(o.get("times") or [])]
    for t in GP.vals(data.get("fxRedraw") or {}):
        for name, d in ((t or {}).get("disp") or {}).items():
            if str(name).startswith("Fx"):
                e = per.setdefault(str(name), {"loop": 0, "timer": 0, "times": []})
                e["timer"] += int((d.get("byPhase") or {}).get("effects") or 0)
                e["times"] += [float(x) for x in GP.vals(d.get("times") or [])]
    eff = {k: e for k, e in per.items() if e["loop"] + e["timer"] > 0}
    most = {k: GP.most_in_second(e["times"]) for k, e in per.items()}
    check(len(eff) >= 7 and all(most[k] <= 30 for k in eff),
          "effects: the effects part drew every effect display and the bar cue (by its effects loop or by the redraw timer), counted per "
          "display, at most 30 in any second", "%s" % sorted((k, e["loop"], e["timer"], most[k]) for k, e in per.items()))
    note("      effects part, per display (loop runs, redraw-timer redraws, most in one second): %s" % sorted(
        (k, e["loop"], e["timer"], most[k]) for k, e in eff.items()))
    # ---- memory -------------------------------------------------------------------------------------------------------------------
    ma = data.get("memAddons") or {}
    mm = GP.vals(ma.get("mem"))
    check(len(mm) == 3 and re.search(r"the addons' own Lua memory \(the memory play\)", text) is not None,
          "memory: the growth per cycle is read in the memory play (the addons' own) and reported", "readings %s" % mm)
    leak = GP.vals(ml.get("mem"))
    if len(leak) == 3 and len(mm) == 3:
        lt = gate_text(dict(data, memAddons={"mem": ml.get("mem"), "memEnd": ml.get("memEnd")}))
        d1, d2 = leak[1] - leak[0], leak[2] - leak[1]
        check(d1 > 16 and d2 > 16 and re.search(r"WARNING \[gate_performance\] \(whole addon set\)\n\s+what:\s+the addons' Lua memory grows every cycle", lt) is not None,
              "memory: a mutant addon keeping 32 KB more per combat end grows %.1f and %.1f KB a cycle in the memory play and is a WARNING" % (d1, d2))


if __name__ == "__main__":
    sys.exit(main())
