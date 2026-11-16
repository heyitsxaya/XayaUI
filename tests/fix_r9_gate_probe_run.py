#!/usr/bin/env python3
"""Round 9 gate fixes, proved on a probe addon and on synthetic results (REQUEST-LOG A23 SD-79, SD-81, SD-82; round 9 gate items 2, 3,
4, 7 and 8; tests/gate_common.py, tests/gate_performance_run.py, tests/gate_mouse_run.py, tests/gate_keyboard_run.py).

Her answers (verbatim, REQUEST-LOG A23): SD-79 "≤30/s, stop if idle (Recommended)"; SD-81 "600, same as core (Recommended)"; SD-82
"FAIL everywhere (Recommended)"; SD-78 "Per pass (Recommended)" (the 10-a-second limit stays per re-check pass).

How: the gate's own scenario (tests/gate_common.py SCENARIO_LUA as it stands in this checkout) is played on a fresh install with a probe
addon file added right after the settings window closes (compiled as Interface/AddOns/XayaUI_Rules/GateProbe.lua, so the gate measures
it as XayaUI Rules). The probe makes frames and puts them in Visual.lua's rule -> display table (as XayaUI Rules' displays are), runs
their frame scripts for 2 s at 144 frames a second, and fires a one-off change event. This checkout's gate_performance_run.py then
judges the result, and its printed findings are read. The rest is judged on synthetic results handed to the gates.

What the gate must report (what the player gets: a build whose display effects run faster than 30 a second per display, or keep
running with nothing left to animate, or make a closure per timer call anywhere, or whose debug tools work in a fight frame, does not land):
  display  per display (SD-79): a display's effects loop with no throttle (144 runs a second) FAILs ("more than 30"); one throttled to
           1/30 s that changes the screen on every run does not; one that changes nothing on its runs FAILs ("changed nothing ...
           beyond the single run"); one whose second run finds nothing to do and takes its script off does not, also when its script is
           set again later (and one whose script is set 3 times with nothing to animate: one detection run each time); two displays at about 29 a second each that share one function are judged each on its own (no finding;
           summed they would be 57); the throttle's early return on the frames between runs is a skip, not a run; a frame that is not a
           display (a re-check driver) at 29 a second is still a P2 FAIL (10 a second, SD-78);
  closure  (SD-82) a handler of a one-off change event that hands C_Timer a new closure on every call FAILs (round 8: a WARNING); one
           that passes a function made once is not a finding;
  debug    (SD-81) XayaUI_Debug's costliest fight frame 601 instructions FAILs, 600 does not (round 8: NOT JUDGED);
  moments  (SD-77) a boss-pull frame or a combat-end frame (the "end N" segment) one instruction above XayaUI Rules' cap FAILs, at the cap
           it does not;
  memory   the growth WARNING reads the memory play (the addons' own): no WARNING when the addons do not grow although the measured play
           (with the gate's records) grows 150 KB a cycle; a WARNING naming the addons' own growth when they grow 40 KB a cycle;
  label    (item 8) the calibration line names the true source of V33_RECORDED, not "round 7";
  variants (SD-64, round 8 review) gate_mouse and gate_keyboard judge the Advanced Debugging variant too: a frame that takes clicks or
           keys only in that variant FAILs, tagged "[Advanced Debugging on]".
Run: python3 tests/fix_r9_gate_probe_run.py   (Lua 5.1 via lupa; about two minutes)"""
import contextlib, io, json, os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H              # noqa: E402
import gate_common as GC     # noqa: E402
import gate_performance_run as GP   # noqa: E402
import gate_mouse_run as GM  # noqa: E402
import gate_keyboard_run as GK   # noqa: E402

MARKER = 'checkpoint("right after the settings window closed")'
PROBE_FILE = "XayaUI_Rules/GateProbe.lua"

PROBE_SRC = r'''
local P = {}
local ns = rawget(_G, "XayaUI_NS")
local frames
for i = 1, 60 do local n, v = debug.getupvalue(ns.DisplayFrame, i); if not n then break end; if n == "frames" then frames = v end end
local parent = CreateFrame("Frame", "XayaUIGateProbe9", UIParent)
parent:SetSize(300, 100); parent:SetPoint("CENTER", UIParent, "CENTER", 0, 0); parent:Show()
local RULES = {}
local function disp(name, isDisplay)
  local f = CreateFrame("Frame", nil, parent); f:SetSize(10, 10); f:SetPoint("CENTER", parent, "CENTER", 0, 0); f:Show()
  f.fs = f:CreateFontString(nil, "OVERLAY"); f.fs:SetPoint("CENTER", f, "CENTER", 0, 0)
  if isDisplay then local r = { name = name }; RULES[#RULES + 1] = r; frames[r] = f end
  return f
end
local function Work() local x = 0; for k = 1, 120 do x = x + k end; return x end   -- (a real run: well above 300 Lua instructions)
local n = 0
-- A: no throttle, a change every run
local function LoopA(self) Work(); n = n + 1; self.fs:SetText("a" .. n) end --@A
-- B: throttled to 1/30 s, a change every run
local function LoopB(self, el) local a = (self.acc or 0) + el; if a < 0.033 then self.acc = a; return end; self.acc = 0; Work(); n = n + 1; self.fs:SetText("b" .. n) end --@B
-- C: throttled, writes the same text every run (changes nothing)
local function LoopC(self, el) local a = (self.acc or 0) + el; if a < 0.033 then self.acc = a; return end; self.acc = 0; Work(); self.fs:SetText("same") end --@C
-- D: throttled; its first run changes the text, the next changes nothing and takes the script off (the single detection run)
local function LoopD(self, el) --@D
  local a = (self.acc or 0) + el; if a < 0.033 then self.acc = a; return end; self.acc = 0; Work()
  local t = self.want or "same"
  if self.fs:GetText() == t then self:SetScript("OnUpdate", nil); return end
  self.fs:SetText(t)
end
-- F and G: two displays, one function, throttled, a change every run
local function LoopFG(self, el) local a = (self.acc or 0) + el; if a < 0.033 then self.acc = a; return end; self.acc = 0; Work(); n = n + 1; self.fs:SetText("fg" .. n) end --@FG
-- H: not a display (a driver frame), throttled to about 29 a second, a change every run
local function LoopH(self, el) local a = (self.acc or 0) + el; if a < 0.033 then self.acc = a; return end; self.acc = 0; Work(); n = n + 1; self.fs:SetText("h" .. n) end --@H
local fA, fB, fC, fD, fE, fF, fG, fH = disp("Probe A", true), disp("Probe B", true), disp("Probe C", true), disp("Probe D", true), disp("Probe E", true),
  disp("Probe F", true), disp("Probe G", true), disp("Probe H", false)
local fI = disp("Probe I", true)   -- (I: its script set 3 times, each time with nothing to animate: one detection run each time)
-- (round 9 repair 1) more frame-script probes
-- Z1: no throttle, cheap (no Work), a visible change on every frame (144 a second)
local function LoopZ1(self) self.k = (self.k or 0) + 1; self:SetAlpha((self.k % 100) / 100) end --@Z1
-- Z2: stays set the whole time, returns at once, changes nothing (an idle loop that has not stopped)
local function LoopZ2(self) if not self.active then return end end --@Z2
-- J31 / J30: exactly 31 / 30 runs in every 144 frames (one second at 144 frames a second), each a real run that changes the text
local function LoopJ31(self) local k = (self.k or 0) + 1; self.k = k; if math.floor(k * 31 / 144) == math.floor((k - 1) * 31 / 144) then return end; Work(); n = n + 1; self.fs:SetText("j" .. n) end --@J31
local function LoopJ30(self) local k = (self.k or 0) + 1; self.k = k; if math.floor(k * 30 / 144) == math.floor((k - 1) * 30 / 144) then return end; Work(); n = n + 1; self.fs:SetText("j" .. n) end --@J30
-- M: throttled; its first run changes the text, its next two runs change nothing (the second of them takes the script off): 2 idle runs
local function LoopM(self, el) --@M
  local a = (self.acc or 0) + el; if a < 0.033 then self.acc = a; return end; self.acc = 0; Work()
  self.k = (self.k or 0) + 1
  self.fs:SetText("m")
  if self.k >= 3 then self:SetScript("OnUpdate", nil) end
end
-- W130 / W160: returns at once on 129 / 159 frames, then a real run that changes the text (0.90 s / 1.10 s of skipped frames)
local function LoopW130(self) self.k = (self.k or 0) + 1; if self.k % 130 ~= 0 then return end; Work(); n = n + 1; self.fs:SetText("w" .. n) end --@W130
local function LoopW160(self) self.k = (self.k or 0) + 1; if self.k % 160 ~= 0 then return end; Work(); n = n + 1; self.fs:SetText("w" .. n) end --@W160
local fZ1, fZ2, fJ31, fJ30, fM, fW130, fW160 = disp("Probe Z1", true), disp("Probe Z2", true), disp("Probe J31", true), disp("Probe J30", true),
  disp("Probe M", true), disp("Probe W130", true), disp("Probe W160", true)
-- (round 9 repair 1) redraw timers (wake chains of C_Timer.After with a function made once); the play names WA, WB, WD, WD1, WE, WF as
-- redraw timers (REDRAWS), not WC
local tA, tB1, tB2, tC, tD, tD1, tE, tF = disp("Probe TA", true), disp("Probe TB1", true), disp("Probe TB2", true), disp("Probe TC", true),
  disp("Probe TD", true), disp("Probe TD1", true), disp("Probe TE", true), disp("Probe TF", true)
local fN = disp("Probe not a display", false)
tF.fs2 = tF:CreateFontString(nil, "OVERLAY"); tF.fs2:SetPoint("CENTER", tF, "CENTER", 0, 0)
local function WakeA() if not P.on or GetTime() > P.t1 then return end; n = n + 1; tA.fs:SetText("ta" .. n); C_Timer.After(0.025, WakeA) end --@WA
local function WakeB() if not P.on or GetTime() > P.t1 then return end; n = n + 1; tB1.fs:SetText("tb" .. n); tB2.fs:SetText("tb" .. n); C_Timer.After(1 / 14, WakeB) end --@WB
local function WakeC() if not P.on or GetTime() > P.t1 then return end; n = n + 1; tC.fs:SetText("tc" .. n); C_Timer.After(1 / 14, WakeC) end --@WC
local function WakeD() tD.k = (tD.k or 0) + 1; tD.fs:SetText("d1"); if tD.k < 3 then C_Timer.After(0.1, WakeD) end end --@WD
local function WakeD1() tD1.k = (tD1.k or 0) + 1; tD1.fs:SetText("d1"); if tD1.k < 2 then C_Timer.After(0.1, WakeD1) end end --@WD1
local function WakeE() if not P.on or GetTime() > P.t1 then return end; n = n + 1; tE.fs:SetText("te" .. n); fN.fs:SetText("te" .. n); C_Timer.After(1 / 14, WakeE) end --@WE
local function WakeF() if not P.on or GetTime() > P.t1 then return end; n = n + 1; tF.fs2:SetText("tf" .. n); C_Timer.After(1 / 6, WakeF) end --@WF
-- closures (SD-82): a one-off change event, fired 4 times
local function Noop() end
local ev1 = CreateFrame("Frame"); ev1:RegisterEvent("PLAYER_STARTED_LOOKING")
ev1:SetScript("OnEvent", function() C_Timer.After(0.05, function() Noop() end) end) --@K
local ev2 = CreateFrame("Frame"); ev2:RegisterEvent("PLAYER_STARTED_LOOKING")
ev2:SetScript("OnEvent", function() C_Timer.After(0.05, Noop) end) --@L
function P.start()
  fA:SetScript("OnUpdate", LoopA); fB:SetScript("OnUpdate", LoopB); fC:SetScript("OnUpdate", LoopC)
  fD.want = "d1"; fD:SetScript("OnUpdate", LoopD); fE.want = "e1"; fE:SetScript("OnUpdate", LoopD)
  fF:SetScript("OnUpdate", LoopFG); fG:SetScript("OnUpdate", LoopFG); fH:SetScript("OnUpdate", LoopH)
  fI.fs:SetText("same"); fI:SetScript("OnUpdate", LoopD)
  fZ1:SetScript("OnUpdate", LoopZ1); fZ2:SetScript("OnUpdate", LoopZ2); fJ31:SetScript("OnUpdate", LoopJ31); fJ30:SetScript("OnUpdate", LoopJ30)
  fM:SetScript("OnUpdate", LoopM); fW130:SetScript("OnUpdate", LoopW130); fW160:SetScript("OnUpdate", LoopW160)
  P.on, P.t1 = true, GetTime() + 1.85   -- (the chains' last run, which changes nothing, falls in the 2-second window of their other runs)
  tF:SetScript("OnUpdate", LoopB)
  C_Timer.After(0.025, WakeA); C_Timer.After(1 / 14, WakeB); C_Timer.After(1 / 14, WakeC); C_Timer.After(0.1, WakeD); C_Timer.After(0.1, WakeD1)
  C_Timer.After(1 / 14, WakeE); C_Timer.After(1 / 6, WakeF)
end
function P.again(k) fE.want = "e" .. k; fE:SetScript("OnUpdate", LoopD); fI:SetScript("OnUpdate", LoopD) end   -- (E: something to animate again; I: nothing)
function P.stop()
  P.on = false
  for _, f in ipairs({ fA, fB, fC, fD, fE, fF, fG, fH, fI, fZ1, fZ2, fJ31, fJ30, fM, fW130, fW160, tF }) do f:SetScript("OnUpdate", nil) end
  ev1:UnregisterAllEvents(); ev2:UnregisterAllEvents()
end
return P
'''

INSERT = r'''
if CFG.probeSrc then   -- (tests/fix_r9_gate_probe_run.py) the probe addon, played right after the window closed
  local PR = assert(loadstring(CFG.probeSrc, "@Interface/AddOns/XayaUI_Rules/GateProbe.lua"))()
  PR.start()
  for i = 1, 288 do
    if i == 100 then PR.again(2) elseif i == 200 then PR.again(3) end
    if i % 50 == 0 then CTX = "change"; W.fire("PLAYER_STARTED_LOOKING") end
    W.tick(1 / 144, 1)
  end
  PR.stop()
  W.tick(1 / 30, 30)
end
'''


def most_in_second(times):
    """The most moments in any sliding second (t - 1, t] (the test's own count, not the gate's)."""
    ts = sorted(float(t) for t in times)
    best, j = 0, 0
    for i, t in enumerate(ts):
        while ts[j] <= t - 1 + 1e-6:
            j += 1
        best = max(best, i - j + 1)
    return best


def lines_of(src):
    out = {}
    for n, line in enumerate(src.split("\n"), 1):
        m = re.search(r"--@(\w+)\s*$", line)
        if m:
            out[m.group(1)] = n
    return out


REDRAW_PROBES = ("WA", "WB", "WD", "WD1", "WE", "WF")   # (repair 1) the probe's wake chains the play names as redraw timers (not WC)


def play(tree=False, redraws=None):
    """The gate's scenario with the probe, as the measured play (tree=False) or the tree play (tree=True: pace per pass, call counts and,
    round 9 repair 1, the listed redraw timers per display, redraws = {"file:line": True})."""
    scen = GC.SCENARIO_LUA
    if scen.count(MARKER) != 1:
        raise SystemExit("the marker %r is not in tests/gate_common.py once; this test needs updating" % MARKER)
    scen = scen.replace(MARKER, MARKER + "\n" + INSERT, 1)
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    world, loader, game, sv = GC._world(L)
    cfg = H.to_lua(L, {"perf": True, "verbose": False, "busy": 1.0, "probeSrc": PROBE_SRC, "tree": bool(tree), "redraws": redraws or {}})
    res = L.eval("function(src, W, Ld, G, C) return loadstring(src)()(W, Ld, G, C) end")(scen, world, loader, game, cfg)
    return json.loads(json.dumps(H.lua_to_py(res), default=str))


def play_both():
    """The measured play and the tree play, merged as tests/gate_common.py result() merges them (pace and redraw timers from the tree
    play), with the probe's redraw timers named."""
    import concurrent.futures
    ln = lines_of(PROBE_SRC)
    rl = {"%s:%d" % (PROBE_FILE, ln[k]): [k, "probe redraw timer " + k] for k in REDRAW_PROBES}
    with concurrent.futures.ProcessPoolExecutor(2) as ex:
        fm = ex.submit(play)
        ft = ex.submit(play, True, {k: True for k in rl})
        data, tdata = fm.result(), ft.result()
    data["pace"], data["paceAny"], data["paceTree"] = tdata.get("pace"), tdata.get("paceAny"), True
    data["fxRedraw"] = tdata.get("fxRedraw") or {}
    data["redrawLines"] = rl
    return data


def run_main(mod, data, ddata=None, base=None):
    """A gate's main() on the given result(s): data for the default variant, ddata (or data) for "debug"."""
    saved = (GC.result, GC.v33_baseline)
    GC.result = lambda variant="default", *a, **k: ((ddata if (variant == "debug" and ddata is not None) else data), 0, True)
    GC.v33_baseline = lambda *a, **k: (base, "not played (tests/fix_r9_gate_probe_run.py)")
    if hasattr(GP, "_BASE"):
        del GP._BASE[:]
    buf = io.StringIO()
    try:
        with contextlib.redirect_stdout(buf):
            mod.main()
    finally:
        GC.result, GC.v33_baseline = saved
        if hasattr(GP, "_BASE"):
            del GP._BASE[:]
    return buf.getvalue()


def findings(text):
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
    data = play_both()
    check(int(data.get("errors") or 0) == 0, "the scenario with the probe ran without a Lua error", "; ".join(data.get("errorText") or [])[:300])
    owners = [o for o in GP.vals(data.get("owners")) if isinstance(o, dict)]
    by = {o.get("rule"): o for o in owners if o.get("rule")}
    check(bool(owners), "display: the result keeps frame-script runs per frame they run on (round 9; before, per script line only)")
    text = run_main(GP, data)
    fs = findings(text)

    def at(where, pattern, kind="FAIL"):
        return [f for f in fs if f[0] == kind and f[1].split(" ")[0] == where and re.search(pattern, f[2])]
    over = r"SD-79 a display's effects loop ran more than 30 times within one second"
    idle = r"SD-79 / P1 a display's effects loop ran while it changed nothing on screen"
    a = by.get("Probe A") or {}
    check(int(a.get("most") or 0) == 144, "display: the loop with no throttle runs 144 times in one second at 144 frames a second",
          "most %s" % a.get("most"))
    hit = at(src["A"], over)
    check(bool(hit) and "'Probe A'" in hit[0][2], "display: that loop FAILs at its line: more than 30 runs in one second on one display")
    b = by.get("Probe B") or {}
    check(int(b.get("most") or 0) in (28, 29) and int(b.get("skips") or 0) > 0,
          "display: the loop throttled to 1/30 s runs 28-29 times a second, and the frames between its runs are skips, not runs",
          "most %s skips %s" % (b.get("most"), b.get("skips")))
    check(not [f for f in fs if f[1].split(" ")[0] == src["B"]], "display: the throttled loop that changes the screen every run is not a finding")
    hit = at(src["C"], idle)
    check(bool(hit) and "'Probe C'" in hit[0][2], "display: a loop whose runs change nothing FAILs (beyond the single run that finds nothing to do)")
    d, e = by.get("Probe D") or {}, by.get("Probe E") or {}
    check(int(d.get("runs") or 0) == 2 and int(d.get("idle") or 0) == 1,
          "display: the loop that changes once, then finds nothing to do and takes its script off, ran twice (one detection run)",
          "runs %s idle %s" % (d.get("runs"), d.get("idle")))
    check(int(e.get("runs") or 0) == 6 and int(e.get("attaches") or 0) == 3,
          "display: the loop set again twice with something new to animate ran 2 runs each time (3 times)", "runs %s attaches %s" % (e.get("runs"), e.get("attaches")))
    i9 = by.get("Probe I") or {}
    check(int(i9.get("runs") or 0) == 3 and int(i9.get("idle") or 0) == 3 and int(i9.get("attaches") or 0) == 3,
          "display: the loop set 3 times with nothing to animate ran one detection run each time", "runs %s idle %s attaches %s" % (
              i9.get("runs"), i9.get("idle"), i9.get("attaches")))
    check(any(o.get("src") == src["D"] for o in (d, e, i9)) and not [f for f in fs if f[1].split(" ")[0] == src["D"]],
          "display: a loop that stops after its single detection run is not a finding, also when its script is set again later (E, I)")
    fg = [o for o in owners if o.get("rule") in ("Probe F", "Probe G")]
    check(len(fg) == 2 and all(int(o.get("most") or 0) in (28, 29) for o in fg),
          "display: two displays that share one function are counted each on its own (28-29 a second each, not 57 together)",
          "%s" % [(o.get("rule"), o.get("most")) for o in fg])
    check(not [f for f in fs if f[1].split(" ")[0] == src["FG"]], "display: those two displays are not a finding")
    h = [o for o in owners if not o.get("display") and o.get("src") == src["H"]]
    check(bool(h) and bool(at(src["H"], r"P2 a frame script \(OnUpdate\) ran more than 10 times within one second")),
          "display: a frame that is not a display, at 28-29 a second, is still a P2 FAIL (10 a second for a re-check path, SD-78)")
    # ---- (round 9 repair 1) frame scripts: a cheap loop that changes the screen, a script left set that only skips, the 30/31 and the
    # 1/2-idle-run boundaries, the 1-second wait boundary
    wait = r"SD-79 / P1 a display's frame script stays set while it changes nothing and does no work for more than a second"
    z1 = by.get("Probe Z1") or {}
    check(int(z1.get("most") or 0) == 144 and bool([f for f in at(src["Z1"], over) if "'Probe Z1'" in f[2]]),
          "display (repair 1): a cheap loop with no throttle that changes the screen on every frame counts every run (144 in one second) "
          "and FAILs (before: all skips, no finding)", "most %s runs %s skips %s" % (z1.get("most"), z1.get("runs"), z1.get("skips")))
    z2 = by.get("Probe Z2") or {}
    check(int(z2.get("runs") or 0) == 0 and bool([f for f in at(src["Z2"], wait) if "'Probe Z2'" in f[2]]),
          "display (repair 1): a script left set that returns at once and changes nothing FAILs: the loop is idle and has not stopped "
          "(before: all skips, no finding)", "runs %s skips %s waits %s" % (z2.get("runs"), z2.get("skips"), z2.get("waits")))
    j31, j30 = by.get("Probe J31") or {}, by.get("Probe J30") or {}
    check(int(j31.get("most") or 0) == 31 and bool(at(src["J31"], over)),
          "display (repair 1): exactly 31 runs in one second FAILs (her limit 30)", "most %s" % j31.get("most"))
    check(int(j30.get("most") or 0) == 30 and not [f for f in fs if f[1].split(" ")[0] == src["J30"]],
          "display (repair 1): exactly 30 runs in one second is not a finding", "most %s" % j30.get("most"))
    m2 = by.get("Probe M") or {}
    check(int(m2.get("runs") or 0) == 3 and int(m2.get("idle") or 0) == 2 and bool([f for f in at(src["M"], idle) if "'Probe M'" in f[2]]),
          "display (repair 1): a loop whose run changes the screen once and then runs twice changing nothing (2 idle runs, then stops) "
          "FAILs (one idle run is allowed: Probe D)", "runs %s idle %s" % (m2.get("runs"), m2.get("idle")))
    w130, w160 = by.get("Probe W130") or {}, by.get("Probe W160") or {}
    check(int(w130.get("runs") or 0) == 2 and not [f for f in fs if f[1].split(" ")[0] == src["W130"]],
          "display (repair 1): a script that skips 129 frames (0.90 s) between real runs that change the screen is not a finding",
          "runs %s waits %s" % (w130.get("runs"), w130.get("waits")))
    check(int(w160.get("runs") or 0) == 1 and bool([f for f in at(src["W160"], wait) if "'Probe W160'" in f[2]]),
          "display (repair 1): a script that skips 159 frames (1.10 s) before its real run FAILs (set, idle, not stopped)",
          "runs %s waits %s" % (w160.get("runs"), w160.get("waits")))
    # ---- (round 9 repair 1) redraw timers, per display
    fr = data.get("fxRedraw") or {}
    redr = r"SD-79 a display was redrawn more than 30 times within one second by this redraw timer and its frame script together"
    p2t = r"P2 a timer callback ran more than 10 times within one second"
    ta = ((fr.get(src["WA"]) or {}).get("disp") or {}).get("Probe TA") or {}
    check(most_in_second(GP.vals(ta.get("times"))) > 30 and bool([f for f in at(src["WA"], redr) if "'Probe TA'" in f[2]]),
          "redraw (repair 1): a redraw timer that redraws one display 36 times a second FAILs per display (SD-79, 30 a second)",
          "most %s" % most_in_second(GP.vals(ta.get("times"))))
    tb = (fr.get(src["WB"]) or {}).get("disp") or {}
    check(sorted(tb) == ["Probe TB1", "Probe TB2"] and all(10 < most_in_second(GP.vals(d.get("times"))) <= 30 for d in tb.values()) and
          not [f for f in fs if f[1].split(" ")[0] == src["WB"]],
          "redraw (repair 1): a redraw timer that redraws two displays 13-14 times a second each is not a finding (judged per display, "
          "not under P2's 10 a second per callback)", "%s" % {k: most_in_second(GP.vals(d.get("times"))) for k, d in tb.items()})
    check(bool(at(src["WC"], p2t)),
          "redraw (repair 1): the same chain NOT named as a redraw timer is still a P2 FAIL (more than 10 a second) "
          "(control: passes before and after the repair)")
    td, td1 = fr.get(src["WD"]) or {}, fr.get(src["WD1"]) or {}
    idt = r"SD-79 a redraw timer ran twice or more in a row changing nothing on screen"
    check(int(td.get("idle") or 0) == 2 and bool(at(src["WD"], idt)),
          "redraw (repair 1): a redraw timer that runs twice in a row changing nothing FAILs", "idle %s" % td.get("idle"))
    check(int(td1.get("idle") or 0) == 1 and not [f for f in fs if f[1].split(" ")[0] == src["WD1"]],
          "redraw (repair 1): one run that changes nothing (it finds nothing left and stops) is not a finding", "idle %s" % td1.get("idle"))
    te = fr.get(src["WE"]) or {}
    check(int(te.get("outside") or 0) > 0 and bool(at(src["WE"], p2t)),
          "redraw (repair 1): a named redraw timer that also changes a frame that is not a display stays under P2 (10 a second) and FAILs",
          "outside %s" % te.get("outside"))
    tf = ((fr.get(src["WF"]) or {}).get("disp") or {}).get("Probe TF") or {}
    hit = [f for f in at(src["WF"], redr) if "'Probe TF'" in f[2]]
    check(bool(hit) and most_in_second(GP.vals(tf.get("times"))) <= 30 and re.search(r"its frame script alone (2[89])\b", hit[0][2]) is not None,
          "redraw (repair 1): a display whose frame script runs 28-29 a second and a redraw timer 6 a second (each under 30 alone) FAILs: "
          "counted per display together", hit[0][2][:300] if hit else "")
    # closures (SD-82)
    hit = at(src["K"], r"P4 a new function per timer call \(outside the hot path")
    check(bool(hit), "closure: a one-off change event's handler that makes a closure per timer call FAILs (SD-82; round 8: a WARNING)")
    check(not [f for f in fs if f[1].split(" ")[0] == src["L"] and re.search(r"new function per timer call", f[2])],
          "closure: the handler that passes a function made once is not a finding")

    # ---- synthetic results ------------------------------------------------------------------------------------------------------
    caps = GP.V33_EVENT_CAPS["caps"]
    rcap = caps["every"]["XayaUI_Rules"]

    def budget(debug_peak=None, rules_fight=None, moments=None, end_peak=None):
        b = {}
        for s in ("fight 1", "fight 2", "fight 3", "end 1", "end 2", "end 3"):
            seg = {"frames": 450 if s.startswith("fight") else 30, "work": {"XayaUI_Rules": 1}, "peak": {"XayaUI_Rules": 1}}
            if s.startswith("fight") and rules_fight is not None:
                seg["peak"]["XayaUI_Rules"] = rules_fight
            if s.startswith("end") and end_peak is not None:
                seg["peak"]["XayaUI_Rules"] = end_peak
                seg["moments"] = {"combat end": {"XayaUI_Rules": end_peak}}
            if s == "fight 2" and moments:
                seg["moments"] = moments
            if debug_peak is not None:
                seg["work"]["XayaUI_Debug"] = 1
                seg["peak"]["XayaUI_Debug"] = debug_peak
            b[s] = seg
        return b
    stamp = GC.scenario_stamp
    GC.scenario_stamp = lambda: GP.V33_EVENT_CAPS["stamp"]
    try:
        def fs_of(d):
            return findings(run_main(GP, d))
        dbg = r"V33 per-event limit: XayaUI_Debug's costliest single fight frame is above her cap of 600"
        check(any(f[0] == "FAIL" and re.search(dbg, f[2]) for f in fs_of({"budget": budget(debug_peak=601), "debugLoaded": True})),
              "debug: XayaUI_Debug's costliest fight frame at 601 instructions FAILs (SD-81 \"600, same as core\")")
        check(not any(re.search(dbg, f[2]) for f in fs_of({"budget": budget(debug_peak=600), "debugLoaded": True})),
              "debug: at 600 it is not a finding")
        mo = r"V33 per-event limit \(SD-77\): XayaUI Rules's costliest frame at a boss pull"
        check(any(f[0] == "FAIL" and re.search(mo, f[2]) for f in fs_of({"budget": budget(moments={"boss pull": {"XayaUI_Rules": rcap + 1}})})),
              "moments: a boss-pull frame one instruction above XayaUI Rules' cap (%d) FAILs on its own line" % rcap)
        check(not any(re.search(mo, f[2]) for f in fs_of({"budget": budget(moments={"boss pull": {"XayaUI_Rules": rcap}})})),
              "moments: a boss-pull frame at the cap is not a finding")
        ce = fs_of({"budget": budget(end_peak=rcap + 1)})
        check(any(f[0] == "FAIL" and re.search(r"costliest frame at combat end is heavier", f[2]) for f in ce) and
              any(f[0] == "FAIL" and re.search(r"V33 per-event limit: XayaUI Rules's costliest single fight frame", f[2]) for f in ce),
              "moments: a combat-end frame (the \"end N\" segment) one instruction above the cap FAILs, on its own line and in the segment cap")
        # memory
        meas = {"mem": [34000.0, 34150.0, 34300.0], "memEnd": 34300.0}
        flat = dict(meas, memAddons={"mem": [33000.0, 33002.0, 33004.0], "memEnd": 33004.0})
        grow = dict(meas, memAddons={"mem": [33000.0, 33040.0, 33080.0], "memEnd": 33080.0})
        mw = r"grows every cycle"
        check(not any(re.search(mw, f[2]) for f in fs_of(flat)),
              "memory: no growth WARNING when the addons' own memory (the memory play) is flat although the measured play grows 150 KB a cycle")
        g = [f for f in fs_of(grow) if f[0] == "WARNING" and re.search(r"the addons' Lua memory grows every cycle", f[2])]
        check(bool(g) and re.search(r"\+40\.0 KB, \+40\.0 KB per cycle", g[0][2]) is not None,
              "memory: a WARNING naming the addons' own growth (+40.0 KB a cycle) when they grow", g[0][2][:300] if g else "")
        # label (item 8)
        rec = GP.V33_RECORDED
        GC.scenario_stamp = lambda: rec["stamp"]
        lab = run_main(GP, {"budget": budget()}, base=None)
        m = re.search(r"the budget uses the calibration recorded ([^\n]*?) for this same scenario", lab)
        check(bool(m) and "when" in rec and m.group(1) == rec["when"] and ("round 7" not in m.group(1) or "round 7" in rec["when"]),
              "label: the calibration line names the true source of the recorded value (%r), not round 7" % rec.get("when"), m.group(0) if m else "")
    finally:
        GC.scenario_stamp = stamp
    # variants: gate_mouse and gate_keyboard judge the Advanced Debugging variant too
    clean = {"checkpoints": [{"label": "x", "combat": True, "mouse": [], "keyboard": [], "keys": [], "focus": []}], "variant": "default"}
    kb = json.loads(json.dumps(clean))
    kb["variant"] = "debug"
    kb["checkpoints"][0]["keyboard"] = [{"name": "DebugBox", "kind": "EditBox", "where": "XayaUI_Debug/Console.lua:10", "by": "XayaUI_Debug/Console.lua:12 EnableKeyboard(true)"}]
    kt = findings(run_main(GK, clean, kb))
    check(any(f[0] == "FAIL" and f[1].startswith("[Advanced Debugging on] XayaUI_Debug/Console.lua:12") for f in kt) and
          not any(f[1].startswith("XayaUI_Debug/Console.lua:12") for f in kt),
          "variants: gate_keyboard FAILs a keyboard-enabled frame shown only with Advanced Debugging on, tagged with that variant")
    ms = json.loads(json.dumps(clean))
    ms["variant"] = "debug"
    ms["checkpoints"][0]["mouse"] = [{"name": "DebugPane", "kind": "Frame", "where": "XayaUI_Debug/Console.lua:20", "by": "XayaUI_Debug/Console.lua:21 EnableMouse(true)",
                                      "w": 200, "h": 100, "frac": 0.01, "strata": "HIGH", "top": "DebugPane", "topWhere": "XayaUI_Debug/Console.lua:20"}]
    mt = findings(run_main(GM, clean, ms))
    check(any(f[0] == "FAIL" and f[1].startswith("[Advanced Debugging on] XayaUI_Debug/Console.lua:21") for f in mt),
          "variants: gate_mouse FAILs a frame that takes clicks only with Advanced Debugging on, tagged with that variant")
    print("%d checks, %d failed" % (len(done), len(fails)))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
