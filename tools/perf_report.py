#!/usr/bin/env python3
"""Performance report from a recorded run (REQUEST-LOG A15 P-1 / P-5: "File + report tool").

Input: the saved file the game writes at /reload or logout,
  WTF/Account/<ACCOUNT>/SavedVariables/XayaUI.lua   (CueRulesDB: the detailed record, CueRulesDB.debugRecord.lines)
recorded with XayaUI Dev Assist's Perf category on (the "Record this run?" prompt turns it on in Mythic 0 / Mythic+ dungeons).

Output (Markdown, to stdout or --out): per recorded run and per fight (boss or trash, length), the engine's own timing per fight,
the game's per-addon CPU meter (C_AddOnProfiler) per fight and for the whole run, the slowest rules, and a ranked list of what
to look at first. Only numbers that are in the file are shown; every derived number says how it was worked out.

Usage: python3 tools/perf_report.py PATH/TO/XayaUI.lua [--out report.md]
The file is read as data only (a small Lua-table reader below; nothing in it is run).
"""
import argparse, re, sys

# ---------------------------------------------------------------------------------------------------------------------------
# A reader for the game's SavedVariables format (Lua table constructors; strings, numbers, booleans, nil; "-- [n]" comments)
# ---------------------------------------------------------------------------------------------------------------------------
class LuaReader:
    def __init__(self, text):
        self.s, self.i, self.n = text, 0, len(text)

    def ws(self):
        s, n = self.s, self.n
        while self.i < n:
            c = s[self.i]
            if c in " \t\r\n,;":
                self.i += 1
            elif s.startswith("--", self.i):
                if s.startswith("--[[", self.i):
                    j = s.find("]]", self.i)
                    self.i = n if j < 0 else j + 2
                else:
                    j = s.find("\n", self.i)
                    self.i = n if j < 0 else j + 1
            else:
                break

    def string(self):
        q = self.s[self.i]; self.i += 1
        out = []
        esc = {"n": "\n", "t": "\t", "r": "\r", "\\": "\\", '"': '"', "'": "'", "\n": "\n", "a": "\a", "b": "\b", "f": "\f", "v": "\v"}
        while self.i < self.n:
            c = self.s[self.i]
            if c == q:
                self.i += 1
                return "".join(out)
            if c == "\\":
                d = self.s[self.i + 1]
                if d.isdigit():
                    m = re.match(r"\d{1,3}", self.s[self.i + 1:])
                    out.append(chr(int(m.group(0)))); self.i += 1 + len(m.group(0))
                    continue
                out.append(esc.get(d, d)); self.i += 2
                continue
            out.append(c); self.i += 1
        raise ValueError("unterminated string")

    def value(self):
        self.ws()
        c = self.s[self.i]
        if c == "{":
            return self.table()
        if c in "\"'":
            return self.string()
        m = re.match(r"-?(?:0x[0-9a-fA-F]+|\d+\.?\d*(?:[eE][-+]?\d+)?|\.\d+|inf|nan)", self.s[self.i:])
        if m and m.group(0):
            self.i += len(m.group(0))
            t = m.group(0)
            if t.startswith(("0x", "-0x")):
                return int(t, 16)
            try:
                v = float(t)
                return int(v) if v.is_integer() and "." not in t and "e" not in t.lower() else v
            except ValueError:
                return t
        for word, val in (("true", True), ("false", False), ("nil", None)):
            if self.s.startswith(word, self.i):
                self.i += len(word)
                return val
        raise ValueError("unexpected %r at %d" % (self.s[self.i:self.i + 20], self.i))

    def table(self):
        self.i += 1
        arr, d, nexti = [], {}, 1
        while True:
            self.ws()
            if self.s[self.i] == "}":
                self.i += 1
                break
            if self.s[self.i] == "[":
                self.i += 1
                k = self.value(); self.ws()
                assert self.s[self.i] == "]"; self.i += 1; self.ws()
                assert self.s[self.i] == "="; self.i += 1
                d[k] = self.value()
                continue
            m = re.match(r"[A-Za-z_][A-Za-z0-9_]*\s*=(?!=)", self.s[self.i:])
            if m:
                k = m.group(0).split("=")[0].strip(); self.i += len(m.group(0))
                d[k] = self.value()
                continue
            d[nexti] = self.value(); nexti += 1
        # a pure list (keys 1..n) comes back as a Python list
        if d and all(isinstance(k, int) for k in d) and sorted(d) == list(range(1, len(d) + 1)):
            return [d[k] for k in range(1, len(d) + 1)]
        return d if d else []

    def assignments(self):
        out = {}
        while True:
            self.ws()
            if self.i >= self.n:
                return out
            m = re.match(r"([A-Za-z_][A-Za-z0-9_]*)\s*=", self.s[self.i:])
            if not m:
                raise ValueError("expected NAME = at %d" % self.i)
            self.i += len(m.group(0))
            out[m.group(1)] = self.value()


def read_saved(path):
    with open(path, encoding="utf-8", errors="replace") as fh:
        return LuaReader(fh.read()).assignments()

# ---------------------------------------------------------------------------------------------------------------------------
# The record's lines -> runs -> fights
# ---------------------------------------------------------------------------------------------------------------------------
LINE = re.compile(r"^(\d\d:\d\d:\d\d)  (\S+)\s+(.*)$")
METER = re.compile(r"^meter (.+?) \| (.+?) ((?:\w+=\S+ ?)+)$")
COMBAT_START = re.compile(r"-+ combat (\d+) starts")
COMBAT_END = re.compile(r"-+ combat (\d+) ends(?: after (\d+) s)?")
BOSS_START = re.compile(r"boss encounter (\S+) '(.*)' starts")
BOSS_END = re.compile(r"boss encounter (\S+) '(.*)' ends: (\S+)")
PERF_OVER = re.compile(r"perf over (\d+)s: (\d+) steps \(([\d.]+)/s\), ([\d.]+) ms avg, ([\d.]+) ms worst")
PERF_PS = re.compile(r"perf: per second: rules ([\d.]+) ms, visuals ([\d.]+) ms, bars ([\d.]+) ms, per-frame effects ([\d.]+) ms")
PERF_TOP = re.compile(r"perf: #\d+ ([\d.]+) ms/s  (.*)$")
PERF_MEM = re.compile(r"perf: Lua memory (\d+) KB now, ([-+]?\d+) KB/s")
RUN_START = re.compile(r"recorded run starts: (.*?) \((.*?), instance (.*?)\)")
RUN_END = re.compile(r"recorded run ends: (.*?) -")


def parse_metrics(s):
    out = {}
    for part in s.split():
        k, _, v = part.partition("=")
        try:
            out[k] = float(v)
        except ValueError:
            out[k] = None   # "?" = the game gave nothing readable (secret or missing); never filled in
    return out


def split_runs(lines):
    """Each recorded run (start marker .. end marker, or the end of the file). Without markers: the whole record as one run."""
    runs, cur = [], None
    for raw in lines:
        m = LINE.match(raw)
        if not m:
            continue
        t, kind, text = m.groups()
        rs = RUN_START.search(text)
        if rs:
            cur = {"name": rs.group(1), "kind": rs.group(2), "instance": rs.group(3), "start": t, "end": None, "lines": []}
            runs.append(cur)
            continue
        if cur is not None:
            cur["lines"].append((t, kind, text))
            if RUN_END.search(text):
                cur["end"] = t
                cur = None
    if not runs:
        runs = [{"name": "(whole record, no run markers)", "kind": "?", "instance": "?", "start": None, "end": None,
                 "lines": [m.groups() for m in map(LINE.match, lines) if m]}]
    return runs


def fights(run):
    out, cur = [], None
    run["meters"] = {}
    for t, kind, text in run["lines"]:
        m = COMBAT_START.search(text)
        if m and kind == "Combat":
            cur = {"n": int(m.group(1)), "start": t, "secs": None, "bosses": [], "meter": {}, "engine": {}, "top": []}
            out.append(cur)
            continue
        m = COMBAT_END.search(text)
        if m and kind == "Combat":
            if cur is not None:
                cur["secs"] = int(m.group(2)) if m.group(2) else None
            continue
        m = METER.match(text)
        if m:
            tag, who, vals = m.groups()
            if tag.startswith("combat ") and cur is not None:
                cur["meter"][who] = parse_metrics(vals)
            else:
                run["meters"].setdefault(tag, {})[who] = parse_metrics(vals)
            continue
        if cur is None:
            continue
        m = BOSS_START.search(text) or BOSS_END.search(text)
        if m:
            name = "%s (%s)" % (m.group(2), m.group(1))
            if name not in cur["bosses"]:
                cur["bosses"].append(name)
            continue
        m = PERF_OVER.search(text)
        if m:
            cur["engine"].update(secs=int(m.group(1)), steps=int(m.group(2)), per_s=float(m.group(3)), avg=float(m.group(4)),
                                 worst=float(m.group(5)))
            continue
        m = PERF_PS.search(text)
        if m:
            cur["engine"].update(rules=float(m.group(1)), visuals=float(m.group(2)), bars=float(m.group(3)), fx=float(m.group(4)))
            continue
        m = PERF_TOP.search(text)
        if m:
            cur["top"].append((float(m.group(1)), m.group(2)))
            continue
        m = PERF_MEM.search(text)
        if m:
            cur["engine"].update(mem_kb=int(m.group(1)), mem_rate=int(m.group(2)))
    return out

# ---------------------------------------------------------------------------------------------------------------------------
# The report
# ---------------------------------------------------------------------------------------------------------------------------
FRAME_MS_60 = 1000.0 / 60   # one frame at 60 fps = 16.67 ms (arithmetic, used only as a yardstick)


def fmt(v, f="%.3f"):
    return "?" if v is None else f % v


def report(saved):
    db = saved.get("CueRulesDB") or {}
    rec = db.get("debugRecord") or {}
    lines = rec.get("lines") or []
    out = []
    w = out.append
    w("# XayaUI performance report")
    w("")
    w("Source: CueRulesDB.debugRecord (%d lines, started %s, %s older lines dropped)." % (len(lines), rec.get("started", "?"),
                                                                                     rec.get("dropped", 0)))
    w("How to read it: 'ms/frame' figures are the game's addon meter (C_AddOnProfiler); the API documentation gives no units or")
    w("definitions, so 'milliseconds per frame' is an INFERENCE (the game's own Addon List shows them that way). 'sess' = average")
    w("over the session, 'recent' = recent average, 'enc' = average during the current or last boss encounter, 'peak' = worst frame,")
    w("'n5 / n10 / n50 / n100' = how many frames took over 5 / 10 / 50 / 100 ms (cumulative counts; differences between readings")
    w("are the frames in between: INFERENCE). Engine figures come from XayaUI's own timer (debugprofilestop around each engine step).")
    w("A value the game hid or did not give is shown as '?', never estimated.")
    w("")
    if rec.get("dropped"):
        w("WARNING: %s older lines were dropped because the record was full; early fights may be missing." % rec.get("dropped"))
        w("")
    runs = split_runs(lines)
    ranking = {}
    for ri, run in enumerate(runs, 1):
        fl = fights(run)
        w("## Run %d: %s (%s, instance %s), %s to %s" % (ri, run["name"], run["kind"], run["instance"], run["start"] or "?",
                                                          run["end"] or "end of record"))
        w("")
        bosses = [f for f in fl if f["bosses"]]
        trash = [f for f in fl if not f["bosses"]]
        tot = sum(f["secs"] or 0 for f in fl)
        w("Fights: %d (%d with a boss, %d trash); %d s in combat in total (sum of the 'combat ends after N s' lines)." %
          (len(fl), len(bosses), len(trash), tot))
        w("")
        if fl:
            w("| Fight | Start | Length (s) | Boss | Engine avg / worst step (ms) | Engine ms per s: rules / visuals / bars / effects | Memory growth (KB/s) | XayaUI* recent ms/frame (sum) |")
            w("|---|---|---|---|---|---|---|---|")
            for f in fl:
                e = f["engine"]
                xs = [v.get("recent") for k, v in f["meter"].items() if k.startswith("XayaUI")]
                xsum = None if (not xs or any(x is None for x in xs)) else sum(xs)
                w("| %d | %s | %s | %s | %s / %s | %s / %s / %s / %s | %s | %s |" % (
                    f["n"], f["start"], fmt(f["secs"], "%d"), ", ".join(f["bosses"]) or "trash",
                    fmt(e.get("avg"), "%.2f"), fmt(e.get("worst"), "%.2f"),
                    fmt(e.get("rules"), "%.2f"), fmt(e.get("visuals"), "%.2f"), fmt(e.get("bars"), "%.2f"), fmt(e.get("fx"), "%.2f"),
                    fmt(e.get("mem_rate"), "%+d"), fmt(xsum, "%.4f")))
            w("")
        # per addon: the run-end reading (session averages), else the last fight's
        end = run["meters"].get("run end") or (fl[-1]["meter"] if fl else {})
        if end:
            w("### Per addon (game meter, %s)" % ("at run end" if "run end" in run["meters"] else "at the last fight's end"))
            w("")
            w("| Addon | sess | recent | enc | peak | n5 | n10 | n50 | n100 |")
            w("|---|---|---|---|---|---|---|---|---|")
            for who, m in sorted(end.items(), key=lambda kv: -(kv[1].get("sess") or 0)):
                w("| %s | %s | %s | %s | %s | %s | %s | %s | %s |" % (who, fmt(m.get("sess"), "%.4f"), fmt(m.get("recent"), "%.4f"),
                  fmt(m.get("enc"), "%.4f"), fmt(m.get("peak"), "%.2f"), fmt(m.get("n5"), "%d"), fmt(m.get("n10"), "%d"),
                  fmt(m.get("n50"), "%d"), fmt(m.get("n100"), "%d")))
                if who.startswith("XayaUI") and m.get("sess") is not None:
                    ranking.setdefault(who, []).append(m["sess"])
            w("")
            # boss vs trash: average of the per-fight 'recent' readings (a plain mean over fights, each fight counted once)
            if bosses and trash:
                w("### Boss vs trash (mean of each fight's 'recent' reading; each fight counts once)")
                w("")
                w("| Addon | boss fights | trash fights |")
                w("|---|---|---|")
                names = sorted({k for f in fl for k in f["meter"] if k.startswith("XayaUI")})
                for who in names:
                    def mean(group):
                        vals = [f["meter"].get(who, {}).get("recent") for f in group]
                        vals = [v for v in vals if v is not None]
                        return (sum(vals) / len(vals), len(vals)) if vals else (None, 0)
                    b, nb = mean(bosses); t, nt = mean(trash)
                    w("| %s | %s (n=%d) | %s (n=%d) |" % (who, fmt(b, "%.4f"), nb, fmt(t, "%.4f"), nt))
                w("")
        # slowest rules over the run
        tops = {}
        for f in fl:
            for ms, name in f["top"]:
                tops.setdefault(name, []).append(ms)
        if tops:
            w("### Slowest rules (engine timer; 'ms/s' = ms of engine time per second of that fight)")
            w("")
            w("| Rule | fights in top 5 | worst ms/s | mean ms/s |")
            w("|---|---|---|---|")
            for name, v in sorted(tops.items(), key=lambda kv: -max(kv[1]))[:15]:
                w("| %s | %d | %.2f | %.2f |" % (name, len(v), max(v), sum(v) / len(v)))
            w("")
        # what to look at first: plain rules, each stated
        w("### What to look at first")
        w("")
        flags = []
        for f in fl:
            e = f["engine"]
            if e.get("worst") is not None and e["worst"] > FRAME_MS_60:
                flags.append("Fight %d: one engine step took %.2f ms, more than a whole 60 fps frame (%.2f ms)." % (f["n"], e["worst"], FRAME_MS_60))
            if e.get("mem_rate") is not None and e["mem_rate"] > 0:
                flags.append("Fight %d: Lua memory grew %+d KB/s (garbage made in combat)." % (f["n"], e["mem_rate"]))
            for who, m in f["meter"].items():
                if who.startswith("XayaUI") and (m.get("n50") or 0) > 0:
                    flags.append("Fight %d: %s has %d frames over 50 ms in the game's count (cumulative)." % (f["n"], who, m["n50"]))
        for name, v in sorted(tops.items(), key=lambda kv: -max(kv[1]))[:5]:
            flags.append("Rule '%s': up to %.2f ms/s of engine time (in the top 5 in %d fights)." % (name, max(v), len(v)))
        if not flags:
            flags.append("Nothing crossed these yardsticks (a step over one 60 fps frame, memory growth in combat, frames over 50 ms).")
        seen = set()
        for x in flags:
            if x not in seen:
                seen.add(x); w("- " + x)
        w("")
    if ranking:
        w("## Ranking of XayaUI addons (game meter session average at each run's end; highest first)")
        w("")
        for i, (who, v) in enumerate(sorted(ranking.items(), key=lambda kv: -max(kv[1])), 1):
            w("%d. %s: %s ms/frame" % (i, who, ", ".join("%.4f" % x for x in v)))
        w("")
    pl = db.get("perfLog") or []
    if pl:
        w("## /xui debug perf readings kept (CueRulesDB.perfLog, newest last)")
        w("")
        for e in pl:
            w("- %s (build %s, %s):" % (e.get("at", "?"), e.get("build", "?"), "in combat" if e.get("combat") else "out of combat"))
            for l in e.get("lines") or []:
                w("  - " + str(l))
        w("")
    return "\n".join(out)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("saved", help="WTF/Account/<ACCOUNT>/SavedVariables/XayaUI.lua")
    ap.add_argument("--out", help="write the report here instead of printing it")
    a = ap.parse_args(argv)
    text = report(read_saved(a.saved))
    if a.out:
        with open(a.out, "w", encoding="utf-8") as fh:
            fh.write(text + "\n")
    else:
        sys.stdout.write(text + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
