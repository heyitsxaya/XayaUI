#!/usr/bin/env python3
"""Round 11a, docs off this public repo (REQUEST-LOG SD-140, SD-144, SD-145, SD-137; the log itself lives in Xaya's private repo
heyitsxaya/XUI-Docs). Her words (SD-140): "Docs like this should not be on main."; her answers: "All but player and build docs
(Recommended)", "Short CLAUDE.md on main (Recommended)"; (SD-145) "Docs meant for players are safe to preserve for now."

What a reader of the public repo gets, checked from git ls-files (V7) and the files themselves:
  W  No working doc is in the tree: nothing under docs/process/, docs/plans/ (except the kept Stat Calculator in-game steps),
     debug-log/, docs/issue-screenshots/, .claude/ or "Claude outputs/", and none of the single working files (roadmap, session
     summaries, audits, research notes). No saved game data (a WTF/ or SavedVariables path) is tracked.
  K  The player guides and build rules are still here (SD-145 keep list), and none of them, nor the in-game info pane text
     (XayaUI_Options/InfoPaneData.lua), points at a working doc by its path or by a markdown link; (round 11 hygiene) every Markdown
     file a kept doc names, by path or by its name alone, is a file of this tree (NAMED_ELSEWHERE lists the reviewed exceptions);
     every relative markdown link in a kept doc opens a file that is in the tree.
  T  No test or tool reads a working doc from this repo: no string in their code (docstrings and comments are not code) names one,
     except the reads listed in ALLOWED_PRIVATE, which read Xaya's private notes checkout (XUI_DOCS_ROOT), never this repo; (round 11
     hygiene) a Markdown file name alone that is not a file here, and a path built with os.path.join("docs", "plans", ...), count too.
  C  The repo-root CLAUDE.md is short (under 25 lines) and says: the repo is public; the rules and the request log live in the private
     repo heyitsxaya/XUI-Docs (docs/process/VERIFICATION.md, docs/process/REQUEST-LOG.md), read them before any work; refer to her as
     Xaya / she / her; never write working docs or her SavedVariables here; player guides, build rules and game data stay.
Fails on the tree before round 11a's docs-off change (proved on a private copy); passes after.
Run: python3 tests/fix_r11_docs_off_run.py   (XUI_R11_ROOT=<a checkout> to check another copy)"""
import ast, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.environ.get("XUI_R11_ROOT") or os.path.join(HERE, ".."))
SELF = "tests/fix_r11_docs_off_run.py"
results = []

# The erase decision (SD-140 / SD-144 / SD-145). Prefixes end with "/"; KEEP wins over a prefix.
WORK_PREFIXES = ("docs/process/", "docs/plans/", "debug-log/", "docs/issue-screenshots/", ".claude/", "Claude outputs/")
WORK_FILES = ("ARCHIVE.md", "CHANGELOG.md", "FEATURE-BLURBS.md", "ROADMAP.md", "SESSION-START-SUMMARY.md", "pa_tmp.md",
              "docs/OPEN-ITEMS.md", "docs/ROADMAP.md", "docs/SESSION-START-SUMMARY.md", "docs/TRIGGER-ENGINE-NOTES.md",
              "docs/design/DISPLAY-AUDIT-UI-47-2026-11-07.md", "docs/reference/GCD-RESEARCH-2026-11-07.md",
              "docs/reference/HOVER-REWRITES-UI-65-2026-11-07.md", "docs/reference/maps/SHOPPING-LIST-UPGRADE-TOAST.md")
KEEP = ("docs/plans/STAT-CALCULATOR-MAIN-INGAME-CHECKS.md",)
# Player guides and build rules that stay (SD-140 "All but player and build docs", SD-145 keep list).
KEPT_DOCS = ("README.md", "LICENSE", "THIRD_PARTY.md", "PATCH-NOTES.md", "docs/USER-GUIDE.md", "docs/HELP-FAQ.md",
             "docs/README-INGAME.md", "docs/WHATS-NEW.md", "docs/QA-CHECKLIST.md", "docs/plans/STAT-CALCULATOR-MAIN-INGAME-CHECKS.md",
             "docs/design/BUILD-RULES.md", "docs/design/DISPLAY-RULES.md", "docs/design/DISPLAY-RULINGS.md", "docs/reference/README.md")
# A pointer at a working doc in text: a path under a working prefix, a single working file, or a per-session request-log file name.
POINTER = re.compile(r"(?:docs/process/|docs/plans/(?!STAT-CALCULATOR-MAIN-INGAME-CHECKS\.md)|debug-log/|docs/issue-screenshots/"
                     r"|docs/(?:ROADMAP|SESSION-START-SUMMARY|OPEN-ITEMS|TRIGGER-ENGINE-NOTES)\.md|DISPLAY-AUDIT-UI-47-2026-11-07\.md"
                     r"|GCD-RESEARCH-2026-11-07\.md|HOVER-REWRITES-UI-65-2026-11-07\.md|REQUEST-LOG[\w-]*\.md|VERIFICATION\.md"
                     r"|RETROSPECTIVE\.md)")
# (round 11 hygiene; docs-off reviewer mutations R2, a bare 'PLATFORM-SPLIT-2026-11-07.md' in USER-GUIDE, and R10, a test reading
# os.path.join('docs', 'plans', 'PLATFORM-SPLIT-2026-11-07.md'), survived POINTER, which knows paths and a few names only) A working
# doc can also be named by its file name alone, or by a path built from parts. So every Markdown file name a kept doc or a test names
# must be a file of this tree (by its path, or by its name when written alone): every working doc left the tree (W1), so a name that is
# not here points at one (or at nothing). This needs no list of the erased names (the public repo does not carry them; the erase list,
# XUI-Docs erase-tools/make_paths.py, was used to prove it catches every one), and it does not go stale.
MD_NAME = re.compile(r"(?<![\w./-])((?:[\w.-]+/)*[\w.-]+\.md)\b", re.I)


# Markdown names that are not files of this tree and are not pointers at a working doc: (file, a regex the name matches, why). Each one is
# a decision; a name in another file, or of another shape, is not covered.
NAMED_ELSEWHERE = (
    ("docs/design/DISPLAY-RULINGS.md", r"\d{4}-\d{2}-\d{2}-\d{4}-[\w.-]+\.md",
     "a ruling's source in its Source column (\"DL <file>\"); the page's legend says every source is a working document kept in the "
     "private developer notes: a citation, not a pointer to read here (the round 11a docs-off review accepted it)"),
    ("docs/QA-CHECKLIST.md", r"report\.md", "J18: the file tools/perf_report.py writes (--out report.md), not a document"),
    ("docs/USER-GUIDE.md", r"XayaUI_DevAssist/FORMULA-CAPTURE-WALKTHROUGH\.md",
     "a tester walkthrough shipped inside the XayaUI Dev Assist addon folder (qa-installer-branch), not a working doc"),
    ("tests/fix_r9_docs_run.py", r"R9-INFO-PANE-TOOL-PATCH-2026-11-16\.md",
     "I3 checks that no player document names this private patch; the file itself is read only from the private notes (T2)"),
)


def named_elsewhere(path, name):
    return any(path == f and re.fullmatch(rx, name) for f, rx, _ in NAMED_ELSEWHERE)


def md_names(text):
    """Every Markdown file name or path written in text (a link target, a path, or a name alone)."""
    return [m.group(1) for m in MD_NAME.finditer(text or "")]


def unknown_md(name, fileset, basenames, here):
    """True when name (a path or a file name alone) is not a file of this tree; here is the folder of the file it is written in."""
    if "/" not in name:
        return name not in basenames
    rel = os.path.normpath(os.path.join(os.path.dirname(here), name)).replace(os.sep, "/")
    return name not in fileset and rel not in fileset


def joined_paths(path):
    """(line, "a/b/c") for every os.path.join(...) call in a Python file whose arguments start with string literals: the path it builds
    from them (a working doc reached as os.path.join("docs", "plans", ...) is a path like any other)."""
    try:
        tree = ast.parse(read(path) or "", filename=path)
    except SyntaxError:
        return []
    out = []
    for n in ast.walk(tree):
        if isinstance(n, ast.Call) and isinstance(n.func, ast.Attribute) and n.func.attr == "join":
            parts = []
            for a in n.args:
                if isinstance(a, ast.Constant) and isinstance(a.value, str):
                    parts.append(a.value)
                elif parts:
                    break
            if len(parts) >= 2:
                out.append((n.lineno, "/".join(parts)))
    return out


# Reads of a working doc that come from Xaya's private notes checkout (XUI_DOCS_ROOT), never from this repo: (file, string, why).
ALLOWED_PRIVATE = (
    ("tests/fix_r9_docs_run.py", "docs/plans/R9-INFO-PANE-TOOL-PATCH-2026-11-16.md",
     "I4 reads the recorded info-pane tool patch from the private notes (XUI_DOCS_ROOT) to rebuild InfoPaneData.lua"),
)


def check(name, ok, extra=""):
    results.append((name + ("" if ok else "  [%s]" % (str(extra)[:400],)), bool(ok)))


def is_work(p):
    return p not in KEEP and (p.startswith(WORK_PREFIXES) or p in WORK_FILES)


def tracked():
    """The repo's tracked files that are on disk (V7: tests read only git ls-files). None when git cannot answer."""
    try:
        r = subprocess.run(["git", "-C", ROOT, "ls-files", "-z"], capture_output=True, timeout=60)
    except Exception as e:  # git missing or hung: say so, the run fails (it needs the file list)
        print("error: git ls-files could not run here (%s)" % e)
        return None
    if r.returncode != 0:
        print("error: git ls-files failed: %s" % r.stderr.decode("utf-8", "replace")[:200])
        return None
    return [p for p in r.stdout.decode("utf-8", "replace").split("\0") if p and os.path.exists(os.path.join(ROOT, p))]


def read(rel):
    p = os.path.join(ROOT, rel)
    if not os.path.isfile(p):
        return None
    with open(p, encoding="utf-8", errors="replace") as f:
        return f.read()


def code_strings(path):
    """(line, text) of every string literal in a Python file that is not a docstring or a bare string statement."""
    try:
        tree = ast.parse(read(path) or "", filename=path)
    except SyntaxError as e:
        return [(e.lineno or 0, "<syntax error: %s>" % e.msg)]
    doc = {id(n.value) for n in ast.walk(tree)
           if isinstance(n, ast.Expr) and isinstance(n.value, ast.Constant) and isinstance(n.value.value, str)}
    return [(n.lineno, n.value) for n in ast.walk(tree)
            if isinstance(n, ast.Constant) and isinstance(n.value, str) and id(n) not in doc]


def main():
    files = tracked()
    check("W0 git ls-files lists the tree", bool(files), "git ls-files gave nothing")
    files = files or []
    fileset = set(files)

    # W: no working doc and no saved game data in the tree
    work = sorted(p for p in files if is_work(p))
    check("W1 no working doc is in the tree (SD-140; %d found)" % len(work), not work, work[:12])
    saved = [p for p in files if re.search(r"(^|/)WTF/|SavedVariables", p)]
    check("W2 no saved game data (WTF/ or SavedVariables) is tracked", not saved, saved[:5])

    # K: kept docs are here and point at nothing missing
    missing = [p for p in KEPT_DOCS if p not in fileset]
    check("K1 every kept player guide and build rule is still in the tree", not missing, missing)
    # (CLAUDE.md names the private repo's own paths on purpose; C1 to C3 check it)
    kept_md = sorted(set(p for p in files if p.endswith(".md") and not is_work(p) and p != "CLAUDE.md"
                         and not p.startswith(("docs/reference/api/", "docs/reference/spells/"))))
    pointers, broken = [], []
    for p in kept_md:
        text = read(p) or ""
        for ln, line in enumerate(text.splitlines(), 1):
            for m in POINTER.finditer(line):
                pointers.append("%s:%d %s" % (p, ln, m.group(0)))
            for m in re.finditer(r"\]\(([^)\s#]+)(?:#[^)]*)?\)", line):
                target = m.group(1)
                if re.match(r"[a-z]+:", target):  # http:, https:, mailto: are not files here
                    continue
                rel = os.path.normpath(os.path.join(os.path.dirname(p), target)).replace(os.sep, "/")
                if rel not in fileset and not os.path.isdir(os.path.join(ROOT, rel)):
                    broken.append("%s:%d -> %s" % (p, ln, target))
    check("K2 no kept doc (%d) names a working doc's path or file (SD-140)" % len(kept_md), kept_md and not pointers, pointers[:10])
    basenames = {os.path.basename(p) for p in fileset}
    unknown = []
    for p in kept_md:
        for ln, line in enumerate((read(p) or "").splitlines(), 1):
            unknown += ["%s:%d %s" % (p, ln, x) for x in md_names(line)
                        if unknown_md(x, fileset, basenames, p) and not named_elsewhere(p, x)]
    check("K2 every Markdown file a kept doc names, by path or by its name alone, is a file of this tree (no working doc named by its"
          " file name)", kept_md and not unknown, unknown[:10])
    check("K3 every relative markdown link in a kept doc opens a file in the tree", kept_md and not broken, broken[:10])
    ipd = read("XayaUI_Options/InfoPaneData.lua")
    pane = [m.group(0) for m in POINTER.finditer(ipd or "")]
    check("K4 the in-game info pane text (InfoPaneData.lua) points at no working doc", ipd is not None and not pane,
          pane[:5] if ipd is not None else "InfoPaneData.lua missing")

    # T: no test or tool reads a working doc from this repo
    readers = []
    allowed = {(f, s) for f, s, _ in ALLOWED_PRIVATE}
    scanned = 0
    for p in files:
        if not p.endswith(".py") or not p.startswith(("tests/", "tools/")) or p == SELF:
            continue
        scanned += 1
        for ln, s in code_strings(p):
            if len(s) < 300 and POINTER.search(s) and (p, s) not in allowed:
                readers.append("%s:%d %r" % (p, ln, s[:80]))
            elif len(s) < 300 and (p, s) not in allowed:
                readers += ["%s:%d %r (not a file of this tree)" % (p, ln, x) for x in md_names(s)
                            if unknown_md(x, fileset, basenames, p) and not named_elsewhere(p, x)]
        for ln, built in joined_paths(p):
            if POINTER.search(built) or any(unknown_md(x, fileset, basenames, p) and not named_elsewhere(p, x) for x in md_names(built)):
                readers.append("%s:%d os.path.join -> %r" % (p, ln, built[:80]))
    check("T1 no test or tool code (%d files) names a working doc to read from this repo" % scanned, scanned and not readers,
          readers[:10])
    for f, s, why in ALLOWED_PRIVATE:
        src = read(f) or ""
        check("T2 %s reads %s only from the private notes checkout (%s)" % (f, s, why),
              s in src and "XUI_DOCS_ROOT" in src and ("os.path.join(DOCS_ROOT, %r)" % s) in src)

    # C: the repo-root CLAUDE.md
    cm = read("CLAUDE.md")
    lines = (cm or "").rstrip("\n").splitlines()
    check("C1 CLAUDE.md is in the tree and under 25 lines (%d)" % len(lines), "CLAUDE.md" in fileset and 0 < len(lines) < 25, len(lines))
    low = (cm or "").lower()
    need = {
        "the repo is public": "public" in low,
        "private repo heyitsxaya/XUI-Docs": "heyitsxaya/XUI-Docs" in (cm or "") and "private" in low,
        "docs/process/VERIFICATION.md": "docs/process/VERIFICATION.md" in (cm or ""),
        "docs/process/REQUEST-LOG.md": "docs/process/REQUEST-LOG.md" in (cm or ""),
        "read them before any work": "before any work" in low,
        "Xaya / she / her": all(re.search(r"\b%s\b" % w, cm or "") for w in ("Xaya", "she", "her")),
        "never working docs here": "never" in low and all(w in low for w in ("logs", "plans", "handoffs")),
        "never her SavedVariables": "savedvariables" in low,
        "player guides, build rules and game data stay": all(w in low for w in ("player guides", "build rules", "game data")),
    }
    lacking = [k for k, ok in need.items() if not ok]
    check("C2 CLAUDE.md says what a session must know (%d points)" % len(need), cm and not lacking, lacking)
    local = [m.group(0) for m in POINTER.finditer(cm or "") if not m.group(0).startswith(("docs/process/", "VERIFICATION", "REQUEST-LOG"))]
    check("C3 CLAUDE.md names no other working-doc path", not local, local)

    bad_n = 0
    for name, ok in results:
        print(("PASS " if ok else "FAIL ") + name)
        bad_n += 0 if ok else 1
    print("%d checks, %d failed" % (len(results), bad_n))
    return 1 if bad_n or not results else 0


if __name__ == "__main__":
    sys.exit(main())
