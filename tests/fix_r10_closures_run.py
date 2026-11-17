#!/usr/bin/env python3
"""Bundle 1 round 10, closures unit (REQUEST-LOG A23 SD-82, her answer verbatim "FAIL everywhere (Recommended)"; SD-90, her answer
verbatim "Is 1 only recommended due to less lift? If so, do 2", which is option 2: fix every site, including about 20 in the settings
window). Every timer call that made a new function on each run now hands the game's timer a function made once. Behaviour must not
change. This test drives the REAL addons in the stand-in game (tests/harness) and, for each of the 29 sites the static scan
(tests/fix_r10_closure_scan_run.py) listed before the fix, checks two things:
  ONCE  the path is run at least twice and every function it hands to C_Timer (After / NewTimer / NewTicker) from that file, at that
        delay, is the SAME function (a new closure per run is a different function each time). FAILS on the pre-change files.
  SAME  what the player sees or gets after the timer has run, which must be what the old code did: these checks PASS on the
        pre-change files too (the negative control for "behaviour must not change"). Where one run handed the timer values of its own
        (a cast's spell, a row, a menu slot), two runs are started before the timer fires, and each must still get its own values,
        in order (the new code keeps them in a list in the order they were set; one site's waits are all the same length, so they
        come due in that order).
Sites (the scan's list before the fix; file:line of the old code):
  core     XayaUI/Theme.lua:521 (NewTicker), MinimapButton.lua:236, KeyCatch.lua:142, GameMenuButton.lua:288
  Rules    XayaUI_Rules/Combat/AuraModel.lua:677 (Reload), :699 (cast diff), AuraTracker.lua:553 (two delays per cast)
  Options  AuraSetup.lua:355, Options.lua:395, RuleEditor/DisplayTab.lua:195, Drafts.lua:224, :277, :368, :744, :771,
           RuleSearch.lua:301, SaveBar.lua:74, Sidebar.lua:225, :1854, :1949, SpellSearch.lua:498, :565, :573,
           Skin.lua:223, :269, :439, :911, :1855 (NewTimer), TreePaint.lua:123
UNVERIFIED IN GAME (V25: the harness is a stand-in). The stand-in runs timers that come due in one tick in the order they were set.
Run: python3 tests/fix_r10_closures_run.py [core|options]   (no argument: both sessions)"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

COMMON = r'''
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local function section(name, fn) local ok, err = pcall(fn); if not ok then check(name .. ": ran to its end (a Lua error stopped it)", false, err) end end
-- every function handed to the game's timer, with the file that handed it (the chunk name the stand-in loader gives each file)
local REC
for _, k in ipairs({ "After", "NewTimer", "NewTicker" }) do
  local raw = C_Timer[k]
  C_Timer[k] = function(d, fn, ...)
    if REC then
      local info = debug.getinfo(2, "S")
      REC[#REC + 1] = { src = info and info.source or "?", fn = fn, d = d, k = k }
    end
    return raw(d, fn, ...)
  end
end
-- run act; the timer calls made from file (at delay d, of kind k when given)
local function rec(file, d, act, k)
  REC = {}
  local ok, err = pcall(act)
  local all = REC; REC = nil
  if not ok then error(err, 0) end
  local out = {}
  for _, x in ipairs(all) do
    -- (a file the loader read has a chunk name "@<path>"; this test's own code, loaded from a string, does not)
    if x.src:sub(1, 1) == "@" and x.src:find(file, 1, true) and (d == nil or x.d == d) and (k == nil or x.k == k) then out[#out + 1] = x end
  end
  return out
end
-- ONCE: at least n timer calls, all handing the same function
local function once(label, list, n)
  local seen, distinct = {}, 0
  for _, x in ipairs(list) do if not seen[x.fn] then seen[x.fn] = true; distinct = distinct + 1 end end
  check("ONCE " .. label .. ": " .. n .. " runs hand the timer one function made once (SD-82 / SD-90)", #list >= n and distinct == 1,
    ("%d timer calls, %d different functions"):format(#list, distinct))
end
local function plain(l) return (tostring(l):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
'''

# ----------------------------------------------------------------------------------------------------------------------------------
# session 1: core and Rules (no settings window)
# ----------------------------------------------------------------------------------------------------------------------------------
S_CORE = COMMON + r'''
return function(W, L)
-- a stand-in Esc menu with pooled buttons laid out from the top (our own small model of the game's layout entries)
local M = CreateFrame("Frame", "GameMenuFrame", UIParent)
M:SetSize(220, 100); M:SetPoint("TOP", UIParent, "TOP", 0, -100)
local pool = { active = {}, free = {} }
function pool:EnumerateActive() local i, t = 0, self.active; return function() i = i + 1; return t[i] end end
M.buttonPool = pool
local nextIdx = 0
function M:AddButton(text)
  local b = table.remove(pool.free) or CreateFrame("Button", nil, M)
  b:SetSize(200, 28); b:SetText(text); b:Show(); nextIdx = nextIdx + 1; b.layoutIndex = nextIdx
  pool.active[#pool.active + 1] = b
  return b
end
function M:Layout()
  table.sort(pool.active, function(a, b) return a.layoutIndex < b.layoutIndex end)
  local y = -40
  for _, b in ipairs(pool.active) do b:ClearAllPoints(); b:SetPoint("TOP", M, "TOP", 0, y); y = y - 30 end
  M:SetHeight(-y + 20 - 2)
end
MACROS = MACROS or "Macros"
function M:InitButtons()
  for _, b in ipairs(pool.active) do b:Hide(); pool.free[#pool.free + 1] = b end
  pool.active = {}; nextIdx = 0
  for _, t in ipairs({ "Options", "AddOns", MACROS, "Log Out", "Return to Game" }) do self:AddButton(t) end
  self:Layout()
end

L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
check("(setup) core and XayaUI Rules loaded", ns ~= nil and ns.AuraModel ~= nil and ns.AuraTracker ~= nil)

-- core, Theme.lua:521: the live preview while the color picker is open (NewTicker every 0.12 s)
section("THEME", function()
  local T = ns.Theme
  local live = 0
  ns.On("THEME_CHANGED", function() live = live + 1 end)
  local ran = 0
  local function job() ran = ran + 1 end
  local okShown, okRan, okStopped = true, true, true
  local list = rec("XayaUI/Theme.lua", 0.12, function()
    for round = 1, 2 do
      ColorPickerFrame:Show()
      local l0, r0 = live, ran
      T.Defer(job); T.Defer(job)
      W.tick(0.13, 2)
      if not (live > l0 and ran == r0) then okShown = false end         -- repainted in place, the queued work waits for the close
      ColorPickerFrame:Hide()
      W.tick(0.13, 1)
      if ran ~= r0 + 1 then okRan = false end                           -- queued once (the same function twice), run once at the close
      local l1 = live
      W.tick(0.13, 3)
      if live ~= l1 then okStopped = false end                          -- the ticker stopped
    end
  end, "NewTicker")
  once("Theme.lua color picker live preview (NewTicker)", list, 2)
  check("SAME Theme.lua: while the color picker is open the open windows repaint in place and the queued work waits", okShown)
  check("SAME Theme.lua: when the picker closes the queued work runs once", okRan, ran)
  check("SAME Theme.lua: then the preview stops (no more repaints)", okStopped)
end)

-- core, MinimapButton.lua:236: the click that ends a drag is not a click (0.05 s)
section("MINIMAP", function()
  local b = rawget(_G, "XayaUIMinimapButton")
  check("(setup) the minimap button exists", b ~= nil)
  if not b then return end
  ns.minimapDB.locked = false
  local opened = 0
  local realToggle = ns.ToggleUI
  ns.ToggleUI = function() opened = opened + 1 end
  local okIgnored, okAfter = true, true
  local list = rec("XayaUI/MinimapButton.lua", 0.05, function()
    for round = 1, 2 do
      b:GetScript("OnDragStart")(b); b:GetScript("OnDragStop")(b)
      local o0 = opened
      b:GetScript("OnClick")(b, "RightButton")
      if opened ~= o0 then okIgnored = false end
      W.tick(0.06, 1)
      b:GetScript("OnClick")(b, "RightButton")
      if opened ~= o0 + 1 then okAfter = false end
    end
  end)
  ns.ToggleUI = realToggle
  once("MinimapButton.lua end of a drag", list, 2)
  check("SAME MinimapButton.lua: the right-click that ends a drag does not open the settings", okIgnored)
  check("SAME MinimapButton.lua: a right-click 0.05 s later does", okAfter, opened)
end)

-- core, KeyCatch.lua:142: a key the window used is kept from the game for that press only, given back next frame
section("KEYCATCH", function()
  local f = CreateFrame("Frame", "ClosureTestKeyWindow", UIParent); f:SetSize(100, 100); f:SetPoint("CENTER"); f:Show()
  local used = 0
  ns.KeyCatch(f, function(_, key) if key == "J" then used = used + 1; return true end end)
  W.tick(0.05, 2)
  local okKept, okBack = true, true
  local list = rec("XayaUI/KeyCatch.lua", 0, function()
    for round = 1, 2 do
      f:GetScript("OnKeyDown")(f, "J")
      if f:GetPropagateKeyboardInput() then okKept = false end
      W.tick(0.01, 1)
      if not f:GetPropagateKeyboardInput() then okBack = false end
    end
  end)
  once("KeyCatch.lua key given back next frame", list, 2)
  check("SAME KeyCatch.lua: the used key is kept from the game for that press", okKept and used == 2, used)
  check("SAME KeyCatch.lua: next frame keys go to the game again", okBack)
end)

-- core, GameMenuButton.lua:288: the XayaUI row sized like the Macros row again next frame (another skin may resize the rows after us)
section("GAMEMENU", function()
  local function ours() return rawget(_G, "XayaUI_GameMenuButton") end
  local function macros() for _, p in ipairs(pool.active) do if p:GetText() == MACROS then return p end end end
  local okSize, seen = true, {}
  local list = rec("XayaUI/GameMenuButton.lua", 0, function()
    for round = 1, 2 do
      M:InitButtons()
      local m = macros()
      m:SetSize(240 + round, 31)                -- another skin resizes the rows after us
      W.tick(0.01, 1)
      local b = ours()
      local w, h = b and b:GetWidth(), b and b:GetHeight()
      seen[#seen + 1] = tostring(w) .. "x" .. tostring(h)
      if not (b and w == 240 + round and h == 31) then okSize = false end
    end
  end)
  -- two builds in one frame: each check runs with its own build's rows, in build order. The pool hands the first build's XayaUI slot
  -- back out as the second build's Macros row, so the first check sizes that row like the first build's anchor (200x28) and the
  -- second check then copies it: the XayaUI row ends 200x28 (the old code, one function per build, does exactly this)
  local twice = rec("XayaUI/GameMenuButton.lua", 0, function()
    M:InitButtons(); M:InitButtons()
    macros():SetSize(250, 33)
    W.tick(0.01, 1)
  end)
  local b = ours()
  local both = b and (tostring(b:GetWidth()) .. "x" .. tostring(b:GetHeight()))
  for _, x in ipairs(twice) do list[#list + 1] = x end
  once("GameMenuButton.lua check again next frame", list, 4)
  check("SAME GameMenuButton.lua: next frame the XayaUI row takes the Macros row's new size (241x31, then 242x31)", okSize,
    table.concat(seen, ", "))
  check("SAME GameMenuButton.lua: two builds in one frame, each check with its own build's rows in order: the XayaUI row ends 200x28",
    #twice == 2 and both == "200x28", tostring(#twice) .. " " .. tostring(both))
end)

-- Rules, AuraModel.lua:677: a burst of spell-data events drops the duration cache once, 1 s later
section("RELOAD", function()
  local Mo = ns.AuraModel
  local realCb = Mo.OnSpellDataLoaded
  local calls = 0
  Mo.OnSpellDataLoaded = function() calls = calls + 1 end
  local okWait, okDrop = true, true
  local list = rec("XayaUI_Rules/Combat/AuraModel.lua", 1, function()
    for round = 1, 2 do
      local c0 = calls
      Mo.cache = { marker = true }
      W.fire("SPELL_DATA_LOAD_RESULT", 1, true); W.fire("SPELL_DATA_LOAD_RESULT", 2, true); W.fire("SPELL_DATA_LOAD_RESULT", 3, true)
      W.tick(0.5, 1)
      if not (Mo.cache.marker and calls == c0) then okWait = false end
      W.tick(0.6, 1)
      if Mo.cache.marker or next(Mo.cache) ~= nil or calls ~= c0 + 1 then okDrop = false end
    end
  end)
  Mo.OnSpellDataLoaded = realCb
  once("AuraModel.lua spell data reload", list, 2)
  check("SAME AuraModel.lua: three events in a burst set one wait; nothing is dropped before 1 s", okWait and #list == 2, #list)
  check("SAME AuraModel.lua: after 1 s the duration cache is empty and the listener ran once", okDrop, calls)
end)

-- Rules, AuraModel.lua:699: learning mode, the aura comparison 0.4 s after each cast, with that cast's own spell and snapshot
section("LEARN", function()
  local Mo = ns.AuraModel
  Mo.SetLearning(true)
  local n0 = #Mo.learnLog
  local A, B = 7001, 7002
  local list = rec("XayaUI_Rules/Combat/AuraModel.lua", 0.4, function()
    W.fire("UNIT_SPELLCAST_SENT", "player", "t", "g1", A)
    W.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g1", A)
    W.fire("UNIT_SPELLCAST_SENT", "player", "t", "g2", B)
    W.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g2", B)
    W.tick(0.2, 1)
  end)
  local mid = #Mo.learnLog
  W.tick(0.25, 1)
  Mo.SetLearning(false)
  local lines = {}
  for i = n0 + 1, #Mo.learnLog do lines[#lines + 1] = plain(Mo.learnLog[i]) end
  once("AuraModel.lua cast comparison", list, 2)
  check("SAME AuraModel.lua: nothing is compared before 0.4 s", mid == n0, mid - n0)
  check("SAME AuraModel.lua: at 0.4 s each cast gets its own line, in cast order (7001, then 7002)", #lines == 2
    and lines[1]:find("7001", 1, true) ~= nil and lines[2]:find("7002", 1, true) ~= nil, table.concat(lines, " / "))
end)

-- Rules, AuraTracker.lua:553: after a readable cast while auras are restricted, the new aura-instance IDs are linked to the aura that
-- cast causes, looked for at 0.15 s and 0.6 s, each cast with its own snapshot
section("LINK", function()
  local T = ns.AuraTracker
  local IDS = { 1 }
  C_UnitAuras.GetUnitAuraInstanceIDs = function() local t = {}; for i, v in ipairs(IDS) do t[i] = v end; return t end
  local realR = ns.AurasRestricted
  ns.AurasRestricted = function() return true end
  local A, B = 8101, 8202
  local list = rec("XayaUI_Rules/Combat/AuraTracker.lua", nil, function()
    T.Resolve(A); T.OnCastSent(A); IDS = { 1, 11 }; T.OnCastWindows(A)
    T.Resolve(B); T.OnCastSent(B); IDS = { 1, 11, 12 }; T.OnCastWindows(B)
  end)
  local function ids(id)
    local s = T.states[id]; local L = s and s.link
    if not L then return "none" end
    local t = {}; for k in pairs(L.ids) do t[#t + 1] = k end; table.sort(t)
    return tostring(L.cast) .. ":" .. table.concat(t, ",")
  end
  W.tick(0.1, 1)
  local early = ids(A) .. " " .. ids(B)
  W.tick(0.1, 1)
  local at015 = ids(A) .. " " .. ids(B)
  W.tick(0.5, 1)
  local at06 = ids(A) .. " " .. ids(B)
  ns.AurasRestricted = realR
  C_UnitAuras.GetUnitAuraInstanceIDs = nil
  local short, long = {}, {}
  for _, x in ipairs(list) do if x.d == 0.15 then short[#short + 1] = x elseif x.d == 0.6 then long[#long + 1] = x end end
  once("AuraTracker.lua link check at 0.15 s", short, 2)
  once("AuraTracker.lua link check at 0.6 s", long, 2)
  check("SAME AuraTracker.lua: nothing is linked before 0.15 s", early == "none none", early)
  -- (the first cast's check runs first, with its own snapshot {1}: both 11 and 12 are new to it and it takes them; the second cast's
  -- check, snapshot {1, 11}, then finds 12 already taken. In the other order, or with the snapshots swapped, 8202 would get 12.)
  check("SAME AuraTracker.lua: at 0.15 s the first cast's check runs first with its own snapshot: 8101 gets 11 and 12, 8202 finds them taken",
    at015 == "8101:11,12 none", at015)
  check("SAME AuraTracker.lua: the 0.6 s look changes nothing more", at06 == at015, at06)
end)

return R
end
'''

S_OPTIONS = COMMON + r'''
-- ONCE for a path that makes more than one timer call: run it again; it may hand the timer only functions it handed the first time
local function rerun(label, file, d, act, k)
  local l1 = rec(file, d, act, k)
  local l2 = rec(file, d, act, k)
  local s1 = {}
  for _, x in ipairs(l1) do s1[x.fn] = true end
  local fresh = 0
  for _, x in ipairs(l2) do if not s1[x.fn] then fresh = fresh + 1 end end
  check("ONCE " .. label .. ": run again, it hands the timer only the functions it handed the first time (made once; SD-82 / SD-90)",
    #l1 >= 1 and #l2 >= 1 and fresh == 0, ("%d then %d timer calls, %d new functions the second time"):format(#l1, #l2, fresh))
end
return function(W, L)
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
check("(setup) the settings window addon loaded", ns ~= nil and ns.BuildOptionsTable ~= nil)
if not (ns and ns.BuildOptionsTable) then return R end
ns.Print = function() end
if IsMouseButtonDown == nil then IsMouseButtonDown = function() return false end end   -- (the stand-in has no mouse buttons: released)
local function NewRule(name, folder)
  local r = ns.NewRule(); r.name = name; r.enabled = true; r.folder = folder; r.uid = ns.NewUID()
  r.useCd = true; r.spellID = 203720; r.cdState = "ready"
  ns.NormalizeRule(r); r.visual.enabled = true
  ns.rules[#ns.rules + 1] = r
  return r
end
local function idx(r) for i, x in ipairs(ns.rules) do if x == r then return i end end end
local function byUid(u) for _, x in ipairs(ns.rules) do if x.uid == u then return x end end end
local function live(r) return byUid(r.uid) end   -- (Discard and Ctrl+Z put copies in a rule's place: look it up again by its uid)
local function find(node, key, depth)
  depth = depth or 0
  if type(node) ~= "table" or depth > 18 then return nil end
  local a = node.args
  if type(a) ~= "table" then return nil end
  if a[key] ~= nil then return a[key] end
  for _, c in pairs(a) do local hit = type(c) == "table" and find(c, key, depth + 1); if hit then return hit end end
end
local F1 = ns.NewFolder("Closure group")
local A = NewRule("Rule One")
local B = NewRule("Rule Two")
local C = NewRule("Group rule one", F1.id)     -- (the group Display tab's two displays)
local D = NewRule("Group rule two", F1.id)
CueRulesDB.ui = CueRulesDB.ui or {}; CueRulesDB.ui.consoleAutoOpen = false
pcall(ns.ToggleUI); W.tick(0.05, 6)
local reg, ACD = LibStub("AceConfigRegistry-3.0"), LibStub("AceConfigDialog-3.0")
local APP = "CueRules"
check("(setup) the settings window is open", ACD.OpenFrames[APP] ~= nil)
-- counters. quiet: a redraw is counted, not done (a stand-in rebuild takes seconds); what is checked is when and how often the window
-- is asked to redraw
local redraws, opens, uiN, quiet = 0, 0, 0, true
local realNC, realOpen = reg.NotifyChange, ACD.Open
reg.NotifyChange = function(self, app, ...) if app == APP then redraws = redraws + 1; if quiet then return end end; return realNC(self, app, ...) end
ACD.Open = function(self, app, ...) if app == APP then opens = opens + 1; if quiet then return end end; return realOpen(self, app, ...) end
local realUI = ns.UI.Notify
ns.UI.Notify = function(...) uiN = uiN + 1; if quiet then return end; return realUI(...) end
local function rulesTree()
  local of = ACD.OpenFrames[APP]
  local function walk(w)
    if not w then return nil end
    if w.type == "TreeGroup" and w.dragger and w.dragger.xuiSafeDrag then return w end
    for _, c in ipairs(w.children or {}) do local f = walk(c); if f then return f end end
  end
  return walk(of)
end
local function row(r)
  local t = rulesTree()
  local want = "rule" .. tostring(idx(live(r)))
  for _, b in ipairs(t and t.buttons or {}) do
    if b:IsShown() and tostring(b.uniquevalue or ""):match("rule%d+$") == want then return b end
  end
end

-- Options, AuraSetup.lua:355: the setup window scans again 1.5 s after it opens (spell text arrives late), only while it is open
section("AURASETUP", function()
  local n = 0
  local realRef = ns.AuraSetup_Refresh
  -- whatever the settings window's opening left waiting runs first; the setup window starts closed
  local fr0 = rawget(_G, "XayaUIAuraSetupFrame"); if fr0 then fr0:Hide() end
  W.tick(0.5, 4)
  -- a scan counts when a function AuraSetup.lua handed the timer at 1.5 s (in this section's record) asks for it
  ns.AuraSetup_Refresh = function(...)
    local info = debug.getinfo(2, "f")
    for _, x in ipairs(REC or {}) do if info and x.fn == info.func and x.d == 1.5 then n = n + 1; break end end
    return realRef(...)
  end
  local okOpen, okClosed, seenA = true, true, {}
  local list = rec("XayaUI_Options/AuraSetup.lua", 1.5, function()
    for round = 1, 2 do
      ns.AuraSetup_Open()
      local n0 = n
      W.tick(1.0, 1)
      local early = n
      W.tick(0.6, 1)
      seenA[#seenA + 1] = (early - n0) .. "+" .. (n - early)
      if not (early == n0 and n == n0 + 1) then okOpen = false end
      local fr = rawget(_G, "XayaUIAuraSetupFrame")
      if fr then fr:Hide() end
      ns.AuraSetup_Open(); if fr then fr:Hide() end
      local n1 = n
      W.tick(1.6, 1)
      if n ~= n1 then okClosed = false end
    end
  end)
  ns.AuraSetup_Refresh = realRef
  once("AuraSetup.lua second scan", list, 4)
  check("SAME AuraSetup.lua: 1.5 s after the setup window opens it scans again, not before", okOpen, table.concat(seenA, ", "))
  check("SAME AuraSetup.lua: closed before then: no second scan", okClosed)
end)

-- Options, Options.lua:395: a view change made outside the window redraws it once, next frame; a later request or a redraw that
-- already shows it replaces the waiting one
section("VIEW", function()
  local Tree = ns.OptionsApi.Shared.Tree
  local r1, r1b, r2, r3, r4
  local list = rec("XayaUI_Options/Options.lua", 0, function()
    opens = 0; Tree.ViewChanged(); Tree.ViewChanged()
    local o0 = opens
    W.tick(0.01, 1); r1 = o0 .. "," .. opens
    W.tick(0.01, 2); r1b = opens
    opens = 0; Tree.ViewChanged(); Tree.view = nil      -- (a full redraw that already shows the change cancels it: TreePaint.lua)
    W.tick(0.01, 2); r2 = opens
    opens = 0; Tree.ViewChanged(); W.tick(0.01, 1); Tree.ViewChanged(); W.tick(0.01, 1); r3 = opens
    -- a request made next frame BEFORE the first one's turn (by something whose own wait was set earlier) replaces it: the first
    -- request's turn draws nothing, the later request draws the frame after
    opens = 0
    C_Timer.After(0, function() Tree.ViewChanged() end)   -- (the test's own wait, set first)
    Tree.ViewChanged()
    W.tick(0.01, 1); local a = opens
    W.tick(0.01, 1); r4 = a .. "," .. opens
  end)
  once("Options.lua view redraw", list, 7)
  check("SAME Options.lua: two requests in one frame: no redraw at once, one redraw next frame, none later", r1 == "0,1" and r1b == 1,
    tostring(r1) .. " then " .. tostring(r1b))
  check("SAME Options.lua: a request that a redraw already showed is dropped: no redraw", r2 == 0, r2)
  check("SAME Options.lua: one request in each of two frames: two redraws", r3 == 2, r3)
  check("SAME Options.lua: a later request made next frame before the first one's turn replaces it: no redraw that frame, one the frame after",
    r4 == "0,1", r4)
end)

-- Options, RuleEditor/DisplayTab.lua:195: a group Display color set while the color picker is open redraws the window once, the
-- frame after the picker closes
section("PICKER", function()
  local col = find(find(ns.BuildOptionsTable(), F1.id), "bdColor")
  check("(setup) the group's Border color picker is there", col ~= nil)
  if not col then return end
  local okHush, okOne = true, true
  local list = rec("XayaUI_Options/RuleEditor/DisplayTab.lua", 0, function()
    for round = 1, 2 do
      local r0 = redraws
      ColorPickerFrame:Show()
      col.set(nil, 0, round * 0.4, 0, 1)
      if redraws ~= r0 then okHush = false end
      ColorPickerFrame:Hide()
      if redraws ~= r0 then okHush = false end
      W.tick(0.01, 1)
      if redraws ~= r0 + 1 then okOne = false end
      W.tick(0.01, 2)
      if redraws ~= r0 + 1 then okOne = false end
    end
  end)
  once("DisplayTab.lua redraw after the picker closes", list, 2)
  check("SAME DisplayTab.lua: no redraw while the picker is open, nor at the close itself", okHush)
  check("SAME DisplayTab.lua: one redraw the frame after the picker closes, none later", okOne, redraws)
  check("SAME DisplayTab.lua: both displays of the group took the color", C.visual.border and D.visual.border
    and C.visual.border.color and D.visual.border.color and C.visual.border.color[2] == 0.8 and D.visual.border.color[2] == 0.8)
end)

-- Options, RuleEditor/Drafts.lua:224: a sidebar refresh redraws now and once more next frame
section("REFRESH", function()
  local okNow, okNext = true, true
  local list = rec("XayaUI_Options/RuleEditor/Drafts.lua", 0, function()
    for round = 1, 2 do
      local u0 = uiN
      ns.RefreshSidebar({ A }); ns.RefreshSidebar({ B })
      if uiN ~= u0 + 2 then okNow = false end
      W.tick(0.01, 1)
      if uiN ~= u0 + 4 then okNext = false end
      W.tick(0.01, 2)
      if uiN ~= u0 + 4 then okNext = false end
    end
  end)
  once("Drafts.lua sidebar refresh", list, 4)
  check("SAME Drafts.lua: each sidebar refresh redraws at once", okNow)
  check("SAME Drafts.lua: and once more next frame (two refreshes: two more), none later", okNext, uiN)
end)

-- Options, RuleEditor/Drafts.lua:277 (Discard changes) and :368 (save as a copy): a redraw now and a second one next frame
section("DISCARD", function()
  local okNow, okNext = true, true
  local function act(fn, r)
    local u0 = uiN
    fn(r)
    if uiN ~= u0 + 1 then okNow = false end
    W.tick(0.01, 1)
    if uiN ~= u0 + 2 then okNext = false end
    W.tick(0.01, 2)
    if uiN ~= u0 + 2 then okNext = false end
  end
  rerun("Drafts.lua second redraw after Discard changes", "XayaUI_Options/RuleEditor/Drafts.lua", 0, function() act(ns.DraftDiscard, B) end)
  check("SAME Drafts.lua: Discard changes redraws at once and once more next frame, none later", okNow and okNext, uiN)
  okNow, okNext = true, true
  local n0 = #ns.rules
  rerun("Drafts.lua second redraw after saving as a copy", "XayaUI_Options/RuleEditor/Drafts.lua", 0, function() act(ns.DraftSaveAsCopy, B) end)
  check("SAME Drafts.lua: saving as a copy adds the copy, redraws at once and once more next frame, none later",
    okNow and okNext and #ns.rules == n0 + 2, (#ns.rules - n0) .. " rules added")
end)

-- Options, RuleEditor/Drafts.lua:744 (an undo step closes 0.5 s after the last edit) and :771 (Ctrl+Z / Ctrl+Y redraw twice)
section("UNDO", function()
  ns.SelectedRuleForUndo = function() return byUid(A.uid) end
  if ns.DraftsOnOpen then pcall(ns.DraftsOnOpen) end
  if ns.UndoFirstState then pcall(ns.UndoFirstState) end
  local uid = A.uid
  local name0 = byUid(uid).name
  local list = rec("XayaUI_Options/RuleEditor/Drafts.lua", 0.5, function()
    for k = 1, 4 do byUid(uid).name = "Edited " .. k; ns.MarkDirty(); W.tick(0.3, 1) end   -- 0.3 s apart: one step
    W.tick(0.3, 4)                                                                         -- closed 0.5 s after the last edit
    byUid(uid).name = "Edited 5"; ns.MarkDirty(); W.tick(0.3, 4)                          -- a step of its own
  end)
  once("Drafts.lua undo step wait", list, 2)
  local okNow, okNext, names = true, true, {}
  rerun("Drafts.lua second redraw after Ctrl+Z", "XayaUI_Options/RuleEditor/Drafts.lua", 0, function()
    local u0 = uiN
    local used = ns.UndoKey(false)
    names[#names + 1] = tostring(used) .. ":" .. tostring(byUid(uid) and byUid(uid).name)
    if uiN ~= u0 + 1 then okNow = false end
    W.tick(0.01, 1)
    if uiN ~= u0 + 2 then okNext = false end
  end)
  check("SAME Drafts.lua: four edits 0.3 s apart make one undo step: Ctrl+Z undoes the fifth edit, a second Ctrl+Z goes back to the name before the first",
    names[1] == "true:Edited 4" and names[2] == "true:" .. tostring(name0), table.concat(names, " / "))
  check("SAME Drafts.lua: each Ctrl+Z redraws at once and once more next frame", okNow and okNext)
  ns.SelectedRuleForUndo = nil
end)

-- Options, RuleEditor/RuleSearch.lua:301: a search result clicked: its option is scrolled into view once its tab is drawn, tried once
-- a frame, at most RS.RevealTries times; each click its own option and count
section("REVEAL", function()
  local RS = ns.RuleSearch
  local E1, E2, E3 = { name = "one", desc = "", tab = "t" }, { name = "two", desc = "", tab = "t" }, { name = "never", desc = "", tab = "t" }
  local tries, need = {}, { [E1] = 3, [E2] = 1, [E3] = 1000 }
  local saved = { Find = RS.Find, OpenPath = RS.OpenPath, Reveal = RS.Reveal, sel = ns.SelectRuleTab }
  local res = {}
  RS.Find = function() return res end
  RS.OpenPath = function() end
  ns.SelectRuleTab = function() end
  RS.Reveal = function(e) tries[e] = (tries[e] or 0) + 1; return tries[e] >= need[e] end
  local args = ns.RuleSearchArgs(A, { A }, function() end)
  args.xuiSearch.set(nil, "x")
  local seq = {}
  local function name(e) return e and e.name or "-" end
  local list = rec("XayaUI_Options/RuleEditor/RuleSearch.lua", 0, function()
    res = { { e = E1 }, { e = E2 } }
    RS.lastReveal = nil
    args.xuiSR1.func(); args.xuiSR2.func()
    seq[#seq + 1] = name(RS.lastReveal) .. (tries[E1] or 0) .. (tries[E2] or 0)
    for _ = 1, 4 do W.tick(0.01, 1); seq[#seq + 1] = name(RS.lastReveal) .. (tries[E1] or 0) .. (tries[E2] or 0) end
    res = { { e = E3 } }
    args.xuiSR1.func()
    W.tick(0.01, 15)
  end)
  RS.Find, RS.OpenPath, RS.Reveal, ns.SelectRuleTab = saved.Find, saved.OpenPath, saved.Reveal, saved.sel
  once("RuleSearch.lua reveal tries", list, 12)
  check("SAME RuleSearch.lua: two results clicked in one frame: each tries its own option once a frame; 'two' is shown first, 'one' on its third try",
    table.concat(seq, " ") == "-00 two11 two21 one31 one31", table.concat(seq, " "))
  check("SAME RuleSearch.lua: an option that never comes into view is tried RS.RevealTries (10) times, then left", tries[E3] == RS.RevealTries,
    tries[E3])
end)

-- Options, RuleEditor/SaveBar.lua:74: "Click again to discard" ends 4 s after the first click; a later first click has its own 4 s
section("SAVEBAR", function()
  ns.Settings("core").promptSave = true
  if ns.DraftsApplySetting then pcall(ns.DraftsApplySetting) end
  pcall(ns.ReselectRule, live(A)); W.tick(0.05, 2)
  live(A).spellID = 6161; W.tick(0.05, 2)
  local fr = CreateFrame("Frame", nil, UIParent); fr:Show()
  local bar = ns.SaveBarUpdate(fr)
  check("(setup) the save bar is up for the changed rule", bar ~= nil and bar.rule ~= nil)
  if not bar then return end
  local realConfirm, realDiscard = ns.DraftsConfirmDiscard, ns.DraftDiscard
  local discards = 0
  ns.DraftsConfirmDiscard = function() return true end
  ns.DraftDiscard = function() discards = discards + 1 end
  local function click() bar.btn.discard:GetScript("OnClick")(bar.btn.discard) end
  local st = {}
  local list = rec("XayaUI_Options/RuleEditor/SaveBar.lua", 4, function()
    click(); st[1] = tostring(bar.armed)                          -- 0 s: first click: armed
    W.tick(1, 1); click(); st[2] = tostring(bar.armed) .. discards  -- 1 s: second click: discards, not armed
    W.tick(1, 1); click(); st[3] = tostring(bar.armed)            -- 2 s: a new first click: armed again
    W.tick(2.1, 1); st[4] = tostring(bar.armed)                   -- 4.1 s: the first click's 4 s end: still armed (its own 4 s run to 6 s)
    W.tick(2, 1); st[5] = tostring(bar.armed)                     -- 6.1 s: not armed
  end)
  ns.DraftsConfirmDiscard, ns.DraftDiscard = realConfirm, realDiscard
  ns.Settings("core").promptSave = nil
  if ns.DraftsApplySetting then pcall(ns.DraftsApplySetting) end
  once("SaveBar.lua end of 'Click again to discard'", list, 2)
  check("SAME SaveBar.lua: armed, discarded, armed again; the first click's 4 s end does not disarm the second; its own does",
    table.concat(st, " ") == "true false1 true true false", table.concat(st, " "))
end)

-- Options, RuleEditor/Sidebar.lua:225: an eye click on the open rule's row puts the sidebar's scroll position back, now and next frame
section("EYE", function()
  pcall(ns.ReselectRule, live(A)); W.tick(0.05, 3)
  local b = row(A)
  local eye = b and b.xuiEye
  local tree = b and b.obj
  local st = tree and (tree.status or tree.localstatus)
  check("(setup) the open rule's row and its eye button are there", eye ~= nil and st ~= nil)
  if not (eye and st) then return end
  local got = {}
  local realDec = ns.DecorateTrees
  realDec(); W.tick(0.05, 2)          -- (rows painted with the rules as they are now: Discard and Ctrl+Z put copies in their place)
  b = row(A); eye = b and b.xuiEye
  ns.DecorateTrees = function() end   -- (the stand-in's row repaint resets the scroll; in the game it keeps it)
  local list = rec("XayaUI_Options/RuleEditor/Sidebar.lua", 0, function()
    for round = 1, 2 do
      local sb = tree.scrollbar
      if sb and sb.SetMinMaxValues then sb:SetMinMaxValues(0, 1000) end   -- (a list long enough to scroll)
      st.scrollvalue = 40 + round
      eye:GetScript("OnClick")(eye)
      if sb then sb:SetValue(0) end; st.scrollvalue = 0   -- (the window's redraw throws the list back to the top)
      W.tick(0.01, 1)
      got[#got + 1] = sb and tostring(sb:GetValue()) or "no scroll bar"   -- (the stored position: AceGUI's own refresh sets 0 while every row fits)
    end
  end)
  -- two clicks in one frame, at two positions: next frame each is put back with its own position, in click order
  local sb = tree.scrollbar
  local puts = {}
  local realSet = sb and sb.SetValue
  local two = rec("XayaUI_Options/RuleEditor/Sidebar.lua", 0, function()
    st.scrollvalue = 41; eye:GetScript("OnClick")(eye)
    st.scrollvalue = 50; eye:GetScript("OnClick")(eye)
    if sb then sb:SetValue(0); sb.SetValue = function(self, v, ...) puts[#puts + 1] = tostring(v); return realSet(self, v, ...) end end
    W.tick(0.01, 1)
    if sb then sb.SetValue = realSet end
  end)
  for _, x in ipairs(two) do list[#list + 1] = x end
  ns.DecorateTrees = realDec
  once("Sidebar.lua scroll position put back", list, 4)
  check("SAME Sidebar.lua: the sidebar's scroll bar is put back next frame (41, then 42)", table.concat(got, ",") == "41,42",
    table.concat(got, ","))
  check("SAME Sidebar.lua: two clicks in one frame (at 41, then at 50): next frame each puts back its own position, in that order",
    table.concat(puts, ",") == "41,50", table.concat(puts, ","))
end)

-- Options, RuleEditor/Sidebar.lua:1854 (rename from the row menu, 0.1 s) and :1949 (a new rule's name box, 0.15 s)
section("RENAME", function()
  local realRename = ns.SidebarRename
  local got = {}
  ns.SidebarRename = function(b) got[#got + 1] = (b == row(A)) and "A" or ((b == row(B)) and "B" or "?") end
  local ra, rb = row(A), row(B)
  check("(setup) both rule rows are there", ra ~= nil and rb ~= nil)
  if not (ra and rb) then ns.SidebarRename = realRename; return end
  local seq = {}
  local list = rec("XayaUI_Options/RuleEditor/Sidebar.lua", 0.1, function()
    ns.SidebarRenameLater(ra); ns.SidebarRenameLater(rb)
    W.tick(0.05, 1); seq[#seq + 1] = table.concat(got, "")
    W.tick(0.06, 1); seq[#seq + 1] = table.concat(got, "")
    ns.SidebarRenameLater(ra); ra:Hide()
    W.tick(0.11, 1); seq[#seq + 1] = table.concat(got, "")
    ra:Show()
  end)
  once("Sidebar.lua rename from the row menu", list, 3)
  check("SAME Sidebar.lua: two rows asked: nothing before 0.1 s, then each row's own name box, in order (A, B)",
    seq[1] == "" and seq[2] == "AB", table.concat(seq, " / "))
  check("SAME Sidebar.lua: a row hidden before the 0.1 s end: no name box", seq[3] == "AB", seq[3])
  got = {}
  local seq2 = {}
  local list2 = {}
  for _, r in ipairs({ A, B }) do
    local l = rec("XayaUI_Options/RuleEditor/Sidebar.lua", 0.15, function()
      ns.pendingRename = live(r)
      if ns.DecorateTrees then ns.DecorateTrees() end
      W.tick(0.1, 1); seq2[#seq2 + 1] = table.concat(got, "")
      W.tick(0.06, 1); seq2[#seq2 + 1] = table.concat(got, "")
    end)
    for _, x in ipairs(l) do list2[#list2 + 1] = x end
  end
  ns.SidebarRename = realRename
  once("Sidebar.lua a new rule's name box", list2, 2)
  check("SAME Sidebar.lua: a new rule's name box opens on its own row 0.15 s after the row is drawn, not before (A, then B)",
    table.concat(seq2, " / ") == " / A / A / AB", table.concat(seq2, " / "))
end)

-- Options, RuleEditor/SpellSearch.lua:565 (results 0.15 s after the last letter), :573 (closed 0.2 s after the box loses focus,
-- unless it gets it back) and :498 (the compare tooltips hidden again next frame while a result is hovered)
section("SPELLSEARCH", function()
  local AceGUI = LibStub("AceGUI-3.0")
  local w = AceGUI:Create("EditBox")
  w.userdata = w.userdata or {}
  w.userdata.appName = APP
  w.userdata.option = { arg = { xuiSearch = function() end, xuiSearchKind = "spell" } }
  w.frame:SetParent(UIParent); w.frame:Show()
  ns.OptionsApi.TreePaint.rules.Widget(w)
  local eb = w.editbox
  check("(setup) the search box took the spell search", eb ~= nil and eb.xuiSearchHooked == true)
  local function popup()
    for _, o in ipairs(W.objects) do if rawget(o, "rows") and rawget(o, "footer") and rawget(o, "all") then return o end end
  end
  local function shown() local p = popup(); return (p and p:IsShown()) and "shown" or "hidden" end
  local function type(t) eb:SetText(t); eb:GetScript("OnTextChanged")(eb, true) end
  local seq = {}
  local list = rec("XayaUI_Options/RuleEditor/SpellSearch.lua", 0.15, function()
    eb:SetFocus()
    type("Fe"); W.tick(0.1, 1); type("Fel")
    W.tick(0.07, 1); seq[#seq + 1] = shown()                  -- 0.17 s: the first letter's wait ended: nothing (a later letter)
    W.tick(0.1, 1); seq[#seq + 1] = shown()                   -- 0.27 s: the last letter's wait ended: the results
  end)
  once("SpellSearch.lua results after the last letter", list, 2)
  check("SAME SpellSearch.lua: two letters 0.1 s apart: no results at the first letter's 0.15 s, results at the last one's",
    table.concat(seq, " ") == "hidden shown", table.concat(seq, " "))
  local seq2 = {}
  local list2 = rec("XayaUI_Options/RuleEditor/SpellSearch.lua", 0.2, function()
    eb:ClearFocus(); W.tick(0.1, 1); seq2[#seq2 + 1] = shown()
    W.tick(0.15, 1); seq2[#seq2 + 1] = shown()
    eb:SetFocus(); type("Fel"); W.tick(0.2, 1); seq2[#seq2 + 1] = shown()
    eb:ClearFocus(); W.tick(0.1, 1); eb:SetFocus(); W.tick(0.15, 1); seq2[#seq2 + 1] = shown()
  end)
  once("SpellSearch.lua close after focus lost", list2, 2)
  check("SAME SpellSearch.lua: the results close 0.2 s after the box loses focus, not if it gets the focus back first",
    table.concat(seq2, " ") == "shown hidden shown shown", table.concat(seq2, " "))
  local SX = ns.SpellSearchTest and ns.SpellSearchTest.SX
  local p = popup()
  local r1 = p and p.rows and p.rows[1]
  check("(setup) the results have rows", SX ~= nil and r1 ~= nil)
  if not (SX and r1) then return end
  r1.id = r1.id or 203720
  local realNC2 = SX.NoCompare
  local nc = 0
  SX.NoCompare = function(...) nc = nc + 1; return realNC2(...) end
  local seq3 = {}
  local list3 = rec("XayaUI_Options/RuleEditor/SpellSearch.lua", 0, function()
    r1:GetScript("OnEnter")(r1); seq3[#seq3 + 1] = nc
    W.tick(0.01, 1); seq3[#seq3 + 1] = nc
    r1:GetScript("OnLeave")(r1)
    r1:GetScript("OnEnter")(r1); r1:GetScript("OnLeave")(r1); seq3[#seq3 + 1] = nc
    W.tick(0.01, 1); seq3[#seq3 + 1] = nc
  end)
  SX.NoCompare = realNC2
  once("SpellSearch.lua compare tooltips hidden again", list3, 2)
  check("SAME SpellSearch.lua: hovering a result hides the compare tooltips now and again next frame; left before then: not again",
    table.concat(seq3, ",") == "1,2,5,5", table.concat(seq3, ","))
end)

-- Options, Skin.lua:223: a theme change repaints the rule-list rows 0.05 s later while the window is open
section("SKINTHEME", function()
  local n = 0
  local realDec = ns.DecorateTrees
  ns.DecorateTrees = function(...) n = n + 1; return realDec(...) end
  local seq = {}
  local list = rec("XayaUI_Options/Skin.lua", 0.05, function()
    for round = 1, 2 do
      local n0 = n
      ns.Theme.Resolve()
      seq[#seq + 1] = n - n0
      W.tick(0.06, 1)
      seq[#seq + 1] = n - n0
    end
  end)
  ns.DecorateTrees = realDec
  once("Skin.lua repaint after a theme change", list, 2)
  check("SAME Skin.lua: a theme change repaints the rows 0.05 s later (once), not at once", table.concat(seq, ",") == "0,1,0,1",
    table.concat(seq, ","))
end)

-- Options, Skin.lua:269: the rule list is filtered 0.25 s after the last letter typed in "Search rules", in the box typed in
section("SKINFILTER", function()
  local sb
  for _, o in ipairs(W.objects) do if o.hint and o.hint.GetText and o.hint:GetText() == "Search rules" and o:IsShown() then sb = o end end
  check("(setup) the 'Search rules' box is there", sb ~= nil)
  if not sb then return end
  local function type(t) sb:SetText(t); sb:GetScript("OnTextChanged")(sb) end
  local seq = {}
  local list = rec("XayaUI_Options/Skin.lua", 0.25, function()
    local u0 = uiN
    type("r"); W.tick(0.1, 1); type("ru")
    seq[#seq + 1] = ns.treeFilter
    W.tick(0.17, 1); seq[#seq + 1] = uiN - u0      -- 0.27 s: the first letter's wait ended: nothing
    W.tick(0.1, 1); seq[#seq + 1] = uiN - u0       -- 0.37 s: the last letter's: one redraw
    type(""); W.tick(0.3, 1); seq[#seq + 1] = uiN - u0
  end)
  once("Skin.lua rule search filter", list, 3)
  check("SAME Skin.lua: typing filters by the text typed (ru); one redraw 0.25 s after the last letter, not after the first; cleared: one more",
    table.concat(seq, ",") == "ru,0,1,2", table.concat(seq, ","))
end)

-- Options, Skin.lua:911: after the sidebar is resized, one pass next frame refreshes its rows
section("SKINRESIZE", function()
  local t = rulesTree()
  local dr = t and t.dragger
  check("(setup) the rule list's resize handle is there", dr ~= nil and dr:GetScript("OnMouseDown") ~= nil)
  if not dr then return end
  local n = 0
  local realRefresh = t.RefreshTree
  t.RefreshTree = function(...) n = n + 1; return realRefresh(...) end
  local seq = {}
  local list = rec("XayaUI_Options/Skin.lua", 0, function()
    for round = 1, 2 do
      local n0 = n
      dr:GetScript("OnMouseDown")(dr, "LeftButton")
      W.tick(0.01, 1)                                 -- the button is up: the drag ends (Finish)
      seq[#seq + 1] = n - n0
      W.tick(0.01, 1)
      seq[#seq + 1] = n - n0
    end
  end)
  t.RefreshTree = realRefresh
  once("Skin.lua refresh after a resize", list, 2)
  check("SAME Skin.lua: the drag ends; the next frame refreshes the rows once", table.concat(seq, ",") == "0,1,0,1", table.concat(seq, ","))
end)

-- Options, Skin.lua:439: /xui debug perf on: a pane switch notes "next frame after tree switch" on the next frame
section("SKINTRACE", function()
  local t = rulesTree()
  check("(setup) the rule list is there", t ~= nil)
  if not t then return end
  ns.perf = ns.perf or {}
  local wasShow = ns.perf.show
  ns.perf.show = true
  local lines = {}
  local realTrace = ns.Trace
  ns.Trace = function(msg) if tostring(msg):find("next frame after", 1, true) then lines[#lines + 1] = msg end end
  local seq = {}
  local list = rec("XayaUI_Options/Skin.lua", 0, function()
    for round = 1, 2 do
      local l0 = #lines
      local stt = t.status or t.localstatus
      pcall(t.Fire, t, "OnGroupSelected", stt and stt.selected)
      seq[#seq + 1] = #lines - l0
      W.tick(0.01, 1)
      seq[#seq + 1] = #lines - l0
    end
  end)
  ns.Trace = realTrace
  ns.perf.show = wasShow
  once("Skin.lua pane switch trace", list, 2)
  check("SAME Skin.lua: the note 'next frame after tree switch' comes one frame after the switch, once",
    table.concat(seq, ",") == "0,1,0,1" and tostring(lines[1]) == "next frame after tree switch (anything below this ran late)",
    table.concat(seq, ",") .. " " .. tostring(lines[1]))
end)

-- Options, TreePaint.lua:123: hovering a row repaints its text now and once more next frame (the game swaps its font on hover)
section("ROWHOVER", function()
  local b = row(A)
  check("(setup) the row is there and painted", b ~= nil and b.xuiFontDone)
  if not b then return end
  ns.HookRowHover(b)
  local n = 0
  local realPaint = ns.PaintRowText
  ns.PaintRowText = function(...) n = n + 1; return realPaint(...) end
  local seq = {}
  local list = rec("XayaUI_Options/TreePaint.lua", 0, function()
    for round = 1, 2 do
      local n0 = n
      b:GetScript("OnEnter")(b)
      local now = n - n0
      W.tick(0.01, 1)
      seq[#seq + 1] = now .. "+" .. (n - n0 - now)
    end
  end)
  ns.PaintRowText = realPaint
  once("TreePaint.lua row repaint next frame", list, 2)
  check("SAME TreePaint.lua: hovering a row repaints its text, then once more next frame", seq[1] and seq[1]:match("%+1$") ~= nil
    and seq[1] == seq[2], table.concat(seq, ","))
end)

-- Options, Skin.lua:1855: a slider arrow held down: one step at once, then after 0.4 s one step every 0.07 s until released
section("SLIDER", function()
  quiet = false
  pcall(ACD.SelectGroup, ACD, APP, "set", "ui"); W.tick(0.05, 4)
  quiet = true
  local arrow
  for _, o in ipairs(W.objects) do if rawget(o, "xuiStop") and o:IsVisible() and o.dir == 1 then arrow = o; break end end
  local f = arrow and arrow:GetParent()
  local w = f and f.obj
  local sl = w and w.slider
  check("(setup) a slider with arrows is on Settings > UI", sl ~= nil)
  if not sl then return end
  local seq = {}
  local list = rec("XayaUI_Options/Skin.lua", 0.4, function()
    for round = 1, 2 do
      local lo, hi = sl:GetMinMaxValues()
      local st = w.step or sl:GetValueStep() or 1
      if st <= 0 then st = 1 end
      sl:SetValue(lo)
      local v0 = sl:GetValue()
      arrow:GetScript("OnMouseDown")(arrow)
      local a = (sl:GetValue() - v0) / st
      W.tick(0.1, 3)
      local b = (sl:GetValue() - v0) / st
      W.tick(0.11, 1)                                  -- 0.41 s: the repeat has started (0.4 s)
      W.tick(0.07, 3)
      local c = (sl:GetValue() - v0) / st
      arrow:GetScript("OnMouseUp")(arrow)
      W.tick(0.07, 3)
      local d = (sl:GetValue() - v0) / st
      seq[#seq + 1] = ("%d,%d,%d,%d"):format(math.floor(a + 0.5), math.floor(b + 0.5), math.floor(c + 0.5), math.floor(d + 0.5))
    end
  end, "NewTimer")
  once("Skin.lua slider arrow repeat (NewTimer)", list, 2)
  check("SAME Skin.lua: held: 1 step at once, none more before 0.4 s, then one every 0.07 s (4 after 0.62 s); released: no more",
    seq[1] == "1,1,4,4" and seq[2] == seq[1], table.concat(seq, " / "))
end)

quiet = false
return R
end
'''


def run_session(src, saved=None):
    folders = H.find_addons()
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    opts = H.to_lua(L, {"folders": folders, "enabled": {k: True for k in folders}})
    opts["saved"] = H.to_lua(L, saved or {})
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(os.path.join(H.HERE, "loader.lua"), world, opts)
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(src, world, loader)
    results = [(res[i][1], res[i][2]) for i in range(1, len(res) + 1)]
    errs = [str(world.errors[i]) for i in range(1, len(world.errors) + 1)]
    return results, errs


def main():
    bad = n = 0
    errs = []
    only = sys.argv[1] if len(sys.argv) > 1 else None   # (core | options: one session, for the mutation runs)
    sessions = []
    if only in (None, "core"):
        sessions.append(("core and Rules", S_CORE))
    if only in (None, "options"):
        sessions.append(("settings window", S_OPTIONS))
    for tag, src in sessions:
        r, e = run_session(src)
        for name, ok in r:
            n += 1
            print(("PASS " if ok else "FAIL ") + "[%s] %s" % (tag, name))
            bad += 0 if ok else 1
        errs.extend("[%s] %s" % (tag, x) for x in e)
    for e in errs:
        print("ERROR in the game stand-in:", e[:600])
    print("%d checks, %d failed, %d Lua errors" % (n, bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
