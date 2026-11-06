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

-- run the group page walkthrough
QA.Start("group-page")
local st = QA.State()
check("a walkthrough starts at step 1 with its text and Do it for me", st and st.i == 1 and Wn.text:GetText():find("Group, Display, Load, Config", 1, true) and Wn.doIt:IsShown())
check("  ...the addon's own check says what it sees (no test group yet) without answering", Wn.check:GetText():find("Looks wrong", 1, true) ~= nil and st.steps[1] == nil, Wn.check:GetText())
QA.DoSetup(); W.tick(0.4, 3); QA.RunCheck()
local tg
for _, f in ipairs(ns.folders) do if f.name == "QA test group" then tg = f end end
check("Do it for me made the QA test group", tg ~= nil)
check("  ...and the check now looks right", Wn.check:GetText():find("Looks right", 1, true) ~= nil, Wn.check:GetText())
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
-- list status after a run
QA.Toggle(); QA.Toggle()
local gp
for i, id in ipairs(QA.list) do if id == "group-page" then gp = Wn.rows[i] end end
check("the list shows the last result of a walkthrough", gp and gp.status:GetText():find("1 failed", 1, true) ~= nil, gp and gp.status:GetText())
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
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
