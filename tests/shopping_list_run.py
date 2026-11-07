# Stub test for Blizzard UI Reskin > Shopping List (XayaUI_QoL, ShoppingList.lua). Xaya 2026-11-05: "Shopping list reskin is the
# profession / crafting list function"; "auto-suggest the user's commonly used gear enchant if a given slot has an equipped item that
# can be enchanted. The same applies for gems for items that have empty sockets"; form "Both"; "In the shopping list"; "Show + add to
# list"; "Default to one, user configurable default, also "select other" button ... Clicking the name of the gem or item in the pane
# should autopopulate the auction house search if auction house pane is open." Rows S1-S10: docs/plans/SHOPPING-LIST-REQUIREMENTS-2026-11-05.md.
# Checks: off costs nothing (V14); history (most used, per character); suggestions for a slot with no enchant and for empty sockets;
# your own default wins; Select other (used before, bags, the Auction House's list); + Add / To buy / remove; have / need; the tracked
# recipes as Blizzard's tracker counts them; a name click searches the Auction House only while it is open; Blizzard's Professions
# section restyled after its layout; the settings page; layout bounds; when the panel shows itself (UI-77).
# Run from the repo root: python3 tests/shopping_list_run.py   Needs: pip install lupa. Stand-in world: tests/char_toolkit_world.lua.
# Every item, recipe, enchant and number below is a TEST STAND-IN (made-up IDs 7001-9100; no game data).
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
def P(rel): return "'" + os.path.join(ROOT, rel).replace("\\", "/") + "'"
lua = LuaRuntime()
lua.execute(r'''
assert(loadfile(__WORLD__))()
-- items by ID: names, classes, counts in bags
NAMES = { [7001] = "Silver Ore", [7002] = "Silver Ore", [8001] = "Deadly Peridot", [9100] = "Enchant Ring - Amani Mastery", [9200] = "Quick Peridot" }
CLASS = { [7001] = { 7, 7 }, [7002] = { 7, 7 }, [8001] = { 3, 10 }, [9100] = { 8, 10 }, [9200] = { 3, 7 } }
COUNT = { [7001] = 3, [7002] = 1, [8001] = 0, [9100] = 2, [9200] = 1 }
BAGS = { { itemID = 7001, stackCount = 3 }, { itemID = 7002, stackCount = 1 }, { itemID = 9100, stackCount = 2 }, { itemID = 9200, stackCount = 1 } }
local baseInstant = C_Item.GetItemInfoInstant
C_Item.GetItemInfoInstant = function(x) if type(x) == "number" and CLASS[x] then return x, "", "", "", 0, CLASS[x][1], CLASS[x][2] end; return baseInstant(x) end
C_Item.GetItemNameByID = function(id) return NAMES[id] end
C_Item.GetItemCount = function(id) return COUNT[id] or 0 end
C_Container = { GetContainerNumSlots = function(bag) return bag == 0 and #BAGS or 0 end,
  GetContainerItemInfo = function(bag, i) local b = BAGS[i]; if bag == 0 and b then return { itemID = b.itemID, stackCount = b.stackCount, itemName = NAMES[b.itemID],
    hyperlink = "|cffffffff|Hitem:" .. b.itemID .. "::::::::90:::::|h[" .. NAMES[b.itemID] .. "]|h|r" } end end }
-- gear: the helm (no enchant, 1 empty socket), the ring (enchant 7000 "Amani Mastery", gem 8001 in its socket)
SOCKETS = { Helm = { 0 }, Ring = { 8001 } }
C_Item.GetItemNumSockets = function(link) local nm = link:match("%[(.-)%]"); return SOCKETS[nm] and #SOCKETS[nm] or 0 end
C_Item.GetItemGemID = function(link, i) local nm = link:match("%[(.-)%]"); local g = SOCKETS[nm] and SOCKETS[nm][i]; if g and g > 0 then return g end end
C_Item.GetItemGem = function(link, i) local id = C_Item.GetItemGemID(link, i); if id then return NAMES[id], "|Hitem:" .. id .. "|h[" .. NAMES[id] .. "]|h" end end
TIP = { [11] = { { type = 15, leftText = "Enchanted: Amani Mastery" } } }
C_TooltipInfo.GetInventoryItem = function(_, slot) return { lines = TIP[slot] or {} } end
ENCHANTED_TOOLTIP_LINE = "Enchanted: %s"
UnitName = function() return "Xaya" end
GetRealmName = function() return "Stormrage" end
-- tracked recipes: one, with a required item slot over two qualities, a required currency, and an optional slot
CURR = { [99] = { name = "Artisan's Acuity", quantity = 2 } }
C_CurrencyInfo = { GetCurrencyInfo = function(id) return CURR[id] end }
TRACKED = { [false] = { 501 }, [true] = {} }
C_TradeSkillUI = {
  GetRecipesTracked = function(recraft) return TRACKED[recraft] end,
  GetRecipeSchematic = function(id, recraft) return { name = "Glimmering Ring", reagentSlotSchematics = {
    { required = true, reagentType = 1, quantityRequired = 5, reagents = { { itemID = 7001 }, { itemID = 7002 } } },
    { required = true, reagentType = 1, quantityRequired = 2, reagents = { { currencyID = 99 } } },
    { required = false, reagentType = 2, quantityRequired = 1, reagents = { { itemID = 8001 } } } } } end }
-- the Auction House (closed to start)
searched, started, browsed = {}, 0, nil
AuctionHouseFrame = mk("Frame")
AuctionHouseFrame.SearchBar = mk("Frame"); AuctionHouseFrame.SearchBar.shown = true
AuctionHouseFrame.SearchBar.SetSearchText = function(self, t) searched[#searched + 1] = t end
AuctionHouseFrame.SearchBar.StartSearch = function(self) started = started + 1 end
C_AuctionHouse = { SendBrowseQuery = function(q) browsed = q end,
  GetBrowseResults = function() return { { itemKey = { itemID = 9100 }, minPrice = 10000 }, { itemKey = { itemID = 9300 }, minPrice = 20000 } } end }
NAMES[9300] = "Enchant Ring - Eyes of the Eagle"
-- Blizzard's Professions section of the objective tracker (names from Blizzard_ProfessionsRecipeTracker.xml / ObjectiveTracker templates)
local function fs() local f = mk("FS"); f.SetTextColor = function(self, r, g, b, a) self.color = { r, g, b, a } end; return f end
local line1 = { Text = fs(), Icon = mk("Texture") }; line1.Icon.shown = true
local line2 = { Text = fs(), Icon = mk("Texture") }; line2.Icon.shown = false
local block = { HeaderText = fs(), ForEachUsedLine = function(self, fn) fn(line1); fn(line2) end }
ProfessionsRecipeTracker = { Header = { Background = mk("Texture"), Text = fs() }, layouts = 0 }
ProfessionsRecipeTracker.Header.Background.SetAlpha = function(self, a) self.alpha = a end
ProfessionsRecipeTracker.EndLayout = function(self) self.layouts = self.layouts + 1 end
ProfessionsRecipeTracker.EnumerateActiveBlocks = function(self, cb) cb(block) end

assert(loadfile(__MOD__))("XayaUI", ns)
assert(loadfile(__COMPAT__))("XayaUI", ns)
assert(loadfile(__SM__))("XayaUI_QoL", ns)
assert(loadfile(__CM__))("XayaUI_QoL", ns)
assert(loadfile(__CT__))("XayaUI_QoL", ns)
local framesBefore = #created
assert(loadfile(__SL__))("XayaUI_QoL", ns)
ns.FireReady()
local Shop = ns.Shop
local c = Shop.Cfg()

-- 1. Off costs nothing (V14) ----------------------------------------------------------------------------------------------------
check("off by default", c.enabled == false)
check("  ...nothing created, registered or hooked while off", #created == framesBefore and XayaUIShoppingList == nil and not Shop.TrackerHooked(), #created - framesBefore)

-- 2. History and suggestions (S4-S7) -------------------------------------------------------------------------------------------
c.enabled = true
Shop.Apply()
local h = Shop.History(c)
check("history: the ring's enchant counted once on the ring slot, by its tooltip name", h.ench[11] and h.ench[11][7000] and h.ench[11][7000].n == 1 and h.ench[11][7000].name == "Amani Mastery")
check("  ...the ring's gem counted once", h.gems[8001] and h.gems[8001].n == 1, h.gems[8001] and h.gems[8001].n)
check("  ...kept for this character only (Xaya-Stormrage)", c.history["Xaya-Stormrage"] ~= nil)
Shop.Observe(c)
check("  ...seeing the same gear again does not count it again", h.ench[11][7000].n == 1 and h.gems[8001].n == 1)
local miss = Shop.Missing(c)
local function find(kind, slot) for _, m in ipairs(miss) do if m.kind == kind and m.slot == slot then return m end end end
check("missing: the helm takes an enchant and has none", find("enchant", 1) ~= nil)
check("  ...the enchanted ring is not missing anything", find("enchant", 11) == nil)
check("  ...the helm's empty socket, with the gem you used (Deadly Peridot, used 1x)", find("gem", 1) and find("gem", 1).count == 1 and find("gem", 1).sug
  and find("gem", 1).sug.name == "Deadly Peridot" and find("gem", 1).sug.src == "used")
check("  ...no enchant ever seen on the helm: no suggestion yet", find("enchant", 1).sug == nil)
check("a ring enchant suggests your most used one (both rings share it)", Shop.EnchantSuggestion(c, 12) and Shop.EnchantSuggestion(c, 12).name == "Amani Mastery")
h.ench[11][7100] = { n = 3, last = 1, name = "Eyes of the Eagle" }
check("  ...the most used wins", Shop.EnchantSuggestion(c, 11).name == "Eyes of the Eagle")
h.ench[11][7100].n = 1; h.ench[11][7100].last = 999999999
check("  ...a tie goes to the most recent", Shop.EnchantSuggestion(c, 11).name == "Eyes of the Eagle")
h.ench[11][7100] = nil
c.defaults["ench:1"] = { name = "Hex of Leeching" }
check("your own default for a slot wins (S7)", Shop.EnchantSuggestion(c, 1) and Shop.EnchantSuggestion(c, 1).name == "Hex of Leeching" and Shop.EnchantSuggestion(c, 1).src == "default")

-- 3. Have / need ---------------------------------------------------------------------------------------------------------------
check("have, by item ID (gems): Deadly Peridot 0", Shop.Have(8001) == 0)
check("have, by the enchant's name (scrolls in your bags): Amani Mastery 2", Shop.Have(nil, "Amani Mastery") == 2)

-- 4. Tracked recipes, as Blizzard's tracker counts them ------------------------------------------------------------------------
local recs = Shop.Recipes()
check("tracked recipes: Glimmering Ring with its two required reagents (the optional slot left out)", #recs == 1 and recs[1].name == "Glimmering Ring" and #recs[1].lines == 2)
check("  ...Silver Ore over both qualities 3 + 1 = 4 / 5, not done", recs[1].lines[1].have == 4 and recs[1].lines[1].need == 5 and recs[1].lines[1].done == false)
check("  ...the currency 2 / 2, done", recs[1].lines[2].name == "Artisan's Acuity" and recs[1].lines[2].done == true)
ProfessionsUtil = { AccumulateReagentsInPossession = function(r) return 9 end }
check("  ...counted with Blizzard's own ProfessionsUtil when it is there (9)", Shop.Recipes()[1].lines[1].have == 9)
ProfessionsUtil = nil

-- 5. The panel ---------------------------------------------------------------------------------------------------------------
Shop.Render()   -- (the settings page redraws on every change; the default above was set directly)
local d = Shop.Drawn()
check("the panel is shown with its title", d.panel and d.panel.shown and d.panel.title.text == "Shopping List")
local function texts() local t = {}; for _, r in ipairs(d.panel.layout) do if r.kind == "text" then t[#t + 1] = tostring(r.text) end end; return table.concat(t, " | ") end
local all = texts()
check("  ...sections: Missing on your gear, To buy, Glimmering Ring", all:find("Missing on your gear", 1, true) and all:find("To buy", 1, true) and all:find("Glimmering Ring", 1, true), all)
check("  ...the helm: your default enchant, and the gem for its socket with have / need", all:find("Head: Hex of Leeching", 1, true) and all:find("Head: Deadly Peridot x1", 1, true) and all:find("0 / 1", 1, true), all)
check("  ...the recipe's reagents with have / need", all:find("Silver Ore", 1, true) and all:find("4 / 5", 1, true) and all:find("2 / 2", 1, true), all)
local function button(label, rowKey)
  for _, b in ipairs(d.buttons) do if b.shown and b.text and b.text.text == label and (not rowKey or (b.row and b.row.key == rowKey)) then return b end end
end
local addGem = button("+ Add", "missgem1")
check("+ Add on the gem suggestion", addGem ~= nil)
if addGem then addGem.scripts.OnClick(addGem) end
check("  ...puts it in To buy (need 1)", #c.buy == 1 and c.buy[1].name == "Deadly Peridot" and c.buy[1].itemID == 8001 and c.buy[1].need == 1)
if addGem then button("+ Add", "missgem1").scripts.OnClick(button("+ Add", "missgem1")) end
check("  ...adding it again does not duplicate it", #c.buy == 1)
d = Shop.Drawn(); all = texts()
check("  ...and it shows under To buy with have / need", all:find("Deadly Peridot", 1, true) ~= nil)
local rm = button("x")
if rm then rm.scripts.OnClick(rm) end
check("x removes it", #c.buy == 0)

-- 6. The Auction House (S9): a name click searches only while it is open --------------------------------------------------------
d = Shop.Drawn()
local function nameHit(key) for _, b in ipairs(d.buttons) do if b.shown and b.row and b.row.key == key and b.text.text == "" then return b end end end
local hit = nameHit("missgem1")
if hit then hit.scripts.OnClick(hit) end
check("Auction House closed: a name click searches nothing", #searched == 0)
AuctionHouseFrame.shown = true
if hit then hit.scripts.OnClick(hit) end
check("Auction House open: the name goes in its search box and it searches (Deadly Peridot)", searched[1] == "Deadly Peridot" and started == 1, tostring(searched[1]))
AuctionHouseFrame.SearchBar.shown = false
Shop.SearchAH("Silver Ore")
check("  ...on its Sell tab (search bar hidden): the text is put in, no search started", searched[2] == "Silver Ore" and started == 1)
AuctionHouseFrame.SearchBar.shown = true

-- 7. Select other (S8) and making a default (S7) -------------------------------------------------------------------------------
local opts = Shop.Options(c, "ench:11")
local function has(list, name, src) for _, o in ipairs(list) do if o.name == name and (not src or (o.src or ""):find(src, 1, true)) then return o end end end
check("Select other for the rings: the one you used before and the ring scroll in your bags", has(opts, "Amani Mastery", "used 1x") and has(opts, "Enchant Ring - Amani Mastery", "in bags 2"))
check("  ...not the gem in your bags", has(opts, "Quick Peridot") == nil)
check("Select other for gems: the one you used and the gem in your bags", has(Shop.Options(c, "gem"), "Deadly Peridot", "used") and has(Shop.Options(c, "gem"), "Quick Peridot", "in bags 1"))
check("asking the Auction House for ring enchants: a browse of item class 8, subclass 10", Shop.Browse("ench:11") and browsed and browsed.itemClassFilters[1].classID == 8
  and browsed.itemClassFilters[1].subClassID == 10 and browsed.searchString == "")
Shop.ReadBrowse()
check("  ...its results join the list (Eyes of the Eagle, Auction House)", has(Shop.Options(c, "ench:11"), "Enchant Ring - Eyes of the Eagle", "Auction House"))
Shop.OpenPopup("gem", nil)
d = Shop.Drawn()
check("the Select other list opens beside the panel with the options", d.popup and d.popup.shown and d.popup.optionCount >= 2)
local row1 = d.popup.rows[1]
local chosen = row1 and row1.text.text
if row1 then row1.scripts.OnClick(row1) end
check("  ...a click picks it for now (and searches the Auction House)", Shop.GemSuggestion(c).name == chosen and Shop.GemSuggestion(c).src == "picked" and searched[#searched] == chosen, chosen)
if row1 then row1.def.scripts.OnClick(row1.def) end
check("  ...'Default' makes it your default", c.defaults.gem and c.defaults.gem.name == chosen and Shop.GemSuggestion(c).src == "default")
AuctionHouseFrame.shown = false

-- 8. Blizzard's Professions section restyled (S3) -------------------------------------------------------------------------------
check("the tracker's layout is post-hooked", Shop.TrackerHooked())
ProfessionsRecipeTracker:EndLayout()
check("after Blizzard's layout: its header art faded, header and recipe in the theme, a finished reagent muted",
  ProfessionsRecipeTracker.Header.Background.alpha == 0 and ProfessionsRecipeTracker.Header.Text.color and block.HeaderText.color
  and line1.Text.color[1] < 0.7 and line2.Text.color[1] > 0.9 and ProfessionsRecipeTracker.layouts >= 1)

-- C8 (Xaya 2026-11-06: "For now colors only but build with the awareness the whole tracking container will be treated with restyling
-- soon"): one restyler for any section of the objective tracker; only the Professions section is listed for now
check("C8: the restyled sections are a list, with only Blizzard's Professions section in it for now", #Shop.TRACKER_MODULES == 1
  and Shop.TRACKER_MODULES[1].global == "ProfessionsRecipeTracker" and Shop.TRACKER_MODULES[1].switch == "tracker")
local qline = { Text = fs(), Icon = mk("Texture") }; qline.Icon.shown = false
local qblock = { HeaderText = fs(), ForEachUsedLine = function(self, fn) fn(qline) end }
local quests = { Header = { Background = mk("Texture"), Text = fs() }, EnumerateActiveBlocks = function(self, fn) fn(qblock) end }
quests.Header.Background.SetAlpha = function(self, a) self.alpha = a end
Shop.RestyleModule(quests)
check("  ...the same restyler takes another section of the tracker (a quest section built like Blizzard's) without new code",
  quests.Header.Background.alpha == 0 and quests.Header.Text.color and qblock.HeaderText.color and qline.Text.color and qline.Text.color[1] > 0.9,
  ("alpha %s, header %s, block %s, line %s"):format(tostring(quests.Header.Background.alpha), tostring(quests.Header.Text.color ~= nil), tostring(qblock.HeaderText.color ~= nil), tostring(qline.Text.color and qline.Text.color[1])))

-- 9. Layout bounds (V11) -------------------------------------------------------------------------------------------------------
Shop.Render(); d = Shop.Drawn()
local W = ns.SHOPPING_LAYOUT.content
local ok, why = true, nil
for _, r in ipairs(d.panel.layout) do if r.x < 0 or r.x + r.w > W + 0.01 or r.w <= 0 then ok, why = false, r.kind .. " " .. tostring(r.text) end end
local t = {}
for _, r in ipairs(d.panel.layout) do if r.kind ~= "hit" then t[#t + 1] = r end end
for i = 1, #t do for j = i + 1, #t do local a, b = t[i], t[j]
  if a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h then ok, why = false, tostring(a.text) .. " / " .. tostring(b.text) end end end
check("layout: inside the width, no two texts or buttons overlap", ok, why)

-- 9b. Her answers of 2026-11-06 ------------------------------------------------------------------------------------------------
-- C9: "Stay dimmed, allow user to "clear" manually — prompt user after all reagents are found in bag if they want to stop tracking"
untracked = nil
C_TradeSkillUI.SetRecipeTracked = function(id, tracked, recraft) untracked = { id, tracked, recraft }; if not tracked then TRACKED[recraft and true or false] = {} end end
local function recSec() for _, sec in ipairs(Shop.Build(c)) do if sec.recipeID == 501 then return sec end end end
check("C9: a reagent short: no question", recSec() and recSec().rows[1].key ~= "rec501:ask")
check("  ...the recipe's header has its own x (stop tracking it)", recSec() and recSec().clear and recSec().clear.recipeID == 501)
COUNT[7002] = 2   -- 3 + 2 = 5 / 5: every required reagent is in the bags
check("  ...every reagent in the bags: 'All reagents are in your bags. Stop tracking it?' at the top of the recipe", recSec() and recSec().rows[1].key == "rec501:ask"
  and recSec().rows[1].label:find("Stop tracking it?", 1, true) ~= nil)
Shop.Render(); d = Shop.Drawn()
local keep = button("Keep", "rec501:ask")
check("  ...with Stop and Keep buttons", button("Stop", "rec501:ask") ~= nil and keep ~= nil)
if keep then keep.scripts.OnClick(keep) end
check("  ...Keep: not asked again", recSec() and recSec().rows[1].key ~= "rec501:ask")
COUNT[7002] = 1; Shop.Build(c); COUNT[7002] = 2
check("  ...short again, then complete again: asked again", recSec() and recSec().rows[1].key == "rec501:ask")
Shop.Render(); d = Shop.Drawn()
local stop = button("Stop", "rec501:ask")
if stop then stop.scripts.OnClick(stop) end
check("  ...Stop: the game's own call lets the recipe go (Blizzard's tracker too)", untracked and untracked[1] == 501 and untracked[2] == false and untracked[3] == false)
check("  ...and it leaves the panel", recSec() == nil)
TRACKED[false] = { 501 }; COUNT[7002] = 1; untracked = nil
Shop.Render(); d = Shop.Drawn()
local hx; for _, b in ipairs(d.buttons) do if b.shown and b.text and b.text.text == "x" and b.hint and b.hint:find("Stop tracking", 1, true) then hx = b end end
check("  ...the header's x stops tracking it by hand", hx ~= nil and (function() hx.scripts.OnClick(hx); return untracked and untracked[1] == 501 and untracked[2] == false end)())
TRACKED[false] = { 501 }

-- C10: "1 as long as prismatic / diamond is always considered (only one is ever possible to equip so its missing is always a default
-- recommendation)". The game says which gem is one-per-character (unique-equipped, limit 1).
NAMES[8100] = "Powerful Eversong Diamond"; CLASS[8100] = { 3, 9 }; COUNT[8100] = 0
C_Item.GetItemUniquenessByID = function(id) if id == 8100 then return true, "Eversong Diamond", 1, 5 end; return false end
local miss2 = Shop.Missing(c)
local function find2(kind, slot) for _, m in ipairs(miss2) do if m.kind == kind and m.slot == slot then return m end end end
check("C10: none worn: the helm's one empty socket gets the one-per-character gem", find2("diamond", 1) ~= nil and find2("diamond", 1).count == 1)
check("  ...so that socket is not also asked for your other gem", find2("gem", 1) == nil)
check("  ...none seen yet: no suggestion (Select other)", find2("diamond", 1).sug == nil)
h.gems[8100] = { n = 2, last = 5, name = "Powerful Eversong Diamond" }
check("  ...seen on your gear before: it is suggested", Shop.DiamondSuggestion(c) and Shop.DiamondSuggestion(c).name == "Powerful Eversong Diamond")
check("  ...and never as your normal gem", Shop.GemSuggestion(c) and Shop.GemSuggestion(c).name ~= "Powerful Eversong Diamond")
c.defaults.diamond = { name = "Stoic Eversong Diamond", itemID = 8101 }
check("  ...your own default for it wins (her answer: \"Give the diamond a default too\")", Shop.DiamondSuggestion(c) and Shop.DiamondSuggestion(c).name == "Stoic Eversong Diamond"
  and Shop.DiamondSuggestion(c).src == "default")
c.defaults.diamond = nil
check("  ...Select other for it lists only one-per-character gems", has(Shop.Options(c, "diamond"), "Powerful Eversong Diamond") and has(Shop.Options(c, "diamond"), "Deadly Peridot") == nil)
Shop.Render(); d = Shop.Drawn()
check("  ...the panel: 'Head: Powerful Eversong Diamond (one per character)' with 0 / 1", texts():find("Head: Powerful Eversong Diamond (one per character)", 1, true) ~= nil, texts())
Shop.OpenPopup("diamond", nil)
local dpop = rawget(_G, "XayaUIShoppingListOther")
local drow
for _, r in ipairs(dpop and dpop.rows or {}) do if r.shown and r.def and r.text and r.text.text == "Powerful Eversong Diamond" then drow = r end end
if drow and drow.def.scripts.OnClick then drow.def.scripts.OnClick(drow.def) end
check("  ...its Select other has a Default button that makes it your default", c.defaults.diamond and c.defaults.diamond.name == "Powerful Eversong Diamond"
  and Shop.DiamondSuggestion(c).src == "default")
c.defaults.diamond = nil
check("  ...and the settings page a box for it", (function() local pg = ns.BuildShoppingListPage(function() end)
  for _, t in pairs(pg.args) do if type(t) == "table" and t.args and t.args.defDiamond then return true end end; return pg.args.defDiamond ~= nil end)())
if dpop then dpop:Hide() end
SOCKETS.Ring = { 8100 }
miss2 = Shop.Missing(c)
check("  ...one worn (in the ring): the helm's socket asks for your normal gem again", find2("diamond", 1) == nil and find2("gem", 1) ~= nil)
SOCKETS.Ring = { 8001 }; C_Item.GetItemUniquenessByID = nil; h.gems[8100] = nil

-- 10. Settings and off again ---------------------------------------------------------------------------------------------------
local page = ns.BuildShoppingListPage(function() end)
local function arg(k) if page.args[k] then return page.args[k] end; for _, tab in pairs(page.args) do if type(tab) == "table" and tab.args and tab.args[k] then return tab.args[k] end end end
check("settings: Blizzard UI Reskin > Shopping List with its switch, the panel and the Blizzard-list switch", page.name == "Shopping List" and page.xuiSwitch and arg("enabled") == nil and arg("panel") and arg("tracker"))
arg("def11").set(nil, "|cff0070dd|Hitem:9100::::::::90:::::|h[Enchant Ring - Amani Mastery]|h|r")
check("  ...a default set by shift-clicking an item: its name and item ID", c.defaults["ench:11"] and c.defaults["ench:11"].name == "Enchant Ring - Amani Mastery" and c.defaults["ench:11"].itemID == 9100)
arg("def11").set(nil, "")
check("  ...empty goes back to the most used", c.defaults["ench:11"] == nil)
page.xuiSwitch.set(nil, false)
check("switched off: the panel hides and its events are let go", not XayaUIShoppingList.shown)

-- 11. When the panel shows itself (UI-77, O-139, QoL 0.7.42; her words: "shopping list keeps popping up but there's no reason for it to
-- show"; conservative reading, flagged): never at login or on a switch by itself; at the Auction House, or when worn gear misses an
-- enchant or a gem; a close (its X, or /xui shop) is saved until the next Auction House visit; /xui shop still opens it ------------
local SL = XayaUIShoppingList
local closeBtn
for _, f in ipairs(created) do if f.parent == SL and f.w == 24 and f.h == 24 and f.scripts.OnClick then closeBtn = f end end
local helmLink = GEAR[1]
local function gearComplete() GEAR[1] = helmLink:gsub("item:(%d+):", "item:%1:7000:", 1); TIP[1] = { { type = 15, leftText = "Enchanted: Amani Mastery" } }; SOCKETS.Helm = { 8001 } end
local function gearMissing() GEAR[1] = helmLink; TIP[1] = nil; SOCKETS.Helm = { 0 } end
local function shown() return SL.shown == true end
gearComplete()
c.enabled = true; c.closedTillAH = false; SL:Hide()
do local m = Shop.Missing(c); local t = {}; for _, x in ipairs(m) do t[#t+1] = x.kind .. ":" .. tostring(x.slot) end; DBGM = table.concat(t, ",") end
check("auto-show: with nothing missing on the gear, Missing is empty (the case she reported: only a tracked recipe)", Shop.Missing(c)[1] == nil, DBGM)
Shop.Apply()   -- what login (ns.WhenReady) and the Blizzard UI Reskin switch call
check("  ...login / the reskin switch: the panel does not pop up", not shown())
fire("PLAYER_ENTERING_WORLD", false, true)
check("  ...a loading screen: still not", not shown())
fire("AUCTION_HOUSE_SHOW")
check("the Auction House opens: the panel shows itself", shown())
check("its X closes it, and the close is saved", closeBtn ~= nil and (closeBtn.scripts.OnClick(closeBtn) or true) and not shown() and c.closedTillAH == true)
gearMissing()
Shop.Apply()   -- a reload: the saved close holds even with something missing
check("  ...after a reload it stays closed, even with the helm missing its enchant", not shown())
fire("PLAYER_EQUIPMENT_CHANGED", 1, false)
check("  ...and putting on gear that misses something does not reopen it", not shown())
fire("AUCTION_HOUSE_SHOW")
check("the next Auction House visit opens it and forgets the close", shown() and c.closedTillAH == false)
SL:Hide()   -- (hidden without a close, as after the Auction House)
fire("PLAYER_EQUIPMENT_CHANGED", 1, false)
check("not closed, and the worn gear misses an enchant or a gem: it shows itself", shown())
Shop.Toggle()
check("/xui shop closes it (saved like the X)", not shown() and c.closedTillAH == true)
Shop.Toggle()
check("/xui shop opens it any time, and forgets the close", shown() and c.closedTillAH == false)
gearComplete(); SL:Hide()
local pg2 = ns.BuildShoppingListPage(function() end)
local function arg2(k) if pg2.args[k] then return pg2.args[k] end; for _, tab in pairs(pg2.args) do if type(tab) == "table" and tab.args and tab.args[k] then return tab.args[k] end end end
arg2("fontSize").set(nil, 12)
check("a setting changed (text size) does not pop it up", not shown())
arg2("panel").set(nil, false); arg2("panel").set(nil, true)
check("the panel's own switch turned on shows it (you asked for it)", shown())
'''.replace("__WORLD__", P("tests/char_toolkit_world.lua")).replace("__MOD__", P("XayaUI/Modules.lua")).replace("__COMPAT__", P("XayaUI/Compat.lua"))
   .replace("__SM__", P("XayaUI_QoL/StatMath.lua")).replace("__CM__", P("XayaUI_QoL/CharacterModel.lua")).replace("__CT__", P("XayaUI_QoL/CharacterToolkit.lua"))
   .replace("__SL__", P("XayaUI_QoL/ShoppingList.lua")))
n, fails = lua.eval("n"), lua.eval("fails")
print("%d checks, %d failed" % (n, fails))
sys.exit(1 if fails else 0)
