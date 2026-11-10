#!/usr/bin/env python3
"""Reviews R13, R14 / R15 and R16 (docs/plans/RULES-REVIEW-2026-11-10.md): what XayaUI's settings window leaves on AceGUI's shared,
pooled widgets once the window closes, and on the game's GameTooltip.

AceGUI (LibStub "AceGUI-3.0") keeps one pool of released widgets for every addon. XayaUI's Rules sidebar tree and its spell search boxes
go back to that pool when the window closes, and the next AceConfig addon the player opens gets them, with XayaUI's hooks still on.
The player opens XayaUI's settings, uses the Rules sidebar and a spell search box, closes the window, then opens another addon's
AceConfig options window ("OtherAddon": a tree with rows keyed all, rule1 and f1, and a text box). Checks what she sees and gets there:
  R13  every row of the other addon's list is drawn (none hidden at zero alpha / height), none carries XayaUI's eye, banner or other parts;
       right-clicking a row or the list's free space opens no XayaUI menu; a double-click opens no XayaUI rename box; a click there does
       not clear her XayaUI multi-selection; XayaUI's rules and groups are unchanged.
  R16  typing in the other addon's text box opens no XayaUI spell search popup, and Enter there does not change the XayaUI rule whose
       search box it was, nor clear what she typed.
  R14 / R15  hovering a result row of XayaUI's search popup still hides Blizzard's compare tooltips, and leaves GameTooltip's
       supportsItemComparison (the game's gear comparison switch, true in the game) as it was: before, one hover set it to nil until /reload.
Positive controls, in XayaUI's own window: the sidebar's right-click menu, the search popup and its pick still work.
Run: python3 tests/fix_u6_pooled_widgets_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local okAll, errAll = pcall(function()
do   -- AceGUI's tree rows are 18 px high (as in tests/sidebar_delete_run.py)
  local init = W.templateInit.OptionsListButtonTemplate
  W.templateInit.OptionsListButtonTemplate = function(f) init(f); f._h = 18 end
end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
check("settings window addon loaded", ns and ns.BuildOptionsTable ~= nil)
if not (ns and ns.BuildOptionsTable) then return end
CueRulesDB.ui = CueRulesDB.ui or {}; CueRulesDB.ui.consoleAutoOpen = false
local ACD, reg, APP = LibStub("AceConfigDialog-3.0"), LibStub("AceConfigRegistry-3.0"), "CueRules"
local function settle() W.tick(0.05, 6) end

-- the game: GameTooltip compares gear (Blizzard's GameTooltip.xml KeyValue), and the compare tooltips it opens
GameTooltip.supportsItemComparison = true
for _, n in ipairs({ "ShoppingTooltip1", "ShoppingTooltip2" }) do if not _G[n] then _G[n] = CreateFrame("GameTooltip", n, UIParent) end end
GameTooltip_ShowCompareItem = function() ShoppingTooltip1:Show(); ShoppingTooltip2:Show() end
C_Spell.GetSpellName = function(id) return ({ [204021] = "Fiery Brand", [204022] = "Fiery Blast" })[id] end

-- menus: which ones were opened, and their buttons by label
local menus, menu = 0, {}
local function rec()
  local root = {}
  function root:CreateButton(text, fn) menu[tostring(text)] = fn; return rec() end
  function root:CreateTitle(text) menu["title:" .. tostring(text)] = true; return rec() end
  function root:CreateDivider() end
  function root:CreateRadio() return rec() end
  function root:CreateCheckbox() return rec() end
  function root:SetScrollMode() end
  function root:AddMenuAcquiredCallback() end
  return root
end
MenuUtil.CreateContextMenu = function(owner, gen) menus = menus + 1; gen(owner, rec()) end

local function findW(w, pred)
  if not w then return nil end
  if pred(w) then return w end
  for _, c in ipairs(w.children or {}) do local f = findW(c, pred); if f then return f end end
end
local function rowIn(t, key)
  for _, b in ipairs(t and t.buttons or {}) do
    if b:IsShown() and (tostring(b.uniquevalue or ""):match("([^\001]+)$") or "") == key then return b end
  end
end

-- XayaUI: two rules in a group, the window open on the Loaded list
ns.folders = { { id = "f1", name = "Defensives" } }
CueRulesDB.folders = ns.folders
ns.rules = {}
local function add(name, folder)
  local r = ns.NewRule(); r.name = name; r.enabled = true; r.spellID = 0; r.visual.enabled = true; r.folder = folder
  ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r; return r
end
local A, B = add("Shield", "f1"), add("Wall", "f1")
A.extra = { list = { { type = "spellKnown", spellID = 0, state = true } } }   -- a Spell Known trigger: its row has a spell search box
-- the trigger's spell ID as the rule now holds it (the editor may hand the edit back as a new table)
local function T1() local r = ns.rules[1]; local t = r and r.extra and r.extra.list and r.extra.list[1]; return t and t.spellID end
B.spellID = 204021   -- a spell a rule uses: the search finds it by name ("in your rules")
CueRulesDB.rules = ns.rules
pcall(ns.ToggleUI); settle()
check("the settings window is open", ACD.OpenFrames[APP] ~= nil)
ACD:SelectGroup(APP, "cooldowns", "enabledTab", "loaded"); settle()
local S = ns.RulesTreeStatus(); S.groups["loaded\001f1"] = true; reg:NotifyChange(APP); settle()
local xt = findW(ACD.OpenFrames[APP], function(w) return w.type == "TreeGroup" and w.status == ns.RulesTreeStatus() end)
local row = xt and rowIn(xt, "rule1")
check("XayaUI's sidebar shows the rule row", row ~= nil)
menu, menus = {}, 0
if row then row:Click("RightButton"); settle() end
check("control: right-click on a XayaUI rule row opens its menu", menus == 1 and menu["Delete"] ~= nil, menus)
IsControlKeyDown = function() return true end
if row then row:Click("LeftButton"); settle() end
IsControlKeyDown = function() return false end
check("control: Ctrl+click selects the rule (multi-selection of 1)", ns.MultiCount and ns.MultiCount() == 1, ns.MultiCount and ns.MultiCount())

-- XayaUI: the rule's Trigger tab with its spell search box
local path = { ns.OptionsApi.RuleEditorParts.RulePath(A) }; path[#path + 1] = "trigger"
ACD:SelectGroup(APP, unpack(path)); settle()
pcall(ns.DecorateTrees); settle()
local sw = findW(ACD.OpenFrames[APP], function(w)
  local o = w.type == "EditBox" and w.userdata and w.userdata.option
  return o and type(o.arg) == "table" and o.arg.xuiSearch ~= nil and o.arg.xuiSearchKind == "cd"
end)
check("XayaUI's rule page shows a spell search box", sw ~= nil)
if not sw then return end
local eb = sw.editbox
local function typeIn(box, text)
  box:SetFocus(); box:SetText(text)
  local f = box:GetScript("OnTextChanged"); if f then f(box, true) end
  W.tick(0.1, 4)
end
local pop = _G.XayaUISpellSearch
typeIn(eb, "fiery")
pop = _G.XayaUISpellSearch
check("control: typing in XayaUI's search box opens the search popup", pop ~= nil and pop:IsShown())
-- R14 / R15: hover a result row and leave it
local first = pop and pop.rows and pop.rows[1]
if first and first:GetScript("OnEnter") then
  first:GetScript("OnEnter")(first)
  GameTooltip_ShowCompareItem(GameTooltip)   -- Blizzard opens its compare tooltips for an item
  check("R14: while a result is hovered, the compare tooltips stay hidden", not ShoppingTooltip1:IsShown() and not ShoppingTooltip2:IsShown())
  first:GetScript("OnLeave")(first)
end
check("R14/R15: after hovering a result, GameTooltip still compares gear (supportsItemComparison unchanged)", GameTooltip.supportsItemComparison == true,
  tostring(GameTooltip.supportsItemComparison))
check("control: the popup lists hits for 'fiery'", pop and pop:IsShown() and pop.results and pop.results[1] ~= nil, pop and pop.results and #pop.results)
local esc = eb:GetScript("OnEscapePressed"); if esc then esc(eb) end; settle()   -- she leaves the box without picking
check("control: Escape closes the search popup", not pop:IsShown())
local pickedId = T1()

-- the player closes XayaUI's settings window
pcall(ns.ToggleUI); W.tick(0.1, 6)
check("XayaUI's window is closed", not (ACD.OpenFrames[APP] and ACD.OpenFrames[APP].frame:IsShown()))
local nSel = ns.MultiCount and ns.MultiCount() or 0
local snapshot = {}
for i, r in ipairs(ns.rules) do snapshot[i] = r.name .. "/" .. tostring(r.folder) .. "/" .. tostring(r.spellID) .. "/" .. tostring(r.extra and r.extra.list[1] and r.extra.list[1].spellID) end
local nFolders = #ns.folders

-- another addon's AceConfig window: a tree whose rows have keys like XayaUI's, and a text box
local typed = {}
local function grp(name, boxes)
  local g = { type = "group", name = name, args = { note = { type = "description", name = name } } }
  for i = 1, boxes or 0 do
    g.args["box" .. i] = { type = "input", name = "Name " .. i, order = i, get = function() return typed[i] end, set = function(_, v) typed[i] = v end }
  end
  return g
end
LibStub("AceConfig-3.0"):RegisterOptionsTable("OtherAddon", { type = "group", name = "Other", childGroups = "tree", args = {
  all = grp("All things", 3),
  rule1 = grp("First rule"), f1 = grp("First folder"), other = grp("Other"),
} })
ACD:Open("OtherAddon"); W.tick(0.1, 6)
local OF = ACD.OpenFrames["OtherAddon"]
check("the other addon's window is open", OF ~= nil)
local ot = OF and findW(OF, function(w) return w.type == "TreeGroup" end)
check("the stand-in handed XayaUI's released tree to the other addon (AceGUI pool)", ot ~= nil and ot.xuiHooked == true)
if not ot then return end
ot:RefreshTree(); settle()
local okRows, bad = true, ""
for _, key in ipairs({ "all", "rule1", "f1", "other" }) do
  local b = rowIn(ot, key)
  if not (b and b:GetAlpha() > 0.5 and b:GetHeight() >= 10) then okRows = false; bad = bad .. key .. ":" .. tostring(b and b:GetAlpha()) .. "/" .. tostring(b and b:GetHeight()) .. " " end
end
check("R13: every row of the other addon's list is drawn (none hidden by XayaUI)", okRows, bad)
local parts = ""
for _, b in ipairs(ot.buttons or {}) do
  if b:IsShown() then
    for k, v in pairs(b) do
      if type(k) == "string" and k:sub(1, 3) == "xui" and type(v) == "table" and type(v.IsShown) == "function" and v:IsShown() then parts = parts .. k .. " " end
    end
  end
end
check("R13: no XayaUI part (eye, banner, arrows, locks, ...) is drawn on the other addon's rows", parts == "", parts)
menus, menu = 0, {}
local r1 = rowIn(ot, "rule1")
if r1 then r1:Click("RightButton"); settle() end
local allRow = rowIn(ot, "all")
if allRow then allRow:Click("RightButton"); settle() end
check("R13: right-clicking rows of the other addon opens no XayaUI menu", menus == 0, menus)
menus, menu = 0, {}
local up = ot.treeframe:GetScript("OnMouseUp")
if up then up(ot.treeframe, "RightButton"); settle() end
check("R13: right-clicking the other addon's list's free space opens no XayaUI Create menu", menus == 0, menus)
if r1 then local dc = r1:GetScript("OnDoubleClick"); if dc then dc(r1, "LeftButton") end; W.tick(0.1, 4) end
check("R13: a double-click there opens no XayaUI rename box", not (r1 and r1.xuiRenameEB and r1.xuiRenameEB:IsShown()))
if r1 then r1:Click("LeftButton"); settle() end
check("R13: a click there leaves XayaUI's multi-selection alone", (ns.MultiCount and ns.MultiCount() or 0) == nSel, nSel)

-- R16: the other addon's text box (XayaUI's released search box, if the pool gave it back)
if allRow then allRow:Click("LeftButton"); settle() end
local ow = findW(OF, function(w) return w.type == "EditBox" and w.editbox == eb end)
check("the stand-in handed XayaUI's released search box to the other addon (AceGUI pool)", ow ~= nil)
if ow then
  local oeb = ow.editbox
  if pop then pop:Hide() end
  typeIn(oeb, "fiery")
  pop = _G.XayaUISpellSearch
  check("R16: typing in the other addon's box opens no XayaUI search popup", not (pop and pop:IsShown()))
  if pop and pop:IsShown() then pop.owner = oeb end   -- (old code: the popup is up for this box; Enter would pick)
  local ep = oeb:GetScript("OnEnterPressed"); if ep then ep(oeb) end; settle()
  check("R16: Enter there does not change the XayaUI rule the box once searched for", T1() == pickedId, tostring(T1()))
  check("R16: Enter there keeps what the player typed", oeb:GetText() == "fiery", tostring(oeb:GetText()))
end
local same = #ns.folders == nFolders
for i, r in ipairs(ns.rules) do if snapshot[i] ~= (r.name .. "/" .. tostring(r.folder) .. "/" .. tostring(r.spellID) .. "/" .. tostring(r.extra and r.extra.list[1] and r.extra.list[1].spellID)) then same = false end end
check("XayaUI's rules and groups are unchanged by the other addon's window", same and #ns.rules == #snapshot, #ns.rules)
ACD:Close("OtherAddon"); W.tick(0.1, 4)

-- back in XayaUI: the sidebar works again (the tree may come back from the pool)
pcall(ns.ToggleUI); settle()
ACD:SelectGroup(APP, "cooldowns", "enabledTab", "loaded"); settle()
local S2 = ns.RulesTreeStatus(); S2.groups["loaded\001f1"] = true; reg:NotifyChange(APP); settle()
xt = findW(ACD.OpenFrames[APP], function(w) return w.type == "TreeGroup" and w.status == ns.RulesTreeStatus() end)
row = xt and rowIn(xt, "rule2")
menus, menu = 0, {}
if row then row:Click("RightButton"); settle() end
check("control: back in XayaUI, right-click on a rule row opens its menu again", menus == 1 and menu["Delete"] ~= nil, menus)
ACD:SelectGroup(APP, unpack(path)); settle()
pcall(ns.DecorateTrees); settle()
sw = findW(ACD.OpenFrames[APP], function(w)
  local o = w.type == "EditBox" and w.userdata and w.userdata.option
  return o and type(o.arg) == "table" and o.arg.xuiSearch ~= nil and o.arg.xuiSearchKind == "cd"
end)
if sw then
  eb = sw.editbox
  typeIn(eb, "fiery")
  pop = _G.XayaUISpellSearch
  check("control: back in XayaUI, typing in the spell search box opens the popup again", pop ~= nil and pop:IsShown() and pop.results[1] ~= nil)
  local f = eb:GetScript("OnEnterPressed"); if f then f(eb) end; settle()
  check("control: Enter in XayaUI's search box picks the first hit into the rule's trigger", T1() == 204021, T1())
else
  check("control: back in XayaUI, the rule's spell search box is shown again", false)
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
