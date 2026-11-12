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
Run: python3 tests/gate_keyboard_run.py  (Lua 5.1 via lupa; about two minutes, or seconds when the shared result is cached)."""
import collections, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gate_common as GC  # noqa: E402

GATE = "gate_keyboard"


def main():
    data, secs, cached = GC.result()
    rep = GC.Report(GATE)
    GC.integrity(data, rep)
    cps = data.get("checkpoints") or []
    n_in = sum(1 for cp in cps if cp.get("combat"))
    rep.note("checkpoints judged: %d (%d in combat, %d out of combat), all after the settings window closed" % (len(cps), n_in, len(cps) - n_in))
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

    for key, what in (("keyboard", "a shown XayaUI frame is keyboard-enabled (it takes keys before the game does)"),
                      ("kbHidden", "a hidden XayaUI frame is still keyboard-enabled (it takes keys the moment it is shown)")):
        for (by, made), o in gather(key).items():
            prop = o["e"].get("propagate")
            rep.fail(GC.short(by) if by != "?" else made, "%s: %s %s" % (what, o["kind"], o["name"]),
                     "made at %s; turned on by %s; propagate %s; %s; at: %s" % (made, by, prop, " and ".join(sorted(o["combat"])), "; ".join(o["cps"])),
                     "turn the keyboard off (EnableKeyboard(false), through core's KeyCatch) when the settings window closes and out of combat only (V29)")

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

    keys = collections.OrderedDict()
    tried = 0
    for cp in cps:
        for k in cp.get("keys") or []:
            tried += 1
            if not k.get("reached"):
                o = keys.setdefault((k.get("key"), k.get("byWhere") or k.get("by")), [])
                o.append(cp["label"] + (" (in combat)" if cp.get("combat") else ""))
    rep.note("key presses tried: %d (PRINTSCREEN, W and SPACE at every checkpoint)" % tried)
    if tried == 0:
        rep.fail("tests/gate_common.py (the scenario)", "no key was pressed at any checkpoint", "", "")
    for (key, by), labels in keys.items():
        rep.fail(str(by), "the %s key did not reach the game: it was kept by %s" % (key, by), "at: " + "; ".join(labels),
                 "nothing XayaUI shows with the window closed may take keys (V27, V29: the screenshot key is never held)")

    for call, n in (data.get("kbCalls") or {}).items():
        line = call.split(" ")[0]
        if "SetPropagateKeyboardInput(true)" in call and "(in combat)" not in call:
            rep.note("after the close: %s, %d time(s) (hands keys back to the game: allowed)" % (call, n))
            continue
        rep.fail(line, "after the settings window closed, XayaUI code called " + call[len(line) + 1:],
                 "%d call(s)" % n,
                 "no keyboard work once the window is closed (V27, V28); in combat SetPropagateKeyboardInput is blocked (widgets.md 295, HasRestrictions)")
    return rep.show(data, secs, cached)


if __name__ == "__main__":
    sys.exit(main())
