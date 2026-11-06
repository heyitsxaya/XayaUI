-------------------------------------------------------------------------------
-- CoreDebug.lua (XayaUI Dev Assist 0.7.5): XayaUI's developer diagnostics, moved out of the addons players run.
-- Xaya, 2026-11-06 (REQUEST-LOG #81, her answers in the feature update summary session, FUS-4): developer diagnostics "Move all of
-- them"; edge cases "Yes, as recommended" (players keep /xui debug perf, the console forms /xui debug status and /xui debug auras, and
-- /xuiengine full and refresh); /xuiskin "move pad and alpha to dev". Plan: docs/plans/DEBUG-TO-DEVASSIST-2026-11-06.md, rows A2-A19, C3.
-- What is here, each registered into XayaUI's own command lists (Modules.lua), so without this addon they and their help lines do not
-- exist and XayaUI does not load their code (V14's strict level: an addon that is off or not installed is never read):
--   /xui debug probe <spellID>, probe ids (AuraIDProbe.lua), timing, model, tracker, mods, groups, icons, media, seed, map, debuffs,
--   loc, gamemenu, chatprobe (ChatProbe.lua), widthprobe (CharacterWidthProbe.lua), perf ui;
--   /xuitt aura | probe | lines;  /xui chat wrap | indent | whispers;  /xuiskin pad N | alpha X;  /xuiengine auto | on | off | reset.
-- The code is XayaUI's own, moved as it was (same output); where it read a file's private state, that file now hands it over through
-- one read-only accessor (ns.VisualProbeState, ns.GameMenu_DiagState, ns.GameMenuSkin_DiagState, ns.MapTraceOrder, AuraTracker T.states
-- and T.DB, AuraDisplay D.DB and D.FindFolder, Tooltips TT.SpellNameOf and TT.NpcIDFromGUID). Nothing here runs until it is typed,
-- except the whisper counters of /xui chat whispers (counted while the Chat Panel is on, as before).
-------------------------------------------------------------------------------
local ns = rawget(_G, "XayaUI_NS")
if type(ns) ~= "table" or type(ns.RegisterDebugCommand) ~= "function" then return end   -- XayaUI is off or too old: nothing to add to
local GDD = {}
ns.DevAssistDebug = GDD   -- (tests)
local issecret = issecretvalue or function() return false end
-- Boolean API: true / false, or nil when the call failed or the answer is secret. (A game nil counts as false.) (as in Triggers.lua)
local function Bool(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, r = pcall(fn, ...)
    if not ok or issecret(r) then return nil end
    return r and true or false
end
local function Field(t, k)
    if type(t) ~= "table" then return nil end
    local ok, v = pcall(function() return t[k] end)
    if not ok or issecret(v) then return nil end
    return v
end

-- What the feature addons offer these reports, through XayaUI's service list (Modules.lua ns.Provide / ns.Service): nil while that addon
-- is off or not installed
local function Svc(name) return ns.Service and ns.Service(name) or nil end
local function ChatC() local v = Svc("chatDebug"); return v and v.C end
local function ChatSettings() local v = Svc("chatDebug"); return v and v.Settings and v.Settings() end
local function TTof() local v = Svc("tooltipsDebug"); return v and v.TT end

-------------------------------------------------------------------------------
-- /xui debug probe <spellID> (was core's Conditions.lua)
-------------------------------------------------------------------------------

local function Show(v)
    if v == nil then return "nil" end
    if issecret(v) then return "<SECRET>" end
    return tostring(v)
end

local function Probe(spellID)
    if not spellID then ns.Print("usage: /xui debug probe <spellID>") return end
    ns.Print("probe spell " .. spellID
        .. "  (auras secret now? " .. Show(C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret()) .. ")")
    local ok, cd = pcall(C_Spell.GetSpellCooldown, spellID)
    if ok and type(cd) == "table" then
        for _, k in ipairs({ "isActive", "isOnGCD", "isEnabled", "duration", "startTime" }) do
            ns.Print("  cooldown." .. k .. " = " .. Show(cd[k]))
        end
    else
        ns.Print("  GetSpellCooldown failed/nil")
    end
    local okc, ch = pcall(C_Spell.GetSpellCharges, spellID)
    if okc and type(ch) == "table" then
        for _, k in ipairs({ "isActive", "maxCharges", "currentCharges" }) do
            ns.Print("  charges." .. k .. " = " .. Show(ch[k]))
        end
    else
        ns.Print("  GetSpellCharges nil (not a charge spell)")
    end
    local present, src = ns.BuffPresent(spellID)
    ns.Print("  as a BUFF id -> present=" .. Show(present) .. " via " .. src)
    ns.Print("  aura reads restricted now: " .. tostring(ns.AurasRestricted())
        .. " | this spell's aura NeverSecret: " .. tostring(ns.AuraTrackable(spellID)))
    if C_Secrets and C_Secrets.ShouldCooldownsBeSecret then
        local okk, cv = pcall(C_Secrets.ShouldCooldownsBeSecret)
        ns.Print("  cooldown reads restricted now: " .. Show(okk and cv or "error"))
    end
end

-- /xui debug debuffs [target|focus]: shows exactly what the game lets us read about your debuffs on that unit right now.
-- Fallback net for "a debuff I put on the target": look the aura up BY NAME with the engine-enforced ownership filter.
-- Returns "found" | "none" | "secret" | "error: <text>". Whether it works in combat is what /xui debug debuffs reports.
local function TargetAuraByName(unit, id)
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName and C_Spell and C_Spell.GetSpellName) then return "api missing" end
    local okn, nm = pcall(C_Spell.GetSpellName, id)
    if not okn or type(nm) ~= "string" or issecret(nm) or nm == "" then return "no spell name" end
    local ok, a = pcall(C_UnitAuras.GetAuraDataBySpellName, unit, nm, "HARMFUL|PLAYER")
    if not ok then return "error: " .. tostring(a):gsub("^.-:%d+: ", "") end
    if a == nil then return "none" end
    if issecret(a) then return "secret" end
    if type(a) == "table" then return "found" end
    return "none"
end
local function ProbeDebuffs(arg)
    -- "/xui debug debuffs", "/xui debug debuffs focus", "/xui debug debuffs 204598", "/xui debug debuffs target 204598"
    local word, num = tostring(arg or ""):match("^%s*(%a*)%s*(%d*)")
    if word == "" and num == "" then num = tostring(arg or ""):match("(%d+)") or "" end
    local unit = (word == "focus") and "focus" or "target"
    ns.probeDebuffID = tonumber(num)
    ns.Print(("debuff probe: unit=%s exists=%s inCombat=%s"):format(unit, tostring(Bool(UnitExists, unit)), tostring(Bool(UnitAffectingCombat, "player"))))
    if not (C_UnitAuras and C_UnitAuras.GetUnitAuras) then ns.Print("  C_UnitAuras.GetUnitAuras is missing") return end
    local ok, err = pcall(function()
        local list = C_UnitAuras.GetUnitAuras(unit, "HARMFUL|PLAYER")
        if issecret(list) then ns.Print("  the returned list itself is SECRET (nothing readable)") return end
        if type(list) ~= "table" then ns.Print("  returned " .. type(list)) return end
        ns.Print("  entries returned: " .. #list)
        for i = 1, math.min(#list, 12) do
            local a = list[i]
            local sid, nm, fp = Field(a, "spellId"), Field(a, "name"), Field(a, "isFromPlayerOrPlayerPet")
            ns.Print(("  %d: spellId=%s name=%s fromPlayer=%s"):format(i, sid == nil and "SECRET" or tostring(sid), nm == nil and "SECRET" or tostring(nm), tostring(fp)))
        end
    end)
    if not ok then ns.Print("  the call failed: " .. tostring(err)) end
    ns.Print("  by-name lookup: use /xui debug debuffs <unit> <spellID>  ->  " .. (ns.probeDebuffID and tostring(TargetAuraByName(unit, ns.probeDebuffID)) or "give a spell ID, e.g. /xui debug debuffs target 204598"))
end

-- /xui debug loc: prints what the game reports right now (to learn the real locType names)
local function ProbeLossOfControl()
    local LOC = C_LossOfControl
    if not (LOC and LOC.GetActiveLossOfControlDataCount) then ns.Print("loss of control: API missing"); return end
    local okc, n = pcall(LOC.GetActiveLossOfControlDataCount)
    if not okc or issecret(n) then ns.Print("loss of control: count unreadable"); return end
    ns.Print("loss of control effects on you: " .. tostring(n))
    for i = 1, (tonumber(n) or 0) do
        local ok, d = pcall(LOC.GetActiveLossOfControlData, i)
        if ok and type(d) == "table" and not issecret(d) then
            local lt = issecret(d.locType) and "<secret>" or tostring(d.locType)
            ns.Print(("  %d: locType=%s spellID=%s text=%s"):format(i, lt, issecret(d.spellID) and "<secret>" or tostring(d.spellID), issecret(d.displayText) and "<secret>" or tostring(d.displayText)))
        else ns.Print("  " .. i .. ": unreadable") end
    end
end

local TIME_REFS = { ["n:buffRemain"] = "aura time left", ["n:cdRemain"] = "cooldown time left", ["n:buffStacks"] = "aura stacks", ["n:cdCharges"] = "charges" }

local function Needs(p)
    local needs = {}
    for _, c in ipairs(ns.ConditionsOf and ns.ConditionsOf(p) or {}) do
        if c.enabled ~= false and type(c.when) == "table" and type(c.when.list) == "table" then
            for _, t in ipairs(c.when.list) do if TIME_REFS[t.ref] then needs[t.ref] = true end end
        end
    end
    local displays = { p }
    for _, c in ipairs(ns.CuesOf and ns.CuesOf(p) or {}) do displays[#displays + 1] = c end
    for _, d in ipairs(displays) do
        local v = d.visual
        if v and v.enabled then
            if (v.text and v.text.enabled) or (v.fill and v.fill.enabled) or v.fadeGrey or v.fadeAlpha or (v.flash and v.flash.enabled) then
                needs.display = needs.display or d
            end
            if v.count and v.count.enabled then needs.displayCount = true end
            -- 12.1.5: the shield amount is always secret; the game helper that hides a zero cannot also abbreviate
            local ab = v.absorb
            if ab and ab.enabled and ab.abbreviate ~= false and ab.hideZero then needs.absorbZero = true end
        end
    end
    return needs
end

-- One line per rule; nothing is left unsaid. (/xui debug timing)
local function TimingReport()
    local P = ns.Print or print
    local rows, ok, warn = {}, 0, 0
    for _, p in ipairs(ns.rules or {}) do
        if not p.parentUid and p.enabled ~= false then
            local needs = Needs(p)
            if next(needs) then
                local parts, bad = {}, false
                local buff = tonumber(p.buffID) or 0
                local spell = tonumber(p.spellID) or 0
                local owned = ns.EngineOwns and needs.display and ns.EngineOwns(needs.display)
                if needs.display then
                    if owned then parts[#parts + 1] = "display: drawn by the game (exact)"
                    else parts[#parts + 1] = "display: XayaUI, using the time below" end
                end
                if needs["n:buffRemain"] or (needs.display and not owned) then
                    if buff == 0 then
                        local row
                        for _, t in ipairs(type(p.extra) == "table" and type(p.extra.list) == "table" and p.extra.list or {}) do
                            if type(t) == "table" and (t.type == "buffAura" or t.type == "targetDebuff") then row = t.type; break end
                        end
                        if not row and spell ~= 0 then parts[#parts + 1] = "display time: the spell's cooldown, counted down by the game (exact, in combat too)"
                        elseif not row then parts[#parts + 1] = "aura time: no aura on this rule"
                        elseif owned then parts[#parts + 1] = "aura time: from its aura trigger row, drawn by the game (exact)"
                        else parts[#parts + 1] = "aura time: from its " .. (row == "targetDebuff" and "Target Debuff" or "Buff / Aura") .. " row out of combat; hidden in combat (the combat engine draws it only when that row is the rule's only trigger)" end
                    elseif ns.AuraTrackable and ns.AuraTrackable(buff) then parts[#parts + 1] = "aura time: exact (the game never hides this aura)"
                    else
                        local inCDM = ns.FindCDMFrame and ns.FindCDMFrame(buff)
                        local L = ns.Timing.LearnedAura()
                        local learned = L and L[buff]
                        if not inCDM then bad = true; parts[#parts + 1] = "aura time: NOT in combat - add this buff to Blizzard's Cooldown Manager (Tracked Buffs)"
                        elseif not learned then bad = true; parts[#parts + 1] = "aura time: needs the buff once out of combat to measure its length"
                        else parts[#parts + 1] = string.format("aura time: estimate from the exact start + measured %.1fs", learned) end
                    end
                end
                if needs["n:cdRemain"] then
                    local Lc = ns.Timing.LearnedCooldown()
                    if spell == 0 then parts[#parts + 1] = "cooldown time: no spell on this rule"
                    elseif not (ns.FindCDMFrame and ns.FindCDMFrame(spell)) then bad = true; parts[#parts + 1] = "cooldown time: NOT in combat if hidden - add the spell to the Cooldown Manager"
                    elseif not (Lc and Lc[spell]) then bad = true; parts[#parts + 1] = "cooldown time: needs one use out of combat to measure it"
                    else parts[#parts + 1] = string.format("cooldown time: exact when shown, else estimate (measured %.1fs)", Lc[spell]) end
                end
                if needs["n:buffStacks"] then bad = true; parts[#parts + 1] = "aura stacks: the game hides stack counts in combat, so a condition on stacks cannot fire there (the display still shows them)" end
                if needs["n:cdCharges"] then parts[#parts + 1] = "charges: exact out of combat; in combat counted from your casts (exact at 0, full, and for 2-charge spells; 3+ charges need the spell in the Cooldown Manager)" end
                if needs.absorbZero then parts[#parts + 1] = "shield amount: a zero shows as '0' (the game hides the amount and cannot both abbreviate and hide a zero; switch Abbreviate off to hide zeros)" end
                if bad then warn = warn + 1 else ok = ok + 1 end
                rows[#rows + 1] = { bad, tostring(p.name) .. ": " .. table.concat(parts, "; ") }
            end
        end
    end
    P(string.format("timing in combat: %d rule%s covered, %d need%s attention.", ok, ok == 1 and "" or "s", warn, warn == 1 and "s" or ""))
    for _, r in ipairs(rows) do if r[1] then P("  ! " .. r[2]) end end
    for _, r in ipairs(rows) do if not r[1] then P("    " .. r[2]) end end
end

-------------------------------------------------------------------------------
-- /xui debug tracker (was core's Combat/AuraTracker.lua)
-------------------------------------------------------------------------------
do
local T = ns.AuraTracker or {}   -- (core's combat files load before this addon; {} only in a stand-in without them)
local S, cap, stats, DB, ResetAll = T.states or {}, T.cap or {}, T.stats or {}, T.DB, T.ResetAll
local function Model() return ns.AuraModel end
local tsort = table.sort
local function P(...) if ns.Print then ns.Print(...) else print(...) end end

local function AuraName(id)
    local M = Model()
    return (M and M.SpellName and M.SpellName(id)) or ("spell " .. id)
end

local function Status()
    local now = GetTime()
    P(("aura tracker | %s | ID diff %s | aura IDs in combat: %s%s | spell ID of an ID in combat: %s"):format(
        T.Enabled() and "ON" or "OFF", T.IdDiffEnabled() and "ON" or "OFF", cap.ids or "untested",
        cap.note and (" (" .. cap.note .. ")") or "", cap.dataSpell or "untested"))
    P(("  links made %d, lost %d, dropped %d, too noisy %d, refused %d | consumers fired %d | list reads %d"):format(
        stats.linksMade, stats.linksLost, stats.linksDropped, stats.noisy, stats.refused, stats.consumed, stats.snaps))
    local ids = {}
    for id, s in pairs(S) do if now - (s.queriedAt or 0) < 120 then ids[#ids + 1] = id end end
    tsort(ids)
    if #ids == 0 then P("  no aura has been asked about in the last 2 minutes") end
    local M = Model()
    for _, id in ipairs(ids) do
        local s = S[id]
        local bits = { s.lastKind or "-" }
        if s.exact then
            bits[#bits + 1] = ("exact %s %.0fs ago"):format(s.exact.present and "present" or "absent", now - s.exact.t)
        end
        local win = M and M.WindowFor and M.WindowFor(id)
        if win then bits[#bits + 1] = ("model window %.1fs left"):format(math.max(0, win.expiry - now)) end
        if s.link then
            bits[#bits + 1] = ("link %d id (%s)%s confirmed %d"):format(s.link.n, s.link.q, s.link.lost and " LOST" or "", s.link.confirmed or 0)
        end
        local d = DB()
        local r = d and d.shadow[id]
        if r and (r.eps or 0) > 0 then
            bits[#bits + 1] = ("shadow %d ok / %d early / %d ext"):format(r.ok or 0, r.earlyMissed or 0, r.extMissed or 0)
        end
        P(("  [%d] %s: %s"):format(id, AuraName(id), table.concat(bits, " | ")))
    end
end

local function ShadowReport()
    local d = DB()
    if not d then return end
    local ids = {}
    for id in pairs(d.shadow) do ids[#ids + 1] = id end
    tsort(ids)
    if #ids == 0 then P("no shadow records yet (they accrue when an estimate is later checked against an exact read)"); return end
    for _, id in ipairs(ids) do
        local r = d.shadow[id]
        local err = (r.expErrN or 0) > 0 and ("%.2fs avg / %.2fs max"):format(r.expErrSum / r.expErrN, r.expErrMax or 0) or "n/a"
        P(("[%d] %s: episodes %d ok %d | early removal missed %d (avg %.1fs) | extension missed %d | expiry error %s | ID gone %d (early %d on time %d) | link mismatch %d false-gone %d")
            :format(id, AuraName(id), r.eps or 0, r.ok or 0, r.earlyMissed or 0,
                (r.earlyMissed or 0) > 0 and (r.earlyMissedBy / r.earlyMissed) or 0, r.extMissed or 0, err,
                r.idGone or 0, r.idGoneEarly or 0, r.idGoneOnTime or 0, r.linkMismatch or 0, r.linkFalseGone or 0))
    end
end

local function TrackerCommand(arg)
    arg = (arg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, rest = arg:match("^(%S+)%s*(.-)$")
    cmd = cmd and cmd:lower() or ""
    if cmd == "" or cmd == "status" then Status()
    elseif cmd == "on" or cmd == "off" then T.SetSetting("enabled", cmd == "on"); P("aura tracker " .. cmd:upper())
    elseif cmd == "id" then
        local v = rest:lower()
        if v == "on" or v == "off" then T.SetSetting("idDiff", v == "on"); P("ID diff " .. v:upper())
        else P("usage: /xui debug tracker id on|off") end
    elseif cmd == "shadow" then ShadowReport()
    elseif cmd == "reset" then ResetAll("manual"); cap.ids = nil; P("tracker state cleared")
    elseif cmd == "consumer" then
        local a, b = rest:match("^(%S+)%s*(%S*)")
        if a == "clear" and tonumber(b) then T.ClearConsumer(tonumber(b)); P("consumers cleared for cast " .. b)
        elseif tonumber(a) and tonumber(b) then T.AddConsumer(tonumber(a), tonumber(b)); P(("cast %s now ends aura %s"):format(a, b))
        else P("usage: /xui debug tracker consumer <castSpellID> <auraID> | consumer clear <castSpellID>") end
    else
        P("commands: /xui debug tracker [status | on | off | id on|off | shadow | reset | consumer <cast> <aura>]")
    end
end
GDD.TrackerCommand = TrackerCommand
end

-------------------------------------------------------------------------------
-- /xui debug model (was core's Combat/AuraModel.lua)
-------------------------------------------------------------------------------
do
local M = ns.AuraModel or {}
local ctx, stats, Profile = M.ctx or {}, M.stats or {}, M.Profile
local function P(...) if ns.Print then ns.Print(...) else print(...) end end

local function Explain(id)
    local r = M.Resolve(id)
    local nm = M.SpellName(id) or ("spell " .. id)
    P(string.format("%s (%d): %s", nm, id, r.seconds and string.format("%.1f s [%s, %s confidence]", r.seconds, r.source, r.confidence) or "no duration known"))
    if r.castID and r.castID ~= id then P("  cast by spell " .. r.castID .. " (" .. (M.SpellName(r.castID) or "?") .. ")") end
    if r.base then P(string.format("  text says %.1f s; model %.1f s", r.base, r.modeled or r.base)) end
    for _, m in ipairs(r.listed or {}) do
        P(string.format("  %s [%s] %s %s%.1f%s -- \"%s\"", m.baked and "already in the text" or ("NOT modeled (" .. (m.conditional or ""):gsub("%s+$", "") .. ")"),
            m.kind, m.srcName, m.amount >= 0 and "+" or "", m.amount, m.op == "pct" and "%" or " s", m.sentence:sub(1, 130)))
    end
    for _, n in ipairs(r.notes or {}) do P("  note: " .. n) end
end

local function ModelCommand(arg)
    arg = (arg or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local cmd, rest = arg:match("^(%S+)%s*(.-)$")
    cmd = cmd and cmd:lower() or ""
    if cmd == "" or cmd == "status" then
        if not ctx.sig then M.Refresh() end
        local p = Profile(false)
        local n = 0; if p and p.entries then for _ in pairs(p.entries) do n = n + 1 end end
        P(string.format("combat tracking model | %s | loadout %s | presence estimate %s | setup %s | learned entries %d",
            ctx.key or "?", ctx.sig or "?", M.PresenceEnabled() and "ON" or "OFF", (p and p.setupDone) and "done" or "NOT done (/xui debug model setup)", n))
        P(string.format("  casts readable %d, secret %d | windows opened %d, skipped %d | estimates served %d | learned this session %d",
            stats.castsReadable, stats.castsSecret, stats.windowsOpened, stats.windowsSkipped, stats.estimatesServed, stats.learned))
        P("  /xui debug model <spellID> | setup | on | off | override <spellID> <seconds|clear> | rescan")
    elseif cmd == "setup" then
        if ns.AuraSetup_Open then ns.AuraSetup_Open() else P("setup window is not loaded") end
    elseif cmd == "on" or cmd == "off" then
        M.SetSetting("presence", cmd == "on"); P("presence estimate " .. cmd:upper())
    elseif cmd == "rescan" then
        M.ClearTextCache(); M.Refresh(); P("rescanned loadout: " .. tostring(ctx.sig))
    elseif cmd == "override" then
        local id, v = rest:match("^(%d+)%s+(%S+)")
        id = tonumber(id)
        if not id then P("usage: /xui debug model override <spellID> <seconds|clear>"); return end
        if v == "clear" then M.SetOverride(id, nil); P("override cleared for " .. id)
        elseif tonumber(v) then M.SetOverride(id, tonumber(v)); P("override " .. id .. " = " .. v .. " s")
        else P("usage: /xui debug model override <spellID> <seconds|clear>") end
    elseif tonumber(cmd) then
        if not ctx.sig then M.Refresh() end
        Explain(tonumber(cmd))
    else
        P("unknown /xui debug model command")
    end
end
GDD.ModelCommand = ModelCommand
end

-- /xui debug mods: for every cue that a condition lists, print each step: which conditions list it and whether they are TRUE / FALSE / UNKNOWN right now,
-- the modifiers each one stores, the merged result the engine hands to the visual, and what the cue's frame actually shows.
local function ProbeMods()
    -- (core 0.6.50: through ns.Print, so /xui debug mods typed in the console window prints there; was print())
    local function P(...) ns.Print("|cff9966ffmods|r", ...) end
    local function TF(v) return v == true and "|cff55ff55TRUE|r" or v == false and "|cffff5555FALSE|r" or "|cffffd100UNKNOWN|r" end
    local function M(m)
        if type(m) ~= "table" then return "no modifiers stored" end
        local t = {}
        t[#t + 1] = "box " .. ((m.on == false) and "UNTICKED" or "ticked")
        if m.tint then t[#t + 1] = ("tint %.2f/%.2f/%.2f/%.2f"):format(m.tint[1] or 0, m.tint[2] or 0, m.tint[3] or 0, m.tint[4] or 0) end
        if m.desat ~= nil then t[#t + 1] = "desat " .. tostring(m.desat) end
        if m.glow ~= nil then t[#t + 1] = "glow " .. tostring(m.glow) end
        if m.alpha ~= nil then t[#t + 1] = ("opacity %.0f%%"):format(m.alpha * 100) end
        if m.strata then t[#t + 1] = "strata " .. m.strata end
        return table.concat(t, ", ")
    end
    local ctx = ns.ReadContext()
    local any = false
    for _, p in ipairs(ns.rules or {}) do
        if not p.parentUid then
            for _, cue in ipairs(ns.CuesOf(p)) do
                local listed = {}
                for _, c in ipairs(ns.ConditionsOf(p)) do
                    for _, k in ipairs(type(c.thenCues) == "table" and c.thenCues or {}) do if k == cue.cueKey then listed[#listed + 1] = c end end
                end
                if #listed > 0 then
                    any = true
                    P(("rule '%s' > cue '%s' (%s, key %s, rule %s, cue %s)"):format(tostring(p.name), tostring(cue.cueName or cue.name), tostring(cue.cueKind), tostring(cue.cueKey), p.enabled and "on" or "OFF", cue.enabled and "on" or "OFF"))
                    for _, c in ipairs(listed) do
                        local okc, res = pcall(ns.Evaluate, c, ctx)
                        P(("   condition '%s' (%s): %s;  %s"):format(tostring(c.name), c.enabled == false and "DISABLED" or "enabled", okc and TF(res) or "ERROR", M(type(c.thenMods) == "table" and c.thenMods[cue.cueKey] or nil)))
                    end
                    local ok, hit, info = pcall(ns.EvaluateCue, cue, ctx)
                    P(("   engine result for the cue: %s;  merged modifiers: %s"):format(ok and TF(hit) or "ERROR", (ok and info and info.mods) and M(info.mods) or "none"))
                    local fs = ns.VisualDebug and ns.VisualDebug(cue)
                    if fs then
                        P(("   frame now: %s, alpha %s, strata %s, color %s, desaturation %s, glow %s"):format(fs.shown and "shown" or "hidden", tostring(fs.alpha and ("%.2f"):format(fs.alpha)), tostring(fs.strata),
                            fs.color and ("%.2f/%.2f/%.2f/%.2f"):format(fs.color[1], fs.color[2], fs.color[3], fs.color[4]) or "?", tostring(fs.desat), tostring(fs.glow)))
                    else P("   frame now: none yet (the cue has never been shown this session)") end
                end
            end
        end
    end
    if not any then P("no condition lists a cue yet (a condition's THEN row must list a display cue for modifiers to matter)") end
end

-- /xui debug groups: what each group holds and where its displays really hang, so "the group setting does nothing" can be told apart from
-- "the display is not attached to the group". Read-only.
local function ProbeGroups()
    local frames, containers, DynAncestor = ns.VisualProbeState()
    ns.Print("group probe: every group with displays, its settings, and each display's attachment")
    local lines = 0
    for _, f in ipairs(ns.folders or {}) do
        local mine = {}
        for _, r in ipairs(ns.rules or {}) do
            if r.folder == f.id and r.visual and r.visual.enabled then mine[#mine + 1] = r end
        end
        if #mine > 0 then
            local c = containers[f.id]
            ns.Print(("|cffffd100%s|r  type=%s  W/H=%s/%s  scale=%s  alpha=%s  strata=%s  level=%s  rel=%s  X/Y=%s/%s  clip=%s  container=%s"):format(
                tostring(f.name), f.cType or "static", tostring(f.cW), tostring(f.cH), tostring(f.cScale), tostring(f.cAlpha),
                tostring(f.cStrata), tostring(f.cLevel), tostring(f.cRel), tostring(f.cX), tostring(f.cY), tostring(f.cClip),
                c and ("%dx%d scale %.2f"):format(c:GetWidth(), c:GetHeight(), c:GetScale()) or "not created yet"))
            for _, r in ipairs(mine) do
                if lines >= 60 then ns.Print("  ... (stopped at 60 lines)") return end
                lines = lines + 1
                local fr = frames[r]
                if fr then
                    local par = fr:GetParent()
                    local dyn = DynAncestor(r.folder)
                    ns.Print(("  %s: attached to group container=%s  effAlpha=%.2f  effScale=%.2f  strata=%s  shown=%s  dynamicLayout=%s%s"):format(
                        tostring(r.name or "?"), tostring(par == c), fr:GetEffectiveAlpha(), fr:GetEffectiveScale(), fr:GetFrameStrata(),
                        tostring(fr:IsShown()), dyn and tostring(dyn.name) or "no",
                        r.parentUid and "  (cue/outcome: follows its parent's group)" or ""))
                else
                    ns.Print(("  %s: no frame built yet"):format(tostring(r.name or "?")))
                end
            end
        end
    end
end

local function UserMediaReport()
    local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("XayaUI_Media")) or (IsAddOnLoaded and IsAddOnLoaded("XayaUI_Media"))
    if not loaded then
        ns.Print("XayaUI_Media is not loaded. Install the folder Interface\\AddOns\\XayaUI_Media and make sure it is enabled in the AddOns list, then /reload.")
        return
    end
    ns.MergeUserMedia()
    local m = _G.XayaUI_UserMedia
    ns.Print(("XayaUI_Media loaded: %d pictures, %d sounds listed in its UserMedia.lua (files themselves are not checked; a missing picture draws blank)."):format(
        m and #(m.graphics or {}) or 0, m and #(m.sounds or {}) or 0))
end

local function MapLines()
    local mapTrace, mapOrder = ns.MapTraceCounts(), ns.MapTraceOrder()
    local function S(v)
        if v == nil then return "?" end
        if issecretvalue and issecretvalue(v) then return "?" end
        if type(v) == "number" then return ("%.4g"):format(v) end
        return tostring(v)
    end
    local function Try(fn, ...) if type(fn) ~= "function" then return nil end; local ok, a, b = pcall(fn, ...); if ok then return a, b end end
    local function CV(name) local get = C_CVar and C_CVar.GetCVar or GetCVar; return S(Try(get, name)) end
    local out = {}
    local m = rawget(_G, "WorldMapFrame")
    if type(m) ~= "table" then
        out[#out + 1] = "world map: not loaded yet"
    else
        local w, h = Try(m.GetSize, m)
        local maxd = Try(m.IsMaximized, m)
        out[#out + 1] = ("world map: shown %s, maximized %s, size %s x %s, scale %s, effective scale %s"):format(S(Try(m.IsShown, m)),
            S(maxd), S(w), S(h), S(Try(m.GetScale, m)), S(Try(m.GetEffectiveScale, m)))
    end
    local rule = C_GameRules and Enum and Enum.GameRule and Enum.GameRule.MaximizeWorldMapDisabled
    out[#out + 1] = ("CVars: miniWorldMap %s (1 = opens small, 0 = opens full screen), questLogOpen %s, useUiScale %s, uiScale %s; game rule MaximizeWorldMapDisabled %s"):format(
        CV("miniWorldMap"), CV("questLogOpen"), CV("useUiScale"), CV("uiScale"), rule and S(Try(C_GameRules.IsGameRuleActive, rule)) or "?")
    local u = rawget(_G, "UIParent")
    if type(u) == "table" then
        local w, h = Try(u.GetSize, u)
        out[#out + 1] = ("UIParent: shown %s, size %s x %s, scale %s, effective scale %s"):format(S(Try(u.IsShown, u)), S(w), S(h),
            S(Try(u.GetScale, u)), S(Try(u.GetEffectiveScale, u)))
    end
    local slots = {}
    for _, k in ipairs({ "fullscreen", "left", "center", "right", "doublewide" }) do
        local f = Try(rawget(_G, "GetUIPanel"), k)
        local n = type(f) == "table" and Try(f.GetName, f) or nil
        slots[#slots + 1] = k .. " " .. (f and S(n or "(unnamed)") or "-")
    end
    out[#out + 1] = "Blizzard's panel slots: " .. table.concat(slots, ", ")
    if #mapOrder == 0 then
        out[#out + 1] = "XayaUI calls into Blizzard's panel layout since login: none"
    else
        local now = GetTime and GetTime() or 0
        for _, name in ipairs(mapOrder) do
            local t = mapTrace[name]
            out[#out + 1] = ("XayaUI since login: %s x%d (last %ds ago)"):format(name, t.n, math.floor(now - (t.last or now) + 0.5))
        end
    end
    return out
end
GDD.MapLines = MapLines   -- (tests)
local function MapReport()
    for _, l in ipairs(MapLines()) do ns.Print("map: " .. l) end
end

local function GameMenuDiagnostics()
    if not ns.GameMenu_DiagState then return end
    local diag, enabled, style = ns.GameMenu_DiagState()
    ns.Print(("game menu button: enabled=%s style=%s hooked=%s path=%s anchor=%s opens=%d paints=%d lastError=%s AddButton=%s InitButtons=%s"):format(
        tostring(enabled), style, tostring(diag.hooked), diag.path, diag.anchor, diag.opens, diag.paints, tostring(diag.lastError),
        tostring(GameMenuFrame and type(GameMenuFrame.AddButton) == "function"),
        tostring(GameMenuFrame and type(GameMenuFrame.InitButtons) == "function")))
    ns.Print("game menu sizes: " .. tostring(diag.sizes) .. "; height fit: " .. tostring(diag.fit) .. "; " .. tostring(diag.pad))
end

local function GameMenuSkinDiagnostics()
    local v = Svc("gameMenuSkinDiag")
    if not (v and v.State) then return end
    local c, diag, rows, ResolveSource = v.State()
    ns.Print(("game menu skin: on=%s mode=%s failed=%s built=%d rows=%d title found=%s lastError=%s"):format(
        tostring(c.skin), c.matchReal ~= false and "match (rows sit on the real buttons)" or "own layout", tostring(diag.failed), diag.built, diag.rows, tostring(diag.titleFound), tostring(diag.lastError)))
    for i, r in ipairs(rows) do
        if r:IsShown() and r.matchSrc then
            local okP, top = pcall(function() return r.matchSrc:GetTop() end)
            local okL, lx = pcall(function() return r.matchSrc:GetLeft() end)
            ns.Print(("  row %d '%s' sits on its real button (layoutIndex=%s, top=%s, left=%s)%s"):format(i, tostring(r.label), tostring(r.matchSrc.layoutIndex),
                okP and tostring(top and math.floor(top)) or "?", okL and tostring(lx and math.floor(lx)) or "?", r.isXui and " [XayaUI slot]" or ""))
        elseif r:IsShown() then
            if r.isXui then ns.Print(("  row %d '%s' -> XayaUI (opens the settings)"):format(i, tostring(r.label)))
            else
                local b = ResolveSource(r)
                local okT, t = pcall(function() return b and b:GetText() end)
                local okP, top = pcall(function() return b and b:GetTop() end)
                ns.Print(("  row %d '%s' -> real '%s' layoutIndex=%s top=%s"):format(i, tostring(r.label), okT and tostring(t) or "?", tostring(b and b.layoutIndex), okP and tostring(top and math.floor(top)) or "?"))
            end
        end
    end
    if GameMenuFrame and GameMenuFrame.buttonPool and GameMenuFrame.buttonPool.EnumerateActive then
        local n, names = 0, {}
        for b in GameMenuFrame.buttonPool:EnumerateActive() do
            n = n + 1; local ok, t = pcall(b.GetText, b); names[#names + 1] = ok and tostring(t) or "?"
        end
        ns.Print(("Blizzard entries (%d): %s"):format(n, table.concat(names, " | ")))
    else
        ns.Print("the Game Menu exposes no button pool on this client: the skin cannot read its entries.")
    end
end

local function SeedRules()
    local kit = SOUNDKIT and SOUNDKIT.RAID_WARNING and tostring(SOUNDKIT.RAID_WARNING) or ""
    local function base(name, spell, buff)
        local r = ns.NewRule()
        r.name = name
        r.spellID, r.buffID = spell, buff
        r.cdState, r.buffState, r.talentMode = "ready", "missing", "none"
        r.load.combat = "yes"
        r.sound.enabled = true
        r.sound.source, r.sound.value = "kit", kit
        return r
    end
    -- 1) Infernal Strike: FILO talent known, in combat, 2 charges, FILO shield NOT up -> sound + icon glow
    local a = base("Infernal Strike (FILO)", 189110, 1266619)
    a.talents, a.talentMode = { { id = 1266497, state = "known" } }, "all"
    a.visual.enabled, a.visual.kind, a.visual.glow, a.visual.trigger = true, "spellicon", true, "condition"
    a.visual.w, a.visual.h, a.visual.y, a.visual.additive = 64, 64, 120, false
    -- 2) Demon Spikes: 2 charges, buff missing, in combat -> repeat 1/s
    local b = base("Demon Spikes 2 charges", 203720, 203819)
    b.repeatSec = 1
    -- 3) Fiery Brand: 2 charges, buff missing, in combat -> repeat 1/s
    --    buffID 204021 is a PLACEHOLDER: confirm the player-buff spell ID in game.
    local c = base("Fiery Brand 2 charges", 204021, 204021)
    c.repeatSec = 1
    for _, r in ipairs({ a, b, c }) do ns.rules[#ns.rules + 1] = r end
    ns.RefreshAllVisuals()
    ns.MarkDirty()
    ns.Fire("CONFIG_CHANGED")
    ns.Print("seeded 3 rules. Pick your sounds in /xui. Fiery Brand buff ID is a placeholder.")
end

-------------------------------------------------------------------------------
-- /xuitt (was XayaUI_Bonus/TooltipsUI.lua and Tooltips.lua): read only; needs XayaUI Bonus Features
-------------------------------------------------------------------------------
local isSecret = issecret
local function readable(v) return v ~= nil and not isSecret(v) end
-- /xuitt aura [spellID]: what every aura source says for one spell (the spell under the mouse when no ID is given). Read only.
local function TTAuraReport(id)
    local TT = TTof()
    local function P(...) print("|cff9966ffXayaUI Tooltips|r", ...) end
    if not id then
        local ok, data = pcall(function() return GameTooltip:GetTooltipData() end)
        id = ok and type(data) == "table" and readable(data.id) and data.id or nil
    end
    id = tonumber(id)
    if not id then P("Hover a spell and run it from a macro (/run C_Timer.After(3, function() SlashCmdList.XUITT('aura') end)), or: /xuitt aura 258920"); return end
    local ver = C_AddOns and C_AddOns.GetAddOnMetadata and select(2, pcall(C_AddOns.GetAddOnMetadata, "XayaUI_Bonus", "Version"))
    local inCombat = InCombatLockdown and InCombatLockdown() and true or false
    P(("spell %d (%s); XayaUI Bonus %s; in combat: %s"):format(id, tostring(TT.SpellNameOf(id) or "?"), tostring(ver or "?"), inCombat and "yes" or "no"))
    if not TT.watching and TT.ResetCooldownLinks then TT.ResetCooldownLinks() end   -- (no spec-change event while IDs and Formulas are off)
    local link = TT.CooldownLinks()[id]
    if link then
        local t = {}
        for _, a in ipairs(link.auras) do t[#t + 1] = tostring(a) end
        P(("  Cooldown Manager: linked auras {%s}; buff tracker with its own ID: %s"):format(table.concat(t, ", "), link.own and "yes" or "no"))
    else
        P("  Cooldown Manager: no entry for this spell (not in your spec's Cooldown Manager list, or its data is not loaded)")
    end
    local okA, ad = pcall(function() return C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID and C_UnitAuras.GetPlayerAuraBySpellID(id) end)
    P("  aura with this ID on you now: " .. (not okA and "error" or ad == nil and (inCombat and "no answer (hidden in combat)" or "no") or isSecret(ad) and "hidden" or "yes"))
    local cast = {}
    if ns.AuraModel and ns.AuraModel.AurasForCast then
        local ok, list = pcall(ns.AuraModel.AurasForCast, id)
        if ok and type(list) == "table" then for _, a in ipairs(list) do cast[#cast + 1] = tostring(a.id) end end
    end
    local castSelf = ns.AuraModel and ns.AuraModel.CastAppliesSelf and select(2, pcall(ns.AuraModel.CastAppliesSelf, id))
    P(("  your recorded casts: auras {%s}; same-ID aura seen: %s"):format(table.concat(cast, ", "), castSelf == true and "yes" or "no"))
    local auras, same = TT.AurasFor("spell", id, nil)
    local t = {}
    if same then t[#t + 1] = tostring(id) .. " (same as the spell)" end
    for _, a in ipairs(auras) do t[#t + 1] = tostring(a.id) .. (a.name and (" " .. a.name) or "") .. TT.SourceText(a) end
    P("  tooltip shows: " .. (#t > 0 and table.concat(t, "; ") or "not known yet"))
end

-- /xuitt lines: dump the raw lines of the tooltip under the mouse (type, tooltipType, tooltipID) so the aura-ID source can be verified.
local function TTDumpLines()
    local TT = TTof()
    local function P(...) print("|cff9966ffXayaUI Tooltips|r", ...) end
    local ok, data = pcall(function() return GameTooltip:GetTooltipData() end)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then P("Hover an item or spell, then run it from a macro: /run C_Timer.After(3, function() SlashCmdList.XUITT('lines') end)"); return end
    P("tooltip type", tostring(readable(data.type) and data.type or "?"), "id", tostring(readable(data.id) and data.id or "?"), "lines", #data.lines)
    for i, ln in ipairs(data.lines) do
        if type(ln) == "table" and readable(ln.type) and (ln.type == ns.AuraSources.NestedType() or ln.tooltipID ~= nil) then
            P(i, "lineType", tostring(ln.type), "tooltipType", tostring(readable(ln.tooltipType) and ln.tooltipType or "?"),
              "tooltipID", tostring(readable(ln.tooltipID) and ln.tooltipID or "?"), tostring(readable(ln.leftText) and ln.leftText or ""))
        end
    end
end

local function TTProbe()
    local TT = TTof()
    local function P(...) print("|cff9966ffXayaUI Tooltips|r", ...) end
    local unit = "mouseover"
    if not UnitExists(unit) then
        P("Point at a unit, then run it from a macro or: /run C_Timer.After(3, function() SlashCmdList.XUITT('probe') end)")
        return
    end
    local function show(v) if v == nil then return "nil" elseif isSecret(v) then return "SECRET" else return tostring(v) end end
    local function try(label, fn)
        local ok, a, b, c = pcall(fn)
        if not ok then P(label, "ERROR", tostring(a)) else P(label, show(a), b ~= nil and show(b) or "", c ~= nil and show(c) or "") end
    end
    try("UnitGUID", function() return UnitGUID(unit) end)
    local okg, guid = pcall(UnitGUID, unit)
    P("NPC ID from GUID", okg and tostring(TT.NpcIDFromGUID(guid)) or "unreadable")
    try("UnitCanAttack", function() return UnitCanAttack("player", unit) end)
    try("UnitIsPlayer", function() return UnitIsPlayer(unit) end)
    try("Enemy forces (count, percent)", function() return C_ScenarioInfo.GetUnitCriteriaProgressValues(unit) end)
    try("CanInspect", function() return CanInspect(unit) end)
    P("IsInInstance type / M+ active", tostring((select(2, IsInInstance()))),
      tostring(C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive()))
end

-------------------------------------------------------------------------------
-- /xui chat indent, whispers, wrap (was XayaUI_Chat/Core.lua): read only; need XayaUI Chat
-------------------------------------------------------------------------------
-- /xui chat indent : READ ONLY. Where the empty space at the left of the chat text comes from. For the first visible lines it prints how far
-- the line's own box sits from the window's left edge, and the first characters of the line's text with every |-code shown as typed (a
-- timestamp or a hidden color / texture code in front of the words shows up there). Text the game marks secret is never read.
local function IndentReport()
    local C = ChatC()
    local cf, ta = C.Main(), C.TextArea()
    if not (cf and ta) then ns.Print("Chat Panel indent: the chat window is not there to measure."); return end
    local function f(v) v = tonumber(v); return (v and not C.IsSecret(v)) and ("%.1f"):format(v) or "?" end
    local function left(o) local ok, v = pcall(function() return o:GetLeft() end); return ok and tonumber(v) or nil end
    local cl, tl = left(cf), left(ta)
    local s = ChatSettings() or {}
    ns.Print(("Chat Panel indent: window left %s, text area left %s (setting: %s px), text area to window: %s px"):format(f(cl), f(tl), tostring(s.textInset), (cl and tl) and f(tl - cl) or "?"))
    local okI, cL, cR, cT, cB = pcall(function() return cf:GetClampRectInsets() end)
    local cl0 = C.Clamped(cf)
    ns.Print(("  clamped to the screen: %s; clamp margins left %s, right %s, top %s, bottom %s (a left margin pushes the window right at the screen edge)"):format(
        cl0 == nil and "unreadable" or (cl0 and "yes" or "no"), okI and f(cL) or "?", okI and f(cR) or "?", okI and f(cT) or "?", okI and f(cB) or "?"))
    local fmt
    if _G.Settings and _G.Settings.GetValue then local ok, v = pcall(_G.Settings.GetValue, "showTimestamps"); if ok and type(v) == "string" then fmt = v end end
    ns.Print(("  the game's timestamp setting: %s"):format(fmt and ("\"" .. fmt:gsub("|", "||") .. "\"") or "unreadable"))
    local function onoff(v) if v == nil then return "unreadable" end return v and "on" or "off" end
    local lines = cf.visibleLines
    ns.Print(("  indent wrapped lines: setting %s, the window's font %s, its first line %s"):format(onoff(s.wrapIndent ~= false), onoff(C.IndentOf(cf)),
        onoff(type(lines) == "table" and C.IndentOf(lines[1]) or nil)))
    if type(lines) ~= "table" or #lines == 0 then ns.Print("  no visible lines to measure (say something in chat first)"); return end
    local shown = 0
    for i = #lines, 1, -1 do
        local fs = lines[i]
        local txt = fs and fs.IsShown and fs:IsShown() and fs.GetText and fs:GetText() or nil
        if type(txt) == "string" and not C.IsSecret(txt) and txt ~= "" then
            local pre = txt:sub(1, 40):gsub("|", "||"):gsub("[%c]", "?")
            -- the start of a chat line can name another player: shown, never recorded or put in a report (Core.lua ns.PrintPrivate)
            local say = ns.PrintPrivate or ns.Print
            say(("  line %d: box left %s px from the window edge, text starts \"%s\""):format(i, (cl and left(fs)) and f(left(fs) - cl) or "?", pre))
            shown = shown + 1
            if shown >= 4 then break end
        end
    end
    if shown == 0 then ns.Print("  the visible lines are empty or protected") end
end

local function ChatIndent()   -- never raises: a game value that cannot be read ends the report with one line, not an error
    local ok, err = pcall(IndentReport)
    if not ok then ns.Print(("Chat Panel indent: could not finish (%s)"):format((tostring(err):gsub("|", "||")))) end
end

-- /xui chat whispers : READ ONLY. Why a whisper does or does not get a tab of its own (Xaya, 2026-11-04: "whispers are not shown as
-- their own tabs even though the option is enabled"). The tab is the game's: its whisper manager (FloatingChatFrameManager_OnEvent,
-- FloatingChatFrame.lua, wow-ui-source live 12.1.5.70783) opens one with FCF_OpenTemporaryWindow when a whisper arrives and the game's
-- setting Options > Social > New Whispers (CVar whisperMode) is "popout" (New Tab) or "popout_and_inline" (Both), and only when no tab
-- for that sender exists yet. The Chat Panel never opens, closes or hides those windows (no reason for a missing tab was found in its
-- code). The report counts, since the last /reload, the whispers that arrived and the whisper tabs the game opened, and the whisper
-- windows there are now. No name is read or printed. V14: counted only while the Chat Panel is on (the "whispers" part).
local WHISPER_IN = { CHAT_MSG_WHISPER = true, CHAT_MSG_BN_WHISPER = true }
local WHISPER_OUT = { CHAT_MSG_WHISPER_INFORM = true, CHAT_MSG_BN_WHISPER_INFORM = true }
local whispers = { got = 0, sent = 0, opened = 0 }
GDD.whispers = whispers   -- (tests)
local wdrv
local function IsWhisperType(t) return type(t) == "string" and not issecret(t) and (t == "WHISPER" or t == "BN_WHISPER") end
local function WhisperPart(C)
C.Part("whispers", function() return true end,
    function()
        if not wdrv then
            wdrv = CreateFrame("Frame")
            wdrv:SetScript("OnEvent", function(_, event)
                if WHISPER_IN[event] then whispers.got = whispers.got + 1
                elseif WHISPER_OUT[event] then whispers.sent = whispers.sent + 1 end
            end)
        end
        for ev in pairs(WHISPER_IN) do pcall(wdrv.RegisterEvent, wdrv, ev) end
        for ev in pairs(WHISPER_OUT) do pcall(wdrv.RegisterEvent, wdrv, ev) end
        C.HookOnce("whispers:open", "FCF_OpenTemporaryWindow", nil, function(chatType)
            if C.on.whispers and IsWhisperType(chatType) then whispers.opened = whispers.opened + 1 end
        end)
    end,
    function()
        if not wdrv then return end
        for ev in pairs(WHISPER_IN) do pcall(wdrv.UnregisterEvent, wdrv, ev) end
        for ev in pairs(WHISPER_OUT) do pcall(wdrv.UnregisterEvent, wdrv, ev) end
    end)
end

local WHISPER_MODES = { popout = "New Tab", inline = "In-line", popout_and_inline = "Both" }
local function WhisperFacts()
    local C = ChatC()
    local out = { got = whispers.got, sent = whispers.sent, opened = whispers.opened, docked = 0, floating = 0 }
    local get = (_G.C_CVar and _G.C_CVar.GetCVar) or _G.GetCVar
    if get then
        local ok, v = pcall(get, "whisperMode")
        if ok and type(v) == "string" and not issecret(v) then out.mode = v end
    end
    local mgr = _G.FloatingChatFrameManager
    local function listens(ev)
        if not (mgr and mgr.IsEventRegistered) then return nil end
        local ok, v = pcall(mgr.IsEventRegistered, mgr, ev)
        if not ok or issecret(v) then return nil end
        return v and true or false
    end
    out.listens, out.listensBN = listens("CHAT_MSG_WHISPER"), listens("CHAT_MSG_BN_WHISPER")
    for _, f in ipairs(C.Frames()) do
        if f.isTemporary and f.inUse and IsWhisperType(f.chatType) then
            if f.isDocked then out.docked = out.docked + 1 else out.floating = out.floating + 1 end
        end
    end
    local dock = _G.GENERAL_CHAT_DOCK
    out.inRow = (type(dock) == "table" and type(dock.DOCKED_CHAT_FRAMES) == "table") and #dock.DOCKED_CHAT_FRAMES or nil
    return out
end

local function WhisperReport()
    local w = WhisperFacts()
    local function yn(v) if v == nil then return "unreadable" end return v and "yes" or "no" end
    ns.Print(("Chat whispers: the game's setting Options > Social > New Whispers is %s"):format(
        w.mode and ("\"" .. (WHISPER_MODES[w.mode] or w.mode) .. "\" (whisperMode " .. w.mode .. ")") or "unreadable"))
    ns.Print(("  the game's whisper-tab manager listens for whispers: %s; for Battle.net whispers: %s"):format(yn(w.listens), yn(w.listensBN)))
    ns.Print(("  since the last /reload, while the Chat Panel was on: %d whispers received, %d sent, %d whisper tabs opened by the game"):format(w.got, w.sent, w.opened))
    ns.Print(("  whisper windows now: %d in the tab row, %d floating; windows in the tab row: %s"):format(w.docked, w.floating, tostring(w.inRow or "unreadable")))
    if w.mode == "inline" then
        ns.Print("  -> the game puts whispers into the chat window itself. For a tab per conversation: Options > Social > New Whispers > New Tab (or Both).")
    elseif w.got == 0 and w.sent == 0 then
        ns.Print("  -> no whisper since the last /reload. Whisper someone (or have them whisper you), then run /xui chat whispers again.")
    elseif (w.mode == "popout" or w.mode == "popout_and_inline") and w.opened == 0 and w.docked + w.floating == 0 then
        ns.Print("  -> whispers arrived but the game opened no tab. Please send this report and any Lua error (turn errors on with /console scriptErrors 1).")
    end
end

local function ChatWhispers()   -- never raises
    local ok, err = pcall(WhisperReport)
    if not ok then ns.Print(("Chat whispers: could not finish (%s)"):format((tostring(err):gsub("|", "||")))) end
end

-- /xui chat wrap: the measurements (the fix itself, C.Rewrap, is the Chat Panel's)
local function ChatWrap()
    local C = ChatC()
    local st = C.WrapStatus and C.WrapStatus()
    if not st then ns.Print("Chat Panel wrap: the chat window is not there to measure."); return end
    local function f(v) return v and ("%.1f"):format(v) or "?" end
    ns.Print(("Chat Panel wrap: window width %s, text area %s, line width %s (%s lines), widest wrapped line %s, lines wider than their box: %s%s"):format(f(st.cf), f(st.text), f(st.line), tostring(st.numLines or "?"), f(st.wrapped), tostring(st.over or "?"), C.WrapOff() and "  <- OFF, laying out again" or "  (consistent)"))
    local cf = C.Main()
    local sc, tsc = cf and cf.GetEffectiveScale and cf:GetEffectiveScale(), C.TextArea() and C.TextArea():GetEffectiveScale()
    ns.Print(("  scale: window %s, text area %s; relayouts asked for this session: %d; indent wrapped lines: %s"):format(f(sc), f(tsc), C.stats.rewraps or 0,
        (C.IndentOf(cf) == nil and "unreadable") or (C.IndentOf(cf) and "on" or "off")))
    C.Rewrap(true)
    ns.Print("  the window lays its lines out again on its next frame; run /xui chat wrap again to see the result")
end

-------------------------------------------------------------------------------
-- /xuiengine auto | on | off | reset (was core's Combat/AuraDisplay.lua; players keep full and refresh)
-------------------------------------------------------------------------------
local function EngineAuto(rest)
    local D = ns.AuraDisplay
    local db, guard = D.DB(), D._guard
    if not db then ns.Print("saved data not loaded yet") return end
    local a = tostring(rest or ""):lower()
    if a == "on" or a == "off" then db.auto = (a == "on"); guard.lean, guard.off = nil, nil; guard.bad = 0; D.Build() end
    D.Status()
end
local function EngineGroup(word)
    return function(rest)
        local D = ns.AuraDisplay
        local db = D.DB()
        if not db then ns.Print("saved data not loaded yet") return end
        local fo, err = D.FindFolder(rest)
        if not fo then ns.Print(err) return end
        if word == "reset" then db.groups[fo.id] = nil   -- back to automatic
        else db.groups[fo.id] = (word == "on") end
        D.Build(); D.Status()
    end
end

-------------------------------------------------------------------------------
-- Registration: XayaUI's lists (Modules.lua). Help lines read as before.
-------------------------------------------------------------------------------
local R = ns.RegisterDebugCommand
R("probe", function(arg)
    arg = tostring(arg or "")
    if arg:match("^ids") then
        if ns.IDProbe then ns.IDProbe((arg:gsub("^ids%s*", ""))) end
    else Probe(tonumber(arg)) end
end, { "probe <spellID> (what the game says about one spell's cooldown and aura)", "probe ids (arm or disarm the aura instance ID probe; probe ids log prints its log)" })
R("debuffs", function(arg) ProbeDebuffs(arg) end, "debuffs [target|focus] [spellID] (the debuffs on your target or focus)")
-- "perf ui": core's /xui debug perf hands "ui" to this (Core.lua); plain perf (the engine meter) stays core's for players
R("perf", function()
    ns.perf = ns.perf or { n = 0 }; ns.perf.show = not ns.perf.show
    ns.Print("rebuild timing " .. (ns.perf.show and "ON: every window rebuild prints build + skin milliseconds" or "OFF"))
end, "perf ui (settings window rebuild timing)")
R("timing", function() if ns.Timing then TimingReport() end end, "timing (how every cue gets its time in combat)")
R("model", function(arg) if ns.AuraModel then GDD.ModelCommand(arg) end end, "model [setup|<spellID>] (the combat aura duration model)")
R("tracker", function(arg) if ns.AuraTracker then GDD.TrackerCommand(arg) end end, "tracker [shadow|status] (the combat aura tracker)")
R("loc", function() ProbeLossOfControl() end, "loc (loss of control the game reports right now)")
R("media", function() UserMediaReport() end, "media (how many pictures and sounds XayaUI_Media lists)")
R("mods", function() ProbeMods() end, "mods (each cue's modifiers, step by step)")
R("groups", function() if ns.VisualProbeState then ProbeGroups() end end, "groups (each group and where its displays hang)")
R("icons", function() if ns.LoadOptions() and ns.Options.IconReport then ns.Options.IconReport() end end, "icons (which eye and headphone icons the settings window uses)")
R("seed", function() if ns.rules then SeedRules() end end, "seed (add three Vengeance Demon Hunter test rules)")
R("map", function() MapReport() end, "map (why the world map opens full screen: its settings and size)")
R("gamemenu", function() GameMenuDiagnostics(); GameMenuSkinDiagnostics() end, "gamemenu (the ESC menu button and skin)")
R("widthprobe", function(arg) if ns.CharWidthProbe_Run then ns.CharWidthProbe_Run(arg or "") end end,
    "widthprobe [px|off] (the in-game test for a wider character window)")
-- (chatprobe: ChatProbe.lua registers itself)

local Sub = ns.RegisterSubcommand
if Sub then
    Sub("xuiskin", "pad", function(rest)
        local pd = tostring(rest or ""):match("^(%d+)")
        if not pd then print("|cffffd100XayaUI|r usage: /xuiskin pad N (0-30)") return end
        CueRulesDB.ui.skinPad = math.max(0, math.min(30, tonumber(pd)))
        print("|cffffd100XayaUI|r right-pane gutter " .. CueRulesDB.ui.skinPad .. "px (reopen the window to apply).")
    end, "pad N (the settings window's right-pane gutter, 0-30 px)")
    Sub("xuiskin", "alpha", function(rest)
        local v = tostring(rest or ""):match("^([%d%.]+)")
        if not v then print("|cffffd100XayaUI|r usage: /xuiskin alpha X (0.1-1)") return end
        v = math.max(0.1, math.min(1, tonumber(v) or 0.5))
        CueRulesDB.ui.skinAlpha = v
        print("|cffffd100XayaUI|r window opacity " .. v .. " (reopen the window to apply).")
    end, "alpha X (the settings window's opacity, 0.1-1)")
    Sub("xuiengine", "auto", EngineAuto, "auto on / off (automatic engine drawing)")
    Sub("xuiengine", "on", EngineGroup("on"), "on / off <group> (a group drawn by the engine, or kept with XayaUI)")
    Sub("xuiengine", "off", EngineGroup("off"))
    Sub("xuiengine", "reset", EngineGroup("reset"), "reset <group> (a group back to automatic)")
    Sub("chat", "wrap", function() if ChatC() then ChatWrap() end end, "wrap (measure the chat lines and lay them out again)")
    Sub("chat", "indent", function() if ChatC() then ChatIndent() end end, "indent (where the space left of the chat text comes from)")
    Sub("chat", "whispers", function() if ChatC() then ChatWhispers() end end, "whispers (why a whisper does or does not get its own tab)")
end
-- the whisper counters: a part of the Chat Panel (counted only while it runs), when XayaUI Chat is there
do local C = ChatC(); if type(C) == "table" and type(C.Part) == "function" then WhisperPart(C) end end

SLASH_XUITT1 = "/xuitt"
if type(SlashCmdList) == "table" then SlashCmdList.XUITT = function(msg)
    if type(TTof()) ~= "table" then print("XayaUI Tooltips: /xuitt needs XayaUI Bonus Features, which is switched off or not installed.") return end
    msg = (msg or ""):lower()
    if msg:find("probe") then TTProbe()
    elseif msg:find("^%s*aura") then TTAuraReport(tonumber(msg:match("aura%s+(%d+)")))
    elseif msg:find("lines") then TTDumpLines()
    else print("XayaUI Tooltips: /xuitt aura [spellID] (what each aura source says), /xuitt probe (point at a unit first), /xuitt lines (raw lines of the tooltip under the mouse)") end
end
end

-- (tests) the moved reports by name
GDD.Probe, GDD.ProbeDebuffs, GDD.ProbeLossOfControl, GDD.TimingReport = Probe, ProbeDebuffs, ProbeLossOfControl, TimingReport
GDD.ProbeMods, GDD.ProbeGroups, GDD.UserMediaReport, GDD.MapReport = ProbeMods, ProbeGroups, UserMediaReport, MapReport
GDD.GameMenuDiagnostics, GDD.GameMenuSkinDiagnostics, GDD.SeedRules = GameMenuDiagnostics, GameMenuSkinDiagnostics, SeedRules
GDD.ChatWrap, GDD.ChatIndent, GDD.ChatWhispers, GDD.WhisperFacts = ChatWrap, ChatIndent, ChatWhispers, WhisperFacts
GDD.TTAuraReport, GDD.TTDumpLines, GDD.TTProbe, GDD.TargetAuraByName = TTAuraReport, TTDumpLines, TTProbe, TargetAuraByName
