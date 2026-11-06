-------------------------------------------------------------------------------
-- Utilities.lua : the "Utilities" node of the Bonus Features tab (Bonus 0.6.11; Xaya 2026-11-05: "Under bonus features, create
-- "Utilities" Group and nest Notepad and Calculator"). A group in the left pane with its tools as nodes under it, sorted by name like
-- the tab's own pages (#274): Calculator (Calculator.lua) and Notepad (Notepad.lua). Its own page is a short overview of them. It
-- has no on / off of its own, so its row has no tick box; Notepad's row carries the Notepad's on / off (its xuiSwitch; Bonus 0.6.14:
-- the whole feature, "Show Notepad" is on its page) and Calculator's row the Calculator's (Bonus 0.6.16). Settings only:
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
            name = "|cffffd100Calculator|r: a small window with a typed line and a keypad; /xui calc with a sum gives the answer in chat. The tick box next to it on the left turns it on or off." }
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

-------------------------------------------------------------------------------
-- /notes and /calc (Bonus 0.6.17; Xaya 2026-11-05, CHAT-6: "Is it possible for /notes /calc to be commands that the addon recognizes
-- and accepts in the console to open the notes and calculator respectively?"). Exactly those two words; /xui notes and /xui calc stay.
--   - A word is claimed only if nothing else has it when we register: every SLASH_<KEY><n> word of SlashCmdList and SecureCmdList
--     (Blizzard's own commands and every loaded addon's) and the chat box's cache hash_SlashCmdList are looked at first. Taken: we
--     leave it alone and /xui notes / /xui calc still work. Registration runs once the player is in the world (ns.WhenReady), after
--     every addon that loads at login has registered its own words. INFERENCE (Blizzard's chat-box source not read in this repo):
--     the game resolves a typed word through those tables; an addon that loads later on demand and takes the same word is not seen.
--   - V14: /notes is registered only while the Notepad is on (at login when saved on, or when it is ticked on). Once registered the
--     game has no way to take a slash word back from its cache, so after the Notepad is turned off /notes stays until /reload and
--     only prints the same "Notepad is off" line as /xui notes; it builds nothing. /calc is always registered (when free) and does
--     exactly what /xui calc does: the Calculator's tick box (Bonus 0.6.16) turns off only the window (Xaya 2026-11-06, S7-2: "If no,
--     just the window"), so with it off /calc alone says it is off and /calc <sum> still answers in chat.
-------------------------------------------------------------------------------
local function WordTaken(word)
    word = word:lower()
    local hash = rawget(_G, "hash_SlashCmdList")
    if type(hash) == "table" and (hash[word] or hash[word:upper()]) then return true end
    for _, list in ipairs({ rawget(_G, "SlashCmdList"), rawget(_G, "SecureCmdList") }) do
        if type(list) == "table" then
            for key in pairs(list) do
                local i = 1
                while true do
                    local w = rawget(_G, "SLASH_" .. tostring(key) .. i)
                    if type(w) ~= "string" then break end
                    if w:lower() == word then return true end
                    i = i + 1
                end
            end
        end
    end
    return false
end

local claimed = {}   -- key -> true once we hold the word
local function Claim(key, word, fn)
    if claimed[key] then return true end
    local list = rawget(_G, "SlashCmdList")
    if type(list) ~= "table" or WordTaken(word) then return false end
    _G["SLASH_" .. key .. "1"] = word
    list[key] = fn
    claimed[key] = true
    return true
end

local function NotesOn() local d = ns.notepadDB; return (d and d.enabled ~= false) and true or false end

-- called at login and whenever the Notepad's on / off changes (Notepad.lua ns.Notepad_SetEnabled)
function ns.Utilities_SyncSlash()
    if ns.Calculator_Command then Claim("XUICALC", "/calc", function(msg) ns.Calculator_Command(msg) end) end
    if NotesOn() and ns.Notepad_Toggle then Claim("XUINOTES", "/notes", function() ns.Notepad_Toggle() end) end
end
function ns.Utilities_SlashClaimed(key) return claimed[key] == true end   -- (tests, and the settings text)

ns.WhenReady(function() ns.Utilities_SyncSlash() end)
