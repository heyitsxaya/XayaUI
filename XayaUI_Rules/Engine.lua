-------------------------------------------------------------------------------
-- Engine.lua : evaluates rules on events + a light ticker, fires sounds on
-- the false -> true edge, drives visuals.
-------------------------------------------------------------------------------
local addonName, ns = ...; ns = XayaUI_NS or ns -- (P4) XayaUI Rules shares the Platform's namespace (XayaUI/Core.lua)
local CoreS = ns.Settings("core")   -- (core 0.6.75, P2 settings seam: the same CueRulesDB keys as before; Modules.lua section 0b)
if ns.SettingsDeclareStore then ns.SettingsDeclareStore("core", "XayaUI_Rules", "XayaUIRulesDB") end   -- (P5) this addon's own saved variable (its .toc; Modules.lua section 0b)

ns.runtime = setmetatable({}, { __mode = "k" }) -- rule -> { active, lastPlay, visualWanted }

local perf = { on = false }   -- /xui debug perf (see the bottom of this file)
-- Round 5 (V27, Xaya 2026-11-10, her answers "No running loops" and "Whole-pixel / no float math"; REQUEST-LOG A23 SD-28 / SD-29 / SD-49):
-- the engine no longer runs every rendered frame. Before, an OnUpdate script ran on every frame for as long as the game was open and
-- stepped every rule five times a second (the 0.2 s tick) whether or not anything had changed: in the V27 gate's busiest case that was
-- 2877 runs, 2739 of them with nothing on screen changing, about 2 MB/s of garbage, and 8 MB in 30 s of idle. Now (the driver at the
-- bottom of this file):
--   * a game event marks what it changed; on the next frame only the loaded rules that read it are re-checked (the "live" lists below,
--     built once whenever the settings or the load facts change), and the frame's OnUpdate script takes itself off again;
--   * a load fact changing (combat, group, zone, mount, spec, talents ...) re-checks every rule once, on the next frame;
--   * time-based changes are waited for with one one-shot timer set to the stored moment they happen: the next whole second of a
--     countdown a display shows, the end of a cooldown, a "cast within N seconds" window, a repeat sound, a "seconds left" threshold
--     (Timing.lua deadlines);
--   * only what the game hides the moment of (a cooldown's end in combat, seconds a display reads from a secret duration, the range to
--     a focus / mouseover / pet) is re-checked every TICK, and only for the loaded rules that wait on it, only while they wait.
-- With nothing loaded waiting on time (idle out of combat, every aura and cooldown gone) nothing of the engine runs.
local TICK = 0.2   -- the re-check pace for what the game hides the moment of (above); nothing else runs on it
local MIN_GAP = 0.05   -- events (casts, movement, target changes) can come many a second: their re-checks run at most this often
-- (review R18) routed cd / aura re-checks: the first after a quiet spell still runs on the very next frame; in a burst (a raid fight) they
-- run at most once per ROUTED_GAP instead of on every rendered frame. A held re-check waits at most this long (no event is lost).
local ROUTED_GAP = 1 / 30
-- (review R18 follow-up) frame times wobble by a millisecond or two: two 60 fps frames often add up to a hair under 1/30 s. Compared
-- against the gap less this slack, a burst re-checks every 2nd frame at 60 fps (every 4th at 120) instead of often waiting a 3rd (5th).
local ROUTED_DUE = ROUTED_GAP - 0.004
local lastRoutedAt, lastStateAt = -1, -1   -- GetTime() of the last routed / state re-check (stored times, compared; nothing counted per frame)
local inCombat = false   -- kept by the combat events (was asked of the game on every rendered frame)
local SNAP_EVERY = 5   -- seconds between auto status snapshots while in combat (only while someone reads them: ns.LogWanted)
local barsDirty = true   -- action bar spell set is rebuilt only when a bar event fires or rules change
local issecret = issecretvalue or function() return false end

local function RT(rule)
    local rt = ns.runtime[rule]
    if not rt then rt = { active = false, lastPlay = 0 }; ns.runtime[rule] = rt end
    return rt
end

-- Errors are reported once per rule (and saved to the error log); the other rules keep running.
local function ReportRuleError(rule, rt, err)
    if rt.vErrored then return end
    rt.vErrored = true
    ns.Print("rule '" .. tostring(rule.name) .. "' error (the other rules keep running): " .. tostring(err))
    -- (core 0.6.56; REQUEST-LOG #82: recorded with its code, XUI-E010, in the debug report; DebugRecord.lua)
    if ns.RecordError then pcall(ns.RecordError, "XayaUI rule '" .. tostring(rule.name) .. "': " .. tostring(err), nil, "XayaUI", "XUI-E010") end
end

-- Actions and sounds run guarded per rule: one failing action can neither stop the step nor block the other rules.
local function Guarded(rule, rt, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then ReportRuleError(rule, rt, err) end
end
local function RunActionsSafe(rule, rt, phase) if ns.RunActions then Guarded(rule, rt, ns.RunActions, rule, phase) end end
local function PlaySoundSafe(rule, rt)
    -- the game already plays this rule's sound on the aura itself (AuraSound.lua, opt-in): no second copy
    if ns.AuraSound and ns.AuraSound.Owns(rule) then
        if ns.RecSound then ns.RecSound(rule, "left to the game (it plays this sound on the aura itself)") end
        return
    end
    Guarded(rule, rt, function()
        local how, res = ns.PlaySound(ns.EffectiveSound(rule))
        if ns.RecSound then ns.RecSound(rule, how or "no sound picked", res) end   -- (DebugRecord.lua: nothing when its category is off)
    end)
end
local function HasSound(rule) return ns.KindHas(rule, "sound") end
local function SoundNote(rule)
    local s = rule.sound
    return (s and s.enabled and s.value ~= "" and HasSound(rule)) and "  (sound)" or ""
end

-- Does XayaUI want this rule's own display shown this step?
local function DisplayWanted(rule, info, result)
    local v = rule.visual
    if not (v and v.enabled and ns.KindHas(rule, "visual")) then return false end
    local wanted = false
    if v.trigger == "buffActive" then wanted = info and info.present == true or false
    elseif v.trigger == "condition" then wanted = result and true or false end   -- blank / none: nothing is shown
    -- gate: never show while the rule's identifying spell isn't currently on an action bar
    if wanted and v.requireOnBar and ns.SpellOnActionBar then
        local checkID = (rule.spellID and rule.spellID ~= 0) and rule.spellID or rule.buffID
        if not ns.SpellOnActionBar(checkID) then wanted = false end
    end
    return wanted
end

-- One enabled rule: evaluate; fire on the false -> true edge, repeat, clear; actions; its display.
local function StepEnabled(rule, rt, ctx, now)
    local pt = perf.on and debugprofilestop()
    local ok, result, info = pcall(ns.Evaluate, rule, ctx)
    if pt then local d = debugprofilestop() - pt; perf.evalMs = perf.evalMs + d; perf.rule[rule] = (perf.rule[rule] or 0) + d end
    if not ok then
        local err = result
        result, info = false, nil
        if not rt.errored then
            rt.errored = true; ns.Print("rule '" .. tostring(rule.name) .. "' error: " .. tostring(err))
            -- audit D57 (core 0.6.67): recorded for /xui report too (the file's header promises the error log), like the action errors
            if ns.RecordError then pcall(ns.RecordError, "XayaUI rule '" .. tostring(rule.name) .. "' (evaluate): " .. tostring(err), nil, "XayaUI", "XUI-E010") end
        end
    end
    rt.info = info
    if ns.RecTrigger then ns.RecTrigger(rule, result, info) end   -- trigger detail for chosen rules (DebugRecord.lua; one test when off)
    -- Actions tab: On Initialization (the rule's load conditions hold), During start, After It Ends
    if not rule.parentUid and ns.RunActions and info then
        -- audit D54 (core 0.6.67): "loaded" is the load conditions AND the talent requirement (ns.IsLoaded); before, a rule whose
        -- talent requirement failed still ran its On Initialization actions
        if info.ctxOK and info.talentOK == true then
            if not rt.inited then rt.inited = true; RunActionsSafe(rule, rt, "init") end
        elseif info.ctxOK == false or info.talentOK == false then rt.inited = nil end
    end
    if result and not rt.active then
        rt.active, rt.lastPlay = true, now
        if not rule.parentUid then RunActionsSafe(rule, rt, "start") end
        if HasSound(rule) then PlaySoundSafe(rule, rt) end
        if ns.LogWanted("rule") then ns.LogKind("rule", "|cff55ff55FIRED|r %s%s", tostring(rule.name), SoundNote(rule)) end
    elseif result then
        local rep = rule.repeatSec or 0
        if rep > 0 and (now - rt.lastPlay) >= rep then
            rt.lastPlay = now
            if HasSound(rule) then PlaySoundSafe(rule, rt) end
            if ns.LogWanted("rule") then ns.LogKind("rule", "repeat  %s", tostring(rule.name)) end
        end
    else
        if rt.active then
            if ns.LogWanted("rule") then ns.LogKind("rule", "cleared %s: %s", tostring(rule.name), info and ns.WhyNot(info) or "error") end
            if not rule.parentUid then RunActionsSafe(rule, rt, "finish") end
        end
        rt.active = false
    end
    local wanted = DisplayWanted(rule, info, result)
    local was = rt.visualWanted
    rt.visualWanted = wanted
    -- the debug record's "Displays" category: only a change is reported (the first step of a hidden display is not a change)
    if was ~= wanted and (was ~= nil or wanted) and ns.RecDisplay then
        ns.RecDisplay(rule, wanted, ns.EngineOwns and ns.EngineOwns(rule) and true or false)
    end
    local pv = perf.on and debugprofilestop()
    Guarded(rule, rt, ns.SetVisualShown, rule, wanted)
    -- a display the combat engine draws is hidden here, so its text / fade work is skipped, except its companion texts (shield
    -- amount, spell charges: the game's container cannot draw them; Visual.lua draws them over the engine's icon)
    if wanted and (not (ns.EngineOwns and ns.EngineOwns(rule)) or (ns.EngineCompanion and ns.EngineCompanion(rule))) then
        Guarded(rule, rt, ns.UpdateVisualText, rule, info)
    end
    if pv then local d = debugprofilestop() - pv; perf.visMs = perf.visMs + d; perf.rule[rule] = (perf.rule[rule] or 0) + d end
end

-- audit D56 (core 0.6.67): a rule taken out of the list (deleted to the Recycle Bin, or swapped out by Load (replace)) finishes what it
-- started, as a switched-off rule does (StepDisabled): its After It Ends actions run and a "During" glow stops (before: the glow stayed
-- until /reload). Called by RecycleBin.lua and Share.lua before they remove the rule.
function ns.EndRule(rule)
    local rt = rule and ns.runtime and ns.runtime[rule]
    if not rt then return end
    if rt.active and not rule.parentUid and ns.RunActions then pcall(ns.RunActions, rule, "finish") end
    rt.active, rt.inited = false, nil
end

-- One disabled rule: finish what it started and hide its display (once).
local function StepDisabled(rule, rt)
    if rt.active and not rule.parentUid then RunActionsSafe(rule, rt, "finish") end
    rt.active, rt.inited = false, nil
    if rt.visualWanted ~= false or rt.shownOnce == nil then
        rt.shownOnce = true
        Guarded(rule, rt, ns.SetVisualShown, rule, false)
    end
    rt.visualWanted = false
end

-- Preview (transient, set from the sidebar eye / headphone icons): force-show the visual and / or loop the sound without
-- touching the rule's own switches or conditions.
local function StepPreview(rule, rt, now)
    if ns.IsPreview(rule, "visual") and ns.KindHas(rule, "visual") then
        rt.visualWanted = true
        ns.SetVisualShown(rule, true)
        ns.UpdateVisualText(rule, rt.info)
    end
    if ns.IsPreview(rule, "sound") and ns.KindHas(rule, "sound") then
        local iv = ((rule.repeatSec or 0) > 0) and math.max(0.5, rule.repeatSec) or 2
        if now - (rt.pvLast or 0) >= iv then
            rt.pvLast = now
            ns.PlaySoundPreview(ns.EffectiveSound(rule))
        end
    else
        rt.pvLast = nil
    end
end

local function StepRule(rule, ctx, now, off)
    local rt = RT(rule)
    if not off then
        rt.offDone = nil
        StepEnabled(rule, rt, ctx, now)
    else
        StepDisabled(rule, rt)
        -- D7: cleaned up once; from then on Step skips it, unless it is being previewed (the step after a preview ends hides it again)
        rt.offDone = not (ns.IsPreview(rule, "visual") or ns.IsPreview(rule, "sound")) or nil
    end
    StepPreview(rule, rt, now)
end

-- D4 / #309 event routing (core 0.6.56; Xaya 2026-11-06: "either way reduce the ms as much as possible. avoid at all costs compromising on
-- performance of rules while minimizing cpu and ram costs"), event-driven since round 5 (V27, see the top of this file). What a rule reads
-- (its own triggers, or its parent's for a cue / condition) decides which events re-check it:
--   cd     cooldowns, charges, usability, the global cooldown, item cooldowns (SPELL_UPDATE_COOLDOWN / _CHARGES / _USABLE, the action bar's
--          cooldown / usable events, BAG_UPDATE_COOLDOWN)
--   aura   your auras (UNIT_AURA on you)            tgt    your debuffs on the target / focus (UNIT_AURA on them)
--   power  class resources, runes (UNIT_POWER_UPDATE, UNIT_MAXPOWER, UNIT_DISPLAYPOWER, RUNE_POWER_UPDATE)
--   range  spell range to the target (SPELL_RANGE_CHECK_UPDATE, with C_Spell.EnableSpellRangeCheck for its spell)
--   cast   "cast within N seconds" (UNIT_SPELLCAST_SUCCEEDED; the window's end is a stored time)
--   other  anything else: the events other files report through ns.MarkStateDirty (casts, movement, target, glows, equipment ...),
--          which re-check every loaded rule, as every event did before
-- A rule that reads only load facts is re-checked when a load fact changes.
local depCache, depVer, depList = setmetatable({}, { __mode = "k" }), nil, nil
local ROW_READS = {
    cooldown = "cd", actionUsable = "cd", globalCooldown = "cd", itemUsable = "cd",
    buffAura = "aura", targetDebuff = "tgt", resource = "power", dkRunes = "power", rangeCheck = "range", castSucceeded = "cast",
    spellKnown = "other", talentKnown = "other", spellGlow = "other", itemCount = "other", itemEquipped = "other", setPieces = "other",
    stanceForm = "other", totem = "other", playerState = "other", lossOfControl = "other", weaponEnchant = "other",
}
local GCD_SPELL = 61304   -- the global cooldown (Triggers.lua "Global Cooldown" reads the same spell)
local function Deps(rule)
    if depVer ~= ns.configVersion or depList ~= ns.rules then
        depVer, depList = ns.configVersion, ns.rules
        for k in pairs(depCache) do depCache[k] = nil end
    end
    local d = depCache[rule]
    if d then return d end
    local r = rule
    if rule.parentUid and ns.FindParentRule then r = ns.FindParentRule(rule) or rule end
    d = {}
    local sid = tonumber(r.spellID) or 0
    if r.useCooldown and sid ~= 0 then d.cd = true; d.cdSpells = { sid }; d.ownCd = true end   -- (ownCd: cdSpells[1] is the rule's own spell)
    if r.countGCD and d.cd then d.cdSpells[#d.cdSpells + 1] = GCD_SPELL end
    if r.useBuff and (tonumber(r.buffID) or 0) ~= 0 then d.aura = true end
    local list = type(r.extra) == "table" and type(r.extra.list) == "table" and r.extra.list or nil
    for _, t in ipairs(list or {}) do
        if type(t) == "table" then
            local k = ROW_READS[t.type]
            if k == nil then d.other, d.poll = true, true   -- a row type this file does not know: re-checked every TICK while loaded (fails safe)
            elseif k == "cd" then
                d.cd = true
                local id = tonumber(t.spellID) or 0
                d.cdSpells = d.cdSpells or {}
                if t.type == "globalCooldown" or t.countGCD then d.cdSpells[#d.cdSpells + 1] = GCD_SPELL end
                if t.type == "itemUsable" then
                    local item = tonumber(t.itemID) or 0
                    if item ~= 0 and t.state == "ready" then d.cdItems = d.cdItems or {}; d.cdItems[#d.cdItems + 1] = item end
                elseif id ~= 0 and t.type ~= "globalCooldown" then d.cdSpells[#d.cdSpells + 1] = id end
            elseif k == "range" then
                d.range = true
                if t.unit == "target" then
                    local id = tonumber(t.spellID) or 0
                    if id ~= 0 then d.rangeSpells = d.rangeSpells or {}; d.rangeSpells[#d.rangeSpells + 1] = id end
                else
                    d.poll = true   -- focus / mouseover / pet: the game sends no range event for them
                end
            elseif k == "cast" then
                d.cast = true
                local w = tonumber(t.window) or 3
                if w <= 0 then w = 3 end
                if w > (d.castWin or 0) then d.castWin = w end
            elseif k == "other" then
                d.other = true
                if t.type == "weaponEnchant" and (tonumber(t.minSec) or 0) > 0 then d.enchant = d.enchant or {}; d.enchant[#d.enchant + 1] = t end
            else
                d[k] = true
            end
        end
    end
    local v = rule.visual
    if type(v) == "table" then
        -- a display showing the spell's charges (Visual.lua DrawCount) changes with the charge events
        if type(v.count) == "table" and v.count.enabled and ns.Val(v.count.source) == "charges" and sid ~= 0 then
            d.cd = true; d.cdSpells = d.cdSpells or {}
        end
        if v.requireOnBar then d.bar = true end
    end
    d.loadOnly = not (d.cd or d.aura or d.tgt or d.power or d.range or d.cast or d.other) or nil   -- reads load facts only
    d.auraOnly = d.aura and not (d.cd or d.tgt or d.power or d.range or d.cast or d.other) or nil
    depCache[rule] = d
    return d
end
ns.EngineDeps = Deps   -- (tests)

-- The live lists: the rules each kind of event re-checks. Built in one pass over the rules whenever every rule is stepped (a settings
-- change, a load fact changing); between those passes nothing about which rules are loaded can change, so an event touches only these.
-- A rule is live when it is switched on and loaded (load conditions and talents hold), or previewed; a rule that is not loaded but whose
-- display follows the buff anyway (ns.NeedsPresence) is live for aura events only. Nothing is live while /xui disable holds.
local KINDS = { "all", "cd", "aura", "tgt", "power", "range", "cast" }
local live = {}
for _, k in ipairs(KINDS) do live[k] = {} end
local liveCount = {}
local liveBars = false   -- a live rule shows only while its spell is on an action bar (requireOnBar)
local rangeOn = {}   -- spell ID -> true: range events the game sends for it (C_Spell.EnableSpellRangeCheck)
local Watch          -- (the driver below: registers an input's events only while a live rule reads it)
local function ClearLive()
    for _, k in ipairs(KINDS) do local l = live[k]; for i = #l, 1, -1 do l[i] = nil end end
    liveBars = false
end
local function Push(k, rule) local l = live[k]; l[#l + 1] = rule end
local function NotLoaded(rule)
    local p = rule
    if rule.parentUid then p = ns.FindParentRule and ns.FindParentRule(rule); if not p then return false end end
    local rt = ns.runtime[p]
    local info = rt and rt.info
    return info and info.skipped == true or false
end
local function AddLive(rule, off, pv)
    if ns.RulesDisabled then return false end
    if off and not pv then return false end
    local d = Deps(rule)
    if not pv and NotLoaded(rule) then
        -- (review R18) not loaded: false again until a load fact changes; kept for aura events only when its display follows the buff
        local p = rule.parentUid and ns.FindParentRule and ns.FindParentRule(rule) or rule
        if ns.NeedsPresence and ns.NeedsPresence(p) then Push("aura", rule) end
        return false
    end
    Push("all", rule)
    if d.cd then Push("cd", rule) end
    if d.aura then Push("aura", rule) end
    if d.tgt then Push("tgt", rule) end
    if d.power then Push("power", rule) end
    if d.range then Push("range", rule) end
    if d.cast then Push("cast", rule) end
    if d.bar then liveBars = true end
    return true
end
-- after the live lists change: the inputs they read have their events registered, the rest let go (V14: nothing listens for nobody)
local function LiveChanged()
    for _, k in ipairs(KINDS) do liveCount[k] = #live[k] end
    local want = {}
    for _, rule in ipairs(live.range) do
        local d = Deps(rule)
        local l = d.rangeSpells
        if l then for i = 1, #l do want[l[i]] = true end end
    end
    if C_Spell and C_Spell.EnableSpellRangeCheck then
        for id in pairs(rangeOn) do if not want[id] then pcall(C_Spell.EnableSpellRangeCheck, id, false); rangeOn[id] = nil end end
        for id in pairs(want) do if not rangeOn[id] then pcall(C_Spell.EnableSpellRangeCheck, id, true); rangeOn[id] = true end end
    end
    if Watch then Watch() end
end

-- When does a rule next change without an event? Worked out after each re-check of a live rule, from the times the game gives:
--   at    the earliest stored moment (a countdown's next whole second, a cooldown's end, a repeat sound, an enchant threshold)
--   poll  true when it changes at a moment the game hides (re-checked every TICK while that lasts)
-- rule -> moment, and the rules re-checked every TICK, are kept in two small sets (only rules waiting on time are in them).
local wakeAt = setmetatable({}, { __mode = "k" })
local polled = setmetatable({}, { __mode = "k" })
local cdMemo = {}      -- spell / item -> its next end this step (reused, emptied per step: no table per read)
local cdMemoStep = -1
local function Earlier(a, b) if a == nil then return b end if b == nil then return a end return (b < a) and b or a end
local function Readable(v) return type(v) == "number" and not issecret(v) end
-- the moment a spell's running cooldown or recharge ends: a number, false (not running), or true (running, the end is hidden)
local function SpellEnd(id, now)
    local key = id
    local m = cdMemo[key]
    if m ~= nil then return m end
    local res = false
    local readID = (ns.SpellOnBar and ns.SpellOnBar(id)) or id
    local ok, cd = pcall(C_Spell.GetSpellCooldown, readID)
    if ok and type(cd) == "table" then
        local act, st, du = cd.isActive, cd.startTime, cd.duration
        if issecret(act) then act = nil end
        if act == true or (act == nil and Readable(du) and du > 0) then
            if Readable(st) and Readable(du) and du > 0 then res = st + du else res = true end
        elseif act == nil and not Readable(du) then
            res = true   -- nothing readable about it: re-checked until it reads
        end
    end
    local okc, ch = pcall(C_Spell.GetSpellCharges, readID)
    if okc and type(ch) == "table" then
        local act, st, du = ch.isActive, ch.cooldownStartTime, ch.cooldownDuration
        if issecret(act) then act = nil end
        if act == true then
            if Readable(st) and Readable(du) and du > 0 then
                local e = st + du
                if res == false or (type(res) == "number" and e < res) then res = e end
            elseif res == false then res = true end
        end
    end
    if type(res) == "number" and res <= now then res = false end
    cdMemo[key] = res
    return res
end
local function ItemEnd(item, now)
    local key = -item   -- (items and spells share the memo: item keys are negative)
    local m = cdMemo[key]
    if m ~= nil then return m end
    local res = false
    local fn = (C_Container and C_Container.GetItemCooldown) or GetItemCooldown
    if fn then
        local ok, st, du = pcall(fn, item)
        if ok and Readable(st) and Readable(du) then
            if du > 1.5 and st > 0 and st + du > now then res = st + du end
        elseif ok then res = true end
    end
    cdMemo[key] = res
    return res
end
local enchMemo, enchMemoStep = {}, -1
local function EnchantEnds(now)
    if enchMemoStep == ns.tickID then return enchMemo end
    enchMemoStep = ns.tickID
    enchMemo.main, enchMemo.off = nil, nil
    local fn = ns.Compat and ns.Compat.WeaponEnchantInfo
    if fn then
        local ok, hm, mexp, _, _, ho, oexp = pcall(fn)
        if ok then
            if hm and Readable(mexp) then enchMemo.main = now + mexp / 1000 end
            if ho and Readable(oexp) then enchMemo.off = now + oexp / 1000 end
        end
    end
    return enchMemo
end
-- your recent casts (UNIT_SPELLCAST_SUCCEEDED, recorded while a live rule has a "cast within N seconds" row): each one's window ends at a
-- stored moment; a ring of the last CAST_RING casts (a window is at most 60 s, Triggers.lua castSucceeded)
local CAST_RING = 16
local castRing, castPos = {}, 0
local function NoteCast(now) castPos = castPos % CAST_RING + 1; castRing[castPos] = now end
local minWake = math.huge   -- the earliest stored moment in wakeAt (kept as moments are added; worked out again when a wake runs)
local EMPTY = {}
local cdFresh = true   -- this step may have seen a cooldown change (a cooldown event, a full or every-live-rule step, a stored moment)
local function Plan(rule, rt, now, pv)
    local d = Deps(rule)
    local at, poll = nil, d.poll and true or false
    if pv or ns.unlocked then poll = true end   -- a preview / the mover's samples move with time (the settings window is open)
    -- a repeat sound
    if rt.active and (rule.repeatSec or 0) > 0 and rt.lastPlay then at = rt.lastPlay + rule.repeatSec end
    -- the countdown a display of XayaUI's own shows (one the combat engine draws is counted down by the game)
    if rt.visualWanted then
        local v = rule.visual
        local tx = type(v) == "table" and v.text
        if type(tx) == "table" and tx.enabled and not (ns.EngineOwns and ns.EngineOwns(rule)) then
            local info = rt.info
            local ref = info and (info.buffRef or info.auraRef)
            local exp = type(ref) == "table" and ref.expiration
            if Readable(exp) then
                local rem = exp - now
                if rem > 0 then at = Earlier(at, now + (rem - math.floor(rem)) + 0.001) end   -- the next whole second it shows
            elseif type(ref) == "table" and ref.instanceID ~= nil then
                poll = true   -- seconds read from the game's duration object (secret in combat): redrawn every TICK while shown
            end
        end
    end
    -- the cooldowns it reads: their end, or re-checked while a hidden one runs. Worked out again only when a cooldown may have changed
    -- (cdFresh), and the game is asked only about a cooldown that runs (the rule's own one is known from this step's answer)
    if d.cd then
        if cdFresh then
            local cAt, cPoll = nil, false
            if cdMemoStep ~= ns.tickID then cdMemoStep = ns.tickID; for k in pairs(cdMemo) do cdMemo[k] = nil end end
            local cdi = rt.info and rt.info.cd
            -- (its own cooldown: this step's answer says whether it runs; isActive is NeverSecret, structures.md:6549, so in game that answer
            -- is there in combat too; with no answer at all nothing is read and its end comes with the next cooldown event)
            local ownIdle = type(cdi) == "table" and not cdi.onCd and cdi.atMax ~= false and not (cdi.onGCD and rule.countGCD)
            local list = d.cdSpells or EMPTY
            for i = 1, #list do
                local id = list[i]
                if not (i == 1 and ownIdle and d.ownCd) then
                    local e = SpellEnd(id, now)
                    if e == true then cPoll = true elseif e then cAt = Earlier(cAt, e + 0.001) end
                end
            end
            list = d.cdItems or EMPTY
            for i = 1, #list do
                local e = ItemEnd(list[i], now)
                if e == true then cPoll = true elseif e then cAt = Earlier(cAt, e + 0.001) end
            end
            if type(cdi) == "table" and Readable(cdi.readyAt) and cdi.readyAt > now then cAt = Earlier(cAt, cdi.readyAt + 0.001) end
            rt.cdAt, rt.cdPoll = cAt, cPoll or nil
        end
        if rt.cdAt and rt.cdAt > now then at = Earlier(at, rt.cdAt) end
        if rt.cdPoll then poll = true end
    end
    -- "cast within N seconds": the moment each recent cast's window closes
    if d.castWin then
        for i = 1, CAST_RING do
            local c = castRing[i]
            if c and c + d.castWin > now then at = Earlier(at, c + d.castWin + 0.001) end
        end
    end
    -- "at least N seconds left" on a weapon enchant: the moment it drops below, and its end
    if d.enchant then
        local e = EnchantEnds(now)
        for _, t in ipairs(d.enchant) do   -- (only rules with such a row)
            local x = (t.weapon == "off") and e.off or e.main
            if x then
                local cross = x - (tonumber(t.minSec) or 0)
                if cross > now then at = Earlier(at, cross + 0.001) end
                if x > now then at = Earlier(at, x + 0.001) end
            end
        end
    end
    wakeAt[rule] = at
    if at and at < minWake then minWake = at end
    polled[rule] = poll or nil
end
local function Unplan(rule) wakeAt[rule] = nil; polled[rule] = nil end

local lastCtx                     -- the last full step's context, reused by every other re-check (load facts change only in a full step)
local lastCtxSig, lastTalentEp    -- what the last full step's load answers were made from
local liveRules, liveRulesN       -- the rule list (and its length) the live lists were built from
local presetCtx                   -- a context already read for this full step (the load-fact check below read it)
local stepList                    -- set for one Step call: the live lists to walk (nil = every rule, a full step)
local stepClearsDeadlines = true  -- false for a re-check of some rules only: the others' "seconds left" moments stay registered
local stepSerial = 0
local seen = setmetatable({}, { __mode = "k" })   -- rule -> stepSerial it was stepped in (a rule in two lists is stepped once)
local pvV, pvS

local function StepOne(rule, ctx, now, off)
    local ok, err = pcall(StepRule, rule, ctx, now, off)
    if not ok then ReportRuleError(rule, RT(rule), err) end
end

local function Step()
    if not ns.rules then return end
    stepSerial = stepSerial + 1
    local lists = stepList
    -- the action bars changed: their spell set is read again before the rules that show only while their spell is on a bar are checked
    -- (a full step looks at every rule; a re-check of every live rule uses what the last full step found)
    if barsDirty and (not lists or stepClearsDeadlines) then
        barsDirty = false
        local need = liveBars
        if not lists then
            need = false
            for _, r in ipairs(ns.rules) do if r.enabled and r.visual and r.visual.requireOnBar then need = true; break end end
        end
        if need and ns.RefreshActionBarSpells then ns.RefreshActionBarSpells() end
    end
    -- every other re-check reuses the last full step's context (load facts change only through the events that run a full step), so no
    -- context table is made per re-check
    local ctx = (lists and lastCtx) or presetCtx or ns.ReadContext()
    ns.tickID = (ns.tickID or 0) + 1
    local now = GetTime()
    pvV, pvS = ns.previewSets and ns.previewSets.visual, ns.previewSets and ns.previewSets.sound
    -- every rule runs on its own: bad data in one can never delay or block the others
    if not lists then
        lastCtx, lastCtxSig, lastTalentEp = ctx, ctx.sig, ns.talentEpoch
        liveRules, liveRulesN = ns.rules, #ns.rules
        ClearLive()
        for k in pairs(wakeAt) do wakeAt[k] = nil end
        for k in pairs(polled) do polled[k] = nil end
        minWake = math.huge
        -- D7 (core 0.6.56): a switched-off rule (or a cue of one) is skipped once it has been cleaned up: no runtime record is made for a
        -- rule that was never on, and nothing of it runs per step, unless it is previewed
        for _, rule in ipairs(ns.rules) do
            local off = ns.RuleOff(rule)
            local rt0 = off and ns.runtime[rule]
            local pv = (pvV and pvV[rule]) or (pvS and pvS[rule]) or false
            if not off or (rt0 and not rt0.offDone) or pv then StepOne(rule, ctx, now, off) end
            if AddLive(rule, off, pv) then Plan(rule, RT(rule), now, pv) else Unplan(rule) end
        end
        LiveChanged()
    else
        for i = 1, #lists do
            local l = lists[i]
            for j = 1, #l do
                local rule = l[j]
                if seen[rule] ~= stepSerial then
                    seen[rule] = stepSerial
                    local pv = (pvV and pvV[rule]) or (pvS and pvS[rule]) or false
                    StepOne(rule, ctx, now, pv and ns.RuleOff(rule) or false)   -- (only a previewed rule can be live while off)
                    Plan(rule, RT(rule), now, pv)
                end
            end
        end
    end
    if lists then return end   -- the bars and the rest wait for the next full step
    if ns.Bars_Update then
        local pb = perf.on and debugprofilestop()
        local okb, errb = pcall(ns.Bars_Update)
        if pb then perf.barsMs = perf.barsMs + (debugprofilestop() - pb) end
        if not okb and not ns.barErr then ns.barErr = true; ns.Print("bars error: " .. tostring(errb)) end
    end
end

-- /xui debug perf: measures the engine on this machine. Off by default; while on, each Step is timed with debugprofilestop,
-- split into rule evaluation / visual updates / bars, with the most expensive rules named. Every report is also saved to
-- XayaUI Dev Assist's XayaUIDevAssistDB.perfLog (P5, B11; CueRulesDB.perfLog before; only while Dev Assist is on) (last 6) so it survives /reload and can be read from the saved variables.
local function PerfReset()
    perf.steps, perf.total, perf.max, perf.events, perf.t0 = 0, 0, 0, {}, GetTime()
    perf.evalMs, perf.visMs, perf.barsMs, perf.fxMs, perf.fxN = 0, 0, 0, 0, 0
    perf.rule = {}
    perf.paths = {}
    perf.mem0 = collectgarbage("count")
    ns.perfOn = true
end
function ns.PerfAdd(key, ms)   -- other files add their own timings (per-frame effects)
    if not perf.on then return end
    if key == "fx" then perf.fxMs, perf.fxN = perf.fxMs + ms, perf.fxN + 1 end
end
function ns.PerfPath(rule, tag)   -- which duration-text path a rule took this tick (counted while measuring)
    if not perf.on then return end
    local k = tostring(tag)
    perf.paths[k] = (perf.paths[k] or 0) + 1
end
local rawStep = Step
-- One step with its lookup index (Core.lua) and the group layouts it queued; the index is dropped even if the step fails.
local function IndexedStep()
    if ns.Timing and stepClearsDeadlines then ns.Timing.ClearDeadline() end   -- this step re-checks every live rule: they register the next moments anew
    ns.BeginStepIndex(stepList ~= nil)   -- a re-check of some rules reuses the kept rule / group index unless settings changed (review R18)
    if ns.BeginVisualStep then ns.BeginVisualStep() end
    local ok, err = pcall(rawStep)
    if ns.FlushLayouts then pcall(ns.FlushLayouts) end
    ns.EndStepIndex()
    if not ok then error(err, 0) end
end
Step = function()
    if not perf.on then return IndexedStep() end
    local t = debugprofilestop()
    IndexedStep()
    local d = debugprofilestop() - t
    perf.steps, perf.total = perf.steps + 1, perf.total + d
    if d > perf.max then perf.max = d end
end

-- the game's own per-addon CPU meter (C_AddOnProfiler); read-only, no cost to the addons measured
local function AddonCPU()
    local out = {}
    if not (C_AddOnProfiler and C_AddOnProfiler.GetAddOnMetric and Enum and Enum.AddOnProfilerMetric and C_AddOns and C_AddOns.GetNumAddOns) then return nil end
    local M = Enum.AddOnProfilerMetric
    for i = 1, C_AddOns.GetNumAddOns() do
        local name = C_AddOns.GetAddOnInfo(i)
        if name and C_AddOns.IsAddOnLoaded(name) then
            local ok, avg = pcall(C_AddOnProfiler.GetAddOnMetric, name, M.RecentAverageTime)
            local ok2, peak = pcall(C_AddOnProfiler.GetAddOnMetric, name, M.PeakTime)
            if ok and type(avg) == "number" then out[#out + 1] = { name = name, avg = avg, peak = (ok2 and type(peak) == "number") and peak or 0 } end
        end
    end
    table.sort(out, function(x, y) return x.avg > y.avg end)
    return out
end

function ns.PerfCommand(arg)
    arg = tostring(arg or ""):lower():match("^%s*(%a*)") or ""
    if arg == "on" or arg == "reset" then
        perf.on = true; PerfReset()
        ns.Print("perf: measuring. Play (ideally a fight), then /xui debug perf to read it, /xui debug perf off to stop.")
        return
    elseif arg == "off" then
        perf.on = false; ns.perfOn = false
        ns.Print("perf: stopped")
        return
    end
    if not perf.t0 then ns.Print("perf: not measuring. /xui debug perf on, play a while, then /xui debug perf."); return end
    local secs = math.max(0.001, GetTime() - perf.t0)
    local steps = math.max(1, perf.steps)
    local ev, parts = perf.events, {}
    for k, n in pairs(ev) do parts[#parts + 1] = ("%s %.1f/s"):format(k, n / secs) end
    table.sort(parts)
    local rules, on = #(ns.rules or {}), 0
    for _, r in ipairs(ns.rules or {}) do if r.enabled then on = on + 1 end end
    local lines = {}
    local function L(fmt, ...) local t = fmt:format(...); lines[#lines + 1] = t; ns.Print(t) end
    L("perf over %.0fs: %d steps (%.1f/s), %.2f ms avg, %.2f ms worst, %.1f%% of one frame budget at 60 fps (%d rules, %d on)",
        secs, perf.steps, perf.steps / secs, perf.total / steps, perf.max, (perf.total / secs) / 10, rules, on)
    L("perf: per second: rules %.2f ms, visuals %.2f ms, bars %.2f ms, per-frame effects %.2f ms (%d calls)",
        perf.evalMs / secs, perf.visMs / secs, perf.barsMs / secs, perf.fxMs / secs, perf.fxN)
    local top = {}
    for r, ms in pairs(perf.rule) do top[#top + 1] = { r, ms } end
    table.sort(top, function(a, b) return a[2] > b[2] end)
    for i = 1, math.min(5, #top) do
        local r = top[i][1]
        L("perf: #%d %.2f ms/s  %s%s", i, top[i][2] / secs, tostring(r.name), r.isCue and " (cue)" or "")
    end
    L("perf: Lua memory %.0f KB now, %+.0f KB/s since start (a high number means garbage)", collectgarbage("count"), (collectgarbage("count") - perf.mem0) / secs)
    L("perf: events %s", #parts > 0 and table.concat(parts, ", ") or "none counted yet")
    local pp = {}
    for k, n in pairs(perf.paths) do pp[#pp + 1] = ("%s x%d"):format(k, n) end
    table.sort(pp)
    if #pp > 0 then L("perf: duration-text paths: %s", table.concat(pp, ", ")) end
    local cpu = AddonCPU()
    if cpu then
        local bits = {}
        for i = 1, math.min(8, #cpu) do bits[#bits + 1] = ("%s %.2f/%.1f"):format(cpu[i].name, cpu[i].avg, cpu[i].peak) end
        L("perf: game's own addon meter, recent avg/peak ms per frame, top 8: %s", table.concat(bits, "; "))
    else
        L("perf: the game's addon meter (C_AddOnProfiler) is not available here")
    end
    -- (P5, B11) kept by XayaUI Dev Assist (its store): with Dev Assist off nothing is saved (and nothing made for it)
    local DevS = ns.SettingsReady("devassist") and ns.Settings("devassist")
    if DevS then
        local log = DevS.perfLog
        if type(log) ~= "table" then log = {}; DevS.perfLog = log end
        log[#log + 1] = { at = date("%Y-%m-%d %H:%M:%S"), build = ns.version or (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("XayaUI", "Version")), combat = (UnitAffectingCombat and UnitAffectingCombat("player")) and true or false, lines = lines }
        while #log > 6 do table.remove(log, 1) end
    end
end


-------------------------------------------------------------------------------
-- The driver (round 5, V27; see the top of this file). Nothing here runs per rendered frame while nothing changes:
--   pend.full  every rule, once (a settings change, login, /xui enable)                 -> a one-shot timer, next frame
--   pend.ctx   a load fact may have changed: the context is read once and compared;      -> the same one-shot timer
--              only a real change re-checks every rule
--   pend.all   ns.MarkStateDirty (another file saw a change: a cast, movement, a glow ...) -> every LIVE rule, next frame (MIN_GAP apart)
--   pend.<k>   an input's own event (cooldowns, your auras, target debuffs, resources,    -> the live rules that read it, next frame
--              range, casts, the action bars)                                                (ROUTED_GAP apart)
--   wakes      the stored moments (Plan above) and the TICK re-check of what the game     -> one one-shot timer at the earliest moment
--              hides the moment of
-- The frame's OnUpdate script is set only while pend.all or a pend.<k> waits, and takes itself off once they are done.
-------------------------------------------------------------------------------
local pend = { full = false, ctx = false, all = false }
local ROUTED = { "cd", "aura", "tgt", "power", "range", "cast" }
for _, k in ipairs(ROUTED) do pend[k] = false end
local f = CreateFrame("Frame")
-- A failing step must never stop the engine or flood the error window: it is caught here, reported once per distinct
-- message (and saved to the error log), and the next step runs as normal.
local lastStepErr
local function SafeStep()
    local ok, err = pcall(Step)
    if not ok then
        err = tostring(err)
        if err ~= lastStepErr then
            lastStepErr = err
            if ns.Print then ns.Print("engine step error (the engine keeps running): " .. err) end
            if ns.RecordError then pcall(ns.RecordError, "XayaUI engine: " .. err, nil, "XayaUI", "XUI-E011") end   -- (DebugRecord.lua)
        end
    end
end

-- the stored-moment timer: one at a time, set to the earliest moment anything waits for
local wakeTimer, wakeTimerAt = nil, math.huge
local lastPollAt = -1
local OnWake
local function ArmWake()
    if ns.RulesDisabled then return end
    local t = minWake
    if ns.Timing then local dl = ns.Timing.NextDeadline(); if dl < t then t = dl end end
    if next(polled) ~= nil then local p = lastPollAt + TICK; if p < t then t = p end end
    if t == math.huge then
        if wakeTimer then wakeTimer:Cancel(); wakeTimer, wakeTimerAt = nil, math.huge end
        return
    end
    if wakeTimer and wakeTimerAt <= t + 0.0005 then return end   -- one is already set for that moment or earlier
    if wakeTimer then wakeTimer:Cancel() end
    local delay = t - GetTime()
    if delay < 0 then delay = 0 end
    wakeTimerAt = t
    wakeTimer = C_Timer.NewTimer(delay, OnWake)
end
local function RunLists(lists, all, cd)
    stepList, stepClearsDeadlines = lists, all and true or false
    cdFresh = (lists == nil or all or cd) and true or false
    SafeStep()
    stepList, stepClearsDeadlines, cdFresh = nil, true, true
    ArmWake()
end
-- every rule at once, now (V26: nothing steps while /xui disable holds); the stored moments it finds are waited for
ns.Step = function() if ns.RulesDisabled then return end Step(); ArmWake() end
local listAll = { live.all }
local runLists, due, dueLists = {}, {}, {}
dueLists[1] = due

-- the stored moment has come: the rules waiting for it (and the TICK re-check, when due)
OnWake = function()
    wakeTimer, wakeTimerAt = nil, math.huge
    if ns.RulesDisabled then return end
    local now = GetTime()
    if ns.Timing and now + 0.0005 >= ns.Timing.NextDeadline() then
        -- a "seconds left" threshold is crossed: the deadline does not say whose it is, so every live rule is re-checked (as before)
        ns.Timing.ClearDeadline()
        lastStateAt = now
        if next(polled) ~= nil then lastPollAt = now end
        return RunLists(listAll, true)
    end
    local n = 0
    minWake = math.huge
    for rule, at in pairs(wakeAt) do
        if at <= now + 0.0005 then n = n + 1; due[n] = rule; wakeAt[rule] = nil
        elseif at < minWake then minWake = at end
    end
    if next(polled) ~= nil and now + 0.0005 >= lastPollAt + TICK then
        lastPollAt = now
        for rule in pairs(polled) do n = n + 1; due[n] = rule end
    end
    for i = n + 1, #due do due[i] = nil end
    if n > 0 then RunLists(dueLists, false, true) else ArmWake() end
end

-- every rule once, or a load-fact check (next frame, after every other addon file has seen the event that asked for it)
local fullQueued = false
local function Settle()
    fullQueued = false
    if ns.RulesDisabled then pend.full, pend.ctx = false, false; return end
    local ctx
    if not pend.full then
        if not pend.ctx then return end
        pend.ctx = false
        ctx = ns.ReadContext()
        -- nothing a load check reads changed (the same values: ctx.sig, Conditions.lua ReadContext; the same talents): nothing to do
        if lastCtx and ctx.sig == lastCtxSig and ns.talentEpoch == lastTalentEp then return end
    end
    pend.full, pend.ctx, pend.all = false, false, false
    for _, k in ipairs(ROUTED) do pend[k] = false end
    local now = GetTime()
    lastStateAt = now   -- (the routed re-checks keep their own pace: a routed event right after still runs on the next frame)
    if next(polled) ~= nil then lastPollAt = now end
    presetCtx = ctx
    RunLists(nil, true)
    presetCtx = nil
end
local function QueueSettle()
    if fullQueued or ns.RulesDisabled then return end
    fullQueued = true
    C_Timer.After(0, Settle)
end

-- the next-frame re-checks of what events marked; the script is taken off as soon as nothing waits
local driving = false
local function AnyRouted() for _, k in ipairs(ROUTED) do if pend[k] then return true end end return false end
local function Drive()
    if ns.RulesDisabled then f:SetScript("OnUpdate", nil); driving = false; return end
    local now = GetTime()
    if pend.all and now - lastStateAt >= MIN_GAP then
        pend.all = false
        for _, k in ipairs(ROUTED) do pend[k] = false end   -- every live rule is in "all"
        lastStateAt = now
        RunLists(listAll, true)
    elseif now - lastRoutedAt >= ROUTED_DUE and AnyRouted() then
        -- D4: the rules that read what changed, this frame (at most once per ROUTED_GAP, review R18)
        local n, cd = 0, pend.cd
        for _, k in ipairs(ROUTED) do
            if pend[k] then pend[k] = false; if liveCount[k] and liveCount[k] > 0 then n = n + 1; runLists[n] = live[k] end end
        end
        for i = n + 1, #runLists do runLists[i] = nil end
        lastRoutedAt = now
        if n > 0 then RunLists(runLists, false, cd) end
    end
    if not (pend.all or AnyRouted()) then f:SetScript("OnUpdate", nil); driving = false end
end
-- a rule list replaced or grown without ns.MarkDirty (an edit that did not announce itself): the next re-check is a full step
local function ListChanged() return ns.rules ~= liveRules or (ns.rules and #ns.rules or 0) ~= liveRulesN end
local function Kick()
    if ListChanged() then pend.full = true; QueueSettle() end
    if driving or ns.RulesDisabled then return end
    driving = true
    f:SetScript("OnUpdate", Drive)
end

-- (ns.configVersion: settings changed, so memos keyed on settings - load checks - start over)
function ns.MarkDirty() barsDirty = true; ns.configVersion = (ns.configVersion or 0) + 1; ns.Fire("EDITED"); pend.full = true; QueueSettle() end
-- game state changed (a cast, movement, target ...): every loaded rule is re-checked on the next frame, keeping the minimum gap between them
function ns.MarkStateDirty() pend.all = true; Kick() end

function ns.OnDBReady()
    ns.RefreshAllVisuals()
    if ns.Bars_OnDBReady then ns.Bars_OnDBReady() end
    pend.full = true; QueueSettle()
end

-- auto-capture status into the ring-buffer log every SNAP_EVERY seconds of combat, since /xui debug status can't be typed mid-fight;
-- only while someone can read it (ns.LogWanted("snapshot"), Core.lua): otherwise no timer exists
local snapTicker
local function SnapTick() if inCombat and ns.LogStatusSnapshot and not ns.RulesDisabled then ns.LogStatusSnapshot("combat tick") end end
local function SnapStop() if snapTicker then snapTicker:Cancel(); snapTicker = nil end end

-- events: always registered (the load facts, the action bars, the state events the engine has always stepped on)
local CTX_EVENTS = {
    PLAYER_ENTERING_WORLD = true, PLAYER_REGEN_DISABLED = true, PLAYER_REGEN_ENABLED = true, GROUP_ROSTER_UPDATE = true,
    ZONE_CHANGED_NEW_AREA = true, ZONE_CHANGED = true, ZONE_CHANGED_INDOORS = true, PLAYER_DIFFICULTY_CHANGED = true,
    PLAYER_SPECIALIZATION_CHANGED = true, TRAIT_CONFIG_UPDATED = true, SPELLS_CHANGED = true, PLAYER_TALENT_UPDATE = true,
    PLAYER_MOUNT_DISPLAY_CHANGED = true, PLAYER_UPDATE_RESTING = true, PLAYER_EQUIPMENT_CHANGED = true,
    CHALLENGE_MODE_START = true, CHALLENGE_MODE_COMPLETED = true, CHALLENGE_MODE_RESET = true, ENCOUNTER_START = true, ENCOUNTER_END = true,
    UNIT_FLAGS = true,   -- (player: the combat flag; UnitAffectingCombat is a load fact)
}
-- load facts another file keeps from the event itself (Conditions.lua ns.LoadEvent: the encounter, the equipment count), that the engine
-- itself changes here (talents), or that the game sets only after the event (PLAYER_REGEN_DISABLED comes just before combat lockdown,
-- INFERENCE from Blizzard's secure code; the stand-in game sets combat after the event too): read on the next frame, once every handler ran
local CTX_LATER = { ENCOUNTER_START = true, ENCOUNTER_END = true, PLAYER_EQUIPMENT_CHANGED = true, PLAYER_ENTERING_WORLD = true,
    PLAYER_SPECIALIZATION_CHANGED = true, TRAIT_CONFIG_UPDATED = true, SPELLS_CHANGED = true, PLAYER_TALENT_UPDATE = true,
    PLAYER_REGEN_DISABLED = true, PLAYER_REGEN_ENABLED = true }
local BAR_EVENTS = { ACTIONBAR_SLOT_CHANGED = true, UPDATE_BONUS_ACTIONBAR = true, ACTIONBAR_PAGE_CHANGED = true, UPDATE_SHAPESHIFT_FORM = true }
for e in pairs(CTX_EVENTS) do if e ~= "UNIT_FLAGS" then f:RegisterEvent(e) end end
f:RegisterUnitEvent("UNIT_FLAGS", "player")
for e in pairs(BAR_EVENTS) do f:RegisterEvent(e) end
f:RegisterEvent("PLAYER_TARGET_CHANGED"); f:RegisterEvent("PLAYER_FOCUS_CHANGED")   -- a new target / focus changes every target answer at once
-- events registered only while a live rule reads their input (Watch, from LiveChanged): kind -> { event, unit or false }
local INPUT_EVENTS = {
    cd = { { "SPELL_UPDATE_COOLDOWN" }, { "SPELL_UPDATE_CHARGES" }, { "SPELL_UPDATE_USABLE" }, { "ACTIONBAR_UPDATE_COOLDOWN" },
           { "ACTIONBAR_UPDATE_USABLE" }, { "BAG_UPDATE_COOLDOWN" } },
    aura = { { "UNIT_AURA", "player" } },
    power = { { "UNIT_POWER_UPDATE", "player" }, { "UNIT_MAXPOWER", "player" }, { "UNIT_DISPLAYPOWER", "player" }, { "RUNE_POWER_UPDATE" } },
    range = { { "SPELL_RANGE_CHECK_UPDATE" } },
    cast = { { "UNIT_SPELLCAST_SUCCEEDED", "player" } },
}
local inputFrame = CreateFrame("Frame")   -- (its own frame: UNIT_AURA on you here, on the target / focus on tgtFrame)
local tgtFrame = CreateFrame("Frame")
local KIND_OF, UNIT_OF = {}, {}
for k, list in pairs(INPUT_EVENTS) do for _, e in ipairs(list) do KIND_OF[e[1]] = k; UNIT_OF[e[1]] = e[2] or nil end end
local watching = {}   -- kind -> true while its events are registered
Watch = function()
    for k, list in pairs(INPUT_EVENTS) do
        local want = not ns.RulesDisabled and (liveCount[k] or 0) > 0
        if want ~= (watching[k] or false) then
            watching[k] = want or nil
            for _, e in ipairs(list) do
                if want then
                    if e[2] then inputFrame:RegisterUnitEvent(e[1], e[2]) else inputFrame:RegisterEvent(e[1]) end
                else
                    inputFrame:UnregisterEvent(e[1])
                end
            end
        end
    end
    local wantT = not ns.RulesDisabled and (liveCount.tgt or 0) > 0
    if wantT ~= (watching.tgt or false) then
        watching.tgt = wantT or nil
        if wantT then tgtFrame:RegisterUnitEvent("UNIT_AURA", "target", "focus") else tgtFrame:UnregisterEvent("UNIT_AURA") end
    end
end
-- (RegisterUnitEvent already limits the unit events to the units named; the unit is checked again here, at the cost of one compare)
inputFrame:SetScript("OnEvent", function(_, event, unit)
    if perf.on then perf.events[event] = (perf.events[event] or 0) + 1 end
    local k = KIND_OF[event]
    local u = UNIT_OF[event]
    if u and unit ~= u then return end
    if event == "UNIT_AURA" then ns.lastAuraEventAt = GetTime() end   -- (Conditions.lua stamps an aura's appearance with it)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then NoteCast(GetTime()) end
    if k then pend[k] = true; Kick() end
end)
tgtFrame:SetScript("OnEvent", function(_, event, unit)
    if unit ~= "target" and unit ~= "focus" then return end
    if perf.on then perf.events["UNIT_AURA (target / focus)"] = (perf.events["UNIT_AURA (target / focus)"] or 0) + 1 end
    pend.tgt = true; Kick()
end)
f:SetScript("OnEvent", function(_, event, arg1)
    if event == "UNIT_FLAGS" and arg1 ~= "player" then return end
    if perf.on then perf.events[event] = (perf.events[event] or 0) + 1 end
    if event == "PLAYER_ENTERING_WORLD" then
        if ns.ClearSecrecyCache then ns.ClearSecrecyCache() end
        inCombat = (UnitAffectingCombat and UnitAffectingCombat("player")) and true or false   -- a /reload can land mid-fight
    end
    if event == "PLAYER_SPECIALIZATION_CHANGED" or event == "TRAIT_CONFIG_UPDATED" or event == "PLAYER_ENTERING_WORLD" or event == "SPELLS_CHANGED"
        or event == "PLAYER_TALENT_UPDATE" then
        ns.talentList = nil; ns.spellList = nil
        -- (review R3) talents may have changed: the kept talent answers (Conditions.lua CheckTalents) are read again; another unit's spec
        -- change does not count
        if event ~= "PLAYER_SPECIALIZATION_CHANGED" or arg1 == "player" then ns.talentEpoch = (ns.talentEpoch or 0) + 1 end
    end
    -- audit D54 (core 0.6.67): On Initialization runs again after a spec change (USER-GUIDE Actions tab; Actions.lua), for every rule
    -- (the event carries unitTarget, events.md 1215, and is registered for every unit: only the player's own spec change counts)
    if event == "PLAYER_SPECIALIZATION_CHANGED" and arg1 == "player" then for _, rt in pairs(ns.runtime or {}) do rt.inited = nil end end
    -- auto-capture status into the ring-buffer log at combat start/end, since /xui debug status can't be typed mid-fight
    -- (V26: not while every rule is off by /xui disable: a snapshot may check rules)
    if event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
        if ns.LogStatusSnapshot and not ns.RulesDisabled then ns.LogStatusSnapshot("combat start") end
        SnapStop()
        if not ns.RulesDisabled and ns.LogWanted and ns.LogWanted("snapshot") then snapTicker = C_Timer.NewTicker(SNAP_EVERY, SnapTick) end
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
        SnapStop()
        if ns.LogStatusSnapshot and not ns.RulesDisabled then ns.LogStatusSnapshot("combat end") end
    end
    if event == "PLAYER_ENTERING_WORLD" or event == "SPELLS_CHANGED" or event == "PLAYER_SPECIALIZATION_CHANGED" or BAR_EVENTS[event] then barsDirty = true end
    if CTX_EVENTS[event] then
        if CTX_LATER[event] then
            pend.ctx = true; QueueSettle()   -- (another file's handler of this event updates what the context reads: checked next frame)
        elseif not pend.full and not ns.RulesDisabled then
            -- the game's own answers are current when the event arrives: compared now, so an event that changed nothing a load check
            -- reads (a roster update with the same group, a subzone with the same map) costs one read and no timer
            local ctx = ns.ReadContext()
            if not (lastCtx and ctx.sig == lastCtxSig and ns.talentEpoch == lastTalentEp) then pend.full = true; QueueSettle() end
        end
    end
    -- the action bars, a form, a new target / focus: every loaded rule (a stance row, "only while on an action bar", target answers)
    if BAR_EVENTS[event] or event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" or event == "SPELLS_CHANGED" then
        pend.all = true
        if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" then pend.tgt = true end
        Kick()
    end
end)

-- (V26) /xui disable (Xaya 2026-11-10, her answer: "/xui disable: all rules off"): the emergency off for every rule, allowed in combat.
-- The engine stops at once (no step, no rule checked, no cue fired, no sound played by XayaUI, no timer, no input event registered);
-- each rule's running state is cleared without its After It Ends actions (they can play a sound or post a message), XayaUI's own rule
-- displays are hidden (XayaUI's frames: allowed in combat), previews end, and RULES_DISABLED tells the parts that show or play something
-- for a rule on their own (Modules.lua section 6). Session only: nothing is saved, so a /reload turns rules back on (no saved switch for
-- this existed). /xui enable (never in combat: Core.lua waits for combat end) steps every rule on the next frame.
-- Rules start fresh after /xui enable, as after a /reload: each rule's running and loaded state was cleared here, so its On
-- Initialization actions run again and a rule still true runs its During actions again (its glow comes back: Actions.lua stopped every
-- glow at RULES_DISABLED). The enable line says so (XayaUI/Core.lua).
function ns.SetRulesDisabled(on)
    on = on and true or false
    if on == (ns.RulesDisabled == true) then return false end
    ns.RulesDisabled = on or nil
    if on then
        f:SetScript("OnUpdate", nil); driving = false
        if wakeTimer then wakeTimer:Cancel(); wakeTimer, wakeTimerAt = nil, math.huge end
        SnapStop()
        pend.full, pend.ctx, pend.all = false, false, false
        for _, k in ipairs(ROUTED) do pend[k] = false end
        ClearLive(); LiveChanged()   -- (no rule is live: the input events are let go, the range checks turned off)
        for k in pairs(wakeAt) do wakeAt[k] = nil end
        for k in pairs(polled) do polled[k] = nil end
        minWake = math.huge
        if ns.AnyPreview and ns.AnyPreview() and ns.ClearPreview then pcall(ns.ClearPreview) end
        for _, rule in ipairs(ns.rules or {}) do
            local rt = ns.runtime[rule]
            if rt then
                rt.active, rt.inited, rt.pvLast, rt.offDone = false, nil, nil, nil
                if rt.visualWanted then rt.visualWanted = false; if ns.SetVisualShown then pcall(ns.SetVisualShown, rule, false) end end
            end
        end
        ns.Fire("RULES_DISABLED")
    else
        barsDirty = true
        lastStateAt, lastRoutedAt = -1, -1
        pend.full = true; QueueSettle()
        ns.Fire("RULES_ENABLED")
    end
    return true
end
