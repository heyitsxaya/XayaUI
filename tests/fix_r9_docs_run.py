#!/usr/bin/env python3
"""Bundle 1 round 9, docs: what the player reads matches the code after rounds 1 to 9, and Xaya's round 7 and 8 answers about the
documents are met (REQUEST-LOG A23). Every quoted chat line and number below is read from the Lua file that prints or uses it, so a
document that drifts from the code fails here.

  F  SD-72, her answer "Remove from main, keep on QA (Recommended)": MANIFEST.md5 is not in the tree; tests/devassist_rename_run.py
     no longer excludes the file.
  D  SD-70, her answer "Short with path (Recommended)": USER-GUIDE, HELP-FAQ (its question heading too), QA-CHECKLIST B402,
     PATCH-NOTES and WHATS-NEW quote the whole chat line exactly as the player sees it: core's "XayaUI: " prefix (XayaUI/Core.lua
     ns.Print) and DR.ON_LINE (XayaUI/DebugRecord.lua); no document keeps the old "Advanced debugging is on. To turn this off" line.
  M  SD-68 mover, her answer "Ask on next settings open (Recommended)": USER-GUIDE, HELP-FAQ, WHATS-NEW and PATCH-NOTES no longer
     say the mover simply opens again next time; each names Save, Discard and Keep editing; QA B405 quotes the close line and the
     question (with 1 move) and the three buttons exactly as XayaUI_Options/Mover.lua prints them; a QA step quotes the mover's
     combat line and expects no question after combat (SD-15).
  T  SD-67 talents, her answer "Read-only answers anytime (Recommended)": QA B404 no longer expects "can't be read during combat";
     it expects the summary at once in combat (XayaUI_Rules/TalentDump.lua's lines) and the scan's combat line.
  P  The bundle 1 landing: PATCH-NOTES has it outside any comment, first, with one heading per changed addon at the version its
     .toc carries, each above main's (origin/main when git has it); main's Stat Calculator landing follows unchanged; the entry names
     the round 8 and 9 changes the player meets (route + narrow, redraws only while something changes, the perf tracker, the mover
     question, Advanced Debugging off by default and its line, talents at once, the right-click tracker gone). WHATS-NEW section 15
     covers rounds 1 to 9.
  N  Numbers the guide states come from the code: "at most 10 times a second" (Engine.lua ROUTED_GAP), "at most 30 times a second"
     per display (Visual.lua FX_GAP), and the tracker's "10 to 14" / "possibly over" range (XayaUI_Debug/RulesPerf.lua LIMIT and its
     "possibly over" text; SD-84 "Keep the range").
  I  SD-69 (recent notes only in game): XayaUI_Options/InfoPaneData.lua holds at most the newest 5 landings plus an "Older notes"
     entry, its first landing is PATCH-NOTES' first, and it offers no removed command (/xuiengine full or refresh, /xui debug perf
     ui) except to say it was removed. (tests/info_pane_run.py checks the pane itself and its memory.)
  Q  QA-CHECKLIST has one step each for the in-game checks of round 9 (B424 to B429): the tracker, the mover after combat, combat
     start / boss pull / combat end drawing, AddOn Usage at a pull, the C_Timer /run test (the exact line), the SD-49 right-click
     check with a /run line; B401 names the new versions; B414 no longer waits on her decision.
  (round 11a, SD-140 "Docs like this should not be on main.": the working docs left this repo for Xaya's private notes repo, so F2
     (VERIFICATION.md V10), S1 / S2 (R7-EUI-STUDY, ROADMAP) and L1 / L2 (the request log's status cells and her words) were removed.)
  (repair 1, the reviewer's three blockers)
  I3 No document says the build tool's round 9 change (KEEP_LANDINGS, XUI_ROOT) is on qa-installer-branch: each one that names it says
     it is pending, and it really is not there (origin/qa-installer-branch, when git has it; once it lands there this check asks
     for the documents to be updated); (round 11a, SD-140) no player document points at the patch's working-doc path. I4 The recorded
     patch, applied to qa-installer-branch's tool, rebuilds InfoPaneData.lua exactly from this checkout's markdown; (round 11a) the
     patch is read from Xaya's private notes checkout (XUI_DOCS_ROOT, else a sibling folder xui-docs), never from this repo. (round 11
     hygiene, V35) Without that checkout, or without the qa-installer-branch ref, the run prints "MISSING INPUT: <what>" and fails,
     unless the named opt-out is set on purpose (XUI_SKIP_PRIVATE_NOTES=1, XUI_SKIP_QA_BRANCH=1; a public clone needs the first); an
     opt-out is printed and named on the count line. I5 The pane's own text uses no in-house word "landing".
  P7 The Rules developers' note compares the costliest fight frame with main's, as the gate stores it (tests/gate_performance_run.py
     V33_EVENT_CAPS, origin/main ad60a051's XayaUI Rules = main's), and its words for the size of the drop match the two numbers it
     gives; no "about half" (that was against round 8's unlanded branch, never main).
  P8 The game-played sound bullets say what AuraSound.lua does: the Load tab choices it cannot know ahead (its DROP list: Combat,
     Boss encounter) count as possibly true, so such a rule's sound can also play outside combat or outside the encounter.
     (repair 2) USER-GUIDE splits them by direction, with the Load tab's words read from Conditions.lua LOAD_TRI: "Only in combat",
     "Only during a boss encounter" and a Boss encounters list can also play outside combat / the encounter and got no game copy on
     main; "Only out of combat" and "Only outside boss encounters" can also play in combat / the encounter and already had the copy
     on main (main's A.Plan skipped rules not loaded at the sync, which runs out of combat only). QA B434 is the in-game step.
  Q2 QA-CHECKLIST has the round 8 in-game checks that had no step: the Cooldown Manager alert (B430), memory over a long session
     (B431), a hitch at a load change (B432), pace and lag in a busy pull with "seconds left" sounds (B433).
  (round 10 docs unit, intended changes decided by her round 10 answers; each is stricter or follows the new code, none is dropped)
  P4 SD-95, SD-105, SD-115 and SD-118 changed XayaUI_Bonus and XayaUI_Bonus_StatCalculator in bundle 1, so they are no longer "main's
     0.6.46": each .toc is now above main's 0.6.46 and the entry has "### Bonus Features <that version>".
  P8 SD-96 ("This function needs to work as intended and expected") removed AuraSound.lua's DROP list: the game's copy follows the Load
     tab exactly. P8 now FAILs if a DROP list comes back or if PATCH-NOTES, WHATS-NEW or USER-GUIDE still says the copy "can also play
     outside combat / outside the encounter" or that a choice "does not apply" (the old behaviour). What the documents must say now is
     checked by tests/fix_r10_docs_run.py (S1 to S4).
  Q B434 quotes LIMITS as AuraSound.lua builds it (was: the removed "does not apply" line); B401 names every addon's .toc version.
Negative control: on the documents before this round's docs unit (proved on a private copy) F, D, M, T, P, I, Q, S and L fail;
on the documents before repair 1 (scratchpad r9pre-docs-repair1) I3, I4, I5, P7, P8 and Q2 fail; on the documents before repair 2
(scratchpad r9pre-docs-repair2) P8 USER-GUIDE and Q B434 fail.
Run: python3 tests/fix_r9_docs_run.py   (XUI_R9_ROOT=<a checkout> to check another copy)"""
import os, re, subprocess, sys, tempfile, shutil, hashlib
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import release_notes as RN  # noqa: E402  (bundle 1's entry and versions, read from fixed facts; SD-155)

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.environ.get("XUI_R9_ROOT") or os.path.join(HERE, ".."))
# Xaya's private notes repo (heyitsxaya/XUI-Docs), where the working docs live since round 11a (SD-140): XUI_DOCS_ROOT, else a sibling
# checkout next to this repo named xui-docs or XUI-Docs (the first that exists). Only I4 reads it; a run without it fails (MISSING
# INPUT) unless XUI_SKIP_PRIVATE_NOTES=1 is set on purpose.
DOCS_ROOT = os.path.normpath(os.environ.get("XUI_DOCS_ROOT") or next(
    (c for c in (os.path.join(ROOT, "..", n) for n in ("xui-docs", "XUI-Docs")) if os.path.isdir(c)), os.path.join(ROOT, "..", "xui-docs")))
results = []
# the named opt-outs for inputs a clone may lack (see I3 / I4): each must be set to 1 on purpose, and is printed when used
OPT_OUTS = {"qa": "XUI_SKIP_QA_BRANCH", "notes": "XUI_SKIP_PRIVATE_NOTES"}
OPTED = []


def check(name, ok, extra=""):
    results.append((name + ("" if ok else "  [%s]" % (str(extra)[:300],)), bool(ok)))


def read(rel):
    p = os.path.join(ROOT, rel)
    if not os.path.exists(p):
        return ""
    with open(p, encoding="utf-8") as f:
        return f.read()


def lua_str(src, pattern):
    m = re.search(pattern, src, re.S)
    return m.group(1) if m else None


def steps(qa):
    out = {}
    for line in qa.splitlines():
        m = re.match(r"- \[ \] \*\*B(\d+)\.\*\*", line)
        if m:
            out[int(m.group(1))] = line
    return out


def nocomment(s):
    return re.sub(r"<!--.*?-->", "", s, flags=re.S)


def vkey(v):
    return tuple(int(x) for x in v.split("."))


def toc_version(folder):
    m = re.search(r"^## Version:\s*(\S+)", read("%s/%s.toc" % (folder, folder)), re.M)
    return m.group(1) if m else None


MAIN_FALLBACK = {"XayaUI": "0.6.85", "XayaUI_Options": "0.6.108", "XayaUI_Rules": "0.7.0"}   # main before bundle 1 (fda1e293)


def main():
    ug, faq, qa = read("docs/USER-GUIDE.md"), read("docs/HELP-FAQ.md"), read("docs/QA-CHECKLIST.md")
    pn_raw, wn = read("PATCH-NOTES.md"), read("docs/WHATS-NEW.md")
    pn = nocomment(pn_raw)
    wn1 = wn.replace("\n  ", " ")
    debugrec, core, mover = read("XayaUI/DebugRecord.lua"), read("XayaUI/Core.lua"), read("XayaUI_Options/Mover.lua")
    talents, perf = read("XayaUI_Rules/TalentDump.lua"), read("XayaUI_Debug/RulesPerf.lua")
    engine, visual = read("XayaUI_Rules/Engine.lua"), read("XayaUI_Rules/Visual.lua")
    st = steps(qa)

    # F: the manifest (SD-72)
    check("F1 SD-72: MANIFEST.md5 is not in the tree", not os.path.exists(os.path.join(ROOT, "MANIFEST.md5")))
    check("F3 SD-72: tests/devassist_rename_run.py no longer excludes MANIFEST.md5 (the file is gone)",
          '":!MANIFEST.md5"' not in read("tests/devassist_rename_run.py"))

    # D: the login line (SD-70)
    on_line = lua_str(debugrec, r'DR\.ON_LINE = "([^"]+)"')
    # core's ns.Print: print("|cff33ccffXayaUI|r: " .. text): the player reads "XayaUI: " before the line (the color code shows nothing)
    pm = re.search(r'print\("\|cff[0-9a-fA-F]{6}(XayaUI)\|r(: )" \.\. text\)', core)
    prefix = pm and (pm.group(1) + pm.group(2).rstrip())
    full = on_line and prefix and ("%s %s" % (prefix, on_line))
    check("D0 the login line and core's prefix are found in the code", full, (prefix, on_line))
    for name, text in (("USER-GUIDE", ug), ("HELP-FAQ", faq), ("QA-CHECKLIST B402", st.get(402, "")), ("PATCH-NOTES", pn),
                       ("WHATS-NEW", wn1)):
        check("D1 SD-70: %s quotes the whole chat line exactly, prefix included" % name, full and ('"%s"' % full) in text, full)
    check("D2 SD-70: the HELP-FAQ question heading quotes \"Advanced Debugging is on\"",
          '### Why does chat say "Advanced Debugging is on" every time I log in?' in faq)
    old = "Advanced debugging is on. To turn this off"
    stale = [n for n, t in (("USER-GUIDE", ug), ("HELP-FAQ", faq), ("QA-CHECKLIST", qa), ("PATCH-NOTES", pn), ("WHATS-NEW", wn1),
                            ("README-INGAME", read("docs/README-INGAME.md"))) if old in t]
    check("D3 SD-70: no document keeps the old line", not stale, stale)

    # M: the mover question (SD-68)
    close_line = lua_str(mover, r'\("(the mover closed with the settings window\. Your %d unsaved move\(s\) are kept[^"]*)"\)')
    ask = lua_str(mover, r'local ASK_TEXT = "([^"]+)"')
    btns = re.findall(r'\{ "(Save|Discard|Keep editing)", ', lua_str(mover, r'(T\.Ask\(ASK_TEXT.*?\}\))') or "")
    combat_line = lua_str(mover, r'"(the mover closed because combat started\. It will open again with your unsaved moves when combat ends\.)"')
    check("M0 the close line, the question, its three buttons and the combat line are found in Mover.lua",
          close_line and ask and btns == ["Save", "Discard", "Keep editing"] and combat_line, (close_line, ask, btns, combat_line))
    old_m = re.compile(r"mover opens again with (them|your moves) the next time you open")
    for name, text in (("USER-GUIDE", ug), ("HELP-FAQ", faq), ("WHATS-NEW", wn1), ("PATCH-NOTES", pn)):
        check("M1 SD-68: %s no longer says the mover just opens again next time, and names Save, Discard and Keep editing" % name,
              not old_m.search(text) and all(w in text for w in ("Save", "Discard", "Keep editing")) and "at login" in text)
    b405 = st.get(405, "")
    check("M2 SD-68: QA B405 quotes the close line and the question (1 move) and the three buttons exactly",
          close_line and ask and (close_line % 1) in b405 and (ask % 1) in b405
          and len(btns) == 3 and ("with the buttons **%s**, **%s** and **%s**" % tuple(btns)) in b405 and "no question at login" in b405,
          b405[:160])
    after = [n for n, l in st.items() if combat_line and combat_line in l and "**no** Save / Discard / Keep editing question" in l]
    check("M3 SD-15: a QA step expects the mover back after combat with no question", len(after) == 1, after)

    # T: talents status at once (SD-67)
    b404 = st.get(404, "")
    scan_lock = lua_str(talents, r'local SCAN_LOCK = "([^"]+)"')
    none = lua_str(talents, r'return "(No talent scan saved yet\.)"')
    check("T1 SD-67: QA B404 expects the talent status at once in combat, with the scan's combat line",
          "can't be read during combat" not in b404 and "at once, in combat" in b404 and scan_lock and scan_lock in b404
          and none and none in b404, b404[:200])

    # P: the bundle 1 landing
    # (SD-155) bundle 1 landed on main (a9cdbba5, SD-150), so "first entry", ".toc version" and "origin/main" no longer name bundle 1
    # and the pre-bundle main: its entry is found by its title, its versions are the landed ones (RN.BUNDLE1) and the main it rose above
    # is main before the merge (MAIN_FALLBACK, fda1e293). Entries still run newest first.
    heads = re.findall(r"^## (\d{4}-\d{2}-\d{2}) — (.+?)\s*$", pn, re.M)
    titles = [t for _, t in heads]
    _, entry = RN.EntryByTitle(pn)
    nxt = RN.Entries(pn)[titles.index("Rules Fix Bundle 1") + 1] if "Rules Fix Bundle 1" in titles[:-1] else (None, None, "")
    check("P1 the bundle 1 landing is in PATCH-NOTES outside any comment, entries newest first",
          entry and RN.NewestFirst(pn), heads[:3])
    check("P2 main's Stat Calculator landing follows it, with Bonus Features 0.6.46 and 0.6.45 and Options 0.6.108",
          nxt[1] == "Stat Calculator"
          and all(h in nxt[2] for h in ("### Bonus Features 0.6.46", "### Options 0.6.108", "### Bonus Features 0.6.45")))
    for addon, folder in (("XayaUI", "XayaUI"), ("Options", "XayaUI_Options"), ("Rules", "XayaUI_Rules")):
        tv, mv = RN.BUNDLE1[folder], MAIN_FALLBACK[folder]
        m = re.search(r"^### %s (\d+\.\d+\.\d+)\s*$" % addon, entry, re.M)
        check("P3 V10: %s's heading in the bundle 1 entry is its landed version (%s), above the earlier main's %s" % (addon, tv, mv),
              m and m.group(1) == tv and vkey(tv) > vkey(mv), m and m.group(1))
    # (round 10) SD-95 / SD-105 / SD-115 / SD-118 changed both Bonus folders in bundle 1: above main's 0.6.46, with their heading
    for folder in ("XayaUI_Bonus", "XayaUI_Bonus_StatCalculator"):
        tv = RN.BUNDLE1[folder]
        check("P4 %s changed in bundle 1 round 10: its version (%s) is above main's 0.6.46 and the entry has its Bonus Features heading"
              % (folder, tv), tv and vkey(tv) > vkey("0.6.46") and ("### Bonus Features %s\n" % tv) in entry, tv)
    must = [("route", "Moving, runes, totems and loss of control"), ("narrow", "a boss pull"),
            ("redraw", "at most 30 times a second on each display, and only while something on it changes"),
            ("tracker", "/xui debug perf on"), ("mover question", "Save, Discard (everything goes back) or Keep editing"),
            ("Debugging off", "Advanced Debugging is now off by default"), ("talents", "answer at once, in combat too"),
            ("tracker off main", "/xui debug mouse (the right-click tracker) is no longer part of this download"),
            ("combat lock", "no longer open in combat"), ("disable", "/xui disable")]
    miss = [k for k, w in must if w not in entry]
    check("P5 the entry names the player-visible changes of rounds 1 to 9", not miss, miss)
    sec = wn1[wn1.find("## 15. Rules fix bundle 1"):]
    wmust = ["rounds 1 to 9", "Moving, runes, totems and loss of control", "at most 30 times a second", "/xui debug perf on",
             "**Keep editing**", "Advanced Debugging is off by default", "/xui disable", "Combat lock"]
    wmiss = [w for w in wmust if w not in sec]
    check("P6 WHATS-NEW section 15 covers rounds 1 to 9", sec and not wmiss, wmiss)

    # N: numbers from the code
    gap = lua_str(engine, r"\nlocal ROUTED_GAP = ([0-9.]+)")
    fx = lua_str(visual, r"\nlocal FX_GAP = ([0-9.]+)")
    check("N1 USER-GUIDE: each kind of re-check at most %s times a second (ROUTED_GAP %s)" % (gap and round(1 / float(gap)), gap),
          gap and ("each kind of re-check runs at most %d times a second" % round(1 / float(gap))) in ug)
    check("N2 USER-GUIDE: moving parts redrawn at most %s times a second per display, only while something changes (FX_GAP %s)"
          % (fx and round(1 / float(fx)), fx),
          fx and ("redrawn at most %d times a second, and only while something on that display changes" % round(1 / float(fx))) in ug)
    limit = lua_str(perf, r"\nlocal LIMIT = (\d+)")
    poss = "(limit %d/s: possibly over)" % int(limit) if limit else None
    check("N3 SD-84: the guide quotes the tracker's range and its 'possibly over' text as RulesPerf.lua prints it",
          poss and poss in perf.replace("%d", str(limit)) and ("most in 1 s 10 to 14 " + poss) in ug and "possibly over" in faq, poss)

    # I: the in-game notes (SD-69)
    ipd = read("XayaUI_Options/InfoPaneData.lua")
    pats = re.findall(r'^    \{ date = "([^"]+)", title = "([^"]+)", blocks = \{', ipd, re.M)
    check("I1 SD-69: the pane holds at most the newest 5 landings plus \"Older notes\", starting with PATCH-NOTES' first",
          pats and len(pats) <= 6 and pats[-1][0] == "Older notes" and heads and pats[0] == heads[0]
          and [p for p in pats[:-1]] == heads[:len(pats) - 1], pats)
    bad = [l.strip()[:120] for l in ipd.splitlines()
           if (re.search(r"/xuiengine (full|refresh)", l) or "perf ui" in l) and "removed" not in l]
    check("I2 the pane offers no removed command (/xuiengine full or refresh, /xui debug perf ui)", not bad, bad)

    # I3 / I4 / I5 (repair 1): the build tool's round 9 change is pending on qa-installer-branch, and the pane is what it builds
    # (round 11a, SD-140) the patch is a working doc: it lives in Xaya's private notes repo (XUI-Docs), read from that checkout only
    plan_name = "R9-INFO-PANE-TOOL-PATCH-2026-11-16.md"
    plan_path = os.path.join(DOCS_ROOT, 'docs/plans/R9-INFO-PANE-TOOL-PATCH-2026-11-16.md')
    plan = None
    if os.path.isfile(plan_path):
        with open(plan_path, encoding="utf-8") as fh:
            plan = fh.read()
    named = {"PATCH-NOTES (its comment)": pn_raw[:pn_raw.find("-->") + 3], "README-INGAME": read("docs/README-INGAME.md")[:1200],
             "HELP-FAQ": faq[:1200], "USER-GUIDE": ug, "tests/info_pane_run.py": read("tests/info_pane_run.py")}
    false_claim = re.compile(r"KEEP_LANDINGS[^.;)]{0,20}(?:on |, )qa-installer-branch|<qa checkout>/tools/build_info_pane_data\.py\)")
    bad_claim = [n for n, t in named.items() if false_claim.search(t)]
    unflagged = [n for n, t in named.items() if "build_info_pane_data" in t and "qa-installer-branch" in t
                 and "pending" not in t.lower()]
    pointing = [n for n, t in named.items() if n != "tests/info_pane_run.py" and plan_name in t]
    check("I3 no document says the tool's round 9 change is on qa-installer-branch; each that names the tool there says it is pending; "
          "no player document points at the patch's working-doc path (SD-140)",
          (named["USER-GUIDE"] and named["HELP-FAQ"] and not bad_claim and not unflagged and not pointing),
          (bad_claim, unflagged, pointing))
    qa_tool = None
    try:
        r = subprocess.run(["git", "-C", ROOT, "show", "origin/qa-installer-branch:tools/build_info_pane_data.py"], capture_output=True,
                           text=True, timeout=60)
        qa_tool = r.stdout if r.returncode == 0 and r.stdout else None
    except Exception:
        pass
    # (round 11 hygiene; V35, SD-138: "a test fails if something it needs is missing (it must say what)") I3's second half and I4 need
    # two inputs that a clone may lack: the qa-installer-branch ref and Xaya's private notes checkout. Each missing one prints
    # "MISSING INPUT: <what>" (the suite's honest-result guard fails the test on it) and fails here, unless its named opt-out is set
    # (OPT_OUTS), which is printed and carried on the count line, so a run that checked less says so. A public clone has no private
    # notes, so it is expected to need XUI_SKIP_PRIVATE_NOTES=1 (technical choice, SD-145: a silent skip once hid I4 from every run).
    def missing(what, var, checks):
        if os.environ.get(var) == "1":
            print("OPT-OUT %s=1: %s not checked (%s)" % (var, checks, what))
            OPTED.append("%s via %s" % (checks, var))
        else:
            print("MISSING INPUT: %s; %s cannot be checked without it (set %s=1 to run without it, on purpose)" % (what, checks, var))
            check("%s (MISSING INPUT: %s)" % (checks, what), False, "set %s=1 to opt out on purpose" % var)
    if qa_tool is None:
        missing("origin/qa-installer-branch:tools/build_info_pane_data.py (git show in %s)" % ROOT, OPT_OUTS["qa"],
                "I3 'really not on qa-installer-branch' and I4")
    else:
        check("I3 the change really is not on qa-installer-branch yet (when it is, update the documents above)",
              "KEEP_LANDINGS" not in qa_tool and "XUI_ROOT" not in qa_tool)
    if qa_tool is not None and plan is None:
        missing("Xaya's private notes checkout with %s (XUI_DOCS_ROOT, else a sibling xui-docs)" % plan_path, OPT_OUTS["notes"], "I4")
    if qa_tool is not None and plan is not None:
        check("I4 the recorded patch (private notes) still says it is pending", "Status: **pending.**" in plan)
        m = re.search(r"```diff\n(.*?)```", plan, re.S)
        base_md5 = re.search(r"md5 ([0-9a-f]{32})", plan)
        ok4, why = False, "no diff in " + plan_path
        if m:
            tmp = tempfile.mkdtemp()
            try:
                os.makedirs(os.path.join(tmp, "tools"))
                with open(os.path.join(tmp, "tools", "build_info_pane_data.py"), "w", encoding="utf-8") as fh:
                    fh.write(qa_tool)
                with open(os.path.join(tmp, "tool.diff"), "w", encoding="utf-8") as fh:
                    fh.write(m.group(1))
                pr = subprocess.run(["patch", "-s", "-p1", "-d", tmp, "-i", os.path.join(tmp, "tool.diff")], capture_output=True,
                                    text=True, timeout=60)
                if pr.returncode != 0:
                    why = "patch did not apply: " + (pr.stdout + pr.stderr)[:200]
                else:
                    env = dict(os.environ, XUI_ROOT=ROOT)
                    cr = subprocess.run([sys.executable, "-I", os.path.join(tmp, "tools", "build_info_pane_data.py"), "--check"],
                                        capture_output=True, text=True, timeout=120, env=env)
                    ok4, why = cr.returncode == 0, (cr.stdout + cr.stderr)[:200]
            finally:
                shutil.rmtree(tmp, ignore_errors=True)
        base_ok = base_md5 and hashlib.md5(qa_tool.encode("utf-8")).hexdigest() == base_md5.group(1)
        check("I4 qa-installer-branch's tool with the recorded patch rebuilds InfoPaneData.lua exactly from this checkout's markdown "
              "(the plan's base md5 is QA's tool)", ok4 and base_ok, (why, base_ok))
    visible = [l for l in ipd.splitlines() if not l.lstrip().startswith("--")]
    land = [l.strip()[:100] for l in visible if re.search(r"\blandings?\b", l, re.I)]
    check("I5 the pane's text uses no in-house word 'landing'", not land, land)

    # P7 / P8 (repair 1): the Rules developers' note and the sound bullets say what is true against main
    gp = read("tests/gate_performance_run.py")
    capm = re.search(r'V33_EVENT_CAPS = \{"source": "ad60a051".*?"every": \{"XayaUI_Rules": (\d+)', gp, re.S)
    main_cap = int(capm.group(1)) if capm else None
    rules = entry[entry.find("### Rules "):] if "### Rules " in entry else ""
    devs = re.findall(r"\*Developers' notes?:[^*]*\*", rules)
    nums = None
    for d in devs:
        mm = re.search(r"costliest frame in a fight is ([\d,]+) .*?main's ([\d,]+)", d)
        if mm:
            nums = (int(mm.group(1).replace(",", "")), int(mm.group(2).replace(",", "")), d)
    words_ok = False
    if nums:
        drop = 1 - nums[0] / float(nums[1])
        words_ok = (("about a third less" in nums[2]) == (0.29 <= drop <= 0.38)) and (("about half" in nums[2]) == (0.45 <= drop <= 0.55))
    check("P7 the Rules developers' note gives the costliest fight frame against main's (%s, the gate's stored ad60a051 = main) and "
          "words that match the two numbers; no 'about half'" % main_cap,
          main_cap and nums and nums[1] == main_cap and words_ok and "about half" not in rules, nums and nums[:2])
    au = read("XayaUI_Rules/AuraSound.lua")
    # (round 10, SD-96) the DROP list is gone: the game's copy follows the Load tab exactly. No document may keep the old behaviour.
    check("P8 SD-96: AuraSound.lua has no DROP list any more (the game's copy follows every Load tab choice)",
          au and not re.search(r"local DROP = \{", au))
    snd_pn = rules[rules.find("**Sounds**"):] if "**Sounds**" in rules else ""
    snd_wn = sec[sec.find("**Game-played sound"):][:900] if "**Game-played sound" in sec else ""
    ug = read("docs/USER-GUIDE.md")
    ugb = ug[ug.find("- **Let the game play this sound on the aura itself**"):]
    nxt = re.search(r"\n- ", ugb[3:])
    ugb = ugb[:nxt.start() + 3] if nxt else ugb
    old_words = ("can also play outside combat", "outside the encounter", "does not apply")
    for name, t in (("PATCH-NOTES", snd_pn), ("WHATS-NEW", snd_wn), ("USER-GUIDE", ugb)):
        stale_w = [w for w in old_words if w in t]
        check("P8 %s: the game-played sound text no longer says the copy can also play outside combat or the encounter, or that a "
              "choice does not apply (SD-96)" % name, bool(t) and not stale_w, stale_w or "no sound text")

    # Q: in-game steps
    want = {
        424: ["/xui debug perf on", "possibly over", "10 to 14", "redrawText", "/xui debug perf ui"],
        425: ["SD-15", "**no** Save / Discard / Keep editing question"],
        426: ["Only in combat", "Only out of combat", "absent", "Out of combat", "boss encounter", "redrawText stops"],
        427: ["AddOn Usage", "Average CPU", "hitch", "V33"],
        428: ['/run collectgarbage("collect") local a=collectgarbage("count") for i=1,1000 do C_Timer.After(10, print) end print(collectgarbage("count")-a)', "C_Timer.NewTimer"],
        429: ["SD-49", "/run for _,r in ipairs(GetMouseFoci()) do", "IsMouseClickEnabled"],
        421: ["RB-29", "garrison"],
        # (repair 1) round8-summary.md in_game_steps that had no step
        430: ["Cooldown Manager", "shows when the buff is applied and hides when it is removed", "flicker",
              "perf: alert (Cooldown Manager alert re-checks):"],
        431: ['/run collectgarbage("collect")', "10 minutes", "AddOns list", "39,959.7 KB", "third"],
        432: ["talent", "loadout", "loading screen", "hitch"],
        433: ["busy pull", "0.1 seconds", "seconds left", "none is skipped"],
        # (repair 2) the USER-GUIDE's combat / boss Load choice bullets for the game-played sound point here
        # (round 10) B434: the Load tab followed exactly (SD-96), and the refusal fallback (SD-109)
        434: ["Only in combat", "Only out of combat", "The game is given it as each fight starts.", "only (b) plays", "only (a) plays",
              "The game would not take this sound when a fight started"],
        401: [RN.BUNDLE1[f] for f in ("XayaUI", "XayaUI_Options", "XayaUI_Rules", "XayaUI_Debug", "XayaUI_Bonus",
                                      "XayaUI_Bonus_StatCalculator")],   # (SD-155) B401 is bundle 1's install step
    }
    for n, words in sorted(want.items()):
        line = st.get(n, "")
        missing = [w for w in words if w not in line]
        check("Q B%d exists once with %s" % (n, ", ".join(repr(w[:40]) for w in words)),
              line and not missing and len(re.findall(r"\*\*B%d\.\*\*" % n, qa)) == 1, missing or "no step")
    # (round 10) B434 quotes the limits line exactly as AuraSound.lua builds it (LIMITS); no "does not apply" (SD-96)
    lim = re.search(r'local LIMITS = "([^"]+)" \.\.\s*"([^"]+)"', au)
    lim_txt = lim and (lim.group(1) + lim.group(2)).strip()
    check("Q B434 quotes the pane's limits line as AuraSound.lua builds it, and no 'does not apply'",
          lim_txt and lim_txt in st.get(434, "") and "does not apply" not in st.get(434, ""), lim_txt)
    b414 = st.get(414, "")
    check("Q B414 no longer waits on her decision (SD-68 decided: gated, with the tracker)",
          "NEEDS HER DECISION" not in b414 and "pollRange" in b414, b414[:120])

    bad_n = 0
    for name, ok in results:
        print(("PASS " if ok else "FAIL ") + name)
        bad_n += 0 if ok else 1
    print("%d checks, %d failed%s" % (len(results), bad_n, (" (opted out: %s)" % "; ".join(OPTED)) if OPTED else ""))
    return 1 if bad_n else 0


if __name__ == "__main__":
    sys.exit(main())
