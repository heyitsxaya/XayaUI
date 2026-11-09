#!/usr/bin/env python3
"""Whole-addon harness for XayaUI (Lua 5.1, like the game).

Loads every addon folder of the repository the way the game does, in every combination of the optional addons switched on or
off, plays one session per combination (tests/harness/scenario.lua), logs out, then plays a second session on what the first one
saved, and reports:
  FAIL  Lua errors (with the step they happened in), widget methods or events the game does not have, files that do not load,
        saved variables the game could not save, settings that change on every reload.
  WARN  errors from events fired WITHOUT their payload (the game always sends one), global names nothing defines (review list),
        tables saved twice.
Exit code 0 only when there is no FAIL.

Usage:
  python3 tests/harness/run.py                    every combination, fresh install
  python3 tests/harness/run.py --saved PATH       also with a real SavedVariables file (e.g. Xaya's WTF\\...\\XayaUI.lua; never committed)
  python3 tests/harness/run.py --only XayaUI_Chat  one combination: core plus the named addons
  XUI_API_INDEX=path/api_index.json               documented API (build it with build_api_index.py); without it, widget methods and
                                                  events are not checked and the run says so
"""
import argparse, itertools, json, os, re, sys, time
import lupa.lua51 as lua51

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
CORE = "XayaUI"
# (P4) XayaUI Rules (rule and aura tracking) is a module a player switches on and off like the others: every combination is run with it
# on and with it off (the Platform and every other module must load and work without it)
FEATURES = ["XayaUI_Rules", "XayaUI_Chat", "XayaUI_QoL", "XayaUI_Bonus", "XayaUI_Reskin", "XayaUI_Options"]
# (P4b) XayaUI_Rules_Options (the rule editor) is load-on-demand like XayaUI_Options and needs XayaUI Rules and XayaUI Options: it is
# switched on in every combination, so it is loaded (when the window opens) exactly where both are on, and nothing of it anywhere else;
# one more combination below has everything but it (a player who did not copy the folder)
ALWAYS = ["XayaUI_Media", "XayaUI_Rules_Options"]


def find_addons():
    """Addon folders: <root>/<Name>/<Name>.toc (one folder per addon); falls back to the old layout (repo root = XayaUI)."""
    found = {}
    for name in sorted(os.listdir(ROOT)):
        d = os.path.join(ROOT, name)
        if os.path.isdir(d) and os.path.isfile(os.path.join(d, name + ".toc")) and name.startswith("XayaUI"):
            found[name] = d
    if CORE not in found and os.path.isfile(os.path.join(ROOT, CORE + ".toc")):
        found[CORE] = ROOT
    return found


def to_lua(L, v):
    if isinstance(v, dict):
        t = L.table()
        for k, x in v.items():
            t[k] = to_lua(L, x)
        return t
    if isinstance(v, list):
        t = L.table()
        for i, x in enumerate(v, 1):
            t[i] = to_lua(L, x)
        return t
    return v


def lua_to_py(v):
    if lupa_type(v) == "table":
        keys = list(v.keys())
        if keys and all(isinstance(k, int) for k in keys) and sorted(keys) == list(range(1, len(keys) + 1)):
            return [lua_to_py(v[k]) for k in sorted(keys)]
        return {str(k): lua_to_py(v[k]) for k in keys}
    return v


def lupa_type(v):
    return lua51.lua_type(v)


API = None


def load_api():
    global API
    if API is not None:
        return API
    p = os.environ.get("XUI_API_INDEX", os.path.join(HERE, "api_index.json"))
    API = json.load(open(p)) if os.path.isfile(p) else {}
    fx = os.environ.get("XUI_FRAMEXML_INDEX", os.path.join(HERE, "framexml_index.json"))
    if os.path.isfile(fx):
        d = json.load(open(fx))
        API["deprecatedOnly"] = d.get("deprecatedOnly", {})
        API["framexml"] = list(d.get("defined", {}).keys())
    return API


def savedvars(L):
    """tests/harness/savedvars.lua in runtime L: Serialize(value) -> Lua source, Load(source) -> value, LoadFile(file text)."""
    return L.eval("function(p) return dofile(p) end")(os.path.join(HERE, "savedvars.lua"))


def read_saved(path):
    """Run a SavedVariables file in an empty Lua and return its globals as {var: value} (Python data; for reports only: numeric
    keys of non-list tables come back as strings. To start a session from the file use read_saved_source)."""
    L = lua51.LuaRuntime(unpack_returned_tuples=True)
    src = open(path, encoding="utf-8", errors="replace").read()
    env = savedvars(L).LoadFile(src)
    return {str(k): lua_to_py(env[k]) for k in env.keys()}


def read_saved_source(path, addon=CORE):
    """A SavedVariables file as the saved-data source a session starts from ({ [addon] = { VAR = value } } as Lua source), so its
    key types (numbers stay numbers) reach the session as the game would load them (fix plan f6-3)."""
    L = lua51.LuaRuntime(unpack_returned_tuples=True)
    sv = savedvars(L)
    env = sv.LoadFile(open(path, encoding="utf-8", errors="replace").read())
    t = L.table()
    t[addon] = env
    return sv.Serialize(t)


def session(folders, enabled, saved, write_back=True, quick=False):
    """One play session in a new Lua state. saved: what the last session saved, either Lua source from savedvars.lua (the
    harness's own round trip and --saved PATH: key types kept, as the game's SavedVariables files keep them) or a Python dict
    {addon: {VAR: value}} (tests that build saved data by hand)."""
    L = lua51.LuaRuntime(unpack_returned_tuples=True)
    sv = savedvars(L)
    api = to_lua(L, {k: v for k, v in load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(HERE, "world.lua"), api)
    opts = to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}})
    opts["saved"] = sv.Load(saved) if isinstance(saved, str) else to_lua(L, saved or {})
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(os.path.join(HERE, "loader.lua"), world, opts)
    t0 = time.time()
    S = L.eval("function(path, W, Ld, o) return dofile(path)(W, Ld, o) end")(
        os.path.join(HERE, "scenario.lua"), world, loader, to_lua(L, {"writeBack": write_back, "quick": quick}))
    out = {
        "seconds": round(time.time() - t0, 1),
        "errors": [world.errors[i] for i in range(1, len(world.errors) + 1)],
        "badMethods": {k: v for k, v in world.badMethods.items()},
        "unknownGlobals": {k: v for k, v in world.unknownGlobals.items()},
        "problems": [loader.problems[i] for i in range(1, len(loader.problems) + 1)],
        "loaded": [loader.loadedOrder[i] for i in range(1, len(loader.loadedOrder) + 1)],
        "files": loader.files,
        "steps": [(S.steps[i].name, S.steps[i].errors) for i in range(1, len(S.steps) + 1)],
        "noPayload": (S.noPayloadStart, S.noPayloadEnd),
        "unknownMethods": {k: v for k, v in world.unknownMethods.items()},
        "stats": {"commands": S.commands, "launchers": S.launchers, "optionNodes": S.optionNodes, "optionCalls": S.optionCalls,
                  "otherEvents": len(S.otherEvents) if S.otherEvents else 0, "noOptions": bool(S.noOptions)},
        "saved": lua_to_py(S.saved) if S.saved else {},           # Python data, for the drift report only
        "savedSource": sv.Serialize(S.saved) if S.saved else "{}",  # what the next session loads (key types kept; f6-3)
        "saveIssues": [S.saveIssues[i] for i in range(1, len(S.saveIssues) + 1)] if S.saveIssues else [],
        "printed": [world.printed[i] for i in range(1, len(world.printed) + 1)],
    }
    return out


def step_of(errors_index, steps):
    name = "?"
    for s, n in steps:
        if errors_index >= n:
            name = s
    return name


VOLATILE = re.compile(r"(time|Time|stamp|Stamp|date|Date|last|Last|seen|Seen|build|Build|session|Session|at$|t$|^t$|now|Now|history|History|log|Log)")


def diff(a, b, path="", out=None, limit=40):
    """Saved data that differs between two consecutive sessions (ignoring values that are clearly time stamps or logs)."""
    out = [] if out is None else out
    if len(out) >= limit:
        return out
    if isinstance(a, dict) and isinstance(b, dict):
        for k in sorted(set(a) | set(b)):
            if VOLATILE.search(k):
                continue
            if k not in a:
                out.append(path + "." + k + ": added on reload")
            elif k not in b:
                out.append(path + "." + k + ": dropped on reload")
            else:
                diff(a[k], b[k], path + "." + k, out, limit)
    elif isinstance(a, list) and isinstance(b, list):
        if len(a) != len(b):
            out.append("%s: list length %d -> %d on reload" % (path, len(a), len(b)))
        for i, (x, y) in enumerate(zip(a, b)):
            diff(x, y, "%s[%d]" % (path, i + 1), out, limit)
    elif a != b and not (isinstance(a, float) and isinstance(b, float) and abs(a - b) < 1e-6):
        out.append("%s: %r -> %r on reload" % (path, a, b))
    return out


def run_combo(folders, enabled, saved, label):
    s1 = session(folders, enabled, saved)                 # a full play session
    s2 = session(folders, enabled, s1["savedSource"], quick=True)   # then a plain reload on what it saved (as Lua source, f6-3)
    s3 = session(folders, enabled, s2["savedSource"], quick=True)   # and another: s2 -> s3 must not change anything
    fails, warns = [], []
    seen = set()
    for idx, s in ((1, s1), (2, s2), (3, s3)):
        a, b = s["noPayload"]
        for i, e in enumerate(s["errors"]):
            key = e.split("\n")[0]
            if key in seen:
                continue
            seen.add(key)
            where = step_of(i, s["steps"])
            line = "session %d, %s: %s" % (idx, where, e.strip()[:1500])
            (warns if (a or 0) <= i < (b or 0) else fails).append(line)
        for k, tb in s["badMethods"].items():
            fails.append("session %d: the game has no %s\n%s" % (idx, k, str(tb)[:600]))
        for p in s["problems"]:
            fails.append("session %d: %s" % (idx, p))
        for p in s["saveIssues"]:
            (warns if "saved twice" in p else fails).append("session %d: saved variables: %s" % (idx, p))
    dep = load_api().get("deprecatedOnly", {})
    for idx, s in ((1, s1),):
        for k, tb in s["unknownGlobals"].items():
            if k in dep:
                where = [l.strip() for l in str(tb).split("\n") if "AddOns/XayaUI" in l][:2]
                fails.append("session %d: reads %s, which 12.1.5 defines only as a deprecation fallback (%s): %s" % (idx, k, dep[k], " | ".join(where)))
    drift = diff(s2["saved"], s3["saved"])
    for d in drift:
        warns.append("settings drift between sessions: " + d)
    return {"label": label, "enabled": sorted(enabled), "fails": fails, "warns": warns, "s1": s1, "s2": s2, "s3": s3}


def addon_lua_files(folders):
    """Every Lua file each addon loads, from its .toc (and the Script lines of .xml files), skipping bundled libraries."""
    out = {}
    for name, d in folders.items():
        toc = open(os.path.join(d, name + ".toc"), encoding="utf-8").read()
        files = [l.strip().replace("\\", "/") for l in toc.splitlines() if l.strip() and not l.startswith("#")]
        out[name] = [os.path.join(d, f) for f in files if f.endswith(".lua") and not f.startswith("Libs/")]
    return out


def strip_comments(code):
    code = re.sub(r"--\[(=*)\[.*?\]\1\]", "", code, flags=re.S)
    return re.sub(r"--[^\n]*", "", code)


def static_checks(folders):
    """Checks that do not need a session: every name the code mentions that 12.1.5 has only as a deprecation fallback."""
    dep = load_api().get("deprecatedOnly", {})
    out = []
    for name, files in addon_lua_files(folders).items():
        for f in files:
            if not os.path.isfile(f) or os.path.basename(f) == "Compat.lua":   # Compat.lua is the one allowed place (current API first)
                continue
            code = strip_comments(open(f, encoding="utf-8", errors="replace").read())
            for n in dep:
                for m in re.finditer(r'(?:(?<![\w.:])|_G\.|_G\[")' + re.escape(n) + r'(?![\w])', code):
                    out.append("%s:%d uses %s, which 12.1.5 defines only as a deprecation fallback (%s)" % (
                        os.path.relpath(f, ROOT), code.count("\n", 0, m.start()) + 1, n, dep[n]))
    out += boundary_checks(folders)
    # a library carried by several addons must be the same file in each (LibStub runs one copy; a stale copy could win)
    copies = {}
    for name, d in folders.items():
        libs = os.path.join(d, "Libs")
        if not os.path.isdir(libs):
            continue
        for lib in os.listdir(libs):
            for dirpath, _, fl in os.walk(os.path.join(libs, lib)):
                for fn in fl:
                    rel = os.path.relpath(os.path.join(dirpath, fn), d)
                    copies.setdefault(rel, []).append((name, open(os.path.join(dirpath, fn), "rb").read()))
    for rel, lst in copies.items():
        if len(lst) > 1 and len({c for _, c in lst}) > 1:
            out.append("%s differs between %s: the copies of a shared library must be identical" % (rel, ", ".join(n for n, _ in lst)))
    return sorted(set(out))


# names a feature addon publishes on purpose for core to read (Modules.lua): the settings window's API
PUBLISHED = {"Options", "OptionsApi"}


def toc_deps(folders, name):
    """The addons a .toc names under ## Dependencies (or RequiredDeps) and ## OptionalDeps."""
    deps = set()
    toc = open(os.path.join(folders[name], name + ".toc"), encoding="utf-8").read()
    for line in toc.splitlines():
        m = re.match(r"^##\s*(Dependencies|RequiredDeps|Dependancies|OptionalDeps)\s*:\s*(.*)$", line)
        if m:
            deps |= {x for x in re.split(r"[,\s]+", m.group(2)) if x}
    return deps


def boundary_checks(folders):
    """Every addon may use its own names, the Platform's (XayaUI) and those of the addons its .toc names as a dependency or optional
    dependency (P4: XayaUI Options and XayaUI Dev Assist name XayaUI Rules as an optional dependency; the harness runs every
    combination with XayaUI Rules off, so a use that is not guarded fails there); reaching into any other addon's names is a failure
    (they talk through Modules.lua: registrations, messages, services). The Platform may use no other addon's names. A name counts as
    an addon's when one of its files defines it (function ns.X(...) or ns.X = ...)."""
    files = addon_lua_files(folders)
    allowed = {a: toc_deps(folders, a) for a in files}
    owner, code = {}, {}
    for addon, fl in files.items():
        for f in fl:
            if not os.path.isfile(f):
                continue
            c = strip_comments(open(f, encoding="utf-8", errors="replace").read())
            code[(addon, f)] = c
            for m in re.finditer(r"(?m)^\s*(?:function\s+ns\.([A-Za-z_]\w*)\s*\(|ns\.([A-Za-z_]\w*)\s*=[^=])", c):
                owner.setdefault(m.group(1) or m.group(2), set()).add(addon)
    out = []
    for (addon, f), c in code.items():
        for i, line in enumerate(c.split("\n"), 1):
            for m in re.finditer(r"\bns\.([A-Za-z_]\w*)", line):
                n = m.group(1)
                o = owner.get(n)
                if not o or addon in o or CORE in o or n in PUBLISHED or (o & allowed[addon]):
                    continue
                out.append("%s:%d (%s) uses ns.%s, which belongs to %s; go through Modules.lua instead" % (
                    os.path.relpath(f, ROOT), i, addon, n, "/".join(sorted(o))))
    return out


def run_combo_job(job):
    return run_combo(*job)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--saved", help="a SavedVariables file to start from (in addition to a fresh install)")
    ap.add_argument("--only", nargs="*", help="run one combination: core plus these addons")
    ap.add_argument("--fresh-only", action="store_true")
    ap.add_argument("--report", default=os.path.join(HERE, "reports"))
    ap.add_argument("--jobs", type=int, default=max(1, os.cpu_count() or 1))
    args = ap.parse_args()
    folders = find_addons()
    if CORE not in folders:
        print("FAIL: no XayaUI folder found under", ROOT)
        return 1
    # the feature addons a player switches on and off; support folders are always on; tools only in the everything-on run
    features = [n for n in FEATURES if n in folders]
    always = [n for n in ALWAYS if n in folders]
    tools = sorted(n for n in folders if n != CORE and n not in FEATURES and n not in ALWAYS)
    if args.only is not None:
        combos = [tuple(always) + tuple(args.only)]
    else:
        combos = [tuple(always) + c for r in range(len(features) + 1) for c in itertools.combinations(features, r)]
        combos.append(tuple(always) + tuple(features) + tuple(tools))
        # (P4) and everything with XayaUI Rules off: Dev Assist and Nameplates too (Dev Assist names XayaUI Rules as an optional dependency)
        if "XayaUI_Rules" in features:
            combos.append(tuple(always) + tuple(f for f in features if f != "XayaUI_Rules") + tuple(tools))
        if "XayaUI_Rules_Options" in always:
            combos.append(tuple(a for a in always if a != "XayaUI_Rules_Options") + tuple(features) + tuple(tools))
    datasets = [("fresh install", {})]
    if args.saved:
        datasets.append(("saved data " + os.path.basename(args.saved), read_saved_source(args.saved)))
    if args.fresh_only:
        datasets = datasets[:1]
    api = load_api()
    print("addons found:", ", ".join(sorted(folders)), "| combinations:", len(combos), "| data sets:", len(datasets),
          "| API documentation:", ("%d functions, %d events, %d widget method lists" % (len(api.get("functions", {})), len(api.get("events", {})), len(api.get("widgets", {})))) if api else "NOT LOADED (methods and events unchecked)")
    os.makedirs(args.report, exist_ok=True)
    total_fail = 0
    static = static_checks(folders)
    for x in static:
        print("FAIL static:", x)
    total_fail += len(static)
    unknown = {}
    summary = []
    jobs = []
    for dname, saved in datasets:
        for combo in combos:
            enabled = {CORE, *combo}
            label = "%s | %s" % (dname, " + ".join(["XayaUI"] + [c.replace("XayaUI_", "") for c in combo]))
            jobs.append((folders, enabled, saved, label))
    import multiprocessing
    with multiprocessing.Pool(args.jobs) as pool:
        results = pool.imap(run_combo_job, jobs)
        for r in results:
                for s in (r["s1"], r["s2"]):
                    for k, tb in s["unknownGlobals"].items():
                        unknown.setdefault(k, str(tb))
                    for k, tb in s["unknownMethods"].items():
                        unknown.setdefault("method " + k, str(tb))
                st = r["s1"]["stats"]
                status = "FAIL" if r["fails"] else "ok  "
                print("%s %-80s files %3d | cmds %2d | rows %d | options %5d nodes %6d calls | %4.1fs + %4.1fs | %d fail, %d warn" % (
                    status, r["label"][:80], r["s1"]["files"], st["commands"], st["launchers"], st["optionNodes"], st["optionCalls"],
                    r["s1"]["seconds"], r["s2"]["seconds"], len(r["fails"]), len(r["warns"])))
                total_fail += len(r["fails"])
                summary.append(r)
    # unknown globals: names nothing defined that our code read. Filter out names our own files define later in a run.
    with open(os.path.join(args.report, "report.txt"), "w") as f:
        for r in summary:
            if r["fails"] or r["warns"]:
                f.write("=" * 100 + "\n" + r["label"] + "\n")
                for x in r["fails"]:
                    f.write("FAIL " + x + "\n\n")
                for x in r["warns"]:
                    f.write("WARN " + x + "\n\n")
        f.write("=" * 100 + "\nGlobal names read but defined nowhere (review: a typo, an API the documentation lacks, or a deliberate 'is it there?' check)\n")
        fxset = set(load_api().get("framexml", []))
        for k in sorted(unknown):
            first = [l.strip() for l in unknown[k].split("\n") if "AddOns/XayaUI" in l][:2]
            tag = "deprecated-only" if k in load_api().get("deprecatedOnly", {}) else ("Blizzard UI defines it" if k in fxset else "defined nowhere")
            f.write("  %-45s [%s] %s\n" % (k, tag, " | ".join(first)))
    print("unknown global names:", len(unknown), "| report:", os.path.join(args.report, "report.txt"))
    print("RESULT:", "FAIL (%d)" % total_fail if total_fail else "PASS")
    return 1 if total_fail else 0


if __name__ == "__main__":
    sys.exit(main())
