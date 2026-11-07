"""Every XayaUI* addon's .toc loads exactly the Lua / XML files its folder ships (hub request, 2026-11-07 ~12:45 UTC: a merge that
night dropped XayaUI_Chat/Whispers.lua from the Chat .toc and the suite did not notice, because the whisper test loads the file directly).

For each folder named XayaUI* with a .toc: the files the game reads are the .toc's file lines plus, recursively, every
<Script file="..."/> and <Include file="..."/> in the XML files it reads (paths relative to that XML file). Checks:
  - every .lua / .xml file in the folder (Libs/ included) is read by the game, unless listed in EXCEPTIONS below with its reason;
  - every file the .toc or an XML names exists (exact case: the game's file names are case-sensitive on some systems);
  - no file is read twice.
Generalises the Dev Assist-only check in tests/devassist_rename_run.py (section 4) to every addon.
Run: python3 tests/toc_files_run.py            (or: python3 tests/toc_files_run.py <repo root> to check another checkout)"""
import os, re, sys

ROOT = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
# folder -> {path relative to the folder: reason}. Files shipped on purpose but not loaded by the game.
_LIBSTUB_TESTS = "the LibStub library's own self-tests, shipped with its copy and never loaded by the game"
EXCEPTIONS = {
    "XayaUI": {"Libs/LibStub/tests/test.lua": _LIBSTUB_TESTS, "Libs/LibStub/tests/test2.lua": _LIBSTUB_TESTS,
               "Libs/LibStub/tests/test3.lua": _LIBSTUB_TESTS, "Libs/LibStub/tests/test4.lua": _LIBSTUB_TESTS},
}

fails = []
def check(name, ok, extra=""):
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  [" + str(extra) + "]"))
    if not ok: fails.append(name)

def norm(p): return p.strip().replace("\\", "/")

XML_REF = re.compile(r'<(?:Script|Include)\s+[^>]*?file\s*=\s*"([^"]+)"', re.I)
XML_COMMENT = re.compile(r"<!--.*?-->", re.S)

def exists_exact(folder, rel):
    """True when rel exists under folder with exactly this case."""
    cur = folder
    for part in rel.split("/"):
        if part in ("", "."): continue
        if not os.path.isdir(cur) or part not in os.listdir(cur): return False
        cur = os.path.join(cur, part)
    return os.path.isfile(cur)

folders = sorted(d for d in os.listdir(ROOT) if d.startswith("XayaUI") and os.path.isdir(os.path.join(ROOT, d)))
checked = 0
for name in folders:
    folder = os.path.join(ROOT, name)
    tocs = [f for f in os.listdir(folder) if f.endswith(".toc")]
    if not tocs: continue
    checked += 1
    toc = os.path.join(folder, name + ".toc") if (name + ".toc") in tocs else os.path.join(folder, tocs[0])
    lines = open(toc, encoding="utf-8-sig").read().splitlines()
    listed = [norm(l) for l in lines if l.strip() and not l.strip().startswith("#")]
    read, missing, twice = [], [], []
    def visit(rel, via):
        rel = os.path.normpath(rel).replace(os.sep, "/")
        if rel in read: twice.append(rel); return
        if not exists_exact(folder, rel): missing.append("%s (named in %s)" % (rel, via)); return
        read.append(rel)
        if rel.lower().endswith(".xml"):
            text = XML_COMMENT.sub("", open(os.path.join(folder, rel), encoding="utf-8-sig", errors="replace").read())
            base = os.path.dirname(rel)
            for ref in XML_REF.findall(text):
                visit(os.path.join(base, norm(ref)) if base else norm(ref), rel)
    for rel in listed: visit(rel, os.path.basename(toc))
    shipped = []
    for root, _, files in os.walk(folder):
        for f in files:
            if f.lower().endswith((".lua", ".xml")):
                shipped.append(os.path.relpath(os.path.join(root, f), folder).replace(os.sep, "/"))
    exc = EXCEPTIONS.get(name, {})
    unread = sorted(f for f in shipped if f not in read and f not in exc)
    check("%s: every shipped .lua / .xml is loaded by the .toc (%d loaded, %d shipped)" % (name, len(read), len(shipped)), not unread, unread)
    check("%s: every file the .toc / its XML names exists, exact case" % name, not missing, missing)
    check("%s: no file loaded twice" % name, not twice, twice)
    stale = sorted(f for f in exc if f in read or f not in shipped)
    check("%s: every exception is still needed (shipped and not loaded)" % name, not stale, stale)

check("checked every XayaUI* addon with a .toc (%d)" % checked, checked >= 1)
print("%d checks, %d failed" % (checked * 4 + 1, len(fails)))
sys.exit(1 if fails else 0)
