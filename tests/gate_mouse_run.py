#!/usr/bin/env python3
"""V27 release gate, mouse (Xaya, 2026-11-10, REQUEST-LOG A23 SD-28 / SD-29, her words): "nothing impacts mouse ability to interact with
(click, toggle, use, etc) in-game objects, buttons, or screen panning once xui options window is closed"; her answer on how to read it:
"Hover only, clicks pass" (a display may show a hover tooltip, but every click and camera drag passes through to the game; the minimap
menu closes on any click or Esc without catching that click).

The scenario (tests/gate_common.py): a ~300-rule profile; the settings window opened, used and closed; the mover opened and closed; the
minimap button's list opened and closed; three 20-second cycles of the busiest case (loading screen, mount, group, fight with event
storms); 30 seconds idle. At every checkpoint after the window closed (out of combat, in each fight, after each fight, idle) the gate
looks at every shown frame XayaUI made (or that sits in one it made):
  FAIL     it takes mouse clicks (clicks on and not passed on) and covers part of the screen (the minimap button itself is allowed;
           the minimap list's own rows are allowed while the list is open);
  FAIL     it takes the mouse at all over half the screen or more (a full-screen catcher);
  FAIL     it takes the mouse wheel (stops camera zoom: INFERENCE, the wheel is not documented to pass through);
  FAIL     the minimap list: a click on the game world while it is open is taken by a XayaUI frame, or it does not close on that click,
           or it does not close on Esc (UISpecialFrames), or it is still open at the end;
  WARNING  hover-only frames (motion on, clicks off), with the line that turned motion on: allowed by her answer for now, listed
           because SD-37 may revisit hover (a hover-enabled frame above the world may still block world mouseover);
  WARNING  aura buttons Blizzard's container made for the combat engine whose click state XayaUI never set (not documented).
Each violation: the line that turned clicks on (or the line that made the frame, when clicks were never set: a Button takes clicks
by default, INFERENCE), the window it sits in, at which checkpoints, how many frames, their size.
Run: python3 tests/gate_mouse_run.py  (Lua 5.1 via lupa; about two minutes, or seconds when the shared result is cached)."""
import collections, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gate_common as GC  # noqa: E402

GATE = "gate_mouse"


def where_of(e):
    """The line a fix changes: the call that turned clicks on, else the CreateFrame line (a Button that was never told)."""
    by = e.get("by") or "?"
    if by.startswith("never set") or by == "?":
        return "%s (CreateFrame; %s)" % (e.get("where"), by if by != "?" else "click state set by code outside XayaUI's files")
    return by


def main():
    data, secs, cached = GC.result()
    rep = GC.Report(GATE)
    GC.integrity(data, rep)
    cps = data.get("checkpoints") or []
    in_combat = [cp for cp in cps if cp.get("combat")]
    rep.note("checkpoints judged: %d (%d in combat), all after the settings window closed" % (len(cps), len(in_combat)))
    if not in_combat:
        rep.fail("tests/gate_common.py (the scenario)", "no checkpoint ran in combat", "", "the scenario must judge the fights too")

    # 1. frames that take clicks
    clicks = collections.OrderedDict()   # (line, top window) -> info
    for cp in cps:
        menu_open = "list is open" in cp["label"]
        for e in cp.get("mouse") or []:
            if menu_open and e.get("inMenu"):
                continue                     # the open minimap list's own rows
            if (e.get("frac") or 0) >= 0.5:
                continue                     # a full-screen catcher: reported once below (2)
            k = (where_of(e), e.get("topWhere") or e.get("where"))
            c = clicks.get(k)
            if not c:
                c = clicks[k] = {"top": e.get("top"), "topWhere": e.get("topWhere"), "made": e.get("where"), "cps": [], "max": 0,
                                 "sizes": set(), "rules": [], "strata": set(), "scripts": set(), "combat": False}
            if cp["label"] not in c["cps"]:
                c["cps"].append(cp["label"])
            c["combat"] = c["combat"] or bool(cp.get("combat"))
            c["sizes"].add("%dx%d" % (round(e.get("w") or 0), round(e.get("h") or 0)))
            c["strata"].add(str(e.get("strata")))
            if e.get("scripts"):
                c["scripts"].add(e["scripts"].strip())
            if e.get("rule") and e["rule"] not in c["rules"] and len(c["rules"]) < 4:
                c["rules"].append(e["rule"])
        per = collections.Counter((where_of(e), e.get("topWhere") or e.get("where")) for e in cp.get("mouse") or []
                                  if not (menu_open and e.get("inMenu")) and (e.get("frac") or 0) < 0.5)
        for k, n in per.items():
            clicks[k]["max"] = max(clicks[k]["max"], n)
    for (line, top), c in clicks.items():
        win = "%s (made at %s)" % (c["top"], c["topWhere"]) if c["topWhere"] and c["topWhere"] != c["made"] else "its own top-level frame"
        rules = (" e.g. the displays of rules " + ", ".join(repr(r) for r in c["rules"])) if c["rules"] else ""
        fix = ("a display takes no clicks once the mover is closed: leave clicks off (SetMouseClickEnabled(false)) and turn motion on only "
               "for 'Show tooltip on hover'" if "Visual.lua" in line else
               "turn clicks off on this frame (SetMouseClickEnabled(false) / EnableMouse(false)) whenever the settings window is closed, "
               "or do not show it unless the player opened it")
        if "MinimapButton.lua" in line:
            fix = "close the list without catching the click: no full-screen button; close it on GLOBAL_MOUSE_DOWN outside the list and on Esc (UISpecialFrames)"
        if "AuraSetup.lua" in (c["topWhere"] or line):
            fix = ("the Combat Tracking Setup window opened by itself (AuraSetup.lua ns.AuraSetup_FirstRunCheck, 6 s after login) and is "
                   "reopened after each fight: do not open a window over the game unasked (a chat line pointing to the settings window, "
                   "or open it with the settings window); a decision for Xaya (V12) on what the first-run prompt should be")
        rep.fail(line, "a shown XayaUI frame takes mouse clicks with the settings window closed; it sits in %s%s" % (win, rules),
                 "up to %d frame(s) at once; size %s; strata %s; scripts %s; %s; at %d of %d checkpoints: %s" % (
                     c["max"], ", ".join(sorted(c["sizes"])), ", ".join(sorted(c["strata"])), ", ".join(sorted(c["scripts"])) or "none",
                     "in and out of combat" if c["combat"] else "out of combat only", len(c["cps"]), len(cps), "; ".join(c["cps"])),
                 fix)

    # 2. full-screen catchers (any mouse at all over half the screen)
    big = collections.OrderedDict()
    for cp in cps:
        for e in cp.get("big") or []:
            k = (GC.short(e.get("by")) if not str(e.get("by", "")).startswith("never") else e.get("where"), e.get("where"))
            b = big.setdefault(k, {"e": e, "cps": []})
            b["cps"].append(cp["label"])
    for (line, made), b in big.items():
        e = b["e"]
        rep.fail(line, "a full-screen mouse catcher: a XayaUI frame covering %d%% of the screen takes the mouse (%s); made at %s" % (
                     round(100 * (e.get("frac") or 0)), "clicks" if e.get("click") else "hover", made),
                 "%dx%d at: %s" % (round(e.get("w") or 0), round(e.get("h") or 0), "; ".join(b["cps"])),
                 "no frame over the game world takes the mouse; close menus on GLOBAL_MOUSE_DOWN instead of a click-catching overlay")

    # 3. the mouse wheel
    wheel = collections.OrderedDict()
    for cp in cps:
        for e in cp.get("wheel") or []:
            wheel.setdefault((e.get("by"), e.get("where")), []).append(cp["label"])
    for (by, made), labels in wheel.items():
        rep.fail(GC.short(by) if by and by != "?" else made, "a shown XayaUI frame takes the mouse wheel (camera zoom stops over it; INFERENCE)",
                 "made at %s; at: %s" % (made, "; ".join(labels)), "EnableMouseWheel(false) once the settings window is closed")

    # 4. the minimap button's list
    mm = data.get("minimap") or {}
    if not mm.get("button"):
        rep.warn("XayaUI/MinimapButton.lua", "the minimap button was not shown, so its list was not checked")
    elif not mm.get("opened"):
        rep.fail("XayaUI/MinimapButton.lua", "a click on the minimap button did not open its list", "", "")
    else:
        if mm.get("clickTakenBy"):
            rep.fail("XayaUI/MinimapButton.lua (the list's click-away)",
                     "with the list open, a click on the game world in the middle of the screen is caught by %s instead of reaching the game" % mm["clickTakenBy"],
                     "", "close the list on GLOBAL_MOUSE_DOWN outside it and let the click through (V27 her answer: closes on any click without catching it)")
        if not mm.get("closedByClick"):
            rep.fail("XayaUI/MinimapButton.lua", "the list stayed open after a click on the game world", "", "close it on any click outside it")
        if not mm.get("escCloses"):
            rep.fail("XayaUI/MinimapButton.lua:122 (CreateFrame XayaUIMinimapMenu)",
                     "Esc does not close the minimap list (it is not in UISpecialFrames); Esc went on to the game: %s" % mm.get("escKey"),
                     "", "tinsert(UISpecialFrames, \"XayaUIMinimapMenu\") (V27 her answer: the minimap menu closes on any click or Esc)")
        if not mm.get("closedAtEnd"):
            rep.fail("XayaUI/MinimapButton.lua", "the minimap list was still open at the end", "", "")

    # 5. hover only (allowed for now; SD-37)
    hov = collections.OrderedDict()
    for cp in cps:
        for e in cp.get("hoverList") or []:
            k = (e.get("by"), e.get("where"))
            h = hov.setdefault(k, {"n": 0, "cps": set(), "sizes": set(), "rules": [], "tip": e.get("tip")})
            h["n"] = max(h["n"], sum(1 for x in cp["hoverList"] if (x.get("by"), x.get("where")) == k))
            h["cps"].add(cp["label"])
            h["sizes"].add("%dx%d" % (round(e.get("w") or 0), round(e.get("h") or 0)))
            if e.get("rule") and e["rule"] not in h["rules"] and len(h["rules"]) < 3:
                h["rules"].append(e["rule"])
    for (by, made), h in hov.items():
        rep.warn(GC.short(by) if by and by != "?" else made,
                 "hover-only frame (motion on, clicks pass): allowed by her V27 answer \"Hover only, clicks pass\"; listed because SD-37 may revisit hover",
                 "made at %s; up to %d at once; size %s; at %d checkpoint(s)%s" % (
                     made, h["n"], ", ".join(sorted(h["sizes"])), len(h["cps"]), ("; rules " + ", ".join(repr(r) for r in h["rules"])) if h["rules"] else ""),
                 "INFERENCE (SD-37, unconfirmed): a hover-enabled frame above the world may block world mouseover / right-click looting")
    if not hov:
        rep.warn("(none)", "no hover-only display was shown at any checkpoint, so hover was not exercised")

    # 6. aura buttons Blizzard's container made for the engine
    eng = collections.Counter()
    for cp in cps:
        for e in cp.get("engine") or []:
            eng[e.get("where")] += 1
    for made, n in eng.items():
        rep.warn(made, "aura buttons Blizzard's container made for the combat engine: whether the game's button takes clicks is not documented "
                 "and XayaUI's initializeFrame does not set it", "%d sightings over the checkpoints" % n,
                 "UNVERIFIED IN GAME: check with /dump GetMouseFoci() over an engine display in game")

    # 7. mouse calls by XayaUI code in combat after the close (protected calls on secure frames would be blocked)
    for k, n in (data.get("mouseCalls") or {}).items():
        rep.warn(k.split(" ")[0], "XayaUI code changed a frame's mouse in combat with the window closed: " + k, "%d call(s)" % n,
                 "EnableMouse / SetMouseClickEnabled are protected on secure frames in combat (widgets.md 110, 283)")
    return rep.show(data, secs, cached)


if __name__ == "__main__":
    sys.exit(main())
