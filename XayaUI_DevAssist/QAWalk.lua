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

function QA.Register(id, def)
    if type(id) ~= "string" or type(def) ~= "table" or type(def.steps) ~= "table" then return end
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
            local res, note = v:match("^([PFS]?):(.*)$")
            if res then r.steps[tonumber(k)] = { r = res, note = Clean(note, 160) } end
        elseif k:match("^k%d+$") and r.steps[tonumber(k:sub(2))] then
            r.steps[tonumber(k:sub(2))].k = Clean(v, 20)
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
local function Btn(parent, label, w, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w or 90, 22); b:SetText(label)
    local cns = rawget(_G, "XayaUI_NS")
    if cns and cns.FlatButton then cns.FlatButton(b) end   -- (#286: XayaUI's flat look)
    b:SetScript("OnClick", onClick)
    return b
end
local function Status(id)
    local r = DB().results[id]
    if not r then return "|cff999999not run|r" end
    local p, f = 0, 0
    for _, s in ipairs(r.steps or {}) do if s.r == "P" then p = p + 1 elseif s.r == "F" then f = f + 1 end end
    return f > 0 and ("|cffff6060%d failed|r"):format(f) or ("|cff60ff60%d passed|r"):format(p)
end

QA.StatusText = Status   -- (0.7.30: the review popup shows the same verdict text)

local ShowList, ShowStep, ShowEnd
local function Build()
    if W then return end
    W = CreateFrame("Frame", "XayaUIDevQAWindow", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    W:SetSize(660, 440); W:SetPoint("CENTER"); W:SetFrameStrata("DIALOG"); W:SetClampedToScreen(true)
    W:EnableMouse(true); W:SetMovable(true); W:RegisterForDrag("LeftButton")
    W:SetScript("OnDragStart", W.StartMoving); W:SetScript("OnDragStop", W.StopMovingOrSizing)
    if W.SetBackdrop then
        W:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        W:SetBackdropColor(0.05, 0.05, 0.07, 0.96); W:SetBackdropBorderColor(ACC[1], ACC[2], ACC[3], 1)
    end
    W.title = W:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); W.title:SetPoint("TOPLEFT", 14, -12)
    local close = CreateFrame("Button", nil, W, "UIPanelCloseButton"); close:SetPoint("TOPRIGHT", 2, 2)
    -- list page: a scrolling list (the walkthroughs do not fit the window)
    W.rows = {}
    W.listScroll = CreateFrame("ScrollFrame", nil, W)
    W.listScroll:SetPoint("TOPLEFT", 14, -40); W.listScroll:SetPoint("BOTTOMRIGHT", -14, 14)
    W.listChild = CreateFrame("Frame", nil, W.listScroll); W.listChild:SetSize(630, 10); W.listScroll:SetScrollChild(W.listChild)
    W.listScroll:EnableMouseWheel(true)
    W.listScroll:SetScript("OnMouseWheel", function(self, d)
        local maxS = math.max(0, (W.listChild:GetHeight() or 0) - (self:GetHeight() or 0))
        self:SetVerticalScroll(math.max(0, math.min(maxS, (self:GetVerticalScroll() or 0) - d * 48)))
    end)
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
    W.pass = Btn(W, "Pass", 90, function() QA.Answer("P") end); W.pass:SetPoint("BOTTOMRIGHT", -14, 10)
    W.fail = Btn(W, "Fail", 90, function() QA.Answer("F") end); W.fail:SetPoint("RIGHT", W.pass, "LEFT", -8, 0)
    W.skip = Btn(W, "Skip", 90, function() QA.Answer("S") end); W.skip:SetPoint("RIGHT", W.fail, "LEFT", -8, 0)
    W.back = Btn(W, "Back", 90, function() QA.Back() end); W.back:SetPoint("BOTTOMLEFT", 14, 10)
    W.toList = Btn(W, "All walkthroughs", 130, function() ShowList() end); W.toList:SetPoint("LEFT", W.back, "RIGHT", 8, 0)
    -- end page
    W.summary = W:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); W.summary:SetPoint("TOPLEFT", 14, -40); W.summary:SetWidth(630)
    W.summary:SetJustifyH("LEFT"); W.summary:SetJustifyV("TOP")
    W.shot = Btn(W, "Screenshot", 110, function() QA.Screenshot() end)
    W.export = Btn(W, "Export code", 110, function() QA.ShowCode() end)
    W.import = Btn(W, "Import a code", 120, function() QA.StartImport() end)
    W.again = Btn(W, "Run again", 100, function() if run then QA.Start(run.id) end end)
    W.shot:SetPoint("BOTTOMLEFT", 14, 40); W.export:SetPoint("LEFT", W.shot, "RIGHT", 8, 0); W.import:SetPoint("LEFT", W.export, "RIGHT", 8, 0)
    W.again:SetPoint("LEFT", W.import, "RIGHT", 8, 0)
    W.code = CreateFrame("EditBox", nil, W, "InputBoxTemplate"); W.code:SetSize(620, 20); W.code:SetPoint("BOTTOMLEFT", 20, 72); W.code:SetAutoFocus(false)
    W.codeLabel = W:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); W.codeLabel:SetPoint("BOTTOMLEFT", 14, 96)
    W.importGo = Btn(W, "Show these results", 140, function() QA.FinishImport() end); W.importGo:SetPoint("BOTTOMRIGHT", -14, 40)
    W:Hide()
end
local STEP_WIDGETS = { "stepNo", "textScroll", "check", "doIt", "recheck", "accept", "noteLabel", "note", "pass", "fail", "skip", "back", "toList" }
local END_WIDGETS = { "summary", "shot", "export", "import", "again", "code", "codeLabel", "importGo" }
local function ShowOnly(list)
    local want = {}
    for _, k in ipairs(list or {}) do want[k] = true end
    for _, k in ipairs(STEP_WIDGETS) do W[k]:SetShown(want[k] and true or false) end
    for _, k in ipairs(END_WIDGETS) do W[k]:SetShown(want[k] and true or false) end
    for _, r in ipairs(W.rows) do r:Hide() end
    if W.listScroll then W.listScroll:Hide() end
end

function ShowList()
    Build()
    ShowOnly({})
    W.title:SetText("XayaUI QA walkthroughs")
    for i, id in ipairs(QA.list) do
        local def = QA.walks[id]
        local r = W.rows[i]
        if not r then
            r = CreateFrame("Button", nil, W.listChild)
            r:SetSize(630, 22)
            r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight"); r.text:SetPoint("LEFT", 6, 0); r.text:SetJustifyH("LEFT")
            r.status = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); r.status:SetPoint("RIGHT", -6, 0)
            local hl = r:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(r); hl:SetColorTexture(1, 1, 1, 0.08)
            W.rows[i] = r
        end
        r:ClearAllPoints(); r:SetPoint("TOPLEFT", W.listChild, "TOPLEFT", 0, -(i - 1) * 24)
        r.text:SetText(("%s%s  |cff999999(%d steps)|r"):format(def.qa and ("[" .. def.qa .. "] ") or "", tostring(def.title), #def.steps))
        r.status:SetText(Status(id))
        r:SetScript("OnClick", function() QA.Start(id) end)
        r:Show()
    end
    W.listChild:SetHeight(math.max(10, #QA.list * 24))
    W.listScroll:Show(); W.listScroll:SetVerticalScroll(0)
    W.list = true
    W:Show()
end

function QA.Start(id)
    local def = QA.walks[id]
    if not def then return end
    Build()
    run = { id = id, i = 1, steps = {} }
    ShowStep()
end
function QA.RunCheck()
    local def = run and QA.walks[run.id]
    local st = def and def.steps[run.i]
    if not (st and st.check) then W.check:SetText(""); return end
    local ok, good, note = pcall(st.check)
    run.suggest = nil
    W.accept:Hide()
    if not ok then W.check:SetText("|cffffaa00The addon could not check this one itself (" .. Clean(good, 120) .. "). Look and decide.|r")
    elseif def.prefill and not st.noVerdict then
        -- pre-fill: the verdict waits on the Accept button; the person's click records it
        run.suggest = { r = good and "P" or "F", note = Clean("addon: " .. tostring(note or ""), 160) }
        W.check:SetText((good and "|cff60ff60The addon says Pass:|r " or "|cffff6060The addon says Fail:|r ") .. Clean(note or "", 300)
            .. "  |cff999999(Accept records it; or press Pass / Fail yourself)|r")
        W.accept:SetText(good and "Accept: Pass" or "Accept: Fail")
        W.accept:Show()
    elseif good then W.check:SetText("|cff60ff60Looks right to the addon:|r " .. Clean(note or "", 300) .. "  |cff999999(you still decide)|r")
    else W.check:SetText("|cffff6060Looks wrong to the addon:|r " .. Clean(note or "", 300) .. "  |cff999999(you still decide)|r") end
end
-- the Accept button: records the addon's verdict (pre-fill walkthroughs only); the person's own note, if typed, is kept
function QA.Accept()
    local sg = run and run.suggest
    if not sg then return end
    local typed = Clean(W.note:GetText(), 160)
    if typed == "" then W.note:SetText(sg.note) end
    QA.Answer(sg.r)
end
function QA.DoSetup()
    local def = run and QA.walks[run.id]
    local st = def and def.steps[run.i]
    if not (st and st.setup) then return end
    local ok, err = pcall(st.setup)
    if not ok then W.check:SetText("|cffffaa00Could not do it automatically: " .. Clean(err, 160) .. "|r") return end
    if C_Timer then C_Timer.After(0.3, function() if W and W:IsShown() then QA.RunCheck() end end) end
end
function ShowStep()
    local def = QA.walks[run.id]
    local st = def.steps[run.i]
    ShowOnly(STEP_WIDGETS)
    W.title:SetText(tostring(def.title))
    W.stepNo:SetText(("Step %d of %d%s"):format(run.i, #def.steps, def.qa and ("  (" .. def.qa .. ")") or ""))
    W.text:SetText(tostring(st.text or ""))
    W.textChild:SetHeight(math.max(10, (W.text.GetStringHeight and W.text:GetStringHeight() or 0) + 4)); W.textScroll:SetVerticalScroll(0)
    W.doIt:SetShown(st.setup ~= nil)
    W.recheck:SetShown(st.check ~= nil)
    W.accept:Hide(); run.suggest = nil
    W.back:SetEnabled(run.i > 1)
    W.note:SetText(run.steps[run.i] and run.steps[run.i].note or "")
    W.check:SetText(st.check and "|cff999999The addon checks this step when you press Check again (or after Do it for me).|r" or "")
    if st.check then QA.RunCheck() end
    W:Show()
end
function QA.Answer(r)
    if not run then return end
    local def = QA.walks[run.id]
    local key = def.steps[run.i] and def.steps[run.i].key
    run.steps[run.i] = { r = r, note = Clean(W.note:GetText(), 160), k = key and Clean(key, 20) or nil }
    if run.i < #def.steps then run.i = run.i + 1; ShowStep()
    else
        DB().results[run.id] = { when = time and time() or 0, v = def.version, steps = run.steps, fp = QA.Fingerprint(def) }
        ShowEnd(DB().results[run.id], def)
    end
end
function QA.Back() if run and run.i > 1 then run.i = run.i - 1; ShowStep() end end

function ShowEnd(res, def, imported)
    ShowOnly({ "summary", "shot", "export", "import", "again" })
    W.title:SetText((imported and "Imported results: " or "Done: ") .. tostring(def and def.title or res.id))
    local lines = {}
    local p, f, s = 0, 0, 0
    for i, st in ipairs(res.steps or {}) do
        local mark = st.r == "P" and "|cff60ff60Pass|r" or st.r == "F" and "|cffff6060Fail|r" or "|cff999999Skip|r"
        if st.r == "P" then p = p + 1 elseif st.r == "F" then f = f + 1 else s = s + 1 end
        lines[#lines + 1] = ("%d. %s%s"):format(i, mark, (st.note and st.note ~= "") and ("  " .. st.note) or "")
    end
    W.summary:SetText(("%d passed, %d failed, %d skipped.\n\n%s\n\nTo send these: press Export code and copy the code (Ctrl+C), or take a Screenshot. They are also kept in the saved file (XayaUIDevAssistDB.qa)."):format(
        p, f, s, table.concat(lines, "\n")))
    W.again:SetShown(not imported)
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
