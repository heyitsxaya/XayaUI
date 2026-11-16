#!/usr/bin/env python3
"""Static scan: no timer call makes a new function per call (REQUEST-LOG A23 SD-82, SD-90; bundle 1 round 10).

Her answers (verbatim, REQUEST-LOG A23): SD-82, a new function per timer call off the hot path: "FAIL everywhere (Recommended)";
SD-90, its scope (fix the 7 sites the gate never reaches + a static scan that reports the Options sites / fix all, including about 20
Options sites, the scan FAILs on all / gate only): "Is 1 only recommended due to less lift? If so, do 2". Option 1 was recommended for
less work, not for a correctness reason, so option 2 is built: every site is fixed and this scan FAILs on every one.

What it reads: every Lua file git tracks (V7: tests read only git ls-files; without git, the folders on disk) in the six addons on main,
XayaUI, XayaUI_Rules, XayaUI_Options, XayaUI_Debug, XayaUI_Bonus and XayaUI_Bonus_StatCalculator, bundled libraries (any path with a
Libs/ folder) left out. The gate (tests/gate_performance_run.py P4, SD-68 guard) catches the sites its scenario reaches; this scan
catches the ones it never reaches (an Options window, a cast while learning, a proc glow).

A timer call: C_Timer.After, C_Timer.NewTimer, C_Timer.NewTicker (and the same through a local alias of C_Timer or of the function),
RunNextFrame, and AceTimer's :ScheduleTimer / :ScheduleRepeatingTimer. Its callback (the 2nd argument; RunNextFrame's and
:ScheduleTimer's 1st) makes a new function each time the call runs when:
  * it is a function literal (function ... end) written inside a function body (a handler, a method, any function): every run of
    that function makes a new closure and hands it to the game's timer;
  * it is a local whose value is a function literal made inside a function body (local function cb() ... end, local cb = function,
    or cb = function ... end assigned there), the timer call inside a function too: a new closure per run of the enclosing function;
  * it is GenerateClosure(...) / GenerateFlatClosure(...) inside a function (Blizzard's helpers make a new closure per call).
Not a site: a function made once at load (a file-level function or local, the main chunk; a field such as ns.Foo or self.Bar; a
parameter, which is the caller's function). A timer call written at file level (the main chunk) runs once per load and is listed as
a note, not failed. A callback the scan cannot classify (another call's result) is a FAIL too ("unknown": prove it is made once).

FAIL: one line per site, "<file>:<line> <timer> <why>"; the last line "closure scan: N site(s) ... FAILS: N" (tests/run_all.py).
Expected (round 10 Stage 1a): FAILS until the closures unit lands (Stage 1b); the list is that unit's work list.
The scanner proves itself first (SELF): known positive and negative Lua snippets, and a mutation of a real file (a closure per call
put into a function of a file with no site) that must add exactly that site.
Run: python3 tests/fix_r10_closure_scan_run.py [--list]"""
import os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
ADDONS = ("XayaUI", "XayaUI_Rules", "XayaUI_Options", "XayaUI_Debug", "XayaUI_Bonus", "XayaUI_Bonus_StatCalculator")

KEYWORDS = {"and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in", "local", "nil", "not", "or",
            "repeat", "return", "then", "true", "until", "while"}
TIMER_FIELDS = {"After": 1, "NewTimer": 1, "NewTicker": 1}          # C_Timer.<field>(delay, callback, ...): callback index
CLOSURE_MAKERS = {"GenerateClosure", "GenerateFlatClosure"}


# ---------------------------------------------------------------------------------------------------------------------------------
# a Lua 5.1 tokenizer: (kind, text, line); kinds: name, kw, str, num, op. Comments and long strings are skipped / kept as one token.
# ---------------------------------------------------------------------------------------------------------------------------------
_LONG_OPEN = re.compile(r"\[(=*)\[")


def tokenize(src):
    toks, i, n, line = [], 0, len(src), 1
    while i < n:
        c = src[i]
        if c == "\n":
            line += 1; i += 1; continue
        if c in " \t\r\f\v":
            i += 1; continue
        if src.startswith("--", i):
            m = _LONG_OPEN.match(src, i + 2)
            if m:
                close = "]" + m.group(1) + "]"
                j = src.find(close, m.end())
                j = n if j < 0 else j + len(close)
                line += src.count("\n", i, j); i = j
            else:
                j = src.find("\n", i)
                i = n if j < 0 else j
            continue
        m = _LONG_OPEN.match(src, i)
        if m:
            close = "]" + m.group(1) + "]"
            j = src.find(close, m.end())
            j = n if j < 0 else j + len(close)
            toks.append(("str", src[i:j], line)); line += src.count("\n", i, j); i = j
            continue
        if c in "\"'":
            j = i + 1
            while j < n and src[j] != c:
                if src[j] == "\\":
                    j += 1
                if j < n and src[j] == "\n":
                    line += 1
                j += 1
            toks.append(("str", src[i:j + 1], line)); i = j + 1
            continue
        if c.isalpha() or c == "_":
            j = i + 1
            while j < n and (src[j].isalnum() or src[j] == "_"):
                j += 1
            w = src[i:j]
            toks.append(("kw" if w in KEYWORDS else "name", w, line)); i = j
            continue
        if c.isdigit() or (c == "." and i + 1 < n and src[i + 1].isdigit()):
            m = re.compile(r"0[xX][0-9a-fA-F]+|\d*\.?\d+(?:[eE][+-]?\d+)?\.?\d*").match(src, i)
            j = m.end() if m and m.end() > i else i + 1
            toks.append(("num", src[i:j], line)); i = j
            continue
        for op in ("...", "..", "==", "~=", "<=", ">="):
            if src.startswith(op, i):
                toks.append(("op", op, line)); i += len(op); break
        else:
            toks.append(("op", c, line)); i += 1
    return toks


# ---------------------------------------------------------------------------------------------------------------------------------
# the scan: one pass with a block stack (function / if / while / for / do / repeat / main) and the locals each block declares
# ---------------------------------------------------------------------------------------------------------------------------------
class Local(object):
    __slots__ = ("name", "fn_depths", "decl_depth", "kind")

    def __init__(self, name, decl_depth, kind):
        self.name, self.decl_depth, self.kind = name, decl_depth, kind   # kind: "param" | "var" | "fn"
        self.fn_depths = set()   # the function depths at which a function literal was stored in it (empty: never)


def _arg_spans(toks, open_i):
    """The top-level argument spans [(start, end_exclusive)] of the call whose "(" is toks[open_i], and the index after ")"."""
    depth, blocks, start, spans, i, n = 0, 0, open_i + 1, [], open_i + 1, len(toks)
    pending_do = 0
    while i < n:
        k, t, _ = toks[i]
        if k == "op" and t in "({[":
            depth += 1
        elif k == "op" and t in ")}]":
            if depth == 0 and blocks == 0 and t == ")":
                if i > start:
                    spans.append((start, i))
                return spans, i + 1
            depth -= 1
        elif k == "kw":
            if t in ("function", "if", "repeat"):
                blocks += 1
            elif t in ("while", "for"):
                blocks += 1; pending_do += 1
            elif t == "do":
                if pending_do:
                    pending_do -= 1
                else:
                    blocks += 1
            elif t in ("end", "until"):
                blocks -= 1
        elif k == "op" and t == "," and depth == 0 and blocks == 0:
            spans.append((start, i)); start = i + 1
        i += 1
    return spans, n


def scan_source(src, fname="?"):
    """Returns (sites, once, indirect): sites = [(line, timer, why)] that make a new function per call; once = [(line, timer, why)]
    timer calls in the main chunk (run once per load); indirect = [(line, text)] timer functions used other than by a direct call."""
    toks = tokenize(src)
    n = len(toks)
    stack = [{"kind": "main", "locals": {}}]
    fn_depth = 0
    pending_do = 0
    aliases_ct = {"C_Timer"}       # names that are C_Timer (global or a local alias)
    alias_fn = {}                  # local name -> callback index (a local alias of C_Timer.After / NewTimer / NewTicker)
    sites, once, indirect = [], [], []

    def lookup(name):
        for b in reversed(stack):
            loc = b["locals"].get(name)
            if loc is not None:
                return loc
        return None

    def declare(name, kind):
        loc = Local(name, fn_depth, kind)
        stack[-1]["locals"][name] = loc
        return loc

    def push(kind):
        stack.append({"kind": kind, "locals": {}})

    def classify(span, here_depth):
        """why the callback makes a new function per call, or None; "unknown: ..." when it cannot be told."""
        s, e = span
        k0, t0, _ = toks[s]
        if k0 == "kw" and t0 == "function":
            return "a function literal written inside a function: a new closure on every run" if here_depth >= 1 else None
        if k0 == "name" and e - s == 1:
            loc = lookup(t0)
            if loc is None:
                return None                         # a global (made once at load) or not ours
            if loc.kind == "param":
                return None                         # the caller's function
            # made in the same function body as the timer call: each run of that body makes it again (made in an OUTER function, it
            # is shared by every run of the inner one: no new function per timer call)
            if here_depth >= 1 and here_depth in loc.fn_depths:
                return "the local '%s' holds a function literal made in the same function: a new closure on every run of it" % t0
            return None
        if k0 == "name":
            # a field read (ns.Foo, self.Bar, a.b.c) is no new function; a call's result is
            j = s + 1
            while j < e and toks[j][0] == "op" and toks[j][1] == "." and j + 1 < e and toks[j + 1][0] == "name":
                j += 2
            if j == e:
                return None
            if toks[j][0] == "op" and toks[j][1] in ("(", ":", "{") or toks[j][0] == "str":
                if t0 in CLOSURE_MAKERS:
                    return "%s(...) makes a new closure on every run" % t0 if here_depth >= 1 else None
                if here_depth >= 1:
                    return "unknown: the callback is another call's result (prove it is a function made once)"
                return None
            if toks[j][0] == "op" and toks[j][1] == "[":
                return None                         # a table read (t[k]): no new function
        if here_depth >= 1:
            return "unknown: the callback expression could not be classified (prove it is a function made once)"
        return None

    def timer_call(i):
        """If a timer call starts at token i, (name shown, callback index, index of its "(") or None."""
        k, t, _ = toks[i]
        if k != "name":
            return None
        prev = toks[i - 1] if i > 0 else ("", "", 0)
        if prev[0] == "op" and prev[1] in (".", ":"):
            # a method :ScheduleTimer / :ScheduleRepeatingTimer (AceTimer): the callback is the 1st argument
            if prev[1] == ":" and t in ("ScheduleTimer", "ScheduleRepeatingTimer") and i + 1 < n and toks[i + 1][1] == "(":
                return (":" + t, 0, i + 1)
            if prev[1] == "." and t in ("ScheduleTimer", "ScheduleRepeatingTimer") and i + 1 < n and toks[i + 1][1] == "(":
                return ("." + t, 1, i + 1)
            return None
        if t in aliases_ct and i + 3 < n and toks[i + 1][1] == "." and toks[i + 2][0] == "name" and toks[i + 2][1] in TIMER_FIELDS:
            if toks[i + 3][1] == "(":
                return ("C_Timer." + toks[i + 2][1], TIMER_FIELDS[toks[i + 2][1]], i + 3)
            return ("indirect", "C_Timer." + toks[i + 2][1])
        if t == "RunNextFrame" and i + 1 < n and toks[i + 1][1] == "(":
            return ("RunNextFrame", 0, i + 1)
        if t in alias_fn and i + 1 < n and toks[i + 1][1] == "(" and lookup(t) is not None:
            return (t + " (C_Timer alias)", alias_fn[t], i + 1)
        return None

    i = 0
    while i < n:
        k, t, line = toks[i]
        # --- timer calls -------------------------------------------------------------------------------------------------------------
        tc = timer_call(i)
        if tc and tc[0] == "indirect":
            # a local alias (local After = C_Timer.After) is learned below; the value handed on (pcall(C_Timer.After, ...), a table
            # field, an assignment that is not a local alias) is listed for review; a test (if C_Timer.After then) is not a use
            before = toks[i - 1] if i > 0 else ("", "", 0)
            alias = before[1] == "=" and i >= 3 and toks[i - 3][1] == "local"
            if before[0] == "op" and before[1] in ("(", ",", "=", "{") and not alias:
                indirect.append((line, tc[1]))
        elif tc:
            label, idx, open_i = tc
            spans, _ = _arg_spans(toks, open_i)
            if len(spans) > idx:
                why = classify(spans[idx], fn_depth)
                if why:
                    sites.append((line, label, why))
                elif fn_depth == 0:
                    once.append((line, label, "written in the main chunk: runs once per load"))
            else:
                if fn_depth >= 1:
                    sites.append((line, label, "unknown: no callback argument found"))
        # --- blocks and locals -------------------------------------------------------------------------------------------------------
        if k == "kw":
            if t == "local":
                if i + 1 < n and toks[i + 1][1] == "function" and i + 2 < n and toks[i + 2][0] == "name":
                    loc = declare(toks[i + 2][1], "fn")
                    loc.fn_depths.add(fn_depth)
                    i += 1           # the "function" keyword is handled on the next turn (its block, its parameters)
                    continue
                else:
                    names, j = [], i + 1
                    while j < n and toks[j][0] == "name":
                        names.append(toks[j][1]); j += 1
                        if j < n and toks[j][1] == ",":
                            j += 1
                        else:
                            break
                    if j < n and toks[j][1] == "=":
                        rhs = toks[j + 1] if j + 1 < n else ("", "", 0)
                        for idx_name, nm in enumerate(names):
                            loc = declare(nm, "var")
                            if idx_name == 0 and rhs[0] == "kw" and rhs[1] == "function":
                                loc.fn_depths.add(fn_depth)
                        # aliases: local T = C_Timer / local After = C_Timer.After
                        if len(names) >= 1 and rhs[0] == "name" and rhs[1] in aliases_ct:
                            if j + 3 < n and toks[j + 2][1] == "." and toks[j + 3][0] == "name" and toks[j + 3][1] in TIMER_FIELDS:
                                alias_fn[names[0]] = TIMER_FIELDS[toks[j + 3][1]]
                            elif not (j + 2 < n and toks[j + 2][1] == "."):
                                aliases_ct.add(names[0])
                    else:
                        for nm in names:
                            declare(nm, "var")
                    i = j
                    continue
            elif t == "function":
                # function name / function a.b:c / anonymous function; the name (if a local) now holds a function made here
                j = i + 1
                fname_parts, is_method = [], False
                while j < n and toks[j][0] == "name":
                    fname_parts.append(toks[j][1]); j += 1
                    if j < n and toks[j][1] in (".", ":"):
                        if toks[j][1] == ":":
                            is_method = True
                        j += 1
                    else:
                        break
                if len(fname_parts) == 1:
                    loc = lookup(fname_parts[0])
                    if loc is not None:
                        loc.fn_depths.add(fn_depth)
                push("function"); fn_depth += 1
                if is_method:
                    declare("self", "param")
                # parameters
                if j < n and toks[j][1] == "(":
                    j += 1
                    while j < n and toks[j][1] != ")":
                        if toks[j][0] == "name":
                            declare(toks[j][1], "param")
                        j += 1
                    i = j + 1
                    continue
            elif t in ("if", "repeat"):
                push(t)
            elif t in ("while", "for"):
                push(t); pending_do += 1
                if t == "for":
                    j = i + 1
                    while j < n and toks[j][0] == "name":
                        declare(toks[j][1], "var"); j += 1
                        if j < n and toks[j][1] == ",":
                            j += 1
                        else:
                            break
            elif t == "do":
                if pending_do:
                    pending_do -= 1
                else:
                    push("do")
            elif t in ("end", "until"):
                if len(stack) > 1:
                    b = stack.pop()
                    if b["kind"] == "function":
                        fn_depth -= 1
            elif t in ("else", "elseif"):
                # a new branch: the locals of the previous branch go out of scope
                stack[-1]["locals"] = {}
        elif k == "name":
            # NAME = function ... (an existing local re-assigned a function literal here)
            if i + 2 < n and toks[i + 1][1] == "=" and toks[i + 2][1] == "function" and not (i > 0 and toks[i - 1][1] in (".", ":", ",", "local")):
                loc = lookup(t)
                if loc is not None:
                    loc.fn_depths.add(fn_depth)
        i += 1
    return sites, once, indirect


def lua_files(root=None):
    """The addon Lua files (git ls-files when git can read root; else the folders on disk), Libs/ left out."""
    root = root or ROOT
    files = None
    try:
        r = subprocess.run(["git", "-C", root, "ls-files", "--"] + list(ADDONS), capture_output=True, timeout=60)
        if r.returncode == 0:
            files = [f for f in r.stdout.decode(errors="replace").splitlines() if f]
    except (OSError, subprocess.SubprocessError):
        files = None
    if files is None:
        files = []
        for a in ADDONS:
            for base, dirs, fs in os.walk(os.path.join(root, a)):
                dirs.sort()
                files += [os.path.relpath(os.path.join(base, f), root) for f in sorted(fs)]
    out = []
    for f in files:
        f = f.replace(os.sep, "/")
        if f.endswith(".lua") and "/Libs/" not in "/" + f and f.split("/")[0] in ADDONS:
            out.append(f)
    return sorted(out)


def scan_tree(root=None):
    root = root or ROOT
    allsites, allonce, allind = [], [], []
    files = lua_files(root)
    for f in files:
        with open(os.path.join(root, f), encoding="utf-8", errors="replace") as fh:
            s, o, ind = scan_source(fh.read(), f)
        allsites += [(f, ln, lab, why) for ln, lab, why in s]
        allonce += [(f, ln, lab, why) for ln, lab, why in o]
        allind += [(f, ln, txt) for ln, txt in ind]
    return files, allsites, allonce, allind


# ---------------------------------------------------------------------------------------------------------------------------------
# SELF: the scanner on known snippets, and a mutation of a real file
# ---------------------------------------------------------------------------------------------------------------------------------
SELF_CASES = [
    # (name, Lua, expected site lines)
    ("literal in a handler", "local f = CreateFrame('Frame')\nf:SetScript('OnEvent', function()\n  C_Timer.After(0, function() print(1) end)\nend)\n", [3]),
    ("file-level function passed", "local function Run() end\nlocal function H()\n  C_Timer.After(1, Run)\nend\n", []),
    ("local function made per call", "local function H()\n  local function cb() end\n  C_Timer.After(1, cb)\nend\n", [3]),
    ("local = function made per call", "function ns.H()\n  local cb = function() end\n  C_Timer.NewTimer(1, cb)\nend\n", [3]),
    ("forward local re-assigned per call", "local cb\nlocal function H()\n  cb = function() end\n  C_Timer.After(1, cb)\nend\n", [4]),
    ("forward local made once", "local cb\ncb = function() end\nlocal function H()\n  C_Timer.After(1, cb)\nend\n", []),
    ("main chunk literal (once per load)", "C_Timer.After(0, function() end)\n", []),
    ("field callback", "local function H()\n  C_Timer.After(0.2, ns.Minimap_Refresh)\nend\n", []),
    ("parameter callback", "local function Later(fn)\n  C_Timer.After(0, fn)\nend\n", []),
    ("ticker literal in a method", "function M:Start()\n  self.t = C_Timer.NewTicker(0.1, function(t) end)\nend\n", [2]),
    ("alias of C_Timer", "local T = C_Timer\nlocal function H()\n  T.After(0, function() end)\nend\n", [3]),
    ("alias of After", "local After = C_Timer.After\nlocal function H()\n  After(0, function() end)\nend\n", [3]),
    ("RunNextFrame literal", "local function H()\n  RunNextFrame(function() end)\nend\n", [2]),
    ("GenerateClosure", "local function H(a)\n  C_Timer.After(0, GenerateClosure(print, a))\nend\n", [2]),
    ("AceTimer method", "function M:H()\n  self:ScheduleTimer(function() end, 1)\nend\n", [2]),
    ("string and comment are not code", "local s = 'C_Timer.After(0, function() end)'\n-- C_Timer.After(0, function() end)\nlocal function H() end\n", []),
    ("long comment", "--[[\nlocal function H() C_Timer.After(0, function() end) end\n]]\nlocal x = 1\n", []),
    ("guarded call in an if", "local function Run() end\nlocal function H()\n  if C_Timer and C_Timer.After then C_Timer.After(1, Run) else Run() end\nend\n", []),
    ("nested literal in a literal", "function H(b)\n  b.t = C_Timer.NewTimer(0.4, function() b.u = C_Timer.NewTicker(0.07, function() end) end)\nend\n", [2, 2]),
    ("local function made per call, used in a loop", "local function H()\n  local function try() end\n  for i = 1, 3 do C_Timer.After(0, try) end\nend\n", [3]),
    ("made once in an outer function, armed in an inner one", "local function Setup(b)\n  local function step() end\n  b:SetScript('OnMouseDown', function()\n    b.t = C_Timer.NewTicker(0.07, step)\n  end)\nend\n", []),
    ("handed on as a value", "local function H()\n  pcall(C_Timer.After, 0, function() end)\nend\n", []),
    ("local in an earlier function is not this one", "local function A()\n  local cb = function() end\nend\nlocal cb2 = function() end\nlocal function B()\n  C_Timer.After(0, cb2)\nend\n", []),
]
MUT_LINE = "local function XuiScanMutant() C_Timer.After(0, function() end) end\n"


def self_check():
    fails = []
    for name, src, want in SELF_CASES:
        got = sorted(ln for ln, _, _ in scan_source(src)[0])
        if got != sorted(want):
            fails.append("SELF %s: sites at lines %s, expected %s" % (name, got, sorted(want)))
    return fails


def mutation_check(files, sites, root=None):
    """A real file with no site gets one closure per call appended: the scan must find exactly one more site, at that line."""
    root = root or ROOT
    with_site = {f for f, _, _, _ in sites}
    clean = [f for f in files if f not in with_site]
    if not clean:
        return ["MUTATION: no file without a site to mutate"], None
    f = clean[0]
    with open(os.path.join(root, f), encoding="utf-8", errors="replace") as fh:
        src = fh.read()
    if not src.endswith("\n"):
        src += "\n"
    mline = src.count("\n") + 1
    before = scan_source(src)[0]
    after = scan_source(src + MUT_LINE)[0]
    extra = [s for s in after if s not in before]
    if len(after) != len(before) + 1 or [ln for ln, _, _ in extra] != [mline]:
        return ["MUTATION %s: expected one new site at line %d, got %s" % (f, mline, extra)], f
    return [], "%s:%d" % (f, mline)


def main():
    listing = "--list" in sys.argv
    print("Static scan: no timer call makes a new function per call (SD-82 \"FAIL everywhere\", SD-90 option 2)")
    selff = self_check()
    for x in selff:
        print("FAIL " + x)
    print("  scanner self-check: %d snippet(s), %d wrong" % (len(SELF_CASES), len(selff)))
    files, sites, once, ind = scan_tree()
    by_addon = {}
    for f, _, _, _ in sites:
        by_addon[f.split("/")[0]] = by_addon.get(f.split("/")[0], 0) + 1
    mutf, mut_where = mutation_check(files, sites)
    for x in mutf:
        print("FAIL " + x)
    if mut_where:
        print("  mutation: a closure per call appended to %s is found there (the scan has teeth)" % mut_where)
    print("  files scanned: %d (%s; Libs/ left out)" % (len(files), ", ".join("%s %d" % (a, sum(1 for f in files if f.split('/')[0] == a)) for a in ADDONS)))
    if not files:
        print("FAIL no Lua file was found (git ls-files of %s)" % ", ".join(ADDONS))
    for f, ln, lab, why in once:
        if listing:
            print("  note %s:%d %s (%s)" % (f, ln, lab, why))
    if once:
        print("  notes: %d timer call(s) in a main chunk (once per load, not failed)" % len(once))
    for f, ln, txt in ind:
        print("  note %s:%d %s used other than by a direct call (not judged; look at it)" % (f, ln, txt))
    for f, ln, lab, why in sites:
        print("FAIL %s:%d %s: %s" % (f, ln, lab, why))
    print("  sites per addon: %s" % (", ".join("%s %d" % (a, by_addon.get(a, 0)) for a in ADDONS)))
    nf = len(sites) + len(selff) + len(mutf) + (0 if files else 1)
    print("closure scan: %d site(s) making a new function per timer call in %d file(s)  FAILS: %d" % (len(sites), len(files), nf))
    return 1 if nf else 0


if __name__ == "__main__":
    sys.exit(main())
