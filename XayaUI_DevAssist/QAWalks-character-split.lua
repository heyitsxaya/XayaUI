-------------------------------------------------------------------------------
-- QAWalks-character-split.lua (XayaUI_DevAssist 0.7.70): the in-game walkthrough for the character pane split
-- (docs/plans/PLATFORM-SPLIT-2026-11-07.md section 4.2; Xaya's Q5 answer, PS-53, PS-54; QA E1z227).
-- Standing rule V22 (Xaya 2026-11-07): every step the addon can judge offers its verdict (prefill = true; recorded only on her click);
-- where it cannot judge, the check captures what it reads into the step's note.
--   Stage 1 (QoL 0.7.53, C20): the character window's features (item level, enchants, gems, the full stat list) are QoL's (QoL >
--   Character Pane) and show with XayaUI Blizzard Reskin off; the reskin (Blizzard Reskin > Character Pane) only changes the look.
--   Stage 2 (Bonus 0.6.37): the Stat Calculator's panel ("the Advanced Character Stats pane window", her Q5) is XayaUI Bonus Features'
--   (Bonus Features > Character Toolkit); its settings were copied once from XayaUIQoLDB.characterToolkit (copy, never move).
--   Stage 3: the one model stays XayaUI QoL's (the "statModel" service); with XayaUI QoL off, Bonus Features shows nothing extra.
-- Reaches XayaUI QoL and XayaUI Bonus Features only through core's services ("characterReskin", "statCalc", "statModel") and settings
-- views (ns.Settings, ns.SettingsKeyMove). UNTESTED IN GAME.
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

QA.Register("character-split", { title = "Character pane split: the item level, enchants and stat list are QoL's, the reskin is the look, the Stat Calculator is Bonus's (E1z227, F30)", area = "QoL", qa = "E1z227, F30", order = 521, prefill = true, steps = {
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
    { text = "The Stat Calculator (the advanced character stats window) is in |cffffd100Bonus Features > Character Toolkit|r now. With XayaUI QoL and XayaUI Bonus Features on, press |cffffd100Do it for me|r: it opens on its Stats tab (the same as the |cffffd100Stat Calc|r button on the character window or |cffffd100/xui stats|r).\n\n|cffffd100Expect:|r the panel opens and fills in, as before this version. If Character Toolkit is off there, tick it first.",
        setup = function() local sc = Svc("statCalc"); if sc and sc.Open then sc.Open("stats") end end,
        check = function()
            local sc = Svc("statCalc")
            if not sc then return nil, "XayaUI Bonus Features is off or older than 0.6.37 (no Stat Calculator service)" end
            if not Svc("statModel") then return nil, "XayaUI QoL is off: the Stat Calculator needs it (its model)" end
            local c = sc.Cfg and sc.Cfg()
            if not (c and c.enabled) then return nil, "Bonus Features > Character Toolkit is off: tick it, then press Do it for me" end
            if not c.panel then return nil, "Bonus Features > Character Toolkit > Panel is off: tick it, then press Do it for me" end
            local shown = sc.Shown and sc.Shown()
            return shown and true or false, ("panel %s; tab %s; side %s; text size %s"):format(shown and "open" or "not open", tostring(c.tab), tostring(c.side), tostring(c.fontSize))
        end },
    { text = "Nothing to do: the check reads where the Stat Calculator's settings came from and compares them, Bonus Features' copy against the old copy XayaUI QoL keeps (copy, never move).\n\n|cffffd100Expect:|r \"copied from XayaUIQoLDB.characterToolkit\" with the version and the day; in the session the copy was made every compared value is the same. In a later session a setting you changed since is meant to differ: the check then lists the values with no verdict.",
        check = function()
            local ns = NS()
            if not (ns and ns.SettingsKeyMove and ns.Settings) then return nil, "XayaUI is older than 0.6.83 (no record of the copy)" end
            local rec, now = ns.SettingsKeyMove("characterToolkit")
            local B, Q = ns.Settings("bonus").characterToolkit, ns.Settings("qol").characterToolkit
            if type(B) ~= "table" then return nil, "Bonus Features has no Stat Calculator settings yet (XayaUI QoL or Bonus Features off, or a new install)" end
            local keys = { "enabled", "panel", "side", "fontSize", "opacity", "heightSmall", "heightLarge", "tab", "gearSumStyle", "advanced" }
            local same, diff, vals = 0, {}, {}
            for _, k in ipairs(keys) do
                local new, old = B[k], type(Q) == "table" and Q[k] or nil
                vals[#vals + 1] = k .. " " .. tostring(old) .. "/" .. tostring(new)
                if old ~= nil and old == new then same = same + 1 elseif old ~= nil then diff[#diff + 1] = k end
            end
            local spells = ("spells %d/%d"):format(type(Q) == "table" and type(Q.spells) == "table" and #Q.spells or 0, type(B.spells) == "table" and #B.spells or 0)
            local where = rec and ("copied from %s by %s on %s (%s keys)"):format(tostring(rec.migratedFrom), tostring(rec.migratedBy), tostring(rec.migratedAt), tostring(rec.migratedKeys)) or "no copy recorded (a new install: nothing to copy)"
            local note = where .. " | old/new: " .. table.concat(vals, ", ") .. ", " .. spells
            if not rec then return nil, note end
            if not now then return nil, "the copy was made in an earlier session (settings may have changed since) | " .. note end
            return #diff == 0, (#diff == 0 and "every compared value the same | " or ("differ: " .. table.concat(diff, ", ") .. " | ")) .. note
        end },
    { text = "Untick |cffffd100XayaUI QoL|r in the AddOns list (keep XayaUI Bonus Features ticked), |cffffd100/reload|r, then open Bonus Features in the settings window and type |cffffd100/xui stats|r.\n\n|cffffd100Expect:|r no Character Toolkit page in Bonus Features, /xui stats is not a command, no Stat Calculator row in the minimap button's list, no Lua error. Tick XayaUI QoL again afterwards.",
        check = function()
            local ns = NS()
            if not ns then return nil, "XayaUI is not loaded" end
            if Svc("statModel") then return nil, "XayaUI QoL is still on: untick it in the AddOns list, /reload, then check again" end
            if not Svc("statCalc") then return nil, "XayaUI Bonus Features is off too: keep it on for this step" end
            local pages = ns.BuildSettingsPages and ns.BuildSettingsPages("bonus") or {}
            local row = false
            for _, e in ipairs(ns.Launchers and ns.Launchers() or {}) do if e[1] == "stats" then row = true end end
            local errs = 0
            for _, e in ipairs(ns.ErrorEntries and ns.ErrorEntries() or {}) do if tostring(e.msg):find("XayaUI_Bonus", 1, true) then errs = errs + 1 end end
            local ok = pages.statcalc == nil and not row and errs == 0
            return ok, ("Character Toolkit page %s; Stat Calculator row %s; saved errors naming XayaUI_Bonus: %d"):format(pages.statcalc and "there" or "not there", row and "there" or "not there", errs)
        end },
    { done = true, text = "Tick |cffffd100XayaUI QoL|r again in the AddOns list if you unticked it, then press |cffffd100Done|r." },
} })
