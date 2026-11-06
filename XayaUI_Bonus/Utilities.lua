-------------------------------------------------------------------------------
-- Utilities.lua : the "Utilities" node of the Bonus Features tab (Bonus 0.6.11; Xaya 2026-11-05: "Under bonus features, create
-- "Utilities" Group and nest Notepad and Calculator"). A group in the left pane with its tools as nodes under it, sorted by name like
-- the tab's own pages (#274): Calculator (Calculator.lua) and Notepad (Notepad.lua). Its own page is a short overview of them. It
-- has no on / off of its own, so its row has no tick box; Notepad's row carries the Notepad's on / off (its xuiSwitch; Bonus 0.6.14:
-- the whole feature, "Show Notepad" is on its page). Settings only:
-- nothing here runs outside the settings window, and nothing is created until the window draws the page.
-- Open a tool's page with ns.OpenSettingsPage("bonus", "utilities", "<tool key>").
-------------------------------------------------------------------------------
local _, ns = ...
ns = _G.XayaUI_NS or ns   -- one namespace with XayaUI core (## Dependencies: XayaUI)

function ns.BuildUtilitiesPage(Notify)
    local args = {
        intro = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "Small tools you open when you need them. Pick one on the left." },
    }
    local calc = ns.BuildCalculatorPage and ns.BuildCalculatorPage(Notify) or nil
    if calc then
        calc.order = 1
        args.calculator = calc
        args.calcNote = { type = "description", order = 1, width = "full", fontSize = "medium",
            name = "|cffffd100Calculator|r: a small window with a typed line and a keypad; /xui calc with a sum gives the answer in chat." }
    end
    local notes = ns.BuildNotepadTab and ns.BuildNotepadTab(Notify) or nil
    if notes then
        notes.order = 2
        args.notepad = notes
        args.notesNote = { type = "description", order = 2, width = "full", fontSize = "medium",
            name = "|cffffd100Notepad|r: a floating box for typed reminders, with any number of notes. The tick box next to it on the left turns it on or off." }
    end
    return { type = "group", name = "Utilities", order = 12, childGroups = "tree", args = args }
end

ns.RegisterSettingsPage("bonus", "utilities", ns.BuildUtilitiesPage)
