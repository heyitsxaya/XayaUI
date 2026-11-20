#!/usr/bin/env python3
"""Round 7 (bundle 1), docs repair: the round 7 docs review's blockers and concerns, checked against the code (V13, V15, V17, V18;
Xaya's rebuild standards). Every label, frame name and number below is read from the Lua file that uses it, so a doc that drifts from
the code fails here.

  R  README.md Install: no line still says the rule editor is inside `XayaUI_Rules` (review blocker 1: line 42 contradicted line 41);
     the old `XayaUI_Rules_Options` line names `XayaUI_Options\\RuleEditor`; the 0.5.x line puts the combat tracking in XayaUI Rules
     (`XayaUI_Rules\\Combat`, which exists), not in XayaUI.
  U  USER-GUIDE: the engine paragraph no longer opens with "does not re-check your rules on a timer" and then names two timed re-checks
     (review concern b); it names them as the two exceptions, at the rate Engine.lua's TICK gives. Section 12.6 lists only the quick-access
     rows this download registers (ns.RegisterLauncher in XayaUI, XayaUI_Options, XayaUI_Rules, XayaUI_Debug), and says what "switched
     off" builds at login and during play, and that XayaUI Options builds the page (XayaUI_Options/MinimapTab.lua ns.BuildMinimapTab).
  F  HELP-FAQ: "while Advanced Debugging is off, every message goes to the chat window" was imprecise (review concern c): the tools stay
     loaded until /reload once loaded (XayaUI/DebugRecord.lua never sets toolsLoaded back to false), and the FAQ now says so.
  Q  QA-CHECKLIST: B406 states the true precondition (review blocker: the first-run record is account-wide: AuraSetup.lua reads
     auraModel.settings.setupShown and every spec's record, and no XayaUI .toc saves per character), with a first-run part that moves the
     account's SavedVariables folder aside and restores it; B416 keeps the rules on and changes only the trigger's State to the editor's
     "Buff is MISSING" label, which AuraDisplay.lua keeps with XayaUI (review concern a); B422 (SD-62: the Minimap Button page in XayaUI
     Options, both buttons not built while switched off, with the code's labels and frame names) and B423 (the retired addons' leftover
     code: /xui dev qa, saved settings kept) exist (review concern b); the newest WHATS-NEW section names B401 to the last bundle 1
     step, read from the checklist (round 11 hygiene: the highest B number there, not a pinned number that goes stale each round).
  (round 11a, SD-140 "Docs like this should not be on main.": the working docs left this repo, so Q6 no longer reads
     SESSION-START-SUMMARY, and L (the request log's status cells for SD-52 to SD-64) was removed; both live in Xaya's private notes.)
Fails on the documents before this repair (proved on a private copy); passes after.
Run: python3 tests/fix_r7_docs_repair_run.py"""
import os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
results = []


def check(name, ok, extra=""):
    results.append((name + ("" if ok else "  [" + str(extra)[:300] + "]"), bool(ok)))


def read(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        return f.read()


def steps(qa):
    out = {}
    for line in qa.splitlines():
        m = re.match(r"- \[ \] \*\*B(\d+)\.\*\*", line)
        if m:
            out.setdefault(int(m.group(1)), []).append(line)
    return out


def main():
    readme, ug, faq, qa = read("README.md"), read("docs/USER-GUIDE.md"), read("docs/HELP-FAQ.md"), read("docs/QA-CHECKLIST.md")
    wn = read("docs/WHATS-NEW.md")
    engine, debugrec = read("XayaUI_Rules/Engine.lua"), read("XayaUI/DebugRecord.lua")
    setup, auradisp, editor = read("XayaUI_Options/AuraSetup.lua"), read("XayaUI_Rules/Combat/AuraDisplay.lua"), read("XayaUI_Options/RuleEditor/Editor.lua")
    minimap, minitab, gamemenu, options = (read("XayaUI/MinimapButton.lua"), read("XayaUI_Options/MinimapTab.lua"),
                                           read("XayaUI/GameMenuButton.lua"), read("XayaUI_Options/Options.lua"))

    # R: README Install
    check("R1 README.md: no line says the rule editor is inside `XayaUI_Rules`",
          "the rule editor is now inside `XayaUI_Rules`" not in readme and not re.search(r"rule editor is (now )?(inside|in) `XayaUI_Rules`", readme))
    old_line = [l for l in readme.splitlines() if "XayaUI_Rules_Options" in l]
    check("R2 README.md: the XayaUI_Rules_Options line names `XayaUI_Options\\RuleEditor`, which exists",
          old_line and all("`XayaUI_Options\\RuleEditor`" in l for l in old_line)
          and os.path.isdir(os.path.join(ROOT, "XayaUI_Options", "RuleEditor")), old_line)
    check("R3 README.md: the 0.5.x line puts the combat tracking in XayaUI Rules (XayaUI_Rules\\Combat exists), not in XayaUI",
          "the combat tracking is inside XayaUI now)" not in readme and "the combat tracking is inside XayaUI Rules now, `XayaUI_Rules\\Combat`" in readme
          and os.path.isdir(os.path.join(ROOT, "XayaUI_Rules", "Combat")))

    # U: USER-GUIDE engine paragraph and 12.6
    tick = re.search(r"\nlocal TICK = ([0-9.]+)", engine)
    words = {2: "twice", 4: "four times", 5: "five times", 10: "10 times"}
    per_tick = tick and words.get(int(round(1 / float(tick.group(1)))))
    check("U1 USER-GUIDE engine paragraph: no longer opens with 'does not re-check your rules on a timer' or says 'Two cases are still'",
          "The engine does not re-check your rules on a timer." not in ug and "Two cases are still looked at again" not in ug)
    check("U2 USER-GUIDE names the timed re-checks as the two exceptions, %s a second (Engine.lua TICK %s)" % (per_tick, tick and tick.group(1)),
          per_tick and "not on a repeating timer, with the two exceptions at the end of this paragraph" in ug
          and ("The two exceptions are looked at again %s a second" % per_tick) in ug)
    rows = []
    for d in ("XayaUI", "XayaUI_Options", "XayaUI_Rules", "XayaUI_Debug"):
        for dp, _, fs in os.walk(os.path.join(ROOT, d)):
            for f in fs:
                if f.endswith(".lua"):
                    with open(os.path.join(dp, f), encoding="utf-8") as fh:
                        rows += re.findall(r'ns\.RegisterLauncher\(\{\s*"[^"]+",\s*"([^"]+)"', fh.read())
    m = re.search(r"\*\*Left-click\*\* opens a list of buttons: ([^.]*)\.", ug)
    listed = m and [x.split(" (")[0].strip() for x in re.split(r",| and ", m.group(1)) if x.strip()]
    check("U3 USER-GUIDE 12.6: the left-click list names exactly the rows this download registers (%s)" % rows,
          rows and listed == rows, listed)
    check("U4 USER-GUIDE 12.6: switched off at login neither button is built; during play the minimap button hides; XayaUI Options builds the page",
          "Switched off when you log in or /reload, the minimap button is not built" in ug and "the ESC-menu button is not built" in ug
          and "The Minimap Button settings page is built by XayaUI Options" in ug and "function ns.BuildMinimapTab" in minitab
          and "if not ns.minimapDB.hide then Watch(true) end" in minimap and "if Enabled() then Enable() end" in gamemenu)

    # F: HELP-FAQ messages
    check("F0 the code: once the debug tools load they stay loaded (toolsLoaded is only ever set to true)",
          len(re.findall(r"toolsLoaded = false", debugrec)) == 1 and "local toolsLoaded = false" in debugrec and "toolsLoaded = true" in debugrec)
    check("F1 HELP-FAQ: messages go to chat while the tools are not loaded, and turning Advanced Debugging off in play keeps them until /reload",
          "while Advanced Debugging is off, every message goes to the chat window" not in faq
          and "while they are not loaded (Advanced Debugging was off at your last login or /reload), every message goes to the chat window" in faq
          and "the tools stay loaded and your choice still applies until the next /reload" in faq)

    # Q: QA steps
    st = steps(qa)
    one = lambda n: st.get(n, [""])[0] if len(st.get(n, [])) == 1 else ""
    per_char = re.findall(r"SavedVariablesPerCharacter", read("XayaUI/XayaUI.toc") + read("XayaUI_Rules/XayaUI_Rules.toc"))
    check("Q0 the code: the first-run record is setupShown or any spec's record, and no XayaUI .toc saves per character",
          "d.settings.setupShown or d.settings.noPrompt or EverSetUp(d)" in setup and not per_char)
    b406 = one(406)
    check("Q1 B406 no longer says a new character has no record; it says the record is saved for the whole account",
          b406 and "(any new character)" not in b406 and "saved for the whole account" in b406 and "a new character does not reset it" in b406, b406[:200])
    check("Q2 B406 checks the first-run case on an account with no record, and puts the saved folder back",
          "rename the folder `WTF\\Account\\<your account>\\SavedVariables` to `SavedVariables-backup`" in b406
          and "rename `SavedVariables-backup` back to `SavedVariables` before you log in again" in b406)
    missing_lbl = re.search(r'missing = "([^"]+)"', editor)
    present_lbl = re.search(r'present = "([^"]+)"', editor)
    kept = re.search(r'p\.buffState == "missing" then return nil, "(shows while the aura is MISSING)', auradisp)
    b416 = one(416)
    check("Q3 B416 keeps the rules on and changes only the State to the editor's labels (%s / %s), which AuraDisplay.lua keeps with XayaUI"
          % (present_lbl and present_lbl.group(1), missing_lbl and missing_lbl.group(1)),
          b416 and missing_lbl and present_lbl and kept and "switch that test group's rules off" not in b416
          and "keep the same rules switched on and change only each rule's State to **%s**" % missing_lbl.group(1) in b416
          and "**%s**" % present_lbl.group(1) in b416 and kept.group(1) in b416, b416[:200])
    show_mm = re.search(r'show = \{ type = "toggle", order = 1, name = "([^"]+)"', minitab)
    show_gm = re.search(r'gameMenuButton = \{ type = "toggle", name = "([^"]+)"', options)
    fr_mm = re.search(r'CreateFrame\("Button", "(XayaUIMinimapButton)"', minimap)
    fr_gm = re.search(r'CreateFrame\("Button", "(XayaUI_GameMenuButton)"', gamemenu)
    b422 = one(422)
    check("Q4 B422 (SD-62) exists once, with the code's labels and frame names",
          b422 and show_mm and show_gm and fr_mm and fr_gm and "SD-62" in b422 and ("**%s**" % show_mm.group(1)) in b422
          and ("**%s**" % show_gm.group(1)) in b422 and ("`/dump %s`" % fr_mm.group(1)) in b422 and ("`/dump %s`" % fr_gm.group(1)) in b422
          and "Settings > Minimap Button" in b422, b422[:200])
    b423 = one(423)
    check("Q5 B423 (retired addons' code) exists once: /xui dev qa gives the command list, saved settings kept",
          b423 and "`/xui dev qa`" in b423 and '"XayaUI: commands ("' in b423 and "Dev Assist" in b423
          and '`["chat"] = {`' in b423 and '`["qol"] = {`' in b423 and '`["rsk"] = {`' in b423 and "still there" in b423, b423[:200])
    sec = qa.split("### B-bundle1.", 1)[1].split("\n## ", 1)[0] if "### B-bundle1." in qa else ""
    last = max([int(x) for x in re.findall(r"\*\*B(\d+)\.\*\*", sec)] or [0])
    # (round 11 hygiene; R11A final review blocker 4: Q6 pinned the last step, 438, which went stale when round 11a correctly added B439
    # to B441; it had been re-pinned every round: B429, B433, B434, B438) What it guards: the newest WHATS-NEW section names the bundle 1
    # steps up to the last one there is. So the last step is read from the checklist, never written here: the highest B number in the
    # bundle 1 section is the highest in the whole checklist (bundle 1 holds the newest steps), and the newest WHATS-NEW section's
    # "B401 to B<n>" range ends exactly there. B438 (round 10's last step) is a floor that does not go stale.
    # (round 11a, SD-140: SESSION-START-SUMMARY, a working doc, left this repo; WHATS-NEW is the player's copy and stays checked)
    every = max([int(x) for x in re.findall(r"\*\*B(\d+)\.\*\*", qa)] or [0])
    secs = re.split(r"^## (?=\d+\. )", wn, flags=re.M)
    nums = [(int(x.split(".", 1)[0]), x) for x in secs[1:] if x.split(".", 1)[0].isdigit()]
    newest = max(nums)[1] if nums else ""
    ranges = [int(x) for x in re.findall(r"\bB401 to B(\d+)\b", newest)]
    check("Q6 the newest WHATS-NEW section (%s) names the bundle 1 steps B401 to the last one in QA-CHECKLIST (B%d; highest anywhere B%d)"
          % (newest.split("\n", 1)[0][:40], last, every),
          last >= 438 and last == every and ranges and all(r == last for r in ranges), (ranges, last, every))

    bad_n = 0
    for name, ok in results:
        print(("PASS " if ok else "FAIL ") + name)
        bad_n += 0 if ok else 1
    print("%d checks, %d failed" % (len(results), bad_n))
    return 1 if bad_n else 0


if __name__ == "__main__":
    sys.exit(main())
