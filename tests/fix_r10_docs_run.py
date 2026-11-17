#!/usr/bin/env python3
"""Bundle 1 round 10, docs: what the player reads, the standards and the request log match the code after round 10 and Xaya's answers
SD-86 to SD-118 (REQUEST-LOG A23). Every quoted chat line, page line and number is read from the Lua or test file that prints or uses it,
so a document that drifts from the code fails here.

  V  VERIFICATION.md: V27 carries SD-99 (her words, exactly as logged) and SD-114; V34 says the Stat Calculator loads at first open
     (SD-105) and names three exceptions: SD-62, SD-113 (BarCue.lua and AuraSound.lua, with the measured 107.7 KB / 3,900 login
     instructions) and SD-115 (Calculator.lua, about 39 KB); standing rules SD-104, SD-113 and SD-118 with her words; the SD-87 replay
     reference; per-event caps SD-112 and SD-117 at the number the gate holds (tests/gate_performance_run.py BONUS_EVENT_CAPS).
  L  REQUEST-LOG status cells (never her words): no SD-86 to SD-118 row starts with OPEN; SD-103 is PARKED; SD-85 says BUILT, not DONE;
     SD-56 names every round 9 merge decision and its round 10 answer; SD-58 corrects the calc / calculator and BarColorizeTypes
     claims; SD-66 gives both caps of each round (every fight frame, steady fights) and the cap the gate holds now.
  C  Stat Calculator (SD-94, SD-100, SD-102, SD-103, SD-105, SD-118): USER-GUIDE, QA B436 and STAT-CALCULATOR-MAIN-INGAME-CHECKS quote
     the off line (core's ns.PartOffText with the loader's part), the memory line, the not-loaded-yet status line, the page lines and the
     switch's hover text exactly as XayaUI_Bonus/StatCalculatorLoader.lua prints them; no player document says it takes effect after a
     reload, that "/xui stats on" exists, or that the panel comes back after combat.
  K  Calculator (SD-95, SD-115, SD-116, SD-118, CHAT-6): USER-GUIDE, README-INGAME, PATCH-NOTES and QA B437 quote its off line and its
     example sum as XayaUI_Bonus/Calculator.lua prints them; its page is Bonus Features > Calculator (its RegisterSettingsPage); /calc.
  S  Sounds (SD-96, SD-107, SD-109): USER-GUIDE quotes the pane's limits line, its Cooldown Manager line and its refusal line as
     XayaUI_Rules/AuraSound.lua builds them; PATCH-NOTES and HELP-FAQ say the same; QA B435 carries six /run probe lines (each at most
     255 characters) that ask the game at fight start, boss pull and key start, and a Cooldown Manager step for a boss fight and a key.
  D  Displays and tracker: the tenths note "next tenth up" is gone (Visual.lua FxTenths now shows the tenth it is on); redrawFill's label
     is quoted as XayaUI_Debug/RulesPerf.lua prints it (USER-GUIDE, B424); B426 (d) covers a display the combat engine draws; B438 is the
     hidden-interface step.
  P  Versions and notes (V10, V17, V18): each addon changed in round 10 is above its round 9 version and main's; every X-Date is
     2026-11-16; PATCH-NOTES' bundle 1 entry (dated 2026-11-16) has a heading per changed addon at its .toc version, Bonus Features
     0.6.47 included, and names the round 10 changes; WHATS-NEW has section 16; QA B401 names every version; the Rules developers' note
     and QA B427 compare with the cap the gate holds for main (V33_EVENT_CAPS).
  M  docs/SESSION-START-SUMMARY.md no longer tells a session to regenerate MANIFEST.md5 on main (SD-72).
  R  (repair 1) README.md, the download's own folder guide: the Stat Calculator loads at its first open, never at login (SD-105);
     XayaUI_Bonus holds the Calculator (SD-115, its page from Calculator.lua's RegisterSettingsPage, its words /xui calc, /xui calculator,
     /calc); no "not on main" claim for the Calculator and no "holds only the Stat Calculator".
  G  (repair 1) every gap the round 10 reviews left unrepaired is written in its REQUEST-LOG status cell, not only in a report: SD-100 /
     SD-112 (the stand-in does not pass a hide to the 8 shown Change boxes; about 842 = 400 + 8 x 55.2), SD-105 (an error inside the
     calculator's files; the AddOns-list reason; the open choice on a second /xui stats after a failed load, NEEDS HER DECISION), SD-107
     (Essential / Utility icons; a Cooldown Manager change noticed only at the next sync or fight end), SD-118 (an unknown /xui stats word
     toggles the panel; the /xui debug help line while Advanced Debugging is off).
Negative control: on the documents before this round's docs unit (scratchpad r10pre-docs, proved on a private copy) checks in every
group fail; each deliberate mutation listed in the round 10 docs report is caught.
Run: python3 tests/fix_r10_docs_run.py   (XUI_R10_ROOT=<a checkout> to check another copy)"""
import os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.environ.get("XUI_R10_ROOT") or os.path.join(HERE, ".."))
results = []


def check(name, ok, extra=""):
    results.append((name + ("" if ok else "  [%s]" % (str(extra)[:300],)), bool(ok)))


def read(rel):
    p = os.path.join(ROOT, rel)
    if not os.path.exists(p):
        return ""
    with open(p, encoding="utf-8") as f:
        return f.read()


def nocomment(s):
    return re.sub(r"<!--.*?-->", "", s, flags=re.S)


def nocolor(s):
    return re.sub(r"\|r", "", re.sub(r"\|c[0-9a-fA-F]{8}", "", s or ""))


def lua_str(src, pattern):
    m = re.search(pattern, src, re.S)
    return m.group(1) if m else None


def steps(qa):
    out = {}
    for line in qa.splitlines():
        m = re.match(r"- \[ \] \*\*B(\d+)\.\*\*", line)
        if m:
            out[int(m.group(1))] = line
    # a step may go on in indented lines (B435's /run lines)
    lines = qa.splitlines()
    for i, line in enumerate(lines):
        m = re.match(r"- \[ \] \*\*B(\d+)\.\*\*", line)
        if m:
            j = i + 1
            while j < len(lines) and lines[j].startswith("  ") and not lines[j].lstrip().startswith("- [ ]"):
                out[int(m.group(1))] += "\n" + lines[j]
                j += 1
    return out


def vkey(v):
    return tuple(int(x) for x in v.split("."))


def toc_version(folder):
    m = re.search(r"^## Version:\s*(\S+)", read("%s/%s.toc" % (folder, folder)), re.M)
    return m.group(1) if m else None


def toc_date(folder):
    m = re.search(r"^## X-Date:\s*(\S+)", read("%s/%s.toc" % (folder, folder)), re.M)
    return m.group(1) if m else None


def log_rows(text):
    rows = {}
    for line in text.splitlines():
        m = re.match(r"\| SD-(\d+) \| ", line)
        if m:
            rows[int(m.group(1))] = re.split(r"(?<!\\) \| ", line.strip()[2:-2])
    return rows


def answer(rows, n):
    """Her verbatim answer in the log row's words cell (after 'verbatim:'), log escapes undone."""
    w = rows.get(n, ["", ""])[1]
    m = re.search(r'verbatim: "(.*)"\s*$', w)
    return m.group(1).replace('\\"', '"') if m else None


# round 9 values (the round 9 docs unit's .toc lines) and main's (origin/main fda1e293)
ROUND9 = {"XayaUI": "0.6.86", "XayaUI_Options": "0.6.109", "XayaUI_Rules": "0.7.1", "XayaUI_Debug": "0.7.0",
          "XayaUI_Bonus": "0.6.46", "XayaUI_Bonus_StatCalculator": "0.6.46"}
MAIN = {"XayaUI": "0.6.85", "XayaUI_Options": "0.6.108", "XayaUI_Rules": "0.7.0", "XayaUI_Bonus": "0.6.46",
        "XayaUI_Bonus_StatCalculator": "0.6.46"}
# changed in round 10 (the Stage 1 units' file lists): core (Modules, Core, Theme, MinimapButton, KeyCatch, GameMenuButton), Options
# (closures, Editor.lua), Rules (AuraSound, Conditions, Visual, AuraDisplay, BarCue, AuraModel, AuraTracker), Debug (RulesPerf.lua),
# Bonus (Calculator.lua, loader, ProfilePart), the Stat Calculator (StatCalculator.lua)
CHANGED_R10 = list(ROUND9)
HEAD_NAMES = {"XayaUI": "XayaUI", "XayaUI_Options": "Options", "XayaUI_Rules": "Rules", "XayaUI_Bonus": "Bonus Features"}


def main():
    ver = read("docs/process/VERIFICATION.md")
    log = read("docs/process/REQUEST-LOG.md")
    rows = log_rows(log)
    ug, faq, qa = read("docs/USER-GUIDE.md"), read("docs/HELP-FAQ.md"), read("docs/QA-CHECKLIST.md")
    rd = nocomment(read("docs/README-INGAME.md"))
    pn = nocomment(read("PATCH-NOTES.md"))
    wn = read("docs/WHATS-NEW.md").replace("\n  ", " ")
    scm = read("docs/plans/STAT-CALCULATOR-MAIN-INGAME-CHECKS.md")
    st = steps(qa)
    modules, loader = read("XayaUI/Modules.lua"), read("XayaUI_Bonus/StatCalculatorLoader.lua")
    calc, au = read("XayaUI_Bonus/Calculator.lua"), read("XayaUI_Rules/AuraSound.lua")
    perf, visual, gp = read("XayaUI_Debug/RulesPerf.lua"), read("XayaUI_Rules/Visual.lua"), read("tests/gate_performance_run.py")

    # ---------------- V: VERIFICATION.md
    v27 = [l for l in ver.splitlines() if l.startswith("- **V27 ")]
    v27 = v27[0] if v27 else ""
    a99 = answer(rows, 99)
    check("V1 V27 quotes SD-99 exactly as logged and says rule displays always pass clicks (SD-114)",
          a99 and ('"%s"' % a99) in v27 and "SD-114" in v27 and "every XayaUI window is closed" in v27, (a99 or "")[:60])
    v34 = [l for l in ver.splitlines() if l.startswith("- **V34 ")]
    v34 = "\n".join(ver.splitlines()[ver.splitlines().index(v34[0]):][:6]) if v34 else ""
    check("V2 V34: the Stat Calculator loads at first open (SD-105, her answer quoted)",
          "loads at first open" in v34 and "SD-105" in v34 and ('"%s' % (answer(rows, 105) or "?")) in v34)
    check("V3 V34 names three exceptions: SD-62; SD-113 (BarCue.lua, AuraSound.lua, 107.7 KB, 3,900 login instructions); SD-115 "
          "(Calculator.lua, about 39 KB, arithmetic shown)",
          "Named exceptions" in v34 and "The one named exception" not in ver and "SD-62" in v34
          and all(w in v34 for w in ("SD-113", "BarCue.lua", "AuraSound.lua", "107.7 KB", "3,900 login instructions"))
          and all(w in v34 for w in ("SD-115", "Calculator.lua", "about 39 KB", "7,737.82 - 7,699.50 = 38.32 KB"))
          and "decided later, after performance is measured" not in ver)
    for n, key in ((104, "Questions to her in plain words"), (113, "No new addon folder unless"), (118, "A part's chat words work only")):
        a = answer(rows, n)
        if n == 118:
            a = answer(rows, 116) and "the chat calls only become available if individual components are enabled"
        check("V4 standing rule SD-%d is written with her words (%s)" % (n, key), a and key in ver and a in ver, (a or "")[:60])
    check("V5 the SD-87 replay reference is written (her answer, today's display, 89ea79ab only reported)",
          "SD-87" in ver and ('"%s"' % (answer(rows, 87) or "?")) in ver and "89ea79ab" in ver)
    caps = {a: b for a, b, _ in re.findall(r'"(XayaUI_Bonus(?:_StatCalculator)?)": \((\d+), "(SD-\d+)"', gp)}
    v33 = [l for l in ver.splitlines() if l.startswith("- **V33 ")]
    v33 = v33[0] if v33 else ""
    check("V6 V33 names the per-event caps SD-112 and SD-117 at the number the gate holds (%s)" % caps,
          caps.get("XayaUI_Bonus_StatCalculator") and caps.get("XayaUI_Bonus")
          and ("XayaUI_Bonus_StatCalculator %s (SD-112" % caps["XayaUI_Bonus_StatCalculator"]) in v33
          and ("XayaUI_Bonus %s (SD-117" % caps["XayaUI_Bonus"]) in v33, caps)

    # ---------------- L: REQUEST-LOG status cells
    open_rows = [n for n in range(86, 119) if n in rows and rows[n][2].startswith("OPEN")]
    check("L1 no SD-86 to SD-118 status starts with OPEN", rows and not open_rows, open_rows)
    check("L2 SD-103 is PARKED (her answer: circle back), and its interim is labelled as not her decision",
          rows.get(103, ["", "", ""])[2].startswith("PARKED") and "not her decision" in rows[103][2])
    check("L3 SD-85 says BUILT, not DONE", rows.get(85, ["", "", ""])[2].startswith("BUILT") and "DONE" not in rows[85][2])
    s56 = rows.get(56, ["", "", ""])[2]
    check("L4 SD-56 names every round 9 merge decision and its round 10 answer",
          "NEEDS HER DECISION from the round 9 merge" not in s56
          and all(w in s56 for w in ("SD-86", "SD-88", "SD-89", "SD-91", "SD-92", "SD-98", "SD-105", "SD-113", "SD-115", "SD-118")), s56[:80])
    s58 = rows.get(58, ["", "", ""])[2]
    check("L5 SD-58 corrects round 9: calc and calculator stay in core's Bonus row on purpose; BarColorizeTypes removed in round 10",
          "calc and calculator" in s58 and "BarColorizeTypes" in s58 and "round 10" in s58 and "REMINDER" not in s58)
    s66 = rows.get(66, ["", "", ""])[2]
    capm = re.search(r'"every": \{"XayaUI_Rules": (\d+).*?"steady": \{"XayaUI_Rules": (\d+)', gp, re.S)
    cap_e, cap_s = (int(capm.group(1)), int(capm.group(2))) if capm else (None, None)
    check("L6 SD-66 gives round 9's caps (579,900 every fight frame, 579,800 steady) and the caps the gate holds now (%s, %s)"
          % (cap_e, cap_s),
          cap_e and "579,900 for every fight frame and 579,800 for the steady fights" in s66
          and ("{:,} for every fight frame and {:,} for the steady fights".format(cap_e, cap_s)) in s66
          and "cap became 579,800" not in s66, s66[:120])
    try:
        r = subprocess.run(["git", "-C", ROOT, "show", "HEAD:docs/process/REQUEST-LOG.md"], capture_output=True, text=True, timeout=60)
        old = log_rows(r.stdout) if r.returncode == 0 else None
    except Exception:
        old = None
    if old:
        changed = [n for n in old if n in rows and old[n][1] != rows[n][1]]
        check("L7 her words (second cell) of every SD row are unchanged from the last commit", not changed, changed)
    else:
        print("note: git not available here; L7 (her words unchanged) not checked")

    # ---------------- C: Stat Calculator
    pfmt = lua_str(modules, r'function ns\.PartOffText\(part\)\s*return \("([^"]+)"\)')
    sc_name = lua_str(loader, r'local LABEL = "([^"]+)"')
    sc_where = lua_str(loader, r'local SC_PART = \{ name = LABEL, isOn = Saved, where = "([^"]+)" \}')
    sc_off = pfmt and sc_name and sc_where and ("XayaUI: " + pfmt.replace("%s", sc_name, 1).replace("%s", sc_where, 1))
    mem = lua_str(loader, r'ns\.Print\("(The Stat Calculator is off\. Its memory is freed at your next /reload\.)"\)')
    notyet = lua_str(loader, r'ns\.Print\("(Stat Calculator: on, not loaded yet \(it loads the first time you open it\)\.)"\)')
    why_dis = lua_str(loader, r'local WHY_DISABLED = "([^"]+)"')
    page = re.findall(r'return "((?:The Stat Calculator could not load|Its options appear|Off\. Turn it on)[^"]*)"', loader)
    desc = lua_str(loader, r'desc = "(On, the Stat Calculator loads the first time you open it\.[^"]*)"')
    check("C0 the Stat Calculator's lines are found in the code", sc_off and mem and notyet and why_dis and len(page) == 3 and desc,
          (sc_off, mem, notyet, len(page), desc))
    for name, text in (("USER-GUIDE", ug), ("QA B436", st.get(436, "")), ("STAT-CALCULATOR-MAIN-INGAME-CHECKS", scm)):
        check("C1 %s quotes the off line exactly: %s" % (name, sc_off), sc_off and ('"%s"' % sc_off) in text)
        check("C2 %s quotes the memory line and the not-loaded-yet status line" % name,
              mem and notyet and ("XayaUI: " + mem) in text and ("XayaUI: " + notyet) in text)
    check("C3 USER-GUIDE quotes the three page lines and the switch's hover text",
          len(page) == 3 and all(('"%s"' % p) in ug for p in page) and desc and ('"%s"' % desc) in ug)
    check("C4 USER-GUIDE and QA B436 quote the failed-load status line", why_dis and ("XayaUI: " + why_dis) in st.get(436, "")
          and why_dis in ug)
    stale = []
    readme = read("README.md")
    for name, text in (("USER-GUIDE", ug), ("README-INGAME", rd), ("HELP-FAQ", faq), ("README.md", readme)):
        if re.search(r"Turning it on or off takes effect after a reload|the change takes effect after a /reload"
                     r"|loads it once at login|once per reload, only while", text):
            stale.append(name + ": reload")
        for m in re.finditer(r"/xui stats on", text):
            ctx = text[max(0, m.start() - 160):m.end() + 160]
            if not re.search(r"no longer exists|no `/xui stats on`|There is no `/xui stats on`|is removed|does not exist", ctx):
                stale.append(name + ": /xui stats on")
    check("C5 no player document (README.md included) says the Stat Calculator switch needs a reload, that it loads at login or "
          "once per reload, or that /xui stats on exists", not stale, stale)
    a12 = ug[ug.find("### 12.12a"):ug.find("### 12.12 Character Toolkit")]
    check("C6 USER-GUIDE 12.12a: loads at first open, never at login or in combat, does not come back after a fight (SD-102), "
          "the settings page interim names SD-103",
          a12 and "loads the first time you open it" in a12 and "Never at login and never in combat" in a12
          and "does **not** come back" in a12 and "SD-103" in a12 and "comes back after combat" not in a12)
    b436 = st.get(436, "")
    check("C7 QA B436: first open by the minimap row, /xui stats and docked, mid-session load (IsAddOnLoaded true without a reload), "
          "no reappearing after combat",
          all(w in b436 for w in ("minimap", "`/xui stats`", "docked", 'IsAddOnLoaded("XayaUI_Bonus_StatCalculator")', "`true`",
                                  "no reload", "does **not** come back")))

    # ---------------- K: Calculator
    c_name = lua_str(calc, r'local PART = \{ name = "([^"]+)", isOn = On, where = "[^"]+" \}')
    c_where = lua_str(calc, r'local PART = \{ name = "[^"]+", isOn = On, where = "([^"]+)" \}')
    c_off = pfmt and c_name and c_where and ("XayaUI: " + pfmt.replace("%s", c_name, 1).replace("%s", c_where, 1))
    ex = lua_str(calc, r"(/xui calc 23,249 / 3,472) prints")
    ex_out = lua_str(calc, r"/xui calc 23,249 / 3,472 prints (23,249 / 3,472 = 6\.696141)")
    pg = re.search(r'RegisterSettingsPage\("(\w+)", "(\w+)"', calc)
    check("K0 the Calculator's off line, example sum and page are found in Calculator.lua", c_off and ex and ex_out and pg,
          (c_off, ex, ex_out))
    for name, text in (("USER-GUIDE", ug), ("README-INGAME", rd), ("PATCH-NOTES", pn), ("QA B437", st.get(437, ""))):
        check("K1 %s quotes the Calculator's off line exactly: %s" % (name, c_off), c_off and c_off in text)
    for name, text in (("USER-GUIDE", ug), ("PATCH-NOTES", pn), ("QA B437", st.get(437, ""))):
        check("K2 %s shows the example sum and its answer as Calculator.lua prints it" % name,
              ex_out and ("XayaUI: " + ex_out) in text and ex and ex in text)
    k3 = ug[ug.find("### 12.4b Calculator"):ug.find("### 12.5 ")]
    check("K3 USER-GUIDE 12.4b: its page is Bonus Features > Calculator (RegisterSettingsPage %s), /calc is there, on by default, "
          "Esc and Enter let go of the keyboard; no 'Utilities' page, no 'with a sum still answers'" % (pg and pg.groups(),),
          pg and pg.groups() == ("bonus", "calculator") and "Bonus Features > Calculator" in k3 and "`/calc`" in k3
          and "on by default" in k3 and "Esc" in k3 and "Enter" in k3 and "Utilities" not in k3
          and "still answers in chat" not in k3 and "SD-115" in k3)
    b437 = st.get(437, "")
    check("K4 QA B437: /calc, Enter, Esc twice, the screenshot key, a click outside, a fight, the tick box",
          all(w in b437 for w in ("`/calc 2+2`", "**Enter**", "**Esc**", "screenshot key", "game world", "training dummy", "untick")))

    # ---------------- S: sounds
    lim = re.search(r'local LIMITS = "([^"]+)" \.\.\s*"([^"]+)"', au)
    lim_txt = lim and (lim.group(1) + lim.group(2)).strip()
    cdm = re.search(r'local CDM_LINE = "([^"]+)"', au)
    cdm_first = cdm and nocolor(cdm.group(1)).split(". ")[0] + "."
    fb = re.search(r'return \(" (The game would not take this sound) %s, (so XayaUI keeps it set up from before the fight\. It plays '
                   r'anyway, and it may)" \.\.\s*" (also play when your Load tab says no\.)%s"\)', au)
    nudge = lua_str(au, r'local NUDGE = " ([^"]+)"')
    fb_txt = fb and nudge and ("%s when a fight started, %s %s %s" % (fb.group(1), fb.group(2), fb.group(3), nudge))
    check("S0 the pane's limits, Cooldown Manager and refusal lines are found in AuraSound.lua", lim_txt and cdm_first and fb_txt,
          (lim_txt, cdm_first, fb_txt))
    ugb = ug[ug.find("- **Let the game play this sound on the aura itself**"):]
    nxt = re.search(r"\n- ", ugb[3:])
    ugb = ugb[:nxt.start() + 3] if nxt else ugb
    lim_plain = lim_txt and lim_txt.replace("(Repeat)", "(**Repeat**)").replace("conditions or", "its conditions or the")
    check("S1 USER-GUIDE: the copy can never repeat or wait for other triggers (the pane's limits line), the Load tab is followed "
          "exactly (SD-96), the Cooldown Manager line (SD-107) and the refusal line (SD-109) as AuraSound.lua builds them",
          lim_plain and lim_plain in ugb and "followed exactly" in ugb and cdm_first and cdm_first in ugb
          and fb_txt and ('"%s"' % fb_txt) in ugb and "can also play outside combat" not in ugb, (lim_plain,))
    sp = pn[pn.find("**Sounds**", pn.find("### Rules ")):]
    sp = sp[:sp.find("**Backups**")]
    check("S2 PATCH-NOTES Sounds: follows the Load tab exactly, refusal fallback, Cooldown Manager, never repeats",
          all(w in sp for w in ("follows the rule's Load tab exactly", "refuses the copy", "Cooldown Manager", "can never repeat")))
    check("S3 HELP-FAQ answers the Cooldown Manager line and the refusal line in the pane's words",
          cdm_first and ('"%s"' % cdm_first.rstrip(".").split(",")[0]) in faq
          and '"The game would not take this sound when a fight started"' in faq)
    b435 = st.get(435, "")
    runs = re.findall(r"`(/run [^`]+)`", b435)
    check("S4 QA B435: six /run probe lines, each at most 255 characters, asking at fight start, boss pull and key start, and the "
          "lit Cooldown Manager icon; a Cooldown Manager rule in a boss fight and a Mythic+ key",
          len(runs) == 6 and all(len(x) <= 255 for x in runs)
          and all(any(w in x for x in runs) for w in ("AddAuraSound", "GetCooldownViewerCooldownInfo", "wasSetFromAura",
                                                         "CHALLENGE_MODE_START", "ENCOUNTER_START", "PLAYER_REGEN_DISABLED"))
          and "boss fight" in b435 and "Mythic+ key" in b435 and cdm_first and cdm_first.split(",")[0] in b435,
          [len(x) for x in runs])

    # ---------------- D: displays and tracker
    tenths_code = re.search(r"math\.ceil\(rem\s*\*\s*10\)\s*-\s*1", visual)
    ipd = read("XayaUI_Options/InfoPaneData.lua")
    check("D1 the 'next tenth up' note is gone (Visual.lua now keys tenths with ceil(rem*10)-1)",
          tenths_code and "next tenth up" not in pn and "next tenth up" not in ipd and "next tenth up" not in wn)
    lab = lua_str(perf, r'redrawFill = "([^"]+)"')
    check("D2 redrawFill's label is quoted as RulesPerf.lua prints it (USER-GUIDE, QA B424); no 'bar fills written'",
          lab and lab in ug and ("redrawFill (%s)" % lab) in st.get(424, "") and "bar fills written" not in ug
          and "bar fills written" not in qa, lab)
    check("D3 QA B426 (d) is also done on a display the combat engine draws", "combat engine draws" in st.get(426, ""))
    check("D4 QA B438: the hidden-interface step (Alt+Z, redrawText)", all(w in st.get(438, "") for w in ("Alt+Z", "redrawText")))

    # ---------------- P: versions and notes
    for f in CHANGED_R10:
        tv = toc_version(f)
        okv = tv and vkey(tv) > vkey(ROUND9[f]) and (f not in MAIN or vkey(tv) > vkey(MAIN[f]))
        check("P1 %s changed in round 10: .toc %s is above round 9's %s%s" % (f, tv, ROUND9[f], (" and main's %s" % MAIN[f]) if f in MAIN else ""),
              okv, tv)
        check("P2 %s X-Date is 2026-11-16" % f, toc_date(f) == "2026-11-16", toc_date(f))
    heads = re.findall(r"^## (\d{4}-\d{2}-\d{2}) — (.+?)\s*$", pn, re.M)
    parts = re.split(r"^## \d{4}-\d{2}-\d{2} — .*$", pn, flags=re.M)
    entry = parts[1] if len(parts) > 1 else ""
    check("P3 the bundle 1 entry is first and dated 2026-11-16", heads and heads[0] == ("2026-11-16", "Rules Fix Bundle 1"), heads[:1])
    for f, h in HEAD_NAMES.items():
        check("P4 the entry has '### %s %s' (its .toc version)" % (h, toc_version(f)), ("### %s %s\n" % (h, toc_version(f))) in entry)
    must = ["**Calculator (new)**", "/xui stats on is removed", "loads the first time you open it", "no longer comes back by itself",
            "follows the rule's Load tab exactly", "Out of combat opacity now also applies", "A part's commands now work only while"]
    check("P5 the entry names the round 10 changes", not [w for w in must if w not in entry], [w for w in must if w not in entry])
    sec16 = wn[wn.find("## 16. Rules fix bundle 1, round 10"):]
    vers = ["XayaUI %s" % toc_version("XayaUI"), "Options %s" % toc_version("XayaUI_Options"), "Rules %s" % toc_version("XayaUI_Rules"),
            "XayaUI Debug %s" % toc_version("XayaUI_Debug"), "Bonus Features %s" % toc_version("XayaUI_Bonus")]
    check("P6 WHATS-NEW section 16 covers round 10 with every version", "## 16. Rules fix bundle 1, round 10" in wn
          and not [v for v in vers if v not in sec16] and "Calculator (new" in sec16, [v for v in vers if v not in sec16])
    b401 = st.get(401, "")
    check("P7 QA B401 names every addon's .toc version", all(toc_version(f) and toc_version(f) in b401 for f in ROUND9)
          and "stay 0.6.46" not in b401)
    rules = entry[entry.find("### Rules "):]
    mm = re.search(r"costliest frame in a fight is ([\d,]+) .*?main's ([\d,]+)", rules)
    nums = mm and (int(mm.group(1).replace(",", "")), int(mm.group(2).replace(",", "")))
    b427 = st.get(427, "")
    check("P8 the Rules developers' note and QA B427 compare with the cap the gate holds for main (%s), with the same reading" % cap_e,
          nums and cap_e and nums[1] == cap_e and ("{:,}".format(nums[0])) in b427 and ("{:,}".format(cap_e)) in b427
          and "576,800" not in b427, nums)

    # ---------------- M: SESSION-START-SUMMARY
    ss = read("docs/SESSION-START-SUMMARY.md")
    check("M1 SESSION-START-SUMMARY no longer tells a session to regenerate MANIFEST.md5 on main (SD-72)",
          "regenerates MANIFEST.md5 and reruns" not in ss and "SD-72" in ss)

    # ---------------- R: README.md (repair 1)
    rows_md = {m.group(1): m.group(2) for m in re.finditer(r"^\| `(XayaUI\w*)` \| [^|]+\| (.+) \|\s*$", readme, re.M)}
    rb, rs = rows_md.get("XayaUI_Bonus", ""), rows_md.get("XayaUI_Bonus_StatCalculator", "")
    toc_b = read("XayaUI_Bonus/XayaUI_Bonus.toc")
    pgname = "Bonus Features > Calculator" if (pg and pg.groups() == ("bonus", "calculator")) else None
    check("R1 README's XayaUI_Bonus row holds the Calculator (Calculator.lua is in its .toc): its words and its page (%s)" % pgname,
          "Calculator.lua" in toc_b and pgname and pgname in rb and all(w in rb for w in ("`/xui calc`", "`/xui calculator`", "`/calc`"))
          and "on by default" in rb, rb[:120])
    check("R2 README says the Calculator is on main and the new Bonus folder holds more than the Stat Calculator",
          not re.search(r"Notepad, Calculator", rb) and "holds only the Stat Calculator)" not in readme
          and "Since Bonus 0.6.47 `XayaUI_Bonus` also holds the Calculator" in readme)
    check("R3 README's Stat Calculator row: loads the first time its panel opens, never at login or in combat; off after loading, "
          "memory freed at the next /reload (SD-105, SD-86, SD-100)",
          all(w in rs for w in ("the first time you open its panel", "never at login and never in combat", "freed at your next /reload"))
          and "once at login" not in rs, rs[:120])

    # ---------------- G: every unrepaired review gap is in its REQUEST-LOG cell (repair 1)
    st_ = lambda n: rows.get(n, ["", "", ""])[2]
    check("G1 SD-100 and SD-112 name the stand-in's hide gap and its estimate with arithmetic (about 842 = 400 + 8 x 55.2, 718 / 13)",
          "about 842 (400 + 8 x 55.2, where 55.2 = 718 / 13" in st_(100) and "8 shown Change boxes" in st_(100)
          and "about 842" in st_(112) and "INFERENCE" in st_(112))
    check("G2 SD-105 names the error-inside-its-files gap, the AddOns-list reason gap and the open choice on a second /xui stats",
          all(w in st_(105) for w in ("stop with a Lua error while loading", "'on, not loaded yet'", "ns.ModuleState",
                                      "NEEDS HER DECISION", "a second /xui stats")) and "see SD-105" in st_(86))
    check("G3 SD-107 names both Cooldown Manager gaps (Essential / Utility icons; a change noticed only at the next sync or fight end)",
          all(w in st_(107) for w in ("Essential or Utility", "next rule sync or at the end of the next fight", "INFERENCE")))
    check("G4 SD-118 names the unknown-word toggle and the /xui debug help line gap",
          "opens or closes the panel without a word" in st_(118) and "shown in the console window" in st_(118)
          and "the list prints in chat, not in a console window" in st_(118))
    check("G5 SD-109's gap stays written", "Known gap from review" in st_(109))

    failed = [n for n, ok in results if not ok]
    for n, ok in results:
        print(("ok    " if ok else "FAIL  ") + n)
    print("%d checks, %d failed" % (len(results), len(failed)))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
