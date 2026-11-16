#!/usr/bin/env python3
"""Round 10 gate: XayaUI Bonus Features folded into the V27 gates, the windows she opens, Bonus's per-event caps, the game-played sound's
edges (bundle 1 round 10; tests/gate_common.py, gate_performance_run.py, gate_mouse_run.py, gate_keyboard_run.py).

Her answers (verbatim, REQUEST-LOG A23):
  SD-98  "Yes, fold in (Recommended)": fold Bonus into the two existing variants: a fresh install lists XayaUI_Bonus with the Stat
         Calculator off (integrity: XayaUI_Bonus_StatCalculator not loaded); the Advanced Debugging variant (her install) also has the
         Stat Calculator on; memory cap stays 39,959.7 KB.
  SD-99  "v27 is only if ALL windows of XUI are closed; XUI windows that are actively opened and have the mouse over them should accept
         clicks unless a "allow clickthrough" is flagged (only available for rules)"; SD-114 "No, keep as is" (no such flag: rule
         displays always pass clicks once every XayaUI window is closed); SD-100 "stat calculator isn't allowed to be open during combat";
         SD-102 "Don't reappear"; SD-105 "Load at first open (Recommended)".
  SD-112 / SD-117 "600, same as core (Recommended)": the per-event caps of XayaUI_Bonus_StatCalculator and XayaUI_Bonus.
  SD-96 "This function needs to work as intended and expected" (the game-played sound; its edges at combat start, a boss pull and combat
         end are measured by the gate).

What is checked (V1: what the gate plays and what it reports, not that a setting exists):
  live     the gate's own scenario on this checkout (both variants; read from the gates' shared cache when there, else played): XayaUI_Bonus
           loaded in both; the Stat Calculator NOT loaded in a fresh install after /xui stats and the character window; in hers, both
           XayaUI_Debug and the Stat Calculator loaded after its panel was opened on its own and docked and closed, and open as each fight
           started; checkpoints with the panel open name it as a window she opened; the game-played sound's edges ran at combat start, the
           boss pull and combat end; the per-event lines for both Bonus addons are printed in both variants, every moment on its own line;
  judges   the gates' judges on copies of that result with one thing changed (mutants of the data), each must FAIL on exactly that, and
           the unchanged result must not: a Bonus / Stat Calculator frame at 601 instructions at combat start, the boss pull or combat end
           (and 600 passes); the Stat Calculator loaded in a fresh install; not loaded in hers; the panel not open at a fight's start; a
           window frame taking the mouse outside its window; a window shown in a fight; a window shown after its close; a key kept by a
           frame after the window closed; a sound edge that did not run (a gate WARNING: older builds the gate plays have no edges); the
           Calculator listed in XayaUI_Bonus but its keypad not opened.
Run: python3 tests/fix_r10_gate_bonus_run.py   (Lua 5.1 via lupa; with the gates' cache a few seconds, else about 10 minutes)"""
import contextlib, copy, io, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gate_common as GC          # noqa: E402
import gate_performance_run as GP  # noqa: E402
import gate_mouse_run as GM        # noqa: E402
import gate_keyboard_run as GK     # noqa: E402

MOMENTS = ("combat start", "boss pull", "combat end")


def fails_of(judge, data):
    rep = GC.Report("probe")
    with contextlib.redirect_stdout(io.StringIO()):
        judge(data, rep)
    return rep


def text_of(rep, kind="fails"):
    return ["%s | %s | %s" % (w, what, nums) for (w, what, nums, _fix) in getattr(rep, kind)]


def has(rep, *needles, kind="fails"):
    return any(all(n in t for n in needles) for t in text_of(rep, kind))


def has_at(rep, where, *needles):
    """A FAIL placed at exactly this addon / line (the Stat Calculator's name contains Bonus Features' name)."""
    return any(w == where and all(n in "%s %s" % (what, nums) for n in needles) for (w, what, nums, _f) in rep.fails)


def lst(d, key):
    """A list field of a checkpoint (an empty Lua table comes back from JSON as {})."""
    v = d.get(key)
    if not isinstance(v, list):
        v = []
        d[key] = v
    return v


def main():
    fails, done = [], []

    def check(ok, what, detail=""):
        print(("ok   " if ok else "FAIL ") + what + (("  [" + str(detail)[:600] + "]") if (detail and not ok) else ""))
        done.append(what)
        if not ok:
            fails.append(what)

    print("Round 10 gate: Bonus folded in (SD-98), the windows she opens (SD-99), Bonus per-event caps (SD-112, SD-117), sound edges")
    check(set(getattr(GC, "BONUS_ADDONS", ("XayaUI_Bonus", "XayaUI_Bonus_StatCalculator"))) <= set(GC.ADDONS), "the gate switches XayaUI_Bonus and XayaUI_Bonus_StatCalculator on in every play (SD-98)",
          "ADDONS %s" % (GC.ADDONS,))
    caps = getattr(GP, "BONUS_EVENT_CAPS", {})
    check(caps.get("XayaUI_Bonus_StatCalculator", (None,))[0] == 600 and caps.get("XayaUI_Bonus", (None,))[0] == 600,
          "gate_performance holds XayaUI_Bonus_StatCalculator (SD-112) and XayaUI_Bonus (SD-117) to 600 instructions per event", caps)

    # ---- live: the gate's scenario on this checkout ------------------------------------------------------------------------------
    dd, _, cd = GC.result("default")
    dg, _, cg = GC.result("debug")
    print("  results: default %s, debug %s" % ("from the cache" if cd else "played now", "from the cache" if cg else "played now"))
    ld, lg = dd.get("addonsLoaded") or {}, dg.get("addonsLoaded") or {}
    check(ld.get("XayaUI_Bonus") is True and lg.get("XayaUI_Bonus") is True, "XayaUI_Bonus is loaded in both variants (SD-98)", (ld, lg))
    check(ld.get("XayaUI_Bonus_StatCalculator") is False, "a fresh install: the Stat Calculator is NOT loaded, after /xui stats and the "
          "character window too (V34, SD-98)", ld)
    check(lg.get("XayaUI_Bonus_StatCalculator") is True and dg.get("debugLoaded") is True,
          "her install: XayaUI_Debug and the Stat Calculator are both loaded after its panel was opened and closed (SD-98, SD-105)", (lg, dg.get("debugLoaded")))
    w = dg.get("win") or {}
    alone, docked = w.get("alone") or {}, w.get("docked") or {}
    at = w.get("atFight")
    atl = [bool(at.get(str(c))) for c in (1, 2, 3)] if isinstance(at, dict) else [bool(x) for x in (at or [])]
    check(int(alone.get("opened") or 0) > 0 and not alone.get("still"), "her install: the panel opened on its own and closed again", alone)
    check(int(docked.get("opened") or 0) > 0 and not docked.get("still"), "her install: the panel opened docked beside the character window "
          "and closed with it", docked)
    check(atl == [True, True, True], "her install: the panel was open as each of the three fights started (its combat-start close is "
          "measured: SD-100, SD-112)", atl)
    labels = [cp.get("label") for cp in dg.get("checkpoints") or [] if cp.get("open")]
    check(any("on its own" in str(l) for l in labels) and any("docked" in str(l) for l in labels),
          "her install: the checkpoints with the panel open (on its own, docked) name it as a window she opened (SD-99)", labels)
    check(all(not lst(cp, "keys") and len(lst(cp, "winKeys")) == 3 for cp in dg.get("checkpoints") or [] if cp.get("open"))
          and all(len(lst(cp, "keys")) == 3 for cp in dg.get("checkpoints") or [] if not cp.get("open")),
          "the keys pressed while a window she opened is open are kept apart (not judged, SD-99); at every other checkpoint all three "
          "(PRINTSCREEN, W, SPACE) are judged", [(cp.get("label"), len(lst(cp, "keys")), len(lst(cp, "winKeys"))) for cp in dg.get("checkpoints") or []][:6])
    closed_after = [cp.get("label") for cp in dg.get("checkpoints") or [] if str(cp.get("label", "")).startswith("after the") and not cp.get("open")]
    check(len(closed_after) >= 2, "her install: after each close a checkpoint judges everything closed again (keys, mouse, focus)", closed_after)
    for d, v in ((dd, "default"), (dg, "debug")):
        e = d.get("soundEdges") or {}
        check(all(int((e.get(m) or {}).get("add") or 0) + int((e.get(m) or {}).get("rem") or 0) > 0 for m in MOMENTS),
              "%s: the game-played sound's edges ran at combat start, the boss pull and combat end, inside the frames the per-event cap "
              "judges" % v, e)
    stamp = GP.V33_EVENT_CAPS["stamp"]
    for d, v in ((dd, "default"), (dg, "debug")):
        rep = GC.Report("probe")
        GP.event_caps(d, rep, None, stamp, None)
        notes = "\n".join(rep.notes + text_of(rep))
        for a, (cap, sd, _ans) in sorted(caps.items()):
            nm = GP.NAMES.get(a, a)
            check(("V33 %s per event (%s): costliest single fight frame" % (nm, sd)) in notes
                  and all(("V33 %s per event, %s (%s)" % (nm, what, sd)) in notes for _m, what in GP.MOMENTS),
                  "%s: %s's per-event line and its combat start / boss pull / boss down / combat end lines are printed (cap %d, %s)" % (v, nm, cap, sd),
                  notes[:400])

    # ---- judges on mutants of the result ------------------------------------------------------------------------------------------
    def budget_mut(d, addon, moment, ins):
        x = copy.deepcopy(d)
        x.setdefault("budget", {})
        seg = {"combat start": "fight 2", "boss pull": "fight 2", "boss down": "fight 2", "combat end": "end 2"}[moment]
        s = x["budget"].setdefault(seg, {"frames": 0, "work": {}, "peak": {}, "sec": {}, "keys": {}})
        s.setdefault("peak", {})[addon] = ins
        s.setdefault("moments", {}).setdefault(moment, {})[addon] = ins
        return x

    base_ok = {}
    for d, v in ((dd, "default"), (dg, "debug")):
        for a in caps:
            # (an unchanged result: the gate's verdict on this checkout's addon is its own business; the probe reads only the mutant's
            # extra FAIL, so it starts from a result whose Bonus peaks are set to a passing 600)
            good = copy.deepcopy(d)
            for s in good.get("budget", {}).values():
                if (s.get("peak") or {}).get(a, 0) > 600:
                    s["peak"][a] = 600
                for mm in (s.get("moments") or {}).values():
                    if mm.get(a, 0) > 600:
                        mm[a] = 600
            rep = GC.Report("probe")
            GP.event_caps(good, rep, None, stamp, None)
            base_ok[(v, a)] = not has_at(rep, a, "above her cap")
            check(base_ok[(v, a)], "%s: %s at 600 instructions in every fight frame passes (her cap is 600, not less)" % (v, a), text_of(rep))
            for m in MOMENTS:
                rep = GC.Report("probe")
                GP.event_caps(budget_mut(good, a, m, 601), rep, None, stamp, None)
                what = dict(GP.MOMENTS)[m]
                check(has_at(rep, a, "above her cap", what),
                      "%s: %s at 601 instructions in the frame after %s FAILs (%s)" % (v, a, m, caps[a][1]), text_of(rep))

    def integ(d):
        rep = GC.Report("probe")
        GC.integrity(d, rep)
        return rep
    r0d, r0g = integ(dd), integ(dg)
    check(not has(r0d, "Stat Calculator") and not has(r0d, "Bonus"), "default: the unchanged result raises no Bonus / Stat Calculator integrity FAIL",
          text_of(r0d))
    check(not has(r0g, "Stat Calculator") and not has(r0g, "Bonus"), "debug: the unchanged result raises no Bonus / Stat Calculator integrity FAIL",
          text_of(r0g))
    m = copy.deepcopy(dd); m.setdefault("addonsLoaded", {})["XayaUI_Bonus_StatCalculator"] = True
    check(has(integ(m), "is NOT loaded"), "mutant: the Stat Calculator loaded in a fresh install FAILs (V34)")
    m = copy.deepcopy(dd); m.setdefault("addonsLoaded", {})["XayaUI_Bonus"] = False
    check(has(integ(m), "XayaUI Bonus Features is switched on"), "mutant: XayaUI_Bonus not loaded FAILs (SD-98)")
    m = copy.deepcopy(dg); m.setdefault("addonsLoaded", {})["XayaUI_Bonus_StatCalculator"] = False
    check(has(integ(m), "are both loaded"), "mutant: her install with the Stat Calculator not loaded after its open FAILs (SD-105)")
    m = copy.deepcopy(dg); m.setdefault("win", {})["atFight"] = [True, False, True]
    check(has(integ(m), "as each of the three fights started"), "mutant: the panel not open as fight 2 starts FAILs (its close is not measured)")
    m = copy.deepcopy(dg); m.setdefault("win", {})["docked"] = {"opened": 1, "still": ["the Stat Calculator docked"]}
    check(has(integ(m), "docked beside the character window"), "mutant: the docked panel still shown after the character window closed FAILs")
    m = copy.deepcopy(dd); m.setdefault("soundEdges", {})["boss pull"] = {"add": 0, "rem": 0}
    check(has(integ(m), "edge at boss pull", kind="warns"), "mutant: no game-played sound edge at the boss pull is a gate WARNING (the edge is "
          "not measured; the live check above FAILs it on this checkout)")
    m = copy.deepcopy(dd); m["bonusTree"] = {"folders": {"XayaUI_Bonus": True, "XayaUI_Bonus_StatCalculator": True}, "calcFiles": ["Calculator.lua"]}
    m.setdefault("win", {})["keypad"] = {"opened": 0}
    check(has(integ(m), "Calculator keypad"), "mutant: XayaUI_Bonus lists the Calculator but its keypad did not open FAILs (SD-115, SD-116)")
    m["win"]["keypad"] = {"opened": 1, "still": []}
    check(not has(integ(m), "Calculator keypad"), "the Calculator listed and its keypad opened and closed: no keypad FAIL")

    # the mouse and keyboard judges (SD-99)
    def mouse(d):
        return fails_of(GM.judge, d)

    def cps_of(d):
        return d.get("checkpoints") or []
    base_m = mouse(dg)
    open_cps = [cp for cp in cps_of(dg) if cp.get("open")]
    check(bool(open_cps) and all(not cp.get("mouse") for cp in open_cps) and any(cp.get("winMouse") for cp in open_cps),
          "her install, the panel open: its frames that take the mouse inside its rectangle are the window's (allowed), not judged as "
          "click catchers over the game (SD-99)", [(cp.get("label"), len(cp.get("mouse") or []), len(cp.get("winMouse") or [])) for cp in open_cps])
    check(has(base_m, "the mouse outside the window's own rectangle") == any(cp.get("winOutside") for cp in open_cps),
          "the mouse gate FAILs a window frame outside its rectangle exactly when the scenario found one",
          [e for cp in open_cps for e in cp.get("winOutside") or []][:3])
    m = copy.deepcopy(dg)
    oc = ([cp for cp in cps_of(m) if cp.get("open")] or [{}])[0]
    lst(oc, "winOutside").append({"name": "a Button", "kind": "Button", "where": "XayaUI_Bonus_StatCalculator/Probe.lua:1",
                                            "by": "XayaUI_Bonus_StatCalculator/Probe.lua:2 EnableMouse(true)", "window": "probe window",
                                            "click": True, "rect": "2000,10 20x20"})
    check(has(mouse(m), "Probe.lua:2", "outside the window's own rectangle"), "mutant: a window frame taking clicks outside its rectangle FAILs (SD-99)")
    m = copy.deepcopy(dg)
    fc = ([cp for cp in cps_of(m) if cp.get("combat")] + [{}, {}])[1]
    lst(fc, "winShown").append({"name": "the Stat Calculator panel on its own", "where": "XayaUI_Bonus_StatCalculator/Probe.lua:3", "combat": True})
    check(has(mouse(m), "Probe.lua:3", "shown in a fight"), "mutant: the panel shown in a fight FAILs (SD-100)")
    m = copy.deepcopy(dg)
    ac = ([cp for cp in cps_of(m) if str(cp.get("label", "")).startswith("out of combat after the fight")] or [{}])[0]
    lst(ac, "winShown").append({"name": "the Stat Calculator panel on its own", "where": "XayaUI_Bonus_StatCalculator/Probe.lua:4", "combat": False})
    check(has(mouse(m), "Probe.lua:4", "Don't reappear"), "mutant: the panel back by itself after a fight FAILs (SD-102)")
    m = copy.deepcopy(dd)
    m.setdefault("checkpoints", []).append({"label": "after the Calculator keypad closed", "combat": False, "keys": [
        {"key": "PRINTSCREEN", "reached": False, "by": "an EditBox", "byWhere": "XayaUI_Bonus/Probe.lua:5"}], "focus": [
        {"name": "an edit box", "where": "XayaUI_Bonus/Probe.lua:6", "xui": True, "visible": False}]})
    kb = fails_of(GK.judge, m)
    check(has(kb, "Probe.lua:5", "PRINTSCREEN") and has(kb, "Probe.lua:6", "keyboard focus"),
          "mutant: after the keypad closed, a key it still keeps and its text box still focused FAIL (V27, V29)", text_of(kb))
    m = copy.deepcopy(dd)
    m.setdefault("checkpoints", []).append({"label": "the Calculator keypad is open (a window she opened)", "combat": False, "open": [{"name": "probe"}],
        "keys": [], "winKeys": [{"key": "W", "reached": False, "by": "an EditBox", "byWhere": "XayaUI_Bonus/Probe.lua:7"}], "winFocus": [
        {"name": "an edit box", "where": "XayaUI_Bonus/Probe.lua:8", "window": "probe"}]})
    kb = fails_of(GK.judge, m)
    check(not has(kb, "Probe.lua:7") and not has(kb, "Probe.lua:8"), "the keypad open: its text box holding the keys is hers while she has "
          "it open (SD-99; listed, not failed)", text_of(kb))

    print("%d checks, %d failed" % (len(done), len(fails)))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
