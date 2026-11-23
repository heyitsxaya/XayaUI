#!/usr/bin/env python3
"""Round 8 gate fixes, proved on a probe addon (REQUEST-LOG A23 SD-66 / SD-68; tests/gate_common.py, tests/gate_performance_run.py).

Her answers: the stand-in timer's gate failure "Fix gate + guard + /run test (Recommended)" (SD-68); the memory budget "Today +15%,
tighten later (Recommended)", the per-event limit "No worse than ad60a51 (Recommended)" and "10/s for all" covering every re-check path
"1" (SD-66).

How: the gate's own scenario (tests/gate_common.py SCENARIO_LUA, as it stands in this checkout) is played on a fresh install with a probe
addon file added right after the settings window closes, played twice as the gate plays it: the measured play, then the play with the
call trees of timer callbacks, frame scripts and event handlers taken (CFG.tree: the gate's second play, which its pace reads). The
probe is compiled as Interface/AddOns/XayaUI_Rules/GateProbe.lua, so the gate measures it exactly as it measures XayaUI Rules. The
probe's handlers each do one known thing on an event the gate fires as a storm event (one that fires every frame of a fight) for 2
seconds. Then this checkout's tests/gate_performance_run.py judges the result (its
main(), with the scenario's result handed in), and the printed findings are read.

What the gate must report (what the player gets: a gate that bills the addon for exactly what the addon does, so a build that makes Lua
garbage per event fails and one that does not passes):
  billing  a handler that only arms a timer (C_Timer.After / NewTimer / NewTicker with a function made once) allocates 0 bytes; a handler
           that makes one known table and arms a timer, walks a list (ipairs), turns the mouse on or sets a non-whole position is billed
           exactly that table's size (the gate's own measuring and the stand-in's work are taken out once, not twice or three times);
  guard    a handler that hands C_Timer.After a new closure on every event is a FAIL ("a new function per timer call on the hot path");
           the handlers that pass one function made once are not;
  pace     a timer chain that runs 15 times a second and changes something on screen every run is a FAIL (round 7 only warned); a chain
           that runs exactly 11 times within one second (her named case) is a FAIL; a frame script (OnUpdate) that runs every frame is a
           pace FAIL whether it changes nothing or redraws on every run (round 8 repair: no redraw exemption is built, NEEDS_HER_DECISION);
           one re-check pass driven by two timers (7.5 a second each) runs 15 a second and is a FAIL at the pass (round 8 repair: a pass
           named to the gate, as the engine's are in REPASSES, is counted whatever drives it), while neither timer is a finding of its own;
           (round 8 repair 2) a pass an event handler runs itself on every event of a storm (30 a second) is a FAIL at the pass, one run
           on every 4th event (7.5 a second) is not, and the handlers themselves are not pace findings;
           two different passes (7.5 a second each) sharing one body are not P2 FAILs, and the body's 15 a second is a WARNING
           (her rule is per path: SD-78 "Per pass (Recommended)", cited by the WARNING since round 11b, SD-147); a timer chain every 3 frames (the stand-in runs
           C_Timer.After(0.09) at the next frame at or after 0.09 s: 0.1 s, 10 a second) is not a pace finding;
  memory   a reading above 34,747.6 KB x 1.15 = 39,959.7 KB at the end of a cycle is a FAIL; 39,959.7 KB itself is not;
  per event  an addon whose costliest fight frame is one instruction above its stored ad60a051 cap is a FAIL; at the cap it is not.
  record   (round 11 repair; R11A final blockers[1] and its concern "a fresh public clone that cannot replay ad60a051 loses its
           calibration") the stored records (V33_RECORDED, V33_EVENT_CAPS) are for this checkout's scenario (stamp) and stand-in, so the
           caps above are judged from the record alone, with ad60a051 not played (as in a public or shallow clone); a record for another
           scenario is a FAIL that says MISSING INPUT, with or without ad60a051 played (before: a WARNING, and the gate passed only where
           git had ad60a051); a record from another stand-in is such a FAIL when ad60a051 cannot be played, a WARNING when it can.
           (round 11 repair 1) The stand-in's fingerprint follows its code, not its comments: a comment or blank-line edit keeps it,
           one changed code line changes it. (round 11 repair 2; round 11a repair 1 review) Comments are read as Lua 5.1 reads them:
           wrapping a code block in a block comment ("--[[" ... "--]]", or "--[==[" ... "]==]") changes it, switching it back on
           ("---[[" ... "--]]") gives the unwrapped fingerprint again, a "--" line inside a long string is string, not comment, and
           the text the fingerprint reads still compiles in Lua 5.1.
  count    (round 11 repair; SD-138 / V35 "a test fails ... if it prints no result count") the gate's last line says how many checks it
           ran and how many failed, in the form tests/run_all.py reads (its COUNT_PATTERNS and failure counts): a clean result reads
           "N checks, 0 failed", N = every named check of both variants; a cap one instruction over reads at least one failed check,
           named, and does not pass.
Run: python3 tests/fix_r8_gate_probe_run.py   (Lua 5.1 via lupa; about a minute and a half)"""
import contextlib, inspect, io, json, os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H              # noqa: E402
import gate_common as GC     # noqa: E402
import gate_performance_run as GP   # noqa: E402

MARKER = 'checkpoint("right after the settings window closed")'
EVENT = "PLAYER_STARTED_TURNING"   # a documented event (docs/reference/api/events.md:1218) XayaUI does not register
PROBE_FILE = "XayaUI_Rules/GateProbe.lua"

PROBE_SRC = r'''
local P = {}
local function Noop() end
local keep
local SMALL = { 1, 2 }
local parent = CreateFrame("Frame", "XayaUIGateProbe", UIParent)
parent:SetSize(200, 60); parent:SetPoint("CENTER", UIParent, "CENTER", 0, 0); parent:Show()
local fs = parent:CreateFontString(nil, "OVERLAY"); fs:SetPoint("TOP", parent, "TOP", 0, 0)
local fs2 = parent:CreateFontString(nil, "OVERLAY"); fs2:SetPoint("BOTTOM", parent, "BOTTOM", 0, 0)
local fs3 = parent:CreateFontString(nil, "OVERLAY"); fs3:SetPoint("LEFT", parent, "LEFT", 0, 0)
local mf = CreateFrame("Frame", nil, parent); mf:SetSize(10, 10); mf:SetPoint("CENTER", parent, "CENTER", 0, 0)
local evs = {}
-- (round 8 repair 2) a re-check pass an event handler runs itself, on every event of the storm (30 a second), and one an event handler
-- runs on every 4th event only (7.5 a second); both are named to the gate as passes (PROBE_PASSES)
local fs7 = parent:CreateFontString(nil, "OVERLAY"); fs7:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
local n7, n8, kSlow = 0, 0, 0
local function EvPass() n7 = n7 + 1; fs7:SetText("ev " .. n7) end --@P14
local function SlowEvPass() n8 = n8 + 1; fs7:SetText("slow ev " .. n8) end --@P15
local function on(handler) local f = CreateFrame("Frame"); f:RegisterEvent("PLAYER_STARTED_TURNING"); f:SetScript("OnEvent", handler); evs[#evs + 1] = f end
function P.setup()
on(function() C_Timer.After(0.05, Noop) end) --@A
on(function() local t = C_Timer.NewTimer(0.05, Noop) end) --@B
on(function() local t = C_Timer.NewTicker(0.05, Noop, 1) end) --@C
on(function() C_Timer.After(0.05, function() Noop() end) end) --@D
on(function() keep = { 1, 2, 3, 4 }; C_Timer.After(0.05, Noop) end) --@E
on(function() keep = { 1, 2, 3, 4 }; for _ in ipairs(SMALL) do end end) --@F
on(function() keep = { 1, 2, 3, 4 }; mf:EnableMouse(true) end) --@G
on(function() keep = { 1, 2, 3, 4 }; mf:SetPoint("CENTER", parent, "CENTER", 0.5, 0) end) --@H
on(function() EvPass() end) --@I
on(function() kSlow = kSlow + 1; if kSlow % 4 == 0 then SlowEvPass() end end) --@J
end
-- pace paths, started once (outside any handler) and re-armed by themselves
local fastOn, slowOn, n1, n2, n4 = true, true, 0, 0, 0
local Fast, Slow
Fast = function() n1 = n1 + 1; fs:SetText("fast " .. n1); if fastOn then C_Timer.After(0.05, Fast) end end --@P1
Slow = function() n2 = n2 + 1; fs2:SetText("slow " .. n2); if slowOn then C_Timer.After(0.09, Slow) end end --@P2
local qf = CreateFrame("Frame", nil, parent)
local vf = CreateFrame("Frame", nil, parent)
-- (round 8 repair) her named case, 11 runs in one second: one chain, 9 gaps of 0.09 s (3 frames) and one of 0.06 s (2 frames), then it
-- stops: 11 runs over 9 x 3 + 2 = 29 frames = 0.967 s, so one sliding second holds 11
local fs4 = parent:CreateFontString(nil, "OVERLAY"); fs4:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
local GAPS, g5, n5 = { 0.09, 0.09, 0.09, 0.09, 0.09, 0.09, 0.09, 0.09, 0.09, 0.06 }, 0, 0
local Eleven
Eleven = function() n5 = n5 + 1; fs4:SetText("eleven " .. n5); g5 = g5 + 1; if GAPS[g5] then C_Timer.After(GAPS[g5], Eleven) end end --@P5
-- (round 8 repair) one re-check pass driven by two timers, each re-armed every 0.12 s (4 frames: 7.5 a second each), set off 0.01 s and
-- 0.07 s after the start: the pass runs 15 a second although neither timer runs more than 8 times in a second
local fs5 = parent:CreateFontString(nil, "OVERLAY"); fs5:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
local n6, twoOn = 0, true
local function Pass() n6 = n6 + 1; fs5:SetText("pass " .. n6) end --@P6
local DriverA, DriverB
DriverA = function() Pass(); if twoOn then C_Timer.After(0.12, DriverA) end end --@P7
DriverB = function() Pass(); if twoOn then C_Timer.After(0.12, DriverB) end end --@P8
-- (round 8 repair) two different passes, each driven by its own timer every 0.12 s (7.5 a second), sharing one body: the body runs 15 a
-- second, once per pass of each; her rule is per path, so the body is reported and neither pass is a finding
local fs6 = parent:CreateFontString(nil, "OVERLAY"); fs6:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
local n9 = 0
local function Body(tag) n9 = n9 + 1; fs6:SetText(tag .. n9) end --@P9
local function PassX() Body("x") end --@P10
local function PassY() Body("y") end --@P11
local DriverX, DriverY
DriverX = function() PassX(); if twoOn then C_Timer.After(0.12, DriverX) end end --@P12
DriverY = function() PassY(); if twoOn then C_Timer.After(0.12, DriverY) end end --@P13
function P.start()
  C_Timer.After(0.05, Fast); C_Timer.After(0.09, Slow)
  C_Timer.After(0.09, Eleven)
  C_Timer.After(0.01, DriverA); C_Timer.After(0.07, DriverB)
  C_Timer.After(0.01, DriverX); C_Timer.After(0.07, DriverY)
  qf:SetScript("OnUpdate", function() end) --@P3
  vf:SetScript("OnUpdate", function() n4 = n4 + 1; fs3:SetText("redraw " .. n4) end) --@P4
end
function P.stop()
  fastOn, slowOn, twoOn = false, false, false
  qf:SetScript("OnUpdate", nil); vf:SetScript("OnUpdate", nil)
  for _, f in ipairs(evs) do f:UnregisterAllEvents() end
end
-- the size of the table the E-H handlers make, measured the same way the gate measures (collector stopped)
function P.ref()
  collectgarbage("stop")
  local m0 = collectgarbage("count")
  local t = { 1, 2, 3, 4 }
  local m1 = collectgarbage("count")
  collectgarbage("restart")
  return math.floor((m1 - m0) * 1024 + 0.5), t
end
return P
'''

INSERT = r'''
if CFG.probeSrc then   -- (tests/fix_r8_gate_probe_run.py) the probe addon, played right after the window closed
  local PR = assert(loadstring(CFG.probeSrc, "@Interface/AddOns/XayaUI_Rules/GateProbe.lua"))()
  OUT.probeRef = PR.ref()
  PR.setup(); PR.start()
  for i = 1, 60 do CTX = "storm"; W.fire("PLAYER_STARTED_TURNING"); CTX = "change"; W.tick(1 / 30, 1) end
  PR.stop()
  W.tick(1 / 30, 30)
end
'''


def lines_of(src):
    out = {}
    for n, line in enumerate(src.split("\n"), 1):
        m = re.search(r"--@(\w+)\s*$", line)
        if m:
            out[m.group(1)] = n
    return out


def play_once(tree):
    scen = GC.SCENARIO_LUA
    if scen.count(MARKER) != 1:
        raise SystemExit("the marker %r is not in tests/gate_common.py once; this test needs updating" % MARKER)
    scen = scen.replace(MARKER, MARKER + "\n" + INSERT, 1)
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    world, loader, game, sv = GC._world(L)
    cfg = H.to_lua(L, {"perf": True, "verbose": False, "busy": 1.0, "probeSrc": PROBE_SRC, "tree": bool(tree)})
    res = L.eval("function(src, W, Ld, G, C) return loadstring(src)()(W, Ld, G, C) end")(scen, world, loader, game, cfg)
    return json.loads(json.dumps(H.lua_to_py(res), default=str))   # (as the gates read it: through JSON)


def play():
    """The two plays the gate makes (gate_common.result): the measured play, then (round 8 repair 2) the tree play, whose call trees
    give the pace per function; its pace records replace the measured play's, as in the gate. A gate without a tree play (the
    pre-repair gate) keeps the measured play's pace."""
    data = play_once(False)
    if "tree" in inspect.getsource(GC.run_scenario):
        t = play_once(True)
        data["pace"], data["paceAny"], data["paceTree"] = t.get("pace"), t.get("paceAny"), True
        # (round 11b, build spec 4.4.5) as the gate's result() does: the tree play also measures the stand-in's share
        data["share"], data["shareCost"], data["shareFound"] = t.get("share"), t.get("shareCost"), t.get("shareFound")
    return data


# (round 8 repair) the probe's re-check passes, named to the gate as the engine's are (gate_performance_run.py REPASSES)
PROBE_PASSES = (("Pass", "the probe's pass driven by two timers"), ("PassX", "the probe's pass X"), ("PassY", "the probe's pass Y"),
                ("EvPass", "the probe's pass an event handler runs every event"),
                ("SlowEvPass", "the probe's pass an event handler runs every 4th event"))


def gate_text(data, base=None):
    """This checkout's gate_performance main() on the given result (every variant), its output as text. The probe's passes are named
    to the gate for this call (when this checkout's gate has a pass list). base (round 11 repair): the result handed in as ad60a051
    played now; None = ad60a051 not played (a checkout without it)."""
    saved = (GC.result, GC.v33_baseline)
    reps = getattr(GP, "REPASSES", None)
    src_text = getattr(GP, "source_text", None)
    if reps is not None and src_text is not None:
        GP.REPASSES = dict(reps, **{PROBE_FILE: PROBE_PASSES})
        GP.source_text = lambda f: PROBE_SRC if f == PROBE_FILE else src_text(f)
    GC.result = lambda *a, **k: (data, 0, True)
    GC.v33_baseline = lambda *a, **k: ((base, "handed in (tests/fix_r8_gate_probe_run.py)") if base is not None else
                                        (None, "not played (tests/fix_r8_gate_probe_run.py)"))
    if hasattr(GP, "_BASE"):
        del GP._BASE[:]
    buf = io.StringIO()
    try:
        with contextlib.redirect_stdout(buf):
            GP.main()
    finally:
        GC.result, GC.v33_baseline = saved
        if reps is not None and src_text is not None:
            GP.REPASSES, GP.source_text = reps, src_text
        if hasattr(GP, "_BASE"):
            del GP._BASE[:]
    return buf.getvalue()


def findings(text):
    """[(kind, where, block text)] for every FAIL / WARNING in the gate's output."""
    out, cur = [], None
    for line in text.split("\n"):
        m = re.match(r"^(FAIL \d+|WARNING) \[[^\]]+\] (.*)$", line)
        if m:
            cur = ["FAIL" if m.group(1).startswith("FAIL") else "WARNING", m.group(2).strip(), line]
            out.append(cur)
        elif cur is not None and line.startswith("    "):
            cur[2] += "\n" + line
        else:
            cur = None
    return out


def main():
    fails, done = [], []

    def check(ok, what, detail=""):
        print(("ok   " if ok else "FAIL ") + what + (("  [" + detail + "]") if (detail and not ok) else ""))
        done.append(what)
        if not ok:
            fails.append(what)

    ln = lines_of(PROBE_SRC)
    src = {k: "%s:%d" % (PROBE_FILE, v) for k, v in ln.items()}
    data = play()
    check(int(data.get("errors") or 0) == 0, "the scenario with the probe ran without a Lua error", "; ".join(data.get("errorText") or [])[:300])
    ev = ((data.get("stats") or {}).get("ev") or {}).get(EVENT) or {}
    srcs = ev.get("srcs") or {}
    ref = int(data.get("probeRef") or 0)
    check(ref > 0, "the probe's reference table has a size (%d bytes)" % ref)

    # ---- billing ----------------------------------------------------------------------------------------------------------------
    for k, what in (("A", "C_Timer.After(0.05, a function made once)"), ("B", "C_Timer.NewTimer(0.05, a function made once)"),
                    ("C", "C_Timer.NewTicker(0.05, a function made once, 1)")):
        h = srcs.get(src[k]) or {}
        check(int(h.get("n") or 0) == 60 and int(h.get("bytes") or 0) == 0,
              "billing: a handler that only calls %s is billed 0 bytes over its 60 runs (the stand-in's timer record, handle and closures "
              "are the stand-in's)" % what, "runs %s, bytes %s" % (h.get("n"), h.get("bytes")))
    for k, what in (("E", "arms C_Timer.After"), ("F", "walks a list with ipairs (the gate's loop counter runs)"),
                    ("G", "turns the mouse on (the gate's mouse records run inside the stand-in's method)"),
                    ("H", "sets a non-whole position (the gate's whole-pixel records run inside the stand-in's method)")):
        h = srcs.get(src[k]) or {}
        n, b = int(h.get("n") or 0), int(h.get("bytes") or 0)
        check(n == 60 and b == 60 * ref,
              "billing: a handler that makes one %d-byte table and %s is billed exactly 60 x %d = %d bytes" % (ref, what, ref, 60 * ref),
              "runs %d, bytes %d (%+d)" % (n, b, b - 60 * ref))

    text = gate_text(data)
    fs = findings(text)

    def has(kind, where, pattern):
        return any(f[0] == kind and f[1].split(" ")[0] == where and re.search(pattern, f[2]) for f in fs)

    # ---- guard ------------------------------------------------------------------------------------------------------------------
    guard = r"new function per timer call on the hot path"
    check(has("FAIL", src["D"], guard), "guard: a handler of a storm event that hands C_Timer.After a new closure every run is a FAIL at %s" % src["D"])
    for k in ("A", "B", "C", "E"):
        check(not any(f[1].split(" ")[0] == src[k] and re.search(r"new function per timer call", f[2]) for f in fs),
              "guard: the handler at %s (one function made once) is not reported as a new function per call" % src[k])

    # ---- pace -------------------------------------------------------------------------------------------------------------------
    pace = r"P2 a timer callback ran more than 10 times within one second"
    check(has("FAIL", src["P1"], pace),
          "pace: a timer chain at 0.05 s (the stand-in runs it every 2 frames: 15 a second) that changes the screen every run is a FAIL "
          "(round 7: only a warning)")
    check(not any(f[1].split(" ")[0] == src["P2"] and re.search(r"P2 ", f[2]) for f in fs),
          "pace: a timer chain every 3 frames (0.1 s: 10 a second) is not a pace finding")
    check(has("FAIL", src["P3"], r"P2 a frame script \(OnUpdate\) ran more than 10 times within one second"),
          "pace: a frame script that runs every frame and changes nothing is a pace FAIL (frame scripts are re-check paths too)")
    # (round 8 repair, reviewer blocker (b)) the redraw exemption the first pass built (a WARNING) was a choice she has not made and could
    # hide a re-check that also redraws: such a frame script is a FAIL like any other path (NEEDS_HER_DECISION in the repair report)
    check(has("FAIL", src["P4"], r"P2 a frame script \(OnUpdate\) ran more than 10 times within one second") and
          not any(f[0] == "WARNING" and f[1].split(" ")[0] == src["P4"] for f in fs),
          "pace: a frame script that redraws on every run, 30 a second, is a pace FAIL (no redraw exemption is built)")
    # (round 8 repair, reviewer blocker (a)) her named case: 11 in a second is a FAIL, and the gate counts exactly 11
    check(has("FAIL", src["P5"], pace), "pace: a timer chain that runs 11 times within one second (her named case) is a FAIL")
    p5 = (data.get("pace") or {}).get(src["P5"]) or {}
    check(int(p5.get("most") or 0) == 11, "pace: that chain's most runs within one second is 11 (29 frames = 0.967 s hold all 11 runs)",
          "most %s" % p5.get("most"))
    # (round 8 repair, reviewer blocker) a pass is one path whatever drives it: two timers at 7.5 a second each drive one pass 15 a second
    check(has("FAIL", src["P6"], r"P2 the probe's pass driven by two timers \(Pass\) ran more than 10 times within one second"),
          "pace: one re-check pass driven by two timers (7.5 a second each) runs 15 a second and is a FAIL at the pass, %s" % src["P6"])
    p6 = (data.get("pace") or {}).get(src["P6"]) or {}
    check(int(p6.get("most") or 0) == 15, "pace: that pass's most runs within one second is 15 (two drivers x 30 frames / 4)",
          "most %s" % p6.get("most"))
    check(sorted((p6.get("drivers") or {}).keys()) == sorted([src["P7"], src["P8"]]),
          "pace: the gate names both timers that drive the pass", "drivers %s" % p6.get("drivers"))
    # (round 8 repair) her rule is per path: two different passes at 7.5 a second each that share one body are not findings; the body
    # (15 a second, once per pass of each) is reported, not judged
    pb = (data.get("pace") or {}).get(src["P9"]) or {}
    check(int(pb.get("most") or 0) == 15, "pace: the body two passes share runs 15 a second (7.5 + 7.5)", "most %s" % pb.get("most"))
    for k in ("P9", "P10", "P11", "P12", "P13"):
        check(not any(f[1].split(" ")[0] == src[k] and re.search(r"P2 ", f[2]) for f in fs),
              "pace: %s (two passes sharing one body, each 7.5 a second) is not a pace finding (her rule is per path)" % src[k])
    check(any(f[0] == "WARNING" and re.search(r"P2 work shared by several paths", f[2]) and
              re.search(r"%s 15 \(from 2 callbacks\)" % re.escape(src["P9"]), f[2]) for f in fs),
          "pace: the shared body is reported (a WARNING) with its 15 a second and its 2 callbacks")
    # (round 11b, SD-147) the WARNING cites her answer SD-78 "Per pass (Recommended)" and asks her nothing (no NEEDS_HER_DECISION)
    shw = [f for f in fs if f[0] == "WARNING" and re.search(r"P2 work shared by several paths", f[2])]
    check(bool(shw) and all("SD-78" in f[2] and "Per pass (Recommended)" in f[2] and "NEEDS_HER_DECISION" not in f[2] for f in shw),
          "pace: the shared-work WARNING cites SD-78 \"Per pass (Recommended)\" and says no NEEDS_HER_DECISION (SD-147)",
          "%s" % [f[2][-300:] for f in shw][:1])
    for k in ("P7", "P8"):
        pk = (data.get("pace") or {}).get(src[k]) or {}
        check(int(pk.get("most") or 0) <= 8 and not any(f[1].split(" ")[0] == src[k] and re.search(r"P2 ", f[2]) for f in fs),
              "pace: each driver alone (%s) runs at most 8 times in a second and is not a finding of its own" % src[k],
              "most %s" % pk.get("most"))
    # (round 8 repair 2) a pass an event handler runs itself is counted too: 30 a second on a storm event is a FAIL at the pass; 7.5 a
    # second is not; the handlers themselves (event handlers run as often as their event fires) are not pace findings
    check(has("FAIL", src["P14"], r"P2 the probe's pass an event handler runs every event \(EvPass\) ran more than 10 times within one second"),
          "pace: a re-check pass an event handler runs on every event of a storm (30 a second) is a FAIL at the pass, %s" % src["P14"])
    p14 = (data.get("paceAny") or {}).get(src["P14"]) or {}
    check(int(p14.get("most") or 0) == 30, "pace: that pass's most runs within one second is 30 (one per frame, 30 frames a second)",
          "most %s" % p14.get("most"))
    p15 = (data.get("paceAny") or {}).get(src["P15"]) or {}
    check(int(p15.get("most") or 0) in (7, 8) and not any(f[1].split(" ")[0] == src["P15"] and re.search(r"P2 ", f[2]) for f in fs),
          "pace: a pass an event handler runs on every 4th event (7.5 a second) is not a pace finding", "most %s" % p15.get("most"))
    check(not any(f[1].split(" ")[0] in (src["I"], src["J"]) and re.search(r"P2 ", f[2]) for f in fs),
          "pace: the event handlers themselves (30 a second, as often as the event fires) are not pace findings")
    p1 = (data.get("pace") or {}).get(src["P1"]) or {}
    check(int(p1.get("most") or 0) == 15, "pace: the 0.05 s chain's most runs within one second is 15 (30 frames / 2)", "most %s" % p1.get("most"))
    p2 = (data.get("pace") or {}).get(src["P2"]) or {}
    check(int(p2.get("most") or 0) == 10, "pace: the 3-frame chain's most runs within one second is 10 (a window holds (now - 1 s, now])",
          "most %s" % p2.get("most"))

    # ---- memory budget (synthetic readings, the same judge) ------------------------------------------------------------------------
    def mem_text(m3):
        d = {"mem": [34000.0, 34100.0, m3], "memEnd": 34000.0}
        return findings(gate_text(d))
    over = mem_text(39959.8)
    check(any(f[0] == "FAIL" and re.search(r"memory budget", f[2]) and re.search(r"39,959\.7", f[2]) for f in over),
          "memory: 39,959.8 KB at the end of cycle 3 is a FAIL against the cap 34,747.6 KB x 1.15 = 39,959.7 KB")
    at = mem_text(39959.7)
    check(not any(f[0] == "FAIL" and re.search(r"memory budget", f[2]) for f in at), "memory: 39,959.7 KB (the cap itself) is not a FAIL")

    # ---- per-event caps (synthetic budget, the stored caps) ----------------------------------------------------------------------
    caps = getattr(GP, "V33_EVENT_CAPS", None)
    rules_cap = (((caps or {}).get("caps") or {}).get("every") or {}).get("XayaUI_Rules", 570600) or 570600
    steady_cap = (((caps or {}).get("caps") or {}).get("steady") or {}).get("XayaUI_Rules", 570600) or 570600

    def cap_budget(v_every, v_steady):
        b = {"fight 1": {"frames": 450, "work": {"XayaUI_Rules": 1}, "peak": {"XayaUI_Rules": v_every}},
             "fight 2": {"frames": 450, "work": {"XayaUI_Rules": 1}, "peak": {"XayaUI_Rules": v_steady}},
             "fight 3": {"frames": 450, "work": {"XayaUI_Rules": 1}, "peak": {"XayaUI_Rules": v_steady}}}
        return {"budget": b}

    def cap_text(v_every, v_steady):
        return findings(gate_text(cap_budget(v_every, v_steady)))
    lim = r"V33 per-event limit"
    def evidence(fs):
        """(round 11 repair) the FAIL that proves a check, printed under it: its numbers line"""
        hit = [f for f in fs if f[0] == "FAIL" and f[1].startswith("XayaUI_Rules") and re.search(lim, f[2])]
        if hit:
            nums = [l.strip() for l in hit[0][2].split("\n") if l.strip().startswith("numbers:")]
            print("      evidence: " + (nums[0] if nums else hit[0][2].split("\n")[0])[:400])
        return bool(hit)
    check(evidence(cap_text(rules_cap + 1, min(steady_cap, rules_cap))),
          "per event: XayaUI Rules one instruction above its ad60a051 cap (%d) in a fight frame is a FAIL" % rules_cap)
    check(evidence(cap_text(min(steady_cap, rules_cap), steady_cap + 1)),
          "per event: XayaUI Rules one instruction above its steady-fight cap (%d) is a FAIL" % steady_cap)
    at_caps = gate_text(cap_budget(rules_cap, steady_cap))
    check(not any(f[1].startswith("XayaUI_Rules") and re.search(lim, f[2]) for f in findings(at_caps)),
          "per event: XayaUI Rules exactly at its caps is not a FAIL")

    # ---- (round 11 repair) the stored record: this scenario, this stand-in, used without ad60a051 -----------------------------------
    stamp_now = GC.scenario_stamp()
    standin_now = GP.standin_stamp() if hasattr(GP, "standin_stamp") else None
    recs = [("V33_EVENT_CAPS", getattr(GP, "V33_EVENT_CAPS", {}) or {}), ("V33_RECORDED", getattr(GP, "V33_RECORDED", {}) or {})]
    check(all(r.get("stamp") == stamp_now and standin_now and r.get("standin") == standin_now for _, r in recs),
          "record: V33_EVENT_CAPS and V33_RECORDED are stored for this scenario (stamp %s) and this stand-in (%s)" % (stamp_now, standin_now),
          "; ".join("%s stamp %s standin %s" % (n, r.get("stamp"), r.get("standin")) for n, r in recs))
    judged = re.search(r"V33 XayaUI Rules per event: costliest single fight frame %d instructions in every fight \(fight 1; cap %d = "
                       r"ad60a051's\) and %d in the steady fights 2-3 \(fight 2; cap %d\).*Caps stored in this gate for scenario %s" % (
                           rules_cap, rules_cap, steady_cap, steady_cap, stamp_now), at_caps)
    check(judged is not None, "record: with ad60a051 not played (a public or shallow clone), the stored caps alone judge XayaUI Rules "
          "and the gate prints that line (cap %d every fight, %d steady, scenario %s)" % (rules_cap, steady_cap, stamp_now),
          "no such line; V33 lines: %s" % [l.strip()[:160] for l in at_caps.split("\n") if "V33 XayaUI Rules per event" in l])
    if judged:
        print("      evidence: " + judged.group(0)[:300])
    mi = re.compile(r"MISSING INPUT:")
    check(not mi.search(at_caps), "record: a record for this scenario and stand-in, ad60a051 not played, says nothing is missing")

    def patched(base=None, caps_stamp=None, rec_stamp=None, standin=None):
        """gate_text with the stored records' stamps, or the stand-in's fingerprint, changed for the call."""
        keep = (GP.V33_EVENT_CAPS, GP.V33_RECORDED, getattr(GP, "standin_stamp", None))
        try:
            if caps_stamp:
                GP.V33_EVENT_CAPS = dict(GP.V33_EVENT_CAPS, stamp=caps_stamp)
            if rec_stamp:
                GP.V33_RECORDED = dict(GP.V33_RECORDED, stamp=rec_stamp)
            if standin:
                GP.standin_stamp = lambda: standin
            return gate_text(cap_budget(rules_cap, steady_cap), base)
        finally:
            GP.V33_EVENT_CAPS, GP.V33_RECORDED = keep[0], keep[1]
            if keep[2] is not None:
                GP.standin_stamp = keep[2]

    def missing(text, where):
        return [f for f in findings(text) if f[0] == "FAIL" and f[1].startswith(where) and mi.search(f[2])]
    # a stand-in result for "ad60a051 played now": the same synthetic fight, enough for the gate's calibration and caps
    base = cap_budget(rules_cap, steady_cap)
    t = patched(caps_stamp="000000000000")
    check(bool(missing(t, "tests/gate_performance_run.py (V33 per-event caps)")),
          "record: per-event caps stored for another scenario, ad60a051 not played, is a FAIL that says MISSING INPUT")
    t = patched(base=base, caps_stamp="000000000000")
    m = missing(t, "tests/gate_performance_run.py (V33 per-event caps)")
    check(bool(m) and "store in V33_EVENT_CAPS" in m[0][2],
          "record: per-event caps stored for another scenario is still a FAIL that says MISSING INPUT when ad60a051 plays here (before "
          "round 11 repair a WARNING: the gate passed only where git had ad60a051), and it prints the numbers to store",
          "findings: %s" % [(f[0], f[1]) for f in findings(t)][:6])
    t = patched(base=base, rec_stamp="000000000000")
    check(bool(missing(t, "tests/gate_common.py (V33 calibration)")),
          "record: V33_RECORDED for another scenario is a FAIL that says MISSING INPUT even when ad60a051 plays here")
    t = patched(standin="ffffffffffff")
    check(bool(missing(t, "tests/gate_performance_run.py (V33 per-event caps)")) and bool(missing(t, "tests/gate_common.py (V33 calibration)")),
          "record: records from another stand-in, ad60a051 not played, are FAILs that say MISSING INPUT (they cannot be confirmed here)")
    t = patched(base=base, standin="ffffffffffff")
    check(not mi.search(t) and any(f[0] == "WARNING" and "another stand-in" in f[2] for f in findings(t)),
          "record: records from another stand-in with ad60a051 played here are a WARNING, not missing (the replay is the cross-check)")

    # ---- (round 11 repair 1 / repair 2) the stand-in fingerprint follows code, not comments -------------------------------------
    # A copy of the three stand-in files in a temp folder, read through the gate's own standin_stamp() (GC.H.HERE pointed at the copy for
    # the call): a comment-only or blank-line edit keeps the fingerprint (no needless re-record of V33); one changed code line, or a
    # trailing "-- note" added after code, changes it (a stand-in change that can move an instruction count is never missed).
    # (round 11 repair 2; round 11a repair 1 review: "--[[" / "--]]" lines were dropped as comments, so commenting a block out or back
    # in kept the fingerprint) comments are read as Lua 5.1 reads them: a block wrapped in "--[[" ... "--]]" (or "--[==[" ... "]==]")
    # changes it; "---[[" ... "--]]" (a line comment each: the block runs) gives the unwrapped fingerprint again; a "--" line inside a long
    # string is string content and changes it; the text the fingerprint reads still compiles in Lua 5.1 (no two tokens merged).
    import shutil, tempfile   # noqa: E402
    if hasattr(GP, "standin_stamp") and hasattr(GP, "V33_STANDIN_FILES"):
        tmpd = tempfile.mkdtemp(prefix="xui-standin-")
        keep_here = GC.H.HERE
        try:
            for f in GP.V33_STANDIN_FILES:
                shutil.copyfile(os.path.join(keep_here, f), os.path.join(tmpd, f))
            wl = os.path.join(tmpd, "world.lua")
            with open(wl, "rb") as fh:
                orig = fh.read()

            def stamp_with(body):
                with open(wl, "wb") as fh:
                    fh.write(body)
                GC.H.HERE = tmpd
                try:
                    return GP.standin_stamp()
                finally:
                    GC.H.HERE = keep_here
            s0 = stamp_with(orig)
            lines = orig.split(b"\n")
            ci = next(i for i, l in enumerate(lines) if l.lstrip().startswith(b"--") and not l.lstrip().startswith(b"--["))
            code_i = next(i for i, l in enumerate(lines) if l.strip() and not l.lstrip().startswith(b"--") and b"=" in l)
            commented = b"\n".join(lines[:ci] + [lines[ci] + b" (edited comment)", b"", b"-- a new comment line   "] + lines[ci + 1:])
            s_comment = stamp_with(commented)
            s_code = stamp_with(b"\n".join(lines[:code_i] + [lines[code_i] + b" local _xui_probe = 1"] + lines[code_i + 1:]))
            s_trail = stamp_with(b"\n".join(lines[:code_i] + [lines[code_i] + b" -- trailing note"] + lines[code_i + 1:]))
            # (round 11 repair 2) a "--" inside a short string on a code line is string content, not a comment
            s_sq_a = stamp_with(b"\n".join(lines[:code_i] + [lines[code_i], b'local _xui_probe_q = "a -- b"'] + lines[code_i + 1:]))
            s_sq_b = stamp_with(b"\n".join(lines[:code_i] + [lines[code_i], b'local _xui_probe_q = "a -- c"'] + lines[code_i + 1:]))
            # a code block: the body of the stand-in's first function with at least three body lines (the lines after "function", up
            # to its "end" at the same indent)
            def fn_end(i):
                ind = re.escape(re.match(rb"\s*", lines[i]).group())
                return next((j for j in range(i + 1, len(lines)) if re.match(rb"%send\b" % ind, lines[j])), None)
            fi, fe = next((i, fn_end(i)) for i, l in enumerate(lines)
                          if re.match(rb"\s*(local\s+)?function\b", l) and fn_end(i) and fn_end(i) - i > 3)
            body_lines = lines[fi + 1:fe]

            def wrap(op, cl):
                return b"\n".join(lines[:fi + 1] + [op] + body_lines + [cl] + lines[fe:])
            s_off = stamp_with(wrap(b"--[[", b"--]]"))
            s_on = stamp_with(wrap(b"---[[", b"--]]"))
            s_off2 = stamp_with(wrap(b"--[==[", b"]==]"))
            s_str_a = stamp_with(orig + b"\nlocal _xui_probe_s = [[\n-- a line in a string\n]]\n")
            s_str_b = stamp_with(orig + b"\nlocal _xui_probe_s = [[\n-- another line in a string\n]]\n")
            s_indent = stamp_with(b"\n".join(lines[:code_i] + [b"    \t" + lines[code_i].lstrip()] + lines[code_i + 1:]))
        finally:
            GC.H.HERE = keep_here
            shutil.rmtree(tmpd, ignore_errors=True)
        check(s0 == standin_now and s_comment == s0,
              "record: a comment-only or blank-line edit of the stand-in keeps its fingerprint (the stored V33 records stay valid)",
              "unchanged %s (live %s), comment edit %s" % (s0, standin_now, s_comment))
        # (round 11 repair 2) a "-- note" after code is a comment (it costs no instruction): it keeps the fingerprint, as Lua reads it;
        # repair 1 expected a change here only because it could not tell such a note from code. A "--" inside a string on a code line
        # is not a comment: changing it changes the fingerprint.
        check(s_code != s0 and s_trail == s0 and s_sq_a != s_sq_b,
              "record: one changed code line in the stand-in changes its fingerprint (never missed); a '-- note' added after code is a "
              "comment and keeps it; a '--' inside a string on a code line is string content and changes it",
              "unchanged %s, code edit %s, trailing note %s, string %s / %s" % (s0, s_code, s_trail, s_sq_a, s_sq_b))
        print("      evidence: stand-in %s; comment edit %s; code edit %s; trailing note %s; '--' in a string %s / %s" % (
            s0, s_comment, s_code, s_trail, s_sq_a, s_sq_b))
        check(s_off != s0 and s_off2 != s0,
              "record: a code block of the stand-in commented out with a block comment ('--[[' ... '--]]', or '--[==[' ... ']==]') "
              "changes its fingerprint (the block no longer runs)", "unchanged %s, --[[ %s, --[==[ %s" % (s0, s_off, s_off2))
        check(s_on == s0 and s_on != s_off,
              "record: the same block switched back on ('---[[' ... '--]]': two line comments, the block runs) gives the unwrapped "
              "fingerprint again, not the commented-out one", "unchanged %s, ---[[ %s, --[[ %s" % (s0, s_on, s_off))
        check(s_str_a != s_str_b,
              "record: a '--' line inside a long string of the stand-in is string content: changing it changes the fingerprint",
              "%s / %s" % (s_str_a, s_str_b))
        check(s_indent == s0, "record: re-indenting a code line keeps the fingerprint (whitespace only)", "%s / %s" % (s0, s_indent))
        print("      evidence: block lines %d-%d of world.lua: --[[ %s; ---[[ %s; --[==[ %s; long string %s / %s; re-indent %s" % (
            fi + 2, fe, s_off, s_on, s_off2, s_str_a, s_str_b, s_indent))
        # the text the fingerprint reads is still Lua that compiles (Lua 5.1, the stand-in's own): no two tokens were merged
        L51 = H.lua51.LuaRuntime(unpack_returned_tuples=True)
        comp = L51.eval("function(s) local f, e = loadstring(s); return f ~= nil, e end")
        res = []
        for f in GP.V33_STANDIN_FILES:
            with open(os.path.join(keep_here, f), "rb") as fh:
                res.append((f, comp(GP.standin_code(fh.read()))))
        check(all(r[1][0] for r in res), "record: the text the fingerprint reads of each stand-in file still compiles in Lua 5.1",
              "%s" % res)
        # Small Lua run in Lua 5.1 (the round 11a repair 1 review's own case): the instructions each version runs, counted with a count
        # hook of 1, against standin_code(). Same text read means the same instructions; a version that runs other instructions reads
        # other text.
        run_n = L51.eval("function(src) local f = assert(loadstring(src)); local c = 0; debug.sethook(function() c = c + 1 end, '', 1); "
                         "f(); debug.sethook(); return c end")
        pre = "local n = 0\nlocal function foo() n = n + 1 end\nlocal function bar() n = n + 1 end\nlocal a = 1\n"
        cases = [("plain", pre + "foo()\nbar()\nreturn a\n"),
                 ("--[[ off", pre + "--[[\nfoo()\nbar()\n--]]\nreturn a\n"),
                 ("---[[ on", pre + "---[[\nfoo()\nbar()\n--]]\nreturn a\n"),
                 ("--[==[ off", pre + "--[==[\nfoo()\nbar()\n]==]\nreturn a\n"),
                 ("note after code", pre + "foo() -- note\nbar()\nreturn a\n"),
                 ("local--[[c]]x", "local--[[c]]x = 1\nreturn x\n"),
                 ("localx", "localx = 1\nreturn x\n")]
        fp = dict((k, GP.standin_code(v.encode())) for k, v in cases)
        ins = dict((k, run_n(v)) for k, v in cases)
        same = ("plain", "---[[ on", "note after code")
        check(all(fp[k] == fp["plain"] and ins[k] == ins["plain"] for k in same)
              and all(fp[k] != fp["plain"] and ins[k] != ins["plain"] for k in ("--[[ off", "--[==[ off"))
              and fp["local--[[c]]x"] != fp["localx"] and ins["local--[[c]]x"] != ins["localx"],
              "record: in Lua 5.1, versions the fingerprint reads alike run the same instructions, and a block commented out "
              "('--[[', '--[==[') or a comment between two words ('local--[[c]]x' against 'localx') reads differently and runs differently",
              "%s" % [(k, ins[k], fp[k] == fp["plain"]) for k, _ in cases])
        print("      evidence: Lua 5.1 instructions run (same text as 'plain'?): %s" % ", ".join(
            "%s %d (%s)" % (k, ins[k], "same" if fp[k] == fp["plain"] else "other") for k, _ in cases))
        # (round 11a final fix, R11A final review concern "stand-in fingerprint": the gates repair-2 reviewer's mutations B, C and E
        # survived, no check read standin_code()'s exact text) exact outputs, one per lexer branch, each written out by Lua 5.1's rule:
        #   B  a long comment ends only at its own level's close: "--[==[ x ]] y ]==]" is one comment (a break that closes at any "]]"
        #      leaves " y ]==]" as code);
        #   C  a long string of any level is a string: "[==[ -- not a comment ]==]" is kept whole (a break that knows only "[[" reads its
        #      "--" as a comment and drops the rest of the line);
        #   E  a comment that spans a line break counts as a line break: "a--[[x\ny]]b" reads "a\nb" (a break that folds it to a space
        #      reads "a b");
        #   plus a short string with an escaped quote and a "--" inside, kept whole, and a line comment before a line break folded into it.
        exact = [("B", b"a--[==[ x ]] y ]==]b", b"a b"),
                 ("C", b"x = [==[ -- not a comment ]==]\nreturn x", b"x = [==[ -- not a comment ]==]\nreturn x"),
                 ("E", b"a--[[x\ny]]b", b"a\nb"),
                 ("short string", b's = "q\\"--r" -- note\nreturn s', b's = "q\\"--r"\nreturn s')]
        got = [(k, GP.standin_code(src), want) for k, src, want in exact]
        check(all(g == w for _k, g, w in got),
              "record: standin_code() reads each lexer branch exactly as Lua 5.1 does (B a level-2 long comment ends at ']==]', not ']]';"
              " C a level-2 long string is kept whole; E a comment over a line break reads as a line break; a short string with an escaped"
              " quote and '--' is kept whole)", "%s" % [(k, g) for k, g, w in got if g != w])
    else:
        check(False, "record: the gate fingerprints the stand-in (standin_stamp, V33_STANDIN_FILES)")

    # ---- (round 11 repair) the count line -------------------------------------------------------------------------------------
    import run_all as RA   # noqa: E402  (tests/run_all.py: the guard's own readers, not a copy of them)
    names = len(re.findall(r'^\s*begin\(rep, "', inspect.getsource(GP.judge), re.M))
    # at the caps: the synthetic result has no scenario, so other checks fail (integrity, memory); the V33 per-event check does not
    last = (at_caps.strip().splitlines() or [""])[-1]
    n = RA.checked_count(last)
    check(n is not None and n == 2 * names and not RA.line_passes(last) and "V33 per-event caps" not in last,
          "count: the gate's last line counts every named check of both variants (2 x %d), as run_all reads it; at the caps the V33 "
          "per-event check is not among the failed ones" % names, "last line %r, count %s" % (last[:300], n))
    over = gate_text(cap_budget(rules_cap + 1, steady_cap))
    lo = (over.strip().splitlines() or [""])[-1]
    mf = re.search(r"\b(\d+) failed\b", lo)
    check(RA.checked_count(lo) == 2 * names and mf is not None and lo.count("V33 per-event caps") == 2 and not RA.line_passes(lo),
          "count: a cap one instruction over adds the V33 per-event check of each variant to the failed checks named on the last line, "
          "which does not pass", "last line %r" % lo[:300])
    # a clean run: every named check begun, no violation (the gate's own Checks and count_line, read by run_all's own readers)
    rep0 = GC.Report("gate_performance")
    if not (hasattr(GP, "Checks") and hasattr(GP, "count_line")):
        clean = one = "(this gate has no Checks / count_line)"
    else:
        counted = [GP.Checks(rep0, "default"), GP.Checks(rep0, "debug")]
        for c in counted:
            for i in range(names):
                c.begin("check %d" % i)
        clean = GP.count_line(rep0, counted)
        counted[1].fail("x", "y", "", "")
        one = GP.count_line(rep0, counted)
    check(names > 0 and RA.checked_count(clean) == 2 * names and RA.line_passes(clean) and re.search(r"\b0 failed\b", clean) is not None,
          "count: a clean run's last line reads '%d checks, 0 failed' and passes run_all's guard" % (2 * names), clean)
    check(not RA.line_passes(one) and re.search(r"\b1 failed\b", one) is not None and "FAILS: 1" in one,
          "count: one violation in one check reads '1 failed' and does not pass", one)

    print("%d checks, %d failed" % (len(done), len(fails)))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
