#!/usr/bin/env python3
"""In-game QA walkthrough for deleting from the Rules sidebar (XayaUI_DevAssist/QAWalks-sidebar-delete.lua; QA B320-B323; Rules Options
0.6.82, Options 0.6.106; REQUEST-LOG-session-014bN6tUDLJ6T742DewZDg1s.md row 20, her words: "deleting auras shifts the rule sidebar up
still and right clicking to delete does not get detected to remove the menu from the top"). Xaya's rule V22 (2026-11-07): "make sure
every feature or significant change to the codebase / bug report fixes have an in game qa test walk through with pre-fill confirmation
options or data capturing".
Loads the real addons (with XayaUI Dev Assist) in the stand-in game and runs each step as a player would (Do it for me, her clicks, Check):
  - registered with pre-fill for B320-B323; the last step is a Done step;
  - step 1 before Do it for me: not tested (nil); after it, before the delete: not tested; after right-click > Delete > Yes: Pass with
    the scroll position and the rows in the note; negative: the list moved after the delete gives Fail;
  - step 2: nothing selected: not tested; three Ctrl+clicked: Pass, "Delete (3) | Move (3) | Deselect (3)";
  - step 3: before a delete: not tested; one deleted by right-click: Pass, the bar reads (2); negative: a bar still reading (3) gives Fail;
  - step 4: the other two deleted: Pass, the bar is gone, the search box is back;
  - step 5: Do it for me opens QA delete 20; the Delete key > Yes: Pass;
  - Done: the group, its rules and the walkthrough's Recycle Bin items are gone; nothing else in the bin is touched.
Run: python3 tests/qa_walks_sidebar_delete_run.py"""
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
local def = QA and QA.walks["sidebar-delete"]
check("the sidebar delete walkthrough is registered with pre-fill, for B320-B323", def ~= nil and def.prefill == true and def.qa == "B320, B321, B322, B323")
if not def then return end
check("its last step is a Done step", def.steps[#def.steps].done == true)
ns.Print = function() end
CueRulesDB.ui = CueRulesDB.ui or {}; CueRulesDB.ui.consoleAutoOpen = false
-- some rules of her own around the test group (the list is long, as hers: LOADED (86)), and one item of hers in the Recycle Bin
if ns.LoadOptions then ns.LoadOptions() end
local hers = ns.NewFolder("Defensives")
for i = 1, 40 do
  local r = ns.NewRule(); r.name = ("Mine %02d"):format(i); r.enabled = true; r.useBuff, r.buffID, r.buffState = true, 3000 + i, "present"
  r.visual.enabled, r.sound.enabled = false, false; r.folder = (i <= 30) and hers.id or nil
  ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
end
do   -- her group is open in the list (the window remembers it)
  local AC = LibStub("AceConfigDialog-3.0")
  local st = AC:GetStatusTable("CueRules", { "cooldowns", "enabledTab" }); st.groups = st.groups or {}; st.groups.groups = st.groups.groups or {}
  st.groups.groups["loaded\001" .. hers.id] = true
end
local mine1 = ns.rules[#ns.rules]
ns.RecycleRule(mine1)
local binBefore = #ns.RecycleDB().items
-- the confirm popup is answered Yes by the test; the right-click menu's buttons by label
local pop
StaticPopup_Show = function(which, text, _, data) pop = { which = which, data = data }; return CreateFrame("Frame") end
local function yes() local p = pop; pop = nil; if p then StaticPopupDialogs[p.which].OnAccept(nil, p.data) end end
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
local T = QA.SidebarDeleteTest
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
local function rightDelete(rule) menu = {}; local b = row(rule); if b then b:Click("RightButton") end; if menu["Delete"] then menu["Delete"]() end; yes(); W.tick(0.05, 6) end
local function byName(n) for _, r in ipairs(ns.rules) do if r.name == n then return r end end end

-- step 1: right-click > Delete > Yes on the open rule
local s1 = def.steps[1]
check("step 1 before Do it for me: not tested (no verdict)", s1.check() == nil)
s1.setup(); W.tick(0.1, 6)
local g = T.TestGroup()
check("step 1's Do it for me: the group QA sidebar delete with 30 rules, the window open on the list, QA delete 10 open",
  g ~= nil and #T.TestRules() == 30 and ns.SelectedRuleForUndo() == byName("QA delete 10") and row(byName("QA delete 10")) ~= nil,
  tostring(#T.TestRules()))
local ok0, n0 = s1.check()
check("step 1 before the delete: not tested, it says what to do", ok0 == nil and has(n0, "still there"), n0)
rightDelete(byName("QA delete 10"))
local ok1, n1 = s1.check()
check("step 1 after right-click > Delete > Yes: Pass, the scroll position and the rows in the note (the list was scrolled)", ok1 == true and has(n1, "none moved") and has(n1, "QA delete 11")
  and not has(n1, "Scroll position 0 "), n1)
do   -- negative: the list jumped to the top after the delete
  local t = tree(); local v = ns.RulesTreeStatus().scrollvalue
  t.scrollbar:SetValue(0); W.tick(0.05, 2)
  local okn, nn = s1.check()
  check("step 1 negative: the list moved after the delete gives Fail", okn == false and has(nn, "moved:"), tostring(okn) .. " " .. tostring(nn))
  t.scrollbar:SetValue(v); W.tick(0.05, 2)
end

-- step 2: three selected
local s2 = def.steps[2]
check("step 2 with nothing selected: not tested (no verdict)", s2.check() == nil)
local picked = { byName("QA delete 12"), byName("QA delete 14"), byName("QA delete 15") }
IsControlKeyDown = function() return true end
for _, r in ipairs(picked) do local b = row(r); if b then b:Click("LeftButton"); W.tick(0.05, 3) end end
IsControlKeyDown = function() return false end
local ok2, n2 = s2.check()
check("step 2 three Ctrl+clicked: Pass, the bar reads Delete (3) | Move (3) | Deselect (3)", ok2 == true and has(n2, "Delete (3) | Move (3) | Deselect (3)"), n2)

-- step 3: one of them deleted by right-click
local s3 = def.steps[3]
check("step 3 before a delete: not tested (no verdict)", s3.check() == nil)
rightDelete(picked[2])
local ok3, n3 = s3.check()
check("step 3 one deleted by right-click: Pass, the bar reads (2)", ok3 == true and has(n3, "Delete (2) | Move (2) | Deselect (2)"), n3)
do   -- negative: a bar still counting the deleted rule
  local bar = tree().xuiSelBar
  local t0 = bar.del:GetText(); bar.del:SetText("Delete (3)")
  local okn, nn = s3.check()
  check("step 3 negative: a bar still reading Delete (3) gives Fail", okn == false, tostring(okn) .. " " .. tostring(nn))
  bar.del:SetText(t0)
end

-- step 4: the other two deleted
local s4 = def.steps[4]
check("step 4 before the others are deleted: not tested (no verdict)", s4.check() == nil)
rightDelete(picked[1]); rightDelete(picked[3])
local ok4, n4 = s4.check()
check("step 4 the other two deleted: Pass, the bar is gone, the search box is back", ok4 == true and has(n4, "The bar is gone"), n4)

-- step 5: the Delete key on the open rule
local s5 = def.steps[5]
s5.setup(); W.tick(0.1, 6)
local r20 = byName("QA delete 20")
check("step 5's Do it for me opens QA delete 20 with the list on the group", ns.SelectedRuleForUndo() == r20 and row(r20) ~= nil)
check("step 5 before the delete: not tested (no verdict)", s5.check() == nil)
ns.DeleteKey(); yes(); W.tick(0.05, 6)
local ok5, n5 = s5.check()
check("step 5 after Delete > Yes: Pass", ok5 == true and has(n5, "none moved"), n5)

-- Done
def.steps[#def.steps].setup(); W.tick(0.05, 6)
local left = 0
for _, r in ipairs(ns.rules) do if r.qaSidebarDelete then left = left + 1 end end
check("Done: the group and its rules are gone", T.TestGroup() == nil and left == 0, left)
check("Done: the walkthrough's Recycle Bin items are gone, hers stays", #ns.RecycleDB().items == binBefore and ns.RecycleDB().items[binBefore] and ns.RecycleDB().items[binBefore].name == mine1.name,
  #ns.RecycleDB().items .. " items, " .. binBefore .. " before")
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
