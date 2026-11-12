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
           directly or through others) runs while it changes nothing visible, or is still armed after 30 seconds idle;
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
Measuring limits (V25; UNVERIFIED IN GAME): instructions are Lua VM instructions in Lua 5.1 and include the stand-in's own widget
methods (C in the game), so they overstate; allocation excludes the stand-in's widget methods and the gate's own measuring; the game's
aura / cooldown reads hand back a new table per call (as the game does), and that garbage counts as XayaUI's.
Run: python3 tests/gate_performance_run.py  (Lua 5.1 via lupa; about two minutes, or seconds when the shared result is cached)."""
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
