#!/usr/bin/env python3
"""The review window and the question flow (XayaUI_DevAssist 0.7.30, QAReview.lua, QAQuestions.lua, QAWalks-review.lua).
Xaya 2026-11-07 ~08:25 UTC (her words): "I want a qa review checklist pushed and displayed as a popup for everything that needs review
when I first load into the game and I want all outstanding questions to be nested within a qa question prompt flow so I know what you
had to execute blindly and need feedback on."
Three game sessions in the stand-in game (the saved file carried across like a /reload or a new login):
 1. first install: V14 (no window before it opens); it opens by itself once after the loading screen, listing every walkthrough (none
    acknowledged yet), grouped by area, as a table (Codes | Title | Area | Status | New | Open, 0.7.52) with Open; a zone change does not open it again; the tick box acknowledges
    the build; the question flow (Next needs an answer, Skip, Back, saves with the time and version, Copy answers);
 2. same versions: it stays shut; the answers survived; /xui dev review and /xui dev questions open them;
 3. a XayaUI version changed while in combat: it waits for combat to end, then lists exactly the walkthrough added and the one whose text
    changed (not the unchanged ones); Open goes to the runner and back; a result recorded against the old text is marked.
Run: python3 tests/qa_review_run.py   (Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

COMMON = r'''
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local QA = rawget(_G, "XayaUI_DevQA")
local RV = QA and QA.Review
local ns = rawget(_G, "XayaUI_NS")
local function ids(list) local t = {}; for _, e in ipairs(list or {}) do t[#t + 1] = e.id end; return table.concat(t, ",") end
'''

S1 = r'''
return function(W, L)
L.startup()
''' + COMMON + r'''
check("Dev Assist has the review window and question API", RV and RV.Show and QA.RegisterQuestion)
if not RV then return R end
check("V14: no review or question window before one opens", RV.Window() == nil and RV.QuestionWindow() == nil
  and rawget(_G, "XayaUIDevReviewWindow") == nil and rawget(_G, "XayaUIDevQuestionsWindow") == nil)
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.5, 2)
check("not under the loading screen: still shut half a second after entering the world", RV.Window() == nil)
W.tick(0.5, 6)
local w = RV.Window()
check("opens by itself after the first load of a new install", w and w:IsShown() and w.title:GetText() == "Review: what's new to test")
check("  ...recorded as opened for the update, not in combat", XayaUIDevAssistDB.review.lastShown.why == "update" and XayaUIDevAssistDB.review.lastShown.combat == false)
check("  ...no build acknowledged yet: every walkthrough is listed", #w.list == #QA.list and w.sub:GetText():find("First time", 1, true) ~= nil, #w.list .. " of " .. #QA.list)
local rows = 0
for _, r in ipairs(w.rows) do if r:IsShown() then rows = rows + 1 end end
local heads = {}
for _, h in ipairs(w.headers) do heads[#heads + 1] = h.text:GetText() end
check("  ...one table row per walkthrough, under the header Codes | Title | Area | Status | New | Open (0.7.52)", rows == #QA.list
  and table.concat(heads, "|") == "Codes|Title|Area|Status|New|Open", rows .. " rows, header " .. table.concat(heads, "|"))
local devRow
for _, r in ipairs(w.rows) do if r.id == "review-window" then devRow = r end end
check("  ...a row shows its codes, title, new/changed and its status, with Open", devRow and devRow.codes:GetText() == "J30"
  and devRow.title:GetText():find("Review window and questions (part 1)", 1, true) and devRow.new:GetText():find("new", 1, true)
  and devRow.status:GetText():find("Not run", 1, true) and devRow.open:IsShown(), devRow and devRow.title:GetText())
local hdr = {}
for _, r in ipairs(w.rows) do if r:IsShown() then hdr[#hdr + 1] = r.area:GetText() end end
check("  ...areas include Dev Assist, Chat and the QA checklist", table.concat(hdr, "|"):find("Dev Assist", 1, true) and table.concat(hdr, "|"):find("|Chat|", 1, true)
  and table.concat(hdr, "|"):find("QA checklist", 1, true), table.concat(hdr, "|"):sub(1, 300))
check("  ...Questions (N) counts the open questions", w.questions:GetText() == ("Questions (%d)"):format(#QA.questions) and #QA.questions >= 1, w.questions:GetText())
check("  ...the tick box starts unticked", not w.dont:GetChecked())
w:Hide()
W.fire("PLAYER_ENTERING_WORLD", false, false); W.tick(0.5, 8)
check("a zone change in the same session does not open it again", not w:IsShown())
-- the tick box
w.dont:SetChecked(true); w.dont:GetScript("OnClick")(w.dont)
check("ticking Don't show again acknowledges this build", RV.Acknowledged() and XayaUIDevAssistDB.review.ack.fps["group-page"] ~= nil)
w.dont:SetChecked(false); w.dont:GetScript("OnClick")(w.dont)
check("  ...unticking takes it back", not RV.Acknowledged())
w.dont:SetChecked(true); w.dont:GetScript("OnClick")(w.dont)
-- the question flow
w.questions:GetScript("OnClick")(w.questions)
local q = RV.QuestionWindow()
check("Questions opens the flow at question 1, the review window goes", q and q:IsShown() and not w:IsShown() and RV.State().qi == 1
  and q.count:GetText():find("Question 1 of", 1, true) ~= nil, q and q.count:GetText())
local first = QA.questions[1]
local txt = q.text:GetText()
check("  ...shows the area, her words verbatim and what was done without asking", txt:find(first.area, 1, true) and txt:find(first.words:sub(1, 40), 1, true)
  and txt:find("What we did without asking", 1, true) and txt:find(first.did:sub(1, 40), 1, true))
check("  ...the keep choice first (\"Keep it\" unless the question names its own), then the alternatives", q.choices[1]:IsShown() and q.choices[1].label:GetText():find(first.choices[1], 1, true)
  and q.choices[#first.choices].label:GetText():find(first.choices[#first.choices]:sub(1, 20), 1, true) and not q.choices[#first.choices + 1]:IsShown())
check("the first question is the held D8 load-condition changes (O-109)", first.key == "D8-Q1" and txt:find("Ship the held rule load-condition changes?", 1, true) ~= nil, first.key)
local plain, wordless = 0, nil
for i, x in ipairs(QA.questions) do
  if x.choices[1] == "Keep it" then plain = plain + 1 end
  if not x.words and not wordless then wordless = i end
end
check("every question has a keep choice and 0-4 alternatives", (function() for _, x in ipairs(QA.questions) do if #x.choices < 1 or #x.choices > 5 or x.did == "" then return false end end; return true end)() and plain > 10, plain)
local keepQi = RV.State().qi
for _ = 1, wordless - 1 do RV.Skip() end
check("a question with no words of hers says so instead of quoting", RV.State().qi == wordless and q.text:GetText():find("no words of yours", 1, true) ~= nil, q.text:GetText():sub(1, 200))
for _ = 1, wordless - 1 do RV.Back() end
check("  ...and Back returns to question 1", RV.State().qi == keepQi)
q.next:GetScript("OnClick")(q.next)
check("Next with nothing picked asks for an answer and stays", RV.State().qi == 1 and q.hint:GetText():find("Pick an answer", 1, true) ~= nil
  and XayaUIDevAssistDB.questions.answers[first.key] == nil)
q.choices[2]:GetScript("OnClick")(q.choices[2])
q.note:SetText("only on |cffff0000login")
q.next:GetScript("OnClick")(q.next)
local a = XayaUIDevAssistDB.questions.answers[first.key]
check("picking a choice and Next saves it with the note, time and version", a and a.c == 2 and a.choice == first.choices[2] and a.note == "only on cffff0000login"
  and a.when and a.v == C_AddOns.GetAddOnMetadata("XayaUI_DevAssist", "Version"), a and (tostring(a.c) .. " " .. tostring(a.note) .. " " .. tostring(a.v)))
check("  ...and moves to question 2", RV.State().qi == 2 and q.count:GetText():find("1 answered", 1, true) ~= nil, q.count:GetText())
q.skip:GetScript("OnClick")(q.skip)
check("Skip moves on without saving", RV.State().qi == 3 and XayaUIDevAssistDB.questions.answers[QA.questions[2].key] == nil)
q.back:GetScript("OnClick")(q.back); q.back:GetScript("OnClick")(q.back)
check("Back reaches an answered question and shows its answer", RV.State().qi == 1 and q.choices[2]:GetChecked() and q.note:GetText() == "only on cffff0000login")
q.copy:GetScript("OnClick")(q.copy)
local copy = q.copyBox:GetText()
check("Copy answers: a text box with one line per answer", q.copyBox:IsShown() and copy:find("XayaUI QA answers", 1, true)
  and copy:find("[" .. first.key .. "]", 1, true) and copy:find(first.choices[2], 1, true) and copy:find("note: only on", 1, true), copy)
check("the review walkthroughs are registered with pre-fill (V22)", QA.walks["review-window"] and QA.walks["review-window"].prefill
  and QA.walks["review-after-reload"] and QA.walks["review-open"])
return R
end
'''

S2 = r'''
return function(W, L)
L.startup()
''' + COMMON + r'''
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", false, true); W.tick(0.5, 10)
check("same versions after a /reload: it stays shut (acknowledged)", RV.Window() == nil and RV.Acknowledged())
local a = XayaUIDevAssistDB.questions.answers[QA.questions[1].key]
check("the answer survived the reload", a and a.c == 2 and a.note == "only on cffff0000login")
ns.RunCommand("dev", "review")
check("/xui dev review opens it", RV.Window() and RV.Window():IsShown())
check("  ...with the tick box ticked", RV.Window().dont:GetChecked())
check("  ...Questions (N) counts only the unanswered", RV.Window().questions:GetText() == ("Questions (%d)"):format(#QA.questions - 1), RV.Window().questions:GetText())
ns.RunCommand("dev", "review")
check("  ...and closes again", not RV.Window():IsShown())
SlashCmdList.XAYAUIDEV("review")
check("/xuidev review opens it too", RV.Window():IsShown())
ns.RunCommand("dev", "questions")
check("/xui dev questions opens the flow at the first unanswered question", RV.QuestionWindow():IsShown() and RV.State().qi == 2, RV.State().qi)
-- a result recorded now, against the text this build has
QA.Start("group-box"); for _ = 1, #QA.walks["group-box"].steps do QA.Answer("S") end
check("a finished walkthrough's result keeps its fingerprint", QA.DB().results["group-box"].fp == QA.Fingerprint(QA.walks["group-box"]))
return R
end
'''

S3 = r'''
return function(W, L)
L.startup()
''' + COMMON + r'''
L.addons["XayaUI"].meta.Version = "9.9.99"   -- an update to the core
QA.Register("test-new-walk", { title = "A walkthrough new in this build", area = "Test area", steps = { { text = "new" } } })
QA.walks["group-page"].steps[1].text = QA.walks["group-page"].steps[1].text .. " (changed)"
QA.walks["group-box"].steps[1].text = QA.walks["group-box"].steps[1].text .. " (changed)"
W.combat = true
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.5, 10)
check("an update, loaded in combat: it does not open in combat", RV.Window() == nil and XayaUIDevAssistDB.review.deferred ~= nil)
W.tick(1, 5)
check("  ...still shut while the fight goes on", RV.Window() == nil)
W.combat = false; W.fire("PLAYER_REGEN_ENABLED"); W.tick(0.1, 2)
local w = RV.Window()
check("  ...opens when combat ends", w and w:IsShown() and XayaUIDevAssistDB.review.lastShown.combat == false)
check("lists exactly the walkthrough added and the ones whose text changed", ids(w.list) == "group-page,group-box,test-new-walk" or
  (#w.list == 3 and ids(w.list):find("test-new-walk", 1, true) and ids(w.list):find("group-page", 1, true) and ids(w.list):find("group-box", 1, true)), ids(w.list))
local st = {}
for _, e in ipairs(w.list) do st[e.id] = e.state end
check("  ...marked new and changed", st["test-new-walk"] == "new" and st["group-page"] == "changed")
check("  ...in area order (the table's Area column)", w.rows[1].area:GetText() == "Groups and displays" and w.rows[2].area:GetText() == "Groups and displays"
  and w.rows[3].area:GetText() == "Test area" and not (w.rows[4] and w.rows[4]:IsShown()), tostring(w.rows[1].area:GetText()) .. " / " .. tostring(w.rows[3].area:GetText()))
local box
for _, r in ipairs(w.rows) do if r:IsShown() and r.id == "group-box" then box = r end end
check("a result recorded against the old text says to run it again", box and box.status:GetText():find("(rerun)", 1, true) ~= nil, box and box.status:GetText())
check("the box is unticked (this build is not acknowledged)", not w.dont:GetChecked() and not RV.Acknowledged())
-- Open: the runner, and back
box.open:GetScript("OnClick")(box.open)
local qw = QA.Window()
check("Open: the review goes, the runner starts that walkthrough", not w:IsShown() and qw and qw:IsShown() and QA.State().id == "group-box")
qw:Hide()
check("  ...closing the runner brings the review back", w:IsShown())
-- a reload in combat after acknowledging: nothing (acknowledged wins before combat matters)
w.dont:SetChecked(true); w.dont:GetScript("OnClick")(w.dont)
check("ticking now lists against this build next time", RV.Acknowledged())
return R
end
'''


def session(L_src, saved):
    folders = H.find_addons()
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in folders}, "saved": saved}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(L_src, world, loader)
    out, issues = loader.logout()
    results = [(res[i][1], res[i][2]) for i in range(1, len(res) + 1)]
    results.append(("the saved file can be written by the game" + ("" if len(issues) == 0 else "  [%s]" % issues[1]), len(issues) == 0))
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    return results, H.lua_to_py(out), errs


def main():
    bad, n, allErrs = 0, 0, []
    saved = {}
    for label, src in (("session 1", S1), ("session 2", S2), ("session 3", S3)):
        results, saved, errs = session(src, saved)
        for name, ok in results:
            n += 1
            print(("PASS " if ok else "FAIL ") + label + ": " + name)
            if not ok:
                bad += 1
        allErrs += errs
    for e in allErrs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (n, bad, len(allErrs)))
    sys.exit(1 if bad or allErrs else 0)


if __name__ == "__main__":
    main()
