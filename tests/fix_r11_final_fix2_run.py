#!/usr/bin/env python3
"""Round 11b final fix 2: what tests/gate_performance_run.py judges for her memory cap and for the per-event caps of the small addons
(REQUEST-LOG SD-120 "yes"; SD-66 her memory cap "Today +15%, tighten later (Recommended)": 39,959.7 KB = 34,747.6 KB x 1.15; SD-81 her
XayaUI_Debug cap "600, same as core (Recommended)").

Found (round 11b final review, gate_performance on the committed snapshot, XUI_GATE_NOCACHE=1, stand-in numbers):
  memory  the Advanced Debugging variant read 40,140.9 / 40,331.8 / 40,518.6 KB and 40,762.2 KB idle, over the cap by 181.2 to 802.5 KB,
          while the memory play of the same scenario (the addons and the stand-in, with nothing of the gate's kept) read 39,091.1 to
          39,107.9 KB. The difference is the gate's own records and instruments (about 1,050 KB at the end of cycle 1, growing about 186 KB
          a cycle in the key fight): the measuring apparatus, never memory the addons use in the game. The cap is now judged on the memory
          play's readings (the measured play's whole state is printed beside it, with the records' size).

What is checked (synthetic gate results through this checkout's gate_performance memory(); no scenario is played):
  M1  the measured play over the cap and the memory play under it: no memory-budget FAIL; the note names the memory play as what is judged
      and prints the measured play's whole state and the gate's records (1,050.0 KB at the end of cycle 1 here). Fails before this change
      (the measured play was judged).
  M2  the memory play over the cap (39,959.8 KB at the end of cycle 2, 0.1 KB above): a FAIL that says it was read in the memory play;
      39,959.7 KB itself is not a FAIL.
  M3  no memory play in the result and no other play either (XUI_GATE_NOTREE=1, an old build): the measured play is judged, as before
      (39,959.8 KB is a FAIL that says the gate's own records are included).
  M4  the other plays ran (paceTree) but the result has no memory play: a FAIL that says MISSING INPUT (never a silent pass).
  M5  the idle reading is judged too (memory play idle 39,960.0 KB: a FAIL naming "after 30 s idle").
  logger  counted in the measured play's 100-instruction steps, XayaUI_Debug's costliest fight frame read 600 to 800 from one play to the
          next with the same code (cap 600, SD-81): its frames are several runs of about 20 to 190 instructions, each read 0 or 100 per
          step, with the gate's own pcall wrapper inside every run. Counted one by one in the same key fight: 593 with the wrapper. The
          gate now counts the addons held to her own fixed 600 exactly and takes its own window instructions out (gate_common.py KF.EXACT,
          KF.OVER); measured: costliest 417 in a fight, 479 at a combat end (Advanced Debugging on), KF.OVER 17.
What is checked on the gate's own counting code (taken verbatim from gate_common.py SCENARIO_LUA and run in Lua 5.1, no scenario):
  E1  KF.EXACT holds exactly the addons with her own fixed per-event caps (gate_performance DEBUG_EVENT_CAP and BONUS_EVENT_CAPS) and none
      of the addons whose caps are ad60a051's readings (V33_EVENT_CAPS). Fails before this change (no KF.EXACT).
  E2  an exact run reads a function's own instructions exactly, the gate's wrapper taken out: functions of 2, 37 and 152 instructions
      read 2, 37 and 152 (KF.OVER measured by KF.calib, as the gate's measured play does at its start).
  E3  the step readings of the other addons stay unbiased after exact runs: 4,000 runs of a 37-instruction function counted in steps,
      each right after an exact run, average 37 + KF.OVER (the window the never-switched hook also reads) within 6, every reading a
      multiple of 100. With the step counter left restarted at a full step after each exact run (no burn), the same runs average 0:
      the mutant is caught.
  E4  the gate reports KF.OVER (OUT.exactOver) and switches to exact counting only in the measured play (KF.on is set where the measured
      play's hook is set, never in the tree play).
Stand-in only: UNVERIFIED IN GAME (nothing here runs in the game).
Run: python3 tests/fix_r11_final_fix2_run.py   (a few seconds; Lua 5.1 via lupa, no scenario)"""
import os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gate_common as GC  # noqa: E402
import gate_performance_run as GP  # noqa: E402
import lupa.lua51 as LUA  # noqa: E402

CAP = 39959.7


def judge(data):
    """GP.memory on a synthetic result: (fails, notes) as text."""
    rep = GC.Report("gate_performance")
    GP.memory(data, rep)
    return ["%s | %s | %s" % (w, what, num) for w, what, num, _ in rep.fails], rep.notes


def counting_code():
    """The gate's counting code, verbatim from SCENARIO_LUA, around a measure(src, fn, ...) that is run()'s window. None when this
    checkout's gate has no exact counting (before round 11b final fix 2)."""
    S = GC.SCENARIO_LUA

    def grab(pattern):
        m = re.search(pattern, S, re.S | re.M)
        return m.group(0) if m else None
    parts = {
        "callhook": grab(r"^local function callhook\(ev\).*?\n  if ev == \"count\" then INS = INS \+ 1; return end\nend\n"),
        "quietRun": grab(r"^local quietRun = function\(fn, \.\.\.\)\n.*?\n  return ok\nend\n"),
        "exact": grab(r"^KF\.EXACT = \{[^\n]*\}\nKF\.on, KF\.OVER, KF\.seed = [^\n]*\nfunction KF\.phase\(\)[^\n]*\n"),
        "window": grab(r"^  local ex = KF\.on and KF\.EXACT\[addonOf\(src\)\].*?^  local ins = ex and KF\.exactDone\(n\) or n \* INS_STEP[^\n]*\n"),
        "helpers": grab(r"^function KF\.burn\(\).*?^function KF\.exactDone\(n\)\n.*?^end\n"),
        "start": grab(r"^  KF\.on, KF\.OVER = true, KF\.calib\(function\(\) end\) - 1\n"),
    }
    if not all(parts.values()):
        return None, [k for k, v in parts.items() if not v]
    chunk = ("local KF = {}\nlocal INS, INS_STEP = 0, 100\nlocal gc = collectgarbage\nlocal W = { errors = {} }\n" + parts["callhook"] +
             parts["quietRun"] + parts["exact"] + "local function addonOf(src) return src end\n"
             "local function measure(src, fn, ...)\n" + parts["window"] + "  return ins\nend\n" + parts["helpers"] +
             "local function start()\n  debug.sethook(callhook, \"\", INS_STEP)\n" + parts["start"] + "end\n"
             "return { KF = KF, measure = measure, start = start, stop = function() debug.sethook() end }\n")
    return chunk, []


def main():
    fails, n = [], [0]

    def check(ok, what, detail=""):
        n[0] += 1
        print(("ok   " if ok else "FAIL ") + what + (("  [" + detail[:400] + "]") if (detail and not ok) else ""))
        if not ok:
            fails.append(what)

    check(abs(getattr(GP, "MEM_CAP_KB", 0) - CAP) < 1e-9, "her cap is unchanged: 34,747.6 KB x 1.15 = 39,959.7 KB (SD-66)",
          "MEM_CAP_KB %s" % getattr(GP, "MEM_CAP_KB", None))

    # M1: the measured play (with the gate's records) over the cap, the memory play under it
    meas = {"mem": [40140.9, 40331.8, 40518.6], "memEnd": 40762.2, "paceTree": True,
            "memAddons": {"mem": [39090.9, 39101.9, 39107.9], "memEnd": 39103.0, "errors": 0}}
    f1, n1 = judge(meas)
    mem_fails = [f for f in f1 if "memory budget" in f]
    check(not mem_fails, "M1 the measured play over the cap (the gate's records included) and the memory play under it: no memory-budget FAIL",
          "; ".join(mem_fails))
    judged = [t for t in n1 if t.startswith("memory budget:")]
    check(bool(judged) and "read in the memory play" in judged[0] and "headroom 851.8 KB" in judged[0],
          "M1 the note says the memory play is what is judged, with its headroom (39,959.7 - 39,107.9 = 851.8 KB)", " / ".join(judged))
    whole = [t for t in n1 if t.startswith("memory, the measured play's whole Lua state")]
    check(bool(whole) and "40,762.2 KB" in whole[0] and "1,050.0" in whole[0] and "printed, not judged" in whole[0],
          "M1 the measured play's whole state is printed beside it, with the gate's records (40,140.9 - 39,090.9 = 1,050.0 KB at cycle 1)",
          " / ".join(whole))

    # M2: the memory play over the cap by 0.1 KB; the cap itself is not over
    over = {"mem": [38000.0, 38100.0, 38200.0], "memEnd": 38300.0, "paceTree": True,
            "memAddons": {"mem": [39000.0, 39959.8, 39000.0], "memEnd": 39000.0, "errors": 0}}
    f2, _ = judge(over)
    check(any("memory budget" in f and "read in the memory play" in f and "end of cycle 2 by 0.1 KB" in f for f in f2),
          "M2 the memory play 39,959.8 KB at the end of cycle 2 is a FAIL read in the memory play, over by 0.1 KB", "; ".join(f2))
    at = {"mem": [38000.0, 38100.0, 38200.0], "memEnd": 38300.0, "paceTree": True,
          "memAddons": {"mem": [39000.0, 39959.7, 39000.0], "memEnd": 39000.0, "errors": 0}}
    f2b, _ = judge(at)
    check(not [f for f in f2b if "memory budget" in f], "M2 39,959.7 KB in the memory play (the cap itself) is not a FAIL", "; ".join(f2b))

    # M3: an old build's play (no memory play, no other play): the measured play's whole state, as before
    old = {"mem": [34000.0, 34100.0, 39959.8], "memEnd": 34000.0}
    f3, _ = judge(old)
    check(any("memory budget" in f and "gate's own records included" in f for f in f3),
          "M3 no memory play (an old build, XUI_GATE_NOTREE=1): the measured play's 39,959.8 KB is a FAIL that says the gate's records count",
          "; ".join(f3))

    # M4: the other plays ran, the memory play is missing
    miss = {"mem": [38000.0, 38100.0, 38200.0], "memEnd": 38300.0, "paceTree": True, "memAddons": {}}
    f4, _ = judge(miss)
    check(any("MISSING INPUT" in f and "memory play" in f for f in f4),
          "M4 the other plays ran but there is no memory play: a FAIL that says MISSING INPUT", "; ".join(f4))

    # M5: the idle reading is judged
    idle = {"mem": [38000.0, 38100.0, 38200.0], "memEnd": 38300.0, "paceTree": True,
            "memAddons": {"mem": [39000.0, 39001.0, 39002.0], "memEnd": 39960.0, "errors": 0}}
    f5, _ = judge(idle)
    check(any("memory budget" in f and "after 30 s idle by 0.3 KB" in f for f in f5),
          "M5 the memory play's idle reading 39,960.0 KB is a FAIL naming 'after 30 s idle', over by 0.3 KB", "; ".join(f5))

    # ---- the gate's exact counting (round 11b final fix 2) ---------------------------------------------------------------------------
    chunk, missing = counting_code()
    fixed = set(getattr(GP, "DEBUG_EVENT_CAP", {})) | set(getattr(GP, "BONUS_EVENT_CAPS", {}))
    calibrated = set((((getattr(GP, "V33_EVENT_CAPS", {}) or {}).get("caps") or {}).get("every") or {}))
    if chunk is None:
        check(False, "E1 the gate's exact counting code is in SCENARIO_LUA (KF.EXACT, run()'s window, KF.calib, KF.exactDone)",
              "missing: %s" % ", ".join(missing))
        for e in ("E2", "E3"):
            check(False, e + " (no exact counting in this checkout's gate)")
    else:
        L = LUA.LuaRuntime(unpack_returned_tuples=True)
        G = L.execute(chunk)
        exact = set(k for k in G.KF.EXACT.keys())
        check(exact == fixed and not (exact & calibrated) and len(fixed) == 3,
              "E1 KF.EXACT is exactly her fixed-cap addons (%s) and none of the ad60a051-calibrated ones (%s)" % (
                  ", ".join(sorted(fixed)), ", ".join(sorted(calibrated))), "KF.EXACT %s" % sorted(exact))
        fn = L.eval("function(m) local src = 'local a = 0\\n' .. string.rep('a = a + 1\\n', m); return assert(loadstring(src)) end")
        G.start()
        over = G.KF.OVER
        reads = [(m + 2, G.measure("XayaUI_Debug", fn(m))) for m in (0, 35, 150)]
        G.stop()
        check(all(r == want for want, r in reads) and 5 <= over <= 60,
              "E2 an exact run reads a function's own instructions, the gate's wrapper (KF.OVER %s) taken out: %s" % (
                  over, ", ".join("%d reads %d" % wr for wr in reads)), "reads %s" % reads)
        f37 = fn(35)

        def after_exact(g):
            """4,000 step readings of the 37-instruction function, each right after an exact run (as a logger run is followed by
            another addon's handler in a fight frame)."""
            g.start()
            vals = []
            for _ in range(4000):
                g.measure("XayaUI_Debug", f37)
                vals.append(g.measure("XayaUI_Rules", f37))
            g.stop()
            return vals
        # a step reading counts the whole window: the function's 37 instructions and the gate's own wrapper (KF.OVER), as the gate's
        # never-switched hook always has (the steps are not corrected: their caps were read the same way); unbiased = 37 + KF.OVER
        want = 37 + over
        v = after_exact(G)
        mean = sum(v) / float(len(v))
        check(abs(mean - want) <= 6 and all(int(x) % 100 == 0 for x in v),
              "E3 after exact runs the step readings stay unbiased: 4,000 step readings of a 37-instruction window (+ the gate's %d) average "
              "%.1f, within 6 of %d, every reading a multiple of 100" % (over, mean, want), "mean %.2f" % mean)
        # the mutant: the step counter left restarted at a full step after each exact run (KF.burn without its burn)
        M = L.execute(chunk)
        L.execute("local KF = ...; KF.burn = function() debug.sethook(debug.gethook(), '', 100) end", M.KF)
        mv = after_exact(M)
        mmean = sum(mv) / float(len(mv))
        check(mmean < 10, "E3 mutant caught: with the step counter left restarted at a full step after each exact run (no burn) the same "
              "readings average %.1f, far below %d" % (mmean, want), "mutant mean %.2f" % mmean)
    S = GC.SCENARIO_LUA
    check("OUT.exactOver = KF.OVER" in S and re.search(r"if PERF and not CFG\.nohook and not CFG\.tree then\n  debug\.sethook\(callhook, \"\", "
                                                     r"INS_STEP\)\n(?:  --[^\n]*\n)*  KF\.on, KF\.OVER = true", S) is not None,
          "E4 the gate reports KF.OVER and turns exact counting on only where the measured play's hook is set (not in the tree play)")

    print("%d checks, %d failed" % (n[0], len(fails)))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
