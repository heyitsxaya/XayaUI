#!/usr/bin/env python3
"""Offline test (bundle 1, round 11 repair, units "standin" and "standin-repair1"; R11A final review, hidden-error inventory groups A and B).

GROUP A. The combat engine (XayaUI_Rules/Combat/AuraDisplay.lua) draws aura displays through Blizzard's aura container (the
"AuraContainer" widget made with CustomAuraContainerTemplate). Only the V27 gate's world had one (tests/gate_common.py GAME_LUA), so
every unit test fell back to XayaUI's own drawing and left warning XUI-W002 in the error record (19 tests). The stand-in world
(tests/harness/world.lua) now has the container, for the unit tests and the gate alike. Checks:
  A1  every container method AuraDisplay.lua calls exists on the stand-in's container (read from the addon's source, so a method the
      addon starts calling and the stand-in lacks fails here, not as a W002 in some other test);
  A2  the gate's world uses the same container, not a copy: after the gate's GAME_LUA (tests/gate_common.py) has run on the stand-in
      world, the five container tables are the stand-in's very tables (rawequal), a container made there has the stand-in's very
      methods (rawequal: a world that rawsets its own over them fails), and the gate reads the stand-in's aura buttons (W.auraButtons);
  A3  what the player gets with the container (as in the game): a buff rule's icon is drawn by the engine (XayaUI's own icon stays
      hidden), the container is told the rule's spell, its aura button is made at the rule's icon size with XayaUI's look, and the
      error record stays empty;
  A4  a client without the container (W.RemoveAuraContainer; V2: the container is not in docs/reference/api, so its absence must fail
      safe): XUI-W002 is recorded once, naming what is missing, and XayaUI draws the icon itself (it shows while the buff is up and
      hides when it goes); with a second display and five rebuilds, no container frame is ever made and the warning stays at one;
  A5  a plain "Frame" made with the template gets no container methods (AuraDisplay.lua: "created as a plain Frame its built-in OnLoad
      never runs"), so the fallback path is what a test that does that sees. (A5 is a boundary check of the stand-in: it passes on the
      pre-change files too.)
  A7  a container widget without the engine's methods (made as a plain Frame on purpose): one frame is tried in the whole session,
      XUI-W002 is recorded once naming the missing method, and XayaUI draws both displays itself.
  A8  a client where the AuraContainer widget cannot be made (CreateFrame raises): it is tried once in the session, XUI-W002 is recorded
      once, and XayaUI draws both displays itself.
GROUP B. ns.SetVisualShown (XayaUI_Rules/Visual.lua) with a rule that has no display settings (rule.visual missing; every real rule
passes ns.NormalizeRule, RuleDefaults.lua):
  B1  no Lua error from any caller (called directly, as the mover does), nothing is shown, and an existing frame is freed ("no frame is
      made for it" is a boundary check: it passes on the pre-change files too, where the call stops with a Lua error before any frame);
  B2  it is reported once per rule, with code XUI-E012, in chat and in the error record (CueRulesDB.errorLog, SD-139), however often the
      engine steps;
  B3  a normalized rule beside it keeps working (its display shows while its buff is up).
  A9  (repair 2; the R11A review's tally finding) the stand-in's loader, the one place saved data enters a session, notes every
      error-record entry it hands over with its count at that moment (Lua registry "XayaUI.harness.loadedErrorLog", read by the
      honest-result guard, tests/run_all.py, to count each occurrence once, in the session where it happened): a fresh session has the
      note and it is empty; the next session, loaded from what the first one saved, has BOTH of the first session's entries noted, each
      at its own count (XUI-W002 n = 1, and an XUI-E001 the first session raised twice on purpose, n = 2; round 11 repair, counts unit:
      one entry at n = 1 could not catch a loader that notes every entry at 1, or only the first); when the W002 happens again there the
      record's count grows in place (n = 2) while the note keeps 1; an entry made in that session is not noted; the note adds no field
      to an entry, no global holds it (nor a table a global holds), making the loader adds to _G only the globals loader.lua assigns by
      name, and after the same start the session loaded from saved data has exactly the fresh session's whole key set of _G.
  A6  (found by this unit) an engine build that fails part-way is recorded (XUI-E011), no longer dropped: three callers in
      AuraDisplay.lua ran pcall(D.Build) and threw the error away; the stand-in's missing flow layout tables stopped every build in
      tests/fix_r6_aura_routing_run.py that way, unseen.
Stand-in numbers are not WoW. UNVERIFIED IN GAME: that Blizzard's container shows the button while the aura is up (the stand-in
container has no auras; A3 checks what XayaUI hands it).
Run: python3 tests/fix_r11_standin_run.py"""
import os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

# one buff rule (icon, 32 x 32, shown while buff 1001 is up), the aura reads answered from a table the scenario changes
SETUP = r'''
local W, L = ...
local aura = {}
local function copy(a) local t = {}; for k, v in pairs(a) do t[k] = v end; return t end
C_UnitAuras.GetPlayerAuraBySpellID = function(id) local a = aura[id]; return a and copy(a) or nil end
C_UnitAuras.GetUnitAuraBySpellID = function(u, id) if u == "player" then return C_UnitAuras.GetPlayerAuraBySpellID(id) end end
local S = {}
function S.start()
  L.startup(); W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 3)
  S.ns = rawget(_G, "XayaUI_NS")
end
function S.buffRule(name, id)
  local ns = S.ns
  local r = ns.NewRule(); r.name = name; r.enabled = true
  r.visual.enabled, r.visual.kind, r.visual.w, r.visual.h = true, "spellicon", 32, 32
  r.visual.text.enabled = false; r.sound.enabled = false; r.visual.trigger = "buffActive"
  r.useBuff, r.buffID, r.buffState, r.cdState = true, id, "present", "none"
  ns.NormalizeRule(r)
  return r
end
function S.gain(id) aura[id] = { spellId = id, auraInstanceID = 500 + id % 100, name = "Buff", applications = 1, duration = 30,
  expirationTime = W.now + 30, sourceUnit = "player", isHelpful = true }; W.fire("UNIT_AURA", "player", { isFullUpdate = true }) end
function S.lose(id) aura[id] = nil; W.fire("UNIT_AURA", "player", { isFullUpdate = true }) end
function S.settle() S.ns.MarkDirty(); S.wait() end   -- (a rule edit: the engine rebuilds)
function S.wait() W.tick(1 / 60, 20); W.tick(0.5, 2) end   -- (time passes; no rebuild asked)
function S.shown(r) local fr = S.ns.VisualProbeState and S.ns.VisualProbeState(); local f = fr and fr[r]; return f and f:IsShown() and true or false end
function S.frame(r) local fr = S.ns.VisualProbeState and S.ns.VisualProbeState(); return fr and fr[r] end
-- the error record (rawget: the stand-in's _G reports every unknown global it is asked for)
function S.record(code)
  local db = rawget(_G, "CueRulesDB"); local log = type(db) == "table" and rawget(db, "errorLog") or nil
  local n, msg = 0, nil
  for _, e in ipairs(type(log) == "table" and log or {}) do if e.code == code then n = n + (e.n or 1); msg = msg or e.msg end end
  return n, msg
end
function S.recordSize() local db = rawget(_G, "CueRulesDB"); local log = type(db) == "table" and rawget(db, "errorLog") or nil; return type(log) == "table" and #log or 0 end
return S
'''

CONTAINER = r'''
return function(W, L, S)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name, ok and true or false, extra ~= nil and tostring(extra) or nil } end
S.start()
local ns = S.ns
local r = S.buffRule("Shield", 1001)
ns.rules = { r }
S.settle()
check("A3. (setup) the combat engine set up its aura containers", #(W.auraContainers or {}) >= 1, #(W.auraContainers or {}))
check("A3. the engine draws the buff rule's icon (it owns the display)", ns.EngineOwns and ns.EngineOwns(r) == true)
-- the container is told the rule's spell (Blizzard's container shows the button while that aura is up: UNVERIFIED IN GAME here)
local told, sized = false, false
for _, c in ipairs(W.auraContainers or {}) do
  for _, g in pairs(c.groups) do
    local ids = type(g.opts) == "table" and g.opts.candidateFilters and g.opts.candidateFilters.includeSpellIDs
    if type(ids) == "table" and (ids[1001] or ids[1] == 1001) then told = true end
  end
end
for _, e in ipairs(W.auraButtons or {}) do if e.button:GetWidth() == 32 and e.button:GetHeight() == 32 then sized = true end end
check("A3. the container is told to show spell 1001 (the rule's buff)", told)
check("A3. its aura button was made and given XayaUI's look at the rule's size (32 x 32)", #(W.auraButtons or {}) >= 1 and sized,
  #(W.auraButtons or {}))
S.gain(1001); S.wait()
check("A3. the buff is up: XayaUI's own icon stays hidden (the engine's button is the one the player sees)", not S.shown(r))
check("A3. the error record stays empty (no XUI-W002: the container was set up)", S.recordSize() == 0, (select(2, S.record("XUI-W002"))))
-- A5: a plain Frame made with the template stays bare, as in the game
local plain = CreateFrame("Frame", nil, UIParent, "CustomAuraContainerTemplate")
check("A5. a plain Frame made with the container template has none of the container's methods",
  rawget(plain, "SetAuraProcessingPolicy") == nil and rawget(plain, "AddAuraGroup") == nil and rawget(plain, "groups") == nil)
local real = CreateFrame("AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
check("A5. ... an AuraContainer made with it has them", type(rawget(real, "SetAuraProcessingPolicy")) == "function"
  and type(rawget(real, "AddAuraGroup")) == "function")
check("no Lua error", #W.errors == 0, W.errors[1])
return R
end
'''

ABSENT = r'''
return function(W, L, S)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name, ok and true or false, extra ~= nil and tostring(extra) or nil } end
if W.RemoveAuraContainer then W.RemoveAuraContainer() end   -- a client without Blizzard's aura container: the XUI-W002 below is caused on purpose
S.start()
local ns = S.ns
local r = S.buffRule("Shield", 1001)
ns.rules = { r }
S.settle()
local n, msg = S.record("XUI-W002")
check("A4. without the container, the engine's fallback is recorded once (one display): XUI-W002 x1", n == 1, tostring(n) .. " " .. tostring(msg))
check("A4. ... and the engine does not own the display (XayaUI draws it)", not (ns.EngineOwns and ns.EngineOwns(r)))
check("A4. the buff is not up: XayaUI's icon is hidden", not S.shown(r))
S.gain(1001); S.wait()
check("A4. the buff comes up: XayaUI's own icon shows", S.shown(r))
S.lose(1001); S.wait()
check("A4. the buff goes: XayaUI's own icon hides", not S.shown(r))
check("A4. the buff coming and going adds no warning (still XUI-W002 x1) and nothing else is in the error record",
  S.record("XUI-W002") == 1 and S.recordSize() == 1, tostring(S.record("XUI-W002")) .. " / " .. S.recordSize())
-- (round 11 repair 1) the fallback holds for the session: more rules and five rebuilds (rule edits) make no container frame and no
-- second warning (before: every build made a container frame it never kept, and recorded XUI-W002 again for every display)
local r2 = S.buffRule("Barrier", 1002)
ns.rules = { r, r2 }
for _ = 1, 5 do S.settle() end
check("A4. five rebuilds with two displays: no container frame is ever made (the game never frees a frame)",
  (W.templates.CustomAuraContainerTemplate or 0) == 0, W.templates.CustomAuraContainerTemplate)
local n2, msg2 = S.record("XUI-W002")
check("A4. ... and the reason is still recorded once (XUI-W002 x1), naming what is missing",
  n2 == 1 and S.recordSize() == 1 and msg2 and msg2:find("CustomAuraContainerAuraProcessingPolicy is missing", 1, true) ~= nil,
  tostring(n2) .. " / " .. S.recordSize() .. " " .. tostring(msg2))
S.gain(1002); S.wait()
check("A4. the second display is drawn by XayaUI too (its buff is up: its icon shows)", S.shown(r2))
check("no Lua error", #W.errors == 0, W.errors[1])
return R
end
'''

# A7: a client whose container widget lacks a method the engine calls (here: the frame is made as a plain Frame, so it has none of them,
# as tests/fix_r10_display_run.py's modes A, B, D and E do on purpose). The XUI-W002 below is caused on purpose by the CreateFrame line.
NOMETHOD = r'''
return function(W, L, S)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name, ok and true or false, extra ~= nil and tostring(extra) or nil } end
local realCreate = CreateFrame
CreateFrame = function(kind, ...) return realCreate(kind == "AuraContainer" and "Frame" or kind, ...) end
S.start()
local ns = S.ns
local r, r2 = S.buffRule("Shield", 1001), S.buffRule("Barrier", 1002)
ns.rules = { r, r2 }
for _ = 1, 5 do S.settle() end
local made = W.templates.CustomAuraContainerTemplate or 0
check("A7. a container without the engine's methods: one frame is tried in the whole session (five rebuilds, two displays)", made == 1, made)
local n, msg = S.record("XUI-W002")
check("A7. ... the reason is recorded once (XUI-W002 x1), naming the missing method", n == 1 and S.recordSize() == 1 and msg
  and msg:find("its method %a+ is missing") ~= nil, tostring(n) .. " / " .. S.recordSize() .. " " .. tostring(msg))
S.gain(1001); S.wait()
check("A7. XayaUI draws both displays itself: the buff that is up shows, the other does not", S.shown(r) and not S.shown(r2))
check("no Lua error", #W.errors == 0, W.errors[1])
return R
end
'''

GUARD = r'''
return function(W, L, S)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name, ok and true or false, extra ~= nil and tostring(extra) or nil } end
S.start()
local ns = S.ns
local good = S.buffRule("Good", 1002)
-- a rule with no display settings (never made by XayaUI: built here on purpose, without ns.NormalizeRule); the XUI-E012 below is
-- caused on purpose by it
local raw = { uid = "raw1", name = "Raw", enabled = true, useBuff = true, buffID = 1003, buffState = "present", cdState = "none" }
ns.rules = { good }
S.settle()
local p0 = #W.printed
local ok1, e1 = pcall(ns.SetVisualShown, raw, true)
local ok2, e2 = pcall(ns.SetVisualShown, raw, false)
local ok3, e3 = pcall(ns.SetVisualShown, raw, true)
check("B1. called directly (as the mover does): no Lua error", ok1 and ok2 and ok3, tostring(e1) .. " / " .. tostring(e2) .. " / " .. tostring(e3))
check("B1. nothing is shown and no frame is made for it", S.frame(raw) == nil)
local n, msg = S.record("XUI-E012")
check("B2. reported once with code XUI-E012 in the error record, naming the rule", n == 1 and msg and msg:find("'Raw'", 1, true) ~= nil, tostring(n) .. " " .. tostring(msg))
local said = 0
for i = p0 + 1, #W.printed do if W.printed[i]:find("Raw", 1, true) then said = said + 1 end end
check("B2. ... and said once in chat", said == 1, said)
-- the engine steps with it in the list, many times
ns.rules = { good, raw }
S.gain(1002); S.settle(); W.tick(0.1, 30)
n = S.record("XUI-E012")
check("B2. the engine stepping with it 30 more times: still one report (n stays 1), and no XUI-E010", n == 1 and S.record("XUI-E010") == 0,
  tostring(n) .. " / E010 " .. tostring(S.record("XUI-E010")))
check("B3. the normalized rule beside it works: its buff is up, the engine wants its icon shown and draws it",
  ns.runtime[good] and ns.runtime[good].visualWanted == true and ns.EngineOwns and ns.EngineOwns(good) == true)
-- a frame it had is freed: give it settings, show it, take them away
raw.visual = nil; ns.NormalizeRule(raw); raw.visual.enabled, raw.visual.trigger, raw.visual.kind = true, "buffActive", "spellicon"
ns.RefreshVisual(raw)
local had = S.frame(raw) ~= nil
raw.visual = nil
local ok4 = pcall(ns.SetVisualShown, raw, true)
check("B1. a frame it had is freed when its settings are gone", had and ok4 and S.frame(raw) == nil, tostring(had))
check("B2. still one report for that rule", S.record("XUI-E012") == 1)
check("no Lua error", #W.errors == 0, W.errors[1])
return R
end
'''


BUILDFAIL = r'''
return function(W, L, S)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name, ok and true or false, extra ~= nil and tostring(extra) or nil } end
-- the engine's build stops part-way on purpose (the stand-in's flow layout names taken away, as the stand-in was before round 11): the
-- XUI-E011 below is caused on purpose by this line
AnchorUtil.FlowLayoutAxis, AnchorUtil.FlowDirection = nil, nil
S.start()
local ns = S.ns
local f = ns.NewFolder("Procs"); f.cType = "dynamic"
local r = S.buffRule("Shield", 1001); r.folder = f.id
ns.rules = { r }
S.settle()
local n, msg = S.record("XUI-E011")
check("A6. an engine build that fails is recorded (XUI-E011, naming the engine build), not dropped", n >= 1 and msg and msg:find("combat engine build", 1, true) ~= nil,
  tostring(n) .. " " .. tostring(msg))
check("no Lua error", #W.errors == 0, W.errors[1])
return R
end
'''


# A8: a client where the AuraContainer widget cannot be made at all (CreateFrame raises for it). The XUI-W002 below is caused on purpose
# by the CreateFrame line in NOWIDGET.
NOWIDGET = r'''
return function(W, L, S)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name, ok and true or false, extra ~= nil and tostring(extra) or nil } end
local realCreate, tries = CreateFrame, 0
CreateFrame = function(kind, ...) if kind == "AuraContainer" then tries = tries + 1; error("unknown frame type 'AuraContainer'", 2) end return realCreate(kind, ...) end
S.start()
local ns = S.ns
local r, r2 = S.buffRule("Shield", 1001), S.buffRule("Barrier", 1002)
ns.rules = { r, r2 }
for _ = 1, 5 do S.settle() end
check("A8. the widget cannot be made: it is tried once in the whole session (five rebuilds, two displays)", tries == 1, tries)
local n, msg = S.record("XUI-W002")
check("A8. ... the reason is recorded once (XUI-W002 x1), saying the container could not be made", n == 1 and S.recordSize() == 1 and msg
  and msg:find("an AuraContainer could not be made", 1, true) ~= nil, tostring(n) .. " / " .. S.recordSize() .. " " .. tostring(msg))
S.gain(1002); S.wait()
check("A8. XayaUI draws both displays itself: the buff that is up shows, the other does not", S.shown(r2) and not S.shown(r))
check("no Lua error", #W.errors == 0, W.errors[1])
return R
end
'''

# A9: two sessions, the second loaded from what the first saved. The XUI-W002 in each is caused on purpose by W.RemoveAuraContainer()
# (one per session: the second adds to the first's entry), the XUI-E001 in the first by its two calls pcall(eh, "...: A9 an error
# carried into the next session") (one entry, n = 2), the XUI-E012 in the second by the rule "Raw" built without ns.NormalizeRule.
# (round 11 repair, counts unit, after the repair-2 review) The first session hands over TWO entries, one with n = 2, so a loader that
# notes every entry at 1, or only the first entry, is caught; "nothing the addons see" compares whole key sets of _G and looks for the
# note itself in any global.
NOTE_LUA = r'''function() local n = debug.getregistry()["XayaUI.harness.loadedErrorLog"]; return n end'''
A9_KEYS = "fix_r11_standin.A9keys"   # (the test's own registry slot, not a global: _G's key set after the start of each A9 session)
KEYS_LUA = r'''function() local k = {}; for x in pairs(_G) do k[#k + 1] = tostring(x) end; table.sort(k); return table.concat(k, "\n") end'''
A9_SNAP = r'''local function a9keys() return (__KEYS__)() end
local function a9holds(note)   -- the globals that hold the note itself, or hold a table with the note in it (one level down)
  local out = {}
  if type(note) ~= "table" then return out end
  for k, v in pairs(_G) do
    if rawequal(v, note) then out[#out + 1] = tostring(k)
    elseif type(v) == "table" then for kk, vv in pairs(v) do if rawequal(vv, note) then out[#out + 1] = tostring(k) .. "." .. tostring(kk) end end end
  end
  return out
end'''.replace("__KEYS__", KEYS_LUA)
CARRY1 = r'''
return function(W, L, S)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name, ok and true or false, extra ~= nil and tostring(extra) or nil } end
__SNAP__
local note = (__NOTE__)()
check("A9. a fresh session: the loader's note of entries from saved data exists", type(note) == "table")
W.RemoveAuraContainer()
S.start()
S.ns.rules = { S.buffRule("Shield", 1001) }
S.settle()
debug.getregistry()["__A9KEYS__"] = a9keys()
-- on purpose: the same Lua error reported twice (one XUI-E001 entry, n = 2)
local eh = geterrorhandler()
pcall(eh, "Interface/AddOns/XayaUI_Rules/Engine.lua:1: A9 an error carried into the next session")
pcall(eh, "Interface/AddOns/XayaUI_Rules/Engine.lua:1: A9 an error carried into the next session")
local db = rawget(_G, "CueRulesDB"); local log = db and rawget(db, "errorLog") or {}
local w, e1
for _, e in ipairs(log) do if e.code == "XUI-W002" then w = e elseif e.code == "XUI-E001" then e1 = e end end
check("A9. ... it stays empty: the XUI-W002 (n = 1) and the XUI-E001 (n = 2) this session made are not noted (they came from no saved data)",
  type(note) == "table" and next(note) == nil and w ~= nil and w.n == 1 and e1 ~= nil and e1.n == 2,
  (w and ("W002 x" .. tostring(w.n)) or "no W002") .. ", " .. (e1 and ("E001 x" .. tostring(e1.n)) or "no E001"))
-- (the stand-in's error handler also lists the two errors raised on purpose above; any other is a failure)
local others, mine = {}, 0
for _, x in ipairs(W.errors) do if tostring(x):find("A9 an error carried into the next session", 1, true) then mine = mine + 1 else others[#others + 1] = x end end
check("no Lua error (but the two raised on purpose)", #others == 0 and mine == 2, others[1] or ("raised on purpose: " .. mine))
return R
end
'''.replace("__A9KEYS__", A9_KEYS)
CARRY2 = r'''
return function(W, L, S)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name, ok and true or false, extra ~= nil and tostring(extra) or nil } end
__SNAP__
W.RemoveAuraContainer()
S.start()
S.ns.rules = { S.buffRule("Shield", 1001) }
S.settle()
debug.getregistry()["__A9KEYS__"] = a9keys()
local note = (__NOTE__)()
local function noted(e) return type(note) == "table" and e ~= nil and note[e] or nil end
local db = rawget(_G, "CueRulesDB"); local log = db and rawget(db, "errorLog") or {}
local carried, e1
for _, e in ipairs(log) do if e.code == "XUI-W002" then carried = e elseif e.code == "XUI-E001" then e1 = e end end
local nNoted = 0; if type(note) == "table" then for _ in pairs(note) do nNoted = nNoted + 1 end end
check("A9. the next session (loaded from what the first saved): BOTH entries the first one saved are noted, each with its own count then "
  .. "(XUI-W002 1, XUI-E001 2), and nothing else",
  carried ~= nil and noted(carried) == 1 and e1 ~= nil and noted(e1) == 2 and nNoted == 2,
  "W002 " .. tostring(noted(carried)) .. ", E001 " .. tostring(noted(e1)) .. ", entries noted " .. nNoted)
local raw = { uid = "raw9", name = "Raw", enabled = true, useBuff = true, buffID = 1003, buffState = "present", cdState = "none" }
pcall(S.ns.SetVisualShown, raw, true)
local made
for _, e in ipairs(log) do if e.code == "XUI-E012" then made = e end end
check("A9. it happens again in this session: the record's count grows in place (n = 2) and the note keeps 1; the XUI-E001 not raised "
  .. "again keeps n = 2 and its note 2",
  carried ~= nil and carried.n == 2 and noted(carried) == 1 and e1 ~= nil and e1.n == 2 and noted(e1) == 2,
  carried and ("W002 n " .. tostring(carried.n) .. ", note " .. tostring(noted(carried)) .. "; E001 n " .. tostring(e1 and e1.n) .. ", note " .. tostring(noted(e1))))
check("A9. an entry made in this session (XUI-E012) is not noted", type(note) == "table" and made ~= nil and noted(made) == nil,
  made and tostring(noted(made)))
local fields = {}; for k in pairs(carried or {}) do fields[#fields + 1] = k end; table.sort(fields)
check("A9. the note adds nothing to the entries: no field on the entry beyond DebugRecord.lua's",
  carried ~= nil and table.concat(fields, ","):find("loaded", 1, true) == nil and table.concat(fields, ","):find("note", 1, true) == nil,
  table.concat(fields, ","))
local holds = a9holds(note)
check("A9. no global holds the note, nor any table a global holds (one level down)", type(note) == "table" and #holds == 0, table.concat(holds, ", "))
check("no Lua error", #W.errors == 0, W.errors[1])
return R
end
'''.replace("__A9KEYS__", A9_KEYS)
# the globals loader.lua assigns by name at its top level (its C_AddOns API); a global the loader adds any other way (rawset, or a
# name built at run time) is caught by the A9 check on what making the loader adds to _G
_LOADER_SRC = open(os.path.join(HERE, "harness", "loader.lua"), encoding="utf-8").read()
LOADER_NAMED = sorted(set(re.findall(r"^([A-Za-z_]\w*)\s*=", _LOADER_SRC, re.M)) - set(re.findall(r"^\s*local\s+([A-Za-z_]\w*)", _LOADER_SRC, re.M)))
LOADER_ADDED = []   # per session() call: the globals that making the loader added to _G (a key set before and after it)

def session(L, scenario, saved=None):
    folders = H.find_addons()
    enabled = [n for n in folders if n != "XayaUI_DevAssist"]
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    opts = H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}})
    # saved: what the last session saved (Lua source, tests/harness/savedvars.lua), as tests/harness/run.py session() hands it over
    opts["saved"] = H.savedvars(L).Load(saved) if isinstance(saved, str) else H.to_lua(L, {})
    keys_w = set(L.eval(KEYS_LUA)().split("\n"))
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(os.path.join(H.HERE, "loader.lua"), world, opts)
    LOADER_ADDED.append(sorted(set(L.eval(KEYS_LUA)().split("\n")) - keys_w))
    S = L.eval("function(src, W, Ld) return loadstring(src)(W, Ld) end")(SETUP, world, loader)
    scenario = scenario.replace("__SNAP__", A9_SNAP).replace("__NOTE__", NOTE_LUA)
    return world, L.eval("function(src, W, Ld, S) return loadstring(src)()(W, Ld, S) end")(scenario, world, loader, S), loader


def logout_source(L, loader):
    """what a session saved at logout, as Lua source (tests/harness/savedvars.lua: what the next session loads)"""
    out, _issues = loader.logout()
    return H.savedvars(L).Serialize(out)


def run(L, label, scenario, report, saved=None):
    """one scenario; a Lua error in it is a named failure (not a crash of the test)"""
    try:
        _, res, loader = session(L, scenario, saved)
    except Exception as e:   # noqa: BLE001  (lupa.LuaError)
        report("%s: the scenario ran to its end" % label, False, str(e).split("\n")[0][:300])
        return None
    for i in range(1, len(res) + 1):
        report(res[i][1], bool(res[i][2]), res[i][3])
    return loader


# the container methods AuraDisplay.lua calls: method calls on its container objects (c, g.frame, s.frame, frame) and the pcall'd
# method references (pcall(g.frame.SetAuraGroupEnabled, ...))
CONTAINER_CALL = re.compile(r"(?:\b(?:c|frame|g\.frame|s\.frame)\s*[:.]\s*)(SetUnit|UpdateAllAuras|AddAuraGroup|RemoveAuraGroup|ClearAuraGroups|"
                            r"SetAuraProcessingPolicy|SetAuraGroup\w*|SetFlowLayout\w*)\b")


def main():
    total = bad = 0
    expect = {}

    def report(name, ok, extra=None):
        nonlocal total, bad
        total += 1
        bad += 0 if ok else 1
        print(("ok  " if ok else "FAIL: ") + name + ("" if extra is None else "  [%s]" % str(extra)[:400]))

    # A1 / A2: static, against a bare stand-in world
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    have = set(k for k in (world.AURA_CONTAINER_METHODS or L.table()).keys())   # (empty when the stand-in has no container)
    src = open(os.path.join(ROOT, "XayaUI_Rules", "Combat", "AuraDisplay.lua"), encoding="utf-8").read()
    code = "\n".join(l.split("--", 1)[0] for l in src.split("\n"))
    used = set(CONTAINER_CALL.findall(code))
    report("A1. (setup) the container methods AuraDisplay.lua calls were found (%d)" % len(used), len(used) >= 10, sorted(used))
    report("A1. every one exists on the stand-in's container", used <= have, sorted(used - have))
    import gate_common as GC  # noqa: E402  (only its GAME_LUA text; nothing of the gate runs)
    # A2: the gate's world must not define its own container: after GAME_LUA has run on the stand-in world, the five tables are still
    # the stand-in's very tables (rawequal, not equal copies) and a container made there has the stand-in's very methods (a world that
    # rawsets its own copies over them, as gate_common.py did before round 11, fails here)
    before = L.eval("function() return { AuraContainerSortMethod, AuraContainerSortDirection, CustomAuraContainerAuraProcessingPolicy, "
                    "AnchorUtil.FlowLayoutAxis, AnchorUtil.FlowDirection } end")()
    g = L.eval("function(src, W) return loadstring(src)()(W) end")(GC.GAME_LUA, world)
    kept = L.eval("""function(b) local now = { AuraContainerSortMethod, AuraContainerSortDirection, CustomAuraContainerAuraProcessingPolicy,
        AnchorUtil.FlowLayoutAxis, AnchorUtil.FlowDirection }
      local names = { "AuraContainerSortMethod", "AuraContainerSortDirection", "CustomAuraContainerAuraProcessingPolicy",
        "AnchorUtil.FlowLayoutAxis", "AnchorUtil.FlowDirection" }
      local bad = {}
      for i = 1, 5 do if b[i] == nil or not rawequal(b[i], now[i]) then bad[#bad + 1] = names[i] end end
      return #bad == 0, table.concat(bad, ", ") end""")
    ok, bad_tables = kept(before)
    report("A2. the gate's world keeps the stand-in's five container tables (the very same tables: it defines none of its own)", ok and g is not None,
           bad_tables)
    meth = L.eval("""function(W) local f = CreateFrame("AuraContainer", nil, UIParent, "CustomAuraContainerTemplate")
      local bad, n = {}, 0
      for k, fn in pairs(W.AURA_CONTAINER_METHODS or {}) do n = n + 1; if not rawequal(rawget(f, k), fn) then bad[#bad + 1] = k end end
      table.sort(bad)
      return n > 0 and #bad == 0, n .. " methods; not the stand-in's: " .. table.concat(bad, ", ") end""")
    ok, why = meth(world)
    report("A2. a container made in the gate's world has the stand-in's very methods (none of the gate's own)", ok, why)
    shared = L.eval("function(W, G) return type(G) == 'table' and rawequal(G.buttons, W.auraButtons) end")(world, g)
    report("A2. the gate reads the stand-in's aura buttons (its G.buttons is W.auraButtons, not a list of its own)", shared)
    pres = L.eval("function(W) return pcall(W.RemoveAuraContainer) and W.auraContainerPresent == false and CustomAuraContainerAuraProcessingPolicy == nil end")(world)
    report("A4. (setup) W.RemoveAuraContainer leaves a client without the container", pres)

    # A3 / A5: the container (as in the game)
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    run(L, "A3 / A5 (with the container)", CONTAINER, report)
    # A4: a client without it (the W002 here is caused on purpose: W.RemoveAuraContainer() in ABSENT)
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    run(L, "A4 (without the container)", ABSENT, report)
    expect["XUI-W002"] = 1   # (A4: W.RemoveAuraContainer() in ABSENT; one per session)
    # A7: a container widget without the engine's methods (the W002 here is caused on purpose: the CreateFrame line in NOMETHOD)
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    run(L, "A7 (a container without its methods)", NOMETHOD, report)
    expect["XUI-W002"] += 1
    # A8: an AuraContainer that cannot be made (the W002 here is caused on purpose: the CreateFrame line in NOWIDGET)
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    run(L, "A8 (no AuraContainer widget)", NOWIDGET, report)
    expect["XUI-W002"] += 1
    # B: the SetVisualShown guard (the E012 here is caused on purpose: the rule "Raw" built without ns.NormalizeRule in GUARD)
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    run(L, "B (the SetVisualShown guard)", GUARD, report)
    expect["XUI-E012"] = 1
    # A6: a failed engine build is recorded (the E011 here is caused on purpose: AnchorUtil's flow tables taken away in BUILDFAIL)
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    run(L, "A6 (an engine build that fails)", BUILDFAIL, report)
    expect["XUI-E011"] = 1
    # A9: the loader's note of saved-data entries (the W002s here are caused on purpose: W.RemoveAuraContainer() in CARRY1 and CARRY2, one
    # per session, the second adding to the first's entry; the E012 by the rule "Raw" in CARRY2)
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    del LOADER_ADDED[:]
    ld = run(L, "A9 (first session)", CARRY1, report)
    src = logout_source(L, ld) if ld is not None else "{}"
    L2 = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    run(L2, "A9 (next session, from the first one's saved data)", CARRY2, report, saved=src)
    # (round 11 repair, counts unit) the whole key sets of _G, compared in Python: making the loader adds only the globals loader.lua
    # assigns by name, and the session loaded from saved data has exactly the fresh session's globals after the same start
    added = LOADER_ADDED[:]
    report("A9. making the loader adds to _G only the globals loader.lua assigns by name (its C_AddOns API), in both sessions",
           len(added) == 2 and all(set(a) <= set(LOADER_NAMED) for a in added),
           "added %s; loader.lua assigns by name: %s" % (" / ".join(",".join(a) for a in added), ",".join(LOADER_NAMED)))
    reg = "function(k) return debug.getregistry()[k] end"
    k1, k2 = L.eval(reg)(A9_KEYS), L2.eval(reg)(A9_KEYS)
    s1, s2 = set((k1 or "").split("\n")), set((k2 or "").split("\n"))
    report("A9. after the same start, the session loaded from saved data has exactly the fresh session's globals (the whole key set of "
           "_G: handing saved data over, and the note, add none)", bool(k1) and bool(k2) and s1 == s2,
           "only in the next session: %s | only in the first: %s" % (",".join(sorted(s2 - s1)), ",".join(sorted(s1 - s2))))
    expect["XUI-W002"] += 2
    expect["XUI-E012"] += 1
    expect["XUI-E001"] = 2   # (A9, on purpose: CARRY1's two calls pcall(eh, "...: A9 an error carried into the next session"), one entry, n = 2)
    for c, n in sorted(expect.items()):
        if n:
            print("EXPECT_ERRORS %s %d" % (c, n))
    print("%d checks, %d failed" % (total, bad))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
