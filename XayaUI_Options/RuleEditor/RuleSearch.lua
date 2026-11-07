-------------------------------------------------------------------------------
-- RuleSearch.lua : a search box at the top of every rule's settings (Xaya 2026-11-04: "allow search bar inside individual rules
-- ... to search through options (also allow regular expression / smart keyword searching)"). Own design and code.
--   * Smart keywords: every word typed must match a word of the option (its name, its help text, or the section and tab it is
--     in), in any order: the same word, the start of a word (3+ letters), or one letter off (5+ letters). Matches in the option's
--     own name rank first.
--   * Patterns: text between slashes, e.g. /charge|stack/ or /^show/, is a Lua pattern. Lua patterns are NOT full regular
--     expressions: they have . %a %d %s %w, sets [abc], repeats * + - ?, anchors ^ $, but no alternation; | between slashes is
--     added here to mean "or". An invalid pattern says so instead of matching nothing.
-- Results (up to 12) name the tab, the section and the option; clicking one opens that tab of the rule (Options.lua
-- ns.SelectRuleTab). The query is kept per rule for this session only.
-------------------------------------------------------------------------------
local ADDON, ns = ...
ns = _G.XayaUI_NS or ns

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
    local function walk(args, tabKey, tabName, path, depth)
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
                if o.type == "group" then
                    local sub = path
                    if nm:match("%S") then sub = path .. (path ~= "" and " > " or "") .. nm end
                    walk(o.args, tabKey, tabName, sub, depth + 1)
                elseif o.type ~= "description" and o.type ~= "header" and nm:match("%S") then
                    out[#out + 1] = { tab = tabKey, tabName = tabName, path = path, name = nm, desc = Strip(Val(o.desc, { k }) or "") }
                end
            end
        end
    end
    for _, k in ipairs(tabs) do
        local g = ruleGroup.args[k]
        local tn = Strip(Val(g.name, { k }) or k)
        walk(g.args, k, tn, "", 0)
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
    local args = {
        xuiSearch = { type = "input", order = 0.001, width = "full", name = "Search this rule's options",
            desc = "Finds options by name, help text, section or tab, words in any order. Text between slashes is a Lua pattern, e.g. /charge|stack/.",
            get = function() return query[rule] or "" end,
            set = function(_, v) v = tostring(v or ""):sub(1, 80); query[rule] = v:match("%S") and v or nil; notify() end },
        xuiSearchNote = { type = "description", order = 0.002, width = "full", fontSize = "small", hidden = empty,
            name = function()
                local res, err = Results()
                if err then return "|cffff6060" .. err .. "|r" end
                if #res == 0 then return "|cff999999No option of this rule matches.|r" end
                return "|cff999999" .. #res .. " option" .. (#res == 1 and "" or "s") .. " match" .. (#res == 1 and "es" or "") .. ((#res > MAX) and (", the best " .. MAX .. " below") or "") .. ". Click one to open its tab.|r"
            end },
        xuiSearchClear = { type = "execute", order = 0.0029, name = "Clear search", hidden = empty,
            func = function() query[rule] = nil; notify() end },
    }
    for i = 1, MAX do
        args["xuiSR" .. i] = { type = "execute", order = 0.003 + i / 10000, width = "full",
            hidden = function() if empty() then return true end; local res = Results(); return res[i] == nil end,
            name = function() local r = Results()[i]; return r and RS.Label(r.e) or "" end,
            desc = function() local r = Results()[i]; return r and (r.e.desc ~= "" and r.e.desc or r.e.name) or "" end,
            func = function()
                local r = Results()[i]
                if r and ns.SelectRuleTab then ns.SelectRuleTab(r.e.tab) end
            end }
    end
    return args
end
