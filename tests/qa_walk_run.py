#!/usr/bin/env python3
"""In-game QA walkthroughs (XayaUI_DevAssist 0.7.4, core 0.6.55). Xaya 2026-11-06 (standing rule): "For all things you need me to debug or
QA in game — wherever possible, design and implement a test script or walkthrough that fires in the game side ... All they should have to
do is open up /xui dev qa and pick an item and have the addon walk them through steps"; her answers: it lives in Dev Assist; "Check,
then ask to confirm"; results by screenshot, an export / import code and the saved file.
Checks, on the real addons (Dev Assist on) in the stand-in game:
- V14: no window until it is opened; /xui dev qa (and /xuidev qa) opens the list with every walkthrough and its status;
- a walkthrough: one step at a time; Do it for me runs its setup; the addon's own check is shown and never answers for the person;
  Pass / Fail / Skip with a note; Back; the end screen; the result is saved (no names or realms);
- the export code round-trips through Import; a code that is not ours, too long or carrying colour codes is refused or cleaned;
- the group walkthrough's last step deletes the QA test group it made.
Run: python3 tests/qa_walk_run.py   (Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local QA = rawget(_G, "XayaUI_DevQA")
local ns = rawget(_G, "XayaUI_NS")
check("Dev Assist has the QA walkthroughs", QA and QA.Register and QA.Toggle)
if not QA then return R end
check("V14: no window before it is opened", QA.Window() == nil and rawget(_G, "XayaUIDevQAWindow") == nil)
check("this session's walkthroughs are registered", QA.walks["group-page"] and QA.walks["group-box"] and QA.walks["group-nested"] and QA.walks["sidebar-drag"]
  and QA.walks["reskin-switches"] and QA.walks["shopping-list"])
ns.RunCommand("dev", "qa")
local Wn = QA.Window()
check("/xui dev qa opens the list", Wn and Wn:IsShown() and Wn.title:GetText() == "XayaUI QA walkthroughs")
local shown = 0
for _, r in ipairs(Wn.rows) do if r:IsShown() then shown = shown + 1 end end
check("  ...one row per walkthrough, each with its status", shown == #QA.list and Wn.rows[1].status:GetText():find("not run", 1, true) ~= nil, shown)
QA.Toggle()
check("  ...and closes again", not Wn:IsShown())
SlashCmdList.XAYAUIDEV("qa")
check("/xuidev qa opens it too", Wn:IsShown())
QA.Toggle(); ns.RunCommand("qa", "test")
check("/xui qa test opens it (Xaya's alias, FUS-9)", Wn:IsShown())
QA.Toggle(); ns.RunCommand("qatest", "")
check("/xui qatest opens it too", Wn:IsShown())

-- run the group page walkthrough
QA.Start("group-page")
local st = QA.State()
check("a walkthrough starts at step 1 with its text and Do it for me", st and st.i == 1 and Wn.text:GetText():find("Group, Display, Load, Config", 1, true) and Wn.doIt:IsShown())
check("  ...the addon's own check says what it sees (no test group yet) without answering (V22 pre-fill: \"The addon says Fail\", nothing recorded until Accept)", (Wn.check:GetText():find("Looks wrong", 1, true) ~= nil or Wn.check:GetText():find("The addon says Fail", 1, true) ~= nil) and st.steps[1] == nil, Wn.check:GetText())
QA.DoSetup(); W.tick(0.4, 3); QA.RunCheck()
local tg
for _, f in ipairs(ns.folders) do if f.name == "QA test group" then tg = f end end
check("Do it for me made the QA test group", tg ~= nil)
check("  ...and the check now looks right", (Wn.check:GetText():find("Looks right", 1, true) ~= nil or Wn.check:GetText():find("The addon says Pass", 1, true) ~= nil), Wn.check:GetText())
Wn.note:SetText("tabs |cffff0000look|r fine")
QA.Answer("P")
check("Pass moves to step 2 and keeps the note (colour codes removed)", st.i == 2 and st.steps[1].r == "P" and st.steps[1].note == "tabs cffff0000lookr fine", st.steps[1] and st.steps[1].note)
QA.Back()
check("Back returns to step 1 with its note", st.i == 1 and Wn.note:GetText() == "tabs cffff0000lookr fine")
QA.Answer("P"); QA.Answer("F"); QA.Answer("S"); QA.Answer("P")
check("at the cleanup step: Do it for me deletes the QA test group", st.i == 5)
QA.DoSetup(); W.tick(0.4, 2)
local still = false
for _, f in ipairs(ns.folders) do if f.name == "QA test group" then still = true end end
check("  ...gone", not still)
QA.Answer("P")
local res = QA.DB().results["group-page"]
check("the end screen: summary with passes, fails and skips", Wn.summary:GetText():find("3 passed, 1 failed, 1 skipped", 1, true) ~= nil, Wn.summary:GetText())
check("the result is saved in the Dev Assist file, without names or realms", res and #res.steps == 5 and res.steps[2].r == "F" and res.char == nil,
  res and ("%d steps: %s"):format(#res.steps, (function() local t = {}; for i, x in ipairs(res.steps) do t[i] = tostring(x.r) end; return table.concat(t, ",") end)()) or "no result")
check("Screenshot, Export code, Import a code and Run again are offered", Wn.shot:IsShown() and Wn.export:IsShown() and Wn.import:IsShown() and Wn.again:IsShown())
local shots = 0
local oldShot = Screenshot; Screenshot = function() shots = shots + 1 end
QA.Screenshot(); Screenshot = oldShot
check("Screenshot takes the game's screenshot with the results on screen", shots == 1)
QA.ShowCode()
local code = Wn.code:GetText()
check("Export code: a code starting XUIQA1: in a box ready to copy", code:sub(1, 7) == "XUIQA1:" and Wn.code:IsShown())
local back, why = QA.ImportCode(code)
check("  ...it imports back to the same results", back and back.id == "group-page" and #back.steps == 5 and back.steps[2].r == "F" and back.steps[1].note == res.steps[1].note, why)
QA.StartImport(); Wn.code:SetText(code); QA.FinishImport()
check("Import a code shows those results", Wn.title:GetText():find("Imported results", 1, true) ~= nil)
check("a code that is not ours is refused", QA.ImportCode("hello") == nil and QA.ImportCode("XUIQA1:" .. string.rep("A", 9000)) == nil)
local evil = "XUIQA1:aWQ9fGNmZmZmMDAwMHJlZApXPTA="   -- "id=|cffff0000red\nW=0"
local e = QA.ImportCode(evil)
check("  ...and what it carries is plain text only", e and e.id == "cffff0000red", e and e.id)
-- the walkthroughs made from docs/QA-CHECKLIST.md (Xaya 2026-11-06: "start with bugs, then UI items that don't impact usage")
local gen, firstGen = 0, nil
for _, id in ipairs(QA.list) do if QA.walks[id].generated then gen = gen + 1; firstGen = firstGen or id end end
check("the checklist walkthroughs are registered (one per chunk of open items)", gen >= 10, gen)
check("  ...the list starts with the open bugs to confirm", QA.list[1] == "chk-bugs" and firstGen == "chk-bugs", QA.list[1])
local look, combat
for i, id in ipairs(QA.list) do if id == "chk-look-1" then look = i elseif id == "chk-combat-1" then combat = combat or i end end
check("  ...then looks and layout before the combat displays", look and combat and look < combat, ("%s %s"):format(tostring(look), tostring(combat)))
QA.Start("chk-bugs")
check("  ...a generated step shows its text, with no Do it for me (nothing to set up)", Wn.text:GetText():find("Bug #", 1, true) ~= nil and not Wn.doIt:IsShown())
check("long step text sits in a scrolling box sized to the text", Wn.textScroll:IsShown() and Wn.textChild:GetHeight() >= 10)
for _ = 1, #QA.walks["chk-bugs"].steps do QA.Answer("S") end
local br = QA.DB().results["chk-bugs"]
check("  ...each answer is saved with its checklist item (steps shift when the list changes)", br and br.steps[1].k == QA.walks["chk-bugs"].steps[1].key and br.steps[1].k:find("^bug%d+$"), br and br.steps[1].k)
local bk = QA.ImportCode(QA.ExportCode("chk-bugs"))
check("  ...and the export code carries it", bk and bk.steps[1].k == br.steps[1].k and bk.steps[2].k == br.steps[2].k, bk and bk.steps[1].k)
-- V22 pre-fill (Xaya 2026-11-07: "pre-fill confirmation options or data capturing"): every hand-written walkthrough of this session
local mine = { "group-page", "group-box", "group-nested", "sidebar-drag", "reskin-switches", "shopping-list", "display-points",
  "mover-session", "group-arrange", "group-fit", "dynamic-limit-align", "sidebar-names" }
local nopf = {}
for _, id in ipairs(mine) do if not (QA.walks[id] and QA.walks[id].prefill) then nopf[#nopf + 1] = id end end
check("V22: every hand-written walkthrough of this session offers the pre-filled verdict", #nopf == 0, table.concat(nopf, ", "))
QA.Start("display-points"); QA.DoSetup(); W.tick(0.4, 3); QA.RunCheck()
local pst = QA.State()
check("  ...after its check, Accept offers the addon's verdict", Wn.accept:IsShown() and Wn.accept:GetText():find("Accept", 1, true) ~= nil, Wn.accept:GetText())
QA.Accept()
check("  ...Accept records it, with the addon's note and its data", pst.steps[1] and pst.steps[1].r == "P" and pst.steps[1].note:find("addon:", 1, true) ~= nil
  and pst.steps[1].a == "Y" and type(pst.steps[1].d) == "string", pst.steps[1] and (tostring(pst.steps[1].r) .. " / " .. tostring(pst.steps[1].note)))
for _ = 2, #QA.walks["display-points"].steps do QA.DoSetup(); W.tick(0.1, 2); QA.Answer("S") end
-- this round's hand-written walkthroughs (B177-B179c): every Do it for me and check runs without an error, and the last step cleans up
for _, id in ipairs({ "display-points", "mover-session", "group-arrange", "group-fit", "dynamic-limit-align", "sidebar-names" }) do
  local def = QA.walks[id]
  local okAll, why = def ~= nil, "not registered"
  if def then
    QA.Start(id)
    for _ = 1, #def.steps do
      local ok, err = pcall(function() QA.DoSetup(); W.tick(0.1, 2); QA.RunCheck() end)
      if not ok then okAll, why = false, err; break end
      QA.Answer("S")
    end
    if ns.unlocked then ns.MoverExit("cancel") end
    local left = false
    for _, f in ipairs(ns.folders) do if f.name == "QA test group" then left = true end end
    if okAll and left then okAll, why = false, "the QA test group is still there" end
  end
  check("walkthrough " .. id .. ": every step's Do it for me and check run, and it cleans up", okAll, why)
end
-- V22 data capture: what the addon's check saw is saved with each answer and travels in the export code
local sres = QA.DB().results["sidebar-names"]
check("V22: each answer keeps the addon's own verdict and data (sidebar width, tightest name)", sres and sres.steps[1].a ~= nil and type(sres.steps[1].d) == "string"
  and sres.steps[1].d:find("sidebar", 1, true) ~= nil, sres and sres.steps[1].d)
local sback = QA.ImportCode(QA.ExportCode("sidebar-names"))
check("  ...and the export code carries it", sback and sback.steps[1].a == sres.steps[1].a and sback.steps[1].d == sres.steps[1].d, sback and sback.steps[1].d)
-- list status after a run
QA.Toggle(); QA.Toggle()
local gp
for i, id in ipairs(QA.list) do if id == "group-page" then gp = Wn.rows[i] end end
check("the list shows the last result of a walkthrough", gp and gp.status:GetText():find("1 failed", 1, true) ~= nil, gp and gp.status:GetText())
-- audit D35 (Dev Assist 0.7.19): a group of the player's own called "QA test group" is never reused or deleted by a walkthrough
do
  local mine = ns.NewFolder("QA test group")
  local r = ns.NewRule(); r.name = "my own rule"; r.folder = mine.id; ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
  local def = QA.walks["group-page"]
  QA.Start("group-page")
  for _ = 1, #def.steps do pcall(function() QA.DoSetup(); W.tick(0.1, 2) end); QA.Answer("S") end
  local kept, ruleKept = false, false
  for _, f in ipairs(ns.folders) do if f == mine then kept = true end end
  for _, x in ipairs(ns.rules) do if x == r and x.folder == mine.id then ruleKept = true end end
  check("D35 the player's own 'QA test group' and its rule survive a walkthrough's Cleanup", kept and ruleKept)
  local tagged = 0
  for _, f in ipairs(ns.folders) do if f.qaTest then tagged = tagged + 1 end end
  check("D35 ...and the walkthrough's own tagged group is gone", tagged == 0, tagged)
end
-- audit D34 (Dev Assist 0.7.19): walkthroughs put back what Do it for me changed
local function RunAll(id)
  local def = QA.walks[id]; QA.Start(id)
  for _ = 1, #def.steps do pcall(function() QA.DoSetup(); W.tick(0.1, 2) end); QA.Answer("S") end
end
if ns.SetReskinTab and ns.ReskinTabOn then
  ns.SetReskinTab(false); W.tick(0.1, 2)
  RunAll("reskin-switches")
  check("D34 reskin walkthrough: All reskins is off again at the end (it was off before)", ns.ReskinTabOn() == false, tostring(ns.ReskinTabOn()))
  ns.SetReskinTab(true); W.tick(0.1, 2)
end
do
  local S = ns.Service and ns.Service("shoppingList")
  if S then
    local c = S.Cfg(); c.enabled, c.panel = false, false; S.Apply()
    RunAll("shopping-list")
    c = S.Cfg()
    check("D34 Shopping List walkthrough: switched off again at the end (it was off before)", c.enabled == false and c.panel == false, tostring(c.enabled) .. "/" .. tostring(c.panel))
  else
    check("D34 Shopping List service available in the stand-in", false, "no shoppingList service")
  end
end
return R
end
'''


def main():
    folders = H.find_addons()
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in folders}, "saved": {}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    bad = 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        print(("PASS " if ok else "FAIL ") + name)
        if not ok:
            bad += 1
    import subprocess
    chk = subprocess.run([sys.executable, os.path.join(HERE, "..", "tools", "qa_walks_from_checklist.py"), "--check"], capture_output=True, text=True)
    print(("PASS " if chk.returncode == 0 else "FAIL ") + "QAWalks-Checklist.lua is in sync with docs/QA-CHECKLIST.md: " + chk.stdout.strip())
    if chk.returncode != 0:
        bad += 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
