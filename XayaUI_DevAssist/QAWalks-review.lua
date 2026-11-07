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
    { text = "Press |cffffd100Do it for me|r (or type |cffffd100/xui dev review|r).\n\n|cffffd100Expect:|r a window \"Review: what's new to test\": the walkthroughs new or changed since the build you last acknowledged, under area headings, each with its key in grey, its title, \"new\" or \"changed\", its last result and an |cffffd100Open|r button. At the bottom: the tick box \"Don't show again until the next update\", |cffffd100Questions (N)|r, All walkthroughs and Close.",
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
    { text = "Last step. Press |cffffd100Do it for me|r: the addon forgets which build you acknowledged (so the next load counts as an update) and remembers how many answers you have now.\n\nThen find a training dummy, attack it, and while you are |cffffd100in combat|r type |cffffd100/reload|r. Keep fighting for a few seconds after the loading screen, then stop.\n\n|cffffd100Expect:|r no review window while you are in combat; it opens a moment after combat ends. Then run \"Review window and questions (part 2)\".",
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

