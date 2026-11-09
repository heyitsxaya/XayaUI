-------------------------------------------------------------------------------
-- QAWalks-merge-rules.lua (listed in XayaUI_DevAssist 0.7.72's toc): in-game QA walkthrough for the Rules sidebar's right-click menu on
-- several selected rules (XayaUI_Rules_Options 0.6.82; QA steps B370 to B375). REQUEST-LOG-session-014bN6tUDLJ6T742DewZDg1s.md:
--   row 23 (her words): "should be able to right click multi delete";
--   row 19 (her words): "I want to be able to merge these into one rule that tracks all of these auras and fires based if any are found by
--     right clicking on them when multi-selected and choose \"merge rules\""; row 27: her answers (the right-clicked rule is kept; the
--     others go to the Recycle Bin one item each; only triggers merge; present with present, missing with missing, "any trigger" fires);
--   the review of the row 20 fix: a delete made in Rules > Disabled opened Enabled > Loaded at the top.
--   B370 two rules selected, right-click one > Delete 2 Selected > Yes: both in the Recycle Bin (one item each), the selection gone;
--   B371 Rules > Disabled, right-click > Delete > Yes: Disabled stays open and the list keeps its place;
--   B372 four aura rules selected, right-click one > Merge 4 Selected > Yes: the right-clicked rule watches every aura in one present
--        trigger and keeps its own name and display; the other three are in the Recycle Bin, one item each;
--   B373 the merged rule fires when any of its auras is on you (the addon's verdict against its reading of each aura);
--   B374 present + missing + cooldown rules merged: one present trigger, one missing trigger, the cooldown as a further trigger, ANY;
--   B375 a rule whose two triggers must ALL be true is refused with a chat line naming it; nothing changes.
-- Test data: a group "QA merge rules" with the walkthrough's own rules (tagged qaMergeRules; no display, no sound except "QA Aura C"'s
-- display art, which the merge must leave alone). The last step (Done) removes the group, its rules and the Recycle Bin items this
-- walkthrough made. Standing rule V22 (Xaya 2026-11-07): each check reads back what the addon holds (rules, triggers, the Recycle Bin, the
-- selection, the list's scroll position and rows), offers its verdict (prefill = true; recorded only on her click) and puts what it
-- read in the note. UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end

local GROUP = "QA merge rules"
local st = {}
local function NS() return rawget(_G, "XayaUI_NS") end
-- the rule editor (XayaUI Rules Options) through ns.OptionsApi.RuleEditor (RuleSettings.lua; MultiMerge published 0.6.82), never
-- through its own names
local function RE() local ns = NS(); return ns and ns.OptionsApi and ns.OptionsApi.RuleEditor or {} end
local function ACD() return LibStub and LibStub("AceConfigDialog-3.0", true) end
local function Root() local a = ACD(); return a and a.OpenFrames and a.OpenFrames.CueRules end
local function Status() local f = RE().RulesTreeStatus; return f and f() end
local function Tree()
    local s = Status()
    local function find(w)
        if type(w) ~= "table" then return nil end
        if w.type == "TreeGroup" and s and w.status == s then return w end
        for _, c in ipairs(w.children or {}) do local f = find(c); if f then return f end end
    end
    return find(Root())
end
local function TestGroup()
    local ns = NS()
    for _, f in ipairs(ns and ns.folders or {}) do if f.qaMergeRules == true then return f end end
end
local function Live(rule) local ns = NS(); for _, r in ipairs(ns and ns.rules or {}) do if r == rule then return true end end; return false end
local function Named(name) local ns = NS(); for _, r in ipairs(ns and ns.rules or {}) do if r.qaMergeRules == true and r.name == name then return r end end end
local function InBin(rule)   -- the Recycle Bin item that holds this rule as its own item (one rule), or nil
    local ns = NS()
    local bin = ns and ns.RecycleDB and ns.RecycleDB()
    for _, it in ipairs(bin and bin.items or {}) do
        if it.kind == "rule" and type(it.rules) == "table" and it.rules[1] == rule then return it end
    end
end
local function IDList(t) local o = {}; for i, v in ipairs(type(t) == "table" and t or {}) do o[i] = tostring(v) end; return table.concat(o, ", ") end

-- the walkthrough's rules: name -> how it is built (the rules of each step are made by that step's Do it for me, once)
local SPECS = {
    delete = { { "QA delete me 1", 104273 }, { "QA delete me 2", 104274 } },
    merge = { { "QA Well Fed A", 104273 }, { "QA Well Fed B", 104280, { 104281 } }, { "QA Aura C", 1233706, nil, true }, { "QA Aura D", 1233712 } },
}
local function NewTestRule(name, fill)
    local ns = NS()
    local r = ns.NewRule(); r.name = name; r.folder = TestGroup().id; r.enabled = true
    r.visual = r.visual or {}; r.visual.enabled = false; r.sound = r.sound or {}; r.sound.enabled = false
    r.useBuff, r.buffState = true, "present"
    if fill then fill(r) end
    ns.NormalizeRule(r); r.qaMergeRules = true; ns.rules[#ns.rules + 1] = r
    return r
end
local function Open(sub, root, rule)
    local ns, a = NS(), ACD()
    if not Root() then a:Open("CueRules") end
    a:SelectGroup("CueRules", "cooldowns", sub, root)
    local okc, ctx = pcall(ns.ReadContext)
    if rule then a:SelectGroup("CueRules", RE().ScopePath(rule, okc and ctx or nil)) end   -- opens the group on the way
end
local function Prepare(which)
    local ns = NS()
    if not (ns and ns.NewFolder and ns.LoadOptions and ns.LoadOptions()) then error("XayaUI or its settings window could not be loaded") end
    if not (RE().MultiMerge and RE().GoHomeKeepScroll) then error("XayaUI Rules Options is older than 0.6.82 (no Merge N Selected)") end
    if not TestGroup() then local f = ns.NewFolder(GROUP); f.qaMergeRules = true end
    local first
    for _, s in ipairs(SPECS[which] or {}) do
        local r = Named(s[1])
        if not r and not st["made" .. s[1]] then
            st["made" .. s[1]] = true
            r = NewTestRule(s[1], function(x)
                x.buffID = s[2]; x.buffAlt = s[3]
                if s[4] then x.visual.enabled = true; x.visual.tex = "Interface\\Icons\\INV_Misc_Food_15"; x.visual.x = 37 end
            end)
        end
        first = first or r
    end
    if ns.MarkDirty then ns.MarkDirty() end
    Open("enabledTab", "loaded", first)
end

-- B370: Delete 2 Selected
local function CheckDeleteN()
    local E = RE()
    local a, b = st.del1, st.del2
    if not (a and b) then return nil, "press Do it for me first" end
    if Live(a) and Live(b) then return nil, "both QA delete me rules are still there: Ctrl+click both, right-click one > Delete 2 Selected > Yes, then Check" end
    local ia, ib = InBin(a), InBin(b)
    local n = E.MultiCount and E.MultiCount() or -1
    local ok = not Live(a) and not Live(b) and ia ~= nil and ib ~= nil and ia ~= ib and n == 0
    return ok, ("QA delete me 1: %s; QA delete me 2: %s. Recycle Bin: %s. Selected now: %d."):format(Live(a) and "still there" or "gone", Live(b) and "still there" or "gone",
        (ia and ib and ia ~= ib) and "one item each" or "not one item each", n)
end

-- B371: a delete in Rules > Disabled
local function OnScreen()
    local ns, t, out = NS(), Tree(), {}
    for _, b in ipairs(t and t.buttons or {}) do
        if b:IsShown() then
            local last = tostring(b.uniquevalue or ""):match("([^\001]+)$") or ""
            local n = tonumber(last:match("^rule(%d+)$"))
            local obj = n and ns.rules[n]
            if not obj and ns.FolderById then obj = ns.FolderById(last) end
            out[#out + 1] = { obj = obj or last, top = b:GetTop(), name = (type(obj) == "table" and tostring(obj.name)) or last }
        end
    end
    return out
end
local function Snapshot() local s = Status(); st.snap = { sv = s and s.scrollvalue, rows = OnScreen() } end
local function PrepareDisabled()
    local ns = NS()
    Prepare("none")
    for i = 1, 30 do
        local name = ("QA disabled %02d"):format(i)
        if not Named(name) and not st["made" .. name] then
            st["made" .. name] = true
            NewTestRule(name, function(x) x.buffID = 104300 + i; x.enabled = false end)
        end
    end
    if ns.MarkDirty then ns.MarkDirty() end
    st.target = Named("QA disabled 10") or Named("QA disabled 20")
    Open("disabledTab", "disabled", st.target)
    if C_Timer then
        C_Timer.After(0.2, function()   -- after the window is drawn: the opened rule in the middle of the view, then the picture to compare with
            local t, s = Tree(), Status()
            for i, l in ipairs(t and t.lines or {}) do
                if s and l.uniquevalue == s.selected and t.scrollbar then t.scrollbar:SetValue(math.max(0, i - 8)); break end
            end
            Snapshot()
        end)
    end
end
local function CheckDisabled()
    local E, s = RE(), Status()
    if not (Root() and s) then return nil, "the settings window is not open: press Do it for me" end
    local target, snap = st.target, st.snap
    if not (target and snap) then return nil, "press Do it for me first" end
    if Live(target) then Snapshot(); return nil, "'" .. tostring(target.name) .. "' is still there: right-click it > Delete > Yes, then Check" end
    local sub = E.CurrentSub and E.CurrentSub()
    local first
    for i, r in ipairs(snap.rows) do if r.obj == target then first = i; break end end
    if not first then return nil, "the deleted rule was not on screen when the picture was taken: press Do it for me again" end
    local now, moved = OnScreen(), {}
    local function at(obj) for _, r in ipairs(now) do if r.obj == obj then return r end end end
    for i = 1, first - 1 do
        local a = at(snap.rows[i].obj)
        if not (a and math.abs(a.top - snap.rows[i].top) < 0.5) then moved[#moved + 1] = snap.rows[i].name end
    end
    local ok = sub == "disabledTab" and s.selected == "disabled" and s.scrollvalue == snap.sv and #moved == 0 and first > 1
    return ok, ("Open list: %s (selected row %s). Scroll position %s -> %s. Rows above it: %d, %s."):format(sub == "disabledTab" and "Rules > Disabled" or tostring(sub),
        tostring(s.selected):gsub("\001", " > "), tostring(snap.sv), tostring(s.scrollvalue), first - 1, #moved == 0 and "none moved" or ("moved: " .. table.concat(moved, ", ")))
end

-- B372 / B373: the four aura rules merged into QA Aura C
local function CheckMerged()
    local K, a, b, d = st.mK, st.mA, st.mB, st.mD
    if not (K and a and b and d) then return nil, "press Do it for me first" end
    if Live(a) and Live(b) and Live(d) then return nil, "nothing merged yet: Ctrl+click the four rules, right-click QA Aura C > Merge 4 Selected > Yes, then Check" end
    local want = "104273, 104280, 104281, 1233712"
    local got = IDList(K.buffAlt)
    local nTrig = NS().TriggerSequence and #NS().TriggerSequence(K) or -1
    local bins = (InBin(a) and 1 or 0) + (InBin(b) and 1 or 0) + (InBin(d) and 1 or 0)
    local own = K.name == "QA Aura C" and K.visual and K.visual.enabled == true and K.visual.x == 37
    local ok = Live(K) and K.buffID == 1233706 and K.buffState == "present" and got == want and nTrig == 1 and bins == 3 and own and true or false
    return ok, ("QA Aura C: aura %s, extra aura IDs %s (expected %s), %d trigger(s); own name and display %s. In the Recycle Bin, one item each: %d of 3.")
        :format(tostring(K.buffID), got ~= "" and got or "none", want, nTrig, own and "kept" or "changed", bins)
end
local function CheckFiresOnAny()
    local ns, K = NS(), st.mK
    if not (K and Live(K) and type(K.buffAlt) == "table") then return nil, "merge the four rules first (step 3)" end
    local okc, ctx = pcall(ns.ReadContext)
    local okE, _, info = pcall(ns.Evaluate, K, okc and ctx or nil)
    if not (okE and type(info) == "table") then return nil, "the rule could not be read right now" end
    local anyOn, unknown, onNames = false, false, {}
    for _, id in ipairs({ K.buffID, unpack(K.buffAlt) }) do
        local p = ns.BuffPresent and ns.BuffPresent(id)
        if p == true then anyOn = true; onNames[#onNames + 1] = tostring(id) elseif p == nil then unknown = true end
    end
    local trig = info.trigOK == true
    local note = ("On you: %s. The merged rule's trigger reads %s."):format(#onNames > 0 and table.concat(onNames, ", ") or "none of its 5 auras",
        trig and "TRUE (it fires)" or "FALSE (it does not fire)")
    if unknown and not anyOn then return nil, note .. " Some auras cannot be read right now (combat?): check out of combat." end
    return trig == anyOn, note .. " Eat a Well Fed food (or have any of its auras) and press Check again to see it fire."
end

-- B374: present + missing + cooldown
local MIX = { { "QA Mix present", function(x) x.buffID = 1459 end }, { "QA Mix missing 1", function(x) x.buffID = 21562; x.buffState = "missing" end },
    { "QA Mix missing 2", function(x) x.buffID = 6673; x.buffState = "missing" end },
    { "QA Mix cooldown", function(x) x.useBuff, x.buffID, x.buffState = false, 0, "none"; x.useCooldown, x.spellID, x.cdState = true, 6603, "ready" end } }
local function PrepareMix()
    Prepare("none")
    st.mix = {}
    for i, s in ipairs(MIX) do
        local r = Named(s[1])
        if not r and not st["made" .. s[1]] then st["made" .. s[1]] = true; r = NewTestRule(s[1], s[2]) end
        st.mix[i] = r
    end
    Open("enabledTab", "loaded", st.mix[1])
end
local function CheckMix()
    local m = st.mix
    if not (m and m[1] and m[2] and m[3] and m[4]) then return nil, "press Do it for me first" end
    local K = m[1]
    if Live(m[2]) and Live(m[3]) and Live(m[4]) then return nil, "nothing merged yet: Ctrl+click the four QA Mix rules, right-click QA Mix present > Merge 4 Selected > Yes, then Check" end
    local X = type(K.extra) == "table" and K.extra.list or {}
    local miss, cd
    for _, t in ipairs(X) do
        if t.type == "buffAura" and t.state == "no" then miss = t elseif t.type == "cooldown" then cd = t end
    end
    local bins = (InBin(m[2]) and 1 or 0) + (InBin(m[3]) and 1 or 0) + (InBin(m[4]) and 1 or 0)
    local ok = K.buffID == 1459 and K.buffState == "present" and K.buffAlt == nil and miss ~= nil and miss.spellID == 21562 and IDList(miss.alt) == "6673"
        and cd ~= nil and cd.spellID == 6603 and cd.state == "ready" and #X == 2 and K.trigMode == "any" and bins == 3
    return ok and true or false, ("QA Mix present: present %s; missing %s (all absent); cooldown %s; %d additional trigger(s); activated by %s. In the Recycle Bin, one item each: %d of 3.")
        :format(tostring(K.buffID), miss and (tostring(miss.spellID) .. (miss.alt and (" + " .. IDList(miss.alt)) or "")) or "none",
        cd and (tostring(cd.spellID) .. " " .. tostring(cd.state)) or "none", #X, K.trigMode == "any" and "ANY trigger" or tostring(K.trigMode or "ALL"), bins)
end

-- B375: refused
local function PrepareRefuse()
    local ns = NS()
    Prepare("none")
    st.both = Named("QA Both triggers")
    if not st.both and not st.madeBoth then
        st.madeBoth = true
        st.both = NewTestRule("QA Both triggers", function(x) x.buffID = 1459; x.useCooldown, x.spellID, x.cdState = true, 6603, "ready" end)
    end
    st.single = Named("QA Single")
    if not st.single and not st.madeSingle then st.madeSingle = true; st.single = NewTestRule("QA Single", function(x) x.buffID = 1460 end) end
    -- what the merge says in chat (ns.Print), for the check; put back by Done
    if not st.print0 then
        st.print0 = ns.Print
        ns.Print = function(s, ...) if type(s) == "string" and s:find("^Merge: ") then st.said = s end; return st.print0(s, ...) end
    end
    st.said = nil
    Open("enabledTab", "loaded", st.single)
end
local function CheckRefused()
    local both, single = st.both, st.single
    if not (both and single) then return nil, "press Do it for me first" end
    if not st.said then return nil, "no Merge message yet: Ctrl+click both rules, right-click QA Single > Merge 2 Selected, then Check" end
    local same = Live(both) and Live(single) and single.buffAlt == nil and #(single.extra and single.extra.list or {}) == 0 and single.trigMode == nil
    local names = st.said:find("'QA Both triggers'", 1, true) ~= nil
    return same and names, ("Chat said: %s. Both rules %s; QA Single %s."):format(st.said, (Live(both) and Live(single)) and "are still there" or "are not both there",
        same and "is unchanged" or "changed")
end

local function Done()
    local ns = NS()
    if not ns then return end
    if RE().MultiClear then RE().MultiClear() end
    if st.print0 then ns.Print = st.print0; st.print0 = nil end
    local first
    for i = #(ns.rules or {}), 1, -1 do if ns.rules[i].qaMergeRules == true then table.remove(ns.rules, i); first = i end end
    if QA.LeaveMovedRuleRow then QA.LeaveMovedRuleRow(first) end   -- rows are keyed by list place: a row after them now names another rule
    for i = #(ns.folders or {}), 1, -1 do if ns.folders[i].qaMergeRules == true then table.remove(ns.folders, i) end end
    local bin = ns.RecycleDB and ns.RecycleDB()
    if bin and ns.RecycleDeleteNow then
        local ids = {}
        for _, it in ipairs(bin.items or {}) do
            local mine = false
            for _, r in ipairs(it.rules or {}) do if type(r) == "table" and r.qaMergeRules == true then mine = true end end
            if mine and it.id then ids[#ids + 1] = it.id end
        end
        for _, id in ipairs(ids) do ns.RecycleDeleteNow(id) end
    end
    if ns.MarkDirty then ns.MarkDirty() end
    local reg = LibStub and LibStub("AceConfigRegistry-3.0", true)
    if reg and Root() then reg:NotifyChange("CueRules") end
    wipe(st)
end
QA.MergeRulesTest = { State = st, Done = Done, Named = Named, TestGroup = TestGroup, InBin = InBin }   -- (tests)

QA.Register("merge-rules", { title = "Right-click on several selected rules: Delete N Selected, Merge N Selected; a delete in Rules > Disabled (B370-B375)",
    qa = "B370, B371, B372, B373, B374, B375", order = 541, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: XayaUI adds a group |cffffd100QA merge rules|r with two rules |cffffd100QA delete me 1|r and |cffffd100QA delete me 2|r and opens |cffffd100Rules > Loaded|r on it.\n\nNow |cffffd100Ctrl+click both|r (they turn purple), |cffffd100right-click one of them|r > |cffffd100Delete 2 Selected|r > |cffffd100Yes|r, then press |cffffd100Check|r.\n\n|cffffd100Expect:|r the menu has |cffffd100Delete 2 Selected|r under |cffffd100Delete|r; the question is the one the bar's Delete (2) asks; both rules are gone, each a Recycle Bin item of its own; nothing is selected any more and the list does not move.",
        setup = function() Prepare("delete"); st.del1, st.del2 = Named("QA delete me 1") or st.del1, Named("QA delete me 2") or st.del2 end, check = CheckDeleteN },
    { text = "Press |cffffd100Do it for me|r: XayaUI adds 30 switched-off rules |cffffd100QA disabled 01|r to |cffffd10030|r, opens |cffffd100Rules > Disabled|r and opens |cffffd100QA disabled 10|r in the middle of the list's view.\n\nNow |cffffd100right-click QA disabled 10|r > |cffffd100Delete|r > |cffffd100Yes|r, then press |cffffd100Check|r.\n\n|cffffd100Expect:|r you stay in |cffffd100Rules > Disabled|r (before this fix it jumped to Enabled > Loaded at the top); the rows above stay where they were, the next rule moves up into its place.",
        setup = PrepareDisabled, check = CheckDisabled },
    { text = "Press |cffffd100Do it for me|r: XayaUI adds four aura rules |cffffd100QA Well Fed A|r (104273), |cffffd100QA Well Fed B|r (104280, also 104281), |cffffd100QA Aura C|r (1233706, with a display) and |cffffd100QA Aura D|r (1233712) and opens the list on them.\n\nNow |cffffd100Ctrl+click all four|r, |cffffd100right-click QA Aura C|r > |cffffd100Merge 4 Selected|r.\n\n|cffffd100Expect:|r the question says it merges 4 rules into |cffffd100'QA Aura C' (the rule you right-clicked)|r, that only triggers are merged, lists one trigger |cffffd100Aura PRESENT (any one of 5)|r with the five auras, and says the other 3 go to the Recycle Bin, one item each, by name. Press |cffffd100Yes|r, then |cffffd100Check|r.",
        setup = function()
            Prepare("merge")
            st.mA, st.mB, st.mK, st.mD = Named("QA Well Fed A") or st.mA, Named("QA Well Fed B") or st.mB, Named("QA Aura C") or st.mK, Named("QA Aura D") or st.mD
        end, check = CheckMerged },
    { text = "Press |cffffd100Check|r. The addon reads each of QA Aura C's five auras on you and the merged rule's trigger.\n\n|cffffd100Expect:|r the trigger is TRUE exactly when any one of the five auras is on you. With Well Fed food at hand: eat it, press |cffffd100Check|r again: TRUE.",
        check = CheckFiresOnAny },
    { text = "Press |cffffd100Do it for me|r: XayaUI adds |cffffd100QA Mix present|r (Arcane Intellect present), |cffffd100QA Mix missing 1|r (Power Word: Fortitude missing), |cffffd100QA Mix missing 2|r (Battle Shout missing) and |cffffd100QA Mix cooldown|r (a Cooldown trigger).\n\nNow |cffffd100Ctrl+click the four|r, |cffffd100right-click QA Mix present|r > |cffffd100Merge 4 Selected|r. |cffffd100Expect:|r the question lists 3 triggers: |cffffd100Aura PRESENT|r, |cffffd100Aura MISSING (all 2 absent)|r, the |cffffd100Cooldown|r, and says the rule fires when ANY of them is true. Press |cffffd100Yes|r, then |cffffd100Check|r.",
        setup = PrepareMix, check = CheckMix },
    { text = "Press |cffffd100Do it for me|r: XayaUI adds |cffffd100QA Both triggers|r (a Cooldown AND an aura, both must be true) and |cffffd100QA Single|r.\n\nNow |cffffd100Ctrl+click both|r, |cffffd100right-click QA Single|r > |cffffd100Merge 2 Selected|r, then press |cffffd100Check|r.\n\n|cffffd100Expect:|r no question; a chat line starting |cffffd100Merge: 'QA Both triggers' has 2 triggers|r says why (merging would make it fire on either one); both rules stay as they were.",
        setup = PrepareRefuse, check = CheckRefused },
    { text = "Press |cffffd100Do it for me|r to remove the QA merge rules group, its rules and the Recycle Bin items this walkthrough made, then |cffffd100Done|r.", done = true, setup = Done },
} })
