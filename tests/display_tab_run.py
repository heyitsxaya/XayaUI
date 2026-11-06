#!/usr/bin/env python3
"""Offline test (Options 0.6.3): the rule editor's tab order (Display | Trigger | Cues | Conditions | Actions | Load | Info), the Display
tab (the rule as the container of its cues: settings written to every display cue at once), the hover tooltip moved there, and the
open / close button (arg.xuiChevron) on trigger, cue, and condition headers instead of an arrow inside the title text.
Run: python3 tests/display_tab_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok) R[#R + 1] = { name, ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 3)
ns = rawget(_G, "XayaUI_NS")
check("settings window addon loaded", ns and ns.BuildOptionsTable ~= nil and ns.BuildDisplayTab ~= nil)
if not (ns and ns.BuildOptionsTable and ns.BuildDisplayTab) then return R end
local function rule(name, enabled) local r = ns.NewRule(); r.name = name; r.enabled = enabled; ns.NormalizeRule(r); return r end
ns.folders = {}
local A = rule("Shell", true); A.useBuff = true; A.buffID = 48707; A.buffState = "present"
ns.rules = { A }
local i1 = ns.NewCueRule(A, "icon"); local t1 = ns.NewCueRule(A, "text"); local s1 = ns.NewCueRule(A, "sound")
i1.visual.x, i1.visual.y = 10, -19
t1.visual.x, t1.visual.y = 30, 5
local OLD = rule("Old style", true); OLD.visual.enabled = true; OLD.visual.x = 7
ns.rules[#ns.rules + 1] = OLD
local built = ns.BuildOptionsTable()
-- find the rule's editor group (it sits in the Smart Categories tree and the Enabled lists; any copy will do)
local function find(t, want, depth)
  if type(t) ~= "table" or depth > 30 then return nil end
  if t.type == "group" and t.childGroups == "tab" and t.args and t.args.trigger and t.args.rule and t.args.load then
    local nm = type(t.name) == "function" and t.name() or t.name
    if nm == want then return t end
  end
  for _, v in pairs(t.args or {}) do local f = find(v, want, depth + 1); if f then return f end end
end
local G = find(built, "Shell", 0)
check("rule editor found", G ~= nil)
if not G then return R end
local a = G.args
local function ord(k) return a[k] and a[k].order end
check("tab order Display | Trigger | Cues | Conditions | Actions | Load | Info",
  ord("display") < ord("trigger") and ord("trigger") < ord("cues") and ord("cues") < ord("conditions") and ord("conditions") < ord("actions")
  and ord("actions") < ord("load") and ord("load") < ord("rule"))
check("Info is the last tab and named Info", a.rule.name == "Info" and a.display.name == "Display")
local D = a.display.args
check("Display lists the rule's two display cues (not the sound cue)", #ns.RuleDisplays(A) == 2 and D.shows.name():find("Icon 1", 1, true) and D.shows.name():find("Text 1", 1, true) and not D.shows.name():find("Sound", 1, true))
-- hover tooltip: one switch for every display cue
check("hover tooltip off at first", D.hoverTip.get() == false)
D.hoverTip.set(nil, true)
check("hover tooltip on writes every display cue", i1.visual.hoverTip == true and t1.visual.hoverTip == true and not s1.visual.hoverTip)
i1.visual.hoverTip = false
check("mixed state: box unticked and the note says 1 of 2", D.hoverTip.get() == false and D.hoverMixed.hidden() == false and D.hoverMixed.name():find("1 of 2", 1, true))
D.hoverTip.set(nil, true)
local n0 = #ns.CuesOf(A)
D.add.set(nil, "texture")
local newC = ns.CuesOf(A)[n0 + 1]
check("Add a display cue > Texture adds a texture cue that takes the hover tooltip", newC and newC.cueKind == "texture" and newC.visual.hoverTip == true)
-- position as a group: the first display is the reference, all move by the same amount
D.posX.set(nil, 25)
check("X moves every display by the same amount (spacing kept)", i1.visual.x == 25 and t1.visual.x == 45)
D.posY.set(nil, -9)
check("Y moves every display by the same amount", i1.visual.y == -9 and t1.visual.y == 15)
check("the sliders show the first display's numbers", D.posX.get() == 25 and D.posY.get() == -9)
-- opacity
D.alpha.set(nil, 0.4)
check("opacity written to every display cue", i1.visual.alpha == 0.4 and t1.visual.alpha == 0.4 and newC.visual.alpha == 0.4)
check("no 'different opacities' note when they agree", D.lookMixed.hidden() == true)
t1.visual.alpha = 0.9
check("note shows when they differ", D.lookMixed.hidden() == false)
-- an older rule (own display, no cues) counts as one display
local GO = find(built, "Old style", 0)
check("older rule: its own display is the one display", GO and #ns.RuleDisplays(OLD) == 1 and ns.RuleDisplays(OLD)[1] == OLD)
-- a rule with no display cue: the tab offers the add buttons only
local E = rule("Empty", true); ns.rules[#ns.rules + 1] = E
local DE = ns.BuildDisplayTab(E, function() end, function() end).args
check("no displays: shared settings hidden, the add dropdown shown (one control, not a row of buttons)", DE.hoverTip.hidden() == true and DE.posX.hidden() == true and DE.add ~= nil and DE.add.type == "select" and DE.add_icon == nil)
check("the add dropdown shares its row with the cue list (both 'normal' width)", D.add.width == "normal" and D.shows.width == "normal")
-- open / close buttons: trigger pane header and cue header carry arg.xuiChevron and no arrow glyph in the title (skin on)
local trig = a.trigger.args
local foundChev, glyph = false, false
local function scan(t, depth)
  if type(t) ~= "table" or depth > 12 then return end
  if t.type == "execute" and type(t.arg) == "table" and type(t.arg.xuiChevron) == "function" then
    foundChev = true
    local nm = type(t.name) == "function" and t.name() or t.name
    if type(nm) == "string" and nm:find("|T", 1, true) then glyph = true end
  end
  for _, v in pairs(t.args or {}) do scan(v, depth + 1) end
end
scan(a.trigger, 0)
check("trigger headers have an open / close button", foundChev)
check("trigger header titles carry no arrow glyph with the skin on", not glyph)
foundChev, glyph = false, false
scan(a.cues, 0)
check("cue headers have an open / close button", foundChev)
check("cue header titles carry no arrow glyph with the skin on", not glyph)
-- the hover tooltip box is gone from each cue's own options (it lives on the Display tab)
local hidden = nil
local function findHover(t, depth)
  if type(t) ~= "table" or depth > 14 then return end
  if t.type == "toggle" and t.name == "Show tooltip on hover" then hidden = t.hidden end
  for _, v in pairs(t.args or {}) do findHover(v, depth + 1) end
end
findHover(a.cues, 0)
check("per-cue 'Show tooltip on hover' is hidden", hidden == true)
-- ===== Group Display tab (0.6.4): every display cue of every rule in the group, edited live =====
ns.folders = { { id = "fG", name = "Group G", cType = "dynamic" }, { id = "fN", name = "Nested", parent = "fG" } }
local P1 = rule("P1", true); P1.folder = "fG"; ns.rules[#ns.rules + 1] = P1
local P2 = rule("P2", true); P2.folder = "fN"; ns.rules[#ns.rules + 1] = P2
local c1 = ns.NewCueRule(P1, "icon"); local c2 = ns.NewCueRule(P1, "text"); local c3 = ns.NewCueRule(P2, "icon"); local cs = ns.NewCueRule(P2, "sound")
c1.visual.w, c2.visual.w, c3.visual.w = 30, 128, 40
local function fr(fid) local out = {}; local function inF(id) while id do if id == fid then return true end; local f; for _, x in ipairs(ns.folders) do if x.id == id then f = x end end; id = f and f.parent end return false end
  for _, r in ipairs(ns.rules) do if r.folder and inF(r.folder) then out[#out + 1] = r end end return out end
local GA = ns.GroupDisplayArgs(ns.folders[1], fr, function() end)
local function body(sec) return GA[sec].args.body.args end
check("group display: the old Apply Text Settings panel is gone (no Apply button)", GA.apply == nil and GA.targets == nil)
check("group display: scope line counts 3 displays in 2 rules (nested group included, sound cue not a display)", GA.scope.name():find("3 displays in 2 rules", 1, true) ~= nil)
local S = body("size")
check("size shows the first display's width", S.w.get() == 30)
check("differing widths are named under the section", S.diff.hidden() == false and S.diff.name():find("Display width", 1, true))
S.w.set(nil, 36)
check("width written to every display cue in the group (nested too)", c1.visual.w == 36 and c2.visual.w == 36 and c3.visual.w == 36)
check("no 'differs' line once they agree", S.diff.hidden() == true)
local BD = body("border")
BD.bdColor.set(nil, 1, 0, 0, 1)
check("a color is written as each display's own table (never one shared table)", c1.visual.border.color ~= c2.visual.border.color and c1.visual.border.color[1] == 1 and c3.visual.border.color[1] == 1)
local T = body("textDur")
T.enabled.set(nil, true)
check("duration text switched on for every display", c1.visual.text.enabled == true and c2.visual.text.enabled == true and c3.visual.text.enabled == true)
T.size.set(nil, 17)
check("text size for every display", c1.visual.text.size == 17 and c3.visual.text.size == 17)
local A = body("textAbs")
A.source.set(nil, "aura")
check("shield amount source for every display", c1.visual.absorb.source == "aura" and c3.visual.absorb.source == "aura")
local Bh = body("behavior")
Bh.hoverTip.set(nil, true)
check("hover tooltip for every display in the group", c1.visual.hoverTip and c2.visual.hoverTip and c3.visual.hoverTip and not cs.visual.hoverTip)
P2.editLocked = true
local GL = ns.GroupDisplayArgs(ns.folders[1], fr, function() end)
local wBefore = c3.visual.w
GL.size.args.body.args.w.set(nil, 50)
check("an edit-locked rule is left out of group edits and the scope line says so", c3.visual.w == wBefore and c1.visual.w == 50 and GL.scope.name():find("1 edit-locked rule is left out", 1, true) ~= nil)
P2.editLocked = nil
local GE = ns.GroupDisplayArgs({ id = "fEmpty", name = "Empty" }, function() return {} end, function() end)
check("a group with no displays hides every section and says why", GE.size.hidden() == true and GE.scope.name():find("nothing to style", 1, true) ~= nil)
-- the real group page: Display tab built from these pieces, Apply Text panel gone
local built2 = ns.BuildOptionsTable()
local function findG(t, depth)
  if type(t) ~= "table" or depth > 30 then return nil end
  if t.type == "group" and t.args and t.args.pageDisplay and t.args.tabDisplay then
    local nm = type(t.name) == "function" and t.name() or t.name
    if tostring(nm):find("Group G", 1, true) then return t end
  end
  for _, v in pairs(t.args or {}) do local x = findG(v, depth + 1); if x then return x end end
end
local GP = findG(built2, 0)
local PD = GP and GP.args.pageDisplay.args
-- #370 (Xaya 2026-11-04: the group page's top-row controls "should be tabs, not buttons"): marked for the skin's tab look, one picked
local TG, TD, TL = GP and GP.args.tabGroup, GP and GP.args.tabDisplay, GP and GP.args.tabLoad
check("group page tabs: Group, Display and Load carry the tab marker for the skin", TG and TD and TL and TG.arg and TG.arg.xuiTab == true
  and TD.arg.xuiTab == true and TL.arg.xuiTab == true)
check("group page tabs: Group is picked at first, the others are not", TG.arg.xuiTabSel() == true and TL.arg.xuiTabSel() == false)
TL.func()
check("group page tabs: clicking Load picks Load (and Group is no longer picked)", TL.arg.xuiTabSel() == true and TG.arg.xuiTabSel() == false)
check("group page tabs: with the skin on, the picked label has no color code (the skin colors it as a selected tab)",
  TL.name() == "Load" and TG.name() == "Group")
CueRulesDB.ui = CueRulesDB.ui or {}; CueRulesDB.ui.skinOff = true
check("group page tabs: with the skin off, the picked tab's label is gold", TL.name() == "|cffffd100Load|r" and TG.name() == "Group")
CueRulesDB.ui.skinOff = nil
TG.func()
-- Xaya 2026-11-04: "Pause preview animations" moves from the Group tab to the Display tab
local PG = GP and GP.args.pageGroup.args
check("pause preview: the tick box is on the group's Display tab, near the top", PD ~= nil and PD.pausePv ~= nil and PD.pausePv.type == "toggle"
  and PD.pausePv.name == "Pause preview animations" and PD.pausePv.order < 1)
check("pause preview: the Group tab no longer has it", PG and PG.pausePv == nil)
-- Group page round (Options, Xaya 2026-11-06: "tabs Group | Display | Load | Config (Group first)", "Delete / New / Enable on Config",
-- "strata / opacity / scale on Group", "icon size on Group"; CHAT-3d: "config includes folder name, folder type, and original
-- character / source of creation. Also includes enable/disable toggle")
local TC = GP and GP.args.tabConfig
check("group page tabs: Group | Display | Load | Config, in that order", TC and TC.arg and TC.arg.xuiTab == true and TG.order < TD.order and TD.order < TL.order and TL.order < TC.order)
local PC = GP and GP.args.pageConfig and GP.args.pageConfig.args
check("Config: name, Enabled toggle, Sound Channel Override, + New rule, + Nested group, Delete, where it came from", PC and PC.name and PC.enabled
  and PC.enabled.type == "toggle" and PC.soundChannel and PC.soundChannel.name == "Sound Channel Override" and PC.newRule and PC.newSub and PC.deleteTop
  and PC.origin and PC.enableAll == nil and PC.disableAll == nil)
check("  ...the group type (static / dynamic) is on Config", PC and PC.ctype_1 and PC.ctype_2 and PC.typeHdr)
check("  ...and none of them is left on the Group tab", PG and PG.name == nil and PG.newRule == nil and PG.deleteTop == nil and PG.enableAll == nil and PG.soundChannel == nil)
local GPC = PG and PG.container and PG.container.args
check("Group tab: the group's opacity, scale and layer (strata) are there now", GPC and GPC.alpha and GPC.scale and GPC.strata)
check("#372 position: Relative to and both points sit label-left, dropdown-right, one row each", GPC and GPC.rel.arg and GPC.rel.arg.xuiSide
  and GPC.point.arg.xuiSide and GPC.relPoint.arg.xuiSide and GPC.rel.width == "full" and GPC.point.width == "full" and GPC.relPoint.width == "full")
check("  ...and the every-display size", PG and PG.size ~= nil and PD.size == nil)
local nf = ns.NewFolder("Origin test")
check("a new group records who made it and how (made here, with the date)", nf.origin and nf.origin.how == "made" and type(nf.origin.at) == "number"
  and (nf.origin.by == nil or type(nf.origin.by) == "string"))
check("  ...an origin read from other data is plain text only (no colour or link codes)", ns.CleanOrigin({ by = "|cffff0000Evil|r-Realm", how = "made" }).by == "cffff0000Evilr-Realm"
  and ns.CleanOrigin({ by = 5 }) == nil and ns.CleanOrigin("x") == nil)
check("Config: who made it (a group from before the record says so)", type(PC.origin.name()) == "string" and PC.origin.name():find("Made by", 1, true) ~= nil, PC.origin.name())
local pvBefore = ns.previewPaused
local PV = PD and PD.pausePv
if PV then PV.set(nil, true) end
check("pause preview: ticking it on the Display tab pauses the previews", PV ~= nil and ns.previewPaused == true and PV.get() == true)
if PV then PV.set(nil, false) end
check("pause preview: unticking resumes them", PV ~= nil and not ns.previewPaused)
ns.SetPreviewPaused(pvBefore)
-- dynamic group wrap options (Xaya: "dynamic groups should have row / column wrap options")
local CG = GP and GP.args.pageGroup.args.container and GP.args.pageGroup.args.container.args
local fG = ns.folders[1]
check("wrap: a 'Wrap into rows' tick box exists for a dynamic group growing across", CG and CG.wrapOn and CG.wrapOn.type == "toggle" and CG.wrapOn.name() == "Wrap into rows" and CG.wrapOn.hidden() == false)
check("wrap: off by default, per-row count hidden until ticked", CG.wrapOn.get() == false and CG.wrapN.hidden() == true)
CG.wrapOn.set(nil, true)
check("wrap: ticking it wraps after 6 and shows the count and 'New rows go'", fG.cWrapN == 6 and CG.wrapN.hidden() == false and CG.wrapDir.hidden() == false and CG.wrapN.name() == "Items per row")
CG.wrapN.set(nil, 9)
check("wrap: the count is saved", fG.cWrapN == 9)
fG.cGrowth = "DOWN"
check("wrap: growing down it reads 'Wrap into columns' / 'Items per column' / 'New columns go'", CG.wrapOn.name() == "Wrap into columns" and CG.wrapN.name() == "Items per column" and CG.wrapDir.name() == "New columns go")
CG.wrapOn.set(nil, false)
-- (Options 0.6.50; Xaya 2026-11-04: "a sort order option for rules in a dynamic group: default, expiration, name, important, manual")
check("sort: the dynamic group's Sort lists her five in her order, with her words (Default, Expiration, Name, Important, Manual)",
  CG.sort and table.concat(CG.sort.sorting, ",") == "default,expiration,name,important,manual"
  and CG.sort.values.default == "Default" and CG.sort.values.expiration == "Expiration" and CG.sort.values.name == "Name"
  and CG.sort.values.important == "Important" and CG.sort.values.manual == "Manual")
check("wrap: unticking removes the wrap", fG.cWrapN == nil and CG.wrapN.hidden() == true)
check("layout dropdowns no longer take a whole row each (no 'double' width)", CG.growth.width == nil and CG.sort.width == nil and CG.wrapDir.width == nil)
-- Rules sub-tabs (Xaya, 0.6.4): Smart Categories | Enabled | Disabled | Drafts, Enabled opens by default, the last one is remembered
local RT = built2.args.cooldowns.args
check("sub-tab order: Smart Categories, Enabled, Disabled, Drafts", RT.smartTab.order < RT.enabledTab.order and RT.enabledTab.order < RT.disabledTab.order and (not RT.draftsTab or RT.disabledTab.order < RT.draftsTab.order))
CueRulesDB.ui = CueRulesDB.ui or {}
CueRulesDB.ui.rulesSub = nil
pcall(ns.ToggleUI); W.tick(0.1, 4)
check("first opening with nothing remembered: Enabled is open", ns.CurrentSub() == "enabledTab", ns.CurrentSub())
local ACD = LibStub("AceConfigDialog-3.0")
pcall(ACD.SelectGroup, ACD, "CueRules", "cooldowns", "smartTab"); W.tick(0.1, 4)
check("the open sub-tab is remembered while the window is open (saved for the next opening)", CueRulesDB.ui.rulesSub == "smartTab", tostring(CueRulesDB.ui.rulesSub))
pcall(ns.ToggleUI); W.tick(0.1, 2)
-- ===== Drafts (Xaya, 0.6.4): the tab is always there; off = description + switch; settings under Settings > Rule Creation =====
CueRulesDB.ui.promptSave = nil
CueRulesDB.drafts = {}
local b3 = ns.BuildOptionsTable()
local DT = b3.args.cooldowns.args.draftsTab
local function hid(o) local h = o and o.hidden; if type(h) == "function" then return h() end; return h and true or false end
check("drafts: tab shown even with drafts off and none stored", DT and not hid(DT))
check("drafts off: a description pane says what drafts do", DT.args.about and not hid(DT.args.about) and DT.args.about.name():find("Drafts are off") ~= nil and DT.args.about.name():find("Save changes") ~= nil)
check("drafts off: the switch reads 'Turn drafts on'", DT.args.toggle and DT.args.toggle.type == "execute" and DT.args.toggle.name() == "Turn drafts on")
check("drafts off: no empty list text and no list intro", hid(DT.args.intro) and hid(DT.args.none))
check("drafts: a 'Draft settings' button exists", DT.args.settings and DT.args.settings.type == "execute")
check("drafts: switch and settings are compact buttons (no width / not full)", DT.args.toggle.width == nil and DT.args.settings.width == nil)
DT.args.toggle.func()
check("drafts: the switch turns drafts on", ns.DraftsEnabled() == true and DT.args.toggle.name() == "Turn drafts off" and DT.args.about.name():find("Drafts are on") ~= nil)
check("drafts on: list intro and 'No drafts.' shown", not hid(DT.args.intro) and not hid(DT.args.none))
local SR = b3.args.settings.args.rules.args
check("settings: Use drafts toggle follows the same switch", SR.promptSave.get() == true)
check("settings: Keep up to (5 to 100, default 30)", SR.draftsMax and SR.draftsMax.min == 5 and SR.draftsMax.max == 100 and SR.draftsMax.get() == 30)
check("settings: confirm discard / confirm delete / chat notice, all on by default", SR.draftsConfirmDiscard.get() and SR.draftsConfirmDelete.get() and SR.draftsCloseNotice.get())
for i = 1, 12 do table.insert(CueRulesDB.drafts, { id = "x" .. i, uid = "x" .. i, name = "D" .. i, ts = i, rules = {} }) end
SR.draftsMax.set(nil, 8)
check("settings: lowering 'Keep up to' trims the oldest drafts at once", #CueRulesDB.drafts == 8 and CueRulesDB.drafts[1].id == "x1", #CueRulesDB.drafts)
check("drafts intro states the chosen number", DT.args.intro.name():find("Up to 8 drafts") ~= nil)
SR.draftsMax.set(nil, 500)
check("settings: 'Keep up to' is clamped to 100", ns.DraftsMax() == 100)
SR.draftsConfirmDelete.set(nil, false)
local b4 = ns.BuildOptionsTable()
local d1 = b4.args.cooldowns.args.draftsTab.args.d1
check("confirm deleting a draft off: Delete asks nothing", d1 and d1.args.delete.confirm() == false)
SR.draftsConfirmDelete.set(nil, true)
check("confirm deleting a draft on: Delete asks first", d1.args.delete.confirm() == true)
SR.draftsConfirmDiscard.set(nil, false)
check("confirm discard off: setting read by the save bar", ns.DraftsConfirmDiscard() == false)
SR.draftsConfirmDiscard.set(nil, true)
DT.args.toggle.func()
check("drafts: the switch turns them off again; stored drafts stay listed", ns.DraftsEnabled() == false and #CueRulesDB.drafts == 8 and not hid(DT.args.intro))
check("settings: the finer draft settings gray out while drafts are off (delete confirm stays usable for leftovers)", SR.draftsMax.disabled() == true and SR.draftsConfirmDiscard.disabled() == true and SR.draftsCloseNotice.disabled() == true and SR.draftsConfirmDelete.disabled == nil)
CueRulesDB.drafts = {}
CueRulesDB.ui.draftsMax = nil
check("group page Display tab has the every-display sections (size now on Group), no Apply Text panel, no whole-group box", PD and PD.placement == nil and PD.textDur and PD.textCnt and PD.textAbs and PD.applyText == nil)
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
        if not ok:
            bad += 1
            print("FAIL:", name)
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
