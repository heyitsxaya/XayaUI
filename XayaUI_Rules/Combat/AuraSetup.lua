-------------------------------------------------------------------------------
-- AuraSetup.lua  (XayaUI 0.5.23)
-- Combat Tracking Setup: the install/initialization sequence for ns.AuraModel.  Works for every class and spec
-- because nothing in it is class-specific: it scans THIS player's spellbook and talents, reads the live spell
-- text, and (out of combat) watches what the player's own casts do to their own buffs.
--
--   Step 1  Scan      what class/spec/loadout was found, how many abilities name a duration
--   Step 2  Learn     cast your self-buffs out of combat; each cast->aura link and its real duration is recorded
--   Step 3  Review    every ability with its duration, where the number came from, and a box to override it
--
-- Opens from /xui debug model setup, from Settings > Advanced, or once automatically the first time a class/spec has
-- no saved setup.  It never opens in combat.
-------------------------------------------------------------------------------
local _, ns = ...; ns = XayaUI_NS or ns -- part of XayaUI core since 0.6.0 (Combat/); shares its namespace
local CoreS = ns.Settings("core")   -- (core 0.6.75, P2 settings seam: the same CueRulesDB keys as before)
if ns.SettingsDeclareStore then ns.SettingsDeclareStore("core", "XayaUI_Rules", "XayaUIRulesDB") end   -- (P5) this addon's own saved variable (its .toc; Modules.lua section 0b)

-- Loaded once: XayaUI itself loads the engine files (XayaUI.toc), so pulling the repo is enough; an old separate
-- XayaUI_CombatEngine folder (installed before 0.6.0) finds this and steps aside (no double load).
ns.engineFiles = ns.engineFiles or {}
if ns.engineFiles.AuraSetup then return end
ns.engineFiles.AuraSetup = true
local M = ns.AuraModel
if not M then return end

local issecret = issecretvalue or function() return false end
local FONT = "Fonts\\ARIALN.TTF"
local ACCENT = { 0.55, 0.35, 0.85 }
local BG = { 0.07, 0.07, 0.09, 0.97 }

local W, H = 660, 560
local frame, step, stepPanels, stepTabs = nil, 1, {}, {}
local rowFrames = {}

local function Fs(parent, size, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(FONT, size or 13, "")
    fs:SetTextColor(r or 0.9, g or 0.9, b or 0.92)
    fs:SetJustifyH("LEFT")
    return fs
end

local function Flat(btn, label)
    local bg = btn:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(ACCENT[1] * 0.45, ACCENT[2] * 0.45, ACCENT[3] * 0.45, 1)
    local hl = btn:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.12)
    local fs = btn:CreateFontString(nil, "OVERLAY"); fs:SetFont(FONT, 13, ""); fs:SetPoint("CENTER"); fs:SetText(label)
    btn.label = fs
    return btn
end

local function Button(parent, label, w, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w or 120, 26)
    Flat(b, label)
    b:SetScript("OnClick", onClick)
    return b
end

local function InCombat() return InCombatLockdown and InCombatLockdown() end

-------------------------------------------------------------------------------
-- Step 1: Scan
-------------------------------------------------------------------------------
local scanText

local function RefreshScan()
    if not frame then return end
    M.Refresh()
    local rows, pending = M.BuildRows()
    local withDur, ambiguous = 0, 0
    for _, r in ipairs(rows) do
        if r.res.seconds then withDur = withDur + 1
        elseif r.res.candidates and #r.res.candidates > 1 then ambiguous = ambiguous + 1 end
    end
    local ctx = M.ctx
    local specName = ""
    if GetSpecialization and GetSpecializationInfo then
        local idx = GetSpecialization()
        if idx then local _, n = GetSpecializationInfo(idx); specName = n or "" end
    end
    local lines = {
        string.format("Class / spec: |cffffd100%s %s|r  (%s)", specName, tostring(ctx.classFile or "?"), tostring(ctx.key or "?")),
        string.format("Talents read from your active setup: |cffffd100%d|r   Set-bonus spells on your gear: |cffffd100%d|r",
            #(ctx.talents or {}), #(ctx.setSpells or {})),
        string.format("Abilities whose text or saved data names a duration: |cffffd100%d|r  (ambiguous, several numbers: %d)", withDur, ambiguous),
    }
    if pending > 0 then
        lines[#lines + 1] = string.format("|cffffa040%d spells are still loading their text from the game; this refreshes by itself.|r", pending)
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "What this scan cannot know: durations the spell text does not state, buffs created by procs, and anything that needs combat."
    lines[#lines + 1] = "Those show as 'no duration' and can be learned out of combat (step 2) or typed in (step 3)."
    scanText:SetText(table.concat(lines, "\n"))
end

-------------------------------------------------------------------------------
-- Step 2: Learn
-------------------------------------------------------------------------------
local learnLogText, learnState

local function RefreshLearn()
    if not frame then return end
    local log = M.learnLog
    local start = math.max(1, #log - 11)
    local t = {}
    for i = start, #log do t[#t + 1] = log[i] end
    learnLogText:SetText(#t > 0 and table.concat(t, "\n") or "(nothing recorded yet)")
    if InCombat() then
        learnState:SetText("|cffff6060In combat: learning is paused. The game hides aura data in combat.|r")
    else
        learnState:SetText(M.IsLearning() and "|cff60ff60Learning is ON. Cast your self-buffs now.|r" or "Learning is OFF.")
    end
end
M.OnLearnLog = function() RefreshLearn() end

-------------------------------------------------------------------------------
-- Step 3: Review
-------------------------------------------------------------------------------
local scroll, content

local SRC_LABEL = {
    override = { "your override", 0.4, 1, 0.4 },
    observed = { "measured", 0.4, 1, 0.4 },
    modeled = { "from spell text", 1, 0.85, 0.3 },
    ["observed-stale"] = { "measured, older setup", 1, 0.6, 0.2 },
    ["legacy-learned"] = { "seen earlier", 1, 0.6, 0.2 },
    none = { "no duration", 0.7, 0.7, 0.7 },
}

local function GetRow(i)
    local r = rowFrames[i]
    if r then return r end
    r = CreateFrame("Frame", nil, content)
    r:SetSize(W - 60, 34)
    r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(26, 26); r.icon:SetPoint("LEFT", 2, 0)
    r.name = Fs(r, 13); r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 6, 0); r.name:SetWidth(260)
    r.sub = Fs(r, 11, 0.7, 0.7, 0.75); r.sub:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 6, 0); r.sub:SetWidth(300)
    r.dur = Fs(r, 13); r.dur:SetPoint("RIGHT", r, "RIGHT", -112, 0); r.dur:SetWidth(110); r.dur:SetJustifyH("RIGHT")
    r.edit = CreateFrame("EditBox", nil, r, "InputBoxTemplate")
    r.edit:SetSize(60, 20); r.edit:SetPoint("RIGHT", r, "RIGHT", -6, 0); r.edit:SetAutoFocus(false); r.edit:SetNumeric(false)
    r.edit:SetFont(FONT, 12, "")
    r.edit:SetScript("OnEnterPressed", function(self)
        local v = tonumber(self:GetText())
        if r.auraID then
            if v and v > 0 then M.SetOverride(r.auraID, v) elseif self:GetText() == "" or self:GetText() == "0" then M.SetOverride(r.auraID, nil) end
        end
        self:ClearFocus()
        if ns.AuraSetup_Refresh then ns.AuraSetup_Refresh() end
    end)
    r.edit:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    r:EnableMouse(true)
    r:SetScript("OnEnter", function(self)
        if not self.tipLines then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        for i2, l in ipairs(self.tipLines) do
            if i2 == 1 then GameTooltip:AddLine(l, 1, 1, 1, true) else GameTooltip:AddLine(l, 0.8, 0.8, 0.85, true) end
        end
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rowFrames[i] = r
    return r
end

local function RefreshReview()
    if not frame then return end
    local rows, pending = M.BuildRows()
    for i = 1, math.max(#rows, #rowFrames) do
        local rf = GetRow(i)
        local d = rows[i]
        if d then
            rf:Show(); rf:ClearAllPoints(); rf:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i - 1) * 36)
            rf.auraID = d.auraID
            local tex
            if C_Spell and C_Spell.GetSpellTexture then local ok, t = pcall(C_Spell.GetSpellTexture, d.castID); if ok then tex = t end end
            rf.icon:SetTexture(tex or 134400)
            rf.name:SetText(d.name)
            local r = d.res
            local lab = SRC_LABEL[r.source] or SRC_LABEL.none
            rf.sub:SetText(string.format("cast %d%s", d.castID, d.auraID ~= d.castID and (" -> aura " .. d.auraID) or ""))
            if r.seconds then rf.dur:SetText(string.format("%.1f s  |cff999999%s|r", r.seconds, lab[1]))
            else rf.dur:SetText(lab[1]) end
            rf.dur:SetTextColor(lab[2], lab[3], lab[4])
            if not rf.edit:HasFocus() then
                local ov = M.Profile(false) and M.Profile(false).entries[d.castID] and M.Profile(false).entries[d.castID].override
                rf.edit:SetText(ov and ov[d.auraID] and tostring(ov[d.auraID]) or "")
            end
            local tip = { d.name .. "  (" .. r.confidence .. " confidence)" }
            if r.base then tip[#tip + 1] = string.format("Spell text says %.1f s; model %.1f s", r.base, r.modeled or r.base) end
            if r.candidates and #r.candidates > 1 then tip[#tip + 1] = "Several durations in the text: " .. table.concat(r.candidates, ", ") .. " s. Type the right one in the box." end
            for _, m in ipairs(r.listed or {}) do
                if m.baked then
                    tip[#tip + 1] = string.format("Already inside the number: %s (%s%.1f%s)", m.srcName, m.amount >= 0 and "+" or "", m.amount, m.op == "pct" and "%" or " s")
                else
                    tip[#tip + 1] = string.format("NOT modeled, depends on an in-combat event: %s -- \"%s\"", m.srcName, m.sentence:sub(1, 120))
                end
            end
            for _, n in ipairs(r.notes or {}) do tip[#tip + 1] = n end
            tip[#tip + 1] = "Type seconds in the box and press Enter to override. Empty box + Enter removes it."
            rf.tipLines = tip
        else
            rf:Hide()
        end
    end
    content:SetHeight(math.max(1, #rows * 36))
    frame.reviewCount:SetText(string.format("%d abilities%s", #rows, pending > 0 and string.format("  (%d still loading)", pending) or ""))
end

-------------------------------------------------------------------------------
-- Frame / steps
-------------------------------------------------------------------------------
local function ShowStep(n)
    step = n
    for i, p in ipairs(stepPanels) do p:SetShown(i == n) end
    for i, t in ipairs(stepTabs) do
        t.label:SetTextColor(i == n and 1 or 0.6, i == n and 1 or 0.6, i == n and 1 or 0.65)
    end
    M.SetLearning(n == 2 and not InCombat())
    frame.back:SetEnabled(n > 1)
    frame.next:SetShown(n < 3)
    frame.finish:SetShown(n == 3)
    if n == 1 then RefreshScan() elseif n == 2 then RefreshLearn() else RefreshReview() end
end

function ns.AuraSetup_Refresh()
    if not (frame and frame:IsShown()) then return end
    if step == 1 then RefreshScan() elseif step == 2 then RefreshLearn() else RefreshReview() end
end

local function Build()
    frame = CreateFrame("Frame", "XayaUIAuraSetupFrame", UIParent, "BackdropTemplate")
    frame:SetSize(W, H); frame:SetPoint("CENTER"); frame:SetFrameStrata("DIALOG")
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    frame:SetBackdropColor(unpack(BG)); frame:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 1)
    frame:EnableMouse(true); frame:SetMovable(true); frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving); frame:SetScript("OnDragStop", frame.StopMovingAndSettling or frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    tinsert(UISpecialFrames, "XayaUIAuraSetupFrame")

    local title = Fs(frame, 17, 1, 1, 1); title:SetPoint("TOPLEFT", 16, -14); title:SetText("XayaUI  |  Combat Tracking Setup")
    local close = Button(frame, "Close", 70, function() frame:Hide() end); close:SetPoint("TOPRIGHT", -12, -10)

    local names = { "1  Scan", "2  Learn", "3  Review" }
    for i = 1, 3 do
        local t = CreateFrame("Button", nil, frame)
        t:SetSize(110, 24); t:SetPoint("TOPLEFT", 16 + (i - 1) * 116, -46)
        local fs = t:CreateFontString(nil, "OVERLAY"); fs:SetFont(FONT, 14, ""); fs:SetPoint("LEFT"); fs:SetText(names[i]); t.label = fs
        t:SetScript("OnClick", function() ShowStep(i) end)
        stepTabs[i] = t
    end
    local rule = frame:CreateTexture(nil, "ARTWORK"); rule:SetColorTexture(ACCENT[1], ACCENT[2], ACCENT[3], 0.6)
    rule:SetPoint("TOPLEFT", 12, -74); rule:SetPoint("TOPRIGHT", -12, -74); rule:SetHeight(1)

    for i = 1, 3 do
        local p = CreateFrame("Frame", nil, frame)
        p:SetPoint("TOPLEFT", 16, -84); p:SetPoint("BOTTOMRIGHT", -16, 52)
        stepPanels[i] = p
    end

    -- step 1
    local p1 = stepPanels[1]
    local h1 = Fs(p1, 13, 0.8, 0.8, 0.85); h1:SetPoint("TOPLEFT", 0, 0); h1:SetWidth(W - 40)
    h1:SetText("This sets up duration tracking for the class and spec you are playing right now. It reads your spellbook, your active talents and the game's own spell text. Nothing is class-specific, so it works for any class.")
    h1:SetWordWrap(true)
    scanText = Fs(p1, 13); scanText:SetPoint("TOPLEFT", 0, -78); scanText:SetWidth(W - 40); scanText:SetWordWrap(true); scanText:SetJustifyV("TOP")
    local rescan = Button(p1, "Scan again", 110, function() M.ClearTextCache(); RefreshScan() end); rescan:SetPoint("BOTTOMLEFT", 0, 0)

    -- step 2
    local p2 = stepPanels[2]
    local h2 = Fs(p2, 13, 0.8, 0.8, 0.85); h2:SetPoint("TOPLEFT", 0, 0); h2:SetWidth(W - 40); h2:SetWordWrap(true)
    h2:SetText("Stand out of combat. Cast each of your self-buffs and cooldowns once (Metamorphosis, Icy Veins, Combustion, Bloodlust-type buffs, defensive cooldowns, anything that puts a timed buff on you). Each cast records the real duration under your current talents and gear.\n\nAbilities that need a target or combat cannot be learned this way, because the game hides aura data in combat. They keep the spell-text value, which you can override in step 3.")
    learnState = Fs(p2, 13); learnState:SetPoint("TOPLEFT", 0, -140); learnState:SetWidth(W - 40)
    learnLogText = Fs(p2, 12, 0.85, 0.85, 0.9); learnLogText:SetPoint("TOPLEFT", 0, -166); learnLogText:SetWidth(W - 40); learnLogText:SetJustifyV("TOP"); learnLogText:SetWordWrap(true)

    -- step 3
    local p3 = stepPanels[3]
    frame.reviewCount = Fs(p3, 12, 0.7, 0.7, 0.75); frame.reviewCount:SetPoint("TOPLEFT", 0, 0)
    local hint = Fs(p3, 12, 0.7, 0.7, 0.75); hint:SetPoint("TOPRIGHT", 0, 0); hint:SetJustifyH("RIGHT"); hint:SetText("hover a row for the reasoning")
    scroll = CreateFrame("ScrollFrame", "XayaUIAuraSetupScroll", p3, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -20); scroll:SetPoint("BOTTOMRIGHT", -24, 0)
    content = CreateFrame("Frame", nil, scroll); content:SetSize(W - 60, 1); scroll:SetScrollChild(content)

    -- footer
    frame.back = Button(frame, "Back", 90, function() ShowStep(math.max(1, step - 1)) end); frame.back:SetPoint("BOTTOMLEFT", 16, 14)
    frame.next = Button(frame, "Next", 90, function() ShowStep(math.min(3, step + 1)) end); frame.next:SetPoint("BOTTOMRIGHT", -16, 14)
    frame.finish = Button(frame, "Finish setup", 120, function()
        local p = M.Profile(true)
        if p then p.setupDone = (select(4, GetBuildInfo())) or true; p.skipped = nil end
        M.SetLearning(false); frame:Hide()
        ns.Print("combat tracking setup saved for " .. tostring(M.ctx.key) .. ". Change it any time: Settings > UI Options > Rule Creation > Combat Tracking Setup.")
    end)
    frame.finish:SetPoint("BOTTOMRIGHT", -16, 14)
    local skip = Button(frame, "Skip for this spec", 140, function()
        local p = M.Profile(true); if p then p.skipped = true end
        M.SetLearning(false); frame:Hide()
        ns.Print("skipped. Open it whenever you want: Settings > UI Options > Rule Creation > Combat Tracking Setup.")
    end)
    skip:SetPoint("BOTTOM", 0, 14)

    frame:SetScript("OnHide", function() M.SetLearning(false) end)
    M.OnSpellDataLoaded = function() if frame:IsShown() and C_Timer then C_Timer.After(0.3, ns.AuraSetup_Refresh) end end
    M.OnLoadoutChanged = function() if frame:IsShown() then ns.AuraSetup_Refresh() end end
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_REGEN_DISABLED"); ev:RegisterEvent("PLAYER_REGEN_ENABLED")
    ev:SetScript("OnEvent", function(_, e)
        if not frame:IsShown() then return end
        if e == "PLAYER_REGEN_DISABLED" then M.SetLearning(false) elseif step == 2 then M.SetLearning(true) end
        ns.AuraSetup_Refresh()
    end)
end

function ns.AuraSetup_Open()
    if InCombat() then ns.Print("combat tracking setup cannot open in combat."); return end
    if not frame then
        local ok, err = pcall(Build)
        if not ok then
            ns.Print("setup window failed to build: " .. tostring(err))
            if frame then frame:Hide() end
            frame = nil; wipe(stepPanels); wipe(stepTabs)
            local db = ns.SettingsReady("core") and CoreS
            if db then db.setupBuildError = (date and date("%Y-%m-%d %H:%M:%S ") or "") .. tostring(err) end
            return
        end
    end
    M.Refresh()
    frame:Show()
    local okS, errS = pcall(ShowStep, 1)
    if not okS then
        ns.Print("setup window error: " .. tostring(errS))
        local db = ns.SettingsReady("core") and CoreS
        if db then db.setupShowError = (date and date("%Y-%m-%d %H:%M:%S ") or "") .. tostring(errS) end
    end
    -- spell text arrives asynchronously: scan again shortly so the first view is not half-empty
    if C_Timer then C_Timer.After(1.5, function() if frame:IsShown() then ns.AuraSetup_Refresh() end end) end
end

-------------------------------------------------------------------------------
-- First run: once per class/spec that has neither a saved setup nor a skip.
-------------------------------------------------------------------------------
local asked = {}
function ns.AuraSetup_FirstRunCheck()
    if InCombat() then return end
    if IsInInstance then local okI, inInst = pcall(IsInInstance); if okI and inInst then return end end
    M.Refresh()
    local key = M.ctx.key
    if not key or asked[key] then return end
    local p = M.Profile(false)
    if p and (p.setupDone or p.skipped) then return end
    if M.DB() and M.DB().settings.noPrompt then return end
    asked[key] = true
    ns.Print("combat tracking is not set up for " .. key .. " yet. Opening the short setup (Skip is on the window).")
    ns.AuraSetup_Open()
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_ENTERING_WORLD")
boot:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
boot:SetScript("OnEvent", function(_, e, unit)
    if e == "PLAYER_SPECIALIZATION_CHANGED" and unit ~= "player" then return end
    if C_Timer then C_Timer.After(6, function() pcall(ns.AuraSetup_FirstRunCheck) end) end
end)
