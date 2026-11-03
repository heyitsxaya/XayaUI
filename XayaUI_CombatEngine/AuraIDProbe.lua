-- XayaUI: aura instance ID probe (diagnostic only; changes no rule behaviour).
-- /xui probe ids        arm / disarm
-- /xui probe ids log    print the saved log lines again
--
-- Question it answers: while in combat, can addon code (a) call
-- C_UnitAuras.GetUnitAuraInstanceIDs("player"), (b) READ and COMPARE the IDs it returns,
-- (c) pass one to GetAuraDuration / GetAuraDataByAuraInstanceID, and (d) tell that a new ID
-- appeared after a readable player cast and later vanished (= early removal detection)?
-- Every call is wrapped in pcall. A possibly-secret value is NEVER passed to tostring or
-- compared: only issecretvalue() and type() are used on values of unknown secrecy.
local ADDON, ns = ...; ns = XayaUI_NS or ns -- sibling addon XayaUI_CombatEngine shares XayaUI's namespace (interim bridge, see README)
if not ns then return end

local isSecret = issecretvalue or function() return false end
local CANDIDATES = { "GetUnitAuraInstanceIDs", "GetAuraDuration", "GetAuraDataByAuraInstanceID",
    "GetAuraDurationRemaining", "DoesAuraHaveExpirationTime", "GetAuraApplicationDisplayCount",
    "IsAuraFilteredOutByInstanceID" }
local DUR_METHODS = { "GetRemainingDuration", "GetRemainingPercent", "GetTotalDuration", "GetEndTime" }

local armed, ticker = false, nil
local before = nil            -- snapshot taken at UNIT_SPELLCAST_SENT
local tracked = {}            -- [auraInstanceID] = { spell, t0, lastSeen }
local lastCount, lastCombat = nil, nil
local detailDone = {}         -- [combatFlag] = true once the heavy tests ran
local stats = { casts = 0, linked = 0, gone = 0 }

local lastLine, repeats = nil, 0
local function Log(line)
    -- identical consecutive lines (e.g. a refused call repeating every cast) are counted, not stored 300 times
    if line == lastLine then repeats = repeats + 1; return end
    if repeats > 0 then
        local db0 = _G.CueRulesDB
        if type(db0) == "table" and db0.idProbe then db0.idProbe[#db0.idProbe + 1] = "   (previous line repeated " .. repeats .. " more times)" end
        repeats = 0
    end
    lastLine = line
    ns.Print("[idprobe] " .. line)
    local db = _G.CueRulesDB
    if type(db) == "table" then
        db.idProbe = db.idProbe or {}
        db.idProbe[#db.idProbe + 1] = (date and date("%H:%M:%S ") or "") .. line
        while #db.idProbe > 300 do table.remove(db.idProbe, 1) end
    end
end

local function Snap()
    local s = { t = GetTime(), combat = InCombatLockdown() and true or false, ids = {}, readN = 0, secretN = 0 }
    local api = C_UnitAuras and C_UnitAuras.GetUnitAuraInstanceIDs
    if not api then s.err = "GetUnitAuraInstanceIDs missing"; return s end
    local ok, ids = pcall(api, "player", "HELPFUL")      -- the API requires the filter argument
    s.ok = ok
    if not ok then s.err = tostring(ids); return s end
    s.rtype = type(ids)
    s.rsecret = isSecret(ids) and true or false
    if type(ids) ~= "table" or s.rsecret then return s end
    local okn, n = pcall(function() return #ids end)
    s.count = okn and n or nil
    pcall(function()
        for i = 1, (s.count or 0) do
            local v = ids[i]
            if isSecret(v) then s.secretN = s.secretN + 1
            elseif type(v) == "number" then s.readN = s.readN + 1; s.ids[v] = true end
        end
    end)
    return s
end

local function Describe(v)
    if v == nil then return "nil" end
    if isSecret(v) then return "SECRET " .. type(v) end
    return type(v)
end

-- Heavy tests on up to 2 readable IDs: duration object + aura data.
local function Detail(s, tag)
    local tested = 0
    for id in pairs(s.ids) do
        tested = tested + 1
        if tested > 2 then break end
        local C = C_UnitAuras
        if C and C.GetAuraDuration then
            local ok, d = pcall(C.GetAuraDuration, "player", id)
            if not ok then Log(tag .. " GetAuraDuration(" .. id .. ") ERROR: " .. tostring(d))
            elseif d == nil then Log(tag .. " GetAuraDuration(" .. id .. ") -> nil")
            else
                local parts = { "object type=" .. type(d) .. (isSecret(d) and " SECRET" or "") }
                for _, m in ipairs(DUR_METHODS) do
                    local okm, r = pcall(function() return d[m](d) end)
                    parts[#parts + 1] = m .. "=" .. (okm and Describe(r) or "error")
                end
                Log(tag .. " GetAuraDuration(" .. id .. ") " .. table.concat(parts, ", "))
            end
        end
        if C and C.GetAuraDataByAuraInstanceID then
            local ok, data = pcall(C.GetAuraDataByAuraInstanceID, "player", id)
            if not ok then Log(tag .. " GetAuraDataByAuraInstanceID(" .. id .. ") ERROR: " .. tostring(data))
            elseif type(data) ~= "table" then Log(tag .. " GetAuraDataByAuraInstanceID(" .. id .. ") -> " .. Describe(data))
            else
                local okf, spellT, nameT, durT = pcall(function()
                    return Describe(data.spellId), Describe(data.name), Describe(data.duration)
                end)
                Log(tag .. " AuraData(" .. id .. ") spellId=" .. (okf and spellT or "error")
                    .. " name=" .. (okf and nameT or "error") .. " duration=" .. (okf and durT or "error"))
            end
        end
    end
    if tested == 0 then Log(tag .. " no readable IDs to run duration/data tests on") end
end

local function Report(s, why)
    local tag = s.combat and "COMBAT" or "ooc"
    if s.err then Log(tag .. " " .. why .. ": " .. s.err); return end
    Log(string.format("%s %s: call ok, returns %s%s, count=%s, readable IDs=%d, SECRET IDs=%d",
        tag, why, s.rtype or "?", s.rsecret and " (SECRET)" or "", tostring(s.count), s.readN, s.secretN))
    if not detailDone[s.combat] and (s.readN > 0) then
        detailDone[s.combat] = true
        Detail(s, tag)
    end
end

local function Poll()
    local s = Snap()
    if lastCombat ~= s.combat then
        lastCombat = s.combat
        Report(s, s.combat and "entered combat" or "left combat")
        lastCount = s.count
    elseif s.count ~= lastCount then
        Log(string.format("%s aura count %s -> %s", s.combat and "COMBAT" or "ooc", tostring(lastCount), tostring(s.count)))
        lastCount = s.count
    end
    for id, info in pairs(tracked) do
        if s.ids[id] then
            info.lastSeen = s.t
        elseif not s.err and s.readN > 0 or (s.count == 0) then
            stats.gone = stats.gone + 1
            Log(string.format("%s TRACKED ID %d (cast spell %s) is GONE %.1f s after it appeared",
                s.combat and "COMBAT" or "ooc", id, tostring(info.spell), s.t - info.t0))
            tracked[id] = nil
        end
    end
end

local function AfterCast(spell, delay)
    C_Timer.After(delay, function()
        if not armed or not before then return end
        local s = Snap()
        local tag = s.combat and "COMBAT" or "ooc"
        if s.err then Log(tag .. " after-cast snapshot failed: " .. s.err); return end
        local newIds = {}
        for id in pairs(s.ids) do if not before.ids[id] then newIds[#newIds + 1] = id end end
        local dCount = (s.count and before.count) and (s.count - before.count) or nil
        Log(string.format("%s cast %s +%.2fs: count %s -> %s (delta %s), NEW readable IDs: %s%s",
            tag, tostring(spell), delay, tostring(before.count), tostring(s.count), tostring(dCount),
            #newIds > 0 and table.concat(newIds, ",") or "none",
            (s.secretN > 0) and (" | " .. s.secretN .. " SECRET IDs present, cannot be diffed") or ""))
        if #newIds >= 1 and #newIds <= 3 then
            for _, id in ipairs(newIds) do
                if not tracked[id] then
                    tracked[id] = { spell = spell, t0 = s.t, lastSeen = s.t }
                    stats.linked = stats.linked + 1
                end
            end
        end
    end)
end

-------------------------------------------------------------------------------
-- UNIT_AURA payload test: the question after the ID-list call proved refused in combat.
-- Does the event payload carry usable instance IDs, and can a (possibly secret) ID be handed to GetAuraDuration?
-- Only issecretvalue() and type() are used on values of unknown secrecy; nothing secret is compared or printed.
-------------------------------------------------------------------------------
local uaLogged = { ooc = 0, combat = 0 }
local UA_MAX = 8                       -- detailed samples per state; the rest are only counted
local uaCount = { ooc = 0, combat = 0 }

local function Sec(v) if v == nil then return "nil" end; return (isSecret(v) and "SECRET " or "") .. type(v) end

local function DurationTest(id, tag)
    local C = C_UnitAuras
    if not (C and C.GetAuraDuration) then return "GetAuraDuration missing" end
    local ok, d = pcall(C.GetAuraDuration, "player", id)
    if not ok then return "GetAuraDuration(id) ERROR: " .. tostring(d):sub(1, 110) end
    if d == nil then return "GetAuraDuration(id) -> nil" end
    local parts = { "object " .. Sec(d) }
    for _, m in ipairs(DUR_METHODS) do
        local okm, r = pcall(function() return d[m](d) end)
        parts[#parts + 1] = m .. "=" .. (okm and Sec(r) or "error")
    end
    return table.concat(parts, ", ")
end

-- Event stream: one compact line per UNIT_AURA event (which of added/updated/removed are PRESENT, never their contents) and
-- one per readable own cast.  Whether a secret table exists is not secret; it says "some aura was added/refreshed/removed now".
-- Offline we can then ask: does a removal event line up with the expected end of a buff cast earlier?
local flagTotals = { A = 0, U = 0, R = 0, n = 0 }
local function Stream(line)
    local db = _G.CueRulesDB
    if type(db) ~= "table" then return end
    local s = db.idProbeStream
    if not s then s = {}; db.idProbeStream = s end
    s[#s + 1] = line
    if #s >= 1600 then
        local n = {}
        for i = 301, #s do n[#n + 1] = s[i] end
        db.idProbeStream = n
    end
end

local function StreamAura(info, combat)
    local a, u, r = "-", "-", "-"
    if type(info) == "table" then
        local ok1, v1 = pcall(function() return info.addedAuras end)
        local ok2, v2 = pcall(function() return info.updatedAuraInstanceIDs end)
        local ok3, v3 = pcall(function() return info.removedAuraInstanceIDs end)
        if ok1 and v1 ~= nil then a = "A" end
        if ok2 and v2 ~= nil then u = "U" end
        if ok3 and v3 ~= nil then r = "R" end
    end
    if combat then
        flagTotals.n = flagTotals.n + 1
        if a == "A" then flagTotals.A = flagTotals.A + 1 end
        if u == "U" then flagTotals.U = flagTotals.U + 1 end
        if r == "R" then flagTotals.R = flagTotals.R + 1 end
    end
    Stream(string.format("%.3f %s %s%s%s", GetTime(), combat and "C" or "o", a, u, r))
end

-- 0.5.27: identity of auras, out of combat only (in combat every field is secret and is never touched).
-- Gives ground truth for "which aura was that removal" when the in-combat flag stream is matched against cast times.
local identity = {}
local function SafeField(t, k)
    local ok, v = pcall(function() return t[k] end)
    if ok and v ~= nil and not isSecret(v) then return v end
    return nil
end

local function StreamIdentity(info)
    if InCombatLockdown() or type(info) ~= "table" or isSecret(info) then return end
    local now = GetTime()
    local added = SafeField(info, "addedAuras")
    if type(added) == "table" and not isSecret(added) then
        local okn, n = pcall(function() return #added end)
        for i = 1, math.min(okn and n or 0, 12) do
            local a = SafeField(added, i)
            if type(a) == "table" and not isSecret(a) then
                local id = SafeField(a, "auraInstanceID")
                if id ~= nil then
                    identity[id] = { spell = SafeField(a, "spellId"), name = SafeField(a, "name"), dur = SafeField(a, "duration"), t0 = now }
                    Stream(string.format("%.3f o ADD id=%s spell=%s name=%s dur=%s", now, tostring(id),
                        tostring(identity[id].spell), tostring(identity[id].name), tostring(identity[id].dur)))
                end
            end
        end
    end
    local removed = SafeField(info, "removedAuraInstanceIDs")
    if type(removed) == "table" and not isSecret(removed) then
        local okn, n = pcall(function() return #removed end)
        for i = 1, math.min(okn and n or 0, 12) do
            local id = SafeField(removed, i)
            if id ~= nil then
                local e = identity[id]
                Stream(string.format("%.3f o REM id=%s spell=%s name=%s life=%s dur=%s", now, tostring(id),
                    e and tostring(e.spell) or "?", e and tostring(e.name) or "?",
                    e and string.format("%.3f", now - e.t0) or "?", e and tostring(e.dur) or "?"))
                identity[id] = nil
            end
        end
    end
end

-- auras already present when the probe is armed (out of combat): record who they are
local function StreamHave(ids)
    local api = C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID
    if not api or InCombatLockdown() then return end
    for id in pairs(ids) do
        local ok, d = pcall(api, "player", id)
        if ok and type(d) == "table" and not isSecret(d) then
            identity[id] = { spell = SafeField(d, "spellId"), name = SafeField(d, "name"), dur = SafeField(d, "duration"), t0 = GetTime() }
            Stream(string.format("%.3f o HAVE id=%s spell=%s name=%s dur=%s", GetTime(), tostring(id),
                tostring(identity[id].spell), tostring(identity[id].name), tostring(identity[id].dur)))
        end
    end
end

local function OnUnitAura(info)
    local st = InCombatLockdown() and "combat" or "ooc"
    StreamAura(info, st == "combat")
    pcall(StreamIdentity, info)
    uaCount[st] = uaCount[st] + 1
    if uaLogged[st] >= UA_MAX then return end
    uaLogged[st] = uaLogged[st] + 1
    local tag = (st == "combat" and "COMBAT" or "ooc") .. " UNIT_AURA #" .. uaCount[st]
    local out = { "payload " .. Sec(info) }
    if type(info) == "table" and not isSecret(info) then
        local function Field(name)
            local ok, v = pcall(function() return info[name] end)
            if not ok then return nil, "error" end
            return v
        end
        local full = Field("isFullUpdate")
        out[#out + 1] = "isFullUpdate=" .. Sec(full)
        for _, name in ipairs({ "addedAuras", "updatedAuraInstanceIDs", "removedAuraInstanceIDs" }) do
            local v = Field(name)
            local n = "?"
            if type(v) == "table" and not isSecret(v) then
                local okn, c = pcall(function() return #v end); n = okn and tostring(c) or "err"
            end
            out[#out + 1] = name .. "=" .. Sec(v) .. " n=" .. n
        end
        -- first added aura: its ID, its data, a duration object from its ID
        local added = Field("addedAuras")
        if type(added) == "table" and not isSecret(added) then
            local okf, first = pcall(function() return added[1] end)
            if okf and type(first) == "table" and not isSecret(first) then
                local okid, id = pcall(function() return first.auraInstanceID end)
                local oksp, sp = pcall(function() return first.spellId end)
                out[#out + 1] = "added[1].auraInstanceID=" .. (okid and Sec(id) or "error") .. " spellId=" .. (oksp and Sec(sp) or "error")
                if okid and id ~= nil then
                    -- can a secret ID be used as a table key (needed for tracking)?
                    local okk = pcall(function() local t = {}; t[id] = true; return t[id] end)
                    out[#out + 1] = "usable as table key=" .. tostring(okk)
                    out[#out + 1] = DurationTest(id)
                end
            else
                out[#out + 1] = "added[1]=" .. (okf and Sec(first) or "error")
            end
        end
        -- removed IDs: the early-removal signal, if readable
        local removed = Field("removedAuraInstanceIDs")
        if type(removed) == "table" and not isSecret(removed) then
            local okr, r1 = pcall(function() return removed[1] end)
            if okr and r1 ~= nil then out[#out + 1] = "removed[1]=" .. Sec(r1) end
        end
        local upd = Field("updatedAuraInstanceIDs")
        if type(upd) == "table" and not isSecret(upd) then
            local oku, u1 = pcall(function() return upd[1] end)
            if oku and u1 ~= nil then out[#out + 1] = "updated[1]=" .. Sec(u1) .. " | " .. DurationTest(u1) end
        end
    end
    Log(tag .. ": " .. table.concat(out, "; "))
end

local f = CreateFrame("Frame")
f:SetScript("OnEvent", function(_, event, unit, a, b)
    if not armed or unit ~= "player" then return end
    if event == "UNIT_AURA" then
        local okU, errU = pcall(OnUnitAura, a)
        if not okU then Log("UNIT_AURA handler error: " .. tostring(errU):sub(1, 120)) end
        return
    end
    if event == "UNIT_SPELLCAST_SENT" then
        before = Snap()
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local spell = b
        if isSecret(spell) then Log((InCombatLockdown() and "COMBAT" or "ooc") .. " cast spell ID is SECRET (cannot link)"); return end
        stats.casts = stats.casts + 1
        if type(spell) == "number" then Stream(string.format("%.3f CAST %d", GetTime(), spell)) end
        if not before then before = Snap() end
        AfterCast(spell, 0.15); AfterCast(spell, 0.6)
    end
end)

local function Arm(on)
    if on == armed then return end
    armed = on
    if on then
        if f.RegisterUnitEvent then   -- player casts only (all units woke this for every nearby cast)
            f:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
            f:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        else
            f:RegisterEvent("UNIT_SPELLCAST_SENT")
            f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
        end
        f:RegisterUnitEvent("UNIT_AURA", "player")
        uaLogged, uaCount = { ooc = 0, combat = 0 }, { ooc = 0, combat = 0 }
        flagTotals = { A = 0, U = 0, R = 0, n = 0 }
        if _G.CueRulesDB then _G.CueRulesDB.idProbeStream = {} end
        local have = {}
        for _, n in ipairs(CANDIDATES) do
            have[#have + 1] = n .. "=" .. ((C_UnitAuras and C_UnitAuras[n]) and "yes" or "no")
        end
        Log("ARMED. C_UnitAuras functions: " .. table.concat(have, ", "))
        tracked, before, lastCount, lastCombat, detailDone = {}, nil, nil, nil, {}
        identity = {}
        do local s0 = Snap(); if not s0.err and not s0.combat then pcall(StreamHave, s0.ids) end end
        Poll()
        ticker = C_Timer.NewTicker(1, Poll)
        Log("Now fight with a buff active: cast Metamorphosis (and Demon Spikes / Immolation Aura), let one fall off, then cancel one early. /xui probe ids to stop, then /reload to save.")
        Log("0.5.27: out of combat the stream also records each aura added/removed (spell, name, duration, lifetime). For identity ground truth, run the same casts once with NO combat, then once in combat.")
    else
        f:UnregisterAllEvents()
        if ticker then ticker:Cancel(); ticker = nil end
        Log(string.format("UNIT_AURA events seen: out of combat %d, in combat %d", uaCount.ooc, uaCount.combat))
        Log(string.format("in combat, events carrying: added %d, updated %d, removed %d (of %d)", flagTotals.A, flagTotals.U, flagTotals.R, flagTotals.n))
        Log(string.format("DISARMED. casts seen %d, ID links made %d, linked IDs seen vanishing %d. /reload to write the log to disk.",
            stats.casts, stats.linked, stats.gone))
    end
end

function ns.IDProbe(arg)
    arg = (arg or ""):lower()
    if arg == "log" then
        local db = _G.CueRulesDB
        local n = db and db.idProbe and #db.idProbe or 0
        ns.Print("[idprobe] " .. n .. " saved lines")
        for i = math.max(1, n - 25), n do ns.Print(db.idProbe[i]) end
    elseif arg == "off" then Arm(false)
    elseif arg == "on" then Arm(true)
    else Arm(not armed) end
end
