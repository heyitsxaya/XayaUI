#!/usr/bin/env python3
"""The closed settings window does no work (REQUEST-LOG A23 SD-12 / SD-13; Xaya: "Yes, in bundle 1").
Hooks cannot be taken off in WoW until /reload, so every lasting hook or listener that the settings window (XayaUI_Options/*.lua) or
the rule editor (XayaUI_Rules/Editor/*.lua) leaves behind must return at once while the window is closed (a hook on one of AceGUI's
shared, pooled widgets: unless that widget is in XayaUI's window right now).
The player opens the window with 300 rules and uses the editor: selects rules (click, Ctrl+click, right-click), types in the rule
search and in a spell search box, drags a group's slider, changes the theme. She closes the window. Then, with the window closed,
the game runs a fight: UNIT_AURA and SPELL_UPDATE_COOLDOWN storms, mouse clicks, gear tooltips (the game's compare tooltips), another
addon's AceConfig window built and used (rows clicked, right- and double-clicked, hovered, its list resized, a text box typed in, a
slider, a dropdown), a theme change, edits from the on-screen mover (a moved display), debug log lines.
Measured with debug.sethook ("call" and "line" events): every function defined in XayaUI_Options/*.lua or XayaUI_Rules/Editor/*.lua
that runs in that time may run only its first line (and its closing "end"), and that line must be its return check (it starts with
"if" or "return"). A function of those files it calls is held to the same rule (a wrapper passing a call on to the next wrapper), except
the pooled-widget ownership check (TreePaint.lua TP.Ours: it only reads a field of the widget).
Libs/ (Ace3) is not counted. Also: core's text-box guard (XayaUI/KeyCatch.lua) listens for mouse clicks (GLOBAL_MOUSE_DOWN) only
while one of its boxes has the keyboard.
The stand-in's SetFocus / ClearFocus run OnEditFocusGained / OnEditFocusLost as the game does (tests/harness/world.lua; warcraft.wiki.gg
UIHANDLER OnEditFocusGained: "Fires when the frame gains keyboard focus"; INFERENCE: SetFocus counts).
Checks marked "(control)" or "(as before)" pass on the old code too; the others fail on the working tree before this change.
Run: python3 tests/fix_r2_closed_window_quiet_run.py   (Lua 5.1 via lupa; opens the settings window with 300 rules: about a minute)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

ROOT = os.path.dirname(HERE)

LUA = r'''
return function(W, L, SRC)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local okAll, errAll = pcall(function()

do   -- AceGUI's tree rows are 18 px high (as in tests/sidebar_delete_run.py)
  local init = W.templateInit.OptionsListButtonTemplate
  W.templateInit.OptionsListButtonTemplate = function(f) init(f); f._h = 18 end
end
-- the game's gear comparison (it must exist before the rule editor is set up: SpellSearch.lua hooks it then)
for _, n in ipairs({ "ShoppingTooltip1", "ShoppingTooltip2" }) do if not _G[n] then _G[n] = CreateFrame("GameTooltip", n, UIParent) end end
GameTooltip_ShowCompareItem = function() ShoppingTooltip1:Show(); ShoppingTooltip2:Show() end

L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
check("(control) the settings window and the rule editor are loaded", ns and ns.BuildOptionsTable ~= nil and ns.UI ~= nil)
if not (ns and ns.BuildOptionsTable) then return end
ns.Print = function() end
MenuUtil.CreateContextMenu = function() end
CueRulesDB.ui = CueRulesDB.ui or {}; CueRulesDB.ui.consoleAutoOpen = false
local ACD, reg, APP = LibStub("AceConfigDialog-3.0"), LibStub("AceConfigRegistry-3.0"), "CueRules"
local function settle() W.tick(0.05, 6) end
local function findW(w, pred)
  if type(w) ~= "table" then return nil end
  if pred(w) then return w end
  for _, c in ipairs(w.children or {}) do local f = findW(c, pred); if f then return f end end
end
local function rowIn(t, key)
  for _, b in ipairs(t and t.buttons or {}) do
    if b:IsShown() and (tostring(b.uniquevalue or ""):match("([^\001]+)$") or "") == key then return b end
  end
end
local function typeIn(box, text)
  box:SetFocus(); box:SetText(text)
  local f = box:GetScript("OnTextChanged"); if f then f(box, true) end
  W.tick(0.1, 4)
end

-- 300 rules: 299 in a group (Defensives), one with a Spell Known trigger (its page has a spell search box)
ns.folders = { { id = "f1", name = "Defensives" } }
CueRulesDB.folders = ns.folders
ns.rules = {}
for i = 1, 300 do
  local r = ns.NewRule(); r.name = "Rule " .. i; r.enabled = true; r.useBuff = true; r.buffID = 1000 + i; r.buffState = "present"
  r.spellID = 2000 + i; r.visual.enabled = (i % 3 == 0); if i > 1 then r.folder = "f1" end
  ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
end
local A = ns.rules[1]
A.extra = { list = { { type = "spellKnown", spellID = 0, state = true } } }
CueRulesDB.rules = ns.rules
if ns.MarkDirty then ns.MarkDirty() end
W.tick(0.1, 4)

-------------------------------------------------------------------------------------------------------------------------------------
-- the player uses the window
-------------------------------------------------------------------------------------------------------------------------------------
pcall(ns.ToggleUI); settle()
check("(control) the settings window is open", ACD.OpenFrames[APP] ~= nil)
ACD:SelectGroup(APP, "cooldowns", "enabledTab", "loaded"); settle()
local S = ns.RulesTreeStatus(); S.groups["loaded\001f1"] = true; reg:NotifyChange(APP); settle()
local xt = findW(ACD.OpenFrames[APP], function(w) return w.type == "TreeGroup" and w.status == ns.RulesTreeStatus() end)
local used = 0
for _, key in ipairs({ "rule2", "rule3" }) do
  local row = rowIn(xt, key)
  if row then
    row:Click("LeftButton"); settle(); used = used + 1
    IsControlKeyDown = function() return true end; row:Click("LeftButton"); IsControlKeyDown = function() return false end; settle()
    local e = row:GetScript("OnEnter"); if e then e(row) end
    local l = row:GetScript("OnLeave"); if l then l(row) end
  end
end
check("(control) she selects rules in the Rules list (click, Ctrl+click, hover)", used == 2 and ns.MultiCount and ns.MultiCount() >= 1, used)
if ns.MultiClear then pcall(ns.MultiClear) end; settle()
-- the rule search at the top of the list
xt = findW(ACD.OpenFrames[APP], function(w) return w.type == "TreeGroup" and w.status == ns.RulesTreeStatus() end)
local sb = xt and xt.xuiSearchBox
if sb then typeIn(sb, "rule 1"); W.tick(0.1, 6) end
check("(control) she types in the rule search (the lists filter)", sb ~= nil and ns.treeFilter == "rule 1", ns.treeFilter)
local mouseOn = W.registeredEvents().GLOBAL_MOUSE_DOWN
if sb then local esc = sb:GetScript("OnEscapePressed"); if esc then esc(sb) end; W.tick(0.1, 6) end
check("(control) a text box with the keyboard: core's guard listens for a click outside", mouseOn == true)
-- a spell search box (the rule's Trigger tab)
local path = { ns.OptionsApi.RuleEditorParts.RulePath(A) }; path[#path + 1] = "trigger"
ACD:SelectGroup(APP, unpack(path)); settle()
pcall(ns.DecorateTrees); settle()
local sw = findW(ACD.OpenFrames[APP], function(w)
  local o = w.type == "EditBox" and w.userdata and w.userdata.option
  return o and type(o.arg) == "table" and o.arg.xuiSearch ~= nil
end)
if sw then typeIn(sw.editbox, "rule"); W.tick(0.1, 4) end
local pop = rawget(_G, "XayaUISpellSearch")
check("(control) she types in a spell search box (its popup opens)", pop ~= nil and pop:IsShown())
if pop and pop.rows and pop.rows[1] then
  local e = pop.rows[1]:GetScript("OnEnter"); if e then e(pop.rows[1]) end
  GameTooltip_ShowCompareItem(GameTooltip)
  local l = pop.rows[1]:GetScript("OnLeave"); if l then l(pop.rows[1]) end
end
if sw then
  W.fire("GLOBAL_MOUSE_DOWN", "LeftButton")   -- she clicks elsewhere: the box lets go
  W.tick(0.3, 3)
end
check("(control) a click outside the box takes the keyboard back from it", not (sw and sw.editbox:HasFocus()))
-- a group's slider, dragged
ACD:SelectGroup(APP, "cooldowns", "enabledTab", "loaded", "f1"); settle()
local slider = findW(ACD.OpenFrames[APP], function(w) return w.type == "Slider" and w.frame and w.frame:IsVisible() end)
if slider then for step = 1, 8 do slider:Fire("OnValueChanged", step * 4); W.tick(1 / 60, 1) end; slider:Fire("OnMouseUp", 32); settle() end
check("(control) she drags a slider on the group's page", slider ~= nil)
-- a theme change with the window open
local TH = ns.Theme
local base0 = CueRulesDB.theme and CueRulesDB.theme.base or "default"
if TH and TH.SetBase then pcall(TH.SetBase, base0 == "default" and "class" or "default"); settle() end
-- she closes the window
local xf = ACD.OpenFrames[APP] and ACD.OpenFrames[APP].frame   -- (AceGUI's frame the window was in: shared with every addon)
local xt0 = xt
pcall(ns.ToggleUI); W.tick(0.1, 40)   -- (4 s: every short timer the window started has run)
check("(control) the window is closed", ACD.OpenFrames[APP] == nil)
check("no text box has the keyboard: core's guard does not listen for mouse clicks (GLOBAL_MOUSE_DOWN)",
  not W.registeredEvents().GLOBAL_MOUSE_DOWN)

-- another addon's AceConfig options (registered now; opened in the fight)
local typed = {}
local function grp(name, extra)
  local g = { type = "group", name = name, args = { note = { type = "description", name = name, order = 1 } } }
  if extra then
    g.args.box = { type = "input", name = "Name", order = 2, get = function() return typed.box end, set = function(_, v) typed.box = v end }
    g.args.size = { type = "range", name = "Size", min = 1, max = 100, step = 1, order = 3, get = function() return typed.size or 10 end, set = function(_, v) typed.size = v end }
    g.args.pick = { type = "select", name = "Pick", values = { a = "A", b = "B" }, order = 4, get = function() return typed.pick or "a" end, set = function(_, v) typed.pick = v end }
    g.args.on = { type = "toggle", name = "On", order = 5, get = function() return typed.on end, set = function(_, v) typed.on = v end }
    g.args.head = { type = "header", name = "Heading", order = 6 }
    g.args.go = { type = "execute", name = "Go", order = 7, func = function() typed.go = (typed.go or 0) + 1 end }
  end
  return g
end
LibStub("AceConfig-3.0"):RegisterOptionsTable("OtherAddon", { type = "group", name = "Other", childGroups = "tree", args = {
  all = grp("All things", true), rule1 = grp("First rule", true), f1 = grp("First folder"), loaded = grp("Loaded"), other = grp("Other", true),
} })

-- the window's old frame: does XayaUI still touch its keyboard? (core KeyCatch.lua; the frame is the next addon's now)
local kbTouch = 0
if xf then
  rawset(xf, "SetPropagateKeyboardInput", function() kbTouch = kbTouch + 1 end)
  rawset(xf, "EnableKeyboard", function() kbTouch = kbTouch + 1 end)
end

-------------------------------------------------------------------------------------------------------------------------------------
-- the meter: every call and every line run in XayaUI_Options/*.lua or XayaUI_Rules/Editor/*.lua (not Libs/)
-------------------------------------------------------------------------------------------------------------------------------------
local mineCache = {}
local function mine(src)
  local v = mineCache[src]
  if v ~= nil then return v end
  v = src:match("^@Interface/AddOns/(XayaUI_Options/[%w_]+%.lua)$") or src:match("^@Interface/AddOns/(XayaUI_Rules/Editor/[%w_]+%.lua)$") or false
  mineCache[src] = v
  return v
end
local getinfo = debug.getinfo
local fn = {}   -- "file:linedefined" -> { file, ld, lastld, calls, lines = { [line] = n }, nested = n, from }
local function rec(file, info)
  local k = file .. ":" .. info.linedefined
  local s = fn[k]
  if not s then s = { file = file, ld = info.linedefined, last = info.lastlinedefined, calls = 0, lines = {}, nested = 0 }; fn[k] = s end
  return s
end
local function hook(ev, line)
  local info = getinfo(2, "S")
  local file = info and mine(info.source)
  if not file then return end
  local s = rec(file, info)
  if ev == "line" then s.lines[line] = (s.lines[line] or 0) + 1; return end
  s.calls = s.calls + 1
  for lv = 3, 60 do   -- called from one of these files (the nearest Lua caller up the stack)?
    local up = getinfo(lv, "S")
    if not up then break end
    local uf = up.what ~= "C" and mine(up.source)
    if uf then s.nested = s.nested + 1; s.from = s.from or (uf .. ":" .. tostring(up.linedefined)); break end
    if up.what ~= "C" and up.what ~= "tail" then break end
  end
end

-- the source text of a line, and the code after the function's own header when the function starts on that line
local function lineText(file, n) local t = SRC[file]; return t and t[n] or "" end
local function bodyOf(s, n)
  local t = lineText(s.file, n)
  if n == s.ld then
    local _, e = t:find("function%s*[%w_.:]*%s*%b()")
    if e then t = t:sub(e + 1) end
  end
  return (t:gsub("^%s+", ""))
end
local CHECKS = { ["XayaUI_Options/TreePaint.lua"] = { ["function TP.Ours(w)"] = true } }   -- the ownership check (reads one field)
local function isCheck(s) local c = CHECKS[s.file]; return c and c[(lineText(s.file, s.ld):gsub("^%s+", ""):gsub("%s+$", ""))] or false end

local function phase(name, run)
  fn = {}
  debug.sethook(hook, "cl")
  local ok, err = pcall(run)
  debug.sethook()
  if not ok then check(name .. ": ran to its end (a Lua error stopped it)", false, err) end
  local bad, nRan = {}, 0
  for _, s in pairs(fn) do
    nRan = nRan + 1
    if not isCheck(s) then
      local ls = {}
      for l in pairs(s.lines) do if not lineText(s.file, l):match("^%s*end[%s%)%],;]*$") then ls[#ls + 1] = l end end   -- (a function's closing "end" line: its return)
      table.sort(ls)
      local why
      if #ls > 1 then why = #ls .. " lines run (" .. table.concat(ls, ",", 1, math.min(#ls, 6)) .. (#ls > 6 and ",..." or "") .. ")"
      elseif #ls == 1 then
        local b = bodyOf(s, ls[1])
        if not (b:match("^if[%s%(]") or b:match("^return[%s%(;]") or b == "return" or b:match("^end")) then why = "its one line is not a return check: " .. b:sub(1, 60) end
      end
      if why then bad[#bad + 1] = ("%s:%d (%d calls%s) %s"):format(s.file, s.ld, s.calls, s.from and (", from " .. s.from) or "", why) end
    end
  end
  table.sort(bad)
  check(name .. ": no function of the settings window or the rule editor does work (" .. nRan .. " ran, each only its return check)",
    #bad == 0, #bad .. ": " .. table.concat(bad, " | ", 1, math.min(#bad, 80)))
end

-------------------------------------------------------------------------------------------------------------------------------------
-- the window is closed; the game goes on
-------------------------------------------------------------------------------------------------------------------------------------
phase("(as before) a fight (300 rules: UNIT_AURA and SPELL_UPDATE_COOLDOWN storms, clicks, gear tooltips)", function()
  W.enterCombat()
  for i = 1, 60 do
    W.fire("UNIT_AURA", "player", { isFullUpdate = (i % 10 == 0) })
    W.fire("UNIT_AURA", "target", { isFullUpdate = false })
    W.fire("SPELL_UPDATE_COOLDOWN")
    W.fire("ACTIONBAR_UPDATE_COOLDOWN")
    if i % 5 == 0 then W.fire("GLOBAL_MOUSE_DOWN", "LeftButton"); W.fire("GLOBAL_MOUSE_UP", "LeftButton") end
    if i % 7 == 0 then GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR"); GameTooltip_ShowCompareItem(GameTooltip); GameTooltip:Hide() end
    W.tick(0.05, 1)
  end
end)

phase("another addon's AceConfig window, built and used in the fight", function()
  ACD:Open("OtherAddon"); W.tick(0.1, 4)
  local OF = ACD.OpenFrames.OtherAddon
  local ot = OF and findW(OF, function(w) return w.type == "TreeGroup" end)
  if not ot then error("the other addon's window has no tree") end
  check("(control) the stand-in handed XayaUI's released window and list to the other addon (AceGUI's pool)", OF.frame == xf and ot == xt0, tostring(OF.frame == xf) .. " " .. tostring(ot == xt0))
  local TG = LibStub("AceGUI-3.0").WidgetRegistry.TreeGroup   -- (an untouched TreeGroup's drag handle scripts, for the check below)
  local fresh = TG and TG()
  local dr0 = ot.dragger
  check("the other addon's list has AceGUI's own resize handle (XayaUI's sidebar drag was put back when its window closed)",
    dr0 and fresh and dr0:GetScript("OnMouseDown") == fresh.dragger:GetScript("OnMouseDown") and dr0:GetScript("OnMouseUp") == fresh.dragger:GetScript("OnMouseUp"))
  ot:RefreshTree(); W.tick(0.05, 2)
  for _, key in ipairs({ "all", "rule1", "f1", "loaded", "other" }) do
    local b = rowIn(ot, key)
    if b then
      local e, l = b:GetScript("OnEnter"), b:GetScript("OnLeave")
      if e then e(b) end
      if l then l(b) end
      local md = b:GetScript("OnMouseDown"); if md then md(b, "LeftButton") end
      b:Click("LeftButton"); W.tick(0.05, 2)
      b:Click("RightButton")
      local dc = b:GetScript("OnDoubleClick"); if dc then dc(b, "LeftButton") end
      local ds, de = b:GetScript("OnDragStart"), b:GetScript("OnDragStop")
      if ds then ds(b) end
      if de then de(b) end
      W.tick(0.05, 2)
    end
  end
  local up = ot.treeframe and ot.treeframe:GetScript("OnMouseUp"); if up then up(ot.treeframe, "RightButton") end
  local dr = ot.dragger
  if dr then
    local d, u = dr:GetScript("OnMouseDown"), dr:GetScript("OnMouseUp")
    if d then d(dr, "LeftButton") end
    W.tick(0.05, 2)
    if u then u(dr, "LeftButton") end
    W.tick(0.05, 2)
  end
  local b = rowIn(ot, "all"); if b then b:Click("LeftButton"); W.tick(0.05, 3) end
  local box = findW(OF, function(w) return w.type == "EditBox" end)
  if box then
    typeIn(box.editbox, "hello")
    local ep = box.editbox:GetScript("OnEnterPressed"); if ep then ep(box.editbox) end
    W.fire("GLOBAL_MOUSE_DOWN", "LeftButton")
    box.editbox:ClearFocus()
  end
  local sl = findW(OF, function(w) return w.type == "Slider" end)
  if sl then sl:Fire("OnValueChanged", 20); sl:Fire("OnMouseUp", 20) end
  local dd = findW(OF, function(w) return w.type == "Dropdown" end)
  if dd and dd.pullout and dd.pullout.Open then pcall(dd.pullout.Open, dd.pullout, "TOPLEFT", dd.frame, "BOTTOMLEFT", 0, 0); pcall(dd.pullout.Close, dd.pullout) end
  W.tick(0.1, 4)
  reg:NotifyChange("OtherAddon"); W.tick(0.1, 4)
  ACD:SelectGroup("OtherAddon", "other"); W.tick(0.1, 4)
  ACD:Close("OtherAddon"); W.tick(0.1, 4)
end)

check("the window's old frame, now the other addon's: XayaUI does not touch its keyboard (in the fight, nor when that window opens and closes)",
  kbTouch == 0, kbTouch)

phase("a theme change, edits from the on-screen mover and debug log lines (in the fight)", function()
  if TH and TH.SetBase then TH.SetBase(base0); W.tick(0.1, 3) end
  if TH and TH.Changed then TH.Changed(); W.tick(0.1, 3) end
  for i = 1, 5 do
    local r = ns.rules[3 * i]
    r.visual.x = (r.visual.x or 0) + 10   -- (a display dragged on screen: the mover saves it, then tells the window)
    ns.MarkDirty(); ns.Fire("CONFIG_CHANGED")
    ns.Fire("CONFIG_CHANGED", "view")
    if ns.Log then ns.Log("a debug line " .. i) end
    W.tick(0.1, 2)
  end
  W.tick(0.5, 4)
  W.leaveCombat(); W.tick(0.1, 10)
end)

-- (control) the window still works afterwards
pcall(ns.ToggleUI); settle()
do
  local lk = ns.infoLink
  local want = TH and TH.TokCol and TH.TokCol("accent", "settings")
  local r, g, b
  if lk and lk.text then r, g, b = lk.text:GetTextColor() end
  check("(control) opened again: the version link has the theme's color (the theme changed while the window was closed)",
    want and r and math.abs(r - want[1]) < 0.01 and math.abs(g - want[2]) < 0.01 and math.abs(b - want[3]) < 0.01,
    tostring(r) .. "," .. tostring(g) .. "," .. tostring(b) .. " want " .. (want and table.concat(want, ",", 1, 3) or "?"))
end
ACD:SelectGroup(APP, "cooldowns", "enabledTab", "loaded"); settle()
local S2 = ns.RulesTreeStatus(); S2.groups["loaded\001f1"] = true; reg:NotifyChange(APP); settle()
xt = findW(ACD.OpenFrames[APP], function(w) return w.type == "TreeGroup" and w.status == ns.RulesTreeStatus() end)
sb = xt and xt.xuiSearchBox
if sb then typeIn(sb, "rule 2"); W.tick(0.1, 6) end
check("(control) opened again: the rule search filters the list again", sb ~= nil and ns.treeFilter == "rule 2", ns.treeFilter)
check("(control) ...and core's guard listens for a click outside while the search box has the keyboard", W.registeredEvents().GLOBAL_MOUSE_DOWN == true)
W.fire("GLOBAL_MOUSE_DOWN", "LeftButton"); W.tick(0.1, 3)
check("(control) ...a click outside takes the keyboard back", sb and not sb:HasFocus())
check("...then the guard stops listening for clicks", not W.registeredEvents().GLOBAL_MOUSE_DOWN)
pcall(ns.ToggleUI); W.tick(0.1, 10)
end)
if not okAll then check("the test ran to its end (a Lua error stopped it)", false, errAll) end
return R
end
'''


def sources(L):
    out = {}
    for sub in ("XayaUI_Options", os.path.join("XayaUI_Rules", "Editor")):
        d = os.path.join(ROOT, sub)
        for name in sorted(os.listdir(d)):
            if name.endswith(".lua"):
                with open(os.path.join(d, name), encoding="utf-8") as fh:
                    out[sub.replace(os.sep, "/") + "/" + name] = fh.read().split("\n")
    t = L.table()
    for k, lines in out.items():
        lt = L.table()
        for i, line in enumerate(lines, 1):
            lt[i] = line
        t[k] = lt
    return t


def main():
    folders = H.find_addons()
    enabled = [n for n in folders if n in ("XayaUI", "XayaUI_Rules", "XayaUI_Options")]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    res = L.eval("function(src, W, Ld, S) return loadstring(src)()(W, Ld, S) end")(LUA, world, loader, sources(L))
    bad = 0
    n = len(res)
    for i in range(1, n + 1):
        name, good = res[i][1], res[i][2]
        print(("PASS " if good else "FAIL ") + name)
        bad += 0 if good else 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (n, bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
