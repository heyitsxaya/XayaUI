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
           callbacks is one path; work several passes share is a WARNING, not judged (her rule is per path: SD-78 "Per pass (Recommended)");
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
           boss pull, the boss down and combat end (SD-77); XayaUI_Debug at most 600 (SD-81 "600, same as core"); (round 10) in both
           variants XayaUI_Bonus_StatCalculator at most 600 (SD-112) and XayaUI_Bonus at most 600 (SD-117), every fight frame and each of
           those moments on its own line (her install opens the Stat Calculator's panel before every fight, so its combat-start close
           is measured).
           (round 11b; REQUEST-LOG SD-120 "yes", SD-126 "Key only, raids in smaller tests (Recommended)") judged on the key fight
           (tests/gate_common.py: the cycles inside a Mythic+ key, hidden aura and cooldown data in the fights and between pulls); the
           calibration (V33_RECORDED, V33_EVENT_CAPS) is ad60a051 played in the same key fight, and a calibration play that raised a Lua
           error is refused (build spec 4.4.3); XayaUI_Debug is also judged when the run logger alone loaded it (SD-149); the stand-in's
           own share of the handlers' work (secret.lua's shells, the API guard, the aura-access check: C in the game) is printed for both
           builds with their wall-clock time, and a readout that moves more than 2% without it FAILs (build spec 4.4.5).
           (round 11b final fix 2) the three addons held to her own fixed 600 (XayaUI_Debug, XayaUI_Bonus_StatCalculator, XayaUI_Bonus)
           are counted exactly, one instruction at a time, without the gate's own instructions in the measuring window (gate_common.py
           KF.EXACT, KF.OVER); the addons judged against ad60a051's readings stay counted in 100-instruction steps, as their caps were.
  DRAW FAIL (round 9, SD-77 "Route + narrow") after each load-fact change a display shows something other than a full re-check of every
           rule shows (gate_common.py drawCheck).
  MEM FAIL (round 8, SD-66 "Today +15%, tighten later") Lua memory after a full collection at the end of any cycle (or after the idle)
           above 34,747.6 KB x 1.15 = 39,959.7 KB; the growth per cycle is still reported (WARNING when it grows every cycle; round 9: read in
           the memory play, so it is the addons' own, not the gate's records). (round 11b final fix 2) The cap is judged on the memory play
           too (the addons and the stand-in, without the gate's own records); the measured play's whole state is printed beside it.
Every check runs on both variants of the scenario (Advanced Debugging off and on; findings of the second are marked so). (round 10,
SD-98) XayaUI_Bonus and XayaUI_Bonus_StatCalculator are switched on in the AddOns list in both: a fresh install ("default") has the Stat
Calculator off (never loaded), hers ("debug") has it on; the windows she opens herself (the "windows" part: the Calculator keypad, the
Stat Calculator on its own and docked) are judged by gate_mouse and gate_keyboard (SD-99), and here only as she has them open (like the
settings window, the P-checks start again once they are closed); the memory cap stays 39,959.7 KB (SD-66).
Measuring limits (V25; UNVERIFIED IN GAME): instructions are Lua VM instructions in Lua 5.1 and include the stand-in's own widget
methods (C in the game), so they overstate; allocation excludes the stand-in's widget methods and the gate's own measuring; the game's
aura / cooldown reads hand back a new table per call (as the game does), and that garbage counts as XayaUI's.
(round 11 repair) The V33 numbers stored in this file (V33_RECORDED, V33_EVENT_CAPS) are the calibration and are self-sufficient: a
checkout that cannot play ad60a051 (no git, a shallow or public clone) judges with them, as long as they were measured or confirmed in this
same scenario (gate_common.scenario_stamp()) and stand-in (standin_stamp(): tests/harness world.lua, loader.lua, savedvars.lua). Playing
ad60a051 now, where git has it, only cross-checks them. A record for another scenario, or one from another stand-in that cannot be
cross-checked here, is a FAIL that says MISSING INPUT (record_check()); before, a replay turned a stale record into a WARNING and the gate
passed only where git had ad60a051. The last line counts the checks run ("gate_performance: N checks, M failed (...)  FAILS: K": N = the
named checks of judge() for each variant, M = those with a violation, K = the violations; Checks, count_line()), as tests/run_all.py reads it.
Run: python3 tests/gate_performance_run.py  (Lua 5.1 via lupa; about two minutes, or seconds when the shared result is cached; the V33
calibration plays ad60a051 once more, from git, about three minutes the first time, then cached).
Proof that the round-7 checks have teeth: tests/v33_budget_teeth_run.py."""
import collections, hashlib, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gate_common as GC  # noqa: E402

GATE = "gate_performance"
# (round 11b) "key start" / "key end": the loading screen into the dungeon and the key's start, and the key's end and the way out (the
# window is closed there too, so every P-check judges them)
AFTER = lambda p: p in ("closed", "effects", "key start", "key end") or p.startswith("busy") or p.startswith("idle")   # noqa: E731
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
# (bundle 1 round 10, 2026-11-16) the scenario changed (stamp 6e573efe8b12 -> f23dc769159a: XayaUI_Bonus and XayaUI_Bonus_StatCalculator
# switched on in every play (SD-98; ad60a051 has neither folder, so nothing of them loads there), the game's character window, the
# windows she opens (the "windows" part; her install's Stat Calculator opened before each fight), five game-played sound rules that follow
# combat and boss encounters (PROFILE_LUA 4b; the list stays at 300 entries: five fewer filler cues), and the sound copies counted), so
# ad60a051 was played twice with this gate (tree_copy / git archive of the repository's own ad60a051, XUI_GATE_NOCACHE=1, 91 s and 119 s):
# XayaUI Rules 386,418,300 / 900 = 429,353.7 per fight frame (second play 386,422,000 / 900 = 429,357.8), core 1,000 / 900 = 1.1 (both
# plays), Options 0.0. Against the 6e573efe8b12 value: (429,353.7 - 425,173.3) / 425,173.3 = +0.98%.
# (round 11 repair, 2026-11-19) stamp f23dc769159a -> c0d0cfcb6da7 (another addon's blocked and forbidden actions in the fights, SD-139;
# see V33_EVENT_CAPS for the four plays, two of this scenario and two of the round-10 one, all on the current stand-in a8c536bf9194):
# XayaUI Rules per fight frame, new scenario 386,411,700 / 900 = 429,346.3 and 386,421,400 / 900 = 429,357.1; round-10 scenario
# 386,421,100 / 900 = 429,356.8 and 386,418,500 / 900 = 429,353.9. The scenario's own change: (429,346.3 + 429,357.1) / 2 - (429,356.8 +
# 429,353.9) / 2 = 429,351.7 - 429,355.35 = -3.65 = -0.0009%, inside the new scenario's own play-to-play spread (429,357.1 - 429,346.3 =
# 10.8): no measured change (ad60a051 has no Rules handler for either event), so Rules stays 429,353.7. XayaUI core: new 1,800 / 900 = 2.0
# and 1,600 / 900 = 1.8, round-10 scenario 1,000 / 900 = 1.1 and 900 / 900 = 1.0: +0.85 per frame in both pairs, far beyond its spread
# (0.1), a real change: ad60a051's core saves Advanced Debugging on by default (Core.lua:317) and so runs its DebugRecord.lua handler on
# each of the 12 blocked / forbidden actions of fights 2-3 (another addon's: it returns at the name check), about 700-800 instructions in
# all. Core is recorded as the first play, 2.0 (2.0 / (429,353.7 / 4) = 0.0019%: she read 0%, consistent). Options 0.0.
# (round 11 repair 1, 2026-11-19) stamp c0d0cfcb6da7 -> 969b7396b065 (the gate's world uses the stand-in's one aura container instead
# of its own copy, tests/gate_common.py GAME_LUA; see V33_EVENT_CAPS) and the stand-in's final round 11 world.lua (fingerprint
# e9492285889a, read the repair 1 way: standin_stamp()). ad60a051 played twice in each scenario on that same stand-in (XUI_GATE_NOCACHE=1,
# 89-93 s each). XayaUI Rules per fight frame: new scenario 386,420,500 / 900 = 429,356.1 and 386,422,400 / 900 = 429,358.2; the
# c0d0cfcb6da7 scenario 386,417,700 / 900 = 429,353.0 and 386,418,900 / 900 = 429,354.3. The scenario's own change: (429,356.1 +
# 429,358.2) / 2 - (429,353.0 + 429,354.3) / 2 = 429,357.15 - 429,353.65 = +3.5 = +0.0008%, inside the eight round 11 plays' own spread
# (the four above on a8c536bf9194 and these four: 429,346.3 to 429,358.2 = 11.9): no measured change (ad60a051 makes its aura containers
# at load, outside the fight frames: see V33_EVENT_CAPS), so Rules stays 429,353.7
# (against it the new plays read +2.4 and +4.5, +0.001%). XayaUI core: new 1,600 / 900 = 1.8 twice, c0d0cfcb6da7 1,800 / 900 = 2.0 and
# 1,700 / 900 = 1.9: (1,600 - 1,750) / 900 = -0.17 per frame, inside the spread of the six c0d0cfcb6da7 plays (1,600 to 1,800 = 0.22 per frame): stays 2.0 (informational
# only: the 'consistent' note of v33()). Options 0.0 in all four plays.
# (round 11 repair 2, 2026-11-19) stand-in e9492285889a -> 7b796e57e823, scenario unchanged (969b7396b065). Two things changed the
# fingerprint: (a) standin_stamp() now reads comments as Lua does (standin_code(); the line-based reading of repair 1 kept the
# fingerprint when a block was commented out with "--[[" ... "--]]"); the very stand-in measured above (its world.lua, loader.lua and
# savedvars.lua byte for byte) reads e9492285889a the old way and 44cc06a46f54 the new way, a new name for the same files; (b) the
# stand-in unit's round 11 repair 2 added to tests/harness/loader.lua a note of the error-record entries it hands each session from saved
# data (at load, outside the fight frames). So ad60a051 was played twice more on the live stand-in 7b796e57e823 in this scenario
# (XUI_GATE_NOCACHE=1, 92 s and 88 s): XayaUI Rules 386,417,100 / 900 = 429,352.3 and 386,416,100 / 900 = 429,351.2 per fight frame;
# against the repair 1 plays above (429,356.1 and 429,358.2): (429,352.3 + 429,351.2) / 2 - 429,357.15 = 429,351.75 - 429,357.15 = -5.4
# (-0.0013%), inside the plays' own spread (429,346.3 to 429,358.2 = 11.9, now ten plays): no measured change, Rules stays 429,353.7
# (the new plays read -1.4 and -2.5 against it). XayaUI core 1,600 / 900 = 1.8 and 1,800 / 900 = 2.0, the same spread: stays 2.0.
# Options 0.0 in both plays. Only the stand-in is stored.
# (round 11b, 2026-11-22; REQUEST-LOG SD-120 "yes", SD-126 "Key only, raids in smaller tests (Recommended)"; build spec 4.4.2) the
# hidden-data fight: stamp 969b7396b065 -> 035eb58d4b1d (the cycles inside a Mythic+ key, hidden payloads and the stand-in's own aura
# and cooldown reads, the key's boss 8 / 5 through the encounter driver, the run logger's question, OnCooldownDone in the gate's frames,
# the line hook off, S.onAlloc; tests/gate_common.py) and stand-in 7b796e57e823 -> a3bd67775e76 (round 11b's world.lua, loader.lua and
# secret.lua, and the API index's secrecy flags, now in the fingerprint: standin_stamp()). ad60a051 played twice in the key fight on that
# stand-in (XUI_GATE_NOCACHE=1, XUI_V33_SHAREPLAY=1: each play its measured play plus a tree play for the share; 688.6 s and 644.3 s, of
# which the tree plays 518.8 s and 494.5 s), 0 Lua errors in both (build spec 4.4.3; spec risk 6 did not happen). XayaUI Rules per fight
# frame (fights 2-3, 900 frames): 417,114,800 / 900 = 463,460.9 and 417,113,100 / 900 = 463,459.0; the second play is 1.9 per frame
# (0.0004%) from the first, inside the two-play rule (0.05%): the first play is recorded. Against the readable record above (429,353.7):
# 463,460.9 - 429,353.7 = +34,107.2 per frame = +7.94%, what the key fight measurably adds on ad60a051 (its restricted paths and the
# stand-in's hidden reads; the build spec's estimate for the restriction state alone was +9.3%). XayaUI core 1,400 / 900 = 1.56 in both
# plays (she read 0%: 1.56 / (463,460.9 / 4) = 0.0013%, consistent). Options 0 in both.
# "share" (build spec 4.4.5): the instructions ad60a051's XayaUI Rules handlers spend in the stand-in's own wrappers in the three fights
# (tests/gate_common.py KF.share: calls counted in the tree play, times each wrapper's instructions per call measured in the same play):
# secret.lua's shell 2,620,971 x 5 = 13,104,855, the widget guard 240,798 x 10 = 2,407,980, the refused aura-access check 8,382 x 51 =
# 427,482; 13,104,855 + 2,407,980 + 427,482 = 15,940,317 of 625,867,400 fight instructions = 2.5469% (the same calls in both plays:
# 625,863,000 in the second, 2.5469%), 0.025469 x 463,460.9 = 11,804 per fight frame.
# (round 11b final fix, 2026-11-22) stamp 035eb58d4b1d -> 4ba9a6ea1da1 and stand-in a3bd67775e76 -> 3fb6b9731c89. Why: the scenario's
# draw check names a cooldown that ended within one frame and a pace step before the reading as a late wake (KF.lateWake, not counted)
# and plays one readable fight after the key's end in the draw play only (absent target debuffs then change in the key); memNow compacts
# the stand-in's hidden-value registries before each whole-state reading (KF.S.compact); tests/harness/secret.lua gained S.compact (at
# a memory reading only, never in a handler). ad60a051 played twice more (XUI_GATE_NOCACHE=1, XUI_V33_SHAREPLAY=1; 675.0 s and 667.6 s,
# of which the tree plays 507.4 s and 504.3 s), 0 Lua errors in both. XayaUI Rules per fight frame (fights 2-3, 900 frames):
# 417,122,800 / 900 = 463,469.8 and 417,120,600 / 900 = 463,467.3; the second is 2.5 per frame (0.0005%) from the first, inside the
# two-play rule (0.05%): the first play is recorded. Against the 035eb58d4b1d record above (463,460.9): +8.9 per frame (+0.0019%), inside
# ad60a051's own spread (the measured play's frames are the same; the draw play's added fight is not a measured play). XayaUI core
# (1,000 + 900) / 900 = 2.11 and (900 + 500) / 900 = 1.56 (she read 0%: 2.11 / (463,469.8 / 4) = 0.0018%, consistent). Options 0 in both.
# "share": the same calls in both plays, shell 2,620,971 x 5 + widget guard 240,798 x 10 + refused aura-access check 8,382 x 51 =
# 13,104,855 + 2,407,980 + 427,482 = 15,940,317 of 625,872,100 fight instructions (625,874,100 in the second) = 2.5469%;
# 0.025469 x 463,469.8 = 11,804 per fight frame.
# (round 11b final fix, second record, 2026-11-22) stamp 4ba9a6ea1da1 -> 199c6009b355 (memNow collects before the registries are rebuilt,
# not only after: see memNow), stand-in unchanged (3fb6b9731c89). ad60a051 played twice more (641.6 s and 636.6 s, of which the tree
# plays 489.3 s and 493.8 s), 0 Lua errors in both. XayaUI Rules per fight frame: 417,119,100 / 900 = 463,465.7 and 417,119,700 / 900 =
# 463,466.3 (0.6 per frame apart, 0.0001%): the first play is recorded; against 4ba9a6ea1da1 (463,469.8): -4.1 (-0.0009%), inside the
# plays' own spread (the measured play's frames do not change with a memory reading). XayaUI core (800 + 700) / 900 = 1.67 and
# (900 + 1,000) / 900 = 2.11. Options 0. Share: the same calls, 15,940,317 of 625,873,600 (625,874,900 in the second) = 2.5469%;
# 0.025469 x 463,465.7 = 11,804 per fight frame.
# (round 11b final fix 2, 2026-11-23) stamp 199c6009b355 -> 4fe081a4e900 (the fixed-cap addons counted exactly, gate_common.py KF.EXACT:
# ad60a051 has none of them, so its plays count as before), stand-in unchanged (3fb6b9731c89). ad60a051 played twice more
# (XUI_GATE_NOCACHE=1, XUI_V33_SHAREPLAY=1; 642.3 s and 641.3 s, of which the tree plays 489.5 s and 490.2 s), 0 Lua errors in both.
# XayaUI Rules per fight frame: 417,120,900 / 900 = 463,467.7 and 417,118,000 / 900 = 463,464.4 (3.3 per frame apart, 0.0007%): the
# first play is recorded; against 199c6009b355 (463,465.7): +2.0 (+0.0004%), inside the plays' own spread. XayaUI core 1,500 / 900 = 1.67
# and 1,700 / 900 = 1.89. Options 0. Share: the same calls, 15,940,317 of 625,876,800 (625,865,600 in the second) = 2.5469%;
# 0.025469 x 463,467.7 = 11,804 per fight frame.
V33_RECORDED = {"stamp": "4fe081a4e900", "standin": "3fb6b9731c89", "rules": 463467.7, "core": 1.67, "options": 0.0,   # (900 fight frames)
                "when": "in bundle 1 round 11b final fix 2 (2026-11-23, ad60a051 played twice in the key fight, the first play; the "
                        "second 0.0007% from it)",
                "share": {"frac": 0.025469, "perFrame": 11804, "samples": 15940317, "total": 625876800,
                          "parts": "shell 2620971 x 5.0, widget guard 240798 x 10.0, aura access check (refused) 8382 x 51.0"}}
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
# (round 11b final fix 2) counted exactly (gate_common.py KF.EXACT): before, in the measured play's 100-instruction steps, the logger's
# costliest frame read 600 to 800 from one play to the next with the same code (its frames are several runs of about 20 to 190
# instructions, each read 0 or 100 per step, the gate's own pcall wrapper inside each), while one by one it was 593 with the wrapper.
DEBUG_EVENT_CAP = {"XayaUI_Debug": 600}
# (bundle 1 round 10) her fixed per-event caps for the Bonus Features addons folded into both variants (SD-98), judged in BOTH variants
# (a fresh install and hers) at every fight frame, the frames right after combat start, a boss pull, the boss down and combat end
# included, each also on its own line: XayaUI_Bonus_StatCalculator, REQUEST-LOG A23 SD-112, her answer "600, same as core
# (Recommended)" (its only fight work is closing its panel at combat start when it is open: the scenario opens it before every fight in
# her install); XayaUI_Bonus (its loader and the arithmetic Calculator, always read while Bonus is on), SD-117, her answer "600, same as
# core (Recommended)". Her numbers, fixed: not taken from ad60a051 (which had no Bonus) and not following core's cap if that is measured
# again. [addon] = (cap, request-log number, her answer)
BONUS_EVENT_CAPS = {"XayaUI_Bonus_StatCalculator": (600, "SD-112", "600, same as core (Recommended)"),
                    "XayaUI_Bonus": (600, "SD-117", "600, same as core (Recommended)")}
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
# (bundle 1 round 10, 2026-11-16) stamp 6e573efe8b12 -> f23dc769159a (see V33_RECORDED). ad60a051 played twice with this gate (tree_copy
# / git archive, XUI_GATE_NOCACHE=1), costliest single frame, fights 1 / 2 / 3, ends 1 / 2 / 3:
#   XayaUI Rules    run 1: 586,200 / 586,000 / 586,000, 583,900 / 583,700 / 583,600   run 2: 586,100 / 586,100 / 586,100, 583,900 / 583,800 / 583,900
#                   -> every 586,200 (run 1, fight 1), steady (fights 2-3, ends 2-3) 586,100 (run 2, fight 2); the frames after each
#                      moment (both runs, the higher): combat start 561,600, boss pull 586,200, boss down 579,200, combat end 583,900
#   XayaUI (core)   run 1: 400 / 500 / 500, 600 / 600 / 600                 run 2: 500 / 500 / 500, 600 / 500 / 600      -> 600, 600
#   XayaUI Options  0 everywhere                                                                                         -> 0
# The rule is unchanged (the higher reading of two plays of this scenario, both kept above; SD-66 "No worse than ad60a51"). Rules' caps
# 579,900 -> 586,200 (every: +6,300 = 6,300 / 579,900 = 1.09%) and 579,800 -> 586,100 (steady: +6,300 = 1.09%); core and Options
# unchanged. Bonus cannot be the cause: ad60a051 has no XayaUI_Bonus folder, so nothing of it loads in the plays the caps come from; the
# scenario played twice more on ad60a051 with only the five game-played sound rules of PROFILE_LUA 4b left out (stamp fee5aed7e287, the
# filler cues back in their place) reads Rules every 579,700 / 579,800 and steady 579,600 / 579,800 (run 1 / run 2): the round 9 caps
# 579,900 / 579,800 within one step of the 100-instruction hook. So the Bonus fold-in, the character window and the windows part change
# nothing of Rules' baseline, and the +6,300 is the five rules' own re-check work on ad60a051 (round 10 gate report).
# (round 11 repair, 2026-11-19) stamp f23dc769159a -> c0d0cfcb6da7: the fights play another addon's ADDON_ACTION_BLOCKED and
# ADDON_ACTION_FORBIDDEN once every 5 s each (tests/gate_common.py storm(); SD-139: XayaUI/DebugRecord.lua listens to both in every
# variant now, so their cost is measured in the same fight frames as everything else, against core's 600 cap). Also since round 10 the
# stand-in changed (tests/harness/world.lua: UnitAffectingCombat while PLAYER_REGEN_DISABLED is handled; stand-in a8c536bf9194, round
# 10's was 5aa34970409d). To keep the two apart, ad60a051 was played twice in each scenario on the SAME current stand-in (tree_copy /
# git archive, XUI_GATE_NOCACHE=1, 101-108 s each): the new scenario, and the round-10 scenario (this gate_common.py with only the
# blocked-action lines taken out: stamp f23dc769159a again). Costliest single frame, fights 1 / 2 / 3, ends 1 / 2 / 3:
#   new scenario c0d0cfcb6da7
#   XayaUI Rules    run 1: 586,400 / 586,200 / 586,100, 583,700 / 583,600 / 583,900   run 2: 586,400 / 585,900 / 586,500, 583,800 / 583,700 / 583,800
#                   -> every 586,400 / 586,500, steady 586,200 / 586,500; moments (higher of the runs): combat start 561,900, boss pull
#                      586,500, boss down 579,300, combat end 583,900
#   XayaUI (core)   run 1: 500 / 500 / 500, 600 / 600 / 500                 run 2: 500 / 500 / 500, 600 / 600 / 500      -> 600, 600
#                   (boss pull 100 in both runs, 0 in the round-10 scenario; INFERENCE: a blocked action lands in the frames after the pull)
#   XayaUI Options  0 everywhere                                                                                         -> 0
#   round-10 scenario f23dc769159a, the same stand-in
#   XayaUI Rules    run 1: 586,200 / 586,300 / 586,100, 583,700 / 583,800 / 583,700   run 2: 586,200 / 586,200 / 586,100, 583,700 / 583,800 / 583,900
#                   -> every 586,300 / 586,200, steady 586,300 / 586,200
#   XayaUI (core)   600, 600 in both runs; XayaUI Options 0
# The scenario's own change, measured (new against round-10 scenario, same stand-in, higher of two plays each): XayaUI Rules every
# 586,500 - 586,300 = +200, steady 586,500 - 586,300 = +200. That is inside the play-to-play spread of the new scenario itself (steady
# 586,500 - 586,200 = 300; this gate's documented spread is 300, V33_EVENT_CAPS_TOL below), so it is no measured change: ad60a051 has no
# XayaUI Rules handler for either event (git grep ad60a051: ADDON_ACTION_BLOCKED is registered only by XayaUI/DebugRecord.lua, core),
# and Rules' whole fight work agrees: (386,411,700 + 386,421,400) / 2 = 386,416,550 instructions in fights 2-3 against (386,421,100 +
# 386,418,500) / 2 = 386,419,800 (-3,250 = -0.0008%). The stand-in's own change, measured (round-10 scenario now against the stored
# round 10 caps): every 586,300 - 586,200 = +100, steady 586,300 - 586,100 = +200, inside the same spread. Core's per-event peak is 600
# in both scenarios. So no cap moves: only the stamp and the stand-in it was confirmed in are recorded (a cap may change only by what
# the scenario measurably adds; SD-66's rule, "No worse than ad60a51", is unchanged). Consequence, stated: a single play of ad60a051 in
# this scenario can read up to 586,500 (+300 = 0.05% above the every cap, +400 = 0.07% above the steady cap); the replay cross-check
# treats that as the same reading (V33_EVENT_CAPS_TOL), and bundle 1's costliest frame (391,300 in round 10) is far from either.
# "standin": tests/harness world.lua + loader.lua + savedvars.lua, the Lua the stand-in runs (standin_stamp() below): the record is
# self-sufficient only in the stand-in it was measured or confirmed in (see record_check()).
# (round 11 repair 1, 2026-11-19) stamp c0d0cfcb6da7 -> 969b7396b065, stand-in -> e9492285889a. Two changes since the record above:
# the stand-in's world.lua became the one definition of Blizzard's aura container (the stand-in unit, round 11 repair 1), and the gate's
# world stopped defining its own copy over it (tests/gate_common.py GAME_LUA: its copy rawset its own methods over the stand-in's and
# dropped any error in the addon's initializeFrame with pcall, so an addon error at that point could never reach the gate; the stand-in's
# container reports it as a Lua error; tests/fix_r11_standin_run.py A2). ad60a051 was played twice in each scenario on the SAME final
# stand-in (tree_copy / git archive, XUI_GATE_NOCACHE=1, 89-93 s each). Costliest single frame, fights 1 / 2 / 3, ends 1 / 2 / 3:
#   new scenario 969b7396b065
#   XayaUI Rules    run 1: 586,500 / 586,200 / 585,900, 583,600 / 583,800 / 583,900   run 2: 586,300 / 586,100 / 586,000, 584,000 / 583,900 / 583,900
#                   -> every 586,500 / 586,300, steady 586,200 / 586,100; moments (higher of the runs): combat start 561,700, boss pull
#                      586,500, boss down 579,400, combat end 584,000
#   XayaUI (core)   every 600 / 600, steady 600 / 600 (boss pull 100: a blocked action lands in the frames after the pull, as before)
#   XayaUI Options  0 everywhere
#   scenario c0d0cfcb6da7 (the record above), the same stand-in
#   XayaUI Rules    run 1: 586,900 / 585,700 / 585,900, 584,100 / 583,800 / 583,600   run 2: 586,400 / 586,200 / 586,000, 583,800 / 583,900 / 583,700
#                   -> every 586,900 / 586,400, steady 585,900 / 586,200
#   XayaUI (core)   600, 600 in both runs; XayaUI Options 0
# The scenario's own change, measured (new against c0d0cfcb6da7, same stand-in, higher of two plays each): XayaUI Rules every 586,500 -
# 586,900 = -400, steady 586,200 - 586,200 = 0; whole fight work (fights 2-3) (386,420,500 + 386,422,400) / 2 - (386,417,700 +
# 386,418,900) / 2 = 386,421,450 - 386,418,300 = +3,150 (+0.0008%). Both inside the play-to-play spread of ad60a051 on this stand-in
# (every 586,300 to 586,900 = 600 over the four plays; steady 585,900 to 586,200 = 300): no measured change. ad60a051 does make Blizzard
# aura containers (XayaUI_Rules/Combat/AuraDisplay.lua:672-711 at ad60a051: CreateFrame "CustomAuraContainerTemplate", AddAuraGroup with
# initializeFrame), but at load, outside the measured fight frames; INFERENCE: in the fights the container methods it calls are one-line
# Lua setters in both the gate's old copy and the stand-in's container, which the +3,150 (3.5 a frame) agrees with. The stand-in's
# own change (c0d0cfcb6da7 now against the plays recorded above on a8c536bf9194: every 586,900 against 586,500, steady 586,200 against
# 586,500) is inside the same spread. Core's per-event peak is 600 in all four plays. So no cap moves (a cap changes only by what the
# scenario measurably adds; SD-66 "No worse than ad60a51"): only the stamp and the stand-in are stored. Stated plainly: one play of
# ad60a051 can read up to 586,900 here, 700 (0.12%) above the every cap and up to 586,500 here, 400 (0.07%) above the steady cap; the
# replay cross-check treats that as the same reading (V33_EVENT_CAPS_TOL, 1%), and bundle 1's costliest frame (391,500 at combat end in
# the round 11a review) is far below both.
# (round 11 repair 2, 2026-11-19) stand-in e9492285889a -> 7b796e57e823 (why: V33_RECORDED above; e9492285889a is 44cc06a46f54 when
# read the new way). ad60a051 played twice on stand-in 7b796e57e823 in this scenario 969b7396b065. Costliest single frame, fights 1 / 2 /
# 3, ends 1 / 2 / 3:
#   XayaUI Rules    run 1: 586,300 / 586,100 / 586,000, 583,800 / 583,800 / 583,700   run 2: 586,200 / 586,000 / 586,100, 583,900 / 583,600 / 583,600
#                   -> every 586,300 / 586,200, steady 586,100 / 586,100; moments (higher of the runs): combat start 561,900, boss pull
#                      586,300, boss down 579,100, combat end 583,900
#   XayaUI (core)   every 600 / 600, steady 600 / 600; XayaUI Options 0 everywhere
# Against the repair 1 plays in this scenario (higher of two each): every 586,300 - 586,500 = -200, steady 586,100 - 586,200 = -100;
# against the stored caps: every 586,300 - 586,200 = +100 (0.02%), steady 586,100 - 586,100 = 0. All inside ad60a051's own
# play-to-play spread (every 586,200 to 586,900 = 700 over the six plays in this scenario and c0d0cfcb6da7; steady 585,900 to 586,200 =
# 300): no measured change, so no cap moves; only the stand-in is stored.
# (round 11b, 2026-11-22; SD-120, SD-126; build spec 4.4.4) the key fight (stamp 035eb58d4b1d, stand-in a3bd67775e76; see V33_RECORDED
# for the two plays). Only the XayaUI_Rules entries are re-recorded (two plays, the higher reading, the 1% tolerance kept). Costliest single
# frame, fights 1 / 2 / 3, ends 1 / 2 / 3:
#   XayaUI Rules    run 1: 601,500 / 652,800 / 625,300, 563,900 / 563,100 / 563,200   run 2: 601,500 / 653,000 / 625,700, 563,800 / 563,300 / 563,100
#                   -> every 652,800 / 653,000, steady (fights 2-3, ends 2-3) 652,800 / 653,000: the higher, 653,000, for both; moments (higher
#                      of the runs): combat start 653,000, boss pull 625,700, boss down 566,200, combat end 563,900
#   XayaUI (core)   every 600 / 700, steady 600 / 600 (run 2's 700 is end 1, the first combat end after login)
# Against the readable caps above: 653,000 - 586,200 = +66,800 (+11.4%) every, 653,000 - 586,100 = +66,900 steady: what the key fight
# adds to ad60a051's costliest frame (its combat start in fight 2, as before). Core's 600 is HELD, not re-measured (build spec 4.4.4:
# BONUS_EVENT_CAPS and SD-112 / SD-117 read "600, same as core"; whether core's 600 was first measured or set is not recorded): ad60a051
# reads 600 and 700 here, and this build's core reads 400 (combat end). Options 0 in both plays.
# (round 11b final fix, 2026-11-22) stamp 035eb58d4b1d -> 4ba9a6ea1da1, stand-in a3bd67775e76 -> 3fb6b9731c89 (why: V33_RECORDED above).
# ad60a051 played twice more. Costliest single frame, fights 1 / 2 / 3, ends 1 / 2 / 3:
#   XayaUI Rules    run 1: 601,500 / 653,400 / 625,600, 564,000 / 563,200 / 563,200   run 2: 601,400 / 652,900 / 625,600, 563,800 / 563,200 / 563,400
#                   -> every 653,400 / 652,900, steady (fights 2-3, ends 2-3) 653,400 / 652,900: the higher, 653,400, for both; moments
#                      (higher of the runs): combat start 653,400, boss pull 625,600, boss down 565,900, combat end 564,000
#   XayaUI (core)   every 600 / 700, steady 600 / 700 (the 700s are combat-end frames, ends 1 and 3 of run 2): core's 600 HELD (as above)
# Against the 035eb58d4b1d caps (653,000): +400 (0.06%), inside the hook's 100-instruction steps and the 1% tolerance; the cap is the
# higher reading of the two plays, as every record above. Options 0 in both plays.
# (round 11b final fix, second record, 2026-11-22) stamp 4ba9a6ea1da1 -> 199c6009b355 (why: V33_RECORDED above). ad60a051 played twice:
#   XayaUI Rules    run 1: 601,600 / 653,000 / 625,200, 563,900 / 563,200 / 563,200   run 2: 601,000 / 653,100 / 625,400, 563,900 / 563,200 / 563,400
#                   -> every 653,000 / 653,100, steady 653,000 / 653,100; moments (higher of the runs): combat start 653,100, boss pull
#                      625,400, boss down 565,600, combat end 563,900
#   XayaUI (core)   every 700 / 700 (ends 3 and 2), steady 700 / 700: core's 600 HELD
# Against the 4ba9a6ea1da1 cap (653,400): -300 (0.05%), inside the hook's 100-instruction steps. The cap is the higher reading of these two
# plays, 653,100, as every record above (the four plays of this round read 652,900 to 653,400). Options 0 in both plays.
# (round 11b final fix 2, 2026-11-23) stamp 199c6009b355 -> 4fe081a4e900 (why: V33_RECORDED above). ad60a051 played twice:
#   XayaUI Rules    run 1: 601,600 / 653,100 / 625,700, 563,700 / 563,100 / 563,100   run 2: 601,400 / 653,400 / 625,300, 563,800 / 563,100 / 563,500
#                   -> every 653,100 / 653,400, steady 653,100 / 653,400; moments (higher of the runs): combat start 653,400, boss pull
#                      625,700, boss down 565,600, combat end 563,800
#   XayaUI (core)   every 600 / 700 (end 2 of run 2), steady 600 / 700: core's 600 HELD
# Against the 199c6009b355 cap (653,100): +300 (0.05%), inside the hook's 100-instruction steps; the cap is the higher reading of these two
# plays, 653,400, as every record above (the six plays of round 11b's last three records read 652,900 to 653,400). Options 0 in both.
V33_EVENT_CAPS = {"source": "ad60a051", "stamp": "4fe081a4e900", "standin": "3fb6b9731c89",
                  "how": ("measured 2026-11-23 (bundle 1 round 11b final fix 2, the key fight: two plays of ad60a051, the higher reading; "
                          "core's 600 held, build spec 4.4.4)"),
                  "caps": {"every": {"XayaUI_Rules": 653400, "XayaUI": 600, "XayaUI_Options": 0},
                           "steady": {"XayaUI_Rules": 653400, "XayaUI": 600, "XayaUI_Options": 0}}}
V33_EVENT_CAPS_TOL = 0.01   # a replay of ad60a051 within 1% of the stored caps is the same reading (the 300-600 instruction spread above)
# (round 11 repair) the stand-in's Lua whose fingerprint a stored record carries (tests/harness/; the scenario's own Lua is the stamp)
# (round 11b, build spec 4.4.1) also secret.lua, the shared hidden-value object every play loads (its shells bill the addon), and, read
# apart in standin_stamp(), the API index the play hands the stand-in (its secrecy flags decide the API guard, its lists every stub)
V33_STANDIN_FILES = ("world.lua", "loader.lua", "savedvars.lua", "secret.lua")
V33_WHERE_CAPS = "tests/gate_performance_run.py (V33 per-event caps)"
V33_WHERE_CAL = "tests/gate_common.py (V33 calibration)"
NAMES = {"XayaUI": "XayaUI (Platform, core)", "XayaUI_Rules": "XayaUI Rules", "XayaUI_Options": "XayaUI Options",
         "XayaUI_Bonus": "XayaUI Bonus Features", "XayaUI_Bonus_StatCalculator": "XayaUI Bonus Features: Stat Calculator"}


def first_second(B, seg, addon):
    """An addon's work in the first second (30 frames) of a budget segment."""
    sec = ((B.get(seg) or {}).get("sec") or {}).get(addon)
    if isinstance(sec, dict):
        return sec.get("1", sec.get(1, 0)) or 0
    return sec[0] if sec else 0


# (round 11 repair 2) what standin_code() looks for: a comment start, a long bracket (a long string, or a long comment after "--") or a
# short string quote; whitespace runs in code (Lua's isspace set)
_LUA_NEXT = re.compile(rb"--|\[=*\[|[\"']")
_LUA_LONG = re.compile(rb"\[(=*)\[")
_LUA_WS = re.compile(rb"[ \t\r\n\f\v]+")


def _lua_ws(chunk):
    """A code chunk with each whitespace run folded to one character: a line break if the run has one, else a space."""
    return _LUA_WS.sub(lambda m: b"\n" if (b"\n" in m.group() or b"\r" in m.group()) else b" ", chunk)


def standin_code(body):
    """(round 11 repair 2) The part of a stand-in Lua file that decides what the stand-in runs: its Lua with every comment taken out the
    way Lua 5.1's own lexer reads comments (llex.c: "--" then a long bracket "[" "="* "[" is a long comment up to the matching "]" "="*
    "]", any other "--" runs to the line end), every string kept byte for byte (short strings with their escapes, long strings
    [[...]] / [=[...]=]), and each whitespace run in code folded to one character (a line break if it had one, else a space; a comment
    counts as whitespace, so "a--[[x]]b" stays two names).
    What it guarantees: two versions with the same result have the same Lua tokens in the same order, the same strings and the same line
    breaks between tokens, so Lua compiles them to the same instructions (line numbers aside, which the gate's count hook does not read:
    tests/gate_common.py debug.sethook(callhook, "", INS_STEP)). So a comment, blank-line or indentation edit keeps the stored V33
    records valid (no needless re-record, which a public clone could not do), and every other edit changes the fingerprint: code
    commented out or switched back on with a block comment ("--[[" ... "--]]" against "---[[" ... "--]]", any level "--[==[" ...
    "]==]"), a changed string (a "--" line inside a long string included), a changed or added token.
    Conservative on purpose (a needless re-confirm, never a missed one): removing or adding whitespace between two tokens ("a=b" against
    "a = b") changes it. Out of scope: a file Lua could not compile (an unfinished string or comment runs to the file end here, and 5.1's
    "nesting of [[...]]" error is not checked) fails to load in the stand-in itself, which every gate play reports.
    Before (round 11 repair 1) it dropped every line whose first text was "--", which also dropped "--[[" / "--]]" themselves: commenting a
    block out or back in kept the fingerprint (round 11a repair 1 review)."""
    src = body.replace(b"\r\n", b"\n")
    out, code, i, n = [], [], 0, len(src)
    while True:
        m = _LUA_NEXT.search(src, i)
        if not m:
            code.append(src[i:])
            break
        code.append(src[i:m.start()])
        tok = m.group()
        if tok == b"--":
            lb = _LUA_LONG.match(src, m.end())
            if lb:   # a long comment: whitespace, a line break if it spans one
                close = b"]" + lb.group(1) + b"]"
                j = src.find(close, lb.end())
                j = n if j < 0 else j + len(close)
                code.append(b"\n" if b"\n" in src[m.start():j] else b" ")
            else:    # a line comment: up to the line end, which stays
                j = src.find(b"\n", m.end())
                j = n if j < 0 else j
                code.append(b" ")
            i = j
            continue
        if tok[:1] == b"[":   # a long string, kept whole
            close = b"]" + tok[1:-1] + b"]"
            j = src.find(close, m.end())
            j = n if j < 0 else j + len(close)
        else:                 # a short string, kept whole: up to the same quote not escaped, or the line end (Lua: unfinished string)
            j = m.end()
            while j < n and src[j:j + 1] != tok:
                if src[j:j + 1] == b"\\":
                    j += 1
                elif src[j:j + 1] == b"\n":
                    break
                j += 1
            j = min(j + 1, n)
        out.append(_lua_ws(b"".join(code)))
        out.append(src[m.start():j])
        code, i = [], j
    out.append(_lua_ws(b"".join(code)))
    return b"".join(out).strip()


def api_index_code():
    """(round 11b, build spec 4.4.1) The API index exactly as a gate play hands it to the stand-in (tests/gate_common.py _world: the
    harness's load_api() without its "framexml" list), as canonical JSON (keys sorted, no whitespace: a re-indented file reads the same,
    one changed value or flag does not). b"(none)" when no index was given (the stand-in then defines no documented function)."""
    p = os.environ.get("XUI_API_INDEX", os.path.join(GC.H.HERE, "api_index.json"))
    if not os.path.isfile(p):
        return b"(none)"
    import json
    with open(p, encoding="utf-8") as fh:
        api = json.load(fh)
    fx = os.environ.get("XUI_FRAMEXML_INDEX", os.path.join(GC.H.HERE, "framexml_index.json"))
    if os.path.isfile(fx):   # (as run.py load_api: the FrameXML index adds deprecatedOnly, which the world reads)
        with open(fx, encoding="utf-8") as fh:
            api["deprecatedOnly"] = json.load(fh).get("deprecatedOnly", {})
    api.pop("framexml", None)
    return json.dumps(api, sort_keys=True, separators=(",", ":")).encode()


def standin_stamp():
    """(round 11 repair) A short hash of the stand-in's own Lua (V33_STANDIN_FILES in tests/harness/; standin_code(): its Lua without
    comments, round 11 repair 2): its widget methods are Lua here and count as instructions, so a stored V33 number holds only in the
    stand-in it was measured in. (round 11b) Also the API index the play reads (api_index_code()): its secrecy flags decide which widget
    methods the stand-in guards, and which functions exist at all."""
    h = hashlib.sha1()
    for f in V33_STANDIN_FILES:
        try:
            with open(os.path.join(GC.H.HERE, f), "rb") as fh:
                body = standin_code(fh.read())
        except OSError:
            body = b"(missing)"
        h.update(f.encode() + b"\0" + body)
    h.update(b"api_index.json\0" + api_index_code())
    return h.hexdigest()[:12]


def record_check(rep, rec, name, stamp, replayed, where, now_text):
    """(round 11 repair; R11A concern "a fresh public clone that cannot replay ad60a051 loses its calibration"; SD-138 / V35: "a test
    fails if something it needs is missing (it must say what)") Whether the stored V33 record `rec` (V33_RECORDED or V33_EVENT_CAPS,
    called `name`) may be used here. The stored record is the calibration and is self-sufficient: a checkout that cannot play ad60a051
    (no git, a shallow or public clone, or after the history rewrite of SD-140) judges with it, as long as it was measured or confirmed
    in this same scenario (stamp) and this same stand-in (standin_stamp()). Playing ad60a051 now (replayed) is a cross-check only.
      the stamp differs                    FAIL, "MISSING INPUT": nothing records this scenario's calibration; with a replay the numbers to
                                           store are printed (the run still judges with them, so every line prints), without one there
                                           is nothing to judge with. Before round 11 repair, a replay made this a WARNING and the gate
                                           passed only where git had ad60a051 (round 11a final review).
      the stand-in differs, no replay      FAIL, "MISSING INPUT": the record cannot be confirmed for this stand-in (the run still judges
                                           with it);
      the stand-in differs, with replay    WARNING: the replay is the check (the drift WARNING follows when it differs by more than 1%);
                                           store the new stand-in once it confirms the record;
      both match                           used as stored.
    Returns True when the stored record is used."""
    here = standin_stamp()
    if rec.get("stamp") != stamp:
        rep.fail(where, "MISSING INPUT: %s holds no record for this scenario (stored for scenario %s, stand-in %s; this run's scenario is "
                 "%s, stand-in %s); %s" % (name, rec.get("stamp"), rec.get("standin"), stamp, here,
                                         "judged this run with ad60a051 played now" if replayed else "ad60a051 could not be played here"),
                 ("store in %s: %s" % (name, now_text)) if replayed else "",
                 "play ad60a051 twice in this scenario (a git checkout that has it, or XUI_V33_REPO) and store the numbers, the stamp and "
                 "the stand-in in %s, with the arithmetic (a value changes only by what the scenario measurably adds)" % name)
        return False
    if rec.get("standin") != here:
        if replayed:
            rep.warn(where, "%s was recorded in another stand-in (%s; this one is %s): ad60a051 played now is the cross-check" % (
                name, rec.get("standin"), here), "", "once the replay confirms it (no drift WARNING), store standin %s in %s" % (here, name))
        else:
            rep.fail(where, "MISSING INPUT: %s was recorded in another stand-in (tests/harness %s; this one is %s) and ad60a051 could not "
                     "be played here to confirm it; judged with the stored record anyway" % (name, rec.get("standin"), here), "",
                     "run the gate in a git checkout that has ad60a051 (or set XUI_V33_REPO): if it confirms the record, store standin %s" % here)
    return True


_BASE = []


def baseline():
    """GC.v33_baseline(), once per run (both variants are judged against the same ad60a051 run)."""
    if not _BASE:
        _BASE.append(GC.v33_baseline())
    return _BASE[0]


def good_base():
    """(round 11b, spec 4.4.3) ad60a051's play, or None when it did not play or raised a Lua error (v33() FAILs that and says why)."""
    b = baseline()[0]
    return b if (b is not None and not int(b.get("errors") or 0)) else None


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


def exact_txt(data):
    """(round 11b final fix 2) how the fixed-cap addons were counted in this result (gate_common.py KF.EXACT / KF.OVER)."""
    ov = data.get("exactOver")
    if isinstance(ov, (int, float)):
        return "counted exactly, the gate's own %d instructions per run taken out" % ov
    return "counted in 100-instruction steps (a result from before round 11b final fix 2)"


def debug_loaded(data):
    """(round 11b, SD-149) XayaUI_Debug was loaded in this play: at login (Advanced Debugging on) or later, for the run logger alone (its box
    "Advanced debug logging" works with Advanced Debugging off and loads the folder at the loading screen into a dungeon). Either way its
    fight frames are held to SD-81's 600."""
    return bool(data.get("debugLoaded")) or bool((data.get("addonsLoaded") or {}).get("XayaUI_Debug"))


def event_caps(data, rep, base, stamp, pct):
    """V33 per event (round 8; SD-66, her answer "No worse than ad60a51 (Recommended)"): see V33_EVENT_CAPS. (round 9) The segments
    judged are the fights and the second after each fight's combat end (CAP_EVERY / CAP_STEADY); the costliest boss-pull and combat-end
    frames are judged against the same caps on their own lines (SD-77); XayaUI_Debug against SD-81's 600 (DEBUG_EVENT_CAP)."""
    rec = V33_EVENT_CAPS
    measured = None
    if base is not None:
        measured = {k: {a: peak(base, segs, a)[0] for a in rec["caps"][k]} for k, segs in (("every", CAP_EVERY), ("steady", CAP_STEADY))}
    # (round 11 repair) the stored caps are the calibration (record_check: self-sufficient in their scenario and stand-in; a stale or
    # unconfirmable record is a FAIL that says MISSING INPUT; playing ad60a051 now only cross-checks them)
    if record_check(rep, rec, "V33_EVENT_CAPS", stamp, measured is not None, V33_WHERE_CAPS,
                    '"stamp": "%s", "standin": "%s", "caps": %s (one play: play it twice and keep the higher reading)' % (
                        stamp, standin_stamp(), measured)):
        caps, how = rec["caps"], "stored in this gate for scenario %s (%s)" % (stamp, rec["how"])
        drift = measured is not None and any(abs(measured[k][a] - caps[k][a]) > V33_EVENT_CAPS_TOL * max(caps[k][a], 100)
                                             for k in caps for a in caps[k])
        if drift:
            rep.warn(V33_WHERE_CAPS, "the stored per-event caps differ from %s played now in this same "
                     "scenario" % rec["source"], "stored %s; played now %s" % (caps, measured),
                     "find why the same build and scenario measure differently (the stand-in or the harness changed?) before trusting either")
        elif measured is None:
            rep.note("V33 per-event caps: %s not played here; the caps stored for this scenario (%s) and stand-in (%s) are used as "
                     "recorded" % (rec["source"], stamp, rec.get("standin")))
    elif measured is not None:
        caps, how = measured, "measured now on %s in this scenario (%s; the stored caps are for scenario %s)" % (rec["source"], stamp, rec["stamp"])
    else:
        caps = None
    B = data.get("budget") or {}
    addons = sorted(set(a for sg in CAP_EVERY for a in (((B.get(sg) or {}).get("peak")) or {})) | set((caps or {}).get("every") or {})
                    | (set(DEBUG_EVENT_CAP) if debug_loaded(data) else set()) | set(BONUS_EVENT_CAPS))
    for a in addons:
        name = NAMES.get(a, a)
        cur_e, seg_e = peak(data, CAP_EVERY, a)
        cur_s, seg_s = peak(data, CAP_STEADY, a)
        if a in BONUS_EVENT_CAPS:
            # (round 10, SD-112 / SD-117) both variants, every fight frame and each moment on its own line
            cap, sd, ans = BONUS_EVENT_CAPS[a]
            loaded = ((data.get("addonsLoaded") or {}).get(a))
            line = ("V33 %s per event (%s): costliest single fight frame %.0f instructions (%s; cap %.0f, her answer \"%s\"; loaded: %s; %s)" % (
                name, sd, cur_e, seg_e or "none", cap, ans, loaded, exact_txt(data)))
            if cur_e > cap:
                rep.fail(a, "V33 per-event limit: %s's costliest single fight frame is above her cap of %.0f instructions (%s \"%s\")" % (
                    name, cap, sd, ans), line + "; over by %.0f" % (cur_e - cap),
                    "do no work in a fight frame beyond what the fight needs: close the panel at combat start with one Hide and nothing else")
            else:
                rep.note(line)
            for mname, what in MOMENTS:
                v, sg = moment_peak(data, CAP_EVERY, mname, a)
                mline = "V33 %s per event, %s (%s): costliest frame %.0f instructions (%s; cap %.0f)" % (name, what, sd, v, sg or "none", cap)
                if v > cap:
                    rep.fail(a, "V33 per-event limit (%s): %s's costliest frame at %s is above her cap of %.0f instructions" % (sd, name, what, cap),
                             mline + "; over by %.0f" % (v - cap), "do no work at that moment beyond one Hide of an open panel")
                else:
                    rep.note(mline)
            continue
        if a in DEBUG_EVENT_CAP:
            # (round 9, SD-81, her answer "600, same as core (Recommended)") XayaUI_Debug, read only with Advanced Debugging on (V34)
            cap = DEBUG_EVENT_CAP[a]
            why = ("Advanced Debugging on" if data.get("debugLoaded") else "loaded for the run logger alone at the key's loading screen, SD-149")
            line = ("V33 %s per event (SD-81): costliest single fight frame %.0f instructions (%s; cap %.0f, her answer \"600, same as core\"; "
                    "%s; %s)" % (name, cur_e, seg_e or "none", cap, why, exact_txt(data)))
            if cur_e > cap:
                rep.fail(a, "V33 per-event limit: %s's costliest single fight frame is above her cap of %.0f instructions (SD-81 \"600, same as "
                         "core\")" % (name, cap), line + "; over by %.0f; %s" % (cur_e - cap, frame_parts(data, CAP_EVERY, a)),
                         "do no work in a fight frame beyond reading counters: count in place and show only when the player asks")
            else:
                rep.note(line)
            # (round 11b) the moments on their own lines too, as for the Bonus addons (the logger answers combat start, the boss pull and
            # the boss down, which share their frame with the restriction events of the key fight)
            for mname, what in MOMENTS:
                v, sg = moment_peak(data, CAP_EVERY, mname, a)
                mline = "V33 %s per event, %s (SD-81): costliest frame %.0f instructions (%s; cap %.0f)" % (name, what, v, sg or "none", cap)
                if v > cap:
                    rep.fail(a, "V33 per-event limit (SD-81): %s's costliest frame at %s is above her cap of %.0f instructions" % (name, what, cap),
                             mline + "; over by %.0f" % (v - cap), "do no work at that moment beyond counting in place")
                else:
                    rep.note(mline)
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


def frame_parts(data, segs, addon):
    """(round 11b) What an addon's handlers did in its costliest frames: its handlers by their costliest single run, over the segments
    (a frame's total is the sum of the handlers that ran in it; the gate keeps per-handler maxima, not per-frame lists)."""
    B = data.get("budget") or {}
    keys = {}
    for sg in segs:
        for k, e in (((B.get(sg) or {}).get("keys") or {}).get(addon) or {}).items():
            keys[k] = max(keys.get(k, 0), int(e.get("max") or 0))
    top = sorted(keys.items(), key=lambda kv: -kv[1])[:6]
    return "its handlers' costliest single runs: " + (", ".join("%s %d" % kv for kv in top) or "none")


def v33(data, rep):
    base, how = baseline()
    stamp = GC.scenario_stamp()
    # (round 11b, build spec 4.4.3) an ad60a051 play that raised a Lua error stopped a handler early and lowers the anchor: the calibration
    # is refused (its errors printed), whatever the record says
    if base is not None and int(base.get("errors") or 0):
        rep.fail(V33_WHERE_CAL, "the calibration play of %s raised %s Lua error(s) in this scenario: an erroring handler stops early and "
                 "lowers the anchor, so it is not used (build spec 4.4.3; spec risk 6: the decision on an invalid anchor is hers)" % (
                     GC.V33_BASE_COMMIT, base.get("errors")), "; ".join((base.get("errorText") or [])[:3]),
                 "find what the key fight hands the old build that its code cannot take (a hidden value it does arithmetic on?) before recording")
        base = None
        how = "the play of %s raised Lua errors" % GC.V33_BASE_COMMIT
    if base is not None:
        b_rules, bn = GC.seg_per_frame(base, FIGHT, "XayaUI_Rules")
        b_core = GC.seg_per_frame(base, FIGHT, "XayaUI")[0]
        b_opt = GC.seg_per_frame(base, FIGHT, "XayaUI_Options")[0]
        if not bn or b_rules <= 0:
            rep.fail(V33_WHERE_CAL, "the calibration run on %s measured no XayaUI Rules work in the fight" % GC.V33_BASE_COMMIT,
                     how, "fix the scenario on the old build before reading the budget")
            return
        # (round 11 repair) the record is checked even when ad60a051 plays here: a stale record is a FAIL (MISSING INPUT), not a pass
        # that holds only where git has ad60a051
        if record_check(rep, V33_RECORDED, "V33_RECORDED", stamp, True, V33_WHERE_CAL,
                        '"stamp": "%s", "standin": "%s", "rules": %.1f, "core": %.1f, "options": %.1f (one play: play it twice)' % (
                            stamp, standin_stamp(), b_rules, b_core, b_opt)) and V33_RECORDED["rules"]:
            how += "; recorded for this scenario %s: %.0f" % (V33_RECORDED["when"], V33_RECORDED["rules"])
    elif V33_RECORDED["stamp"] == stamp and V33_RECORDED["rules"]:
        b_rules, b_core, b_opt = V33_RECORDED["rules"], V33_RECORDED["core"], V33_RECORDED["options"]
        if V33_RECORDED.get("standin") == standin_stamp():
            rep.warn(V33_WHERE_CAL, "%s could not be played here (%s); the budget uses the calibration recorded %s "
                     "for this same scenario and stand-in" % (GC.V33_BASE_COMMIT, how, V33_RECORDED["when"]))
        else:
            record_check(rep, V33_RECORDED, "V33_RECORDED", stamp, False, V33_WHERE_CAL, "")
        how = "recorded %s for scenario %s" % (V33_RECORDED["when"], stamp)
    else:
        # (round 11 repair) says MISSING INPUT (SD-138 / V35: it must say what is missing)
        if record_check(rep, V33_RECORDED, "V33_RECORDED", stamp, False, V33_WHERE_CAL, ""):
            rep.fail(V33_WHERE_CAL, "MISSING INPUT: V33_RECORDED has no XayaUI Rules number for this scenario and %s could not be played "
                     "here (%s)" % (GC.V33_BASE_COMMIT, how), "", "play ad60a051 twice in this scenario and store its numbers")
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


# (round 11b; build spec 4.4.5) the stand-in's share of the handlers' work: secret.lua's shells and the stand-in's API guard, aura-access
# check and forbidden-button wrapper are Lua here and C in the game, so the addons are billed a few instructions per call that the game
# would not bill. Measured in the tree play (tests/gate_common.py KF.share: every call into each wrapper during the handlers of the three
# fights, times that wrapper's own instructions per call measured in the same play), for this build and for ad60a051 (the share stored
# in V33_RECORDED with its record, or its own tree play when asked: XUI_V33_SHAREPLAY=1), and printed with both builds' wall-clock time. Held: the
# readout's ratio (this build / ad60a051, XayaUI Rules per fight frame) moves by at most 2% when the share is taken out of both builds.
SHARE_SHIFT_MAX = 0.02
FIGHT3 = ("fight 1", "fight 2", "fight 3")


def share_of(d, addon):
    """(stand-in instructions billed to the addon's fight handlers, the addon's measured fight work, {kind: (calls, cost)}, kinds with no
    measured cost) for one build's result, from its tree play's KF.share (calls) and shareCost (instructions per call)."""
    calls = ((d.get("share") or {}).get(addon)) or {}
    cost = d.get("shareCost") or {}
    total = sum(((d.get("budget") or {}).get(sg) or {}).get("work", {}).get(addon, 0) for sg in FIGHT3)
    ins, parts, nocost = 0.0, {}, []
    for k, n in calls.items():
        c = cost.get(k)
        if c is None:
            nocost.append("%s %s calls" % (k, n))
            continue
        ins += float(n) * float(c)
        parts[k] = (int(n), float(c))
    return ins, float(total), parts, nocost


def share_check(data, rep):
    where = "tests/gate_performance_run.py (V33 stand-in share)"
    cur_w = GC.seg_per_frame(data, FIGHT, "XayaUI_Rules")[0]
    rep.note("wall-clock: this variant's plays took %.0f s on this build (measured%s)" % (
        float(data.get("_secs") or 0), ", tree, draw and memory plays" if data.get("paceTree") else " play only: no tree play"))
    if data.get("share") is None or not data.get("shareCost"):
        if data.get("paceTree"):
            rep.fail(where, "the tree play measured no stand-in share for this build (tests/gate_common.py KF.share)", "found: %s" % data.get("shareFound"),
                     "the share count did not run: fix it before reading the ratio")
        else:
            rep.warn(where, "the stand-in share was not measured for this build (no tree play: XUI_GATE_NOTREE / XUI_GATE_NOHOOK)")
        return
    missing = [k for k, v in (data.get("shareFound") or {}).items() if not v]
    if missing:
        rep.fail(where, "the share count could not find the stand-in's wrapper(s) %s" % ", ".join(sorted(missing)), "found: %s" % data.get("shareFound"),
                 "tests/gate_common.py KF.share finds each wrapper from the stand-in's own functions: follow the stand-in's change")
    sc_ins, sc_tot, sc_parts, sc_no = share_of(data, "XayaUI_Rules")
    cfrac = sc_ins / sc_tot if sc_tot else 0.0
    base = good_base()
    if base is not None and base.get("share") is not None and base.get("shareCost"):
        b_ins, b_tot, b_parts, b_no = share_of(base, "XayaUI_Rules")
        bfrac = b_ins / b_tot if b_tot else 0.0
        b_w = GC.seg_per_frame(base, FIGHT, "XayaUI_Rules")[0]
        bsrc = "%s played now (its tree play %s s; all its plays %s s)" % (GC.V33_BASE_COMMIT, base.get("shareSecs"), base.get("_secs"))
        b_parts_txt = ", ".join("%s %d x %.1f" % (k, n, c) for k, (n, c) in sorted(b_parts.items())) or "none"
    elif V33_RECORDED.get("share") and V33_RECORDED.get("stamp") == GC.scenario_stamp() and V33_RECORDED.get("standin") == standin_stamp():
        bfrac, b_w = float(V33_RECORDED["share"]["frac"]), float(V33_RECORDED["rules"])
        bsrc, b_parts_txt = "stored in V33_RECORDED for this scenario and stand-in", V33_RECORDED["share"].get("parts", "")
    else:
        rep.fail(where, "MISSING INPUT: no stand-in share for %s (not played here with its tree play, none stored for this scenario and stand-in)" % GC.V33_BASE_COMMIT,
                 "this build: %.2f%% of XayaUI Rules' fight work" % (100 * cfrac),
                 "play ad60a051 here with XUI_V33_SHAREPLAY=1 and store its share in V33_RECORDED")
        return
    sc, sb = cfrac * cur_w, bfrac * b_w
    ratio = cur_w / b_w if b_w else 0.0
    ratio_wo = (cur_w - sc) / (b_w - sb) if (b_w - sb) else 0.0
    shift = (ratio / ratio_wo - 1.0) if ratio_wo else 0.0
    line = ("XayaUI Rules in the three fights: this build %.0f of %.0f instructions in the stand-in's wrappers (%.2f%%; calls x instructions "
            "per call: %s%s), %.0f of %.0f per fight frame; %s %.2f%% (%s), %.0f of %.0f per fight frame (%s). Readout ratio %.4f with the "
            "share, %.4f without: shift %+.2f%% (held to %.0f%%). Instructions per call measured in this play: %s" % (
                sc_ins, sc_tot, 100 * cfrac, ", ".join("%s %d x %.1f" % (k, n, c) for k, (n, c) in sorted(sc_parts.items())) or "none",
                ("; not costed: " + ", ".join(sc_no)) if sc_no else "", sc, cur_w, GC.V33_BASE_COMMIT, 100 * bfrac, b_parts_txt, sb, b_w, bsrc,
                ratio, ratio_wo, 100 * shift, 100 * SHARE_SHIFT_MAX, data.get("shareCost")))
    if abs(shift) > SHARE_SHIFT_MAX:
        rep.fail(where, "V33 stand-in share: taking the stand-in's own Lua out of both builds moves the readout by more than %.0f%% (build spec "
                 "4.4.5)" % (100 * SHARE_SHIFT_MAX), line, "move the heaviest wrapper's work host-side (tests/harness/secret.lua S.host)")
    else:
        rep.note("V33 stand-in share (build spec 4.4.5): " + line)
    for a in sorted(data.get("share") or {}):
        if a != "XayaUI_Rules":
            i, t, parts, no = share_of(data, a)
            rep.note("V33 stand-in share, %s: %.0f of %.0f fight instructions (%.2f%%)%s" % (
                NAMES.get(a, a), i, t, (100.0 * i / t) if t else 0.0, ("; not costed: " + ", ".join(no)) if no else ""))


def memory_report_fold(data, rep):
    """(round 11, SD-129 "Yes, in round 11 (Recommended)"; test audit section 2) the rule-count checks tests/memory_report_run.py made,
    now here (its moved-files and moved-functions checks are in tests/fix_r7_relocate_run.py L1; its report is the tool
    tests/memory_report.py, outside the suite): (C4) the profile session A made has about 300 rules, at least 250 as memory_report held
    it; (C1) "no rules loaded": the session played from what session A saved loaded its rules. The gate's own integrity check holds the
    second at 290 or more; this one keeps memory_report's exact terms, so a change to either is seen. Session A's Lua errors, which
    memory_report printed without failing, now fail.
    NOT memory_report's realistic case on its own terms (round 11 repair 1, review finding): this is the gate's profile, the ~300-rule list
    alone. memory_report's realistic profile was that list plus a long-used install's extras (tests/memory_report.py EXTRAS_LUA: backups,
    the old place the settings move kept, Recycle Bin, drafts, a full error log, talent scan, learned data); that case, with C1 and C2 on
    it, is tests/fix_r7_relocate_run.py L1 (one shared session A, memory_report.realistic_session_a). The extras stay out of the gate's
    scenario on purpose: they would change its stamp and its calibrated caps (V33) for checks that need no frame timing. These are extra
    checks on the gate's own profile, not the place C1 moved to."""
    prof = data.get("profile") or {}
    made = int(prof.get("entries") or 0)
    if made < 250:
        rep.fail("tests/gate_common.py (PROFILE_LUA, session A)", "[memory_report C4] the realistic profile has %d rules, expected about 300 "
                 "(at least 250)" % made, "rules made by session A: %d" % made, "")
    if int(data.get("rules") or 0) <= 0:
        rep.fail("tests/gate_common.py (the scenario)", "[memory_report C1] no rules loaded: the session played from what session A saved "
                 "has no rules", "rules: %s" % data.get("rules"), "")
    errs = prof.get("errorsA") or []
    if errs:
        rep.fail("tests/gate_common.py (PROFILE_LUA, session A)", "[memory_report] session A (the realistic profile) raised a Lua error",
                 "; ".join(str(e) for e in errs[:3])[:400], "")


class Checks(object):
    """(round 11 repair; R11A final: gate_performance had no count line, so the honest-result guard read it as NO COUNT LINE; SD-138 /
    V35 "a test fails ... if it prints no result count") The gate's checks, counted for its last line. judge() names each check as it
    starts it (begin()); every FAIL reported while a check runs counts against that check. A check is one of the named judgements above
    (P1-P6, V33, DRAW, MEM, the scenario's integrity), run over every measured handler of one variant's result; the count line reads
    "gate_performance: N checks, M failed (...)" where M is the number of checks with at least one violation."""

    def __init__(self, rep, label):
        self.rep, self.label, self.run = rep, label, []

    def begin(self, name):
        self.run.append([name, 0])

    def fail(self, where, what, numbers, fix):
        if not self.run:
            self.begin("(a FAIL before any named check)")
        self.run[-1][1] += 1
        self.rep.fail(where, what, numbers, fix)

    def warn(self, where, what, numbers="", fix=""):
        self.rep.warn(where, what, numbers, fix)

    def note(self, text):
        self.rep.note(text)


def begin(rep, name):
    """Names the check that starts now, when rep counts checks (Checks); a plain Report (a test calling judge() itself) ignores it."""
    b = getattr(rep, "begin", None)
    if b is not None:
        b(name)


def count_line(rep, counted):
    """(round 11 repair) The gate's last line: the checks run, the checks failed, and (as before) its violations and warnings. Read by
    tests/run_all.py (COUNT_PATTERNS "N checks", FAILED_COUNT, FAILS_COUNT)."""
    n = sum(len(c.run) for c in counted)
    bad = [(c.label, name) for c in counted for name, f in c.run if f]
    parts = "; ".join("variant %s: %d" % (c.label, len(c.run)) for c in counted)
    return "%s: %d checks, %d failed (%s%s; %d violation(s), %d warning(s))  FAILS: %d" % (
        GATE, n, len(bad), parts, ("; failed: " + ", ".join("%s %s" % b for b in bad)) if bad else "", len(rep.fails), len(rep.warns),
        len(rep.fails))


def judge(data, rep):
    """Every check of this gate on one variant's result. (round 11 repair) Each check is named as it starts (begin(): its FAILs are counted
    against it for the count line, see Checks; a plain Report is passed through unchanged)."""
    begin(rep, "the scenario ran as planned (gate_common.integrity)")
    GC.integrity(data, rep)
    begin(rep, "memory_report C1 / C4 (the profile's rules)")
    memory_report_fold(data, rep)
    begin(rep, "the scenario's length (steady state and idle)")
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
    begin(rep, "P1 frame scripts and display effects (SD-79)")
    p1(data, rep)

    # ---- P2 tickers and timer chains ------------------------------------------------------------------------------------------
    begin(rep, "P2 tickers and timer chains")
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
    begin(rep, "P3 loops over all rules per event")
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
    begin(rep, "P4 allocation")
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
    begin(rep, "P5 whole pixels")
    for line, s in (data.get("nonint") or {}).items():
        rep.fail(line, "P5 a non-integer position or size passed to %s by XayaUI code" % s.get("method"),
                 "%d call(s) with the window closed, e.g. %s; phases %s" % (s.get("n", 0), s.get("example"), ", ".join(sorted(s.get("phases") or {}))),
                 "store and set whole pixels: round once where the value is made (math.floor(v + 0.5)), not per frame")

    # ---- P6 runaway -----------------------------------------------------------------------------------------------------------------
    begin(rep, "P6 runaway")
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
    begin(rep, "P2 her pace, 10 a second per re-check path")
    pace(data, rep)
    # ---- P4 (round 8) a new function per timer call ---------------------------------------------------------------------------
    begin(rep, "P4 a new function per timer call (SD-68, SD-82)")
    closures(data, rep)

    # ---- V33 work budget per addon ------------------------------------------------------------------------------------------------
    begin(rep, "V33 work budget per fight frame")
    pct = v33(data, rep)
    begin(rep, "V33 per-event caps")
    event_caps(data, rep, good_base(), GC.scenario_stamp(), pct)
    begin(rep, "V33 stand-in share (build spec 4.4.5)")
    share_check(data, rep)
    # ---- (round 9, SD-77) what is drawn after each load-fact change, against a full re-check ---------------------------------------
    begin(rep, "DRAW what is drawn after each load-fact change (SD-77)")
    drawn(data, rep)

    begin(rep, "MEM memory budget (SD-66)")
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
# path, so it is not judged (her decision SD-66 "1": each path at most 10 a second); (round 8 repair 2) it is a WARNING, since on the
# round 8 tree one rule's check runs 21 times a second over the passes together. (round 11b, SD-147) Her answer SD-78 "Per pass
# (Recommended)" settles it (EUI paces each path on its own; nothing adds the paths together): the WARNING cites SD-78 and asks nothing.
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
                 "settled by her answer SD-78 \"Per pass (Recommended)\" (REQUEST-LOG; re-asked as SD-147 and answered from the record): "
                 "10 a second is counted per re-check pass, as EUI paces each path on its own; work several passes share is reported here, "
                 "not judged")
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
# (round 11b final fix) the draw play's one fight out of the key, on readable data with a target selected (tests/gate_common.py, after
# "key end"): inside the key the target's debuffs are hidden at every moment, so only this fight changes the absent target debuffs at
# combat start and combat end (shown out of combat, not in combat) and gives the check its teeth on them; each runs once
DRAW_OUT_LABELS = ("target picked, out of the key", "combat start, out of the key", "combat end, out of the key")
# (round 11b gate repair 1) whether the scenario has a target selected at each moment (tests/gate_common.py SCENARIO_LUA: G.target is set
# at "target picked" and dropped at "group left, target dropped"), so the gate's words say which moments had a target. The words are
# what Xaya reads: round 11b's first report said the absent target debuffs were "never shown, out of combat included" from the line
# "shown 0 (out of combat 0)", whose second number was the combat-end moment (out of combat but with the target still selected); the play
# showed them 6 of 6 at every moment with no target selected. Each moment is now printed with its combat and target state.
DRAW_TARGET = {"mounted": False, "dismounted": False, "group joined": False, "target picked": True, "combat start": True,
               "boss pull": True, "boss down": True, "combat end": True, "group left, target dropped": False,
               "target picked, out of the key": True, "combat start, out of the key": True, "combat end, out of the key": True}


def draw_group_by_moment(checks, group, field="shown"):
    """One draw-check group (Absent, Ooc, Boss) read at every moment of each cycle, in the scenario's order, with each moment's combat and
    target state: 'cycle 1: mounted 6 (out of combat, no target); ...'. Cycles that read the same are printed once ('the same in cycles
    2 and 3'). Returns '' when the draw play has no checks."""
    per = collections.OrderedDict()
    for c in checks:
        cyc = str(c.get("phase") or "?").replace("busy ", "cycle ")
        g = (c.get("groups") or {}).get(group) or {}
        lab = c.get("label")
        tgt = DRAW_TARGET.get(lab)
        state = "%s, %s" % ("in combat" if c.get("combat") else "out of combat",
                            "target selected" if tgt else ("no target" if tgt is False else "target unknown"))
        per.setdefault(cyc, []).append("%s %s (%s)" % (lab, g.get(field), state))
    if not per:
        return ""
    groups = collections.OrderedDict()
    for cyc, parts in per.items():
        groups.setdefault(tuple(parts), []).append(cyc)
    out = []
    for parts, cycs in groups.items():
        head = cycs[0] + ((" (the same in %s)" % " and ".join(c.replace("cycle ", "cycles ", 1) if i == 0 else c.replace("cycle ", "")
                                                              for i, c in enumerate(cycs[1:]))) if len(cycs) > 1 else "")
        out.append("%s: %s" % (head, "; ".join(parts)))
    return " || ".join(out)


def draw_absent_summary(checks):
    """The absent target debuffs (PROFILE_LUA 6c) shown with no target selected and while a target is selected, each split by combat:
    'with no target selected: 6 of 6 at every moment (out of combat); while a target is selected: 0 of 6 out of combat (target picked,
    combat end), 0 of 6 in combat (...)'."""
    buckets = collections.OrderedDict()
    total = 0
    for c in checks:
        g = (c.get("groups") or {}).get("Absent") or {}
        total = max(total, int(g.get("rules") or 0))
        tgt = DRAW_TARGET.get(c.get("label"))
        key = ("while a target is selected" if tgt else "with no target selected", "in combat" if c.get("combat") else "out of combat")
        b = buckets.setdefault(key, {"shown": set(), "labels": []})
        b["shown"].add(g.get("shown"))
        if c.get("label") not in b["labels"]:
            b["labels"].append(c.get("label"))
    parts = []
    for (tgt, cmb), b in buckets.items():
        sh = sorted(b["shown"], key=lambda v: (v is None, v))
        parts.append("%s, %s: %s of %d (%s)" % (tgt, cmb, "/".join(str(v) for v in sh), total, " / ".join(b["labels"])))
    return "; ".join(parts)


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
    missing = [l for l in DRAW_LABELS if labels.get(l, 0) < 3] + [l for l in DRAW_OUT_LABELS if labels.get(l, 0) < 1]
    if missing:
        rep.fail("tests/gate_common.py (the draw play)", "the draw check did not run at every moment of the three cycles", "missing: %s; ran: %s" % (
            missing, dict(labels)), "")
    notran = [c for c in checks if not c.get("ran")]
    if notran:
        rep.fail("tests/gate_common.py (the draw play)", "the full re-check the draw check compares with did not run (Engine.lua ns.EngineStats.settle did "
                 "not move after ns.MarkDirty), so these checks prove nothing", "; ".join("%s (%s)" % (c.get("label"), c.get("phase")) for c in notran[:6]), "")
    bad = [c for c in checks if int(c.get("ndiff") or 0) > 0]
    # (round 11b final fix) the draw check now tells the second cause apart for a cooldown rule (gate_common.py KF.lateWake): a display
    # whose cooldown ended during the check's quiet frames, at most one pace gap and two frames (KF.LATE_S) before the read, is its own
    # wake still on the way, not the moment's re-check; it is listed here, every time, and not counted. One that ended earlier and is
    # still drawn wrong stays a difference (a wake that never came).
    late = [c for c in checks if int(c.get("nlate") or 0) > 0]
    if late:
        rep.note("draw check (SD-77): %d check(s) read a cooldown display whose own end came during the quiet frames and whose wake (the "
                 "next frame, then her pace: Engine.lua, SD-60) had not landed yet; listed, not counted: %s" % (
                     len(late), "; ".join("%s (%s): %s" % (c.get("label"), c.get("phase"), ", ".join(vals(c.get("late")))) for c in late)[:900]))
    # (round 11b gate repair 1) the FAIL says what the check measured and no more. A display that differs from a full re-check in the same
    # instant has two possible causes, and this check cannot tell them apart: a narrowed re-check that missed a rule (SD-77), or a rule
    # whose own wake had not come yet when the gate read it. The second is measured in the key fight: a cooldown whose times are hidden is
    # woken at its end by the engine's Cooldown widget (Engine.lua: "its OnCooldownDone is the end and wakes the rules waiting for it (on
    # the stored-moment timer, the next frame)", SD-60). In a private probe of the draw play (round 11b gate repair 1), Cooldown 13's
    # display came back without any re-check 2 frames (0.0667 s) after its cooldown's end with hidden times and 1 frame (0.0333 s) after
    # with readable times (W.cdSecrecy 0), and the gate's read at "group left, target dropped" fell 1 frame (0.0333 s) after that end. So
    # the FAIL stays a FAIL and its fix names the step that tells the two causes apart.
    # (round 11b final fix) that step is now taken for a cooldown rule: gate_common.py KF.lateWake lists (not counts) a display whose cooldown
    # ended during the check's quiet frames at most KF.LATE_S (one pace gap and two frames) before the read; any other difference, and a
    # cooldown that ended earlier and is still drawn wrong, stays a FAIL (fix_r9_gate_scenario's wake mutant proves the second).
    for c in bad:
        rep.fail("XayaUI_Rules (what is drawn after %s)" % c.get("label"),
                 "SD-77: after %s (%s, %s) %d display(s) show something other than what a full re-check of every rule shows in the same "
                 "instant. This check does not tell why: a narrowed re-check that missed a rule whose answer or drawing reads the changed "
                 "fact (SD-77), or a rule whose own wake had not come yet when the gate read it (a cooldown whose times are hidden is woken "
                 "at its end on the next frame, Engine.lua, SD-60)" % (
                     c.get("label"), c.get("phase"), "in combat" if c.get("combat") else "out of combat", int(c.get("ndiff") or 0)),
                 "; ".join(vals(c.get("diffs")))[:900],
                 "first find which: read the display again one frame later without a re-check (and, for a cooldown rule, where the read falls "
                 "against that cooldown's end); if it still differs, re-check every rule whose answer or drawing reads the fact that changed "
                 "(SD-77 conditions 2 and 3)")

    def grp(label, cyc_phase=None):
        out = [c.get("groups") or {} for c in checks if c.get("label") == label]
        return out
    # the scenario's own rules must change at their moments (else the draw check cannot see a narrowing that misses them)
    # (round 11b final fix) the out-of-combat opacity is tested at every combat start and end of the key's three cycles, the boss rules at
    # every boss pull and down, and the absent target debuffs in the fight out of the key (DRAW_OUT_LABELS): shown with the target picked
    # and at combat end, not at combat start. Inside the key they read "unknown" at every moment (hidden debuffs, out of combat too), so
    # the key's moments cannot test them; that is printed, not judged.
    cov = []
    for cs, ce in zip(grp("combat start"), grp("combat end")):
        o_in, o_out = (cs.get("Ooc") or {}).get("alpha"), (ce.get("Ooc") or {}).get("alpha")
        cov.append(bool(o_in and o_out and set(o_in.split(",")) == {"1"} and set(o_out.split(",")) == {"0.5"}))
    for bp, bd in zip(grp("boss pull"), grp("boss down")):
        cov.append(bool((bp.get("Boss") or {}).get("shown")) and (bd.get("Boss") or {}).get("shown") == 0)
    ot, os_, oe = (grp(l) for l in DRAW_OUT_LABELS)
    a_tp = [(g.get("Absent") or {}).get("shown") for g in ot]
    a_in = [(g.get("Absent") or {}).get("shown") for g in os_]
    a_out = [(g.get("Absent") or {}).get("shown") for g in oe]
    a_rules = max([int((g.get("Absent") or {}).get("rules") or 0) for g in ot + os_ + oe] + [0])
    cov.append(len(a_tp) == 1 and len(a_in) == 1 and len(a_out) == 1 and a_rules > 0 and a_tp[0] == a_rules and a_in[0] == 0
               and a_out[0] == a_rules)
    keyc = [c for c in checks if c.get("label") not in DRAW_OUT_LABELS]   # (the key's cycles; the fight out of the key is printed apart)
    absent_by = draw_group_by_moment(keyc, "Absent")
    absent_sum = draw_absent_summary(keyc)
    if len(cov) < 7 or not all(cov):
        # (round 11b gate repair 1) the numbers name every moment's combat and target state, so a reader sees WHEN the absent target
        # debuffs did not change (e.g. already 0 from "target picked", out of combat, on), not only that they did not
        tp = [((c.get("groups") or {}).get("Absent") or {}).get("shown") for c in checks if c.get("label") == "target picked"]
        why = ""
        ce = [(g.get("Absent") or {}).get("shown") for g in grp("combat end")]
        if not (len(a_tp) == 1 and len(a_in) == 1 and len(a_out) == 1):
            why = "; the fight out of the key (%s) did not run once each: %s" % (", ".join(DRAW_OUT_LABELS), [len(a_tp), len(a_in), len(a_out)])
        elif tp and all(v == 0 for v in tp) and ce and all(v == 0 for v in ce):
            why = ("; (in the key the absent target debuffs read 0 from \"target picked\" on: hidden debuffs, as expected; the fight out of "
                   "the key read %s with the target picked, %s at combat start, %s at combat end, of %d)" % (a_tp, a_in, a_out, a_rules))
        rep.fail("tests/gate_common.py (the draw play)", "the rules that test the narrowed re-check did not change at their moments (target debuffs "
                 "that must be absent: shown out of combat, not in combat; out-of-combat opacity: 0.5 out of combat, 1 in combat; boss rules: "
                 "shown only during the boss), so a narrowing that missed them would not show",
                 "absent target debuffs shown at every moment: %s; by state: %s%s; out of the key: target picked %s, combat start %s, combat end "
                 "%s || combat start %s; combat end %s; boss pull %s; boss down %s" % (
                     absent_by, absent_sum, why, a_tp, a_in, a_out, grp("combat start")[:1], grp("combat end")[:1], grp("boss pull")[:1],
                     grp("boss down")[:1]), "")
    rep.note("draw check (SD-77): %d moment(s) compared with a full re-check of every rule (%d displays and aura groups each), %d differ; the "
             "absent target debuffs shown by state: %s; out of the key (readable): target picked %s, combat start %s, combat end %s; "
             "out-of-combat opacity at combat start %s, at combat end (out of combat) %s; at the boss pull the boss rules shown %s" % (
                 len(checks), max([int(c.get("n") or 0) for c in checks] + [0]), len(bad), absent_sum, a_tp, a_in, a_out,
                 ((grp("combat start") or [{}])[0].get("Ooc") or {}).get("alpha"), ((grp("combat end") or [{}])[0].get("Ooc") or {}).get("alpha"),
                 ((grp("boss pull") or [{}])[0].get("Boss") or {}).get("shown")))


# ---------------------------------------------------------------------------------------------------------------------------------
# Memory budget (REQUEST-LOG A23 SD-38 / SD-41 "measure first, then set"; SD-66, her answer "Today +15%, tighten later (Recommended)"):
# the cap is the round 7 reading plus 15%: Lua memory after a full collection at the end of cycle 3 was 34,747.6 KB, so
# 34,747.6 KB x 1.15 = 39,959.74 KB, kept as 39,959.7 KB. Judged on every reading after a full collection at the end of a gate cycle
# (cycles 1, 2, 3) and after the 30 s idle; any reading above the cap is a violation. To be lowered as cuts land ("tighten later").
# (round 7 to round 11b final fix) The reading judged was the whole Lua state of the measured play (the addons, the stand-in game and the
# gate's own records); see "WHAT IS JUDGED" below for round 11b final fix 2.
# (round 11b final fix) Before each reading the stand-in's own hidden-value registries (tests/harness/secret.lua KIND, VALUE, FORBID,
# FNAME, STABLE) are made again with their live entries only (tests/gate_common.py memNow, S.compact): they are weak-keyed, but a Lua 5.1
# table keeps the slots it grew to, and the key fight makes hidden values by the thousand between two collections. Without it the
# readings held about 5 MB of empty slots of the stand-in's (memory play: 42,890.8 KB at the end of cycle 1; with three of the five made
# again 40,113.9 KB; tests/fix_r11_final_fix_run.py C1). A collection comes first (memNow: collect, rebuild, collect): a hidden payload's
# real table holds hidden values of its own and a Lua 5.1 weak-keyed table marks its values, so a registry forgets one layer of dead
# hidden values per collection (rebuilt before the only collection, the memory play still read 42,884.2 KB at the end of cycle 1;
# collected, rebuilt and collected again 37,548.1 KB). What the addons hold is still counted, the stand-in and the gate's records too.
# (round 11b final fix 2) WHAT IS JUDGED: the memory play's readings (gate_common.py CFG.memplay: the same scenario, the same stand-in, the
# same addons, with no instrument and nothing of the gate's kept per cycle), i.e. the addons and the stand-in game, without the gate's own
# records. Before, the measured play's whole Lua state was judged, the gate's own records included, as when the cap was set in round 7
# (round 9 added the memory play to read the growth without them, but left the cap on the measured play). Why it changed (a measurement
# choice, SD-145; her number is unchanged): the gate's records are the measuring apparatus, never memory the addons use in the game, and
# they grow with the gate itself, not with XayaUI. Measured on this branch (stand-in numbers, KB, after a full collection): the measured
# play holds 660 more than the memory play before the first fight and 1,050 to 1,620 more at the readings (Advanced Debugging variant
# 40,140.9 / 40,331.8 / 40,518.6, idle 40,762.2, against the memory play's 39,128.6 / 39,139.4 / 39,145.5, idle 39,140.0); the
# records grow about 186 KB a cycle in the key fight. In the same round the apparatus that both plays still count grew too, by more than
# the records' share of the round 7 reading (INFERENCE: round 9's measured-minus-memory gap was 930 KB at the end of cycle 3): the
# stand-in's API index (tests/harness/api_index.json, rebuilt from docs/reference/api in round 11b with the secrecy section) +710 KB and
# the stand-in's hidden-value code (tests/harness/secret.lua and world.lua) +270 KB (round 11a 18798861, default variant, memory play at
# the end of cycle 1: 36,284.6 KB with its own index in its gate run, 36,994.2 KB with this branch's index; the stand-in alone, loaded
# with no addon, 9,103.8 KB on 18798861 against 9,374.4 KB here, the same index).
# The measured play's whole state is still printed next to the judged reading, with the records' size, so nothing is hidden. With no
# memory play in the result (XUI_GATE_NOTREE=1: an old build played for the calibration) the measured play's whole state is judged, as
# before (stricter: the records count); a result whose other plays ran but has no memory play is a FAIL (MISSING INPUT).
# ---------------------------------------------------------------------------------------------------------------------------------
MEM_BASE_KB, MEM_FACTOR = 34747.6, 1.15
MEM_CAP_KB = round(MEM_BASE_KB * MEM_FACTOR, 1)   # 39959.7


def mem_readings(mem, end):
    """The readings judged against the cap, by name: the end of each cycle and, when there is one, the reading after the idle."""
    return [("end of cycle %d" % (i + 1), m) for i, m in enumerate(mem)] + ([("after 30 s idle", end)] if isinstance(end, (int, float)) else [])


def memory(data, rep):
    mem = [m for m in vals(data.get("mem")) if isinstance(m, (int, float))]
    end = data.get("memEnd")
    ma = data.get("memAddons") or {}
    mm = [m for m in vals(ma.get("mem")) if isinstance(m, (int, float))]
    mend = ma.get("memEnd")
    played = len(mm) >= 3   # (round 11b final fix 2) the memory play ran: its readings are judged
    if data.get("paceTree") and not played:
        rep.fail("tests/gate_common.py (the memory play)", "MISSING INPUT: the result has no memory play although the gate played its other "
                 "plays, so the memory budget has nothing to judge", "memory play readings: %s" % ma.get("mem"),
                 "find why gate_common.py result() kept no memory play (run_scenario memplay=True)")
    if played:
        readings, what = mem_readings(mm, mend), "the memory play (the addons and the stand-in game, without the gate's own records)"
    else:
        readings, what = mem_readings(mem, end), "the measured play's whole Lua state (no memory play: the gate's own records included)"
        if len(mem) < 3:
            rep.fail("tests/gate_common.py (the scenario)", "the memory budget has no reading for each of the three cycles", "readings: %s" % mem, "")
    cap_txt = "cap %s KB = %s KB x %.2f (SD-66 \"Today +15%%, tighten later\")" % ("{:,.1f}".format(MEM_CAP_KB), "{:,.1f}".format(MEM_BASE_KB), MEM_FACTOR)
    over = [(w, m) for w, m in readings if m > MEM_CAP_KB]
    all_txt = "; ".join("%s %s KB" % (w, "{:,.1f}".format(m)) for w, m in readings)
    if over:
        rep.fail("(whole addon set)", "memory budget: Lua memory after a full collection is above her cap (%s), read in %s" % (cap_txt, what),
                 "%s; above the cap: %s" % (all_txt, "; ".join("%s by %s KB" % (w, "{:,.1f}".format(m - MEM_CAP_KB)) for w, m in over)),
                 "find what holds the memory (the per-cycle growth below, a /xui debug memory report in game) and cut it")
    else:
        rep.note("memory budget: %s; read in %s: %s; headroom %s KB" % (cap_txt, what, all_txt,
                                                                     "{:,.1f}".format(MEM_CAP_KB - max([m for _, m in readings] + [0]))))
    if played and len(mem) >= 3:
        # (round 11b final fix 2) the measured play's whole state, printed beside the judged reading (not judged: see above)
        meas = mem_readings(mem, end)
        rep.note("memory, the measured play's whole Lua state (the gate's own records included; printed, not judged): %s; the gate's records "
                 "and instruments: %s" % ("; ".join("%s %s KB" % (w, "{:,.1f}".format(m)) for w, m in meas),
                                          ", ".join("{:,.1f}".format(a[1] - b[1]) for a, b in zip(meas, readings))))
    # (round 9; round 8 engine-core handoff: the growth WARNING measured the gate's own per-cycle records: ST.cyc snapshots, BUD
    # segments, PACE rings, TIMERS_SEEN, OUT.checkpoints and mouseCombat, the stand-in's W.sounds) the growth per cycle is read in the
    # memory play (gate_common.py CFG.memplay: no instruments, nothing of the gate's kept per cycle, the stand-in's list of sounds played
    # emptied before each reading), so it is the addons' own (with the stand-in's records of the frames they made).
    if played:
        d1, d2 = mm[1] - mm[0], mm[2] - mm[1]
        txt = ("the addons' own Lua memory (the memory play) after a full collection at the end of cycles 1, 2, 3: %s, %s, %s (+%s, +%s per "
               "cycle); after the effects part and 30 s idle: %s" % (kb(mm[0] * 1024), kb(mm[1] * 1024), kb(mm[2] * 1024), kb(d1 * 1024),
                                                                     kb(d2 * 1024), kb((mend or 0) * 1024)))
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
    counted = [Checks(rep, "default")]
    judge(data, counted[0])
    # (round 8; round 7 review: the gate never loaded XayaUI_Debug, and every install from before round 7 saved Advanced Debugging on,
    # hers included, SD-64) the same scenario with Advanced Debugging on: XayaUI_Debug loaded, judged by every check above
    tag = "[Advanced Debugging on] "
    if not os.path.isdir(os.path.join(GC.ROOT, GC.DEBUG_ADDON)):
        # (an older build played for the calibration or a teeth proof: it has no debug addon to load, so there is nothing to measure)
        rep.note(tag + "variant \"debug\" not played: this checkout has no %s folder" % GC.DEBUG_ADDON)
        rc = rep.show(data, secs, cached)
        print(count_line(rep, counted))
        return rc
    ddata, dsecs, dcached = GC.result("debug")
    rep.note(tag + "variant \"debug\": the same scenario with Settings > Debugging > Advanced Debugging saved on; XayaUI_Debug loaded: %s" %
             ddata.get("debugLoaded"))
    counted.append(Checks(Tagged(rep, tag), "debug"))
    judge(ddata, counted[1])
    rc = rep.show(data, (secs or 0) + (dsecs or 0), cached and dcached)
    print(count_line(rep, counted))   # (round 11 repair) the last line: run_all.py reads its count
    return rc


if __name__ == "__main__":
    sys.exit(main())
