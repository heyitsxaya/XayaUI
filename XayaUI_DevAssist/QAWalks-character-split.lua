-------------------------------------------------------------------------------
-- QAWalks-character-split.lua (XayaUI_DevAssist 0.7.70): the in-game walkthrough for the character pane split
-- (docs/plans/PLATFORM-SPLIT-2026-11-07.md section 4.2; Xaya's Q5 answer, PS-53, PS-54; QA E1z227).
-- Standing rule V22 (Xaya 2026-11-07): every step the addon can judge offers its verdict (prefill = true; recorded only on her click);
-- where it cannot judge, the check captures what it reads into the step's note.
--   Stage 1 (QoL 0.7.53, C20): the character window's features (item level, enchants, gems, the full stat list) are QoL's (QoL >
--   Character Pane) and show with XayaUI Blizzard Reskin off; the reskin (Blizzard Reskin > Character Pane) only changes the look.
-- Reaches XayaUI QoL only through core's services ("characterReskin"). UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end

local function NS() return rawget(_G, "XayaUI_NS") end
local function Svc(n) local ns = NS(); return ns and ns.Service and ns.Service(n) end
local function WindowShown() local cf = rawget(_G, "CharacterFrame"); return (type(cf) == "table" and cf.IsShown and cf:IsShown()) and true or false end
-- what the character window shows now (QoL's own count of its pieces), or nil and why not
local function Drawn()
    local s = Svc("characterReskin")
    if not (s and s.Drawn) then return nil, "XayaUI QoL is off or older than 0.7.53 (no character pane count)" end
    local ok, d = pcall(s.Drawn)
    if not ok or type(d) ~= "table" then return nil, "the count failed: " .. tostring(d) end
    return d
end
local function Line(d)
    return ("item levels on %d slots, enchants on %d, gems / sockets %d, full stat list %s; reskin look %s (Blizzard Reskin %s, its tab %s, %d regions faded); QoL > Character Pane %s"):format(
        d.ilvl, d.enchants, d.sockets, d.statList and "shown" or "not shown", d.look and "on" or "off", d.reskinLoaded and "loaded" or "off",
        d.tabOn and "on" or "off", d.faded, d.features and "on" or "off")
end

QA.Register("character-split", { title = "Character pane split: the item level, enchants and stat list are QoL's, the reskin is the look (E1z227)", area = "QoL", qa = "E1z227", order = 521, prefill = true, steps = {
    { text = "Switch XayaUI Blizzard Reskin off: untick it in the AddOns list (or untick |cffffd100Enable Blizzard Reskin|r on Blizzard Reskin > Overview), then |cffffd100/reload|r. QoL > Character Pane ticked (it starts ticked if your Character Pane reskin was on). Open the character window (C) with your gear on.\n\n|cffffd100Expect:|r an item level on each slot, the enchant (or \"No enchant\") and the gems beside the slots, the full stat list in the stats pane, and Blizzard's own window art (no reskin).",
        check = function()
            local d, why = Drawn()
            if not d then return nil, why end
            if d.reskinLoaded and d.tabOn then return nil, "Blizzard Reskin is still on: switch it off, /reload, then check again | " .. Line(d) end
            if not d.features then return nil, "QoL > Character Pane is off: tick it, then check again | " .. Line(d) end
            if not WindowShown() then return nil, "open the character window (C), then check again | " .. Line(d) end
            return (d.ilvl > 0 and not d.look) and true or false, Line(d)
        end },
    { text = "Now the other way round: switch XayaUI Blizzard Reskin on again (and its Character Pane tick box), untick |cffffd100QoL > Character Pane|r, |cffffd100/reload|r and open the character window.\n\n|cffffd100Expect:|r only the look changes (the clean window, theme colours); no item level, enchant, gem or full stat list of XayaUI's.",
        check = function()
            local d, why = Drawn()
            if not d then return nil, why end
            if not d.look then return nil, "the Character Pane reskin is not on: tick Blizzard Reskin > Character Pane (and Blizzard Reskin itself), /reload | " .. Line(d) end
            if d.features then return nil, "QoL > Character Pane is still ticked: untick it, then check again | " .. Line(d) end
            if not WindowShown() then return nil, "open the character window (C), then check again | " .. Line(d) end
            return (d.ilvl == 0 and d.enchants == 0 and d.sockets == 0 and not d.statList) and true or false, Line(d)
        end },
    { text = "Tick |cffffd100QoL > Character Pane|r again (no reload needed) with the window open.\n\n|cffffd100Expect:|r the item levels, enchants, gems and the full stat list come back over the reskinned window, as before this version.",
        check = function()
            local d, why = Drawn()
            if not d then return nil, why end
            if not d.features then return nil, "QoL > Character Pane is off: tick it | " .. Line(d) end
            if not WindowShown() then return nil, "open the character window (C) | " .. Line(d) end
            return (d.ilvl > 0) and true or false, Line(d)
        end },
    { done = true, text = "Press |cffffd100Done|r." },
} })
