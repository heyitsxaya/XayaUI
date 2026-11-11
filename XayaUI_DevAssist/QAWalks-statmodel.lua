-------------------------------------------------------------------------------
-- QAWalks-statmodel.lua: the in-game QA walkthrough for the stat model's fixes of V25 unit B (XayaUI QoL, StatModel.lua; review
-- docs/plans/STAT-CALCULATOR-REVIEW-2026-11-10.md SC-034, SC-050, SC-098, SC-099). Xaya's rule (2026-11-07, V22, her words): "make sure
-- every feature or significant change to the codebase / bug report fixes have an in game qa test walk through with pre-fill confirmation
-- options or data capturing". prefill = true: where the addon can read the result it offers its own verdict on one button (QAWalk.lua);
-- nothing is recorded without the person's click. Where it cannot (no fitting item in the bags, XayaUI Rules still on) the check gives no
-- verdict and says what to do.
-- Every read goes through core's service list (Modules.lua ns.Service): "statCalc" (XayaUI Bonus Features, StatCalculator.lua: Open,
-- Shown, Drawn, Cfg, SelectGearSlot, PickItem) and "statModel" (XayaUI QoL: the model, for the help texts and the bag list). No other
-- addon's own tables are named here. What "Do it for me" changes (the panel's tab, open or closed, Spell Math on, the compared item) is
-- remembered in the first step and put back in the last one. Needs a XayaUI_DevAssist.toc line after the other QAWalks files (the
-- integration step adds it). UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end

local function NS() return rawget(_G, "XayaUI_NS") end
local function Svc(name) local ns = NS(); return ns and ns.Service and ns.Service(name) or nil end
local function SC() return Svc("statCalc") end
local function CMod() local s = Svc("statModel"); return s and s.CM or nil end

local function Ready()
    local sc = SC()
    if not sc then return false, "XayaUI Bonus Features is not loaded, or XayaUI QoL is off" end
    if not CMod() then return false, "XayaUI QoL is off: the Stat Calculator needs its model" end
    local c = sc.Cfg()
    if not (c and c.enabled) then return false, "the Stat Calculator is off: XayaUI > Bonus Features > Stat Calculator" end
    if not c.panel then return false, "the Stat Calculator panel is off: Bonus Features > Stat Calculator > Panel" end
    return true
end
local function Model()
    local sc = SC()
    local d = sc and sc.Shown() and sc.Drawn()
    return d and d.model or nil
end
local function Open(tab)
    local ok, why = Ready(); if not ok then error(why) end
    local done, w2 = SC().Open(tab)
    if not done then error(w2 or "the panel did not open (in combat it stays hidden)") end
end
local function Pairs(it, label) for _, p in ipairs(it and it.pairs or {}) do if p.label == label then return p.value end end end

-- what this walkthrough changes, remembered at the start and put back at the end. (round 2; review: step 3 asks for a /reload, which
-- emptied a file-local and made step 3 remember the state steps 1-2 had left) kept in Dev Assist's own saved table (QA.DB(), saved
-- across a /reload), so the last step puts back what the player had before step 1.
local function Store() local db = QA.DB and QA.DB(); return type(db) == "table" and db or nil end
local function Saved() local db = Store(); return db and type(db.statModelSaved) == "table" and db.statModelSaved or nil end
local function Remember()
    local sc = SC(); local c = sc and sc.Cfg()
    local db = Store()
    if not (c and db) or Saved() then return end
    db.statModelSaved = { tab = c.tab, open = sc.Shown(), advanced = c.advanced }
end
local function PutBack()
    local sc = SC(); local c = sc and sc.Cfg()
    local CM = CMod()
    if CM then CM.compareLinks, CM.compareText, CM.gearSlot, CM.compareSlot = {}, nil, nil, nil end
    local saved, db = Saved(), Store()
    if db then db.statModelSaved = nil end
    if not (c and saved) then return end
    c.tab, c.advanced = saved.tab, saved.advanced
    if saved.open then sc.Open(saved.tab) elseif sc.Shown() then sc.Close() end
end

-- (a) a bag item that fits a slot but has another equip location than the item there: a one-hand weapon over a main-hand-only one, a
-- robe over a chest, a shield over an off-hand frill, a two-hander over a one-hander. C_Item.GetItemInfoInstant (namespaces.md:2772)
-- gives the equip location; the bag list is the model's own (CM.OwnedFor).
local function Loc(link)
    if not (C_Item and C_Item.GetItemInfoInstant) then return nil end
    local ok, _, _, _, loc = pcall(C_Item.GetItemInfoInstant, link)
    return ok and type(loc) == "string" and loc or nil
end
local function FindPair()
    local CM = CMod(); if not CM then return nil end
    for _, slot in ipairs({ 16, 5, 17 }) do
        local eq = CM.SlotInfo(slot)
        local el = eq and Loc(eq.link)
        if el then
            for _, o in ipairs(CM.OwnedFor(slot)) do
                local ol = Loc(o.link)
                if ol and ol ~= el then return slot, o.link, eq.link end
            end
        end
    end
end
local picked
local function CompareState()
    local ok, why = Ready(); if not ok then return nil, why end
    if not picked then return nil, "no bag item fits a slot with another kind of item: wear a main-hand-only weapon and carry a one-hand one (or a chest piece and a robe, an off-hand frill and a shield), then press Do it for me again" end
    local m = Model()
    if not m then return nil, "the Stat Calculator is not open (press Do it for me)" end
    local il = m.byKey.gc_ilvl
    if not il then return nil, "no comparison drawn (press Do it for me)" end
    return { eq = il.cells and il.cells[1], item = il.cells and il.cells[2], prim = m.byKey.gc_primary }
end

-- (d) the help hovers every player sees (it.tip of the column heads and buttons): no game call named, no formula. The builds for the
-- three tabs replace the model's What If base readings, so the open panel is drawn again afterwards from its own tab (sc.Open).
local API = { "C_%u%a+", "Get%u%a+", "Unit%u%a+", "ATTACK_POWER_MAGIC_NUMBER", " / attack power now", "card's" }
local function HelpTexts()
    local CM = CMod(); local sc = SC(); local c = sc and sc.Cfg()
    if not (CM and c) then return nil end
    local out, bad = {}, {}
    for _, tab in ipairs({ "stats", "gear", "spells" }) do
        local m = CM.Build(c, tab)
        for _, sec in ipairs(m.sections) do
            for _, it in ipairs(sec.items) do
                if CM.HELP_KINDS[it.kind] and #(it.tip or {}) > 0 then
                    local text = table.concat(it.tip, " ")
                    out[#out + 1] = tostring(it.label) .. ": " .. text
                    for _, pat in ipairs(API) do if text:find(pat) then bad[#bad + 1] = tostring(it.key) .. " (" .. pat .. ")" end end
                end
            end
        end
    end
    if sc.Shown() then sc.Open(c.tab) end
    return out, bad
end

QA.Register("statmodel", { title = "Stat Calculator: gear comparison, Armor rows, Ability Scaling without XayaUI Rules, help hovers", qa = "E1z231, E1z232, E1z233, E1z234", order = 196, prefill = true, steps = {
    { text = "Wear a |cffffd100main-hand-only|r weapon and carry a |cffffd100one-hand|r weapon in your bags (or wear a chest piece and carry a robe; or hold an off-hand frill and carry a shield). Press |cffffd100Do it for me|r: the Stat Calculator opens on its |cffffd100Gear|r tab, selects that slot and picks the bag item.\n\n|cffffd100Expect:|r the Changes table's |cffffd100Equipped|r column shows the item you wear (its item level and stats, not \"empty\"), and each change in brackets is the difference.",
      setup = function()
          Remember()
          local slot, link = FindPair()
          picked = link
          Open("gear")
          if not slot then return end
          local sc, CM = SC(), CMod()
          if sc.SelectGearSlot and sc.PickItem then
              CM.compareLinks, CM.compareText = {}, nil
              if CM.gearSlot ~= slot then sc.SelectGearSlot(slot) end
              sc.PickItem(link, slot)
          else
              CM.gearSlot, CM.compareSlot, CM.compareLinks, CM.compareText = slot, slot, { link }, link
              sc.Open("gear")
          end
      end,
      check = function()
          local s, why = CompareState(); if not s then return nil, why end
          local ok = s.eq ~= nil and tostring(s.eq) ~= "empty" and tostring(s.eq) ~= "0"
          local pr = s.prim and s.prim.cells and (tostring(s.prim.cells[1]) .. " -> " .. tostring(s.prim.cells[2]) .. " (" .. tostring(s.prim.diffs and s.prim.diffs[2] or "") .. ")") or "no primary stat row"
          return ok, ("Equipped item level %s, picked %s; primary stat %s"):format(tostring(s.eq), tostring(s.item), pr)
      end },
    { text = "Press |cffffd100Do it for me|r: the |cffffd100Stats|r tab. Click |cffffd100Armor|r (under Defensive) to open its rows.\n\n|cffffd100Expect:|r |cffffd100Base armor|r and |cffffd100From buffs and talents|r (+N), each with its own number, and |cffffd100Bonus armor|r when you have some. Base + From buffs and talents = the Armor figure. (No row reads \"Base, buffs and talents\".)",
      setup = function() Open("stats") end,
      check = function()
          local ok, why = Ready(); if not ok then return nil, why end
          local m = Model(); if not m then return nil, "the Stat Calculator is not open (press Do it for me)" end
          local a = m.byKey.map_armor
          if not a then return nil, "no Armor line drawn" end
          if a.hidden then return nil, "armor is hidden in combat: leave combat and Check again" end
          local b, f, x = Pairs(a, "Base armor"), Pairs(a, "From buffs and talents"), Pairs(a, "Bonus armor")
          return b ~= nil and f ~= nil and Pairs(a, "Base, buffs and talents") == nil,
              ("Armor %s: Base armor %s, From buffs and talents %s, Bonus armor %s"):format(tostring(a.value), tostring(b), tostring(f), tostring(x))
      end },
    { text = "Switch |cffffd100XayaUI Rules|r off in the AddOns list (character select, or Esc > AddOns), type |cffffd100/reload|r, open this walkthrough again at this step, then press |cffffd100Do it for me|r: the |cffffd100Ability Scaling|r tab with its spell data read (Spell Math on).\n\n|cffffd100Expect:|r your spellbook's spells are listed (no \"No spells found\"). Switch XayaUI Rules back on afterwards.",
      setup = function()
          Remember()
          local c = SC() and SC().Cfg()
          if c then c.advanced = true end
          Open("spells")
      end,
      check = function()
          local ok, why = Ready(); if not ok then return nil, why end
          if Svc("rules") then return nil, "XayaUI Rules is still on: switch it off in the AddOns list, /reload, then run this step again" end
          local m = Model(); if not m then return nil, "the Stat Calculator is not open (press Do it for me)" end
          local names = {}
          for _, sec in ipairs(m.sections) do
              if sec.key == "spellmath" then for _, it in ipairs(sec.items) do if it.spellID then names[#names + 1] = tostring(it.label) end end end
          end
          return #names > 0 and m.byKey.noSpells == nil, ("%d spells listed: %s"):format(#names, table.concat(names, ", ", 1, math.min(#names, 5)))
      end },
    { text = "Press |cffffd100Check|r: the addon reads every help hover a player sees on the three tabs (the column heads, the Configure / Refresh spell data buttons, the gear icons).\n\n|cffffd100Expect:|r none names a game call (C_..., Get..., Unit...) or shows a formula; each says in plain words what the column means or what a click does. The texts are kept with the result for Xaya.",
      check = function()
          local ok, why = Ready(); if not ok then return nil, why end
          local out, bad = HelpTexts()
          if not out then return nil, "the model is not there" end
          return #bad == 0, (#bad == 0 and "" or ("names a call: " .. table.concat(bad, ", ") .. ". ")) .. table.concat(out, " | ")
      end },
    { done = true, text = "Last step: press |cffffd100Do it for me|r to put the Stat Calculator back as it was (its tab, open or closed, Spell Math, no compared item). Switch XayaUI Rules back on if you switched it off. Then press |cffffd100Done|r.",
      setup = function() PutBack() end,
      check = function() local back = Saved() == nil; return back, back and "put back" or "press Do it for me" end },
} })
