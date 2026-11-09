#!/usr/bin/env python3
"""In-game QA walkthrough for the right-click menu on several selected rules (XayaUI_DevAssist/QAWalks-merge-rules.lua; QA B370-B375;
Rules Options 0.6.82; REQUEST-LOG-session-014bN6tUDLJ6T742DewZDg1s.md rows 19, 23, 27 and the review of the row 20 fix). Her words: row 23
"should be able to right click multi delete"; row 19 "I want to be able to merge these into one rule that tracks all of these auras and
fires based if any are found by right clicking on them when multi-selected and choose \"merge rules\"". Xaya's rule V22 (2026-11-07):
"make sure every feature or significant change to the codebase / bug report fixes have an in game qa test walk through with pre-fill
confirmation options or data capturing".
Loads the real addons (with XayaUI Dev Assist) in the stand-in game and runs each step as a player would (Do it for me, her clicks in the
real sidebar and right-click menu, the question's Yes, Check):
  - registered with pre-fill for B370-B375; the last step is a Done step;
  - step 1: before Do it for me / before the delete: not tested (nil); after Delete 2 Selected > Yes: Pass; negative: one rule put back
    from the bin gives Fail;
  - step 2: before the delete: not tested; right-click > Delete > Yes in Rules > Disabled: Pass, "Rules > Disabled" in the note;
    negative: the list switched to Enabled gives Fail;
  - step 3: before the merge: not tested; Merge 4 Selected > Yes on QA Aura C: Pass with the 4 extra aura IDs in the note; negative: an ID
    taken out gives Fail;
  - step 4: no aura on: Pass ("FALSE"); one of the auras on (the game's aura reader stubbed): Pass ("TRUE"); negative: the trigger reading
    FALSE with an aura on gives Fail;
  - step 5: before the merge: not tested; after Merge 4 Selected > Yes: Pass (present, missing 21562 + 6673, cooldown 6603, ANY);
  - step 6: before the right-click: not tested; Merge 2 Selected: refused, Pass with the chat line in the note; nothing changed;
  - Done: the group, its rules and the walkthrough's Recycle Bin items are gone; her own bin item stays; ns.Print is hers again.
Run: python3 tests/qa_walks_merge_rules_run.py"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

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
local QA = rawget(_G, "XayaUI_DevQA")
local def = QA and QA.walks["merge-rules"]
check("the merge walkthrough is registered with pre-fill, for B370-B375", def ~= nil and def.prefill == true and def.qa == "B370, B371, B372, B373, B374, B375")
if not def then return end
check("its last step is a Done step", def.steps[#def.steps].done == true)
local herPrint = function() end
ns.Print = herPrint
CueRulesDB.ui = CueRulesDB.ui or {}; CueRulesDB.ui.consoleAutoOpen = false
if ns.LoadOptions then ns.LoadOptions() end
-- her own rules around the test group, and one item of hers in the Recycle Bin
local hers = ns.NewFolder("Defensives")
for i = 1, 30 do
  local r = ns.NewRule(); r.name = ("Mine %02d"):format(i); r.enabled = true; r.useBuff, r.buffID, r.buffState = true, 3000 + i, "present"
  r.visual.enabled, r.sound.enabled = false, false; r.folder = (i <= 20) and hers.id or nil
  ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
end
local mine1 = ns.rules[#ns.rules]
ns.RecycleRule(mine1)
local binBefore = #ns.RecycleDB().items
local pop
StaticPopup_Show = function(which, text, _, data) pop = { which = which, text = text, data = data }; return CreateFrame("Frame") end
local function yes() local p = pop; pop = nil; if p then StaticPopupDialogs[p.which].OnAccept(nil, p.data) end; W.tick(0.05, 6) end
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
local T = QA.MergeRulesTest
local function tree()
  local s = ns.RulesTreeStatus()
  local function find(w) if type(w) ~= "table" then return end; if w.type == "TreeGroup" and w.status == s then return w end; for _, c in ipairs(w.children or {}) do local f = find(c); if f then return f end end end
  return find(LibStub("AceConfigDialog-3.0").OpenFrames.CueRules)
end
local function row(rule)
  for _, b in ipairs(tree() and tree().buttons or {}) do
    local n = tonumber(tostring(b.uniquevalue or ""):match("rule(%d+)$"))
    if b:IsShown() and n and ns.rules[n] == rule then return b end
  end
end
local function ctrl(rules)
  IsControlKeyDown = function() return true end
  for _, r in ipairs(rules) do local b = row(r); if b then b:Click("LeftButton"); W.tick(0.05, 3) end end
  IsControlKeyDown = function() return false end
end
local function right(rule, label) menu = {}; local b = row(rule); if b then b:Click("RightButton") end; local f = menu[label]; if f then f() end; return f ~= nil end
local function run(i) local s = def.steps[i]; if s.setup then s.setup() end; W.tick(0.1, 8) end
local N = T.Named

-- step 1: Delete 2 Selected
local s1 = def.steps[1]
check("step 1 before Do it for me: not tested (no verdict)", s1.check() == nil)
run(1)
local d1, d2 = N("QA delete me 1"), N("QA delete me 2")
check("step 1's Do it for me: the group QA merge rules with the two rules, both on screen", T.TestGroup() ~= nil and d1 and d2 and row(d1) ~= nil and row(d2) ~= nil)
check("step 1 before the delete: not tested", s1.check() == nil)
ctrl({ d1, d2 })
check("step 1: the menu offers Delete 2 Selected", right(d2, "Delete 2 Selected"))
yes()
local ok1, n1 = s1.check()
check("step 1 after Delete 2 Selected > Yes: Pass, one bin item each, nothing selected", ok1 == true and has(n1, "one item each") and has(n1, "Selected now: 0"), n1)
do   -- negative: one of them back from the bin
  local it = T.InBin(d1)
  ns.RecycleRestore(it.id)
  local okn, nn = s1.check()
  check("step 1 negative: a rule that is not in the bin gives Fail", okn == false, tostring(okn) .. " " .. tostring(nn))
  ns.RecycleRules({ d1 })
end

-- step 2: a delete in Rules > Disabled
local s2 = def.steps[2]
run(2)
local t10 = N("QA disabled 10")
check("step 2's Do it for me: Rules > Disabled open, QA disabled 10 open and on screen", ns.CurrentSub() == "disabledTab" and ns.SelectedRuleForUndo() == t10 and row(t10) ~= nil)
check("step 2 before the delete: not tested", s2.check() == nil)
check("step 2: right-click > Delete", right(t10, "Delete"))
yes()
local ok2, n2 = s2.check()
check("step 2 after right-click > Delete > Yes: Pass, Rules > Disabled stays, the rows do not move", ok2 == true and has(n2, "Open list: Rules > Disabled") and has(n2, "none moved"), n2)
do   -- negative: the list switched to Enabled > Loaded
  LibStub("AceConfigDialog-3.0"):SelectGroup("CueRules", "cooldowns", "enabledTab", "loaded"); W.tick(0.05, 4)
  local okn, nn = s2.check()
  check("step 2 negative: Enabled > Loaded open after the delete gives Fail", okn == false, tostring(okn) .. " " .. tostring(nn))
end

-- step 3: Merge 4 Selected on QA Aura C
local s3 = def.steps[3]
run(3)
local A, B, C, D = N("QA Well Fed A"), N("QA Well Fed B"), N("QA Aura C"), N("QA Aura D")
check("step 3's Do it for me: the four aura rules on screen", A and B and C and D and row(A) and row(B) and row(C) and row(D) and true or false)
check("step 3 before the merge: not tested", s3.check() == nil)
ctrl({ A, B, C, D })
check("step 3: right-click QA Aura C offers Merge 4 Selected", right(C, "Merge 4 Selected"))
check("step 3: the question names QA Aura C and the 5 auras", pop and has(pop.text, "into 'QA Aura C' (the rule you right-clicked)") and has(pop.text, "Aura PRESENT (any one of 5)"), pop and pop.text)
yes()
local ok3, n3 = s3.check()
check("step 3 after Yes: Pass, the 4 extra aura IDs, 1 trigger, own display kept, 3 in the bin", ok3 == true and has(n3, "extra aura IDs 104273, 104280, 104281, 1233712") and has(n3, "kept")
  and has(n3, "3 of 3"), n3)
do   -- negative: an ID missing
  local keep = C.buffAlt; C.buffAlt = { 104273, 104280 }
  local okn = s3.check()
  check("step 3 negative: an aura missing from the merged trigger gives Fail", okn == false)
  C.buffAlt = keep
end

-- step 4: fires on any
local s4 = def.steps[4]
local on = {}
local bp = ns.BuffPresent
ns.BuffPresent = function(id) if on[id] then return true, "test", { applications = 1 } end; return false, "test" end
W.tick(0.1, 1)
local ok4, n4 = s4.check()
check("step 4 nothing on: Pass, FALSE", ok4 == true and has(n4, "FALSE"), n4)
on[104281] = true; W.tick(0.1, 1)
local ok4b, n4b = s4.check()
check("step 4 one of the auras (104281) on: Pass, TRUE", ok4b == true and has(n4b, "TRUE") and has(n4b, "104281"), n4b)
do   -- negative: the rule's trigger reads FALSE although an aura is on
  local ev = ns.Evaluate
  ns.Evaluate = function(r, ctx) local a, info = ev(r, ctx); if r == C then info.trigOK = false end; return a, info end
  local okn = s4.check()
  check("step 4 negative: FALSE with an aura on gives Fail", okn == false)
  ns.Evaluate = ev
end
ns.BuffPresent = bp

-- step 5: present + missing + cooldown
local s5 = def.steps[5]
run(5)
local mp, m1, m2, mc = N("QA Mix present"), N("QA Mix missing 1"), N("QA Mix missing 2"), N("QA Mix cooldown")
check("step 5 before the merge: not tested", s5.check() == nil)
ctrl({ mp, m1, m2, mc })
check("step 5: right-click QA Mix present > Merge 4 Selected", right(mp, "Merge 4 Selected"))
check("step 5: the question lists 3 triggers", pop and has(pop.text, "Aura MISSING (all 2 absent)") and has(pop.text, "3. Cooldown"), pop and pop.text)
yes()
local ok5, n5 = s5.check()
check("step 5 after Yes: Pass (present 1459; missing 21562 + 6673; cooldown 6603 ready; ANY)", ok5 == true and has(n5, "missing 21562 + 6673") and has(n5, "ANY trigger"), n5)

-- step 6: refused
local s6 = def.steps[6]
run(6)
local both, single = N("QA Both triggers"), N("QA Single")
check("step 6 before the right-click: not tested", s6.check() == nil)
ctrl({ both, single })
check("step 6: right-click QA Single > Merge 2 Selected", right(single, "Merge 2 Selected"))
check("step 6: no question", pop == nil)
local ok6, n6 = s6.check()
check("step 6: Pass, the chat line names QA Both triggers, both unchanged", ok6 == true and has(n6, "Merge: 'QA Both triggers' has 2 triggers") and has(n6, "unchanged"), n6)

-- Done
def.steps[#def.steps].setup(); W.tick(0.05, 6)
local left = 0
for _, r in ipairs(ns.rules) do if r.qaMergeRules then left = left + 1 end end
check("Done: the group and its rules are gone", T.TestGroup() == nil and left == 0, left)
check("Done: the walkthrough's Recycle Bin items are gone, hers stays", #ns.RecycleDB().items == binBefore and ns.RecycleDB().items[binBefore].name == mine1.name,
  #ns.RecycleDB().items .. " items, " .. binBefore .. " before")
check("Done: ns.Print is hers again", ns.Print == herPrint)
end)
if not okAll then check("the test ran to its end (a Lua error stopped it)", false, errAll) end
return R
end
'''


def main():
    folders = H.find_addons()
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in folders}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    bad = 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        print(("PASS " if ok else "FAIL ") + str(name)[:900])
        if not ok:
            bad += 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    return 1 if bad or errs else 0


if __name__ == "__main__":
    sys.exit(main())
