-------------------------------------------------------------------------------
-- QAWalks-debug-w1.lua (XayaUI_DevAssist 0.7.62): in-game QA walkthrough for debug batch W1 (Rules_Options 0.6.79, Options 0.6.94;
-- QA steps B280 to B283):
--   #476 "missing devourer": the Specialization list is built from the game's own spec count per class, gaps skipped (B280);
--   #482 the Cooldown Manager warning repeated word for word: identical lines are shown once (B281);
--   #484 "import button has wrong alignment": the type picker's Import row lines up with the rows above it (B282);
--   #487 "????????????????????????": the type picker stays with the Rules sub-tab it was opened in and is gone on Drafts (B283).
-- Standing rule V22 (Xaya 2026-11-07): every step the addon can judge offers its verdict (prefill = true; recorded only on her click);
-- what it reads is written into the step's note. Reaches the settings window only through core (ns.LoadOptions), ns.OptionsApi
-- (RuleEditorParts.SpecChoices; RuleEditor.CdmWarnArg / CurrentSub / PickerShown / NewRule, published by XayaUI Rules Options 0.6.79),
-- XayaUI Rules' ns.CdmNeeds and AceConfigDialog. Nothing is saved. UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end

local function NS() return rawget(_G, "XayaUI_NS") end
local function RE() local ns = NS(); return ns and ns.OptionsApi and ns.OptionsApi.RuleEditor or {} end
local function ACD() return LibStub and LibStub("AceConfigDialog-3.0", true) end
local function Root() local a = ACD(); return a and a.OpenFrames and a.OpenFrames["CueRules"] end
local function Loaded() local ns = NS(); return ns and ns.LoadOptions and ns.LoadOptions() and true or false end
local function Open(...)
    if not Loaded() then return end
    local a = ACD(); if not a then return end
    if not (Root() and Root().frame and Root().frame:IsShown()) then a:Open("CueRules") end
    a:SelectGroup("CueRules", ...)
end
local function Num(o, m) if not (o and o[m]) then return nil end local ok, v = pcall(o[m], o); if ok and type(v) == "number" then return v end end
local function Each(fn)
    local function walk(w, d) if not w or d > 40 then return end; fn(w); for _, c in ipairs(w.children or {}) do walk(c, d + 1) end end
    walk(Root(), 0)
end
-- the picker's rows that are on screen now, by title
local TITLES = { "Icon", "Texture", "Progress Bar", "Progress Texture", "Text", "Sound Cue", "Static Group", "Custom", "Dynamic Group", "Import" }
local function PickerRows()
    local out, n = {}, 0
    Each(function(w)
        local o = w.GetUserData and w:GetUserData("option")
        local nm = o and type(o.name) == "string" and o.name or ""
        if w.frame and w.frame:IsVisible() then
            for _, t in ipairs(TITLES) do if nm:find("|cffffd100" .. t .. "|r", 1, true) == 1 then out[t] = w; n = n + 1 end end
        end
    end)
    return out, n
end

-- B280 (#476)
local function CheckSpecs()
    local ns = NS()
    if not Loaded() then return nil, "the settings window's addon did not load" end
    local P = ns.OptionsApi and ns.OptionsApi.RuleEditorParts
    if not (P and P.SpecChoices) then return nil, "the rule editor (XayaUI Rules Options) is not loaded: is XayaUI Rules on?" end
    local dh, has = {}, false
    for _, c in ipairs(P.SpecChoices()) do
        if c.class == "DEMONHUNTER" then dh[#dh + 1] = c.id; if c.id == "1480" then has = true end end
    end
    -- what the game itself answers (kept for the report: why index 3 came back empty before is not known)
    local raw = {}
    local cnt = C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializationsForClassID
    local okN, n = false, nil
    if cnt then okN, n = pcall(cnt, 12) end
    for i = 1, math.max(5, (okN and tonumber(n)) or 0) do
        local ok, id, name = pcall(GetSpecializationInfoForClassID, 12, i)
        raw[#raw + 1] = i .. "=" .. ((ok and id) and (tostring(id) .. " " .. tostring(name)) or "nothing")
    end
    return has, ("Demon Hunter specs listed: %s; Devourer (1480): %s. The game: GetNumSpecializationsForClassID(12) = %s; GetSpecializationInfoForClassID(12, i): %s"):format(
        table.concat(dh, ", "), has and "listed" or "MISSING", okN and tostring(n) or "not available", table.concat(raw, "; "))
end

-- B281 (#482)
local function CheckWarn()
    local ns = NS()
    if not Loaded() then return nil, "the settings window's addon did not load" end
    local warnArg = RE().CdmWarnArg
    if not (warnArg and ns.CdmNeeds) then return nil, "the rule editor (XayaUI Rules Options) is not loaded: is XayaUI Rules on?" end
    local withWarn, merged, repeated, example = 0, 0, 0, nil
    for _, r in ipairs(ns.rules or {}) do
        local okA, arg = pcall(warnArg, r, -1)
        local okT, txt = false, nil
        if okA and arg and type(arg.name) == "function" then okT, txt = pcall(arg.name) end
        if okT and type(txt) == "string" and txt ~= "" then
            withWarn = withWarn + 1
            local seen, lines, dup = {}, 0, false
            for l in (txt .. "\n"):gmatch("([^\n]*)\n") do lines = lines + 1; if seen[l] then dup = true end; seen[l] = true end
            if dup then repeated = repeated + 1 end
            local okN, needs = pcall(ns.CdmNeeds, r)
            if okN and type(needs) == "table" and #needs > lines then
                merged = merged + 1
                example = example or ("'" .. tostring(r.name or "?") .. "': " .. #needs .. " aura IDs, " .. lines .. " line(s)")
            end
        end
    end
    if withWarn == 0 then return nil, "no rule shows a Cooldown Manager warning right now (log in on the character and spec of the rule, e.g. your Vengeance Demon Hunter, then press Check)" end
    return repeated == 0, ("%d rule(s) show the warning; %d with a line repeated; %d where identical lines were merged%s"):format(
        withWarn, repeated, merged, example and (" (e.g. " .. example .. ")") or "")
end

-- B282 (#484)
local function CheckImportRow()
    if not (Root() and Root().frame and Root().frame:IsShown()) then return nil, "the settings window is not open: press Do it for me" end
    local rows, n = PickerRows()
    local imp, ref = rows["Import"], rows["Dynamic Group"]
    if not (imp and ref) then return nil, ("the type picker is not on screen (%d of its rows shown): press Do it for me"):format(n) end
    local function geo(w)
        local fl = Num(w.frame, "GetLeft") or 0
        return { x = fl, w = Num(w.frame, "GetWidth") or 0, il = (Num(w.image, "GetLeft") or fl) - fl, tl = (Num(w.label, "GetLeft") or fl) - fl,
                 top = (Num(w.frame, "GetTop") or 0) - (Num(w.image, "GetTop") or 0) }
    end
    local a, b = geo(imp), geo(ref)
    local function near(p, q) return math.abs(p - q) < 1 end
    local ok = near(a.x, b.x) and near(a.w, b.w) and near(a.il, b.il) and near(a.tl, b.tl) and near(a.top, b.top)
    return ok, ("Import: row x %.0f, width %.0f, icon +%.0f, text +%.0f, icon %.0f px below the row top; Dynamic Group: row x %.0f, width %.0f, icon +%.0f, text +%.0f, icon %.0f px below the row top"):format(
        a.x, a.w, a.il, a.tl, a.top, b.x, b.w, b.il, b.tl, b.top)
end

-- B283 (#487)
local function CheckDrafts()
    if not (Root() and Root().frame and Root().frame:IsShown()) then return nil, "the settings window is not open: press Do it for me" end
    local R = RE()
    local sub = R.CurrentSub and R.CurrentSub()
    if sub ~= "draftsTab" then return nil, "Rules > Drafts is not the open sub-tab (" .. tostring(sub) .. "): press Do it for me" end
    local _, n = PickerRows()
    local open = R.PickerShown and R.PickerShown() or false
    return n == 0 and not open, ("on Drafts: %d picker row(s) drawn; the picker is %s"):format(n, open and "still open (not forgotten)" or "closed")
end

QA.Register("debug-w1", { title = "Rules editor fixes: Devourer, one Cooldown Manager line, the type picker (B280-B283, debug W1)", qa = "B280, B281, B282, B283", order = 514, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: the rule editor is loaded and its Specialization list is read.\n\n|cffffd100Expect:|r Demon Hunter - Devourer is in the list (a rule's or a group's Load > Specialization), with Havoc and Vengeance; no \"Initial\" entry. The note also keeps what the game answers for the Demon Hunter specs.",
        setup = function() Loaded() end, check = CheckSpecs },
    { text = "On the character and spec of a rule that shows the red Cooldown Manager line (your Vengeance Demon Hunter: Personal Buff Tracking > Active Mitigation, the Metamorphosis rule), press |cffffd100Check|r. Then open that rule's |cffffd100Display|r tab and look under Opacity (all displays).\n\n|cffffd100Expect:|r each red line once: \"Blizzard's Cooldown Manager does not offer in-combat tracking for this aura for your current spec. Rule might not work reliably.\" shows once, not 4 times.",
        check = CheckWarn },
    { text = "Press |cffffd100Do it for me|r: the settings window opens on Rules > Smart Categories and |cffffd100+ New Rule|r is pressed.\n\n|cffffd100Expect:|r \"Choose what this rule shows\": the Import row's icon and text start at the same place as the rows above it (Icon, Texture, ... Dynamic Group), with no extra gap above it.",
        setup = function() Open("cooldowns", "smartTab"); if RE().NewRule then RE().NewRule() end end,
        check = CheckImportRow },
    { text = "Leave the picker open and press |cffffd100Do it for me|r: Rules > |cffffd100Drafts|r opens (or click Drafts yourself).\n\n|cffffd100Expect:|r no type picker on Drafts: the Drafts page shows its own entries and drafts from the top. Back on Smart Categories, the picker is gone too.",
        setup = function() Open("cooldowns", "draftsTab") end,
        check = CheckDrafts },
    { done = true, noVerdict = true, text = "Last step: anything look wrong in these four (a name, a size, a line)? Write it in the note, then press |cffffd100Done|r (no verdict: a note is kept, nothing is recorded as Pass or Fail)." },
} })
