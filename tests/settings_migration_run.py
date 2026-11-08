#!/usr/bin/env python3
"""Settings migration P5 (docs/plans/PLATFORM-SPLIT-2026-11-07.md section 5 steps 2-3, risk R1; Xaya's answers PS-52 / PS-53 / PS-54).
Every module with its own store (XayaUI/Modules.lua SETTINGS_STORES, read by tests/settings_stores.py: the test grows with the code)
copies its keys out of CueRulesDB on its first load, never moves them. The saved data used ("before"): a full scripted play session of
every addon (tests/harness/scenario.lua, the golden scenario of tests/settings_seam_run.py) folded back into CueRulesDB as the code before
P5 saved it (settings_stores.project; settings_seam_run.py B checks that fold against the pre-split golden hash), then a session that
reads and writes CueRulesDB exactly as before P5 (ns.settingsTestHooks.keepOld) adds a large realistic set: 320 rules, 45 groups (nested),
12 buff bars, and a distinct value for every module's keys (the split characterReskin with both halves, Reskin's keys inside ui).
  F  the "before" file: no module store exists in it (the keepOld session made none), and it holds every key the test copies
  M1 first load (every addon on): per module, the store as copied deep-equals the old keys (split / ui keys mapped), the store records
     migratedFrom "CueRulesDB", migratedAt, migratedBy (addon and version), migratedKeys; the module's view reads the store; every
     old key in CueRulesDB is byte-identical to the before file (copy, never move), also after a whole play session and the logout
  M2 second load: nothing is copied again (an old key changed in CueRulesDB between the loads does not reach the store; migratedAt kept);
     a setting changed in session 1 is still there after the /reload
  P  the settings window reads the same values: the whole options table (every page of every module, tests/options_split_parity_run.py's
     dump) built after the migration equals the one built from the same file read the pre-P5 way (keepOld); every profile part's export
     string is byte-identical between the two
  O  module off: with one store module switched off, its store is not created and its old keys stay as they were; no Lua error
  R  (XayaUI Rules, when it has its store) a backup of the rules is saved first (Profiles backups, CueRulesDB.profiles) and restores
     (Load (replace)) to the same rules; counts of rules, groups, bars equal; a copy that differs (a rule lost in the copy) keeps the
     rules in CueRulesDB, takes the copy out again, records the mismatch and tells the player once; the next load tries again
Negative control: on the code before P5 (branch head d3b5cc8) there is no module store: M1 fails (no store, no marks), and the run
says so.
Run: python3 tests/settings_migration_run.py"""
import json, os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
sys.path.insert(0, os.environ.get("XUI_HARNESS") or os.path.join(HERE, "harness"))
sys.path.insert(0, HERE)
import run as H  # noqa: E402  (the whole-addon harness)
import settings_stores as SST  # noqa: E402
import settings_seam_run as SEAM  # noqa: E402  (its play session and its pre-split golden fold)
import options_split_parity_run as OPT  # noqa: E402  (the options table dump)

results = []


def check(name, ok, extra=""):
    results.append((name, bool(ok)))
    print(("PASS " if ok else "FAIL ") + name + ("" if ok or not extra else "  [" + str(extra)[:500] + "]"))


def var_owners(folders):
    """{saved variable: addon folder} from the tocs"""
    out = {}
    for name, d in folders.items():
        toc = open(os.path.join(d, name + ".toc"), encoding="utf-8").read()
        for line in toc.splitlines():
            m = re.match(r"^## SavedVariables(?:PerCharacter)?:\s*(.*)$", line)
            if m:
                for v in m.group(1).split(","):
                    if v.strip():
                        out[v.strip()] = name
    return out


def per_addon(merged, owners):
    out = {}
    for var, val in merged.items():
        out.setdefault(owners.get(var, "XayaUI"), {})[var] = val
    return out


def merge(saved):
    m = {}
    for addon in sorted(saved or {}):
        for var, val in (saved[addon] or {}).items():
            m[var] = val
    return m


DRIVER = SEAM.PRELUDE + r'''
local function deep(v, seen)
  if type(v) ~= "table" then return v end
  local o = {}
  for k, x in pairs(v) do o[deep(k)] = deep(x) end
  return o
end
return function(W, L, opts, DUMP)
local out = { printed = {}, snaps = {}, states = {}, early = {} }
-- the Platform first (the game loads it first: every module depends on it), so the test's hooks are in place before any store opens
L.load("XayaUI")
local ns = rawget(_G, "XayaUI_NS")
local realPrint = ns.Print
ns.Print = function(...) local t = {}; for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end; out.printed[#out.printed + 1] = table.concat(t, " "); return realPrint(...) end
if opts.keepOld then ns.settingsTestHooks.keepOld = true end
ns.settingsTestHooks.afterCopy = function(m, store)
  out.snaps[m] = deep(store)
  if opts.breakCore and m == "core" and type(store.rules) == "table" then table.remove(store.rules) end   -- a rule lost in the copy
end
L.startup()
-- the old keys right after every store opened, before anything ran on them
local old = rawget(_G, "CueRulesDB")
out.oldAtLoad = deep(old)
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
for _, m in ipairs(ns.SettingsStoreModules()) do
  local st = ns.SettingsStore(m)
  out.states[m] = st.state
end
out.dropped = {}
for k, n in pairs(ns.SettingsDroppedWrites()) do out.dropped[#out.dropped + 1] = k .. "=" .. n end
if opts.fill then
  -- a large realistic set, made with the addon's own calls, read and written the pre-P5 way (keepOld)
  local C = ns.Settings("core")
  if ns.NewRule and ns.NewFolder then
    local folders, rules = {}, {}
    for i = 1, 45 do
      local parent = (i > 15) and folders[((i - 1) % 15) + 1].id or nil
      local f = ns.NewFolder("Group " .. i, parent)
      folders[#folders + 1] = f
    end
    for i = 1, 320 do
      local r = ns.NewRule(); r.name = "Rule " .. i; r.enabled = (i % 7) ~= 0
      r.spellID = 100000 + i; r.useBuff = (i % 3) == 0; r.buffID = (i % 3 == 0) and (200000 + i) or 0
      r.folder = folders[(i % 45) + 1].id
      ns.NormalizeRule(r)
      ns.rules[#ns.rules + 1] = r
    end
    if ns.NewBar then for i = 1, 12 do local b = ns.NewBar(); b.name = "Bar " .. i; b.buffID = 300000 + i; ns.bars[#ns.bars + 1] = b end end
    C.barGroup = C.barGroup or {}; C.barGroup.spacing = 7
    C.auraAlias = { [62618] = { [81782] = true } }
    C.learnedAuraDur = { [12345] = 8.5 }
  end
  local R = ns.Settings("reskin")
  R.rsk = { windows = true, tooltips = true, winOff = { bags = true }, shape = "SQUARE", bgAlpha = 0.8 }
  R.gm = { skin = true, accR = 0.5, matchReal = false }
  R.friendColors = { on = false }
  ns.Settings("qol").characterReskin = { enabled = true, chrome = false, stats = true, wide = true, widePx = 99, bgAlpha = 0.7, tallPx = 12,
    widePxTo42 = true, ilvl = false, enchants = true, gems = false, statList = true, statHide = { haste = true },
    statOrder = { core = { "crit", "haste" } }, statMode = { crit = "both" }, statName = { crit = "Crit!" }, statColor = { crit = { 1, 0, 0 } },
    groupName = { core = "Mine" }, groupColor = { core = { 0, 1, 0 } } }
  local Q = ns.Settings("qol")
  Q.cursorTrail = { enabled = true, marker = "trail" }; Q.cursorHighlight = { enabled = true, size = 44 }; Q.cursor = { a = 1 }
  Q.shoppingList = { enabled = true, items = { { id = 2589, need = 20 } } }; Q.releaseGuard = { enabled = true, text = "NOPE" }
  Q.characterToolkit = Q.characterToolkit or {}; Q.characterToolkit.marker = "toolkit"
  local Ch = ns.Settings("chat")
  Ch.chat2 = Ch.chat2 or {}; Ch.chat2.fadeMarker = 7; Ch.chat = Ch.chat or {}; Ch.chat.marker = "c"
  local B = ns.Settings("bonus")
  B.notepad = { pages = { { title = "Raid", text = "pull at 5" } } }; B.calculator = { enabled = true, history = { "1+1 = 2" } }
  B.tooltips = B.tooltips or {}; B.tooltips.marker = 3; B.dataPanels = B.dataPanels or {}; B.dataPanels.markerA = "a"
  local D = ns.Settings("devassist")
  D.idProbe = { on = true, ids = { 1, 2, 3 } }; D.chatProbe = { lines = { "x" } }; D.idProbeStream = { { 1, "a" } }
end
if opts.change then   -- one setting changed per module (through its view, as the settings window does)
  local V = function(m) return ns.Settings(m) end
  if ns.SettingsStore("reskin") then local r = V("reskin").rsk; if type(r) == "table" then r.changedAfter = "reskin" end end
  for _, m in ipairs({ "qol", "chat", "bonus", "devassist", "core" }) do
    if ns.SettingsStore(m).state == "own" then
      local k = ({ qol = "cursorTrail", chat = "chat2", bonus = "calculator", devassist = "idProbe", core = "barGroup" })[m]
      local t = V(m)[k]; if type(t) == "table" then t.changedAfter = m end
    end
  end
end
if opts.tweakOld then   -- an old key changed in CueRulesDB between the loads (what an older build would do)
  local db = rawget(_G, "CueRulesDB")
end
out.views = {}
for _, m in ipairs(ns.SettingsStoreModules()) do
  local t = {}
  for _, k in ipairs(ns.SettingsKeys(m)) do t[k] = deep(ns.Settings(m)[k]) end
  out.views[m] = t
end
if opts.rulesInfo then
  out.rulesIsOld = rawequal(ns.rules, rawget(_G, "CueRulesDB") and CueRulesDB.rules)
  out.nRules = ns.rules and #ns.rules or -1
  out.backups = {}
  for i, b in ipairs(ns.Backups and ns.Backups() or {}) do out.backups[i] = { name = b.name, nRules = b.data and b.data.rules and #b.data.rules or -1, nFolders = b.data and b.data.folders and #b.data.folders or -1 } end
  -- restorable: the backup as a share string (Profiles > Backups "show as text"), read back, then Load (replace)
  local bk
  for _, b in ipairs(ns.Backups and ns.Backups() or {}) do if tostring(b.name):find("before the settings move", 1, true) then bk = b end end
  if bk then
    local str = ns.Share.Encode("rules", bk.data)
    out.backupString = type(str) == "string" and #str or 0
    local back = ns.Share.Read(str)
    local okA = pcall(ns.Share_ApplyRules, ns.Copy(back.data or back), "replace")
    out.restored = okA and #ns.rules or -1
    out.restoredFolders = #ns.folders
  end
end
if opts.dump then
  local ok, res = pcall(function()
    if ns.LoadOptions then ns.LoadOptions() end; W.tick(0.1, 3)
    local A = C_AddOns; local realGet = A.GetAddOnMetadata
    local parts = {}
    for _, p in ipairs(ns.ProfileParts()) do
      local okS, snap = pcall(p.snapshot, "x")
      if okS and type(snap) == "table" then
        local okE, s = pcall(ns.Share.Encode, "profile", { v = 1, name = "x", addonVersion = "0", parts = { [p.key] = snap } })
        parts[#parts + 1] = p.key .. "=" .. (okE and s or ("ERR " .. tostring(s)))
      end
    end
    table.sort(parts)
    return table.concat(parts, "\n")
  end)
  out.exports = ok and res or ("ERR " .. tostring(res))
end
local saved, issues = L.logout()
out.saved = saved
out.issues = issues
return out
end
'''


def run(saved, enabled=None, **opts):
    folders = H.find_addons()
    en = set(folders) if enabled is None else enabled
    L, world, loader = SEAM.build(folders, en, saved)
    res = L.eval("function(src, W, Ld, o) return loadstring(src)()(W, Ld, o) end")(DRIVER, world, loader, H.to_lua(L, opts))
    errs = [str(world.errors[i]) for i in range(1, len(world.errors) + 1)]
    out = {k: H.lua_to_py(res[k]) for k in res.keys()}
    out["errors"] = errs
    if opts.get("optdump"):
        out["optdump"] = None
    return out


def opt_dump(saved, keep_old):
    """the options table dump (tests/options_split_parity_run.py) built from `saved`, read the pre-P5 way or migrated"""
    folders = H.find_addons()
    L, world, loader = SEAM.build(folders, set(folders), saved)
    L.execute("XUI_KEEP = %s" % ("true" if keep_old else "false"))
    pre = r'''
    local Ld = ...
    Ld.load("XayaUI")
    local ns = rawget(_G, "XayaUI_NS")
    if XUI_KEEP then ns.settingsTestHooks.keepOld = true end
    math.randomseed(1234)   -- (new group ids are random: the same ones in both builds of the window)
    '''
    L.eval("function(src, Ld) return loadstring(src)(Ld) end")(pre, loader)
    # the dump's own fixed rule state replaces the rules: compare the rest of the window (every module's pages) on the same file
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(OPT.LUA, world, loader)
    errs = [str(world.errors[i]) for i in range(1, len(world.errors) + 1)]
    if res[1] != "ok":
        return None, errs + [str(res[1])]
    return str(res[2]), errs


def legacy_value(lay, module, k, old):
    old = old or {}
    v = (old.get("ui") or {}).get(k) if k in lay["underUi"].get(module, []) else old.get(k)
    sp = lay["split"].get(k)
    if sp and isinstance(v, dict):
        sub = set(sp["sub"])
        part = {kk: x for kk, x in v.items() if (sp["owner"] == module and kk in sub) or (sp["rest"] == module and kk not in sub)}
        return part or None
    return v


def norm(v):
    """JSON-canonical (lists for 1..n tables, as the harness returns them)"""
    return json.dumps(v, sort_keys=True)


def main():
    folders = H.find_addons()
    owners = var_owners(folders)
    try:
        lay = SST.layout(ROOT)
    except ValueError:   # the code before P5: no store tables in Modules.lua at all
        lay = None
    stores = lay["stores"] if lay else {}
    check("there is at least one module with its own store (negative control: none before P5)", len(stores) > 0, stores)
    if not stores:
        print("%d checks, %d failed" % (len(results), 1))
        sys.exit(1)
    for m, st in stores.items():
        check("%s: its addon %s declares %s in its .toc" % (m, st["addon"], st["var"]), owners.get(st["var"]) == st["addon"], owners.get(st["var"]))

    # ---------------------------------------------------------------------------------------------------------------- the "before" file
    s0, e0, _ = SEAM.play(folders, set(folders), {}, False)
    base = SST.project(merge(s0), lay)
    fill = run(per_addon(base, owners), keepOld=True, fill=True)
    check("F: the session that made the before file had no Lua error", not fill["errors"], fill["errors"][:3])
    before_m = merge(fill["saved"])
    before = per_addon(before_m, owners)
    old = before_m.get("CueRulesDB") or {}
    check("F: the before file has no module store (read and written the pre-P5 way)",
          not any(st["var"] in before_m for m, st in stores.items() if m != "devassist") and
          not any(k in (before_m.get("XayaUIDevAssistDB") or {}) for k in SST.STORE_MARKS), sorted(before_m))
    nR, nF, nB = len(old.get("rules") or []), len(old.get("folders") or []), len(old.get("bars") or [])
    check("F: the before file is large: >= 320 rules, >= 45 groups, >= 12 buff bars (%d, %d, %d)" % (nR, nF, nB), nR >= 320 and nF >= 45 and nB >= 12)
    for m in stores:
        have = [k for k in lay["keys"][m] if legacy_value(lay, m, k, old) is not None]
        check("F: %s: the before file holds old keys to copy (%s)" % (m, ", ".join(have)), len(have) > 0)

    # ---------------------------------------------------------------------------------------------------------------- M1 first load
    m1 = run(before, change=True, rulesInfo=True)
    check("M1: first load: no Lua error", not m1["errors"], m1["errors"][:3])
    check("M1: no write was dropped (nothing wrote to a store before it opened)", not m1.get("dropped"), m1.get("dropped"))
    saved1 = merge(m1["saved"])
    for m, st in stores.items():
        snap = (m1["snaps"] or {}).get(m) or {}
        bad = [k for k in lay["keys"][m] if norm(snap.get(k)) != norm(legacy_value(lay, m, k, old))]
        check("M1: %s: the store as copied deep-equals every old key (%d keys)" % (m, len(lay["keys"][m])), not bad and snap, bad)
        check("M1: %s: the module reads its own store %s" % (m, st["var"]), (m1["states"] or {}).get(m) == "own", (m1["states"] or {}).get(m))
        s = saved1.get(st["var"]) or {}
        check("M1: %s: the store records migratedFrom CueRulesDB, the date, the addon and version, the number of keys" % m,
              s.get("migratedFrom") == "CueRulesDB" and isinstance(s.get("migratedAt"), str) and str(s.get("migratedBy", "")).startswith(st["addon"] + " ")
              and s.get("migratedKeys") == len([k for k in lay["keys"][m] if legacy_value(lay, m, k, old) is not None]) and s.get("storeVersion") == 1,
              {k: s.get(k) for k in SST.STORE_MARKS})
        old_at_load = m1.get("oldAtLoad") or {}
        old_after = saved1.get("CueRulesDB") or {}
        moved = [k for k in lay["keys"][m] if norm(legacy_value(lay, m, k, old_at_load)) != norm(legacy_value(lay, m, k, old))
                 or norm(legacy_value(lay, m, k, old_after)) != norm(legacy_value(lay, m, k, old))]
        check("M1: %s: copy, never move: every old key in CueRulesDB is unchanged after the load and after a whole session and logout" % m, not moved, moved)

    # ---------------------------------------------------------------------------------------------------------------- M2 second load
    s1 = {a: dict(v) for a, v in m1["saved"].items()}
    tweaked = json.loads(json.dumps(s1))
    cdb = tweaked["XayaUI"]["CueRulesDB"]
    for m in stores:   # an old key changed in CueRulesDB between the loads (an older build ran in between)
        for k in lay["keys"][m]:
            v = legacy_value(lay, m, k, cdb)
            if isinstance(v, dict):
                tgt = (cdb.get("ui") or {}).get(k) if k in lay["underUi"].get(m, []) else cdb.get(k)
                tgt["olderBuildWrote"] = m
                break
    m2 = run(tweaked)
    check("M2: second load: no Lua error", not m2["errors"], m2["errors"][:3])
    saved2 = merge(m2["saved"])
    for m, st in stores.items():
        check("M2: %s: nothing copied again (no copy was made at the second load)" % m, m not in (m2["snaps"] or {}), list((m2["snaps"] or {}).keys()))
        s2 = saved2.get(st["var"]) or {}
        found = [k for k in lay["keys"][m] if isinstance(s2.get(k), dict) and s2[k].get("olderBuildWrote")]
        check("M2: %s: an old key changed in CueRulesDB after the copy does not reach the store; migratedAt kept" % m,
              not found and s2.get("migratedAt") == (saved1.get(st["var"]) or {}).get("migratedAt"), found)
        changed = [k for k in lay["keys"][m] if isinstance(s2.get(k), dict) and s2[k].get("changedAfter") == m]
        check("M2: %s: the setting changed in session 1 is still there after the /reload" % m, changed, sorted(s2)[:12])

    # ---------------------------------------------------------------------------------------------------------------- P parity
    keep = run(before, keepOld=True, dump=True)
    mig = run(before, dump=True)
    check("P: profile parts: every part's export string is byte-identical, migrated vs read the pre-P5 way", keep.get("exports") == mig.get("exports")
          and "ERR" not in str(mig.get("exports")), (str(keep.get("exports"))[:200], str(mig.get("exports"))[:200]))
    d_keep, ek = opt_dump(before, True)
    d_mig, em = opt_dump(before, False)
    if d_keep != d_mig and d_keep and d_mig:
        a, b = d_keep.split("\n"), d_mig.split("\n")
        diff = [x for x in b if x not in set(a)][:3]
    else:
        diff = ek[:2] + em[:2]
    check("P: the settings window (every page of every module) reads the same values, migrated vs read the pre-P5 way",
          d_keep is not None and d_keep == d_mig, diff)

    # ---------------------------------------------------------------------------------------------------------------- O module off
    for m, st in stores.items():
        en = {n for n in folders if n != st["addon"]}
        o = run(before, enabled=en)
        so = merge(o["saved"])
        made = st["var"] in so and any(k in (so.get(st["var"]) or {}) for k in list(lay["keys"][m]) + list(SST.STORE_MARKS))
        check("O: %s off: no Lua error" % st["addon"], not o["errors"], o["errors"][:3])
        check("O: %s off: its store is not created and nothing is written into it (V14)" % st["addon"], not made, sorted(so.get(st["var"]) or {})[:10])
        changed = [k for k in lay["keys"][m] if norm(legacy_value(lay, m, k, so.get("CueRulesDB"))) != norm(legacy_value(lay, m, k, old))]
        check("O: %s off: its old keys in CueRulesDB are untouched" % st["addon"], not changed, changed)

    # ---------------------------------------------------------------------------------------------------------------- R rules
    if "core" in stores:
        sv = stores["core"]["var"]
        check("R: a backup of the rules was saved before the copy (Profiles > Backups), with every rule and group",
              any("before the settings move" in str(b.get("name")) and b.get("nRules") == nR and b.get("nFolders") == nF for b in (m1.get("backups") or [])),
              m1.get("backups"))
        check("R: the backup is restorable: as a share string it reads back and Load (replace) gives the same number of rules and groups",
              (m1.get("backupString") or 0) > 0 and m1.get("restored") == nR and m1.get("restoredFolders") == nF, (m1.get("restored"), m1.get("restoredFolders")))
        snap = (m1["snaps"] or {}).get("core") or {}
        check("R: counts equal on both sides: rules, groups, bars", len(snap.get("rules") or []) == nR and len(snap.get("folders") or []) == nF
              and len(snap.get("bars") or []) == nB)
        bad = run(before, breakCore=True, rulesInfo=True)
        sb = merge(bad["saved"])
        st_b = sb.get(sv) or {}
        mm = st_b.get("migrationMismatch") or {}
        check("R mismatch: no Lua error", not bad["errors"], bad["errors"][:3])
        check("R mismatch: XayaUI Rules keeps reading CueRulesDB (state old; the engine's rules are CueRulesDB.rules, all of them)",
              (bad["states"] or {}).get("core") == "old" and bad.get("rulesIsOld") is True and bad.get("nRules") == nR, (bad["states"], bad.get("rulesIsOld"), bad.get("nRules")))
        check("R mismatch: the copy is taken out of the store again and the difference recorded (when, by what, where, reported)",
              not any(k in st_b for k in lay["keys"]["core"]) and mm.get("reported") is True and mm.get("tries") == 1 and "rules" in str(mm.get("diff")),
              (sorted(st_b), mm))
        said = [p for p in (bad.get("printed") or []) if "could not be copied" in p]
        check("R mismatch: the player is told once, in chat", len(said) == 1, bad.get("printed"))
        check("R mismatch: CueRulesDB's rules are untouched", norm((sb.get("CueRulesDB") or {}).get("rules")) == norm(old.get("rules")))
        again = run(bad["saved"], breakCore=True)
        said2 = [p for p in (again.get("printed") or []) if "could not be copied" in p]
        st_a = merge(again["saved"]).get(sv) or {}
        check("R mismatch twice: not told again; the record counts the second try", not said2 and (st_a.get("migrationMismatch") or {}).get("tries") == 2,
              (said2, st_a.get("migrationMismatch")))
        fixed = run(bad["saved"])
        check("R mismatch, then a clean load: the copy is made and XayaUI Rules reads its own store", (fixed["states"] or {}).get("core") == "own"
              and len(((fixed["snaps"] or {}).get("core") or {}).get("rules") or []) == nR, fixed["states"])

    failed = sum(1 for _, ok in results if not ok)
    print("%d checks, %d failed" % (len(results), failed))
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
