-------------------------------------------------------------------------------
-- ShoppingList.lua : Blizzard UI Reskin > Shopping List (XayaUI QoL). The profession / crafting shopping list: XayaUI's own panel of
-- your tracked recipes and their reagents, Blizzard's Professions section of the objective tracker restyled, and suggestions for the
-- enchants and gems missing on your gear. Off by default; while off nothing is created, registered or hooked (V14).
--
-- Xaya, 2026-11-05: "Shopping list reskin is the profession / crafting list function"; "It should also auto-suggest the user's
-- commonly used gear enchant if a given slot has an equipped item that can be enchanted. The same applies for gems for items that have
-- empty sockets"; form: "Both"; suggestions "In the shopping list"; "Show + add to list"; and (her note, verbatim) "Default to one,
-- user configurable default, also "select other" button to provide the list of other available options in case the user wants to
-- feelcraft a different choice spontaneously and needs help looking it up. Clicking the name of the gem or item in the pane should
-- autopopulate the auction house search if auction house pane is open." Rows S1-S10: docs/plans/SHOPPING-LIST-REQUIREMENTS-2026-11-05.md.
--
-- What the game gives (live 12.1.5 source and the API docs, read 2026-11-05):
--   tracked recipes   C_TradeSkillUI.GetRecipesTracked(isRecraft), .GetRecipeSchematic(recipeID, isRecraft) (namespaces.md:4898-4957);
--                     Blizzard's tracker (Blizzard_ObjectiveTracker/Blizzard_ProfessionsRecipeTracker.lua) lists each required slot's
--                     first reagent, counted over every quality with ProfessionsUtil.AccumulateReagentsInPossession; we do the same.
--   Auction House     AuctionHouseFrame.SearchBar:SetSearchText(text) and :StartSearch() (Blizzard_AuctionHouseSearchBar.lua:194-207);
--                     C_AuctionHouse.SendBrowseQuery with itemClassFilters (structures.md:331-349); AUCTION_HOUSE_BROWSE_RESULTS_UPDATED.
--   your gear         the Stat Calculator's model (CharacterModel.lua): CM.SlotInfo (link, enchanted, gems per socket, empty sockets),
--                     CM.SlotEnchant (the enchant's name from the tooltip), CM.EnchantSlots (the slots that take an enchant).
--   history           the game keeps none: XayaUI counts what it sees on your gear (this character only), from the first look.
-- NOT RUN IN GAME when written (QA E2a-E2d).
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns
local CM = ns.CharModel
local Shop = {}
ns.Shop = Shop
-- (the Dev Assist QA walkthroughs reach the Shopping List through this service: a feature is never called by name from another addon)
if ns.Provide then ns.Provide("shoppingList", { Cfg = function() return Shop.Cfg() end, Apply = function() return Shop.Apply() end,
    Recipes = function() return Shop.Recipes() end, Missing = function(c) return Shop.Missing(c) end }) end

local function num(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end
local function isSecret(v) return CM and CM.IsSecret and CM.IsSecret(v) end
local R = function(fn, ...) return CM.R(fn, ...) end
local N = function(fn, ...) return CM.N(fn, ...) end

-------------------------------------------------------------------------------
-- Settings
-------------------------------------------------------------------------------
local DEFAULTS = {
    enabled = false,     -- the whole feature (V14: off = nothing exists)
    panel = true,        -- XayaUI's own panel (S2)
    tracker = true,      -- Blizzard's Professions section restyled (S3)
    fontSize = 11,
    free = { x = 360, y = 120 },   -- the panel's centre, from the screen's centre
    defaults = {},       -- your own default per slot key ("ench:<slot>", "gem"): { name, itemID }   (S7)
    buy = {},            -- the "To buy" list: { { name, itemID, need, key } }   (S10)
    history = {},        -- per character: { ench = { [slot] = { [enchantID] = { n, last, name } } }, gems = { [gemID] = { n, last, name } },
                         --   lastEnch = { [slot] = enchantID or 0 }, lastGems = { [slot] = { [gemID] = count } } }   (S6)
}
ns.SHOPPING_DEFAULTS = DEFAULTS
local function Copy(v) if type(v) ~= "table" then return v end; local t = {}; for k, x in pairs(v) do t[k] = Copy(x) end; return t end
local function Cfg()
    if not CueRulesDB then return nil end
    local c = CueRulesDB.shoppingList
    if type(c) ~= "table" then c = {}; CueRulesDB.shoppingList = c end
    for k, v in pairs(DEFAULTS) do if c[k] == nil then c[k] = Copy(v) end end
    for _, k in ipairs({ "enabled", "panel", "tracker" }) do c[k] = c[k] == true end
    c.fontSize = math.max(8, math.min(16, tonumber(c.fontSize) or 11))
    for _, k in ipairs({ "free", "defaults", "buy", "history" }) do if type(c[k]) ~= "table" then c[k] = Copy(DEFAULTS[k]) end end
    for i = #c.buy, 1, -1 do
        local b = c.buy[i]
        if type(b) ~= "table" or type(b.name) ~= "string" or b.name == "" then table.remove(c.buy, i)
        else b.need = math.max(1, math.floor(tonumber(b.need) or 1)); if not num(b.itemID) then b.itemID = nil end end
    end
    return c
end
Shop.Cfg = Cfg
-- on = its own switch AND the Blizzard UI Reskin tab's switch (S1 #48: off there turns every reskin off, each keeps its own switch)
local function On(c) return c and c.enabled and ns.ReskinTabOn() and true or false end
Shop.On = On

-- this character's history (personal data: kept in your own saved settings only)
local function CharKey()
    local name = R(UnitName, "player")
    local realm = R(GetRealmName)
    if type(name) ~= "string" then return "?" end
    return name .. "-" .. ((type(realm) == "string" and realm) or "?")
end
function Shop.History(c)
    c = c or Cfg()
    local k = CharKey()
    local h = c.history[k]
    if type(h) ~= "table" then h = {}; c.history[k] = h end
    for _, f in ipairs({ "ench", "gems", "lastEnch", "lastGems" }) do if type(h[f]) ~= "table" then h[f] = {} end end
    return h
end

-------------------------------------------------------------------------------
-- What your gear wears: history (S6)
-------------------------------------------------------------------------------
-- the slot key suggestions and history share: both rings are one ("Finger 2" counts with "Finger 1")
local function SlotKey(slot) return (slot == 12) and 11 or slot end
Shop.SlotKey = SlotKey
-- the enchant on an item link: its second field (the item link format; CM.LinkEnchanted reads the same field)
function Shop.EnchantID(link)
    if type(link) ~= "string" or isSecret(link) then return nil end
    local f = tonumber(link:match("item:%-?%d+:(%d*)") or "")
    return (f and f > 0) and f or nil
end
local function Now() local t = (GetServerTime and R(GetServerTime)) or (time and time()); return num(t) and t or 0 end

-- Counts every enchant newly seen on a slot, and every gem newly seen in a slot's sockets, once each time it appears there.
function Shop.Observe(c)
    c = c or Cfg()
    if not (c and CM and CM.SLOTS) then return end
    local h = Shop.History(c)
    for _, s in ipairs(CM.SLOTS) do
        local slot = s[1]
        local info = CM.SlotInfo(slot)
        local key = SlotKey(slot)
        if info then
            local eid = Shop.EnchantID(info.link)
            local last = h.lastEnch[slot]
            if eid and last ~= eid then
                local per = h.ench[key] or {}
                local r = per[eid] or { n = 0 }
                r.n, r.last = r.n + 1, Now()
                local name = CM.SlotEnchant(slot)
                if type(name) == "string" and name ~= "" then r.name = name end
                per[eid] = r
                h.ench[key] = per
            end
            h.lastEnch[slot] = eid or 0
            local seen = {}
            for _, g in ipairs(info.gems or {}) do if num(g.gemID) then seen[g.gemID] = (seen[g.gemID] or 0) + 1 end end
            local before = h.lastGems[slot] or {}
            for id, cnt in pairs(seen) do
                local more = cnt - (before[id] or 0)
                if more > 0 then
                    local r = h.gems[id] or { n = 0 }
                    r.n, r.last = r.n + more, Now()
                    for _, g in ipairs(info.gems) do if g.gemID == id and g.name then r.name = g.name end end
                    h.gems[id] = r
                end
            end
            h.lastGems[slot] = seen
        end
    end
end

-------------------------------------------------------------------------------
-- Suggestions (S4-S7)
-------------------------------------------------------------------------------
local picks = {}   -- this session's "Select other" choice per slot key (S8: "a different choice spontaneously")
Shop.picks = picks
local function MostUsed(per)
    local best, bestID
    for id, r in pairs(per or {}) do
        if type(r) == "table" and num(r.n) and (not best or r.n > best.n or (r.n == best.n and (r.last or 0) > (best.last or 0))) then best, bestID = r, id end
    end
    return best, bestID
end
-- one suggestion: { name, itemID, src = "picked" | "default" | "used", count = how often used }
function Shop.EnchantSuggestion(c, slot)
    local key = "ench:" .. SlotKey(slot)
    if picks[key] then return picks[key] end
    local d = c.defaults[key]
    if type(d) == "table" and type(d.name) == "string" and d.name ~= "" then return { name = d.name, itemID = d.itemID, src = "default" } end
    local best, id = MostUsed(Shop.History(c).ench[SlotKey(slot)])
    if best and best.name then return { name = best.name, enchantID = id, src = "used", count = best.n } end
end
-- The one-per-character gem (C10, Xaya 2026-11-06: "1 as long as prismatic / diamond is always considered (only one is ever possible to
-- equip so its missing is always a default recommendation)"): a gem whose unique-equipped limit is 1, read from the game
-- (C_Item.GetItemUniquenessByID -> isUnique, limitCategoryName, limitCategoryCount; namespaces.md:2797). No names or IDs ship.
-- INFERENCE until seen in game: this expansion's Eversong Diamonds carry that limit (the client data shows them as a gem kind of their
-- own, subclass Other, epic). A gem the game has not sent yet reads as not one (asked again next time, not remembered).
local oneOf = {}
function Shop.CanReadUniqueness() return (C_Item and C_Item.GetItemUniquenessByID) and true or false end
function Shop.IsOneOfGem(itemID)
    if not num(itemID) then return false end
    if oneOf[itemID] ~= nil then return oneOf[itemID] end
    if not Shop.CanReadUniqueness() then return false end
    local ok, isUnique, _, count = pcall(C_Item.GetItemUniquenessByID, itemID)
    if not ok or isUnique == nil then return false end
    local v = (isUnique == true and num(count) and count == 1) and true or false
    oneOf[itemID] = v
    return v
end
local function GemsOf(per, wantOneOf)
    local t = {}
    for id, r in pairs(per or {}) do if Shop.IsOneOfGem(id) == wantOneOf then t[id] = r end end
    return t
end
-- the one-per-character gem: picked for now, else your default for it, else the one you used most (2026-11-06, her answer: "Give the
-- diamond a default too")
function Shop.DiamondSuggestion(c)
    if picks.diamond then return picks.diamond end
    local d = c.defaults.diamond
    if type(d) == "table" and type(d.name) == "string" and d.name ~= "" then return { name = d.name, itemID = d.itemID, src = "default" } end
    local best, id = MostUsed(GemsOf(Shop.History(c).gems, true))
    if best then
        local name = best.name or (C_Item and C_Item.GetItemNameByID and R(C_Item.GetItemNameByID, id))
        if type(name) == "string" then return { name = name, itemID = id, src = "used", count = best.n } end
    end
end
function Shop.GemSuggestion(c)
    if picks.gem then return picks.gem end
    local d = c.defaults.gem
    if type(d) == "table" and type(d.name) == "string" and d.name ~= "" then return { name = d.name, itemID = d.itemID, src = "default" } end
    local best, id = MostUsed(GemsOf(Shop.History(c).gems, false))
    if best then
        local name = best.name or (C_Item and C_Item.GetItemNameByID and R(C_Item.GetItemNameByID, id))
        if type(name) == "string" then return { name = name, itemID = id, src = "used", count = best.n } end
    end
end

-- What is missing on your gear: a slot that takes an enchant (the Character Toolkit's enchant slots) whose item has none; an item
-- with empty sockets.
-- The one-per-character gem (C10): when none is in your sockets, the first empty socket gets it and the rest get your gem.
function Shop.Missing(c)
    local out = {}
    local tk = ns.CharToolkit_Cfg and ns.CharToolkit_Cfg() or nil
    local wanted = CM.EnchantSlots(tk)
    local infos, oneOfWorn, firstEmpty = {}, false, nil
    for _, s in ipairs(CM.SLOTS) do
        local slot = s[1]
        local info = CM.SlotInfo(slot)
        infos[slot] = info
        if info then
            for _, g in ipairs(info.gems or {}) do if Shop.IsOneOfGem(g.gemID) then oneOfWorn = true end end
            if not firstEmpty and num(info.sockets) and info.sockets > 0 then firstEmpty = slot end
        end
    end
    local wantOneOf = Shop.CanReadUniqueness() and not oneOfWorn
    for _, s in ipairs(CM.SLOTS) do
        local slot = s[1]
        local info = infos[slot]
        if info then
            if wanted[slot] and info.enchanted == false then
                out[#out + 1] = { kind = "enchant", slot = slot, label = CM.SlotLabel(slot), sug = Shop.EnchantSuggestion(c, slot) }
            end
            if num(info.sockets) and info.sockets > 0 then
                local n = info.sockets
                if wantOneOf and slot == firstEmpty then
                    out[#out + 1] = { kind = "diamond", slot = slot, label = CM.SlotLabel(slot), count = 1, sug = Shop.DiamondSuggestion(c) }
                    n = n - 1
                end
                if n > 0 then out[#out + 1] = { kind = "gem", slot = slot, label = CM.SlotLabel(slot), count = n, sug = Shop.GemSuggestion(c) } end
            end
        end
    end
    return out
end

-------------------------------------------------------------------------------
-- Your bags
-------------------------------------------------------------------------------
local ITEM_CLASS_GEM, ITEM_CLASS_ENH = 3, 8   -- Enum.ItemClass.Gem / ItemEnhancement (enums.md:7506)
-- the Item Enhancement subclass each slot's enchant scrolls have (checked against the client item reference, build 12.1.5.70783;
-- only these numbers ship): helm 0, shoulders 2, chest 4, legs 8 (spellthreads / armor kits), boots 9, rings 10, weapons 11, ranged
-- scopes 12
Shop.ENH_SUBCLASS = { [1] = { 0 }, [3] = { 2 }, [5] = { 4 }, [7] = { 8 }, [8] = { 9 }, [11] = { 10 }, [12] = { 10 }, [16] = { 11, 12 }, [17] = { 11 } }
local function BagCount()
    local k = _G.Constants and Constants.InventoryConstants and Constants.InventoryConstants.NumBagSlots
    return num(k) and k or 4
end
-- every item in your bags: { itemID, link, name, count, classID, subclassID }
function Shop.BagItems()
    local out = {}
    if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo) then return out end
    for bag = 0, BagCount() do
        local n = N(C_Container.GetContainerNumSlots, bag)
        for i = 1, (num(n) and n or 0) do
            local info = R(C_Container.GetContainerItemInfo, bag, i)
            if type(info) == "table" and num(info.itemID) and not isSecret(info.itemID) then
                local _, _, _, _, _, classID, subclassID = R(C_Item.GetItemInfoInstant, info.itemID)
                local name = (type(info.itemName) == "string" and not isSecret(info.itemName)) and info.itemName or nil
                out[#out + 1] = { itemID = info.itemID, link = info.hyperlink, name = name, count = num(info.stackCount) and info.stackCount or 1,
                    classID = classID, subclassID = subclassID }
            end
        end
    end
    return out
end
-- how many you have: by item ID (C_Item.GetItemCount, namespaces.md:2760: your bags), else enchant scrolls whose name holds the name
-- (an enchant's tooltip name "Amani Mastery" is in its scroll's "Enchant Ring - Amani Mastery": INFERENCE, said in the hover)
function Shop.Have(itemID, name, bag)
    if num(itemID) then local n = N(C_Item.GetItemCount, itemID); return num(n) and n or 0 end
    if type(name) ~= "string" or name == "" then return 0 end
    local want, total = name:lower(), 0
    for _, it in ipairs(bag or Shop.BagItems()) do
        if it.classID == ITEM_CLASS_ENH and it.name and it.name:lower():find(want, 1, true) then total = total + it.count end
    end
    return total
end

-------------------------------------------------------------------------------
-- Tracked recipes (S2): as Blizzard's tracker lists them
-------------------------------------------------------------------------------
local function ReagentName(reagent)
    if num(reagent.itemID) then
        local nm = C_Item and C_Item.GetItemNameByID and R(C_Item.GetItemNameByID, reagent.itemID)
        if type(nm) == "string" then return nm end
        if C_Item and C_Item.RequestLoadItemDataByID then R(C_Item.RequestLoadItemDataByID, reagent.itemID) end   -- GET_ITEM_INFO_RECEIVED redraws
        return nil
    elseif num(reagent.currencyID) then
        local ci = C_CurrencyInfo and R(C_CurrencyInfo.GetCurrencyInfo, reagent.currencyID)
        if type(ci) == "table" and type(ci.name) == "string" then return ci.name end
    end
end
local function Possessed(slotSchematic)
    local PU = _G.ProfessionsUtil
    if PU and PU.AccumulateReagentsInPossession then
        local ok, q = pcall(PU.AccumulateReagentsInPossession, slotSchematic.reagents)
        if ok and num(q) then return q end
    end
    local total = 0
    for _, r in ipairs(slotSchematic.reagents or {}) do
        if num(r.itemID) then local n = N(C_Item.GetItemCount, r.itemID); if num(n) then total = total + n end
        elseif num(r.currencyID) then
            local ci = C_CurrencyInfo and R(C_CurrencyInfo.GetCurrencyInfo, r.currencyID)
            if type(ci) == "table" and num(ci.quantity) then total = total + ci.quantity end
        end
    end
    return total
end
local function Required(ss)
    local PU = _G.ProfessionsUtil
    if PU and PU.IsReagentSlotBasicRequired then local ok, v = pcall(PU.IsReagentSlotBasicRequired, ss); if ok then return v end end
    return ss.required == true and (ss.reagentType == nil or ss.reagentType == ((Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic) or 1))
end
function Shop.Recipes()
    local out = {}
    if not (C_TradeSkillUI and C_TradeSkillUI.GetRecipesTracked) then return out end
    for _, recraft in ipairs({ false, true }) do
        local ids = R(C_TradeSkillUI.GetRecipesTracked, recraft)
        for _, id in ipairs(type(ids) == "table" and ids or {}) do
            local sch = R(C_TradeSkillUI.GetRecipeSchematic, id, recraft)
            if type(sch) == "table" then
                local rec = { recipeID = id, recraft = recraft, name = (recraft and "Recraft: " or "") .. tostring(sch.name or ("Recipe " .. id)), lines = {} }
                for _, ss in ipairs(sch.reagentSlotSchematics or {}) do
                    if type(ss) == "table" and Required(ss) and ss.reagents and ss.reagents[1] then
                        local r = ss.reagents[1]
                        local name = ReagentName(r)
                        local need = num(ss.quantityRequired) and ss.quantityRequired or 1
                        local have = Possessed(ss)
                        rec.lines[#rec.lines + 1] = { name = name or "(loading)", itemID = r.itemID, currencyID = r.currencyID, need = need, have = have, done = have >= need }
                    end
                end
                out[#out + 1] = rec
            end
        end
    end
    return out
end

-- Stop tracking a recipe (C9, Xaya 2026-11-06: "Stay dimmed, allow user to "clear" manually — prompt user after all reagents are found
-- in bag if they want to stop tracking"). The game's own call: Blizzard's tracker lets it go too (namespaces.md:4957).
function Shop.Untrack(recipeID, recraft)
    if not (num(recipeID) and C_TradeSkillUI and C_TradeSkillUI.SetRecipeTracked) then return false end
    return pcall(C_TradeSkillUI.SetRecipeTracked, recipeID, false, recraft and true or false)
end
-- "Keep" on the question: not asked again for that recipe until it is short of a reagent again (this session)
local asked = {}
Shop.asked = asked

-------------------------------------------------------------------------------
-- The Auction House (S8, S9)
-------------------------------------------------------------------------------
function Shop.AHOpen() local f = _G.AuctionHouseFrame; return f and f.IsShown and f:IsShown() and true or false end
-- puts the text in the game's own search box and searches (its Buy tab); returns true when the Auction House took it
function Shop.SearchAH(text)
    if type(text) ~= "string" or text == "" or not Shop.AHOpen() then return false end
    local sb = AuctionHouseFrame.SearchBar
    if not (sb and sb.SetSearchText) then return false end
    local ok = pcall(sb.SetSearchText, sb, text)
    if ok and sb.IsShown and sb:IsShown() and sb.StartSearch then pcall(sb.StartSearch, sb) end
    return ok
end
-- "Select other" while the Auction House is open: what it lists for that slot (item class 8 + the slot's subclass; gems: class 3)
local browse = { key = nil, results = {} }
Shop.browse = browse
function Shop.Browse(key)
    if not (Shop.AHOpen() and C_AuctionHouse and C_AuctionHouse.SendBrowseQuery) then return false end
    local filters = {}
    if key == "gem" or key == "diamond" then filters[1] = { classID = ITEM_CLASS_GEM }
    else
        local slot = tonumber(key:match("^ench:(%d+)$"))
        for _, sub in ipairs(Shop.ENH_SUBCLASS[slot or 0] or {}) do filters[#filters + 1] = { classID = ITEM_CLASS_ENH, subClassID = sub } end
    end
    if #filters == 0 then return false end
    local order = (Enum and Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price) or 0
    browse.key, browse.results = key, {}
    return pcall(C_AuctionHouse.SendBrowseQuery, { searchString = "", sorts = { { sortOrder = order, reverseSort = false } }, itemClassFilters = filters })
end
function Shop.ReadBrowse()
    if not (C_AuctionHouse and C_AuctionHouse.GetBrowseResults) then return end
    local res = R(C_AuctionHouse.GetBrowseResults)
    local out = {}
    for _, r in ipairs(type(res) == "table" and res or {}) do
        local id = type(r.itemKey) == "table" and r.itemKey.itemID
        if num(id) then
            local nm = C_Item and C_Item.GetItemNameByID and R(C_Item.GetItemNameByID, id)
            out[#out + 1] = { itemID = id, name = type(nm) == "string" and nm or ("Item " .. id), price = r.minPrice }
        end
    end
    browse.results = out
end

-- the "Select other" list for a slot key: used before, in your bags, and the Auction House's list (when it is open)
function Shop.Options(c, key)
    local out, seen = {}, {}
    local function add(o) local k = o.itemID or o.name; if k and not seen[k] then seen[k] = true; out[#out + 1] = o end end
    local h = Shop.History(c)
    if key == "gem" or key == "diamond" then
        for id, r in pairs(GemsOf(h.gems, key == "diamond")) do
            local nm = r.name or (C_Item.GetItemNameByID and R(C_Item.GetItemNameByID, id))
            if type(nm) == "string" then add({ name = nm, itemID = id, src = ("used %dx"):format(r.n or 0) }) end
        end
    else
        local slot = tonumber(key:match("^ench:(%d+)$"))
        for _, r in pairs(h.ench[slot or 0] or {}) do if r.name then add({ name = r.name, src = ("used %dx"):format(r.n or 0) }) end end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    local subs = {}
    local gemKey = key == "gem" or key == "diamond"
    if not gemKey then for _, sub in ipairs(Shop.ENH_SUBCLASS[tonumber(key:match("^ench:(%d+)$")) or 0] or {}) do subs[sub] = true end end
    for _, it in ipairs(Shop.BagItems()) do
        local fits = (gemKey and it.classID == ITEM_CLASS_GEM and (key ~= "diamond" or Shop.IsOneOfGem(it.itemID)))
            or (not gemKey and it.classID == ITEM_CLASS_ENH and subs[it.subclassID])
        if fits and it.name then add({ name = it.name, itemID = it.itemID, link = it.link, src = ("in bags %d"):format(it.count) }) end
    end
    if browse.key == key then
        for _, r in ipairs(browse.results) do
            if key ~= "diamond" or Shop.IsOneOfGem(r.itemID) then add({ name = r.name, itemID = r.itemID, src = "Auction House" }) end
        end
    end
    return out
end

-------------------------------------------------------------------------------
-- The "To buy" list (S10)
-------------------------------------------------------------------------------
function Shop.AddToBuy(c, name, itemID, need, key)
    if type(name) ~= "string" or name == "" then return end
    for _, b in ipairs(c.buy) do
        if (itemID and b.itemID == itemID) or (not itemID and not b.itemID and b.name == name) then b.need = math.max(b.need, need or 1); return b end
    end
    local b = { name = name, itemID = itemID, need = math.max(1, need or 1), key = key }
    c.buy[#c.buy + 1] = b
    return b
end
function Shop.RemoveToBuy(c, i) if c.buy[i] then table.remove(c.buy, i) end end

-------------------------------------------------------------------------------
-- The model the panel draws: sections of rows
-------------------------------------------------------------------------------
-- row: { key, label, right, tone, search (the name a click puts in the Auction House), itemID, actions = { other = key, add = {...}, remove = i }, tip }
function Shop.Build(c)
    local secs = {}
    local bag = Shop.BagItems()
    -- Missing on your gear
    local miss = { key = "missing", title = "Missing on your gear", rows = {} }
    for _, m in ipairs(Shop.Missing(c)) do
        local key = (m.kind == "gem" or m.kind == "diamond") and m.kind or ("ench:" .. SlotKey(m.slot))
        local row = { key = "miss" .. m.kind .. m.slot, actions = { other = key } }
        if m.kind == "enchant" then
            row.label = m.label .. ": no enchant"
            if m.sug then
                local have = Shop.Have(m.sug.itemID, m.sug.name, bag)
                row.label, row.search, row.itemID = m.label .. ": " .. m.sug.name, m.sug.name, m.sug.itemID
                row.right, row.tone = ("%d / 1"):format(have), have >= 1 and "good" or "warn"
                row.actions.add = { name = m.sug.name, itemID = m.sug.itemID, need = 1, key = key }
                row.tip = { ("Suggested for your %s: %s (%s)."):format(m.label, m.sug.name,
                    m.sug.src == "default" and "your default" or (m.sug.src == "picked" and "picked for now" or ("you used it " .. (m.sug.count or 1) .. "x"))),
                    "Click the name: the Auction House searches for it when it is open. Have / need: the enchant scrolls in your bags whose name holds it." }
            else
                row.right, row.tone = "nothing used yet", "mute"
                row.tip = { ("Your %s has no enchant. XayaUI has not seen an enchant on this slot yet: use Select other, or set a default in the settings."):format(m.label) }
            end
        elseif m.kind == "diamond" then
            row.label = m.label .. ": one-per-character gem (none worn)"
            local why = "Only one of these gems can be worn at a time, and none is in your sockets, so one empty socket gets it."
            if m.sug then
                local have = Shop.Have(m.sug.itemID, m.sug.name, bag)
                row.label, row.search, row.itemID = ("%s: %s (one per character)"):format(m.label, m.sug.name), m.sug.name, m.sug.itemID
                row.right, row.tone = ("%d / 1"):format(have), have >= 1 and "good" or "warn"
                row.actions.add = { name = m.sug.name, itemID = m.sug.itemID, need = 1, key = key }
                row.tip = { why, ("Suggested: %s (%s)."):format(m.sug.name, m.sug.src == "default" and "your default" or (m.sug.src == "picked" and "picked for now" or ("you used it " .. (m.sug.count or 1) .. "x"))),
                    "Click the name: the Auction House searches for it when it is open." }
            else
                row.right, row.tone = "none seen yet", "warn"
                row.tip = { why, "XayaUI has not seen one in your sockets yet: use Select other (your bags, or the Auction House when it is open), or set a default for it in the settings." }
            end
        else
            local need = m.count
            row.label = ("%s: %d empty socket%s"):format(m.label, need, need == 1 and "" or "s")
            if m.sug then
                local have = Shop.Have(m.sug.itemID, m.sug.name, bag)
                row.label, row.search, row.itemID = ("%s: %s x%d"):format(m.label, m.sug.name, need), m.sug.name, m.sug.itemID
                row.right, row.tone = ("%d / %d"):format(have, need), have >= need and "good" or "warn"
                row.actions.add = { name = m.sug.name, itemID = m.sug.itemID, need = need, key = key }
                row.tip = { ("Suggested gem: %s (%s)."):format(m.sug.name, m.sug.src == "default" and "your default" or (m.sug.src == "picked" and "picked for now" or ("you used it " .. (m.sug.count or 1) .. "x"))),
                    "Click the name: the Auction House searches for it when it is open." }
            else
                row.right, row.tone = "nothing used yet", "mute"
                row.tip = { "XayaUI has not seen a gem in your sockets yet: use Select other, or set a default in the settings." }
            end
        end
        miss.rows[#miss.rows + 1] = row
    end
    if #miss.rows == 0 then miss.rows[1] = { key = "missNone", label = "Nothing missing: every enchant and socket is filled.", tone = "mute", note = true } end
    secs[#secs + 1] = miss
    -- To buy
    local buy = { key = "buy", title = "To buy", rows = {} }
    for i, b in ipairs(c.buy) do
        local have = Shop.Have(b.itemID, b.name, bag)
        buy.rows[#buy.rows + 1] = { key = "buy" .. i, label = b.name, search = b.name, itemID = b.itemID, right = ("%d / %d"):format(have, b.need),
            tone = have >= b.need and "good" or nil, done = have >= b.need, actions = { remove = i },
            tip = { "Click the name: the Auction House searches for it when it is open.", "x removes it from the list." } }
    end
    if #buy.rows == 0 then buy.rows[1] = { key = "buyNone", label = "Nothing yet: + Add on a suggestion puts it here.", tone = "mute", note = true } end
    secs[#secs + 1] = buy
    -- Tracked recipes
    for _, rec in ipairs(Shop.Recipes()) do
        local s = { key = "rec" .. rec.recipeID .. (rec.recraft and "r" or ""), title = rec.name, rows = {}, recipeID = rec.recipeID,
            clear = { recipeID = rec.recipeID, recraft = rec.recraft } }
        local complete = #rec.lines > 0
        for _, l in ipairs(rec.lines) do if not l.done then complete = false end end
        if not complete then asked[s.key] = nil
        elseif asked[s.key] ~= "keep" then
            s.rows[1] = { key = s.key .. ":ask", label = "All reagents are in your bags. Stop tracking it?", tone = "good", note = true,
                actions = { stop = { recipeID = rec.recipeID, recraft = rec.recraft }, keep = s.key } }
        end
        for j, l in ipairs(rec.lines) do
            s.rows[#s.rows + 1] = { key = s.key .. ":" .. j, label = l.name, search = l.itemID and l.name or nil, itemID = l.itemID,
                right = ("%d / %d"):format(l.have, l.need), tone = l.done and "good" or nil, done = l.done,
                tip = { "Click the name: the Auction House searches for it when it is open.", "Counted as Blizzard's own tracker counts it (every quality)." } }
        end
        secs[#secs + 1] = s
    end
    if #secs == 2 then secs[#secs + 1] = { key = "recNone", title = "Tracked recipes", rows = { { key = "recNoneRow", label = "Track a recipe in your profession window: it shows here with its reagents.", tone = "mute", note = true } } } end
    return secs
end

-------------------------------------------------------------------------------
-- The panel (S2)
-------------------------------------------------------------------------------
local panel, content, popup
local PAD, GUT = ns.UI_MARGIN or 10, ns.UI_GUTTER or 10
local PANEL_W = 340
local W = PANEL_W - 2 * PAD
local BTN_W = 46
ns.SHOPPING_LAYOUT = { width = PANEL_W, content = W, button = BTN_W }
local fsPool, btnPool, nFS, nBtn = {}, {}, 0, 0
local layout = {}
local function TC(class, prop, fb)
    local T = ns.Theme
    if T and T.Col then local ok, col = pcall(T.Col, class, prop, fb); if ok and type(col) == "table" then return col end end
    return fb
end
local TONES = { good = { 0.5, 1, 0.5, 1 }, warn = { 1, 0.56, 0.25, 1 } }
local function Tone(t, fb) if t == "mute" then return TC("xui-text-muted", "text", { 0.6, 0.6, 0.65, 1 }) end; return TONES[t] or fb end
local function FontPath() local T = ns.Theme; local p = T and T.FontPath and T.FontPath(); return p or "Fonts\\FRIZQT__.TTF" end

local function FS()
    nFS = nFS + 1
    local f = fsPool[nFS]
    if not f then f = content:CreateFontString(nil, "OVERLAY", "GameFontNormal"); fsPool[nFS] = f end
    f:Show()
    return f
end
local function Place(f, x, y, w, size, text, col, justify)
    if not f:SetFont(FontPath(), size, "") then f:SetFont("Fonts\\FRIZQT__.TTF", size, "") end
    f:ClearAllPoints(); f:SetPoint("TOPLEFT", content, "TOPLEFT", x, -y); f:SetWidth(w)
    f:SetJustifyH(justify or "LEFT")
    if f.SetWordWrap then f:SetWordWrap(false) end
    f:SetText(text or "")
    if col then f:SetTextColor(col[1], col[2], col[3], col[4] or 1) end
    layout[#layout + 1] = { kind = "text", x = x, y = y, w = w, h = size, text = text }
end
local function ShowItemTip(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    local r = self.row
    if r and num(r.itemID) and GameTooltip.SetItemByID then pcall(GameTooltip.SetItemByID, GameTooltip, r.itemID); GameTooltip:AddLine(" ") end
    if r and r.label and not num(r.itemID) then GameTooltip:AddLine(r.label, 1, 0.82, 0) end
    for _, l in ipairs(r and r.tip or {}) do GameTooltip:AddLine(l, 0.9, 0.9, 0.9, true) end
    if self.hint then GameTooltip:AddLine(self.hint, 0.9, 0.9, 0.9, true) end
    GameTooltip:Show()
end
local function Btn()
    nBtn = nBtn + 1
    local b = btnPool[nBtn]
    if not b then
        b = CreateFrame("Button", nil, content)
        if b.RegisterForClicks then b:RegisterForClicks("LeftButtonUp") end
        b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints(b)
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); b.text:SetPoint("CENTER")
        local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(b); hl:SetColorTexture(1, 1, 1, 0.08)
        b:SetScript("OnEnter", ShowItemTip)
        b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
        b:SetScript("OnClick", function(self) if self.onClick then self.onClick(self) end end)
        btnPool[nBtn] = b
    end
    b.row, b.hint, b.onClick = nil, nil, nil
    b.bg:Hide(); b.text:SetText("")
    b:Show()
    return b
end
local function SmallButton(x, y, w, h, label, hint, onClick, row)
    local b = Btn()
    b:ClearAllPoints(); b:SetPoint("TOPLEFT", content, "TOPLEFT", x, -y); b:SetSize(w, h)
    local bg = TC("xui-button", "bg", { 0.04, 0.04, 0.04, 0.7 })
    b.bg:SetColorTexture(bg[1], bg[2], bg[3], bg[4] or 1); b.bg:Show()
    b.text:SetText(label)
    local tc = TC("xui-button", "text", { 1, 0.82, 0, 1 }); b.text:SetTextColor(tc[1], tc[2], tc[3], 1)
    b.row, b.hint, b.onClick = row, hint, onClick
    layout[#layout + 1] = { kind = "button", x = x, y = y, w = w, h = h, text = label }
    return b
end

-- a name: click = the Auction House search when it is open, else the item's link (shift-click) / nothing
local function OnNameClick(self)
    local r = self.row
    if not r then return end
    if IsModifiedClick and IsModifiedClick("CHATLINK") and num(r.itemID) and C_Item and C_Item.GetItemInfo then
        local link = select(2, R(C_Item.GetItemInfo, r.itemID))
        if type(link) == "string" and type(HandleModifiedItemClick) == "function" then pcall(HandleModifiedItemClick, link) end
        return
    end
    if r.search then Shop.SearchAH(r.search) end
end

local OpenPopup
function Shop.Render()
    local c = Cfg()
    if not (c and panel) then return end
    nFS, nBtn, layout = 0, 0, {}
    local size = c.fontSize
    local cText = TC("xui-text", "text", { 0.96, 0.96, 0.98, 1 })
    local cLabel = TC("xui-label", "text", { 1, 0.82, 0, 1 })
    local cLine = TC("xui-window", "border", { 0.35, 0.35, 0.4, 1 })
    local bgc = TC("xui-window", "bg", { 0.04, 0.04, 0.06, 1 })
    panel.bg:SetColorTexture(bgc[1], bgc[2], bgc[3], 0.94)
    for _, e in ipairs(panel.edges) do e:SetColorTexture(cLine[1], cLine[2], cLine[3], cLine[4] or 1) end
    panel.title:SetTextColor(cLabel[1], cLabel[2], cLabel[3], 1)
    panel.ahNote:SetText(Shop.AHOpen() and "Auction House open: click a name to search" or "")
    local y = 0
    local rowH = size + 6
    for _, sec in ipairs(Shop.Build(c)) do
        if y > 0 then y = y + 6 end
        Place(FS(), 0, y, sec.clear and (W - 22) or W, size + 1, sec.title, cLabel)
        if sec.clear then
            local cl = sec.clear
            SmallButton(W - 18, y, 18, size + 2, "x", "Stop tracking this recipe (Blizzard's tracker lets it go too).", function() Shop.Untrack(cl.recipeID, cl.recraft); Shop.Render() end)
        end
        local rule = panel.rules[sec.key]
        if not rule then rule = content:CreateTexture(nil, "ARTWORK"); panel.rules[sec.key] = rule end
        rule:ClearAllPoints(); rule:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(y + size + 3)); rule:SetSize(W, 1)
        rule:SetColorTexture(cLine[1], cLine[2], cLine[3], 0.7); rule:Show(); rule.used = true
        y = y + size + 6
        for _, r in ipairs(sec.rows) do
            local right = W
            if r.actions and r.actions.stop then
                local st, key = r.actions.stop, r.actions.keep
                SmallButton(right - BTN_W, y, BTN_W, rowH - 2, "Keep", "Keep tracking it (not asked again until a reagent is short again).", function() asked[key] = "keep"; Shop.Render() end, r)
                right = right - BTN_W - 4
                SmallButton(right - BTN_W, y, BTN_W, rowH - 2, "Stop", "Stop tracking this recipe (Blizzard's tracker lets it go too).", function() Shop.Untrack(st.recipeID, st.recraft); asked[key] = nil; Shop.Render() end, r)
                right = right - BTN_W - 4
            end
            if r.actions and r.actions.remove then
                local i = r.actions.remove
                SmallButton(right - 18, y, 18, rowH - 2, "x", "Remove from the list", function() Shop.RemoveToBuy(c, i); Shop.Render() end, r)
                right = right - 18 - 4
            end
            if r.actions and r.actions.add then
                local a = r.actions.add
                SmallButton(right - BTN_W, y, BTN_W, rowH - 2, "+ Add", "Put it in the To buy list", function() Shop.AddToBuy(c, a.name, a.itemID, a.need, a.key); Shop.Render() end, r)
                right = right - BTN_W - 4
            end
            if r.actions and r.actions.other then
                local key = r.actions.other
                SmallButton(right - BTN_W, y, BTN_W, rowH - 2, "Other", "Select other: what you used before, what is in your bags and, while the Auction House is open, what it lists", function(self) OpenPopup(key, self) end, r)
                right = right - BTN_W - 4
            end
            local rw = r.right and 54 or 0
            if r.right then Place(FS(), right - rw, y + 2, rw, size - 1, r.right, Tone(r.tone, cText), "RIGHT"); right = right - rw - 4 end
            local col = r.note and Tone(r.tone or "mute", cText) or (r.done and Tone("mute") or cText)
            Place(FS(), 4, y + 2, math.max(20, right - 4), size, (r.done and "|TInterface\\RaidFrame\\ReadyCheck-Ready:0|t " or "") .. tostring(r.label), col)
            if not r.note then
                local nb = Btn()   -- the name's click area
                nb:ClearAllPoints(); nb:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y); nb:SetSize(math.max(20, right), rowH)
                nb.row, nb.onClick = r, OnNameClick
                layout[#layout + 1] = { kind = "hit", x = 0, y = y, w = math.max(20, right), h = rowH, text = r.key }
            end
            y = y + rowH
        end
    end
    for i = nFS + 1, #fsPool do fsPool[i]:Hide() end
    for i = nBtn + 1, #btnPool do btnPool[i]:Hide() end
    for _, rule in pairs(panel.rules) do if not rule.used then rule:Hide() end; rule.used = nil end
    content:SetHeight(math.max(10, y))
    panel:SetHeight(math.min(520, y + 2 * PAD + 30))
    panel.layout = layout
    if popup and popup:IsShown() and popup.key then OpenPopup(popup.key, popup.anchor) end
end

-- Select other (S8): the options for a slot key; a click picks one for now (and searches the Auction House when it is open); "Default"
-- makes it your default (S7)
function OpenPopup(key, anchor)
    local c = Cfg()
    if not (c and panel) then return end
    if not popup then
        popup = CreateFrame("Frame", "XayaUIShoppingListOther", panel)
        popup:SetFrameStrata("DIALOG")
        popup.bg = popup:CreateTexture(nil, "BACKGROUND"); popup.bg:SetAllPoints(popup)
        popup.title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal"); popup.title:SetPoint("TOPLEFT", 8, -8)
        popup.rows, popup.defs = {}, {}
        local close = CreateFrame("Button", nil, popup, "UIPanelCloseButton"); close:SetSize(24, 24); close:SetPoint("TOPRIGHT", 2, 2)
        close:SetScript("OnClick", function() popup:Hide() end)
        popup.ah = CreateFrame("Button", nil, popup)
        popup.ah.bg = popup.ah:CreateTexture(nil, "BACKGROUND"); popup.ah.bg:SetAllPoints(popup.ah)
        popup.ah.text = popup.ah:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); popup.ah.text:SetPoint("CENTER")
        popup.ah:SetScript("OnClick", function() if Shop.Browse(popup.key) then popup.ah.text:SetText("Asking the Auction House...") end end)
    end
    popup.key, popup.anchor = key, anchor
    popup:ClearAllPoints(); popup:SetPoint("TOPLEFT", panel, "TOPRIGHT", 4, 0)
    local bgc = TC("xui-window", "bg", { 0.04, 0.04, 0.06, 1 }); popup.bg:SetColorTexture(bgc[1], bgc[2], bgc[3], 0.97)
    local slot = tonumber(key:match("^ench:(%d+)$"))
    popup.title:SetText(slot and ("Other enchants: " .. CM.SlotLabel(slot)) or (key == "diamond" and "One-per-character gems" or "Other gems"))
    local opts = Shop.Options(c, key)
    local y = 32
    for i, o in ipairs(opts) do
        if i > 14 then break end
        local r = popup.rows[i]
        if not r then
            r = CreateFrame("Button", nil, popup)
            r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.text:SetPoint("LEFT", 6, 0); r.text:SetJustifyH("LEFT")
            r.src = r:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); r.src:SetPoint("RIGHT", -60, 0)
            local hl = r:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(r); hl:SetColorTexture(1, 1, 1, 0.08)
            r.def = CreateFrame("Button", nil, r)
            r.def:SetSize(52, 16); r.def:SetPoint("RIGHT", -4, 0)
            r.def.bg = r.def:CreateTexture(nil, "BACKGROUND"); r.def.bg:SetAllPoints(r.def)
            r.def.text = r.def:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); r.def.text:SetPoint("CENTER"); r.def.text:SetText("Default")
            popup.rows[i] = r
        end
        r:ClearAllPoints(); r:SetPoint("TOPLEFT", popup, "TOPLEFT", 4, -y); r:SetSize(292, 18)
        r.text:SetWidth(170); r.text:SetText(o.name); r.src:SetText(o.src or "")
        local bg = TC("xui-button", "bg", { 0.04, 0.04, 0.04, 0.7 }); r.def.bg:SetColorTexture(bg[1], bg[2], bg[3], bg[4] or 1)
        r:SetScript("OnClick", function()
            picks[key] = { name = o.name, itemID = o.itemID, src = "picked" }
            Shop.SearchAH(o.name)
            Shop.Render()
        end)
        r.def:SetScript("OnClick", function()
            c.defaults[key] = { name = o.name, itemID = o.itemID }
            picks[key] = nil
            Shop.Render()
        end)
        r:Show()
        y = y + 20
    end
    for i = #opts + 1, #popup.rows do popup.rows[i]:Hide() end
    if #opts == 0 then
        popup.rows.none = popup.rows.none or popup:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        popup.rows.none:SetPoint("TOPLEFT", popup, "TOPLEFT", 10, -y); popup.rows.none:SetWidth(280)
        popup.rows.none:SetText("Nothing used before or in your bags. Open the Auction House and ask it below.")
        popup.rows.none:Show(); y = y + 30
    elseif popup.rows.none then popup.rows.none:Hide() end
    popup.ah:ClearAllPoints(); popup.ah:SetPoint("TOPLEFT", popup, "TOPLEFT", 8, -(y + 4)); popup.ah:SetSize(284, 20)
    local bg = TC("xui-button", "bg", { 0.04, 0.04, 0.04, 0.7 }); popup.ah.bg:SetColorTexture(bg[1], bg[2], bg[3], bg[4] or 1)
    popup.ah.text:SetText(Shop.AHOpen() and "List what the Auction House has" or "Open the Auction House to list what it has")
    if popup.ah.SetEnabled then popup.ah:SetEnabled(Shop.AHOpen()) end
    popup:SetSize(300, y + 32)
    popup.optionCount = #opts
    popup:Show()
end
Shop.OpenPopup = function(key, anchor) OpenPopup(key, anchor) end

local function BuildPanel()
    if panel then return end
    local c = Cfg()
    panel = CreateFrame("Frame", "XayaUIShoppingList", UIParent)
    panel:SetSize(PANEL_W, 200)
    panel:SetFrameStrata("MEDIUM")
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true); panel:SetMovable(true); panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self) self:StartMoving() end)
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y = self:GetCenter(); local ux, uy = UIParent:GetCenter()
        if num(x) and num(ux) then local cc = Cfg(); cc.free.x, cc.free.y = math.floor(x - ux + 0.5), math.floor(y - uy + 0.5) end
    end)
    panel.bg = panel:CreateTexture(nil, "BACKGROUND"); panel.bg:SetAllPoints(panel)
    panel.edges = {}
    for i, pts in ipairs({ { "TOPLEFT", "TOPRIGHT", 0 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0 }, { "TOPLEFT", "BOTTOMLEFT", 1 }, { "TOPRIGHT", "BOTTOMRIGHT", 1 } }) do
        local e = panel:CreateTexture(nil, "BORDER"); e:SetPoint(pts[1]); e:SetPoint(pts[2])
        if pts[3] == 1 then e:SetWidth(1) else e:SetHeight(1) end
        panel.edges[i] = e
    end
    panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal"); panel.title:SetPoint("TOPLEFT", PAD, -PAD); panel.title:SetText("Shopping List")
    panel.ahNote = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); panel.ahNote:SetPoint("TOPRIGHT", -(PAD + 22), -(PAD + 2))
    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton"); close:SetSize(24, 24); close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() panel.userHidden = true; panel:Hide(); if popup then popup:Hide() end end)
    local scroll = CreateFrame("ScrollFrame", nil, panel)
    scroll:SetPoint("TOPLEFT", PAD, -(PAD + 24)); scroll:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    content = CreateFrame("Frame", nil, scroll); content:SetSize(W, 10); scroll:SetScrollChild(content)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, d)
        local maxS = math.max(0, (content:GetHeight() or 0) - (self:GetHeight() or 0))
        self:SetVerticalScroll(math.max(0, math.min(maxS, (self:GetVerticalScroll() or 0) - d * 40)))
    end)
    panel.rules = {}
    panel:ClearAllPoints(); panel:SetPoint("CENTER", UIParent, "CENTER", c.free.x or 0, c.free.y or 0)
    panel:Hide()
end

-------------------------------------------------------------------------------
-- Blizzard's Professions section restyled (S3): after each layout the tracker's own lines are recoloured in the theme. A post-hook
-- (hooksecurefunc) on the module's EndLayout; Blizzard's code runs unchanged. Off: nothing is recoloured, and Blizzard's next layout
-- puts its own colours back.
-- Built for the whole objective tracker (C8, Xaya 2026-11-06: "For now colors only but build with the awareness the whole tracking
-- container will be treated with restyling soon"): RestyleModule works on any section of Blizzard's objective tracker (each one is a
-- module with Header, EnumerateActiveBlocks, a block's ForEachUsedLine and EndLayout: Blizzard_ObjectiveTracker), and
-- Shop.TRACKER_MODULES says which sections are restyled and which switch each follows. Only the Professions section is in it now; the
-- objective pane reskin (RM-OBJECTIVES) adds the others there, with their own switch, without a second copy of this code.
-------------------------------------------------------------------------------
Shop.TRACKER_MODULES = {
    { global = "ProfessionsRecipeTracker", switch = "tracker" },   -- Blizzard_ProfessionsRecipeTracker.lua
}
local hookedModules = {}
local function ModuleOn(c, m) return On(c) and c[m.switch] == true end
local function RestyleModule(mod)
    if type(mod) ~= "table" then return end
    local label = TC("xui-label", "text", { 1, 0.82, 0, 1 })
    local text = TC("xui-text", "text", { 0.96, 0.96, 0.98, 1 })
    local muted = TC("xui-text-muted", "text", { 0.6, 0.6, 0.65, 1 })
    local hdr = mod.Header
    if type(hdr) == "table" then
        if hdr.Background and hdr.Background.SetAlpha then hdr.Background:SetAlpha(0) end
        if hdr.Text and hdr.Text.SetTextColor then hdr.Text:SetTextColor(label[1], label[2], label[3], 1) end
    end
    if mod.EnumerateActiveBlocks then
        pcall(mod.EnumerateActiveBlocks, mod, function(block)
            if block.HeaderText and block.HeaderText.SetTextColor then block.HeaderText:SetTextColor(text[1], text[2], text[3], 1) end
            if block.ForEachUsedLine then
                block:ForEachUsedLine(function(line)
                    local met = line.Icon and line.Icon.IsShown and line.Icon:IsShown()   -- the tick a finished line shows
                    local col = met and muted or text
                    if line.Text and line.Text.SetTextColor then line.Text:SetTextColor(col[1], col[2], col[3], 1) end
                end)
            end
        end)
    end
end
Shop.RestyleModule = RestyleModule
local function RestyleTracker()
    local c = Cfg()
    for _, m in ipairs(Shop.TRACKER_MODULES) do if ModuleOn(c, m) then RestyleModule(_G[m.global]) end end
end
Shop.RestyleTracker = RestyleTracker
local function HookTracker()
    if type(hooksecurefunc) ~= "function" then return end
    for _, m in ipairs(Shop.TRACKER_MODULES) do
        local mod = _G[m.global]
        if not hookedModules[m.global] and type(mod) == "table" and type(mod.EndLayout) == "function" then
            hooksecurefunc(mod, "EndLayout", function(self) if ModuleOn(Cfg(), m) then RestyleModule(self) end end)
            hookedModules[m.global] = true
        end
    end
end
function Shop.TrackerHooked() return hookedModules.ProfessionsRecipeTracker == true end

-------------------------------------------------------------------------------
-- On / off (V14: nothing exists while off)
-------------------------------------------------------------------------------
local ev
local pending = false
local function Refresh()
    if pending then return end
    pending = true
    C_Timer.After(0, function() pending = false; local c = Cfg(); if On(c) and panel and panel:IsShown() then Shop.Render() end end)
end
function Shop.Apply()
    local c = Cfg()
    if not c then return end
    if not On(c) then
        if ev then ev:UnregisterAllEvents() end
        if panel then panel:Hide() end
        if popup then popup:Hide() end
        return
    end
    Shop.Observe(c)
    if not ev then
        ev = CreateFrame("Frame")
        ev:SetScript("OnEvent", function(_, event, ...)
            local cc = Cfg()
            if not On(cc) then return end
            if event == "PLAYER_EQUIPMENT_CHANGED" or event == "PLAYER_ENTERING_WORLD" then Shop.Observe(cc) end
            if event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" then Shop.ReadBrowse() end
            if event == "AUCTION_HOUSE_CLOSED" then browse.key, browse.results = nil, {} end
            if event == "ADDON_LOADED" then HookTracker() end
            Refresh()
        end)
    end
    for _, e in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "PLAYER_ENTERING_WORLD", "BAG_UPDATE_DELAYED", "TRACKED_RECIPE_UPDATE",
        "GET_ITEM_INFO_RECEIVED", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", "ADDON_LOADED" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    if c.tracker then HookTracker(); RestyleTracker() end
    if c.panel then
        BuildPanel()
        if not panel.userHidden then panel:Show(); Shop.Render() end
    elseif panel then panel:Hide() end
end
function Shop.Toggle()
    local c = Cfg()
    if not c then return end
    if not c.enabled then c.enabled, c.panel = true, true end
    if not ns.ReskinTabOn() then ns.Print("Shopping List: Blizzard UI Reskin is off (Blizzard UI Reskin > Overview); it shows once that is on again."); return end
    if panel and panel:IsShown() then panel.userHidden = true; panel:Hide(); if popup then popup:Hide() end; return end
    if panel then panel.userHidden = nil end
    c.panel = true
    Shop.Apply()
end
ns.RegisterReskin("shoppinglist", function() Shop.Apply() end)   -- (the Reskin tab's switch: core ns.SetReskinTab walks these)
function Shop.Drawn() return { panel = panel, popup = popup, layout = panel and panel.layout, buttons = btnPool, fonts = fsPool } end
-- (read without Cfg: off, no saved table is made either, V14)
ns.WhenReady(function() local raw = CueRulesDB and CueRulesDB.shoppingList; if type(raw) == "table" and raw.enabled == true and ns.ReskinTabOn() then Shop.Apply() end end)

-------------------------------------------------------------------------------
-- Settings page: Blizzard UI Reskin > Shopping List
-------------------------------------------------------------------------------
local SLOT_KEYS = { 1, 3, 5, 7, 8, 11, 16, 17 }
function ns.BuildShoppingListPage(Notify)
    local function C() return Cfg() or DEFAULTS end
    local function Changed() Shop.Apply(); if panel and panel:IsShown() then Shop.Render() end; if Notify then Notify() end end
    local function off() return not C().enabled end
    local args = {
        intro = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "Your crafting shopping list: the recipes you track, with their reagents (have / need), and what is missing on your gear: an enchant on a slot that takes one, a gem for an empty socket, each with your usual choice. Click a name while the Auction House is open and it searches for it. Off by default." },
        panel = { type = "toggle", order = 2, width = "full", name = "XayaUI's Shopping List panel", disabled = off,
            desc = "A movable panel in the theme: Missing on your gear, To buy, and your tracked recipes. /xui shop shows or hides it.",
            get = function() return C().panel end, set = function(_, v) C().panel = v and true or false; Changed() end },
        tracker = { type = "toggle", order = 3, width = "full", name = "Restyle Blizzard's Professions list (objective tracker)", disabled = off,
            desc = "The tracked recipes in Blizzard's objective tracker in the theme's colors: header, recipe names, reagents (finished ones muted). The rest of the objective tracker is untouched for now.",
            get = function() return C().tracker end, set = function(_, v) C().tracker = v and true or false; Changed() end },
        fontSize = { type = "range", order = 4, name = "Text size", min = 8, max = 16, step = 1, disabled = off,
            get = function() return C().fontSize end, set = function(_, v) C().fontSize = v; Changed() end },
        defHdr = { type = "header", order = 10, name = "Your defaults",
            desc = "One suggestion per slot: the default you set here, else the enchant (gem) XayaUI has seen most on it. Type a name, or shift-click an item into the box. Empty = back to the most used." },
        histHdr = { type = "header", order = 30, name = "History" },
        forget = { type = "execute", order = 31, name = "Forget what this character used", disabled = off,
            desc = "Clears the counts of enchants and gems XayaUI has seen on this character's gear (your defaults stay).",
            func = function() local c = Cfg(); c.history[CharKey()] = nil; Changed() end },
        clearBuy = { type = "execute", order = 32, name = "Empty the To buy list", disabled = off,
            func = function() Cfg().buy = {}; Changed() end },
    }
    local function DefInput(key, order, name)
        return { type = "input", order = order, name = name, disabled = off, width = "double",
            get = function() local d = C().defaults[key]; return (type(d) == "table" and d.name) or "" end,
            set = function(_, v)
                v = tostring(v or ""):gsub("^%s+", ""):gsub("%s+$", "")
                if v == "" then C().defaults[key] = nil; Changed(); return end
                local id = tonumber(v:match("|Hitem:(%d+)") or "")
                local nm = v:match("%[(.-)%]") or v
                C().defaults[key] = { name = nm, itemID = id }
                Changed()
            end }
    end
    for i, slot in ipairs(SLOT_KEYS) do args["def" .. slot] = DefInput("ench:" .. slot, 10 + i, "Enchant: " .. (CM.SlotLabel(slot) == "Finger 1" and "Rings" or CM.SlotLabel(slot))) end
    args.defGem = DefInput("gem", 20, "Gem")
    args.defDiamond = DefInput("diamond", 21, "One-per-character gem (diamond)")
    -- its on / off is the tick box on this page's row in the left pane (xuiSwitch; QoL 0.7.32, S1 #48: "individual toggles for
    -- individual reskins"), greyed while the Blizzard UI Reskin tab's own switch is off
    local switch = { type = "toggle", name = "Shopping List", tip = "Lists what your tracked recipes and your gear still need.", desc = "Turns the shopping list on. While it is off nothing is created or read. Greyed while Blizzard UI Reskin is off (this tab's Overview).",
        disabled = function() return not ns.ReskinTabOn() end,
        get = function() return C().enabled end, set = function(_, v) C().enabled = v and true or false; Changed() end }
    local g = { type = "group", name = "Shopping List", order = 5, xuiSwitch = switch, args = args }
    return ns.SectionTabs and ns.SectionTabs(g) or g
end
ns.RegisterSettingsPage("reskin", "shoppinglist", ns.BuildShoppingListPage)
ns.RegisterCommand("shop", function(arg)
    arg = tostring(arg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if arg == "options" or arg == "settings" then ns.OpenSettingsPage("reskin", "shoppinglist"); return end
    if arg == "status" then
        local c = Cfg()
        if not c then return end
        ns.Print(("Shopping List: %s%s; panel %s; Blizzard's list restyled %s; %d to buy; tracker hooked %s."):format(c.enabled and "on" or "off",
            ns.ReskinTabOn() and "" or " (Blizzard UI Reskin is off: Blizzard UI Reskin > Overview, so it does not show)",
            c.panel and "on" or "off", c.tracker and "on" or "off", #c.buy, Shop.TrackerHooked() and "yes" or "no"))
        return
    end
    Shop.Toggle()
end, "/xui shop [options|status] (the crafting Shopping List)")
