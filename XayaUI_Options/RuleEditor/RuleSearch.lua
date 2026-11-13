-------------------------------------------------------------------------------
-- RuleSearch.lua : a search box at the top of every rule's settings (Xaya 2026-11-04: "allow search bar inside individual rules
-- ... to search through options (also allow regular expression / smart keyword searching)"). Own design and code.
--   * Smart keywords: every word typed must match a word of the option (its name, its help text, or the section and tab it is
--     in), in any order: the same word, the start of a word (3+ letters), or one letter off (5+ letters). Matches in the option's
--     own name rank first.
--   * Patterns: text between slashes, e.g. /charge|stack/ or /^show/, is a Lua pattern. Lua patterns are NOT full regular
--     expressions: they have . %a %d %s %w, sets [abc], repeats * + - ?, anchors ^ $, but no alternation; | between slashes is
--     added here to mean "or". An invalid pattern says so instead of matching nothing.
-- Results (up to 12) name the tab, the section and the option; clicking one opens that tab of the rule (Editor.lua
-- ns.SelectRuleTab), folds the results away and scrolls the option into view (#483, Rules Options 0.6.81; RS.Reveal below). The query
-- is kept per rule for this session only.
-------------------------------------------------------------------------------
local ADDON, ns = ...
ns = _G.XayaUI_NS or ns
-- (bundle 1 round 7, REQUEST-LOG A23 SD-57, her words: "editor is an 'options' pane so 3"; V34) This file is part of XayaUI Options
-- (it was XayaUI_Rules/Editor/, read at login with Rules). The game reads it only when the settings window's code loads, after the
-- window's own files (XayaUI_Options.toc). With XayaUI Rules switched off it stops on the next line and builds nothing.
if not (ns.OptionsApi and ns.Service and ns.Service("rules")) then return end   -- (and nothing while the window's code could not load: Options.lua)

local O = ns.OptionsApi and ns.OptionsApi.Shared or {}   -- (#483) the settings window's AceConfigDialog, to find the clicked option
local APP, AceConfigDialog = O.APP or "CueRules", O.AceConfigDialog

local RS = {}
ns.RuleSearch = RS
local MAX = 12
local query = setmetatable({}, { __mode = "k" })   -- rule -> text typed (session only)

local function Strip(s)
    s = tostring(s or "")
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|n", " ")
    return s
end
local function Norm(s)
    s = Strip(s):lower():gsub("['\226\128\153]", ""):gsub("%p", " "):gsub("%s+", " ")
    return (s:match("^%s*(.-)%s*$"))
end
RS.Norm = Norm
-- edit distance with an early stop (enough for words of a few letters)
local function Dist(a, b, maxd)
    if math.abs(#a - #b) > maxd then return maxd + 1 end
    local prev = {}
    for j = 0, #b do prev[j] = j end
    for i = 1, #a do
        local cur, best = { [0] = i }, i
        for j = 1, #b do
            local cost = (a:sub(i, i) == b:sub(j, j)) and 0 or 1
            cur[j] = math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
            if cur[j] < best then best = cur[j] end
        end
        if best > maxd then return maxd + 1 end
        prev = cur
    end
    return prev[#b]
end
RS.Dist = Dist
local function WordHit(q, w)
    if w == q then return 3 end
    if #q >= 3 and w:sub(1, #q) == q then return 2 end
    if #q >= 5 and Dist(q, w, 1) <= 1 then return 1 end
    return nil
end
-- smart keywords: score, or nil when a word is not found anywhere
function RS.SmartScore(q, name, rest)
    local qn = Norm(q)
    if qn == "" then return nil end
    local nameWords, allWords = {}, {}
    for w in Norm(name):gmatch("%S+") do nameWords[#nameWords + 1] = w; allWords[#allWords + 1] = w end
    for w in Norm(rest):gmatch("%S+") do allWords[#allWords + 1] = w end
    local score, inName = 0, true
    for qw in qn:gmatch("%S+") do
        local best, bestName = nil, nil
        for _, w in ipairs(allWords) do local h = WordHit(qw, w); if h and (not best or h > best) then best = h end end
        if not best then return nil end
        for _, w in ipairs(nameWords) do local h = WordHit(qw, w); if h and (not bestName or h > bestName) then bestName = h end end
        if not bestName then inName = false end
        score = score + best
    end
    return score + (inName and 10 or 0)
end
-- /pattern/ (with | for "or"): returns a matcher, or nil plus the reason
function RS.Pattern(q)
    local inner = tostring(q or ""):match("^%s*/(.+)/%s*$")
    if not inner then return nil end
    local alts, buf, i = {}, "", 1
    while i <= #inner do
        local ch = inner:sub(i, i)
        if ch == "%" and i < #inner then buf = buf .. inner:sub(i, i + 1); i = i + 2
        elseif ch == "|" then alts[#alts + 1] = buf; buf = ""; i = i + 1
        else buf = buf .. ch; i = i + 1 end
    end
    alts[#alts + 1] = buf
    for _, a in ipairs(alts) do
        if a == "" then return false, "an empty alternative (a | at the start, the end, or twice)" end
        local ok, err = pcall(string.find, "", a)
        if not ok then return false, tostring(err):gsub("^.-:%d+: ", "") end
    end
    return function(text)
        local t = Strip(text)
        local tl = t:lower()
        for _, a in ipairs(alts) do
            local ok1, s1 = pcall(string.find, t, a)
            local ok2, s2 = pcall(string.find, tl, a)
            if (ok1 and s1) or (ok2 and s2) then return true end
        end
        return false
    end
end
local function Val(v, info)
    if type(v) == "function" then local ok, r = pcall(v, info); return ok and r or nil end
    return v
end
-- every option of a rule's settings, with the tab and the sections it sits in
function RS.Index(ruleGroup)
    local out = {}
    local tabs = {}
    for k, g in pairs(ruleGroup.args or {}) do
        if type(g) == "table" and g.type == "group" and not g.inline then tabs[#tabs + 1] = k end
    end
    table.sort(tabs, function(a, b) return (tonumber(ruleGroup.args[a].order) or 100) < (tonumber(ruleGroup.args[b].order) or 100) end)
    local seen = {}
    local function walk(args, tabKey, tabName, path, depth, kpath, korder)
        if depth > 12 or type(args) ~= "table" then return end
        local keys = {}
        for k, o in pairs(args) do if type(o) == "table" then keys[#keys + 1] = k end end
        table.sort(keys, function(a, b)
            local oa, ob = tonumber(args[a].order) or 100, tonumber(args[b].order) or 100
            if oa ~= ob then return oa < ob end
            return tostring(a) < tostring(b)
        end)
        for _, k in ipairs(keys) do
            local o = args[k]
            if not seen[o] then
                seen[o] = true
                local nm = Strip(Val(o.name, { k }) or "")
                local kk, ko = {}, {}
                for n2 = 1, #kpath do kk[n2] = kpath[n2]; ko[n2] = korder[n2] end
                kk[#kk + 1] = k; ko[#ko + 1] = tonumber(o.order) or 100
                if o.type == "group" then
                    local sub = path
                    if nm:match("%S") then sub = path .. (path ~= "" and " > " or "") .. nm end
                    walk(o.args, tabKey, tabName, sub, depth + 1, kk, ko)
                elseif o.type ~= "description" and o.type ~= "header" and nm:match("%S") then
                    -- keys: the option's place under the rule (tab key, group keys, its own key) = the end of the AceConfig path the
                    -- window keeps on the option's control (#483: the click finds that control and scrolls to it)
                    out[#out + 1] = { tab = tabKey, tabName = tabName, path = path, name = nm, desc = Strip(Val(o.desc, { k }) or ""), keys = kk, orders = ko }
                end
            end
        end
    end
    for _, k in ipairs(tabs) do
        local g = ruleGroup.args[k]
        local tn = Strip(Val(g.name, { k }) or k)
        walk(g.args, k, tn, "", 0, { k }, { tonumber(g.order) or 100 })
    end
    return out
end
-- results for a query: list of { entry, score }, plus an error text for a bad pattern
function RS.Find(ruleGroup, q)
    q = tostring(q or "")
    if not q:match("%S") then return {}, nil end
    local idx = RS.Index(ruleGroup)
    local res = {}
    local matcher, why = RS.Pattern(q)
    if matcher == false then return {}, "That pattern is not valid: " .. tostring(why) end
    for n, e in ipairs(idx) do
        local hay = e.tabName .. " " .. e.path .. " " .. e.desc
        local sc
        if matcher then
            if matcher(e.name) then sc = 20 elseif matcher(hay) then sc = 10 end
        else
            sc = RS.SmartScore(q, e.name, hay)
        end
        if sc then res[#res + 1] = { e = e, score = sc, n = n } end
    end
    table.sort(res, function(a, b) if a.score ~= b.score then return a.score > b.score end return a.n < b.n end)
    return res, nil
end
function RS.Label(e)
    return e.tabName .. "  >  " .. ((e.path ~= "") and (e.path .. "  >  ") or "") .. e.name
end

-- #483 (Rules Options 0.6.81; Xaya 2026-11-07, J31 step 3: "nothing happens on click"; step text "the rule's tab with that option
-- opens"). A click used to switch the tab only: the results stayed above the tabs and pushed the tab's page out of sight, and the page
-- kept its old scroll. Now the click also folds the results away (the typed text stays; Enter in the box, typing, or Clear search
-- brings them back) and, once the window has redrawn, scrolls the tab's page so the option's control is in view. A highlight flash
-- (A17) and a "show results" toggle wait for her.
local folded = setmetatable({}, { __mode = "k" })   -- rule -> true while its results are folded away after a click
RS.folded = folded   -- (tests)
-- how many of the entry's keys a control's AceConfig path holds in order, from the tab key on; exact = it is the option's own control
local function Match(path, keys)
    if type(path) ~= "table" then return 0, false end
    local best, exact, at = 0, false, nil
    for p = 1, #path do
        if path[p] == keys[1] then
            local m = 0
            while keys[m + 1] ~= nil and path[p + m] == keys[m + 1] do m = m + 1 end
            if m > best then best = m; exact = (m == #keys and p + m - 1 == #path); at = p end
        end
    end
    return best, exact, at
end
-- the order of the option-tree node at path[n] (from the window's own options table)
local function OrderAt(options, path, n)
    local t = options
    for i = 1, n do
        t = type(t) == "table" and type(t.args) == "table" and t.args[path[i]] or nil
        if not t then return nil end
    end
    return tonumber(t.order) or 100
end
-- the open settings window's control for an index entry (its AceConfig path ends with the entry's keys), and the scroll frame it is in.
-- When the option itself is not drawn (a switch above it is off), the drawn control nearest to it in the options tree (the most keys in
-- common, at least the tab and one more; the first one drawn), and false as the third value.
function RS.FindControl(e)
    local root = AceConfigDialog and AceConfigDialog.OpenFrames and AceConfigDialog.OpenFrames[APP]
    if not (root and e and type(e.keys) == "table" and e.keys[1]) then return nil end
    -- (ties: the control whose branch comes just before the option's own, where the switch that hides it usually is)
    local found, scroll, near, nearSc, nearKey
    local function walk(w, sc, d)
        if found or type(w) ~= "table" or d > 40 then return end
        if w.type == "ScrollFrame" then sc = w end
        local u = w.GetUserDataTable and w:GetUserDataTable()
        if u and u.option and u.option.type ~= "group" and w.frame and w.frame:IsVisible() then
            local m, exact, at = Match(u.path, e.keys)
            if exact then found, scroll = w, sc; return end
            if m >= 2 then
                local so = OrderAt(u.options, u.path, at + m) or 100
                local to = (e.orders and e.orders[m + 1]) or 100
                local key = m * 1e6 + ((so <= to) and 5e5 or 0) - math.min(4e5, math.abs(to - so) * 1000)
                if not nearKey or key > nearKey then near, nearSc, nearKey = w, sc, key end
            end
        end
        for _, c in ipairs(w.children or {}) do walk(c, sc, d + 1) end
    end
    walk(root, nil, 0)
    if found then return found, scroll, true end
    if near then return near, nearSc, false end
    return nil
end
-- a closed section on the way to the option is opened, as a click on its open / close button would (session only; no setting
-- changes): a section with a header button beside its body (arg.xuiChevron: Editor.lua Sub, ns.GatedPane, ns.ArrowToggle banners)
-- and an option under a collapsed sub-header (arg.xuiCollapse: ns.CollapsibleHeaders). Options hidden by a switch stay hidden.
local function Hidden(o)
    local h = o.hidden
    if type(h) == "function" then local ok, v = pcall(h, {}); return ok and v and true or false end
    return h and true or false
end
function RS.OpenPath(ruleGroup, keys)
    local args, opened = ruleGroup and ruleGroup.args, 0
    for i = 1, #(keys or {}) do
        local node = type(args) == "table" and args[keys[i]]
        if type(node) ~= "table" then break end
        if i > 1 and Hidden(node) then
            for _, o in pairs(args) do
                local a = type(o) == "table" and o.type == "execute" and type(o.arg) == "table" and o.arg or nil
                if a and type(a.xuiChevron) == "function" and type(o.func) == "function" and node.type == "group" then
                    local ok, open = pcall(a.xuiChevron)
                    if ok and not open then pcall(o.func); opened = opened + 1 end
                end
            end
            local hdr, ho, no = nil, nil, tonumber(node.order) or 100
            for _, o in pairs(args) do
                local a = type(o) == "table" and o.type == "header" and type(o.arg) == "table" and o.arg or nil
                local oo = a and tonumber(o.order)
                if a and a.xuiCollapse and oo and oo < no and (not ho or oo > ho) then hdr, ho = o, oo end
            end
            if hdr and type(hdr.arg.xuiCollapsed) == "function" and type(hdr.arg.xuiToggle) == "function" then
                local ok, shut = pcall(hdr.arg.xuiCollapsed)
                if ok and shut then pcall(hdr.arg.xuiToggle); opened = opened + 1 end
            end
        end
        args = node.args
    end
    return opened
end
-- scroll so the control is in view (a few px under the page's top); true when it is (or already was) inside the visible part
function RS.Reveal(e)
    local w, sc, exact = RS.FindControl(e)
    if not w then return false end
    RS.lastExact = exact
    if not (sc and sc.content and sc.scrollframe) then return true end   -- not in a scrolling page: it is on the page as drawn
    local ct, wt, wb = sc.content:GetTop(), w.frame:GetTop(), w.frame:GetBottom()
    local view, total = sc.scrollframe:GetHeight() or 0, sc.content:GetHeight() or 0
    if not (ct and wt and wb) then return false end
    if total <= view then return true end
    local off = math.max(0, math.min(total - view, (ct - wt) - 8))
    local value = off / (total - view) * 1000
    sc:SetScroll(value)
    if sc.scrollbar and sc.scrollbar.SetValue then pcall(sc.scrollbar.SetValue, sc.scrollbar, value) end
    return true
end
RS.RevealTries = 10   -- frames to wait for the redraw that draws the option's tab
local function RevealSoon(e)
    local n = 0
    local function try()
        n = n + 1
        if RS.Reveal(e) then RS.lastReveal = e; return end
        if n < RS.RevealTries and C_Timer and C_Timer.After then C_Timer.After(0, try) end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, try) else try() end
end

-- the search box and its results, added on top of a rule's settings (above its tabs). notify() redraws.
function ns.RuleSearchArgs(rule, ruleGroup, notify)
    local cache = { q = nil, at = nil }
    local function Results()
        local q = query[rule] or ""
        local now = GetTime and GetTime() or 0
        if cache.q ~= q or cache.at ~= now then cache.q, cache.at = q, now; cache.res, cache.err = RS.Find(ruleGroup, q) end
        return cache.res or {}, cache.err
    end
    local function empty() local q = query[rule]; return not (q and q:match("%S")) end
    local function listHidden() return empty() or folded[rule] == true end   -- (#483) the note and the result rows
    local args = {
        xuiSearch = { type = "input", order = 0.001, width = "full", name = "Search this rule's options",
            desc = "Finds options by name, help text, section or tab, words in any order. Text between slashes is a Lua pattern, e.g. /charge|stack/.",
            get = function() return query[rule] or "" end,
            set = function(_, v) v = tostring(v or ""):sub(1, 80); query[rule] = v:match("%S") and v or nil; folded[rule] = nil; notify() end },
        xuiSearchNote = { type = "description", order = 0.002, width = "full", fontSize = "small", hidden = listHidden,
            name = function()
                local res, err = Results()
                if err then return "|cffff6060" .. err .. "|r" end
                if #res == 0 then return "|cff999999No option of this rule matches.|r" end
                return "|cff999999" .. #res .. " option" .. (#res == 1 and "" or "s") .. " match" .. (#res == 1 and "es" or "") .. ((#res > MAX) and (", the best " .. MAX .. " below") or "") .. ". Click one to open its tab.|r"
            end },
        xuiSearchClear = { type = "execute", order = 0.0029, name = "Clear search", hidden = empty,
            func = function() query[rule] = nil; folded[rule] = nil; notify() end },
    }
    for i = 1, MAX do
        args["xuiSR" .. i] = { type = "execute", order = 0.003 + i / 10000, width = "full",
            hidden = function() if listHidden() then return true end; local res = Results(); return res[i] == nil end,
            name = function() local r = Results()[i]; return r and RS.Label(r.e) or "" end,
            desc = function() local r = Results()[i]; return r and (r.e.desc ~= "" and r.e.desc or r.e.name) or "" end,
            func = function()
                local r = Results()[i]
                if not r then return end
                folded[rule] = true   -- (#483) the results make room for the tab's page
                pcall(RS.OpenPath, ruleGroup, r.e.keys)
                if ns.SelectRuleTab then ns.SelectRuleTab(r.e.tab) else notify() end
                RevealSoon(r.e)
            end }
    end
    return args
end
