-------------------------------------------------------------------------------
-- QAWalks-review.lua (XayaUI_DevAssist 0.7.30): the in-game walkthroughs for the review window and the question flow (QAReview.lua).
-- Standing rule V22 (Xaya, 2026-11-07): every feature lands with a walkthrough "with pre-fill confirmation options or data capturing".
-- prefill = true: each check reads the windows and the saved file and offers its verdict on Accept; nothing is recorded without her click.
-- Three walkthroughs: the second runs after a /reload (answers and the acknowledged build must survive it; the window must stay shut while
-- in combat); the third is started from the review window's Open button. "Do it for me" in step 1 of the first only opens the window; the last step's "Do it for me" forgets the acknowledged build (so the
-- next /reload counts as an update) and remembers how many answers there were. UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not (QA and QA.Review) then return end
local RV = QA.Review

local function Shown(w) return (w and w:IsShown()) and true or false end
local function NAnswers() local n = 0; for _ in pairs(RV.SV().questions.answers) do n = n + 1 end; return n end

QA.Register("review-window", { title = "Review window and questions (part 1)", area = "Dev Assist", qa = "J30", order = 302, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r (or type |cffffd100/xui dev review|r).\n\n|cffffd100Expect:|r a window \"Review: what's new to test\": the walkthroughs new or changed since the build you last acknowledged, as a table (Codes | Title | Area | Status | New | Open): each row with its codes, its title, its area, its last result, \"new\" or \"changed\" and an |cffffd100Open|r button. At the bottom: the tick box \"Don't show again until the next update\", |cffffd100Questions (N)|r, All walkthroughs and Close.",
      setup = function() RV.Show("walkthrough") end,
      check = function()
          local w = RV.Window()
          local n = w and w.list and #w.list or 0
          return Shown(w), Shown(w) and ("the window is open, listing %d walkthrough(s); Questions button: %s"):format(n, w.questions:GetText()) or "the review window is not open"
      end },
    { text = "Press |cffffd100Do it for me|r (or the |cffffd100Questions (N)|r button).\n\n|cffffd100Expect:|r \"Questions: what we did without asking you\": one question, with \"Question 1 of N\", the area, |cffffd100Your words|r (your own words, in quotes), |cffffd100What we did without asking|r, then \"Keep it\" (green) and the other choices, a note box, Back / Copy answers / Review list / Skip / Next.",
      setup = function() RV.ShowQuestions() end,
      check = function()
          local w = RV.QuestionWindow()
          return Shown(w) and #QA.questions > 0, Shown(w) and ("%d question(s), %d still open"):format(#QA.questions, RV.OpenCount()) or "the question window is not open"
      end },
    { text = "Answer at least one question for real: pick a choice (or write a note) and press |cffffd100Next|r. Press |cffffd100Skip|r on one you are not sure about; press |cffffd100Next|r with nothing picked once.\n\n|cffffd100Expect:|r Next with nothing picked says \"Pick an answer or write a note, or press Skip.\" and stays; the count goes up by one for each answer.",
      check = function() local n = NAnswers(); return n > 0, ("%d answer(s) saved"):format(n) end },
    { text = "Press |cffffd100Do it for me|r (or Copy answers).\n\n|cffffd100Expect:|r a text box with one line per answer: [key] area: your choice; note, with the time and Dev Assist's version. Its text is selected: Ctrl+C copies it. Paste it into a chat with Claude (or anywhere) to see it worked.",
      setup = function() RV.ShowCopy() end,
      check = function()
          local w = RV.QuestionWindow()
          local t = w and w.copyBox and w.copyBox:GetText() or ""
          local lines = select(2, t:gsub("\n", "")) or 0
          return Shown(w) and t:find("XayaUI QA answers", 1, true) ~= nil and NAnswers() > 0, ("the box holds %d line(s) for %d answer(s)"):format(lines, NAnswers())
      end },
    { done = true, text = "Last step. Press |cffffd100Do it for me|r: the addon forgets which build you acknowledged (so the next load counts as an update) and remembers how many answers you have now. Then press |cffffd100Done|r here (before the /reload, so this result is kept).\n\nThen find a training dummy, attack it, and while you are |cffffd100in combat|r type |cffffd100/reload|r. Keep fighting for a few seconds after the loading screen, then stop.\n\n|cffffd100Expect:|r no review window while you are in combat; it opens a moment after combat ends. Then run \"Review window and questions (part 2)\".",
      setup = function()
          local r = RV.SV().review
          r.ack, r.prev = nil, nil
          r.walkAnswers, r.walkWhen, r.deferred = NAnswers(), time and time() or 0, nil
      end,
      check = function() local r = RV.SV().review; return r.ack == nil and r.walkAnswers ~= nil, r.ack == nil and ("ready: %d answer(s) remembered; no build acknowledged"):format(r.walkAnswers or 0) or "press Do it for me" end },
} })

QA.Register("review-after-reload", { title = "Review window and questions (part 2, after the /reload)", area = "Dev Assist", qa = "J30", order = 302.5, prefill = true, steps = {
    { text = "Run this after part 1's last step and the /reload in combat.\n\n|cffffd100Expect:|r the review window did NOT open while you were in combat and opened a moment after combat ended.",
      check = function()
          local r = RV.SV().review
          local d, s = r.deferred, r.lastShown
          if not r.walkWhen then return false, "part 1's last step has not been done" end
          local waited = d and d.when >= r.walkWhen
          local after = s and s.why == "update" and s.when >= r.walkWhen and s.combat == false
          return (waited and after) and true or false, ("waited for combat: %s; opened by itself after: %s"):format(waited and "yes" or "no (were you in combat at the load?)", after and "yes, not in combat" or "no")
      end },
    { text = "In the review window, tick |cffffd100Don't show again until the next update|r and close it. Type |cffffd100/reload|r (out of combat).\n\n|cffffd100Expect:|r no review window after the reload. (/xui dev review still opens it.)",
      check = function() return RV.Acknowledged(), RV.Acknowledged() and "this build is acknowledged" or "this build is not acknowledged: tick the box" end },
    { text = "Your answers survived the reloads.\n\n|cffffd100Expect:|r /xui dev questions shows your earlier answers (Back to reach them); Copy answers lists them.",
      check = function()
          local r = RV.SV().review
          local n = NAnswers()
          return r.walkAnswers ~= nil and n >= r.walkAnswers and n > 0, ("%d answer(s) now; %s before the reload"):format(n, tostring(r.walkAnswers or "?"))
      end },
} })

QA.Register("review-open", { title = "Review window: Open a walkthrough from it (part 3)", area = "Dev Assist", qa = "J30", order = 302.7, prefill = true, steps = {
    { text = "Start this one from the review window: type |cffffd100/xui dev review|r and press |cffffd100Open|r on the row \"Review window: Open a walkthrough from it\" (under Dev Assist). If it is not listed (nothing changed since the build you acknowledged), press Open on any row, close that walkthrough, and come back here with /xui dev qa.\n\n|cffffd100Expect:|r the review window goes and the runner opens on the walkthrough you picked.",
      check = function()
          local id = RV.SV().review.lastOpened
          return id ~= nil, id and ("last opened from the review: " .. tostring(id)) or "nothing opened from the review yet"
      end },
    { text = "Press |cffffd100Pass|r here to finish, then close this window with its X (top right).\n\n|cffffd100Expect:|r when the runner closes, the review window comes back, and this walkthrough's row shows its new result.",
      noVerdict = true },
} })


-- (Dev Assist 0.7.52; Xaya 2026-11-07, REQUEST-LOG PS-16..PS-18: "an issue search bar and issues tags here to be able to navigate more
-- easily", then "the codes are fine to keep, all of this data just needs to be clearly put into tables with clear sortable rows and
-- columns (think excel style navigation)") the walkthrough table: search, tag chips, sortable columns (QATable.lua). It runs on the
-- review window, because the runner and All walkthroughs share one window; All walkthroughs has the same table (the last step).
-- Every check reads the table itself: what it shows, against what the search and tags should leave (prefill = true).
local function Tbl() local w = RV.Window(); return (w and w:IsShown() and w.tbl) or nil end
local function Need(t) if not t then return false, "the review window is not open: press Do it for me in step 1" end end
local function CountMatches(t, pred) local n = 0; for _, e in ipairs(t.entries) do if pred(e) then n = n + 1 end end; return n end
local function AllVisible(t, pred) for _, e in ipairs(t.visible) do if not pred(e) then return false end end; return true end
local function TitlesSorted(t, desc)
    for i = 2, #t.visible do
        local a, b = t.visible[i - 1].title:lower(), t.visible[i].title:lower()
        if (desc and a < b) or ((not desc) and a > b) then return false end
    end
    return true
end
local function OpenClear() RV.Show("walkthrough"); local t = Tbl(); if t then t:Clear() end; return t end
local SEARCH = "j32"
QA.Register("review-search", { title = "Walkthrough list: search, tags and sortable columns", area = "Dev Assist", qa = "J32", order = 302.9, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r (or type |cffffd100/xui dev review|r).\n\n|cffffd100Expect:|r the review window shows its walkthroughs as a table with the columns |cffffd100Codes | Title | Area | Status | New | Open|r (a colored header row, rows shaded every other line), above it a |cffffd100Search|r box, |cffffd100Clear|r and \"Showing N of N\", and a row of tags: Baseline, one per area, Not run, Passed, Failed, New or changed. Codes such as J31 or #210 sit in the Codes column, not in the title.",
      setup = function() OpenClear() end,
      check = function()
          local t = Tbl()
          if not t then return Need(t) end
          local h = {}
          for i, x in ipairs(t.headers) do h[i] = x.text:GetText() end
          local n = 0
          for _ in pairs(t.chips) do n = n + 1 end
          local ok = table.concat(h, " | ") == "Codes | Title | Area | Status | New | Open" and #t.visible == #t.entries and n >= 6
          return ok, ("header: %s; %d of %d rows shown; %d tags"):format(table.concat(h, " | "), #t.visible, #t.entries, n)
      end },
    { text = "Press |cffffd100Do it for me|r: it types |cffffd100J32|r (this walkthrough's own code) in the Search box. Then try a word of your own (for example |cffffd100dummy|r or |cffffd100chat|r), and clear the box again.\n\n|cffffd100Expect:|r the table narrows as you type to the walkthroughs whose title, id, codes, area or step text contain it (capital letters do not matter); the count follows.",
      setup = function() local t = OpenClear(); if t then t:Type("J32") end end,
      check = function()
          local t = Tbl()
          if not t then return Need(t) end
          local want = CountMatches(t, function(e) return e.hay:find(SEARCH, 1, true) ~= nil end)
          local ok = t.f.q == SEARCH and #t.visible == want and AllVisible(t, function(e) return e.hay:find(SEARCH, 1, true) ~= nil end)
          return ok, ("search \"%s\": %d row(s) shown, %d expected; count reads \"%s\""):format(t.f.q, #t.visible, want, tostring(t.count:GetText()))
      end },
    { text = "Press |cffffd100Do it for me|r: the box is cleared and the |cffffd100Baseline|r tag clicked.\n\n|cffffd100Expect:|r the tag turns green and only the rows marked |cffffd100Baseline|r (gold, after the title) stay. In All walkthroughs there are exactly 10.",
      setup = function() local t = OpenClear(); if t then t:ToggleChip("baseline") end end,
      check = function()
          local t = Tbl()
          if not t then return Need(t) end
          local want = CountMatches(t, function(e) return e.baseline end)
          local ok = t.f.base and #t.visible == want and AllVisible(t, function(e) return e.baseline end)
          return ok, ("Baseline on: %d row(s) shown, %d Baseline walkthrough(s) in this list (%d in all)"):format(#t.visible, want, #QA.BASELINE)
      end },
    { text = "Press |cffffd100Do it for me|r: with Baseline still on, the |cffffd100Not run|r and |cffffd100Passed|r tags are clicked too.\n\n|cffffd100Expect:|r tags of one kind add up (Not run OR Passed), tags of different kinds narrow (Baseline AND one of those): the rows left are Baseline walkthroughs that are not run or passed; a Failed one is hidden.",
      setup = function()
          local t = Tbl() or OpenClear()
          if not t then return end
          if not t.f.base then t:ToggleChip("baseline") end
          if not t.f.status.notrun then t:ToggleChip("status:notrun") end
          if not t.f.status.passed then t:ToggleChip("status:passed") end
      end,
      check = function()
          local t = Tbl()
          if not t then return Need(t) end
          local function pick(e) return e.baseline and (e.status == "notrun" or e.status == "passed") end
          local want = CountMatches(t, pick)
          local ok = t.f.base and t.f.status.notrun and t.f.status.passed and #t.visible == want and AllVisible(t, pick)
          return ok, ("Baseline + (Not run or Passed): %d row(s) shown, %d expected"):format(#t.visible, want)
      end },
    { text = "Press |cffffd100Do it for me|r: the tags are cleared and the |cffffd100Title|r column header clicked.\n\n|cffffd100Expect:|r the rows sort A to Z by title and the Title header shows |cffffd100^|r.",
      setup = function()
          local t = OpenClear()
          if not t then return end
          t.sortKey, t.sortDesc = nil, false
          t:SortBy("title")
      end,
      check = function()
          local t = Tbl()
          if not t then return Need(t) end
          local def = QA.Table.View(t.entries, t.f, nil, false)
          local moved = false
          for i, e in ipairs(def) do if t.visible[i] ~= e then moved = true; break end end
          local hdr = t.headers[2].text:GetText()
          local ok = t.sortKey == "title" and not t.sortDesc and TitlesSorted(t, false) and hdr:find("^", 1, true) ~= nil and (moved or #def < 2)
          return ok, ("sorted by %s, %s; order %s the default; header \"%s\""):format(tostring(t.sortKey), t.sortDesc and "Z to A" or "A to Z",
              moved and "differs from" or "same as", tostring(hdr))
      end },
    { text = "Press |cffffd100Do it for me|r (or click the |cffffd100Title|r header again).\n\n|cffffd100Expect:|r the order reverses (Z to A) and the header shows |cffffd100v|r. Clicking another header (Codes, Area, Status, New) sorts by that one instead; Area A to Z is the order the window opened with.",
      setup = function() local t = Tbl(); if t then if t.sortKey ~= "title" then t:SortBy("title") end; t:SortBy("title") end end,
      check = function()
          local t = Tbl()
          if not t then return Need(t) end
          local hdr = t.headers[2].text:GetText()
          local ok = t.sortKey == "title" and t.sortDesc and TitlesSorted(t, true) and hdr:find("v", #hdr - 1, true) ~= nil
          return ok, ("sorted by %s, %s; header \"%s\""):format(tostring(t.sortKey), t.sortDesc and "Z to A" or "A to Z", tostring(hdr))
      end },
    { text = "Type something in the Search box and click two tags, then press |cffffd100Clear|r yourself and press |cffffd100Check again|r.\n\n|cffffd100Expect:|r the box empties, no tag is green, every row is back (\"Showing N of N\"). The sort you picked stays until you close the window.",
      check = function()
          local t = Tbl()
          if not t then return Need(t) end
          local on = 0
          for _, b in pairs(t.chips) do if b.on then on = on + 1 end end
          local ok = t.f.q == "" and on == 0 and #t.visible == #t.entries
          return ok, ("search \"%s\", %d tag(s) on, %d of %d rows shown"):format(t.f.q, on, #t.visible, #t.entries)
      end },
    { text = "Last step: look at the rows marked |cffffd100Baseline|r, then after this walkthrough open |cffffd100/xui dev qa|r (All walkthroughs): the same table, search and tags are there for every walkthrough. After a /reload the search box is empty and no tag is on (nothing of it is saved).\n\n|cffffd100Your call:|r are the Baseline titles plain words you understand? Pass = yes; Fail = no (name the ones that are not in the note).",
      noVerdict = true },
} })


-- (Dev Assist 0.7.53; docs/plans/PLATFORM-SPLIT-2026-11-07.md section 15, P0.5; issues #461, #465, #484) the runner's own rules, tried on
-- three walkthroughs in a row (J33): a step with Do it for me cannot be passed before it ran; a clean-up step has Done instead of Pass /
-- Fail; a run with every step skipped reads Skipped; the Done page's Next in this list follows the list it was opened from, and the
-- list keeps its search, tags and sort. The checks read the runner's own window and the saved results (prefill = true).
local nav = {}   -- memory only: what the window showed when Do it for me was pressed
local function QW() return QA.Window and QA.Window() end
QA.Register("qa-runner-nav", { title = "Walkthrough runner: Do it for me first, Done steps, Skipped and the Done page (part 1 of 3)", area = "Dev Assist", qa = "J33", order = 303, prefill = true, steps = {
    { text = "Start this from |cffffd100All walkthroughs|r: type |cffffd100J33|r in its Search box and press |cffffd100Open|r on this row (part 1). If you opened it another way, press All walkthroughs (bottom left), search J33 and Open it again.\n\nBefore you press anything else, look: |cffffd100Pass|r is greyed out and the line above the buttons says \"Press Do it for me first\". Then press |cffffd100Do it for me|r.\n\n|cffffd100Expect:|r after it, Pass works and the addon offers its verdict.",
        setup = function()
            local w, st = QW(), QA.State and QA.State()
            nav.passBefore = w and w.pass:IsEnabled() and true or false
            nav.checkBefore = w and tostring(w.check:GetText() or "") or ""
            nav.order = st and st.order
        end,
        check = function()
            if nav.passBefore == nil then return false, "press Do it for me" end
            local gated = nav.passBefore == false and nav.checkBefore:find("Do it for me first", 1, true) ~= nil
            local list, nextOk = nav.order, false
            for i, id in ipairs(list or {}) do if id == "qa-runner-nav" and list[i + 1] == "qa-runner-skip" then nextOk = true end end
            return (gated and nextOk) and true or false, ("before Do it for me: Pass %s, the check said \"%s\"; opened from a list with the sample next: %s"):format(
                nav.passBefore and "ENABLED" or "greyed", nav.checkBefore:sub(1, 60), nextOk and "yes" or "NO (open this from All walkthroughs with J33 typed)")
        end },
    { done = true, text = "A clean-up kind of step: no Pass and no Fail, one |cffffd100Done|r button (greyed until Do it for me ran). Press |cffffd100Do it for me|r, then |cffffd100Done|r.\n\nOn the page that follows press |cffffd100Next in this list|r.\n\n|cffffd100Expect:|r that page has All walkthroughs, Review list and Next in this list; Next opens \"Walkthrough runner: a sample to skip (part 2 of 3)\".",
        setup = function() nav.doneSeen = true end,
        check = function()
            local w = QW(); if not w then return false, "the runner window is not open" end
            local ok = w.doneBtn:IsShown() and w.doneBtn:IsEnabled() and not w.pass:IsShown() and not w.fail:IsShown()
            return ok and true or false, ("Done button %s; Pass / Fail %s"):format(w.doneBtn:IsShown() and "shown" or "NOT shown", (w.pass:IsShown() or w.fail:IsShown()) and "SHOWN" or "hidden")
        end },
} })
QA.Register("qa-runner-skip", { title = "Walkthrough runner: a sample to skip (part 2 of 3)", area = "Dev Assist", qa = "J33", order = 303.01, prefill = true, steps = {
    { text = "Press |cffffd100Skip|r on this step and the next. On the page that follows press |cffffd100Next in this list|r.\n\n|cffffd100Expect:|r the page says \"Skipped: no step was passed or failed\"; Next opens part 3." },
    { text = "Press |cffffd100Skip|r." },
} })
QA.Register("qa-runner-nav-2", { title = "Walkthrough runner: Next in this list, Skipped and the list kept (part 3 of 3)", area = "Dev Assist", qa = "J33", order = 303.02, prefill = true, steps = {
    { text = "You came here with |cffffd100Next in this list|r from part 2.\n\n|cffffd100Expect:|r this walkthrough opened straight from part 2's Done page.",
        check = function()
            local ln = QA.lastNext
            local p1 = QA.DB().results["qa-runner-nav"]
            local done = p1 and p1.steps and p1.steps[2] and p1.steps[2].r == "D"
            local ok = ln and ln.from == "qa-runner-skip" and ln.to == "qa-runner-nav-2"
            return (ok and done) and true or false, ("Next went from %s to %s; part 1's clean-up step recorded as Done: %s"):format(tostring(ln and ln.from), tostring(ln and ln.to), done and "yes" or "NO")
        end },
    { text = "Look at part 2's row in |cffffd100All walkthroughs|r or the review list after this walkthrough (or trust the check).\n\n|cffffd100Expect:|r its Status reads |cffffd100Skipped|r (not Passed): you skipped every step.",
        check = function()
            local st = QA.Table and QA.Table.Status("qa-runner-skip")
            local txt = QA.StatusText and QA.StatusText("qa-runner-skip") or ""
            return st == "skipped" and txt:find("Skipped", 1, true) ~= nil, ("part 2's status: %s (%s)"):format(tostring(st), txt:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
        end },
    { done = true, text = "Last step: press |cffffd100Done|r, then on the page that follows press |cffffd100All walkthroughs|r.\n\n|cffffd100Expect:|r J33 is still typed in its Search box, and the tags and sort you had are as you left them (until you close the game). Its |cffffd100Review list|r button (top right) opens the review window with its own search and tags as you left them.",
        check = function()
            local w = QW(); local t = w and w.tbl
            if not t then return false, "All walkthroughs has no table" end
            return t.f.q == "j33", ("All walkthroughs still holds: search \"%s\", sorted by %s"):format(tostring(t.f.q), tostring(t.sortKey or "the default order"))
        end },
} })
