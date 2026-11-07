-- tests/options_open_cost.lua: driven by tests/options_open_cost_run.py (see there)
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
local g1 = ns.NewFolder("Group 1")
for i = 1, 40 do
  local r = ns.NewRule()
  r.name = "Rule " .. i; r.folder = g1.id; r.enabled = (i <= 30); r.uid = ns.NewUID()
  r.useCd = true; r.spellID = 203720; r.cdState = "ready"
  if i % 5 == 0 then r.load = { combat = "yes" } end
  ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
end
CueRulesDB.rules = ns.rules
pcall(ns.RefreshAllVisuals); W.tick(0.1, 10)
pcall(ns.LoadOptions); W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
local reg, ACD = LibStub("AceConfigRegistry-3.0"), LibStub("AceConfigDialog-3.0")
local builds, decorates = 0, 0
local realBuild = ns.BuildOptionsTable
ns.BuildOptionsTable = function(...) builds = builds + 1; return realBuild(...) end
local realDec = ns.DecorateTrees
ns.DecorateTrees = function(...) decorates = decorates + 1; return realDec(...) end
local function frames(n) for i = 1, n do W.tick(1 / 60, 1) end end
local function shown() local of = ACD.OpenFrames and ACD.OpenFrames[APP]; return of and of.frame and of.frame:IsShown() and true or false end

local before = live()
builds = 0; ns.ToggleUI(); frames(5)
check("first open: the window shows", shown())
check("first open: ONE full build (Options 0.6.65: 3 in game, 4 in the stand-in): " .. builds, builds == 1)
check("first open: the Rules sub-tab is selected", (function() local st = ACD:GetStatusTable(APP); return st and st.groups and st.groups.selected == "cooldowns" end)())
check("ns.PickerInto is not kept after a build (it held the whole tree)", ns.PickerInto == nil)
builds = 0; reg:NotifyChange(APP); ACD:Open(APP); frames(5)
check("a click (a set asks for a redraw, then AceConfigDialog redraws at once): ONE build (Options 0.6.65: 2): " .. builds, builds == 1)
builds = 0; reg:NotifyChange(APP); frames(5)
check("a redraw asked for with no Open after it still happens (one build)", builds == 1)
frames(30); decorates = 0; builds = 0; frames(300)
local firstIdle = decorates
decorates = 0; frames(300)
check("window open, idle (the second 5 s): no decorate / skin pass (Options 0.6.65: every 0.25 s = 20): " .. decorates .. " (first 5 s: " .. firstIdle .. ")", decorates == 0)
check("window open, idle 5 s: no build", builds == 0)
local of = ACD.OpenFrames[APP]
local AceGUI = LibStub("AceGUI-3.0")
decorates = 0; local w = AceGUI:Create("Label"); frames(20)
check("a new widget made while open: decorated on the next pass (once)", decorates == 1)
AceGUI:Release(w)
-- combat: rules that load only in combat move between LOADED and NOT LOADED; the lists are not rebuilt during or after the fight
builds = 0
W.combat = true; W.fire("PLAYER_REGEN_DISABLED"); frames(180)
check("combat start with the window open: no rebuild during the fight (Options 0.6.65: one full build): " .. builds, builds == 0)
W.combat = false; W.fire("PLAYER_REGEN_ENABLED"); frames(180)
check("combat end, the same rules loaded as before: no rebuild (Options 0.6.65: another full build): " .. builds, builds == 0)
-- a lasting change out of combat still moves a rule
ns.rules[2].load = { mode = "never" }; if ns.MarkStateDirty then ns.MarkStateDirty() end; frames(120)
check("a rule that stops loading out of combat: the lists are redrawn (one build)", builds >= 1)
ns.ToggleUI(); frames(5)
check("closed", not shown())
local after = live()
check(("after close + full collect: %.0f KB more than before the open (Options 0.6.65 kept the whole tree)"):format(after - before), after - before < 3000)
return OUT
end
