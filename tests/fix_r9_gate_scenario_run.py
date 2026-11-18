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


# (round 11) every mutant tree this run makes, removed when it ends (each is about 7 MB; before round 11 they stayed in the temp folder,
# one pair per checkout, 70 of them by 2026-11-18, and the disk filled up)
TREES = []
# (round 11) the plays running in their own processes, stopped if this test is stopped
PROCS, PROCS_LOCK = [], threading.Lock()


def mutant_tree(name, edit):
    # (round 11) a folder of this run's own. Before round 11 the folder was named after the checkout only, so two runs of this test on
    # the same checkout at the same time (a suite while another session ran the same tests) deleted and rewrote each other's mutant
    # addons in the middle of a play.
    dest = tempfile.mkdtemp(prefix="xui_r9_%s-" % name)
    TREES.append(dest)
    for a in GC.ADDONS + (GC.DEBUG_ADDON,):
        if os.path.isdir(os.path.join(GC.ROOT, a)):
            shutil.copytree(os.path.join(GC.ROOT, a), os.path.join(dest, a))
    os.makedirs(os.path.join(dest, "tests"))
    shutil.copytree(os.path.join(HERE, "harness"), os.path.join(dest, "tests", "harness"), ignore=shutil.ignore_patterns("reports", "__pycache__"))
    for f in os.listdir(HERE):
        if f.startswith("gate_") and f.endswith(".py"):
            shutil.copy(os.path.join(HERE, f), os.path.join(dest, "tests", f))
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


def check(ok, what, detail=""):
    print(("ok   " if ok else "FAIL ") + what + (("  [" + detail + "]") if (detail and not ok) else ""))
    DONE.append(what)
    if not ok:
        FAILS.append(what)


class Stopped(Exception):
    """The test was stopped from outside (the suite's time limit sends SIGTERM)."""


def _kill_plays():
    with PROCS_LOCK:
        for p in PROCS:
            if p.poll() is None:
                p.kill()


def _on_term(signum, _frame):
    _kill_plays()
    raise Stopped("stopped by signal %d" % signum)


class _Pool(concurrent.futures.ThreadPoolExecutor):
    """A thread pool that, when the block it serves ends with an error, does not wait for the plays still running (they are stopped,
    and the reference play in this process is abandoned: main() ends the process at once after the count line)."""
    def __exit__(self, et, ev, tb):
        self.shutdown(wait=et is None, cancel_futures=et is not None)
        return False


def main():
    """(round 11, round 10 final review: inside the suite this test once printed nothing at all) it always ends with its count line:
    each line is written out as it is printed (a test killed part-way still shows how far it got); an error anywhere (the gate's
    scenario, a disk that is full, a play that dies) or a stop from outside (SIGTERM, Ctrl+C) is a named FAIL with its traceback,
    followed by the count line; the plays running in their own processes are stopped and the mutant trees removed."""
    sys.stdout.reconfigure(line_buffering=True)
    signal.signal(signal.SIGTERM, _on_term)
    stopped = False
    try:
        _main()
    except (Exception, KeyboardInterrupt) as e:  # noqa: BLE001  (every way of stopping is reported, never silent)
        stopped = True
        print("".join(traceback.format_exception(type(e), e, e.__traceback__))[-3000:].rstrip())
        check(False, "the test ran to its end", "it stopped at: %s: %s" % (type(e).__name__, str(e)[:300]))
    finally:
        _kill_plays()
        for t in TREES:
            shutil.rmtree(t, ignore_errors=True)
        if not DONE:
            check(False, "the test checked something (no check ran)")
        print("%d checks, %d failed" % (len(DONE), len(FAILS)))
    if stopped:
        sys.stdout.flush()
        os._exit(1)   # (a play still running in this process's threads must not hold the exit back)
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
        mdraw, mdraw_ok = mutant_tree("drawmut", edit_draw)
        mleak, _ = mutant_tree("leakmut", edit_leak)
        f_md = ex.submit(play_in, mdraw, perf=False, drawcheck=True) if mdraw_ok else None
        f_ml = ex.submit(play_in, mleak, perf=False, memplay=True)
        def got(f, what):
            try:
                return f.result() if f else None
            except Exception as e:  # noqa: BLE001  (reported as a failed check)
                check(False, "the %s play ran" % what, str(e)[-300:])
                return None
        ref = got(f_ref, "reference (no call hook)") or {}
        md = got(f_md, "mutant draw")
        ml = got(f_ml, "mutant memory") or {}

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
    for what in ("a boss pull \\(ENCOUNTER_START\\)", "combat end"):
        check(re.search(r"V33 XayaUI Rules per event, %s: costliest frame \d+ instructions" % what, text) is not None,
              "scenario: the gate judges XayaUI Rules' costliest frame at %s against the cap and prints it" % what.replace("\\", ""))
    dc = [c for c in GP.vals(data.get("drawCheck")) if isinstance(c, dict)]
    labels = [c.get("label") for c in dc]
    check(all(labels.count(l) == 3 for l in DRAW_LABELS) and all(c.get("ran") for c in dc),
          "scenario: the draw check ran after each of the %d load-fact changes in all three cycles, and its full re-check ran each time" % len(DRAW_LABELS),
          "%s" % {l: labels.count(l) for l in DRAW_LABELS})
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
        print("      mutant draw findings: %s; displays named: %s" % (sorted(set(h[0] for h in hit)), sorted(names)))
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
    print("      effects part, per display (loop runs, redraw-timer redraws, most in one second): %s" % sorted(
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
