-- tests/rule_click_cost.lua: driven by tests/rule_click_cost_run.py (see there)
return function(W, L)
local OUT = {}
local function check(name, ok) OUT[#OUT + 1] = (ok and "ok    " or "FAIL  ") .. name end
local APP = "CueRules"
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
local function MakeRules(N)
  ns.rules = {}; ns.folders = {}
  local f1 = ns.NewFolder("Group 1"); local f2 = ns.NewFolder("Group 2"); local f3 = ns.NewFolder("Inner", f1.id)
  local fl = { f1.id, f2.id, f3.id, nil }
  for i = 1, N do
    local r = ns.NewRule()
    r.name = "Rule " .. i; r.folder = fl[i % 4 + 1]; r.enabled = (i % 10 ~= 0); r.uid = ns.NewUID()
    r.useCd = true; r.spellID = 203720; r.cdState = "ready"
    if i % 5 == 0 then r.load = { combat = "yes" } end
    ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
    if i % 9 == 0 then ns.NewCueRule(r, "icon"); ns.NewCueRule(r, "sound"); ns.NewCueRule(r, "texture") end
    if i % 11 == 0 then
      local n = ns.NewRule(); n.name = "Condition"; n.parentUid = r.uid; n.folder = r.folder
      n.when = { list = { { neg = false, op = "and", cmp = "==", num = 0 } } }
      ns.NormalizeRule(n); ns.rules[#ns.rules + 1] = n
    end
  end
  CueRulesDB.rules = ns.rules; CueRulesDB.folders = ns.folders
end
MakeRules(313)
pcall(ns.RefreshAllVisuals); W.tick(0.1, 10)
pcall(ns.LoadOptions); W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
local reg, ACD, GUI = LibStub("AceConfigRegistry-3.0"), LibStub("AceConfigDialog-3.0"), LibStub("AceGUI-3.0")
local A = ns.OptionsApi
local RE = A.RuleEditor
local function frames(n) for i = 1, n do W.tick(1 / 60, 1) end end
local function FindW(pred, w, d)
  w = w or (ACD.OpenFrames and ACD.OpenFrames[APP]); d = d or 0
  if not w or d > 30 then return nil end
  if pred(w) then return w end
  for _, c in ipairs(w.children or {}) do local r = FindW(pred, c, d + 1); if r then return r end end
end

------------------------------------------------------------------ probes: exclusive time and game-API calls per phase
local clock = os.clock
local PH = { order = {}, self = {}, calls = {}, api = {} }
local stack = { "other" }
local tstart = clock()
local function note(n) if not PH.self[n] then PH.self[n] = 0; PH.calls[n] = 0; PH.api[n] = 0; PH.order[#PH.order + 1] = n end end
note("other")
local AFTER = false
local function enter(n) if AFTER and n ~= "engine + timers (frames after the click)" then n = n .. " [frames after]"; note(n) end local t = clock(); local top = stack[#stack]; PH.self[top] = PH.self[top] + (t - tstart); tstart = t; stack[#stack + 1] = n; PH.calls[n] = PH.calls[n] + 1 end
local function leave() local t = clock(); local top = stack[#stack]; PH.self[top] = PH.self[top] + (t - tstart); tstart = t; stack[#stack] = nil end
local function wrap(n, fn)
  note(n)
  return function(...)
    enter(n)
    local r = { pcall(fn, ...) }
    leave()
    if not r[1] then error(r[2], 0) end
    return unpack(r, 2, table.maxn(r))
  end
end
local function upidx(fn, name) local i = 1; while true do local n = debug.getupvalue(fn, i); if not n then return nil end; if n == name then return i end; i = i + 1 end end
local function wrapUp(fn, upname, label)
  local i = upidx(fn, upname); if not i then OUT[#OUT + 1] = "info  no upvalue " .. upname; return end
  local orig = select(2, debug.getupvalue(fn, i)); debug.setupvalue(fn, i, wrap(label, orig)); return orig
end
-- game API calls (every widget method of the stand-in, CreateFrame): counted against the phase on top
do
  local idx = getmetatable(UIParent).__index
  local proto
  local i = 1
  while true do local n, v = debug.getupvalue(idx, i); if not n then break end; if n == "proto" then proto = v end; i = i + 1 end
  for k, f in pairs(proto) do
    if type(f) == "function" then proto[k] = function(...) local top = stack[#stack]; PH.api[top] = PH.api[top] + 1; return f(...) end end
  end
  local CF = CreateFrame
  CreateFrame = function(...) local top = stack[#stack]; PH.api[top] = PH.api[top] + 1; return CF(...) end
end
local P_TREE, P_FILL = "tree build (ns.BuildOptionsTable, whole options table)", "rule editor build (FillRule, the open rule)"
local P_RELEASE, P_DRAW = "draw: release the old widgets (AceGUI Release)", "draw: AceConfigDialog FeedGroup (new widgets, layout)"
local P_SIDE = "sidebar refresh (TreeGroup:RefreshTree + row paint)"
local P_SCAN = "skin: ScanDropdowns (min width: every dropdown text in the tree)"
local P_SKIN = "skin: rest (SkinFrame, Walk, ShadowPass)"
local P_TP = "decorate: TreePaint pass (rows, headings)"
local P_SET = "click handler (set, Changed, Notify)"
local P_ENG = "engine + timers (frames after the click)"
note(P_SET)
ns.BuildOptionsTable = wrap(P_TREE, ns.BuildOptionsTable)
A.FillRule = wrap(P_FILL, A.FillRule)
GUI.Release = wrap(P_RELEASE, GUI.Release)
ACD.FeedGroup = wrap(P_DRAW, ACD.FeedGroup)
local skinDecorate = ns.DecorateTrees
wrapUp(skinDecorate, "origDecorate", P_TP)
local CNT = { rows = 0 }
local SCAN
do
  local umw = ns.UpdateMinWidth
  local i = upidx(umw, "ScanDropdowns")
  if i then
    local scan = select(2, debug.getupvalue(umw, i))
    SCAN = scan
    debug.setupvalue(umw, i, wrap(P_SCAN, scan))
  else OUT[#OUT + 1] = "info  no ScanDropdowns" end
  local sd = ns.SafeDecorate
  ns.SafeDecorate = function(...) CNT.rows = CNT.rows + 1; return sd(...) end
end
ns.DecorateTrees = wrap(P_SKIN, ns.DecorateTrees)
ACD.Open = wrap("draw: ACD:Open (rest)", ACD.Open)
note(P_SIDE)
local function treeProbe()
  local tree = FindW(function(w) return w.type == "TreeGroup" end)
  if tree and not tree.xuiMeasure then
    tree.xuiMeasure = true
    tree.RefreshTree = wrap(P_SIDE, tree.RefreshTree)
  end
end
note(P_ENG)
local function reset() for _, n in ipairs(PH.order) do PH.self[n] = 0; PH.calls[n] = 0; PH.api[n] = 0 end; for k in pairs(CNT) do CNT[k] = 0 end end


------------------------------------------------------------------ open a rule's editor on its Display tab
local function PathOf(i)
  local t = reg:GetOptionsTable(APP)("dialog", "AceConfigDialog-3.0").args.cooldowns.args.enabledTab
  local function w(g, path, d)
    if d > 10 or type(g) ~= "table" or type(g.args) ~= "table" then return nil end
    for k, v in pairs(g.args) do
      if type(v) == "table" and v.type == "group" then
        path[#path + 1] = k
        if k == "rule" .. i then return { unpack(path) } end
        local r = w(v, path, d + 1); if r then return r end
        path[#path] = nil
      end
    end
  end
  return w(t, {}, 0)
end
ns.ToggleUI(); frames(5)
local ctxOK, ctx = pcall(ns.ReadContext)
local function LoadedRule(after)
  for i, r in ipairs(ns.rules) do if i > after and not r.parentUid and not ns.RuleDisabled(r) and ctxOK and ns.IsLoaded(r, ctx) and #ns.CuesOf(r) > 0 then return i end end
end
local CUR
local function OpenRule(i)
  CUR = i
  local p = { "cooldowns", "enabledTab", unpack(PathOf(i)) }
  p[#p + 1] = "display"
  ACD:SelectGroup(APP, unpack(p)); frames(5)
end
local function Toggle()
  return FindW(function(w)
    if w.type ~= "CheckBox" then return false end
    local u = w:GetUserDataTable(); local p = u and u.path
    if type(p) ~= "table" then return false end
    local inRule = false
    for _, k in ipairs(p) do if k == "rule" .. CUR then inRule = true end end
    return inRule and not w.disabled
  end)
end
local L1 = LoadedRule(100)
OpenRule(L1)
-- AceGUI hands back a pooled widget with next(pool) (AceGUI-3.0.lua newWidget): which pooled widget a redraw gets depends on memory
-- addresses, and a reused tree or tab group keeps the size it had (the sidebar's row fit starts from it). For counts that do not
-- move from run to run, the test makes the pick fixed: the widget released last comes back first.
do
  local pools = GUI.objPools
  local stack = {}
  local R0, C0 = GUI.Release, GUI.Create
  GUI.Release = function(self, w, ...)
    local t = type(w) == "table" and w.type
    if t then stack[t] = stack[t] or {}; table.insert(stack[t], w) end
    return R0(self, w, ...)
  end
  GUI.Create = function(self, t, ...)
    local pool, st = pools[t], stack[t]
    if pool and st then
      local pick
      while #st > 0 do local w = table.remove(st, 1); if pool[w] then pick = w; break end end
      if pick then
        pools[t] = { [pick] = true }
        local res = { pcall(C0, self, t, ...) }
        pool[pick] = nil
        pools[t] = pool
        if not res[1] then error(res[2], 0) end
        return unpack(res, 2, table.maxn(res))
      end
    end
    return C0(self, t, ...)
  end
end
local cb = Toggle()
check("rule" .. tostring(L1) .. "'s editor is open on its Display tab with a tick box to click (" .. (cb and table.concat(cb:GetUserDataTable().path, " > ") or "none") .. ")", cb ~= nil)
local function Click()
  treeProbe()
  local w = Toggle()
  enter(P_SET)
  w:Fire("OnValueChanged", not w:GetValue())
  leave()
end

-- the reference: every dropdown text of the tree the window was drawn from, measured again with a font string of its own in the
-- measuring string's font (what Options 0.6.99 did on every scan)
local function MeasuringString()
  local i = upidx(SCAN, "TextW"); local tw = i and select(2, debug.getupvalue(SCAN, i))
  local j = tw and upidx(tw, "mfs"); return j and select(2, debug.getupvalue(tw, j))
end
local ref
local function Reference()
  local mfs = MeasuringString()
  ref = ref or UIParent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  if mfs then local f, h, fl = mfs:GetFont(); ref:SetFont(f, h, fl) end
  local function TW(s)
    local extra = 0
    s = s:gsub("|T.-|t", function() extra = extra + 18; return "" end)
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    ref:SetText(s)
    return (ref:GetStringWidth() or 0) + extra
  end
  local seen, mx, n = {}, 0, 0
  local function walk(g, depth)
    if type(g) ~= "table" or seen[g] or depth > 30 then return end
    seen[g] = true
    if g.type == "select" then
      local vals = g.values
      if type(vals) == "function" then local ok, r = pcall(vals, {}); vals = ok and r or nil end
      if type(vals) == "table" then for _, txt in pairs(vals) do if type(txt) == "string" then n = n + 1; local w = TW(txt) + 40; if w > mx then mx = w end end end end
    end
    if type(g.args) == "table" then for _, v in pairs(g.args) do walk(v, depth + 1) end end
  end
  walk(A.LastTree(), 0)
  return math.min(mx, 520), n
end
local of = ACD.OpenFrames[APP]
local function OneClick()
  collectgarbage("collect")
  reset()
  local t0 = clock(); tstart = t0
  Click()
  local t1 = clock()
  enter(P_ENG); frames(5); leave()
  local s = { click = t1 - t0, after = clock() - t1, rows = CNT.rows }
  for _, n in ipairs(PH.order) do s[n] = { c = PH.calls[n], t = PH.self[n], a = PH.api[n] } end
  return s
end
for k = 1, 2 do OneClick() end   -- warm up (the first scans measure)

------------------------------------------------------------------ A, B: one click, measured
local RUNS = 5
local sums, clickT, afterT, rows = {}, 0, 0, {}
for k = 1, RUNS do
  local s = OneClick()
  clickT, afterT = clickT + s.click, afterT + s.after
  rows[#rows + 1] = s.rows
  for _, n in ipairs(PH.order) do local m = sums[n] or { c = 0, t = 0, a = 0 }; sums[n] = m; m.c = m.c + s[n].c; m.t = m.t + s[n].t; m.a = m.a + s[n].a end
end
local tot, apiTot = 0, 0
for _, n in ipairs(PH.order) do tot = tot + sums[n].t; apiTot = apiTot + sums[n].a end
OUT[#OUT + 1] = ("info  one rule-editor click, 313 rules: %.1f ms in the click + %.1f ms in the 5 frames after (stand-in Lua, mean of %d; not the game's ms)"):format(clickT / RUNS * 1000, afterT / RUNS * 1000, RUNS)
OUT[#OUT + 1] = ("info  %-62s | calls | self ms | share | game calls"):format("phase")
for _, n in ipairs(PH.order) do
  local m = sums[n]
  if m.c > 0 or m.a > 0 then
    OUT[#OUT + 1] = ("info  %-62s | %5.1f | %7.2f | %4.1f%% | %6.0f (%4.1f%%)"):format(n, m.c / RUNS, m.t / RUNS * 1000, m.t / tot * 100, m.a / RUNS, m.a / math.max(1, apiTot) * 100)
  end
end
OUT[#OUT + 1] = ("info  sidebar rows painted per click: %s"):format(table.concat(rows, ", "))
local per = function(n) return sums[n].c / RUNS end
check(("A one click: one redraw (%.0f), one options table build (%.0f), the open rule's editor built once (%.0f)"):format(per("draw: ACD:Open (rest)"), per(P_TREE), per(P_FILL)),
  per("draw: ACD:Open (rest)") == 1 and per(P_TREE) == 1 and per(P_FILL) == 1)
check(("B the minimum-width scan ran on each click (%.0f) and made %.0f game calls per click (Options 0.6.99: 26,102, every dropdown text measured again)"):format(per(P_SCAN), sums[P_SCAN].a / RUNS),
  per(P_SCAN) == 1 and sums[P_SCAN].a / RUNS < 20)

------------------------------------------------------------------ C: the scan's answer = measuring every text again
local r, n = Reference()
check(("C after the clicks the window's minimum width follows the widest dropdown text: %s = a fresh measurement of all %d texts (%s)"):format(tostring(of.xuiDD), n, tostring(r)), of.xuiDD == r and n > 1000)
-- another rule
local L2 = LoadedRule(L1 + 20)
OpenRule(L2)
local s = OneClick()
r = Reference()
check(("C another rule (rule%d): %s = %s"):format(L2, tostring(of.xuiDD), tostring(r)), of.xuiDD == r)
-- a new dropdown text (a group renamed: the rule's Group list shows it)
local long = "A renamed group with a much longer name than any option text in the whole window"
ns.folders[1].name = long
s = OneClick()
r = Reference()
local seenLong = false
do local seen = {}; local function w(g) if type(g) ~= "table" or seen[g] then return end; seen[g] = true
  if g.type == "select" and type(g.values) ~= "function" then for _, t in pairs(g.values or {}) do if t == long then seenLong = true end end end
  if type(g.values) == "function" and g.type == "select" then local ok, v = pcall(g.values, {}); if ok and type(v) == "table" then for _, t in pairs(v) do if t == long then seenLong = true end end end end
  for _, v in pairs(type(g.args) == "table" and g.args or {}) do w(v) end end; w(A.LastTree()) end
check(("C a new dropdown text (a group renamed, in the tree: %s): measured (%d game calls in the scan) and the width follows it: %s = %s"):format(tostring(seenLong), s[P_SCAN].a, tostring(of.xuiDD), tostring(r)),
  seenLong and s[P_SCAN].a > 0 and of.xuiDD == r)
-- the measuring string's font changes: every text is measured again
local mfs = MeasuringString()
check("the measuring string is found (Skin.lua TextW's mfs)", mfs ~= nil)
if mfs then
  mfs:SetFont("Fonts\\ARIALN.TTF", 15, "OUTLINE")
  s = OneClick()
  r = Reference()
  check(("C the measuring font changed: every distinct text measured again (%d game calls in the scan) and %s = %s"):format(s[P_SCAN].a, tostring(of.xuiDD), tostring(r)), s[P_SCAN].a > 1000 and of.xuiDD == r)
  s = OneClick()
  check(("... and the click after it is back to %d game calls"):format(s[P_SCAN].a), s[P_SCAN].a < 20)
end
ns.ToggleUI(); frames(5)
return OUT
end
