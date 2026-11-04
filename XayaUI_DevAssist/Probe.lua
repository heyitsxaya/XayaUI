-------------------------------------------------------------------------------
-- XayaUI_DevAssist ("XayaUI Dev Assist", formerly XayaUI_GameDump): Probe.lua (0.6.0). `/xuidev probe`: an event recorder that answers open questions about what the game lets an
-- addon read in 12.1.5 ("Midnight"), so XayaUI's instance mapper (ROADMAP RM-INST) and proc-glow triggers (task 28) are built on
-- observed behaviour, not guesses. Written 2026-11-04. UNTESTED IN GAME: tests/gamedump_probe_run.py drives it with stand-in game
-- functions only. Run sheet: docs/process/IN-GAME-DATA-2026-11-05.md.
--
-- Commands: /xuidev probe on | off | status | clear | spells <id> <id> ... | mark
-- Output: XayaUIDevAssistDB.probe (WTF\Account\<account>\SavedVariables\XayaUI_DevAssist.lua, written on /reload or logout):
--   .log[seq]      ring buffer: the newest CAP entries (.first .. .last; .dropped counts what fell out). Each entry: t = GetTime()
--                  (3 decimals), e = event code (.legend lists them), u = unit token, c = in combat, then the event's fields.
--   .anchors[seq]  clock anchors (GetTime, time(), GetServerTime, date, instance, context flags) at `on`, ENCOUNTER_START, zone
--                  changes and `off`, so entries line up with WoWCombatLog.txt (local wall-clock times). Kept apart from .log.
--   .stats         readability tallies per field, never dropped: r / s / n / e / m = readable / secret / nil / the call raised /
--                  the function is missing, then o / c = out of / in combat (stats["cast.id"].sc = enemy cast IDs secret in combat).
--   .secrecy[id]   C_Secrets cast and aura secrecy of the spell list, XayaUI's rule spells and the IDs added with `spells`.
--   .watchPairs    ShouldSpellAuraBeSecret / GetPlayerAuraBySpellID result pairs for the watched spells (counts).
--   .marks         `mark` results. .errors: handler failures (counted, recorded once per kind). .callErrors: game calls that raised.
-- Rules: nothing is registered until `on`; the setting survives /reload (the probe resumes and says so in chat). Event handlers and
-- one-shot C_Timer.After only, no OnUpdate. Every game value goes through issecretvalue (pcall-wrapped) BEFORE anything else touches
-- it, nil and boolean tests included; a secret is stored as the string "secret" and never compared, counted, joined or formatted.
-- Every handler runs in pcall. No character name, realm or other player's GUID is stored (see Identity, Who and Scrub).
-- API facts quoted below are from docs/reference/api/ (Blizzard's generated documentation 12.1.5.70688, live client 12.1.5.70783).
-------------------------------------------------------------------------------
local ADDON = ...
local GD = _G.XayaUIDevAssist
if not GD then return end

local VERSION = "0.6.0"
local CAP = 6000              -- ring buffer entries kept (oldest dropped and counted)
local ANCHOR_CAP = 400        -- anchors kept
local MARK_CAP = 50
local WATCH_CAP = 40          -- spell IDs read on every UNIT_AURA for the player (cost bound)
local MERGE_WINDOW = 2        -- seconds: payload-less or very frequent events merge into one entry (n = how many, tl = last time)
local PAIR_DELAY = 0.1        -- seconds after a glow before the paired aura is read
local SECRET, MISSING, ERR = "secret", "<missing>", "<error>"

-- the built-in spell list (item 11). Labels as given in the request (Xaya, 2026-11-04); the game's own name is read at run time.
local LIST = {
    { 1233398, "Mad Shriek" }, { 402772, "Horrifying Shriek" },
    { 1265968, "Boiling Point" }, { 1265982, "Boiling Point" }, { 1265790, "Boiling Point" }, { 50842, "Blood Boil" },
    { 1306161, "Divine Arbiter" }, { 1306162, "Divine Arbiter" }, { 1310461, "Divine Arbiter" },
    { 53385, "Divine Storm" }, { 85256, "Templar's Verdict" }, { 383328, "Final Verdict" },
}
-- Enum.SecrecyLevel (docs/reference/api/enums.md): NeverSecret = 0, AlwaysSecret = 1, ContextuallySecret = 2
local LEVEL = { [0] = "never", [1] = "always", [2] = "contextual" }

local LEGEND = {
    codes = {
        AN = "anchor: a = index in .anchors", RD = "PLAYER_REGEN_DISABLED (+ context flags)", RE = "PLAYER_REGEN_ENABLED (+ context flags)",
        GS = "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", GH = "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE",
        OS = "SPELL_ACTIVATION_OVERLAY_SHOW", OH = "SPELL_ACTIVATION_OVERLAY_HIDE",
        GP = "glow pairing: XayaUI's PROC_GLOW_AURAS aura read about 0.1 s after a GLOW_SHOW",
        OV = "COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED", IC = "SPELL_UPDATE_ICON", US = "SPELL_UPDATE_USABLE (merged)",
        CH = "SPELL_UPDATE_CHARGES (merged)", PC = "UNIT_SPELLCAST_SUCCEEDED for the player",
        CS = "UNIT_SPELLCAST_START", CC = "UNIT_SPELLCAST_SUCCEEDED", CL = "UNIT_SPELLCAST_CHANNEL_START",
        CI = "UNIT_SPELLCAST_INTERRUPTED", CT = "UNIT_SPELLCAST_STOP",
        NA = "NAME_PLATE_UNIT_ADDED", NR = "NAME_PLATE_UNIT_REMOVED", UF = "UNIT_FLAGS: UnitAffectingCombat changed on a nameplate",
        TA = "ENCOUNTER_TIMELINE_EVENT_ADDED", TR = "ENCOUNTER_TIMELINE_EVENT_REMOVED", TS = "ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED",
        ES = "ENCOUNTER_START", EE = "ENCOUNTER_END", EW = "ENCOUNTER_WARNING", BE = "RAID_BOSS_EMOTE",
        AU = "UNIT_AURA for player / target: payload readability and list lengths only (merged)",
        AW = "watched spells: w[id] = { s = ShouldSpellAuraBeSecret, a = GetPlayerAuraBySpellID found / none / secret }",
        MK = "/xuidev probe mark", SL = "spell list secrecy checked", AB = "ADDON_ACTION_BLOCKED", AF = "ADDON_ACTION_FORBIDDEN",
        ER = "a handler failed (first time for this kind)",
    },
    keys = {
        t = "GetTime() (3 decimals)", e = "event code", u = "unit token", c = "in combat (InCombatLockdown)",
        n = "events merged into this entry", tl = "GetTime() of the last merged event", id = "spell ID (timeline: event ID)",
        s = "spell snapshot (item 3)", g = "castGUID", ib = "interruptedBy: me / GUID kind / secret (no other player's GUID)",
        sec = "C_Secrets.GetSpellCastSecrecy (0 never, 1 always, 2 contextual)",
    },
    values = { secret = "the game returned a secret value", ["<missing>"] = "the function does not exist in this client",
        ["<error>"] = "the call raised an error (first text in .callErrors)", readable = "readable, value not stored (another player)",
        none = "the call returned nil" },
}

local P = { on = false }
local IX = {}                  -- /xuidev instance (section 12, Dev Assist 0.7.1): hooks filled in below, plus .enc (current encounter ID)
local D                        -- XayaUIDevAssistDB.probe while a handler or command runs
local CUR = {}                 -- t, c of the event being handled
local open, mobCombat, lastWatch = {}, {}, {}
local pairIndex, pairSource    -- reverse index of XayaUI_NS.PROC_GLOW_AURAS (rebuilt when that table changes)

-------------------------------------------------------------------------------
-- Reading game values safely
-------------------------------------------------------------------------------
-- true when v is secret. Called before ANY other use of a game value (12.1.5: comparing, testing, indexing or doing arithmetic on a
-- secret raises in addon code). If the check itself fails, the value is treated as secret and never touched.
local function IsSecret(v)
    local fn = issecretvalue
    if type(fn) ~= "function" then return false end   -- no secret system in this client (the other Dev Assist files do the same)
    local ok, s = pcall(fn, v)
    if not ok then return true end
    return s == true
end

-- a game value as it may be stored: "secret", nil, a number, a boolean, a string (cut to maxLen), or "<type>" for anything else
local function V(v, maxLen)
    if IsSecret(v) then return SECRET end
    local t = type(v)
    if t == "number" then
        if v ~= v or v == math.huge or v == -math.huge then return tostring(v) end   -- nan / inf would not load back from the file
        return v
    elseif t == "boolean" or t == "nil" then
        return v
    elseif t == "string" then
        maxLen = maxLen or 120
        if #v > maxLen then return v:sub(1, maxLen) end
        return v
    end
    return "<" .. t .. ">"
end

local function Round3(v)   -- v already checked by V
    if type(v) ~= "number" then return v end
    return math.floor(v * 1000 + 0.5) / 1000
end

local function Index(t, k) return t[k] end
local function RawLen(t) return #t end
local function Pack(...) return { n = select("#", ...), ... } end

-- one field of a game table, checked: the table itself may be secret, and indexing it may raise
local function F(t, k, maxLen)
    if IsSecret(t) then return SECRET end
    if type(t) ~= "table" then return nil end
    local ok, v = pcall(Index, t, k)
    if not ok then return ERR end
    return V(v, maxLen)
end

-- length of a list field (UNIT_AURA payload): "secret", nil when absent, or the count. The elements are never read.
local function Len(t, k)
    if IsSecret(t) then return SECRET end
    if type(t) ~= "table" then return nil end
    local ok, v = pcall(Index, t, k)
    if not ok then return ERR end
    if IsSecret(v) then return SECRET end
    if type(v) ~= "table" then return nil end
    local ok2, n = pcall(RawLen, v)
    if not ok2 then return ERR end
    return n
end

local function Real(v)     -- a checked value that holds something readable
    return v ~= nil and v ~= SECRET and v ~= ERR and v ~= MISSING
end

local function NoteCallError(name, err)
    if not D then return end
    local c = D.callErrors[name]
    if not c then c = { n = 0, first = V(err, 200) }; D.callErrors[name] = c end
    c.n = c.n + 1
end

-- calls a game function. Returns MISSING, ERR, or "ok" plus a packed table of the RAW results (r[2] is the first; check them with
-- V / F before any use)
local function Call(name, fn, ...)
    if type(fn) ~= "function" then return MISSING end
    local r = Pack(pcall(fn, ...))
    if not r[1] then NoteCallError(name, r[2]); return ERR end
    return "ok", r
end

local function R1(name, fn, ...)   -- the first result, checked
    local st, r = Call(name, fn, ...)
    if st ~= "ok" then return st end
    return V(r[2])
end

local function Res(st, r, i, maxLen)   -- result i of a Call, checked
    if st ~= "ok" then return st end
    return V(r[i + 1], maxLen)
end

local function ResF(st, r, key, maxLen)   -- a field of the first result of a Call, checked
    if st ~= "ok" then return st end
    return F(r[2], key, maxLen)
end

local function NS(ns, fn)   -- C_Something.Function or nil
    local t = _G[ns]
    if type(t) ~= "table" then return nil end
    return t[fn]
end

-------------------------------------------------------------------------------
-- Saved data, ring buffer, tallies
-------------------------------------------------------------------------------
local function Data()
    local d = GD.DB()
    local p = d.probe
    if type(p) ~= "table" or p.v ~= 1 then
        p = { v = 1, on = false, log = {}, first = 1, last = 0, dropped = 0, anchors = {}, aFirst = 1, aLast = 0, aDropped = 0,
              count = {}, stats = {}, secrecy = {}, userSpells = {}, watchPairs = {}, marks = {}, errors = {}, callErrors = {},
              notRegistered = {} }
        d.probe = p
    end
    p.version, p.cap, p.legend = VERSION, CAP, LEGEND
    return p
end

local function Begin()
    D = Data()
    CUR.t = Round3(R1("GetTime", GetTime))
    CUR.c = R1("InCombatLockdown", InCombatLockdown)
end

local function Count(code) D.count[code] = (D.count[code] or 0) + 1 end

local function Push(e)
    D.last = D.last + 1
    D.log[D.last] = e
    while D.last - D.first + 1 > CAP do
        D.log[D.first] = nil
        D.first = D.first + 1
        D.dropped = D.dropped + 1
    end
end

-- frequent events: merge into the open entry for the same key while it is younger than MERGE_WINDOW (sums add up)
local function PushMerged(key, e, sums)
    local m = open[key]
    if m and D.log[m.seq] == m.e and type(e.t) == "number" and type(m.e.t) == "number" and e.t - m.e.t <= MERGE_WINDOW then
        m.e.n = (m.e.n or 1) + 1
        m.e.tl = e.t
        for _, k in ipairs(sums or {}) do
            if type(m.e[k]) == "number" and type(e[k]) == "number" then m.e[k] = m.e[k] + e[k] end
        end
        return
    end
    e.n = 1
    Push(e)
    open[key] = { seq = D.last, e = e }
end

local function Entry(code, unit)
    local e = { t = CUR.t, e = code, c = CUR.c }
    if unit ~= nil then e.u = unit end
    return e
end

local function Tally(field, v)
    local s
    if v == SECRET then s = "s" elseif v == nil then s = "n" elseif v == ERR then s = "e" elseif v == MISSING then s = "m" else s = "r" end
    local k = s .. ((CUR.c == true) and "c" or "o")
    local st = D.stats[field]
    if not st then st = {}; D.stats[field] = st end
    st[k] = (st[k] or 0) + 1
end

local function Put(e, key, v, field)   -- store a checked value and tally its readability
    e[key] = v
    Tally(field, v)
end

-- a handler failure: counted every time, recorded (text and one log entry) the first time for this kind
local function Fail(kind, err)
    D = D or Data()
    local f = D.errors[kind]
    if not f then
        f = { n = 0, first = V(err, 300), at = R1("date", date, "%Y-%m-%d %H:%M:%S") }
        D.errors[kind] = f
        Push({ t = CUR.t, e = "ER", k = kind, msg = f.first })
    end
    f.n = f.n + 1
end

-------------------------------------------------------------------------------
-- 1) Context flags and anchors
-------------------------------------------------------------------------------
-- C_Secrets.HasSecretRestrictions() -> bool; ShouldAurasBeSecret() -> bool; ShouldCooldownsBeSecret() -> bool (no flags).
-- C_ChatInfo.IsLoggingCombat() -> enabled: bool, advanced: bool (no flags).
-- LoggingCombat: not in the public reference (it leaves undocumented globals out). Blizzard's own /combatlog command calls it
-- (Blizzard_ChatFrameBase SlashCommands.lua, 12.1.5.70783). Whether an ADDON may call it is unknown, so only its type is recorded;
-- it is never called.
local function Context(t)
    t.restr = R1("C_Secrets.HasSecretRestrictions", NS("C_Secrets", "HasSecretRestrictions"))
    t.aurasSecret = R1("C_Secrets.ShouldAurasBeSecret", NS("C_Secrets", "ShouldAurasBeSecret"))
    t.cdsSecret = R1("C_Secrets.ShouldCooldownsBeSecret", NS("C_Secrets", "ShouldCooldownsBeSecret"))
    local st, r = Call("C_ChatInfo.IsLoggingCombat", NS("C_ChatInfo", "IsLoggingCombat"))
    t.logging, t.loggingAdv = Res(st, r, 1), Res(st, r, 2)
    t.LoggingCombat = type(_G.LoggingCombat)
    for _, k in ipairs({ "restr", "aurasSecret", "cdsSecret", "logging" }) do Tally("ctx." .. k, t[k]) end
    D.lastCtx = { restr = t.restr, aurasSecret = t.aurasSecret, cdsSecret = t.cdsSecret, logging = t.logging, LoggingCombat = t.LoggingCombat }
    return t
end

-- GetTime() -> number; GetServerTime() -> number; time() / date(): the game's Lua clock functions (not in the API reference).
-- GetInstanceInfo() -> name, instanceType, difficultyID, difficultyName, maxPlayers, dynamicDifficulty, isDynamic, instanceID, ...
-- (no flags). WoWCombatLog.txt uses local wall-clock time: date() and time() give that clock; GetTime() is what every entry carries.
local function Anchor(why, extra)
    local a = { why = why, t = CUR.t, c = CUR.c }
    a.time = R1("time", time)
    a.server = R1("GetServerTime", GetServerTime)
    a.date = R1("date", date, "%Y-%m-%d %H:%M:%S")
    local st, r = Call("GetInstanceInfo", GetInstanceInfo)
    a.instance = Res(st, r, 1, 80)
    a.instanceType = Res(st, r, 2)
    a.difficultyID = Res(st, r, 3)
    a.instanceID = Res(st, r, 8)
    a.ctx = Context({})
    if IX.Context then IX.Context(a.instanceID, a.instance, a.instanceType, a.difficultyID) end
    for k, v in pairs(extra or {}) do a[k] = v end
    D.aLast = D.aLast + 1
    D.anchors[D.aLast] = a
    while D.aLast - D.aFirst + 1 > ANCHOR_CAP do
        D.anchors[D.aFirst] = nil
        D.aFirst = D.aFirst + 1
        D.aDropped = D.aDropped + 1
    end
    local e = Entry("AN")
    e.a, e.why = D.aLast, why
    Count("AN")
    Push(e)
    return D.aLast
end

-------------------------------------------------------------------------------
-- 11) Secrecy list, and the watched spells
-------------------------------------------------------------------------------
-- XayaUI's rule spells: spellID / buffID fields and buffAlt / alt lists in CueRulesDB.rules and .bars (plain saved data).
local ID_KEYS, LIST_KEYS = { spellID = true, buffID = true }, { buffAlt = true, alt = true }
local function AddID(set, v)
    local n = tonumber(v)
    if n and n > 0 and n < 2147483648 and n == math.floor(n) then set[n] = true end
end
local function Walk(t, set, depth)
    if depth > 6 then return end
    for k, v in pairs(t) do
        if ID_KEYS[k] then AddID(set, v)
        elseif LIST_KEYS[k] and type(v) == "table" then for _, x in ipairs(v) do AddID(set, x) end
        elseif type(v) == "table" then Walk(v, set, depth + 1) end
    end
end
local function RuleIDs()
    local db = _G.CueRulesDB
    if type(db) ~= "table" then return nil end
    local set = {}
    if type(db.rules) == "table" then Walk(db.rules, set, 1) end
    if type(db.bars) == "table" then Walk(db.bars, set, 1) end
    local list = {}
    for id in pairs(set) do list[#list + 1] = id end
    table.sort(list)
    while #list > 400 do list[#list] = nil end
    return list
end
GD.RuleSpellIDs = RuleIDs   -- shared with TooltipCapture.lua (0.7.1): the spell / item IDs XayaUI's rules and bars name, sorted, at most 400

-- C_Secrets.GetSpellCastSecrecy(spellIdentifier) -> secrecy: SecrecyLevel · SecretArguments=AllowedWhenUntainted
-- C_Secrets.GetSpellAuraSecrecy(spellIdentifier) -> secrecy: SecrecyLevel · SecretArguments=AllowedWhenUntainted
-- Whether a spell's level ever changes is not documented: every check is kept as it came, changes are listed.
local function CheckSecrecy(id, src, label)
    local s = D.secrecy[id]
    if not s then s = { src = src, checks = 0 }; D.secrecy[id] = s
    elseif not (" " .. s.src .. " "):find(" " .. src .. " ", 1, true) then s.src = s.src .. " " .. src end
    if label then s.label = label end
    local cast = R1("C_Secrets.GetSpellCastSecrecy", NS("C_Secrets", "GetSpellCastSecrecy"), id)
    local aura = R1("C_Secrets.GetSpellAuraSecrecy", NS("C_Secrets", "GetSpellAuraSecrecy"), id)
    Tally("secrecy.cast", cast); Tally("secrecy.aura", aura)
    if s.checks > 0 and (cast ~= s.cast or aura ~= s.aura) then
        s.changes = s.changes or {}
        if #s.changes < 10 then s.changes[#s.changes + 1] = { t = CUR.t, c = CUR.c, cast = cast, aura = aura, castWas = s.cast, auraWas = s.aura } end
    end
    s.cast, s.aura = cast, aura
    s.castLevel = LEVEL[cast] or nil
    s.auraLevel = LEVEL[aura] or nil
    s.name = R1("C_Spell.GetSpellName", NS("C_Spell", "GetSpellName"), id)
    s.checks = s.checks + 1
    s.lastCombat = CUR.c
end

local function CheckList(why)
    for _, s in ipairs(LIST) do CheckSecrecy(s[1], "list", s[2]) end
    local ok, ids = pcall(RuleIDs)
    if ok and ids then
        for _, id in ipairs(ids) do CheckSecrecy(id, "rules") end
        D.ruleSpells = #ids
    else
        D.ruleSpells = ok and "XayaUI rules not loaded" or V(ids, 200)
    end
    for id in pairs(D.userSpells) do CheckSecrecy(id, "you") end
    if P.on then
        local e = Entry("SL")
        e.why = why
        Count("SL")
        Push(e)
    end
end

-- the watched spells (coordinator request, 2026-11-04): the built-in list plus the IDs added with `spells`
local function WatchIDs()
    local ids, seen = {}, {}
    for _, s in ipairs(LIST) do if not seen[s[1]] then seen[s[1]] = true; ids[#ids + 1] = s[1] end end
    local extra = {}
    for id in pairs(D.userSpells) do if not seen[id] then extra[#extra + 1] = id end end
    table.sort(extra)
    for _, id in ipairs(extra) do if #ids < WATCH_CAP then ids[#ids + 1] = id end end
    return ids
end

-- C_UnitAuras.GetPlayerAuraBySpellID(spellID) -> aura: AuraData? · RequiresNonSecretAura, SecretArguments=AllowedWhenTainted,
-- SecretWhenUnitAuraRestricted. "found" (a table came back; its fields are never read), "none" (nil), "secret", or "<error>"
-- (INFERENCE: RequiresNonSecretAura may make the call raise for a hidden aura; the text is kept in .callErrors).
local function AuraState(id)
    local st, r = Call("C_UnitAuras.GetPlayerAuraBySpellID", NS("C_UnitAuras", "GetPlayerAuraBySpellID"), id)
    if st ~= "ok" then return st end
    local a = r[2]
    if IsSecret(a) then return SECRET end
    if a == nil then return "none" end
    return "found"
end

-- C_Secrets.ShouldSpellAuraBeSecret(spellIdentifier) -> isAuraSecret: bool · SecretArguments=AllowedWhenUntainted.
-- Question (retrospective gap 20): can "false" + a nil aura read be trusted as "absent"? The answer comes from lining these entries
-- up with the combat log's SPELL_AURA_APPLIED / _REMOVED on the player. Entries are written at combat start and end (all spells)
-- and on UNIT_AURA for the player (only spells whose pair changed); every read is counted in .watchPairs.
local function Watch(why)
    local w, any = {}, false
    for _, id in ipairs(WatchIDs()) do
        local sab = R1("C_Secrets.ShouldSpellAuraBeSecret", NS("C_Secrets", "ShouldSpellAuraBeSecret"), id)
        local a = AuraState(id)
        Tally("watch.shouldAuraBeSecret", sab); Tally("watch.aura", a)
        local pairKey = tostring(sab) .. "/" .. tostring(a) .. ((CUR.c == true) and " in combat" or "")
        D.watchPairs[pairKey] = (D.watchPairs[pairKey] or 0) + 1
        local last = lastWatch[id]
        if why ~= "AU" or not last or last.s ~= sab or last.a ~= a then
            w[id] = { s = sab, a = a }
            any = true
        end
        lastWatch[id] = { s = sab, a = a }
    end
    if any then
        local e = Entry("AW")
        e.why, e.w = why, w
        Count("AW")
        Push(e)
    end
end

-------------------------------------------------------------------------------
-- 3) One spell's state right now (for events of items 2 and 3 that name a spell)
-------------------------------------------------------------------------------
-- C_Spell.IsSpellUsable(id) -> isUsable, insufficientPower · SecretArguments=AllowedWhenTainted
-- C_Spell.GetOverrideSpell(id) -> overrideSpellID · SecretArguments=AllowedWhenUntainted
-- C_Spell.GetSpellTexture(id) -> iconID, originalIconID, conditionalIconID? · MayReturnNothing
-- C_Spell.GetSpellInfo(id) -> SpellInfo · MayReturnNothing (castTime: no NeverSecret flag)
-- C_Spell.GetSpellPowerCost(id) -> table<SpellPowerCostInfo> · MayReturnNothing (hasRequiredAura, requiredAuraID: no NeverSecret flag)
-- C_Spell.GetSpellCharges(id) -> SpellChargeInfo · SecretWhenCooldownsRestricted (maxCharges, isActive: NeverSecret)
-- C_Spell.GetSpellCooldown(id) -> SpellCooldownInfo · SecretWhenCooldownsRestricted (isActive, isOnGCD: NeverSecret)
local function Snap(id)
    local s = {}
    local st, r = Call("C_Spell.IsSpellUsable", NS("C_Spell", "IsSpellUsable"), id)
    Put(s, "usable", Res(st, r, 1), "snap.usable")
    Put(s, "noPower", Res(st, r, 2), "snap.noPower")
    Put(s, "override", R1("C_Spell.GetOverrideSpell", NS("C_Spell", "GetOverrideSpell"), id), "snap.override")
    st, r = Call("C_Spell.GetSpellTexture", NS("C_Spell", "GetSpellTexture"), id)
    Put(s, "icon", Res(st, r, 1), "snap.icon")
    Put(s, "iconOrig", Res(st, r, 2), "snap.iconOrig")
    st, r = Call("C_Spell.GetSpellInfo", NS("C_Spell", "GetSpellInfo"), id)
    Put(s, "castTime", ResF(st, r, "castTime"), "snap.castTime")
    st, r = Call("C_Spell.GetSpellPowerCost", NS("C_Spell", "GetSpellPowerCost"), id)
    if st ~= "ok" then
        Put(s, "costs", st, "snap.costs")
    else
        local list = r[2]
        if IsSecret(list) then
            Put(s, "costs", SECRET, "snap.costs")
        elseif type(list) == "table" then
            s.costs = {}
            for i = 1, 3 do
                local ok, c = pcall(Index, list, i)
                if not ok then s.costs[i] = ERR; break end
                if IsSecret(c) then
                    s.costs[i] = SECRET
                elseif type(c) ~= "table" then
                    break
                else
                    local x = {}
                    Put(x, "hasAura", F(c, "hasRequiredAura"), "snap.hasRequiredAura")
                    Put(x, "auraID", F(c, "requiredAuraID"), "snap.requiredAuraID")
                    s.costs[i] = x
                end
            end
        end
    end
    st, r = Call("C_Spell.GetSpellCharges", NS("C_Spell", "GetSpellCharges"), id)
    Put(s, "maxCharges", ResF(st, r, "maxCharges"), "snap.maxCharges")
    Put(s, "chargeActive", ResF(st, r, "isActive"), "snap.chargeIsActive")
    st, r = Call("C_Spell.GetSpellCooldown", NS("C_Spell", "GetSpellCooldown"), id)
    Put(s, "cdActive", ResF(st, r, "isActive"), "snap.cooldownIsActive")
    Put(s, "onGCD", ResF(st, r, "isOnGCD"), "snap.isOnGCD")
    Count("snap")
    return s
end

-------------------------------------------------------------------------------
-- Handlers (event -> function(event, ...)); each runs inside pcall (OnEvent)
-------------------------------------------------------------------------------
local H = {}

-- 1) combat start / end. PLAYER_REGEN_DISABLED / _ENABLED · SynchronousEvent (no payload)
local function Regen(code, why)
    Begin()
    local e = Entry(code)
    Context(e)
    Count(code)
    Push(e)
    Watch(why)
end
H.PLAYER_REGEN_DISABLED = function() Regen("RD", "combat start") end
H.PLAYER_REGEN_ENABLED = function() Regen("RE", "combat end") end

-- anchors on zone changes. ZONE_CHANGED_NEW_AREA · SynchronousEvent; PLAYER_ENTERING_WORLD (isInitialLogin, isReloadingUi)
H.ZONE_CHANGED_NEW_AREA = function() Begin(); Anchor("zone") end
H.PLAYER_ENTERING_WORLD = function(_, isInitialLogin, isReloadingUi)
    Begin()
    Anchor("enter", { login = V(isInitialLogin), reload = V(isReloadingUi) })
end

-- 2) proc glows and proc art. SPELL_ACTIVATION_OVERLAY_GLOW_SHOW / _HIDE (spellID: number) · SynchronousEvent, no secrecy flag.
-- C_SpellActivationOverlay.IsSpellOverlayed(spellID: number) -> bool · SecretArguments=AllowedWhenUntainted.
-- C_Spell.GetBaseSpell(spellIdentifier, spec = 0) -> baseSpellID · SecretArguments=AllowedWhenTainted.
-- Blizzard's action buttons light the button whose spell equals the payload (ActionButton.lua, 12.1.5.70783); which ID the event
-- reports for a replaced spell (Final Verdict for Templar's Verdict) is not documented, hence the base / override reads.
local function Overlayed(id)
    return R1("C_SpellActivationOverlay.IsSpellOverlayed", NS("C_SpellActivationOverlay", "IsSpellOverlayed"), id)
end

-- 2b) glow pairing (coordinator request): XayaUI core's ns.PROC_GLOW_AURAS = { [auraID] = { buttonSpellIDs } } when that table
-- exists at run time (XayaUI_NS, the core namespace). Never needed at load time.
local function PairAuras(spellID)
    local ns = _G.XayaUI_NS
    local map = type(ns) == "table" and ns.PROC_GLOW_AURAS or nil
    if type(map) ~= "table" then return nil end
    if pairSource ~= map then
        pairIndex, pairSource = {}, map
        for auraID, list in pairs(map) do
            if type(auraID) == "number" and type(list) == "table" then
                for _, b in ipairs(list) do
                    if type(b) == "number" then
                        pairIndex[b] = pairIndex[b] or {}
                        local l = pairIndex[b]
                        l[#l + 1] = auraID
                    end
                end
            end
        end
    end
    return pairIndex[spellID]
end

local function PairLater(spellID, auras, shownAt)
    local after = NS("C_Timer", "After")
    if type(after) ~= "function" then return end
    after(PAIR_DELAY, function()
        if not P.on then return end
        local ok, err = pcall(function()
            Begin()
            for i, auraID in ipairs(auras) do
                if i > 6 then break end
                local e = Entry("GP")
                e.glow, e.aura, e.shown = spellID, auraID, shownAt
                Put(e, "st", AuraState(auraID), "pair.aura")
                Put(e, "sab", R1("C_Secrets.ShouldSpellAuraBeSecret", NS("C_Secrets", "ShouldSpellAuraBeSecret"), auraID), "pair.shouldAuraBeSecret")
                Count("GP")
                Push(e)
            end
        end)
        if not ok then pcall(Fail, "glow pairing", err) end
    end)
end

local function Glow(code, spellID)
    Begin()
    local e = Entry(code)
    local id = V(spellID)
    Put(e, "id", id, "glow.id")
    if type(id) == "number" then
        Put(e, "ovl", Overlayed(id), "glow.overlayed")
        local base = R1("C_Spell.GetBaseSpell", NS("C_Spell", "GetBaseSpell"), id)
        local over = R1("C_Spell.GetOverrideSpell", NS("C_Spell", "GetOverrideSpell"), id)
        e.base, e.over = base, over
        if type(base) == "number" and base ~= id then Put(e, "baseOvl", Overlayed(base), "glow.baseOverlayed") end
        if type(over) == "number" and over ~= id then Put(e, "overOvl", Overlayed(over), "glow.overrideOverlayed") end
        e.s = Snap(id)
        if code == "GS" then
            local auras = PairAuras(id)
            if auras then e.pair = #auras; PairLater(id, auras, CUR.t) end
        end
    end
    Count(code)
    Push(e)
end
H.SPELL_ACTIVATION_OVERLAY_GLOW_SHOW = function(_, spellID) Glow("GS", spellID) end
H.SPELL_ACTIVATION_OVERLAY_GLOW_HIDE = function(_, spellID) Glow("GH", spellID) end

-- SPELL_ACTIVATION_OVERLAY_SHOW (spellID, overlayFileDataID, locationType: ScreenLocationType, scale, r, g, b) · SynchronousEvent
-- SPELL_ACTIVATION_OVERLAY_HIDE (spellID: number?) · SynchronousEvent
H.SPELL_ACTIVATION_OVERLAY_SHOW = function(_, spellID, overlayFileDataID, locationType)
    Begin()
    local e = Entry("OS")
    local id = V(spellID)
    Put(e, "id", id, "overlay.id")
    Put(e, "file", V(overlayFileDataID), "overlay.fileDataID")
    Put(e, "loc", V(locationType), "overlay.locationType")
    if type(id) == "number" then e.s = Snap(id) end
    Count("OS")
    Push(e)
end
H.SPELL_ACTIVATION_OVERLAY_HIDE = function(_, spellID)
    Begin()
    local e = Entry("OH")
    local id = V(spellID)
    Put(e, "id", id, "overlay.id")
    if type(id) == "number" then e.s = Snap(id) end
    Count("OH")
    Push(e)
end

-- 3) spell-state changes. COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED (baseSpellID: number, overrideSpellID: number?) · SynchronousEvent
-- SPELL_UPDATE_ICON (spellID: number?) · UniqueEvent; SPELL_UPDATE_USABLE · UniqueEvent; SPELL_UPDATE_CHARGES · SynchronousEvent,
-- UniqueEvent (no payloads, so they are merged).
H.COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED = function(_, baseSpellID, overrideSpellID)
    Begin()
    local e = Entry("OV")
    local b, o = V(baseSpellID), V(overrideSpellID)
    Put(e, "base", b, "override.base")
    Put(e, "over", o, "override.override")
    if type(b) == "number" then e.s = Snap(b) end
    if type(o) == "number" and o ~= b then e.so = Snap(o) end
    Count("OV")
    Push(e)
end
H.SPELL_UPDATE_ICON = function(_, spellID)
    Begin()
    local e = Entry("IC")
    local id = V(spellID)
    Put(e, "id", id, "icon.id")
    Count("IC")
    local m = open["IC:" .. tostring(id)]
    local fresh = not (m and D.log[m.seq] == m.e and type(CUR.t) == "number" and type(m.e.t) == "number" and CUR.t - m.e.t <= MERGE_WINDOW)
    if fresh and type(id) == "number" then e.s = Snap(id) end
    PushMerged("IC:" .. tostring(id), e)
end
H.SPELL_UPDATE_USABLE = function() Begin(); Count("US"); PushMerged("US", Entry("US")) end
H.SPELL_UPDATE_CHARGES = function() Begin(); Count("CH"); PushMerged("CH", Entry("CH")) end

-- 4) and 5) casts. UNIT_SPELLCAST_START / _SUCCEEDED / _CHANNEL_START / _STOP (unitTarget, castGUID, spellID, castBarID?) and
-- _INTERRUPTED (unitTarget, castGUID, spellID, interruptedBy, castBarID?) · SecretWhenUnitSpellCastRestricted, SynchronousEvent.
-- Registered with plain RegisterEvent (RegisterUnitEvent takes at most two units) and filtered here: the player (SUCCEEDED only),
-- boss1-5, target, focus, nameplateN. Whether a unit token in the payload can itself be secret is not documented (INFERENCE: no);
-- a secret token is only counted.
local ENEMY = { boss1 = true, boss2 = true, boss3 = true, boss4 = true, boss5 = true, target = true, focus = true }
local CAST_CODE = { UNIT_SPELLCAST_START = "CS", UNIT_SPELLCAST_SUCCEEDED = "CC", UNIT_SPELLCAST_CHANNEL_START = "CL",
    UNIT_SPELLCAST_INTERRUPTED = "CI", UNIT_SPELLCAST_STOP = "CT" }

local function IsPlate(unit) return unit:find("^nameplate%d") ~= nil end

-- who interrupted: "me", the GUID's kind ("Player", "Creature", "Pet"...), "secret". No other player's GUID is stored.
local function Who(guid)
    local v = V(guid, 80)
    if type(v) ~= "string" or not Real(v) or v == "" then return v end
    local mine = R1("UnitGUID", UnitGUID, "player")
    if type(mine) == "string" and mine == v then return "me" end
    return v:match("^(%a+)%-") or "readable"
end

local function Cast(event, unit, castGUID, spellID, interruptedBy)
    if IsSecret(unit) then D = Data(); Count("castUnitSecret"); return end
    if type(unit) ~= "string" then return end
    if unit == "player" then
        if event ~= "UNIT_SPELLCAST_SUCCEEDED" then return end
        Begin()
        local e = Entry("PC")
        Put(e, "id", V(spellID), "playerCast.id")
        Count("PC")
        Push(e)
        return
    end
    if not (ENEMY[unit] or IsPlate(unit)) then return end
    local code = CAST_CODE[event]
    if not code then return end
    Begin()
    local e = Entry(code, unit)
    local id = V(spellID)
    Put(e, "id", id, "cast.id")
    Put(e, "g", V(castGUID, 80), "cast.guid")
    if code == "CI" then Put(e, "ib", Who(interruptedBy), "cast.interruptedBy") end
    if IX.Cast then IX.Cast(unit, id, code) end
    -- C_Secrets.GetSpellCastSecrecy(spellIdentifier) · SecretArguments=AllowedWhenUntainted: asked only with a readable ID
    if type(id) == "number" then Put(e, "sec", R1("C_Secrets.GetSpellCastSecrecy", NS("C_Secrets", "GetSpellCastSecrecy"), id), "cast.secrecy") end
    Count(code)
    Push(e)
end
for ev in pairs(CAST_CODE) do H[ev] = Cast end

-- 6) mob identity. NAME_PLATE_UNIT_ADDED / _REMOVED (unitToken) · SynchronousEvent; UNIT_FLAGS (unitTarget) · SynchronousEvent.
-- UnitCreatureID(unit) -> creatureID? · RequiresUnitIdentityAccess, SecretWhenUnitIdentityRestricted
-- UnitGUID(unit) -> WOWGUID? · SecretWhenUnitIdentityRestricted;  UnitName(unit) -> name, server · SecretWhenUnitNameIdentityRestricted
-- C_Secrets.ShouldUnitIdentityBeSecret(unit) -> bool · SecretArguments=AllowedWhenUntainted
-- UnitClassification, UnitIsDead, CanBeRaidTarget, UnitAffectingCombat, UnitIsPlayer: SecretArguments=AllowedWhenUntainted only.
-- Players (or units not known to be non-players): their name and GUID are recorded as "readable" / "secret" only.
-- Whether the token still answers at NAME_PLATE_UNIT_REMOVED is not documented (INFERENCE): whatever it answers is recorded.
local function Identity(e, unit)
    local pl = R1("UnitIsPlayer", UnitIsPlayer, unit)
    Put(e, "pl", pl, "mob.isPlayer")
    Put(e, "cid", R1("UnitCreatureID", UnitCreatureID, unit), "mob.creatureID")
    local guid = R1("UnitGUID", UnitGUID, unit)
    local name = R1("UnitName", UnitName, unit)
    if pl ~= false then
        if Real(guid) then guid = "readable" end
        if Real(name) then name = "readable" end
    end
    Put(e, "guid", guid, "mob.guid")
    Put(e, "name", name, "mob.name")
    Put(e, "idSecret", R1("C_Secrets.ShouldUnitIdentityBeSecret", NS("C_Secrets", "ShouldUnitIdentityBeSecret"), unit), "mob.identitySecret")
    Put(e, "cls", R1("UnitClassification", UnitClassification, unit), "mob.classification")
    Put(e, "dead", R1("UnitIsDead", UnitIsDead, unit), "mob.dead")
    Put(e, "rt", R1("CanBeRaidTarget", CanBeRaidTarget, unit), "mob.canBeRaidTarget")
    Put(e, "ac", R1("UnitAffectingCombat", UnitAffectingCombat, unit), "mob.affectingCombat")
    if IX.Seen then IX.Seen(e, unit) end
end

local function Plate(code, unit)
    if IsSecret(unit) then D = Data(); Count("plateUnitSecret"); return end
    if type(unit) ~= "string" then return end
    Begin()
    local e = Entry(code, unit)
    Identity(e, unit)
    if code == "NA" then mobCombat[unit] = e.ac else mobCombat[unit] = nil end
    Count(code)
    Push(e)
end
H.NAME_PLATE_UNIT_ADDED = function(_, unit) Plate("NA", unit) end
H.NAME_PLATE_UNIT_REMOVED = function(_, unit) Plate("NR", unit) end
H.UNIT_FLAGS = function(_, unit)
    if IsSecret(unit) or type(unit) ~= "string" or not IsPlate(unit) then return end
    Begin()
    local ac = R1("UnitAffectingCombat", UnitAffectingCombat, unit)
    if ac == mobCombat[unit] then return end
    local e = Entry("UF", unit)
    e.was = mobCombat[unit]
    Identity(e, unit)
    mobCombat[unit] = e.ac
    Count("UF")
    Push(e)
end

-- 7) Blizzard's boss timeline. ENCOUNTER_TIMELINE_EVENT_ADDED (eventInfo: EncounterTimelineEventInfo) · SecretWhenEncounterEvent.
-- EncounterTimelineEventInfo: id, source, duration NeverSecret; spellName, spellID, iconFileID, severity, isApproximate not.
-- _REMOVED / _STATE_CHANGED (eventID) · UniqueEvent. C_EncounterTimeline.GetEventState / GetEventTimeRemaining(eventID)
-- · RequiresValidTimelineEvent, SecretArguments=NotAllowed: asked only with a readable ID.
local TL_FIELDS = { "id", "source", "spellID", "spellName", "iconFileID", "duration", "severity", "isApproximate" }
H.ENCOUNTER_TIMELINE_EVENT_ADDED = function(_, info)
    Begin()
    local e = Entry("TA")
    if IsSecret(info) then
        Put(e, "info", SECRET, "timeline.info")
    elseif type(info) ~= "table" then
        Put(e, "info", V(info), "timeline.info")
    else
        for _, k in ipairs(TL_FIELDS) do
            local v = F(info, k, 80)
            if k == "duration" then v = Round3(v) end
            Put(e, k, v, "timeline." .. k)
        end
    end
    Count("TA")
    Push(e)
end
H.ENCOUNTER_TIMELINE_EVENT_REMOVED = function(_, eventID)
    Begin()
    local e = Entry("TR")
    Put(e, "id", V(eventID), "timeline.eventID")
    Count("TR")
    Push(e)
end
H.ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED = function(_, eventID)
    Begin()
    local e = Entry("TS")
    local id = V(eventID)
    Put(e, "id", id, "timeline.eventID")
    if type(id) == "number" then
        Put(e, "st", R1("C_EncounterTimeline.GetEventState", NS("C_EncounterTimeline", "GetEventState"), id), "timeline.state")
        Put(e, "rem", Round3(R1("C_EncounterTimeline.GetEventTimeRemaining", NS("C_EncounterTimeline", "GetEventTimeRemaining"), id)), "timeline.timeRemaining")
    end
    Count("TS")
    Push(e)
end

-- ENCOUNTER_START (encounterID, encounterName, difficultyID, groupSize) · SynchronousEvent: an anchor first
-- ENCOUNTER_END (..., success: number, encounterUnitStatus: table<EncounterUnitStatus>) · SynchronousEvent
-- EncounterUnitStatus: creatureID, creatureName, remainingHealthPercent (no flags)
local function Encounter(e, encounterID, encounterName, difficultyID, groupSize)
    Put(e, "id", V(encounterID), "encounter.id")
    Put(e, "name", V(encounterName, 80), "encounter.name")
    Put(e, "diff", V(difficultyID), "encounter.difficultyID")
    Put(e, "size", V(groupSize), "encounter.groupSize")
end
H.ENCOUNTER_START = function(_, ...)
    Begin()
    local a = Anchor("encounter")
    local e = Entry("ES")
    e.a = a
    Encounter(e, ...)
    IX.enc = (type(e.id) == "number") and e.id or nil   -- creatures seen from now on are filed under this encounter
    Count("ES")
    Push(e)
end
H.ENCOUNTER_END = function(_, encounterID, encounterName, difficultyID, groupSize, success, unitStatus)
    Begin()
    local e = Entry("EE")
    Encounter(e, encounterID, encounterName, difficultyID, groupSize)
    IX.enc = nil
    Put(e, "success", V(success), "encounter.success")
    if IsSecret(unitStatus) then
        Put(e, "units", SECRET, "encounter.unitStatus")
    elseif type(unitStatus) == "table" then
        e.units = {}
        for i = 1, 5 do
            local ok, u = pcall(Index, unitStatus, i)
            if not ok then e.units[i] = ERR; break end
            if IsSecret(u) then
                e.units[i] = SECRET
            elseif type(u) ~= "table" then
                break
            else
                local x = {}
                Put(x, "cid", F(u, "creatureID"), "encounter.unit.creatureID")
                Put(x, "name", F(u, "creatureName", 80), "encounter.unit.creatureName")
                Put(x, "hp", F(u, "remainingHealthPercent"), "encounter.unit.remainingHealthPercent")
                e.units[i] = x
            end
        end
    end
    Count("EE")
    Push(e)
end

-- 8) warnings and emotes. Text can name players: the player's own name becomes <me>, group members' <group>. A name the game
-- would not give (secret) cannot be replaced; the entry then says scrub = "partial".
local function Esc(s) return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")) end
local function Scrub(v, maxLen, e)
    if type(v) ~= "string" or not Real(v) or v == "" then return v end
    local names, partial = {}, false
    local function add(unit, tag)
        local n = R1("UnitName", UnitName, unit)
        if type(n) == "string" and Real(n) and #n >= 2 then names[#names + 1] = { n, tag }
        elseif n == SECRET or n == ERR then partial = true end
    end
    add("player", "<me>")
    for i = 1, 4 do add("party" .. i, "<group>") end
    if R1("IsInRaid", IsInRaid) == true then for i = 1, 40 do add("raid" .. i, "<group>") end end
    for _, p in ipairs(names) do v = v:gsub(Esc(p[1]), p[2]) end
    if #v > maxLen then v = v:sub(1, maxLen) end
    if partial and e then e.scrub = "partial" end
    return v
end

-- ENCOUNTER_WARNING (encounterWarningInfo: EncounterWarningInfo) · SynchronousEvent. EncounterWarningInfo: text, casterName,
-- tooltipSpellID are SecretValue; duration, severity carry no flag.
H.ENCOUNTER_WARNING = function(_, info)
    Begin()
    local e = Entry("EW")
    if IsSecret(info) then
        Put(e, "info", SECRET, "warning.info")
    elseif type(info) ~= "table" then
        Put(e, "info", V(info), "warning.info")
    else
        Put(e, "text", Scrub(F(info, "text", 400), 200, e), "warning.text")
        Put(e, "caster", Scrub(F(info, "casterName", 160), 80, e), "warning.casterName")
        Put(e, "spellID", F(info, "tooltipSpellID"), "warning.tooltipSpellID")
        Put(e, "dur", Round3(F(info, "duration")), "warning.duration")
        Put(e, "sev", F(info, "severity"), "warning.severity")
    end
    Count("EW")
    Push(e)
end
-- RAID_BOSS_EMOTE (text, playerName, displayTime, enableBossEmoteWarningSound) · SynchronousEvent, no secrecy flag (the chat
-- version CHAT_MSG_RAID_BOSS_EMOTE carries SecretInChatMessagingLockdown). Text kept to 200 characters.
H.RAID_BOSS_EMOTE = function(_, text)
    Begin()
    local e = Entry("BE")
    Put(e, "text", Scrub(V(text, 400), 200, e), "emote.text")
    Count("BE")
    Push(e)
end

-- 9) UNIT_AURA (unitTarget, updateInfo: UnitAuraUpdateInfo) · SecretWhenAurasRestricted. UnitAuraUpdateInfo: isFullUpdate,
-- addedAuras?, updatedAuraInstanceIDs?, removedAuraInstanceIDs?. Only readability and list lengths; aura data is never read.
local function K(v)   -- one character per checked value (merge key)
    if v == SECRET then return "s" elseif v == nil then return "n" elseif v == ERR then return "e" elseif v == MISSING then return "m"
    elseif v == true then return "T" elseif v == false then return "F" end
    return "r"
end
H.UNIT_AURA = function(_, unit, info)
    if IsSecret(unit) or (unit ~= "player" and unit ~= "target") then return end
    Begin()
    local e = Entry("AU", unit)
    if IsSecret(info) then
        Put(e, "info", SECRET, "aura.info")
    elseif type(info) ~= "table" then
        Put(e, "info", V(info), "aura.info")
    else
        Put(e, "full", F(info, "isFullUpdate"), "aura.isFullUpdate")
        Put(e, "add", Len(info, "addedAuras"), "aura.added")
        Put(e, "upd", Len(info, "updatedAuraInstanceIDs"), "aura.updated")
        Put(e, "rem", Len(info, "removedAuraInstanceIDs"), "aura.removed")
    end
    Count("AU")
    PushMerged("AU:" .. unit .. ":" .. K(e.info) .. K(e.full) .. K(e.add) .. K(e.upd) .. K(e.rem) .. K(e.c), e, { "add", "upd", "rem" })
    if unit == "player" then Watch("AU") end
end

-- 10) ADDON_ACTION_BLOCKED / _FORBIDDEN (isTainted, function) · SynchronousEvent: shows whether `mark` (or anything) was blocked
local function Blocked(code, addon, fn)
    Begin()
    local e = Entry(code)
    Put(e, "addon", V(addon, 60), "blocked.addon")
    Put(e, "fn", V(fn, 60), "blocked.function")
    Count(code)
    Push(e)
end
H.ADDON_ACTION_BLOCKED = function(_, a, f) Blocked("AB", a, f) end
H.ADDON_ACTION_FORBIDDEN = function(_, a, f) Blocked("AF", a, f) end

-------------------------------------------------------------------------------
-- Frames and registration
-------------------------------------------------------------------------------
local EVENTS = {
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD",
    "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE", "SPELL_ACTIVATION_OVERLAY_SHOW", "SPELL_ACTIVATION_OVERLAY_HIDE",
    "COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED", "SPELL_UPDATE_ICON", "SPELL_UPDATE_USABLE", "SPELL_UPDATE_CHARGES",
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_STOP",
    "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "UNIT_FLAGS",
    "ENCOUNTER_TIMELINE_EVENT_ADDED", "ENCOUNTER_TIMELINE_EVENT_REMOVED", "ENCOUNTER_TIMELINE_EVENT_STATE_CHANGED",
    "ENCOUNTER_START", "ENCOUNTER_END", "ENCOUNTER_WARNING", "RAID_BOSS_EMOTE", "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN",
}

local function OnEvent(_, event, ...)
    if not P.on then return end
    local h = H[event]
    if not h then return end
    local ok, err = pcall(h, event, ...)
    if not ok then pcall(Fail, event, err) end
end

local frame = CreateFrame("Frame")       -- every event above (plain RegisterEvent)
frame:SetScript("OnEvent", OnEvent)
local auraFrame = CreateFrame("Frame")   -- UNIT_AURA for player and target only (as Blizzard's Cooldown Viewer registers it)
auraFrame:SetScript("OnEvent", OnEvent)

local function Register()
    D.notRegistered = {}
    for _, ev in ipairs(EVENTS) do
        local ok, err = pcall(frame.RegisterEvent, frame, ev)
        if not ok then D.notRegistered[ev] = V(err, 200) end
    end
    local ok, err
    if auraFrame.RegisterUnitEvent then
        ok, err = pcall(auraFrame.RegisterUnitEvent, auraFrame, "UNIT_AURA", "player", "target")
    else
        ok, err = pcall(auraFrame.RegisterEvent, auraFrame, "UNIT_AURA")   -- the handler filters to player / target anyway
    end
    if not ok then D.notRegistered.UNIT_AURA = V(err, 200) end
end

local function Unregister()
    pcall(frame.UnregisterAllEvents, frame)
    pcall(auraFrame.UnregisterAllEvents, auraFrame)
end

-------------------------------------------------------------------------------
-- 12) Per-creature summary: /xuidev instance (Dev Assist 0.7.1, written 2026-11-04). UNTESTED IN GAME: tests/devassist_instance_run.py
-- drives it with stand-in game functions only.
-------------------------------------------------------------------------------
-- What Blizzard's client data cannot say (docs/reference/content; debug-log 2026-11-04-1523): most creatures' names, which creatures
-- cast what, which auras sit on them, their Mythic+ count, and which of a dungeon's two enemy-forces criteria the game uses. While the
-- probe is on, every enemy read it already makes (nameplate added, combat flag change, enemy cast) also files the creature here.
-- `/xuidev instance` reads the units visible right now (target, focus, boss1-5, nameplate1-40) and prints the summary.
-- Output: XayaUIDevAssistDB.instance (apart from .probe: `/xuidev probe clear` leaves it; `/xuidev instance clear` empties it)
--   .creatures[creatureID]  n / nc = sightings (nc in combat), name, cls (classification), inst[instanceKey] = n,
--                           enc[encounterID] = n, mp = { a = actualValue, p = percentValue, n = readable reads, s = secret reads,
--                           varies = true when two readable values differed }, casts[spellID] = n (nCasts distinct, castsMore =
--                           spells past the cap), auras[spellID] = { n, f = "H" harmful / "B" helpful, name } (nAuras, aurasMore)
--   .hidden[instanceKey]    sightings whose creature ID was not readable: o / c = out of / in combat, secret / none = why
--   .orphanCasts[instanceKey] = { n = distinct, ids = { [spellID] = n } }: enemy casts whose caster's creature ID was not readable
--   .instances[instanceKey] name, type, diffs[difficultyID] = n, cm (challenge-mode map ID), keyLevel, step (the scenario step with
--                           every criterion's fields, read at each anchor and scan), last (date)
--   .season                 C_MythicPlus.GetCurrentSeasonValues() and GetCurrentSeason() at the last read
--   .fields[field]          readability tallies like the probe's .stats (r / s / n / e / m = readable / secret / nil / raised /
--                           missing, then o / c = out of / in combat)
-- instanceKey = GetInstanceInfo's instanceID, or "unknown" before the first read. Players are never filed (UnitIsPlayer true, or not
-- readable as false: skipped). A secret is stored as "secret" and never compared, counted as a value or formatted.
-- API (docs/reference/api, 12.1.5.70688):
--   C_ScenarioInfo.GetUnitCriteriaProgressValues(unit: UnitToken) -> actualValue: number, percentValue: number,
--     percentValueString: string · MayReturnNothing, SecretArguments=AllowedWhenUntainted, SecretWhenUnitIdentityRestricted
--   C_ScenarioInfo.GetScenarioStepInfo(scenarioStepID: number?) -> scenarioStepInfo: ScenarioStepInfo · MayReturnNothing,
--     SecretArguments=AllowedWhenUntainted. ScenarioStepInfo: title, description, numCriteria, stepFailed, isBonusStep,
--     isForCurrentStepOnly, shouldShowBonusObjective, spells, weightedProgress?, rewardQuestID, widgetSetID?, stepID
--   C_ScenarioInfo.GetCriteriaInfo(criteriaIndex: number) -> scenarioCriteriaInfo: ScenarioCriteriaInfo · MayReturnNothing,
--     SecretArguments=AllowedWhenUntainted. ScenarioCriteriaInfo: description, criteriaType, completed, quantity, totalQuantity,
--     flags, assetID, criteriaID, duration, elapsed, failed, isWeightedProgress, isFormatted, quantityString
--   C_ChallengeMode.GetActiveChallengeMapID() -> mapChallengeModeID: number? (no flags)
--   C_ChallengeMode.GetActiveKeystoneInfo() -> activeKeystoneLevel: number, activeAffixIDs: table<number>, wasActiveKeystoneCharged: bool
--   C_MythicPlus.GetCurrentSeasonValues() -> displaySeasonID: number, milestoneSeasonID: number, rewardSeasonID: number (no flags)
--   C_MythicPlus.GetCurrentSeason() -> seasonID: number (no flags)
--   C_UnitAuras.GetAuraDataByIndex(unit: UnitTokenRestrictedForAddOns, index: luaIndex, filter: AuraFilters?) -> aura: AuraData?
--     · RequiresUnitAuraAccess, SecretArguments=AllowedWhenUntainted, SecretWhenUnitAuraRestricted. AuraData's fields are not in the
--     generated reference: spellId and name are the fields DevAssist.lua's ReadAuras reads (INFERENCE: the same on enemy units).
--   UnitExists(unit: UnitToken?) -> result: bool · SecretArguments=AllowedWhenUntainted. Identity reads: section 6.
-- INFERENCE (not documented): which criterion is the enemy-forces bar. Every criterion of the step is kept with isWeightedProgress
-- and totalQuantity, so it can be picked afterwards (Kings' Rest, Temple of Sethraliss and Seat of the Triumvirate have two trees).
local INST_V = 1
local CREATURE_CAP = 600       -- creatures kept (more are counted in .dropped)
local PER_CREATURE = 30        -- distinct spells and distinct auras kept per creature
local ORPHAN_CAP = 200         -- distinct spells of unreadable casters kept per instance
local AURA_READ = 40           -- auras read per unit and filter
local CRITERIA_READ = 20       -- criteria read per scenario step
local SCAN_UNITS = { "target", "focus", "boss1", "boss2", "boss3", "boss4", "boss5" }
for i = 1, 40 do SCAN_UNITS[#SCAN_UNITS + 1] = "nameplate" .. i end
local CRIT_FIELDS = { "criteriaID", "assetID", "criteriaType", "description", "quantity", "totalQuantity", "isWeightedProgress",
    "quantityString", "completed", "flags" }
local AURA_FILTERS = { { "HARMFUL", "H" }, { "HELPFUL", "B" } }
local CAST_FILED = { CS = true, CC = true, CL = true }   -- start, success, channel start (not interrupted / stop: the same cast again)
local INST_LEGEND = {
    creatures = "creature ID -> n sightings (nc in combat), name, cls, inst / enc counts, mp Mythic+ count, casts, auras",
    hidden = "per instance: sightings whose creature ID was not readable (o / c out of / in combat; secret / none)",
    orphanCasts = "per instance: enemy spells cast by a unit whose creature ID was not readable",
    instances = "instanceID -> name, type, diffs, cm (challenge-mode map ID), keyLevel, step (scenario step and its criteria)",
    season = "C_MythicPlus.GetCurrentSeasonValues (display / milestone / reward) and GetCurrentSeason",
    fields = "readability tallies: r / s / n / e / m = readable / secret / nil / raised / missing, o / c = out of / in combat",
}

local X                        -- XayaUIDevAssistDB.instance while a handler or command runs
local function InstData()
    local d = GD.DB()
    local x = d.instance
    if type(x) ~= "table" or x.v ~= INST_V then
        x = { v = INST_V, creatures = {}, nCreatures = 0, dropped = 0, skipped = 0, hidden = {}, orphanCasts = {}, instances = {},
              fields = {}, scans = 0 }
        d.instance = x
    end
    x.legend = INST_LEGEND
    X = x
    return x
end

local function ITally(field, v)
    local s
    if v == SECRET then s = "s" elseif v == nil then s = "n" elseif v == ERR then s = "e" elseif v == MISSING then s = "m" else s = "r" end
    local k = s .. ((CUR.c == true) and "c" or "o")
    local st = X.fields[field]
    if not st then st = {}; X.fields[field] = st end
    st[k] = (st[k] or 0) + 1
end

local function IBump(t, k) t[k] = (t[k] or 0) + 1 end
local function Now() return R1("date", date, "%Y-%m-%d %H:%M:%S") end

local function Creature(cid)
    local c = X.creatures[cid]
    if c then return c end
    if X.nCreatures >= CREATURE_CAP then X.dropped = X.dropped + 1; return nil end
    c = { n = 0, nc = 0, inst = {}, enc = {}, casts = {}, nCasts = 0, auras = {}, nAuras = 0, first = Now() }
    X.creatures[cid] = c
    X.nCreatures = X.nCreatures + 1
    return c
end

-- the instance, its scenario step and criteria, the Mythic+ season. Called by Anchor (probe on / resume, zone change, encounter
-- start, probe off) and by every /xuidev instance scan. The arguments are GetInstanceInfo values already checked by V.
IX.Context = function(instanceID, name, itype, diff)
    InstData()
    local key = (type(instanceID) == "number") and instanceID or "unknown"
    IX.inst = key
    local rec = X.instances[key]
    if not rec then rec = { diffs = {} }; X.instances[key] = rec end
    if type(name) == "string" and Real(name) then rec.name = name end
    if type(itype) == "string" and Real(itype) then rec.type = itype end
    if type(diff) == "number" then IBump(rec.diffs, diff) end
    rec.last = Now()
    rec.cm = R1("C_ChallengeMode.GetActiveChallengeMapID", NS("C_ChallengeMode", "GetActiveChallengeMapID"))
    local stK, rK = Call("C_ChallengeMode.GetActiveKeystoneInfo", NS("C_ChallengeMode", "GetActiveKeystoneInfo"))
    rec.keyLevel = Res(stK, rK, 1)
    local stS, rS = Call("C_ScenarioInfo.GetScenarioStepInfo", NS("C_ScenarioInfo", "GetScenarioStepInfo"))
    local nCrit = ResF(stS, rS, "numCriteria")
    ITally("scenario.numCriteria", nCrit)
    if type(nCrit) == "number" and nCrit > 0 then
        local step = { stepID = ResF(stS, rS, "stepID"), title = ResF(stS, rS, "title", 80), weighted = ResF(stS, rS, "weightedProgress"),
                       numCriteria = nCrit, criteria = {} }
        local fn = NS("C_ScenarioInfo", "GetCriteriaInfo")
        for i = 1, math.min(nCrit, CRITERIA_READ) do
            local stC, rC = Call("C_ScenarioInfo.GetCriteriaInfo", fn, i)
            local cr = {}
            for _, k in ipairs(CRIT_FIELDS) do cr[k] = ResF(stC, rC, k, 80) end
            ITally("scenario.criteriaID", cr.criteriaID)
            step.criteria[i] = cr
        end
        rec.step = step
    end
    local stV, rV = Call("C_MythicPlus.GetCurrentSeasonValues", NS("C_MythicPlus", "GetCurrentSeasonValues"))
    X.season = { display = Res(stV, rV, 1), milestone = Res(stV, rV, 2), reward = Res(stV, rV, 3),
                 season = R1("C_MythicPlus.GetCurrentSeason", NS("C_MythicPlus", "GetCurrentSeason")), at = rec.last }
    ITally("season.display", X.season.display)
end

local function Auras(c, unit)
    local fn = NS("C_UnitAuras", "GetAuraDataByIndex")
    for _, fl in ipairs(AURA_FILTERS) do
        for i = 1, AURA_READ do
            local st, r = Call("C_UnitAuras.GetAuraDataByIndex", fn, unit, i, fl[1])
            if st ~= "ok" then ITally("aura.data", st); break end
            local a = r[2]
            if IsSecret(a) then ITally("aura.data", SECRET); break end
            if type(a) ~= "table" then break end
            local id = F(a, "spellId")
            ITally("aura.spellId", id)
            if type(id) == "number" then
                local x = c.auras[id]
                if not x then
                    if c.nAuras >= PER_CREATURE then
                        c.aurasMore = (c.aurasMore or 0) + 1
                    else
                        x = { n = 0, f = fl[2] }
                        c.auras[id] = x
                        c.nAuras = c.nAuras + 1
                    end
                end
                if x then
                    x.n = x.n + 1
                    if x.name == nil then
                        local nm = F(a, "name", 80)
                        if type(nm) == "string" and Real(nm) then x.name = nm end
                    end
                end
            end
        end
    end
end

-- a sighting: called at the end of Identity (section 6) with its checked reads. NR (plate removed) is the same mob again: skipped.
IX.Seen = function(e, unit)
    if e.e == "NR" then return end
    InstData()
    if e.pl ~= false then
        if e.pl ~= true then X.skipped = X.skipped + 1 end   -- not known to be a non-player: never filed
        return
    end
    local cid = e.cid
    ITally("creatureID", cid)
    if type(cid) ~= "number" then
        local key = IX.inst or "unknown"
        local h = X.hidden[key]
        if not h then h = { o = 0, c = 0 }; X.hidden[key] = h end
        if CUR.c == true then h.c = h.c + 1 else h.o = h.o + 1 end
        IBump(h, (cid == SECRET) and "secret" or "none")
        return
    end
    local c = Creature(cid)
    if not c then return end
    c.n = c.n + 1
    if CUR.c == true then c.nc = c.nc + 1 end
    if type(e.name) == "string" and Real(e.name) then c.name = e.name end
    if type(e.cls) == "string" and Real(e.cls) then c.cls = e.cls end
    IBump(c.inst, IX.inst or "unknown")
    if IX.enc then IBump(c.enc, IX.enc) end
    c.last = Now()
    local st, r = Call("C_ScenarioInfo.GetUnitCriteriaProgressValues", NS("C_ScenarioInfo", "GetUnitCriteriaProgressValues"), unit)
    local a, p = Res(st, r, 1), Res(st, r, 2)
    ITally("mplus.actualValue", a)
    if a == SECRET or p == SECRET then
        c.mp = c.mp or { n = 0, s = 0 }
        c.mp.s = c.mp.s + 1
    elseif type(a) == "number" then
        local mp = c.mp or { n = 0, s = 0 }
        c.mp = mp
        if type(mp.a) == "number" and mp.a ~= a then mp.varies = true end
        mp.a = a
        if type(p) == "number" then mp.p = p end
        mp.n = mp.n + 1
    end
    Auras(c, unit)
end

-- an enemy cast (section 4 / 5 already checked the spell ID): filed under its caster's creature ID when that is readable
IX.Cast = function(unit, id, code)
    if not CAST_FILED[code] then return end
    InstData()
    if R1("UnitIsPlayer", UnitIsPlayer, unit) ~= false then return end
    local cid = R1("UnitCreatureID", UnitCreatureID, unit)
    ITally("cast.creatureID", cid)
    if type(id) ~= "number" then return end
    if type(cid) == "number" then
        local c = Creature(cid)
        if not c then return end
        if c.casts[id] == nil then
            if c.nCasts >= PER_CREATURE then c.castsMore = (c.castsMore or 0) + 1; return end
            c.nCasts = c.nCasts + 1
        end
        c.casts[id] = (c.casts[id] or 0) + 1
    else
        local key = IX.inst or "unknown"
        local o = X.orphanCasts[key]
        if not o then o = { n = 0, ids = {} }; X.orphanCasts[key] = o end
        if o.ids[id] == nil then
            if o.n >= ORPHAN_CAP then return end
            o.n = o.n + 1
        end
        o.ids[id] = (o.ids[id] or 0) + 1
    end
end

-- /xuidev instance: read the instance, then every unit visible now (Identity files each one through IX.Seen)
local function InstScan()
    Begin()
    InstData()
    local st, r = Call("GetInstanceInfo", GetInstanceInfo)
    IX.Context(Res(st, r, 8), Res(st, r, 1, 80), Res(st, r, 2), Res(st, r, 3))
    local n = 0
    for _, unit in ipairs(SCAN_UNITS) do
        if R1("UnitExists", UnitExists, unit) == true then
            local e = Entry("IS", unit)
            Identity(e, unit)
            n = n + 1
        end
    end
    X.scans = X.scans + 1
    return n
end

local function InstLines()
    InstData()
    local nName, nMp, nCast, nAura = 0, 0, 0, 0
    for _, c in pairs(X.creatures) do
        if c.name then nName = nName + 1 end
        if c.mp and c.mp.n > 0 then nMp = nMp + 1 end
        if c.nCasts > 0 then nCast = nCast + 1 end
        if c.nAuras > 0 then nAura = nAura + 1 end
    end
    local hO, hC = 0, 0
    for _, h in pairs(X.hidden) do hO = hO + h.o; hC = hC + h.c end
    local insts = {}
    for k, rec in pairs(X.instances) do insts[#insts + 1] = ("%s (%s)"):format(tostring(rec.name or "?"), tostring(k)) end
    table.sort(insts)
    local s = X.season or {}
    return {
        ("instance: %d creatures%s: %d with a name, %d with a Mythic+ count, %d with spells seen cast, %d with auras seen."):format(
            X.nCreatures, X.dropped > 0 and (" (" .. X.dropped .. " more not kept)") or "", nName, nMp, nCast, nAura),
        ("creature ID hidden on %d sightings out of combat and %d in combat. Collecting: %s."):format(hO, hC,
            P.on and "ON, with the probe" or "only when you type /xuidev instance (/xuidev probe on collects as you play)"),
        ("instances: %s. Mythic+ season: display %s, milestone %s, reward %s."):format(#insts > 0 and table.concat(insts, ", ") or "none yet",
            tostring(s.display), tostring(s.milestone), tostring(s.reward)),
    }
end
IX.Lines = InstLines
IX.Scan = InstScan

-------------------------------------------------------------------------------
-- Commands
-------------------------------------------------------------------------------
local function Say(msg) GD.Say("probe: " .. msg) end

function P.On(resumed)
    Begin()
    if P.on then Say("already on. /xuidev probe status shows what it has."); return end
    P.on, D.on = true, true
    D.started = D.started or CUR.t
    if not D.build then
        local st, r = Call("GetBuildInfo", GetBuildInfo)
        D.build = { version = Res(st, r, 1), build = Res(st, r, 2), toc = Res(st, r, 4) }
    end
    open, mobCombat, lastWatch = {}, {}, {}
    Register()
    Anchor(resumed and "resume" or "on")
    CheckList(resumed and "resume" or "on")
    Watch("on")
    local ns = _G.XayaUI_NS
    D.pairTable = (type(ns) == "table" and type(ns.PROC_GLOW_AURAS) == "table") and "present" or "absent"
    local refused = 0
    for _ in pairs(D.notRegistered) do refused = refused + 1 end
    if resumed then
        Say("ON (resumed after a reload). Type /xuidev probe off when you are done.")
    else
        Say("ON. Play normally; type /xuidev probe off when you are done, then /xuidev save (or /reload) to write the file.")
    end
    local nRules = type(D.ruleSpells) == "number" and D.ruleSpells or 0
    Say(("spell list checked: %d built-in, %d from your XayaUI rules, your own IDs too%s."):format(#LIST, nRules,
        refused > 0 and (" (" .. refused .. " event(s) refused by the game: see /xuidev probe status)") or ""))
end

function P.Off()
    Begin()
    if not P.on then D.on = false; Say("already off."); return end
    Anchor("off")
    Unregister()
    P.on, D.on = false, false
    open, mobCombat, lastWatch = {}, {}, {}
    Say(("OFF: %d entries recorded (%d kept). /xuidev save (or /reload) writes the file."):format(D.last, D.last - D.first + 1))
end

function P.Clear()
    local old = Data()
    GD.DB().probe = nil
    D = Data()
    D.on, D.userSpells = old.on, old.userSpells or {}
    open, mobCombat, lastWatch = {}, {}, {}
    if P.on then Begin(); Anchor("clear") end
    Say("data cleared (your added spell IDs are kept).")
end

function P.Spells(rest)
    Begin()
    local added = {}
    for w in (rest or ""):gmatch("%S+") do
        local n = tonumber(w)
        if n and n > 0 and n < 2147483648 and n == math.floor(n) then D.userSpells[n] = true; added[#added + 1] = n end
    end
    if #added == 0 then
        local have = {}
        for id in pairs(D.userSpells) do have[#have + 1] = id end
        table.sort(have)
        Say("usage: /xuidev probe spells 1233398 402772 ... Your IDs so far: " .. (#have > 0 and table.concat(have, " ") or "none") .. ".")
        return
    end
    local parts = {}
    for _, id in ipairs(added) do
        CheckSecrecy(id, "you")
        local s = D.secrecy[id]
        parts[#parts + 1] = ("%d %s: cast %s, aura %s"):format(id, tostring(s.name), tostring(s.castLevel or s.cast), tostring(s.auraLevel or s.aura))
    end
    if P.on then
        local e = Entry("SL")
        e.why, e.ids = "spells", added
        Count("SL")
        Push(e)
    end
    Say("checked " .. table.concat(parts, "; ") .. ". They are re-checked at every /xuidev probe on and watched on your auras.")
end

-- 10) mark: ONLY from this command, never automatic (a raid marker is visible to the group).
-- SetRaidTarget(target: UnitToken, userIndex: luaIndex) · HasRestrictions; GetRaidTargetIndex(target) -> luaIndex? · SecretReturns.
-- Blizzard's UI calls SetRaidTarget(unit, index) to set and SetRaidTarget(unit, 0) to clear (TargetFrame.lua, SecureTemplates.lua,
-- 12.1.5.70783). Whether an addon call is blocked in or out of combat is the question; a block shows up as AB / AF entries.
function P.Mark()
    Begin()
    local m = { t = CUR.t, c = CUR.c, date = R1("date", date, "%H:%M:%S") }
    m.target = R1("UnitExists", UnitExists, "target")
    m.before = R1("GetRaidTargetIndex", GetRaidTargetIndex, "target")
    if type(SetRaidTarget) ~= "function" then
        m.ok, m.err = false, MISSING
    else
        local ok, err = pcall(SetRaidTarget, "target", 8)
        m.ok = ok
        if not ok then m.err = V(err, 200) end
    end
    m.after = R1("GetRaidTargetIndex", GetRaidTargetIndex, "target")
    if #D.marks < MARK_CAP then D.marks[#D.marks + 1] = m end
    if P.on then
        local e = Entry("MK")
        e.ok, e.err, e.target, e.before, e.after = m.ok, m.err, m.target, m.before, m.after
        Count("MK")
        Push(e)
    end
    Say(("mark: SetRaidTarget(\"target\", 8) %s%s, %s; marker before %s, after %s."):format(m.ok and "ran" or "failed",
        m.err and (" (" .. tostring(m.err) .. ")") or "", m.c == true and "in combat" or "out of combat", tostring(m.before), tostring(m.after)))
end

-- status: one line per item
local function RS(field)
    local st = D.stats[field] or {}
    local function g(k) return st[k] or 0 end
    return ("readable %d (%d in combat), secret %d (%d in combat)"):format(g("ro") + g("rc"), g("rc"), g("so") + g("sc"), g("sc"))
end
local function N(code) return D.count[code] or 0 end

function P.StatusLines()
    D = Data()
    local L = {}
    local nFail, kinds = 0, {}
    for k, f in pairs(D.errors) do nFail = nFail + (f.n or 0); kinds[#kinds + 1] = k end
    table.sort(kinds)
    L[#L + 1] = ("%s: %d entries recorded, %d kept, %d dropped (keeps the newest %d); %d anchors; %d handler failures%s."):format(
        P.on and "ON" or "off", D.last, D.last - D.first + 1, D.dropped, CAP, D.aLast, nFail, #kinds > 0 and (" (" .. table.concat(kinds, ", ") .. ")") or "")
    local ctx = D.lastCtx or {}
    L[#L + 1] = ("1 context: %d anchors, combat start %d / end %d; last: restrictions %s, auras secret %s, cooldowns secret %s, combat log %s, LoggingCombat %s."):format(
        N("AN"), N("RD"), N("RE"), tostring(ctx.restr), tostring(ctx.aurasSecret), tostring(ctx.cdsSecret), tostring(ctx.logging), tostring(ctx.LoggingCombat))
    L[#L + 1] = ("2 glows: glow show %d / hide %d, proc art show %d / hide %d; spell ID %s; glow pairing %d reads (%s)."):format(
        N("GS"), N("GH"), N("OS"), N("OH"), RS("glow.id"), N("GP"), tostring(D.pairTable or "not checked"))
    local snapSecret = 0
    for k, st in pairs(D.stats) do if k:find("^snap%.") then snapSecret = snapSecret + (st.so or 0) + (st.sc or 0) end end
    L[#L + 1] = ("3 spell state: override %d, icon %d, usable %d, charges %d; %d spell snapshots (%d secret fields)."):format(
        N("OV"), N("IC"), N("US"), N("CH"), N("snap"), snapSecret)
    L[#L + 1] = ("4 your casts: %d; spell ID %s."):format(N("PC"), RS("playerCast.id"))
    L[#L + 1] = ("5 enemy casts: start %d, success %d, channel %d, interrupted %d, stop %d; spell ID %s; cast GUID %s; %d secret unit tokens."):format(
        N("CS"), N("CC"), N("CL"), N("CI"), N("CT"), RS("cast.id"), RS("cast.guid"), N("castUnitSecret"))
    L[#L + 1] = ("6 mobs: plates added %d / removed %d, combat changes %d; creature ID %s; GUID %s; name %s."):format(
        N("NA"), N("NR"), N("UF"), RS("mob.creatureID"), RS("mob.guid"), RS("mob.name"))
    L[#L + 1] = ("7 boss timeline: added %d, removed %d, state changes %d; timeline spell ID %s; encounters started %d / ended %d."):format(
        N("TA"), N("TR"), N("TS"), RS("timeline.spellID"), N("ES"), N("EE"))
    L[#L + 1] = ("8 warnings: %d (text %s); boss emotes %d (text %s)."):format(N("EW"), RS("warning.text"), N("BE"), RS("emote.text"))
    local wp = {}
    for k, n in pairs(D.watchPairs) do wp[#wp + 1] = k .. " x" .. n end
    table.sort(wp)
    L[#L + 1] = ("9 auras: %d UNIT_AURA events (player and target); payload %s; watched spells %d changes (%s)."):format(
        N("AU"), RS("aura.info"), N("AW"), #wp > 0 and table.concat(wp, ", ") or "none yet")
    local last = D.marks[#D.marks]
    L[#L + 1] = ("10 mark: %d tries%s; blocked-action events %d."):format(#D.marks,
        last and ("; last " .. (last.ok and "ran" or ("failed: " .. tostring(last.err))) .. (last.c == true and " in combat" or " out of combat")) or "",
        N("AB") + N("AF"))
    local nSp, lv = 0, { never = 0, always = 0, contextual = 0, other = 0 }
    for _, s in pairs(D.secrecy) do
        nSp = nSp + 1
        local w = s.castLevel or "other"
        lv[w] = lv[w] + 1
    end
    L[#L + 1] = ("11 secrecy list: %d spells (%s from your rules); cast secrecy never %d, always %d, contextual %d, other %d."):format(
        nSp, tostring(D.ruleSpells or "not read yet"), lv.never, lv.always, lv.contextual, lv.other)
    local xi = GD.DB().instance
    L[#L + 1] = ("12 creatures filed for /xuidev instance: %d."):format(type(xi) == "table" and xi.nCreatures or 0)
    local refused = {}
    for ev in pairs(D.notRegistered or {}) do refused[#refused + 1] = ev end
    if #refused > 0 then table.sort(refused); L[#L + 1] = "events the game refused: " .. table.concat(refused, ", ") .. "." end
    return L
end

function P.Status()
    for _, l in ipairs(P.StatusLines()) do Say(l) end
end

-- summary for the main /xuidev status line
function GD.ProbeSummary()
    local p = GD.DB().probe
    return P.on, type(p) == "table" and p.last or 0
end

local USAGE = "usage: /xuidev probe on | off | status | clear | spells <id> <id> ... | mark"
function GD.Probe(arg)
    local sub, rest = (arg or ""):match("^(%S*)%s*(.-)%s*$")
    local fn
    if sub == "on" then fn = function() P.On(false) end
    elseif sub == "off" then fn = P.Off
    elseif sub == "status" or sub == "" then fn = P.Status
    elseif sub == "clear" then fn = P.Clear
    elseif sub == "spells" then fn = function() P.Spells(rest) end
    elseif sub == "mark" then fn = P.Mark
    else Say(USAGE); return end
    local ok, err = pcall(fn)
    if not ok then
        pcall(Fail, "command " .. sub, err)
        Say("that command failed and was logged: " .. tostring(V(err, 200)))
    end
    if sub == "" then Say(USAGE) end
end
GD.ProbeState = P   -- (tests read it)

-- /xuidev instance [status | clear] (section 12)
local INST_USAGE = "usage: /xuidev instance (read the units you can see now, then the summary) | status | clear"
function GD.Instance(arg)
    local sub = (arg or ""):match("^(%S*)") or ""
    local ok, err = pcall(function()
        if sub == "" or sub == "scan" then
            local n = IX.Scan()
            GD.Say(("instance: read %d unit(s) you can see now."):format(n))
            for _, l in ipairs(IX.Lines()) do GD.Say(l) end
        elseif sub == "status" then
            for _, l in ipairs(IX.Lines()) do GD.Say(l) end
        elseif sub == "clear" then
            GD.DB().instance = nil
            GD.Say("instance: cleared.")
        else
            GD.Say(INST_USAGE)
        end
    end)
    if not ok then
        pcall(Fail, "instance " .. sub, err)
        GD.Say("instance: that command failed and was logged: " .. tostring(V(err, 200)))
    end
end
function GD.InstanceSummary()
    local x = GD.DB().instance
    return type(x) == "table" and x.nCreatures or 0
end

-- resume after a reload when the probe was on (the only thing that runs while it is off: this one ADDON_LOADED check)
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, _, name)
    if IsSecret(name) or name ~= ADDON then return end
    self:UnregisterEvent("ADDON_LOADED")
    local ok, err = pcall(function()
        local d = Data()
        if d.on == true then P.On(true) end
    end)
    if not ok then pcall(Fail, "resume", err) end
end)

-- XayaUI's "Advanced Debugging" (Settings > Debugging, core DebugRecord.lua) can switch the probe on and off, so a tester does not have
-- to remember /xuidev probe on. Offered as the "gameDataProbe" service of XayaUI's feature contract (Modules.lua ns.Provide); this
-- addon loads after XayaUI (## OptionalDeps), so the core namespace exists here when XayaUI is installed. Without XayaUI: nothing.
do
    local core = rawget(_G, "XayaUI_NS")
    if type(core) == "table" and type(core.Provide) == "function" then
        core.Provide("gameDataProbe", {
            On = function() if not P.on then P.On() end end,
            Off = function() if P.on then P.Off() end end,
            Active = function() return P.on and true or false end,
            -- for XayaUI's Settings > Debugging: this addon's name, its window, and the file its captures are saved in ("What to send")
            name = "XayaUI Dev Assist",
            Open = function() if GD and GD.Toggle then GD.Toggle() end end,
            savedFile = "XayaUI_DevAssist.lua",
            savedWhat = "the probe and the other developer captures",
        })
    end
end
