-------------------------------------------------------------------------------
-- QAWalks-character-split.lua (XayaUI_DevAssist 0.7.70): the in-game walkthrough for the character pane split
-- (docs/plans/PLATFORM-SPLIT-2026-11-07.md section 4.2; Xaya's Q5 answer, PS-53, PS-54; QA E1z227).
-- Standing rule V22 (Xaya 2026-11-07): every step the addon can judge offers its verdict (prefill = true; recorded only on her click);
-- where it cannot judge, the check captures what it reads into the step's note.
--   Stage 1 (QoL 0.7.53, C20): the character window's features (item level, enchants, gems, the full stat list) are QoL's (QoL >
--   Improved Character Display since V25 R2) and show with XayaUI Blizzard Reskin off; the reskin (Blizzard Reskin > Character Reskin)
--   only changes the look.
--   Stage 2 (Bonus 0.6.37): the Stat Calculator's panel ("the Advanced Character Stats pane window", her Q5) is XayaUI Bonus Features'
--   (Bonus Features > Stat Calculator); its settings were copied once from XayaUIQoLDB.characterToolkit (copy, never move).
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
    return ("item levels on %d slots, enchants on %d, gems / sockets %d, full stat list %s; reskin look %s (Blizzard Reskin %s, its tab %s, %d regions faded); QoL > Improved Character Display %s"):format(
        d.ilvl, d.enchants, d.sockets, d.statList and "shown" or "not shown", d.look and "on" or "off", d.reskinLoaded and "loaded" or "off",
        d.tabOn and "on" or "off", d.faded, d.features and "on" or "off")
end

QA.Register("character-split", { title = "Character window split: the item level, enchants and stat list are QoL's (Improved Character Display), the reskin is the look, the Stat Calculator is Bonus's (E1z227, F30)", area = "QoL", qa = "E1z227, F30", order = 521, prefill = true, steps = {
    { text = "Switch XayaUI Blizzard Reskin off: untick it in the AddOns list (or untick |cffffd100Enable Blizzard Reskin|r on Blizzard Reskin > Overview), then |cffffd100/reload|r. QoL > Improved Character Display ticked, with Item level, Enchants, Gems and Full stat list ticked. Open the character window (C) with your gear on.\n\n|cffffd100Expect:|r an item level on each slot, the enchant (or \"No enchant\") and the gems beside the slots, the full stat list in the stats pane, and Blizzard's own window art (no reskin).",
        check = function()
            local d, why = Drawn()
            if not d then return nil, why end
            if d.reskinLoaded and d.tabOn then return nil, "Blizzard Reskin is still on: switch it off, /reload, then check again | " .. Line(d) end
            if not d.features then return nil, "QoL > Improved Character Display is off: tick it, then check again | " .. Line(d) end
            if not WindowShown() then return nil, "open the character window (C), then check again | " .. Line(d) end
            return (d.ilvl > 0 and not d.look) and true or false, Line(d)
        end },
    { text = "Now the other way round: switch XayaUI Blizzard Reskin on again (and its Character Reskin tick box), untick |cffffd100QoL > Improved Character Display|r, |cffffd100/reload|r and open the character window.\n\n|cffffd100Expect:|r only the look changes (the clean window, theme colors); no item level, enchant, gem or full stat list of XayaUI's.",
        check = function()
            local d, why = Drawn()
            if not d then return nil, why end
            if not d.look then return nil, "the Character Reskin is not on: tick Blizzard Reskin > Character Reskin (and Blizzard Reskin itself), /reload | " .. Line(d) end
            if d.features then return nil, "QoL > Improved Character Display is still ticked: untick it, then check again | " .. Line(d) end
            if not WindowShown() then return nil, "open the character window (C), then check again | " .. Line(d) end
            return (d.ilvl == 0 and d.enchants == 0 and d.sockets == 0 and not d.statList) and true or false, Line(d)
        end },
    { text = "Tick |cffffd100QoL > Improved Character Display|r again (no reload needed) with the window open.\n\n|cffffd100Expect:|r the item levels, enchants, gems and the full stat list come back over the reskinned window, as before this version.",
        check = function()
            local d, why = Drawn()
            if not d then return nil, why end
            if not d.features then return nil, "QoL > Improved Character Display is off: tick it | " .. Line(d) end
            if not WindowShown() then return nil, "open the character window (C) | " .. Line(d) end
            return (d.ilvl > 0) and true or false, Line(d)
        end },
    { text = "The Stat Calculator (the advanced character stats window) is in |cffffd100Bonus Features > Stat Calculator|r now. With XayaUI QoL and XayaUI Bonus Features on, press |cffffd100Do it for me|r: it opens on its Stats tab (the same as the |cffffd100Stat Calc|r button on the character window or |cffffd100/xui stats|r).\n\n|cffffd100Expect:|r the panel opens and fills in, as before this version. If Stat Calculator is off there, tick it first.",
        setup = function() local sc = Svc("statCalc"); if sc and sc.Open then sc.Open("stats") end end,
        check = function()
            local sc = Svc("statCalc")
            if not sc then return nil, "XayaUI Bonus Features is off or older than 0.6.37 (no Stat Calculator service)" end
            if not Svc("statModel") then return nil, "XayaUI QoL is off: the Stat Calculator needs it (its model)" end
            local c = sc.Cfg and sc.Cfg()
            if not (c and c.enabled) then return nil, "Bonus Features > Stat Calculator is off: tick it, then press Do it for me" end
            if not c.panel then return nil, "Bonus Features > Stat Calculator > Panel is off: tick it, then press Do it for me" end
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
    { text = "Untick |cffffd100XayaUI QoL|r in the AddOns list (keep XayaUI Bonus Features ticked), |cffffd100/reload|r, then open Bonus Features in the settings window and type |cffffd100/xui stats|r.\n\n|cffffd100Expect:|r no Stat Calculator page in Bonus Features, /xui stats is not a command, no Stat Calculator row in the minimap button's list, no Lua error. Tick XayaUI QoL again afterwards.",
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
            return ok, ("Stat Calculator page %s; Stat Calculator row %s; saved errors naming XayaUI_Bonus: %d"):format(pages.statcalc and "there" or "not there", row and "there" or "not there", errs)
        end },
    { done = true, text = "Tick |cffffd100XayaUI QoL|r again in the AddOns list if you unticked it, then press |cffffd100Done|r." },
} })

-------------------------------------------------------------------------------
-- Stat Calculator V25 step R4 (Bonus 0.6.39, QoL 0.7.56): the extra lines on the character window's own stat tooltips moved from XayaUI
-- QoL (Improved Character Display's part "Tooltip lines") to Bonus Features > Enhanced Tooltips > Character stats, OFF by default, and
-- only while Enhanced Tooltips and Improved Character Display are both on (Xaya, REQUEST-LOG A24 #5 / #6). Method notes show only while
-- XayaUI Dev Assist is loaded (A22 #15), so in this walkthrough (Dev Assist is on) they show; the next threshold in words always shows (A8). Reached through the "tooltipsDebug" service only.
-- UNTESTED IN GAME.
-------------------------------------------------------------------------------
local function TTs() local s = Svc("tooltipsDebug"); return s and s.TT end
local function StatLinesState()
    local TT = TTs()
    if not (TT and TT.CharStatsWanted and TT.charStatsState) then return nil, "XayaUI Bonus Features is off or older than 0.6.39 (no Character stats option)" end
    local db = TT.DB and TT.DB() or {}
    local cs = TT.charStatsState
    return { et = db.enabled ~= false, ticked = db.charStats == true, icd = cs.icdOn == true, read = cs.read == true, hooked = cs.hooked == true,
        on = TT.charStatsOn == true }, nil, TT
end
local function StatLine(s)
    return ("Enhanced Tooltips %s; Character stats %s; Improved Character Display %s (as last read or told); tie-ins read %s; hooks placed %s; lines %s"):format(
        s.et and "on" or "off", s.ticked and "ticked" or "unticked", s.icd and "on" or "off", s.read and "yes" or "no", s.hooked and "yes" or "no", s.on and "on" or "off")
end
QA.Register("character-stat-lines", { title = "Character window stat tooltips: the XayaUI lines are Enhanced Tooltips' option now, off by default (V25 R4, E1z64)", area = "Bonus", qa = "E1z64", order = 522, prefill = true, steps = {
    { text = "Nothing to do on a fresh install (or one where you never ticked it): |cffffd100/reload|r first if you changed anything below in this session.\n\n|cffffd100Expect:|r |cffffd100Bonus Features > Enhanced Tooltips > Character stats|r exists and is unticked; QoL > Improved Character Display has no Tooltip lines row any more; hovering a stat in the character window (C) shows Blizzard's tooltip only.",
        check = function()
            local s, why = StatLinesState()
            if not s then return nil, why end
            if s.ticked then return nil, "Character stats is ticked (you ticked it before): this step checks the default | " .. StatLine(s) end
            return (not s.hooked and not s.on) and true or false, StatLine(s)
        end },
    { text = "Make sure |cffffd100QoL > Improved Character Display|r is ticked and |cffffd100Enhanced Tooltips|r is ticked (its row in Bonus Features). Tick |cffffd100Bonus Features > Enhanced Tooltips > Character stats|r. Open the character window (C) and hover |cffffd100Critical Strike|r in its stats.\n\n|cffffd100Expect:|r under Blizzard's text a \"XayaUI\" block: Rating, Rating per 1%, Diminishing returns and what it feeds (» lines). The diminishing returns line ends with the next threshold in words (for everyone); with Dev Assist on (as now) the other notes follow their values too, without it they are left out.",
        check = function()
            local s, why, TT = StatLinesState()
            if not s then return nil, why end
            if not s.et then return nil, "Enhanced Tooltips is off: tick its row, then check again | " .. StatLine(s) end
            if not s.ticked then return nil, "Character stats is unticked: tick it, then check again | " .. StatLine(s) end
            if not s.icd then return nil, "Improved Character Display is off (or XayaUI QoL is): tick QoL > Improved Character Display, then check again | " .. StatLine(s) end
            local label = rawget(_G, "STAT_CRITICAL_STRIKE") or "Critical Strike"
            local ok, lines = pcall(TT.CharStatLines, label)
            local got = {}
            for i, l in ipairs(ok and lines or {}) do if i <= 4 then got[#got + 1] = tostring(l[1]) .. (l[2] and (" " .. tostring(l[2])) or "") end end
            -- the verdict: the lines are switched on and hooked; the crit lines are captured for her to compare with what she sees
            return (s.on and s.hooked) and true or false, StatLine(s) .. " | crit lines: " .. (#got > 0 and table.concat(got, "; ") or "none")
        end },
    { text = "Untick |cffffd100QoL > Improved Character Display|r (keep Character stats ticked) and hover Critical Strike again.\n\n|cffffd100Expect:|r Blizzard's tooltip only, at once (no reload); Character stats shows greyed with a line saying it needs Improved Character Display (it may need the settings window closed and opened again to grey). Tick Improved Character Display again afterwards.",
        check = function()
            local s, why = StatLinesState()
            if not s then return nil, why end
            if not s.ticked then return nil, "Character stats is unticked: tick it for this step | " .. StatLine(s) end
            if s.icd then return nil, "Improved Character Display is still on: untick it, then check again | " .. StatLine(s) end
            return (not s.on) and true or false, StatLine(s)
        end },
    { text = "Your look: with Character stats ticked, hover a few stats (Haste, Mastery, your main stat). Are the XayaUI lines short and useful? Pass if yes; Fail and say which lines to change.", noVerdict = true },
    { done = true, text = "Leave Character stats ticked or unticked as you like, then press |cffffd100Done|r." },
} })

-------------------------------------------------------------------------------
-- Stat Calculator V25 (QoL 0.7.56, Bonus 0.6.39): QoL > Improved Character Display (Xaya, REQUEST-LOG A24 #3-#6): one page and one
-- switch for everything XayaUI changes on the character window: the one-time merge of the old switches at the update, the Stat Calc
-- button (its own tick box; it calls the Stat Calculator through its service) and the slot marks. QA E1z228. Reached through the
-- "charDisplay" and "statCalc" services and the settings view only. UNTESTED IN GAME.
-------------------------------------------------------------------------------
local function ICD()
    local s = Svc("charDisplay")
    if not (s and s.Drawn) then return nil, "XayaUI QoL is off or older than 0.7.56 (no Improved Character Display)" end
    local ok, d = pcall(s.Drawn)
    if not ok or type(d) ~= "table" then return nil, "the count failed: " .. tostring(d) end
    local ns = NS()
    local q = ns and ns.Settings and ns.Settings("qol") or {}
    local p, t = type(q.characterReskin) == "table" and q.characterReskin or {}, type(q.characterToolkit) == "table" and q.characterToolkit or {}
    -- (A24 #7) the Slot Overlays are gone: one Item level and one Enchants option, each with a style ("On the slot" / "Beside the slot")
    local function Style(v, beside) if v == beside then return "beside the slot" end; return "on the slot" end
    d.on, d.merged, d.btnSwitch = p.features == true, p._merged == true, t.statCalcButton ~= false
    d.ilvlOn, d.enchOnSlot = p.ilvl == true, p.enchants == true and t.enchantStyle == "slot"
    d.parts = ("item level %s (%s), enchants %s (%s), gems %s, full stat list %s, empty sockets mark %s"):format(tostring(p.ilvl),
        Style(t.ilvlStyle, "beside"), tostring(p.enchants), t.enchantStyle == "slot" and "on the slot" or "beside the slot", tostring(p.gems),
        tostring(p.statList), tostring(t.socketMark == true))
    return d
end
local function ICDLine(d)
    return ("Improved Character Display %s (merge done: %s); parts: %s; Stat Calc button tick box %s, button %s; slot marks on %d slots; item levels on %d slots"):format(
        d.on and "on" or "off", d.merged and "yes" or "no", d.parts, d.btnSwitch and "ticked" or "unticked", d.button and "shown" or "hidden", d.marks or 0, d.ilvl or 0)
end
local function PanelReady()
    local sc = Svc("statCalc")
    if not sc then return nil, "XayaUI Bonus Features is off: the Stat Calc button needs the Stat Calculator" end
    local c = sc.Cfg and sc.Cfg()
    if not (c and c.enabled and c.panel) then return nil, "Bonus Features > Stat Calculator (and its Panel) is off: tick both" end
    return sc
end
QA.Register("improved-character-display", { title = "Improved Character Display: one page and switch for the character window, the Stat Calc button, the slot marks (V25, E1z228)", area = "QoL", qa = "E1z228", order = 523, prefill = true, steps = {
    { text = "Nothing to do: the check reads what the update did with your old switches (QoL > Character Pane and the slot marks' page are now one page, |cffffd100QoL > Improved Character Display|r).\n\n|cffffd100Expect:|r the merge is done; Improved Character Display is on if anything of it showed on your character window before the update (item levels, enchants, gems, the full stat list, the slot marks or the Stat Calc button), and each part that did not show is off. The check lists what it reads; the next step asks you.",
        check = function()
            local d, why = ICD()
            if not d then return nil, why end
            return nil, ICDLine(d)
        end },
    { text = "Open the character window (C). Does it show what it showed before the update (no part appeared or went away)? Pass if yes; Fail and say what changed.", noVerdict = true },
    { text = "Tick |cffffd100QoL > Improved Character Display|r and its |cffffd100Stat Calc button|r tick box; tick |cffffd100Bonus Features > Stat Calculator|r and its |cffffd100Panel|r. Open the character window (C) out of combat.\n\n|cffffd100Expect:|r the |cffffd100Stat Calc|r button in the window's title row; a click opens and closes the Stat Calculator beside the window.",
        check = function()
            local d, why = ICD()
            if not d then return nil, why end
            local sc, why2 = PanelReady()
            if not sc then return nil, why2 .. " | " .. ICDLine(d) end
            if not d.on then return nil, "Improved Character Display is off: tick it | " .. ICDLine(d) end
            if not d.btnSwitch then return nil, "the Stat Calc button tick box is unticked: tick it | " .. ICDLine(d) end
            if not WindowShown() then return nil, "open the character window (C), then check again | " .. ICDLine(d) end
            return d.button == true, ICDLine(d)
        end },
    { text = "Untick the |cffffd100Stat Calc button|r tick box (Improved Character Display stays ticked) with the window open.\n\n|cffffd100Expect:|r the button goes at once; the Stat Calculator still opens from the minimap button or |cffffd100/xui stats|r. Tick it again afterwards if you want the button.",
        check = function()
            local d, why = ICD()
            if not d then return nil, why end
            if d.btnSwitch then return nil, "the Stat Calc button tick box is still ticked: untick it | " .. ICDLine(d) end
            return d.button == false, ICDLine(d)
        end },
    { text = "On QoL > Improved Character Display, tick |cffffd100Item level|r and |cffffd100Enchants|r and set the Enchants |cffffd100Style|r to |cffffd100On the slot|r. Open the character window (C) with your gear on.\n\n|cffffd100Expect:|r an item level on each item slot and E? / E at the top of the enchant slots you ticked (Improved Character Display > Enchant Slots).",
        check = function()
            local d, why = ICD()
            if not d then return nil, why end
            if not d.on then return nil, "Improved Character Display is off: tick it | " .. ICDLine(d) end
            if not d.ilvlOn then return nil, "Item level is unticked: tick it | " .. ICDLine(d) end
            if not d.enchOnSlot then return nil, "Enchants is unticked or its Style is Beside the slot: tick it and pick On the slot | " .. ICDLine(d) end
            if not WindowShown() then return nil, "open the character window (C), then check again | " .. ICDLine(d) end
            return (d.marks or 0) > 0 and (d.ilvl or 0) > 0, ICDLine(d)
        end },
    { done = true, text = "Leave the parts as you like them, then press |cffffd100Done|r." },
} })

-------------------------------------------------------------------------------
-- Stat Calculator V26 combat lock (Bonus 0.6.39, QoL 0.7.56; Xaya, REQUEST-LOG A24 #2 "Stat calculator unavailable in combat; character
-- pane openable in combat" and #3 "Hide silently"): in combat the Stat Calculator panel and the Stat Calc button are hidden with no
-- message and nothing opens the panel; after combat both come back as they would otherwise be. QA E1z229. UNTESTED IN GAME.
-------------------------------------------------------------------------------
local function InCombat() local f = rawget(_G, "InCombatLockdown"); return (type(f) == "function" and f()) and true or false end
local function CombatLine(sc, d)
    return ("in combat %s; character window %s; Stat Calculator panel %s; Stat Calc button %s"):format(InCombat() and "yes" or "no",
        WindowShown() and "open" or "closed", (sc and sc.Shown and sc.Shown()) and "shown" or "hidden", (d and d.button) and "shown" or "hidden")
end
QA.Register("statcalc-combat", { title = "Stat Calculator in combat: hidden silently, back after combat (V26, E1z229)", area = "Bonus", qa = "E1z229", order = 524, prefill = true, steps = {
    { text = "Out of combat: Bonus Features > Stat Calculator and its Panel on, QoL > Improved Character Display on with its Stat Calc button ticked. Open the character window (C) and open the Stat Calculator with the |cffffd100Stat Calc|r button.\n\n|cffffd100Expect:|r the panel beside the window and the Stat Calc button in its title row.",
        check = function()
            local sc, why = PanelReady()
            if not sc then return nil, why end
            local d = ICD()
            if InCombat() then return nil, "you are in combat: leave combat first | " .. CombatLine(sc, d) end
            if not WindowShown() then return nil, "open the character window (C) | " .. CombatLine(sc, d) end
            return (sc.Shown() and d and d.button) and true or false, CombatLine(sc, d)
        end },
    { text = "Attack a training dummy and keep fighting. In combat, close and open the character window (C), click where the Stat Calc button was, and type |cffffd100/xui stats|r; then press |cffffd100Check|r while still in combat.\n\n|cffffd100Expect:|r the character window opens and closes as usual; the Stat Calculator panel and the Stat Calc button are hidden and nothing opens them; no message in chat.",
        check = function()
            local sc, why = PanelReady()
            if not sc then return nil, why end
            local d = ICD()
            if not InCombat() then return nil, "not in combat: attack a training dummy and press Check while fighting | " .. CombatLine(sc, d) end
            return (not sc.Shown() and not (d and d.button)) and true or false, CombatLine(sc, d)
        end },
    { text = "Stop attacking and wait for combat to end, with the character window open.\n\n|cffffd100Expect:|r the Stat Calculator panel comes back beside the window (as it was before combat) and the Stat Calc button shows again.",
        check = function()
            local sc, why = PanelReady()
            if not sc then return nil, why end
            local d = ICD()
            if InCombat() then return nil, "still in combat: wait for it to end | " .. CombatLine(sc, d) end
            if not WindowShown() then return nil, "open the character window (C) | " .. CombatLine(sc, d) end
            return (sc.Shown() and d and d.button) and true or false, CombatLine(sc, d)
        end },
    { text = "Did any XayaUI message appear in chat during the fight or when it ended? Pass if none; Fail and copy the message.", noVerdict = true },
    { done = true, text = "Press |cffffd100Done|r." },
} })
