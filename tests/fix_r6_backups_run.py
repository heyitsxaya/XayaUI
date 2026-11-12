#!/usr/bin/env python3
"""Round 6, SD-55 "Compact backups": each rule backup (Profiles > Backups, CueRulesDB.profiles) is kept as one text and read back into
tables only when it is loaded or shown as export text; backups an older XayaUI saved are turned into text once, at the login, and
nothing is lost.

Xaya, 2026-11-12 (REQUEST-LOG A23 SD-55, her answer on the memory cuts, her words): "Dead logs (0.2 MB),Compact backups (7.8 -> ~2 MB)".
The memory report (docs/plans/MEMORY-REPORT-2026-11-11.md, P-2): "Keep each rule backup as one text ..., read only when she loads that
backup"; "Backups load, show as text and delete as now. An XayaUI older than the change could not read the new backups."

Sessions (each a new Lua state, as the game runs each login; saved variables carried as Lua source, numbers and key types kept):
  0  the gate's 300-rule profile (tests/gate_common.py), saved by a logout;
  1  an older XayaUI's backups: four backups saved the way the older code kept them ({ name, data = <tables> }): the whole profile, a
     "Rules before the settings move" backup, one with hard cases (number keys, gaps, decimals to the last bit, "|H" and quotes in text,
     true / false keys, deep nesting, a local sound file) and an empty one; saved by a logout;
  2  this version's first login with them; then a logout;
  3  the next login: the Profiles page, Show export text, Load (replace), a new backup, a damaged one.
What the player sees / gets, checked here ([new] = fails on the pre-change files, proved on a copy):
  K  [new] after the first login every backup is kept as one text, nothing of its rules as tables; the saved backups hold far less;
  X  every older backup restores to exactly the same rules: the data Load and Show export text get is key for key and value for value
     the older backup's, after the login that turned it into text and after the next login; Load (replace) from the Profiles page gives
     the same rules and groups as loading the older backup did; Show export text gives the same text;
  P  the Profiles page shows the same line under each backup as before, and drawing the page reads no backup text;
  S  [new] a backup saved now is kept as text, and loads back exactly what was saved; [new] a damaged one changes nothing and says so
     in chat.
Run: python3 tests/fix_r6_backups_run.py   (Lua 5.1 via lupa; reads tests/harness/api_index.json when XUI_API_INDEX points to it)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "harness"))
import gate_common as GC  # noqa: E402  (the gate's 300-rule profile and stand-in game; read only)
import run as H  # noqa: E402

COMMON = r'''
local W, L, G, SV = ...
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local realTime = time
time = function(t) if t ~= nil then return realTime(t) end return 1794000000 end   -- a fixed clock (new group ids and dates)
local function login()
  L.startup()
  W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
  return rawget(_G, "XayaUI_NS")
end
local function rawData(p) return type(p) == "table" and rawget(p, "data") end
'''

# session 1: what an older XayaUI kept (Backup_Save before round 6: list[#list + 1] = { name = name, data = snap })
OLD = COMMON + r'''
local ns = login()
local list = CueRulesDB.profiles or {}
CueRulesDB.profiles = list
list[#list + 1] = { name = "Full profile", data = ns.Share_SnapshotAll(nil, "Full profile") }
local some = {}
for i = 1, 40 do some[i] = ns.Copy(ns.rules[i]) end
list[#list + 1] = { name = "Rules before the settings move (2026-11-08 20:14)", data = { v = 1, name = "Rules before the settings move (2026-11-08 20:14)",
  addonVersion = "0.6.80", rules = some, folders = ns.Copy(ns.folders) } }
local hard = ns.Copy(ns.rules[1])
hard.name = 'Link |Hspell:12345|h[Fire]|h, "quotes", \\back\\slash, a new\nline, s5:abc;{x}'
hard.uid = "hard-1"; hard.folder = nil
hard.sound = { source = "file", enabled = true, file = "Interface\\AddOns\\MySounds\\ding.ogg" }
hard.extra = { alpha = 0.1, third = 1 / 3, big = 2 ^ 53 + 2, neg = -0.25, tiny = 1e-300, huge = 1e300, whole = 1234567890123,
  ids = { [12345] = true, [67890] = "x", [1] = 5, [3] = 7 }, list = { 1, 2, 3, "a", false }, gaps = { [1] = "a", [2] = "b", [4] = "d" },
  mixed = { 10, 20, x = "y", [2.5] = "half", [-1] = "neg", [true] = "t", [false] = "f" }, empty = {}, nested = { { { { { "deep" } } } } },
  numstr = { ["1"] = "string one", [1] = "number one" }, utf8 = "Fl\195\164che \226\152\133", ctl = "a\1b\0c\127\t" }
list[#list + 1] = { name = "Hard cases", data = { v = 1, name = "Hard cases", addonVersion = "0.6.84", rules = { hard }, folders = {} } }
list[#list + 1] = { name = "Empty", data = { v = 1, name = "Empty", addonVersion = "0.6.84", rules = {}, folders = {} } }
local out = L.logout()
return out, #list
'''

# session 2: this version's first login with the older backups
FIRST = COMMON + r'''
L.startup()
-- what the older backups hold, read before the login (the game has loaded the saved file; nothing of this version has touched them)
local ns = rawget(_G, "XayaUI_NS")
local ref, refDesc, names = {}, {}, {}
for i, p in ipairs(CueRulesDB.profiles or {}) do
  ref[i] = SV.Serialize(rawData(p)); names[i] = p.name
  refDesc[i] = ns.Share_DescribeRules(rawData(p))
end
local sizeOld = SV.Serialize(CueRulesDB.profiles)
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local asText, notText = 0, {}
for i, p in ipairs(ns.Backups()) do
  local d = rawData(p)
  if type(rawget(p, "text")) == "string" and type(d) == "table" and next(d) == nil then asText = asText + 1 else notText[#notText + 1] = tostring(p.name) end
end
check("[new] K1 after the first login every older backup is kept as one text, nothing of its rules as tables (" .. #ref .. " backups)",
  #ref == 4 and asText == #ref, table.concat(notText, ", "))
local same, diff = 0, {}
for i, p in ipairs(ns.Backups()) do
  if p.name == names[i] and SV.Serialize(ns.Copy(p.data)) == ref[i] then same = same + 1 else diff[#diff + 1] = tostring(p.name) end
end
check("X1 after the first login, what Load gets from each backup is exactly the older backup (every key and value)", same == #ref and #ref == 4, table.concat(diff, ", "))
local out = L.logout()
return out, ref, refDesc, names, sizeOld, SV.Serialize(out.XayaUI.CueRulesDB.profiles), R
'''

# session 3: the next login, the Profiles page and its buttons
NEXT = COMMON + r'''
local ref, refDesc, names = select(5, ...)
local reads = 0
local ns0
local function counting(on)
  if on then
    local read = ns0.BackupText and ns0.BackupText.Read
    debug.sethook(function() if read and debug.getinfo(2, "f").func == read then reads = reads + 1 end end, "c")
  else debug.sethook() end
end
L.startup()
ns0 = rawget(_G, "XayaUI_NS")
counting(true)
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
counting(false)
local ns = ns0
check("K2 the next login reads no backup text (" .. reads .. " reads)", reads == 0, reads)
local nOk = 0
for i, p in ipairs(ns.Backups()) do if SV.Serialize(ns.Copy(p.data)) == ref[i] then nOk = nOk + 1 end end
check("X2 after the next login too, what Load gets from each backup is exactly the older backup", nOk == #ref and #ref == 4, nOk .. " of " .. #ref)

if ns.LoadOptions then ns.LoadOptions() end; W.tick(0.1, 3)
ns = rawget(_G, "XayaUI_NS")
reads = 0; counting(true)
local built = ns.BuildOptionsTable()
built = ns.BuildOptionsTable()   -- (every redraw of the window builds the tree again)
counting(false)
local ex = built.args.profiles.args.export.args
check("P1 drawing the Profiles page twice reads no backup text (" .. reads .. " reads)", reads == 0, reads)
local descOk, bad = 0, {}
for i = 1, #ref do
  local g = ex["p" .. i]
  local shown = g and (g.xuiInfo or (g.args.desc and g.args.desc.name))   -- (the window shows the line in the group's title row: xuiInfo)
  if g and g.name == names[i] and shown == refDesc[i] then descOk = descOk + 1 else bad[#bad + 1] = tostring(shown) .. " vs " .. refDesc[i] end
end
check("P2 the Profiles page shows the same name and line under each backup as before (e.g. '" .. tostring(refDesc[1]):gsub("\n.*", "") .. "')", descOk == #ref, table.concat(bad, " | "))

-- the rules and groups after a load, with the new group ids replaced by their place in the list (they are made from the clock and a random number)
local function canonNow()
  local id = {}
  for i, f in ipairs(ns.folders) do id[f.id] = "F" .. i end
  local function m(v) return v ~= nil and (id[v] or ("?" .. tostring(v))) or nil end
  local fs, rs = {}, {}
  for i, f in ipairs(ns.folders) do local c = ns.Copy(f); c.id = m(c.id); c.parent = m(c.parent); if c.cGroup ~= nil then c.cGroup = m(c.cGroup) end; fs[i] = c end
  for i, r in ipairs(ns.rules) do local c = ns.Copy(r); c.folder = m(c.folder); for k in pairs(c) do if type(k) == "string" and k:sub(1, 1) == "_" then c[k] = nil end end; rs[i] = c end
  return SV.Serialize({ rules = rs, folders = fs })
end
local loadOk, textOk, lbad = 0, 0, {}
for i = 1, #ref do
  local old = SV.Load(ref[i])
  ns.Share_ApplyRules(ns.Copy(old), "replace"); W.tick(0.05, 2)
  local want = canonNow()
  local wantText = ns.Share.Encode("rules", old)
  ex["p" .. i].args.replace.func(); W.tick(0.05, 2)
  local got = canonNow()
  if got == want and #ns.rules == #(old.rules or {}) then loadOk = loadOk + 1 else lbad[#lbad + 1] = names[i] .. " (" .. #ns.rules .. " rules)" end
  ex["p" .. i].args.export.func()
  if ex.exportBox.get() == wantText then textOk = textOk + 1 end
end
check("X3 Profiles > Load (replace) gives exactly the rules and groups that loading the older backup gave (" .. #ref .. " backups; the full one " .. #(SV.Load(ref[1]).rules or {}) .. " rules)",
  loadOk == #ref, table.concat(lbad, ", "))
check("X4 Show export text gives the same text as for the older backup", textOk == #ref, textOk .. " of " .. #ref)

-- a backup saved now
ns.Share_ApplyRules(ns.Copy(SV.Load(ref[1])), "replace"); W.tick(0.05, 2)
local okS = ns.Backup_Save("Saved now", nil)
local now = SV.Serialize(ns.Share_SnapshotAll(nil, "Saved now"))
local p
for _, x in ipairs(ns.Backups()) do if x.name == "Saved now" then p = x end end
check("[new] S1 a backup saved now is kept as one text", okS and p and type(rawget(p, "text")) == "string" and next(rawData(p)) == nil, p and tostring(rawget(p, "text")):sub(1, 12))
check("S2 ... and loads back exactly what was saved", p and SV.Serialize(ns.Copy(p.data)) == now)
-- a damaged one: nothing changes, and chat says so
local said = {}
local P0 = ns.Print; ns.Print = function(fmt, ...) said[#said + 1] = select("#", ...) > 0 and fmt:format(...) or tostring(fmt) end
local before = canonNow()
if p and type(rawget(p, "text")) == "string" then rawset(p, "text", rawget(p, "text"):sub(1, 5000)) end
built = ns.BuildOptionsTable(); ex = built.args.profiles.args.export.args
local gi
for i = 1, 10 do if ex["p" .. i] and ex["p" .. i].name == "Saved now" then gi = i end end
if gi then ex["p" .. gi].args.replace.func(); W.tick(0.05, 2) end
ns.Print = P0
local line = table.concat(said, " | ")
check("[new] S3 a damaged backup: Load (replace) changes nothing and chat says it could not be read", gi and canonNow() == before and line:find("could not be read", 1, true) ~= nil, line)
return R
'''


def lua_mem_kb(src):
    """KB a saved value takes in memory once the game has loaded it (a fresh Lua; collected before and after)."""
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    sv = H.savedvars(L)
    f = L.eval("function(sv, src) collectgarbage('collect'); collectgarbage('collect'); local c0 = collectgarbage('count'); "
               "KEEP = sv.Load(src); collectgarbage('collect'); collectgarbage('collect'); return collectgarbage('count') - c0 end")
    return f(sv, src)


def session(code, saved, *extra):
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    world, loader, game, sv = GC._world(L, saved)
    fn = L.eval("function(src) return loadstring(src) end")(code)
    res = fn(world, loader, game, sv, *extra)
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    return L, sv, res, errs


def main():
    results, errors = [], []
    saved0, n, _made, _nf, e0 = GC.build_profile()
    errors += e0
    L1, sv1, (out1, nb), e1 = session(OLD, saved0)
    errors += e1
    saved1 = sv1.Serialize(out1)
    L2, sv2, (out2, ref, refDesc, names, sizeOld, sizeNew, r2), e2 = session(FIRST, saved1)
    errors += e2
    results += [(r2[i][1], r2[i][2]) for i in range(1, len(r2) + 1)]
    old_kb, new_kb = lua_mem_kb(sizeOld), lua_mem_kb(sizeNew)
    results.append(("[new] K3 the saved backups take far less memory once loaded: %.0f KB as text, %.0f KB as tables before (at most a third)"
                    % (new_kb, old_kb), new_kb <= old_kb / 3))
    saved2 = sv2.Serialize(out2)
    # (carried into session 3 as plain Lua values made there)
    L3 = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    world, loader, game, sv3 = GC._world(L3, saved2)
    t = lambda xs: L3.table_from({i + 1: xs[i] for i in range(len(xs))})
    ref_p = [ref[i] for i in range(1, len(ref) + 1)]
    desc_p = [refDesc[i] for i in range(1, len(refDesc) + 1)]
    names_p = [names[i] for i in range(1, len(names) + 1)]
    fn = L3.eval("function(src) return loadstring(src) end")(NEXT)
    r3 = fn(world, loader, game, sv3, t(ref_p), t(desc_p), t(names_p))
    errors += [world.errors[i] for i in range(1, len(world.errors) + 1)]
    results += [(r3[i][1], r3[i][2]) for i in range(1, len(r3) + 1)]
    bad = 0
    for name, ok in results:
        print(("PASS " if ok else "FAIL ") + name)
        bad += 0 if ok else 1
    for e in errors:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("(%d rules in the profile; %d older backups)" % (n, nb))
    print("%d checks, %d failed, %d Lua errors" % (len(results), bad, len(errors)))
    sys.exit(1 if bad or errors else 0)


if __name__ == "__main__":
    main()
