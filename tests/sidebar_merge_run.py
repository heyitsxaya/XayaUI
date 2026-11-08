#!/usr/bin/env python3
"""Right-click on several selected rules in the Rules sidebar: Delete N Selected, Merge N Selected, and a delete made in Rules > Disabled
(XayaUI_Rules_Options 0.6.82). REQUEST-LOG-session-014bN6tUDLJ6T742DewZDg1s.md:
  row 23 (her words): "should be able to right click multi delete" [two rules selected; the right-click menu offers "Link 2 Selected
    (move together)" and "Move 2 Selected To" but only a single "Delete"];
  row 19 (her words): "I want to be able to merge these into one rule that tracks all of these auras and fires based if any are found by
    right clicking on them when multi-selected and choose \"merge rules\"" [four rules selected: Well Fed, Well Fed, Aura 1233706, Aura 1233712];
  row 27, her answers: kept rule "The one I right-click (Recommended)"; the others "Bin, one item each"; "for now, only allow merging of
    triggers"; "depends on the individual triggers; if the triggers differ in detection, missing ones consolidate with missing; present
    consolidate with present -- two triggers attach to one tracker and \"any trigger\" fires";
  the review of the row 20 fix: a delete made from Rules > Disabled went to Enabled > Loaded at the top (TreeHelpers.lua GoHomeKeepScroll:
    the Disabled sub-tab was not a target).
What the player sees, read from the real window drawn in the stand-in game (rows 18 px for AceGUI's count):
  A  Delete N Selected: offered when the right-clicked rule is one of several selected (as Link / Move N Selected); it asks the selection
     bar's question, puts each rule in the Recycle Bin as its own item, leaves edit-locked ones out with the count, clears the selection
     and keeps the list in place;
  B  a delete in Rules > Disabled (right-click > Delete, the Delete key, Delete N Selected) stays in Disabled with the list in place;
  C  Merge N Selected: the right-clicked rule keeps its name, displays, sounds and load settings; the others' present aura triggers join
     its present trigger (fires when ANY of the auras is on you: the engine's own verdict), missing ones one missing trigger (ALL absent),
     other triggers become further triggers (a cooldown row reads exactly what the built-in did: parity), the rule fires on any trigger;
     the others go to the Recycle Bin one item each and come back unchanged; refusals name the rule and change nothing;
  D  one aura ID list rule (TreeHelpers.lua ns.AuraIDList) for the Trigger tab's two boxes and the merge.
Every A / B / C / D check fails on the code before this change (no Delete N Selected / Merge N Selected entry, no ns.AuraIDList; B: the
list opened Enabled > Loaded).
Run: python3 tests/sidebar_merge_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local function has(s, p) return type(s) == "string" and s:find(p, 1, true) ~= nil end
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

local said = {}
ns.Print = function(s) said[#said + 1] = tostring(s) end
local function lastSaid() return said[#said] end
local pop
StaticPopup_Show = function(which, text, _, data) pop = { which = which, text = text, data = data }; return CreateFrame("Frame") end
local function yes() local p = pop; pop = nil; if not p then return false end; StaticPopupDialogs[p.which].OnAccept(nil, p.data); return true end
local menu, order = {}, {}
local function rec()
  local root = {}
  function root:CreateButton(text, fn) menu[tostring(text)] = fn; order[#order + 1] = tostring(text); return rec() end
  function root:CreateTitle() return rec() end
  function root:CreateDivider() order[#order + 1] = "--" end
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
local function live(r) for _, x in ipairs(ns.rules) do if x == r then return true end end; return false end
local function binNames() local o = {}; for _, it in ipairs((ns.RecycleDB() or {}).items or {}) do o[#o + 1] = tostring(it.kind) .. ":" .. tostring(it.name) .. ":" .. #(it.rules or {}) end; return o end

local byName
local function add(name, folder, fill)
  local r = ns.NewRule(); r.name = name; r.enabled = true; r.useBuff, r.buffID, r.buffState = true, 2000 + #ns.rules, "present"
  r.visual.enabled, r.sound.enabled = false, false
  r.folder = folder
  if fill then fill(r) end
  ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r; byName[name] = r
  return r
end
local function fresh()
  ns.MultiClear(); pop = nil
  ns.folders = { { id = "f1", name = "Defensives" }, { id = "f2", name = "Items + Consumables" } }
  CueRulesDB.folders = ns.folders
  ns.rules, byName = {}, {}
  CueRulesDB.rules = ns.rules
  local b = ns.RecycleDB(); if b then wipe(b.items) end
end
local function open(sub, root, groups, scrollTo)
  ACD:SelectGroup(APP, "cooldowns", sub, root); settle()
  local s = S()
  for _, g in ipairs(groups or {}) do s.groups[root .. "\001" .. g] = true end
  reg:NotifyChange(APP); settle()
  local t = tree()
  if scrollTo then t.scrollbar:SetValue(scrollTo); settle() end
  return t
end
-- the long list of the delete test (sidebar_delete_run.py): 20 in Defensives, 40 in Items + Consumables, 10 at the top level
local function setupLong(scrollTo, disabled)
  fresh()
  local function off(r) if disabled then r.enabled = false end end
  for i = 1, 20 do add(("Defensive %02d"):format(i), "f1", off) end
  for i = 1, 40 do add(("Item %02d"):format(i), "f2", off) end
  for i = 1, 10 do add(("Top %02d"):format(i), nil, off) end
  if disabled then return open("disabledTab", "disabled", { "f1", "f2" }, scrollTo) end
  return open("enabledTab", "loaded", { "f1", "f2" }, scrollTo)
end
local function click(row, mouse) local b = row and row.b; if b then b:Click(mouse or "LeftButton"); settle() end end
local function ctrlClick(obj) IsControlKeyDown = function() return true end; click(rowOf(obj)); IsControlKeyDown = function() return false end end
local function rightMenu(obj) menu, order = {}, {}; local r = rowOf(obj); if r then r.b:Click("RightButton") end; return menu end
local function samePlace(tag, before, gone, svBefore)
  settle()
  local after = onScreen()
  local firstGone
  for i, r in ipairs(before) do if gone[r.obj] then firstGone = i; break end end
  local ok, bad = true, {}
  for i = 1, (firstGone or (#before + 1)) - 1 do
    local a = rowOf(before[i].obj)
    if not (a and math.abs(a.top - before[i].top) < 0.5) then ok = false; bad[#bad + 1] = tostring(before[i].name) end
  end
  check(tag .. ": the scroll position is kept (" .. tostring(svBefore) .. ")", sv() == svBefore, "now " .. tostring(sv()) .. "; on screen: " .. names(after))
  check(tag .. ": every row above the deleted one stays where it was on screen", ok and firstGone ~= nil and firstGone > 1,
    "moved: " .. table.concat(bad, ", ") .. "; before: " .. names(before) .. "; after: " .. names(after))
end

-------------------------------------------------------------------------------- A  Delete N Selected (row 23)
do   -- A1 her screenshot: two selected, the right-click menu
  setupLong(40)
  local a, b = byName["Item 20"], byName["Item 22"]
  ctrlClick(a); ctrlClick(b)
  local m = rightMenu(b)
  check("A1 two selected, right-click one of them: the menu offers Delete 2 Selected", m["Delete 2 Selected"] ~= nil, table.concat(order, " / "))
  local function listed(t) for _, x in ipairs(order) do if x == t then return true end end; return false end
  check("A1 ...beside Move 2 Selected To and the single Delete", listed("Move 2 Selected To") and m["Delete"] ~= nil, table.concat(order, " / "))
  local iDel, iMulti
  for i, t in ipairs(order) do if t == "Delete" then iDel = i elseif t == "Delete 2 Selected" then iMulti = i end end
  check("A1 Delete 2 Selected sits right under Delete", iDel ~= nil and iMulti == iDel + 1, table.concat(order, " / "))
  local before, s0 = onScreen(), sv()
  if m["Delete 2 Selected"] then m["Delete 2 Selected"]() end
  check("A2 it asks the selection bar's question", pop and pop.text == ("Delete 2 selected rule(s)? Each goes to the Recycle Bin for %s and can be restored on its own."):format(ns.RecycleKeepLabel()),
    pop and pop.text)
  yes(); settle()
  check("A2 after Yes both rules are gone, each a Recycle Bin item of its own", not live(a) and not live(b) and #ns.RecycleDB().items == 2
    and has(table.concat(binNames(), ","), "rule:Item 20:1") and has(table.concat(binNames(), ","), "rule:Item 22:1"), table.concat(binNames(), ","))
  check("A2 the selection is cleared: the bar is gone", ns.MultiCount() == 0 and barText() == "hidden", barText())
  samePlace("A2 Delete 2 Selected", before, { [a] = true, [b] = true }, s0)
end
do   -- A3 when it is not offered
  setupLong(40)
  local a, b, c = byName["Item 20"], byName["Item 22"], byName["Item 24"]
  ctrlClick(a); ctrlClick(b)
  local m = rightMenu(c)
  local any = false; for k in pairs(m) do if k:match("^Delete %d+ Selected$") or k:match("^Merge %d+ Selected$") then any = true end end
  check("A3 right-click on a rule that is not selected: no Delete / Merge N Selected", not any and m["Delete"] ~= nil, table.concat(order, " / "))
  ns.MultiClear(); ctrlClick(a)
  m = rightMenu(a); any = false; for k in pairs(m) do if k:match("^Delete %d+ Selected$") or k:match("^Merge %d+ Selected$") then any = true end end
  check("A3 only one rule selected: no Delete / Merge N Selected", not any, table.concat(order, " / "))
end
do   -- A4 an edit-locked rule among them
  setupLong(40)
  local a, b, c = byName["Item 20"], byName["Item 22"], byName["Item 23"]
  ctrlClick(a); ctrlClick(b); ctrlClick(c)
  c.editLocked = true
  local m = rightMenu(a)
  said = {}
  if m["Delete 3 Selected"] then m["Delete 3 Selected"]() end
  check("A4 three selected, one edit-locked: it says the locked one is left out", has(said[1], "1 edit-locked rule(s) are left out"), said[1])
  check("A4 ...and asks about the other 2", pop and has(pop.text, "Delete 2 selected rule(s)?"), pop and pop.text)
  yes()
  check("A4 after Yes the 2 are gone, the locked one stays", not live(a) and not live(b) and live(c))
end

-------------------------------------------------------------------------------- B  a delete in Rules > Disabled stays in Disabled
local function inDisabled(tag)
  local sub = ns.CurrentSub()
  check(tag .. ": Rules > Disabled stays open (DISABLED is the list's selected row)", sub == "disabledTab" and S() and S().selected == "disabled",
    tostring(sub) .. " / " .. tostring(S() and S().selected))
end
do   -- B1 right-click > Delete > Yes
  setupLong(30, true)
  check("B setup: the 70 switched-off rules are listed in Rules > Disabled", ns.CurrentSub() == "disabledTab" and rowOf(byName["Item 20"]) ~= nil, names(onScreen()))
  local r = byName["Item 20"]
  click(rowOf(r))
  local before, s0 = onScreen(), sv()
  local m = rightMenu(r); if m["Delete"] then m["Delete"]() end; yes()
  inDisabled("B1 right-click > Delete > Yes")
  samePlace("B1 right-click > Delete > Yes in Disabled", before, { [r] = true }, s0)
end
do   -- B2 the Delete key on the open rule
  setupLong(30, true)
  local r = byName["Item 21"]
  click(rowOf(r))
  local before, s0 = onScreen(), sv()
  ns.DeleteKey(); yes()
  inDisabled("B2 the Delete key > Yes")
  samePlace("B2 the Delete key > Yes in Disabled", before, { [r] = true }, s0)
end
do   -- B3 Delete N Selected
  setupLong(30, true)
  local a, b = byName["Item 20"], byName["Item 22"]
  check("B3 setup: both rules on screen", rowOf(a) ~= nil and rowOf(b) ~= nil, names(onScreen()))
  ctrlClick(a); ctrlClick(b)
  local before, s0 = onScreen(), sv()
  local m = rightMenu(a); if m["Delete 2 Selected"] then m["Delete 2 Selected"]() end; yes()
  check("B3 Delete 2 Selected in Disabled: both gone", not live(a) and not live(b), table.concat(order, " / ") .. " / count " .. ns.MultiCount())
  inDisabled("B3 Delete 2 Selected > Yes")
  samePlace("B3 Delete 2 Selected in Disabled", before, { [a] = true, [b] = true }, s0)
end

-------------------------------------------------------------------------------- C  Merge N Selected (rows 19, 27)
-- aura presence for the engine: only the IDs in `on` are on the player (the same reader every aura trigger uses: Conditions.lua)
local on = {}
ns.BuffPresent = function(id) if on[tonumber(id) or 0] then return true, "test aura", { applications = 1 } end; return false, "test: absent" end
local function fires(r) W.tick(0.1, 1); local ok, res = pcall(ns.Evaluate, r, ns.ReadContext()); return ok and res == true end
local function setOn(...) on = {}; for _, id in ipairs({ ... }) do on[id] = true end end
local function list(t) local o = {}; for i, v in ipairs(t or {}) do o[i] = tostring(v) end; return table.concat(o, ",") end
local function setupMerge(build)
  fresh()
  build()
  open("enabledTab", "loaded", { "f2" }, 0)
end
local function selectAll(rules) for _, r in ipairs(rules) do ctrlClick(r) end end

do   -- C1-C5 her screenshot: four present-aura rules, right-click Aura 1233706
  local K, wf1, wf2, a12
  setupMerge(function()
    for i = 1, 3 do add(("Item %02d"):format(i), "f2") end
    wf1 = add("Well Fed", "f2", function(r) r.buffID = 104273; r.visual.enabled = true; r.visual.tex = "wf1.tga" end)
    wf2 = add("Well Fed ", "f2", function(r) r.buffID = 104280; r.buffAlt = { 104281 } end)
    K = add("Aura 1233706", "f2", function(r) r.buffID = 1233706; r.visual.enabled = true; r.visual.tex = "k.tga"; r.visual.x = 12
      r.sound.enabled = true; r.sound.value = "k-sound"; r.load.combat = "no"; r.repeatSec = 3 end)
    a12 = add("Aura 1233712", "f2", function(r) r.buffID = 1233712 end)
  end)
  local keep = { name = K.name, visual = ns.Copy(K.visual), sound = ns.Copy(K.sound), load = ns.Copy(K.load), repeatSec = K.repeatSec }
  setOn(104273)
  check("C0 before the merge Aura 1233706 does not fire on Well Fed (104273)", not fires(K))
  selectAll({ wf1, wf2, K, a12 })
  local m = rightMenu(K)
  check("C1 four selected, right-click Aura 1233706: the menu offers Merge 4 Selected", m["Merge 4 Selected"] ~= nil, table.concat(order, " / "))
  local iL, iM = nil, nil
  for i, t in ipairs(order) do if t == "Merge 4 Selected" then iM = i elseif t == "Move 4 Selected To" then iL = i end end
  check("C1 ...right before Move 4 Selected To (where Link N Selected sits)", iM ~= nil and iL == iM + 1, table.concat(order, " / "))
  if m["Merge 4 Selected"] then m["Merge 4 Selected"]() end
  local q = pop and pop.text or ""
  check("C2 the question names the kept rule (the right-clicked one)", has(q, "Merge 4 selected rules into 'Aura 1233706' (the rule you right-clicked)?"), q)
  check("C2 ...lists the one trigger it ends up with: present, any one of the 5 auras", has(q, "1. Aura PRESENT (any one of 5): ") and has(q, "(1233706)")
    and has(q, "(104273)") and has(q, "(104280)") and has(q, "(104281)") and has(q, "(1233712)") and not has(q, "2. "), q)
  check("C2 ...says only triggers move and the other 3 go to the Recycle Bin, one item each, by name", has(q, "Only triggers are merged")
    and has(q, "The other 3 rule(s) go to the Recycle Bin for " .. ns.RecycleKeepLabel() .. ", one item each") and has(q, "'Well Fed', 'Well Fed ', 'Aura 1233712'"), q)
  check("C2 nothing changes before Yes", live(wf1) and live(wf2) and live(a12) and K.buffAlt == nil)
  local before, s0 = onScreen(), sv()
  yes(); settle()
  check("C3 after Yes the kept rule watches all 5 auras in one present trigger", K.buffID == 1233706 and K.buffState == "present"
    and list(K.buffAlt) == "104273,104280,104281,1233712" and #ns.TriggerSequence(K) == 1 and #K.extra.list == 0, list(K.buffAlt))
  check("C3 ...keeps its own name, display, sound, load settings and repeat", K.name == keep.name and K.visual.tex == "k.tga" and K.visual.x == 12
    and K.visual.enabled == true and K.sound.value == "k-sound" and K.sound.enabled == true and K.load.combat == "no" and K.repeatSec == 3)
  check("C3 the other 3 are gone, each a Recycle Bin item of its own", not live(wf1) and not live(wf2) and not live(a12) and live(K)
    and #ns.RecycleDB().items == 3, table.concat(binNames(), ","))
  check("C3 the selection is cleared and the list keeps its place", ns.MultiCount() == 0 and barText() == "hidden" and sv() == s0, barText() .. " " .. tostring(sv()))
  local okAny = true
  for _, id in ipairs({ 1233706, 104273, 104280, 104281, 1233712 }) do setOn(id); if not fires(K) then okAny = false end end
  check("C4 the merged rule fires when ANY one of the 5 auras is on you (the engine's verdict, each alone)", okAny)
  setOn()
  check("C4 ...and not when none is", not fires(K))
  -- the bin gives the others back as they were
  local id
  for _, it in ipairs(ns.RecycleDB().items) do if it.name == "Aura 1233712" then id = it.id end end
  ns.RecycleRestore(id)
  check("C5 a merged rule restored from the Recycle Bin comes back with its own trigger; the kept rule is unchanged",
    live(a12) and a12.buffID == 1233712 and a12.buffState == "present" and list(K.buffAlt) == "104273,104280,104281,1233712")
end

do   -- C6 present + missing + a cooldown + a row: one present, one missing, the cooldown as a further trigger, any trigger fires
  local K, m1, m2, cd, p2
  setupMerge(function()
    K = add("Mix present", "f2", function(r) r.buffID = 500 end)
    m1 = add("Mix missing 1", "f2", function(r) r.buffID = 600; r.buffState = "missing" end)
    m2 = add("Mix missing 2", "f2", function(r) r.useBuff, r.buffID, r.buffState = false, 0, "none"
      r.extra = { list = { { type = "buffAura", spellID = 601, state = "no" } } } end)
    cd = add("Mix cooldown", "f2", function(r) r.useBuff, r.buffID, r.buffState = false, 0, "none"
      r.useCooldown, r.spellID, r.cdState, r.countGCD, r.cdName = true, 700, "notReady", true, "My CD" end)
    p2 = add("Mix present 2", "f2", function(r) r.useBuff, r.buffID, r.buffState = false, 0, "none"
      r.extra = { list = { { type = "buffAura", spellID = 501, alt = { 502 }, state = "yes" } } } end)
  end)
  -- spell 700's cooldown as the game reports it out of combat (SpellCooldownInfo.isActive, NeverSecret): running, then not
  local cdRuns = true
  local gsc = C_Spell.GetSpellCooldown
  C_Spell.GetSpellCooldown = function(id)
    if id == 700 then return { startTime = GetTime() - 1, duration = cdRuns and 30 or 0, isEnabled = true, modRate = 1, isActive = cdRuns, isOnGCD = false } end
    return gsc(id)
  end
  setOn(600, 601)
  W.tick(0.1, 1)
  local _, info0 = ns.Evaluate(cd, ns.ReadContext())
  local cdBefore = info0 and info0.cdOK
  selectAll({ K, m1, m2, cd, p2 })
  local m = rightMenu(K)
  if m["Merge 5 Selected"] then m["Merge 5 Selected"]() end
  local q = pop and pop.text or ""
  check("C6 the question lists 3 triggers: present (3 auras), missing (2, all absent), the cooldown; fires on ANY",
    has(q, "1. Aura PRESENT (any one of 3): ") and has(q, "2. Aura MISSING (all 2 absent): ") and has(q, "3. Cooldown") and has(q, "(700)")
    and has(q, "fires when ANY of these triggers is true"), q)
  yes(); settle()
  local X = K.extra.list
  check("C6 kept rule: its present trigger watches 500 + 501, 502; one missing row 600 + 601; one cooldown row; ANY trigger",
    list(K.buffAlt) == "501,502" and #X == 2 and X[1].type == "buffAura" and X[1].state == "no" and X[1].spellID == 600 and list(X[1].alt) == "601"
    and X[2].type == "cooldown" and X[2].spellID == 700 and X[2].state == "notReady" and X[2].countGCD == true and X[2].name == "My CD"
    and K.trigMode == "any", list(K.buffAlt) .. " / " .. #X .. " / " .. tostring(K.trigMode))
  W.tick(0.1, 1)
  local _, info1 = ns.Evaluate(K, ns.ReadContext())
  local cdAfter = ns.TriggerValueOf(K, info1, "x2")
  check("C7 parity, cooldown running: the cooldown row reads what the built-in Cooldown of 'Mix cooldown' read (Not fully ready: true)",
    cdBefore == true and cdAfter == true, tostring(cdBefore) .. " vs " .. tostring(cdAfter) .. " / " .. tostring(info0 and info0.cd and info0.cd.why))
  check("C7 ...so with no aura trigger true (600, 601 on you, 500-502 not) the merged rule fires on its cooldown trigger", fires(K))
  cdRuns = false
  W.tick(0.1, 1)
  local okp = true
  do   -- the same parity with the cooldown back: the old rule (restored from the bin, read on its own) and the row agree on false
    local _, a = ns.Evaluate(cd, ns.ReadContext())
    local _, b = ns.Evaluate(K, ns.ReadContext())
    okp = a and b and a.cdOK == false and ns.TriggerValueOf(K, b, "x2") == false
  end
  check("C7 parity, cooldown ready: both read false", okp)
  setOn(600, 601)
  check("C7 nothing true (600 and 601 on you, 500-502 not, the cooldown ready): the merged rule does not fire", not fires(K))
  setOn(600, 601, 502)
  check("C7 one present aura (502) on you: fires", fires(K))
  setOn(600)
  check("C7 600 on you, 601 not: the missing trigger needs ALL its auras absent, so it does not fire", not fires(K))
  setOn()
  check("C7 every aura absent: the missing trigger is true, fires", fires(K))
  C_Spell.GetSpellCooldown = gsc
end

do   -- C8 refusals and the edit lock
  local K, both, locked, cue
  setupMerge(function()
    K = add("Keep me", "f2", function(r) r.buffID = 800 end)
    both = add("Both triggers", "f2", function(r) r.buffID = 801; r.useCooldown, r.spellID, r.cdState = true, 900, "ready" end)
    locked = add("Locked one", "f2", function(r) r.buffID = 802 end)
  end)
  selectAll({ K, both })
  local m = rightMenu(K)
  said = {}
  if m["Merge 2 Selected"] then m["Merge 2 Selected"]() end
  check("C8 a rule whose two triggers must ALL be true: refused, the message names it, no question", pop == nil and has(lastSaid(), "'Both triggers' has 2 triggers")
    and has(lastSaid(), "ANY trigger"), lastSaid())
  check("C8 ...nothing changed", live(both) and K.buffAlt == nil and #K.extra.list == 0 and K.trigMode == nil)
  both.trigMode = "any"
  ns.MultiClear(); selectAll({ K, both, locked }); locked.editLocked = true
  m = rightMenu(K); said = {}
  if m["Merge 3 Selected"] then m["Merge 3 Selected"]() end
  check("C9 the edit-locked rule is left out with the count", has(said[1], "1 edit-locked rule(s) are left out of the merge"), said[1])
  check("C9 ...the question is about the 2 others", pop and has(pop.text, "Merge 2 selected rules into 'Keep me'"), pop and pop.text)
  yes(); settle()
  check("C9 'Both triggers' (ANY) merged: its aura joins, its cooldown is a further trigger; the locked one stays", not live(both) and live(locked)
    and list(K.buffAlt) == "801" and #K.extra.list == 1 and K.extra.list[1].type == "cooldown" and K.extra.list[1].spellID == 900 and K.trigMode == "any")
end
do   -- C10 more than 30 extra aura IDs; C11 a kept rule with a built-in trigger with no state; C12 more than 12 rows
  local K, big
  setupMerge(function()
    K = add("Keep big", "f2", function(r) r.buffID = 1000; r.buffAlt = {}; for i = 1, 20 do r.buffAlt[i] = 1000 + i end end)
    big = add("Big", "f2", function(r) r.buffID = 1100; r.buffAlt = {}; for i = 1, 15 do r.buffAlt[i] = 1100 + i end end)
  end)
  selectAll({ K, big })
  local m = rightMenu(K); said = {}
  if m["Merge 2 Selected"] then m["Merge 2 Selected"]() end
  check("C10 the merged present trigger would watch 37 auras: refused (at most 30 more than its own)", pop == nil and has(lastSaid(), "would watch 37 auras"), lastSaid())
  check("C10 ...nothing changed", #K.buffAlt == 20 and live(big))
  local K2, o2
  setupMerge(function()
    K2 = add("Keep cd none", "f2", function(r) r.buffID = 1200; r.spellID = 77 end)   -- a cooldown spell set, its state "none" (ignored)
    o2 = add("Other", "f2", function(r) r.buffID = 1201 end)
  end)
  selectAll({ K2, o2 })
  m = rightMenu(K2); said = {}
  if m["Merge 2 Selected"] then m["Merge 2 Selected"]() end
  check("C11 the kept rule's Cooldown has no state: refused (with ANY it would always fire), names it", pop == nil and has(lastSaid(), "'Keep cd none' has a Cooldown trigger with no state chosen"), lastSaid())
  local K3, o3
  setupMerge(function()
    K3 = add("Keep rows", "f2", function(r) r.trigMode = "any"; r.extra = { list = {} }; for i = 1, 12 do r.extra.list[i] = { type = "itemCount", itemID = i, op = ">=", count = 1 } end end)
    o3 = add("Debuff", "f2", function(r) r.useBuff, r.buffID, r.buffState = false, 0, "none"
      r.extra = { list = { { type = "targetDebuff", spellID = 204598, unit = "target", state = "yes" } } } end)
  end)
  selectAll({ K3, o3 })
  m = rightMenu(K3); said = {}
  if m["Merge 2 Selected"] then m["Merge 2 Selected"]() end
  check("C12 the kept rule would hold 13 additional triggers: refused (a rule holds 12)", pop == nil and has(lastSaid(), "would hold 13 additional triggers"), lastSaid())
  check("C12 ...nothing changed", #K3.extra.list == 12 and live(o3))
end

do   -- C13 a present aura with "seconds left" is not a plain present trigger: it comes over as its own Buff / Aura (another) row, as it was
  local K, t
  setupMerge(function()
    K = add("Keep timed", "f2", function(r) r.buffID = 1300 end)
    t = add("Timed", "f2", function(r) r.buffID = 1301; r.buffAlt = { 1302 }; r.buffTimeOp, r.buffTimeSec, r.buffEstimate, r.buffName = "<=", 5, false, "Short" end)
  end)
  selectAll({ K, t })
  local m = rightMenu(K)
  if m["Merge 2 Selected"] then m["Merge 2 Selected"]() end
  local q = pop and pop.text or ""
  check("C13 the question lists it as its own trigger, with its seconds left", has(q, "1. Aura PRESENT: ") and has(q, "2. Aura PRESENT (any one of 2): ") and has(q, "seconds left <= 5"), q)
  yes(); settle()
  local x = K.extra.list[1]
  check("C13 kept rule: its own present trigger unchanged, the timed one a row with the same auras, time, estimate off and name; ANY trigger",
    K.buffAlt == nil and #K.extra.list == 1 and x.type == "buffAura" and x.spellID == 1301 and list(x.alt) == "1302" and x.state == "yes"
    and x.timeOp == "<=" and x.timeSec == 5 and x.estimate == false and x.name == "Short" and K.trigMode == "any")
  setOn(1301)
  check("C13 the timed row reads like any Buff / Aura (another) row: its aura on you with unknown time left is not a guess (no fire)", not fires(K))
  setOn(1300)
  check("C13 the kept rule's own aura on you: fires", fires(K))
end

-------------------------------------------------------------------------------- D  one aura ID list rule
do
  check("D1 the shared aura ID list rule exists (TreeHelpers.lua ns.AuraIDList)", type(ns.AuraIDList) == "function")
  if type(ns.AuraIDList) == "function" then
    local l, over = ns.AuraIDList(5, "5, 7, 7, x, 0, 9")
    check("D1 numbers only, no repeats, never the trigger's own aura", list(l) == "7,9" and over == 0, list(l))
    local many = {}; for i = 1, 33 do many[i] = 100 + i end
    l, over = ns.AuraIDList(1, many)
    check("D1 at most 30, the rest counted", #l == 30 and over == 3 and l[30] == 130)
    check("D1 empty gives nil", ns.AuraIDList(5, "5") == nil)
  end
  -- parity: the Trigger tab's two boxes (built-in Buff / Aura, a Buff / Aura (another) row) store what the shared rule gives
  local r = ns.NewRule(); r.useBuff, r.buffID, r.buffState = true, 5, "present"
  r.extra = { list = { { type = "buffAura", spellID = 5, state = "yes" } } }
  ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
  local tbl = ns.BuildOptionsTable()
  local okc, ctx = pcall(ns.ReadContext)
  ACD:SelectGroup(APP, ns.ScopePath(r, okc and ctx or nil)); settle()
  local node = tbl.args.cooldowns.args.enabledTab
  for seg in tostring(S().selected):gmatch("[^\001]+") do node = node and node.args and node.args[seg] end
  local boxes = {}
  local stack, seen = { node }, {}
  while #stack > 0 do
    local t = table.remove(stack)
    if type(t) == "table" and not seen[t] then
      seen[t] = true
      if t.type == "input" and type(t.name) == "string" and (t.name:find("Extra aura IDs", 1, true)) and t.set then boxes[#boxes + 1] = t end
      for _, v in pairs(t) do if type(v) == "table" then stack[#stack + 1] = v end end
    end
  end
  check("D2 the rule's page has both Extra aura IDs boxes", #boxes == 2, #boxes)
  local text = "5, 7, 7, 9"; for i = 1, 33 do text = text .. ", " .. (100 + i) end
  for _, bx in ipairs(boxes) do bx.set(nil, text) end
  local want = list((ns.AuraIDList(5, text)))
  check("D2 both boxes store what the shared rule gives (7, 9, then 28 more; 30 in all)", list(r.buffAlt) == want and list(r.extra.list[1].alt) == want and #r.buffAlt == 30,
    list(r.buffAlt) .. " | " .. list(r.extra.list[1].alt))
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
        print(("PASS " if ok else "FAIL ") + str(name)[:1200])
        if not ok:
            bad += 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
