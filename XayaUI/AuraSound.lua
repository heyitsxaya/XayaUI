-------------------------------------------------------------------------------
-- AuraSound.lua : opt-in "the game plays this rule's sound when its aura is gained / lost" (decision D2, retrospective gap 21).
--
-- C_UnitAuras.AddAuraSound(trigger: UnitAuraSoundTrigger, sound: UnitAuraSoundInfo) -> auraSoundID: number?
--   flags HasRestrictions, SecretArguments=AllowedWhenUntainted (12.1.5 docs, docs/reference/api/namespaces.md);
--   UnitAuraSoundTrigger: Added 0, ApplicationsIncreased 1, Removed 2;
--   UnitAuraSoundInfo: unitToken, spellID (required); soundFileName?, soundFileID?, outputChannel?, throttleSeconds?
-- C_UnitAuras.RemoveAuraSound(auraSoundID) undoes one.
-- The game plays the sound itself, so it works while the aura is hidden from addons in combat. It gives addons no signal back
-- (AURA-PLAN D2), and it ignores the rule's other triggers and conditions: the sound follows the aura alone.
--
-- NOT CONFIRMED IN GAME (inference, to check with QA): that it plays for ordinary auras. Blizzard_Deprecated 12.1.0 maps the old
-- AddPrivateAuraAppliedSound onto it, and no Blizzard UI code calls it. Also unconfirmed: whether a /reload clears the game's
-- registrations (the QA step checks for a doubled sound). Registration is done out of combat only ("HasRestrictions": what is
-- restricted is not documented; a refused call is reported and XayaUI keeps playing the sound itself).
-------------------------------------------------------------------------------
local _, ns = ...
local issecret = ns.IsSecret or issecretvalue or function() return false end

local A = {}
ns.AuraSound = A

local registered = {}   -- [rule] = { ids = { auraSoundID ... }, sig = text }
local lastWhy = setmetatable({}, { __mode = "k" })   -- [rule] = why it is not registered (for the settings pane)
local pending = false

A.TRIGGERS = { added = "Added", removed = "Removed", stacks = "ApplicationsIncreased" }
A.WHEN_VALUES = { auto = "Follow the trigger (gained / lost)", added = "When the aura is gained", removed = "When the aura is lost",
    stacks = "When it gains a stack" }
A.WHEN_ORDER = { "auto", "added", "removed", "stacks" }

local function AuraRule(rule)   -- the rule whose Buff / Aura trigger names the aura (a cue's parent)
    if rule.isCue or rule.parentUid then return ns.FindParentRule and ns.FindParentRule(rule) or nil end
    return rule
end

function A.Settings(rule)
    return type(rule) == "table" and type(rule.gameSound) == "table" and rule.gameSound or nil
end

-- A sound the game can play this way: a file path or a FileDataID. Returns fileName, fileID, or nil, nil, why.
function A.ResolveFile(s)
    if type(s) ~= "table" or s.value == nil or s.value == "" then return nil, nil, "no sound picked" end
    if s.source == "kit" then return nil, nil, "a [Game] sound kit cannot be handed to the game this way: pick a sound file" end
    if s.source == "tts" then return nil, nil, "speech cannot be played by the game this way" end
    local v = s.value
    if s.source == "lsm" then
        local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
        v = lsm and lsm:Fetch("sound", s.value, true)
        if v == nil then return nil, nil, "sound not found in LibSharedMedia" end
    end
    local n = tonumber(v)
    if n and n > 0 then return nil, n end
    if type(v) == "string" and v ~= "" then return v, nil end
    return nil, nil, "no sound file"
end

-- What this rule wants registered, or nil and why not.
function A.Plan(rule)
    local g = A.Settings(rule)
    if not (g and g.enabled) then return nil, "off" end
    if not rule.enabled then return nil, "the rule is switched off" end
    if not (ns.KindHas and ns.KindHas(rule, "sound")) then return nil, "this rule plays no sound" end
    local ar = AuraRule(rule)
    if not (ar and ns.BuffUsed and ns.BuffUsed(ar)) then return nil, "the rule has no Buff / Aura trigger" end
    local main = tonumber(ar.buffID) or 0
    if main <= 0 then return nil, "the Buff / Aura trigger has no aura ID" end
    if ns.IsLoaded and not ns.IsLoaded(rule) then return nil, "not loaded now (class, spec, talents or load conditions)" end
    local when = g.when
    if not A.TRIGGERS[when] then when = (ar.buffState == "missing") and "removed" or "added" end
    local snd = (ns.EffectiveSound and ns.EffectiveSound(rule)) or rule.sound
    if not (type(snd) == "table" and snd.enabled) then return nil, "the rule's sound is switched off" end
    local name, fid, why = A.ResolveFile(snd)
    if not (name or fid) then return nil, why end
    local ids, seen = { main }, { [main] = true }
    if type(ar.buffAlt) == "table" then
        for _, a in ipairs(ar.buffAlt) do
            a = tonumber(a)
            if a and a > 0 and not seen[a] then seen[a] = true; ids[#ids + 1] = a end
        end
    end
    local ch = (type(g.channel) == "string" and g.channel ~= "" and g.channel ~= "none") and g.channel or "Ambience"
    local thr = tonumber(g.throttle) or 1
    if thr < 0 then thr = 0 end
    return { ids = ids, when = when, name = name, fid = fid, channel = ch, throttle = thr,
        sig = table.concat(ids, ",") .. "|" .. when .. "|" .. tostring(name or fid) .. "|" .. ch .. "|" .. thr }
end

local function Unregister(rule)
    local r = registered[rule]
    if not r then return end
    for _, id in ipairs(r.ids) do pcall(C_UnitAuras.RemoveAuraSound, id) end
    registered[rule] = nil
end

function A.Available()
    return C_UnitAuras and C_UnitAuras.AddAuraSound and C_UnitAuras.RemoveAuraSound and Enum and Enum.UnitAuraSoundTrigger and true or false
end

-- Bring the game's registrations in line with the rules. Out of combat only.
function A.Sync()
    if not A.Available() then return false, "this game client has no C_UnitAuras.AddAuraSound" end
    if InCombatLockdown and InCombatLockdown() then pending = true; return false, "in combat: updated when combat ends" end
    pending = false
    local want = {}
    for _, r in ipairs(ns.rules or {}) do
        local okP, p, why = pcall(A.Plan, r)
        if okP and p then want[r] = p; lastWhy[r] = nil
        elseif A.Settings(r) and A.Settings(r).enabled then lastWhy[r] = okP and why or ("error: " .. tostring(p))
        else lastWhy[r] = nil end
    end
    for r, reg in pairs(registered) do
        if not want[r] or want[r].sig ~= reg.sig then Unregister(r) end
    end
    for r, p in pairs(want) do
        if not registered[r] then
            local got, err = {}, nil
            local trig = Enum.UnitAuraSoundTrigger[A.TRIGGERS[p.when]]
            for _, aura in ipairs(p.ids) do
                local info = { unitToken = "player", spellID = aura, soundFileName = p.name, soundFileID = p.fid,
                    outputChannel = p.channel, throttleSeconds = (p.throttle > 0) and p.throttle or nil }
                local ok, sid = pcall(C_UnitAuras.AddAuraSound, trig, info)
                if ok and type(sid) == "number" and not issecret(sid) then got[#got + 1] = sid
                else err = ok and "the game gave no sound ID back" or tostring(sid):gsub("^.-:%d+: ", "") end
            end
            if #got > 0 then registered[r] = { ids = got, sig = p.sig, partial = err }; lastWhy[r] = nil
            else lastWhy[r] = "the game refused it: " .. tostring(err) end
            if ns.RecordLine then
                ns.RecordLine("sound", ("game-played sound for rule '%s' (auras %s, %s): %s"):format(tostring(r.name), table.concat(p.ids, ","), p.when,
                    #got > 0 and ("set up, " .. #got .. " ID(s)" .. (err and ("; some refused: " .. tostring(err)) or "")) or ("refused: " .. tostring(err))))
            end
        end
    end
    return true
end

-- The game plays this rule's sound now, and the rule asked XayaUI not to play it as well (Engine.lua skips its own copy).
function A.Owns(rule)
    local r = registered[rule]
    if not r then return false end
    local g = A.Settings(rule)
    return not (g and g.alsoXayaUI)
end

-- One line for the settings pane.
function A.StatusLine(rule)
    local g = A.Settings(rule)
    if not (g and g.enabled) then return "" end
    if not A.Available() then return "|cffffd100Not available:|r this game client has no C_UnitAuras.AddAuraSound." end
    local r = registered[rule]
    local okNow, now = pcall(A.Plan, rule)
    if pending and (not r or not (okNow and now and now.sig == r.sig)) then
        return "|cffffd100Waiting:|r the game takes changes only out of combat; this one is applied when combat ends" ..
            (r and " (until then the game keeps the previous setting)." or ".")
    end
    if r then
        local p = okNow and now or nil
        local what = p and (A.WHEN_VALUES[p.when] or p.when):lower() or "?"
        return ("|cff55ff55The game plays this sound|r %s (aura%s %s, channel %s)%s. Not yet confirmed in game: check it once (QA B33)."):format(
            what, (p and #p.ids > 1) and "s" or "", p and table.concat(p.ids, ", ") or "?", p and p.channel or "?",
            r.partial and (" Some IDs were refused: " .. r.partial) or "")
    end
    if lastWhy[rule] then return "|cffffd100Not played by the game:|r " .. tostring(lastWhy[rule]) .. ". XayaUI plays the sound itself as before." end
    local okP, p, why = pcall(A.Plan, rule)
    if okP and p then return "|cffffd100Not set up yet|r (it is set up a moment after you change a setting)." end
    return "|cffffd100Not played by the game:|r " .. tostring(why or "unknown") .. ". XayaUI plays the sound itself as before."
end

-- When to resync: login, end of combat, spec / talent / gear changes, and every rule edit (debounced; out of combat only).
local queued = false
function A.Queue()
    if queued then return end
    queued = true
    local function Run() queued = false; pcall(A.Sync) end
    if C_Timer and C_Timer.After then C_Timer.After(0.5, Run) else Run() end
end
if CreateFrame then
    local f = CreateFrame("Frame")
    for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "PLAYER_SPECIALIZATION_CHANGED", "TRAIT_CONFIG_UPDATED",
        "PLAYER_EQUIPMENT_CHANGED" }) do pcall(f.RegisterEvent, f, e) end
    if f.SetScript then
        f:SetScript("OnEvent", function(_, event)
            if event == "PLAYER_REGEN_ENABLED" and not pending then return end
            A.Queue()
        end)
    end
end
if hooksecurefunc and ns.MarkDirty then hooksecurefunc(ns, "MarkDirty", A.Queue) end
A._registered = registered
