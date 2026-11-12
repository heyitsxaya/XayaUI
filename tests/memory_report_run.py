#!/usr/bin/env python3
"""Memory report (REQUEST-LOG A23 SD-38 / SD-41; her answer on the memory budget: "Measure first, then set (Recommended)").

What XayaUI holds in memory after login, and where it comes from, measured in the stand-in game (tests/harness/world.lua and
loader.lua, Lua 5.1 through lupa). The numbers are ESTIMATES, not game numbers: the game's Lua is a modified 64-bit Lua 5.1, so the
size of code, tables and strings is close to what is measured here, but the stand-in keeps every frame's points, scripts and children
in Lua tables (the game keeps them in C, outside an addon's memory), so frame records are measured and taken out, and the game's own
reading (the AddOns list, GetAddOnMemoryUsage) also counts garbage not yet collected. Compare the parts with each other and with the
next build; compare with her in-game readings only as a rough check (docs/plans/MEMORY-REPORT-2026-11-11.md says how).

Two saved-data profiles, each with XayaUI (Platform) and XayaUI Rules loaded and XayaUI Options not loaded (as at login):
  * a fresh install (nothing saved);
  * a realistic profile: tests/gate_common.py's ~300-entry rule list (buff, cooldown, bar, sound, icon, game-sound, hover and
    debuff rules with cues, static, dynamic and nested groups), saved by a logout, plus what a long-used install keeps, each made the
    way the code makes it: 3 rule backups (Profiles > Backups: 2 of hers and the one the settings move made, RuleShare.lua), the
    old copy of the rules the settings move left in CueRulesDB (Modules.lua 0c: "copy, never move"), 20 deleted rules in the Recycle
    Bin, 30 drafts (the default "Keep up to"), a full error log (50 entries, DebugRecord.lua), the detailed debug record an earlier
    Dev Assist left in CueRulesDB (3,000 lines, its default), the last bug report text, a talent scan of every class (XayaUITalentDB,
    TalentDump.lua's layout) and learned aura and cooldown data. What her own files hold is not known here (INFERENCE): each part is
    reported on its own, so her real file can be compared part by part.

Reported (no budget is enforced yet; SD-41: the budget is set from these numbers with her):
  (a) per file: compiled code (collectgarbage before / after loadstring) and what the file keeps after it ran;
  (b) per file: every table it builds at load (named holders: ns keys, file locals, globals) with its size (estimated by walking the
      tables: 64 B a table, 16 B an array slot, 40 B a hash slot, 37 B + length a string, 40 B + 8 B an upvalue a closure);
  (c) every saved variable and its sub-tables, as loaded (exact, collectgarbage around loading each part from its saved text);
  (d) the 20 largest holders after login;
  plus per-addon totals and the cost of loading XayaUI Options and opening / closing the window once.
Run: python3 tests/memory_report_run.py [--json PATH]   (Lua 5.1 via lupa; about a minute)"""
import json, os, sys, time
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H            # noqa: E402  (the whole-addon harness)
import gate_common as G    # noqa: E402  (the V27 gate's ~300-rule profile and stand-in game)

# the readings she sent from the game's AddOns list (REQUEST-LOG A23 SD-38 / SD-40, 2026-11-10), for the comparison only
IN_GAME = [("XayaUI Platform 0.6.85", "11 MB"), ("XayaUI Rules 0.7.0", "12 MB"), ("XayaUI Options 0.6.107", "976 KB"),
           ("EllesmereUI Chat / Mythic+ Tools / DataBars", "954 / 967 / 862 KB"), ("OPie 8.10.2", "2 MB"),
           ("KiraUI-Plugin 1.28", "6 MB"), ("Xaya Plugin (EllesmereUI)", "197 KB")]

# ---------------------------------------------------------------------------------------------------------------------------------
# session A: the realistic profile. gate_common's PROFILE_LUA makes the ~300 rules and logs out; EXTRAS_LUA runs just before that
# logout and adds what a long-used install keeps, through the addon's own functions where they exist.
# ---------------------------------------------------------------------------------------------------------------------------------
EXTRAS_LUA = r'''
return function(W, Ld)
local logout = Ld.logout
Ld.logout = function(...)
  local ns = rawget(_G, "XayaUI_NS")
  local CoreS, PlatS = ns.Settings("core"), ns.Settings("platform")
  local made = {}
  -- 1. rule backups (Profiles > Backups, CueRulesDB.profiles; RuleShare.lua ns.Backup_Save): two of hers, then the one the settings
  --    move made before its copy (RuleShare.lua migration guard "before": rules and groups as they were in CueRulesDB)
  ns.Backup_Save("Before the raid tier", { rules = true })
  ns.Backup_Save("Mythic+ set", { rules = true })
  local list = ns.Backups()
  local mv = "Rules before the settings move (2026-11-08 10:12)"
  list[#list + 1] = { name = mv, data = { v = 1, name = mv, addonVersion = "0.6.79", rules = ns.Copy(ns.rules), folders = ns.Copy(ns.folders) } }
  made.backups = #list
  -- 2. the old place the settings move kept (Modules.lua section 0c: "copy, never move"; "kept untouched until P6"): CueRulesDB still
  --    holds the rules' keys as they were when the move ran (here: the same rule list)
  CueRulesDB.rules = ns.Copy(ns.rules); CueRulesDB.folders = ns.Copy(ns.folders)
  CueRulesDB.barGroup = ns.Copy(CoreS.barGroup); CueRulesDB.bars = {}
  CueRulesDB.auraTracker = ns.Copy(CoreS.auraTracker); CueRulesDB.classLearn = nil
  -- 3. the Recycle Bin: 20 deleted rules (RuleBin.lua ns.RecycleRule; kept 7 days by default)
  for i = 1, 20 do
    local r = ns.NewRule(); r.name = "Deleted rule " .. i; r.enabled = true
    r.useBuff, r.buffID, r.buffState = true, 350000 + i, "present"
    r.visual.enabled, r.visual.kind = true, "spellicon"
    ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
    ns.RecycleRule(r)
  end
  made.recycled = #((ns.RecycleDB() or {}).items or {})
  -- 4. drafts: 30, the default "Keep up to" (Editor/Drafts.lua StoreDraft: the root rule and its cues, deep copies)
  local drafts = {}
  local roots = {}
  for _, r in ipairs(ns.rules) do if not r.parentUid and not r.isCue then roots[#roots + 1] = r end end
  for i = 1, 30 do
    local root = roots[(i * 7 - 1) % #roots + 1]
    local group = { ns.Copy(root) }
    for _, o in ipairs(ns.OutcomesOf and ns.OutcomesOf(root) or {}) do group[#group + 1] = ns.Copy(o) end
    drafts[i] = { id = tostring(root.uid) .. ":" .. (1762800000 + i), uid = root.uid, name = root.name, ts = 1762800000 + i, rules = group }
  end
  CoreS.drafts = drafts
  made.drafts = #drafts
  -- 5. the error log at its cap (DebugRecord.lua: 50 entries, message up to 700 and stack up to 900 characters), through the recorder
  local stack = ("[string \"@Interface/AddOns/XayaUI_Rules/Visual.lua\"]:1234: in function <Interface/AddOns/XayaUI_Rules/Visual.lua:1201>\n"):rep(7)
  for i = 1, 50 do
    ns.RecordError(("Interface/AddOns/XayaUI_Rules/Visual.lua:%d: attempt to index field 'icon' (a nil value) while drawing rule %d"):format(1000 + i, i),
      stack, "XayaUI_Rules")
  end
  made.errors = #(CueRulesDB.errorLog or {})
  -- 6. Dev Assist's detailed debug record (qa-installer-branch XayaUI_DevAssist/DevRecord.lua writes CueRulesDB.debugRecord, default
  --    "Lines kept" 3,000, trimmed at 3,200): left in the Platform's saved file by an install that had Dev Assist; nothing on main
  --    writes or trims it
  local lines = {}
  for i = 1, 3000 do
    lines[i] = ("%02d:%02d:%02d  %-8s Rule 'Buff %d' (%d): %s"):format(20 + (i % 3), i % 60, (i * 7) % 60, (i % 3 == 0) and "Trigger" or "Display",
      i % 66 + 1, 300000 + i % 66, (i % 2 == 0) and "aura gained, display shown at 36 x 36" or "aura lost, display hidden")
  end
  CueRulesDB.debugRecord = { lines = lines, dropped = 4200, started = "2026-11-08 20:14:02" }
  -- 7. the last bug report (Console.lua ns.ShowBugReport keeps the whole text in CueRulesDB.lastBugReport; with the record above, a
  --    Dev Assist-era report held its newest 1,500 lines)
  CueRulesDB.lastBugReport = "XayaUI bug report\n" .. table.concat(lines, "\n", 1501, 3000)
  -- 8. a talent scan of every class (/xui debug talents; TalentDump.lua's layout). Counts are an estimate of Midnight's trees: about 51
  --    class nodes, 45 nodes per spec and 3 hero trees of 11 nodes per class; 13 classes, 40 specs; 1 in 6 nodes is a choice of 2.
  local classes, sid, nid, eid, spell = {}, 60, 80000, 90000, 100000
  local specCount = { 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 4, 3, 3 }
  for cid = 1, 13 do
    local c = { name = "Class " .. cid, token = "CLASS" .. cid, specs = {}, nodes = {} }
    local specs = {}
    for s = 1, specCount[cid] do sid = sid + 1; c.specs[sid] = "Specialization " .. s; specs[#specs + 1] = sid end
    local function node(scope, set, hero)
      nid = nid + 1
      local choice = (nid % 6 == 0)
      local n = { t = choice and 2 or 0, max = (nid % 3 == 0) and 2 or 1, hero = hero, e = {}, scope = scope, choice = choice or nil, specs = {} }
      for s in pairs(set) do n.specs[s] = true end
      for k = 1, choice and 2 or 1 do
        eid, spell = eid + 1, spell + 1
        local e = { entry = eid, spell = spell, name = "Talent spell " .. spell, sub = hero }
        if spell % 3 ~= 0 then e.passive = true end
        if spell % 5 == 0 then e.cd = 30 + spell % 150 end
        n.e[k] = e
      end
      c.nodes[nid] = n
    end
    local all = {}
    for _, s in ipairs(specs) do all[s] = true end
    for _ = 1, 51 do node("class", all) end
    for _, s in ipairs(specs) do for _ = 1, 45 do node("spec", { [s] = true }) end end
    for h = 1, 3 do
      local set = { [specs[h]] = true, [specs[h % #specs + 1]] = true }
      for _ = 1, 11 do node("hero", set, 100 + cid * 3 + h) end
    end
    classes[cid] = c
  end
  XayaUITalentDB = { built = "2026-11-08 21:40", build = 120100, classes = classes, errors = {} }
  -- 9. learned data (Conditions.lua / Timing.lua / ClassLearn.lua): aura durations, stacks, cooldowns, proc glows, 4 specs learned
  local dur, stk, cd, glow = {}, {}, {}, {}
  for i = 1, 200 do dur[300000 + i] = 6 + i % 30 end
  for i = 1, 50 do stk[300000 + i] = 1 + i % 5 end
  for i = 1, 150 do cd[400000 + i] = 30 + i % 120 end
  for i = 1, 40 do glow[400000 + i] = { seen = 3 + i % 7, ok = 2 + i % 5 } end
  CoreS.learnedAuraDur, CoreS.learnedAuraStacks, CoreS.learnedCooldown, CoreS.procGlowSeen = dur, stk, cd, glow
  local specsL = {}
  for s = 1, 4 do
    local entries = {}
    for i = 1, 45 do entries[i] = { id = 400000 + s * 100 + i, name = "Spell " .. (s * 100 + i), kind = (i % 4 == 0) and "aura" or "cd", role = "Unsorted" } end
    specsL[70 + s] = { class = "Demon Hunter", classToken = "DEMONHUNTER", spec = "Spec " .. s, entries = entries, learned = "2026-11-0" .. s }
  end
  CoreS.classLearn = { build = "66666", specs = specsL }
  EXTRAS_MADE = made
  return logout(...)
end
end
'''

# the saved data, split into parts the way the game would load it (one saved variable per entry, one source text per sub-key; a big
# list sub-key with 40 entries or fewer is split into its entries so each backup / draft gets its own number). Text in the layout the
# game writes (positional entries for a list, ["key"] = value for the rest; without the game's tabs and "-- [n]" comments).
SPLIT_LUA = r'''
return function(OUT)
local function ser(v, out)
  local t = type(v)
  if t == "string" then out[#out + 1] = string.format("%q", v)
  elseif t == "number" then
    if v == math.floor(v) and math.abs(v) < 2^53 then out[#out + 1] = string.format("%d", v) else out[#out + 1] = string.format("%.17g", v) end
  elseif t == "boolean" then out[#out + 1] = v and "true" or "false"
  elseif t == "table" then
    out[#out + 1] = "{"
    local n = #v
    for i = 1, n do ser(v[i], out); out[#out + 1] = "," end
    local keys = {}
    for k, x in pairs(v) do
      local kt = type(k)
      if not (kt == "number" and k >= 1 and k <= n and k == math.floor(k)) and (kt == "string" or kt == "number" or kt == "boolean") then keys[#keys + 1] = k end
    end
    table.sort(keys, function(a, b) if type(a) ~= type(b) then return type(a) < type(b) end; return a < b end)
    for _, k in ipairs(keys) do
      local xt = type(v[k])
      if xt == "string" or xt == "number" or xt == "boolean" or xt == "table" then
        out[#out + 1] = "["; ser(k, out); out[#out + 1] = "]="; ser(v[k], out); out[#out + 1] = ","
      end
    end
    out[#out + 1] = "}"
  else out[#out + 1] = "nil" end
end
local function S(v) local o = {}; ser(v, o); return table.concat(o) end
local function count(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end
local res = {}
for _, addon in ipairs({ "XayaUI", "XayaUI_Rules" }) do
  local vars = {}
  for var, val in pairs(OUT[addon] or {}) do
    if type(val) == "table" then
      local parts = {}
      local keys = {}
      for k in pairs(val) do keys[#keys + 1] = k end
      table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
      for _, k in ipairs(keys) do
        local x = val[k]
        local p = { k = k, src = S(x), n = (type(x) == "table") and count(x) or nil, list = (type(x) == "table" and #x > 0 and count(x) == #x) or nil }
        if type(x) == "table" and #x > 0 and #x <= 40 and count(x) == #x then
          p.children = {}
          for i = 1, #x do
            local nm = (type(x[i]) == "table" and type(x[i].name) == "string") and x[i].name or nil
            p.children[i] = { k = i, src = S(x[i]), name = nm }
          end
        end
        parts[#parts + 1] = p
      end
      vars[#vars + 1] = { name = var, parts = parts }
    end
  end
  table.sort(vars, function(a, b) return a.name < b.name end)
  res[addon] = vars
end
return res
end
'''

# ---------------------------------------------------------------------------------------------------------------------------------
# shared Lua: the stand-in's frame records (estimate), and a loader that measures each file, each saved part and each event
# ---------------------------------------------------------------------------------------------------------------------------------
COMMON_LUA = r'''
local M = {}
local function pow2(n) if n <= 0 then return 0 end; local p = 1; while p < n do p = p * 2 end; return p end
M.pow2 = pow2
-- a table's own size: 64 B, an array part (power of two) of 16 B slots, a hash part (power of two) of 40 B nodes
function M.tsize(t, exactArray)
  local n = #t
  local h = 0
  for k in pairs(t) do if not (type(k) == "number" and k >= 1 and k <= n and k == math.floor(k)) then h = h + 1 end end
  return 64 + 16 * (exactArray and n or pow2(n)) + 40 * pow2(h)
end
-- the stand-in's own record of a frame (its table's "_" fields and the tables they hold: points, scripts, events, children, regions):
-- the game keeps these in C, outside an addon's memory, so they are taken out of the per-file numbers
function M.standinFrame(o, isFrame)
  local nU, size = 0, 0
  for k, v in pairs(o) do
    if type(k) == "string" and k:sub(1, 1) == "_" then
      nU = nU + 1
      if type(v) == "table" and k ~= "_parent" and not isFrame(v) then
        size = size + M.tsize(v)
        for _, x in pairs(v) do if type(x) == "table" and not isFrame(x) then size = size + M.tsize(x) end end
      end
    end
  end
  return size + 64 + 40 * pow2(nU)
end
function M.frameSet(W, i0)
  local set = {}
  for i = i0 or 1, #W.objects do set[W.objects[i]] = true end
  return set
end
return M
'''

MEASURE_LUA = r'''
return function(W, Ld, SPEC, CFG, CM)
-- a full collection, repeated until the count stops falling: each collection also halves Lua's lexer buffer (grown by a long string in a
-- saved file) and may shrink the string table, which would otherwise show up as a negative size in the next part measured
local function c()
  local last
  for _ = 1, 40 do collectgarbage("collect"); local n = collectgarbage("count"); if n == last then break end; last = n end
  return last * 1024
end
local OUT = { files = {}, sv = {}, events = {}, frames = {}, kinds = {} }
local isFrameT = {}
local function isFrame(v) return isFrameT[v] == true end
for _, o in ipairs(W.objects) do isFrameT[o] = true end
local function readFile(p) local f = io.open(p, "rb"); if not f then return nil end; local s = f:read("*a"); f:close(); return s end
local function standin(i0, i1)
  for i = i0, i1 do isFrameT[W.objects[i]] = true end
  local b = 0
  for i = i0, i1 do b = b + CM.standinFrame(W.objects[i], isFrame) end
  return b
end
local function kinds(i0, i1)
  local k = {}
  for i = i0, i1 do local o = W.objects[i]; k[o._kind or "?"] = (k[o._kind or "?"] or 0) + 1 end
  return k
end
-- one file, the way the game reads it (tests/harness/loader.lua runFile), measured
local function runFile(a, rel, private)
  if rel:lower():match("%.xml$") then
    local src = readFile(a.dir .. "/" .. rel) or ""
    local base = rel:match("^(.*)/[^/]*$") or ""
    src = src:gsub("<!%-%-.-%-%->", "")
    local subs = {}
    for tag, file in src:gmatch("<%s*(%a+)%s+file%s*=%s*\"([^\"]+)\"") do
      if tag == "Script" or tag == "Include" then subs[#subs + 1] = (base ~= "" and (base .. "/") or "") .. file:gsub("\\", "/") end
    end
    src = nil
    for _, s in ipairs(subs) do runFile(a, s, private) end
    return
  end
  local n0 = #W.objects
  local m0 = c()
  local src = readFile(a.dir .. "/" .. rel)
  if not src then OUT.files[#OUT.files + 1] = { addon = a.name, file = rel, missing = true }; return end
  local srcBytes = #src
  local ma = c()
  local fn = loadstring(src, "@Interface/AddOns/" .. a.name .. "/" .. rel)
  local m1 = c()
  src = nil
  if fn then W.safecall(fn, a.name, private) end
  fn = nil
  local m2 = c()
  local n1 = #W.objects
  OUT.files[#OUT.files + 1] = { addon = a.name, file = rel, srcBytes = srcBytes, compiled = m1 - ma, kept = m2 - m0, frames = n1 - n0,
    standin = standin(n0 + 1, n1) }
end
local function value(src) local f = assert(loadstring("return " .. src)); return (f()) end
-- one saved variable, part by part (exact: collectgarbage around each part, from its saved text)
local function loadVar(addon, var)
  local m0 = c()
  local t = {}
  local rec = { addon = addon, name = var.name, parts = {} }
  for _, p in ipairs(var.parts) do
    local a0 = c()
    local pr = { k = p.k, textBytes = #p.src, n = p.n, list = p.list }
    if p.children then
      local sub = {}
      t[p.k] = sub
      pr.children = {}
      for _, ch in ipairs(p.children) do
        local b0 = c()
        sub[ch.k] = value(ch.src)
        local b1 = c()
        pr.children[#pr.children + 1] = { k = ch.k, name = ch.name, bytes = b1 - b0, textBytes = #ch.src }
      end
    else
      t[p.k] = value(p.src)
    end
    pr.bytes = c() - a0
    rec.parts[#rec.parts + 1] = pr
  end
  rawset(_G, var.name, t)
  rec.bytes = c() - m0
  OUT.sv[#OUT.sv + 1] = rec
end
local function event(label, fn)
  local n0 = #W.objects
  local m0 = c()
  fn()
  local m1 = c()
  local n1 = #W.objects
  OUT.events[#OUT.events + 1] = { label = label, bytes = m1 - m0, frames = n1 - n0, standin = standin(n0 + 1, n1), kinds = kinds(n0 + 1, n1) }
end
-- an addon the way the game loads it: files, then its saved variables, then ADDON_LOADED
local function loadAddon(name)
  local a = Ld.addons[name]
  if Ld.loaded[name] then return true end
  for _, d in ipairs(a.deps) do loadAddon(d) end
  local private = {}
  a.private = private
  for _, rel in ipairs(a.files) do runFile(a, rel, private) end
  local svs = {}
  for _, v in ipairs(SPEC[name] or {}) do svs[v.name] = v end
  for _, var in ipairs(a.sv) do
    if svs[var] then loadVar(name, svs[var]) else OUT.sv[#OUT.sv + 1] = { addon = name, name = var, bytes = 0, parts = {}, absent = true } end
  end
  Ld.loaded[name] = true
  Ld.loadedOrder[#Ld.loadedOrder + 1] = name
  event(name .. ": ADDON_LOADED", function() W.fire("ADDON_LOADED", name, false) end)
  return true
end
OUT.base = c()
loadAddon("XayaUI")
if CFG.rules then loadAddon("XayaUI_Rules") end
event("login: PLAYER_LOGIN, PLAYER_ENTERING_WORLD, first 2 s", function()
  W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
end)
event("10 s idle out of combat", function() W.tick(0.1, 100) end)
OUT.atLogin = c()
-- the reading before a collection (the game's AddOns list shows this kind of number: it includes garbage not yet collected)
W.tick(0.1, 50)
OUT.rawBeforeCollect = collectgarbage("count") * 1024
OUT.afterCollect = c()
local ns = rawget(_G, "XayaUI_NS")
OUT.rules = ns and ns.rules and #ns.rules or 0
OUT.folders = ns and ns.folders and #ns.folders or 0
if CFG.strip and ns and ns.NewRule and ns.NormalizeRule and ns.Copy then
  -- what if a rule kept only what differs from a new rule (as AceDB does: values equal to a default are not saved)? Table memory of a
  -- copy of every rule as it is, against a copy without the values a new, normalized rule already has (strings are shared, so this
  -- compares the tables only; cues are compared with a plain rule's defaults, so they shrink less than they could)
  local d = ns.NewRule(); ns.NormalizeRule(d)
  local function strip(v, def)
    local o = {}
    for k, x in pairs(v) do
      local dx = (type(def) == "table") and def[k] or nil
      if type(x) == "table" then
        local sx = strip(x, dx)
        if next(sx) ~= nil or type(dx) ~= "table" then o[k] = sx end
      elseif x ~= dx then o[k] = x end
    end
    return o
  end
  local m0 = c(); local full = ns.Copy(ns.rules); local m1 = c(); full = nil
  local m2 = c(); local st = {}; for i, r in ipairs(ns.rules) do st[i] = strip(r, d) end; local m3 = c(); st = nil
  OUT.stripFull, OUT.stripped = m1 - m0, m3 - m2
  d = nil; c()
end
if CFG.options and ns then
  -- XayaUI Options, as /xui loads it: each file measured (C_AddOns.LoadAddOn goes through the measuring loader)
  local before = c()
  local nf0 = #OUT.files
  C_AddOns.LoadAddOn = function(n) return loadAddon(n) end
  LoadAddOn = C_AddOns.LoadAddOn
  local t0 = os.clock()
  local ok = ns.LoadOptions and ns.LoadOptions()
  OUT.optionsLoaded = ok and true or false
  OUT.optionsLoadBytes = c() - before
  OUT.optionsFiles = { nf0 + 1, #OUT.files }
  local n0 = #W.objects
  local m0 = c()
  pcall(ns.ToggleUI); W.tick(0.05, 10)
  OUT.optionsOpenBytes = c() - m0
  OUT.optionsOpenFrames = #W.objects - n0
  OUT.optionsOpenStandin = standin(n0 + 1, #W.objects)
  pcall(ns.ToggleUI); W.tick(0.1, 20)
  OUT.optionsClosedBytes = c() - m0
  OUT.optionsClosedStandin = standin(n0 + 1, #W.objects)
  OUT.optionsSeconds = os.clock() - t0
end
return OUT
end
'''

# ---------------------------------------------------------------------------------------------------------------------------------
# the holders: who keeps what (estimated by walking the tables; one owner per object, the first that reaches it)
# ---------------------------------------------------------------------------------------------------------------------------------
WALK_LUA = r'''
return function(W, Ld, SPEC, CM)
local STR, CLO, UPV = 37, 40, 40
local OUT = { walks = {} }
local readFile = function(p) local f = io.open(p, "rb"); if not f then return nil end; local s = f:read("*a"); f:close(); return s end
local baseG = {}
for k, v in pairs(_G) do baseG[k] = true end
local n0 = #W.objects
local seen = {}              -- object -> true (kept across the load-time walks, so each shows only what is new)
local fileOfKey = {}         -- ns key -> the file that defined it
local fileOfGlobal = {}
local frameFile = {}         -- index range -> file / phase
local private = {}           -- addon -> private table
local function src(fn) local i = debug.getinfo(fn, "S"); return i and i.source or "?" end
local function addonFile(s) return s and s:match("^@Interface/AddOns/(.+)$") end
-- mark what the stand-in itself holds (the game's API, the stand-in's frames and tables), stopping at XayaUI's own things
local function standinMark(stopAt, isAddonFrame, found)
  local stack = { _G, W, Ld, debug.getregistry() }
  for i = 1, n0 do stack[#stack + 1] = W.objects[i] end
  seen[W.objects] = true
  while #stack > 0 do
    local v = stack[#stack]; stack[#stack] = nil
    local t = type(v)
    if (t == "table" or t == "function") and not seen[v] and not stopAt[v] and not isAddonFrame[v] then
      if t == "function" then
        local f = addonFile(src(v))
        if f then found[#found + 1] = v
        else
          seen[v] = true
          local j = 1
          while true do local nm, x = debug.getupvalue(v, j); if not nm then break end; stack[#stack + 1] = x; j = j + 1 end
          local e = getfenv(v); if e then stack[#stack + 1] = e end
        end
      else
        seen[v] = true
        if v == _G then
          for k, x in pairs(v) do if baseG[k] then stack[#stack + 1] = x end end
        else
          for k, x in pairs(v) do stack[#stack + 1] = k; stack[#stack + 1] = x end
        end
        local mt = getmetatable(v); if type(mt) == "table" then stack[#stack + 1] = mt end
      end
    end
  end
end
-- walk one holder; functions found are sized as closures and their upvalues become holders of their own (queued)
local function walkHolder(h, root, queue, isAddonFrame, frameFields)
  local stack = { root }
  while #stack > 0 do
    local v = stack[#stack]; stack[#stack] = nil
    local t = type(v)
    if t == "string" then
      if not seen[v] then seen[v] = true; h.bytes = h.bytes + STR + #v; h.strings = h.strings + 1 end
    elseif t == "table" then
      if not seen[v] and not (isAddonFrame[v] and v ~= root) then
        seen[v] = true
        h.bytes = h.bytes + CM.tsize(v); h.tables = h.tables + 1
        for k, x in pairs(v) do
          if not (frameFields and v == root and type(k) == "string" and k:sub(1, 1) == "_") then stack[#stack + 1] = k; stack[#stack + 1] = x end
        end
        local mt = getmetatable(v); if type(mt) == "table" then stack[#stack + 1] = mt end
      end
    elseif t == "function" then
      if not seen[v] then
        seen[v] = true
        local f = addonFile(src(v))
        local nups = debug.getinfo(v, "u").nups or 0
        h.bytes = h.bytes + CLO + 8 * math.max(0, nups - 1) + UPV * nups; h.closures = h.closures + 1
        for j = 1, nups do
          local nm, x = debug.getupvalue(v, j)
          local xt = type(x)
          if xt == "table" or xt == "function" then
            if not seen[x] then queue[#queue + 1] = { name = (f or "?") .. ": local " .. tostring(nm), file = f, root = x } end
          elseif xt == "string" then stack[#stack + 1] = x end
        end
      end
    end
  end
end
local function newHolder(name, file, kind) return { name = name, file = file, kind = kind, bytes = 0, tables = 0, strings = 0, closures = 0 } end
local function walk(label, opts)
  local holders = {}
  local queue = {}
  local isAddonFrame = {}
  for i = n0 + 1, #W.objects do isAddonFrame[W.objects[i]] = true end
  local stopAt = {}
  for _, p in pairs(private) do stopAt[p] = true end
  local ns = rawget(_G, "XayaUI_NS"); if ns then stopAt[ns] = true end
  local svNames = {}
  for _, a in pairs(Ld.addons) do for _, var in ipairs(a.sv) do svNames[var] = true; local t = rawget(_G, var); if type(t) == "table" then stopAt[t] = true end end end
  local found = {}
  standinMark(stopAt, isAddonFrame, found)
  local function run(h, root, frameFields)
    walkHolder(h, root, queue, isAddonFrame, frameFields)
    if h.bytes > 0 then holders[#holders + 1] = h end
  end
  -- 1. saved variables, by sub-key (unless left out)
  if not opts.noSV then
    for _, var in ipairs({ "CueRulesDB", "XayaUIRulesDB", "XayaUITalentDB" }) do
      local t = rawget(_G, var)
      if type(t) == "table" and not seen[t] then
        local keys = {}
        for k in pairs(t) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        local shell = newHolder(var .. " (its own table)", nil, "saved"); shell.bytes = CM.tsize(t); seen[t] = true; holders[#holders + 1] = shell
        for _, k in ipairs(keys) do run(newHolder(var .. "." .. tostring(k), nil, "saved"), t[k]) end
      end
    end
  else
    for var in pairs(svNames) do local t = rawget(_G, var); if type(t) == "table" then seen[t] = true end end
  end
  -- 2. the shared namespace (XayaUI_NS) and each addon's private table, key by key
  local fnH = {}
  local function nsWalk(tbl, prefix)
    if type(tbl) ~= "table" then return end
    if not seen[tbl] then seen[tbl] = true; local h = newHolder(prefix .. " (the table itself)", nil, "ns"); h.bytes = CM.tsize(tbl); holders[#holders + 1] = h end
    local keys = {}
    for k in pairs(tbl) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(keys) do
      local v = tbl[k]
      local f = fileOfKey[k]
      if type(v) == "function" then
        local key = tostring(f or "?")
        local h = fnH[key]
        if not h then h = newHolder("functions in " .. prefix .. " from " .. key .. " (closures)", f, "functions"); fnH[key] = h; holders[#holders + 1] = h end
        walkHolder(h, v, queue, isAddonFrame)
      else
        run(newHolder(prefix .. "." .. tostring(k), f, "ns"), v)
      end
    end
  end
  nsWalk(ns, "ns")
  for name, p in pairs(private) do if p ~= ns then nsWalk(p, name .. " private") end end
  -- 3. globals XayaUI made
  local gk = {}
  for k in pairs(_G) do if not baseG[k] then gk[#gk + 1] = k end end
  table.sort(gk, function(a, b) return tostring(a) < tostring(b) end)
  for _, k in ipairs(gk) do
    local v = rawget(_G, k)
    if not svNames[k] and not isAddonFrame[v] then run(newHolder("_G." .. tostring(k), fileOfGlobal[k], "global"), v) end
  end
  -- 4. XayaUI's frames: the fields XayaUI set on them (the stand-in's own "_" records are left out) and their scripts
  local fh = {}
  for i = n0 + 1, #W.objects do
    local o = W.objects[i]
    local who = "?"
    for _, r in ipairs(frameFile) do if i >= r[1] and i <= r[2] then who = r[3] end end
    local h = fh[who]
    if not h then h = newHolder("frames made by " .. who .. ": XayaUI's fields and scripts on them", who, "frames"); fh[who] = h; h.frames = 0 end
    h.frames = h.frames + 1
    if not seen[o] then
      seen[o] = true
      local nAddon = 0
      for k, x in pairs(o) do
        if type(k) == "string" and k:sub(1, 1) == "_" then
          if k == "_scripts" and type(x) == "table" then for _, s in pairs(x) do walkHolder(h, s, queue, isAddonFrame) end end
        else
          nAddon = nAddon + 1
          walkHolder(h, k, queue, isAddonFrame)
          if not isAddonFrame[x] then walkHolder(h, x, queue, isAddonFrame) end   -- (a region or child frame is counted as its own frame)
        end
      end
      h.bytes = h.bytes + 40 * nAddon
    end
  end
  for _, h in pairs(fh) do if h.bytes > 0 then holders[#holders + 1] = h end end
  -- 5. XayaUI functions the stand-in holds (timers, hooks, event dispatch): closures, their upvalues queued
  local cb = newHolder("callbacks the game holds (timers, hooks)", nil, "functions")
  for _, fn in ipairs(found) do walkHolder(cb, fn, queue, isAddonFrame) end
  if cb.bytes > 0 then holders[#holders + 1] = cb end
  -- 6. file locals, wave by wave (a local found inside another local's closures is queued again)
  local qi = 1
  while qi <= #queue do
    local q = queue[qi]; qi = qi + 1
    if not seen[q.root] then run(newHolder(q.name, q.file, "local"), q.root) end
  end
  table.sort(holders, function(a, b) return a.bytes > b.bytes end)
  OUT.walks[#OUT.walks + 1] = { label = label, holders = holders }
end
-- a plain load (no measuring), recording which file defined each ns key and global, and which file made each frame
local function nsKeys(t) local s = {}; if type(t) == "table" then for k in pairs(t) do s[k] = true end end; return s end
local function runFile(a, rel, p)
  if rel:lower():match("%.xml$") then
    local s = readFile(a.dir .. "/" .. rel) or ""
    local base = rel:match("^(.*)/[^/]*$") or ""
    s = s:gsub("<!%-%-.-%-%->", "")
    for tag, file in s:gmatch("<%s*(%a+)%s+file%s*=%s*\"([^\"]+)\"") do
      if tag == "Script" or tag == "Include" then runFile(a, (base ~= "" and (base .. "/") or "") .. file:gsub("\\", "/"), p) end
    end
    return
  end
  local s = readFile(a.dir .. "/" .. rel)
  local fn = s and loadstring(s, "@Interface/AddOns/" .. a.name .. "/" .. rel)
  local ns0 = nsKeys(rawget(_G, "XayaUI_NS") or p)
  local g0 = nsKeys(_G)
  local i0 = #W.objects
  if fn then W.safecall(fn, a.name, p) end
  local here = a.name .. "/" .. rel
  for k in pairs(rawget(_G, "XayaUI_NS") or p) do if not ns0[k] and not fileOfKey[k] then fileOfKey[k] = here end end
  for k in pairs(_G) do if not g0[k] and not fileOfGlobal[k] then fileOfGlobal[k] = here end end
  if #W.objects > i0 then frameFile[#frameFile + 1] = { i0 + 1, #W.objects, here } end
end
local function value(s) local f = assert(loadstring("return " .. s)); return (f()) end
local function phase(label, fn)
  local i0 = #W.objects
  fn()
  if #W.objects > i0 then frameFile[#frameFile + 1] = { i0 + 1, #W.objects, label } end
end
local function loadAddon(name, walkLabel)
  local a = Ld.addons[name]
  local p = {}
  a.private = p; private[name] = p
  for _, rel in ipairs(a.files) do runFile(a, rel, p) end
  if walkLabel then walk(walkLabel, { noSV = true }) end
  for _, var in ipairs(SPEC[name] or {}) do
    local t = {}
    for _, part in ipairs(var.parts) do
      if part.children then local sub = {}; t[part.k] = sub; for _, ch in ipairs(part.children) do sub[ch.k] = value(ch.src) end
      else t[part.k] = value(part.src) end
    end
    rawset(_G, var.name, t)
  end
  Ld.loaded[name] = true
  Ld.loadedOrder[#Ld.loadedOrder + 1] = name
  phase(name .. " ADDON_LOADED", function() W.fire("ADDON_LOADED", name, false) end)
end
loadAddon("XayaUI", "built by XayaUI's files")
loadAddon("XayaUI_Rules", "built by XayaUI Rules' files")
phase("login", function() W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20); W.tick(0.1, 100) end)
seen = {}
walk("after login", {})
return OUT
end
'''


def compile_alone(path, chunk):
    """Compiled size of one file in a Lua state of its own (no strings shared with other files, no string-table growth from them)."""
    L = lua()
    return L.eval("""function(path, chunk)
      local f = io.open(path, "rb"); local s = f:read("*a"); f:close()
      local function c() local last; for _ = 1, 40 do collectgarbage("collect"); local n = collectgarbage("count"); if n == last then break end; last = n end; return last * 1024 end
      local m0 = c(); local fn = loadstring(s, chunk); local m1 = c(); fn = nil
      return m1 - m0
    end""")(path, chunk)


def lua():
    return H.lua51.LuaRuntime(unpack_returned_tuples=True)


def py(v):
    return H.lua_to_py(v) if H.lupa_type(v) == "table" else v


def build_realistic():
    """Session A: the ~300-entry rule list (tests/gate_common.py) plus EXTRAS_LUA, saved by a logout; returned as parts (SPLIT_LUA)."""
    L = lua()
    world, loader, game, sv = G._world(L)
    L.eval("function(src) return loadstring(src)() end")(EXTRAS_LUA)(world, loader)
    out, n, made, nf = L.eval("function(src, W, Ld, G) return loadstring(src)()(W, Ld, G) end")(G.PROFILE_LUA, world, loader, game)
    errors = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    spec = L.eval("function(src, o) return loadstring(src)()(o) end")(SPLIT_LUA, out)
    extras = py(L.globals().EXTRAS_MADE)
    return to_spec(spec), {"rules": n, "groups": nf, "kinds": py(made), "extras": extras}, errors


def to_spec(spec):
    """Lua parts -> Python (strings and numbers only), so each measuring session gets its own copy."""
    out = {}
    for addon in ("XayaUI", "XayaUI_Rules"):
        vars_ = []
        lv = spec[addon]
        for i in range(1, len(lv) + 1 if lv else 1):
            v = lv[i]
            parts = []
            for j in range(1, len(v.parts) + 1):
                p = v.parts[j]
                d = {"k": p.k, "src": p.src, "n": p.n, "list": bool(p.list)}
                if p.children:
                    d["children"] = [{"k": p.children[x].k, "src": p.children[x].src, "name": p.children[x].name}
                                     for x in range(1, len(p.children) + 1)]
                parts.append(d)
            vars_.append({"name": v.name, "parts": parts})
        out[addon] = vars_
    return out


def spec_to_lua(L, spec):
    t = L.table()
    for addon, vars_ in spec.items():
        lv = L.table()
        for i, v in enumerate(vars_, 1):
            parts = L.table()
            for j, p in enumerate(v["parts"], 1):
                lp = L.table()
                lp["k"], lp["src"], lp["n"], lp["list"] = p["k"], p["src"], p["n"], p.get("list")
                if p.get("children"):
                    ch = L.table()
                    for x, c in enumerate(p["children"], 1):
                        lc = L.table(); lc["k"], lc["src"], lc["name"] = c["k"], c["src"], c["name"]; ch[x] = lc
                    lp["children"] = ch
                parts[j] = lp
            lvv = L.table(); lvv["name"] = v["name"]; lvv["parts"] = parts
            lv[i] = lvv
        t[addon] = lv
    return t


def measure(spec, options=True, rules=True, strip=False):
    L = lua()
    world, loader, game, sv = G._world(L)
    cm = L.execute(COMMON_LUA)
    lspec = spec_to_lua(L, spec)
    cfg = L.table(); cfg["options"] = options; cfg["rules"] = rules; cfg["strip"] = strip
    out = L.eval("function(src, W, Ld, S, C, CM) return loadstring(src)()(W, Ld, S, C, CM) end")(MEASURE_LUA, world, loader, lspec, cfg, cm)
    errors = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    return py(out), errors


def walk(spec):
    L = lua()
    world, loader, game, sv = G._world(L)
    cm = L.execute(COMMON_LUA)
    out = L.eval("function(src, W, Ld, S, CM) return loadstring(src)()(W, Ld, S, CM) end")(WALK_LUA, world, loader, spec_to_lua(L, spec), cm)
    return py(out)


def from_saved_dir(path):
    """Her own SavedVariables files (WTF/Account/<account>/SavedVariables/XayaUI.lua and XayaUI_Rules.lua, never committed) as parts."""
    L = lua()
    sv = H.savedvars(L)
    out = L.table()
    for addon in ("XayaUI", "XayaUI_Rules"):
        f = os.path.join(path, addon + ".lua")
        env = sv.LoadFile(open(f, encoding="utf-8", errors="replace").read()) if os.path.isfile(f) else L.table()
        out[addon] = env
    spec = L.eval("function(src, o) return loadstring(src)()(o) end")(SPLIT_LUA, out)
    return to_spec(spec)


# ---------------------------------------------------------------------------------------------------------------------------------
# the report
# ---------------------------------------------------------------------------------------------------------------------------------
def kb(b):
    return "%.1f KB" % (b / 1024.0) if abs(b) < 1024 * 1024 else "%.2f MB" % (b / 1048576.0)


def totals(m):
    """Per addon, without the stand-in's frame records: compiled code, kept by its files, saved variables, ADDON_LOADED; and login."""
    t = {}
    for f in m["files"]:
        if f.get("missing"):
            continue
        d = t.setdefault(f["addon"], {"compiled": 0, "kept": 0, "sv": 0, "loaded": 0, "frames": 0, "files": 0})
        d["compiled"] += f["compiled"]; d["kept"] += f["kept"] - f["standin"]; d["frames"] += f["frames"]; d["files"] += 1
    for s in m["sv"]:
        t.setdefault(s["addon"], {"compiled": 0, "kept": 0, "sv": 0, "loaded": 0, "frames": 0, "files": 0})["sv"] += s["bytes"]
    login = 0
    for e in m["events"]:
        if e["label"].endswith(": ADDON_LOADED"):
            a = e["label"].split(":")[0]
            if a in t:
                t[a]["loaded"] += e["bytes"] - e["standin"]; t[a]["frames"] += e["frames"]
        else:
            login += e["bytes"] - e["standin"]
    return t, login


def platform_rules(both, plat):
    """The Platform's share = the Platform-only session; XayaUI Rules' share = both minus that (its files, saved data, load and login)."""
    tb, lb = totals(both)
    tp, lp = totals(plat)
    p = tp["XayaUI"]
    ptotal = p["kept"] + p["sv"] + p["loaded"] + lp
    r = tb["XayaUI_Rules"]
    rlogin = (tb["XayaUI"]["kept"] + tb["XayaUI"]["sv"] + tb["XayaUI"]["loaded"] + lb) - ptotal
    rtotal = r["kept"] + r["sv"] + r["loaded"] + rlogin
    return {"platform": dict(p, login=lp, total=ptotal), "rules": dict(r, login=rlogin, total=rtotal)}


def report(res):
    out = []
    P = out.append
    info = res["profile"]
    P("XayaUI memory report (stand-in estimates, Lua 5.1 via lupa; not game numbers)")
    P("realistic profile: %d entries in the rule list (%s), %d groups; extras: %s" % (
        info["rules"], ", ".join("%s %d" % kv for kv in sorted(info["kinds"].items())), info["groups"],
        ", ".join("%s %d" % kv for kv in sorted(info["extras"].items()))))
    for name in ("fresh", "realistic") + (("saved",) if "saved" in res else ()):
        s = res[name]["split"]
        P("")
        P("== totals at login, %s (XayaUI Options not loaded; the stand-in's frame records taken out)" % name)
        for a, lab in (("platform", "XayaUI Platform"), ("rules", "XayaUI Rules")):
            d = s[a]
            P("  %-16s total %10s = code and tables of its files %10s (compiled code %s) + saved variables %10s + ADDON_LOADED %9s + login and first 12 s %9s" % (
                lab, kb(d["total"]), kb(d["kept"]), kb(d["compiled"]), kb(d["sv"]), kb(d["loaded"]), kb(d["login"])))
        m = res[name]["both"]
        P("  frames made by the end of login: %d (in the game these are C objects outside the addons' memory; the stand-in's records of them, %s, are taken out)" % (
            sum(f["frames"] for f in m["files"]) + sum(e["frames"] for e in m["events"]),
            kb(sum(f["standin"] for f in m["files"]) + sum(e["standin"] for e in m["events"]))))
        for e in m["events"]:
            P("    %-58s %9s  (frames %d%s)" % (e["label"], kb(e["bytes"] - e["standin"]), e["frames"],
                ("" if not e.get("kinds") else ": " + ", ".join("%s %d" % kv for kv in sorted(e["kinds"].items())))))
    m = res["fresh"]["both"]
    P("")
    P("== (a) per file: source; compiled code (collectgarbage around loadstring, in load order, and alone in a Lua state of its own); kept after")
    P("   the file ran (its code and the tables it built; stand-in frame records out). '*' = the in-order number includes a one-time growth of")
    P("   Lua's string table, which all files share (not this file's own)")
    folders = H.find_addons()
    for f in m["files"]:
        if f.get("missing"):
            P("  %s/%s: MISSING" % (f["addon"], f["file"])); continue
        alone = compile_alone(os.path.join(folders[f["addon"]], f["file"]), "@Interface/AddOns/%s/%s" % (f["addon"], f["file"]))
        f["alone"] = alone
        P("  %-46s source %9s  compiled %9s%s (alone %9s)  kept %9s  frames %d" % (f["addon"] + "/" + f["file"], kb(f["srcBytes"]),
            kb(f["compiled"]), "*" if f["compiled"] - alone > 64 * 1024 else " ", kb(alone), kb(f["kept"] - f["standin"]), f["frames"]))
    ed = [f for f in m["files"] if f["addon"] == "XayaUI_Rules" and f["file"].startswith("Editor/")]
    P("  XayaUI Rules' rule editor (Editor/, %d files, read at login): compiled %s, kept %s" % (len(ed), kb(sum(f["compiled"] for f in ed)),
        kb(sum(f["kept"] - f["standin"] for f in ed))))
    P("")
    P("== (b) tables each file builds at load (realistic profile; estimated by walking them; 1 KB and up, then the rest per file)")
    for w in res["walk"]["walks"][:2]:
        P("  -- " + w["label"])
        byfile = {}
        for h in w["holders"]:
            if h["bytes"] <= 0:
                continue
            byfile.setdefault(h.get("file") or "(no file: the namespace table)", []).append(h)
        for fname, hs in sorted(byfile.items(), key=lambda kv: -sum(h["bytes"] for h in kv[1])):
            tot = sum(h["bytes"] for h in hs)
            big = [h for h in hs if h["bytes"] >= 1024]
            P("    %-48s %9s in %d holders" % (fname, kb(tot), len(hs)))
            for h in big:
                P("        %9s  %s (%d tables, %d strings, %d closures)" % (kb(h["bytes"]), h["name"], h["tables"], h["strings"], h["closures"]))
            rest = [h for h in hs if h["bytes"] < 1024]
            if rest:
                P("        %9s  %d smaller holders" % (kb(sum(h["bytes"] for h in rest)), len(rest)))
    P("")
    P("== (c) saved variables as loaded (exact: collectgarbage around loading each part from its saved text; text = compact saved text)")
    for name in ("fresh", "realistic") + (("saved",) if "saved" in res else ()):
        P("  -- " + name)
        for sv in res[name]["both"]["sv"]:
            if sv.get("absent"):
                P("    %-16s (none saved)" % sv["name"]); continue
            P("    %-16s %10s  (text %s)" % (sv["name"], kb(sv["bytes"]), kb(sum(p["textBytes"] for p in sv["parts"]))))
            for p in sorted(sv["parts"], key=lambda p: -p["bytes"]):
                if p["bytes"] < 1024 and name != "fresh":
                    continue
                P("        %-24s %10s  text %9s%s" % (str(p["k"]), kb(p["bytes"]), kb(p["textBytes"]),
                    ("  (%d entries, %s each)" % (p["n"], kb(p["bytes"] / p["n"]))) if p.get("list") else
                    (("  (%d keys)" % p["n"]) if p.get("n") else "")))
                if p["bytes"] >= 100 * 1024 and len(p.get("children") or []) <= 12:
                    for ch in p.get("children") or []:
                        P("            [%s] %-44s %9s" % (ch["k"], (ch.get("name") or "")[:44], kb(ch["bytes"])))
            small = [p for p in sv["parts"] if p["bytes"] < 1024]
            if small and name != "fresh":
                P("        %d smaller parts, %s together" % (len(small), kb(sum(p["bytes"] for p in small))))
    rm = res["realistic"]["both"]
    if rm.get("stripFull"):
        P("  what if each rule kept only what differs from a new rule: its tables %s instead of %s (%.0f%% less; INFERENCE: lossless only if every reader goes through NormalizeRule)" % (
            kb(rm["stripped"]), kb(rm["stripFull"]), 100.0 * (1 - rm["stripped"] / rm["stripFull"])))
    P("")
    P("== (d) the 20 largest holders after login (estimated by walking; each object counted once, by the first holder that reaches it)")
    w = res["walk"]["walks"][-1]
    for i, h in enumerate(w["holders"][:20], 1):
        P("  %2d. %9s  %s%s" % (i, kb(h["bytes"]), h["name"], (" [%s]" % h["file"]) if h.get("file") and h["file"] not in h["name"] else ""))
    wt = sum(h["bytes"] for h in w["holders"])
    s = res["realistic"]["split"]
    exact = s["platform"]["total"] + s["rules"]["total"]
    code = s["platform"]["compiled"] + s["rules"]["compiled"]
    P("  check: the walk finds %s of tables, strings and closures; with the compiled code (%s) that is %s against the measured %s (%.0f%%)" % (
        kb(wt), kb(code), kb(wt + code), kb(exact), 100.0 * (wt + code) / exact))
    P("  fresh install, 10 largest:")
    for i, h in enumerate(res["walk_fresh"]["walks"][-1]["holders"][:10], 1):
        P("  %2d. %9s  %s" % (i, kb(h["bytes"]), h["name"]))
    if rm.get("optionsLoaded"):
        P("")
        P("== XayaUI Options (loads on demand: /xui), realistic profile")
        of = [f for f in rm["files"] if f["addon"] == "XayaUI_Options"]
        P("  load: %s (its files: compiled %s, kept %s)" % (kb(rm["optionsLoadBytes"] - sum(f["standin"] for f in of)),
            kb(sum(f["compiled"] for f in of)), kb(sum(f["kept"] - f["standin"] for f in of))))
        for f in sorted(of, key=lambda f: -(f["kept"] - f["standin"]))[:12]:
            P("    %-58s compiled %9s  kept %9s" % (f["file"], kb(f["compiled"]), kb(f["kept"] - f["standin"])))
        P("  window open (rule editor built, %d frames): +%s; after closing it and a collection: +%s kept (stand-in frame records out; %.1f s of stand-in time)" % (
            rm["optionsOpenFrames"], kb(rm["optionsOpenBytes"] - rm["optionsOpenStandin"]), kb(rm["optionsClosedBytes"] - rm["optionsClosedStandin"]),
            rm["optionsSeconds"]))
    P("")
    P("== her in-game readings (AddOns list, 2026-11-10; they include garbage not yet collected): " + "; ".join("%s %s" % kv for kv in IN_GAME))
    return out


def main():
    args = sys.argv[1:]
    jpath = args[args.index("--json") + 1] if "--json" in args else None
    saved_dir = args[args.index("--saved") + 1] if "--saved" in args else None
    t0 = time.time()
    real, info, errA = build_realistic()
    fresh = {"XayaUI": [], "XayaUI_Rules": []}
    res = {"profile": info}
    problems = []
    for name, spec in (("fresh", fresh), ("realistic", real)) + ((("saved", from_saved_dir(saved_dir)),) if saved_dir else ()):
        both, e1 = measure(spec, options=(name != "fresh"), strip=(name == "realistic"))
        plat, e2 = measure(spec, options=False, rules=False)
        res[name] = {"both": both, "platform_only": plat, "split": platform_rules(both, plat), "errors": e1 + e2}
        if both["rules"] == 0 and name != "fresh":
            problems.append("%s: no rules loaded" % name)
    res["walk"] = walk(real)
    res["walk_fresh"] = walk(fresh)
    for line in report(res):
        print(line)
    errs = errA + res["fresh"]["errors"] + res["realistic"]["errors"]
    for e in errs:
        print("Lua error in the stand-in (the numbers after it may be incomplete):", str(e)[:400])
    if jpath:
        json.dump(res, open(jpath, "w"), indent=1, default=str)
    if info["rules"] < 250:
        problems.append("the realistic profile has %d rules, expected about 300" % info["rules"])
    for p in problems:
        print("FAIL", p)
    print("%.0f s. Report only: no memory budget is enforced yet (REQUEST-LOG A23 SD-41: measure first, then set)." % (time.time() - t0))
    print("FAILS: %d" % len(problems))
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
