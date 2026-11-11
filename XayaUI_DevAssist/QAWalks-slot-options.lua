-------------------------------------------------------------------------------
-- QAWalks-slot-options.lua (XayaUI Dev Assist): the in-game walkthrough for Improved Character Display's merged slot options (XayaUI
-- QoL, ImprovedCharacterDisplay.lua; Xaya, REQUEST-LOG A24 #7, her answer "1 with the caveat needs review in game"; option 1: "One
-- 'Item level' option and one 'Enchants' option, each with a style choice: on the slot or beside it. The overlap is gone."). Standing
-- rule V22 (Xaya 2026-11-07, her words): "make sure every feature or significant change to the codebase / bug report fixes have an in
-- game qa test walk through with pre-fill confirmation options or data capturing". prefill = true: where the addon can read the result
-- its verdict is offered on one button and recorded only on a click (QAWalk.lua); a step marked noVerdict asks something only the person
-- can see (the last one is Xaya's own in-game review of the merged layout: Pass / Fail by her).
-- Reads and sets XayaUI QoL only through core's "charDisplayDebug" service (its settings, Apply, Draws, SlotMarks) and reads what is
-- drawn through "charDisplay" (Drawn). What "Do it for me" changes (Item level, Enchants, their styles) is remembered at step 2 and put
-- back by the last step. Nothing here takes the keyboard, the mouse or a frame. Listed in XayaUI_DevAssist.toc after the other QAWalks
-- files (the integration step adds the line); does nothing without the framework. UNVERIFIED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end

local function NS() return rawget(_G, "XayaUI_NS") end
local function Svc(n) local ns = NS(); return ns and ns.Service and ns.Service(n) or nil end
local function Dbg()
    local dbg = Svc("charDisplayDebug")
    if not (dbg and dbg.Cfg and dbg.Draws) then return nil, "XayaUI QoL is off or too old (no charDisplayDebug.Draws)" end
    return dbg
end
local function Drawn()
    local s = Svc("charDisplay")
    return (s and s.Drawn) and s.Drawn() or nil
end
local function Plain(s) return (tostring(s or "")):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "") end
local function StyleName(v) if v == "slot" then return "On the slot" elseif v == "beside" then return "Beside the slot" end; return "off" end
-- the drawing state now, as a note: where each option draws, and what is counted on the slots
local function State()
    local dbg, why = Dbg()
    if not dbg then return nil, why end
    local w = dbg.Draws()
    if not w then return nil, "Improved Character Display is off: tick QoL > Improved Character Display" end
    local d = Drawn() or {}
    return w, d, ("Item level: %s; Enchants: %s; item levels drawn: %d; enchants beside the slots: %d; slots with a mark: %d"):format(
        StyleName(w.ilvl), StyleName(w.enchants), d.ilvl or 0, d.enchants or 0, d.marks or 0)
end
local function Set(fn)
    local dbg = Dbg()
    local c = dbg and dbg.Cfg()
    if not c then error("XayaUI QoL is off") end
    if not c.enabled then error("tick QoL > Improved Character Display first") end
    fn(c)
    dbg.Apply()
end

local kept   -- step 2: { ilvl, enchants, ilvlStyle, enchantStyle } as they were
QA.Register("slot-options", { title = "Improved Character Display: Item level and Enchants, each On the slot or Beside the slot (A24 #7; Xaya's in-game review)",
    area = "QoL", qa = "E1z243", order = 532, prefill = true, steps = {
    { text = "Open the character window (|cffffd100C|r) on the Character tab. XayaUI moved your old settings once (the Slot Overlays marks and the item level / enchants beside the slots became one |cffffd100Item level|r and one |cffffd100Enchants|r option, each with a |cffffd100Style|r).\n\n|cffffd100Expect:|r the note shows what your settings are now. Tell us in the note whether the window shows what it showed before the update (a question for you; no verdict from the addon).",
        noVerdict = true,
        check = function()
            local w, d, note = State()
            if not w then return nil, d end
            local dbg = Dbg()
            local c = dbg and dbg.Cfg() or {}
            return true, note .. ("; Empty sockets mark: %s"):format(c.socketMark == true and "ticked" or "unticked")
        end },
    { text = "Press |cffffd100Do it for me|r: XayaUI remembers your four settings, then ticks |cffffd100Item level|r (Style |cffffd100On the slot|r) and |cffffd100Enchants|r (Style |cffffd100Beside the slot|r). Keep the character window open.\n\n|cffffd100Expect:|r one item level at the bottom of each equipped slot (colored by its upgrade track), and each enchant's name (or \"No enchant\" in orange) beside its slot. No E? or E on the slots.",
        setup = function()
            Set(function(c)
                if not kept then kept = { ilvl = c.ilvl, enchants = c.enchants, ilvlStyle = c.ilvlStyle, enchantStyle = c.enchantStyle } end
                c.ilvl, c.enchants, c.ilvlStyle, c.enchantStyle = true, true, nil, nil
            end)
        end,
        check = function()
            local w, d, note = State()
            if not w then return nil, d end
            if (d.ilvl or 0) == 0 then return nil, "nothing drawn yet: open the character window (C) on the Character tab | " .. note end
            return w.ilvl == "slot" and w.enchants == "beside" and (d.enchants or 0) > 0, note
        end },
    { text = "Press |cffffd100Do it for me|r: XayaUI sets the Item level's Style to |cffffd100Beside the slot|r.\n\n|cffffd100Expect:|r the item level is now the first line beside each slot, above the enchant, in the same color; none is left on the slots. Hover it: the item level and its upgrade track.",
        setup = function() Set(function(c) c.ilvlStyle = "beside" end) end,
        check = function()
            local w, d, note = State()
            if not w then return nil, d end
            return w.ilvl == "beside" and (d.ilvl or 0) > 0, note
        end },
    { text = "Press |cffffd100Do it for me|r: XayaUI sets the Enchants' Style to |cffffd100On the slot|r.\n\n|cffffd100Expect:|r at the top of each slot ticked in QoL > Improved Character Display > Enchant Slots: |cffffd100E?|r in orange when it has no enchant, |cffffd100E|r in green when it has one. No enchant names or embellishment lines beside the slots any more (the gems stay).",
        setup = function() Set(function(c) c.enchantStyle = "slot" end) end,
        check = function()
            local w, d, note = State()
            if not w then return nil, d end
            local dbg = Dbg()
            local head = dbg and dbg.SlotMarks and Plain(dbg.SlotMarks("HeadSlot")) or ""
            return w.enchants == "slot" and (d.enchants or 0) == 0 and (d.marks or 0) > 0, note .. "; head slot's mark: " .. (head ~= "" and head or "none")
        end },
    { text = "|cffffd100Xaya's in-game review of the merged options (A24 #7, \"needs review in game\").|r Open the settings window (|cffffd100/xui|r) at QoL > Improved Character Display and try each |cffffd100Style|r of |cffffd100Item level|r and |cffffd100Enchants|r with the character window open (also with Blizzard Reskin > Character Reskin's Wider window on and off).\n\n|cffffd100Your call:|r do the two options, their \"On the slot\" / \"Beside the slot\" choices and the layout on the window read the way you want? Press |cffffd100Pass|r or |cffffd100Fail|r and say what to change in the note (also: the gems and the \"2S\" Empty sockets mark were left as they were; where should they go?).",
        noVerdict = true,
        check = function()
            local w, d, note = State()
            if not w then return nil, d end
            return true, note
        end },
    { done = true, text = "Last step: press |cffffd100Do it for me|r to put Item level, Enchants and their styles back as they were before step 2. Then press |cffffd100Done|r.",
        setup = function()
            local dbg = Dbg()
            local c = dbg and dbg.Cfg()
            if c and kept then c.ilvl, c.enchants, c.ilvlStyle, c.enchantStyle = kept.ilvl, kept.enchants, kept.ilvlStyle, kept.enchantStyle; dbg.Apply() end
            kept = nil
        end },
} })
