#!/usr/bin/env python3
"""Round 8 gate fixes, proved on the gate's own scenario (REQUEST-LOG A23 SD-66 / SD-68; tests/gate_common.py, tests/gate_performance_run.py).

What the gate must do now, checked on this checkout's addons:
  events   the fight plays movement (PLAYER_STARTED_MOVING / PLAYER_STOPPED_MOVING), a Death Knight's runes (RUNE_POWER_UPDATE), a totem
           (PLAYER_TOTEM_UPDATE) and a stun (LOSS_OF_CONTROL_ADDED / _UPDATE) in every cycle, they reach XayaUI Rules' handlers, and
           the V33 work budget measures them (round 7 review: the gate never fired them, so a movement-heavy or Death Knight fight was
           never measured);
  debug    a second variant plays the same scenario with Settings > Debugging > Advanced Debugging saved on: XayaUI_Debug is loaded
           there and its handlers are measured (its work shows in the budget); in the default variant (Advanced Debugging off) it is
           switched on in the AddOns list and not loaded (V34);
  guard    (SD-68 "Fix gate + guard") the engine as it stands passes the guard (its timer calls hand C_Timer functions made once), and
           a mutant engine whose Kick arms the routed re-check with C_Timer.After(d, function() RoutedTimer() end) on every event is a
           FAIL of the guard at that line ("a new function per timer call on the hot path").
The mutant is this checkout's addon folders copied to the temp folder with only that change, played in this checkout's gate scenario.
Run: python3 tests/fix_r8_gate_scenario_run.py   (Lua 5.1 via lupa; the two variants take about 3.5 minutes each unless the gate's
result is cached, the mutant about 3.5 minutes the first time)"""
import hashlib, os, re, shutil, sys, tempfile
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gate_common as GC          # noqa: E402
import fix_r8_gate_probe_run as PROBE   # noqa: E402  (gate_text / findings: this checkout's gate_performance main() on a result)

FIGHT_EVENTS = ("PLAYER_STARTED_MOVING", "PLAYER_STOPPED_MOVING", "RUNE_POWER_UPDATE", "PLAYER_TOTEM_UPDATE", "LOSS_OF_CONTROL_ADDED",
                "LOSS_OF_CONTROL_UPDATE")
GUARD = r"new function per timer call on the hot path"
MUTANT_RE = re.compile(r"C_Timer\.After\(([^\n]*?),\s*RoutedTimer\)")


def mutant_tree():
    """This checkout's addon folders and gate files in the temp folder, with Engine.lua's routed timer armed through a new closure."""
    dest = os.path.join(tempfile.gettempdir(), "xui_r8_guard_mutant-" + hashlib.sha1(GC.ROOT.encode()).hexdigest()[:10])
    shutil.rmtree(dest, ignore_errors=True)
    for a in GC.ADDONS + (getattr(GC, "DEBUG_ADDON", "XayaUI_Debug"),):
        if os.path.isdir(os.path.join(GC.ROOT, a)):
            shutil.copytree(os.path.join(GC.ROOT, a), os.path.join(dest, a))
    os.makedirs(os.path.join(dest, "tests"))
    shutil.copytree(os.path.join(HERE, "harness"), os.path.join(dest, "tests", "harness"), ignore=shutil.ignore_patterns("reports", "__pycache__"))
    for f in os.listdir(HERE):
        if f.startswith("gate_") and f.endswith(".py"):
            shutil.copy(os.path.join(HERE, f), os.path.join(dest, "tests", f))
    eng = os.path.join(dest, "XayaUI_Rules", "Engine.lua")
    src = open(eng, encoding="utf-8").read()
    new, n = MUTANT_RE.subn(r"C_Timer.After(\1, function() RoutedTimer() end)", src)
    with open(eng, "w", encoding="utf-8") as fh:
        fh.write(new)
    lines = [i + 1 for i, l in enumerate(new.split("\n")) if "function() RoutedTimer() end" in l]
    return dest, n, lines


def main():
    fails, done = [], []

    def check(ok, what, detail=""):
        print(("ok   " if ok else "FAIL ") + what + (("  [" + detail + "]") if (detail and not ok) else ""))
        done.append(what)
        if not ok:
            fails.append(what)

    data, _, _ = GC.result()
    check(int(data.get("errors") or 0) == 0, "the gate's scenario ran without a Lua error", "; ".join(data.get("errorText") or [])[:300])

    # ---- events -----------------------------------------------------------------------------------------------------------------
    fired = data.get("fired") or {}
    # (per cycle: 15 s x 30 frames = 450 storm frames; moving starts at frame i % 15 == 3: 30 a cycle; runes at i % 10 == 6: 45; a totem
    # at i % 90 == 45: 5; a stun added at i % 150 == 75: 3, updated at i % 150 == 76 and 120: 6; three cycles)
    want = {"PLAYER_STARTED_MOVING": 90, "PLAYER_STOPPED_MOVING": 90, "RUNE_POWER_UPDATE": 135, "PLAYER_TOTEM_UPDATE": 15,
            "LOSS_OF_CONTROL_ADDED": 9, "LOSS_OF_CONTROL_UPDATE": 18}
    check(all(int(fired.get(e) or 0) == n for e, n in want.items()),
          "events: the fight fires movement, runes, a totem and a stun the planned number of times over the three cycles", "fired %s" % fired)
    ev = (data.get("stats") or {}).get("ev") or {}
    reached = [e for e in FIGHT_EVENTS if any(s.startswith("XayaUI_Rules/") for s in ((ev.get(e) or {}).get("srcs") or {}))]
    check(len(reached) == len(FIGHT_EVENTS), "events: each of them reaches a XayaUI Rules handler (measured by the dispatcher)",
          "reached %s" % reached)
    B = data.get("budget") or {}
    keys = set()
    for s in ("fight 1", "fight 2", "fight 3"):
        keys |= set((((B.get(s) or {}).get("keys") or {}).get("XayaUI_Rules") or {}).keys())
    check(all(e in keys for e in FIGHT_EVENTS), "events: the V33 work budget of the fight counts XayaUI Rules' work on each of them",
          "budget keys missing: %s" % [e for e in FIGHT_EVENTS if e not in keys])

    # ---- debug variant ----------------------------------------------------------------------------------------------------------
    check(data.get("debugLoaded") is False and data.get("variant") == "default",
          "debug: in the default variant (Advanced Debugging off) XayaUI_Debug is switched on in the AddOns list and not loaded (V34)",
          "variant %s, loaded %s" % (data.get("variant"), data.get("debugLoaded")))
    try:
        dd, _, _ = GC.result("debug")
    except TypeError as e:
        dd = {}
        check(False, "debug: the gate has a variant with Advanced Debugging on", str(e))
    if dd:
        check(int(dd.get("errors") or 0) == 0, "debug: the scenario with Advanced Debugging on ran without a Lua error",
              "; ".join(dd.get("errorText") or [])[:300])
        check(dd.get("debugLoaded") is True, "debug: with Advanced Debugging saved on, core loaded XayaUI_Debug at login")
        dB = dd.get("budget") or {}
        segs = [s for s, v in dB.items() if "XayaUI_Debug" in ((v.get("work") or {}))]
        check(bool(segs), "debug: XayaUI_Debug's handlers are measured by the work budget (its addon appears in the budget's segments)",
              "segments with XayaUI_Debug: %s" % segs)
        text = PROBE.gate_text(dd)
        check(re.search(r"V33 XayaUI_Debug: .* per fight frame", text) is not None,
              "debug: the gate prints XayaUI_Debug's V33 line (judged under her 1% always)")

    # ---- guard on the real engine, and on a mutant engine ------------------------------------------------------------------------
    fs = PROBE.findings(PROBE.gate_text(data))
    eng_guard = [f for f in fs if f[1].startswith("XayaUI_Rules/Engine.lua") and re.search(GUARD, f[2])]
    check(not eng_guard, "guard: the engine as it stands hands C_Timer functions made once (no guard FAIL in Engine.lua)",
          "; ".join(f[1] for f in eng_guard))
    tree, n, lines = mutant_tree()
    check(n >= 1, "guard: the mutant (C_Timer.After(d, function() RoutedTimer() end)) could be made from Engine.lua (%d site(s), lines %s)" % (n, lines))
    if n:
        mdata, _ = GC.tree_result(tree)
        mf = PROBE.findings(PROBE.gate_text(mdata))
        hit = [f for f in mf if f[0] == "FAIL" and f[1].split(" ")[0] in ["XayaUI_Rules/Engine.lua:%d" % l for l in lines] and re.search(GUARD, f[2])]
        check(bool(hit), "guard: the mutant engine is a FAIL of the guard at the closure's line (Engine.lua %s)" % lines,
              "guard findings: %s" % [f[1] for f in mf if re.search(r"new function per timer call", f[2])])
    print("%d checks, %d failed" % (len(done), len(fails)))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
