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
--     built once whenever the settings or the load facts change). (round 6) An aura or cooldown event marks the aura / cooldown CHECKS it
--     can change; they are read once each and only the rules whose check answered differently are re-checked (the checks section below,
--     REQUEST-LOG A23 SD-54). (round 7, SD-61, her answer "10/s for all, like EUI") these routed passes run at most 10 times a second
--     for every unit: the first change after a quiet moment is handled on the very next frame; in a burst the next pass waits until
--     a tenth of a second after the last one. Each pass runs from a one-shot timer the first event after the last pass made, so a
--     timer exists only while a change waits to be checked, and none is set once the changes stop: no frame script, no pump;
--   * a load fact changing (combat, group, zone, mount, spec, talents ...) re-checks every rule once, on the next frame;
--   * time-based changes are waited for with one one-shot timer set to the stored moment they happen: the next whole second of a
--     countdown a display shows, the end of a cooldown, a "cast within N seconds" window, a repeat sound, a "seconds left" threshold
--     (Timing.lua deadlines);
--   * only what the game hides the moment of (a cooldown's end in combat, seconds a display reads from a secret duration, the range to
--     a focus / mouseover / pet) is re-checked every TICK, and only for the loaded rules that wait on it, only while they wait.
-- With nothing loaded waiting on time (idle out of combat, every aura and cooldown gone) nothing of the engine runs.
local TICK = 0.2   -- the re-check pace for what the game hides the moment of (above); nothing else runs on it
local MIN_GAP = 0.05   -- events (casts, movement, target changes) can come many a second: their re-checks run at most this often
-- (review R18; round 7, SD-61, her answer "10/s for all, like EUI (Recommended)") routed re-checks (your auras, the target's and the
-- focus's auras, cooldowns, resources, range, casts): the first after a quiet moment still runs on the very next frame; in a burst (a
-- raid fight) they run at most once per ROUTED_GAP, 10 a second, for every unit. A held re-check waits at most this long (no event is
-- lost). A pass is due once ROUTED_GAP has gone by since the last one, less half a millisecond for rounding in the stored moments (six
-- 60 fps frames add up to a hair under 0.1 s).
local ROUTED_GAP = 0.1
local ROUTED_DUE = ROUTED_GAP - 0.0005
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
        -- (round 6, SD-54) a display greyed while the spell cools down follows the cooldown events itself; before, an aura rule's grey
        -- changed only when an aura event happened to re-check the rule
        if v.desatOnCD and sid ~= 0 and not d.ownCd then d.cd = true; d.cdSpells = d.cdSpells or {}; d.cdSpells[#d.cdSpells + 1] = sid end
        -- texts the display reads from the game itself when it is drawn (a charge count, a shield amount): the rule is checked again
        -- on every cooldown / aura event of its kind, as before, since the reading the engine compares does not show them changing
        if type(v.count) == "table" and v.count.enabled and ns.Val(v.count.source) == "charges" then d.cdText = true end
        if type(v.absorb) == "table" and v.absorb.enabled then d.auraText = true end
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
local BuildProbes    -- (the aura and cooldown checks below: built from the live lists)
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
    if BuildProbes then BuildProbes() end
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
local deadlineOf = setmetatable({}, { __mode = "k" })   -- rule -> the "seconds left" moment its last check registered (Timing.lua)
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
    -- a "seconds left" threshold this rule's own check registered (Timing.lua deadlines, kept per rule: StepTracked below)
    local dl = deadlineOf[rule]
    if dl and dl > now then at = Earlier(at, dl) end
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
-- (round 6, review R3 gate 2) the "seconds left" moment a rule's check registers (Timing.lua T.Deadline) is kept for that rule, so the
-- moment re-checks that rule and its cues only; before, the engine kept one moment for all rules and re-checked every live rule at it
local function StepTracked(rule, ctx, now, off)
    local T = ns.Timing
    if T then T.ClearDeadline() end
    StepOne(rule, ctx, now, off)
    if T then local dl = T.NextDeadline(); deadlineOf[rule] = (dl < math.huge) and dl or nil end
end

-------------------------------------------------------------------------------
-- The aura and cooldown checks (round 6; REQUEST-LOG A23 SD-54, her words "check how EUI checks. it does not fail and performance is
-- kept low"; the design and its reasons: docs/plans/AURA-CHECKS-EUI-STUDY-2026-11-12.md, our own design and code). An aura or a
-- cooldown event no longer re-checks every rule that reads auras or cooldowns. Instead:
--   * each thing the live rules read from auras or cooldowns is one CHECK: a rule's own Buff / Aura (the same ns.AuraPresence call
--     ns.Evaluate makes, with the same time estimate), each "Buff / Aura (another)" and "Target Debuff (yours)" row (ns.CheckTrigger, as
--     ns.CheckExtraTriggers calls it), a rule's own cooldown and each "Cooldown (any spell)" row (ns.ReadCooldown, the same memo the rule
--     reads), and each other cooldown row (Spell Usable, Global Cooldown, Item Usable: ns.CheckTrigger). Built once per settings or
--     load-fact change (LiveChanged), never per event;
--   * an event marks the checks it can change, read from its payload when the game shows it: the spell IDs of auras added, the aura
--     instances updated or removed (looked up in a small memory of the watched auras' instance IDs). A payload the game hides (combat),
--     a full update, an instance the memory cannot vouch for: every check of that unit. Nothing in a hidden payload is ever tested. A
--     cooldown event marks every cooldown check (RouteCooldown below: its payload is no proof of what changed);
--   * on the next frame (the same pace as before) the marked checks are read once each, inside the engine step (so every read is the
--     step's own memo: the very reads the rules then use), and compared with what they read last. Only the rules whose check answered
--     differently are checked again in full. A rule checked for any other reason since its check was last read is checked again too
--     (its check counts as changed), so a rule can never be left on an answer its check no longer gives;
--   * a check whose answer does not come from the aura API alone (the Cooldown Manager's icons, a name match, the tracker's estimate,
--     an unknown answer) is read on every aura event of its unit, as every aura rule was before; a rule whose display shows a text the
--     game hands over at drawing time (a shield amount, a charge count) is checked again on every event of its kind, as before.
-- So an aura or cooldown change costs one read per marked check, and a full check only of the rules whose answer changed; the worst case
-- (everything hidden, everything changed) checks the same rules as before. UNVERIFIED IN GAME.
-------------------------------------------------------------------------------
local probeUnits = {}   -- unit -> { probes = {}, idx = { [spellID] = { check, ... } }, mem = { [instanceID] = spellID (an added aura) },
                        --          memP = { [instanceID] = check or list (what a check read) }, complete,
                        --          whole, touched, loose = { rule, ... } (re-checked on every event of the unit), nonDirect }
for _, u in ipairs({ "player", "target", "focus" }) do probeUnits[u] = { probes = {}, idx = {}, mem = {}, memP = {}, loose = {}, complete = false, nonDirect = 0 } end
local cdChecks = { probes = {}, loose = {}, whole = false }   -- (every cooldown check is read on every cooldown event: RouteCooldown)
local probesOf = setmetatable({}, { __mode = "k" })   -- live rule -> its checks (every unit and cooldowns)
local famOf = setmetatable({}, { __mode = "k" })      -- live rule -> the live rules that share its triggers (a rule and its cues)
-- the checks an event marked, read on the next pass: a list and a flag on each check (no table keys added and dropped per event, which
-- made the table grow and shrink again: garbage on every aura event)
local pendList, pendN = {}, 0
local function Mark(pr) if not pr.pending then pr.pending = true; pendN = pendN + 1; pendList[pendN] = pr end end
local function ClearMarks() for i = 1, pendN do pendList[i].pending = false end; pendN = 0 end
local buildSerial = 0
local probeDue = {}       -- the rules the last read found changed (reused list)
local lastCdmGen = nil
local PROBE_UNITS = { "player", "target", "focus" }

-- the values a check read, stored in its own table: true when all of them were there already (one call per check, no call per field,
-- no table made). The values are what the readers hand back after their own cleaning (no secret among them); should one ever be secret,
-- the compare errors and the caller (CheckOne, under pcall) counts the check as changed.
local function Same16(fp, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14, v15, v16)
    local same = true
    if fp[1] ~= v1 then fp[1] = v1; same = false end
    if fp[2] ~= v2 then fp[2] = v2; same = false end
    if fp[3] ~= v3 then fp[3] = v3; same = false end
    if fp[4] ~= v4 then fp[4] = v4; same = false end
    if fp[5] ~= v5 then fp[5] = v5; same = false end
    if fp[6] ~= v6 then fp[6] = v6; same = false end
    if fp[7] ~= v7 then fp[7] = v7; same = false end
    if fp[8] ~= v8 then fp[8] = v8; same = false end
    if fp[9] ~= v9 then fp[9] = v9; same = false end
    if fp[10] ~= v10 then fp[10] = v10; same = false end
    if fp[11] ~= v11 then fp[11] = v11; same = false end
    if fp[12] ~= v12 then fp[12] = v12; same = false end
    if fp[13] ~= v13 then fp[13] = v13; same = false end
    if fp[14] ~= v14 then fp[14] = v14; same = false end
    if fp[15] ~= v15 then fp[15] = v15; same = false end
    if fp[16] ~= v16 then fp[16] = v16; same = false end
    return same
end
local function RefFields(ref)
    if type(ref) ~= "table" then return false end
    return true, ref.expiration, ref.duration, ref.applications, ref.instanceID, ref.hiddenID, ref.unit, ref.cdmFrame, ref.estimated
end
-- does an aura check's answer come from the aura API alone (so only an event about one of its own auras can change it)?
local function ApiOnly(present, src, ids1, ids2)
    if present == nil or type(src) ~= "string" then return false end
    if src:find("CDM", 1, true) or src:find("Cooldown Manager", 1, true) then return false end
    if not (src:sub(1, 4) == "aura" or src:sub(1, 9) == "set bonus") then return false end
    local find = ns.FindCDMFrame
    if find then
        if ids1 and find(ids1) then return false end
        if type(ids2) == "table" then for i = 1, #ids2 do local id = tonumber(ids2[i]); if id and find(id) then return false end end end
    end
    return true
end
local function Pcall3(fn, a, b, c) return pcall(fn, a, b, c) end
-- read one check; true when it answered as it did last time
local function ProbeSame(pr)
    local fp, k = pr.fp, pr.kind
    if k == "buff" then
        local P = pr.root
        local ok, p, src, ref, which = Pcall3(ns.AuraPresence, P.buffID, P.buffAlt, P.spellID)
        if not ok then p, src, ref, which = nil, nil, nil, nil end
        local ee, ed
        local timed = type(ref) == "table" and ref.expiration ~= nil
        if p == true and type(ref) == "table" and not timed and P.buffEstimate ~= false and ns.AuraEstimateTimes then
            local okE, e1, e2 = pcall(ns.AuraEstimateTimes, which or P.buffID, ref)
            if okE then ee, ed = e1, e2 end
        end
        local t, r1, r2, r3, r4, r5, r6, r7, r8 = RefFields(ref)
        local same = Same16(fp, p, src, which, t, r1, r2, r3, r4, r5, r6, r7, r8, ee, ed, nil, nil)
        -- (a present aura with no readable time is answered by an estimate that moves with your casts: read on every aura event)
        pr.direct = ApiOnly(p, src, tonumber(P.buffID), P.buffAlt) and not (p == true and not timed)
        pr.present = p
        pr.iid = (p == true and t and not issecret(r4)) and r4 or nil
        return same
    elseif k == "arow" or k == "trow" then
        local tr = pr.row
        local r, d = ns.CheckTrigger(tr)
        local pp, ref = nil, nil
        if ns.TriggerAuraRef then pp, ref = ns.TriggerAuraRef(tr) end
        local t, r1, r2, r3, r4, r5, r6, r7, r8 = RefFields(ref)
        local same = Same16(fp, r, d, pp, t, r1, r2, r3, r4, r5, r6, r7, r8, nil, nil, nil, nil)
        if k == "arow" then
            pr.direct = r ~= nil and ApiOnly(pp, d == nil and "aura" or d, tonumber(tr.spellID), tr.alt) and not (pp == true and r1 == nil)
        else
            -- a Target Debuff row answers from the game's list of your debuffs unless it says otherwise (the icon, hidden, combat)
            pr.direct = r ~= nil and pp ~= nil and (d == nil or (type(d) == "string" and d:sub(1, 3) == "no "))
        end
        pr.present = pp
        pr.iid = (pp == true and t and not issecret(r4)) and r4 or nil
        return same
    elseif k == "cd" then
        local c = ns.ReadCooldown(pr.reader)
        if type(c) ~= "table" then return Same16(fp, nil, false) end
        return Same16(fp, c.known, c.max, c.onCd, c.atMax, c.empty, c.count, c.onGCD, c.locked, c.readID, c.readyAt, c.estimated, c.why,
            nil, nil, nil, nil)
    else   -- "crow": Spell Usable / Global Cooldown / Item Usable
        local r, d = ns.CheckTrigger(pr.row)
        return Same16(fp, r, d)
    end
end

-- (round 7, SD-63) ver counts the answers a check has given: it goes up each time a read finds the answer changed. seen[i] is the answer
-- (ver) its reader readers[i] was last checked against. A check is shared by a rule and its cues; before, the shared reading alone said
-- whether "the answer changed", so when one reader (a rule woken by its countdown) read the new answer first, the next event's read
-- found it "the same" and the other readers (its icon cue) were never checked again: the cue's icon stayed on screen after its aura was
-- gone. Now a reader is checked again whenever the answer it last saw is not the check's current one, whoever read the change first.
local function NewCheck(kind, root, unit)
    return { kind = kind, root = root, unit = unit, readers = {}, seen = {}, ver = 0, fp = {}, valid = false, tick = -1, direct = false }
end
local function IndexCheck(idx, id, pr)
    id = tonumber(id)
    if not id or id == 0 then return end
    local l = idx[id]
    if not l then l = {}; idx[id] = l end
    if l[#l] ~= pr then l[#l + 1] = pr end
end
local function IndexAuraIDs(idx, pr, main, alts)
    local al = ns.AuraAliasesOf
    local function one(id)
        id = tonumber(id)
        if not id or id == 0 then return end
        IndexCheck(idx, id, pr)
        local a = al and al(id)
        if a then for aid in pairs(a) do IndexCheck(idx, aid, pr) end end
    end
    one(main)
    if type(alts) == "table" then for i = 1, #alts do one(alts[i]) end end
end
local function Wipe(t) for k in pairs(t) do t[k] = nil end end
local function AddUnique(l, x) for i = 1, #l do if l[i] == x then return end end l[#l + 1] = x end
local function SlotOf(l, x) for i = 1, #l do if l[i] == x then return i end end local n = #l + 1; l[n] = x; return n end

-- built from the live lists (LiveChanged): every check, who reads it, and the indexes the events use
BuildProbes = function()
    for _, u in ipairs(PROBE_UNITS) do
        local U = probeUnits[u]
        U.probes, U.idx, U.loose = {}, {}, {}
        Wipe(U.mem); Wipe(U.memP); U.complete, U.whole, U.touched, U.nonDirect = false, false, false, 0
    end
    cdChecks.probes, cdChecks.loose = {}, {}
    cdChecks.whole = false
    ClearMarks()
    lastCdmGen = ns.cdmGen
    buildSerial = buildSerial + 1
    if ns.RulesDisabled then return end
    local rootChecks = {}   -- root -> { checks of its own aura / cooldown triggers }
    local fam = {}          -- root -> live rules sharing it
    local function Root(rule)
        if rule.parentUid and ns.FindParentRule then return ns.FindParentRule(rule) or rule end
        return rule
    end
    local function ChecksOf(root, loaded)
        local c = rootChecks[root]
        if c then return c end
        c = { aura = {}, cd = {} }
        rootChecks[root] = c
        local d = Deps(root)
        -- its own Buff / Aura: read for every rule that reads auras (ns.Evaluate reads it for each loaded rule, and for a rule that is
        -- not loaded only when its display follows the buff)
        -- (with no aura ID the reading is the same "no buff" every time: nothing to read)
        local U = probeUnits.player
        if (tonumber(root.buffID) or 0) ~= 0 then
            local pr = NewCheck("buff", root, "player")
            c.aura[#c.aura + 1] = pr
            U.probes[#U.probes + 1] = pr
            IndexAuraIDs(U.idx, pr, root.buffID, root.buffAlt)
        end
        if loaded then
            local list = type(root.extra) == "table" and type(root.extra.list) == "table" and root.extra.list or nil
            if list then
                for _, t in ipairs(list) do
                    if type(t) == "table" then
                        if t.type == "buffAura" then
                            local r = NewCheck("arow", root, "player"); r.row = t
                            c.aura[#c.aura + 1] = r; U.probes[#U.probes + 1] = r
                            IndexAuraIDs(U.idx, r, t.spellID, t.alt)
                        elseif t.type == "targetDebuff" then
                            local unit = (t.unit == "focus") and "focus" or "target"
                            local TU = probeUnits[unit]
                            local r = NewCheck("trow", root, unit); r.row = t
                            c.aura[#c.aura + 1] = r; TU.probes[#TU.probes + 1] = r
                            IndexCheck(TU.idx, t.spellID, r)
                        elseif t.type == "cooldown" then
                            local r = NewCheck("cd", root, "cd"); r.row = t
                            r.reader = { spellID = tonumber(t.spellID), maxCharges = tonumber(t.maxCharges) or 0, exactSpell = t.exactSpell and true or nil }
                            c.cd[#c.cd + 1] = r; cdChecks.probes[#cdChecks.probes + 1] = r
                        elseif t.type == "actionUsable" or t.type == "globalCooldown" or t.type == "itemUsable" then
                            local r = NewCheck("crow", root, "cd"); r.row = t
                            c.cd[#c.cd + 1] = r; cdChecks.probes[#cdChecks.probes + 1] = r
                        end
                    end
                end
            end
            -- its own cooldown (ns.Evaluate reads it for every loaded rule)
            if d.cd then
                local r = NewCheck("cd", root, "cd"); r.reader = root
                c.cd[#c.cd + 1] = r; cdChecks.probes[#cdChecks.probes + 1] = r
            end
        end
        return c
    end
    local function Reader(rule, root, list)
        local f = fam[root]
        if not f then f = {}; fam[root] = f end
        AddUnique(f, rule)
        famOf[rule] = f
        -- mine: pairs (a check, this rule's place among its readers), each check once
        local mine = probesOf[rule]
        if not mine or mine.serial ~= buildSerial then mine = { serial = buildSerial }; probesOf[rule] = mine end
        for i = 1, #list do
            local pr = list[i]
            local slot = SlotOf(pr.readers, rule)
            if pr.seen[slot] == nil then pr.seen[slot] = -1 end
            local have = false
            for j = 1, #mine, 2 do if mine[j] == pr then have = true; break end end
            if not have then mine[#mine + 1] = pr; mine[#mine + 1] = slot end
        end
    end
    for _, rule in ipairs(live.aura) do
        local root = Root(rule)
        local c = ChecksOf(root, not NotLoaded(rule))
        Reader(rule, root, c.aura)
        local own = false
        for i = 1, #c.aura do if c.aura[i].unit == "player" then own = true; break end end
        if Deps(root).auraText or not own then AddUnique(probeUnits.player.loose, rule) end
    end
    for _, rule in ipairs(live.tgt) do local root = Root(rule); Reader(rule, root, ChecksOf(root, true).aura) end
    for _, rule in ipairs(live.cd) do
        local root = Root(rule)
        local c = ChecksOf(root, true)
        Reader(rule, root, c.cd)
        if #c.cd == 0 or Deps(root).cdText then AddUnique(cdChecks.loose, rule) end
    end
end

-- after a full step (every rule was just checked): each check is read once, in the same step, so the next event compares with what
-- the rules saw

-- the memory of the watched auras' instance IDs, from what the checks just read; "complete" when every check of the unit answered
-- from the aura API and every present aura's instance ID was readable (then an unknown instance cannot be a watched aura)
local function NoteMem(U, pr)
    local iid = pr.iid
    if iid ~= nil then
        local m = U.memP[iid]
        if m == nil then U.memP[iid] = pr
        elseif m ~= pr then
            if m.kind then m = { m }; U.memP[iid] = m end   -- (two checks see the same aura: a small list)
            AddUnique(m, pr)
        end
    end
end
local function CountLoose(U)
    local n, complete = 0, true
    for i = 1, #U.probes do
        local pr = U.probes[i]
        if not pr.direct then n = n + 1; complete = false
        elseif pr.present == true and pr.iid == nil then complete = false end
    end
    U.nonDirect = n
    return complete
end

-- read one check in this step: its answer count (ver) goes up when the answer is not the one read last (or could not be read)
local function ReadCheck(pr, tick)
    local ok, same = pcall(ProbeSame, pr)
    if not (ok and same and pr.valid) then pr.ver = pr.ver + 1 end
    pr.valid, pr.tick = ok, tick
end
-- after a full step (every rule was just checked): each check is read once, in the same step, so the next event compares with what
-- the rules saw (every reader has seen this answer), and the memory of the watched auras' instance IDs starts from these reads
local function SeenAll(pr) local s, v = pr.seen, pr.ver; for i = 1, #pr.readers do s[i] = v end end
local function PrimeProbes()
    local tick = ns.tickID
    for _, u in ipairs(PROBE_UNITS) do
        local U = probeUnits[u]
        Wipe(U.mem); Wipe(U.memP)
        for i = 1, #U.probes do local pr = U.probes[i]; ReadCheck(pr, tick); SeenAll(pr); NoteMem(U, pr) end
        U.complete = CountLoose(U)
    end
    for i = 1, #cdChecks.probes do local pr = cdChecks.probes[i]; ReadCheck(pr, tick); SeenAll(pr) end
end
-- read the marked checks (inside the step), and list the rules that have not seen the check's current answer (it changed now, or it
-- changed when another reader read it since)
local function CheckOne(pr, n, tick)
    ReadCheck(pr, tick)
    local rd, seen, v = pr.readers, pr.seen, pr.ver
    for i = 1, #rd do if seen[i] ~= v then n = n + 1; probeDue[n] = rd[i] end end
    return n
end
local function AddLoose(l, n) for i = 1, #l do n = n + 1; probeDue[n] = l[i] end return n end
local function RunProbes()
    local n, tick = 0, ns.tickID
    if ns.cdmGen ~= lastCdmGen then   -- which icon stands for which spell changed: every aura check is read again
        lastCdmGen = ns.cdmGen
        for _, u in ipairs(PROBE_UNITS) do local U = probeUnits[u]; if #U.probes > 0 and (U.whole or U.touched) then U.whole = true end end
    end
    for _, u in ipairs(PROBE_UNITS) do
        local U = probeUnits[u]
        if U.whole then
            Wipe(U.mem); Wipe(U.memP)
            for i = 1, #U.probes do local pr = U.probes[i]; n = CheckOne(pr, n, tick); NoteMem(U, pr) end
            U.complete = CountLoose(U)
            n = AddLoose(U.loose, n)
        elseif U.touched then
            for i = 1, #U.probes do
                local pr = U.probes[i]
                if pr.pending or not pr.direct or not pr.valid then n = CheckOne(pr, n, tick); NoteMem(U, pr) end
            end
            if not CountLoose(U) then U.complete = false end
            n = AddLoose(U.loose, n)
        end
        U.whole, U.touched = false, false
    end
    local C = cdChecks
    if C.whole then
        for i = 1, #C.probes do n = CheckOne(C.probes[i], n, tick) end
        n = AddLoose(C.loose, n)
        C.whole = false
    end
    ClearMarks()
    for i = n + 1, #probeDue do probeDue[i] = nil end
    return n
end
-- a rule was checked in full: its checks that were not read in this same step are read now, in the same step (the step's memos: the
-- very values the rule just saw), and the rule is noted as having seen each check's current answer. When such a read finds the answer
-- changed, the check's other readers have not seen it: the next read of the check (the event that changed it marks it) checks them.
local function ProbesStale(rule, tick)
    local l = probesOf[rule]
    if not l or l.serial ~= buildSerial then return end
    for i = 1, #l, 2 do
        local pr = l[i]
        if pr.tick ~= tick then ReadCheck(pr, tick) end
        pr.seen[l[i + 1]] = pr.ver
    end
end
local function AnyProbeWork()
    if cdChecks.whole then return true end
    for _, u in ipairs(PROBE_UNITS) do local U = probeUnits[u]; if U.whole or U.touched then return true end end
    return false
end

local talentRules, talentN = {}, 0   -- the switched-on rules with a talent requirement (rebuilt by every full step; TalentEventCheck)
local stepProbe = false             -- set for one Step call: read the marked aura / cooldown checks first
-- the live rules of one list, each once per step (a rule in two lists is stepped once)
local function StepLive(l, ctx, now)
    local tick = ns.tickID
    for j = 1, #l do
        local rule = l[j]
        if seen[rule] ~= stepSerial then
            seen[rule] = stepSerial
            local pv = (pvV and pvV[rule]) or (pvS and pvS[rule]) or false
            StepTracked(rule, ctx, now, pv and ns.RuleOff(rule) or false)   -- (only a previewed rule can be live while off)
            ProbesStale(rule, tick)
            Plan(rule, RT(rule), now, pv)
        end
    end
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
        talentN = 0
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
            if not off or (rt0 and not rt0.offDone) or pv then StepTracked(rule, ctx, now, off) end
            if AddLive(rule, off, pv) then Plan(rule, RT(rule), now, pv) else Unplan(rule) end
            -- the rules with a talent requirement, compared on a talent-tree event (TalentEventCheck below)
            if not off and ns.HasTalentRequirement and ns.HasTalentRequirement(rule) then talentN = talentN + 1; talentRules[talentN] = rule end
        end
        for i = talentN + 1, #talentRules do talentRules[i] = nil end
        LiveChanged()
        PrimeProbes()   -- (each aura / cooldown check is read once now, so the next event compares with what the rules just saw)
    else
        -- the aura and cooldown checks the events marked: read once each, here, in this step; the rules whose check changed join the run
        local pn = stepProbe and RunProbes() or 0
        for i = 1, #lists do StepLive(lists[i], ctx, now) end
        if pn > 0 then StepLive(probeDue, ctx, now) end
    end
end

-- /xui debug perf: measures the engine on this machine. Off by default; while on, each Step is timed with debugprofilestop,
-- split into rule evaluation / visual updates, with the most expensive rules named. Every report is also saved to
-- XayaUI Dev Assist's XayaUIDevAssistDB.perfLog (P5, B11; CueRulesDB.perfLog before; only while Dev Assist is on) (last 6) so it survives /reload and can be read from the saved variables.
local function PerfReset()
    perf.steps, perf.total, perf.max, perf.events, perf.t0 = 0, 0, 0, {}, GetTime()
    perf.evalMs, perf.visMs, perf.fxMs, perf.fxN = 0, 0, 0, 0
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
    ns.BeginStepIndex(stepList ~= nil)   -- a re-check of some rules reuses the kept rule / group index unless settings changed (review R18)
    if ns.BeginVisualStep then ns.BeginVisualStep(stepList == nil) end   -- (a full step also checks the dynamic groups' member index)
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
    L("perf: per second: rules %.2f ms, visuals %.2f ms, per-frame effects %.2f ms (%d calls)",
        perf.evalMs / secs, perf.visMs / secs, perf.fxMs / secs, perf.fxN)
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
-- The driver (round 5, V27; round 6: see the top of this file and the aura / cooldown checks above). Nothing here runs per rendered
-- frame while nothing changes:
--   pend.full  every rule, once (a settings change, login, /xui enable)                 -> a one-shot timer, next frame
--   pend.ctx   a load fact may have changed: the context is read once and compared;      -> the same one-shot timer
--              only a real change re-checks every rule
--   pend.all   ns.MarkStateDirty (another file saw a change: movement, a glow ...)        -> every LIVE rule, next frame (MIN_GAP apart)
--   pend.<k>   an input's own event: your auras, target / focus auras and cooldowns      -> the aura / cooldown checks it marked, read
--              mark checks (above); resources, range and casts mark the live rules that     on the next frame, then only the rules whose
--              read them                                                                    check changed (ROUTED_GAP apart)
--   wakes      the stored moments (Plan above) and the TICK re-check of what the game     -> one one-shot timer at the earliest moment
--              hides the moment of
-- (round 6, V27 P1 / P4; round 7, SD-61) the next-frame re-checks run from a one-shot timer made by the first event after the last
-- pass, set for the moment the pace allows; later events of the burst find it set and only mark what they changed. The pass does not
-- set the next one: once the events stop, no timer is left. A change marked while the engine itself is running (an action a rule ran)
-- is taken by a frame script on the next frame only: it runs what is due then, takes itself off, and hands what still waits for the
-- pace to the one-shot timers (round 7 repair: before, it stayed on every frame until the pace allowed the pass, up to 6 frames).
-------------------------------------------------------------------------------
local pend = { full = false, ctx = false, all = false }
local ROUTED = { "cd", "aura", "tgt", "power", "range", "cast" }
local LISTED = { power = true, range = true, cast = true }   -- (cd, aura and tgt go through their checks)
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
    local t = minWake   -- (a rule's "seconds left" moments are in it: Plan)
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
local function RunLists(lists, all, cd, probe)
    stepList, stepClearsDeadlines = lists, all and true or false
    cdFresh = (lists == nil or all or cd) and true or false
    stepProbe = probe and true or false
    SafeStep()
    stepList, stepClearsDeadlines, cdFresh, stepProbe = nil, true, true, false
    ArmWake()
end
local listAll = { live.all }
local runLists, due, dueLists = {}, {}, {}
dueLists[1] = due
local inCallback = false   -- the engine's own timer or frame script is running (a change it marks waits for the next frame)

-- the stored moment has come: the rules waiting for it (and the TICK re-check, when due); a rule whose "seconds left" moment came brings
-- its cues (they read its triggers)
OnWake = function()
    wakeTimer, wakeTimerAt = nil, math.huge
    if ns.RulesDisabled then return end
    local now = GetTime()
    local n = 0
    minWake = math.huge
    for rule, at in pairs(wakeAt) do
        if at <= now + 0.0005 then
            n = n + 1; due[n] = rule; wakeAt[rule] = nil
            local dl = deadlineOf[rule]
            local fam = dl and dl <= now + 0.0005 and famOf[rule]
            if fam then for i = 1, #fam do if fam[i] ~= rule then n = n + 1; due[n] = fam[i] end end end
        elseif at < minWake then minWake = at end
    end
    if next(polled) ~= nil and now + 0.0005 >= lastPollAt + TICK then
        lastPollAt = now
        for rule in pairs(polled) do n = n + 1; due[n] = rule end
    end
    for i = n + 1, #due do due[i] = nil end
    inCallback = true
    if n > 0 then RunLists(dueLists, false, true) else ArmWake() end
    inCallback = false
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
local function SettleTimer() inCallback = true; Settle(); inCallback = false end
local fallbackOn = false
local DriveFrame
local function UseFrameScript()
    if not fallbackOn then fallbackOn = true; f:SetScript("OnUpdate", DriveFrame) end
end
local function QueueSettle()
    if fullQueued or ns.RulesDisabled then return end
    fullQueued = true
    if inCallback then UseFrameScript() else C_Timer.After(0, SettleTimer) end
end

-- the next-frame re-checks of what events marked
local function AnyRouted() for _, k in ipairs(ROUTED) do if pend[k] then return true end end return false end
local function DoAll(now)
    pend.all = false
    for _, k in ipairs(ROUTED) do pend[k] = false end   -- every live rule is in "all" (the marked checks are read in the same step)
    lastStateAt = now
    RunLists(listAll, true, nil, AnyProbeWork())
end
local function DoRouted(now)
    -- D4: the rules that read what changed, this frame (at most once per ROUTED_GAP, review R18); auras and cooldowns through their checks
    local n, cd = 0, pend.cd
    for _, k in ipairs(ROUTED) do
        if pend[k] then
            pend[k] = false
            if LISTED[k] and liveCount[k] and liveCount[k] > 0 then n = n + 1; runLists[n] = live[k] end
        end
    end
    for i = n + 1, #runLists do runLists[i] = nil end
    lastRoutedAt = now
    if n > 0 or AnyProbeWork() then RunLists(runLists, false, cd, true) end
end
local allArmed, routedArmed = false, false
local Kick
-- a change marked while the engine itself ran: this frame script takes it on the next frame, runs what is due, takes itself off, and
-- hands what still waits for the pace to the one-shot timers (Kick). It never stays on to wait.
DriveFrame = function()
    f:SetScript("OnUpdate", nil); fallbackOn = false
    if ns.RulesDisabled then return end
    inCallback = true
    if fullQueued then Settle() end
    local now = GetTime()
    if pend.all and now - lastStateAt >= MIN_GAP then DoAll(now)
    elseif now - lastRoutedAt >= ROUTED_DUE and AnyRouted() then DoRouted(now) end
    inCallback = false
    if fallbackOn then return end   -- (the pass just run marked a change: this script takes it on the next frame, as above)
    if pend.all or AnyRouted() then Kick() end
end
local function AllTimer()
    allArmed = false
    if ns.RulesDisabled or not pend.all or fallbackOn then return end
    local now = GetTime()
    local d = lastStateAt + MIN_GAP - now
    -- (a full step moved the pace on since this timer was set: wait for the moment it now allows, on a new one-shot timer)
    if d > 0.0005 then allArmed = true; C_Timer.After(d, AllTimer); return end
    inCallback = true
    DoAll(now)
    inCallback = false
end
-- (round 7, SD-61) a routed pass: the one-shot timer the first event after the last pass made, at the moment the pace allows (the next
-- frame after a quiet moment, else a tenth of a second after the last pass). It runs every change marked since, and sets no timer
-- itself: the next one is made by the next event, so with no event nothing is left running (EllesmereUI's 10-a-second engine ticker, per
-- the study, stops itself after about a second with nothing to do; ours is never set while nothing waits)
local function RoutedTimer()
    routedArmed = false
    if ns.RulesDisabled or fallbackOn or not AnyRouted() then return end
    local now = GetTime()
    -- (the timer was set for this moment; a rounding error in the moment's sum is not a reason to wait a frame. A pass run since it was
    -- set, by the frame script, moved the pace on: wait for the moment it now allows, on a new one-shot timer)
    local d = lastRoutedAt + ROUTED_DUE - now
    if d > 0.0001 then routedArmed = true; C_Timer.After(d, RoutedTimer); return end
    inCallback = true
    DoRouted(now)
    inCallback = false
end
-- a rule list replaced or grown without ns.MarkDirty (an edit that did not announce itself): the next re-check is a full step
local function ListChanged() return ns.rules ~= liveRules or (ns.rules and #ns.rules or 0) ~= liveRulesN end
Kick = function()
    if ListChanged() then pend.full = true; QueueSettle() end
    if ns.RulesDisabled then return end
    if inCallback or fallbackOn then UseFrameScript(); return end
    local now = GetTime()
    if pend.all and not allArmed then
        allArmed = true
        local d = lastStateAt + MIN_GAP - now
        C_Timer.After(d > 0 and d or 0, AllTimer)
    end
    if AnyRouted() and not routedArmed then
        routedArmed = true
        local d = lastRoutedAt + ROUTED_DUE - now
        C_Timer.After(d > 0 and d or 0, RoutedTimer)
    end
end

-- (ns.configVersion: settings changed, so memos keyed on settings - load checks - start over)
function ns.MarkDirty() barsDirty = true; ns.configVersion = (ns.configVersion or 0) + 1; ns.Fire("EDITED"); pend.full = true; QueueSettle() end
-- game state changed: every loaded rule is re-checked on the next frame, keeping the minimum gap between them. (round 6) what = "cast"
-- (your cast, Triggers.lua): only what a cast can change is checked: your auras (a cast moves the time estimates of hidden auras), the
-- cooldowns and charges (a cast spends a charge) and the "cast within N seconds" rows; the rest of a rule cannot change with a cast.
function ns.MarkStateDirty(what)
    if what == "cast" then
        -- (an answer read from the aura API with a readable time cannot change with a cast: only the checks that answer otherwise, a
        -- hidden aura's estimate or the tracker, are read, as on every aura event: RunProbes reads a touched unit's non-API checks)
        local U = probeUnits.player
        if U.nonDirect > 0 or #U.loose > 0 then U.touched = true; pend.aura = true end
        if #cdChecks.probes > 0 or #cdChecks.loose > 0 then cdChecks.whole = true; pend.cd = true end
        if (liveCount.cast or 0) > 0 then pend.cast = true end
    else
        pend.all = true
    end
    Kick()
end
-- (AuraAlias.lua) a same-name aura was just learned for a rule's aura: its ID joins the index, and every check of your auras is read on
-- the next frame (the rule may already show it)
function ns.EngineAliasLearned()
    local U = probeUnits.player
    if ns.RulesDisabled or (#U.probes == 0 and #U.loose == 0) then return end
    for i = 1, #U.probes do
        local pr = U.probes[i]
        if pr.kind == "buff" then IndexAuraIDs(U.idx, pr, pr.root.buffID, pr.root.buffAlt)
        elseif pr.kind == "arow" then IndexAuraIDs(U.idx, pr, pr.row.spellID, pr.row.alt) end
    end
    U.whole, U.complete = true, false
    pend.aura = true
    Kick()
end

function ns.OnDBReady()
    ns.RefreshAllVisuals()
    pend.full = true; QueueSettle()
end

-- (round 7, SD-60, her answer "1": events only, no talent timer) talents are read again only when the game says they may have changed. The
-- once-a-second talent re-read (review R3's safety net, a C_Timer.NewTicker out of combat) is gone. The events, all in
-- docs/reference/api/events.md:
--   * these say talents or the spec did change: the kept talent answers are dropped (ns.talentEpoch) and every rule is checked again on
--     the next frame (TALENT_EVENTS below);
--   * these fire while talents are picked in the talent window before they are saved, or for a single node: the switched-on rules with a
--     talent requirement compare each entry's known / not known with their kept answer (Conditions.lua ns.TalentCodesChanged: no table,
--     no string), and only a real difference re-checks the rules (TALENT_MAYBE below).
local function TalentEventCheck()
    if ns.RulesDisabled or not ns.TalentCodesChanged then return end
    for i = 1, talentN do
        if ns.TalentCodesChanged(talentRules[i]) then ns.talentEpoch = (ns.talentEpoch or 0) + 1; pend.ctx = true; QueueSettle(); return end
    end
end

-- auto-capture status into the ring-buffer log every SNAP_EVERY seconds of combat, since /xui debug status can't be typed mid-fight;
-- only while someone can read it (ns.LogWanted("snapshot"), Core.lua): otherwise no timer exists
local snapTicker
local function SnapTick() if inCombat and ns.LogStatusSnapshot and not ns.RulesDisabled then ns.LogStatusSnapshot("combat tick") end end
local function SnapStop() if snapTicker then snapTicker:Cancel(); snapTicker = nil end end

-- events: always registered (the load facts, the action bars, the state events the engine has always stepped on)
-- (round 7, SD-60) every way the reference names for talents or the spec to change (events.md): the spec (PLAYER_SPECIALIZATION_CHANGED
-- :1215, ACTIVE_PLAYER_SPECIALIZATION_CHANGED :30, ACTIVE_TALENT_GROUP_CHANGED :31), talents and loadouts saved or switched
-- (PLAYER_TALENT_UPDATE :1222, TRAIT_CONFIG_UPDATED :1536, TRAIT_CONFIG_LIST_UPDATED :1535, ACTIVE_COMBAT_CONFIG_CHANGED :27),
-- hero talents (TRAIT_SUB_TREE_CHANGED :1540), PvP talents (PLAYER_PVP_TALENT_UPDATE :1204, and WAR_MODE_STATUS_UPDATE :1770), a reset
-- or a spec change by the game (TALENTS_INVOLUNTARILY_RESET :1466, SPEC_INVOLUNTARILY_CHANGED :1426), the spellbook (SPELLS_CHANGED :1428, the spells the talent check reads with
-- IsPlayerSpell) and entering the world. (INFERENCE, not in the reference: War Mode, and a loading screen into an arena or battleground,
-- switch PvP talents on and off without a talent event of their own; both are listened to for that reason.)
local TALENT_EVENTS = {
    PLAYER_SPECIALIZATION_CHANGED = true, ACTIVE_PLAYER_SPECIALIZATION_CHANGED = true, ACTIVE_TALENT_GROUP_CHANGED = true,
    PLAYER_TALENT_UPDATE = true, TRAIT_CONFIG_UPDATED = true, TRAIT_CONFIG_LIST_UPDATED = true, ACTIVE_COMBAT_CONFIG_CHANGED = true,
    TRAIT_SUB_TREE_CHANGED = true, PLAYER_PVP_TALENT_UPDATE = true, WAR_MODE_STATUS_UPDATE = true, TALENTS_INVOLUNTARILY_RESET = true,
    SPELLS_CHANGED = true, PLAYER_ENTERING_WORLD = true, SPEC_INVOLUNTARILY_CHANGED = true,
}
-- picked in the talent window but not saved yet, or one node or tree changed (TRAIT_NODE_CHANGED :1537, TRAIT_NODE_CHANGED_PARTIAL :1538,
-- TRAIT_NODE_ENTRY_UPDATED :1539, TRAIT_TREE_CHANGED :1543), a loadout made, deleted or picked in the list, or a save that failed
-- (TRAIT_CONFIG_CREATED :1533, TRAIT_CONFIG_DELETED :1534, SELECTED_LOADOUT_CHANGED :1359, CONFIG_COMMIT_FAILED :446), or a spell
-- learned (LEARNED_SPELL_IN_SKILL_LINE :897); (round 7 repair) a level gained (PLAYER_LEVEL_UP :1193, it carries numNewTalents), a
-- node's condition (TRAIT_COND_INFO_CHANGED :1532), the talent-point count (CHARACTER_POINTS_CHANGED :271), and a pick, a PvP pick, a
-- spec change or a starter build that failed (PLAYER_LEARN_TALENT_FAILED :1189, PLAYER_LEARN_PVP_TALENT_FAILED :1188,
-- SPECIALIZATION_CHANGE_CAST_FAILED :1425, STARTER_BUILD_ACTIVATION_FAILED :1447; INFERENCE: the talent window may show a pick before
-- it fails): compared, not re-checked (TalentEventCheck above). Each is rare and costs one compare of the talent rules' entries.
-- Considered and not listened to: glyphs (ACTIVATE_GLYPH :26, USE_GLYPH :1699, CANCEL_GLYPH_CAST :223: no talent entry reads a glyph;
-- a spell a glyph teaches comes with SPELLS_CHANGED, INFERENCE), the pet's spec (PET_SPECIALIZATION_CHANGED :1143: no load check reads
-- it), talent-tree currency and the trait NPC (TRAIT_TREE_CURRENCY_INFO_UPDATED :1544, TRAIT_SYSTEM_INTERACTION_STARTED :1541,
-- TRAIT_SYSTEM_NPC_CLOSED :1542: points and windows, not picks), and PLAYER_LEVEL_CHANGED :1192 (PLAYER_LEVEL_UP is listened to).
local TALENT_MAYBE = { TRAIT_NODE_CHANGED = true, TRAIT_NODE_CHANGED_PARTIAL = true, TRAIT_NODE_ENTRY_UPDATED = true, TRAIT_TREE_CHANGED = true,
    TRAIT_CONFIG_CREATED = true, TRAIT_CONFIG_DELETED = true, SELECTED_LOADOUT_CHANGED = true, CONFIG_COMMIT_FAILED = true,
    LEARNED_SPELL_IN_SKILL_LINE = true, PLAYER_LEVEL_UP = true, TRAIT_COND_INFO_CHANGED = true, CHARACTER_POINTS_CHANGED = true,
    PLAYER_LEARN_TALENT_FAILED = true, PLAYER_LEARN_PVP_TALENT_FAILED = true, SPECIALIZATION_CHANGE_CAST_FAILED = true,
    STARTER_BUILD_ACTIVATION_FAILED = true }
local CTX_EVENTS = {
    PLAYER_ENTERING_WORLD = true, PLAYER_REGEN_DISABLED = true, PLAYER_REGEN_ENABLED = true, GROUP_ROSTER_UPDATE = true,
    ZONE_CHANGED_NEW_AREA = true, ZONE_CHANGED = true, ZONE_CHANGED_INDOORS = true, PLAYER_DIFFICULTY_CHANGED = true,
    PLAYER_MOUNT_DISPLAY_CHANGED = true, PLAYER_UPDATE_RESTING = true, PLAYER_EQUIPMENT_CHANGED = true,
    CHALLENGE_MODE_START = true, CHALLENGE_MODE_COMPLETED = true, CHALLENGE_MODE_RESET = true, ENCOUNTER_START = true, ENCOUNTER_END = true,
    UNIT_FLAGS = true,   -- (player: the combat flag; UnitAffectingCombat is a load fact)
}
for e in pairs(TALENT_EVENTS) do CTX_EVENTS[e] = true end
-- load facts another file keeps from the event itself (Conditions.lua ns.LoadEvent: the encounter, the equipment count), that the engine
-- itself changes here (talents), or that the game sets only after the event (PLAYER_REGEN_DISABLED comes just before combat lockdown,
-- INFERENCE from Blizzard's secure code; the stand-in game sets combat after the event too): read on the next frame, once every handler ran
local CTX_LATER = { ENCOUNTER_START = true, ENCOUNTER_END = true, PLAYER_EQUIPMENT_CHANGED = true, PLAYER_ENTERING_WORLD = true,
    PLAYER_REGEN_DISABLED = true, PLAYER_REGEN_ENABLED = true }
for e in pairs(TALENT_EVENTS) do CTX_LATER[e] = true end
local BAR_EVENTS = { ACTIONBAR_SLOT_CHANGED = true, UPDATE_BONUS_ACTIONBAR = true, ACTIONBAR_PAGE_CHANGED = true, UPDATE_SHAPESHIFT_FORM = true }
for e in pairs(CTX_EVENTS) do if e ~= "UNIT_FLAGS" then f:RegisterEvent(e) end end
for e in pairs(TALENT_MAYBE) do f:RegisterEvent(e) end
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
-- (round 6, SD-54) an aura event marks the checks it can change. The payload is read only when the game shows it (out of combat): the
-- spell IDs of the auras added, and the instances updated or removed, looked up in the memory of the watched auras' instance IDs. A
-- hidden payload, a hidden field, a full update, or an instance the memory cannot vouch for: every check of the unit. Nothing in a
-- hidden payload is tested. Returns true when anything is to be read on the next frame.
local function MarkList(l) for i = 1, #l do Mark(l[i]) end end
local function MarkMem(U, iid, forget)
    local x = U.mem[iid]
    if x == nil then x = U.memP[iid] end
    if x == nil then return false end
    if type(x) == "number" then local l = U.idx[x]; if l then MarkList(l) end
    elseif x.kind then Mark(x)
    else MarkList(x) end
    if forget then U.mem[iid], U.memP[iid] = nil, nil end
    return true
end
local function MarkIDs(U, ids, forget)
    if ids == nil then return true end
    if type(ids) ~= "table" or issecret(ids) then return false end
    for i = 1, #ids do
        local iid = ids[i]
        if iid == nil or issecret(iid) then return false end
        if not MarkMem(U, iid, forget) and not U.complete then return false end   -- (not one the memory knows, and it may be watched)
    end
    return true
end
local function RouteAura(unit, info)
    local U = probeUnits[unit]
    if not U or (#U.probes == 0 and #U.loose == 0) then return false end
    if U.whole then return true end
    local ok = type(info) == "table" and not issecret(info)
    if ok then
        local full = info.isFullUpdate
        if issecret(full) or full == true then ok = false end
    end
    if ok then
        local added = info.addedAuras
        if added ~= nil then
            if type(added) ~= "table" or issecret(added) then ok = false
            else
                for i = 1, #added do
                    local a = added[i]
                    if type(a) ~= "table" or issecret(a) then ok = false; break end
                    local sid, iid = a.spellId, a.auraInstanceID
                    if issecret(sid) or issecret(iid) then ok = false; break end
                    local l = U.idx[sid]
                    if l then MarkList(l); if iid ~= nil then U.mem[iid] = sid end end
                end
            end
        end
    end
    if ok then ok = MarkIDs(U, info.removedAuraInstanceIDs, true) end
    if ok then ok = MarkIDs(U, info.updatedAuraInstanceIDs, false) end
    if not ok then
        U.whole, U.complete = true, false
        for k in pairs(U.mem) do U.mem[k] = nil end
        for k in pairs(U.memP) do U.memP[k] = nil end
        return true
    end
    if pendN > 0 or U.nonDirect > 0 or #U.loose > 0 then U.touched = true; return true end
    return false
end
-- a cooldown event: every cooldown check is read on the next pass (and only the rules whose check answered differently are checked in
-- full). (round 7 repair, V2 fail-safe) SPELL_UPDATE_COOLDOWN carries (spellID, baseSpellID, category, startRecoveryCategory, itemID),
-- all optional, and is a UniqueEvent (events.md:1443). The reference documents what the fields are, not that one event names every
-- cooldown that changed: a category or start-recovery category means the spells sharing it changed too (which ones the event does not
-- say), an item ID means the items sharing its cooldown did, a field may be hidden (secret), and what UniqueEvent does to the payload
-- is not documented at all (the game may send the event once for several cooldowns that changed in one frame, naming one of them:
-- INFERENCE, UNVERIFIED IN GAME). So no payload is trusted to say what did NOT change: no field of it is read. The cost is one quick
-- read of each cooldown check per pass, and passes run at most 10 a second (SD-61); before round 6 every cooldown rule was checked
-- in full on every cooldown event.
local function RouteCooldown()
    local C = cdChecks
    if #C.probes == 0 and #C.loose == 0 then return #live.cd > 0 end
    C.whole = true
    return true
end
inputFrame:SetScript("OnEvent", function(_, event, unit, a2, a3, a4, a5)
    if perf.on then perf.events[event] = (perf.events[event] or 0) + 1 end
    local k = KIND_OF[event]
    local u = UNIT_OF[event]
    if u and unit ~= u then return end
    if event == "UNIT_AURA" then
        ns.lastAuraEventAt = GetTime()   -- (Conditions.lua stamps an aura's appearance with it)
        if RouteAura("player", a2) then pend.aura = true; Kick() end
        return
    end
    if k == "cd" then
        if RouteCooldown() then pend.cd = true; Kick() end
        return
    end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then NoteCast(GetTime()) end
    if k then pend[k] = true; Kick() end
end)
tgtFrame:SetScript("OnEvent", function(_, event, unit, info)
    if unit ~= "target" and unit ~= "focus" then return end
    if perf.on then perf.events["UNIT_AURA (target / focus)"] = (perf.events["UNIT_AURA (target / focus)"] or 0) + 1 end
    if RouteAura(unit, info) then pend.tgt = true; Kick() end
end)
f:SetScript("OnEvent", function(_, event, arg1)
    if event == "UNIT_FLAGS" and arg1 ~= "player" then return end
    if perf.on then perf.events[event] = (perf.events[event] or 0) + 1 end
    if event == "PLAYER_ENTERING_WORLD" then
        if ns.ClearSecrecyCache then ns.ClearSecrecyCache() end
        inCombat = (UnitAffectingCombat and UnitAffectingCombat("player")) and true or false   -- a /reload can land mid-fight
    end
    if TALENT_MAYBE[event] then TalentEventCheck(); return end
    if TALENT_EVENTS[event] then
        ns.talentList = nil; ns.spellList = nil
        -- (review R3; round 7, SD-60) talents may have changed: the kept talent answers (Conditions.lua CheckTalents) are read again;
        -- another unit's spec change does not count
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
        if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" then
            -- another unit: what was known about its auras is about the old one (every check of it is read again, the memory starts over)
            local U = probeUnits[event == "PLAYER_TARGET_CHANGED" and "target" or "focus"]
            for k2 in pairs(U.mem) do U.mem[k2] = nil end
            for k2 in pairs(U.memP) do U.memP[k2] = nil end
            U.complete = false
            if #U.probes > 0 or #U.loose > 0 then U.whole = true end
            pend.tgt = true
        end
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
        f:SetScript("OnUpdate", nil); fallbackOn = false
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
