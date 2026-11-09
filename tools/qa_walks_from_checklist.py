#!/usr/bin/env python3
"""Build XayaUI_DevAssist/QAWalks-Checklist.lua: every open item of docs/QA-CHECKLIST.md as a step of an in-game walkthrough (/xui dev qa).
Xaya 2026-11-06: the walkthroughs are a standing rule (V20); "High priority qa items should also be shipped in this first batch", and the
items she counts as high priority (question flow): "Combat display checks, Things you called urgent, Open bugs not yet checked,
Everything on main not checked"; and the order (same day): "start with bugs, then UI items that don't impact usage". So:
  1. Open bugs to confirm: docs/process/qa-open-bugs.json (open issues labelled bug + unverified-in-game), with the QA item that
     covers each one when the checklist names it;
  2. UI items that don't affect use: items whose text is about the look / layout (LOOK words) and not about combat, triggers, firing,
     sounds or saving (USE words). INFERENCE: the checklist has no such marking; this word rule decides, and is shown to her;
  3. Combat displays: section "B-engine" of the checklist;
  4. Urgent: the items she flagged (#268 anchors, the rules sidebar / group page fixes #368-#370, the character pane);
  5. Everything else, section by section, in walkthroughs of at most CHUNK steps.
An item already in an earlier walkthrough is not repeated. Text: **bold** and the word Expect turn gold, `code` light blue, a lone "|"
is doubled (the game draws "||" as "|"). Run: python3 tools/qa_walks_from_checklist.py [--check]  (--check: fail if the file is stale)."""
import json, os, re, sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SRC = os.path.join(ROOT, "docs/QA-CHECKLIST.md")
BUGS = os.path.join(ROOT, "docs", "process", "qa-open-bugs.json")
OUT = os.path.join(ROOT, "XayaUI_DevAssist", "QAWalks-Checklist.lua")
CHUNK = 12
LOOK = r"\b(label|labels|clip|clipped|clips|colou?r|colou?rs|font|width|wider|border|gutter|margin|skin|tab|tabs|truncat\w*|align\w*|look|icon size|spacing|overlap\w*|highlight\w*|tooltip|text size|layout|banner|theme)\b"
USE = r"\b(combat|trigger\w*|fires?|firing|sound\w*|saves?|saved|reload|import|export|load(s|ed)?|cast\w*|aura\w*|proc\w*|delete\w*|crash\w*|error)\b"
# Checklist sections for addons that live only on qa-installer-branch (tools/qa-only-paths.txt, 2026-11-08): their steps carry
# `needs`, so Dev Assist (QAWalk.lua QA.Register) leaves them out where that addon is not installed.
SECTION_NEEDS = {"G": "XayaUI_Reskin", "K": "XayaUI_Nameplates"}
URGENT = [r"#268\b", r"#368\b", r"#369\b", r"#370\b", r"[Cc]haracter [Pp]ane", r"[Cc]haracter [Rr]eskin"]


def items():
    text = open(SRC, encoding="utf-8").read()
    out, section = [], None
    for line in text.splitlines():
        h = re.match(r"^(##+) (.*)$", line)
        if h:
            section = h.group(2).strip()
            continue
        m = re.match(r"^- \[ \] \*\*([A-Za-z0-9\-]+)\.\*\* (.*)$", line)
        if m:
            out.append({"id": m.group(1), "text": m.group(2), "section": section or ""})
    return out


def wow(t):
    t = t.replace("|", "||")
    t = re.sub(r"\*\*(.+?)\*\*", r"|cffffd100\1|r", t)
    t = re.sub(r"`([^`]+)`", r"|cff88ccff\1|r", t)
    return t


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def needs_of(item):
    m = re.match(r"^([A-Z])\.", item.get("section") or "")
    return SECTION_NEEDS.get(m.group(1)) if m else None


def build():
    its = items()
    used = set()
    walks = []

    def add(key, title, order, steps):
        if steps:
            walks.append((key, title, order, steps))

    def chunked(prefix, title, order, lst):
        for n in range(0, len(lst), CHUNK):
            part = lst[n:n + CHUNK]
            k = (n // CHUNK) + 1
            total = (len(lst) + CHUNK - 1) // CHUNK
            add("%s-%d" % (prefix, k), "%s%s" % (title, (" (%d of %d)" % (k, total)) if total > 1 else ""), order + k * 0.01,
                [(i["id"], ("[%s] " % i["id"]) + wow(i["text"]), needs_of(i)) for i in part])
            for i in part:
                used.add(i["id"])

    bugs = json.load(open(BUGS, encoding="utf-8")).get("issues", [])
    bsteps = []
    for b in bugs:
        n = b["number"]
        cover = [i["id"] for i in its if re.search(r"#%d\b" % n, i["text"])]
        step = "|cffffd100Bug #%d:|r %s" % (n, wow(b["title"]))
        if cover:
            step += "\n\nThe QA step that covers it: %s (in the walkthroughs below)." % ", ".join(cover)
        step += "\n\n|cffffd100Your call:|r does this still happen in your game? Pass = it is fixed, Fail = it still happens (say what you see)."
        bsteps.append(("bug%d" % n, step, None))
    add("chk-bugs", "1. Open bugs to confirm", 100, bsteps)
    look = [i for i in its if not i["section"].startswith("B-engine") and re.search(LOOK, i["text"], re.I) and not re.search(USE, i["text"], re.I)]
    chunked("chk-look", "2. Looks and layout (no effect on use)", 200, look)
    engine = [i for i in its if i["id"] not in used and i["section"].startswith("B-engine")]
    chunked("chk-combat", "3. Combat displays", 300, engine)
    urgent = [i for i in its if i["id"] not in used and any(re.search(p, i["text"]) for p in URGENT)]
    chunked("chk-urgent", "4. Urgent items", 400, urgent)
    rest = {}
    order = []
    for i in its:
        if i["id"] in used:
            continue
        sec = i["section"]
        if sec not in rest:
            rest[sec] = []
            order.append(sec)
        rest[sec].append(i)
    for n, sec in enumerate(order):
        letter = re.match(r"^([A-Z])", sec)
        chunked("chk-%s" % (letter.group(1).lower() if letter else str(n)), "5. " + re.sub(r"\s*\(.*$", "", sec).strip(), 500 + n, rest[sec])
    lines = [
        "-------------------------------------------------------------------------------",
        "-- QAWalks-Checklist.lua (XayaUI_DevAssist 0.7.4): GENERATED by tools/qa_walks_from_checklist.py from docs/QA-CHECKLIST.md and",
        "-- docs/process/qa-open-bugs.json. Do not edit by hand: change the checklist and run the tool. Every open checklist item is one step",
        "-- (what to do and what to expect); hand-written walkthroughs with Do it for me and the addon's own checks live in QAWalks*.lua.",
        "-- Order (Xaya 2026-11-06: \"start with bugs, then UI items that don't impact usage\"): open bugs, looks and layout, combat displays,",
        "-- urgent items, then everything else. Each step's key (the checklist ID, or bugNNN) is saved with its result and in the export code.",
        "-------------------------------------------------------------------------------",
        "local QA = XayaUI_DevQA",
        "if not QA then return end",
    ]
    for key, title, order, steps in walks:
        lines.append("QA.Register(%s, { title = %s, order = %s, generated = true, steps = {" % (lua_str(key), lua_str(title), repr(order)))
        for key, s, needs in steps:
            lines.append("    { key = %s, text = %s%s }," % (lua_str(key), lua_str(s), (", needs = %s" % lua_str(needs)) if needs else ""))
        lines.append("} })")
    return "\n".join(lines) + "\n", walks, its


def main():
    text, walks, its = build()
    if "--check" in sys.argv:
        cur = open(OUT, encoding="utf-8").read() if os.path.exists(OUT) else ""
        if cur != text:
            print("STALE: XayaUI_DevAssist/QAWalks-Checklist.lua differs from docs/QA-CHECKLIST.md; run python3 tools/qa_walks_from_checklist.py")
            sys.exit(1)
        print("in sync: %d walkthroughs, %d checklist items" % (len(walks), len(its)))
        return
    open(OUT, "w", encoding="utf-8").write(text)
    print("wrote %s: %d walkthroughs, %d checklist items" % (os.path.relpath(OUT, ROOT), len(walks), len(its)))


if __name__ == "__main__":
    main()
