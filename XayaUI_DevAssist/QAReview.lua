-------------------------------------------------------------------------------
-- QAReview.lua (XayaUI_DevAssist 0.7.30): the "Review: what's new to test" window and the question flow.
-- Xaya 2026-11-07 ~08:25 UTC (her words): "I want a qa review checklist pushed and displayed as a popup for everything that needs review
-- when I first load into the game and I want all outstanding questions to be nested within a qa question prompt flow so I know what you
-- had to execute blindly and need feedback on."
--
-- 1. The review window. On the first PLAYER_ENTERING_WORLD of a session, when the installed XayaUI* versions differ from the ones she
--    last acknowledged, it opens (a moment after the loading screen; never in combat: it waits for combat to end). It lists every QA
--    walkthrough (XayaUI_DevQA.Register) that is new or changed since the acknowledged build, grouped by area, each with its key, title,
--    verdict and an Open button (the /xui dev qa runner). "Don't show again until the next update" acknowledges this build; without it the
--    window comes back on the next login or /reload. "Questions (N)" opens part 2. Reopen: /xui dev review (also /xuidev review).
--    "Changed" = the walkthrough's title or step texts differ (QA.Fingerprint, QAWalk.lua); walkthroughs carry no version of their own.
-- 2. The question flow: the open questions (XayaUI_DevQA.RegisterQuestion, data in QAQuestions.lua), one per screen: the area, her own
--    words, what was done without asking, "Keep it" plus the alternatives, a note; Back / Skip / Next and a count. Answers are kept in
--    XayaUIDevAssistDB.questions (with the time and Dev Assist's version). "Copy answers" puts them in a text box to copy (Ctrl+C; an
--    addon cannot write the clipboard). Reopen: /xui dev questions.
-- 3. (0.7.52; Xaya 2026-11-07, REQUEST-LOG PS-16..PS-18) the list is a table, Codes | Title | Area | Status | New | Open, with a search
--    box, tag chips and sortable columns (QATable.lua, shared with All walkthroughs); the window is 900 x 560 for it.
-- 4. (0.7.53) the intro line is measured and the search row placed below it (#466); the background is 0.95 opaque (#481); a walkthrough
--    opened here gets the table's order for the runner's "Next in this list" (#465).
-- V14: no window is made until one opens; at load only one small event frame exists, and it stops listening after the first
-- PLAYER_ENTERING_WORLD (or after combat ends, when it had to wait). UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end
local RV = {}
QA.Review = RV

local ACC = { 0.55, 0.35, 0.95 }
local function Clean(s, max) s = tostring(s or ""):gsub("|", ""):gsub("[%c]", " "); return s:sub(1, max or 300) end
local function Esc(s) return (tostring(s or ""):gsub("|", "||")) end   -- show text as written (no colour codes)
local function Now() return time and time() or 0 end
local function DevVersion()
    local ok, v = pcall(function() return C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("XayaUI_DevAssist", "Version") end)
    return ok and v or "?"
end
local function InCombat()
    if InCombatLockdown and InCombatLockdown() then return true end
    return (UnitAffectingCombat and UnitAffectingCombat("player")) and true or false
end

local function SV()
    XayaUIDevAssistDB = XayaUIDevAssistDB or {}
    local d = XayaUIDevAssistDB
    d.review = type(d.review) == "table" and d.review or {}
    d.questions = type(d.questions) == "table" and d.questions or {}
    d.questions.answers = type(d.questions.answers) == "table" and d.questions.answers or {}
    return d
end
RV.SV = SV

-------------------------------------------------------------------------------
-- Versions and the acknowledged build
-------------------------------------------------------------------------------
-- "XayaUI=0.6.80;XayaUI_Chat=0.4.2;..." for every installed addon whose folder name starts with XayaUI (switched on or not)
function RV.Signature()
    local list = {}
    local okN, n = pcall(function() return C_AddOns.GetNumAddOns() end)
    for i = 1, (okN and tonumber(n) or 0) do
        local okI, name = pcall(C_AddOns.GetAddOnInfo, i)
        if okI and type(name) == "string" and name:find("^XayaUI") then
            local okV, v = pcall(C_AddOns.GetAddOnMetadata, name, "Version")
            list[#list + 1] = name .. "=" .. tostring(okV and v or "?")
        end
    end
    table.sort(list)
    return table.concat(list, ";")
end
local function AllPrints()
    local t = {}
    for _, id in ipairs(QA.list) do t[id] = QA.Fingerprint(QA.walks[id]) end
    return t
end
function RV.Acknowledged() local r = SV().review; return r.ack ~= nil and r.ack.sig == RV.Signature() end
-- the build the list compares with: the acknowledged one, or (when this build is already acknowledged) the one before it
local function Base()
    local r, sig = SV().review, RV.Signature()
    if r.ack and r.ack.sig == sig then return r.prev end
    return r.ack
end
local undo   -- (this session only) what ticking the box replaced, so unticking puts it back
function RV.Acknowledge(on)
    local r, sig = SV().review, RV.Signature()
    if on then
        if r.ack and r.ack.sig == sig then return end
        undo = { ack = r.ack, prev = r.prev }
        r.prev = r.ack
        r.ack = { sig = sig, fps = AllPrints(), when = Now() }
    elseif r.ack and r.ack.sig == sig then
        if undo then r.ack, r.prev = undo.ack, undo.prev; undo = nil else r.ack = r.prev; r.prev = nil end
    end
end

-- areas: a walkthrough's own area, else one read from its id (the walkthrough files name their ids by area)
local PREFIX = { group = "Groups and displays", display = "Groups and displays", mover = "Groups and displays", dynamic = "Groups and displays",
    sidebar = "Rules sidebar", reskin = "Blizzard Reskin", shopping = "Shopping List", chat = "Chat", ui = "Settings window",
    perf = "Dev Assist", debug = "Dev Assist", review = "Dev Assist" }
function RV.Area(def)
    if type(def.area) == "string" and def.area ~= "" then return def.area end
    if def.generated then return "QA checklist (from docs/QA-CHECKLIST.md)" end
    local p = tostring(def.id or ""):match("^(%a+)")
    return PREFIX[p or ""] or "Other"
end
-- the walkthroughs new or changed since the base build: { { id, area, state = "new" | "changed" }, ... }, firstTime
function RV.Changed()
    local base, out = Base(), {}
    for _, id in ipairs(QA.list) do
        local def = QA.walks[id]
        local old = base and type(base.fps) == "table" and base.fps[id]
        local state = (not old) and "new" or (old ~= QA.Fingerprint(def) and "changed") or nil
        if state then out[#out + 1] = { id = id, area = RV.Area(def), state = state } end
    end
    local order = {}
    for i, e in ipairs(out) do order[e] = i end
    table.sort(out, function(a, b) if a.area ~= b.area then return a.area < b.area end; return order[a] < order[b] end)
    return out, base == nil
end
-- the verdict text: the runner's own, plus a note when the result was recorded against an older text of the walkthrough
function RV.Verdict(id)
    local txt = QA.StatusText and QA.StatusText(id) or ""
    local res = QA.DB().results[id]
    if res and res.fp and res.fp ~= QA.Fingerprint(QA.walks[id]) then txt = txt .. " |cffffaa00(before it changed: run it again)|r" end
    return txt
end

-------------------------------------------------------------------------------
-- Questions
-------------------------------------------------------------------------------
QA.questions, QA.questionByKey = {}, {}
-- XayaUI_DevQA.RegisterQuestion{ key, area, words, did, choices = { "...", ... } (1-4 alternatives; "Keep it" comes first by itself),
-- since = "<addon version it shipped in>", order (optional) }
function QA.RegisterQuestion(q)
    if type(q) ~= "table" or type(q.key) ~= "string" or q.key == "" or type(q.did) ~= "string" then return end
    if q.words ~= nil and type(q.words) ~= "string" then return end
    -- keep = the first choice's label when "Keep it" does not fit (a question where nothing was decided yet)
    local choices = { type(q.keep) == "string" and q.keep ~= "" and q.keep or "Keep it" }
    for i, c in ipairs(type(q.choices) == "table" and q.choices or {}) do
        if i > 4 then break end
        if type(c) == "string" and c ~= "" then choices[#choices + 1] = c end
    end
    local e = { key = q.key, area = tostring(q.area or "Other"), words = (q.words ~= "" and q.words) or nil, wordsNote = q.wordsNote, did = q.did, choices = choices, ask = q.ask,
        since = tostring(q.since or ""), order = tonumber(q.order) or (#QA.questions + 1) }
    if QA.questionByKey[q.key] then
        for i, x in ipairs(QA.questions) do if x.key == q.key then e.order = x.order; QA.questions[i] = e end end
    else QA.questions[#QA.questions + 1] = e end
    QA.questionByKey[q.key] = e
    table.sort(QA.questions, function(a, b) if a.order ~= b.order then return a.order < b.order end; return a.key < b.key end)
end
local function Answers() return SV().questions.answers end
function RV.OpenCount()
    local n, a = 0, Answers()
    for _, q in ipairs(QA.questions) do if not a[q.key] then n = n + 1 end end
    return n
end
function RV.SaveAnswer(key, choiceIndex, note)
    local q = QA.questionByKey[key]
    if not q then return false end
    note = Clean(note, 300)
    if not choiceIndex and note == "" then return false end
    local ci = tonumber(choiceIndex)
    Answers()[key] = { c = ci, choice = ci and q.choices[ci] or nil, note = note ~= "" and note or nil,
        when = Now(), at = date and date("!%Y-%m-%d %H:%M UTC") or "", v = DevVersion(), since = q.since ~= "" and q.since or nil }
    return true
end
-- the text for "Copy answers": one line per answered question, in the questions' order
function RV.AnswersText()
    local a, lines = Answers(), { ("XayaUI QA answers (Dev Assist %s, copied %s)"):format(DevVersion(), date and date("!%Y-%m-%d %H:%M UTC") or "") }
    local n = 0
    for _, q in ipairs(QA.questions) do
        local x = a[q.key]
        if x then
            n = n + 1
            lines[#lines + 1] = ("[%s] %s: %s%s  (%s, Dev Assist %s)"):format(q.key, q.area, x.choice or "(no choice)",
                x.note and ("; note: " .. x.note) or "", tostring(x.at or ""), tostring(x.v or "?"))
        end
    end
    -- answers to questions no longer registered are kept and copied too (nothing she typed is dropped)
    local extra = {}
    for k in pairs(a) do if not QA.questionByKey[k] then extra[#extra + 1] = k end end
    table.sort(extra)
    for _, k in ipairs(extra) do
        local x = a[k]
        lines[#lines + 1] = ("[%s] %s%s  (%s, Dev Assist %s)"):format(k, tostring(x.choice or "(no choice)"), x.note and ("; note: " .. x.note) or "",
            tostring(x.at or ""), tostring(x.v or "?"))
        n = n + 1
    end
    if n == 0 then lines[#lines + 1] = "(no answers yet)" end
    return table.concat(lines, "\n")
end

-------------------------------------------------------------------------------
-- Shared look
-------------------------------------------------------------------------------
local function Btn(parent, label, w, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w or 90, 22); b:SetText(label)
    local cns = rawget(_G, "XayaUI_NS")
    if cns and cns.FlatButton then cns.FlatButton(b) end
    b:SetScript("OnClick", onClick)
    return b
end
local function Window(name, w, h)
    local f = CreateFrame("Frame", name, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    f:SetSize(w, h); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true)
    f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    if QA.SolidBackground then QA.SolidBackground(f)   -- (0.7.53, #481: 0.95 opaque, provisional; QAWalk.lua)
    elseif f.SetBackdrop then
        f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        f:SetBackdropColor(0.05, 0.05, 0.07, 0.96); f:SetBackdropBorderColor(ACC[1], ACC[2], ACC[3], 1)
    end
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); f.title:SetPoint("TOPLEFT", 14, -12)
    f.title:SetWidth(w - 14 - 36); f.title:SetJustifyH("LEFT"); f.title:SetWordWrap(true)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", 2, 2)
    if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = name end   -- (Escape closes it)
    f:Hide()
    return f
end
local function Scroll(parent, w)
    local s = CreateFrame("ScrollFrame", nil, parent)
    local c = CreateFrame("Frame", nil, s); c:SetSize(w, 10); s:SetScrollChild(c)
    s:EnableMouseWheel(true)
    s:SetScript("OnMouseWheel", function(self, d)
        local maxS = math.max(0, (c:GetHeight() or 0) - (self:GetHeight() or 0))
        self:SetVerticalScroll(math.max(0, math.min(maxS, (self:GetVerticalScroll() or 0) - d * 40)))
    end)
    return s, c
end

-------------------------------------------------------------------------------
-- The review window
-------------------------------------------------------------------------------
local RW
local fromReview = false   -- a walkthrough opened from the review: when the runner closes, the review comes back
local function BuildReview()
    if RW then return end
    RW = Window("XayaUIDevReviewWindow", 900, 560)
    RW.sub = RW:CreateFontString(nil, "OVERLAY", "GameFontDisable"); RW.sub:SetPoint("TOPLEFT", 14, -36); RW.sub:SetWidth(870); RW.sub:SetJustifyH("LEFT")
    -- (0.7.52) the table with search, tag chips and sortable columns (QATable.lua, shared with All walkthroughs)
    RW.tbl = QA.Table.Create(RW, { left = 14, top = 56, bottom = 70, width = 872, onOpen = function(id) RV.OpenWalk(id, RW.tbl:Ids()) end })
    RW.rows, RW.headers = RW.tbl.rows, RW.tbl.headers
    RW.dont = CreateFrame("CheckButton", nil, RW, "UICheckButtonTemplate"); RW.dont:SetSize(24, 24); RW.dont:SetPoint("BOTTOMLEFT", 10, 38)
    RW.dontLabel = RW:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); RW.dontLabel:SetPoint("LEFT", RW.dont, "RIGHT", 4, 0)
    RW.dontLabel:SetText("Don't show again until the next update")
    RW.dont:SetScript("OnClick", function(self) RV.Acknowledge(self:GetChecked() and true or false) end)
    RW.questions = Btn(RW, "Questions", 140, function() RV.ShowQuestions() end); RW.questions:SetPoint("BOTTOMLEFT", 14, 10)
    RW.all = Btn(RW, "All walkthroughs", 140, function() RW:Hide(); if QA.Toggle then QA.Toggle() end end); RW.all:SetPoint("LEFT", RW.questions, "RIGHT", 8, 0)
    RW.close = Btn(RW, "Close", 90, function() RW:Hide() end); RW.close:SetPoint("BOTTOMRIGHT", -14, 10)
end
function RV.Fill()
    BuildReview()
    local list, first = RV.Changed()
    RW.title:SetText("Review: what's new to test")
    RW.sub:SetText(first and ("First time: every walkthrough is listed (%d). Tick the box below once you have looked, and the next update lists only what is new or changed."):format(#list)
        or (#list == 0 and "Nothing new or changed since the build you acknowledged." or ("%d walkthrough(s) new or changed since the build you acknowledged."):format(#list)))
    -- (0.7.53, #466) the intro line can wrap (long text, a bigger text size): the title and the intro are measured and the search row
    -- starts below them, so nothing overlaps
    local subTop = QA.TitleBottom and QA.TitleBottom(RW.title) or 36
    RW.sub:ClearAllPoints(); RW.sub:SetPoint("TOPLEFT", 14, -subTop)
    local sh = RW.sub.GetStringHeight and RW.sub:GetStringHeight() or 12
    if type(sh) ~= "number" or sh < 10 then sh = 12 end
    RW.tbl:SetTop(math.max(56, subTop + math.ceil(sh) + 10))
    RW.tbl:SetEntries(list)
    RW.questions:SetText(("Questions (%d)"):format(RV.OpenCount()))
    RW.dont:SetChecked(RV.Acknowledged())
    RW.list = list
end
function RV.Show(why)
    RV.Fill()
    RW:Show()
    local r = SV().review
    r.lastShown = { when = Now(), sig = RV.Signature(), why = tostring(why or "command"), combat = InCombat() }
end
function RV.Toggle() if RW and RW:IsShown() then RW:Hide() else RV.Show("command") end end
-- order: the ids as the review's table showed them when Open was pressed (the runner's Next in this list follows it, 0.7.53)
function RV.OpenWalk(id, order)
    if not (id and QA.walks[id]) then return end
    SV().review.lastOpened = id
    if RW then RW:Hide() end
    fromReview = true
    QA.Start(id, { order = order, from = "review" })
    local qw = QA.Window and QA.Window()
    if qw and not qw.xuiReviewHook then
        qw.xuiReviewHook = true
        qw:HookScript("OnHide", function() if fromReview then fromReview = false; RV.Show("back from a walkthrough") end end)
    end
end
-- (0.7.53) the runner went elsewhere on her click (All walkthroughs, Review list): closing it later does not bring the review back
function RV.ForgetReturn() fromReview = false end
RV.Returning = function() return fromReview end   -- (tests)
function RV.Window() return RW end   -- (tests)

-------------------------------------------------------------------------------
-- The question flow
-------------------------------------------------------------------------------
local QW
local qi, pick = 1, nil
local MAXC = 5
local ShowQuestion, ShowCopy
local function BuildQuestions()
    if QW then return end
    QW = Window("XayaUIDevQuestionsWindow", 700, 500)
    QW.count = QW:CreateFontString(nil, "OVERLAY", "GameFontDisable"); QW.count:SetPoint("TOPLEFT", 14, -36)
    QW.scroll, QW.child = Scroll(QW, 660)
    QW.scroll:SetPoint("TOPLEFT", 14, -58); QW.scroll:SetPoint("BOTTOMRIGHT", -14, 240)
    QW.text = QW.child:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); QW.text:SetPoint("TOPLEFT", 0, 0); QW.text:SetWidth(655)
    QW.text:SetJustifyH("LEFT"); QW.text:SetJustifyV("TOP"); if QW.text.SetSpacing then QW.text:SetSpacing(3) end
    QW.choices = {}
    for i = 1, MAXC do
        local c = CreateFrame("CheckButton", nil, QW, "UICheckButtonTemplate"); c:SetSize(22, 22)
        c:SetPoint("TOPLEFT", QW, "BOTTOMLEFT", 12, 236 - (i - 1) * 24)
        c.label = QW:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); c.label:SetPoint("LEFT", c, "RIGHT", 4, 0); c.label:SetWidth(630); c.label:SetJustifyH("LEFT")
        c:SetScript("OnClick", function() RV.Pick(i) end)
        QW.choices[i] = c
    end
    QW.noteLabel = QW:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); QW.noteLabel:SetPoint("BOTTOMLEFT", 14, 86)
    QW.noteLabel:SetText("Note (optional): anything to add, or your own answer")
    QW.note = CreateFrame("EditBox", nil, QW, "InputBoxTemplate"); QW.note:SetSize(660, 20); QW.note:SetPoint("BOTTOMLEFT", 20, 62); QW.note:SetAutoFocus(false)
    do local cns = rawget(_G, "XayaUI_NS"); if cns and cns.KeyFocusGuard then cns.KeyFocusGuard(QW.note) end end   -- (row 56) lets go of the keyboard: Enter / Esc / a click outside / hiding (core KeyCatch.lua)
    QW.hint = QW:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); QW.hint:SetPoint("BOTTOMLEFT", 14, 42)
    QW.back = Btn(QW, "Back", 90, function() RV.Back() end); QW.back:SetPoint("BOTTOMLEFT", 14, 10)
    QW.copy = Btn(QW, "Copy answers", 120, function() ShowCopy() end); QW.copy:SetPoint("LEFT", QW.back, "RIGHT", 8, 0)
    QW.review = Btn(QW, "Review list", 110, function() QW:Hide(); RV.Show("from the questions") end); QW.review:SetPoint("LEFT", QW.copy, "RIGHT", 8, 0)
    QW.next = Btn(QW, "Next", 90, function() RV.Next() end); QW.next:SetPoint("BOTTOMRIGHT", -14, 10)
    QW.skip = Btn(QW, "Skip", 90, function() RV.Skip() end); QW.skip:SetPoint("RIGHT", QW.next, "LEFT", -8, 0)
    -- the copy page: a text box to select and copy (Ctrl+C)
    QW.copyLabel = QW:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); QW.copyLabel:SetPoint("TOPLEFT", 14, -36); QW.copyLabel:SetWidth(670); QW.copyLabel:SetJustifyH("LEFT")
    QW.copyScroll = CreateFrame("ScrollFrame", nil, QW, "UIPanelScrollFrameTemplate")
    QW.copyScroll:SetPoint("TOPLEFT", 14, -78); QW.copyScroll:SetPoint("BOTTOMRIGHT", -34, 44)
    QW.copyBox = CreateFrame("EditBox", nil, QW.copyScroll); QW.copyBox:SetMultiLine(true); QW.copyBox:SetAutoFocus(false)
    QW.copyBox:SetFontObject(ChatFontNormal or GameFontHighlight); QW.copyBox:SetWidth(640)
    QW.copyBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    QW.copyScroll:SetScrollChild(QW.copyBox)
    do local cns = rawget(_G, "XayaUI_NS"); if cns and cns.KeyFocusGuard then cns.KeyFocusGuard(QW.copyBox) end end   -- (row 56) lets go of the keyboard: Enter / Esc / a click outside / hiding (core KeyCatch.lua)
    QW.backToQ = Btn(QW, "Back to the questions", 170, function() ShowQuestion() end); QW.backToQ:SetPoint("BOTTOMLEFT", 14, 10)
    QW.select = Btn(QW, "Select all", 100, function() QW.copyBox:SetFocus(); QW.copyBox:HighlightText() end); QW.select:SetPoint("BOTTOMRIGHT", -14, 10)
end
local Q_WIDGETS = { "count", "scroll", "noteLabel", "note", "hint", "back", "copy", "review", "next", "skip" }
local C_WIDGETS = { "copyLabel", "copyScroll", "backToQ", "select" }
local function Page(copy)
    for _, k in ipairs(Q_WIDGETS) do QW[k]:SetShown(not copy) end
    for _, k in ipairs(C_WIDGETS) do QW[k]:SetShown(copy and true or false) end
    for _, c in ipairs(QW.choices) do c:SetShown(false); c.label:SetShown(false) end
end
function RV.Pick(i)
    pick = i
    for j, c in ipairs(QW.choices) do c:SetChecked(j == i) end
end
function ShowQuestion()
    BuildQuestions()
    Page(false)
    QW.title:SetText("Questions: what we did without asking you")
    local n = #QA.questions
    if n == 0 then
        QW.count:SetText("No open questions.")
        QW.text:SetText(""); QW.next:Disable(); QW.skip:Disable(); QW.back:Disable(); QW.note:Hide(); QW.noteLabel:Hide(); QW.hint:SetText("")
        QW:Show(); return
    end
    qi = math.max(1, math.min(n, qi))
    local q, a = QA.questions[qi], Answers()
    local x = a[q.key]
    local done = 0
    for _, e in ipairs(QA.questions) do if a[e.key] then done = done + 1 end end
    QW.count:SetText(("Question %d of %d  (%d answered)%s"):format(qi, n, done, x and "  |cff60ff60answered|r" or ""))
    local words = q.words and ("\"" .. Esc(q.words) .. "\"") or ("|cff999999(no words of yours: " .. Esc(q.wordsNote or "this came up during the work") .. ")|r")
    QW.text:SetText(("|cffffd100Area:|r %s   |cff999999[%s]%s|r\n\n|cffffd100Your words:|r\n%s\n\n|cffffd100What we did without asking:|r\n%s%s"):format(
        Esc(q.area), Esc(q.key), q.since ~= "" and ("  " .. Esc(q.since)) or "", words, Esc(q.did),
        q.ask and ("\n\n|cffffd100The question:|r " .. Esc(q.ask)) or ""))
    QW.child:SetHeight(math.max(10, (QW.text.GetStringHeight and QW.text:GetStringHeight() or 0) + 4)); QW.scroll:SetVerticalScroll(0)
    for i, c in ipairs(QW.choices) do
        local label = q.choices[i]
        c:SetShown(label ~= nil); c.label:SetShown(label ~= nil)
        if label then c.label:SetText(i == 1 and ("|cff60ff60" .. Esc(label) .. "|r") or Esc(label)) end
    end
    RV.Pick(x and x.c or nil)
    QW.note:SetText(x and x.note or "")
    QW.hint:SetText("")
    QW.back:SetEnabled(qi > 1); QW.next:Enable(); QW.skip:Enable()
    QW.next:SetText(qi < n and "Next" or "Finish")
    QW:Show()
end
function RV.Next()
    local q = QA.questions[qi]
    if not q then return end
    local note = QW.note:GetText()
    if not pick and Clean(note) == "" and not Answers()[q.key] then
        QW.hint:SetText("|cffffaa00Pick an answer or write a note, or press Skip.|r"); return
    end
    if pick or Clean(note) ~= "" then RV.SaveAnswer(q.key, pick, note) end
    if qi < #QA.questions then qi = qi + 1; ShowQuestion() else ShowCopy(true) end
end
function RV.Skip() if qi < #QA.questions then qi = qi + 1; ShowQuestion() else ShowCopy(true) end end
function RV.Back() if qi > 1 then qi = qi - 1; ShowQuestion() end end
function ShowCopy(finished)
    BuildQuestions()
    Page(true)
    QW.title:SetText(finished and "Questions: done" or "Copy your answers")
    QW.copyLabel:SetText((finished and ("You reached the end (%d of %d answered). "):format(#QA.questions - RV.OpenCount(), #QA.questions) or "")
        .. "Click in the box, press Ctrl+A then Ctrl+C, and paste it into your chat with Claude. The answers are also kept in the saved file (XayaUIDevAssistDB.questions).")
    QW.copyBox:SetText(RV.AnswersText())
    QW:Show()
    QW.copyBox:SetFocus(); QW.copyBox:HighlightText()
end
function RV.ShowQuestions()
    if RW then RW:Hide() end
    -- start at the first unanswered question
    local a = Answers()
    qi = 1
    for i, q in ipairs(QA.questions) do if not a[q.key] then qi = i; break end end
    ShowQuestion()
end
RV.ShowCopy = function() ShowCopy() end
function RV.QuestionWindow() return QW end   -- (tests)
RV.State = function() return { qi = qi, pick = pick } end   -- (tests)

-------------------------------------------------------------------------------
-- When to open by itself: the first PLAYER_ENTERING_WORLD of the session, versions changed, not in combat
-------------------------------------------------------------------------------
local ev = CreateFrame("Frame")
local seen = false
local function TryAuto()
    if RV.Acknowledged() then return end
    if InCombat() then
        SV().review.deferred = { when = Now(), sig = RV.Signature() }
        ev:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    RV.Show("update")
end
RV.TryAuto = TryAuto
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_ENABLED" then
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        TryAuto()
        return
    end
    if seen then return end
    seen = true
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    if RV.Acknowledged() then return end
    -- a moment after the loading screen, so it does not open under it
    if C_Timer and C_Timer.After then C_Timer.After(2, TryAuto) else TryAuto() end
end)

-- /xui dev review, /xui dev questions (QAWalk.lua owns /xui dev and /xui dev qa; the core runs every handler of a command)
local core = rawget(_G, "XayaUI_NS")
if core and core.RegisterCommand then
    core.RegisterCommand("dev", function(arg)
        arg = tostring(arg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
        if arg == "review" then RV.Toggle()
        elseif arg == "questions" or arg == "question" then RV.ShowQuestions() end
    end)
end
