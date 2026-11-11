-------------------------------------------------------------------------------
-- QAWalks-chardisplay-fixes.lua (XayaUI Dev Assist): the in-game walkthrough for the Improved Character Display / Character Reskin fixes
-- of 2026-11-10 (XayaUI QoL, ImprovedCharacterDisplay.lua and CharacterReskin.lua; docs/plans/STAT-CALCULATOR-REVIEW-2026-11-10.md
-- SC-069 / SC-103): (a) a slot mark that cannot show because the matching "beside the slots" option already shows the same thing is
-- greyed, unticked, and its hover names the option to turn off, and Text size is greyed while no mark can show (since A24 #7 the one
-- such mark left is Empty sockets: the Slot Overlays' Item level and Enchant check marks were merged into the Item level and Enchants
-- options); (b) the Character Reskin's stat list toggle is "Stat list colors", so it
-- is not confused with Improved Character Display's Stat list page. Standing rule V22 (Xaya 2026-11-07, her words): "make sure every
-- feature or significant change to the codebase / bug report fixes have an in game qa test walk through with pre-fill confirmation
-- options or data capturing". prefill = true: where the addon can read the result its verdict is offered on one button and recorded only
-- on a click (QAWalk.lua); a step marked noVerdict asks something only the person can see.
-- Reads the settings pages as the settings window builds them (core's ns.BuildSettingsPages: the same tables, their disabled / get /
-- desc functions) and reaches XayaUI QoL only through core's "charDisplayDebug" service (its settings and Apply). Building the QoL pages
-- here runs Improved Character Display's page builder, which takes its once-per-reload "first options-window open" read of the Stat
-- Calculator tie-in (Xaya A24 #6) at walkthrough time instead of at the settings window's first open; Dev Assist only, harmless. What "Do it for me"
-- changes (Enchants and its Style, Gems and sockets beside the slots, Empty sockets) is remembered and put back by the last step. Nothing here takes the keyboard, the
-- mouse or a frame. Listed in XayaUI_DevAssist.toc after the other QAWalks files (the integration step adds the line); does nothing
-- without the framework. UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end

local function NS() return rawget(_G, "XayaUI_NS") end
local function Svc(n) local ns = NS(); return ns and ns.Service and ns.Service(n) or nil end
local function V(x) if type(x) == "function" then local ok, r = pcall(x, {}); return ok and r or nil end; return x end
local function Short(s, n) s = tostring(s or ""):gsub("|", "||"); return #s > (n or 120) and (s:sub(1, n or 120) .. "...") or s end

-- a page as the settings window builds it (nil and why not)
local function Page(module, key)
    local ns = NS()
    if not (ns and ns.BuildSettingsPages) then return nil, "XayaUI is not loaded" end
    local pages = ns.BuildSettingsPages(module) or {}
    local p = pages[key]
    if type(p) ~= "table" then return nil, ("the page %s > %s is not there (is XayaUI QoL on?)"):format(module, key) end
    return p
end
-- a control on QoL > Improved Character Display (default: the "Empty sockets" tick box). (A24 #7) The Slot Overlays part and its greyed
-- Item level / Enchant check marks are gone (one Item level and one Enchants option, each with a style; QAWalks-slot-options.lua); the
-- Empty sockets mark and the marks' Text size are kept as they were and are what this walkthrough checks now.
local function MarkBox(key)
    local p, why = Page("qol", "chardisplay")
    if not p then return nil, why end
    local box = p.args and p.args[key or "socketMark"]
    if type(box) ~= "table" then return nil, "no " .. tostring(key or "socketMark") .. " on the page (is XayaUI QoL up to date?)" end
    return box
end

local kept   -- step 1: { enchants, enchantStyle, gems, socketMark } as they were
QA.Register("chardisplay-fixes", { title = "Improved Character Display: a slot mark that cannot show is greyed with the reason; Character Reskin's \"Stat list colors\" (SC-069, SC-103)",
    area = "QoL", qa = "E1z235, E1z236", order = 527, prefill = true, steps = {
    { text = "Tick |cffffd100QoL > Improved Character Display|r if it is not ticked. Then press |cffffd100Do it for me|r: XayaUI remembers four of its settings, then ticks |cffffd100Gems and sockets beside the slots|r and |cffffd100Empty sockets|r.\n\n|cffffd100Expect:|r on QoL > Improved Character Display, the |cffffd100Empty sockets|r tick box is greyed and unticked (the gems beside the slots already show the sockets, so the mark would add nothing).",
        setup = function()
            local dbg = Svc("charDisplayDebug")
            local c = dbg and dbg.Cfg and dbg.Cfg()
            if not c then error("XayaUI QoL is off") end
            if not c.enabled then error("tick QoL > Improved Character Display first") end
            if not kept then kept = { enchants = c.enchants, enchantStyle = c.enchantStyle, gems = c.gems, socketMark = c.socketMark } end
            c.gems, c.socketMark = true, true
            dbg.Apply()
        end,
        check = function()
            local box, why = MarkBox()
            if not box then return nil, why end
            local dis, tick, hover = V(box.disabled) == true, V(box.get) == true, tostring(V(box.desc) or "")
            local ok = dis and not tick and hover:find("Gems and sockets beside the slots", 1, true) ~= nil
            return ok, ("Empty sockets box: %s, %s; its hover: %s"):format(dis and "greyed" or "NOT greyed", tick and "ticked" or "unticked", Short(hover))
        end },
    { text = "Open the settings window (|cffffd100/xui|r), go to QoL > Improved Character Display, and hover the greyed |cffffd100Empty sockets|r tick box.\n\n|cffffd100Expect:|r the hover says it is greyed because \"Gems and sockets beside the slots\" already shows this, and to turn it off to use this mark. The note below shows the text XayaUI gives the window.",
        noVerdict = true,
        check = function()
            local box, why = MarkBox()
            if not box then return nil, why end
            return true, "hover text given: " .. Short(V(box.desc), 200)
        end },
    { text = "Press |cffffd100Do it for me|r: XayaUI also ticks |cffffd100Enchants|r with its Style |cffffd100Beside the slot|r (the default), so no mark can show on the slots.\n\n|cffffd100Expect:|r |cffffd100Text size|r is greyed as well, and its hover says no mark shows on the slots.",
        setup = function()
            local dbg = Svc("charDisplayDebug")
            local c = dbg and dbg.Cfg and dbg.Cfg()
            if not c then error("XayaUI QoL is off") end
            c.enchants, c.enchantStyle = true, nil
            dbg.Apply()
        end,
        check = function()
            local sz, why = MarkBox("markSize")
            if not sz then return nil, why end
            local dis, hover = V(sz.disabled) == true, tostring(V(sz.desc) or "")
            return dis and hover:find("Greyed", 1, true) ~= nil, ("Text size: %s; its hover: %s"):format(dis and "greyed" or "NOT greyed", Short(hover))
        end },
    { text = "Open Blizzard Reskin > Character Reskin in the settings window (tick |cffffd100Character Reskin|r on its row if its options are greyed).\n\n|cffffd100Expect:|r the toggle that colors Blizzard's stat list reads |cffffd100Stat list colors|r (not \"Stat list\"); \"Stat list\" is only Improved Character Display's page of XayaUI's own full list.",
        check = function()
            local p, why = Page("reskin", "charreskin")
            if not p then return nil, why end
            local t = p.args and p.args.stats
            local name = t and V(t.name)
            return name == "Stat list colors", "the stat list toggle reads: " .. tostring(name)
        end },
    { done = true, text = "Last step: press |cffffd100Do it for me|r to put Enchants (and its Style), Gems and sockets beside the slots and Empty sockets back as they were before step 1. Then press |cffffd100Done|r.",
        setup = function()
            local dbg = Svc("charDisplayDebug")
            local c = dbg and dbg.Cfg and dbg.Cfg()
            if c and kept then c.enchants, c.enchantStyle, c.gems, c.socketMark = kept.enchants, kept.enchantStyle, kept.gems, kept.socketMark; dbg.Apply() end
            kept = nil
        end },
} })

-------------------------------------------------------------------------------
-- (U1, the V27 gate fixes of 2026-11-11: G-001, G-002, G-005, G-007) Improved Character Display's display over Blizzard's window is
-- hover only (her reading of V27, "Hover only, clicks pass"): the enchant / gem rows beside the slots and the full stat list show their
-- tooltips but every click and camera drag passes through; rows faded out under the model's camera buttons take no mouse at all; the
-- stat list is not redrawn when nothing it shows changed, and not in combat (once when combat ends; DECISION to confirm with Xaya).
-- The addon reads the mouse state of its own frames through "charDisplayDebug" (Mouse, ListCounts; read only) and offers a verdict
-- where it can; what only the player can see (the model turning, a camera button working) is asked (noVerdict). Nothing here takes the
-- keyboard, the mouse or a frame. UNVERIFIED IN GAME.
-------------------------------------------------------------------------------
local keptGate   -- step 1: { enchants, enchantStyle, gems, statList } as they were
local function Mouse()
    local dbg = Svc("charDisplayDebug")
    if not (dbg and dbg.Mouse) then return nil, "XayaUI QoL is off or too old (no charDisplayDebug.Mouse)" end
    return dbg.Mouse()
end
QA.Register("chardisplay-gate", { title = "Improved Character Display: rows and the stat list are hover only (clicks and camera drags pass); stat list quiet in combat (V27 G-001, G-002, G-005, G-007)",
    area = "QoL", qa = "E1z238", order = 528, prefill = true, steps = {
    { text = "Tick |cffffd100QoL > Improved Character Display|r if it is not ticked, then press |cffffd100Do it for me|r: XayaUI remembers four of its settings, then ticks |cffffd100Enchants|r with its Style |cffffd100Beside the slot|r, |cffffd100Gems and sockets beside the slots|r and the |cffffd100Full stat list|r. Open the character window (|cffffd100C|r) on the Character tab.\n\n|cffffd100Expect:|r enchant and gem rows beside the slots and XayaUI's stat list in the stats pane. The addon reads that none of them takes clicks.",
        setup = function()
            local dbg = Svc("charDisplayDebug")
            local c = dbg and dbg.Cfg and dbg.Cfg()
            if not c then error("XayaUI QoL is off") end
            if not c.enabled then error("tick QoL > Improved Character Display first") end
            if not keptGate then keptGate = { enchants = c.enchants, enchantStyle = c.enchantStyle, gems = c.gems, statList = c.statList } end
            c.enchants, c.enchantStyle, c.gems, c.statList = true, nil, true, true
            dbg.Apply()
        end,
        check = function()
            local m, why = Mouse()
            if not m then return nil, why end
            if m.rows == 0 then return nil, "nothing drawn yet: open the character window (C) on the Character tab" end
            return m.clicks == 0 and m.hover > 0, ("%d rows / list frames shown: %d take clicks (should be 0), %d take hover; waiting for combat to end: %s"):format(m.rows, m.clicks, m.hover, tostring(m.queued))
        end },
    { text = "Turn |cffffd100Blizzard Reskin > Character Reskin > Wider window|r off if it is on (at Blizzard's width the rows run over the sides of the model). Then |cffffd100left-drag|r on the model starting ON an enchant or gem row that lies over the model, and |cffffd100right-drag|r the same way.\n\n|cffffd100Expect:|r the left-drag turns your character and the right-drag pans it, as when you start beside the row. Hovering the row alone still shows its tooltip.",
        noVerdict = true,
        check = function()
            local m, why = Mouse()
            if not m then return nil, why end
            return true, ("rows taking clicks: %d (0 lets the drag reach the model); rows taking hover: %d"):format(m.clicks, m.hover)
        end },
    { text = "Still at Blizzard's width: move the mouse over the model so its camera buttons (zoom, rotate) show at its top. The head and hands rows that meet them fade out. Click each camera button, and hover where a faded row was.\n\n|cffffd100Expect:|r every camera button works, and no tooltip pops up for a row you cannot see. Keep the mouse over the model while the addon checks (press |cffffd100Check|r again if needed).",
        check = function()
            local m, why = Mouse()
            if not m then return nil, why end
            if m.faded == 0 then return nil, "no row is faded right now: keep the mouse over the model with the window at Blizzard's width" end
            return m.fadedHover == 0, ("%d faded row(s); %d of them still take the mouse (should be 0)"):format(m.faded, m.fadedHover)
        end },
    { text = "In the stats pane (XayaUI's full stat list): click a line, roll the mouse wheel over the list, and hover a line.\n\n|cffffd100Expect:|r the click does nothing (nothing of XayaUI's catches it), the wheel scrolls the list, and the hover shows the line's tooltip.",
        noVerdict = true,
        check = function()
            local m, why = Mouse()
            if not m then return nil, why end
            return true, ("frames shown: %d; taking clicks: %d (should be 0)"):format(m.rows, m.clicks)
        end },
    { text = "With the character window open, start combat (attack a training dummy) and use something that changes a stat (a haste or crit buff, a trinket). Look at the stat list during combat, then let combat end.\n\n|cffffd100Expect (DECISION to confirm with Xaya):|r during combat the list keeps the numbers it had when combat started; within a moment of combat ending it shows the new numbers. Tell us in the note whether that is what you want, or a refresh every few seconds in combat.",
        noVerdict = true,
        check = function()
            local dbg = Svc("charDisplayDebug")
            if not (dbg and dbg.ListCounts) then return nil, "XayaUI QoL is off or too old (no charDisplayDebug.ListCounts)" end
            local l = dbg.ListCounts()
            return true, ("stat model builds: %d; layouts: %d; waiting for combat to end: %s"):format(l.builds, l.layouts, tostring(l.stale))
        end },
    { done = true, text = "Last step: press |cffffd100Do it for me|r to put Enchants (and its Style), Gems and sockets beside the slots and the Full stat list back as they were before step 1, and turn the Wider window back on if you turned it off. Then press |cffffd100Done|r.",
        setup = function()
            local dbg = Svc("charDisplayDebug")
            local c = dbg and dbg.Cfg and dbg.Cfg()
            if c and keptGate then c.enchants, c.enchantStyle, c.gems, c.statList = keptGate.enchants, keptGate.enchantStyle, keptGate.gems, keptGate.statList; dbg.Apply() end
            keptGate = nil
        end },
} })
