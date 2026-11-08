-------------------------------------------------------------------------------
-- QAWalks-code-move.lua (XayaUI_DevAssist 0.7.57): the in-game regression walkthrough for the code move of the platform split, phase
-- P4 (docs/plans/PLATFORM-SPLIT-2026-11-07.md sections 3, 4, 6.2, 6.3, 10; XayaUI 0.6.76, XayaUI Rules 0.6.76, QA H14). Rule and aura
-- tracking moved from the XayaUI folder (now "XayaUI Platform") into its own addon, XayaUI_Rules ("XayaUI Rules"), which can be
-- switched off. Standing rule V22 (Xaya 2026-11-07): every step the addon can judge offers its verdict (prefill = true; recorded only on
-- her click). Three parts around two /reloads:
--   part 1 (XayaUI Rules on): the AddOns list titles; a QA test rule on a buff you have shows its icon cue; the rule is shared and the
--           string imported again; the rule goes to the Recycle Bin and is restored; XayaUI Rules is switched off for the /reload;
--   part 2 (XayaUI Rules off): it is not loaded and no XayaUI error was recorded at login; the settings window opens without the Rules
--           tab and every other tab draws; /xui status says it needs XayaUI Rules; Profiles does not offer "Rules and groups"; XayaUI
--           Rules is switched back on;
--   part 3 (XayaUI Rules on again): the QA test rule is back and shows its cue again; the QA test data is removed.
-- Reaches XayaUI only through the Platform (ns.LoadOptions, ns.Share, ns.ErrorEntries, ns.CaptureOutput, ns.ProfilePartsByKey,
-- ns.Recycle*) and, while it is loaded, XayaUI Rules' own names (ns.NewRule, ns.NewCueRule, ns.DisplayFrame, ns.RecycleRule ...).
-- C_AddOns.DisableAddOn / EnableAddOn as in QAWalks-options-split.lua (which characters the default covers is not documented:
-- INFERENCE). UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end

local function NS() return rawget(_G, "XayaUI_NS") end
local RULES = "XayaUI_Rules"
local APP = "CueRules"
local loadedAt = time and time() or 0   -- (this file loads at login; errors recorded from a minute before count as this login's)
local function ACD() return LibStub and LibStub("AceConfigDialog-3.0", true) end
local function Api()
    local ns = NS()
    if not (ns and ns.LoadOptions and ns.LoadOptions()) then return nil end
    return ns.OptionsApi
end
local function OpenFrame() local a = ACD(); return a and a.OpenFrames and a.OpenFrames[APP] end
local function Errors() local ns = NS(); local n = ns and ns.ErrorCount and ns.ErrorCount(); return tonumber(n) or 0 end
local function RulesLoaded() local ok, l = pcall(C_AddOns.IsAddOnLoaded, RULES); return ok and l and true or false end
local function Title(addon) local ok, _, t = pcall(C_AddOns.GetAddOnInfo, addon); return ok and t or nil end
local CONTAINERS = { Frame = true, TabGroup = true, TreeGroup = true, SimpleGroup = true, InlineGroup = true, ScrollFrame = true }
local function Rows(w, d)
    d = d or 0
    if type(w) ~= "table" or d > 30 then return 0 end
    local kids = w.children
    if type(kids) ~= "table" or #kids == 0 then return CONTAINERS[w.type or ""] and 0 or 1 end
    local n = 0
    for _, c in ipairs(kids) do n = n + Rows(c, d + 1) end
    return n
end

-- the QA test data: one rule (on a buff you have now) with an icon cue, tagged (qaCodeMove); your own rules are never touched
local RULE_NAME = "QA code move rule"
local function Tagged(x) return type(x) == "table" and x.qaCodeMove == true end
local function TestRule(name)
    local ns = NS()
    for _, r in ipairs(ns and ns.rules or {}) do if Tagged(r) and not r.parentUid and (name == nil or r.name == name) then return r end end
end
local function CueOf(r) local ns = NS(); for _, x in ipairs(ns and ns.rules or {}) do if x.parentUid == r.uid and x.isCue then return x end end end
local function CueShown(r)
    local ns, cue = NS(), r and CueOf(r)
    local fr = cue and ns.DisplayFrame and ns.DisplayFrame(cue)
    local ok, shown = false, false
    if fr and fr.IsShown then ok, shown = pcall(fr.IsShown, fr) end
    return (ok and shown) and true or false, cue ~= nil, fr ~= nil
end
local function Num(v) if type(v) == "number" and not (rawget(_G, "issecretvalue") and issecretvalue(v)) then return v end end
local function CurrentBuff()
    local CU = rawget(_G, "C_UnitAuras")
    if not (CU and CU.GetAuraDataByIndex) then return nil end
    for i = 1, 40 do
        local ok, a = pcall(CU.GetAuraDataByIndex, "player", i, "HELPFUL")
        if not (ok and type(a) == "table") then break end
        local id = Num(a.spellId)
        if id and id > 0 then return id, a.name end
    end
end
local function HasBuff(id)
    local CU = rawget(_G, "C_UnitAuras")
    local ok, a = pcall(CU.GetPlayerAuraBySpellID, id)
    return ok and type(a) == "table"
end
local function Cleanup()
    local ns = NS(); if not (ns and ns.rules) then return end
    local first
    for i = #ns.rules, 1, -1 do
        local r = ns.rules[i]
        if Tagged(r) then if ns.DropVisual then pcall(ns.DropVisual, r) end; table.remove(ns.rules, i); first = i end
    end
    -- (0.7.64, debug W3) an editor open on a removed rule's row would slide onto the next rule: back to the list (QAWalks-bars.lua)
    if QA.LeaveMovedRuleRow then QA.LeaveMovedRuleRow(first) end
    local b = ns.RecycleDB and ns.RecycleDB()
    local ids = {}
    for _, it in ipairs(b and b.items or {}) do
        for _, r in ipairs(it.rules or {}) do if Tagged(r) then ids[#ids + 1] = it.id; break end end
    end
    for _, id in ipairs(ids) do ns.RecycleDeleteNow(id) end
    if ns.RefreshAllVisuals then pcall(ns.RefreshAllVisuals) end
    if ns.MarkDirty then ns.MarkDirty() end
end

local st = {}
local switchedOff, switchedOn   -- set in this session (gone after the /reload)

QA.Register("code-move", { title = "Code move: XayaUI Platform and XayaUI Rules, a rule's cue, sharing and the Recycle Bin (part 1 of 3) (H14)", area = "Platform", qa = "H14", order = 272.6, prefill = true, steps = {
    { text = "Open the game's AddOns list (Esc > AddOns) and look at XayaUI's entries, then close it and press Check.\n\n|cffffd100Expect:|r the entry that was \"XayaUI\" reads |cffffd100XayaUI Platform|r, and a new entry |cffffd100XayaUI Rules|r is there and ticked. The check reads both titles from the game.",
        check = function()
            local p, r = Title("XayaUI"), Title(RULES)
            return (p == "XayaUI Platform" and r == "XayaUI Rules" and RulesLoaded()) and true or false,
                ("XayaUI folder: %s; XayaUI_Rules folder: %s, loaded: %s"):format(tostring(p), tostring(r), tostring(RulesLoaded()))
        end },
    { text = "Press |cffffd100Do it for me|r: a QA test rule \"" .. RULE_NAME .. "\" is made on a buff you have right now (out of combat), with an icon cue. Wait two seconds, then press Check. (No buff on you: get one, e.g. eat food or use a mount, then press Do it for me again.)\n\n|cffffd100Expect:|r the buff's icon shows on screen, as a rule's cue always did.",
        setup = function()
            local ns = NS()
            if not (ns and ns.NewRule and ns.NewCueRule) then error("XayaUI Rules is not loaded: switch it on in the AddOns list and /reload") end
            Cleanup()
            local id = CurrentBuff()
            if not id then error("you have no buff the game lets an addon read right now: get one (food, a mount) and press Do it for me again") end
            local r = ns.NewRule(); r.name = RULE_NAME; r.enabled = true; r.uid = ns.NewUID(); r.qaCodeMove = true
            r.useBuff, r.buffID, r.buffState = true, id, "present"
            ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r
            local cue = ns.NewCueRule(r, "icon")
            if cue then cue.qaCodeMove = true end
            st.buff = id
            ns.MarkDirty()
        end,
        check = function()
            local r = TestRule(RULE_NAME); if not r then return nil, "press Do it for me first" end
            local shown, hasCue, hasFrame = CueShown(r)
            return (shown and HasBuff(r.buffID)) and true or false, ("buff %s on you: %s; cue: %s; its display: %s, shown: %s"):format(
                tostring(r.buffID), tostring(HasBuff(r.buffID)), tostring(hasCue), tostring(hasFrame), tostring(shown))
        end },
    { text = "Press |cffffd100Do it for me|r: the QA test rule is shared (the text you would paste to a friend: right-click > Export) and that text is imported again (Import, Add).\n\n|cffffd100Expect:|r a second copy of the rule, with its cue, in a new group \"Imported: " .. RULE_NAME .. " (...)\" (the check looks for it).",
        setup = function()
            local ns = NS(); local r = TestRule(RULE_NAME)
            if not (ns and r and ns.Share_SnapshotRule) then error("run the step before first (XayaUI Rules must be loaded)") end
            local txt = ns.Share.Encode("rules", ns.Share_SnapshotRule(r, RULE_NAME))
            local data, def = ns.Share.Read(txt)
            if not data then error("the share string did not read back: " .. tostring(def)) end
            st.shared = txt:sub(1, 5)
            st.imported = nil
            ns.Share.Apply(def, data, "add", function(c) st.imported = c end)
        end,
        check = function()
            local ns = NS(); if not st.shared then return nil, "press Do it for me first" end
            local copies, withCue = 0, 0
            for _, r in ipairs(ns.rules or {}) do
                if Tagged(r) and not r.parentUid and r.name == RULE_NAME then copies = copies + 1; if CueOf(r) then withCue = withCue + 1 end end
            end
            local c = st.imported
            return (st.shared == "XUI1:" and c and c.rules == 2 and copies == 2 and withCue == 2) and true or false,
                ("string starts %s; imported %s row(s); copies of the rule now: %d, with their cue: %d"):format(st.shared, tostring(c and c.rules), copies, withCue)
        end },
    { text = "Press |cffffd100Do it for me|r: the imported copy is deleted (it goes to the Recycle Bin), then restored from the Recycle Bin.\n\n|cffffd100Expect:|r it is gone, then back where it was, with its cue. The check reads both moments.",
        setup = function()
            local ns = NS(); if not (ns and ns.RecycleRule) then error("XayaUI Rules is not loaded") end
            local copy
            for _, r in ipairs(ns.rules) do if Tagged(r) and not r.parentUid and r.name == RULE_NAME and r ~= TestRule(RULE_NAME) then copy = r end end
            if not copy then error("the imported copy is missing: run the step before again") end
            local uid = copy.uid
            local item = ns.RecycleRule(copy)
            local gone = true
            for _, r in ipairs(ns.rules) do if r.uid == uid then gone = false end end
            st.binGone = gone and item ~= nil
            st.binOk, st.binNote = ns.RecycleRestore(item and item.id)
            st.binUid = uid
            ns.MarkDirty()
        end,
        check = function()
            local ns = NS(); if st.binGone == nil then return nil, "press Do it for me first" end
            local back
            for _, r in ipairs(ns.rules or {}) do if r.uid == st.binUid then back = r end end
            return (st.binGone and st.binOk and back and CueOf(back)) and true or false,
                ("gone after the delete: %s; restored: %s (%s); back with its cue: %s"):format(tostring(st.binGone), tostring(st.binOk), tostring(st.binNote), tostring(back and CueOf(back) ~= nil))
        end },
    { text = "Press |cffffd100Do it for me|r: XayaUI Rules is switched off for your next /reload (part 2 switches it back on). Your rules stay in your saved settings; nothing is deleted.\n\n|cffffd100Expect:|r the check reads that it is set to off.",
        setup = function()
            if not (C_AddOns and C_AddOns.DisableAddOn) then error("the game's AddOns calls are missing") end
            C_AddOns.DisableAddOn(RULES)
            switchedOff = true
        end,
        check = function()
            if not switchedOff then return nil, "press Do it for me first" end
            local ok, s = pcall(C_AddOns.GetAddOnEnableState, RULES)
            return (ok and s == 0) and true or false, ("XayaUI Rules enable state: %s (0 = off)"):format(tostring(s))
        end },
    { done = true, text = "Press |cffffd100Done|r here first (so this record is kept), type |cffffd100/reload|r, and run \"Code move: XayaUI Rules switched off (part 2 of 3) (H14)\"." },
} })

QA.Register("code-move-off", { title = "Code move: XayaUI Rules switched off (part 2 of 3) (H14)", area = "Platform", qa = "H14", order = 272.7, prefill = true, steps = {
    { text = "Run this after part 1 and its /reload. Press Check.\n\n|cffffd100Expect:|r XayaUI Rules is not loaded, no Lua error appeared at login, and your chat and other XayaUI windows work as usual. The check lists every XayaUI error recorded since this login.",
        check = function()
            if switchedOff then return nil, "not reloaded yet: type /reload, then come back and Check again" end
            local ns = NS(); if not (ns and ns.ErrorEntries) then return false, "XayaUI (the Platform) is not loaded" end
            local recent = {}
            for _, e in ipairs(ns.ErrorEntries()) do
                if e.kind ~= "warning" and type(e.last) == "number" and e.last >= loadedAt - 60 then recent[#recent + 1] = tostring(e.code) .. " " .. tostring(e.msg):sub(1, 120) end
            end
            return (not RulesLoaded() and #recent == 0) and true or false,
                ("XayaUI Rules loaded: %s; XayaUI Lua errors since this login: %s"):format(tostring(RulesLoaded()), #recent == 0 and "none" or table.concat(recent, " || "))
        end },
    { text = "Press |cffffd100Do it for me|r: the settings window opens; then press Check: it shows each of its top tabs in turn.\n\n|cffffd100Expect:|r there is no Rules tab; QoL, Bonus Features, Blizzard Reskin, Profiles and Settings are there and draw as usual, with no Lua error. Settings > UI Options has no Rule Creation tab.",
        setup = function()
            local api = Api()
            if not api then error("the settings window (XayaUI_Options) could not be loaded") end
            st.err1 = Errors()
            if not api.IsOpen() then api.Toggle() end
        end,
        check = function()
            local api, a = Api(), ACD()
            if not (api and a and st.err1) then return nil, "press Do it for me first" end
            st.tabs, st.bad = {}, {}
            local tree = api.LastTree() or {}
            local keys = {}
            for k, g in pairs(tree.args or {}) do
                local h = g.hidden; if type(h) == "function" then local ok, v = pcall(h, { k }); h = ok and v end
                if type(g) == "table" and g.type == "group" and not h then keys[#keys + 1] = k end
            end
            table.sort(keys)
            for _, k in ipairs(keys) do
                local ok = pcall(a.SelectGroup, a, APP, k)
                local n = ok and Rows(OpenFrame()) or 0
                st.tabs[#st.tabs + 1] = k .. "=" .. n
                if n == 0 then st.bad[#st.bad + 1] = k end
            end
            local set = tree.args and tree.args.set
            st.ruleCreation = set and set.args and set.args.ui and set.args.ui.args and set.args.ui.args.rules ~= nil
            st.rulesTab = tree.args and tree.args.cooldowns ~= nil
            local e = Errors() - st.err1
            return (not st.rulesTab and not st.ruleCreation and #st.bad == 0 and #st.tabs > 0 and e == 0) and true or false,
                ("Rules tab: %s; Rule Creation tab: %s; tabs drawn: %s; without rows: %s; new XayaUI errors: %d"):format(
                    st.rulesTab and "there" or "absent", st.ruleCreation and "there" or "absent", table.concat(st.tabs, " "),
                    #st.bad == 0 and "none" or table.concat(st.bad, ", "), e)
        end },
    { text = "Press |cffffd100Do it for me|r: /xui status runs (as if you typed it).\n\n|cffffd100Expect:|r instead of the rule list, one line: \"/xui status is part of XayaUI Rules, which is switched off. Turn it on in the game's AddOns list, then /reload.\" The check reads the line.",
        setup = function()
            local ns = NS()
            if not (ns and ns.CaptureOutput and SlashCmdList and SlashCmdList.XAYAUI) then error("XayaUI's /xui command is missing") end
            st.status = ns.CaptureOutput(SlashCmdList.XAYAUI, "status")
        end,
        check = function()
            if not st.status then return nil, "press Do it for me first" end
            local txt = table.concat(st.status, " / ")
            return txt:find("part of XayaUI Rules, which is switched off", 1, true) ~= nil, "printed: " .. txt
        end },
    { text = "Press |cffffd100Do it for me|r: the settings window shows Profiles > Export.\n\n|cffffd100Expect:|r the parts to tick are Themes, Settings, QoL, Bonus Features, Blizzard Reskin (and Nameplates when it is on), without \"Rules and groups\", and there is no \"Backups saved on this computer\" section.",
        setup = function()
            local api, a = Api(), ACD()
            if not (api and a) then error("the settings window could not be loaded") end
            if not api.IsOpen() then api.Toggle() end
            pcall(a.SelectGroup, a, APP, "profiles", "export")
        end,
        check = function()
            local ns, api = NS(), Api(); if not (ns and api) then return false, "the settings window could not be loaded" end
            local parts = {}
            for _, p in ipairs(ns.ProfileParts and ns.ProfileParts() or {}) do parts[#parts + 1] = p.label end
            local tree = api.LastTree() or {}
            local ex = tree.args and tree.args.profiles and tree.args.profiles.args and tree.args.profiles.args.export
            local backups = ex and ex.args and ex.args.savedH ~= nil
            local rulesPart = (ns.ProfilePartsByKey and ns.ProfilePartsByKey().rules) ~= nil
            return (not rulesPart and not backups and #parts > 0) and true or false,
                ("parts offered: %s; backups section: %s"):format(table.concat(parts, ", "), backups and "there" or "absent")
        end },
    { text = "Press |cffffd100Do it for me|r: the settings window closes and XayaUI Rules is switched back on for your next /reload.\n\n|cffffd100Expect:|r the check reads that it is set to on.",
        setup = function()
            local api = Api(); if api and api.IsOpen() then api.Toggle() end
            if not (C_AddOns and C_AddOns.EnableAddOn) then error("the game's AddOns calls are missing") end
            C_AddOns.EnableAddOn(RULES)
            switchedOn = true
        end,
        check = function()
            if not switchedOn then return nil, "press Do it for me first" end
            local ok, s = pcall(C_AddOns.GetAddOnEnableState, RULES)
            return (ok and s ~= 0) and true or false, ("XayaUI Rules enable state: %s (0 = off)"):format(tostring(s))
        end },
    { done = true, text = "Press |cffffd100Done|r here first (so this record is kept), type |cffffd100/reload|r, and run \"Code move: XayaUI Rules back on (part 3 of 3) (H14)\"." },
} })

QA.Register("code-move-on", { title = "Code move: XayaUI Rules back on (part 3 of 3) (H14)", area = "Platform", qa = "H14", order = 272.8, prefill = true, steps = {
    { text = "Run this after part 2 and its /reload, with the buff from part 1 on you again (out of combat). Wait two seconds and press Check.\n\n|cffffd100Expect:|r XayaUI Rules is loaded, the QA test rule is back (your rules were kept while it was off) and its icon shows again; no Lua error appeared at login.",
        check = function()
            if switchedOn then return nil, "not reloaded yet: type /reload, then come back and Check again" end
            local ns = NS()
            local r = TestRule(RULE_NAME)
            local shown = r and CueShown(r)
            local recent = 0
            for _, e in ipairs(ns and ns.ErrorEntries and ns.ErrorEntries() or {}) do if e.kind ~= "warning" and type(e.last) == "number" and e.last >= loadedAt - 60 then recent = recent + 1 end end
            return (RulesLoaded() and r and shown and recent == 0) and true or false,
                ("XayaUI Rules loaded: %s; QA rule back: %s; buff %s on you: %s; its icon shown: %s; XayaUI Lua errors since this login: %d"):format(
                    tostring(RulesLoaded()), tostring(r ~= nil), tostring(r and r.buffID), tostring(r and HasBuff(r.buffID)), tostring(shown), recent)
        end },
    { done = true, text = "Last step: press |cffffd100Do it for me|r to remove the QA test rules (both copies) and their group and Recycle Bin items. Then press |cffffd100Done|r.",
        setup = function()
            local ns = NS(); if not ns then return end
            Cleanup()
            for i = #(ns.folders or {}), 1, -1 do
                local f = ns.folders[i]
                local pre = "Imported: " .. RULE_NAME .. " ("
                if type(f.name) == "string" and f.name:sub(1, #pre) == pre then
                    local used = false
                    for _, r in ipairs(ns.rules) do if r.folder == f.id then used = true end end
                    if not used then table.remove(ns.folders, i) end
                end
            end
            if ns.MarkDirty then ns.MarkDirty() end
        end,
        check = function()
            local ns = NS(); if not ns then return false, "XayaUI is not loaded" end
            for _, r in ipairs(ns.rules or {}) do if Tagged(r) then return false, "a QA test rule is still there" end end
            return true, "the QA test rules are gone"
        end },
} })
