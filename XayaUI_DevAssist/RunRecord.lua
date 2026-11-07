-------------------------------------------------------------------------------
-- RunRecord.lua (XayaUI Dev Assist 0.7.8): "Record this run?" for Mythic 0 and Mythic+ dungeons.
--
-- ONE-PUSH FEATURE. Xaya, 2026-11-07 (REQUEST-LOG A12 CLEAN-10, A15 P-4): "For exactly one main push for the time being, have dev
-- assist pre-loaded with a prompt that auto-pops when it detects a player has entered a m+/m0 instance. Suggest recording the run.
-- "Accept" button will turn on every dev assist tool reasonably required to assess performance and functionality." Her answer:
-- "Ships once, then removed". REMOVE THIS FILE (and its line in XayaUI_DevAssist.toc, its QA step and tests/run_record_run.py) in the
-- landing AFTER the one that ships it. The recording tools themselves stay (DevRecord.lua, incl. the per-addon meter lines).
--
-- What it does (her answers, A15 P-4 / P-5):
--   * On entering a Mythic 0 or Mythic+ dungeon, out of combat, once per visit: "Record this run?" Accept / Not now. Never in combat
--     (it waits for combat to end).
--   * Accept turns on Advanced Debugging and the detailed record, the record kinds a dungeon needs (rules, snapshots, auras,
--     displays, glows, sounds, game state, engine, Perf, messages), and 10,000 kept lines ("10,000 lines (Recommended)"). It leaves
--     off what cannot change in a key (stat weights, formula capture, Character Toolkit, API inventory, width probes) and the
--     game-data probe ("Probe off; keep yours (Recommended)"). Trigger detail stays as set (it needs rules picked by hand). It lists
--     what it turned on.
--   * Leaving that dungeon: "Done with instance?" Confirm turns off ONLY what Accept turned on (tools that were on before stay on)
--     and reloads, which writes the saved file (WTF\Account\<account>\SavedVariables\XayaUI.lua) for upload; tools/perf_report.py
--     reads it. Not yet: it keeps recording and asks again at the next zone change.
-- Cost: one small event frame while Dev Assist is enabled (zone changes, combat end, Mythic+ start); the window is made on first
-- show. Dev Assist is a developer addon, off for players (V14).
--
-- API 12.1.5 (docs/reference/api/api.json, quoted in full; no documentation text exists for any of them):
--   GetInstanceInfo() -> name: cstring, instanceType: cstring, difficultyID: number, difficultyName: cstring, maxPlayers: number,
--       dynamicDifficulty: number, isDynamic: bool?, instanceID: number, instanceGroupSize: number, lfgDungeonID: number?,
--       hasWorldTier: bool = false
--   GetDifficultyInfo(difficultyID: number) -> name: cstring, instanceType: cstring, isHeroic: bool, isChallengeMode: bool,
--       displayHeroic: bool, displayMythic: bool, toggleDifficultyID: number?, isLFR: bool, minPlayers: number?, maxPlayers: number?,
--       isUserSelectable: bool   [SecretArguments=AllowedWhenUntainted]
--   C_ChallengeMode.IsChallengeModeActive() -> challengeModeActive: bool
--   events: PLAYER_ENTERING_WORLD (isInitialLogin: bool, isReloadingUi: bool), ZONE_CHANGED_NEW_AREA (no payload),
--       PLAYER_REGEN_ENABLED (no payload), CHALLENGE_MODE_START (mapID: number)
-- No difficulty ID is hard-coded: Mythic+ = isChallengeMode (or a running key); Mythic 0 = a "party" instance whose difficulty has
-- displayMythic and not isChallengeMode. INFERENCE: a key dungeon reads as Mythic 0 until the key starts, so entering it prompts
-- then; CHALLENGE_MODE_START prompts if that was missed. Every value read is checked with issecretvalue; a secret one counts as
-- "not a Mythic dungeon" (nothing is guessed).
-------------------------------------------------------------------------------
local ns = rawget(_G, "XayaUI_NS")
if type(ns) ~= "table" or type(ns.DebugRecordInfo) ~= "table" or type(ns.SetRecCat) ~= "function" then return end
local DR = ns.DebugRecordInfo
local issecret = ns.IsSecret or issecretvalue or function() return false end
local RR = {}
DR.RunRecord = RR

-- the record kinds Accept switches on (DevRecord.lua DR.CATS keys); "triggers" is left as the player set it
RR.CATS = { "rules", "snapshots", "auras", "displays", "glows", "sounds", "game", "engine", "perf", "messages" }
RR.MAX_LINES = 10000
-- what Accept leaves off on purpose (shown in the window so the choice is visible)
RR.LEFT_OFF = "stat weights, formula capture, Character Toolkit, API inventory, width probes, game-data probe"

local function Ui()
    if type(CueRulesDB) ~= "table" then return {} end
    CueRulesDB.ui = CueRulesDB.ui or {}
    return CueRulesDB.ui
end
local function State() local u = Ui(); return type(u.runRecord) == "table" and u.runRecord or nil end
local function Clean(v) if v == nil or issecret(v) then return nil end return v end
local function InCombat()
    local ok, c = pcall(function() return (InCombatLockdown and InCombatLockdown()) or (UnitAffectingCombat and UnitAffectingCombat("player")) end)
    return (not ok) or (c and true or false)
end

-- Where are we? -> kind ("mplus", "m0" or nil), instanceID, name
function RR.Place()
    local ok, name, itype, diff, _, _, _, _, instID = pcall(GetInstanceInfo)
    if not ok then return nil end
    itype, diff, instID, name = Clean(itype), Clean(diff), Clean(instID), Clean(name)
    if itype ~= "party" or type(diff) ~= "number" then return nil, instID, name end
    local okA, active = pcall(function() return C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() end)
    if okA and Clean(active) == true then return "mplus", instID, name end
    local okD, _, _, _, isCM, _, dispMythic = pcall(GetDifficultyInfo, diff)
    if not okD then return nil, instID, name end
    if Clean(isCM) == true then return "mplus", instID, name end
    if Clean(dispMythic) == true then return "m0", instID, name end
    return nil, instID, name
end

-------------------------------------------------------------------------------
-- Accept / Done
-------------------------------------------------------------------------------
function RR.Accept(instID, name, kind)
    local u = Ui()
    if State() then return {} end
    local st = { instanceID = instID, name = name, kind = kind, started = date and date("%Y-%m-%d %H:%M:%S") or "?", turned = {} }
    local turned, labels = st.turned, {}
    if not u.advancedDebug then
        u.advancedDebug = true; turned.advancedDebug = true; labels[#labels + 1] = "Advanced Debugging"
        -- (turning Advanced Debugging on would also start the game-data probe; her answer keeps it off for the run)
        if u.debugProbe ~= false then u.debugProbe = false; turned.probeOff = true end
    end
    if u.recordOff == true then u.recordOff = nil; turned.recordOn = true; labels[#labels + 1] = "the detailed record" end
    turned.cats = {}
    for _, key in ipairs(RR.CATS) do
        if not ns.RecCatSetting(key) then ns.SetRecCat(key, true); turned.cats[#turned.cats + 1] = key; labels[#labels + 1] = key end
    end
    if tonumber(u.recordMax) ~= RR.MAX_LINES then turned.recordMax = u.recordMax or "default"; u.recordMax = RR.MAX_LINES
        labels[#labels + 1] = RR.MAX_LINES .. " kept lines" end
    u.runRecord = st
    if ns.DebugSettingsChanged then pcall(ns.DebugSettingsChanged) end
    if ns.RecordLine then
        ns.RecordLine("note", ("---------- recorded run starts: %s (%s, instance %s) ----------"):format(tostring(name or "?"),
            kind == "mplus" and "Mythic+" or "Mythic 0", tostring(instID or "?")))
        if DR.RecordMeter then DR.RecordMeter("run start") end
    end
    return labels
end

function RR.Done(reload)
    local u, st = Ui(), State()
    if not st then return end
    if ns.RecordLine then
        if DR.RecordMeter then DR.RecordMeter("run end") end
        ns.RecordLine("note", ("---------- recorded run ends: %s ----------"):format(tostring(st.name or "?")))
    end
    local t = type(st.turned) == "table" and st.turned or {}
    for _, key in ipairs(type(t.cats) == "table" and t.cats or {}) do ns.SetRecCat(key, false) end
    if t.recordMax ~= nil then u.recordMax = (t.recordMax ~= "default") and t.recordMax or nil end
    if t.recordOn then u.recordOff = true end
    if t.probeOff then u.debugProbe = nil end
    if t.advancedDebug then u.advancedDebug = false end
    u.runRecord = nil
    if ns.DebugSettingsChanged then pcall(ns.DebugSettingsChanged) end
    if reload and ReloadUI then ReloadUI() end
end

-------------------------------------------------------------------------------
-- The window (made the first time it shows)
-------------------------------------------------------------------------------
local W
local ACC = { 0.55, 0.35, 0.95 }
local function Btn(parent, label, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(120, 22); b:SetText(label)
    if ns.FlatButton then ns.FlatButton(b) end
    b:SetScript("OnClick", onClick)
    return b
end
local function Build()
    if W then return W end
    W = CreateFrame("Frame", "XayaUIDevRunRecord", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    W:SetSize(420, 150); W:SetPoint("TOP", 0, -140); W:SetFrameStrata("DIALOG"); W:SetClampedToScreen(true)
    if W.SetBackdrop then
        W:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
        W:SetBackdropColor(0.05, 0.05, 0.07, 0.96); W:SetBackdropBorderColor(ACC[1], ACC[2], ACC[3], 1)
    end
    W.title = W:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"); W.title:SetPoint("TOP", 0, -12)
    W.text = W:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    W.text:SetPoint("TOPLEFT", 14, -40); W.text:SetPoint("TOPRIGHT", -14, -40); W.text:SetJustifyH("LEFT"); W.text:SetJustifyV("TOP")
    if W.text.SetWordWrap then W.text:SetWordWrap(true) end
    W.yes = Btn(W, "Accept", function() if W.onYes then W.onYes() end end); W.yes:SetPoint("BOTTOMRIGHT", W, "BOTTOM", -6, 12)
    W.no = Btn(W, "Not now", function() if W.onNo then W.onNo() end end); W.no:SetPoint("BOTTOMLEFT", W, "BOTTOM", 6, 12)
    W:Hide()
    return W
end
local function Show(title, text, yes, no, onYes, onNo)
    local w = Build()
    w.title:SetText(title); w.text:SetText(text); w.yes:SetText(yes); w.no:SetText(no)
    w.onYes, w.onNo = onYes, onNo
    w:Show()
end
RR.Window = function() return W end
local function Hide() if W then W:Hide() end end

-------------------------------------------------------------------------------
-- When to ask
-------------------------------------------------------------------------------
local declined, pending = nil, nil   -- declined: the instance answered "Not now" this visit; pending: a check waiting for combat end
local function AskStart(kind, instID, name)
    Show("Record this run?",
        ("%s: %s. Dev Assist can record this run for the performance test: rule and display activity, the engine's timing per fight and the game's CPU meter per addon. Accept turns on what a dungeon needs and lists it; it stays off: %s.")
            :format(kind == "mplus" and "Mythic+" or "Mythic 0", tostring(name or "this dungeon"), RR.LEFT_OFF),
        "Accept", "Not now",
        function()
            local labels = RR.Accept(instID, name, kind)
            local list = #labels > 0 and table.concat(labels, ", ") or "nothing (all of it was already on)"
            if ns.Print then ns.Print("Dev Assist: recording this run. Turned on: " .. list .. ".") end
            Show("Recording this run", "Turned on: " .. list .. ".\nWhen you leave the dungeon, Dev Assist asks whether you are done.",
                "OK", "Close", Hide, Hide)
        end,
        function() declined = instID; Hide() end)
end
local function AskDone()
    local st = State()
    Show("Done with instance?",
        ("You left %s. Confirm turns off the recording tools this run turned on and reloads the interface, which writes the record to your saved file (SavedVariables\\XayaUI.lua) for upload. Not yet keeps recording.")
            :format(tostring(st and st.name or "the dungeon")),
        "Confirm", "Not yet",
        function() Hide(); RR.Done(true) end,
        function() Hide() end)
end
function RR.Check()
    if InCombat() then pending = true; return end
    pending = nil
    local kind, instID, name = RR.Place()
    local st = State()
    if st then
        if kind and instID ~= nil and instID == st.instanceID then
            if W and W:IsShown() and W.title:GetText() == "Done with instance?" then Hide() end
            return
        end
        AskDone()
        return
    end
    if not kind then declined = nil; if W and W:IsShown() and W.title:GetText() == "Record this run?" then Hide() end; return end
    if declined ~= nil and declined == instID then return end
    if W and W:IsShown() then return end
    AskStart(kind, instID, name)
end

local f = CreateFrame("Frame")
f:SetScript("OnEvent", function(_, e)
    if e == "PLAYER_REGEN_ENABLED" then if pending then RR.Check() end return end
    RR.Check()
end)
for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_REGEN_ENABLED", "CHALLENGE_MODE_START" }) do
    pcall(f.RegisterEvent, f, e)
end
RR.frame = f
