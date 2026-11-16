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
  P1 FAIL  an OnUpdate script runs in a 2-second window in which it changes nothing visible (a running loop); (round 9, SD-79) counted
           per frame it runs on; a display's effects loop (Visual.lua) is held per display to at most 30 runs in any second and to no run
           that changes nothing beyond the single run that finds nothing left to animate (her answer "<=30/s, stop if idle");
           (round 9 repair 1) a run that changes the screen always counts, a display script left set while it only skips for more than a
           second FAILs, and the redraw timers (gate_common.py REDRAWS: Visual.lua's wake) are counted per display with its frame
           script, at most 30 in any second, and FAIL on two idle runs in a row (instead of P2's 10 a second per callback);
  P2 FAIL  a repeating timer (C_Timer.NewTicker) or a timer chain that re-arms itself (a timer callback that makes the next timer,
           directly or through others) runs while it changes nothing visible, or is still armed after 30 seconds idle; (round 7, round 8)
           any re-check path, every timer callback (one-shot ones armed by events included: routed and every-live-rule passes, wakes,
           polls) and every frame script (OnUpdate), that runs more than 10 times in any sliding one-second window, the first second of a
           fight included (her pace, SD-61 "10/s for all, like EUI"; SD-66 "1": every re-check path at most 10 a second), whatever it
           changed on screen; (round 8 repair) each re-check pass named in REPASSES (routed, every-live-rule, settle, wake and poll) is
           counted over everything that runs it (timer callbacks, frame scripts and event handlers), so a pass driven by several
           callbacks is one path; work several passes share is a WARNING, not judged (her rule is per path; NEEDS_HER_DECISION);
  P3 FAIL  work per event that loops over all rules: a loop (ipairs / pairs) over a table as long as the rule list, or a function called
           at least that many times in one dispatch, in a combat storm event, an event that changed nothing, an OnUpdate or a repeating
           timer; in a one-off change event (loading screen, mount, combat start / end, a real group change) one pass is reported as a
           warning, more than two passes in one event (rules x rules) fail;
  P4 FAIL  steady-state allocation per frame in the busiest case (cycles 2 and 3): an OnUpdate that allocates, or a storm-event handler
           that allocates on 10% or more of its runs; every handler's KB per second and bytes per frame is reported; (round 8, SD-68
           guard) a timer call site that hands C_Timer a new function made from the same definition on a later call (a closure per call),
           (round 9, SD-82 "FAIL everywhere") on the hot path and everywhere else;
  P5 FAIL  a non-integer x / y passed to SetPoint, or a non-integer size to SetSize / SetWidth / SetHeight, by XayaUI code;
  P6 FAIL  runaway: a function whose call count grows from cycle to cycle (or idle window to idle window) on identical input, a
           handler whose work grows the same way, frames made or hooks placed again in the steady state (frames are never freed in
           WoW, hooks never removed), timers made in growing numbers; memory per cycle is reported (WARNING when it grows each cycle).
  V33 FAIL a per-addon work budget per frame of the fight (round 7, her answer "Proxy gate + your check"; see v33() below): XayaUI Rules
           and XayaUI Options above 2% (WARNING above her aim of 0.9%), any other XayaUI addon above 1% in any part of play, where 4% is
           XayaUI Rules' work per fight frame on origin/main ad60a051 in this same scenario (her reading SD-38). Linear scaling, the
           billing and the scenario's likeness to her play are INFERENCE; the budget and the measured numbers are printed on every run,
           with each addon's work per event and per frame and its timers' allocation per pass. (round 8, SD-66 "No worse than ad60a51")
           per addon, the costliest single fight frame above that addon's own on ad60a051 (V33_EVENT_CAPS, stored with its source).
           (round 9) the fights and each combat end's second ("end N"), and on their own lines the frames right after combat start, a
           boss pull, the boss down and combat end (SD-77); XayaUI_Debug at most 600 (SD-81 "600, same as core").
  DRAW FAIL (round 9, SD-77 "Route + narrow") after each load-fact change a display shows something other than a full re-check of every
           rule shows (gate_common.py drawCheck).
  MEM FAIL (round 8, SD-66 "Today +15%, tighten later") Lua memory after a full collection at the end of any cycle (or after the idle)
           above 34,747.6 KB x 1.15 = 39,959.7 KB; the growth per cycle is still reported (WARNING when it grows every cycle; round 9: read in
           the memory play, so it is the addons' own, not the gate's records).
Every check runs on both variants of the scenario (Advanced Debugging off and on; findings of the second are marked so).
Measuring limits (V25; UNVERIFIED IN GAME): instructions are Lua VM instructions in Lua 5.1 and include the stand-in's own widget
methods (C in the game), so they overstate; allocation excludes the stand-in's widget methods and the gate's own measuring; the game's
aura / cooldown reads hand back a new table per call (as the game does), and that garbage counts as XayaUI's.
Run: python3 tests/gate_performance_run.py  (Lua 5.1 via lupa; about two minutes, or seconds when the shared result is cached; the V33
calibration plays ad60a051 once more, from git, about three minutes the first time, then cached).
Proof that the round-7 checks have teeth: tests/v33_budget_teeth_run.py."""
import collections, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gate_common as GC  # noqa: E402

GATE = "gate_performance"
AFTER = lambda p: p in ("closed", "effects") or p.startswith("busy") or p.startswith("idle")   # noqa: E731  (the window is closed)
FX_PHASES = ("preview", "unlock")   # (round 9, SD-79) before the close: the previews and the mover, judged only by the per-display checks
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
# Per event (round 8): her answer SD-66 "No worse than ad60a51 (Recommended)"; see V33_EVENT_CAPS below.
# ---------------------------------------------------------------------------------------------------------------------------------
V33_READING = ("SD-38 (2026-11-11, origin/main ad60a051): XayaUI Rules 0.7.0 Average CPU 4%, XayaUI Platform 0.6.85 0%, "
               "XayaUI Options 0.6.107 0%")
V33_BASE_PCT = 4.0
V33_TWO = ("XayaUI_Rules", "XayaUI_Options", "XayaUI_Chat")   # her 2% maximum; every other addon: 1% always
V33_LIMIT_TWO, V33_AIM_TWO, V33_LIMIT_ONE = 2.0, 0.9, 1.0
FIGHT = ("fight 2", "fight 3")
# the calibration measured when this budget was written (round 7), used only when ad60a051 cannot be played (no git in this checkout)
# and the scenario is the same one (stamp): XayaUI Rules' instructions per fight frame on ad60a051
# (round 8) the scenario changed (stamp e16caab88dce -> 8dc78a680bbc: the fight's movement, rune, totem and loss-of-control events, the
# stand-in's timer records billed to itself, the debug variant), so the round-7 record no longer applies; ad60a051 played again with
# this gate in a clone of it (2026-11-13, 900 fight frames of cycles 2 and 3): XayaUI Rules 367,582,500 instructions / 900 = 408,425.0 per
# fight frame (a second play: 408,465.3), core 1.2, Options 0.0. So 4% = 408,425.0 and 1% = 408,425.0 / 4 = 102,106.25 per frame.
# (round 7's record for its scenario: stamp e16caab88dce, rules 403,062.2, core 1.0, options 0.0.)
# (round 8 repair) the scenario's text changed again (stamp 8dc78a680bbc -> cdcaf3b76a92: the pace per re-check pass, taken in a second
# play; the measured play is unchanged), so ad60a051 was played again with this gate (2026-11-13, two plays, 900 fight frames each):
# XayaUI Rules (183,842,100 + 183,876,500) / 900 = 408,576.2 per fight frame (second play (183,840,100 + 183,775,600) / 900 = 408,461.9),
# core 1.2, Options 0.0: within 0.04% of the 408,425.0 above ((408,576.2 - 408,425.0) / 408,425.0 = 0.037%), the same reading. So
# 4% = 408,576.2 and 1% = 408,576.2 / 4 = 102,144.05 per frame.
# (round 8 repair 2, 2026-11-15) the scenario's text changed again (stamp cdcaf3b76a92 -> 9a9fb14ec503: the tree play also takes the call
# trees of event handlers, for a pass an event handler runs itself; the measured play is unchanged), so ad60a051 was played twice more
# with this gate (tests/gate_common.py v33_baseline, XUI_GATE_NOCACHE=1, the repository's own git for ad60a051):
# XayaUI Rules 367,547,500 / 900 = 408,386.1 per fight frame (second play 367,582,400 / 900 = 408,424.9), core 800 / 900 = 0.9,
# Options 0.0: within 0.05% of the 408,576.2 above ((408,386.1 - 408,576.2) / 408,576.2 = -0.047%), the same reading. So
# 4% = 408,386.1 and 1% = 408,386.1 / 4 = 102,096.5 per frame.
# (round 9, 2026-11-15) the scenario changed (stamp 9a9fb14ec503 -> aa8a21168329: the measured play counts no call (SD-80), a boss pull
# in every fight, combat end as a segment of its own, 25 more rules with displays (absent target debuffs, out-of-combat opacity, boss
# rules, effect displays), previews and the mover at 144 frames a second, the effects part); ad60a051 played twice with this gate
# (tests/gate_common.py tree_copy / tree_result, git archive of the repository's own ad60a051, XUI_GATE_NOCACHE=1):
# XayaUI Rules 382,651,600 / 900 = 425,168.4 per fight frame (second play 382,651,100 / 900 = 425,167.9), core 1,000 / 900 = 1.1
# (second play 900 / 900 = 1.0), Options 0.0. So 4% = 425,168.4 and 1% = 425,168.4 / 4 = 106,292.1 per frame. (The round 8 value
# above, 408,386.1, was for scenario 9a9fb14ec503: (425,168.4 - 408,386.1) / 408,386.1 = +4.1%.)
# (round 9 gate repair 1, 2026-11-16) the scenario's text changed again (stamp aa8a21168329 -> 6e573efe8b12: the gate's own records only:
# a display script's skips while it changes nothing, the run times per display, and in the tree play the widget each change lands on for
# the redraw timers, REDRAWS; the addons' code and the measured play's hook are unchanged), so ad60a051 was played twice more with this
# gate (tree_copy / git archive of the repository's own ad60a051, XUI_GATE_NOCACHE=1, 182 s each):
# XayaUI Rules 382,656,000 / 900 = 425,173.3 per fight frame (second play 382,655,800 / 900 = 425,173.1), core 1,000 / 900 = 1.1 (both
# plays), Options 0.0. Against the aa8a21168329 value: (425,173.3 - 425,168.4) / 425,168.4 = +0.001%, the same reading (the gate's own
# code between two measured runs moves the 100-instruction counter's phase).
V33_RECORDED = {"stamp": "6e573efe8b12", "rules": 425173.3, "core": 1.1, "options": 0.0,   # (2026-11-16, round 9 gate repair 1, 900 fight frames)
                "when": "in round 9 gate repair 1 (2026-11-16, ad60a051 played twice, the first play)"}
FIGHT_ALL = ("fight 1", "fight 2", "fight 3")
# (round 9, SD-77) the second after each fight's combat end is a measured segment of its own ("end N"); the per-event cap judges the
# fights and these together, and the frames right after each moment that changes load facts on their own lines
END_ALL = ("end 1", "end 2", "end 3")
CAP_EVERY = FIGHT_ALL + END_ALL
CAP_STEADY = ("fight 2", "fight 3", "end 2", "end 3")
MOMENTS = (("combat start", "combat start"), ("boss pull", "a boss pull (ENCOUNTER_START)"), ("boss down", "the boss down (ENCOUNTER_END)"),
           ("combat end", "combat end"))
# (round 9; REQUEST-LOG A23 SD-81, her answer "600, same as core (Recommended)") XayaUI_Debug (read only with Advanced Debugging on, V34):
# its costliest single fight frame at most 600 Lua instructions, in every variant it is loaded in. Her number, fixed: it is not taken
# from ad60a051 (which had no XayaUI_Debug) and does not follow core's cap if that is measured again.
DEBUG_EVENT_CAP = {"XayaUI_Debug": 600}
# V33 per event (round 8; REQUEST-LOG A23 SD-66, her answer "No worse than ad60a51 (Recommended)"): for each addon, the costliest single
# frame of the fight (its handlers' Lua instructions billed to one drawn frame) must not exceed that addon's own costliest fight frame
# on origin/main ad60a051 (her install when she read AddOn Usage, SD-38), played in this same scenario by this same gate. Two readings,
# both judged: every fight (cycles 1-3, the first fight after login included) and the steady fights (cycles 2-3: the reading round 7
# printed, Rules 570,600 then, before round 8 billed the stand-in's timer records to itself and added the fight's movement, rune, totem
# and loss-of-control events). An addon ad60a051 did not have (XayaUI_Debug) has no value: NOT JUDGED (NEEDS_HER_DECISION, round 8).
# Used as stored while the scenario stamp matches; when it does not, ad60a051 is played now (git) and a WARNING asks to store the new
# numbers; with neither, a FAIL.
# Measured 2026-11-13 (round 8) with this gate on a clone of ad60a051 (the gate files and harness of this checkout copied into it, the
# scenario played twice, XUI_GATE_NOCACHE=1). Costliest single fight frame, Lua instructions, fights 1 / 2 / 3:
#   XayaUI Rules    run 1: 538,500 / 538,200 / 538,500   run 2: 538,300 / 538,600 / 538,400   -> cap 538,600 (both readings)
#   XayaUI (core)   run 1: 600 / 600 / 500                run 2: 600 / 600 / 500                -> cap 600
#   XayaUI Options  0 in every fight                                                             -> cap 0
# The two plays differ by at most 300 instructions (the hook counts every 100; table order follows memory addresses), so the cap is the
# higher reading. Round 7's printed 570,600 was the round 7 gate: its costliest frame fell inside its call-counting window (fight frames
# 31-45); the same gate with call counting off reads 533,500, and this gate reads 538,400 with it off (round 8 gate report).
# (round 8 repair) stamp 8dc78a680bbc -> cdcaf3b76a92 (the pace per re-check pass, in a second play; the measured play is unchanged);
# ad60a051 played twice more with this gate (2026-11-13), costliest single fight frame, fights 1 / 2 / 3:
#   XayaUI Rules    run 1: 538,300 / 538,500 / 538,600   run 2: 538,800 / 538,600 / 538,300   -> every fight 538,800, steady 538,600
#   XayaUI (core)   run 1: 800 / 500 / 600                run 2: 800 / 500 / 600                -> every fight 800, steady 600
#   XayaUI Options  0 in every fight                                                             -> cap 0
# Rules' steady cap is the same 538,600; the every-fight caps are the higher reading of the two plays, as above (the 100-instruction steps
# of the hook: Rules +200 = 0.04%, core +200 in fight 1, two PLAYER_REGEN_DISABLED runs of 300-400 each).
# (round 8 repair 2, 2026-11-15) stamp cdcaf3b76a92 -> 9a9fb14ec503 (event handlers' call trees in the tree play; the measured play is
# unchanged); ad60a051 played twice more with this gate, costliest single fight frame, fights 1 / 2 / 3:
#   XayaUI Rules    run 1: 538,500 / 538,400 / 538,300   run 2: 538,400 / 538,400 / 538,500   -> every fight 538,500, steady 538,500
#   XayaUI (core)   run 1: 300 / 200 / 600                run 2: 300 / 200 / 600                -> every fight 600, steady 600
#   XayaUI Options  0 in every fight                                                             -> cap 0
# The rule is unchanged (the higher reading of two plays of this scenario), so the caps follow this scenario's readings: Rules 538,500
# (300 below the cdcaf3b76a92 cap 538,800: three steps of the 100-instruction hook, 0.06%), core 600 (fight 1's 800 above was two
# PLAYER_REGEN_DISABLED runs; here fight 1 reads 300).
# (round 9, 2026-11-15) stamp 9a9fb14ec503 -> aa8a21168329 (see V33_RECORDED); the caps are now judged on the fights and each combat
# end's second (CAP_EVERY / CAP_STEADY). ad60a051 played twice with this gate (tree_copy / tree_result, as in round 8), costliest single
# frame, fights 1 / 2 / 3, ends 1 / 2 / 3:
#   XayaUI Rules    run 1: 579,700 / 579,600 / 579,500, 577,900 / 577,900 / 578,000   run 2: 579,700 / 579,800 / 579,500, 578,000 / 577,700 / 577,700
#                   -> every 579,800, steady (fights 2-3, ends 2-3) 579,800; the frames after each moment (both runs, the higher):
#                      combat start 577,000, boss pull 579,700, boss down 573,300, combat end 578,000
#   XayaUI (core)   run 1: 500 / 500 / 500, 600 / 600 / 600                 run 2: 500 / 400 / 500, 600 / 600 / 600      -> 600, 600
#   XayaUI Options  0 everywhere                                                                                         -> 0
# The rule is unchanged (the higher reading of two plays of this scenario). Rules' cap rises from 538,500 to 579,800: +41,300 = 7.7%
# (41,300 / 538,500). Its costliest frame is still the every-frame step lining up with the AuraDisplay timer and the charges handler
# (step up to 555,600, AuraDisplay timer 51,400, SPELL_UPDATE_CHARGES 23,200 in fight 2); INFERENCE: the step re-checks every rule every
# frame on ad60a051, and the 25 rules with displays the round 9 profile adds are dearer to re-check than the 22 cues they replace (the
# list stays at about 300 entries); ad60a051's per-frame average rose 4.1% (V33_RECORDED). The call counting no longer in the measured
# play does not change ad60a051's costliest frame (round 8: its costliest frame was outside the counting window).
# (round 9 gate repair 1, 2026-11-16) stamp aa8a21168329 -> 6e573efe8b12 (see V33_RECORDED: only the gate's own records changed).
# ad60a051 played twice with this gate (tree_copy / git archive, XUI_GATE_NOCACHE=1), costliest single frame, fights 1 / 2 / 3, ends 1 / 2 / 3:
#   XayaUI Rules    run 1: 579,800 / 579,800 / 579,600, 578,000 / 577,900 / 578,000   run 2: 579,900 / 579,600 / 579,700, 577,900 / 578,000 / 578,000
#                   -> every 579,900 (run 2, fight 1), steady (fights 2-3, ends 2-3) 579,800 (run 1, fight 2); the frames after each
#                      moment (both runs, the higher): combat start 576,800, boss pull 579,900, boss down 573,400, combat end 578,000
#   XayaUI (core)   run 1: 500 / 500 / 500, 600 / 600 / 500                 run 2: 500 / 500 / 500, 600 / 600 / 600      -> 600, 600
#   XayaUI Options  0 everywhere                                                                                         -> 0
# The rule is unchanged (the higher reading of two plays of this scenario, both kept above). Rules' every-segment cap 579,800 -> 579,900
# (+100 = one step of the 100-instruction hook, 100 / 579,800 = 0.017%); its steady cap stays 579,800; core and Options unchanged.
V33_EVENT_CAPS = {"source": "ad60a051", "stamp": "6e573efe8b12",
                  "how": "measured 2026-11-16, round 9 gate repair 1, two plays of ad60a051 in this scenario, the higher reading",
                  "caps": {"every": {"XayaUI_Rules": 579900, "XayaUI": 600, "XayaUI_Options": 0},
                           "steady": {"XayaUI_Rules": 579800, "XayaUI": 600, "XayaUI_Options": 0}}}
V33_EVENT_CAPS_TOL = 0.01   # a replay of ad60a051 within 1% of the stored caps is the same reading (the 300-instruction spread above)
NAMES = {"XayaUI": "XayaUI (Platform, core)", "XayaUI_Rules": "XayaUI Rules", "XayaUI_Options": "XayaUI Options"}


def first_second(B, seg, addon):
    """An addon's work in the first second (30 frames) of a budget segment."""
    sec = ((B.get(seg) or {}).get("sec") or {}).get(addon)
    if isinstance(sec, dict):
        return sec.get("1", sec.get(1, 0)) or 0
    return sec[0] if sec else 0


_BASE = []


def baseline():
    """GC.v33_baseline(), once per run (both variants are judged against the same ad60a051 run)."""
    if not _BASE:
        _BASE.append(GC.v33_baseline())
    return _BASE[0]


def peak(d, segs, addon):
    """An addon's costliest single frame (Lua instructions of its handlers) over the named budget segments, and the segment it was in."""
    best, where = 0, None
    for s in segs:
        v = (((d.get("budget") or {}).get(s) or {}).get("peak") or {}).get(addon, 0) or 0
        if v > best:
            best, where = v, s
    return best, where


def moment_peak(d, segs, name, addon):
    """(round 9) An addon's costliest frame among the frames right after a moment (gate_common.py moment()) over the named segments."""
    best, where = 0, None
    for s in segs:
        v = ((((d.get("budget") or {}).get(s) or {}).get("moments") or {}).get(name) or {}).get(addon, 0) or 0
        if v > best:
            best, where = v, s
    return best, where


def event_caps(data, rep, base, stamp, pct):
    """V33 per event (round 8; SD-66, her answer "No worse than ad60a51 (Recommended)"): see V33_EVENT_CAPS. (round 9) The segments
    judged are the fights and the second after each fight's combat end (CAP_EVERY / CAP_STEADY); the costliest boss-pull and combat-end
    frames are judged against the same caps on their own lines (SD-77); XayaUI_Debug against SD-81's 600 (DEBUG_EVENT_CAP)."""
    rec = V33_EVENT_CAPS
    measured = None
    if base is not None:
        measured = {k: {a: peak(base, segs, a)[0] for a in rec["caps"][k]} for k, segs in (("every", CAP_EVERY), ("steady", CAP_STEADY))}
    if rec["stamp"] == stamp:
        caps, how = rec["caps"], "stored in this gate for scenario %s (%s)" % (stamp, rec["how"])
        drift = measured is not None and any(abs(measured[k][a] - caps[k][a]) > V33_EVENT_CAPS_TOL * max(caps[k][a], 100)
                                             for k in caps for a in caps[k])
        if drift:
            rep.warn("tests/gate_performance_run.py (V33 per-event caps)", "the stored per-event caps differ from %s played now in this same "
                     "scenario" % rec["source"], "stored %s; played now %s" % (caps, measured),
                     "find why the same build and scenario measure differently (the stand-in or the harness changed?) before trusting either")
    elif measured is not None:
        caps, how = measured, "measured now on %s in this scenario (%s; the stored caps are for scenario %s)" % (rec["source"], stamp, rec["stamp"])
        rep.warn("tests/gate_performance_run.py (V33 per-event caps)", "the stored per-event caps are for another scenario; this run uses "
                 "%s played now" % rec["source"], "now: %s" % measured, "record these numbers and this scenario's stamp in V33_EVENT_CAPS")
    else:
        rep.fail("tests/gate_performance_run.py (V33 per-event caps)", "the V33 per-event limit has no caps: %s could not be played here and the "
                 "stored caps are for another scenario (%s, this one is %s)" % (rec["source"], rec["stamp"], stamp), "",
                 "run the gate in a git checkout that has %s (or set XUI_V33_REPO to one), then store its numbers in V33_EVENT_CAPS" % rec["source"])
        caps = None
    B = data.get("budget") or {}
    addons = sorted(set(a for sg in CAP_EVERY for a in (((B.get(sg) or {}).get("peak")) or {})) | set((caps or {}).get("every") or {})
                    | (set(DEBUG_EVENT_CAP) if data.get("debugLoaded") else set()))
    for a in addons:
        name = NAMES.get(a, a)
        cur_e, seg_e = peak(data, CAP_EVERY, a)
        cur_s, seg_s = peak(data, CAP_STEADY, a)
        if a in DEBUG_EVENT_CAP:
            # (round 9, SD-81, her answer "600, same as core (Recommended)") XayaUI_Debug, read only with Advanced Debugging on (V34)
            cap = DEBUG_EVENT_CAP[a]
            line = ("V33 %s per event (SD-81): costliest single fight frame %.0f instructions (%s; cap %.0f, her answer \"600, same as core\")" % (
                name, cur_e, seg_e or "none", cap))
            if cur_e > cap:
                rep.fail(a, "V33 per-event limit: %s's costliest single fight frame is above her cap of %.0f instructions (SD-81 \"600, same as "
                         "core\")" % (name, cap), line + "; over by %.0f" % (cur_e - cap),
                         "do no work in a fight frame beyond reading counters: count in place and show only when the player asks")
            else:
                rep.note(line)
            continue
        if caps is None:
            continue
        if a not in caps["every"]:
            if cur_e:
                rep.note("V33 %s per event (NOT JUDGED, NEEDS_HER_DECISION: %s has no value on %s, which had no such addon): costliest single "
                         "fight frame %.0f instructions (%s)" % (name, name, rec["source"], cur_e, seg_e))
            continue
        cap_e, cap_s = caps["every"][a], caps["steady"][a]
        line = ("V33 %s per event: costliest single fight frame %.0f instructions in every fight (%s; cap %.0f = %s's) and %.0f in the steady "
                "fights 2-3 (%s; cap %.0f); %s if every frame cost that. Caps %s" % (
                    name, cur_e, seg_e or "none", cap_e, rec["source"], cur_s, seg_s or "none", cap_s,
                    ("%.1f%%" % pct(cur_e)) if pct else "(no V33 calibration)", how))
        if cur_e > cap_e or cur_s > cap_s:
            rep.fail(a, "V33 per-event limit: %s's costliest single fight frame is heavier than on %s (SD-66, her answer \"No worse than "
                     "ad60a51\")" % (name, rec["source"]), line + "; over by %.0f (every fight) and %.0f (steady)" % (cur_e - cap_e, cur_s - cap_s),
                     "make the costliest pass in a fight frame no heavier than %s's: spread a full re-check over frames or re-check only what "
                     "changed" % rec["source"])
        else:
            rep.note(line)
        # (round 9, SD-77 "Route + narrow (Recommended)": "boss pulls (encounterID) and combat end") the frames right after each moment
        for mname, what in MOMENTS:
            v, sg = moment_peak(data, CAP_EVERY, mname, a)
            if not sg:
                continue
            mline = "V33 %s per event, %s: costliest frame %.0f instructions (%s; cap %.0f = %s's)" % (name, what, v, sg, cap_e, rec["source"])
            if v > cap_e:
                rep.fail(a, "V33 per-event limit (SD-77): %s's costliest frame at %s is heavier than %s's costliest fight frame" % (
                    name, what, rec["source"]), mline + "; over by %.0f" % (v - cap_e),
                    "re-check only the rules the changed fact concerns (SD-77), not every rule")
            else:
                rep.note(mline)


def v33(data, rep):
    base, how = baseline()
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
            how += "; recorded for this scenario %s: %.0f" % (V33_RECORDED["when"], V33_RECORDED["rules"])
    elif V33_RECORDED["stamp"] == stamp and V33_RECORDED["rules"]:
        b_rules, b_core, b_opt = V33_RECORDED["rules"], V33_RECORDED["core"], V33_RECORDED["options"]
        rep.warn("tests/gate_common.py (V33 calibration)", "%s could not be played here (%s); the budget uses the calibration recorded %s "
                 "for this same scenario" % (GC.V33_BASE_COMMIT, how, V33_RECORDED["when"]))
        how = "recorded %s for scenario %s" % (V33_RECORDED["when"], stamp)
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
    return pct


def judge(data, rep):
    """Every check of this gate on one variant's result."""
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

    # ---- P1 OnUpdate scripts running while nothing visible changes (round 9, SD-79: per frame they run on, "per display") -----------
    p1(data, rep)

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
    # ---- P2 (round 7, round 8) her pace for every re-check path ------------------------------------------------------------------
    pace(data, rep)
    # ---- P4 (round 8) a new function per timer call ---------------------------------------------------------------------------
    closures(data, rep)

    # ---- V33 work budget per addon ------------------------------------------------------------------------------------------------
    pct = v33(data, rep)
    event_caps(data, rep, baseline()[0], GC.scenario_stamp(), pct)
    # ---- (round 9, SD-77) what is drawn after each load-fact change, against a full re-check ---------------------------------------
    drawn(data, rep)

    memory(data, rep)


# ---------------------------------------------------------------------------------------------------------------------------------
# P1 and the display effects loop (round 9; REQUEST-LOG A23 SD-79, her answer "<=30/s, stop if idle (Recommended)": "effects loop at
# most 30/s per display while a run changes something; the loop stops when a run changes nothing (exact-value compare); the gate gets an
# effects scenario and counts per display"). Every frame script's runs are kept per frame it runs on (gate_common.py ownNote; before
# round 9 the effects loop, Visual.lua FxOnUpdate, was summed over every display). Judged after the window closed (the fights, the
# effects part at 144 frames a second, idle) and, for displays, also in the preview and the mover before the close:
#   P1 FAIL     a frame that is not a display (the engine's next-frame script): its script runs in a 2-second window in which it changes
#               nothing on screen (as before round 9, now per frame);
#   SD-79 FAIL  a display's effects loop runs more than 30 times in any sliding second (a real run: one that does at least FX_SKIP Lua
#               instructions; the throttle's early return on the frames between runs is a skip);
#   SD-79 FAIL  a display's effects loop runs while it changes nothing on screen, beyond the single run that finds there is nothing
#               left to animate (counted again from 0 when the loop is set on the display again, or when a run changes something).
# (round 9 repair 1) A run that changes the screen is always a run, however few instructions it takes (before, a loop that changed the
# screen on every frame in under FX_SKIP instructions was all skips and never judged). Also:
#   SD-79 FAIL  a display's frame script stays set while it only skips (no run that changes something or does real work) for more than
#               a second of frames: the loop is idle and has not stopped (before, such a script was all skips and never judged);
#   SD-79 FAIL  a display redrawn more than 30 times in any second by its frame script and the redraw timers (gate_common.py REDRAWS:
#               Visual.lua's wake, which draws a display at the next moment its tenths, flash threshold or wipe pixel changes) together,
#               counted per display (SD-76 asked "whether 10/s covers screen redraws"; her answer SD-79: at most 30 a second per display);
#   SD-79 FAIL  a redraw timer that runs twice in a row changing nothing on screen (it did not stop when nothing was left to draw).
# A redraw timer is judged per display instead of P2's 10 a second per callback only while every run of it changes nothing outside the
# displays and it runs no re-check pass (REPASSES: a pass stays at 10 a second whatever drives it, SD-78); otherwise P2 judges it as any
# timer callback.
# The 10-a-second limit stays on every re-check path (P2 below; SD-78 "Per pass (Recommended)"); the display effects loop is held to
# 30 a second per display instead (SD-79), and a re-check pass it runs still counts for that pass.
# ---------------------------------------------------------------------------------------------------------------------------------
def fx_judged(ph):
    return AFTER(ph) or ph in FX_PHASES


def p1(data, rep):
    """P1 per frame (non-display frames) and the SD-79 checks per display (see above)."""
    owners = [dict(o, n=i) for i, o in enumerate(vals(data.get("owners")), 1) if isinstance(o, dict)]   # (n: the order the frames were first seen)
    ou = (data.get("stats") or {}).get("ou") or {}
    ran_after = sum(sum(p.get("n", 0) for ph, p in (s.get("byPhase") or {}).items() if AFTER(ph)) for s in ou.values())
    if ran_after and not owners:
        rep.fail("tests/gate_common.py (the scenario)", "frame scripts ran after the close but the result has no record per frame (ownNote): P1 and "
                 "the per-display effects checks cannot be judged", "%d frame-script runs after the close" % ran_after, "")
        return
    fx_n = int(data.get("fxN") or 30)
    # P1 for frames that are not displays: per frame, every invocation a run
    groups = collections.OrderedDict()
    for o in owners:
        if o.get("display"):
            continue
        wins = [w for w in vals(o.get("wins")) if AFTER(w.get("phase", ""))]
        bad = [w for w in wins if w.get("runs", 0) > 0 and w.get("vis", 0) == 0]
        if bad:
            groups.setdefault(o.get("src") or "?", []).append((o, bad, wins))
    for src, lst in groups.items():
        runs = sum(o.get("runs", 0) for o, _, _ in lst)
        idle = sum(o.get("idle", 0) for o, _, _ in lst)
        nbad = sum(len(b) for _, b, _ in lst)
        nwin = sum(len(w) for _, _, w in lst)
        st = ou.get(src) or {}
        idle_runs = sum(p.get("n", 0) for ph, p in (st.get("byPhase") or {}).items() if ph in IDLE)
        rep.fail(src, "P1 an OnUpdate script runs while it changes nothing on screen (a running loop), counted per frame it runs on",
                 "%d frame(s); %d runs with the window closed, %d of them with no visible change; %d of %d 2-second windows changed nothing "
                 "(%d runs in the 30 s idle with nothing on screen changing); %s allocated; %d Lua instructions per run on average" % (
                     len(lst), runs, idle, nbad, nwin, idle_runs, kb(st.get("bytes", 0)), st.get("ins", 0) // max(1, st.get("n", 1))),
                 "run an OnUpdate only while something it draws is moving; hide its frame / SetScript(\"OnUpdate\", nil) otherwise, and do the "
                 "work in the events that change it (a stored expiry time for countdowns)")
    # SD-79 per display
    disp = [o for o in owners if o.get("display")]
    over, idle = collections.OrderedDict(), collections.OrderedDict()
    for o in disp:
        n_over = sum(int(v) for ph, v in (o.get("over") or {}).items() if fx_judged(ph))
        n_idle = sum(int(v) for ph, v in (o.get("idleOver") or {}).items() if fx_judged(ph))
        if n_over:
            over.setdefault(o.get("src") or "?", []).append((o, n_over))
        if n_idle:
            idle.setdefault(o.get("src") or "?", []).append((o, n_idle))

    def who(o):
        return "%r (frame %s)" % (o.get("rule"), o.get("n") or "?")
    for src, lst in over.items():
        rep.fail(src, "SD-79 a display's effects loop ran more than %d times within one second (her limit: at most 30 a second per display, "
                 "\"<=30/s, stop if idle\")" % fx_n,
                 "%d display(s); %s" % (len(lst), "; ".join("%s: %d run(s) found more than %d runs in the second up to them, most %d; first: %s" % (
                     who(o), n, fx_n, int(o.get("most") or 0), o.get("first")) for o, n in sorted(lst, key=lambda x: -x[1])[:6])),
                 "hold each display's effects runs to one per 1/30 s, counted from its last run")
    for src, lst in idle.items():
        rep.fail(src, "SD-79 / P1 a display's effects loop ran while it changed nothing on screen, beyond the single run that finds there is "
                 "nothing left to animate (her answer \"<=30/s, stop if idle\": the loop stops when a run changes nothing)",
                 "%d display(s); %s" % (len(lst), "; ".join("%s: %d such run(s) of %d (%d changed something; by phase %s); first: %s" % (
                     who(o), n, int(o.get("runs") or 0), int(o.get("changed") or 0),
                     ", ".join("%s %s" % (ph, v) for ph, v in sorted((o.get("idleOver") or {}).items()) if fx_judged(ph)), o.get("firstIdle"))
                     for o, n in sorted(lst, key=lambda x: -x[1])[:6])),
                 "take the frame script off when a run changes nothing (exact-value compare), and set it again at the next moment something "
                 "will change (the flash threshold, the next tenth, an aura change)")
    # (repair 1) a display's frame script set and only skipping for more than a second of frames: idle, not stopped
    waits = collections.OrderedDict()
    for o in disp:
        n_wait = sum(int(v) for ph, v in (o.get("waitOver") or {}).items() if fx_judged(ph))
        if n_wait:
            waits.setdefault(o.get("src") or "?", []).append((o, n_wait))
    for src, lst in waits.items():
        rep.fail(src, "SD-79 / P1 a display's frame script stays set while it changes nothing and does no work for more than a second "
                 "(her answer \"<=30/s, stop if idle\": the loop stops when there is nothing to animate; a script left set that returns at "
                 "once has not stopped)",
                 "%d display(s); %s" % (len(lst), "; ".join("%s: %d call(s) more than %s s of frames after its last run or after it was set "
                                                            "(%d runs, %d skips); first: %s" % (
                     who(o), n, data.get("fxWait") or 1, int(o.get("runs") or 0), int(o.get("skips") or 0), o.get("firstWait"))
                     for o, n in sorted(lst, key=lambda x: -x[1])[:6])),
                 "take the frame script off when there is nothing to animate, and set it again (or arm one timer) at the next moment "
                 "something will change")
    runs_by = collections.Counter()
    for o in disp:
        for ph, v in (o.get("runsBy") or {}).items():
            if fx_judged(ph):
                runs_by[ph.split(" ")[0]] += int(v)
    rep.note("display effects loop (SD-79), per display: %d display(s) ran it; real runs by part: %s; most runs within one second on one "
             "display: %d (limit %d; the effects part at %s frames a second); skips (the throttle's early return): %d" % (
                 len(disp), ", ".join("%s %d" % kv for kv in sorted(runs_by.items())) or "none",
                 max([int(o.get("most") or 0) for o in disp] + [0]), fx_n, data.get("fpsFx"), sum(int(o.get("skips") or 0) for o in disp)))
    redraw(data, rep, owners)
    tr = sum(int((d.get("byPhase") or {}).get("effects") or 0) for t in vals(data.get("fxRedraw") or {}) if isinstance(t, dict)
             for d in vals(t.get("disp") or {}) if isinstance(d, dict))
    if not runs_by.get("effects") and not tr:
        rep.warn("tests/gate_common.py (the effects part)", "the display effects loop did not run in the effects part, so SD-79 (at most 30 a "
                 "second per display, stop if idle) was not exercised there", "effect displays shown: %s of %s" % (data.get("fxShown"), data.get("fxGained")),
                 "if the effects no longer use a frame script, nothing is left to judge; otherwise the scenario is not reaching them")


def most_in_second(times):
    """The most entries in any sliding second (t - 1, t] of a list of moments (seconds; FX_EPS for the float error of 1/144 s frames)."""
    ts = sorted(float(t) for t in times)
    best, j = 0, 0
    for i, t in enumerate(ts):
        while ts[j] <= t - 1 + 1e-6:
            j += 1
        best = max(best, i - j + 1)
    return best


def redraw_lines(data):
    """The listed redraw timers the play kept ({"file:line": (name, what)}): as the play recorded them (gate_common.py run_scenario),
    else this checkout's REDRAWS."""
    rl = data.get("redrawLines")
    if isinstance(rl, dict):
        return {k: tuple(vals(v)) for k, v in rl.items()}
    return GC.redraw_lines()[0]


def redraw_exempt(data):
    """{callback src: why} for the listed redraw timers (gate_common.py REDRAWS) that P2 does not judge per callback: kept in the tree
    play (fxRedraw), no change outside the displays, and no re-check pass (REPASSES) run by them."""
    fr = data.get("fxRedraw")
    if not isinstance(fr, dict):
        return {}
    lines = redraw_lines(data)
    passes = set()
    try:
        passes = set(pass_lines(GC.Report("quiet")))
    except Exception:  # noqa: BLE001  (the pass list is judged in pace())
        passes = set()
    drives = set()
    for src, p in (data.get("paceAny") or {}).items():
        if src in passes:
            drives |= set((p.get("drivers") or {}).keys())
    out = {}
    for src in lines:
        t = fr.get(src)
        if isinstance(t, dict) and not int(t.get("outside") or 0) and src not in drives:
            out[src] = lines[src]
    return out


def redraw(data, rep, owners):
    """(round 9 repair 1) the listed redraw timers per display, with each display's frame-script runs (see above)."""
    fx_n = int(data.get("fxN") or 30)
    missing = GC.redraw_lines()[1]
    lines = redraw_lines(data)
    for m in missing:
        rep.fail("tests/gate_common.py (REDRAWS)", "the redraw timer %s named in REDRAWS is not defined: the list is out of date, so that "
                 "callback's redraws are not counted per display" % m, "REDRAWS", "name the callback as the file defines it now")
    fr = data.get("fxRedraw")
    if fr is None:
        if data.get("paceTree"):
            rep.fail("tests/gate_common.py (the scenario)", "the tree play has no record of the redraw timers (fxRedraw): their redraws "
                     "cannot be counted per display", "", "")
        return
    ftimes = collections.defaultdict(list)
    for o in owners:
        if o.get("display") and o.get("rule") is not None:
            ftimes[str(o.get("rule"))] += [float(t) for t in vals(o.get("times") or [])]
    for src in sorted(lines):
        t = fr.get(src)
        if not isinstance(t, dict):
            continue
        over = []
        for key, d in (t.get("disp") or {}).items():
            tt = [float(x) for x in vals((d or {}).get("times") or [])]
            both = most_in_second(tt + ftimes.get(key, []))
            if both > fx_n:
                over.append((key, both, most_in_second(tt), most_in_second(ftimes.get(key, []))))
        if over:
            over.sort(key=lambda x: -x[1])
            rep.fail(src, "SD-79 a display was redrawn more than %d times within one second by this redraw timer and its frame script "
                     "together (her limit: at most 30 a second per display, \"<=30/s, stop if idle\")" % fx_n,
                     "%d display(s); %s" % (len(over), "; ".join("%r: most %d in one second (this timer alone %d, its frame script alone %d)" % x
                                                               for x in over[:6])),
                     "draw each display at most once per 1/30 s, counting the timer's redraws and the frame script's runs together")
        n_idle = sum(int(v) for ph, v in (t.get("idleOver") or {}).items() if fx_judged(ph))
        if n_idle:
            rep.fail(src, "SD-79 a redraw timer ran twice or more in a row changing nothing on screen (her answer \"<=30/s, stop if idle\": "
                     "it stops when a run changes nothing)",
                     "%d such run(s) of %d (%d changed nothing); first: %s" % (n_idle, int(t.get("runs") or 0), int(t.get("idle") or 0),
                                                                            t.get("firstIdle")),
                     "arm the next wake only for a moment at which something drawn changes, and arm none when nothing is left")
        why = []
        if int(t.get("outside") or 0):
            why.append("%d change(s) outside the displays (first: %s)" % (int(t.get("outside")), t.get("firstOutside")))
        if src not in redraw_exempt(data) and not why:
            why.append("it runs a re-check pass (REPASSES)")
        disp_n = len(t.get("disp") or {})
        allm = [most_in_second([float(x) for x in vals((d or {}).get("times") or [])]) for d in vals(t.get("disp") or {}) if isinstance(d, dict)]
        rep.note("redraw timer %s (%s): %d run(s), %d changed nothing; %d display(s) redrawn, most redraws of one display within one second "
                 "%d (limit %d, with its frame script); %s" % (
                     src, lines[src][0], int(t.get("runs") or 0), int(t.get("idle") or 0), disp_n, max(allm + [0]), fx_n,
                     ("judged under P2 per callback (10 a second): " + "; ".join(why)) if why else
                     "judged per display (SD-79), not under P2's 10 a second per callback"))


# ---------------------------------------------------------------------------------------------------------------------------------
# P2 her pace (SD-61 "10/s for all, like EUI"; round 8, SD-66 her answer "1": "every re-check path at most 10 a second", the
# 11-in-a-second overshoot is a bug). Judged, in any sliding one-second window (the first second of a fight included), whatever it
# changed on screen; more than 10 runs is a violation:
#   - every timer callback and every frame script (OnUpdate) of XayaUI, counted over all its runs (also when another callback runs it);
#   - (round 8 repair) every re-check pass, counted whatever drives it: the gate notes every function a timer callback, frame script or
#     event handler enters (gate_common.py, in a second play of the scenario so the measured play's readings are untouched), and
#     REPASSES names the passes. In the engine one pass has several drivers (the routed pass runs from its
#     timer, from the next-frame script and from a settle; the every-live-rule pass and the settle likewise), so a pass driven by two
#     callbacks at 7.5 a second each runs 15 a second and fails here although neither callback is over 10.
# The work several different passes share (RunLists, the rule checks, the drawing) runs once per pass of each of them; her rule is per
# path, so it is not judged (her decision SD-66 "1": each path at most 10 a second); (round 8 repair 2) it is a WARNING marked
# NEEDS_HER_DECISION, since on the round 8 tree one rule's check runs 21 times a second over the passes together.
# (The round 8 first pass turned a frame script whose every run changed the screen into a WARNING; that was a choice she has not made
# and could hide a re-check that also redraws, so it is not built: such a run is a FAIL like any other, with "every run changed the
# screen" in its numbers. NEEDS_HER_DECISION, round 8 gate repair report.)
# ---------------------------------------------------------------------------------------------------------------------------------
REPASSES = {   # [addon file] = ((function name as written in the file, what it is), ...): the re-check passes, judged whatever drives them
    "XayaUI_Rules/Engine.lua": (("DoRouted", "the routed re-check pass"), ("DoAll", "the every-live-rule re-check pass"),
                                ("Settle", "the settle pass (every rule, or the load facts)"), ("OnWake", "the wake and poll pass")),
}


def source_text(f):
    """An addon file's text (this checkout), or None."""
    path = os.path.join(GC.ROOT, f)
    if not os.path.isfile(path):
        return None
    with open(path, encoding="utf-8", errors="replace") as fh:
        return fh.read()


def pass_lines(rep):
    """{"file:line": (name, what)} for REPASSES, the line being where the function is defined (as the gate keys functions); a name
    not found is a FAIL (the list is out of date, and that pass would be judged only through its callbacks)."""
    out = {}
    for f, names in sorted(REPASSES.items()):
        text = source_text(f)
        lines = text.split("\n") if text is not None else []
        for name, what in names:
            pat = re.compile(r"^\s*(?:local\s+)?(?:function\s+%s\s*\(|%s\s*=\s*function\s*\()" % (re.escape(name), re.escape(name)))
            hit = next((i + 1 for i, ln in enumerate(lines) if pat.search(ln)), None)
            if hit is None:
                rep.fail("tests/gate_performance_run.py (P2 pass list)", "the re-check pass %s (%s) is not defined in %s: the gate's list of "
                         "passes is out of date, so that pass is judged only through the callbacks that drive it" % (name, what, f),
                         "REPASSES[%r]" % f, "name the pass as the file defines it now in REPASSES")
                continue
            out["%s:%d" % (f, hit)] = (name, what)
    return out


def pace(data, rep):
    pace_n = data.get("paceN") or 10
    passes = pass_lines(rep)
    shared = []
    # (round 8 repair 2) each named pass on every one of its runs, whatever ran it: a timer callback, a frame script or an event handler
    # (data["paceAny"], the tree play's record of every function entered in any measured run); a result without it (no tree play) is
    # judged on the timer and frame-script runs only
    anyp = data.get("paceAny")
    seen = []
    for src in sorted(passes):
        p = (anyp if anyp is not None else (data.get("pace") or {})).get(src) or {}
        seen.append("%s %d" % (passes[src][0], int(p.get("most") or 0)))
        over = sum(n for ph, n in (p.get("over") or {}).items() if AFTER(ph))
        if not over:
            continue
        drivers = p.get("drivers") or {}
        first_sec = sum(n for ph, n in (p.get("firstSec") or {}).items() if AFTER(ph))
        numbers = ("%d run(s) found more than %d runs of this pass in the second up to them (%d of them in the first second of a fight); most "
                   "runs within one second: %d; first: %s; run by: %s" % (
                       over, pace_n, first_sec, int(p.get("most") or 0), p.get("first"),
                       ", ".join("%s (%d runs)" % (d, n) for d, n in sorted(drivers.items(), key=lambda kv: (-kv[1], kv[0])))))
        rep.fail(src, "P2 %s (%s) ran more than %d times within one second: faster than her pace for every re-check path (SD-61 \"10/s for "
                 "all\"; SD-66 \"1\": every re-check path at most 10 a second, the first second of a fight included), counted over every "
                 "callback, frame script and event handler that runs it" % (passes[src][1], passes[src][0], pace_n), numbers,
                 "hold the next run of this pass until a tenth of a second after its last run, counted from when it ran (not from when "
                 "it was armed) and over everything that runs it, and run it only when something it reads changed")
    if passes:
        rep.note("pace per re-check pass, most runs within one second over everything that runs it%s: %s" % (
            "" if anyp is not None else " (timer callbacks and frame scripts only: this result has no event call trees)", ", ".join(seen)))
    exempt = redraw_exempt(data)
    for src, p in sorted((data.get("pace") or {}).items()):
        if src in passes:
            continue   # (judged above, on every run)
        if src in exempt:
            continue   # (round 9 repair 1: a redraw timer, judged per display; see redraw())
        over = sum(n for ph, n in (p.get("over") or {}).items() if AFTER(ph))
        if not over:
            continue
        kind = p.get("kind") or "timer"
        drivers = p.get("drivers") or {}
        is_cb = (not drivers) or (src in drivers)
        if is_cb:
            label = "a frame script (OnUpdate)" if kind == "onupdate" else ("a timer callback" if kind == "timer" else "a callback")
        else:
            shared.append((p.get("most", 0), src, len(drivers)))
            continue
        quiet = sum(n for ph, n in (p.get("quiet") or {}).items() if AFTER(ph))
        allvis = sum(n for ph, n in (p.get("allVis") or {}).items() if AFTER(ph))
        first_sec = sum(n for ph, n in (p.get("firstSec") or {}).items() if AFTER(ph))
        numbers = ("%d run(s) found more than %d runs of this path in the second up to them (%d of them in the first second of a fight; %d in a "
                   "second with nothing on screen changed; %d in a second where every run changed the screen); most runs within one second: "
                   "%d; first: %s; run by: %s" % (
                       over, pace_n, first_sec, quiet, allvis, p.get("most", 0), p.get("first"),
                       ", ".join("%s (%d runs)" % (d, n) for d, n in sorted(drivers.items(), key=lambda kv: (-kv[1], kv[0])))))
        rep.fail(src, "P2 %s ran more than %d times within one second: faster than her pace for every re-check path (SD-61 \"10/s for all\"; "
                 "SD-66 \"1\": every re-check path at most 10 a second, the first second of a fight included)" % (label, pace_n), numbers,
                 "hold the next run of this path until a tenth of a second after its last run, counted from when it ran (not from when "
                 "it was armed) and over every callback that drives it, and run it only when something it reads changed")
    if shared:
        # (round 8 repair 2) a WARNING, not a note: the rule checks the passes share run more often than any one pass (on the round 8
        # tree, 21 a second: routed + every-live-rule + wake + settle); whether her 10/s bounds that total is hers to say
        shared.sort(key=lambda x: (-x[0], x[1]))
        rep.warn("tests/gate_performance_run.py (P2 shared work)", "P2 work shared by several paths ran more than %d times within one "
                 "second (report only: each path is held to %d, and her rule is per path, SD-66 \"1\")" % (pace_n, pace_n),
                 "%d function(s) ran more than %d times in one second as part of different passes or callbacks; most: %s" % (
                     len(shared), pace_n, ", ".join("%s %d (from %d callbacks)" % (s, m, d) for m, s, d in shared[:6])),
                 "NEEDS_HER_DECISION: whether 10 a second also bounds how often the work several paths share (one rule's check) runs "
                 "over all of them together")
    fp = data.get("filePace") or {}
    if fp:
        rep.note("pace, every callback of one file together (report only: her rule is per path, SD-66): " + ", ".join(
            "%s %d runs in a second at most" % (f, n) for f, n in sorted(fp.items(), key=lambda kv: -kv[1]) if n))


# ---------------------------------------------------------------------------------------------------------------------------------
# P4 (round 8; REQUEST-LOG SD-66 / SD-68, her answer "Fix gate + guard + /run test (Recommended)") the guard that keeps the gate's
# teeth now that the stand-in's own timer records are no longer billed to the addon: a timer call site that hands C_Timer a NEW
# function made from the same definition on a later call (a closure made per call), on the hot path (a storm event that fires every
# frame of a fight, a timer callback or a frame script, after the window closed), is a violation: that closure is Lua garbage per
# event in the game too, whatever the game's C_Timer does. (round 9, SD-82, her answer "FAIL everywhere (Recommended)") The same outside
# the hot path (a one-off change event) is a violation too (before round 9 a WARNING).
# ---------------------------------------------------------------------------------------------------------------------------------
def closures(data, rep):
    for site, g in sorted((data.get("timerFresh") or {}).items()):
        fresh, calls = g.get("fresh") or {}, g.get("calls") or {}
        hot, other = int(fresh.get("hot") or 0), int(fresh.get("other") or 0)
        numbers = "%d new function(s) on %d hot-path call(s), %d on %d other call(s) after the window closed; first: %s" % (
            hot, int(calls.get("hot") or 0), other, int(calls.get("other") or 0), g.get("example"))
        fix = ("pass one function made once (a file-level function) and keep what it needs in file-level state, with a pending flag so "
               "at most one timer of the kind is armed (as the engine's Kick does)")
        if hot:
            rep.fail(site, "P4 a new function per timer call on the hot path: this C_Timer call makes a closure each time it runs, in "
                     "handlers that run every frame of a fight (SD-68 guard)", numbers, fix)
        elif other:
            # (round 9, SD-82, her answer "FAIL everywhere (Recommended)": before, a WARNING outside the hot path)
            rep.fail(site, "P4 a new function per timer call (outside the hot path: a one-off change event; SD-82 \"FAIL everywhere\")",
                     numbers, fix)


# ---------------------------------------------------------------------------------------------------------------------------------
# (round 9; REQUEST-LOG A23 SD-77, her answer "Route + narrow (Recommended)": "at a load-fact change re-check only the affected rules,
# including combat-only drawing (Triggers.lua:878 absent rows, Visual.lua:2642-2644 out-of-combat opacity), boss pulls (encounterID) and
# combat end") the draw check (gate_common.py drawCheck, a play of its own with nothing measured): after each moment that changes load
# facts (mount, dismount, a group joined, a target, combat start, a boss pull, the boss down, combat end, the group left), what every
# display shows is compared with what it shows after the engine re-checks every rule, in the same instant. FAIL: any display that differs
# (a narrowed re-check missed a rule); FAIL: the full re-check did not run (the check proves nothing); FAIL: the scenario's rules that
# test the narrowing (PROFILE_LUA 6c) did not change at their moment (the target debuffs that must be absent shown out of combat and not
# in it, the out-of-combat opacity 0.5 out of combat and 1 in it, the boss rules shown only during the boss), so a narrowing that missed
# them would not show here.
# ---------------------------------------------------------------------------------------------------------------------------------
DRAW_LABELS = ("mounted", "dismounted", "group joined", "target picked", "combat start", "boss pull", "boss down", "combat end",
               "group left, target dropped")


def drawn(data, rep):
    checks = [c for c in vals(data.get("drawCheck")) if isinstance(c, dict)]
    if data.get("drawCheck") is None:
        if data.get("paceTree"):
            rep.fail("tests/gate_common.py (the draw play)", "the result has no draw check although the gate played its other plays", "", "")
        else:
            rep.note("draw check (SD-77) not played: this result has no second play (XUI_GATE_NOTREE / XUI_GATE_NOHOOK)")
        return
    if int(data.get("drawErrors") or 0):
        rep.fail("tests/gate_common.py (the draw play)", "a Lua error in the draw play", "; ".join(vals(data.get("drawErrorText")))[:400], "")
    labels = collections.Counter(c.get("label") for c in checks)
    missing = [l for l in DRAW_LABELS if labels.get(l, 0) < 3]
    if missing:
        rep.fail("tests/gate_common.py (the draw play)", "the draw check did not run at every moment of the three cycles", "missing: %s; ran: %s" % (
            missing, dict(labels)), "")
    notran = [c for c in checks if not c.get("ran")]
    if notran:
        rep.fail("tests/gate_common.py (the draw play)", "the full re-check the draw check compares with did not run (Engine.lua ns.EngineStats.settle did "
                 "not move after ns.MarkDirty), so these checks prove nothing", "; ".join("%s (%s)" % (c.get("label"), c.get("phase")) for c in notran[:6]), "")
    bad = [c for c in checks if int(c.get("ndiff") or 0) > 0]
    for c in bad:
        rep.fail("XayaUI_Rules (what is drawn after %s)" % c.get("label"),
                 "SD-77: after %s (%s, %s) %d display(s) show something other than what a full re-check of every rule shows: the narrowed "
                 "re-check missed a rule whose answer or drawing reads the changed fact" % (
                     c.get("label"), c.get("phase"), "in combat" if c.get("combat") else "out of combat", int(c.get("ndiff") or 0)),
                 "; ".join(vals(c.get("diffs")))[:900],
                 "re-check every rule whose answer or drawing reads the fact that changed (SD-77 conditions 2 and 3)")

    def grp(label, cyc_phase=None):
        out = [c.get("groups") or {} for c in checks if c.get("label") == label]
        return out
    # the scenario's own rules must change at their moments (else the draw check cannot see a narrowing that misses them)
    cov = []
    for cs, ce in zip(grp("combat start"), grp("combat end")):
        a_in, a_out = (cs.get("Absent") or {}).get("shown"), (ce.get("Absent") or {}).get("shown")
        o_in, o_out = (cs.get("Ooc") or {}).get("alpha"), (ce.get("Ooc") or {}).get("alpha")
        cov.append(bool(a_out) and a_in == 0 and o_in and o_out and set(o_in.split(",")) == {"1"} and set(o_out.split(",")) == {"0.5"})
    for bp, bd in zip(grp("boss pull"), grp("boss down")):
        cov.append(bool((bp.get("Boss") or {}).get("shown")) and (bd.get("Boss") or {}).get("shown") == 0)
    if len(cov) < 6 or not all(cov):
        rep.fail("tests/gate_common.py (the draw play)", "the rules that test the narrowed re-check did not change at their moments (target debuffs "
                 "that must be absent: shown out of combat, not in combat; out-of-combat opacity: 0.5 out of combat, 1 in combat; boss rules: "
                 "shown only during the boss), so a narrowing that missed them would not show",
                 "combat start %s; combat end %s; boss pull %s; boss down %s" % (grp("combat start")[:1], grp("combat end")[:1], grp("boss pull")[:1],
                                                                                 grp("boss down")[:1]), "")
    rep.note("draw check (SD-77): %d moment(s) compared with a full re-check of every rule (%d displays and aura groups each), %d differ; at combat "
             "start the absent target debuffs shown %s (out of combat %s), out-of-combat opacity %s (out of combat %s); at the boss pull the boss "
             "rules shown %s" % (
                 len(checks), max([int(c.get("n") or 0) for c in checks] + [0]), len(bad),
                 ((grp("combat start") or [{}])[0].get("Absent") or {}).get("shown"), ((grp("combat end") or [{}])[0].get("Absent") or {}).get("shown"),
                 ((grp("combat start") or [{}])[0].get("Ooc") or {}).get("alpha"), ((grp("combat end") or [{}])[0].get("Ooc") or {}).get("alpha"),
                 ((grp("boss pull") or [{}])[0].get("Boss") or {}).get("shown")))


# ---------------------------------------------------------------------------------------------------------------------------------
# Memory budget (REQUEST-LOG A23 SD-38 / SD-41 "measure first, then set"; SD-66, her answer "Today +15%, tighten later (Recommended)"):
# the cap is the round 7 reading plus 15%: Lua memory after a full collection at the end of cycle 3 was 34,747.6 KB, so
# 34,747.6 KB x 1.15 = 39,959.74 KB, kept as 39,959.7 KB. Judged on every reading after a full collection at the end of a gate cycle
# (cycles 1, 2, 3) and after the 30 s idle; any reading above the cap is a violation. To be lowered as cuts land ("tighten later").
# The reading is the whole Lua state of the stand-in (the addons, the stand-in game and the gate's own records), as in round 7.
# ---------------------------------------------------------------------------------------------------------------------------------
MEM_BASE_KB, MEM_FACTOR = 34747.6, 1.15
MEM_CAP_KB = round(MEM_BASE_KB * MEM_FACTOR, 1)   # 39959.7


def memory(data, rep):
    mem = [m for m in vals(data.get("mem")) if isinstance(m, (int, float))]
    end = data.get("memEnd")
    readings = [("end of cycle %d" % (i + 1), m) for i, m in enumerate(mem)] + ([("after 30 s idle", end)] if isinstance(end, (int, float)) else [])
    if len(mem) < 3:
        rep.fail("tests/gate_common.py (the scenario)", "the memory budget has no reading for each of the three cycles", "readings: %s" % mem, "")
    cap_txt = "cap %s KB = %s KB x %.2f (SD-66 \"Today +15%%, tighten later\")" % ("{:,.1f}".format(MEM_CAP_KB), "{:,.1f}".format(MEM_BASE_KB), MEM_FACTOR)
    over = [(w, m) for w, m in readings if m > MEM_CAP_KB]
    all_txt = "; ".join("%s %s KB" % (w, "{:,.1f}".format(m)) for w, m in readings)
    if over:
        rep.fail("(whole addon set)", "memory budget: Lua memory after a full collection is above her cap (%s)" % cap_txt,
                 "%s; above the cap: %s" % (all_txt, "; ".join("%s by %s KB" % (w, "{:,.1f}".format(m - MEM_CAP_KB)) for w, m in over)),
                 "find what holds the memory (the per-cycle growth below, a /xui debug memory report in game) and cut it")
    else:
        rep.note("memory budget: %s; %s; headroom %s KB" % (cap_txt, all_txt, "{:,.1f}".format(MEM_CAP_KB - max([m for _, m in readings] + [0]))))
    # (round 9; round 8 engine-core handoff: the growth WARNING measured the gate's own per-cycle records: ST.cyc snapshots, BUD
    # segments, PACE rings, TIMERS_SEEN, OUT.checkpoints and mouseCombat, the stand-in's W.sounds) the growth per cycle is read in the
    # memory play (gate_common.py CFG.memplay: no instruments, nothing of the gate's kept per cycle, the stand-in's list of sounds played
    # emptied before each reading), so it is the addons' own (with the stand-in's records of the frames they made). The cap above is
    # still judged on the measured play's whole-state readings, as when it was set (SD-66).
    ma = data.get("memAddons") or {}
    mm = [m for m in vals(ma.get("mem")) if isinstance(m, (int, float))]
    if len(mm) >= 3:
        d1, d2 = mm[1] - mm[0], mm[2] - mm[1]
        txt = ("the addons' own Lua memory (the memory play) after a full collection at the end of cycles 1, 2, 3: %s, %s, %s (+%s, +%s per "
               "cycle); after the effects part and 30 s idle: %s" % (kb(mm[0] * 1024), kb(mm[1] * 1024), kb(mm[2] * 1024), kb(d1 * 1024),
                                                                     kb(d2 * 1024), kb((ma.get("memEnd") or 0) * 1024)))
        if len(mem) >= 3:
            g1, g2 = mem[1] - mem[0], mem[2] - mem[1]
            txt += ("; the measured play, whole Lua state with the gate's records: %s, %s, %s (+%s, +%s per cycle), so the gate's own records "
                    "and the stand-in's sound list grew by %s and %s" % (kb(mem[0] * 1024), kb(mem[1] * 1024), kb(mem[2] * 1024), kb(g1 * 1024),
                                                                         kb(g2 * 1024), kb((g1 - d1) * 1024), kb((g2 - d2) * 1024)))
        if int(ma.get("errors") or 0):
            rep.fail("tests/gate_common.py (the memory play)", "a Lua error in the memory play", "errors: %s" % ma.get("errors"), "")
        if d1 > 16 and d2 > 16:
            rep.warn("(whole addon set)", "the addons' Lua memory grows every cycle on identical input (a leak or an unbounded cache)", txt,
                     "find the table that grows (a /xui debug memory report in game)")
        else:
            rep.note(txt)
    elif len(mem) >= 3:
        d1, d2 = mem[1] - mem[0], mem[2] - mem[1]
        if data.get("paceTree"):
            rep.fail("tests/gate_common.py (the memory play)", "the result has no memory play although the gate played its other plays", "", "")
        txt = ("Lua memory after a full collection at the end of cycles 1, 2, 3: %s, %s, %s (+%s, +%s per cycle); after 30 s idle: %s (no memory "
               "play: these include the gate's own per-cycle records)" % (kb(mem[0] * 1024), kb(mem[1] * 1024), kb(mem[2] * 1024), kb(d1 * 1024),
                                                                         kb(d2 * 1024), kb((end or 0) * 1024)))
        if d1 > 16 and d2 > 16:
            rep.warn("(whole addon set)", "Lua memory grows every cycle on identical input (a leak or an unbounded cache); includes the gate's own "
                     "per-cycle records", txt, "find the table that grows (a /xui debug memory report in game)")
        else:
            rep.note(txt)


class Tagged(object):
    """A Report seen through a variant's name: every finding of the "debug" variant says which variant it came from."""

    def __init__(self, rep, tag):
        self.rep, self.tag = rep, tag

    def fail(self, where, what, numbers, fix):
        self.rep.fail(self.tag + where, what, numbers, fix)

    def warn(self, where, what, numbers="", fix=""):
        self.rep.warn(self.tag + where, what, numbers, fix)

    def note(self, text):
        self.rep.note(self.tag + text)


def main():
    rep = GC.Report(GATE)
    data, secs, cached = GC.result()
    rep.note("variant \"default\" (Advanced Debugging off, XayaUI_Debug switched on in the AddOns list and not loaded: V34)")
    judge(data, rep)
    # (round 8; round 7 review: the gate never loaded XayaUI_Debug, and every install from before round 7 saved Advanced Debugging on,
    # hers included, SD-64) the same scenario with Advanced Debugging on: XayaUI_Debug loaded, judged by every check above
    tag = "[Advanced Debugging on] "
    if not os.path.isdir(os.path.join(GC.ROOT, GC.DEBUG_ADDON)):
        # (an older build played for the calibration or a teeth proof: it has no debug addon to load, so there is nothing to measure)
        rep.note(tag + "variant \"debug\" not played: this checkout has no %s folder" % GC.DEBUG_ADDON)
        return rep.show(data, secs, cached)
    ddata, dsecs, dcached = GC.result("debug")
    rep.note(tag + "variant \"debug\": the same scenario with Settings > Debugging > Advanced Debugging saved on; XayaUI_Debug loaded: %s" %
             ddata.get("debugLoaded"))
    judge(ddata, Tagged(rep, tag))
    return rep.show(data, (secs or 0) + (dsecs or 0), cached and dcached)


if __name__ == "__main__":
    sys.exit(main())
