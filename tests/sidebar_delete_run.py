#!/usr/bin/env python3
"""Deleting from the Rules sidebar (XayaUI_Rules_Options 0.6.82, XayaUI_Options 0.6.106). Xaya, 2026-11-08 (request log
REQUEST-LOG-session-014bN6tUDLJ6T742DewZDg1s.md row 20, her words): "deleting auras shifts the rule sidebar up still and right clicking
to delete does not get detected to remove the menu from the top". Screenshot 1: the list scrolled into the group Items + Consumables,
the confirm "Delete the rule 'Hearty Well Fed'? ..."; screenshot 2: the bar "Delete (3)", "Move (3)", "Deselect (3)" over "LOADED (86)".

(a) After a delete the list stays where it was: the rows above the deleted one keep their place on screen and the row after it moves up
    into its place; a list that gets shorter than the view settles at its bottom, never at the top.
    Cause: every delete goes back to the list's top row (ns.GoHome selects Loaded, or All in Smart Categories). The window rebuild that
    follows re-selects that row through AceGUI's TreeGroup:Select, which asks RefreshTree to scroll the selected row into view, so the
    list jumped to Loaded at the top. The earlier fix (XayaUI_Options/Skin.lua, the tree's Select wrapper: "a rebuild does not" scroll)
    only covers re-selecting the row that was already selected; a delete changes the selection, and the wrapper is not on the tree yet
    when AceConfigDialog's rebuild selects (Skin.lua takes it off on release and puts it back after the rebuild).
(b) Deleting removes the deleted rules from the multi-selection by every path; the bar's counts follow and the bar goes when nothing is
    left. Cause: the selection (Sidebar.lua, a set of rule tables) was emptied only by the bar's own Delete (N); a rule deleted any
    other way (right-click > Delete, Del on the open rule, the rule page's Delete this rule, a group deleted with its contents) stayed
    in it, so the bar kept counting it, and a rule put back from the Recycle Bin came back selected.

Paths: right-click > Delete + the confirm's Yes; Del on the open rule; the bar's Delete (N); Del with rules selected; the rule page's
Delete this rule; right-click on a group > Delete Group (Contents Move Up) and > Delete Group and All Contents; the Recycle Bin's restore.
Draws the real window in the stand-in game (rows 18 px for AceGUI's count; ours are taller) and reads what is on screen: the rows'
screen positions, the bar's text, the purple selection wash.
Run: python3 tests/sidebar_delete_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local okAll, errAll = pcall(function()
do   -- AceGUI's tree rows are 18 px high (AceGUIContainer-TreeGroup.lua counts lines as (height - 20) / 18)
  local init = W.templateInit.OptionsListButtonTemplate
  W.templateInit.OptionsListButtonTemplate = function(f) init(f); f._h = 18 end
end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
check("settings window addon loaded", ns and ns.BuildOptionsTable ~= nil and ns.DeleteKey ~= nil)
if not (ns and ns.BuildOptionsTable) then return end
CueRulesDB.ui = CueRulesDB.ui or {}; CueRulesDB.ui.consoleAutoOpen = false
local ACD, reg, APP = LibStub("AceConfigDialog-3.0"), LibStub("AceConfigRegistry-3.0"), "CueRules"
pcall(ns.ToggleUI); W.tick(0.05, 6)
check("the settings window is open", ACD.OpenFrames[APP] ~= nil)

-- the confirm popup: remembered, answered Yes by the test (the stand-in's StaticPopup_Show shows nothing)
local pop
StaticPopup_Show = function(which, text, _, data) pop = { which = which, text = text, data = data }; return CreateFrame("Frame") end
local function yes()
  local p = pop; pop = nil
  if not p then return false end
  local d = StaticPopupDialogs[p.which]
  d.OnAccept(nil, p.data)
  return true
end
-- the right-click menu: its buttons by label
local menu = {}
local function rec()
  local root = {}
  function root:CreateButton(text, fn) menu[tostring(text)] = fn; return rec() end
  function root:CreateTitle() return rec() end
  function root:CreateDivider() end
  function root:CreateRadio() return rec() end
  function root:CreateCheckbox() return rec() end
  function root:SetScrollMode() end
  function root:AddMenuAcquiredCallback() end
  return root
end
MenuUtil.CreateContextMenu = function(owner, gen) gen(owner, rec()) end

local function S() return ns.RulesTreeStatus() end
local function findW(w, pred)
  if not w then return nil end
  if pred(w) then return w end
  for _, c in ipairs(w.children or {}) do local f = findW(c, pred); if f then return f end end
end
local function tree() local s = S(); return findW(ACD.OpenFrames[APP], function(w) return w.type == "TreeGroup" and w.status == s end) end
local function settle() W.tick(0.05, 6) end
-- the rows on screen, top to bottom: { obj = rule or group table, top = screen y, b = button }
local function onScreen()
  local t, out = tree(), {}
  for _, b in ipairs(t and t.buttons or {}) do
    if b:IsShown() then
      local last = tostring(b.uniquevalue or ""):match("([^\001]+)$") or ""
      local n = tonumber(last:match("^rule(%d+)$"))
      local obj = n and ns.rules[n]
      if not obj then for _, f in ipairs(ns.folders or {}) do if f.id == last then obj = f end end end
      out[#out + 1] = { obj = obj or last, top = b:GetTop(), b = b, name = (type(obj) == "table" and obj.name) or last }
    end
  end
  return out
end
local function rowOf(obj) for _, r in ipairs(onScreen()) do if r.obj == obj then return r end end end
local function names(list) local o = {}; for _, r in ipairs(list) do o[#o + 1] = tostring(r.name) .. "@" .. math.floor((r.top or 0) + 0.5) end; return table.concat(o, " ") end
local function sv() local s = S(); return s and s.scrollvalue end
local function bar() local t = tree(); return t and t.xuiSelBar end
local function barText()
  local b = bar()
  if not (b and b:IsShown()) then return "hidden" end
  return b.del:GetText() .. " | " .. b.mv:GetText() .. " | " .. b.clr:GetText()
end
local function purple(rule) local r = rowOf(rule); return r and r.b.xuiMultiTex and r.b.xuiMultiTex:IsShown() and true or false end

-- 20 rules in Defensives, 40 in Items + Consumables (Xaya's group), 10 at the top level: a list that scrolls
local byName
local function setup(scrollTo)
  ns.MultiClear()
  ns.folders = { { id = "f1", name = "Defensives" }, { id = "f2", name = "Items + Consumables" } }
  CueRulesDB.folders = ns.folders
  ns.rules, byName = {}, {}
  local function add(name, folder)
    local r = ns.NewRule(); r.name = name; r.enabled = true; r.useBuff, r.buffID, r.buffState = true, 2000 + #ns.rules, "present"
    r.visual.enabled, r.sound.enabled = false, false
    r.folder = folder
    ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r; byName[name] = r
  end
  for i = 1, 20 do add(("Defensive %02d"):format(i), "f1") end
  for i = 1, 40 do add(i == 25 and "Hearty Well Fed" or ("Item %02d"):format(i), "f2") end
  for i = 1, 10 do add(("Top %02d"):format(i), nil) end
  CueRulesDB.rules = ns.rules
  ACD:SelectGroup(APP, "cooldowns", "enabledTab", "loaded"); settle()
  local s = S()
  s.groups["loaded\001f1"], s.groups["loaded\001f2"] = true, true
  reg:NotifyChange(APP); settle()
  local t = tree()
  if scrollTo == "bottom" then local _, mx = t.scrollbar:GetMinMaxValues(); scrollTo = mx end
  t.scrollbar:SetValue(scrollTo); settle()
  return t
end
local function click(row, mouse)
  local b = row and row.b
  if b then b:Click(mouse or "LeftButton"); settle() end
end
local function ctrlClick(obj)
  IsControlKeyDown = function() return true end
  click(rowOf(obj))
  IsControlKeyDown = function() return false end
end
local function rightMenu(obj) menu = {}; local r = rowOf(obj); if r then r.b:Click("RightButton") end; return menu end

-- (a): the rows above the deleted one keep their screen place, the next row takes its place, the scroll position is kept
local function samePlace(tag, before, gone, svBefore)
  settle()
  local after = onScreen()
  local firstGone
  for i, r in ipairs(before) do if gone[r.obj] then firstGone = i; break end end
  local ok, bad = true, {}
  for i = 1, (firstGone or (#before + 1)) - 1 do
    local r = before[i]
    local a = rowOf(r.obj)
    if not (a and math.abs(a.top - r.top) < 0.5) then ok = false; bad[#bad + 1] = tostring(r.name) end
  end
  check(tag .. ": the scroll position is kept (" .. tostring(svBefore) .. ")", sv() == svBefore, "now " .. tostring(sv()) .. "; on screen: " .. names(after))
  check(tag .. ": every row above the deleted one stays where it was on screen", ok and firstGone ~= nil and firstGone > 1,
    "moved: " .. table.concat(bad, ", ") .. "; before: " .. names(before) .. "; after: " .. names(after))
  if firstGone then
    -- the row now drawn right under the last row kept above it (the next one in the list, which may have been below the view)
    local above, a = before[firstGone - 1], nil
    for i, r in ipairs(after) do if above and r.obj == above.obj then a = after[i + 1] end end
    check(tag .. ": the row after the deleted one moves up into its place", a ~= nil and not gone[a.obj] and math.abs(a.top - before[firstGone].top) < 0.5,
      (a and tostring(a.name) or "none") .. " at " .. tostring(a and a.top) .. ", the deleted row was at " .. tostring(before[firstGone].top))
  end
  for o in pairs(gone) do
    local still = false
    for _, r in ipairs(ns.rules) do if r == o then still = true end end
    for _, f in ipairs(ns.folders) do if f == o then still = true end end
    if still then check(tag .. ": it was deleted", false, tostring(o.name)) end
  end
end

-------------------------------------------------------------------------------- (a) the list stays where it was
do   -- 1. her screenshot: the open rule, right-click > Delete, Yes
  setup(40)
  local hw = byName["Hearty Well Fed"]
  click(rowOf(hw))
  check("a1 Hearty Well Fed is on screen and open", rowOf(hw) ~= nil and ns.SelectedRuleForUndo() == hw, names(onScreen()))
  local before, s0 = onScreen(), sv()
  local m = rightMenu(hw)
  check("a1 its right-click menu has Delete", m["Delete"] ~= nil)
  if m["Delete"] then m["Delete"]() end
  check("a1 the confirm names the rule", pop and tostring(pop.text):find("Hearty Well Fed", 1, true) ~= nil, pop and pop.text)
  yes()
  samePlace("a1 right-click > Delete > Yes", before, { [hw] = true }, s0)
end
do   -- 2. Del on the open rule
  setup(40)
  local r = byName["Item 27"]
  click(rowOf(r))
  local before, s0 = onScreen(), sv()
  ns.DeleteKey(); yes()
  samePlace("a2 Del on the open rule", before, { [r] = true }, s0)
end
do   -- 3. three selected, the bar's Delete (3)
  setup(40)
  local a, b, c = byName["Item 20"], byName["Item 22"], byName["Hearty Well Fed"]
  ctrlClick(a); ctrlClick(b); ctrlClick(c)
  check("a3 three rules selected: the bar reads Delete (3)", barText():find("Delete (3)", 1, true) ~= nil, barText())
  local before, s0 = onScreen(), sv()
  bar().del:Click(); yes()
  samePlace("a3 the bar's Delete (3)", before, { [a] = true, [b] = true, [c] = true }, s0)
  check("a3 after it the bar is gone", barText() == "hidden", barText())
end
do   -- 4. two selected, Del
  setup(40)
  local a, b = byName["Item 21"], byName["Item 23"]
  ctrlClick(a); ctrlClick(b)
  local before, s0 = onScreen(), sv()
  ns.DeleteKey(); yes()
  samePlace("a4 Del with two rules selected", before, { [a] = true, [b] = true }, s0)
end
do   -- 5. the rule page's Delete this rule
  setup(40)
  local r = byName["Item 24"]
  click(rowOf(r))
  local before, s0 = onScreen(), sv()
  local fn
  do   -- the execute "Delete this rule" of the open rule's page, as the window builds it
    local node = ns.BuildOptionsTable().args.cooldowns.args.enabledTab
    for seg in tostring(S().selected):gmatch("[^\001]+") do node = node and node.args and node.args[seg] end
    local stack, seen = { node }, {}
    while #stack > 0 and not fn do
      local t = table.remove(stack)
      if type(t) == "table" and not seen[t] then
        seen[t] = true
        if t.type == "execute" and t.name == "Delete this rule" then fn = t.func end
        for _, v in pairs(t) do if type(v) == "table" then stack[#stack + 1] = v end end
      end
    end
  end
  check("a5 the open rule's page has Delete this rule", fn ~= nil)
  if fn then fn() end
  samePlace("a5 the rule page's Delete this rule", before, { [r] = true }, s0)
end
do   -- 6. right-click on a group > Delete Group (Contents Move Up) / > Delete Group and All Contents
  for _, which in ipairs({ "Delete Group (Contents Move Up)", "|cffff6060Delete Group and All Contents|r" }) do
    setup(12)
    local g = ns.folders[2]
    local before, s0 = onScreen(), sv()
    local m = rightMenu(g)
    check("a6 the group row's menu has " .. which, m[which] ~= nil)
    if m[which] then m[which]() end
    yes()
    local gone = { [g] = true }
    if which:find("All Contents", 1, true) then for i = 1, 40 do gone[byName[i == 25 and "Hearty Well Fed" or ("Item %02d"):format(i)]] = true end end
    samePlace("a6 " .. which:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""), before, gone, s0)
  end
end
do   -- 7. scrolled to the bottom: the list gets shorter than the view, so it settles at its (new) bottom, not at the top
  setup("bottom")
  local r = byName["Top 05"]
  click(rowOf(r))
  -- at the bottom: the list's last row is drawn (a blank spacer line under it aside)
  local function atBottom(list)
    local lines = tree().lines or {}
    local last = lines[#lines - ((lines[#lines] and tostring(lines[#lines].uniquevalue):match("^spacer")) and 1 or 0)]
    local _, mx = tree().scrollbar:GetMinMaxValues()
    local seen = false
    for _, r in ipairs(list) do if last and r.b.uniquevalue == last.uniquevalue then seen = true end end
    return seen, tostring(sv()) .. " of " .. tostring(mx) .. ", last line " .. tostring(last and last.uniquevalue):gsub("\001", ">")
  end
  local before, s0 = onScreen(), sv()
  local b0, why0 = atBottom(before)
  check("a7 scrolled to the bottom of the list", b0 and s0 > 5, why0 .. ": " .. names(before))
  local m = rightMenu(r); if m["Delete"] then m["Delete"]() end; yes(); settle()
  local after = onScreen()
  local b1, why1 = atBottom(after)
  check("a7 the list, one line shorter, settles at its new bottom (one line up, or two when one more row now fits), not at the top",
    b1 and (sv() == s0 - 1 or sv() == s0 - 2), "scroll " .. tostring(s0) .. " -> " .. why1 .. "; " .. names(after))
  local ok = true
  for _, n in ipairs({ "Top 04", "Top 06", "Top 07", "Top 08", "Top 09", "Top 10" }) do if not rowOf(byName[n]) then ok = false end end
  check("a7 the rows around the deleted one are still on screen", ok, "before: " .. names(before) .. "; after: " .. names(after))
end

do   -- 8. what the rebuild after a delete does to the list: the tree widget AceGUI hands back has no remembered row count (Skin.lua
     -- forgets it on release), so the sidebar fits its rows again from AceGUI's 18 px guess. Near the bottom that must not move the list.
  setup("bottom")
  local t = tree()
  local before, s0 = onScreen(), sv()
  t.xuiLines = nil
  t:RefreshTree(); settle()
  local after = onScreen()
  local last = before[#before]
  local a = last and rowOf(last.obj)
  check("a8 a refit from AceGUI's first guess keeps a list scrolled to its bottom where it was (scroll position, last row)",
    sv() == s0 and a ~= nil and math.abs(a.top - last.top) < 0.5, "scroll " .. tostring(s0) .. " -> " .. tostring(sv()) .. "; before: " .. names(before) .. "; after: " .. names(after))
end

-------------------------------------------------------------------------------- (b) the selection drops what is deleted
do   -- 1. her screenshot 2: three selected, right-click one of them > Delete > Yes
  setup(40)
  local a, b, c = byName["Item 20"], byName["Item 22"], byName["Hearty Well Fed"]
  ctrlClick(a); ctrlClick(b); ctrlClick(c)
  check("b1 three selected: Delete (3) | Move (3) | Deselect (3)", barText() == "Delete (3) | Move (3) | Deselect (3)", barText())
  local m = rightMenu(c); if m["Delete"] then m["Delete"]() end; yes(); settle()
  check("b1 right-click > Delete on one of them: the selection holds the other two", ns.MultiCount() == 2 and not ns.MultiHas(c) and ns.MultiHas(a) and ns.MultiHas(b), ns.MultiCount())
  check("b1 the bar now reads Delete (2) | Move (2) | Deselect (2)", barText() == "Delete (2) | Move (2) | Deselect (2)", barText())
  check("b1 the other two keep the purple wash", purple(a) and purple(b))
  m = rightMenu(a); if m["Delete"] then m["Delete"]() end; yes(); settle()
  check("b1 the next right-click delete: (1)", barText() == "Delete (1) | Move (1) | Deselect (1)", barText())
  m = rightMenu(b); if m["Delete"] then m["Delete"]() end; yes(); settle()
  check("b1 the last one deleted: nothing selected, the bar is gone from the top", ns.MultiCount() == 0 and barText() == "hidden", barText())
  local t = tree()
  check("b1 the search box is back in its place", t and t.xuiSearchBox and t.xuiSearchBox:IsShown())
end
do   -- 2. Del on the open rule while other rules are selected goes to the selection (Delete (N)) as before; the open rule alone:
  setup(40)
  local a, b = byName["Item 20"], byName["Item 22"]
  ctrlClick(a); ctrlClick(b)
  -- the rule page's Delete this rule on a selected rule: open it without dropping the selection (the editor is driven directly)
  local fn
  do
    ACD:SelectGroup(APP, ns.ScopePath(a, select(2, pcall(ns.ReadContext)))); settle()
    local node = ns.BuildOptionsTable().args.cooldowns.args.enabledTab
    for seg in tostring(S().selected):gmatch("[^\001]+") do node = node and node.args and node.args[seg] end
    local stack, seen = { node }, {}
    while #stack > 0 and not fn do
      local t = table.remove(stack)
      if type(t) == "table" and not seen[t] then
        seen[t] = true
        if t.type == "execute" and t.name == "Delete this rule" then fn = t.func end
        for _, v in pairs(t) do if type(v) == "table" then stack[#stack + 1] = v end end
      end
    end
  end
  check("b2 two selected, the first one's page is open", ns.MultiCount() == 2 and fn ~= nil, ns.MultiCount())
  if fn then fn() end; settle()
  check("b2 its Delete this rule: the selection holds the other one, the bar reads (1)", ns.MultiCount() == 1 and ns.MultiHas(b) and barText() == "Delete (1) | Move (1) | Deselect (1)", barText())
end
do   -- 3. a group deleted with its contents takes its selected rules out of the selection
  setup(12)
  local a, d = byName["Item 02"], byName["Defensive 18"]
  ctrlClick(a); ctrlClick(d)
  local m = rightMenu(ns.folders[2]); local k = "|cffff6060Delete Group and All Contents|r"
  if m[k] then m[k]() end; yes(); settle()
  check("b3 Delete Group and All Contents: only the rule outside it stays selected, the bar reads (1)", ns.MultiCount() == 1 and ns.MultiHas(d) and barText() == "Delete (1) | Move (1) | Deselect (1)", barText())
end
do   -- 4. the Recycle Bin: a selected rule deleted by right-click and put back is not selected again
  setup(40)
  local a, b = byName["Item 20"], byName["Item 22"]
  ctrlClick(a); ctrlClick(b)
  local m = rightMenu(a); if m["Delete"] then m["Delete"]() end; yes(); settle()
  local id
  for _, it in ipairs((ns.RecycleDB() or {}).items or {}) do if it.kind == "rule" and it.name == "Item 20" then id = it.id end end
  local ok = id and ns.RecycleRestore(id)
  reg:NotifyChange(APP); settle()
  local back = false; for _, r in ipairs(ns.rules) do if r == a then back = true end end
  check("b4 Item 20 is back from the Recycle Bin", ok and back, tostring(id))
  check("b4 ...and not selected: no purple wash, the bar still counts one", not ns.MultiHas(a) and not purple(a) and ns.MultiCount() == 1 and barText() == "Delete (1) | Move (1) | Deselect (1)", barText())
end
do   -- 5. Move (N) after a right-click delete moves only the rules that are still there
  setup(40)
  local a, b = byName["Item 20"], byName["Item 22"]
  ctrlClick(a); ctrlClick(b)
  local m = rightMenu(a); if m["Delete"] then m["Delete"]() end; yes(); settle()
  local said
  local p0 = ns.Print; ns.Print = function(s) said = s end
  ns.MultiMove(nil)
  ns.Print = p0
  check("b5 Move (1) then: 1 rule moved, the deleted one is left alone", said == "moved 1 rule(s) to the top level" and a.folder == "f2" and b.folder == nil, said)
end
end)
if not okAll then check("the test ran to its end (a Lua error stopped it)", false, errAll) end
return R
end
'''


def main():
    folders = H.find_addons()
    enabled = [n for n in folders if n != "XayaUI_DevAssist"]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    bad = 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        print(("PASS " if ok else "FAIL ") + name)
        if not ok:
            bad += 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
