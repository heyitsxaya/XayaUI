-------------------------------------------------------------------------------
-- QAQuestions.lua (XayaUI_DevAssist 0.7.30): the open questions for Xaya, shown one per screen by the question flow (QAReview.lua,
-- /xui dev questions, and "Questions (N)" on the review window). Her words (2026-11-07 ~08:25 UTC): "I want all outstanding questions to
-- be nested within a qa question prompt flow so I know what you had to execute blindly and need feedback on."
--
-- ONE data file, owned by the review-popup build session: other sessions send their entries (to it or through the hub) and it adds them
-- here, so no other file or .toc line changes. Each entry:
--   key    the request-log / question id (an answer is saved under it: keep it stable)
--   area   the feature
--   words  Xaya's own words, VERBATIM (never paraphrased)
--   did    what shipped (or was held) without asking her, plainly
--   choices  1-4 alternatives; "Keep it" (keep what was done) is always the first choice by itself
--   since  the addon and version it shipped in (or "held" when it did not ship)
-- Only entries whose words and "did" text come from the session that did the work (or the repository) are written here: nothing is
-- invented. A question that is answered stays registered until its answer is acted on, so Back can still reach it.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not (QA and QA.RegisterQuestion) then return end
local Q = QA.RegisterQuestion

-- The review window and question flow (this build). Her request, verbatim, for all four:
local REVIEW_WORDS = "I want a qa review checklist pushed and displayed as a popup for everything that needs review when I first load into the game and I want all outstanding questions to be nested within a qa question prompt flow so I know what you had to execute blindly and need feedback on."

Q{ key = "REVIEW-1", area = "Dev Assist: review window", order = 10, since = "Dev Assist 0.7.30", words = REVIEW_WORDS,
   did = "The review window opens by itself on the first load of a session (login or /reload) after the XayaUI versions change, a moment after the loading screen (after combat if you are fighting). It keeps coming back at each login or /reload until you tick \"Don't show again until the next update\".",
   choices = { "Show it only once per update, ticked or not", "Never open it by itself; I will use /xui dev review" } }

Q{ key = "REVIEW-2", area = "Dev Assist: review window", order = 11, since = "Dev Assist 0.7.30", words = REVIEW_WORDS,
   did = "A walkthrough is listed when it is new, or its title or any step's text changed, since the build you acknowledged (walkthroughs carry no version of their own). The first time (no build acknowledged yet) every walkthrough is listed, including the ones made from the QA checklist.",
   choices = { "First time: list only the walkthroughs I have not run yet", "Also list every walkthrough whose last result has a Fail", "Leave the QA checklist walkthroughs out of the list" } }

Q{ key = "REVIEW-3", area = "Dev Assist: review window", order = 12, since = "Dev Assist 0.7.30", words = REVIEW_WORDS,
   did = "Open hides the review window and starts that walkthrough in the /xui dev qa runner; when you close the runner, the review window comes back with the new verdict.",
   choices = { "Keep the review window open beside the walkthrough" } }

Q{ key = "REVIEW-4", area = "Dev Assist: question flow", order = 13, since = "Dev Assist 0.7.30", words = REVIEW_WORDS,
   did = "The question flow starts at the first question you have not answered. Answered questions stay in the list (Back reaches them, your answer is shown and can be changed). Next needs an answer or a note; Skip moves on without saving. \"Questions (N)\" counts the unanswered ones.",
   choices = { "Hide the questions I have answered", "Let Next move on without an answer (like Skip)" } }

-- D8 session (session_014bN6tTZroPi49dAYwBbeGp), relayed by the hub's brief (2026-11-07). Her words as the brief quotes them (O-109).
Q{ key = "O-109", area = "Rules: load conditions", order = 100, since = "held (not shipped)",
   words = "Hold the rule load condition changes",
   did = "The rule load condition changes were held: they are not on main and not in your installed build.",
   choices = { "Ship them now", "Show me what they change first (a walkthrough), then ship" } }
