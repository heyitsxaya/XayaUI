#!/usr/bin/env python3
"""V27 release gate, keyboard (Xaya, 2026-11-10, REQUEST-LOG A23 SD-28, her words): "nothing impacts keyboard ability to interact with
the game once xui options window is closed (unless otherwise directly scripted — this functionality is not a concern yet, since we
don't have custom script injection enabled)"; with V29 (SD-3, SD-11): the screenshot key is never held, nothing takes the keyboard in
combat, every text box lets go.

The scenario (tests/gate_common.py) is the same as the mouse gate's. At every checkpoint after the settings window closed (out of
combat, in each of three fights, after each fight, after 30 seconds idle) the gate checks:
  FAIL  a XayaUI frame is keyboard-enabled (shown: it takes keys now; hidden: it takes them the moment it is shown);
  FAIL  a XayaUI edit box has the keyboard focus;
  FAIL  the screenshot key (PRINTSCREEN), a movement key (W) or jump (SPACE) does not reach the game's key bindings;
  FAIL  XayaUI code, after the close, turned a frame's keyboard on, focused an edit box, set SetPropagateKeyboardInput(false) or
        changed a key binding (SetBinding* / SetOverrideBinding*);
  NOTE  SetPropagateKeyboardInput(true) after the close (it hands keys back to the game) is listed, not failed.
Each violation: the line that turned the keyboard on (or made the frame), which checkpoints, in or out of combat.
(round 9; SD-64: she keeps Advanced Debugging on; round 8 review) every check runs on both variants of the scenario, Advanced
Debugging off and on (XayaUI_Debug loaded); findings of the second are marked "[Advanced Debugging on]".
(round 10; REQUEST-LOG A23 SD-98, SD-99, her words: "v27 is only if ALL windows of XUI are closed; XUI windows that are actively opened
and have the mouse over them should accept clicks [...]") the windows she opens herself (the Calculator keypad, whose text box takes the
keyboard focus; the Stat Calculator panel on its own and docked) are played open and closed. Key presses are judged only while every
XayaUI window is closed; while a window she opened is open, its own keyboard and text-box focus and the keyboard calls its code makes are
listed (NOTE), and every frame outside it is judged as above. After its close every check above applies again: a frame of it still
keyboard-enabled (shown or hidden), a text box of it still holding the focus, or a key that no longer reaches the game, FAILs.
Run: python3 tests/gate_keyboard_run.py  (Lua 5.1 via lupa; about two minutes, or seconds when the shared result is cached)."""
import collections, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gate_common as GC  # noqa: E402

GATE = "gate_keyboard"


class Checks(object):
    """(round 11 repair; R11A final: this gate printed no count line, so the honest-result guard read it as NO COUNT LINE; SD-138 / V35
    "a test fails ... if it prints no result count") The gate's checks, counted for its last line, as gate_performance counts its own.
    judge() names each check as it starts it (begin()); every FAIL reported while a check runs counts against that check. Warnings and
    notes judge nothing and are not counted as checks. A plain Report (a test calling judge() itself: fix_r9_gate_probe,
    fix_r10_gate_bonus) has no begin(), so begin() leaves it as it is.
    (Kept in this file, not imported from gate_performance_run.py, so a fault in one gate cannot stop another; the shared home for it is
    gate_common.Report, reported to its owner.)"""

    def __init__(self, rep, label):
        self.rep, self.label, self.run, self.warns = rep, label, [], 0

    def begin(self, name):
        self.run.append([name, 0])

    def fail(self, where, what, numbers, fix):
        if not self.run:
            self.begin("(a FAIL before any named check)")
        self.run[-1][1] += 1
        self.rep.fail(where, what, numbers, fix)

    def warn(self, where, what, numbers="", fix=""):
        self.warns += 1
        self.rep.warn(where, what, numbers, fix)

    def note(self, text):
        self.rep.note(text)


def begin(rep, name):
    """Names the check that starts now, when rep counts checks (Checks); a plain Report ignores it."""
    b = getattr(rep, "begin", None)
    if b is not None:
        b(name)


def count_line(counted):
    """The gate's last line, read by tests/run_all.py: the checks run in every variant judged, the checks with a violation, and (as on the
    line before it) the violations and warnings: "<gate>: N checks, M failed (variant default: n; variant debug: n; ...)  FAILS: K"."""
    n = sum(len(c.run) for c in counted)
    bad = [(c.label, name) for c in counted for name, f in c.run if f]
    k = sum(f for c in counted for _name, f in c.run)
    parts = "; ".join("variant %s: %d" % (c.label, len(c.run)) for c in counted)
    return "%s: %d checks, %d failed (%s%s; %d violation(s), %d warning(s))  FAILS: %d" % (
        GATE, n, len(bad), parts, ("; failed: " + ", ".join("%s %s" % b for b in bad)) if bad else "", k, sum(c.warns for c in counted), k)



def judge(data, rep):
    """Every check of this gate on one variant's result (round 9: both variants, see main). (round 11 repair) Each check is named as it
    starts (begin(): its FAILs count against it for the count line, see Checks); a plain Report passes through unchanged."""
    begin(rep, "the scenario ran as planned (gate_common.integrity)")
    GC.integrity(data, rep)
    cps = data.get("checkpoints") or []
    n_in = sum(1 for cp in cps if cp.get("combat"))
    rep.note("checkpoints judged: %d (%d in combat, %d out of combat), all after the settings window closed" % (len(cps), n_in, len(cps) - n_in))
    begin(rep, "the checkpoints cover both in and out of combat")
    if n_in == 0 or n_in == len(cps):
        rep.fail("tests/gate_common.py (the scenario)", "the checkpoints must cover both in and out of combat", "in combat: %d of %d" % (n_in, len(cps)), "")

    def gather(key):
        out = collections.OrderedDict()
        for cp in cps:
            for e in cp.get(key) or []:
                k = (e.get("by") or "?", e.get("where"))
                o = out.setdefault(k, {"cps": [], "combat": set(), "name": e.get("name"), "kind": e.get("kind"), "e": e})
                o["cps"].append(cp["label"])
                o["combat"].add("in combat" if cp.get("combat") else "out of combat")
        return out

    begin(rep, "no XayaUI frame, shown or hidden, is keyboard-enabled with every window closed")
    for key, what in (("keyboard", "a shown XayaUI frame is keyboard-enabled (it takes keys before the game does)"),
                      ("kbHidden", "a hidden XayaUI frame is still keyboard-enabled (it takes keys the moment it is shown)")):
        for (by, made), o in gather(key).items():
            prop = o["e"].get("propagate")
            rep.fail(GC.short(by) if by != "?" else made, "%s: %s %s" % (what, o["kind"], o["name"]),
                     "made at %s; turned on by %s; propagate %s; %s; at: %s" % (made, by, prop, " and ".join(sorted(o["combat"])), "; ".join(o["cps"])),
                     "turn the keyboard off (EnableKeyboard(false), through core's KeyCatch) when the settings window closes and out of combat only (V29)")

    begin(rep, "no XayaUI edit box holds the keyboard focus with every window closed")
    focus = collections.OrderedDict()
    for cp in cps:
        for e in cp.get("focus") or []:
            if not e.get("xui"):
                continue
            o = focus.setdefault(e.get("where"), {"cps": [], "visible": set(), "name": e.get("name")})
            o["cps"].append(cp["label"] + (" (in combat)" if cp.get("combat") else ""))
            o["visible"].add("shown" if e.get("visible") else "hidden")
    for made, o in focus.items():
        rep.fail(made, "a XayaUI edit box (%s) has the keyboard focus with the settings window closed" % o["name"],
                 "%s; at: %s" % ("/".join(sorted(o["visible"])), "; ".join(o["cps"])),
                 "ClearFocus() on close, on combat start, on Enter / Esc and on a click outside (V29, core KeyFocusGuard)")
    others = sorted({e.get("name") for cp in cps for e in cp.get("focus") or [] if not e.get("xui")})
    if others:
        rep.note("edit boxes with focus that XayaUI did not make (not judged): " + ", ".join(map(str, others)))

    begin(rep, "keys were pressed, and PRINTSCREEN, W and SPACE reach the game at every checkpoint with every window closed")
    keys = collections.OrderedDict()
    tried = 0
    for cp in cps:
        for k in cp.get("keys") or []:
            tried += 1
            if not k.get("reached"):
                o = keys.setdefault((k.get("key"), k.get("byWhere") or k.get("by")), [])
                o.append(cp["label"] + (" (in combat)" if cp.get("combat") else ""))
    rep.note("key presses tried: %d (PRINTSCREEN, W and SPACE at every checkpoint where every XayaUI window is closed)" % tried)
    # (round 10, SD-99) while a window she opened is open: what took the keys, its keyboard and focus (listed, not judged)
    for cp in cps:
        if cp.get("open"):
            rep.note("%s: keys (not judged while a window she opened is open, SD-99): %s; keyboard-enabled in it: %d; text box focus in it: %s" % (
                cp["label"], ", ".join("%s %s" % (k.get("key"), "reached the game" if k.get("reached") else "kept by %s" % (k.get("byWhere") or k.get("by")))
                                       for k in cp.get("winKeys") or []),
                len(cp.get("winKb") or []), ", ".join(str(f.get("where")) for f in cp.get("winFocus") or []) or "none"))
    for call, n in ((data.get("win") or {}).get("kbCalls") or {}).items():
        rep.note("while a window she opened was open: %s, %d time(s) (that window's own; not judged, SD-99)" % (call, n))
    if tried == 0:
        rep.fail("tests/gate_common.py (the scenario)", "no key was pressed at any checkpoint", "", "")
    for (key, by), labels in keys.items():
        rep.fail(str(by), "the %s key did not reach the game: it was kept by %s" % (key, by), "at: " + "; ".join(labels),
                 "nothing XayaUI shows with the window closed may take keys (V27, V29: the screenshot key is never held)")

    begin(rep, "no keyboard call by XayaUI code after the close (SetPropagateKeyboardInput(true) out of combat allowed)")
    for call, n in (data.get("kbCalls") or {}).items():
        line = call.split(" ")[0]
        if "SetPropagateKeyboardInput(true)" in call and "(in combat)" not in call:
            rep.note("after the close: %s, %d time(s) (hands keys back to the game: allowed)" % (call, n))
            continue
        rep.fail(line, "after the settings window closed, XayaUI code called " + call[len(line) + 1:],
                 "%d call(s)" % n,
                 "no keyboard work once the window is closed (V27, V28); in combat SetPropagateKeyboardInput is blocked (widgets.md 295, HasRestrictions)")


def main():
    # (round 9; SD-64 she keeps Advanced Debugging on; round 8 review: only the default variant was judged) both variants
    # (round 11 repair) each variant's judge counts its checks (Checks) for the last line
    counted = []

    def counting(data, rep):
        c = Checks(rep, data.get("variant") or "default")
        counted.append(c)
        judge(data, c)
    rc = GC.both_variants(GATE, counting)
    print(count_line(counted))   # the last line: run_all.py reads its count
    return rc


if __name__ == "__main__":
    sys.exit(main())
