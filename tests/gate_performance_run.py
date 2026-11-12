#!/usr/bin/env python3
"""V27 release gate, performance (Xaya, 2026-11-10, REQUEST-LOG A23 SD-28 / SD-29, her words): "every single element of the
functionality has been built to run optimally in a high-cost gaming environment. This means zero code loops, zero unnecessary complex
calculations, zero floating numbers, nothing anything that demands cpu or memory resources beyond what is ABSOLUTELY necessary without
any other workarounds, and no runaway functions." Her answers: loops "No running loops" (nothing loops every frame, nothing polls on a
timer, nothing loops over all rules on every game event; a loop runs once, bounded, only when something actually changes); numbers
"Whole-pixel / no float math" (positions and sizes set in whole pixels).

The scenario (tests/gate_common.py): a ~300-rule profile; the settings window used and closed; then, with the window closed, three
identical 20-second cycles of the busiest case at 30 frames a second (a loading screen, mount / dismount, a group joined and left, a
target, a 15-second fight with UNIT_AURA, SPELL_UPDATE_COOLDOWN, SPELL_UPDATE_CHARGES, ACTIONBAR_UPDATE_*, UNIT_POWER_FREQUENT and
cast storms every frame, roster updates) and 30 seconds idle. Every event handler, OnUpdate script and timer callback of XayaUI runs
through a measuring dispatcher; judged per source file and line, everything after the settings window closed:
  P1 FAIL  an OnUpdate script runs in a 2-second window in which it changes nothing visible (a running loop);
  P2 FAIL  a repeating timer (C_Timer.NewTicker) or a timer chain that re-arms itself (a timer callback that makes the next timer,
           directly or through others) runs while it changes nothing visible, or is still armed after 30 seconds idle; (round 7) any
           timer callback, one-shot ones armed by events included, that runs more than 10 times within one second (her pace, SD-61
           "10/s for all, like EUI") with nothing on screen changing in that second (WARNING when something did change);
  P3 FAIL  work per event that loops over all rules: a loop (ipairs / pairs) over a table as long as the rule list, or a function called
           at least that many times in one dispatch, in a combat storm event, an event that changed nothing, an OnUpdate or a repeating
           timer; in a one-off change event (loading screen, mount, combat start / end, a real group change) one pass is reported as a
           warning, more than two passes in one event (rules x rules) fail;
  P4 FAIL  steady-state allocation per frame in the busiest case (cycles 2 and 3): an OnUpdate that allocates, or a storm-event handler
           that allocates on 10% or more of its runs; every handler's KB per second and bytes per frame is reported;
  P5 FAIL  a non-integer x / y passed to SetPoint, or a non-integer size to SetSize / SetWidth / SetHeight, by XayaUI code;
  P6 FAIL  runaway: a function whose call count grows from cycle to cycle (or idle window to idle window) on identical input, a
           handler whose work grows the same way, frames made or hooks placed again in the steady state (frames are never freed in
           WoW, hooks never removed), timers made in growing numbers; memory per cycle is reported (WARNING when it grows each cycle).
  V33 FAIL a per-addon work budget per frame of the fight (round 7, her answer "Proxy gate + your check"; see v33() below): XayaUI Rules
           and XayaUI Options above 2% (WARNING above her aim of 0.9%), any other XayaUI addon above 1% in any part of play, where 4% is
           XayaUI Rules' work per fight frame on origin/main ad60a051 in this same scenario (her reading SD-38). Linear scaling, the
           billing and the scenario's likeness to her play are INFERENCE; the budget and the measured numbers are printed on every run,
           with each addon's work per event and per frame and its timers' allocation per pass. A per-event limit is not judged (hers).
Measuring limits (V25; UNVERIFIED IN GAME): instructions are Lua VM instructions in Lua 5.1 and include the stand-in's own widget
methods (C in the game), so they overstate; allocation excludes the stand-in's widget methods and the gate's own measuring; the game's
aura / cooldown reads hand back a new table per call (as the game does), and that garbage counts as XayaUI's.
Run: python3 tests/gate_performance_run.py  (Lua 5.1 via lupa; about two minutes, or seconds when the shared result is cached; the V33
calibration plays ad60a051 once more, from git, about three minutes the first time, then cached).
Proof that the round-7 checks have teeth: tests/v33_budget_teeth_run.py."""
import collections, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gate_common as GC  # noqa: E402

GATE = "gate_performance"
AFTER = lambda p: p == "closed" or p.startswith("busy") or p.startswith("idle")   # noqa: E731  (the window is closed)
STEADY = ("busy 2", "busy 3")
IDLE = ("idle 1", "idle 2", "idle 3")
STORM_FAIL = 0.10   # a storm-event handler that allocates on this share of its runs or more allocates per frame
STORM_FRAMES = 15.0 / 20.0   # share of a cycle's frames that are fight frames with storms (15 of 20 seconds)


def vals(x):
    """A Lua table read back from JSON: a list (keys 1..n) or a dict."""
    if isinstance(x, list):
        return x
    if isinstance(x, dict):
        return list(x.values())
    return []


def kb(b):
    return "%.1f KB" % (b / 1024.0)


def cycles_in(graph):
    """Nodes of the timer graph that sit on a cycle (a chain that re-arms itself)."""
    on = set()
    for start in graph:
        stack, seen = [(start, iter(graph.get(start, {})))], {start}
        while stack:
            node, it = stack[-1]
            nxt = next(it, None)
            if nxt is None:
                stack.pop()
                continue
            if nxt == start:
                on.update(n for n, _ in stack)
            elif nxt not in seen:
                seen.add(nxt)
                stack.append((nxt, iter(graph.get(nxt, {}))))
    return on


def handler_rows(st):
    """Every measured handler as (kind, name, src, record) with record = the per-source stats."""
    rows = []
    for kind, table in (("event", st.get("ev") or {}), ("onupdate", st.get("ou") or {}), ("timer", st.get("tm") or {})):
        for name, s in table.items():
            for src, h in (s.get("srcs") or {}).items():
                rows.append((kind, name, src, h, s))
    return rows


# ---------------------------------------------------------------------------------------------------------------------------------
# V33 work budget (round 7; Xaya, REQUEST-LOG A23 SD-50 / SD-51, her words): "Be sure to set a running standard for all addons that their
# performance benchmarks should be at under 2% cpu at most (in combat, multiple rules running at once), and generally should aim to be
# reasonably under .9%"; "1, but all but combat engine / rules, chat, and options should aim to be under 1% always; 2% only extends as a
# maximum for chat, rules, and options"; how judged: "Proxy gate + your check (Recommended)".
# Calibration (her reading SD-38, 2026-11-11, on her install = origin/main ad60a051): XayaUI Rules 0.7.0 Average CPU 4%, XayaUI Platform
# 0.6.85 0%, XayaUI Options 0.6.107 0%. The gate plays this same scenario on ad60a051 (gate_common.v33_baseline) and takes XayaUI Rules'
# work per fight frame there as 4%; so 1% = a quarter of it. Limits per frame of the fight (cycles 2 and 3, the first second included):
#   XayaUI Rules (with its combat engine), XayaUI Options (and XayaUI Chat, not on main): FAIL above 2% = 50% of ad60a051's Rules work;
#     WARNING above her aim of 0.9% = 22.5% of it;
#   every other XayaUI addon (XayaUI core "Platform" and any new one): FAIL above 1% = 25% of ad60a051's Rules work, in every part of the
#     scenario ("always": the fights, out of combat and idle). Core read 0% in SD-38; its 1% limit is derived with the same proportion
#     (1% = Rules' baseline work / 4), and core's own work on ad60a051 here is printed as a check that the proportion matches her 0%.
# INFERENCE, printed on every run: that Average CPU scales linearly with this work; that the work of an addon's handlers (with everything
# they call) is what the game bills to that addon; that this scenario's fight is like the play in which she read 4%; and Lua VM
# instructions in the stand-in (whose widget methods are Lua here and C in the game) as the measure of work. UNVERIFIED IN GAME: after
# landing she reads AddOn Usage in a fight (V33); any reading over its limit reopens the bundle.
# Per event: the costliest single frame of each addon is printed, but not judged: a per-event limit cannot be derived from an Average
# CPU reading, and how to limit one event is hers to decide (round-7 gate report, NEEDS_HER_DECISION).
# ---------------------------------------------------------------------------------------------------------------------------------
V33_READING = ("SD-38 (2026-11-11, origin/main ad60a051): XayaUI Rules 0.7.0 Average CPU 4%, XayaUI Platform 0.6.85 0%, "
               "XayaUI Options 0.6.107 0%")
V33_BASE_PCT = 4.0
V33_TWO = ("XayaUI_Rules", "XayaUI_Options", "XayaUI_Chat")   # her 2% maximum; every other addon: 1% always
V33_LIMIT_TWO, V33_AIM_TWO, V33_LIMIT_ONE = 2.0, 0.9, 1.0
FIGHT = ("fight 2", "fight 3")
# the calibration measured when this budget was written (round 7), used only when ad60a051 cannot be played (no git in this checkout)
# and the scenario is the same one (stamp): XayaUI Rules' instructions per fight frame on ad60a051
V33_RECORDED = {"stamp": "e16caab88dce", "rules": 403062.2, "core": 1.0, "options": 0.0}   # (2026-11-12, round 7, 900 fight frames)
NAMES = {"XayaUI": "XayaUI (Platform, core)", "XayaUI_Rules": "XayaUI Rules", "XayaUI_Options": "XayaUI Options"}


def first_second(B, seg, addon):
    """An addon's work in the first second (30 frames) of a budget segment."""
    sec = ((B.get(seg) or {}).get("sec") or {}).get(addon)
    if isinstance(sec, dict):
        return sec.get("1", sec.get(1, 0)) or 0
    return sec[0] if sec else 0


def v33(data, rep):
    base, how = GC.v33_baseline()
    stamp = GC.scenario_stamp()
    if base is not None:
        b_rules, bn = GC.seg_per_frame(base, FIGHT, "XayaUI_Rules")
        b_core = GC.seg_per_frame(base, FIGHT, "XayaUI")[0]
        b_opt = GC.seg_per_frame(base, FIGHT, "XayaUI_Options")[0]
        if not bn or b_rules <= 0:
            rep.fail("tests/gate_common.py (V33 calibration)", "the calibration run on %s measured no XayaUI Rules work in the fight" % GC.V33_BASE_COMMIT,
                     how, "fix the scenario on the old build before reading the budget")
            return
        if V33_RECORDED["stamp"] == stamp and V33_RECORDED["rules"]:
            how += "; recorded for this scenario in round 7: %.0f" % V33_RECORDED["rules"]
    elif V33_RECORDED["stamp"] == stamp and V33_RECORDED["rules"]:
        b_rules, b_core, b_opt = V33_RECORDED["rules"], V33_RECORDED["core"], V33_RECORDED["options"]
        rep.warn("tests/gate_common.py (V33 calibration)", "%s could not be played here (%s); the budget uses the calibration recorded in round 7 "
                 "for this same scenario" % (GC.V33_BASE_COMMIT, how))
        how = "recorded in round 7 for scenario %s" % stamp
    else:
        rep.fail("tests/gate_common.py (V33 calibration)", "the V33 budget has no calibration: %s could not be played (%s) and the recorded "
                 "calibration is for another scenario (%s, this one is %s)" % (GC.V33_BASE_COMMIT, how, V33_RECORDED["stamp"], stamp), "",
                 "run the gate in a git checkout that has %s, then record its numbers in V33_RECORDED" % GC.V33_BASE_COMMIT)
        return
    unit = b_rules / V33_BASE_PCT          # instructions per frame that read as 1% Average CPU (INFERENCE: linear)
    pct = lambda w: w / unit               # noqa: E731
    rep.note("V33 budget, calibrated on her reading %s. Calibration: %s; there XayaUI Rules does %.0f Lua instructions per fight frame "
             "(cycles 2 and 3), taken as 4%%, so 1%% = %.0f per frame. INFERENCE: linear scaling, the game billing an addon for its handlers' "
             "work, and this scenario's fight being like her play; UNVERIFIED IN GAME (she reads AddOn Usage after landing)." % (
                 V33_READING, how, b_rules, unit))
    rep.note("V33 core's limit, derived: SD-38 read XayaUI Platform 0%%; with the same proportion its 1%% limit is %.0f instructions per frame; "
             "ad60a051's own core work in this fight is %.1f per frame = %.4f%% and Options' %.1f = %.4f%% (she read 0%% for both: %s)" % (
                 unit, b_core, pct(b_core), b_opt, pct(b_opt),
                 "consistent" if pct(b_core) < 0.05 and pct(b_opt) < 0.05 else "NOT consistent: the scenario or the billing differs from her play"))
    B = data.get("budget") or {}
    addons = sorted(set(a for s in B.values() for a in (s.get("work") or {})) | {"XayaUI", "XayaUI_Rules", "XayaUI_Options"})
    segs_all = sorted(B)
    for a in addons:
        name = NAMES.get(a, a)
        w, n = GC.seg_per_frame(data, FIGHT, a)
        first = sum(first_second(B, s, a) for s in FIGHT) / float(30 * len(FIGHT))
        peak_f = max([((B.get(s) or {}).get("peak") or {}).get(a, 0) for s in FIGHT] + [0])
        parts = ", ".join("%s %.3f%%" % (s, pct(GC.seg_per_frame(data, (s,), a)[0])) for s in segs_all)
        if a in V33_TWO:
            limit, aim = V33_LIMIT_TWO, V33_AIM_TWO
            line = ("V33 %s: %.0f instructions per fight frame = %.3f%% (limit %.1f%% = %.0f, aim %.1f%% = %.0f); first second of the fight "
                    "%.0f per frame = %.3f%%; costliest fight frame %.0f; every part: %s" % (
                        name, w, pct(w), limit, limit * unit, aim, aim * unit, first, pct(first), peak_f, parts))
            rep.note(line)
            if not n:
                rep.fail("tests/gate_common.py (the scenario)", "V33: no fight frames were measured", "", "")
            elif pct(w) > limit:
                rep.fail(a, "V33 work budget: %s works more per fight frame than her %.0f%% maximum (\"2%% only extends as a maximum for chat, rules, "
                         "and options\")" % (name, limit), line,
                         "bring the fight's per-frame work under %.0f Lua instructions: re-check only what changed, at her pace" % (limit * unit))
            elif pct(w) > aim:
                rep.warn(a, "V33 work budget: %s is above her aim of %.1f%% (\"generally should aim to be reasonably under .9%%\")" % (name, aim), line)
        else:
            limit = V33_LIMIT_ONE
            worst = max(segs_all, key=lambda s: GC.seg_per_frame(data, (s,), a)[0]) if segs_all else None
            ww = GC.seg_per_frame(data, (worst,), a)[0] if worst else 0.0
            line = ("V33 %s: %.0f instructions per fight frame = %.4f%%; most in any part (%s): %.0f per frame = %.4f%% (limit %.0f%% always = %.0f); "
                    "every part: %s" % (name, w, pct(w), worst, ww, pct(ww), limit, limit * unit, parts))
            rep.note(line)
            if pct(ww) > limit:
                rep.fail(a, "V33 work budget: %s works more per frame than her 1%% (\"should aim to be under 1%% always\")" % name, line,
                         "bring its per-frame work under %.0f Lua instructions in every part of play" % (limit * unit))
        # what the work is made of: per event (its handlers) and per frame (OnUpdate scripts, timers), in the steady fight
        keys = {}
        for s in FIGHT:
            for k, e in (((B.get(s) or {}).get("keys") or {}).get(a) or {}).items():
                t = keys.setdefault(k, {"n": 0, "ins": 0, "max": 0, "bytes": 0, "allocRuns": 0})
                for f in ("n", "ins", "bytes", "allocRuns"):
                    t[f] += e.get(f, 0)
                t["max"] = max(t["max"], e.get("max", 0))
        if keys and n:
            top = sorted(keys.items(), key=lambda kv: -kv[1]["ins"])[:6]
            rep.note("V33 %s per event and per frame in the fight: %s" % (name, "; ".join(
                "%s: %d run(s), %d instructions each, %.0f per frame (%.3f%%), costliest run %d" % (
                    k, t["n"], t["ins"] // max(1, t["n"]), t["ins"] / float(n), pct(t["ins"] / float(n)), t["max"]) for k, t in top)))
            timers = sorted(((k, t) for k, t in keys.items() if k.startswith("timer ")), key=lambda kv: -kv[1]["n"])[:4]
            if timers:
                rep.note("V33 %s allocation per pass of each timer callback in the fight (most passes first; the engine's routed re-check pass is its busiest: INFERENCE from its run count): %s" % (
                    name, "; ".join("%s: %d pass(es), %.0f bytes per pass, %d of %d allocate, %d instructions per pass" % (
                        k[6:], t["n"], t["bytes"] / float(max(1, t["n"])), t["allocRuns"], t["n"], t["ins"] // max(1, t["n"])) for k, t in timers)))
        bpeak = max([((base or {}).get("budget", {}).get(s) or {}).get("peak", {}).get(a, 0) for s in FIGHT] + [0]) if base else None
        if peak_f:
            rep.note("V33 %s per event (NOT JUDGED: a per-event limit is her decision): costliest single fight frame %.0f instructions "
                     "(%.1f%% if every frame cost that)%s" % (name, peak_f, pct(peak_f),
                                                              ("; ad60a051: %.0f" % bpeak) if bpeak is not None else ""))


def main():
    data, secs, cached = GC.result()
    rep = GC.Report(GATE)
    GC.integrity(data, rep)
    st = data.get("stats") or {}
    frames = data.get("frames") or {}
    fps = data.get("fps") or 30
    nrules = int(data.get("rules") or 0)
    loopmin = data.get("loopMin")
    steady_frames = sum(frames.get(p, 0) for p in STEADY)
    idle_frames = sum(frames.get(p, 0) for p in IDLE)
    rep.note("rule entries: %s; a loop over all rules = a table of %s or more entries; steady state = cycles 2 and 3, %d frames (%.0f s); "
             "idle = %d frames (%.0f s)" % (nrules, loopmin, steady_frames, steady_frames / float(fps), idle_frames, idle_frames / float(fps)))
    if steady_frames < 30 * fps or idle_frames < 25 * fps:
        rep.fail("tests/gate_common.py (the scenario)", "the busiest case ran less than 30 s of steady state or the idle less than 25 s",
                 "steady %d frames, idle %d frames" % (steady_frames, idle_frames), "")
    timers_made = data.get("timersMade") or {}
    pending = data.get("timersPending") or {}
    chains = cycles_in(data.get("timerEdges") or {})
    repeating_site = {site for site, t in timers_made.items() if t.get("kind") == "NewTicker" or t.get("rearm") or site in chains}

    # ---- P1 OnUpdate scripts running while nothing visible changes ------------------------------------------------------------
    for src, s in (st.get("ou") or {}).items():
        wins = [w for w in vals(s.get("wins")) if AFTER(w.get("phase", ""))]
        idle_w = [w for w in wins if w.get("runs", 0) > 0 and w.get("vis", 0) == 0]
        if not idle_w:
            continue
        idle_runs = sum(p.get("n", 0) for ph, p in (s.get("byPhase") or {}).items() if ph in IDLE)
        rep.fail(src, "P1 an OnUpdate script runs every frame while it changes nothing on screen (a running loop)",
                 "%d runs with the window closed, %d of them with no visible change; %d of %d 2-second windows changed nothing "
                 "(%d runs in the 30 s idle with nothing on screen changing); %s allocated; %d Lua instructions per run on average" % (
                     s.get("n", 0), s.get("idle", 0), len(idle_w), len(wins), idle_runs, kb(s.get("bytes", 0)),
                     s.get("ins", 0) // max(1, s.get("n", 1))),
                 "run an OnUpdate only while something it draws is moving; hide its frame / SetScript(\"OnUpdate\", nil) otherwise, and do the "
                 "work in the events that change it (a stored expiry time for countdowns)")

    # ---- P2 tickers and timer chains ------------------------------------------------------------------------------------------
    tm = st.get("tm") or {}
    for site in sorted(set(repeating_site) | set(pending)):
        t = timers_made.get(site) or {}
        s = tm.get(site) or {}
        wins = [w for w in vals(s.get("wins")) if AFTER(w.get("phase", ""))]
        quiet = [w for w in wins if w.get("vis", 0) == 0]
        p = pending.get(site)
        if not (quiet or p):
            continue
        kind = t.get("kind") or (p or {}).get("kind")
        if site in chains or t.get("rearm"):
            kind = "a timer chain that re-arms itself (%s)" % kind
        every = t.get("every") if t else (p or {}).get("every")
        rep.fail(site, "P2 %s every %s s keeps running with nothing on screen to animate" % (
                     "a repeating timer (C_Timer.NewTicker)" if kind == "NewTicker" else kind, every),
                 "%d run(s) with the window closed, in %d 2-second window(s) with no visible change; %s at the end of 30 s idle; "
                 "%s allocated; %d Lua instructions per run" % (
                     s.get("n", 0), len(quiet), "STILL ARMED" if p else "stopped", kb(s.get("bytes", 0)), s.get("ins", 0) // max(1, s.get("n", 1))),
                 "no polling: do the work in the event that changes what the timer checks (or a one-shot C_Timer.After at the stored "
                 "expiry time), and cancel any timer tied to an animation when the animation ends")
    oneshots = [(site, t) for site, t in timers_made.items() if site not in repeating_site and t.get("afterClose")]
    if oneshots:
        rep.note("one-shot timers made after the close (allowed: each runs once): " + "; ".join(
            "%s %s x%d" % (site, t.get("kind"), t.get("afterClose")) for site, t in sorted(oneshots)))

    # ---- P3 loops over all rules per event --------------------------------------------------------------------------------------
    disp = collections.Counter()      # (kind, name, src, ctx) -> dispatches after the close
    ins = collections.Counter()
    insmax = collections.Counter()
    for kind, name, src, h, s in handler_rows(st):
        for ph, hp in (h.get("byPhase") or {}).items():
            if not AFTER(ph):
                continue
            for c, hc in (hp.get("ctx") or {}).items():
                disp[(kind, name, src, c)] += hc.get("n", 0)
                ins[(kind, name, src, c)] += hc.get("ins", 0)
                insmax[(kind, name, src, c)] = max(insmax[(kind, name, src, c)], hc.get("insMax", 0))
    viol = collections.OrderedDict()
    for hk, d in (st.get("loops") or {}).items():
        kind, _, name = hk.partition(" ")
        for line, s in d.items():
            if not any(AFTER(ph) for ph in (s.get("phases") or {})):
                continue
            for ck, n in (s.get("ctx") or {}).items():
                c, _, src = ck.partition("|")
                v = viol.setdefault((kind, name, src, c), {"loops": [], "wide": []})
                v["loops"].append((line, n, s.get("max", 0)))
    for hk, d in (st.get("wide") or {}).items():
        kind, _, name = hk.partition(" ")
        for fn, s in d.items():
            if not any(AFTER(ph) for ph in (s.get("phases") or {})):
                continue
            for c, n in (s.get("ctx") or {}).items():
                v = viol.setdefault((kind, name, s.get("src"), c), {"loops": [], "wide": []})
                v["wide"].append((fn, n, s.get("max", 0)))
    CTXNAME = {"storm": "a combat storm event", "same": "an event that changed nothing the rules read", "change": "a one-off change event",
               "onupdate": "an OnUpdate script", "timer": "a timer"}
    for (kind, name, src, c), v in viol.items():
        n = max(1, disp[(kind, name, src, c)])
        total = sum(t for _, t, _ in v["loops"])
        passes = total / float(n)
        wide_n = max([t for _, t, _ in v["wide"]] + [0])
        where = src or "?"
        label = name if kind == "event" else ("an OnUpdate script" if kind == "onupdate" else "the timer made at " + name)
        lines = "; ".join("loop at %s over %d entries, %d time(s)" % (ln, mx, t) for ln, t, mx in sorted(v["loops"], key=lambda x: -x[1])[:6])
        wides = "; ".join("%s called up to %d times in one dispatch (%d dispatches)" % (fn, mx, t) for fn, t, mx in sorted(v["wide"], key=lambda x: -x[2])[:5])
        numbers = "%s: %d dispatch(es) after the close; %d loop(s) over every rule in total (%.1f per dispatch)%s; %d Lua instructions per " \
                  "dispatch on average, %d at most%s%s" % (
                      label, n, total, passes, ("; %d dispatch(es) called one function once per rule or more" % wide_n) if wide_n else "",
                      ins[(kind, name, src, c)] // n, insmax[(kind, name, src, c)], ("; " + lines) if lines else "", ("; " + wides) if wides else "")
        what = "P3 work loops over all %d rules in %s" % (nrules, ("%s (%s)" % (CTXNAME.get(c, c), name)) if kind == "event" else label)
        fix = ("keep an index from what the event reports (spell ID / aura instance / unit) to the rules that read it, built once when rules "
               "change, and touch only those rules")
        if c in ("storm", "same", "onupdate") or (c == "timer" and name in repeating_site):
            rep.fail(where, what, numbers, fix)
        elif passes > 2.0:
            rep.fail(where, what + ": %.0f passes over every rule in one event (rules x rules)" % passes, numbers,
                     "one bounded pass per real change at most; look rules up through an index instead of scanning the list inside the loop")
        else:
            rep.warn(where, what + " (one pass per real change: allowed by her answer, listed for review)", numbers)

    # ---- P4 allocation ----------------------------------------------------------------------------------------------------------
    sec = steady_frames / float(fps) if steady_frames else 1.0
    per_file = collections.Counter()
    per_file_idle = collections.Counter()
    for kind, name, src, h, s in handler_rows(st):
        steady = [h.get("byPhase", {}).get(p) or {} for p in STEADY]
        b = sum(x.get("bytes", 0) for x in steady)
        runs = sum(x.get("n", 0) for x in steady)
        aruns = sum(x.get("allocRuns", 0) for x in steady)
        idle_b = sum((h.get("byPhase", {}).get(p) or {}).get("bytes", 0) for p in IDLE)
        f = (src or "?").split(":")[0]
        per_file[f] += b
        per_file_idle[f] += idle_b
        if not b and not idle_b:
            continue
        storm = [(x.get("ctx") or {}).get("storm") or {} for x in steady]
        sn = sum(x.get("n", 0) for x in storm)
        sa = sum(x.get("allocRuns", 0) for x in storm)
        sb = sum(x.get("bytes", 0) for x in storm)
        label = name if kind == "event" else kind
        numbers = "%s in the busiest case: %s per second, %.0f bytes per frame on average, %d of %d runs allocate, %.0f bytes per allocating run" \
                  "; idle: %s over %d frames" % (label, kb(b / sec), b / float(max(1, steady_frames)), aruns, runs, b / float(max(1, aruns)),
                                                  kb(idle_b), idle_frames)
        fix = "reuse tables and strings (no table / closure / string building per event or frame); cache what the handler reads and update it by event"
        every_frame = sn >= 0.9 * steady_frames * STORM_FRAMES   # the storm event fires every frame of the fight
        if kind == "onupdate" and (aruns or idle_b):
            rep.fail(src, "P4 per-frame steady-state allocation: an OnUpdate script allocates Lua memory while it runs every frame", numbers, fix)
        elif every_frame and sa / float(sn) >= STORM_FAIL:
            rep.fail(src, "P4 per-frame steady-state allocation: a handler of %s, which fires every frame of the fight, allocates on %d%% of its runs" % (
                label, round(100.0 * sa / sn)), numbers + "; in the storm: %d of %d runs allocate, %s" % (sa, sn, kb(sb)), fix)
        elif sn and sa:
            rep.warn(src, "P4 allocation in combat: a handler of %s allocates on %d of %d runs (not every frame)" % (label, sa, sn), numbers,
                     "reported, not failed: the gate fails only allocation that happens every frame")
        else:
            rep.note("allocation (reported): %s %s" % (src, numbers))
    tot = sum(per_file.values())
    rep.note("allocation in the busiest case, all XayaUI handlers: %s per second, %.0f bytes per frame; per file: %s" % (
        kb(tot / sec), tot / float(max(1, steady_frames)),
        ", ".join("%s %s/s" % (f, kb(b / sec)) for f, b in per_file.most_common() if b) or "none"))
    rep.note("allocation in 30 s idle: %s" % (", ".join("%s %s" % (f, kb(b)) for f, b in per_file_idle.most_common() if b) or "none"))

    # ---- P5 whole pixels ----------------------------------------------------------------------------------------------------------
    for line, s in (data.get("nonint") or {}).items():
        rep.fail(line, "P5 a non-integer position or size passed to %s by XayaUI code" % s.get("method"),
                 "%d call(s) with the window closed, e.g. %s; phases %s" % (s.get("n", 0), s.get("example"), ", ".join(sorted(s.get("phases") or {}))),
                 "store and set whole pixels: round once where the value is made (math.floor(v + 0.5)), not per frame")

    # ---- P6 runaway -----------------------------------------------------------------------------------------------------------------
    def growth(seq, label, unit, min_delta, what, fix):
        series = [dict(x) if isinstance(x, dict) else {} for x in seq]
        if len(series) < 3:
            return
        for k in sorted(set().union(*series)):
            a, b, c = (s.get(k, 0) for s in series[:3])
            if b > a and c > b and c - b >= max(min_delta, 0.05 * b):
                rep.fail(k, "P6 runaway: %s grows %s on identical input" % (what, label), "%s: %d, %d, %d" % (unit, a, b, c), fix)
    growth(st.get("cyc") or [], "from cycle to cycle", "calls in the sampled part of cycles 1, 2, 3", 10, "a function's call count",
           "find what accumulates (a list appended to per event, a hook placed per call, a callback registered again) and make it bounded")
    growth(st.get("idlewin") or [], "from one idle window to the next", "calls in the first 2 s of idle windows 1, 2, 3", 5, "a function's call count",
           "nothing should run while idle; find what keeps scheduling more work")
    ins_by_cycle = [collections.Counter(), collections.Counter(), collections.Counter()]
    for kind, name, src, h, s in handler_rows(st):
        for i, p in enumerate(("busy 1", "busy 2", "busy 3")):
            ins_by_cycle[i]["%s (%s)" % (src, name if kind == "event" else kind)] += (h.get("byPhase", {}).get(p) or {}).get("ins", 0)
    growth(ins_by_cycle, "from cycle to cycle", "Lua instructions in cycles 1, 2, 3", 20000, "a handler's work",
           "find what grows (a list or cache that is never trimmed) and bound it")
    created = st.get("created") or {}
    for ph in ("busy 2", "busy 3") + IDLE + ("idle settle",):
        for line, n in (created.get(ph) or {}).items():
            rep.fail(line, "P6 runaway: frames made again in the steady state (%s); WoW never frees a frame" % ph,
                     "%d frame(s) made in %s; per phase: %s" % (n, ph, ", ".join("%s %d" % (p, (created.get(p) or {}).get(line, 0))
                                                                              for p in ("busy 1", "busy 2", "busy 3") if (created.get(p) or {}).get(line))),
                     "make the frame once and reuse it (a pool), never per event")
    for ph in ("busy 1",):
        for line, n in (created.get(ph) or {}).items():
            rep.note("frames made in the first busy cycle (first use; not made again later): %s x%d" % (line, n))
    hooks = st.get("hooks") or {}
    for ph, d in hooks.items():
        for what, n in d.items():
            (rep.fail if ph in STEADY + IDLE else rep.warn)(
                what.split(" ")[0], "P6 a hook placed after the settings window closed (%s): %s; a hook can never be removed" % (ph, what),
                "%d time(s) in %s" % (n, ph), "place hooks once at load, never per event (V28)")
    for site, t in timers_made.items():
        bp = t.get("byPhase") or {}
        a, b, c = bp.get("busy 1", 0), bp.get("busy 2", 0), bp.get("busy 3", 0)
        if b > a and c > b:
            rep.fail(site, "P6 runaway: timers made in growing numbers from cycle to cycle", "timers made in cycles 1, 2, 3: %d, %d, %d" % (a, b, c),
                     "one timer per real change; cancel the old one before making a new one")
    # ---- P2 (round 7) her pace for every timer callback, however it was armed ---------------------------------------------------
    pace_n = data.get("paceN") or 10
    for src, p in sorted((data.get("pace") or {}).items()):
        over = sum(n for ph, n in (p.get("over") or {}).items() if AFTER(ph))
        quiet = sum(n for ph, n in (p.get("quiet") or {}).items() if AFTER(ph))
        if quiet:
            rep.fail(src, "P2 a timer callback ran more than %d times within one second (faster than her pace, SD-61 \"10/s for all\") while "
                     "changing nothing on screen, armed by events or by itself (one-shot timers count: round 6's first second of a fight "
                     "escaped P2 this way)" % pace_n,
                     "%d run(s) found more than %d runs in the second before them, %d of them with nothing on screen changed in that second "
                     "(first: %s); most runs within one second: %d" % (over, pace_n, quiet, p.get("first"), p.get("most", 0)),
                     "hold the next pass until a tenth of a second after the last (her pace), and run it only when something it reads changed")
        elif over:
            rep.warn(src, "P2 a timer callback ran more than %d times within one second (her pace, SD-61), each second of it changing something "
                     "on screen" % pace_n, "%d run(s) above the pace; most runs within one second: %d" % (over, p.get("most", 0)),
                     "listed against her pace: a re-check pass may run at most 10 times a second")

    # ---- V33 work budget per addon ------------------------------------------------------------------------------------------------
    v33(data, rep)

    mem = [m for m in vals(data.get("mem")) if isinstance(m, (int, float))]
    if len(mem) >= 3:
        d1, d2 = mem[1] - mem[0], mem[2] - mem[1]
        txt = "Lua memory after a full collection at the end of cycles 1, 2, 3: %s, %s, %s (+%s, +%s); after 30 s idle: %s" % (
            kb(mem[0] * 1024), kb(mem[1] * 1024), kb(mem[2] * 1024), kb(d1 * 1024), kb(d2 * 1024), kb((data.get("memEnd") or 0) * 1024))
        if d1 > 16 and d2 > 16:
            rep.warn("(whole addon set)", "Lua memory grows every cycle on identical input (a leak or an unbounded cache); includes the gate's own "
                     "per-cycle records, a few KB", txt, "find the table that grows (a /xui debug memory report in game)")
        else:
            rep.note(txt)
    return rep.show(data, secs, cached)


if __name__ == "__main__":
    sys.exit(main())
