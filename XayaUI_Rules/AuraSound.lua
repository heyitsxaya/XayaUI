-------------------------------------------------------------------------------
-- AuraSound.lua : opt-in "the game plays this rule's sound when its aura is gained / lost" (decision D2, retrospective gap 21).
--
-- C_UnitAuras.AddAuraSound(trigger: UnitAuraSoundTrigger, sound: UnitAuraSoundInfo) -> auraSoundID: number?
--   flags HasRestrictions, SecretArguments=AllowedWhenUntainted (12.1.5 docs, docs/reference/api/namespaces.md:5310);
--   UnitAuraSoundTrigger: Added 0, ApplicationsIncreased 1, Removed 2;
--   UnitAuraSoundInfo: unitToken, spellID (required); soundFileName?, soundFileID?, outputChannel?, throttleSeconds?
-- C_UnitAuras.RemoveAuraSound(auraSoundID) undoes one (namespaces.md:5341: no restriction flag, so it is done in combat too, SD-25).
-- The game plays the sound itself, so it works while the aura is hidden from addons in combat. It gives addons no signal back
-- (AURA-PLAN D2). It plays on the aura alone: the game's copy can never repeat (Repeat) or wait for the rule's other triggers,
-- conditions or its ANY trigger mode (UnitAuraSoundInfo has no such field, structures.md:7686-7693).
--
-- (round 10, SD-96 "This function needs to work as intended and expected", V32) What the switch is for: the rule's own sound, heard
-- when the aura is gained / lost, also while the game hides the aura from addons in a fight. So the copy follows the rule's Load tab
-- EXACTLY (every choice, the groups' too, and the Talent List): the game holds it only while XayaUI's own load answer is yes.
--   * taken back the moment the answer turns no, in combat too (RemoveAuraSound has no restriction);
--   * added when it turns yes out of combat (the 0.5 s sync), and at the moments it turns yes in a fight: the start of a fight
--     (PLAYER_REGEN_DISABLED, which comes before the combat lockdown: INFERENCE, the SD-31 mount hold relies on the same) and a boss
--     pull (ENCOUNTER_START; ENCOUNTER_END for "Only outside boss encounters"), handled at once, not through the queue;
--   * any other change in a fight that turns the answer yes (joining a group mid-fight) is added when combat ends.
-- (SD-109, her answer "Nudge to Cooldown Manager") AddAuraSound carries "HasRestrictions" and what is restricted is not documented. The
-- build sees a refusal itself (the call errors or gives no ID). After the game refused one at the start of a fight (or at a boss pull
-- in the lockdown), the rules that need such an add keep the copy from before the fight instead, for the rest of this session: it plays
-- anyway and may play when the Load tab says no, never silent; the pane says so and tells her to add the buff to her Cooldown Manager.
-- What the game answered is kept for this session only (a /reload asks again). UNVERIFIED IN GAME: which of these the game refuses.
-- (SD-107, her answer "Switch automatically (Recommended)") A rule whose aura has a live icon in her Blizzard Cooldown Manager gets no
-- game copy: XayaUI plays the sound itself (Engine.lua: A.Owns is false), from the icon it reads in fights too (Conditions.lua FrameIDs,
-- FrameActive; Timing.lua's TriggerAlertEvent hook), so every Load choice, trigger, condition and Repeat is honored. Decided out of
-- combat at each sync and kept through a fight.
--
-- NOT CONFIRMED IN GAME (inference, to check with QA): that it plays for ordinary auras. Blizzard_Deprecated 12.1.0 maps the old
-- AddPrivateAuraAppliedSound onto it, and no Blizzard UI code calls it. Also unconfirmed: whether a /reload clears the game's
-- registrations (the QA step checks for a doubled sound).
-------------------------------------------------------------------------------
local _, ns = ...; ns = XayaUI_NS or ns -- (P4) XayaUI Rules shares the Platform's namespace (XayaUI/Core.lua)
local issecret = ns.IsSecret or issecretvalue or function() return false end

local A = {}
ns.AuraSound = A

local registered = {}   -- [rule] = { ids = { auraSoundID ... }, sig = text }
local lastWhy = setmetatable({}, { __mode = "k" })   -- [rule] = why it has no plan (for the settings pane)
local waiting = setmetatable({}, { __mode = "k" })   -- [rule] = true: its Load answer is yes but the copy could not be added in lockdown
local cdmOwn = setmetatable({}, { __mode = "k" })    -- [rule] = true: XayaUI plays it itself, its aura is in the Cooldown Manager (SD-107)
local plans = {}       -- [rule] = its plan at the last sync (every rule with one); emptied and filled again by each sync
local edgePlans = {}   -- [rule] = its plan, for the rules whose Load tab reads a choice that changes in a fight (combat, boss, mount)
local talentAns = {}   -- [rule] = its Talent List answer at the last sync (rules with a talent requirement only)
-- (SD-109) what the game answered this session when a copy was added at the start of a fight ("start") or in the combat lockdown at a
-- boss pull ("lock"): nil = not seen yet, true = taken, false = refused
local edge = { start = nil, lock = nil }
local pending = false   -- a change waits for the end of combat (an add in lockdown, or a refused one: the sync after combat redoes it)

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

local function LoadRule(rule)   -- an outcome loads exactly when its parent does (as ns.IsLoaded)
    return rule.parentUid and ns.FindParentRule and ns.FindParentRule(rule) or rule
end
-- The groups (folders) whose load lists apply to the rule: none while a group's Never / Always overrides them (as ns.CheckContext).
local function GroupLists(rule, key)
    if not ns.FolderById or (ns.FolderLoadOverride and ns.FolderLoadOverride(rule)) then return false end
    local fid, guard = rule.folder, 0
    while fid and guard < 32 do
        local f = ns.FolderById(fid)
        if not f then break end
        if type(f.loadIds) == "table" and ns.SetActive(f.loadIds[key]) then return true end
        fid, guard = f.parent, guard + 1
    end
    return false
end
-- Which choices of the rule's Load tab change during a fight. edge: any of them (combat, boss encounter, a Boss encounters list of the
-- rule or a group, mounted). needStart: the answer can turn yes as a fight starts ("Only in combat"; "Only when not mounted", SD-31).
-- needLock: it can turn yes at a boss pull or a boss kill, which may come in the lockdown (boss choice either way, a Boss encounters list).
local function FightReads(lr)
    local ld = type(lr.load) == "table" and lr.load or nil
    local edgeR, needStart, needLock, mount, boss, combat = false, false, false, false, false, false
    if ld and ld.mode ~= "always" and ld.mode ~= "never" then
        if not ns.Ignored(ld.combat) then edgeR, combat = true, true; if ld.combat == "yes" then needStart = true end end
        if not ns.Ignored(ld.encounter) then edgeR, needLock, boss = true, true, true end
        if ns.SetActive(ld.encounterIDs) then edgeR, needLock, boss = true, true, true end
        if not ns.Ignored(ld.mounted) then edgeR, mount = true, true; if ld.mounted == "no" then needStart = true end end
    end
    if GroupLists(lr, "encounterIDs") then edgeR, needLock, boss = true, true, true end
    return edgeR, needStart, needLock, mount, boss, combat
end
-- (round 10) Whether the rule could load at all here: its Load tab with the choices that change in a fight (combat, boss encounter and
-- the Boss encounters lists) left open. Only whether a plan exists comes from this view; whether the game holds the copy now is the full
-- check (Want, below). A Match ANY rule with such a choice counts as possibly loaded.
local FIGHT = { combat = true, encounter = true }
local function FightOn(load)
    if load.mode == "always" or load.mode == "never" or not ns.LOAD_TRI then return false end
    for k in pairs(FIGHT) do if not ns.Ignored(load[k]) then return true end end
    return ns.SetActive(load.encounterIDs) and true or false
end
local ANY_OPEN = { mode = "any" }   -- (read only) a Match ANY rule with a fight choice: its own choices pass
local function LoadView(load)   -- the rule's load table without those choices (a copy; made only on a sync or a pane redraw)
    if load.mode == "any" and FightOn(load) then return ANY_OPEN end
    local copy = {}
    for k, v in pairs(load) do copy[k] = v end
    for k in pairs(FIGHT) do copy[k] = nil end
    copy.encounterIDs = nil
    return copy
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
        ok, fine, why = pcall(ns.CheckContext, view, ctx, true)   -- (static: the Boss encounters lists of the rule and its groups are left open)
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
    local edgeR, needStart, needLock, rm, rb, rc = FightReads(LoadRule(rule))
    -- (SD-107) the moment XayaUI's own sound plays is the rule's own trigger (gained for "present", lost for "missing"); the game's copy
    -- may be set to another moment ("When it gains a stack"), which XayaUI cannot play itself: such a copy stays with the game
    local own = (when == "added" and ar.buffState ~= "missing") or (when == "removed" and ar.buffState == "missing")
    return { ids = ids, when = when, name = name, fid = fid, channel = ch, throttle = thr, mount = gate, edge = edgeR,
        needStart = needStart, needLock = needLock, readsMount = rm, readsBoss = rb, readsCombat = rc, ownMoment = own,
        sig = table.concat(ids, ",") .. "|" .. when .. "|" .. tostring(name or fid) .. "|" .. ch .. "|" .. thr }
end

-- (SD-109) Does the rule keep its copy from before the fight? Only after the game refused an add at the moment the rule needs one.
local function Fallback(p)
    return (p.needStart and edge.start == false) or (p.needLock and edge.lock == false) or false
end
local inFight = false   -- (SD-31) from PLAYER_REGEN_DISABLED to PLAYER_REGEN_ENABLED, seen while the fight events are listened to
-- (round 10, SD-96) XayaUI's own load answer for the copy now: core's full check (ns.CheckContext, not the static view) with the context
-- given. (SD-31) An "Only when not mounted" copy is held for the whole fight, mounted or not. (SD-109) A rule kept from before the fight
-- reads its fight choices as met (and its Boss encounters lists as open). The context is changed only for the call and put back.
local function Want(r, p, ctx)
    if not ctx then return not p.edge end
    if not p.edge then return true end   -- (every choice it reads was checked by the plan, with this same context)
    local lr = LoadRule(r)
    local ld = type(lr.load) == "table" and lr.load or nil
    local c0, e0, m0, id0 = ctx.combat, ctx.encounter, ctx.mounted, ctx.encounterID
    local static = false
    if ld then
        if inFight and ld.mounted == "no" then ctx.mounted = false end
        if p.needStart and edge.start == false then
            if ld.combat == "yes" then ctx.combat = true end
            if ld.mounted == "no" then ctx.mounted = false end
        end
        if p.needLock and edge.lock == false then
            if ld.encounter == "yes" then ctx.encounter = true elseif ld.encounter == "no" then ctx.encounter = false end
            static = true
        end
    elseif p.needLock and edge.lock == false then static = true end
    local ok, fine = pcall(ns.CheckContext, lr, ctx, static)
    ctx.combat, ctx.encounter, ctx.mounted, ctx.encounterID = c0, e0, m0, id0
    return ok and fine == true
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

local Start, Stop, Users, Watch   -- (below: the feature's events, V14)
local keptCtx   -- the load context the last sync read; the fight events change only the facts their event says

-- Hand one plan to the game. Returns true when the game took at least one of its aura IDs. The info tables are made once per plan and
-- kept on it, so an add at a fight start makes only the small list of IDs. (SD-109) A refusal (an error, or no ID back) is reported.
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
    return #got > 0
end

local NO_LOAD = {}   -- (read only) a rule with no Load tab table, for the pane
local function TriLabel(key, yes)   -- the Load tab's own words for a Yes / No choice
    for _, c in ipairs(ns.LOAD_TRI or NO_LOAD) do
        if c.key == key then return yes and c.yes or c.no end
    end
    return key
end
local function MountLabel(gate) return TriLabel("mounted", gate) end
-- The mount state now: true / false, or nil when the game does not say (IsMounted, globals.md: no secrecy flag; checked anyway).
local function MountedNow()
    local ok, m = pcall(IsMounted)
    if not ok or m == nil or issecret(m) then return nil end
    return m and true or false
end
local function ReadCtx() return ns.ReadContext and ns.ReadContext() end
local function InFightNow()
    if inFight or (InCombatLockdown and InCombatLockdown()) then return true end
    local ok, c = pcall(UnitAffectingCombat, "player")
    return ok and c == true
end
-- (SD-107) Has every aura ID of the plan a live icon in her Cooldown Manager (Conditions.lua: only visible viewers are indexed, and an
-- icon is filed under the IDs it showed while readable, or under its cooldownID's spells)? Then XayaUI's own sound can hear it in a fight.
local function CDMLive(p)
    if not (ns.FindCDMFrame and p.ownMoment) then return false end
    for _, id in ipairs(p.ids) do
        local ok, fr = pcall(ns.FindCDMFrame, id)
        if not (ok and fr) then return false end
    end
    return true
end
-- Does a zone list (the rule's own or a group's) decide this rule? Then the sub-zone events are listened to (ZONE_CHANGED fires often).
local function ZoneListed(r)
    local lr = LoadRule(r)
    local ld = type(lr.load) == "table" and lr.load or nil
    if ld and ld.mode ~= "always" and ld.mode ~= "never" and ns.SetActive(ld.mapIDs) then return true end
    return GroupLists(lr, "mapIDs")
end

-- Bring the game's registrations in line with the rules. A copy is taken back at once, in combat too; one is added only out of the
-- combat lockdown (in the lockdown it waits for the end of combat). The Cooldown Manager choice (SD-107) is made out of combat only.
local wantNow = {}   -- (reused) [rule] = true: the game should hold its copy now
function A.Sync()
    if not A.Available() then return false, "this version of the game cannot do this" end
    if ns.RulesDisabled then A.TakeAllBack(); return false, "every rule is off (/xui disable)" end   -- (V26)
    local locked = InCombatLockdown and InCombatLockdown()
    local fight = InFightNow()
    if locked and (next(registered) or Users()) then Start() end   -- (the end of combat applies what waits: PLAYER_REGEN_ENABLED)
    pending = false
    for r in pairs(plans) do plans[r] = nil end
    for r in pairs(edgePlans) do edgePlans[r] = nil end
    for r in pairs(wantNow) do wantNow[r] = nil end
    for r in pairs(talentAns) do talentAns[r] = nil end
    local okC, ctx = pcall(ReadCtx)   -- read once for every rule (review R2)
    if okC and type(ctx) == "table" then ctx.sig = nil else ctx = nil end
    if ctx and inFight then ctx.combat = true end
    keptCtx = ctx
    local zone, wFight, wMount, wBoss = false, false, false, false
    for _, r in ipairs(ns.rules or {}) do
        local g = A.Settings(r)
        if g and g.enabled then
            if not zone and ZoneListed(r) then zone = true end
            local lr = LoadRule(r)
            if ns.HasTalentRequirement and ns.HasTalentRequirement(lr) then
                local okT, t = pcall(ns.CheckTalents, lr)
                talentAns[r] = okT and t or "?"
            end
            local okP, p, why = pcall(A.Plan, r, ctx)
            if okP and p then
                lastWhy[r] = nil
                plans[r] = p
                if not fight then cdmOwn[r] = CDMLive(p) or nil end
                if p.edge then
                    edgePlans[r] = p
                    wFight = true
                    if p.readsMount then wMount = true end
                    if p.readsBoss then wBoss = true end
                end
                if not cdmOwn[r] and Want(r, p, ctx) then wantNow[r] = true end
            else
                lastWhy[r] = okP and why or ("something went wrong (" .. tostring(p):gsub("^.-:%d+: ", "") .. ")")
                if not fight then cdmOwn[r] = nil end
            end
        else
            lastWhy[r] = nil
            if not fight then cdmOwn[r] = nil end
        end
    end
    for r, reg in pairs(registered) do
        local p = plans[r]
        if not wantNow[r] then Unregister(r)   -- the answer is no now (or no plan): taken back at once, in combat too
        elseif p.sig ~= reg.sig then
            if locked then waiting[r] = true; pending = true else Unregister(r) end   -- (in the lockdown the old copy plays until it can be replaced)
        end
    end
    for r in pairs(waiting) do if not wantNow[r] then waiting[r] = nil end end
    for r in pairs(wantNow) do
        if not registered[r] then
            if locked then waiting[r] = true; pending = true
            elseif Register(r, plans[r]) then waiting[r] = nil end
        elseif not locked then waiting[r] = nil end
    end
    Watch(wFight, wMount, wBoss, zone, next(talentAns) ~= nil)
    if not next(registered) and not Users() then Stop() end   -- the last rule unticked and the game's copies taken back: nothing left
    return true
end

-- (round 10, SD-96) A fight or mount moment: bring the copies whose Load tab reads combat, a boss encounter or the mount state in line
-- at once, no delay. Bounded: one pass over those rules only, on these events. Makes no table unless a copy is added.
--   PLAYER_REGEN_DISABLED: combat starts (before the lockdown, INFERENCE); a boss encounter already in progress counts
--     (C_InstanceEncounter.IsEncounterInProgress, namespaces.md:2667, no secrecy flag; through ns.Compat.InEncounter).
--   ENCOUNTER_START / ENCOUNTER_END (events.md:560-562): the boss and its ID from the event itself (core's own handler of the same event
--     may run after this one).
--   PLAYER_MOUNT_DISPLAY_CHANGED (events.md 1201, no payload) and the end of the fight (PLAYER_REGEN_ENABLED, after the lockdown).
-- Adds: out of the lockdown, always; in the lockdown, only at a boss pull or kill, and not after the game refused one (SD-109); a mount
-- change in the lockdown waits for the end of combat, as before. (SD-31, Xaya: "A: never miss it") an "Only when not mounted" copy is
-- added as each fight starts, even while mounted, and kept for the whole fight.
-- the boss encounter now, from the game (at the start and the end of a fight: an ENCOUNTER_START or _END may not have been seen)
local function ReadEncounter(ctx)
    local C = ns.Compat
    local okE, e = false, nil
    if C and C.InEncounter then okE, e = pcall(C.InEncounter) end
    if not okE or e == nil or issecret(e) then return end
    ctx.encounter = e and true or false
    if e then
        local last = ns.LastEncounter and ns.LastEncounter()   -- (Conditions.lua: the boss of the last ENCOUNTER_START)
        ctx.encounterID = (type(last) == "table" and type(last.id) == "number") and last.id or nil
    else
        ctx.encounterID = 0
    end
end
local function OnEdge(event, a1)
    if ns.RulesDisabled then return end   -- (V26: nothing is handed to the game while rules are off)
    if event == "PLAYER_REGEN_DISABLED" then inFight = true elseif event == "PLAYER_REGEN_ENABLED" then inFight = false end
    if not next(edgePlans) then return end
    local ctx = keptCtx
    if not ctx then A.Queue(); return end
    if event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
        local m = MountedNow()
        if m == nil then A.Queue(); return end   -- (mount state unknown: left as it is; the sync re-plans)
        ctx.mounted = m
    elseif event == "PLAYER_REGEN_DISABLED" then
        ctx.combat = true
        ReadEncounter(ctx)
    elseif event == "PLAYER_REGEN_ENABLED" then
        ctx.combat = false
        ReadEncounter(ctx)
    elseif event == "ENCOUNTER_START" then
        ctx.encounter = true
        ctx.encounterID = (type(a1) == "number" and not issecret(a1)) and a1 or nil
    elseif event == "ENCOUNTER_END" then
        ctx.encounter, ctx.encounterID = false, 0
    end
    local locked = InCombatLockdown and InCombatLockdown()
    local boss = event == "ENCOUNTER_START" or event == "ENCOUNTER_END"
    local kind = (event == "PLAYER_REGEN_DISABLED" and not locked and "start") or (locked and boss and "lock") or nil
    local took, refused = 0, 0
    local mountEv = event == "PLAYER_MOUNT_DISPLAY_CHANGED"
    for r, p in pairs(edgePlans) do
        -- only the rules whose answer this moment can change: a mount change the mount rules, a boss pull or kill the boss rules
        if not cdmOwn[r] and ((mountEv and p.readsMount) or (boss and p.readsBoss) or not (mountEv or boss)) then
            if Want(r, p, ctx) then
                if not registered[r] then
                    if (locked and kind ~= "lock") or (kind == "lock" and edge.lock == false) then waiting[r] = true; pending = true
                    elseif Register(r, p) then took = took + 1; waiting[r] = nil
                    else refused = refused + 1; waiting[r] = true; pending = true end
                end
            else
                if registered[r] then Unregister(r) end
                waiting[r] = nil
            end
        end
    end
    -- (SD-109) the game's answer at this moment: any copy taken means it takes them here; only refusals means it does not
    if kind and (took > 0 or refused > 0) then edge[kind] = took > 0 end
end
A.OnEdge = OnEdge
A.OnMount = OnEdge   -- (the round 3 name)

-- The game plays this rule's sound now, and the rule asked XayaUI not to play it as well (Engine.lua skips its own copy).
function A.Owns(rule)
    local r = registered[rule]
    if not r then return false end
    local g = A.Settings(rule)
    return not (g and g.alsoXayaUI)
end
-- (SD-107) XayaUI plays this rule's sound itself because its aura is in the Cooldown Manager (no game copy).
function A.PlayedByXayaUI(rule) return cdmOwn[rule] == true end

-- (round 4 review blocker) What XayaUI itself does when the game does not play the sound, said only where it is true for the reason.
-- XayaUI plays its own copy when the rule fires and it can see the aura (Engine.lua: A.Owns is false while the game holds no copy), so
-- the line says so only when the rule itself is set to play: the game refused the copy, or the sound is one the game cannot take (a
-- [Game] sound kit, speech). For a rule or sound switched off, or a rule that does not load here, XayaUI plays nothing either. Any
-- other reason (no aura ID, no sound picked or found, something went wrong, a check that cannot be made now) gets no promise.
local ALSO_XAYAUI = " XayaUI plays the sound itself instead, but only when it can see the aura, and many auras are hidden from addons in combat."
local NOR_XAYAUI = " XayaUI does not play it either."
local function NotPlayedLine(why)
    why = tostring(why or "unknown")
    local tail = ""
    if why:find("^the game refused it") or why:find("sound kit cannot be handed", 1, true) or why:find("^speech cannot") then
        tail = ALSO_XAYAUI
    elseif why == "the rule is switched off" or why == "the rule it belongs to is switched off" or why == "the rule's sound is switched off"
        or why:find("^it is not set to load here") or why:find("^it is not for this character") or why:find("Never load", 1, true)
        or why:find("^none of its Load tab choices") or why == "its Load tab does not match this character here" then
        tail = NOR_XAYAUI
    elseif why == "the rule has no Buff / Aura trigger" then
        tail = " The game can play a sound only on an aura named in a Buff / Aura trigger."
    end
    return "|cffffd100Not played by the game:|r " .. why .. "." .. tail
end
A._NotPlayedLine = NotPlayedLine   -- (tests)

-- (round 10, SD-96 / SD-109) Pane text. What the game's copy can never do, said plainly (it plays on the aura alone).
local LIMITS = " The game plays it on the aura alone, so it can never repeat it (Repeat) or wait for the rule's other triggers," ..
    " conditions or ANY trigger mode."
local NUDGE = " Add this buff to your Cooldown Manager to make the sound exact."
-- (SD-109) the rule keeps its copy from before the fight: why, and what she can do
local function FallbackLine(p)
    local where = (p.needStart and edge.start == false) and "when a fight started" or "at a boss pull"
    return (" The game would not take this sound %s, so XayaUI keeps it set up from before the fight. It plays anyway, and it may" ..
        " also play when your Load tab says no.%s"):format(where, NUDGE)
end
-- (SD-107) XayaUI plays it itself: why, and the two known differences from the game's copy (verified in the stand-in game, not in WoW)
local CDM_LINE = "|cff55ff55XayaUI plays this sound itself|r, because this buff is in your Cooldown Manager. It follows every setting" ..
    " of this rule, in fights too, while the buff's icon is there. Two small differences from the game's copy. If the buff is already up" ..
    " (or already gone) when a fight starts, a rule that loads only in combat plays once as the fight starts. A buff lost and gained" ..
    " again in the same instant makes no sound. Not yet confirmed in boss fights and Mythic+."
-- Why the game does not hold the copy right now (its Load answer is no), in the Load tab's words, and when it gets it back.
local function NotNowLine(rule, p)
    local lr = LoadRule(rule)
    local ld = type(lr.load) == "table" and lr.load or nil
    local okC, ctx = pcall(ReadCtx)
    local why = ""
    if okC and type(ctx) == "table" then
        ctx.sig = nil
        if inFight and ld and ld.mounted == "no" then ctx.mounted = false end
        local ok, fine, w = pcall(ns.CheckContext, lr, ctx)
        if ok and fine ~= true and w then why = Plain(tostring(w), ld) end
    end
    if why == "" then why = "its Load tab choices are not met here" end
    local back = " The game is given it again as soon as they are met."
    if ld and ld.combat == "yes" then back = " The game is given it as each fight starts."
    elseif p.needLock then back = " The game is given it when a boss fight it is set for starts." end
    return "|cffffd100Not playing right now|r because " .. why .. "." .. back
end

-- One line for the settings pane.
function A.StatusLine(rule)
    local g = A.Settings(rule)
    if not (g and g.enabled) then return "" end
    if not A.Available() then return "|cffffd100Not available:|r this version of the game cannot play a sound on an aura by itself." end
    if ns.RulesDisabled then return "|cffffd100Not playing right now:|r every rule is off (/xui disable). Type /xui enable to turn them back on." end
    if cdmOwn[rule] then return CDM_LINE end
    local r = registered[rule]
    local okNow, now, nowWhy = pcall(A.Plan, rule)
    local p = okNow and now or nil
    local gate, mountNow   -- (SD-25) the mount state the copy is set to follow (nil = either), and the mount state now
    if p then gate = p.mount end
    if gate ~= nil then mountNow = MountedNow() end
    local offMount = gate ~= nil and not r and mountNow ~= nil and mountNow ~= gate and not inFight
    if waiting[rule] and (not r or not (p and p.sig == r.sig)) and not offMount then
        if p and Fallback(p) then return "|cffffd100Waiting|r for the end of combat." .. FallbackLine(p) end
        return "|cffffd100Waiting:|r the game takes changes only out of combat; this one is applied when combat ends" ..
            (r and " (until then the game keeps the previous setting)." or (". Until then XayaUI plays the sound itself only" ..
            " if it can see the aura, and many auras are hidden from addons in combat."))
    end
    if offMount then   -- (SD-25) held back only while the mount state is not the one it is set to
        return ('|cffffd100Not playing right now|r because it is set to "%s". The game plays it again as soon as you %s.%s'):format(
            MountLabel(gate), gate and "mount" or "dismount", gate and "" or   -- (SD-31)
            " It is also set up as each fight starts, so it still plays if you are knocked off your mount during the fight.")
    end
    if r then
        local what = p and (A.WHEN_VALUES[p.when] or p.when):lower() or "?"
        local fb = p and Fallback(p)
        local extra = fb and "" or " It is held only while the rule's Load tab choices are met, and taken back the moment they stop being met."
        if p and (p.readsCombat or p.readsBoss) and not fb then
            extra = extra .. " Choices that change in a fight are followed as the fight or the boss fight starts and ends."
        end
        if gate == true then   -- (SD-25)
            extra = extra .. (' It follows "%s", so the game stops playing it when you dismount.'):format(MountLabel(true))
        elseif gate == false then
            extra = extra .. (' It follows "%s", so the game stops playing it when you mount. It is also set up as each fight' ..   -- (SD-31)
                ' starts, even while you are mounted, so it still plays if you are knocked off your mount during the fight; until' ..
                ' that fight ends it may also play while you are still mounted.'):format(MountLabel(false))
        end
        if fb then extra = extra .. FallbackLine(p) end
        return ("|cff55ff55The game plays this sound|r %s (aura%s %s, channel %s).%s%s%s This is not yet confirmed in game, so check once that it plays."):format(
            what, (p and #p.ids > 1) and "s" or "", p and table.concat(p.ids, ", ") or "?", p and p.channel or "?",
            r.partial and (" The game refused some of the aura IDs (" .. r.partial .. ").") or "", extra, LIMITS)
    end
    if lastWhy[rule] then return NotPlayedLine(lastWhy[rule]) end
    if p then
        if p.edge and keptCtx and not Want(rule, p, keptCtx) then return NotNowLine(rule, p) end
        return "|cffffd100Not set up yet|r (it is set up a moment after you change a setting)."
    end
    return NotPlayedLine(okNow and nowWhy or ("something went wrong (" .. tostring(now):gsub("^.-:%d+: ", "") .. ")"))
end

-- When to resync: login, end of combat (when something waits), spec / talent / gear / zone / group / Mythic+ / resting / difficulty
-- changes, and every rule edit (debounced; one timer at most). Fight and mount moments do not wait for this: OnEdge (above) runs at once.
-- (SD-82 / SD-90) one function made once, not a new one per call. (round 10) A talent event that may not have changed anything asks for
-- a light check only: the Talent List answers of the rules that have one, compared with the last sync's; a full sync only if one moved.
local queued, queuedFull = false, false
local function TalentsMoved()
    for r, was in pairs(talentAns) do
        local okT, t = pcall(ns.CheckTalents, LoadRule(r))
        if (okT and t or "?") ~= was then return true end
    end
    return false
end
local function RunQueued()
    local full = queuedFull
    queued, queuedFull = false, false
    if full or TalentsMoved() then pcall(A.Sync) end
end
function A.Queue(light)
    if not light then queuedFull = true end
    if queued then return end
    queued = true
    if C_Timer and C_Timer.After then C_Timer.After(0.5, RunQueued) else RunQueued() end
end
-- (SD-107) the end of a fight: did an icon of her Cooldown Manager come or go for a rule? (no table made; a full sync only then)
local function CDMMoved()
    for r, p in pairs(plans) do
        if (CDMLive(p) or nil) ~= cdmOwn[r] then return true end
    end
    return false
end

-- V14 (core 0.6.47; Xaya 2026-11-05: "anything that is disabled in the addon through a tick box should NEVER LOAD or contribute to
-- performance cost / demand in any way"). The switch is per rule ("Let the game play this sound on the aura itself", off by default).
-- While no rule ticks it and the game holds none of XayaUI's sounds: no frame, no event, no timer, no sync. The events below are
-- registered while at least one rule ticks it (or a registration still has to be taken back), and let go after the sync that takes
-- the last one back. What remains while off: on each rule edit (core's own EDITED message, which ns.MarkDirty sends), one pass over
-- the rules reading each rule's switch, to notice a tick.
-- Game API (docs/reference/api/widgets.md, Frame): RegisterEvent(eventName) -> registered: bool; UnregisterEvent; UnregisterAllEvents().
-- The Load tab facts (events.md): Instance (PLAYER_ENTERING_WORLD), Group / Raid group (GROUP_ROSTER_UPDATE), Mythic+
-- (CHALLENGE_MODE_START / _COMPLETED / _RESET :261), Resting area (PLAYER_UPDATE_RESTING), a zone without a loading screen
-- (ZONE_CHANGED_NEW_AREA; round 10: ZONE_CHANGED / ZONE_CHANGED_INDOORS :1786-1787 too, only while a rule has a zone list), the
-- difficulty (PLAYER_DIFFICULTY_CHANGED :1170), gear (PLAYER_EQUIPMENT_CHANGED). (round 10) Talents: the same events the rules engine
-- listens to (Engine.lua TALENT_EVENTS / TALENT_MAYBE): the spec, the hero talents and a loading screen re-plan; the others compare the
-- Talent List answers first (TalentsMoved).
local EVENTS = { "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "PLAYER_SPECIALIZATION_CHANGED", "TRAIT_CONFIG_UPDATED",
    "PLAYER_EQUIPMENT_CHANGED", "ZONE_CHANGED_NEW_AREA", "GROUP_ROSTER_UPDATE", "CHALLENGE_MODE_START", "CHALLENGE_MODE_COMPLETED",
    "CHALLENGE_MODE_RESET", "PLAYER_UPDATE_RESTING", "PLAYER_DIFFICULTY_CHANGED",
    "ACTIVE_PLAYER_SPECIALIZATION_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED", "TRAIT_SUB_TREE_CHANGED", "SPEC_INVOLUNTARILY_CHANGED" }
-- (only while a ticked rule has a Talent List: they can change only that answer)
local TALENT_LIST = { "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_LIST_UPDATED", "ACTIVE_COMBAT_CONFIG_CHANGED", "PLAYER_PVP_TALENT_UPDATE",
    "WAR_MODE_STATUS_UPDATE", "TALENTS_INVOLUNTARILY_RESET", "SPELLS_CHANGED", "TRAIT_NODE_CHANGED", "TRAIT_NODE_CHANGED_PARTIAL",
    "TRAIT_NODE_ENTRY_UPDATED", "TRAIT_TREE_CHANGED", "TRAIT_CONFIG_CREATED", "TRAIT_CONFIG_DELETED", "SELECTED_LOADOUT_CHANGED",
    "CONFIG_COMMIT_FAILED", "LEARNED_SPELL_IN_SKILL_LINE", "PLAYER_LEVEL_UP", "TRAIT_COND_INFO_CHANGED", "CHARACTER_POINTS_CHANGED",
    "PLAYER_LEARN_TALENT_FAILED", "PLAYER_LEARN_PVP_TALENT_FAILED", "SPECIALIZATION_CHANGE_CAST_FAILED", "STARTER_BUILD_ACTIVATION_FAILED",
    "PVP_MATCH_ACTIVE", "PVP_MATCH_INACTIVE", "PLAYER_JOINED_PVP_MATCH" }
local TALENT_LIGHT = {}
for _, e in ipairs(TALENT_LIST) do TALENT_LIGHT[e] = true end
A._EVENTS, A._TALENT_LIGHT = EVENTS, TALENT_LIGHT   -- (tests: compared with the engine's talent events)
local ZONE_EVENTS = { "ZONE_CHANGED", "ZONE_CHANGED_INDOORS" }
local FIGHT_EVENTS, MOUNT_EVENTS, BOSS_EVENTS = { "PLAYER_REGEN_DISABLED" }, { "PLAYER_MOUNT_DISPLAY_CHANGED" }, { "ENCOUNTER_START", "ENCOUNTER_END" }
local evf, live = nil, false
local on = { fight = false, mount = false, boss = false, zone = false, talent = false }
local inGroup, inRaid   -- last seen: GROUP_ROSTER_UPDATE fires on every roster change, only joining / leaving / raid matters
local lastMap           -- last seen map: a sub-zone crossing on the same map changes no zone answer
-- does any rule tick the switch? (one field read per rule; no table is made)
Users = function()
    for _, r in ipairs(ns.rules or {}) do
        local g = r.gameSound
        if type(g) == "table" and g.enabled then return true end
    end
    return false
end
local function MapNow()
    if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
    local ok, m = pcall(C_Map.GetBestMapForUnit, "player")
    if ok and type(m) == "number" and not issecret(m) then return m end
    return nil
end
local function OnEvent(_, event, unit)
    -- (RB-30) PLAYER_SPECIALIZATION_CHANGED (unitTarget: UnitTokenVariant; events.md 1215, no secret flag) also fires for other units:
    -- only the player's own spec change re-plans (Start registers it for "player" only where the game can)
    if event == "PLAYER_SPECIALIZATION_CHANGED" and unit ~= "player" then return end
    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_MOUNT_DISPLAY_CHANGED" or event == "ENCOUNTER_START"
        or event == "ENCOUNTER_END" then OnEdge(event, unit); return end
    if event == "PLAYER_REGEN_ENABLED" then
        if on.fight then OnEdge(event) end   -- the fight is over: every fight copy back to the load answer now
        if pending then A.Queue() elseif CDMMoved() then A.Queue() end
        return
    end
    if TALENT_LIGHT[event] then A.Queue(true); return end
    if event == "GROUP_ROSTER_UPDATE" then
        local g, r = IsInGroup and IsInGroup(), IsInRaid and IsInRaid()
        if not (issecret(g) or issecret(r)) then
            if g == inGroup and r == inRaid then return end
            inGroup, inRaid = g, r
        end
    elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" or event == "ZONE_CHANGED_NEW_AREA" then
        local m = MapNow()
        if m ~= nil and m == lastMap then return end
        lastMap = m
    end
    A.Queue()
end
Start = function()
    if live or not CreateFrame then return end
    live = true
    if not evf then
        evf = CreateFrame("Frame")
        if evf.SetScript then evf:SetScript("OnEvent", OnEvent) end
    end
    lastMap = MapNow()
    for _, e in ipairs(EVENTS) do
        -- (RB-30) the spec event for the player only: RegisterUnitEvent (widgets.md 239, SecretArguments=AllowedWhenUntainted)
        if e == "PLAYER_SPECIALIZATION_CHANGED" and evf.RegisterUnitEvent then pcall(evf.RegisterUnitEvent, evf, e, "player")
        else pcall(evf.RegisterEvent, evf, e) end
    end
end
Stop = function()
    if not live then return end
    live, inFight = false, false
    on.fight, on.mount, on.boss, on.zone, on.talent = false, false, false, false, false
    inGroup, inRaid, lastMap = nil, nil, nil   -- (round 3, R2 blocker) not seen while stopped: the next roster event after Start re-plans
    if evf and evf.UnregisterAllEvents then evf:UnregisterAllEvents() end
end
local function Toggle(key, want, list)
    want = want and true or false
    if want == on[key] then return end
    on[key] = want
    for _, e in ipairs(list) do
        if want then pcall(evf.RegisterEvent, evf, e) elseif evf.UnregisterEvent then pcall(evf.UnregisterEvent, evf, e) end
    end
end
-- the fight, mount, boss, sub-zone and talent-tree events, each only while a rule needs it
Watch = function(fight, mount, boss, zone, talent)
    if (fight or mount or boss or zone or talent) and not live then Start() end
    if not (evf and live) then return end
    Toggle("fight", fight, FIGHT_EVENTS)
    Toggle("mount", mount, MOUNT_EVENTS)
    Toggle("boss", boss, BOSS_EVENTS)
    Toggle("zone", zone, ZONE_EVENTS)
    Toggle("talent", talent, TALENT_LIST)
    if not fight then inFight = false end
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
-- game again (A.Sync, OnEdge and OnEdited do nothing) and the events are let go. /xui enable (RULES_ENABLED, never in combat) starts
-- it again if a rule ticks the switch, and the sync hands the sounds back to the game.
function A.TakeAllBack()
    for r in pairs(registered) do Unregister(r) end
    for r in pairs(plans) do plans[r] = nil end
    for r in pairs(edgePlans) do edgePlans[r] = nil end
    for r in pairs(waiting) do waiting[r] = nil end
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
A._edge = edge   -- (tests: what the game answered this session)
