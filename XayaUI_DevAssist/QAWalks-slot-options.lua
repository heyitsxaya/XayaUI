-------------------------------------------------------------------------------
-- QAWalks-slot-options.lua (XayaUI Dev Assist): the in-game walkthrough for Improved Character Display's slot layout (XayaUI QoL,
-- ImprovedCharacterDisplay.lua). Xaya, REQUEST-LOG A24 #7 (one "Item level" and one "Enchants" option) and A24 #9, her words: "Ilvl goes
-- on item block; enchant and gems are both on the outside right border of the icon. Don't remove anything else"; on the Style choice:
-- "I don't know what the style label is, but it sounds unnecessary". Built: no Style select; the item level on the slot's icon; the
-- enchant, the embellishment and the gems against the outside right edge of the slot's icon for every slot (INFERENCE that she means
-- every column, the right-hand column included, where the rows lie over the stats pane; the main hand's block stays left of the
-- weapons because a block right of it would cover the off hand's icon). Her review step (step 4) puts each open choice to her: the
-- stat hovers under the right-hand column's rows, the main hand, the item level, the removed E? / E check, the narrow window. Standing rule V22 (Xaya 2026-11-07, her words): "make sure every
-- feature or significant change to the codebase / bug report fixes have an in game qa test walk through with pre-fill confirmation
-- options or data capturing". prefill = true: where the addon can read the result its verdict is offered on one button and recorded only
-- on a click (QAWalk.lua); a step marked noVerdict asks something only the person can see (the review step is Xaya's own in-game review
-- of the layout: Pass / Fail by her).
-- Reads and sets XayaUI QoL only through core's "charDisplayDebug" service (its settings, Apply, Draws, Placement), reads what is drawn
-- through "charDisplay" (Drawn) and reads the settings page as the settings window builds it (ns.BuildSettingsPages). What "Do it for me"
-- changes (Item level, Enchants, Gems and sockets beside the slots) is remembered at step 2 and put back by the last step. Nothing here
-- takes the keyboard, the mouse or a frame. Listed in XayaUI_DevAssist.toc after the other QAWalks files; does nothing without the
-- framework. UNVERIFIED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end

local function NS() return rawget(_G, "XayaUI_NS") end
local function Svc(n) local ns = NS(); return ns and ns.Service and ns.Service(n) or nil end
local function Dbg()
    local dbg = Svc("charDisplayDebug")
    if not (dbg and dbg.Cfg and dbg.Draws and dbg.Placement) then return nil, "XayaUI QoL is off or too old (no charDisplayDebug.Placement)" end
    return dbg
end
local function Drawn()
    local s = Svc("charDisplay")
    return (s and s.Drawn) and s.Drawn() or nil
end
local function V(x) if type(x) == "function" then local ok, r = pcall(x, {}); return ok and r or nil end; return x end
-- a page as the settings window builds it (nil and why not)
local function Page(module, key)
    local ns = NS()
    if not (ns and ns.BuildSettingsPages) then return nil, "XayaUI is not loaded" end
    local p = (ns.BuildSettingsPages(module) or {})[key]
    if type(p) ~= "table" then return nil, ("the page %s > %s is not there (is XayaUI QoL on?)"):format(module, key) end
    return p
end
local function OnOff(v) return v and "on" or "off" end
-- the drawing state now, as a note: which option is on, what is counted on the slots and where the rows lie
local function State()
    local dbg, why = Dbg()
    if not dbg then return nil, why end
    local w = dbg.Draws()
    if not w then return nil, "Improved Character Display is off: tick QoL > Improved Character Display" end
    local d, p = Drawn() or {}, dbg.Placement()
    return w, d, p, ("Item level: %s; Enchants: %s; Gems: %s; item levels drawn: %d (on their icon: %d, off it: %d); enchants drawn: %d; sockets drawn: %d; rows: %d (right of their slot: %d, not: %d, main hand's left of the weapons: %d, over a slot icon: %d, past the window: %d, over the stats pane: %d, over a Full stat list line: %d)"):format(
        OnOff(w.ilvl), OnOff(w.enchants), OnOff(w.gems), d.ilvl or 0, p.ilvlOnIcon, p.ilvlOffIcon, d.enchants or 0, d.sockets or 0,
        p.rows, p.rightOf, p.notRightOf, p.mainHand, p.overSlot, p.offWindow, p.overStats or 0, p.overStatList or 0)
end
local function Set(fn)
    local dbg = Dbg()
    local c = dbg and dbg.Cfg()
    if not c then error("XayaUI QoL is off") end
    if not c.enabled then error("tick QoL > Improved Character Display first") end
    fn(c)
    dbg.Apply()
end

local kept   -- step 2: { ilvl, enchants, gems } as they were
QA.Register("slot-options", { title = "Improved Character Display: item level on the icon, enchant and gems at the icon's right edge, no Style (A24 #9; Xaya's in-game review)",
    area = "QoL", qa = "E1z243", order = 532, prefill = true, steps = {
    { text = "Open the character window (|cffffd100C|r) on the Character tab. Since this update there is no |cffffd100Style|r choice: the item level is on each slot's icon, and the enchant and the gems are against the outside right edge of each slot's icon.\n\n|cffffd100Expect:|r the note shows your settings now and where things are drawn. Tell us in the note whether anything you had before is missing (a question for you; no verdict from the addon).",
        noVerdict = true,
        check = function()
            local w, d, p, note = State()
            if not w then return nil, d end
            local dbg = Dbg()
            local c = dbg and dbg.Cfg() or {}
            return true, note .. ("; Empty sockets mark: %s"):format(c.socketMark == true and "ticked" or "unticked")
        end },
    { text = "Press |cffffd100Do it for me|r: XayaUI remembers three of your settings, then ticks |cffffd100Item level|r, |cffffd100Enchants|r and |cffffd100Gems and sockets beside the slots|r. Keep the character window open on the Character tab.\n\n|cffffd100Expect:|r one item level at the bottom of each equipped slot's icon (colored by its upgrade track); each enchant's name (or \"No enchant\" in orange), the embellishment and the gems starting just right of the slot's icon, in both columns; the off hand's to the right of the weapons; the main hand's still left of the weapons. Nothing covers a slot's icon or reaches past the window.",
        setup = function()
            Set(function(c)
                if not kept then kept = { ilvl = c.ilvl, enchants = c.enchants, gems = c.gems } end
                c.ilvl, c.enchants, c.gems = true, true, true
            end)
        end,
        check = function()
            local w, d, p, note = State()
            if not w then return nil, d end
            if (d.ilvl or 0) == 0 or p.rows == 0 then return nil, "nothing drawn yet: open the character window (C) on the Character tab | " .. note end
            return w.ilvl == "icon" and w.enchants == "right" and p.ilvlOffIcon == 0 and p.rightOf > 0 and p.notRightOf == 0 and p.overSlot == 0
                and p.offWindow == 0, note
        end },
    { text = "Open the settings window (|cffffd100/xui|r) at QoL > Improved Character Display.\n\n|cffffd100Expect:|r the |cffffd100Item level|r and |cffffd100Enchants|r tick boxes are there, with no |cffffd100Style|r dropdown after either; Empty sockets, Text size, Enchant Slots and the other options are still there.",
        check = function()
            local pg, why = Page("qol", "chardisplay")
            if not pg then return nil, why end
            local a, styles = pg.args or {}, {}
            for k, v in pairs(a) do if type(v) == "table" and v.type == "select" and V(v.name) == "Style" then styles[#styles + 1] = k end end
            local kept2 = a.ilvl and a.enchants and a.gems and a.socketMark and a.markSize and a.enchantSlotsPage and a.statList and a.statCalcButton
            return #styles == 0 and kept2 and true or false, ("Style dropdowns on the page: %d%s; Item level: %s; Enchants: %s; the other options there: %s"):format(#styles,
                #styles > 0 and (" (" .. table.concat(styles, ", ") .. ")") or "", tostring(a.ilvl and V(a.ilvl.name)), tostring(a.enchants and V(a.enchants.name)), kept2 and "yes" or "NO")
        end },
    { text = "|cffffd100Xaya's in-game review of the layout (A24 #9).|r With the character window open, look at both columns and the weapons, also with Blizzard Reskin > Character Reskin's Wider window on and off. Each point is an open question for you; nothing in it was decided for you:\n(1) |cffffd100Right-hand column:|r its enchants and gems now lie over the stats pane (built literally from \"the outside right border of the icon\" for every slot: an INFERENCE that you meant every column). Hover a stat line that has an enchant or gem line over it (Blizzard's stats, and XayaUI's Full stat list if you use it): does the stat's own tooltip still show? If not, this takes away a stat hover you had before.\n(2) |cffffd100Main hand:|r its enchant and gems are NOT on its right edge: they stay left of the weapons, because right of it is the off hand's icon. Say where you want them.\n(3) |cffffd100Item level:|r at the bottom of the icon.\n(4) |cffffd100Removed:|r the E? / E enchant check that could show on the slot (the enchant now shows only at the right edge). Say if you want it back.\n(5) |cffffd100Narrow window:|r without the stats pane there is no room right of the right-hand column, and its enchants and gems are not drawn. Tell us if you ever see that.\n\n|cffffd100Your call:|r press |cffffd100Pass|r or |cffffd100Fail|r and say what to change in the note.",
        noVerdict = true,
        check = function()
            local w, d, p, note = State()
            if not w then return nil, d end
            return true, note
        end },
    { done = true, text = "Last step: press |cffffd100Do it for me|r to put Item level, Enchants and Gems and sockets beside the slots back as they were before step 2. Then press |cffffd100Done|r.",
        setup = function()
            local dbg = Dbg()
            local c = dbg and dbg.Cfg()
            if c and kept then c.ilvl, c.enchants, c.gems = kept.ilvl, kept.enchants, kept.gems; dbg.Apply() end
            kept = nil
        end },
} })
