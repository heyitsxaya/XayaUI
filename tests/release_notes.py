"""Shared reading of PATCH-NOTES.md for the docs tests (not a test itself: tests/run_all.py runs only *_run.py).

Why it exists: the bundle 1 docs tests (fix_r9_docs, fix_r10_docs, info_pane) were written while bundle 1 was the newest release, so they
read "the first PATCH-NOTES entry" and "the .toc version" as bundle 1's. Bundle 1 landed on main at a9cdbba5 (2026-11-24, REQUEST-LOG
SD-150); from the next version bump on, both of those name a later release and the checks failed on correct docs (found with SD-155,
Options 0.6.114). What they guard stays the same, read from fixed facts instead:
  - bundle 1's entry is found by its title, and its headings, QA B401 and WHATS-NEW sections 15 to 17 carry bundle 1's landed versions
    (BUNDLE1, read from main a9cdbba5's .toc files);
  - versions and notes still move together, for every later release too: each addon's .toc X-Date is the date of the newest entry
    with a heading at its current .toc version (VersionDateProblems), and entries run newest first.
"""
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUNDLE1_TITLE = "Rules Fix Bundle 1"
# main a9cdbba5 (bundle 1 landed, SD-150): each addon's ## Version
BUNDLE1 = {"XayaUI": "0.6.90", "XayaUI_Options": "0.6.113", "XayaUI_Rules": "0.7.5", "XayaUI_Debug": "0.7.3",
           "XayaUI_Bonus": "0.6.50", "XayaUI_Bonus_StatCalculator": "0.6.50"}
# the heading name each addon folder uses in PATCH-NOTES ("### <name> <version>")
HEAD_NAMES = {"XayaUI": "XayaUI", "XayaUI_Options": "Options", "XayaUI_Rules": "Rules", "XayaUI_Debug": "XayaUI Debug",
              "XayaUI_Bonus": "Bonus Features", "XayaUI_Bonus_StatCalculator": "Bonus Features"}
_HEAD = re.compile(r"^## (\d{4}-\d{2}-\d{2}) — (.+?)\s*$", re.M)


def Entries(pn):
    """[(date, title, body)] in file order. pn must already have its HTML comments removed."""
    heads = _HEAD.findall(pn)
    bodies = _HEAD.split(pn)[3::3]   # split keeps the two groups: [pre, d1, t1, body1, d2, t2, body2, ...]
    return [(d, t, b) for (d, t), b in zip(heads, bodies)]


def EntryByTitle(pn, title=BUNDLE1_TITLE):
    """(date, body) of the first entry with that title, or (None, "")."""
    for d, t, b in Entries(pn):
        if t == title:
            return d, b
    return None, ""


def NewestFirst(pn):
    """True when every entry is dated no later than the one above it."""
    ds = [d for d, _, _ in Entries(pn)]
    return all(a >= b for a, b in zip(ds, ds[1:]))


def _toc(folder, key):
    try:
        with open(os.path.join(ROOT, folder, folder + ".toc"), encoding="utf-8") as fh:
            m = re.search(r"^## %s:\s*(\S+)" % re.escape(key), fh.read(), re.M)
    except OSError:
        return None
    return m.group(1) if m else None


def VersionDateProblems(pn, folders=tuple(BUNDLE1)):
    """Each addon's .toc X-Date must be the date of the newest entry holding '### <name> <its .toc version>'.
    Returns a list of problem strings (empty = fine); an addon with no such entry is a problem (its notes are missing), except one that
    has never had a heading of its own, whose X-Date need only be some entry's date."""
    out = []
    for f in folders:
        v, xd = _toc(f, "Version"), _toc(f, "X-Date")
        want = None
        for d, _, b in Entries(pn):
            if ("### %s %s\n" % (HEAD_NAMES[f], v)) in b:
                want = d
                break
        if want is None:
            # an addon PATCH-NOTES never gives a heading of its own (XayaUI Debug: its changes are told under XayaUI's): its X-Date must
            # still be a release's date; one with headings in older entries but none at its current version has missing notes
            named = any(re.search(r"^### %s \d" % re.escape(HEAD_NAMES[f]), b, re.M) for _, _, b in Entries(pn))
            if named or xd not in [d for d, _, _ in Entries(pn)]:
                out.append("%s %s: no PATCH-NOTES entry has its heading" % (f, v))
        elif xd != want:
            out.append("%s X-Date %s, its entry is dated %s" % (f, xd, want))
    return out
