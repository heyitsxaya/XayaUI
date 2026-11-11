-------------------------------------------------------------------------------
-- QAWalks-chardisplay-fixes.lua (XayaUI Dev Assist): the in-game walkthrough for the Improved Character Display / Character Reskin fixes
-- of 2026-11-10 (XayaUI QoL, ImprovedCharacterDisplay.lua and CharacterReskin.lua; docs/plans/STAT-CALCULATOR-REVIEW-2026-11-10.md
-- SC-069 / SC-103): (a) a slot mark that cannot show because the matching "beside the slots" option already shows the same thing is
-- greyed, unticked, and its hover names the option to turn off, and Text size is greyed while no mark can show; (b) the Character Reskin's stat list toggle is "Stat list colors", so it
-- is not confused with Improved Character Display's Stat list page. Standing rule V22 (Xaya 2026-11-07, her words): "make sure every
-- feature or significant change to the codebase / bug report fixes have an in game qa test walk through with pre-fill confirmation
-- options or data capturing". prefill = true: where the addon can read the result its verdict is offered on one button and recorded only
-- on a click (QAWalk.lua); a step marked noVerdict asks something only the person can see.
-- Reads the settings pages as the settings window builds them (core's ns.BuildSettingsPages: the same tables, their disabled / get /
-- desc functions) and reaches XayaUI QoL only through core's "charDisplayDebug" service (its settings and Apply). Building the QoL pages
-- here runs Improved Character Display's page builder, which takes its once-per-reload "first options-window open" read of the Stat
-- Calculator tie-in (Xaya A24 #6) at walkthrough time instead of at the settings window's first open; Dev Assist only, harmless. What "Do it for me"
-- changes (Item level on each slot, Enchants and Gems beside the slots, Slot overlays) is remembered and put back by the last step. Nothing here takes the keyboard, the
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
-- a control on QoL > Improved Character Display > Slot Overlays > Show (default: the "Item level" tick box)
local function IlvlBox(key)
    local p, why = Page("qol", "chardisplay")
    if not p then return nil, why end
    local op = p.args and p.args.overlayPart
    local box = op and op.args and op.args.show and op.args.show.args and op.args.show.args[key or "ovIlvl"]
    if type(box) ~= "table" then return nil, "no Slot Overlays > Show > " .. tostring(key or "ovIlvl") .. " on the page" end
    return box
end

local kept   -- step 1: { ilvl, overlays, enchants, gems } as they were
QA.Register("chardisplay-fixes", { title = "Improved Character Display: a slot mark that cannot show is greyed with the reason; Character Reskin's \"Stat list colors\" (SC-069, SC-103)",
    area = "QoL", qa = "E1z235, E1z236", order = 527, prefill = true, steps = {
    { text = "Tick |cffffd100QoL > Improved Character Display|r if it is not ticked. Then press |cffffd100Do it for me|r: XayaUI remembers two of its settings, then ticks |cffffd100Item level on each slot|r and the |cffffd100Slot overlays|r row.\n\n|cffffd100Expect:|r on QoL > Improved Character Display > Slot Overlays > Show, the |cffffd100Item level|r tick box is greyed and unticked (the item level already shows on each slot, so the mark would add nothing).",
        setup = function()
            local dbg = Svc("charDisplayDebug")
            local c = dbg and dbg.Cfg and dbg.Cfg()
            if not c then error("XayaUI QoL is off") end
            if not c.enabled then error("tick QoL > Improved Character Display first") end
            if not kept then kept = { ilvl = c.ilvl, overlays = c.overlays, enchants = c.enchants, gems = c.gems } end
            c.ilvl, c.overlays = true, true
            dbg.Apply()
        end,
        check = function()
            local box, why = IlvlBox()
            if not box then return nil, why end
            local dis, tick, hover = V(box.disabled) == true, V(box.get) == true, tostring(V(box.desc) or "")
            local ok = dis and not tick and hover:find("Item level on each slot", 1, true) ~= nil
            return ok, ("Item level box: %s, %s; its hover: %s"):format(dis and "greyed" or "NOT greyed", tick and "ticked" or "unticked", Short(hover))
        end },
    { text = "Open the settings window (|cffffd100/xui|r), go to QoL > Improved Character Display > Slot Overlays > Show, and hover the greyed |cffffd100Item level|r tick box.\n\n|cffffd100Expect:|r the hover says it is greyed because \"Item level on each slot\" already shows this, and to turn it off to use this mark. The note below shows the text XayaUI gives the window.",
        noVerdict = true,
        check = function()
            local box, why = IlvlBox()
            if not box then return nil, why end
            return true, "hover text given: " .. Short(V(box.desc), 200)
        end },
    { text = "Press |cffffd100Do it for me|r: XayaUI also ticks |cffffd100Enchants beside the slots|r and |cffffd100Gems and sockets beside the slots|r (the defaults), so none of the three slot marks can show.\n\n|cffffd100Expect:|r on Slot Overlays > Show, |cffffd100Text size|r is greyed as well, and its hover says no mark above shows on the slots.",
        setup = function()
            local dbg = Svc("charDisplayDebug")
            local c = dbg and dbg.Cfg and dbg.Cfg()
            if not c then error("XayaUI QoL is off") end
            c.enchants, c.gems = true, true
            dbg.Apply()
        end,
        check = function()
            local sz, why = IlvlBox("ovSize")
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
    { done = true, text = "Last step: press |cffffd100Do it for me|r to put Item level on each slot, Enchants beside the slots, Gems and sockets beside the slots and Slot overlays back as they were before step 1. Then press |cffffd100Done|r.",
        setup = function()
            local dbg = Svc("charDisplayDebug")
            local c = dbg and dbg.Cfg and dbg.Cfg()
            if c and kept then c.ilvl, c.overlays, c.enchants, c.gems = kept.ilvl, kept.overlays, kept.enchants, kept.gems; dbg.Apply() end
            kept = nil
        end },
} })
