-- tests/options_click_cost.lua: driven by tests/options_click_cost_run.py (see there)
return function(W, L)
local OUT = {}
local function check(name, ok) OUT[#OUT + 1] = (ok and "ok    " or "FAIL  ") .. name end
local APP = "CueRules"
local function live() collectgarbage("collect"); return collectgarbage("count") end
-- (test-only) stand-in speedup: memoize world.lua's rectOf (anchor resolution) until any geometry setter runs. Same results, no
-- per-query garbage and no exponential re-walk of anchor chains (the game resolves geometry in C, so this cost is not the addon's).
do
  local proto
  local idx = getmetatable(UIParent).__index
  local i = 1
  while true do local n, v = debug.getupvalue(idx, i); if not n then break end; if n == "proto" then proto = v end; i = i + 1 end
  local orig, screenW, screenH
  i = 1
  while true do local n, v = debug.getupvalue(proto.GetWidth, i); if not n then break end; if n == "rectOf" then orig = v end; i = i + 1 end
  i = 1
  while true do local n, v = debug.getupvalue(orig, i); if not n then break end; if n == "screenW" then screenW = v elseif n == "screenH" then screenH = v end; i = i + 1 end
  local GEN, cache = 0, setmetatable({}, { __mode = "k" })
  local ZERO = { l = 0, b = 0, w = 0, h = 0 }
  local SCREEN = { l = 0, b = 0, w = screenW, h = screenH }
  local R
  R = function(f, depth)
    depth = depth or 0
    if depth > 50 or f == nil then return ZERO end
    if f == UIParent or f._isScreen then return SCREEN end
    local c = cache[f]
    if c and c.g == GEN then return c end
    local left, right, bottom, top, cx, cy
    for _, pt in ipairs(f._pts) do
      local p, rel, rp, ox, oy = pt[1], pt[2], pt[3], pt[4], pt[5]
      if type(rel) == "string" then rel = _G[rel] end
      rel = rel or f._parent or UIParent
      local rr = R(rel, depth + 1)
      rp = rp or p
      local ax = rp:find("RIGHT") and rr.l + rr.w or (rp:find("LEFT") and rr.l or rr.l + rr.w / 2)
      local ay = rp:find("TOP") and rr.b + rr.h or (rp:find("BOTTOM") and rr.b or rr.b + rr.h / 2)
      ax, ay = ax + (ox or 0), ay + (oy or 0)
      if p:find("LEFT") then left = ax elseif p:find("RIGHT") then right = ax else cx = ax end
      if p:find("TOP") then top = ay elseif p:find("BOTTOM") then bottom = ay else cy = ay end
    end
    local w, h = f._w or 0, f._h or 0
    if left and right then w = right - left end
    if bottom and top then h = top - bottom end
    c = c or {}; cache[f] = c
    c.l = left or (right and right - w) or (cx and cx - w / 2) or 0; c.b = bottom or (top and top - h) or (cy and cy - h / 2) or 0
    c.w, c.h, c.g = w, h, GEN
    return c
  end
  local n = 0
  for k, fn in pairs(proto) do
    if type(fn) == "function" then
      local j = 1
      while true do local nm = debug.getupvalue(fn, j); if not nm then break end; if nm == "rectOf" then debug.setupvalue(fn, j, R); n = n + 1 end; j = j + 1 end
    end
  end
  W.rect = R
  for _, k in ipairs({ "SetPoint", "ClearAllPoints", "ClearPoint", "SetAllPoints", "SetSize", "SetWidth", "SetHeight", "SetParent" }) do
    local f0 = proto[k]
    if f0 then proto[k] = function(...) GEN = GEN + 1; return f0(...) end end
  end
  local CF0 = CreateFrame
  CreateFrame = function(...) local f = CF0(...); GEN = GEN + 1; return f end
  local new0 = W.new
  W.new = function(...) local f = new0(...); GEN = GEN + 1; return f end
  PROBE_RECT_PATCHED = n
end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
local N = 313   -- her shape (REQUEST-LOG A15 P-16)
-- rules of several shapes: folders, switched off, load conditions, icon / texture / sound cues (one icon cue with a texture source,
-- which the editor build corrects), conditions (outcomes), outlines missing their defaults, an unnamed rule
local function MakeRules(N)
  ns.rules = {}; ns.folders = {}
  local f1 = ns.NewFolder("Group 1"); local f2 = ns.NewFolder("Group 2"); local f3 = ns.NewFolder("Inner", f1.id)
  local fl = { f1.id, f2.id, f3.id, nil }
  for i = 1, N do
    local r = ns.NewRule()
    r.name = (i == 7) and "" or ("Rule " .. i); r.folder = fl[i % 4 + 1]; r.enabled = (i % 10 ~= 0); r.uid = ns.NewUID()
    r.useCd = true; r.spellID = 203720; r.cdState = "ready"
    if i % 5 == 0 then r.load = { combat = "yes" } end
    if i % 7 == 0 then r.visual.outline = { enabled = true } end
    ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
    if i % 9 == 0 then
      ns.NewCueRule(r, "icon"); ns.NewCueRule(r, "sound")
      local c = ns.NewCueRule(r, "texture")
      if i % 18 == 0 then local ic = ns.NewCueRule(r, "icon"); ic.visual.kind = "texture" end
    end
    if i % 11 == 0 then
      local n = ns.NewRule(); n.name = "Condition"; n.parentUid = r.uid; n.folder = r.folder
      n.when = { list = { { neg = false, op = "and", cmp = "==", num = 0 } } }
      ns.NormalizeRule(n); ns.rules[#ns.rules + 1] = n
    end
  end
  CueRulesDB.rules = ns.rules; CueRulesDB.folders = ns.folders
end
MakeRules(72)   -- the parity checks (1-3) compare every option of every rule: a smaller set with every shape
pcall(ns.RefreshAllVisuals); W.tick(0.1, 10)
pcall(ns.LoadOptions); W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
local reg, ACD = LibStub("AceConfigRegistry-3.0"), LibStub("AceConfigDialog-3.0")
local function frames(n) for i = 1, n do W.tick(1 / 60, 1) end end
local A = ns.OptionsApi or {}
check("Options 0.6.69 present: row-only rules (ns.OptionsApi.RuleStub / FillRule)", type(A.RuleStub) == "function" and type(A.FillRule) == "function")

-- deterministic dump of a value (sorted keys; functions as "fn"; shared tables by first path); `call` = also the result of name / hidden
local function Dump(v, call)
  local out, seen = {}, {}
  local function key(k) return type(k) .. ":" .. tostring(k) end
  local function d(x, path, depth)
    local t = type(x)
    if t == "function" then
      if call then local ok, r = pcall(x, {}); out[#out + 1] = path .. "=fn->" .. (ok and tostring(r) or "err") else out[#out + 1] = path .. "=fn" end
      return
    end
    if t ~= "table" then out[#out + 1] = path .. "=" .. t .. ":" .. tostring(x); return end
    if seen[x] then out[#out + 1] = path .. "=@" .. seen[x]; return end
    seen[x] = path
    if depth > 40 then out[#out + 1] = path .. "=deep"; return end
    local ks = {}
    for k in pairs(x) do ks[#ks + 1] = k end
    table.sort(ks, function(a, b) return key(a) < key(b) end)
    for _, k in ipairs(ks) do
      local sub = path .. "." .. key(k)
      local val = x[k]
      if call and type(val) == "function" and (k == "name" or k == "hidden") then d(val, sub, depth + 1)
      else d(val, sub, depth + 1) end
      if type(val) == "function" and not (call and (k == "name" or k == "hidden")) then out[#out] = sub .. "=fn" end
    end
  end
  d(v, "", 0)
  return out
end
local function Same(a, b)
  if #a ~= #b then
    for i = 1, math.max(#a, #b) do if a[i] ~= b[i] then return false, ("%d vs %d lines; first difference: %s | %s"):format(#a, #b, tostring(a[i]), tostring(b[i])) end end
  end
  for i = 1, #a do if a[i] ~= b[i] then return false, "line " .. i .. ": " .. tostring(a[i]) .. " | " .. tostring(b[i]) end end
  return true, #a .. " lines"
end
local function Copy(t, seen)
  if type(t) ~= "table" then return t end
  seen = seen or {}
  if seen[t] then return seen[t] end
  local c = {}; seen[t] = c
  for k, v in pairs(t) do c[Copy(k, seen)] = Copy(v, seen) end
  return setmetatable(c, getmetatable(t))
end

------------------------------------------------------------------ 1. the saved data after a window build = after a full build
do
  local before = Copy(ns.rules)
  local folders0 = Copy(ns.folders)
  local lazyTree = reg:GetOptionsTable(APP)("dialog", "AceConfigDialog-3.0")   -- the window's build (Tree.Get)
  local stubs = 0
  local function count(g, seen) if type(g) ~= "table" or seen[g] then return end; seen[g] = true; if g.xuiStub then stubs = stubs + 1 end; if type(g.args) == "table" then for _, v in pairs(g.args) do count(v, seen) end end end
  count(lazyTree, {})
  check("the window's build has row-only rules (" .. stubs .. ")", stubs > 0)
  local afterLazy = Dump(ns.rules)
  ns.rules = Copy(before); ns.folders = Copy(folders0); CueRulesDB.rules = ns.rules; CueRulesDB.folders = ns.folders
  local full = ns.BuildOptionsTable()
  local fstubs = 0
  count = function(g, seen) if type(g) ~= "table" or seen[g] then return end; seen[g] = true; if g.xuiStub then fstubs = fstubs + 1 end; if type(g.args) == "table" then for _, v in pairs(g.args) do count(v, seen) end end end
  count(full, {})
  check("a direct ns.BuildOptionsTable() (tests, other files) is the full tree: no row-only rule", fstubs == 0)
  local ok, why = Same(afterLazy, Dump(ns.rules))
  check("parity: every rule's saved data is the same after the window's build as after a full build (" .. why .. ")", ok)
  local iconFixed = true
  for _, r in ipairs(ns.rules) do if r.isCue and r.cueKind == "icon" and r.visual.kind ~= "spellicon" then iconFixed = false end end
  check("the icon cue with a texture source is corrected by both builds", iconFixed)
end

------------------------------------------------------------------ 2. every rule's editor filled in = the full build's tree
do
  local full = ns.BuildOptionsTable()
  local lazyTree = reg:GetOptionsTable(APP)("dialog", "AceConfigDialog-3.0")
  local filled, seen = 0, {}
  local function fill(g) if type(g) ~= "table" or seen[g] then return end; seen[g] = true; if g.xuiStub and A.FillRule then A.FillRule(g); filled = filled + 1 end; if type(g.args) == "table" then for _, v in pairs(g.args) do fill(v) end end end
  fill(lazyTree)
  check("filled every row-only rule (" .. filled .. ")", filled > 0)
  local full2 = ns.BuildOptionsTable()
  -- the Rules tab (every rule list) is what the window builds differently; other tabs (module pages) are compared by the open-cost test
  local function R(t) return t.args.cooldowns end
  local okC, whyC = Same(Dump(R(full)), Dump(R(full2)))
  check("control: two full builds dump the same Rules tab (" .. whyC .. ")", okC)
  local ok, why = Same(Dump(R(full)), Dump(R(lazyTree)))
  check("parity: the window's tree with every editor filled in is the full build's tree (every option, every value; functions by place; " .. why .. ")", ok)
  local function V(t) local okV, err = pcall(reg.ValidateOptionsTable, reg, R(t), APP); return okV and "ok" or tostring(err):gsub("^.-ValidateOptionsTable%(%)", "") end
  local rowsSame, rows = true, 0
  local function rowsOf(t) local m, seen = {}, {}; local function w(g) if type(g) ~= "table" or seen[g] then return end; seen[g] = true
    for k, v in pairs(type(g.args) == "table" and g.args or {}) do if type(v) == "table" then if tostring(k):match("^rule%d+$") then m[k] = v end; w(v) end end end
    w(t); return m end
  local rf, rl = rowsOf(R(full)), rowsOf(R(lazyTree))
  for k, g in pairs(rf) do
    rows = rows + 1
    local h = rl[k]
    if not h or g.name() ~= h.name() or (g.hidden() and true or false) ~= (h.hidden() and true or false) or g.order ~= h.order then rowsSame = false end
  end
  ns.treeFilter = "rule 1"
  for k, g in pairs(rf) do if (g.hidden() and true or false) ~= (rl[k].hidden() and true or false) then rowsSame = false end end
  ns.treeFilter = nil
  check("parity: every rule row's name, order and search-hidden answer are the same (" .. rows .. " rows)", rowsSame and rows > 0)
  local vf, vl = V(full), V(lazyTree)
  check("AceConfigRegistry's validation of the Rules tab: the same answer for the filled tree as for the full build (" .. vl .. ")", vf == vl)
end

------------------------------------------------------------------ 2b. the info-icon pass (Options 0.6.69 skips the sort where nothing moves) = Options 0.6.68's
do
  -- Options 0.6.68's ns.InfoPass, verbatim (the reference)
  local function OldInfoPass(root)
    local seen = {}
    local function ord(a) return tonumber(a and a.order) or 100 end
    local function walk(g)
      if type(g) ~= "table" or seen[g] then return end
      seen[g] = true
      if g.type ~= "group" or type(g.args) ~= "table" then return end
      local keys = {}
      for k, v in pairs(g.args) do if type(v) == "table" then keys[#keys + 1] = k end end
      table.sort(keys, function(a, b)
        local oa, ob = ord(g.args[a]), ord(g.args[b])
        if oa ~= ob then return oa < ob end
        return tostring(a) < tostring(b)
      end)
      local lastHeader
      for _, k in ipairs(keys) do
        local v = g.args[k]
        if v.type == "header" and type(v.name) == "string" and v.name ~= "" then
          lastHeader = v
        elseif v.type == "description" and type(v.name) == "string" and #v.name >= 50 and v.hidden == nil
          and not (type(v.arg) == "table" and v.arg.xuiKeep) then
          local owner = lastHeader or ((g.inline and type(g.name) == "string" and g.name ~= "") and g or nil)
          if owner then
            owner.xuiInfo = owner.xuiInfo and (owner.xuiInfo .. "\n\n" .. v.name) or v.name
            g.args[k] = nil
          end
        elseif v.type == "group" then
          lastHeader = nil
        end
      end
      for _, v in pairs(g.args) do if type(v) == "table" and v.type == "group" then walk(v) end end
    end
    walk(root)
  end
  check("the skin is on in this test (the info-icon pass runs)", ns.SkinRows and ns.SkinRows() and true or false)
  local newT = ns.BuildOptionsTable()
  local newPass = ns.InfoPass
  ns.InfoPass = OldInfoPass
  local oldT = ns.BuildOptionsTable()
  ns.InfoPass = newPass
  local infos = 0
  local function cnt(g, seen) if type(g) ~= "table" or seen[g] then return end; seen[g] = true; if g.xuiInfo then infos = infos + 1 end; for _, v in pairs(type(g.args) == "table" and g.args or {}) do cnt(v, seen) end end
  cnt(newT, {})
  local ok, why = Same(Dump(oldT.args.cooldowns), Dump(newT.args.cooldowns))
  check("parity: the info icons (" .. infos .. " in the whole tree) and the rows left are the same as Options 0.6.68's pass (Rules tab, " .. why .. ")", ok and infos > 0)
  local ok2, why2 = Same(Dump(oldT.args.set or {}), Dump(newT.args.set or {}))
  check("... and on the Settings pages (" .. why2 .. ")", ok2)
end

------------------------------------------------------------------ 3. the cue lookup used during a build = ns.CuesOf
do
  local orig = ns.CuesOf
  local plain = {}
  for i, r in ipairs(ns.rules) do local l = orig(r); local ids = {}; for _, c in ipairs(l) do ids[#ids + 1] = tostring(c.uid) end; plain[i] = table.concat(ids, ",") end
  local same, n, copies = true, 0, true
  local WCM = A.WithCueMemo or function(fn) return fn() end
  WCM(function()
    for i, r in ipairs(ns.rules) do
      local l = ns.CuesOf(r); local ids = {}
      for _, c in ipairs(l) do ids[#ids + 1] = tostring(c.uid) end
      if table.concat(ids, ",") ~= plain[i] then same = false end
      if #l > 0 then n = n + 1; if ns.CuesOf(r) == l then copies = false end end
    end
  end)
  check("parity: during a build every rule's cue list is ns.CuesOf's, in order (" .. n .. " rules with cues)", same and n > 0)
  check("each call gets its own copy", copies)
  check("ns.CuesOf is put back after the build", ns.CuesOf == orig)
  pcall(WCM, function() error("x") end)
  check("... and after an error in it", ns.CuesOf == orig and not A.cueMemoOn)
end

------------------------------------------------------------------ 4. the window: open, a rule on screen, clicks (her shape: 313 rules)
MakeRules(N); pcall(ns.RefreshAllVisuals); W.tick(0.1, 5)
local builds, fills = 0, 0
local realBuild = ns.BuildOptionsTable
ns.BuildOptionsTable = function(...) builds = builds + 1; return realBuild(...) end
local realFill = A.FillRule
if realFill then A.FillRule = function(...) local r = realFill(...); if r then fills = fills + 1 end; return r end end
local function shown() local of = ACD.OpenFrames and ACD.OpenFrames[APP]; return of and of.frame and of.frame:IsShown() and true or false end
local function FindW(pred, w, d)
  w = w or (ACD.OpenFrames and ACD.OpenFrames[APP]); d = d or 0
  if not w or d > 30 then return nil end
  if pred(w) then return w end
  for _, c in ipairs(w.children or {}) do local r = FindW(pred, c, d + 1); if r then return r end end
end
local function RulePane(i)   -- a widget drawn from rule i's editor (its user data path ends at "rule<i>" or below it)
  return FindW(function(w)
    local u = w.GetUserDataTable and w:GetUserDataTable()
    local p = u and u.path
    if type(p) ~= "table" then return false end
    for _, k in ipairs(p) do if k == "rule" .. i then return true end end
    return false
  end)
end
local function garbage(fn) collectgarbage("collect"); collectgarbage("stop"); local m = collectgarbage("count"); fn(); local d = collectgarbage("count") - m; collectgarbage("restart"); return d end
local function loadedKey()   -- a rule listed under LOADED (rule 1 may not be)
  local ctxOK, ctx = pcall(ns.ReadContext)
  for i, r in ipairs(ns.rules) do if not r.parentUid and not ns.RuleDisabled(r) and ctxOK and ns.IsLoaded(r, ctx) and r.uid and #ns.CuesOf(r) > 0 then return i end end
end
local function PathOf(i)   -- the path of rule i under the Enabled sub-tab (LOADED > its group > rule<i>)
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
local L1 = loadedKey()
check("a loaded rule with cues to show: rule" .. tostring(L1), L1 ~= nil)
ns.ToggleUI(); frames(5)
check("the window shows", shown())
builds, fills = 0, 0
local P1 = PathOf(L1)
check("its path: " .. table.concat(P1 or {}, " > "), P1 ~= nil)
ACD:SelectGroup(APP, "cooldowns", "enabledTab", unpack(P1)); frames(5)
check("a rule picked (SelectGroup): its editor is on screen", RulePane(L1) ~= nil)
check("... and only that editor was built (" .. fills .. " filled; builds " .. builds .. ")", fills <= 1)
local g1 = garbage(function()
  builds, fills = 0, 0
  reg:NotifyChange(APP); ACD:Open(APP); frames(1)
end)
do   -- time, for the record only (not checked: the stand-in's speed is not the game's)
  local t = {}
  for k = 1, 5 do collectgarbage("collect"); local t0 = os.clock(); reg:NotifyChange(APP); ACD:Open(APP); frames(1); t[k] = os.clock() - t0 end
  table.sort(t)
  OUT[#OUT + 1] = ("info  a click with a rule on screen, 313 rules: median %.0f ms of Lua in the stand-in (5 clicks, %.0f-%.0f)"):format(t[3] * 1000, t[1] * 1000, t[5] * 1000)
  builds, fills = 1, 1
end
check(("a click with a rule on screen: ONE build and the one editor (builds %d, editors filled %d)"):format(builds, fills), builds == 1 and fills == 1)
check(("a click with a rule on screen: %.1f MB of garbage (Options 0.6.68: ~165 MB with 313 rules)"):format(g1 / 1024), g1 < 30 * 1024)
check("after the click the same rule's editor is on screen", RulePane(L1) ~= nil)
-- the editor's Cues tab, by a SelectGroup path into the rule (the rule search's results do this)
local P1c = { "cooldowns", "enabledTab", unpack(P1) }
P1c[#P1c + 1] = "cues"
ACD:SelectGroup(APP, unpack(P1c)); frames(5)
P1c[#P1c] = nil
local stc = ACD:GetStatusTable(APP, P1c)
check("a SelectGroup path into a rule's tab selects that tab", stc and stc.groups and stc.groups.selected == "cues")
-- picking another rule in the sidebar (the tree's own click: OnGroupSelected -> FeedGroup)
local tree = FindW(function(w) return w.type == "TreeGroup" end)
local L2
do local ctxOK, ctx = pcall(ns.ReadContext); for i, r in ipairs(ns.rules) do if i ~= L1 and not r.parentUid and not ns.RuleDisabled(r) and ctxOK and ns.IsLoaded(r, ctx) then L2 = i; break end end end
fills, builds = 0, 0
tree:SelectByValue(table.concat(PathOf(L2), "\001")); frames(2)
check(("a click on another rule's row: its editor is drawn, one editor per draw (drawn by the click + %d redraw(s), editors built %d)"):format(builds, fills), RulePane(L2) ~= nil and fills >= 1 and fills <= builds + 1)
check("... and the first rule's editor is gone", RulePane(L1) == nil)

------------------------------------------------------------------ 5. rename / delete / move, then a redraw: no stale row
local function rowTexts()
  local t = FindW(function(w) return w.type == "TreeGroup" end)
  local out = {}
  for _, b in ipairs(t and t.buttons or {}) do if b:IsShown() and b.text then out[#out + 1] = tostring(b.text:GetText() or "") end end
  return table.concat(out, "|")
end
local function lines(st) local n = 0; for _ in st:gmatch("[^|]+") do n = n + 1 end; return n end
local rr = ns.rules[L2]
rr.name = "Renamed rule"; reg:NotifyChange(APP); frames(2)
check("rename the rule on screen: its row shows the new name", rowTexts():find("Renamed rule", 1, true) ~= nil)
check("... and its editor is still on screen", RulePane(L2) ~= nil)
local other = ns.rules[L1]
other.name = "Also renamed"; reg:NotifyChange(APP); frames(2)
check("rename a rule NOT on screen (row-only): its row shows the new name", rowTexts():find("Also renamed", 1, true) ~= nil)
local n0 = lines(rowTexts())
for i, r in ipairs(ns.rules) do if r == other then table.remove(ns.rules, i); break end end
ns.MarkStateDirty(); reg:NotifyChange(APP); frames(2)
check("delete a rule: its row is gone (rows " .. n0 .. " -> " .. lines(rowTexts()) .. ")", rowTexts():find("Also renamed", 1, true) == nil)
-- after the delete every index after it moved down by one: the editor on screen is for the rule now at that index (or none)
local cur = ACD:GetStatusTable(APP, { "cooldowns", "enabledTab" })
local sel = cur and cur.groups and cur.groups.selected
local si = sel and tonumber(tostring(sel):match("rule(%d+)$"))
local paneOK = true
if si then
  local pane = RulePane(si)
  paneOK = pane ~= nil
end
check("after a delete the editor drawn matches the selected row (" .. tostring(sel) .. ")", paneOK)
local before = rowTexts()
rr.folder = nil; ns.MarkStateDirty(); reg:NotifyChange(APP); frames(2)
check("move the rule on screen to another group: redrawn without an error", #W.errors == 0)

------------------------------------------------------------------ 6. close: nothing kept
ns.ToggleUI(); frames(5)
check("closed", not shown())
ns.BuildOptionsTable = realBuild; A.FillRule = realFill
return OUT
end
