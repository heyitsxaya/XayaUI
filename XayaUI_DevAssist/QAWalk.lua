-------------------------------------------------------------------------------
-- QAWalk.lua (XayaUI_DevAssist 0.7.9): in-game QA walkthroughs, /xui dev qa (also /xuidev qa)
-- Xaya 2026-11-06 (standing rule): "For all things you need me to debug or QA in game — wherever possible, design and implement a test
-- script or walkthrough that fires in the game side so it removes all friction for a less technical friend. All they should have to do
-- is open up /xui dev qa and pick an item and have the addon walk them through steps with as limited console interaction as possible".
-- Her answers (same day): it lives in Dev Assist; "Check, then ask to confirm" (the addon shows what it can check itself, the person
-- still clicks Pass / Fail); results by "Screenshot, import/export result code, saved file support — all options should be allowed to
-- remove all points of friction".
--
-- A walkthrough: XayaUI_DevQA.Register(id, { title, area, qa = "B171", order, steps = { { text = "...", setup = fn (optional "Do it for
-- me"), check = fn returning ok, note (optional) }, ... } }). The window lists them (with their last result); one step at a time:
-- the step's text, "Do it for me" when the step has a setup, the addon's own check (shown, never decides), Pass / Fail / Skip, a note,
-- Back. The end screen: a summary, Screenshot (the game's own screenshot key action), Export code (a text code to paste into chat),
-- Import code (paste a code someone sent: their results show here), Run again. Every result is kept in XayaUIDevAssistDB.qa.
-- No names or realms are stored or exported. V14: nothing is built until the window opens. UNTESTED IN GAME.
-- Pre-fill (Dev Assist 0.7.9; Xaya 2026-11-06, REQUEST-LOG A14 CHATREV-6: "ensure qa has a handler that can automatically generate an
-- answer", and her answer on how: "Pre-fill, I confirm"): a walkthrough registered with prefill = true offers the addon's own verdict on
-- one button, "Accept: Pass" / "Accept: Fail", which records it with the check's note. Nothing is recorded without that click; Pass /
-- Fail / Skip still work. No Accept when the check could not run, or on a step marked noVerdict = true (a question for the person).
-- The list (Dev Assist 0.7.52; Xaya 2026-11-07, REQUEST-LOG PS-16..PS-18): a table, Codes | Title | Area | Status | New | Open, with a
-- search box, tag chips and sortable columns (QATable.lua, shared with the review popup); the window widens to 900 x 560 for it.
-- Trustworthy results (Dev Assist 0.7.53; docs/plans/PLATFORM-SPLIT-2026-11-07.md section 15, P0.5; issues #461, #465, #466, #481, #484):
--  - a step with a setup ("Do it for me") cannot be passed, accepted or marked done until its setup has run in this run: its check says
--    "Press Do it for me first" and Pass / Accept / Done stay disabled (Fail and Skip stay: a setup that cannot run is a failure);
--  - a check that returns nil (not true / false) did not test the thing: "Not tested yet", no Accept;
--  - a step marked done = true (clean-up, "put back", "anything look wrong?"): no Pass / Fail, one Done button; recorded as "D", which
--    counts as no verdict, so "no difference" is never recorded as a Fail;
--  - a run with no Pass and no Fail (every step skipped or done) shows Skipped, not Passed;
--  - the Done page: All walkthroughs, Review list and Next in this list (the next walkthrough in the list it was opened from, in the
--    order that list showed when it was opened); All walkthroughs has a Review list button;
--  - the title wraps inside the window and the page starts below its measured height; the windows' background is 0.95 opaque
--    (QA.WINDOW_ALPHA; provisional until Xaya answers C4).
-------------------------------------------------------------------------------
local QA = { walks = {}, list = {} }
XayaUI_DevQA = QA

local function DB()
    XayaUIDevAssistDB = XayaUIDevAssistDB or {}
    local d = XayaUIDevAssistDB
    d.qa = type(d.qa) == "table" and d.qa or {}
    d.qa.results = type(d.qa.results) == "table" and d.qa.results or {}
    return d.qa
end
QA.DB = DB

-- (0.7.30, the review popup, QAReview.lua) a walkthrough's fingerprint: its title and step texts. The review lists walkthroughs whose
-- fingerprint is new or differs from the build she last acknowledged; a saved result keeps the fingerprint it was run against.
function QA.Fingerprint(def)
    if type(def) ~= "table" or type(def.steps) ~= "table" then return "0" end
    local parts = { tostring(def.title or ""), tostring(#def.steps) }
    for _, st in ipairs(def.steps) do parts[#parts + 1] = tostring(type(st) == "table" and st.text or "") end
    local s, h = table.concat(parts, "\1"), 5381
    for i = 1, #s do h = (h * 33 + s:byte(i)) % 2147483647 end
    return tostring(h)
end

-- (0.7.53) what the addon saw at step i of a walkthrough's last saved run (the check's note), or nil: walkthroughs in parts across a
-- /reload read what part 1 recorded from the result it saved (no other saved key)
function QA.SeenNote(id, i)
    local r = DB().results[id]
    local st = r and type(r.steps) == "table" and r.steps[i]
    return st and type(st.d) == "string" and st.d or nil
end

-- (Dev Assist 0.7.72) `needs` on a walkthrough or on one step: the addon it tests. Since 2026-11-08 main has no XayaUI_Reskin or
-- XayaUI_Nameplates (tools/qa-only-paths.txt: they live on qa-installer-branch), and the same Dev Assist files serve both branches, so
-- a walkthrough or step whose addon is not installed is not listed. Only "missing" counts (core ns.ModuleState): an installed but
-- switched-off addon keeps its walkthroughs, whose steps may switch it on.
function QA.Missing(addon)
    local ns = rawget(_G, "XayaUI_NS")
    if type(addon) ~= "string" or type(ns) ~= "table" or type(ns.ModuleState) ~= "function" then return false end
    local ok, state = pcall(ns.ModuleState, addon)
    return ok and state == "missing" or false
end

function QA.Register(id, def)
    if type(id) ~= "string" or type(def) ~= "table" or type(def.steps) ~= "table" then return end
    if def.needs and QA.Missing(def.needs) then return end
    local kept = {}
    for _, st in ipairs(def.steps) do
        if not (type(st) == "table" and st.needs and QA.Missing(st.needs)) then kept[#kept + 1] = st end
    end
    if #kept == 0 then return end
    if #kept ~= #def.steps then def.steps = kept end
    if not QA.walks[id] then QA.list[#QA.list + 1] = id end
    def.id = id
    QA.walks[id] = def
    table.sort(QA.list, function(a, b)
        local A, B = QA.walks[a], QA.walks[b]
        local oa, ob = tonumber(A.order) or 100, tonumber(B.order) or 100
        if oa ~= ob then return oa < ob end
        return tostring(A.title) < tostring(B.title)
    end)
end

-- the result of one run: { id, when, steps = { { r = "P" | "F" | "S", note = "..." }, ... } }
local run = nil   -- the walkthrough being run: { id, i, steps = {} }
local function Clean(s, max) s = tostring(s or ""):gsub("|", ""):gsub("[%c]", " "); return s:sub(1, max or 200) end

-- result codes: "XUIQA1:" + base64 of plain lines. Only the fields below are read back from a code, each one length-capped.
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function enc64(s)
    local out = {}
    for i = 1, #s, 3 do
        local a, b, c = s:byte(i, i + 2)
        local n = a * 65536 + (b or 0) * 256 + (c or 0)
        local q = { math.floor(n / 262144) % 64, math.floor(n / 4096) % 64, math.floor(n / 64) % 64, n % 64 }
        out[#out + 1] = B64:sub(q[1] + 1, q[1] + 1) .. B64:sub(q[2] + 1, q[2] + 1)
            .. (b and B64:sub(q[3] + 1, q[3] + 1) or "=") .. (c and B64:sub(q[4] + 1, q[4] + 1) or "=")
    end
    return table.concat(out)
end
local function dec64(s)
    s = s:gsub("[^%w%+/=]", "")
    local map = {}
    for i = 1, 64 do map[B64:sub(i, i)] = i - 1 end
    local out = {}
    for i = 1, #s, 4 do
        local c1, c2, c3, c4 = s:sub(i, i), s:sub(i + 1, i + 1), s:sub(i + 2, i + 2), s:sub(i + 3, i + 3)
        local a, b = map[c1], map[c2]
        if not (a and b) then break end
        local cc, dd = map[c3], map[c4]
        local n = a * 262144 + b * 4096 + (cc or 0) * 64 + (dd or 0)
        out[#out + 1] = string.char(math.floor(n / 65536) % 256)
        if c3 ~= "=" and cc then out[#out + 1] = string.char(math.floor(n / 256) % 256) end
        if c4 ~= "=" and dd then out[#out + 1] = string.char(n % 256) end
    end
    return table.concat(out)
end
function QA.ExportCode(id)
    local r = DB().results[id]
    if not r then return nil end
    local lines = { "id=" .. Clean(id, 40), "when=" .. tostring(r.when or 0), "v=" .. Clean(r.v or "", 40) }
    for i, s in ipairs(r.steps or {}) do
        lines[#lines + 1] = ("%d=%s:%s"):format(i, Clean(s.r, 1), Clean(s.note, 160))
        if s.k then lines[#lines + 1] = ("k%d=%s"):format(i, Clean(s.k, 20)) end   -- (the checklist item: steps shift when the list changes)
        if s.a then lines[#lines + 1] = ("a%d=%s:%s"):format(i, Clean(s.a, 1), Clean(s.d, 200)) end   -- (what the addon saw: V22)
    end
    return "XUIQA1:" .. enc64(table.concat(lines, "\n"))
end
-- a pasted code -> a result table (or nil, reason); never runs anything from the code
function QA.ImportCode(code)
    code = tostring(code or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if #code > 8000 then return nil, "the code is too long" end
    local body = code:match("^XUIQA1:(.+)$")
    if not body then return nil, "this is not a XayaUI QA code (it starts with XUIQA1:)" end
    local text = dec64(body)
    local r = { steps = {} }
    for line in text:gmatch("[^\n]+") do
        local k, v = line:match("^([%w]+)=(.*)$")
        if k == "id" then r.id = Clean(v, 40)
        elseif k == "when" then r.when = tonumber(v)
        elseif k == "v" then r.v = Clean(v, 40)
        elseif tonumber(k) and tonumber(k) <= 60 then
            local res, note = v:match("^([PFSD]?):(.*)$")
            if res then r.steps[tonumber(k)] = { r = res, note = Clean(note, 160) } end
        elseif k:match("^k%d+$") and r.steps[tonumber(k:sub(2))] then
            r.steps[tonumber(k:sub(2))].k = Clean(v, 20)
        elseif k:match("^a%d+$") and r.steps[tonumber(k:sub(2))] then
            local a, d = v:match("^([YN%?]):(.*)$")
            if a then r.steps[tonumber(k:sub(2))].a, r.steps[tonumber(k:sub(2))].d = a, Clean(d, 200) end
        end
    end
    if not r.id then return nil, "the code has no walkthrough in it" end
    return r
end

-------------------------------------------------------------------------------
-- The window (made the first time it opens)
-------------------------------------------------------------------------------
local W
local ACC = { 0.55, 0.35, 0.95 }
-- the window's size: the list page is wider and taller, for the table (0.7.52); the step and end pages keep 660 x 440
local LIST_W, LIST_H, STEP_W, STEP_H = 900, 560, 660, 440
-- (0.7.53, #481) how solid the walkthrough windows are: text behind them must not read through. 0.95 is provisional (Xaya's answer C4
-- is pending). The theme's "Window opacity" (CueRulesDB.ui.skinAlpha, 0.62 by default) is the settings window's see-through look and
-- is not used here. A plain colour texture under everything, so it does not depend on the backdrop template.
QA.WINDOW_ALPHA = 0.95
function QA.SolidBackground(f)
    if not f.xuiSolid then f.xuiSolid = f:CreateTexture(nil, "BACKGROUND", nil, -8); f.xuiSolid:SetAllPoints(f) end
    f.xuiSolid:SetColorTexture(0.05, 0.05, 0.07, QA.WINDOW_ALPHA); f.xuiSolid:Show()
    if f.SetBackdrop then
        f:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        f:SetBackdropBorderColor(ACC[1], ACC[2], ACC[3], 1)
    end
end
-- (0.7.53, #481) a title that wraps inside the window; returns how far below the window's top the page can start
local TITLE_TOP, CLOSE_W = 12, 36
function QA.TitleBottom(fs)
    local h = fs and fs.GetStringHeight and fs:GetStringHeight() or 16
    if type(h) ~= "number" or h < 12 then h = 16 end
    return TITLE_TOP + math.ceil(h) + 8
end
local function Btn(parent, label, w, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w or 90, 22); b:SetText(label)
    local cns = rawget(_G, "XayaUI_NS")
    if cns and cns.FlatButton then cns.FlatButton(b) end   -- (#286: XayaUI's flat look)
    b:SetScript("OnClick", onClick)
    return b
end
-- (0.7.53) a run with no Pass and no Fail (every step skipped, or done without a verdict) is Skipped, never Passed
function QA.Counts(steps)
    local p, f, s, d = 0, 0, 0, 0
    for _, x in ipairs(steps or {}) do
        if x.r == "P" then p = p + 1 elseif x.r == "F" then f = f + 1 elseif x.r == "D" then d = d + 1 else s = s + 1 end
    end
    return p, f, s, d
end
local function Status(id)
    local r = DB().results[id]
    if not r then return "|cff999999not run|r" end
    local p, f = QA.Counts(r.steps)
    if f > 0 then return ("|cffff6060%d failed|r"):format(f) end
    if p > 0 then return ("|cff60ff60%d passed|r"):format(p) end
    return "|cffccccccSkipped|r"
end

QA.StatusText = Status   -- (0.7.30: the review popup shows the same verdict text)

local ShowList, ShowStep, ShowEnd
local function Build()
    if W then return end
    W = CreateFrame("Frame", "XayaUIDevQAWindow", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    W:SetSize(STEP_W, STEP_H); W:SetPoint("CENTER"); W:SetFrameStrata("DIALOG"); W:SetClampedToScreen(true)
    W:EnableMouse(true); W:SetMovable(true); W:RegisterForDrag("LeftButton")
    W:SetScript("OnDragStart", W.StartMoving); W:SetScript("OnDragStop", W.StopMovingOrSizing)
    QA.SolidBackground(W)
    W.title = W:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); W.title:SetPoint("TOPLEFT", 14, -TITLE_TOP)
    W.title:SetJustifyH("LEFT"); W.title:SetJustifyV("TOP"); W.title:SetWordWrap(true)
    local close = CreateFrame("Button", nil, W, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", 2, 2)
    -- list page (0.7.52): the walkthrough table with search, tag chips and sortable columns (QATable.lua), in a wider window. Open keeps
    -- the order the table shows at that moment, for Next in this list (0.7.53)
    W.tbl = QA.Table and QA.Table.Create(W, { left = 14, top = 40, bottom = 14, width = LIST_W - 28,
        onOpen = function(id) QA.Start(id, { order = W.tbl:Ids(), from = "list" }) end })
    W.rows = W.tbl and W.tbl.rows or {}
    W.listReview = Btn(W, "Review list", 110, function() QA.ToReview() end); W.listReview:SetPoint("TOPRIGHT", -CLOSE_W, -10)
    -- step page
    W.stepNo = W:CreateFontString(nil, "OVERLAY", "GameFontDisable"); W.stepNo:SetPoint("TOPLEFT", 14, -40)
    -- the step's text scrolls when it is long (some checklist items are over 1000 characters)
    W.textScroll = CreateFrame("ScrollFrame", nil, W)
    W.textScroll:SetPoint("TOPLEFT", 14, -62); W.textScroll:SetPoint("BOTTOMRIGHT", -14, 132)
    W.textChild = CreateFrame("Frame", nil, W.textScroll); W.textChild:SetSize(620, 10); W.textScroll:SetScrollChild(W.textChild)
    W.textScroll:EnableMouseWheel(true)
    W.textScroll:SetScript("OnMouseWheel", function(self, d)
        local maxS = math.max(0, (W.textChild:GetHeight() or 0) - (self:GetHeight() or 0))
        self:SetVerticalScroll(math.max(0, math.min(maxS, (self:GetVerticalScroll() or 0) - d * 40)))
    end)
    W.text = W.textChild:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); W.text:SetPoint("TOPLEFT", 0, 0); W.text:SetWidth(615)
    W.text:SetJustifyH("LEFT"); W.text:SetJustifyV("TOP"); if W.text.SetSpacing then W.text:SetSpacing(3) end
    W.check = W:CreateFontString(nil, "OVERLAY", "GameFontNormal"); W.check:SetPoint("BOTTOMLEFT", 14, 112); W.check:SetWidth(630); W.check:SetJustifyH("LEFT")
    W.doIt = Btn(W, "Do it for me", 120, function() QA.DoSetup() end); W.doIt:SetPoint("BOTTOMLEFT", 14, 82)
    W.recheck = Btn(W, "Check again", 110, function() QA.RunCheck() end); W.recheck:SetPoint("LEFT", W.doIt, "RIGHT", 8, 0)
    W.accept = Btn(W, "Accept", 150, function() QA.Accept() end); W.accept:SetPoint("BOTTOMRIGHT", -14, 82)
    W.noteLabel = W:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); W.noteLabel:SetPoint("BOTTOMLEFT", 14, 62); W.noteLabel:SetText("Note (optional): what did you see?")
    W.note = CreateFrame("EditBox", nil, W, "InputBoxTemplate"); W.note:SetSize(620, 20); W.note:SetPoint("BOTTOMLEFT", 20, 38); W.note:SetAutoFocus(false)
    do local cns = rawget(_G, "XayaUI_NS"); if cns and cns.KeyFocusGuard then cns.KeyFocusGuard(W.note) end end   -- (row 56) lets go of the keyboard: Enter / Esc / a click outside / hiding (core KeyCatch.lua)
    W.pass = Btn(W, "Pass", 90, function() QA.Answer("P") end); W.pass:SetPoint("BOTTOMRIGHT", -14, 10)
    W.fail = Btn(W, "Fail", 90, function() QA.Answer("F") end); W.fail:SetPoint("RIGHT", W.pass, "LEFT", -8, 0)
    W.skip = Btn(W, "Skip", 90, function() QA.Answer("S") end); W.skip:SetPoint("RIGHT", W.fail, "LEFT", -8, 0)
    -- (0.7.53, #484) a clean-up / "anything look wrong?" step: one Done button where Pass and Fail were (no verdict)
    W.doneBtn = Btn(W, "Done", 188, function() QA.Answer("D") end); W.doneBtn:SetPoint("BOTTOMRIGHT", -14, 10)
    W.back = Btn(W, "Back", 90, function() QA.Back() end); W.back:SetPoint("BOTTOMLEFT", 14, 10)
    W.toList = Btn(W, "All walkthroughs", 130, function() ShowList() end); W.toList:SetPoint("LEFT", W.back, "RIGHT", 8, 0)
    -- end page
    W.summary = W:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); W.summary:SetPoint("TOPLEFT", 14, -40); W.summary:SetWidth(630)
    W.summary:SetJustifyH("LEFT"); W.summary:SetJustifyV("TOP")
    W.shot = Btn(W, "Screenshot", 110, function() QA.Screenshot() end)
    W.export = Btn(W, "Export code", 110, function() QA.ShowCode() end)
    W.import = Btn(W, "Import a code", 120, function() QA.StartImport() end)
    W.again = Btn(W, "Run again", 100, function() if run then QA.Start(run.id, { order = run.order, from = run.from }) end end)
    W.shot:SetPoint("BOTTOMLEFT", 14, 40); W.export:SetPoint("LEFT", W.shot, "RIGHT", 8, 0); W.import:SetPoint("LEFT", W.export, "RIGHT", 8, 0)
    W.again:SetPoint("LEFT", W.import, "RIGHT", 8, 0)
    W.code = CreateFrame("EditBox", nil, W, "InputBoxTemplate"); W.code:SetSize(620, 20); W.code:SetPoint("BOTTOMLEFT", 20, 72); W.code:SetAutoFocus(false)
    do local cns = rawget(_G, "XayaUI_NS"); if cns and cns.KeyFocusGuard then cns.KeyFocusGuard(W.code) end end   -- (row 56) lets go of the keyboard: Enter / Esc / a click outside / hiding (core KeyCatch.lua)
    W.codeLabel = W:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); W.codeLabel:SetPoint("BOTTOMLEFT", 14, 96)
    W.importGo = Btn(W, "Show these results", 140, function() QA.FinishImport() end); W.importGo:SetPoint("BOTTOMRIGHT", -14, 40)
    -- (0.7.53, #465) where to go from the end page
    W.endList = Btn(W, "All walkthroughs", 130, function() ShowList() end); W.endList:SetPoint("BOTTOMLEFT", 14, 10)
    W.endReview = Btn(W, "Review list", 110, function() QA.ToReview() end); W.endReview:SetPoint("LEFT", W.endList, "RIGHT", 8, 0)
    W.nextBtn = Btn(W, "Next in this list", 150, function() QA.Next() end); W.nextBtn:SetPoint("BOTTOMRIGHT", -14, 10)
    W:Hide()
end
local STEP_WIDGETS = { "stepNo", "textScroll", "check", "doIt", "recheck", "accept", "noteLabel", "note", "pass", "fail", "skip", "doneBtn", "back", "toList" }
local END_WIDGETS = { "summary", "shot", "export", "import", "again", "code", "codeLabel", "importGo", "endList", "endReview", "nextBtn" }
local function ShowOnly(list)
    local want = {}
    for _, k in ipairs(list or {}) do want[k] = true end
    for _, k in ipairs(STEP_WIDGETS) do W[k]:SetShown(want[k] and true or false) end
    for _, k in ipairs(END_WIDGETS) do W[k]:SetShown(want[k] and true or false) end
    W.listReview:SetShown(want.listReview and true or false)
    if W.tbl then W.tbl:SetShown(false) end
    W:SetSize(STEP_W, STEP_H)
end
-- the title, wrapped inside the window (the close button keeps its corner; on the list page the Review list button too)
local function SetTitle(text, room)
    W.title:SetWidth(W:GetWidth() - 14 - CLOSE_W - (room or 0))
    W.title:SetText(text)
    return QA.TitleBottom(W.title)
end
QA.SetTitle = function(text, room) return SetTitle(text, room) end   -- (tests)

function ShowList()
    Build()
    -- leaving for the list ends "back to the review when the runner closes" (QAReview.lua): the list is where she went
    if QA.Review and QA.Review.ForgetReturn then QA.Review.ForgetReturn() end
    ShowOnly({ "listReview" })
    W:SetSize(LIST_W, LIST_H)
    local top = SetTitle("XayaUI QA walkthroughs", 120)
    if W.tbl then
        local states, list = QA.Table.States(), {}
        for _, id in ipairs(QA.list) do list[#list + 1] = { id = id, state = states[id] } end
        W.tbl:SetShown(true)
        W.tbl:SetTop(math.max(40, top))
        W.tbl:SetEntries(list)   -- (search, tags and sort stay as she left them this session: the table keeps them in memory only)
    end
    W.list = true
    W:Show()
end
function QA.ToReview()
    if not (QA.Review and QA.Review.Show) then return end
    if QA.Review.ForgetReturn then QA.Review.ForgetReturn() end
    if W then W:Hide() end
    QA.Review.Show("from the walkthroughs")
end

-- QA.Start(id, { order = { ids as the list showed them }, from = "list" | "review" }) (both optional)
function QA.Start(id, opts)
    local def = QA.walks[id]
    if not def then return end
    Build()
    opts = type(opts) == "table" and opts or {}
    run = { id = id, i = 1, steps = {}, setupDone = {}, order = type(opts.order) == "table" and opts.order or nil, from = opts.from }
    ShowStep()
end
-- (0.7.53) the walkthrough after this one in the list it was opened from (the order that list showed then), or nil
function QA.NextId()
    local order = run and run.order
    if not order then return nil end
    for i, id in ipairs(order) do if id == run.id then
        for j = i + 1, #order do if QA.walks[order[j]] then return order[j] end end
        return nil
    end end
    return nil
end
function QA.Next()
    local nid = QA.NextId()
    if not nid then return end
    QA.lastNext = { from = run.id, to = nid }   -- (memory only: the runner walkthrough J33 reads it)
    QA.Start(nid, { order = run.order, from = run.from })
end
local function CurStep()
    local def = run and QA.walks[run.id]
    return def and def.steps[run.i], def
end
-- (0.7.53, #461) a step whose setup has not run in this run: its check means nothing yet
local function Gated(st) return st and st.setup ~= nil and not (run.setupDone and run.setupDone[run.i]) end
QA.Gated = function() return Gated((CurStep())) and true or false end   -- (tests)
local function UpdateButtons()
    local st = CurStep()
    if not st then return end
    local gated, done = Gated(st), st.done == true
    W.pass:SetShown(not done); W.fail:SetShown(not done); W.doneBtn:SetShown(done)
    W.pass:SetEnabled(not gated); W.doneBtn:SetEnabled(not gated)
    W.doneBtn:SetText(gated and "Done (Do it for me first)" or "Done")
    if gated then W.accept:Hide(); run.suggest = nil end
end
function QA.RunCheck()
    local st, def = CurStep()
    if not st then return end
    if Gated(st) then
        run.suggest = nil; W.accept:Hide()
        if run.seen then run.seen[run.i] = nil end
        W.check:SetText("|cffffaa00Press Do it for me first: this step's check only means something after it has run.|r")
        UpdateButtons()
        return
    end
    if not st.check then W.check:SetText(""); return end
    local ok, good, note = pcall(st.check)
    -- V22 (Xaya 2026-11-07: "... in game qa test walk through with pre-fill confirmation options or data capturing"): what the addon
    -- saw is kept with the answer (its verdict and its note), so a result carries the data, not only Pass / Fail
    run.seen = run.seen or {}
    run.seen[run.i] = { a = (not ok or good == nil) and "?" or (good and "Y" or "N"), d = Clean(ok and note or good, 200) }
    run.suggest = nil
    W.accept:Hide()
    if not ok then W.check:SetText("|cffffaa00The addon could not check this one itself (" .. Clean(good, 120) .. "). Look and decide.|r")
    elseif good == nil then
        -- (0.7.53) the check ran but the thing under test was not exercised: no verdict to offer
        W.check:SetText("|cffffaa00Not tested yet:|r " .. Clean(note or "", 300) .. "  |cff999999(no verdict from the addon)|r")
    elseif def.prefill and not st.noVerdict and not st.done then
        -- pre-fill: the verdict waits on the Accept button; the person's click records it
        run.suggest = { r = good and "P" or "F", note = Clean("addon: " .. tostring(note or ""), 160) }
        W.check:SetText((good and "|cff60ff60The addon says Pass:|r " or "|cffff6060The addon says Fail:|r ") .. Clean(note or "", 300)
            .. "  |cff999999(Accept records it; or press Pass / Fail yourself)|r")
        W.accept:SetText(good and "Accept: Pass" or "Accept: Fail")
        W.accept:Show()
    elseif good then W.check:SetText("|cff60ff60Looks right to the addon:|r " .. Clean(note or "", 300) .. "  |cff999999(you still decide)|r")
    else W.check:SetText("|cffff6060Looks wrong to the addon:|r " .. Clean(note or "", 300) .. "  |cff999999(you still decide)|r") end
    UpdateButtons()
end
-- the Accept button: records the addon's verdict (pre-fill walkthroughs only); the person's own note, if typed, is kept
function QA.Accept()
    local sg = run and run.suggest
    if not sg then return end
    if Gated((CurStep())) then return end
    local typed = Clean(W.note:GetText(), 160)
    if typed == "" then W.note:SetText(sg.note) end
    QA.Answer(sg.r)
end
function QA.DoSetup()
    local st = CurStep()
    if not (st and st.setup) then return end
    local ok, err = pcall(st.setup)
    if not ok then W.check:SetText("|cffffaa00Could not do it automatically: " .. Clean(err, 160) .. "|r") return end
    run.setupDone[run.i] = true
    UpdateButtons()
    local i = run.i
    if C_Timer then C_Timer.After(0.3, function() if W and W:IsShown() and run and run.i == i then QA.RunCheck() end end)
    else QA.RunCheck() end
end
function ShowStep()
    local def = QA.walks[run.id]
    local st = def.steps[run.i]
    ShowOnly(STEP_WIDGETS)
    local top = SetTitle(tostring(def.title))
    W.stepNo:ClearAllPoints(); W.stepNo:SetPoint("TOPLEFT", 14, -top)
    W.textScroll:ClearAllPoints(); W.textScroll:SetPoint("TOPLEFT", 14, -(top + 22)); W.textScroll:SetPoint("BOTTOMRIGHT", -14, 132)
    W.stepNo:SetText(("Step %d of %d%s"):format(run.i, #def.steps, def.qa and ("  (" .. def.qa .. ")") or ""))
    W.text:SetText(tostring(st.text or ""))
    W.textChild:SetHeight(math.max(10, (W.text.GetStringHeight and W.text:GetStringHeight() or 0) + 4)); W.textScroll:SetVerticalScroll(0)
    W.doIt:SetShown(st.setup ~= nil)
    W.recheck:SetShown(st.check ~= nil)
    W.accept:Hide(); run.suggest = nil
    W.back:SetEnabled(run.i > 1)
    W.note:SetText(run.steps[run.i] and run.steps[run.i].note or "")
    W.check:SetText(st.check and "|cff999999The addon checks this step when you press Check again (or after Do it for me).|r" or "")
    UpdateButtons()
    if st.check or Gated(st) then QA.RunCheck() end
    W:Show()
end
function QA.Answer(r)
    if not run then return end
    local st, def = CurStep()
    if not st then return end
    -- (0.7.53) Pass and Done wait for the step's setup; a clean-up step takes Done (or Skip), never Pass / Fail
    if (r == "P" or r == "D") and Gated(st) then return end
    if st.done and (r == "P" or r == "F") then return end
    if r == "D" and not st.done then return end
    local key = st.key
    local seen = run.seen and run.seen[run.i]
    run.steps[run.i] = { r = r, note = Clean(W.note:GetText(), 160), k = key and Clean(key, 20) or nil,
        a = seen and seen.a or nil, d = seen and seen.d or nil }   -- (a / d: the addon's own check at that step: verdict, data)
    if run.i < #def.steps then run.i = run.i + 1; ShowStep()
    else
        DB().results[run.id] = { when = time and time() or 0, v = def.version, steps = run.steps, fp = QA.Fingerprint(def) }
        ShowEnd(DB().results[run.id], def)
    end
end
function QA.Back() if run and run.i > 1 then run.i = run.i - 1; ShowStep() end end

function ShowEnd(res, def, imported)
    ShowOnly({ "summary", "shot", "export", "import", "again", "endList", "endReview", "nextBtn" })
    local top = SetTitle((imported and "Imported results: " or "Done: ") .. tostring(def and def.title or res.id))
    W.summary:ClearAllPoints(); W.summary:SetPoint("TOPLEFT", 14, -top)
    local lines = {}
    for i, st in ipairs(res.steps or {}) do
        local mark = st.r == "P" and "|cff60ff60Pass|r" or st.r == "F" and "|cffff6060Fail|r" or st.r == "D" and "|cff99ccffDone|r" or "|cff999999Skip|r"
        lines[#lines + 1] = ("%d. %s%s%s"):format(i, mark, (st.note and st.note ~= "") and ("  " .. st.note) or "",
            (st.d and st.d ~= "") and ("  |cff999999(the addon saw: " .. st.d .. ")|r") or "")
    end
    local p, f, s, d = QA.Counts(res.steps)
    local head = (p == 0 and f == 0) and "|cffccccccSkipped:|r no step was passed or failed. " or ""
    W.summary:SetText(("%s%d passed, %d failed, %d skipped%s.\n\n%s\n\nTo send these: press Export code and copy the code (Ctrl+C), or take a Screenshot. They are also kept in the saved file (XayaUIDevAssistDB.qa)."):format(
        head, p, f, s, d > 0 and (", %d done"):format(d) or "", table.concat(lines, "\n")))
    W.again:SetShown(not imported)
    W.endReview:SetShown(QA.Review ~= nil and QA.Review.Show ~= nil)
    local nid = (not imported) and QA.NextId() or nil
    W.nextBtn:SetShown(not imported)
    W.nextBtn:SetEnabled(nid ~= nil)
    W.nextBtn:SetText(nid and "Next in this list" or "Last in this list")
end
function QA.Screenshot()
    -- the game's own screenshot (the Print Screen action); the window stays visible so the results are in the picture
    if Screenshot then pcall(Screenshot) end
end
function QA.ShowCode()
    if not run then return end
    local code = QA.ExportCode(run.id)
    W.codeLabel:SetText("Your code (press Ctrl+C to copy, then paste it into chat):"); W.codeLabel:Show()
    W.code:SetText(code or ""); W.code:Show(); W.code:SetFocus(); W.code:HighlightText()
end
function QA.StartImport()
    W.codeLabel:SetText("Paste a code (Ctrl+V), then press Show these results:"); W.codeLabel:Show()
    W.code:SetText(""); W.code:Show(); W.code:SetFocus(); W.importGo:Show()
end
function QA.FinishImport()
    local res, why = QA.ImportCode(W.code:GetText())
    if not res then W.codeLabel:SetText("|cffff6060" .. tostring(why) .. "|r"); return end
    W.importGo:Hide(); W.code:Hide(); W.codeLabel:Hide()
    ShowEnd(res, QA.walks[res.id], true)
end

function QA.Toggle()
    if W and W:IsShown() then W:Hide() else ShowList() end
end
function QA.Window() return W end   -- (tests)
QA.State = function() return run end   -- (tests)

-- /xui dev qa (XayaUI's own command line; core lists Dev Assist as the addon that owns "dev")
local core = rawget(_G, "XayaUI_NS")
if core and core.RegisterCommand then
    core.RegisterCommand("dev", function(arg)
        arg = tostring(arg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
        if arg == "" or arg == "qa" then QA.Toggle() end
    end)
    -- (Xaya 2026-11-06, via the feature update summary session, FUS-9: "also create another shortcut /xui qa test and /xui qatest
    -- aliases for common sense readability")
    core.RegisterCommand("qa", function(arg)
        arg = tostring(arg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
        if arg == "test" or arg == "" then QA.Toggle() end
    end)
    core.RegisterCommand("qatest", function() QA.Toggle() end)
end
