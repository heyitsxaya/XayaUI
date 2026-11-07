#!/usr/bin/env python3
"""The QA walkthrough runner's rules (XayaUI_DevAssist 0.7.53; docs/plans/PLATFORM-SPLIT-2026-11-07.md section 15, phase P0.5; issues
#461, #465, #466, #481, #484). The walkthroughs are the regression tool for the refactor, so their results must mean what they say.
Checked in the stand-in game on what the windows draw and record:
  A1 a step with "Do it for me" offers no verdict before its setup ran in this run: the check says "Press Do it for me first", Pass /
     Accept / Done stay greyed and record nothing (Fail and Skip stay); after it, Pass and Accept work; a new run asks again;
     a check that returns nil (not tested) offers no verdict ("Not tested yet", no Accept, recorded as "?");
  A2 a run with no Pass and no Fail reads Skipped (All walkthroughs, the review popup, the runner's status text), never Passed;
  A3 a clean-up step (done = true): Done instead of Pass / Fail, recorded as "D" (no verdict), kept through the export code; every
     hand-written walkthrough's clean-up / put-back last step is such a step;
  A4 the Done page: All walkthroughs, Review list, Next in this list (the next walkthrough in the list it was opened from, in the
     order that list showed then, also after the finished one's status changed); All walkthroughs has a Review list button; both lists
     keep their search, tags and sort while she moves between them (memory only); going to a list ends "back to the review on close";
  A5 a long title wraps inside the window and the page starts below its measured height (step and Done pages); the runner, review and
     question windows have a 0.95 opaque background;
  A6 the review window's search row starts below the intro text's measured height (no overlap at a bigger text size);
  V22 the runner walkthroughs (J33, three in a row) pass on the real runner when played the way she would;
  no new saved key (CueRulesDB unchanged by any of it; XayaUIDevAssistDB keeps only qa.results for the runs).
Every check fails on Dev Assist 0.7.52 (no gating, no Done button, no Skipped status, no Done-page navigation, a fixed title row).
Run: python3 tests/qa_runner_run.py   (Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

MAIN = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", false, true); W.tick(0.5, 10)
local QA = rawget(_G, "XayaUI_DevQA")
local RV = QA and QA.Review
local ns = rawget(_G, "XayaUI_NS")
local function join(t) return table.concat(t, ",") end
if RV and RV.Window() then RV.Window():Hide() end
check("Dev Assist 0.7.53 runner (Done step, setup gating, Next in this list)", QA and QA.NextId and QA.Gated and QA.Counts)
if not (QA and QA.NextId) then return R end
local function Dump(v, path, out)
  out = out or {}
  if type(v) == "table" then
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    if #keys == 0 then out[#out + 1] = path .. "={}" end
    for _, k in ipairs(keys) do Dump(v[k], path .. "." .. tostring(k), out) end
  else out[#out + 1] = path .. "=" .. tostring(v) end
  return out
end
local cueBefore = table.concat(Dump(rawget(_G, "CueRulesDB"), "CueRulesDB"), "\n")

-- sample walkthroughs (the area "Zz runner" keeps them together at the end of the default order)
local flag = 0
QA.Register("zz-run-a", { title = "Runner sample A", area = "Zz runner", order = 990, prefill = true, steps = {
  { text = "with setup", setup = function() flag = flag + 1 end, check = function() return flag > 0, "flag " .. flag end },
  { text = "not tested", check = function() return nil, "nothing was exercised" end },
  { text = "clean up", done = true, setup = function() flag = 0 end, check = function() return flag == 0, "flag back" end },
} })
QA.Register("zz-run-b", { title = "Runner sample B", area = "Zz runner", order = 991, steps = { { text = "skip me" }, { text = "skip me too" } } })
QA.Register("zz-run-c", { title = "Runner sample C", area = "Zz runner", order = 992, steps = { { text = "pass me" } } })

ns.RunCommand("dev", "qa")
local Wn = QA.Window(); local t = Wn.tbl
-- A1
QA.Start("zz-run-a")
local st = QA.State()
check("A1 before Do it for me: the check says to press it first, no Accept, Pass greyed, Fail and Skip available",
  Wn.check:GetText():find("Do it for me first", 1, true) and not Wn.accept:IsShown() and not Wn.pass:IsEnabled() and Wn.fail:IsEnabled() and Wn.skip:IsEnabled() and QA.Gated(), Wn.check:GetText())
QA.Answer("P"); QA.Accept()
check("A1 ...Pass and Accept record nothing before it", st.i == 1 and st.steps[1] == nil)
QA.DoSetup(); W.tick(0.4, 2)
check("A1 after Do it for me: Pass works and Accept offers the addon's verdict", Wn.pass:IsEnabled() and Wn.accept:IsShown() and Wn.accept:GetText() == "Accept: Pass" and not QA.Gated(), Wn.accept:GetText())
QA.Accept()
check("A1 ...Accept records it", st.steps[1] and st.steps[1].r == "P" and st.i == 2)
QA.RunCheck()
check("A1 a check that returns nil: \"Not tested yet\", no Accept, recorded as not judged", Wn.check:GetText():find("Not tested yet", 1, true) and not Wn.accept:IsShown()
  and st.seen[2] and st.seen[2].a == "?", Wn.check:GetText())
QA.Back(); QA.Back()
check("A1 going Back keeps the step's Do it for me done in this run", st.i == 1 and not QA.Gated() and Wn.pass:IsEnabled())
QA.Answer("P"); QA.Answer("S")
-- A3
check("A3 the clean-up step shows Done (greyed until Do it for me), no Pass / Fail", Wn.doneBtn:IsShown() and not Wn.doneBtn:IsEnabled() and not Wn.pass:IsShown() and not Wn.fail:IsShown())
QA.Answer("D"); QA.Answer("P"); QA.Answer("F")
check("A3 ...Done, Pass and Fail record nothing before Do it for me", st.i == 3 and st.steps[3] == nil)
QA.DoSetup(); W.tick(0.4, 2)
check("A3 ...after Do it for me Done works; no Accept on it", Wn.doneBtn:IsEnabled() and not Wn.accept:IsShown())
QA.Answer("D")
local res = QA.DB().results["zz-run-a"]
check("A3 Done is recorded as D (no verdict), with what the addon saw", res and res.steps[3].r == "D" and res.steps[3].a == "Y", res and res.steps[3].r)
local back = QA.ImportCode(QA.ExportCode("zz-run-a"))
check("A3 the export code keeps the Done step", back and back.steps[3].r == "D" and back.steps[2].r == "S", back and tostring(back.steps[3].r))
check("A3 the Done page counts it apart: 1 passed, 0 failed, 1 skipped, 1 done", Wn.summary:GetText():find("1 passed, 0 failed, 1 skipped, 1 done", 1, true) ~= nil, Wn.summary:GetText())
QA.Start("zz-run-a")
check("A1 Run again: the step asks for Do it for me again (each run)", QA.Gated() and not Wn.pass:IsEnabled())
QA.Toggle()
-- every hand-written walkthrough's clean-up / put-back last step is a Done step (#484)
local missing = {}
for _, id in ipairs(QA.list) do
  local d = QA.walks[id]
  local last = d.steps[#d.steps]
  local txt = tostring(last.text or "")
  if not d.generated and last.setup and (txt:find("put .* back") or txt:find("to remove") or txt:find("to delete") or txt:find("to close") or txt:find("put back")) and not last.done then missing[#missing + 1] = id end
  if not d.generated and (txt:find("Then Pass", 1, true) or txt:find("Then Accept or Pass", 1, true)) then missing[#missing + 1] = id .. " (says Then Pass)" end
end
check("A3 every clean-up / put-back last step of a hand-written walkthrough is a Done step", #missing == 0, join(missing))

-- A2
local DB = QA.DB().results
DB["zz-run-b"] = { when = 1, steps = { { r = "S" }, { r = "S" } }, fp = QA.Fingerprint(QA.walks["zz-run-b"]) }
DB["zz-run-c"] = { when = 1, steps = { { r = "S" }, { r = "D" } }, fp = QA.Fingerprint(QA.walks["zz-run-c"]) }
check("A2 a run with every step skipped (or done) is Skipped, not Passed", QA.Table.Status("zz-run-b") == "skipped" and QA.Table.Status("zz-run-c") == "skipped"
  and QA.Table.Status("zz-run-a") == "passed", QA.Table.Status("zz-run-b"))
check("A2 ...the runner's status text says Skipped", QA.StatusText("zz-run-b"):find("Skipped", 1, true) ~= nil and RV.Verdict("zz-run-b"):find("Skipped", 1, true) ~= nil, QA.StatusText("zz-run-b"))
ns.RunCommand("dev", "qa")
local function RowOf(tb, id) for _, r in ipairs(tb.rows) do if r:IsShown() and r.id == id then return r end end end
local rb = RowOf(t, "zz-run-b")
check("A2 All walkthroughs: the Status column reads Skipped", rb and rb.status:GetText():find("Skipped", 1, true) and not rb.status:GetText():find("Passed", 1, true), rb and rb.status:GetText())
RV.Show("test")
local rt = RV.Window().tbl
rt:Clear()
local rr = RowOf(rt, "zz-run-b")
check("A2 the review popup: the Status column reads Skipped", rr and rr.status:GetText():find("Skipped", 1, true) ~= nil, rr and rr.status:GetText())
RV.Window():Hide()

-- A4: All walkthroughs with a search, a tag and a sort; Open; Done page; Next follows that list's order
ns.RunCommand("dev", "qa")
check("A4 All walkthroughs has a Review list button", Wn.listReview and Wn.listReview:IsShown() and Wn.listReview:GetText() == "Review list")
t:Type("runner sample"); t:ToggleChip("area:Zz runner"); t:SortBy("title"); t:SortBy("title")   -- Z to A: C, B, A
check("(the list shows the three samples, Z to A)", join(t:Ids()) == "zz-run-c,zz-run-b,zz-run-a", join(t:Ids()))
local rc = RowOf(t, "zz-run-c"); rc.open:GetScript("OnClick")(rc.open)
check("A4 Open keeps the order the list showed", QA.State().id == "zz-run-c" and join(QA.State().order) == "zz-run-c,zz-run-b,zz-run-a")
QA.Answer("P")
check("A4 the Done page: All walkthroughs, Review list and Next in this list", Wn.endList:IsShown() and Wn.endReview:IsShown() and Wn.nextBtn:IsShown() and Wn.nextBtn:IsEnabled()
  and Wn.endList:GetText() == "All walkthroughs" and Wn.endReview:GetText() == "Review list" and Wn.nextBtn:GetText() == "Next in this list")
check("A4 ...the Done-page buttons sit inside the window, under the summary, apart", Wn.endList:GetBottom() >= Wn:GetBottom() and Wn.nextBtn:GetRight() <= Wn:GetRight() + 0.5
  and Wn.endReview:GetRight() <= Wn.nextBtn:GetLeft() and Wn.endList:GetTop() <= Wn.shot:GetBottom())
Wn.nextBtn:GetScript("OnClick")(Wn.nextBtn)
check("A4 Next in this list opens the next walkthrough in that order (B after C, sorted Z to A)", QA.State().id == "zz-run-b" and QA.State().i == 1, QA.State().id)
QA.Answer("S"); QA.Answer("S")
check("A2 the Done page of an all-skipped run says Skipped", Wn.summary:GetText():find("Skipped:", 1, true) ~= nil, Wn.summary:GetText())
Wn.nextBtn:GetScript("OnClick")(Wn.nextBtn)
check("A4 ...and A after B", QA.State().id == "zz-run-a")
QA.DoSetup(); W.tick(0.4, 2); QA.Answer("P"); QA.Answer("S"); QA.DoSetup(); W.tick(0.4, 2); QA.Answer("D")
check("A4 the last one in the list: Next is greyed (Last in this list)", Wn.nextBtn:IsShown() and not Wn.nextBtn:IsEnabled() and Wn.nextBtn:GetText() == "Last in this list", Wn.nextBtn:GetText())
Wn.endList:GetScript("OnClick")(Wn.endList)
check("A4 All walkthroughs from the Done page: the search, the tag and the sort are as she left them", t.head:IsShown() and t.f.q == "runner sample"
  and t.f.areas["Zz runner"] == true and t.sortKey == "title" and t.sortDesc == true and t.search:GetText() == "runner sample" and join(t:Ids()) == "zz-run-c,zz-run-b,zz-run-a", t.f.q)
-- a status tag: the finished walkthrough leaves the filtered list, but Next still follows the order she opened it from
DB["zz-run-a"], DB["zz-run-b"], DB["zz-run-c"] = nil, nil, nil
QA.Toggle(); QA.Toggle()   -- (the list reads the results again when it opens)
t:Clear(); t:Type("runner sample"); t:ToggleChip("status:notrun")
check("(Not run: the three samples)", #t:Ids() == 3, join(t:Ids()))
local first = t:Ids()[1]
local r1 = RowOf(t, first); r1.open:GetScript("OnClick")(r1.open)
local order = join(QA.State().order)
for i = 1, #QA.walks[first].steps do local s2 = QA.walks[first].steps[i]; if s2.setup then QA.DoSetup(); W.tick(0.4, 2) end; QA.Answer(s2.done and "D" or "P") end
check("A4 with the Not run tag on, the finished one is no longer Not run, and Next still goes to the next in the order she opened it from", QA.NextId() == QA.State().order[2] and order == join(QA.State().order), tostring(QA.NextId()))
-- Review list from the Done page
Wn.endReview:GetScript("OnClick")(Wn.endReview)
check("A4 Review list on the Done page: the review window opens, the runner goes", RV.Window():IsShown() and not Wn:IsShown())
rt:Type("runner sample")
RV.Window():Hide()
ns.RunCommand("dev", "qa")
Wn.listReview:GetScript("OnClick")(Wn.listReview)
check("A4 Review list on All walkthroughs: the review window opens with its own search as she left it", RV.Window():IsShown() and not Wn:IsShown() and rt.f.q == "runner sample" and rt.search:GetText() == "runner sample", rt.f.q)
-- from the review: Open, then All walkthroughs on the step page: closing that list does not bring the review back
local rrow = rt.rows[1]
rrow.open:GetScript("OnClick")(rrow.open)
check("A4 Open in the review starts the walkthrough with the review's order", QA.State().from == "review" and QA.State().order ~= nil and not RV.Window():IsShown())
Wn.toList:GetScript("OnClick")(Wn.toList)
QA.Toggle()
check("A4 ...after going to All walkthroughs, closing it does not bring the review back (she went elsewhere)", not RV.Window():IsShown() and not RV.Returning())
rrow = (function() RV.Show("test"); return rt.rows[1] end)()
rrow.open:GetScript("OnClick")(rrow.open); Wn:Hide()
check("A4 ...closing the runner straight after Open from the review still brings the review back (as before)", RV.Window():IsShown())
RV.Window():Hide()
t:Clear(); rt:Clear()

-- A5: a long title wraps inside the window; the page starts below it
local long = "A very long walkthrough title that goes on and on: it names a feature, then another, and then a third one, so it needs more than one line to fit"
QA.Register("zz-run-long", { title = long, area = "Zz runner", order = 993, steps = { { text = "step text" } } })
rawset(Wn.title, "GetStringHeight", function() return 48 end)
QA.Start("zz-run-long")
local tl, tr, tb = Wn.title:GetLeft(), Wn.title:GetRight(), Wn.title:GetTop() - 48
check("A5 step page: the title wraps inside the window (its width leaves the close button room)", tl >= Wn:GetLeft() and tr <= Wn:GetRight() - 30 and Wn.title:GetWidth() <= Wn:GetWidth() - 14 - 30,
  ("%.0f..%.0f in %.0f..%.0f"):format(tl, tr, Wn:GetLeft(), Wn:GetRight()))
check("A5 ...the step number and the step text start below the title's measured height", Wn.stepNo:GetTop() <= tb and Wn.textScroll:GetTop() <= Wn.stepNo:GetTop() - 12,
  ("title bottom %.0f, step %.0f, text %.0f"):format(tb, Wn.stepNo:GetTop(), Wn.textScroll:GetTop()))
QA.Answer("P")
check("A5 Done page: the summary starts below the wrapped title", Wn.summary:GetTop() <= Wn.title:GetTop() - 48, ("%.0f vs %.0f"):format(Wn.summary:GetTop(), Wn.title:GetTop() - 48))
rawset(Wn.title, "GetStringHeight", nil)
local function Solid(f) local x = f and f.xuiSolid; return x and x._color and math.abs(x._color[4] - 0.95) < 0.001 and x:GetLeft() == f:GetLeft() and x:GetTop() == f:GetTop() end
RV.Show("test"); RV.Window():Hide(); RV.ShowQuestions(); local qwin = RV.QuestionWindow(); qwin:Hide()
check("A5 the runner, review and question windows have a 0.95 opaque background over their whole area", Solid(Wn) and Solid(RV.Window()) and Solid(qwin) and QA.WINDOW_ALPHA == 0.95)

-- A6: the review's intro text wraps (a bigger text size): the search row starts below it
local rw = RV.Window()
rawset(rw.sub, "GetStringHeight", function() return 60 end)
RV.Show("test")
local subBottom = rw.sub:GetTop() - 60
check("A6 review window: the search row and the tags start below the intro text's measured height", rt.searchLabel:GetTop() <= subBottom and rt.search:GetTop() <= subBottom
  and rt.chips["baseline"]:GetTop() <= rt.search:GetBottom() and rt.head:GetTop() <= rt.chips["new"]:GetBottom(), ("intro bottom %.0f, search %.0f"):format(subBottom, rt.searchLabel:GetTop()))
rawset(rw.sub, "GetStringHeight", nil); RV.Show("test")
check("A6 ...and back at one line it sits where it did (56 px)", math.abs((rw:GetTop() - rt.searchLabel:GetTop()) - 59) < 0.5, rw:GetTop() - rt.searchLabel:GetTop())
rw:Hide()

-- V22: the runner walkthroughs, played the way she would (J33)
for _, id in ipairs({ "qa-runner-nav", "qa-runner-skip", "qa-runner-nav-2" }) do QA.DB().results[id] = nil end
check("V22 the runner walkthroughs are registered with pre-fill (J33)", QA.walks["qa-runner-nav"] and QA.walks["qa-runner-nav"].prefill and QA.walks["qa-runner-nav"].qa == "J33"
  and QA.walks["qa-runner-skip"] and QA.walks["qa-runner-nav-2"])
ns.RunCommand("dev", "qa")
t:Clear(); t.sortKey, t.sortDesc = nil, false; t:Type("J33")
local r0 = RowOf(t, "qa-runner-nav"); r0.open:GetScript("OnClick")(r0.open)
QA.DoSetup(); W.tick(0.4, 2)
local v1 = QA.State().suggest
check("V22 J33 part 1 step 1: Pass was greyed and the check said press Do it for me first; opened from the J33 list: the addon says Pass", v1 and v1.r == "P", Wn.check:GetText())
QA.Accept()
QA.DoSetup(); W.tick(0.4, 2)
check("V22 J33 part 1 step 2 (a Done step): the addon sees Done shown and Pass / Fail hidden", QA.State().seen[2] and QA.State().seen[2].a == "Y", QA.State().seen[2] and QA.State().seen[2].d)
QA.Answer("D")
Wn.nextBtn:GetScript("OnClick")(Wn.nextBtn)
check("V22 J33 Next in this list opens part 2 (the sample to skip)", QA.State().id == "qa-runner-skip")
QA.Answer("S"); QA.Answer("S")
Wn.nextBtn:GetScript("OnClick")(Wn.nextBtn)
check("V22 J33 Next opens part 3", QA.State().id == "qa-runner-nav-2")
QA.RunCheck(); local p1 = QA.State().suggest
QA.Accept(); QA.RunCheck(); local p2 = QA.State().suggest
QA.Accept(); QA.RunCheck()
local s3 = QA.State(); local p3 = s3.seen and s3.seen[3]
check("V22 J33 part 3: Next came from part 2, part 2 reads Skipped, the list still holds J33: every check the addon can judge says Pass",
  p1 and p1.r == "P" and p2 and p2.r == "P" and p3 and p3.a == "Y", (p1 and p1.note or "?") .. " | " .. (p2 and p2.note or "?") .. " | " .. (p3 and p3.d or "?"))
QA.Answer("D")
local rn = QA.DB().results["qa-runner-nav-2"]
check("V22 J33 part 3 recorded: 2 passed and the Done step", rn and rn.steps[1].r == "P" and rn.steps[2].r == "P" and rn.steps[3].r == "D")
Wn:Hide()

-- nothing of it is saved outside qa.results
do
  local now = table.concat(Dump(rawget(_G, "CueRulesDB"), "CueRulesDB"), "\n")
  local a, b = {}, {}
  for l in cueBefore:gmatch("[^\n]+") do a[l] = true end
  for l in now:gmatch("[^\n]+") do b[l] = true end
  local diff = {}
  -- (XayaUI's own runtime, not the runner: the combat tracker's store made on its first read, the debug record's log lines, and the
  -- console its first-login setup message opens)
  local function noise(l) return l:find("^CueRulesDB%.auraModel") or l:find("^CueRulesDB%.debugRecord%.") or l:find("^CueRulesDB%.ui%.consoleOpen") end
  for l in pairs(b) do if not a[l] and not noise(l) then diff[#diff + 1] = "+" .. l end end
  for l in pairs(a) do if not b[l] and not noise(l) then diff[#diff + 1] = "-" .. l end end
  table.sort(diff)
  check("no new saved key: CueRulesDB is unchanged by the runner and its windows", #diff == 0, table.concat(diff, " ; "):sub(1, 400))
end
local da = rawget(_G, "XayaUIDevAssistDB") or {}
local qaKeys = {}
for k in pairs(da.qa or {}) do qaKeys[#qaKeys + 1] = tostring(k) end
local bad = {}
for _, line in ipairs(Dump(da, "DevAssist")) do
  local p = line:match("^([^=]*)") or line
  if not (p:find("^DevAssist%.qa%.results%.") or p:find("^DevAssist%.review%.") or p:find("^DevAssist%.questions%.") or not p:find("^DevAssist%.qa")) then bad[#bad + 1] = line end
  for comp in p:gmatch("[^%.]+") do local c = comp:lower(); if c == "order" or c == "setupdone" or c == "lastnext" or c:find("search", 1, true) or c:find("chip", 1, true) or c == "sortkey" then bad[#bad + 1] = line; break end end
end
check("no new saved key: XayaUIDevAssistDB.qa holds only results; no order, Next, setup, search, tag or sort key anywhere", join(qaKeys) == "results" and #bad == 0, join(qaKeys) .. " / " .. join(bad))
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
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(MAIN, world, loader)
    out, issues = loader.logout()
    bad = 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        print(("PASS " if ok else "FAIL ") + name)
        if not ok:
            bad += 1
    ok = len(issues) == 0
    print(("PASS " if ok else "FAIL ") + "the saved files can be written by the game" + ("" if ok else "  [%s]" % issues[1]))
    bad += 0 if ok else 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res) + 1, bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
