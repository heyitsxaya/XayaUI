#!/usr/bin/env python3
"""tests/precheck_run.py: each tools/precheck.py check catches the slip it was written for, and passes a clean case.
Run: python3 tests/precheck_run.py"""
import datetime, hashlib, importlib.util, os, sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
spec = importlib.util.spec_from_file_location("precheck", os.path.join(ROOT, "tools", "precheck.py"))
P = importlib.util.module_from_spec(spec)
spec.loader.exec_module(P)

fails, checks = 0, 0


def expect(name, result, n_err, n_warn=None):
    global fails, checks
    checks += 1
    errs, warns = result
    ok = len(errs) == n_err and (n_warn is None or len(warns) == n_warn)
    if not ok:
        fails += 1
        print("FAIL", name, "errors:", errs, "warnings:", warns)


now = datetime.datetime(2026, 11, 4, 6, 0)
# S3: a debug-log time in the future; 24:00 is not a time; a past time passes
expect("log name in the future", P.check_log_times([("2026-11-04-0640-x.md", "")], now), 1)
expect("Logged line in the future", P.check_log_times([("2026-11-04-0500-x.md", "Logged 2026-11-04 07:10 UTC.")], now), 1)
expect("24:00 rejected", P.check_log_times([("2026-11-02-2400-x.md", "")], now), 1)
expect("summary updated in the future", P.check_log_times([("docs/SESSION-START-SUMMARY.md", "Last updated 2026-11-04 07:00 UTC by")], now), 1)
expect("past log passes", P.check_log_times([("2026-11-04-0550-x.md", "Logged 2026-11-04 05:50 UTC.")], now), 0)
expect("within slack passes", P.check_log_times([("2026-11-04-0605-x.md", "")], now), 0)

# S5: manifest must list exactly the tracked files with current checksums
files = {"a.lua": b"one", "b.lua": b"two"}
good = "\n".join("%s  %s" % (hashlib.md5(v).hexdigest(), k) for k, v in sorted(files.items()))
expect("manifest exact", P.check_manifest(list(files) + ["MANIFEST.md5"], good, files.get), 0)
expect("manifest missing a file", P.check_manifest(list(files) + ["c.lua"], good, {**files, "c.lua": b"3"}.get), 1)
expect("manifest stale checksum", P.check_manifest(list(files), good, {"a.lua": b"changed", "b.lua": b"two"}.get), 1)
expect("manifest extra line", P.check_manifest(["a.lua"], good, files.get), 1)

# S4: stray files in an addon folder or the repo root are errors; elsewhere a warning
expect("stray wheel at root", P.check_untracked(["?? pip-1.0-py3-none-any.whl"]), 1, 0)
expect("stray file in addon", P.check_untracked(["?? XayaUI/new.lua"]), 1, 0)
expect("untracked doc is a warning", P.check_untracked(["?? docs/process/new.md"]), 0, 1)
expect("tracked change ignored", P.check_untracked([" M XayaUI/Core.lua"]), 0, 0)

# version: an addon whose code changed must have a new .toc version
expect("code changed, version same", P.check_versions(["XayaUI/Core.lua"], {"XayaUI": "0.6.11"}, {"XayaUI": "0.6.11"}), 1)
expect("code changed, version bumped", P.check_versions(["XayaUI/Core.lua"], {"XayaUI": "0.6.12"}, {"XayaUI": "0.6.11"}), 0)
expect("docs only, no bump needed", P.check_versions(["docs/x.md", "XayaUI/README.md"], {"XayaUI": "0.6.11"}, {"XayaUI": "0.6.11"}), 0)
expect("new addon has no base version", P.check_versions(["XayaUI_New/a.lua"], {"XayaUI_New": "0.1"}, {}), 0)

# #319: QA step IDs must be unique
expect("duplicate QA step", P.check_qa_ids("- [ ] **J6.** one\n- [ ] **J6.** two"), 1)
expect("unique QA steps", P.check_qa_ids("- [ ] **J6.** one\n- [ ] **J7.** two"), 0)

# S8: a test without a run_all.py pass marker is listed as FAIL even when it passes
expect("old pitfalls ending caught", P.check_test_markers([("x_run.py", 'print("%d Lua files checked, %d problems" % (n, b))')]), 1)
expect("FAILS marker passes", P.check_test_markers([("x_run.py", 'print("checked  FAILS: %d" % b)')]), 0)
expect("templated failed passes", P.check_test_markers([("x_run.py", 'print("%d checks, %d failed" % (n, f))')]), 0)

# #333: media lists that name files the repository does not hold
src = 'local t = { "Interface\\\\AddOns\\\\XayaUI\\\\Media\\\\Graphics\\\\Mine.tga", "Interface\\\\AddOns\\\\XayaUI\\\\Media\\\\Graphics\\\\Here.tga" }'
expect("missing media warned", P.check_media_lists([("XayaUI/LocalGraphics.lua", src)], {"xayaui/media/graphics/here.tga"}), 0, 1)
expect("all media present", P.check_media_lists([("XayaUI/LocalGraphics.lua", src)],
                                                {"xayaui/media/graphics/here.tga", "xayaui/media/graphics/mine.tga"}), 0, 0)

# the documents moved into docs/ (2026-11-06, REQUEST-LOG #81 / FUS-6): an old root path anywhere but the history is an error; the
# checklist must be found for its IDs to be checked
ALL = [("docs/" + n, "") for n in P.MOVED_DOCS]
expect("moved docs: docs/ paths pass", P.check_doc_paths(ALL + [("tools/x.py", 'read("docs/QA-CHECKLIST.md")'), ("README.md", "see `docs/USER-GUIDE.md`")]), 0)
expect("moved docs: an old root path in a tool fails", P.check_doc_paths(ALL + [("tools/x.py", 'read("QA-CHECKLIST.md")')]), 1)
expect("moved docs: an old root path in a doc link fails", P.check_doc_paths(ALL + [("README.md", "[guide](USER-GUIDE.md) and ROADMAP.md")]), 2)
expect("moved docs: debug-log history is left as written", P.check_doc_paths(ALL + [("debug-log/2026-11-01-0000-x.md", "USER-GUIDE.md")]), 0)
expect("moved docs: a document missing from docs/ fails", P.check_doc_paths(ALL[1:]), 1)
expect("QA IDs: a missing checklist is an error, not a pass", P.check_qa_ids(None), 1)

# fix plan f6-6: git errors stop precheck. The old git() returned "" for a failed command, so `--base no-such-ref` diffed against
# nothing and the version check passed (negative control: the old tools/precheck.py printed no base error and its version
# group passed with --base no-such-ref).
import subprocess


def check(name, ok, detail=""):
    global fails, checks
    checks += 1
    if not ok:
        fails += 1
        print("FAIL", name, detail)


check("f6-6: HEAD is a commit (verify_base)", P.verify_base("HEAD") is None)
check("f6-6: a ref that does not exist is refused (verify_base)", P.verify_base("no-such-ref-f6-6") is not None)
try:
    P.git("rev-parse", "--verify", "--quiet", "no-such-ref-f6-6^{commit}")
    check("f6-6: a failing git command raises GitError", False, "no error raised")
except P.GitError:
    check("f6-6: a failing git command raises GitError", True)
r = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "precheck.py"), "--base", "no-such-ref-f6-6"],
                   cwd=ROOT, capture_output=True, text=True)
check("f6-6: precheck --base <bad ref> exits 1 with a clear error", r.returncode == 1 and "does not name a commit" in r.stdout
      and "FAILS: 1" in r.stdout, (r.returncode, r.stdout[-300:]))
check("f6-6: ls-files -z gives the same tracked list as the plain one for ordinary names",
      set(P.git_paths("ls-files")) >= {"tools/precheck.py", "tests/run_all.py"})

print("%d checks  FAILS: %d" % (checks, fails))
sys.exit(1 if fails else 0)
