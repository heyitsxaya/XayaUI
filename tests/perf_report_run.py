"""tools/perf_report.py (REQUEST-LOG A15 P-5, "File + report tool"): reads a SavedVariables file in the game's format and reports
runs, fights (boss / trash), engine timing, the per-addon meter, slowest rules and what to look at first.
The fixture below is written the way the game writes SavedVariables (["key"] = value, "-- [n]" index comments, escaped quotes);
its numbers are stand-ins, not measurements.
Run: python3 tests/perf_report_run.py"""
import os, sys, tempfile
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
sys.path.insert(0, os.path.join(ROOT, "tools"))
import perf_report as PR

FIX = r'''
CueRulesDB = {
["ui"] = {
["advancedDebug"] = true,
["recordMax"] = 10000,
},
["debugRecord"] = {
["dropped"] = 0,
["started"] = "2026-11-07 20:00:00",
["lines"] = {
"20:00:01  Game     now in: Dornogal", -- [1]
"20:01:00  Note     ---------- recorded run starts: Skyreach (Mythic+, instance 1209) ----------", -- [2]
"20:01:00  Perf     meter run start | XayaUI sess=0.0100 recent=0.0100 enc=0.0000 peak=0.500 n5=0 n10=0 n50=0 n100=0", -- [3]
"20:02:00  Combat   ---------- combat 1 starts | Skyreach ----------", -- [4]
"20:02:30  Combat   ---------- combat 1 ends after 30 s ----------", -- [5]
"20:02:30  Perf     perf over 30s: 150 steps (5.0/s), 0.12 ms avg, 1.10 ms worst, 0.1% of one frame budget at 60 fps (12 rules, 10 on)", -- [6]
"20:02:30  Perf     perf: per second: rules 0.40 ms, visuals 0.10 ms, bars 0.05 ms, per-frame effects 0.02 ms (40 calls)", -- [7]
"20:02:30  Perf     perf: #1 0.30 ms/s  Rule \"A\"", -- [8]
"20:02:30  Perf     perf: Lua memory 2048 KB now, +3 KB/s since start (a high number means garbage)", -- [9]
"20:02:30  Perf     meter combat 1 | XayaUI sess=0.0200 recent=0.0300 enc=0.0000 peak=1.200 n5=0 n10=0 n50=0 n100=0", -- [10]
"20:02:30  Perf     meter combat 1 | XayaUI_Bonus sess=0.0050 recent=0.0040 enc=0.0000 peak=0.300 n5=0 n10=0 n50=0 n100=0", -- [11]
"20:02:30  Perf     meter combat 1 | (all addons) sess=0.9000 recent=1.0000 enc=0.0000 peak=9.000 n5=3 n10=1 n50=0 n100=0", -- [12]
"20:05:00  Combat   ---------- combat 2 starts | Skyreach ----------", -- [13]
"20:05:01  Game     boss encounter 1698 'Ranjit' starts (difficulty 8, 5 players)", -- [14]
"20:06:30  Game     boss encounter 1698 'Ranjit' ends: kill (difficulty 8, 5 players)", -- [15]
"20:06:30  Perf     meter boss 1698 | XayaUI sess=0.0250 recent=0.0500 enc=0.0600 peak=20.000 n5=1 n10=1 n50=0 n100=0", -- [16]
"20:06:31  Combat   ---------- combat 2 ends after 91 s ----------", -- [17]
"20:06:31  Perf     perf over 91s: 600 steps (6.6/s), 0.30 ms avg, 18.40 ms worst, 0.3% of one frame budget at 60 fps (12 rules, 10 on)", -- [18]
"20:06:31  Perf     perf: per second: rules 0.90 ms, visuals 0.20 ms, bars 0.05 ms, per-frame effects 0.02 ms (90 calls)", -- [19]
"20:06:31  Perf     perf: #1 0.70 ms/s  Rule \"A\"", -- [20]
"20:06:31  Perf     perf: #2 0.20 ms/s  Bloodlust", -- [21]
"20:06:31  Perf     perf: Lua memory 2100 KB now, +0 KB/s since start (a high number means garbage)", -- [22]
"20:06:31  Perf     meter combat 2 | XayaUI sess=0.0260 recent=0.0700 enc=0.0600 peak=20.000 n5=1 n10=1 n50=1 n100=0", -- [23]
"20:06:31  Perf     meter combat 2 | XayaUI_Bonus sess=0.0050 recent=?  enc=? peak=0.300 n5=0 n10=0 n50=0 n100=0", -- [24]
"20:30:00  Perf     meter run end | XayaUI sess=0.0270 recent=0.0100 enc=0.0600 peak=20.000 n5=1 n10=1 n50=1 n100=0", -- [25]
"20:30:00  Perf     meter run end | XayaUI_Bonus sess=0.0060 recent=0.0010 enc=? peak=0.300 n5=0 n10=0 n50=0 n100=0", -- [26]
"20:30:00  Note     ---------- recorded run ends: Skyreach ----------", -- [27]
},
},
["perfLog"] = {
{
["at"] = "2026-11-07 20:06:31",
["combat"] = false,
["lines"] = {
"perf over 91s: 600 steps", -- [1]
},
}, -- [1]
},
}
XayaUITalentDB = {
}
'''
fails = []
def check(name, ok):
    print(("ok    " if ok else "FAIL  ") + name)
    if not ok: fails.append(name)

d = tempfile.mkdtemp()
p = os.path.join(d, "XayaUI.lua")
open(p, "w").write(FIX)
saved = PR.read_saved(p)
check("reader: both saved tables, the record's 27 lines, escaped quotes kept", "XayaUITalentDB" in saved and
      len(saved["CueRulesDB"]["debugRecord"]["lines"]) == 27 and saved["CueRulesDB"]["debugRecord"]["lines"][7].endswith('Rule "A"'))
check("reader: numbers and booleans", saved["CueRulesDB"]["ui"]["recordMax"] == 10000 and saved["CueRulesDB"]["ui"]["advancedDebug"] is True)
r = PR.report(saved)
check("report: the run, with its dungeon, kind and instance", "## Run 1: Skyreach (Mythic+, instance 1209), 20:01:00 to 20:30:00" in r)
check("report: 2 fights, 1 boss, 1 trash, 121 s in combat (30 + 91)", "Fights: 2 (1 with a boss, 1 trash); 121 s in combat" in r)
check("report: the boss fight row names the boss and the engine numbers", "| 2 | 20:05:00 | 91 | Ranjit (1698) | 0.30 / 18.40 | 0.90 / 0.20 / 0.05 / 0.02 | +0 |" in r)
check("report: trash row sums XayaUI* recent readings (0.03 + 0.004 = 0.034)", "| 1 | 20:02:00 | 30 | trash | 0.12 / 1.10 |" in r and "| +3 | 0.0340 |" in r)
check("report: a fight whose XayaUI* reading was hidden shows '?', not a partial sum", "| +0 | ? |" in r)
check("report: per addon at run end, highest session average first", r.index("| XayaUI | 0.0270") < r.index("| XayaUI_Bonus | 0.0060"))
check("report: '?' from the game stays '?'", "| XayaUI_Bonus | 0.0060 | 0.0010 | ? |" in r)
check("report: boss vs trash means per addon", "| XayaUI | 0.0700 (n=1) | 0.0300 (n=1) |" in r)
check("report: slowest rules over the run", "| Rule \"A\" | 2 | 0.70 | 0.50 |" in r)
check("report: flags a step longer than a 60 fps frame (16.67 ms)", "Fight 2: one engine step took 18.40 ms, more than a whole 60 fps frame (16.67 ms)." in r)
check("report: flags memory growth in combat", "Fight 1: Lua memory grew +3 KB/s" in r)
check("report: flags frames over 50 ms", "Fight 2: XayaUI has 1 frames over 50 ms" in r)
check("report: ranking of XayaUI addons", "1. XayaUI: 0.0270 ms/frame" in r and "2. XayaUI_Bonus: 0.0060 ms/frame" in r)
check("report: the kept /xui debug perf readings", "/xui debug perf readings kept" in r)
check("report: a record with no run markers is one run", "(whole record, no run markers)" in PR.report(
      {"CueRulesDB": {"debugRecord": {"lines": ["20:00:00  Combat   ---------- combat 1 starts | X ----------"]}}}))
out = os.path.join(d, "r.md")
check("command line: --out writes the file", PR.main([p, "--out", out]) == 0 and open(out).read().startswith("# XayaUI performance report"))

print("FAILS: %d" % len(fails))
sys.exit(1 if fails else 0)
