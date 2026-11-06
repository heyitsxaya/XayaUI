#!/usr/bin/env python3
"""Pre-commit / pre-push checks for the XayaUI repository (docs/process/VERIFICATION.md, rule V10).

Usage:
  python3 tools/precheck.py                 # before committing: compares the working tree with HEAD
  python3 tools/precheck.py --base origin/main   # before pushing to main: every addon changed since main must have a new version

Errors make the exit code 1. Warnings are printed but do not fail. Each check exists because a slip got past without it
(docs/process/RETROSPECTIVE.md, rows S3-S8 and #333).
"""
import argparse, datetime, hashlib, os, re, subprocess, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
PASS_MARKERS = ("0 failed", "PASS", "passed", "FAILS: 0")   # what tests/run_all.py accepts on a test's last line


def git(*args):
    return subprocess.run(["git"] + list(args), cwd=ROOT, capture_output=True, text=True).stdout


# ---------------------------------------------------------------------------------------------------------------------------
# Individual checks. Each returns (errors, warnings) as lists of strings, and takes plain inputs so tests can drive it.
# ---------------------------------------------------------------------------------------------------------------------------
LOG_NAME = re.compile(r"^(\d{4})-(\d{2})-(\d{2})-(\d{2})(\d{2})-")
LOGGED = re.compile(r"(?:Logged|Last updated) (\d{4})-(\d{2})-(\d{2}) ~?(\d{2}):(\d{2}) UTC")


def check_log_times(entries, now, slack_min=10):
    """entries: list of (file name, text). A time more than slack_min minutes in the future is an error (S3)."""
    errs = []
    limit = now + datetime.timedelta(minutes=slack_min)

    def when(m):
        try:
            return datetime.datetime(*map(int, m.groups()))
        except ValueError:
            return None

    for name, text in entries:
        m = LOG_NAME.match(name)
        if m:
            t = when(m)
            if t is None:
                errs.append("debug-log/%s: the file name holds an impossible date or time (24:00 is 00:00 of the next day)" % name)
            elif t > limit:
                errs.append("debug-log/%s: the time in the file name (%s UTC) is in the future" % (name, t.strftime("%Y-%m-%d %H:%M")))
        m = LOGGED.search(text or "")
        if m:
            t = when(m)
            if t is None:
                errs.append("debug-log/%s: 'Logged' holds an impossible date or time" % name)
            elif t > limit:
                errs.append("%s: the logged / updated time %s UTC is in the future" % (name, t.strftime("%Y-%m-%d %H:%M")))
    return errs, []


def check_manifest(tracked, manifest_text, read):
    """tracked: tracked file paths; read(path) -> bytes or None. MANIFEST.md5 must list exactly the tracked files with their md5 (S5)."""
    errs = []
    want = {}
    for p in tracked:
        if p == "MANIFEST.md5":
            continue
        data = read(p)
        if data is not None:
            want[p] = hashlib.md5(data).hexdigest()
    have = {}
    for line in (manifest_text or "").splitlines():
        if "  " in line:
            h, p = line.split("  ", 1)
            have[p] = h
    missing = sorted(set(want) - set(have))
    extra = sorted(set(have) - set(want))
    wrong = sorted(p for p in want if p in have and have[p] != want[p])
    if missing:
        errs.append("MANIFEST.md5 lacks %d tracked file(s), e.g. %s (run tools/manifest.py AFTER git add)" % (len(missing), missing[0]))
    if extra:
        errs.append("MANIFEST.md5 lists %d file(s) git does not track, e.g. %s" % (len(extra), extra[0]))
    if wrong:
        errs.append("MANIFEST.md5 has a stale checksum for %d file(s), e.g. %s (run tools/manifest.py)" % (len(wrong), wrong[0]))
    return errs, []


def check_untracked(porcelain_lines):
    """Untracked files in an addon folder or at the repo root are errors (S4); elsewhere warnings."""
    errs, warns = [], []
    for line in porcelain_lines:
        if not line.startswith("?? "):
            continue
        p = line[3:].strip().strip('"')
        top = p.split("/", 1)[0]
        if "/" not in p.rstrip("/") or top.startswith("XayaUI"):
            errs.append("untracked file %s (add it, or remove it before committing)" % p)
        else:
            warns.append("untracked file %s" % p)
    return errs, warns


TOC_VERSION = re.compile(r"^## Version:\s*(\S+)", re.M)


def check_versions(changed_paths, toc_now, toc_base):
    """changed_paths: paths changed since the base. toc_now / toc_base: {addon folder: version or None}.
    An addon with a changed .lua / .xml / .toc file must have a different version than at the base."""
    errs = []
    folders = sorted({p.split("/", 1)[0] for p in changed_paths
                      if p.split("/", 1)[0].startswith("XayaUI") and p.endswith((".lua", ".xml", ".toc"))})
    for f in folders:
        now, base = toc_now.get(f), toc_base.get(f)
        if base is not None and now == base:
            errs.append("%s changed but its .toc version is still %s" % (f, now))
    return errs, []


QA_ID = re.compile(r"\*\*([A-Z][0-9]+[a-z]?)\.\*\*")
QA_PATH = "docs/QA-CHECKLIST.md"   # (moved from the repository root on 2026-11-06, REQUEST-LOG #81 / FUS-6)


def check_qa_ids(text):
    if text is None:   # (a moved or renamed checklist must not pass unchecked)
        return ["%s not found: the QA step IDs could not be checked" % QA_PATH], []
    seen, errs = {}, []
    for m in QA_ID.finditer(text or ""):
        seen[m.group(1)] = seen.get(m.group(1), 0) + 1
    for k, n in sorted(seen.items()):
        if n > 1:
            errs.append("%s: step %s is used %d times (step IDs must be unique)" % (QA_PATH, k, n))
    return errs, []


# The documents moved from the repository root into docs/ (Xaya 2026-11-06, FUS-6: "All but README, THIRD_PARTY"). A reference to one of
# them by its old root path (the name with no "docs/" in front) points at a file that is no longer there. debug-log/ is history and the
# verbatim session request logs quote Xaya's own words: both are left as written.
MOVED_DOCS = ("WHATS-NEW.md", "USER-GUIDE.md", "QA-CHECKLIST.md", "ROADMAP.md", "SESSION-START-SUMMARY.md")
OLD_DOC_PATH = re.compile(r"(?<![\w/.-])(" + "|".join(re.escape(n) for n in MOVED_DOCS) + r")")
# (the checker and its own test hold the old names on purpose)
DOC_PATH_SKIP = re.compile(r"^(debug-log/|docs/process/REQUEST-LOG-session-|MANIFEST\.md5$|tools/precheck\.py$|tests/precheck_run\.py$)")
TEXT_EXT = (".md", ".lua", ".py", ".toc", ".txt", ".sh", ".json", ".xml", ".yml", ".yaml")


def check_doc_paths(files):
    """files: list of (path, text). Every mention of a moved document must name it by its path under docs/ (docs/USER-GUIDE.md)."""
    errs = []
    for path, text in files:
        if DOC_PATH_SKIP.match(path) or not path.endswith(TEXT_EXT) or text is None:
            continue
        for i, line in enumerate(text.splitlines(), 1):
            for m in OLD_DOC_PATH.finditer(line):
                errs.append("%s:%d names %s by its old root path; it is docs/%s now" % (path, i, m.group(1), m.group(1)))
    for n in MOVED_DOCS:
        if not any(p == "docs/" + n for p, _ in files):
            errs.append("docs/%s is not in the repository" % n)
    return errs, []


def check_test_markers(tests):
    """tests: list of (file name, source). A test whose source prints none of run_all.py's pass markers is listed as FAIL
    even when it passes (S8)."""
    errs = []
    words = ("failed", "PASS", "passed", "FAILS:")   # markers are often built from a template ("%d failed"), so look for the words
    for name, src in tests:
        if not any(w in src for w in words):
            errs.append("tests/%s prints none of the pass markers run_all.py looks for (%s)" % (name, ", ".join(PASS_MARKERS)))
    return errs, []


MEDIA_PATH = re.compile(r'"(Interface\\\\AddOns\\\\[^"]+\.(?:tga|blp|png|ogg|mp3))"', re.I)


def check_media_lists(lists, tracked_lower):
    """lists: list of (file name, source). Paths into our own folders that the repository does not hold only work on the
    author's machine (#333, #144). Reported as a warning until those issues are fixed."""
    warns = []
    for name, src in lists:
        paths = MEDIA_PATH.findall(src)
        own = [p for p in paths if p.lower().replace("\\\\", "/").split("/")[2].startswith("xayaui")]
        missing = [p for p in own if p.replace("\\\\", "/").split("/", 2)[2].lower() not in tracked_lower]
        if missing:
            warns.append("%s lists %d file(s) that are not in the repository (e.g. %s); open issue #333 / #290"
                         % (name, len(missing), missing[0].replace("\\\\", "\\")))
    return [], warns


# ---------------------------------------------------------------------------------------------------------------------------
def toc_versions(reader):
    out = {}
    for d in sorted(os.listdir(ROOT)):
        if d.startswith("XayaUI") and os.path.isdir(os.path.join(ROOT, d)):
            src = reader(d + "/" + d + ".toc")
            m = TOC_VERSION.search(src or "")
            out[d] = m.group(1) if m else None
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default="HEAD", help="ref to compare against for the version check (default HEAD)")
    a = ap.parse_args()
    now = datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)

    def read_bytes(p):
        fp = os.path.join(ROOT, p)
        return open(fp, "rb").read() if os.path.isfile(fp) else None

    def read_text(p):
        b = read_bytes(p)
        return b.decode("utf-8", "replace") if b is not None else None

    tracked = git("ls-files").splitlines()
    results = []
    logs = [(n, read_text("debug-log/" + n)) for n in sorted(os.listdir(os.path.join(ROOT, "debug-log"))) if n.endswith(".md")]
    logs.append(("docs/SESSION-START-SUMMARY.md", read_text("docs/SESSION-START-SUMMARY.md")))
    results.append(("debug-log times", check_log_times(logs, now)))
    results.append(("manifest", check_manifest(tracked, read_text("MANIFEST.md5"), read_bytes)))
    results.append(("untracked files", check_untracked(git("status", "--porcelain", "--untracked-files=all").splitlines())))
    changed = set(git("diff", "--name-only", a.base).splitlines()) | set(git("diff", "--name-only", "--cached", a.base).splitlines())

    def base_reader(p):
        r = subprocess.run(["git", "show", "%s:%s" % (a.base, p)], cwd=ROOT, capture_output=True, text=True)
        return r.stdout if r.returncode == 0 else None

    results.append(("versions", check_versions(changed, toc_versions(read_text), toc_versions(base_reader))))
    results.append(("QA step IDs", check_qa_ids(read_text(QA_PATH))))
    results.append(("moved documents", check_doc_paths([(p, read_text(p)) for p in tracked])))
    tests = []
    for n in sorted(os.listdir(os.path.join(ROOT, "tests"))):
        if not n.endswith("_run.py"):
            continue
        src = read_text("tests/" + n) or ""
        # a test may print its result line from a Lua or Python file it runs (usage_run.py runs usage_check.lua)
        for ref in set(re.findall(r"['\"]([\w-]+\.(?:lua|py))['\"]", src)):
            extra = read_text("tests/" + ref)
            if extra and ref != n:
                src += "\n" + extra
        tests.append((n, src))
    results.append(("test pass markers", check_test_markers(tests)))
    media = [(p, read_text(p)) for p in tracked if re.search(r"(LocalGraphics|LocalSounds)\.lua$", p)]
    results.append(("media lists", check_media_lists(media, {t.lower() for t in tracked})))

    n_err = n_warn = 0
    for title, (errs, warns) in results:
        for e in errs:
            print("ERROR  [%s] %s" % (title, e))
        for w in warns:
            print("warn   [%s] %s" % (title, w))
        n_err += len(errs)
        n_warn += len(warns)
    print("precheck: %d check groups, %d warnings  FAILS: %d" % (len(results), n_warn, n_err))
    return 1 if n_err else 0


if __name__ == "__main__":
    sys.exit(main())
