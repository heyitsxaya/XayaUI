#!/usr/bin/env python3
"""The settings migration's in-game QA walkthrough (XayaUI_DevAssist 0.7.59, QAWalks-settings-migration.lua, QA H16; platform split P5;
standing rule V22, Xaya 2026-11-07: "make sure every feature or significant change to the codebase / bug report fixes have an in game qa
test walk through with pre-fill confirmation options or data capturing").
Runs both parts on the real addons (every one on) in the stand-in game, starting from the large "before" file of
tests/settings_migration_run.py (a CueRulesDB as the code before P5 saved it), with the saved variables carried over the /reload:
- both parts are registered with prefill = true;
- part 1 (the first login with P5: every module copies its settings): step 1 lists every module as "copied from CueRulesDB by <addon>
  <version> on <date>" (Pass); step 2 compares a few values of each module, own store against the old copy (Pass, this session);
  step 3 counts XayaUI Rules' rules, groups and bars on both sides and finds the backup (Pass); step 4 writes a marker into each module's
  own store and reads it back (Pass); part 2 before the /reload says "part 1 has no record" or reads the markers (no Fail);
- part 2 (after the /reload): every marker is still there and nothing was copied again (Pass); its last step takes the markers out (after
  one more /reload no store holds a marker);
- the mismatch path: with a rule lost in the copy (the test hook), step 1 says Fail and names XayaUI Rules "kept on CueRulesDB".
Negative control: on the code before P5 the walkthrough does not exist (the registration checks fail).
Run: python3 tests/qa_walk_settings_migration_run.py   (Lua 5.1 via lupa)."""
import json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
sys.path.insert(0, HERE)
import run as H  # noqa: E402
import settings_seam_run as SEAM  # noqa: E402
import settings_stores as SST  # noqa: E402
import settings_migration_run as MIG  # noqa: E402

COMMON = SEAM.PRELUDE + r'''
return function(W, L, opts)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.load("XayaUI")
local ns = rawget(_G, "XayaUI_NS")
if opts.breakCore then ns.settingsTestHooks.afterCopy = function(m, store) if m == "core" and type(store.rules) == "table" then table.remove(store.rules) end end end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.5, 10)
local QA = rawget(_G, "XayaUI_DevQA")
local RV = QA and QA.Review
if RV and RV.Window and RV.Window() then RV.Window():Hide() end
ns.Print = function() end
-- drive the runner as she would: Do it for me (when the step has one), then the addon's verdict (Accept) or Pass, or Done
local function Walk(id)
  QA.Start(id)
  local def = QA.walks[id]
  local out = {}
  for i, st in ipairs(def.steps) do
    if st.setup then QA.DoSetup(); W.tick(0.4, 3) end
    QA.RunCheck()
    local s = QA.State()
    out[i] = { v = s.suggest and s.suggest.r == "P" or (s.suggest and false) or nil, d = s.seen and s.seen[i] and s.seen[i].d or "" }
    if st.done then QA.Answer("D") elseif s.suggest then QA.Accept() else QA.Answer("P") end
  end
  return out
end
if not QA then check("Dev Assist QA framework", false); return R end
for _, id in ipairs({ "settings-migration", "settings-migration-reload" }) do
  local d = QA.walks[id]
  check(id .. ": registered with prefill", d ~= nil and d.prefill == true and #d.steps >= 2, d and d.prefill)
end
if not QA.walks["settings-migration"] then return R end
local function Check(id, i) local okC, v, n = pcall(QA.walks[id].steps[i].check); if not okC then return "ERR", tostring(v) end; return v, n end
'''

PART1 = COMMON + r'''
if opts.breakCore then
  local v, n = Check("settings-migration", 1)
  check("mismatch: step 1 says Fail and names XayaUI Rules kept on CueRulesDB, with the difference", v == false and tostring(n):find("XayaUI Rules: kept on CueRulesDB (rules.", 1, true) ~= nil, n)
  return R
end
local res = Walk("settings-migration")
local function said(i, pat) return tostring(res[i].d):find(pat, 1, true) ~= nil end
check("part 1 step 1: every module copied from CueRulesDB (verdict Pass); the record names the version that copied and the day",
  res[1].v == true and said(1, "copied from CueRulesDB: Reskin 0 11-06 now") and said(1, "Rules 0 11-06 now") and said(1, "DevAssist 0 11-06 now"), res[1].d)
check("part 1 step 2: the compared values are the same, own store against the old copy (verdict Pass)", res[2].v == true and said(2, "changed or lost: none"), res[2].d)
check("part 1 step 3: rules, groups, bars counted the same on both sides; the backup is there (verdict Pass)",
  res[3].v == true and said(3, "Rules before the settings move") and said(3, "own: 320 rules"), res[3].d)
check("part 1 step 4: a marker in every module's own store, read back (verdict Pass)", res[4].v == true and said(4, "every marker is there"), res[4].d)
return R
'''.replace("own: 320 rules", "own: __NR__ rules") + "\nend\n"

PART2 = COMMON + r'''
local v, n = Check("settings-migration-reload", 1)
check("part 2 step 1 after the /reload: every marker kept, nothing copied again (verdict Pass)", v == true, n)
Walk("settings-migration-reload")
return R
end
'''

PART3 = COMMON + r'''
local left = {}
for _, m in ipairs(ns.SettingsStoreModules()) do
  for _, k in ipairs(ns.SettingsKeys(m)) do local t = ns.Settings(m)[k]; if type(t) == "table" and t._qaP5 ~= nil then left[#left + 1] = m .. "." .. k end end
end
check("after part 2's last step and one more /reload: no marker is left in any store", #left == 0, table.concat(left, ", "))
return R
end
'''


def session(src, saved, **opts):
    folders = H.find_addons()
    L, world, loader = SEAM.build(folders, set(folders), saved)
    res = L.eval("function(src, W, Ld, o) return loadstring(src)()(W, Ld, o) end")(src, world, loader, H.to_lua(L, opts))
    out, issues = loader.logout()
    results = [(res[i][1], res[i][2]) for i in range(1, len(res) + 1)]
    errs = [str(world.errors[i]) for i in range(1, len(world.errors) + 1)]
    return results, H.lua_to_py(out), errs


def main():
    folders = H.find_addons()
    owners = MIG.var_owners(folders)
    lay = SST.layout(MIG.ROOT)
    s0, _, _ = SEAM.play(folders, set(folders), {}, False)
    fill = MIG.run(MIG.per_addon(SST.project(MIG.merge(s0), lay), owners), keepOld=True, fill=True)
    before = MIG.per_addon(MIG.merge(fill["saved"]), owners)
    nR = len((MIG.merge(fill["saved"]).get("CueRulesDB") or {}).get("rules") or [])
    bad, n, errs = 0, 0, []

    def report(tag, results, e):
        nonlocal bad, n, errs
        errs += e
        for name, ok in results:
            n += 1
            print(("PASS " if ok else "FAIL ") + tag + ": " + name)
            bad += 0 if ok else 1

    r1, s1, e1 = session(PART1.replace("__NR__", str(nR)), before)
    report("part 1", r1, e1)
    r2, s2, e2 = session(PART2, s1)
    report("part 2", r2, e2)
    r3, s3, e3 = session(PART3, s2)
    report("after", r3, e3)
    rb, _, eb = session(PART1, before, breakCore=True)
    report("mismatch", rb, eb)
    for e in errs:
        print("ERROR in the game stand-in:", e[:600])
    print("%d checks, %d failed, %d Lua errors" % (n, bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
