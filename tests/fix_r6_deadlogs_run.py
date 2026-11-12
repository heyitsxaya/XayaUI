#!/usr/bin/env python3
"""Round 6, SD-55 "Dead logs": two saved texts nothing on main reads are let go at the login, and the bug report is no longer kept.

Xaya, 2026-11-12 (REQUEST-LOG A23 SD-55, her answer on the memory cuts, her words): "Dead logs (0.2 MB),Compact backups (7.8 -> ~2 MB)".
The memory report (docs/plans/MEMORY-REPORT-2026-11-11.md): P-4 "Clear Dev Assist's detailed debug record left in CueRulesDB" (113 KB
at 3,000 lines; "Nothing on main shows it; Dev Assist (qa-installer-branch) would start a new record"); P-5 "Stop keeping the last bug
report text, and clear the kept one" ("/xui bug builds the report fresh each time, as now; the old text is not kept").
What the player gets, checked here ([new] = fails on the pre-change files, proved on a copy):
  D  [new] without XayaUI Dev Assist, the detailed record an earlier Dev Assist left (CueRulesDB.debugRecord, 3,000 lines) is gone after
     the login and is not saved again; with Dev Assist installed and on, its record stays (it is that addon's own);
  B  [new] the bug report kept from before (CueRulesDB.lastBugReport) is gone after the login; /xui bug still shows the whole report to
     copy, and nothing of it is saved; the error log the report reads is untouched;
  M  [new] the saved XayaUI data is smaller by those two texts.
Run: python3 tests/fix_r6_deadlogs_run.py   (Lua 5.1 via lupa; reads tests/harness/api_index.json when XUI_API_INDEX points to it)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
local W, L, devAssist = ...
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
local ns = rawget(_G, "XayaUI_NS")
-- XayaUI Dev Assist (qa-installer-branch) puts its hand-in points in place when it loads, before the login (DevRecord.lua)
if devAssist then ns.SetDebugHooks({ RecordSummary = function() return #CueRulesDB.debugRecord.lines, 0, "2026-11-08 20:14:02" end }) end
local errBefore = #(CueRulesDB.errorLog or {})
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local shown = {}
local S0 = ns.ShowCopyBox
ns.ShowCopyBox = function(title, txt) shown[#shown + 1] = { title, txt } end
if not devAssist then
  check("[new] D1 without XayaUI Dev Assist: the detailed record an earlier Dev Assist left is gone after the login",
    CueRulesDB.debugRecord == nil, CueRulesDB.debugRecord and #CueRulesDB.debugRecord.lines)
  check("[new] B1 the bug report kept from before is gone after the login", CueRulesDB.lastBugReport == nil, CueRulesDB.lastBugReport and #CueRulesDB.lastBugReport)
  SlashCmdList.XAYAUI("bug")
  local box = shown[#shown]
  check("B2 /xui bug still shows the whole report to copy (title 'XayaUI bug report'; the report's own lines)",
    box and box[1] == "XayaUI bug report" and box[2]:find("^XayaUI bug report\nXayaUI version: ") ~= nil and box[2]:find("\nLast console lines:\n", 1, true) ~= nil
    and box[2]:find("Errors and warnings from XayaUI: ", 1, true) ~= nil, box and box[2]:sub(1, 80))
  check("[new] B3 ... and nothing of it is kept in the saved data", CueRulesDB.lastBugReport == nil)
  check("B4 the error log the report reads is untouched (" .. errBefore .. " entries)", #(CueRulesDB.errorLog or {}) == errBefore and errBefore == 2)
else
  check("D2 with XayaUI Dev Assist on: its detailed record stays (" .. #((CueRulesDB.debugRecord or { lines = {} }).lines) .. " lines)",
    type(CueRulesDB.debugRecord) == "table" and #CueRulesDB.debugRecord.lines == 3000)
end
ns.ShowCopyBox = S0
local out = L.logout()
local db = out.XayaUI and out.XayaUI.CueRulesDB or {}
return R, db.debugRecord ~= nil, db.lastBugReport ~= nil
'''


def saved():
    lines = ["%02d:%02d:%02d rule 'Buff %d' fired: spell %d, aura shown, sound played (Master)" % (20 + i // 3600 % 4, i // 60 % 60, i % 60, i % 66, 100000 + i)
             for i in range(3000)]
    report = "XayaUI bug report\nXayaUI version: 0.6.84\n" + "\n".join("  " + l for l in lines[1500:])
    errs = [{"code": "XUI-E010", "msg": "a rule failed", "n": 3, "first": 1794000000, "last": 1794000100, "ver": "0.6.84"},
            {"code": "XUI-W001", "msg": "the game blocked an action", "n": 1, "first": 1794000000, "last": 1794000000, "ver": "0.6.84"}]
    return {"XayaUI": {"CueRulesDB": {"version": 1, "ui": {"advancedDebug": True}, "errorLog": errs,
                                      "debugRecord": {"lines": lines, "dropped": 4200, "started": "2026-11-08 20:14:02"},
                                      "lastBugReport": report}}}


def run(dev_assist):
    folders = H.find_addons()
    enabled = [n for n in folders if n in ("XayaUI", "XayaUI_Rules", "XayaUI_Options")]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    sv = H.savedvars(L)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": saved()}))
    src_before = sv.Serialize(H.to_lua(L, saved()["XayaUI"]["CueRulesDB"]))
    res, rec_saved, rep_saved = L.eval("function(src, ...) return loadstring(src)(...) end")(LUA, world, loader, dev_assist)
    results = [(res[i][1], res[i][2]) for i in range(1, len(res) + 1)]
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    return results, errs, rec_saved, rep_saved, len(src_before)


def main():
    results, errors = [], []
    r, e, rec, rep, before = run(False)
    results += r
    errors += e
    results.append(("[new] M1 without Dev Assist the next saved XayaUI data holds neither text (CueRulesDB was %d characters of text before)" % before,
                    not rec and not rep))
    r, e, rec, rep, _ = run(True)
    results += r
    errors += e
    results.append(("[new] D3 with Dev Assist on its record is saved again; the bug report is not", rec and not rep))
    bad = 0
    for name, ok in results:
        print(("PASS " if ok else "FAIL ") + name)
        bad += 0 if ok else 1
    for x in errors:
        print("ERROR in the game stand-in:", str(x)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(results), bad, len(errors)))
    sys.exit(1 if bad or errors else 0)


if __name__ == "__main__":
    main()
