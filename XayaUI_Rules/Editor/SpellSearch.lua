-------------------------------------------------------------------------------
-- XayaUI_Rules/Editor/SpellSearch.lua : Spell / item search boxes in the rule editor and the talent icons' spell tooltips (attached by the window's widget walker, XayaUI_Options/TreePaint.lua).
-- Part of the rule editor, moved out of Options.lua unchanged in the platform split P3 (Options 0.6.83;
-- docs/plans/PLATFORM-SPLIT-2026-11-07.md section 7, Q1: the rule module owns its editor). This folder talks to the rest of the
-- settings window only through ns.OptionsApi: ns.OptionsApi.Shared (what Options.lua lends it) in, ns.OptionsApi.RuleEditor (what
-- Options.lua asks of it) out; its files share their own parts through ns.OptionsApi.RuleEditorParts.
-------------------------------------------------------------------------------
local addonName, ns = ...
ns = _G.XayaUI_NS or ns   -- one namespace with XayaUI core (XayaUI Rules depends on it: ## Dependencies: XayaUI)
-- (Rules 0.7.0, REQUEST-LOG A23 SD-6) This file is part of XayaUI Rules (it was the load-on-demand addon XayaUI_Rules_Options). The game
-- reads it at login with Rules; everything below only runs when the settings window first opens with Rules on: it is one set-up
-- function, run once by XayaUI_Options (Options.lua ns.OptionsApi.LoadRuleEditor) in the .toc order. Nothing is built before then.
local function EditorFileInit()
if not (ns.OptionsApi and ns.OptionsApi.Shared) then return end   -- Options.lua stopped early (its Ace3 libraries are missing)
local O = ns.OptionsApi.Shared
local APP, AceConfigDialog = O.APP, O.AceConfigDialog
local P = ns.OptionsApi.RuleEditorParts
local SpellTex = P.SpellTex
local Ours = ns.OptionsApi.TreePaint.Ours   -- (review R16) a pooled AceGUI widget that is in XayaUI's window right now (TreePaint.lua)


-- Full Blizzard spell tooltip on the talent icon (an AceGUI Icon whose option carries arg.xuiSpell = the talent row).
-- AceGUI clears callbacks when a widget is recycled, so this re-checks on every pass instead of flagging the widget.
-------------------------------------------------------------------------------
-- Spell-name search. By default a search box looks only through what is relevant to the player, all of it at once: this class's
-- spells and talents, the spellbook, the spells the rules use, and the auras the carried items apply (SX.Near). The game has no
-- "search spells by name" call, so finding any spell in the game means walking spell IDs 1..SI_MAX (about 4 ms per frame) and keeping
-- every name; that whole-game index is built only after the player clicks "Search all spells" (SX.full), and it is freed, with the
-- item index and the aura-source pass, when the settings window closes (ns.SearchOnClose).
-- Xaya, 2026-11-04, choosing this ("go with b"): before Options 0.6.37 the first focus of any search box built the whole-game spell
-- and item indexes and kept them until /reload, and an aura search also started a tooltip pass over every indexed item that kept
-- running after the window closed; her addon-usage tooltip showed XayaUI_Options at 521.4 MB after /xui.
-------------------------------------------------------------------------------
local AttachSearch
do
local SI = { names = {}, ids = {}, n = 0, nextId = 1, running = false }
local SI_MAX = 1900000
local SX = {}   -- item-search helpers in one table (this file is close to Lua's 200-locals limit)
local function StartScan(S, max, getn)
    if S.running or S.nextId > max or not getn then return end
    S.running = true
    S.frame = S.frame or CreateFrame("Frame")
    S.frame:SetScript("OnUpdate", function(self)
        local ok = pcall(function()
            local t0 = debugprofilestop()
            while S.nextId <= max and debugprofilestop() - t0 < 4 do
                local last = math.min(S.nextId + 499, max)
                for id = S.nextId, last do
                    local nm = getn(id)
                    if nm and nm ~= "" then local n = S.n + 1; S.n = n; S.names[n] = nm:lower(); S.ids[n] = id end
                end
                S.nextId = last + 1
            end
        end)
        if not ok or S.nextId > max then S.running = false; self:SetScript("OnUpdate", nil) end
    end)
end
-- Item names: the client only knows the names of items it has already loaded (no way to list every item in the game), so this index
-- holds those; the items you carry / wear are added fresh on every search (OwnedItems).
SX.II = { names = {}, ids = {}, n = 0, nextId = 1, running = false }
SX.II_MAX = 300000
SX.full = false   -- true after "Search all spells / items", until the settings window closes
function SX.Start(kind)
    if kind == "talent" and not XayaUITalentDB and not SX.scanTried and ns.ScanAllTalents then
        SX.scanTried = true   -- once per session: lists every spec and hero tree of the class, not only the current build
        pcall(ns.ScanAllTalents)
    end
    if not SX.full then return end
    if kind == "item" then StartScan(SX.II, SX.II_MAX, C_Item and C_Item.GetItemNameByID)
    else StartScan(SI, SI_MAX, C_Spell.GetSpellName) end
    if kind == "aura" and ns.AuraSources then   -- the "source" column needs the item index and a tooltip pass over it (AuraSources.lua)
        StartScan(SX.II, SX.II_MAX, C_Item and C_Item.GetItemNameByID)
        SX.II.max = SX.II_MAX
        local ids = {}
        for _, sp in ipairs(ns.BuildSpellList() or {}) do if sp.id then ids[#ids + 1] = sp.id end end
        if ns.AuraSources and ns.AuraSources.Start then pcall(ns.AuraSources.Start, SX.II, ids) end   -- core module (AuraSources.lua)
    end
end
function SX.SearchAll(kind)
    SX.full = true
    SX.Start(kind)
end

-- The spells the rules use and the auras the carried items apply, in the class-set format so SX.ClassMatches ranks them the same way.
-- Built once per search box focus (SX.near is cleared on focus and on close). The items' auras come from their tooltips' embedded
-- effect blocks, read the same way AuraSources.lua reads them, and are noted there too, so the "From" column knows them.
-- C_TooltipInfo.GetItemByID(itemID) -> TooltipData · MayReturnNothing (docs/reference/api); TooltipUtil.SurfaceArgs as AuraSources.lua.
SX.NEAR_ID_KEYS, SX.NEAR_LIST_KEYS = { spellID = true, buffID = true }, { buffAlt = true, alt = true }   -- (in SX: this file is near the 200-locals limit)
function SX.Near()
    if SX.near then return SX.near end
    local list, have = {}, {}
    local function nameOf(id)
        local ok, n = pcall(C_Spell.GetSpellName, id)
        if ok and type(n) == "string" and n ~= "" then return n end
    end
    local function add(id, name, tag)
        if type(id) ~= "number" or have[id] or type(name) ~= "string" or name == "" then return end
        have[id] = true
        local nn = SX.Norm(name)
        local words = {}
        for w in nn:gmatch("%S+") do words[#words + 1] = w end
        list[#list + 1] = { id = id, name = name, tag = tag, norm = nn, words = words, cond = (nn:gsub(" ", "")) }
    end
    local visited, n = {}, 0
    local function walk(t, depth)
        if depth > 6 or visited[t] or n > 600 then return end
        visited[t] = true
        for k, v in pairs(t) do
            if SX.NEAR_ID_KEYS[k] and type(v) == "number" then n = n + 1; add(v, nameOf(v), "in your rules")
            elseif SX.NEAR_LIST_KEYS[k] and type(v) == "table" then
                for _, x in ipairs(v) do if type(x) == "number" then n = n + 1; add(x, nameOf(x), "in your rules") end end
            elseif type(v) == "table" then walk(v, depth + 1) end
        end
    end
    if type(ns.rules) == "table" then walk(ns.rules, 1) end
    local AS = ns.AuraSources
    if AS and AS.EmbeddedAuras and C_TooltipInfo and C_TooltipInfo.GetItemByID then
        for _, it in ipairs(SX.OwnedItems()) do
            local ok, data = pcall(C_TooltipInfo.GetItemByID, it.id)
            if ok and type(data) == "table" then
                if TooltipUtil and TooltipUtil.SurfaceArgs then
                    pcall(TooltipUtil.SurfaceArgs, data)
                    if type(data.lines) == "table" then for _, ln in ipairs(data.lines) do pcall(TooltipUtil.SurfaceArgs, ln) end end
                end
                local okA, auras = pcall(AS.EmbeddedAuras, data)
                if okA and type(auras) == "table" and #auras > 0 then
                    if AS.Note then pcall(AS.Note, "item", it.id, auras) end
                    for _, a in ipairs(auras) do add(a.id, a.name or nameOf(a.id), "from " .. tostring(it.name)) end
                end
            end
        end
    end
    SX.near = list
    return list
end
function SX.OwnedItems()
    local out, seen = {}, {}
    local function addId(id)
        pcall(function()
            if type(id) == "number" and id > 0 and not seen[id] then
                local nm = C_Item.GetItemNameByID(id)
                if type(nm) == "string" and nm ~= "" then seen[id] = true; out[#out + 1] = { id = id, name = nm } end
            end
        end)
    end
    for slot = 1, 19 do local ok, id = pcall(GetInventoryItemID, "player", slot); if ok then addId(id) end end
    if C_Container and C_Container.GetContainerNumSlots then
        for bag = 0, 12 do
            local ok, n = pcall(C_Container.GetContainerNumSlots, bag)
            if ok and type(n) == "number" then
                for s = 1, n do
                    local ok2, info = pcall(C_Container.GetContainerItemInfo, bag, s)
                    if ok2 and type(info) == "table" then addId(info.itemID) end
                end
            end
        end
    end
    return out
end

-- Class-scoped, typo-tolerant candidates. Sets ("talent", "cd", "aura", "any") hold every spell of the player's class that fits the kind:
-- the current build's talents + the last /xui debug talents scan (all specs and hero trees) + the class data (cooldowns, buffs, procs, debuffs of
-- every spec) + the spellbook. Every ID is kept, so a name shared by a talent, its buff and its debuff lists all of them, each labelled.
function SX.Norm(t)
    t = tostring(t or ""):lower():gsub("['\226\128\153]", ""):gsub("%p", " "):gsub("%s+", " ")
    return t:match("^%s*(.-)%s*$")
end
-- edit distance with swapped neighbours counted as one edit; gives up (returns maxd + 1) once it must exceed maxd
function SX.Dist(a, b, maxd)
    local la, lb = #a, #b
    if math.abs(la - lb) > maxd then return maxd + 1 end
    if la == 0 then return lb end
    if lb == 0 then return la end
    local p2, p1, cur = {}, {}, {}
    for j = 0, lb do p1[j] = j end
    for i = 1, la do
        cur[0] = i
        local ai, rowmin = a:byte(i), i
        for j = 1, lb do
            local bj = b:byte(j)
            local v = math.min(p1[j] + 1, cur[j - 1] + 1, p1[j - 1] + ((ai == bj) and 0 or 1))
            if i > 1 and j > 1 and ai == b:byte(j - 1) and a:byte(i - 1) == bj then v = math.min(v, p2[j - 2] + 1) end
            cur[j] = v
            if v < rowmin then rowmin = v end
        end
        if rowmin > maxd then return maxd + 1 end
        p2, p1, cur = p1, cur, p2
    end
    return p1[lb]
end
function SX.ClassSet(kind)
    local _, token, classID = UnitClass("player")
    if not token then return nil end
    local db = XayaUITalentDB
    local sig = table.concat({ token, tostring(GetSpecialization and GetSpecialization() or 0), tostring(db and db.built or ""),
        tostring(ns.talentList and #ns.talentList or 0), tostring(ns.spellList and #ns.spellList or 0) }, "|")
    if not (SX.cs and SX.cs.sig == sig) then
        local cs = { sig = sig, talent = {}, cd = {}, aura = {}, any = {} }
        local seen = { talent = {}, cd = {}, aura = {}, any = {} }
        local function add(which, id, name, tag)
            if not id or seen[which][id] then return end
            seen[which][id] = true
            local nn = SX.Norm(name)
            local words = {}
            for w in nn:gmatch("%S+") do words[#words + 1] = w end
            local l = cs[which]; l[#l + 1] = { id = id, name = name, tag = tag, norm = nn, words = words, cond = nn:gsub(" ", "") }
        end
        local function nameOf(id)
            local ok, n = pcall(C_Spell.GetSpellName, id)
            if ok and type(n) == "string" and n ~= "" then return n end
        end
        for _, tl in ipairs(ns.BuildTalentList and ns.BuildTalentList() or {}) do
            add("talent", tl.id, tl.name, "talent, your build"); add("any", tl.id, tl.name, "talent, your build")
        end
        local c = db and db.classes and classID and db.classes[classID]
        if c then
            for _, n in pairs(c.nodes or {}) do
                for _, e in ipairs(n.e or {}) do
                    local nm = e.spell and nameOf(e.spell)
                    if nm then
                        local where
                        if n.scope == "hero" then where = "hero talent"
                        elseif n.scope == "class" then where = "class talent"
                        else
                            local sp = {}
                            for sid in pairs(n.specs or {}) do sp[#sp + 1] = c.specs[sid] or tostring(sid) end
                            table.sort(sp)
                            where = "talent, " .. (#sp > 0 and table.concat(sp, "/") or "spec")
                        end
                        add("talent", e.spell, nm, where); add("any", e.spell, nm, where)
                        if not e.passive then add("cd", e.spell, nm, where) end
                    end
                end
            end
        end
        for _, d in pairs(ns.CLASS_AURA_DATA or {}) do
            if d.classToken == token then
                for _, e in ipairs(d.entries or {}) do
                    local nm = nameOf(e.id)
                    if nm then
                        local what = (e.kind == "cd") and "cooldown" or ((e.kind == "debuff") and "debuff" or ((e.kind == "proc") and "proc" or "buff"))
                        local tag = what .. ", " .. tostring(d.spec)
                        if e.kind == "cd" then add("cd", e.id, nm, tag) else add("aura", e.id, nm, tag) end
                        add("any", e.id, nm, tag)
                    end
                end
            end
        end
        for _, sp in ipairs(ns.BuildSpellList and ns.BuildSpellList() or {}) do
            if sp.name then add("cd", sp.id, sp.name, "spellbook"); add("any", sp.id, sp.name, "spellbook") end
        end
        SX.cs = cs
    end
    return SX.cs[(kind == "talent" or kind == "cd" or kind == "aura") and kind or "any"]
end
-- rank 1 exact, 2 starts with, 3 every word found, 4 found with typos / a missing space (closest first)
function SX.ClassMatches(set, q)
    local qn = SX.Norm(q)
    if qn == "" then return {} end
    local qw = {}
    for w in qn:gmatch("%S+") do qw[#qw + 1] = w end
    local qc = qn:gsub(" ", "")
    local out = {}
    for _, e in ipairs(set) do
        local rank, dist
        if e.norm == qn then rank, dist = 1, 0
        elseif e.norm:sub(1, #qn) == qn then rank, dist = 2, 0
        else
            local all, total = true, 0
            for _, w in ipairs(qw) do
                local best
                for _, x in ipairs(e.words) do
                    local d
                    if x:find(w, 1, true) then d = 0
                    else
                        local tol = (#w >= 8) and 2 or ((#w >= 4) and 1 or 0)
                        if tol > 0 then
                            d = math.min(SX.Dist(w, x, tol), SX.Dist(w, x:sub(1, #w), tol))
                            if d > tol then d = nil end
                        end
                    end
                    if d and (not best or d < best) then best = d end
                end
                if not best then all = false; break end
                total = total + best
            end
            if all then rank, dist = (total == 0) and 3 or 4, total
            elseif #qc >= 4 then   -- a missing or extra space, or a typo across the whole name
                local tol = (#qc >= 8) and 2 or 1
                local d = math.min(SX.Dist(qc, e.cond, tol), SX.Dist(qc, e.cond:sub(1, #qc), tol))
                if e.cond:find(qc, 1, true) then d = 0 end
                if d <= tol then rank, dist = 4, d end
            end
        end
        if rank then out[#out + 1] = { id = e.id, tag = e.tag, rank = rank, dist = dist, name = e.name } end
    end
    table.sort(out, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        if a.dist ~= b.dist then return a.dist < b.dist end
        if a.name ~= b.name then return a.name < b.name end
        return a.id < b.id
    end)
    return out
end

local function SearchSpells(q, kind)
    local item = kind == "item"
    local res, seen = {}, {}
    SX.tags = {}
    q = (q or ""):lower():match("^%s*(.-)%s*$")
    if q == "" then return res end
    local num = tonumber(q)
    if num then
        local ok, nm = pcall(item and C_Item.GetItemNameByID or C_Spell.GetSpellName, num)
        if ok and nm then res[1] = num; seen[num] = true end
    end
    if not item and not num then   -- this class first (typos tolerated), then the rest of the game
        local okS, set = pcall(SX.ClassSet, kind)
        if okS and set and #set > 0 then
            local okM, hits = pcall(SX.ClassMatches, set, q)
            for _, h in ipairs(okM and hits or {}) do
                if #res >= 80 then break end
                if not seen[h.id] then seen[h.id] = true; res[#res + 1] = h.id; SX.tags[h.id] = h.tag end
            end
            if kind == "talent" then return res end   -- a talent search lists this class's talents only
        end
        local okN, near = pcall(SX.Near)
        if okN and near and #near > 0 then
            local okM2, hits2 = pcall(SX.ClassMatches, near, q)
            for _, h in ipairs(okM2 and hits2 or {}) do
                if #res >= 80 then break end
                if not seen[h.id] then seen[h.id] = true; res[#res + 1] = h.id; SX.tags[h.id] = h.tag end
            end
        end
    end
    -- No syntax to remember: every word must appear in the name, in any order; "*" matches anything. Exact names rank first,
    -- then names that start with the search, then the rest.
    local words = {}
    for w in q:gmatch("%S+") do
        words[#words + 1] = w:gsub("[%^%$%(%)%%%.%[%]%+%-%?]", "%%%0"):gsub("%*", ".*")
    end
    local function matches(nm)
        for i = 1, #words do if not nm:find(words[i]) then return false end end
        return true
    end
    local function rank(nm)
        if nm == q then return 1 end
        if nm:sub(1, #q) == q then return 2 end
        return 3
    end
    local buckets = { {}, {}, {} }
    local function consider(id, nm)
        if id and nm and not seen[id] and matches(nm) then
            seen[id] = true
            local t = buckets[rank(nm)]; t[#t + 1] = id
        end
    end
    if item then
        for _, it in ipairs(SX.OwnedItems()) do consider(it.id, it.name:lower()) end
    else
        for _, sp in ipairs(ns.BuildSpellList() or {}) do
            if sp.name then consider(sp.id, sp.name:lower()) end
        end
    end
    local S = item and SX.II or SI
    local names, ids = S.names, S.ids
    for i = 1, S.n do consider(ids[i], names[i]) end
    for _, t in ipairs(buckets) do
        for _, id in ipairs(t) do
            if #res >= 80 then return res end
            res[#res + 1] = id
        end
    end
    return res
end

local SP, SP_ROWS, SP_ROW_H = nil, 8, 24
local function SP_Render()
    if not SP then return end
    local r, total = SP.results or {}, #(SP.results or {})
    for i = 1, SP_ROWS do
        local row, id = SP.rows[i], r[SP.offset + i]
        if id then
            row.id = id
            if SP.kind == "item" then
                local oki, ic = pcall(C_Item.GetItemIconByID, id)
                row.icon:SetTexture((oki and ic) or 134400)
            else row.icon:SetTexture(SpellTex(id)) end
            local okn, nm = pcall(SP.kind == "item" and C_Item.GetItemNameByID or C_Spell.GetSpellName, id)
            local tg = SX.tags and SX.tags[id]
            local src = (SP.kind == "aura" and ns.AuraSources) and ns.AuraSources.Label(id) or nil
            row.text:SetText(((okn and nm) or "?") .. "  |cff888888[" .. id .. "]|r" .. (tg and ("  |cff7fb6e6" .. tg .. "|r") or "")
                .. (src and ("  |cffb4a06eFrom|r |cffc9c9c9" .. src .. "|r") or ""))
            row:Show()
        else row:Hide() end
    end
    local msg = ""
    local S, smax = (SP.kind == "item") and SX.II or SI, (SP.kind == "item") and SX.II_MAX or SI_MAX
    if S.running then msg = ("Indexing %s names... %d%%  "):format(SP.kind == "item" and "item" or "spell", math.floor(S.nextId / smax * 100)) end
    if SP.kind == "talent" and not (XayaUITalentDB and XayaUITalentDB.classes) then msg = msg .. "Your current build only; /xui debug talents adds every spec.  " end
    if SP.kind == "aura" and ns.AuraSources then
        local pr = ns.AuraSources.Progress()
        if pr then msg = msg .. ("Finding what applies each aura... %d%%  "):format(math.floor(pr * 100)) end
    end
    local canAll = SP.kind ~= "talent" and not SX.full
    if total == 0 then msg = msg .. (canAll and (SP.kind == "item" and "No match in your bags" or "No match in your spells, rules or bags") or "No match yet")
    elseif total > SP_ROWS then msg = msg .. total .. " results - scroll for more" end
    SP.footer:SetText(msg)
    if canAll then
        SP.all.t:SetText(SP.kind == "item" and "Search all items" or "Search all spells")
        SP.all:SetWidth((SP.all.t:GetStringWidth() or 100) + 8)
        SP.all:Show()
    else
        SP.all:Hide()
    end
end
local function SP_Hide() if SP then SP:Hide(); SP.owner, SP.pick = nil, nil end end
-- The settings window closed: stop the scans and the aura-source pass, and free both whole-game indexes and the near set. What the
-- pass already learned stays (CueRulesDB.auraSources, small); a later "Search all" starts the indexes again from the first ID.
function ns.SearchOnClose()
    SP_Hide()
    for _, S in ipairs({ SI, SX.II }) do
        if S.frame then S.frame:SetScript("OnUpdate", nil) end
        S.running = false
        S.names, S.ids, S.n, S.nextId = {}, {}, 0, 1
    end
    SX.full, SX.near, SX.cs, SX.tags = false, nil, nil, {}
    local st = ns.AuraSources and ns.AuraSources.state   -- AuraSources.lua's pass state (its item positions point into SX.II)
    if st then
        if st.frame then st.frame:SetScript("OnUpdate", nil) end
        st.running, st.stage, st.pos, st.idx, st.spells, st.finished = false, 1, 1, nil, nil, nil
    end
end
ns.SpellSearchTest = { SX = SX, SI = SI, Search = function(q, k) return SearchSpells(q, k) end }   -- (tests)
-- (review R16) What a search box picks into is read from the widget's option, never kept on the box: AceGUI hands its edit boxes to
-- other addons after release, and a box that is not in XayaUI's window right now (TreePaint Ours) has no search. The popup keeps the
-- pick of the box it opened for (SP.pick) until it hides; the window closing hides it (ns.SearchOnClose).
local function SearchOf(eb)
    local w = eb and eb.obj
    if not Ours(w) then return nil end
    local opt = w.userdata.option
    local arg = type(opt) == "table" and opt.arg
    if type(arg) ~= "table" or type(arg.xuiSearch) ~= "function" then return nil end
    return arg.xuiSearch, arg.xuiSearchKind
end
local function SP_Pick(id)
    local eb, fn = SP and SP.owner, SP and SP.pick
    SP_Hide()
    if not (id and fn and eb and Ours(eb.obj)) then return end
    eb:SetText(""); eb:ClearFocus()
    local ok, err = pcall(fn, id)   -- an error in the pick handler used to vanish and leave the ID box unchanged
    if not ok then ns.Print("search pick failed: " .. tostring(err)) end
end

-- Hovering a result must never open the "compare with equipped gear" tooltips (Blizzard adds them on its own for items).
function SX.NoCompare()
    if GameTooltip_HideShoppingTooltips then pcall(GameTooltip_HideShoppingTooltips, GameTooltip) end
    for _, n in ipairs({ "ShoppingTooltip1", "ShoppingTooltip2" }) do local f = _G[n]; if f and f.Hide then f:Hide() end end
end
function SX.HookCompare()
    if SX.compareHooked then return end
    SX.compareHooked = true
    if hooksecurefunc and type(GameTooltip_ShowCompareItem) == "function" then
        hooksecurefunc("GameTooltip_ShowCompareItem", function()
            if SP and SP.tipRow and GameTooltip:GetOwner() == SP.tipRow then SX.NoCompare() end
        end)
    end
end
local function SP_Build()
    if SP then return SP end
    SP = CreateFrame("Frame", "XayaUISpellSearch", UIParent, "BackdropTemplate")
    SP:SetFrameStrata("TOOLTIP"); SP:SetClampedToScreen(true); SP:EnableMouse(true); SP:EnableMouseWheel(true)
    SP:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    SP:SetBackdropColor(0.05, 0.05, 0.08, 0.97); SP:SetBackdropBorderColor(0.6, 0.5, 0.1, 1)
    SP:SetSize(340, SP_ROWS * SP_ROW_H + 22)
    SP.rows, SP.offset, SP.results = {}, 0, {}
    for i = 1, SP_ROWS do
        local b = CreateFrame("Button", nil, SP)
        b:SetHeight(SP_ROW_H)
        b:SetPoint("TOPLEFT", SP, "TOPLEFT", 2, -2 - (i - 1) * SP_ROW_H)
        b:SetPoint("TOPRIGHT", SP, "TOPRIGHT", -2, -2 - (i - 1) * SP_ROW_H)
        b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetSize(20, 20); b.icon:SetPoint("LEFT", 2, 0)
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        b.text:SetPoint("LEFT", b.icon, "RIGHT", 6, 0); b.text:SetPoint("RIGHT", -4, 0); b.text:SetJustifyH("LEFT")
        b.hl = b:CreateTexture(nil, "HIGHLIGHT"); b.hl:SetAllPoints(); b.hl:SetColorTexture(1, 0.82, 0, 0.18)
        -- mouse DOWN so the pick lands before the edit box loses focus
        b:SetScript("OnMouseDown", function(self) SP_Pick(self.id) end)
        -- (review R14 / R15) GameTooltip's own fields are never written (one of them turned the game's gear comparison off until
        -- /reload): the compare tooltips Blizzard opens for a hovered result are hidden by the hook above instead
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            SX.HookCompare(); SP.tipRow = self
            if SP.kind == "item" then
                if not pcall(GameTooltip.SetItemByID, GameTooltip, self.id) then GameTooltip:SetText("Item " .. tostring(self.id)) end
            elseif not pcall(GameTooltip.SetSpellByID, GameTooltip, self.id) then GameTooltip:SetText("Spell " .. tostring(self.id)) end
            GameTooltip:Show()
            SX.NoCompare()
            if C_Timer then C_Timer.After(0, function() if SP and SP.tipRow == self then SX.NoCompare() end end) end
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide(); if SP then SP.tipRow = nil end; SX.NoCompare() end)
        SP.rows[i] = b
    end
    SP.footer = SP:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    SP.footer:SetPoint("BOTTOMLEFT", 6, 5); SP.footer:SetJustifyH("LEFT")
    -- "Search all spells / items": builds the whole-game index for this window session (freed when the window closes)
    SP.all = CreateFrame("Button", nil, SP)
    SP.all:SetHeight(16); SP.all:SetPoint("BOTTOMRIGHT", -6, 2)
    SP.all.t = SP.all:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    SP.all.t:SetPoint("RIGHT", 0, 0); SP.all.t:SetJustifyH("RIGHT")
    SP.all:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(SP.kind == "item" and "Search every item the game knows" or "Search every spell in the game")
        GameTooltip:AddLine("Takes a few seconds and memory while the settings window is open; it is freed when you close the window.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    SP.all:SetScript("OnLeave", function() GameTooltip:Hide() end)
    SP.all:SetScript("OnMouseDown", function()   -- mouse DOWN, before the edit box loses focus (as the result rows)
        SX.SearchAll(SP.kind)
        if SP.owner then SP.results, SP.offset = SearchSpells(SP.owner:GetText(), SP.kind), 0; SP_Render() end
    end)
    SP:SetScript("OnMouseWheel", function(self, d)
        local maxOff = math.max(0, #self.results - SP_ROWS)
        self.offset = math.max(0, math.min(maxOff, self.offset - d * 2))
        SP_Render()
    end)
    local acc = 0
    SP:SetScript("OnUpdate", function(self, e)
        if self.owner and not self.owner:IsVisible() then SP_Hide(); return end
        if ((self.kind == "item") and SX.II.running) or (self.kind ~= "item" and SI.running)
            or (self.kind == "aura" and ns.AuraSources and ns.AuraSources.Progress()) then
            acc = acc + e
            if acc > 0.6 and self.owner then acc = 0; self.results = SearchSpells(self.owner:GetText(), self.kind); SP_Render() end
        end
    end)
    SP:Hide()
    return SP
end
local function SP_Update(eb)
    local fn, kind = SearchOf(eb)
    local q = eb:GetText() or ""
    if not fn or (#q < 2 and not tonumber(q)) then SP_Hide(); return end
    SP_Build()
    SP.owner, SP.pick = eb, fn
    SP.kind = kind
    SP.results, SP.offset = SearchSpells(q, SP.kind), 0
    SP:ClearAllPoints()
    SP:SetPoint("TOPLEFT", eb, "BOTTOMLEFT", -4, -2)
    SP:SetWidth(math.max(SP.kind == "aura" and 560 or 340, eb:GetWidth() + 8))
    SP:Show()
    SP_Render()
end
AttachSearch = function(w)
    local eb = w.editbox
    if not eb or eb.xuiSearchHooked or not SearchOf(eb) then return end
    eb.xuiSearchHooked = true   -- (review R16) the hooks stay on the pooled box: each acts only while SearchOf finds a search, or for the popup it opened
    -- (A23 SD-12) each returns at its first line while the box is not in XayaUI's window (Ours) or the popup is not its own
    eb:HookScript("OnEditFocusGained", function(self) if not Ours(self.obj) then return end; local fn, kind = SearchOf(self); if fn then SX.near = nil; SX.Start(kind) end end)
    eb:HookScript("OnTextChanged", function(self, user)
        if not (user and Ours(self.obj)) then if SP and SP.owner == self then SP_Hide() end return end
        local fn, kind = SearchOf(self)
        if not fn then if SP and SP.owner == self then SP_Hide() end; return end
        SX.Start(kind)
        self.xuiStamp = (self.xuiStamp or 0) + 1
        local stamp = self.xuiStamp
        C_Timer.After(0.15, function() if self.xuiStamp == stamp and self:HasFocus() then SP_Update(self) end end)
    end)
    eb:HookScript("OnEnterPressed", function(self)
        if SP and SP:IsShown() and SP.owner == self and SP.results[1] then SP_Pick(SP.results[1]) end
    end)
    eb:HookScript("OnEscapePressed", function(self) if SP and SP.owner == self then SP_Hide() end end)
    eb:HookScript("OnEditFocusLost", function(self)
        if not (SP and SP.owner == self) then return end
        C_Timer.After(0.2, function() if SP and SP.owner == self and not self:HasFocus() then SP_Hide() end end)
    end)
end

end

local function SpellIconLeave() GameTooltip:Hide() end
local function SpellIconEnter(widget)
    local opt = widget.GetUserData and widget:GetUserData("option")
    local row = opt and type(opt.arg) == "table" and opt.arg.xuiSpell
    local id = row and row.id
    GameTooltip:SetOwner(widget.frame, "ANCHOR_RIGHT")
    if id and id > 0 then
        local ok = pcall(GameTooltip.SetSpellByID, GameTooltip, id)
        if not ok then GameTooltip:SetText("Unknown spell ID " .. tostring(id)) end
    else
        GameTooltip:SetText("Type a spell ID to see its tooltip.")
    end
    GameTooltip:Show()
end
local function AttachSpellTip(w)
    local opt = w.GetUserData and w:GetUserData("option")
    if not (opt and type(opt.arg) == "table" and opt.arg.xuiSpell) then return end
    if not (w.events and w.events.OnEnter == SpellIconEnter) then
        w:SetCallback("OnEnter", SpellIconEnter)
        w:SetCallback("OnLeave", SpellIconLeave)
    end
end

-- (P4b) the window's widget walker (XayaUI_Options/TreePaint.lua ns.DecorateTrees) hands every Icon and EditBox widget here: the
-- talent icons' spell tooltips and the spell / item search boxes are the rule editor's (Sidebar.lua made TreePaint.rules)
ns.OptionsApi.TreePaint.rules.Widget = function(w)
    if w.type == "Icon" then AttachSpellTip(w) end
    if w.type == "EditBox" then AttachSearch(w) end
end
end
ns.RuleEditorFiles = ns.RuleEditorFiles or {}
ns.RuleEditorFiles[#ns.RuleEditorFiles + 1] = EditorFileInit
