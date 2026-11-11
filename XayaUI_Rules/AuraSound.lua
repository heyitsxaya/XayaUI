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
-- registrations (the QA step checks for a doubled sound). AddAuraSound is called out of combat lockdown only ("HasRestrictions",
-- the flag the protected TargetUnit also carries; what is restricted is not documented; a refused call is reported and XayaUI keeps
-- playing the sound itself). RemoveAuraSound carries no such flag, so a copy is taken back at once, in combat too (SD-25).
-------------------------------------------------------------------------------
local _, ns = ...; ns = XayaUI_NS or ns -- (P4) XayaUI Rules shares the Platform's namespace (XayaUI/Core.lua)
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
    if s.source == "kit" then return nil, nil, "a [Game] sound kit cannot be handed to the game this way, so pick a sound file instead" end
    if s.source == "tts" then return nil, nil, "speech cannot be played by the game this way" end
    local v = s.value
    if s.source == "lsm" then
        local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
        v = lsm and lsm:Fetch("sound", s.value, true)
        if v == nil then return nil, nil, "the sound was not found in the shared sound list" end
    end
    local n = tonumber(v)
    if n and n > 0 then return nil, n end
    if type(v) == "string" and v ~= "" then return v, nil end
    return nil, nil, "no sound file"
end

-- (review R2) Whether the game's copy is set up for this rule now. The game plays it on the aura alone, in combat too, and takes
-- new sounds only out of combat. So it follows the Load tab except the choices whose answer at the moment the aura changes cannot be
-- known at set-up: Combat, Boss encounter and the Boss encounters lists (the rule's and its groups'). Those count as "may be true".
-- Instance, Group, Raid group, Mythic+ and Resting area are kept: they change out of combat, and the events below re-plan (an
-- in-combat change waits for the end of combat through `pending`). Mounted is kept too (SD-25, Xaya: "it should be option two with
-- zero justifications for failure"): the plan says which mount state the copy needs (plan.mount), and the mount event and the start
-- of combat add or take it back at once (OnMount, below). Returns true and that mount state, or false and a plain reason for the pane.
local DROP = { combat = true, encounter = true }
-- Does the load table set any of those choices? names (pane only): gets them as the Load tab shows them; rule (pane only): also
-- names the Boss encounters lists of its groups.
local function DroppedOn(load, names, rule)
    if names and rule and ns.FolderById and not (ns.FolderLoadOverride and ns.FolderLoadOverride(rule)) then
        -- (round 3, R2 concern) a group's list is skipped too (ns.CheckContext static)
        local fid, guard = rule.folder, 0
        while fid and guard < 32 do
            local f = ns.FolderById(fid)
            if not f then break end
            if type(f.loadIds) == "table" and ns.SetActive(f.loadIds.encounterIDs) then
                names[#names + 1] = ('"Boss encounters" of its group "%s"'):format(tostring(f.name))
            end
            fid, guard = f.parent, guard + 1
        end
    end
    if load.mode == "always" or load.mode == "never" or not ns.LOAD_TRI then return false end
    local on = false
    for _, c in ipairs(ns.LOAD_TRI) do
        local st = load[c.key]
        if DROP[c.key] and not ns.Ignored(st) then
            on = true
            if names then names[#names + 1] = '"' .. ((st == "yes" and c.yes) or (st == "no" and c.no) or c.label) .. '"' end
        end
    end
    if ns.SetActive(load.encounterIDs) then
        on = true
        if names then names[#names + 1] = '"Boss encounters"' end
    end
    return on
end
local ANY_OPEN = { mode = "any" }   -- (read only) a Match ANY rule with a "may be true" choice: its own choices pass
local function LoadView(load)   -- the rule's load table without those choices (a copy; made only on a sync or a pane redraw)
    if load.mode == "any" and DroppedOn(load) then return ANY_OPEN end   -- (R2 follow-up: treated as possibly true)
    local copy = {}
    for k, v in pairs(load) do copy[k] = v end
    for k in pairs(DROP) do copy[k] = nil end
    copy.encounterIDs = nil
    return copy
end
local function LoadRule(rule)   -- an outcome loads exactly when its parent does (as ns.IsLoaded)
    return rule.parentUid and ns.FindParentRule and ns.FindParentRule(rule) or rule
end
-- (R2 follow-up) core's reason (Conditions.lua CheckContextRaw), in the words the editor uses. One clause, no colon.
local LABEL = { class = "Class", spec = "Specialization", specialization = "Specialization", role = "Role", ["hero talents"] = "Hero Talents",
    ["instance type"] = "Instance Type", zone = "Zones", ["instance ID"] = "Instances", difficulty = "Difficulties",
    ["instance size"] = "Instance sizes", encounter = "Boss encounters", ["item equipped"] = "Items equipped" }
local CHARACTER = { Class = true, Specialization = true, Role = true, ["Hero Talents"] = true, ["Items equipped"] = true }
local function Plain(why, load)
    local folder = why:match("^load: never %(folder (.*)%)$")
    if folder then return ('its group "%s" is set to Never load'):format(folder) end
    if why == "load: never" then return 'its Load tab is set to "Never load"' end
    if why:find("^none of the conditions matched") then return 'none of its Load tab choices are met here ("Match ANY")' end
    local unknown = why:find(" %(unknown%)$") ~= nil
    if unknown then why = why:sub(1, -11) end
    local g, key = why:match("^group (.*) %(Always load, only this (%a+)")
    if not g then key = why:match("^Always load, only this (%a+)") end
    if not key then g, key = why:match("^group (.*): ([^:]+)$") end
    key = key or why
    local label = LABEL[key]
    if not (label or g) then   -- one of the rule's own Yes / No choices: as the Load tab shows it once ticked
        for _, c in ipairs(ns.LOAD_TRI) do
            if c.key == key then
                local st = load and load[key]
                label = (st == "yes" and c.yes) or (st == "no" and c.no) or c.label
                break
            end
        end
    end
    label = (label or key) .. (g and (', group "' .. g .. '"') or "")
    if unknown then return ("it cannot be checked right now (%s)"):format(label) end
    if CHARACTER[LABEL[key] or ""] then return ("it is not for this character (%s)"):format(label) end
    return ("it is not set to load here (%s)"):format(label)
end
-- Returns true and the mount state the copy needs (true / false; nil = either), or false and why.
local function StaticLoaded(rule, ctx)
    local lr = LoadRule(rule)
    if not lr.enabled then return false, "the rule it belongs to is switched off" end
    if not (ns.CheckContext and ns.ReadContext and ns.LOAD_TRI) then   -- (an older core: the full check, as before)
        if ns.IsLoaded and not ns.IsLoaded(rule) then return false, "its Load tab does not match this character here" end
        return true
    end
    if not ctx then ctx = ns.ReadContext(); ctx.sig = nil end   -- (no sig: the answer for this view is not kept in core's memo)
    local ld = type(lr.load) == "table" and lr.load or nil
    local view = lr
    if ld then view = setmetatable({ load = LoadView(ld) }, { __index = lr }) end
    local ok, fine, why, gate
    local ms = ld and ld.mounted
    if ms ~= nil and not ns.Ignored(ms) and ld.mode ~= "always" and ld.mode ~= "never" then
        -- (SD-25) answer for both mount states: true for both = no gate; for one = the copy follows that state
        local real = ctx.mounted
        ctx.mounted = true
        local okY, fineY, whyY = pcall(ns.CheckContext, view, ctx, true)
        ctx.mounted = false
        local okN, fineN, whyN = pcall(ns.CheckContext, view, ctx, true)
        ctx.mounted = real
        ok = okY and okN
        if not ok then fine = okY and fineN or fineY
        elseif fineY == true and fineN == true then fine = true
        elseif fineY == true then fine, gate = true, true
        elseif fineN == true then fine, gate = true, false
        else fine, why = false, (ms == "yes") and whyY or whyN end   -- (the reason other than the mount state)
    else
        ok, fine, why = pcall(ns.CheckContext, view, ctx, true)   -- (round 3, R2 concern: static, so a group's Boss encounters list is skipped too)
    end
    if not ok then return false, "something went wrong (" .. tostring(fine):gsub("^.-:%d+: ", "") .. ")" end
    if fine ~= true then return false, Plain(tostring(why or ""), ld) end
    local okT, t = pcall(ns.CheckTalents, lr)
    if okT and t == nil then return false, "it cannot be checked right now (Talent List)" end
    if not (okT and t == true) then return false, "it is not for this character (Talent List)" end
    return true, gate
end

-- What this rule wants registered, or nil and why not. ctx: core's load context without its sig (A.Sync reads it once).
function A.Plan(rule, ctx)
    local g = A.Settings(rule)
    if not (g and g.enabled) then return nil, "off" end
    if not rule.enabled then return nil, "the rule is switched off" end
    if not (ns.KindHas and ns.KindHas(rule, "sound")) then return nil, "this rule plays no sound" end
    local ar = AuraRule(rule)
    if not (ar and ns.BuffUsed and ns.BuffUsed(ar)) then return nil, "the rule has no Buff / Aura trigger" end
    local main = tonumber(ar.buffID) or 0
    if main <= 0 then return nil, "the Buff / Aura trigger has no aura ID" end
    local loaded, lwhy = StaticLoaded(rule, ctx)
    if not loaded then return nil, lwhy end
    local gate = lwhy   -- (SD-25) true / false: the copy is held only while mounted / not mounted; nil: either
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
    return { ids = ids, when = when, name = name, fid = fid, channel = ch, throttle = thr, mount = gate,
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

local Start, Stop, Users, MountWatch   -- (below: the feature's events, V14)
local gated = {}   -- (SD-25) [rule] = its plan, for every rule whose copy follows the mount state (kept ready for OnMount)

-- Hand one plan to the game. Never called in combat lockdown (AddAuraSound "HasRestrictions"). The info tables are made once per plan
-- and kept on it, so a mount / dismount that adds the copy again makes only the small list of IDs.
local function Register(r, p)
    local infos = p.infos
    if not infos then
        infos = {}
        for i, aura in ipairs(p.ids) do
            infos[i] = { unitToken = "player", spellID = aura, soundFileName = p.name, soundFileID = p.fid,
                outputChannel = p.channel, throttleSeconds = (p.throttle > 0) and p.throttle or nil }
        end
        p.infos = infos
    end
    local got, err = {}, nil
    local trig = Enum.UnitAuraSoundTrigger[A.TRIGGERS[p.when]]
    for _, info in ipairs(infos) do
        local ok, sid = pcall(C_UnitAuras.AddAuraSound, trig, info)
        if ok and type(sid) == "number" and not issecret(sid) then got[#got + 1] = sid
        else err = ok and "the game gave no sound ID back" or tostring(sid):gsub("^.-:%d+: ", "") end
    end
    if #got > 0 then registered[r] = { ids = got, sig = p.sig, partial = err }; lastWhy[r] = nil
    else lastWhy[r] = "the game refused it (" .. tostring(err) .. ")" end
    if ns.RecordOn and ns.RecordOn("sound") then   -- (the text only while the debug record keeps "Sounds"; DebugRecord.lua)
        ns.RecordLine("sound", ("game-played sound for rule '%s' (auras %s, %s): %s"):format(tostring(r.name), table.concat(p.ids, ","), p.when,
            #got > 0 and ("set up, " .. #got .. " ID(s)" .. (err and ("; some refused: " .. tostring(err)) or "")) or ("refused: " .. tostring(err))))
    end
end

local NO_LOAD = {}   -- (read only) a rule with no Load tab table, for the pane
local function MountLabel(gate)   -- the Load tab's own words for the mount choice
    for _, c in ipairs(ns.LOAD_TRI or NO_LOAD) do
        if c.key == "mounted" then return gate and c.yes or c.no end
    end
    return gate and "Only when mounted" or "Only when not mounted"
end
-- The mount state now: true / false, or nil when the game does not say (IsMounted, globals.md: no secrecy flag; checked anyway).
local function MountedNow()
    local ok, m = pcall(IsMounted)
    if not ok or m == nil or issecret(m) then return nil end
    return m and true or false
end

-- Bring the game's registrations in line with the rules. Out of combat only.
function A.Sync()
    if not A.Available() then return false, "this version of the game cannot do this" end
    if ns.RulesDisabled then A.TakeAllBack(); return false, "every rule is off (/xui disable)" end   -- (V26)
    if InCombatLockdown and InCombatLockdown() then
        pending = true
        if next(registered) or Users() then Start() end   -- (the end of combat applies it: PLAYER_REGEN_ENABLED)
        return false, "in combat: updated when combat ends"
    end
    pending = false
    local want = {}
    for r in pairs(gated) do gated[r] = nil end
    local okC, ctx = pcall(function() return ns.ReadContext and ns.ReadContext() end)   -- read once for every rule (review R2)
    if okC and type(ctx) == "table" then ctx.sig = nil else ctx = nil end
    local mounted = MountedNow()
    for _, r in ipairs(ns.rules or {}) do
        local okP, p, why = pcall(A.Plan, r, ctx)
        if okP and p then
            lastWhy[r] = nil
            if p.mount == nil then want[r] = p
            else
                gated[r] = p   -- (SD-25) kept ready: OnMount adds / takes it back as the mount state changes
                if p.mount == mounted then want[r] = p end
            end
        elseif A.Settings(r) and A.Settings(r).enabled then lastWhy[r] = okP and why or ("something went wrong (" .. tostring(p):gsub("^.-:%d+: ", "") .. ")")
        else lastWhy[r] = nil end
    end
    for r, reg in pairs(registered) do
        if not want[r] or want[r].sig ~= reg.sig then Unregister(r) end
    end
    for r, p in pairs(want) do
        if not registered[r] then Register(r, p) end
    end
    MountWatch(next(gated) ~= nil)
    if not next(registered) and not Users() then Stop() end   -- the last rule unticked and the game's copies taken back: nothing left
    return true
end

-- (SD-25) The mount state changed, or a fight is about to start: bring the mount-following copies in line at once, no delay, so a
-- dismount straight into a pull is covered. Taking a copy back (RemoveAuraSound, no restriction flag) is done in combat too. Adding
-- one is not done in combat lockdown: PLAYER_REGEN_DISABLED comes before the lockdown (INFERENCE), so a dismount in the same moment
-- as the pull is added there; a dismount later in a fight that started mounted waits for the end of combat (`pending`), and until
-- then XayaUI plays the sound itself (A.Owns is false). Makes no table unless a copy is added.
local function OnMount()
    if ns.RulesDisabled then return end   -- (V26: nothing is handed to the game while rules are off)
    local m = MountedNow()
    if m == nil then A.Queue(); return end
    local locked = InCombatLockdown and InCombatLockdown()
    for r, p in pairs(gated) do
        if p.mount == m then
            if not registered[r] then
                if locked then pending = true else Register(r, p) end
            end
        elseif registered[r] then
            Unregister(r)
        end
    end
end
A.OnMount = OnMount

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
    if not A.Available() then return "|cffffd100Not available:|r this version of the game cannot play a sound on an aura by itself." end
    if ns.RulesDisabled then return "|cffffd100Not playing right now:|r every rule is off (/xui disable). Type /xui enable to turn them back on." end
    local r = registered[rule]
    local okNow, now = pcall(A.Plan, rule)
    local gate, mountNow   -- (SD-25) the mount state the copy is set to follow (nil = either), and the mount state now
    if okNow and now then gate = now.mount end
    if gate ~= nil then mountNow = MountedNow() end
    local offMount = gate ~= nil and not r and mountNow ~= nil and mountNow ~= gate
    if pending and (not r or not (okNow and now and now.sig == r.sig)) and not offMount then
        return "|cffffd100Waiting:|r the game takes changes only out of combat; this one is applied when combat ends" ..
            (r and " (until then the game keeps the previous setting)." or ". Until then XayaUI plays the sound itself.")
    end
    if offMount then   -- (SD-25) held back only while the mount state is not the one it is set to
        return ('|cffffd100Not playing right now|r because it is set to "%s". The game plays it again as soon as you %s.'):format(
            MountLabel(gate), gate and "mount" or "dismount")
    end
    if r then
        local p = okNow and now or nil
        local what = p and (A.WHEN_VALUES[p.when] or p.when):lower() or "?"
        -- (R2 follow-up) name the Load tab choices the game's copy does not follow, as the tab shows them (pane redraw only)
        local lr, names, extra = LoadRule(rule), {}, ""
        local ld = type(lr.load) == "table" and lr.load or nil
        pcall(DroppedOn, ld or NO_LOAD, names, lr)
        if #names > 0 then
            extra = " The game plays it on the aura alone, so " .. table.concat(names, ", ") ..
                ((#names > 1) and " do" or " does") .. " not apply to it" ..
                ((ld and ld.mode == "any") and ', and with "Match ANY" its other Load tab choices do not limit it either.' or ".")
        end
        if gate == true then   -- (SD-25)
            extra = extra .. (' It follows "%s", so the game stops playing it when you dismount.'):format(MountLabel(true))
        elseif gate == false then
            extra = extra .. (' It follows "%s", so the game stops playing it when you mount. If a fight starts while you are mounted' ..
                ' and you dismount during it, XayaUI plays it itself until that fight ends.'):format(MountLabel(false))
        end
        return ("|cff55ff55The game plays this sound|r %s (aura%s %s, channel %s).%s%s This is not yet confirmed in game, so check once that it plays."):format(
            what, (p and #p.ids > 1) and "s" or "", p and table.concat(p.ids, ", ") or "?", p and p.channel or "?",
            r.partial and (" The game refused some of the aura IDs (" .. r.partial .. ").") or "", extra)
    end
    if lastWhy[rule] then return "|cffffd100Not played by the game:|r " .. tostring(lastWhy[rule]) .. ". XayaUI plays the sound itself as before." end
    local okP, p, why = pcall(A.Plan, rule)
    if okP and p then return "|cffffd100Not set up yet|r (it is set up a moment after you change a setting)." end
    return "|cffffd100Not played by the game:|r " .. tostring(why or "unknown") .. ". XayaUI plays the sound itself as before."
end

-- When to resync: login, end of combat, spec / talent / gear / zone / group / Mythic+ / resting changes, and every rule edit (debounced; out of combat only).
-- Mount changes do not wait for this: OnMount (above) runs at once.
local queued = false
function A.Queue()
    if queued then return end
    queued = true
    local function Run() queued = false; pcall(A.Sync) end
    if C_Timer and C_Timer.After then C_Timer.After(0.5, Run) else Run() end
end

-- V14 (core 0.6.47; Xaya 2026-11-05: "anything that is disabled in the addon through a tick box should NEVER LOAD or contribute to
-- performance cost / demand in any way"). The switch is per rule ("Let the game play this sound on the aura itself", off by default).
-- While no rule ticks it and the game holds none of XayaUI's sounds: no frame, no event, no timer, no sync. The events below are
-- registered while at least one rule ticks it (or a registration still has to be taken back), and let go after the sync that takes
-- the last one back. What remains while off: on each rule edit (core's own EDITED message, which ns.MarkDirty sends), one pass over
-- the rules reading each rule's switch, to notice a tick (the switch is written by the settings window, which tells core only
-- through ns.MarkDirty). The old hook on ns.MarkDirty (a sync 0.5 s after every edit, every rule planned) is gone.
-- Game API (docs/reference/api/widgets.md, Frame): RegisterEvent(eventName) -> registered: bool; UnregisterAllEvents().
-- ZONE_CHANGED_NEW_AREA (events.md, MapUI): a rule's zone list follows you into a new zone without a loading screen (review R2).
-- (R2 follow-up) the Load tab choices the game's copy keeps: Instance (PLAYER_ENTERING_WORLD), Group / Raid group
-- (GROUP_ROSTER_UPDATE, PartyInfo), Mythic+ (CHALLENGE_MODE_START / CHALLENGE_MODE_COMPLETED, ChallengeModeInfo) and Resting area
-- (PLAYER_UPDATE_RESTING, Unit); events.md. (round 3) CHALLENGE_MODE_RESET (events.md 261: a key reset or abandoned while still
-- inside) brings "Not during a Mythic+" back without waiting for a loading screen.
-- (SD-25) PLAYER_MOUNT_DISPLAY_CHANGED (events.md 1201, Unit; no payload) and PLAYER_REGEN_DISABLED: registered only while a rule's
-- copy follows the mount state (MountWatch), and handled at once by OnMount, not through the 0.5 s queue.
local EVENTS = { "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "PLAYER_SPECIALIZATION_CHANGED", "TRAIT_CONFIG_UPDATED",
    "PLAYER_EQUIPMENT_CHANGED", "ZONE_CHANGED_NEW_AREA", "GROUP_ROSTER_UPDATE", "CHALLENGE_MODE_START", "CHALLENGE_MODE_COMPLETED",
    "CHALLENGE_MODE_RESET", "PLAYER_UPDATE_RESTING" }
local MOUNT_EVENTS = { "PLAYER_MOUNT_DISPLAY_CHANGED", "PLAYER_REGEN_DISABLED" }
local evf, live, mountOn = nil, false, false
local inGroup, inRaid   -- last seen: GROUP_ROSTER_UPDATE fires on every roster change, only joining / leaving / raid matters
-- does any rule tick the switch? (one field read per rule; no table is made)
Users = function()
    for _, r in ipairs(ns.rules or {}) do
        local g = r.gameSound
        if type(g) == "table" and g.enabled then return true end
    end
    return false
end
Start = function()
    if live or not CreateFrame then return end
    live = true
    if not evf then
        evf = CreateFrame("Frame")
        if evf.SetScript then
            evf:SetScript("OnEvent", function(_, event)
                if event == "PLAYER_MOUNT_DISPLAY_CHANGED" or event == "PLAYER_REGEN_DISABLED" then OnMount(); return end
                if event == "PLAYER_REGEN_ENABLED" and not pending then return end
                if event == "GROUP_ROSTER_UPDATE" then
                    local g, r = IsInGroup and IsInGroup(), IsInRaid and IsInRaid()
                    if not (issecret(g) or issecret(r)) then
                        if g == inGroup and r == inRaid then return end
                        inGroup, inRaid = g, r
                    end
                end
                A.Queue()
            end)
        end
    end
    for _, e in ipairs(EVENTS) do pcall(evf.RegisterEvent, evf, e) end
    if next(gated) then MountWatch(true) end
end
Stop = function()
    if not live then return end
    live, mountOn = false, false
    inGroup, inRaid = nil, nil   -- (round 3, R2 blocker) not seen while stopped: the next roster event after Start re-plans
    if evf and evf.UnregisterAllEvents then evf:UnregisterAllEvents() end
end
-- (SD-25) the two mount events, only while a rule's copy follows the mount state
MountWatch = function(on)
    if on and not live then Start() end   -- (Start calls back here)
    if not (evf and live) or on == mountOn then return end
    mountOn = on
    for _, e in ipairs(MOUNT_EVENTS) do
        if on then pcall(evf.RegisterEvent, evf, e) elseif evf.UnregisterEvent then pcall(evf.UnregisterEvent, evf, e) end
    end
end
function A.Live() return live end   -- (tests)
-- after a rule edit: a ticked switch starts it (and syncs, as every edit did); with none ticked, one more sync takes the game's
-- copies back if it still holds any, then it stops
local function OnEdited()
    if ns.RulesDisabled then return end   -- (V26: /xui enable sets it up again)
    if Users() then Start(); A.Queue()
    elseif live or next(registered) or pending then A.Queue() end
end
A.OnEdited = OnEdited
if ns.On then ns.On("EDITED", OnEdited) end
-- (V26) /xui disable (Xaya 2026-11-10: "/xui disable: all rules off"; Engine.lua ns.SetRulesDisabled fires RULES_DISABLED, in or out
-- of combat): every sound handed to the game is taken back at once. RemoveAuraSound carries no restriction flag
-- (docs/reference/api/namespaces.md: SecretArguments=AllowedWhenUntainted only), so this is done in combat too; nothing is handed to the
-- game again (A.Sync, OnMount and OnEdited do nothing) and the events are let go. /xui enable (RULES_ENABLED, never in combat) starts
-- it again if a rule ticks the switch, and the sync hands the sounds back to the game.
function A.TakeAllBack()
    for r in pairs(registered) do Unregister(r) end
    for r in pairs(gated) do gated[r] = nil end
    pending = false
    Stop()
end
if ns.On then
    ns.On("RULES_DISABLED", A.TakeAllBack)
    ns.On("RULES_ENABLED", function() if Users() then Start(); A.Queue() end end)
end
-- at login: start only if a rule ticks it (the first sync waits for PLAYER_ENTERING_WORLD, as before)
if ns.WhenRulesReady then ns.WhenRulesReady(function() if Users() then Start() end end) end   -- (P4: was ns.WhenReady, which now fires before this addon loads; RuleDefaults.lua)
A._registered = registered
