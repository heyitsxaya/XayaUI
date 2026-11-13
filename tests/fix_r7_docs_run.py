#!/usr/bin/env python3
"""Round 7 (bundle 1), docs: the player documents say what the code does after rounds 6 and 7 (V13, V17, V18; Xaya's rebuild
standards). What the player reads is checked against the code itself: every quoted chat line and number below is read from the Lua
file that prints or uses it, so a doc that drifts from the code fails here.

  E  Engine (USER-GUIDE section 1; the round 6 review: "With nothing waiting ... the engine does nothing" was false while a talent rule
     was on): the guide states the routed pace from Engine.lua's ROUTED_GAP (10 times a second, SD-61), that talents are read only on the
     game's events (no talent ticker in Engine.lua, SD-60), the two cases still re-checked on Engine.lua's TICK (five times a second: a Range
     Check row on focus / mouseover / pet, and a hidden cooldown end with no timer; NEEDS HER DECISION), and no longer the old claim.
  G  No speed guard (SD-52): QA-CHECKLIST B38 no longer expects the guard's readings ("Blizzard's aura containers ... ms"); B38 and B400
     quote /xuiengine's last line exactly as XayaUI_Debug/RulesEngine.lua prints it.
  D  Advanced Debugging and the debug tools (SD-58, SD-61, SD-64): the guide says off by default (not "on by default"); the guide, the
     FAQ, the QA steps, PATCH-NOTES and WHATS-NEW quote the login line exactly as XayaUI/DebugRecord.lua prints it (DR.ON_LINE); the
     guide and the FAQ say the debug tools need Advanced Debugging and a /reload, and the guide quotes the one-line answer
     ns.DebugToolsNeeded prints for /xui status while they are not loaded.
  M  Mover (SD-58, SD-64): the guide no longer says a /xui unlock typed with the window closed stays until locked; it says the mover works
     only while the settings window is open; the QA step quotes the mover's close line (XayaUI_Options/Mover.lua) and its combat line
     (XayaUI/Core.lua).
  B  Compact backups (SD-55; the round 6 review): the plain line "Older XayaUI versions cannot read the new backups" is in WHATS-NEW,
     PATCH-NOTES (its bundle 1 entry is held in a comment until XayaUI_Options/InfoPaneData.lua can be regenerated: regenerating passes
     tests/info_pane_run.py's 200 KB cap, her decision) and the guide, and the code says the same (XayaUI_Rules/RuleShare.lua).
  R  Recycle Bin (round 6 core review): the guide no longer says "every 30 minutes", and XayaUI/RecycleBin.lua has no timer.
  X  /xuiengine full and refresh (SD-16): no line of PATCH-NOTES offers them unless it says they were removed.
  Q  QA-CHECKLIST has exact in-game steps for every round 6 and 7 change, one numbered step each, B401 to B421, among them: the SD-49
     right-click comparison with XayaUI off, the V33 AddOn Usage readings, the totem / pet icon gap (study question 3), whether the game
     bills its aura frames to XayaUI Rules (study question 4), the stuck-icon case (SD-63), a shared cooldown, a talent swap (SD-60), the
     two cases still re-checked every 0.2 s, and the garrison reminder (RB-29).
  A  The addon tables (USER-GUIDE section 0, README.md) list XayaUI Rules and XayaUI Debug, and every folder they name exists; the Combat
     README points at XayaUI_Options/AuraSetup.lua, which exists.
  L  REQUEST-LOG A23 (status column only): SD-52, SD-53 and SD-55 no longer read "OPEN, round 6"; SD-57, SD-58, SD-61 and SD-64 no longer
     say "OPEN, bundle 1 round 7" / "OPEN, round 7"; her words (the second column) of SD-52 to SD-64 are unchanged from the
     last commit (when git is there).
Fails on the documents before round 7's docs unit (proved on a private copy); passes after.
Run: python3 tests/fix_r7_docs_run.py"""
import os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
results = []


def check(name, ok, extra=""):
    results.append((name + ("" if ok else "  [" + str(extra)[:300] + "]"), bool(ok)))


def read(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return f.read()


def lua_str(src, pattern):
    m = re.search(pattern, src, re.S)
    return m.group(1) if m else None


def steps(qa):
    """{number: full text of the step line} for every '- [ ] **Bn.**' step."""
    out = {}
    for line in qa.splitlines():
        m = re.match(r"- \[ \] \*\*B(\d+)\.\*\*", line)
        if m:
            out[int(m.group(1))] = line
    return out


def main():
    ug, faq, qa = read("docs/USER-GUIDE.md"), read("docs/HELP-FAQ.md"), read("docs/QA-CHECKLIST.md")
    pn, wn, readme, combat = read("PATCH-NOTES.md"), read("docs/WHATS-NEW.md"), read("README.md"), read("XayaUI_Rules/Combat/README.md")
    engine = read("XayaUI_Rules/Engine.lua")
    debugrec, core, mover = read("XayaUI/DebugRecord.lua"), read("XayaUI/Core.lua"), read("XayaUI_Options/Mover.lua")
    rengine, ruleshare, recycle = read("XayaUI_Debug/RulesEngine.lua"), read("XayaUI_Rules/RuleShare.lua"), read("XayaUI/RecycleBin.lua")

    # E: the engine paragraph
    gap = lua_str(engine, r"\nlocal ROUTED_GAP = ([0-9.]+)")
    tick = lua_str(engine, r"\nlocal TICK = ([0-9.]+)")
    per_sec = gap and int(round(1 / float(gap)))
    check("E0 the code's numbers are found (Engine.lua ROUTED_GAP, TICK) and the engine makes no talent ticker",
          gap and tick and "TalentWatch" not in engine and not re.search(r"NewTicker\([^)]*[Tt]alent", engine), (gap, tick))
    check("E1 USER-GUIDE no longer says the engine does nothing 'out of combat, no aura or cooldown running' (false while a talent "
          "rule or a focus range row was loaded)", "With nothing waiting (out of combat, no aura or cooldown running) the engine does nothing." not in ug)
    check("E2 USER-GUIDE states the routed pace the code uses (%s times a second, ROUTED_GAP %s)" % (per_sec, gap),
          per_sec and ("at most %d times a second" % per_sec) in ug)
    check("E3 USER-GUIDE: talents are read again only when the game says they changed, never on a timer",
          "Talents are read again only when the game says they changed" in ug and "never on a timer" in ug)
    words = {2: "twice", 4: "four times", 5: "five times", 10: "10 times"}
    per_tick = tick and words.get(int(round(1 / float(tick))))
    check("E4 USER-GUIDE names the two cases still re-checked %s a second (TICK %s): a Range Check row on focus / mouseover / pet, and "
          "a hidden cooldown end with no timer" % (per_tick, tick),
          per_tick and ("looked at again %s a second" % per_tick) in ug and "Range Check row on your focus, mouseover or pet" in ug
          and "a hidden cooldown end the game gives XayaUI no timer for" in ug)

    # G: no speed guard in the QA steps
    last = lua_str(rengine, r'Say\("(combat engine: on \([^"]*\)\.)"\)')
    st = steps(qa)
    check("G0 /xuiengine's last line is found in XayaUI_Debug/RulesEngine.lua", last, last)
    b38, b400 = st.get(38, ""), st.get(400, "")
    check("G1 QA B38 no longer expects the speed guard's readings ('Blizzard's aura containers ... ms', 'all of XayaUI ... ms')",
          b38 and '**Expect:** the last line names "Blizzard\'s aura containers' not in b38 and "notes the old trip was undone" not in b38, b38[:200])
    check("G2 QA B38 and B400 quote /xuiengine's last line exactly as the code prints it", last and last in b38 and last in b400, last)

    # D: Advanced Debugging
    on_line = lua_str(debugrec, r'DR\.ON_LINE = "([^"]+)"')
    check("D0 the login line is found in XayaUI/DebugRecord.lua (DR.ON_LINE)", on_line, on_line)
    check("D1 USER-GUIDE: Advanced Debugging is off by default (it no longer says 'on by default')",
          "Advanced Debugging (recommended)**, off by default" in ug and "Advanced Debugging (recommended)**, on by default" not in ug)
    for name, text in (("USER-GUIDE", ug), ("HELP-FAQ", faq), ("QA-CHECKLIST", qa), ("PATCH-NOTES", pn), ("WHATS-NEW", wn.replace("\n  ", " "))):
        check("D2 %s quotes the login line exactly" % name, on_line and on_line in text, on_line)
    tmpl = lua_str(debugrec, r'ns\.Print\(what \.\. " (needs Advanced Debugging: [^"]+)"\)')
    check("D3 USER-GUIDE quotes the one line /xui status prints while the debug tools are not loaded (ns.DebugToolsNeeded)",
          tmpl and ("/xui status " + tmpl) in ug, tmpl)
    for name, text in (("USER-GUIDE", ug), ("HELP-FAQ", faq)):
        check("D4 %s says the debug tools (/xuiengine, /xui status, /xui auras, /xui bug, /xui report, the console) need Advanced Debugging"
              % name, all(w in text for w in ("`/xuiengine`", "`/xui status`", "`/xui auras`", "`/xui bug`", "`/xui report`"))
              and re.search(r"debug tools[^.]*Advanced Debugging", text) is not None)

    # M: the mover
    close_line = lua_str(mover, r'\("(the mover closed with the settings window\. Your %d unsaved move\(s\) are kept[^"]*)"\)')
    combat_line = lua_str(core, r'ns\.CombatLock\("unlock", function\(\) Open\(true\) end, "([^"]+)"\)')
    check("M0 the mover's close line (Mover.lua) and its combat line (Core.lua) are found", close_line and combat_line, (close_line, combat_line))
    check("M1 USER-GUIDE no longer says a /xui unlock typed with the window closed stays until you lock it",
          "An unlock you typed as `/xui unlock` while the window was closed stays until you lock it again." not in ug)
    check("M2 USER-GUIDE and HELP-FAQ: the mover works only while the settings window is open; /xui unlock opens the window",
          "works only while that window is open" in ug and "`/xui unlock` with the window closed opens it" in ug
          and "### Why does /xui unlock open the settings window?" in faq)
    b405 = st.get(405, "")
    check("M3 QA B405 quotes the mover's close line (with 1 move) and its combat line exactly",
          close_line and combat_line and (close_line % 1) in b405 and combat_line in b405, b405[:200])

    # B: compact backups
    plain = "Older XayaUI versions cannot read the new backups"
    check("B0 the code says it (XayaUI_Rules/RuleShare.lua)", re.search(r"Older XayaUI versions\s*\n?\s*--\s*cannot read the new backups", ruleshare) is not None)
    check("B1 PATCH-NOTES has the plain line (in the bundle 1 entry, held in a comment until the in-game pane can be regenerated: her "
          "decision on its memory cap)", (plain + ".") in pn)
    check("B2 WHATS-NEW has the plain line", plain in wn.replace("\n  ", " "))
    check("B3 USER-GUIDE (Backups) has the plain line", plain in ug)

    # R: Recycle Bin
    check("R1 USER-GUIDE no longer says deleted items are removed 'every 30 minutes', and RecycleBin.lua has no timer",
          "every 30 minutes" not in ug and "C_Timer" not in recycle and "OnUpdate" not in recycle)

    # X: /xuiengine full / refresh
    bad = [n for n, line in enumerate(pn.splitlines(), 1) if re.search(r"/xuiengine (full|refresh)", line) and "removed" not in line]
    check("X1 PATCH-NOTES: no line offers /xuiengine full or refresh unless it says they were removed", not bad, bad)

    # Q: the in-game steps
    want = {
        401: ["XayaUI_Debug", "whole folders"],
        402: [on_line or "?", "needs Advanced Debugging"],
        403: ["XayaUI Options", "not loaded"],
        404: ["/xui debug talents status", "Element options"],
        405: ["/xui unlock"],
        406: ["Open Combat Tracking Setup", "Learn"],
        407: [last or "?"],
        408: ["Show export text", "0 rule(s)"],
        409: ["lastBugReport"],
        410: ["stuck-icon", "SD-63", "tenth of a second"],
        411: ["share one cooldown", "BOTH"],
        412: ["Apply Changes", "loadout", "SD-60"],
        413: ["lights up"],
        414: ["Range Check", "0.2"],
        415: ["Tracked Buffs", "totem", "question 3"],
        416: ["billed", "question 4"],
        417: ["SD-49", "XayaUI off", "Respawn Point"],
        418: ["V33", "Average CPU", "2%", "0.9%"],
        419: ["GetMouseFoci"],
        420: ["Print Screen"],
        421: ["RB-29", "GetInstanceInfo"],
    }
    for n, words in sorted(want.items()):
        line = st.get(n, "")
        missing = [w for w in words if w not in line]
        check("Q B%d exists once with %s" % (n, ", ".join(repr(w) for w in words)),
              line and not missing and len(re.findall(r"\*\*B%d\.\*\*" % n, qa)) == 1, missing or "no step")
    check("Q the QA intro says the debug tools need Advanced Debugging", "**Debug tools need Advanced Debugging" in qa)

    # A: the addon tables and the paths the docs name
    check("A1 USER-GUIDE section 0 lists XayaUI Rules and XayaUI Debug, and puts the rule editor and the mover in XayaUI Options",
          "| **XayaUI Rules** |" in ug and "| **XayaUI Debug** |" in ug and re.search(r"\| \*\*XayaUI Options\*\* \|[^\n]*rule editor[^\n]*mover", ug))
    check("A2 README.md lists XayaUI_Debug and the editor in XayaUI_Options; both folders exist",
          "| `XayaUI_Debug` |" in readme and "`RuleEditor/`" in readme
          and os.path.isfile(os.path.join(ROOT, "XayaUI_Debug", "XayaUI_Debug.toc"))
          and os.path.isdir(os.path.join(ROOT, "XayaUI_Options", "RuleEditor")))
    check("A3 the Combat README points at XayaUI_Options/AuraSetup.lua (which exists), not at a file in this folder",
          "`XayaUI_Options/AuraSetup.lua`" in combat and os.path.isfile(os.path.join(ROOT, "XayaUI_Options", "AuraSetup.lua"))
          and not os.path.isfile(os.path.join(ROOT, "XayaUI_Rules", "Combat", "AuraSetup.lua")))

    # L: the request log's status column
    log = read("docs/process/REQUEST-LOG.md")
    rows = {}
    for line in log.splitlines():
        m = re.match(r"\| (SD-(\d+)) \| ", line)
        if m and 52 <= int(m.group(2)) <= 64:
            cells = re.split(r"(?<!\\) \| ", line.strip()[2:-2])
            rows[m.group(1)] = cells
    check("L0 rows SD-52 to SD-64 are found with four cells each", len(rows) == 13 and all(len(c) == 4 for c in rows.values()),
          {k: len(v) for k, v in rows.items()})
    for sd in ("SD-52", "SD-53", "SD-55"):
        st_cell = rows.get(sd, ["", "", ""])[2]
        check("L1 %s status no longer reads 'OPEN, round 6'" % sd, st_cell and not st_cell.startswith("OPEN, round 6"), st_cell[:80])
    for sd in ("SD-57", "SD-58", "SD-61", "SD-64"):
        st_cell = rows.get(sd, ["", "", ""])[2]
        check("L2 %s status no longer says 'OPEN, bundle 1 round 7' / 'OPEN, round 7' (built in round 7)" % sd,
              st_cell and "OPEN, bundle 1 round 7" not in st_cell and "OPEN, round 7" not in st_cell, st_cell[:80])
    try:
        old = subprocess.run(["git", "-C", ROOT, "show", "HEAD:docs/process/REQUEST-LOG.md"], capture_output=True, text=True, timeout=60)
        old_log = old.stdout if old.returncode == 0 else None
    except Exception:
        old_log = None
    if old_log:
        changed = []
        for line in old_log.splitlines():
            m = re.match(r"\| (SD-(\d+)) \| ", line)
            if m and 52 <= int(m.group(2)) <= 64:
                cells = re.split(r"(?<!\\) \| ", line.strip()[2:-2])
                now = rows.get(m.group(1))
                if not now or now[1] != cells[1] or now[3] != cells[3]:
                    changed.append(m.group(1))
        check("L3 her words (second column) and the where column of SD-52 to SD-64 are unchanged from the last commit", not changed, changed)
    else:
        print("note: git not available here; L3 (her words unchanged) not checked")

    bad_n = 0
    for name, ok in results:
        print(("PASS " if ok else "FAIL ") + name)
        bad_n += 0 if ok else 1
    print("%d checks, %d failed" % (len(results), bad_n))
    return 1 if bad_n else 0


if __name__ == "__main__":
    sys.exit(main())
