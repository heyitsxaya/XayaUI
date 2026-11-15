#!/usr/bin/env python3
"""Round 8 gate fixes, proved on a probe addon (REQUEST-LOG A23 SD-66 / SD-68; tests/gate_common.py, tests/gate_performance_run.py).

Her answers: the stand-in timer's gate failure "Fix gate + guard + /run test (Recommended)" (SD-68); the memory budget "Today +15%,
tighten later (Recommended)", the per-event limit "No worse than ad60a51 (Recommended)" and "10/s for all" covering every re-check path
"1" (SD-66).

How: the gate's own scenario (tests/gate_common.py SCENARIO_LUA, as it stands in this checkout) is played on a fresh install with a probe
addon file added right after the settings window closes, with the call trees of timer callbacks and frame scripts taken (CFG.tree: the
gate's second play, which its pace per re-check pass reads). The probe is compiled as Interface/AddOns/XayaUI_Rules/GateProbe.lua, so the
gate measures it exactly as it measures XayaUI Rules. The probe's handlers each do one known thing on an event the gate fires as a storm
event (one that fires every frame of a fight) for 2 seconds. Then this checkout's tests/gate_performance_run.py judges the result (its
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
           two different passes (7.5 a second each) sharing one body are not findings, and the body's 15 a second is reported (her rule
           is per path); a timer chain every 3 frames (the stand-in runs
           C_Timer.After(0.09) at the next frame at or after 0.09 s: 0.1 s, 10 a second) is not a pace finding;
  memory   a reading above 34,747.6 KB x 1.15 = 39,959.7 KB at the end of a cycle is a FAIL; 39,959.7 KB itself is not;
  per event  an addon whose costliest fight frame is one instruction above its stored ad60a051 cap is a FAIL; at the cap it is not.
Run: python3 tests/fix_r8_gate_probe_run.py   (Lua 5.1 via lupa; about a minute and a half)"""
import contextlib, io, json, os, re, sys
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


def play():
    scen = GC.SCENARIO_LUA
    if scen.count(MARKER) != 1:
        raise SystemExit("the marker %r is not in tests/gate_common.py once; this test needs updating" % MARKER)
    scen = scen.replace(MARKER, MARKER + "\n" + INSERT, 1)
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    world, loader, game, sv = GC._world(L)
    cfg = H.to_lua(L, {"perf": True, "verbose": False, "busy": 1.0, "probeSrc": PROBE_SRC, "tree": True})   # (the gate's tree play)
    res = L.eval("function(src, W, Ld, G, C) return loadstring(src)()(W, Ld, G, C) end")(scen, world, loader, game, cfg)
    return json.loads(json.dumps(H.lua_to_py(res), default=str))   # (as the gates read it: through JSON)


# (round 8 repair) the probe's re-check passes, named to the gate as the engine's are (gate_performance_run.py REPASSES)
PROBE_PASSES = (("Pass", "the probe's pass driven by two timers"), ("PassX", "the probe's pass X"), ("PassY", "the probe's pass Y"))


def gate_text(data):
    """This checkout's gate_performance main() on the given result (every variant), its output as text. The probe's passes are named
    to the gate for this call (when this checkout's gate has a pass list)."""
    saved = (GC.result, GC.v33_baseline)
    reps = getattr(GP, "REPASSES", None)
    src_text = getattr(GP, "source_text", None)
    if reps is not None and src_text is not None:
        GP.REPASSES = dict(reps, **{PROBE_FILE: PROBE_PASSES})
        GP.source_text = lambda f: PROBE_SRC if f == PROBE_FILE else src_text(f)
    GC.result = lambda *a, **k: (data, 0, True)
    GC.v33_baseline = lambda *a, **k: (None, "not played (tests/fix_r8_gate_probe_run.py)")
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
    check(re.search(r"work shared by several paths \(report only[^\n]*%s 15 \(from 2 callbacks\)" % re.escape(src["P9"]), text) is not None,
          "pace: the shared body is reported with its 15 a second and its 2 callbacks")
    for k in ("P7", "P8"):
        pk = (data.get("pace") or {}).get(src[k]) or {}
        check(int(pk.get("most") or 0) <= 8 and not any(f[1].split(" ")[0] == src[k] and re.search(r"P2 ", f[2]) for f in fs),
              "pace: each driver alone (%s) runs at most 8 times in a second and is not a finding of its own" % src[k],
              "most %s" % pk.get("most"))
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

    def cap_text(v_every, v_steady):
        b = {"fight 1": {"frames": 450, "work": {"XayaUI_Rules": 1}, "peak": {"XayaUI_Rules": v_every}},
             "fight 2": {"frames": 450, "work": {"XayaUI_Rules": 1}, "peak": {"XayaUI_Rules": v_steady}},
             "fight 3": {"frames": 450, "work": {"XayaUI_Rules": 1}, "peak": {"XayaUI_Rules": v_steady}}}
        return findings(gate_text({"budget": b}))
    lim = r"V33 per-event limit"
    check(any(f[0] == "FAIL" and f[1].startswith("XayaUI_Rules") and re.search(lim, f[2]) for f in cap_text(rules_cap + 1, min(steady_cap, rules_cap))),
          "per event: XayaUI Rules one instruction above its ad60a051 cap (%d) in a fight frame is a FAIL" % rules_cap)
    check(any(f[0] == "FAIL" and f[1].startswith("XayaUI_Rules") and re.search(lim, f[2]) for f in cap_text(min(steady_cap, rules_cap), steady_cap + 1)),
          "per event: XayaUI Rules one instruction above its steady-fight cap (%d) is a FAIL" % steady_cap)
    check(not any(f[1].startswith("XayaUI_Rules") and re.search(lim, f[2]) for f in cap_text(rules_cap, steady_cap)),
          "per event: XayaUI Rules exactly at its caps is not a FAIL")

    print("%d checks, %d failed" % (len(done), len(fails)))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
