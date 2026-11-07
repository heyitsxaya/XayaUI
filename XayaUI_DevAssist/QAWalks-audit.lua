-------------------------------------------------------------------------------
-- QAWalks-audit.lua (XayaUI_DevAssist 0.7.19): in-game QA walkthroughs for the function audit's fixes (REQUEST-LOG A11; UI-60;
-- docs/process/FUNCTION-AUDIT-2026-11-07.md). Standing rule V21 (Xaya 2026-11-07, her words): "make sure every feature or significant
-- change to the codebase / bug report fixes have an in game qa test walk through with pre-fill confirmation options or data capturing".
-- Every walkthrough sets prefill = true: where the addon can read the result, its verdict is offered on one button (Accept), recorded
-- only on a click (QAWalk.lua). Steps the addon cannot judge are marked noVerdict and capture what it reads into the check line.
-- Test data: notes, groups and rules made here are tagged (qaAudit) and removed by the walkthrough's last step (deleted notes go to the
-- Notepad's Deleted notes, groups and rules to the Recycle Bin, like anything deleted). What a step switches is remembered and put back
-- by the last step. Your own notes, groups and rules are never touched. Does nothing without the framework. UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end
local function NS() return rawget(_G, "XayaUI_NS") end
-- (Dev Assist 0.7.55, P2 settings seam) XayaUI's settings through its views (core Modules.lua section 0b); an empty table without XayaUI
local function Settings(m) local cns = NS(); return cns and cns.Settings and cns.Settings(m) or {} end
local PlatS = Settings("platform")
local function Short(s, n) s = tostring(s or ""):gsub("|", "||"); return #s > (n or 60) and (s:sub(1, n or 60) .. "...") or s end

-------------------------------------------------------------------------------
-- Notepad format bar (UI-59, FA-9, FA-10, UI-65): highlighted text is kept; spell link look; hovers
-------------------------------------------------------------------------------
local np = {}   -- what the walkthrough changed: { shown, format, current, noteId }
-- XayaUI_Bonus is reached only through its "notepadDebug" service (Notepad.lua; nil while the Notepad's addon is off)
local function NPS() local ns = NS(); return ns and ns.Service and ns.Service("notepadDebug") end
local function NP() local sv = NPS(); return sv and sv.Frame() end
local function NDB() local sv = NPS(); return sv and sv.DB() end
local function OnQANote()
    local db, f = NDB(), NP()
    if not (db and f and f.eb) then return nil, "the Notepad box is not open: press Do it for me on step 1" end
    if not (np.noteId and db.current == np.noteId) then return nil, "the QA note is not the open note: press Do it for me on step 1" end
    return f, db
end
local FMT_INDEX = { View = 1, H = 2, Bullet = 3, Checkbox = 4, R = 5, Y = 6, G = 7, B = 8, Spell = 9 }   -- the format bar's order (Notepad.lua FMT)
local function Press(name)
    local f = NP(); local b = f and f.fb and f.fb.btns and f.fb.btns[FMT_INDEX[name]]
    if not b then error("the format bar is not built") end
    local fn = b:GetScript("OnClick"); if fn then fn(b, "LeftButton") end
end
local function Highlight(text, from, to)   -- puts text in the QA note and highlights characters from..to (the game's own HighlightText)
    local f = NP(); f.eb:SetFocus(); f.eb:SetText(text); f.eb:HighlightText(from, to)
end
QA.Register("audit-notepad-format", { title = "Notepad: format buttons keep highlighted text (UI-59)", qa = "F22", order = 300, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: XayaUI remembers how your Notepad is set, opens it with Formatting tools on, and adds a new note for this test (the last step deletes it).\n\n|cffffd100Expect:|r the Notepad box shows an empty note and the format bar (View, H, -, [ ], R, Y, G, B, Spell).",
        setup = function()
            local sv, db = NPS(), NDB()
            if not (sv and db and sv.On()) then error("the Notepad is switched off (Bonus Features > Utilities > Notepad)") end
            np.shown, np.format, np.current = db.shown and true or false, db.format and true or false, db.current
            sv.SetShown(true)
            if not db.format then sv.ToggleFormat() end
            sv.New("")
            np.noteId = db.current
        end,
        check = function() local f, why = OnQANote(); if not f then return false, why end; return (f.fb and f.fb:IsShown()) and true or false, (f.fb and f.fb:IsShown()) and "the QA note is open with the format bar" or "the format bar is not showing" end },
    { text = "Press |cffffd100Do it for me|r: the note gets the text |cffffd100say oop now|r, the word |cffffd100oop|r is highlighted the way a mouse drag does, and the |cff55dd55G|r button is pressed.\n\n|cffffd100Expect:|r the word is still there, now green (the plain text reads say ||cff55dd55oop||r now). Before the fix the word was deleted.",
        setup = function() local f = OnQANote(); if not f then error("press Do it for me on step 1 first") end; Highlight("say oop now", 4, 7); Press("G") end,
        check = function() local f, why = OnQANote(); if not f then return false, why end; local t = f.eb:GetText(); return t == "say |cff55dd55oop|r now", "the note reads: " .. Short(t) end },
    { text = "Press |cffffd100Do it for me|r: the note gets |cffffd100cast Fireball now|r, |cffffd100Fireball|r is highlighted and |cffffd100Spell|r is pressed, then the formatted view is switched on.\n\n|cffffd100Expect:|r the text holds {spell:Fireball}; the formatted view shows |cff71d5ff[Fireball]|r in the spell-link color, like a spell shift-clicked into chat, with no icon.",
        setup = function() local sv = NPS(); local f = OnQANote(); if not f then error("press Do it for me on step 1 first") end
            sv.SetView(false)
            Highlight("cast Fireball now", 5, 13); Press("Spell")
            sv.SetView(true) end,
        check = function() local sv = NPS(); local f, why = OnQANote(); if not f then return false, why end
            local t = f.eb:GetText(); local shown = sv.Render(t) or ""
            -- the word kept inside the braces and no icon is the fix; whether the game turns "Fireball" into a link depends on the game
            -- knowing that name (INFERENCE: a spell name may only resolve for a character who has it), so the link is reported, not required
            local ok = t == "cast {spell:Fireball} now" and not shown:find("|T", 1, true)
            return ok, "text: " .. Short(t) .. "; formatted: " .. Short(shown, 80) .. (shown:find("|Hspell:", 1, true) and " (a spell link)" or " (no spell link: the game did not know that name here; try a spell you have)") end },
    { text = "Press |cffffd100Do it for me|r: the formatted view is switched off, the note gets two lines (first / second), the whole second line is highlighted and |cffffd100H|r is pressed.\n\n|cffffd100Expect:|r the note reads first, then # second on its own line: nothing lost, no empty line added.",
        setup = function() local sv = NPS(); local f = OnQANote(); if not f then error("press Do it for me on step 1 first") end
            sv.SetView(false)
            Highlight("first\nsecond", 6, 12); Press("H") end,
        check = function() local f, why = OnQANote(); if not f then return false, why end; local t = f.eb:GetText(); return t == "first\n# second", "the note reads: " .. Short(t:gsub("\n", " / ")) end },
    { text = "Hover each button of the format bar (H, -, [ ], R, Y, G, B, Spell), then press |cffffd100Check again|r.\n\n|cffffd100Expect:|r each shows a gold title (Heading, Bullet, Checkbox, Red text, ..., Spell link) and one or two short lines. The addon checks the texts it has; whether they read well is yours to judge.",
        check = function()
            local f = NP(); if not (f and f.fb) then return false, "the format bar is not built" end
            local bad = 0
            for _, b in ipairs(f.fb.btns) do
                local fn = b:GetScript("OnEnter"); if fn then pcall(fn, b) end
                local t1 = rawget(_G, "GameTooltipTextLeft1"); local t2 = rawget(_G, "GameTooltipTextLeft2")
                local a, d = t1 and t1:GetText(), t2 and t2:GetText()
                if not (a and a ~= "" and d and d ~= "") then bad = bad + 1 end
                if GameTooltip then GameTooltip:Hide() end
            end
            if #f.fb.btns == 0 then return false, "the format bar has no buttons" end
            return bad == 0, bad == 0 and ("all %d buttons have a title and a short text"):format(#f.fb.btns) or (bad .. " button(s) without a title and text")
        end },
    { done = true, text = "Last step: press |cffffd100Do it for me|r to delete the QA note (it goes to Deleted notes) and put the Notepad back as it was (shown or hidden, Formatting tools on or off, the note you had open). Then press |cffffd100Done|r.",
        setup = function()
            local sv, db = NPS(), NDB(); if not (sv and db) then return end
            if np.noteId and db.current == np.noteId then sv.Delete() end
            for _ = 1, #(db.notes or {}) do if np.current == nil or db.current == np.current then break end; sv.Next() end
            if np.format ~= nil and (db.format and true or false) ~= np.format then sv.ToggleFormat() end
            if np.shown ~= nil then sv.SetShown(np.shown) end
            np.noteId = nil; np.done = true
        end,
        check = function() local db = NDB(); if not db then return false, "the Notepad is off" end
            for _, n in ipairs(db.notes or {}) do if np.noteId and n.id == np.noteId then return false, "the QA note is still there" end end
            return np.done == true, np.done and "the QA note is gone and the Notepad is as it was" or "press Do it for me" end },
} })

-- Notepad Restore list without the box (D48): the addon cannot see a Lua error, so this one captures what it reads and asks
QA.Register("audit-notepad-restore", { title = "Notepad: Restore list from settings, box never opened (D48)", qa = "F23", order = 301, prefill = true, steps = {
    { text = "Type /reload and do NOT open the Notepad. Then open the settings: Bonus Features > Utilities > Notepad > |cffffd100Open Restore list|r, and click an entry under \"Earlier versions of this note\" (if there is none, Skip).\n\nThen come back here and press |cffffd100Check again|r.\n\n|cffffd100Expect:|r no Lua error. The check shows the note's text now: it should be the version you clicked.",
        noVerdict = true,
        check = function() local sv, db = NPS(), NDB(); if not db then return false, "the Notepad is off" end
            local cur = sv.CurrentText() or ""
            return true, ("box built: %s; the open note now reads: %s"):format(NP() and "yes" or "no", Short(cur)) end },
} })

-------------------------------------------------------------------------------
-- Minimap list (O-100 / FA-15, D11 / FA-12): rows without on / off; "XayaUI Settings"; "Data Panels"
-------------------------------------------------------------------------------
QA.Register("audit-minimap-rows", { title = "Minimap list: row names, no on / off (O-100)", qa = "B225, F24, E1z194", order = 302, prefill = true, steps = {
    { text = "Left-click the XayaUI minimap button.\n\n|cffffd100Expect:|r Notes, Calculator and Stat Calculator (when those features are on) show just their names, with no \"on\" or \"off\"; the settings row reads |cffffd100XayaUI Settings|r and its hover says \"Open or close the XayaUI settings window\"; the data panels row reads |cffffd100Data Panels|r. Press |cffffd100Check again|r: the addon reads its own list.",
        check = function()
            local ns = NS(); if not (ns and ns.Launchers) then return false, "XayaUI is not loaded" end
            local by, out, ok = {}, {}, true
            for _, e in ipairs(ns.Launchers()) do by[e[1]] = e end
            for _, k in ipairs({ "notes", "calc", "stats" }) do
                local e = by[k]
                if e and e[5] ~= nil then ok = false; out[#out + 1] = e[2] .. " still has a state text" end
            end
            if not (by.settings and by.settings[2] == "XayaUI Settings" and tostring(by.settings[3]):find("Open or close", 1, true)) then ok = false; out[#out + 1] = "the settings row is \"" .. tostring(by.settings and by.settings[2]) .. "\"" end
            if by.data and by.data[2] ~= "Data Panels" then ok = false; out[#out + 1] = "the data row is \"" .. tostring(by.data[2]) .. "\"" end
            return ok, ok and "Notes / Calculator / Stat Calculator have no state text; XayaUI Settings and Data Panels are named right" or table.concat(out, "; ")
        end },
} })

-------------------------------------------------------------------------------
-- Groups and displays (D18 arrangement, D19 snap, D27 mover tab, D55 Recycle Bin): on a tagged test group
-------------------------------------------------------------------------------
local TEST = "QA audit group"
local tg = {}   -- { group, rules = {} }
local function MakeGroup(n, w, h)
    local ns = NS(); if not (ns and ns.NewFolder) then error("XayaUI is not loaded") end
    local f = ns.NewFolder(TEST); f.qaAudit = true; f.cW, f.cH = 200, 200
    local list = {}
    for i = 1, n do
        local r = ns.NewRule(); r.name = "QA audit " .. i; r.folder = f.id; r.enabled = true; r.qaAudit = true
        r.visual = r.visual or {}; r.visual.enabled = true; r.visual.w, r.visual.h = w or 37, h or 37; r.visual.point = "TOPLEFT"
        r.visual.x, r.visual.y = (i - 1) * 60 + 3, -(i - 1) * 7
        ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r; list[#list + 1] = r
    end
    if ns.SetPreview then ns.SetPreview(list, "visual", true) end
    if ns.RefreshAllVisuals then pcall(ns.RefreshAllVisuals) end
    tg.group, tg.rules = f, list
    return f, list
end
local function RemoveGroup()
    local ns = NS(); local f = tg.group
    if ns.unlocked and ns.MoverExit then ns.MoverExit("cancel") end
    if f then
        if ns.SetPreview then ns.SetPreview(tg.rules or {}, "visual", false) end
        if ns.LoadOptions then ns.LoadOptions() end
        if ns.OptionsApi and ns.OptionsApi.DeleteFolderAll then ns.OptionsApi.DeleteFolderAll(f.id) end
        if ns.RefreshAllVisuals then pcall(ns.RefreshAllVisuals) end
    end
    tg.group, tg.rules = nil, nil
end
local function GroupGone()
    local ns = NS()
    for _, f in ipairs(ns and ns.folders or {}) do if f.qaAudit then return false, "a QA audit group is still there" end end
    return true, "the QA audit group is gone"
end
QA.Register("audit-groups", { title = "Groups: arrangement holds still, Snap, mover tab, Recycle Bin (D18, D19, D27, D55)", qa = "B224, B227, B226", order = 303, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: XayaUI makes \"QA audit group\" with two sample icons (37 x 37, anchor Top left), sets Align left and Align top, and applies the arrangement six times in a row.\n\n|cffffd100Expect:|r two icons lined up on their left edges and tops; the check says their X / Y did not change after the first apply (before the fix they grew by 1 each time).",
        setup = function()
            local ns = NS(); local f, l = MakeGroup(2, 37, 37)
            f.cArrX, f.cArrY = "left", "top"
            ns.ApplyGroupArrangement(f)
            tg.first = { l[1].visual.x, l[1].visual.y, l[2].visual.x, l[2].visual.y }
            for _ = 1, 5 do ns.ApplyGroupArrangement(f) end
        end,
        check = function()
            local l, a = tg.rules, tg.first; if not (l and a) then return false, "press Do it for me" end
            local now = { l[1].visual.x, l[1].visual.y, l[2].visual.x, l[2].visual.y }
            local same = now[1] == a[1] and now[2] == a[2] and now[3] == a[3] and now[4] == a[4]
            return same and now[1] == now[3], ("after 1 apply: %s,%s / %s,%s; after 6: %s,%s / %s,%s"):format(a[1], a[2], a[3], a[4], now[1], now[2], now[3], now[4])
        end },
    { text = "Press |cffffd100Do it for me|r: the first icon is snapped (right-click > Snap Target) to a frame name that does not exist.\n\n|cffffd100Expect:|r chat says the frame does not exist and the aura keeps its own position; the icon does not move (before the fix it jumped and lost its X / Y).",
        setup = function() local ns = NS(); local r = tg.rules and tg.rules[1]; if not r then error("press Do it for me on step 1 first") end
            tg.snapXY = { r.visual.x, r.visual.y }; ns.SnapToTarget(r, "qa_no_such_frame", "TOP_CENTER") end,
        check = function() local r = tg.rules and tg.rules[1]; if not (r and tg.snapXY) then return false, "press Do it for me" end
            local kept = r.visual.x == tg.snapXY[1] and r.visual.y == tg.snapXY[2] and not (r.visual.snap and r.visual.snap.target)
            return kept, ("X / Y %s,%s (was %s,%s); snap saved: %s"):format(r.visual.x, r.visual.y, tg.snapXY[1], tg.snapXY[2], (r.visual.snap and r.visual.snap.target) and "yes" or "no") end },
    { text = "Press |cffffd100Do it for me|r: the mover view opens (everything unlocked). Click the second icon, then click the small name tab of \"QA audit group\" above its outline, then press the Up arrow key once. Press |cffffd100Check again|r.\n\n|cffffd100Expect:|r the whole group moved up 1 pixel, not the icon you clicked first.",
        setup = function() local ns = NS(); if not tg.group then error("press Do it for me on step 1 first") end
            if not ns.unlocked then ns.ToggleUnlock() end; tg.cY = tg.group.cY or 0; tg.icon2Y = tg.rules[2].visual.y end,
        check = function() local f = tg.group; if not (f and tg.cY) then return false, "press Do it for me" end
            local moved = (f.cY or 0) - tg.cY; local iconMoved = tg.rules[2].visual.y ~= tg.icon2Y
            return moved == 1 and not iconMoved, ("group moved %d px; the icon %s"):format(moved, iconMoved and "moved on its own" or "did not move on its own") end },
    { text = "Press |cffffd100Do it for me|r (or click the lock icon on the group's name tab): the group is locked for now. Then drag the name tab. Press |cffffd100Check again|r.\n\n|cffffd100Expect:|r the group does not move while locked (a click on the tab still opens its settings).",
        setup = function() local ns = NS(); if tg.group and ns.SetMoverTempLock then ns.SetMoverTempLock(tg.group, true) end; tg.lockXY = tg.group and { tg.group.cX or 0, tg.group.cY or 0 } end,
        check = function() local ns = NS(); local f = tg.group; if not (f and tg.lockXY) then return false, "press Do it for me first" end
            local locked = ns.IsMoverTempLocked and ns.IsMoverTempLocked(f)
            local still = (f.cX or 0) == tg.lockXY[1] and (f.cY or 0) == tg.lockXY[2]
            return locked and still, ("locked for now: %s; position %s"):format(locked and "yes" or "no", still and "unchanged" or "CHANGED") end },
    { text = "Press |cffffd100Do it for me|r: the mover view closes without saving, the group's second icon gets no cue or condition, and the group is deleted on its own (not with its contents) and restored from the Recycle Bin.\n\n|cffffd100Expect:|r both icons are back inside \"QA audit group\" (before the fix a rule with no cue or condition stayed one level up).",
        setup = function() local ns = NS(); local f = tg.group; if not f then error("press Do it for me on step 1 first") end
            if ns.unlocked and ns.MoverExit then ns.MoverExit("cancel") end
            local it = ns.RecycleFolder(f); tg.binOk = it and ns.RecycleRestore(it.id)
            for _, x in ipairs(ns.folders) do if x.qaAudit then tg.group = x end end end,
        check = function() local f = tg.group; if not (f and tg.rules) then return false, "press Do it for me" end
            local inside = 0; for _, r in ipairs(tg.rules) do if r.folder == f.id then inside = inside + 1 end end
            return inside == #tg.rules, ("%d of %d rules are back inside the group"):format(inside, #tg.rules) end },
    { done = true, text = "Last step: press |cffffd100Do it for me|r to delete \"QA audit group\" and its two sample rules (they go to the Recycle Bin). Then press |cffffd100Done|r.",
        setup = RemoveGroup, check = GroupGone },
} })

-------------------------------------------------------------------------------
-- Backup Load (replace) keeps the built-in categories (D40): only checked, never run for you (it replaces your rules)
-------------------------------------------------------------------------------
QA.Register("audit-backup-replace", { title = "Backups: loading a backup in place of your rules keeps the built-in rule categories (D40)", qa = "B223", order = 304, prefill = true, steps = {
    { text = "This one you do by hand, because Load (replace) swaps out all your rules. Profiles > Export > Backups saved on this computer: |cffffd100Save|r a backup, then |cffffd100Load (replace)|r that same backup. Press |cffffd100Check again|r.\n\n|cffffd100Expect:|r Display Cues, Sound Cues, Hybrid Cues, Advanced Cue Tracking and Mouse Cursor Cues are still the built-in categories (a rule in Display Cues has no sound options). The check counts the categories it finds.",
        check = function()
            local ns = NS(); if not ns then return false, "XayaUI is not loaded" end
            local have, names = 0, {}
            for _, d in ipairs(ns.DEFAULT_FOLDERS or {}) do
                for _, f in ipairs(ns.folders or {}) do if not f.parent and f.default == d.key then have = have + 1; names[#names + 1] = d.name; break end end
            end
            local want = #(ns.DEFAULT_FOLDERS or {})
            return have == want, ("%d of %d built-in categories are marked as such%s"):format(have, want, have < want and " (a category you deleted yourself also counts as missing)" or "")
        end },
} })

-------------------------------------------------------------------------------
-- Talent scan (D9, D10) and On Initialization (D54)
-------------------------------------------------------------------------------
local ts = {}
QA.Register("audit-talents-init", { title = "Talent scan guard; On Initialization and talents (D9, D10, D54)", qa = "B225, B226", order = 305, prefill = true, steps = {
    { text = "Open your talent window (N), then press |cffffd100Do it for me|r: XayaUI starts the talent scan (/xui debug talents scan).\n\n|cffffd100Expect:|r it refuses: \"Close the talent window first, then scan again.\" (before the fix it scanned anyway).",
        setup = function() local ns = NS(); if not ns.ScanAllTalents then error("this client has no talent scan") end; ts.ok, ts.why = ns.ScanAllTalents() end,
        check = function() if ts.ok == nil then return false, "press Do it for me with the talent window open" end
            local refused = ts.ok == false and tostring(ts.why):find("Close the talent window", 1, true) ~= nil
            return refused, "the scan answered: " .. tostring(ts.why) end },
    { text = "Make a rule (or use one) with an Actions tab |cffffd100On Initialization|r chat message and a talent requirement you do NOT have. Type /reload, come back here (/xui dev qa) and press |cffffd100Check again|r.\n\n|cffffd100Expect:|r no message after the reload. Then learn the talent (or change the requirement to one you have): the message shows once. Change spec (with no spec load condition on the rule): it shows again. The addon cannot see the chat line, so you judge; the check lists rules whose On Initialization has run this session.",
        noVerdict = true,
        check = function() local ns = NS(); local names = {}
            for r, rt in pairs(ns and ns.runtime or {}) do if type(r) == "table" and rt and rt.inited and not r.parentUid then names[#names + 1] = tostring(r.name) end end
            return true, #names > 0 and ("On Initialization has run for: " .. Short(table.concat(names, ", "), 120)) or "no rule has run On Initialization yet this session" end },
} })

-------------------------------------------------------------------------------
-- Chat (D31 fade back, D32 ignore message, D37 whole words)
-------------------------------------------------------------------------------
local ch = {}
local function Chat() local ns = NS(); local sv = ns and ns.Service and ns.Service("chatDebug"); return sv and sv.C end   -- (Chat Core.lua)
QA.Register("audit-chat", { title = "Chat: fade given back, ignore message, whole-word filter (D31, D32, D37)", qa = "D22, D23", order = 306, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: XayaUI checks the whole-word spam filter with phrases that start or end with punctuation and with Cyrillic letters (it changes no setting).\n\n|cffffd100Expect:|r \"wts!\" is found in \"wts! cheap\", \"$gold\" in \"only $gold here\", \"gold\" is not found inside \"golden\".",
        setup = function() ch.ww = true end,
        check = function() local C = Chat(); local W = C and C.WholeWord; if not W then return false, "XayaUI Chat is not loaded" end
            local cyr, cyrLong = "\208\183\208\190\208\187\208\190\209\130\208\190", "\208\183\208\190\208\187\208\190\209\130\208\190\208\185"
            local r = { W("wts! cheap", "wts!"), W("only $gold here", "$gold"), not W("golden rings", "gold"), W("x " .. cyr .. " y", cyr), not W(cyrLong, cyr) }
            local ok = r[1] and r[2] and r[3] and r[4] and r[5]
            return ok and true or false, ("wts!: %s, $gold: %s, gold not in golden: %s, Cyrillic word: %s, not inside a longer word: %s"):format(tostring(r[1]), tostring(r[2]), tostring(r[3]), tostring(r[4]), tostring(r[5])) end },
    { text = "With the Chat Panel on, press |cffffd100Do it for me|r: XayaUI notes Blizzard's own fade of old chat lines (kept when XayaUI first set it) and turns the Chat Panel off (/xui chat off) and Improved Chat off (QoL > Improved Chat: the fade of old lines is Improved Chat's setting). The next step turns both back on.\n\n|cffffd100Expect:|r Blizzard's chat comes back, and its old lines fade exactly as they did before XayaUI changed them.",
        setup = function() local C = Chat(); if not (C and C.On and C.On()) then error("the Chat Panel is off: turn it on first") end
            local cf = rawget(_G, "ChatFrame1"); ch.wasOn = true; ch.game = cf and cf._xuiFade and { cf._xuiFade[1], cf._xuiFade[2] }
            local s = (NS() or {}).chat2; ch.impWas = s and s.improvedOn
            C.Command("off"); if s then s.improvedOn = false; C.Refresh() end end,
        check = function() local cf = rawget(_G, "ChatFrame1"); if not (cf and cf.GetFading) then return false, "no chat window" end
            if not ch.wasOn then return false, "press Do it for me" end
            -- (0.7.53) nothing to give back means the give-back was not exercised: not tested (before: a Pass)
            if not ch.game then return nil, "not tested: XayaUI had not changed Blizzard's fade of old lines this session, so there was nothing to give back (turn Improved Chat's fade of old lines on, /reload, and run this again)" end
            local f, t = cf:GetFading(), cf:GetTimeVisible()
            local ok = (f and true or false) == (ch.game[1] and true or false) and t == ch.game[2]
            return ok, ("Blizzard's fade now: %s, %s s (before XayaUI: %s, %s s)"):format(tostring(f), tostring(t), tostring(ch.game[1]), tostring(ch.game[2])) end },
    { text = "Press |cffffd100Do it for me|r to turn the Chat Panel and Improved Chat back on (as they were). Then, if you have someone on your Ignore list, use the ignore click (QoL > Improved Chat > Filters > Quick ignore) on that player's name in chat.\n\n|cffffd100Expect:|r the Chat Panel is back. The ignore click on an already ignored player says \"Could not ignore <name>: the game did not add them ...\" (before: always \"Ignoring <name>\"). The addon cannot see the chat line, so you judge that part.",
        setup = function() local C = Chat(); local s = (NS() or {}).chat2
            if C and ch.wasOn then if s then s.improvedOn = ch.impWas end; if not (C.On and C.On()) then C.Command("on") else C.Refresh() end end; ch.wasOn, ch.impWas = nil, nil end,
        check = function() local C = Chat(); local on = C and C.On and C.On(); return on and true or false, on and "the Chat Panel is on again" or "the Chat Panel is still off" end },
} })

-------------------------------------------------------------------------------
-- American spelling (FA-16 / FA-17): what the addon can read of its own texts, the rest by eye
-------------------------------------------------------------------------------
local BRIT = { "colour", "favour", "behaviour", "honour", "armour", "flavour", "centre", "catalogue", "neighbour", "labelled", "cancelled", "organis", "recognis", "customis", "realis", "gray" }
QA.Register("audit-spelling", { title = "American spelling in the addon's texts (FA-16)", qa = "FA-16", order = 307, prefill = true, steps = {
    { text = "Press |cffffd100Check again|r: the addon reads the texts it can reach (the minimap list and the Info pane's What's New, Getting Started and Help texts) and looks for British spellings (words ending in -our, -re or -ogue where American English writes -or, -er or -og, and -ise verbs) and that grey is spelled with an e, as you asked.\n\n|cffffd100Expect:|r none found.",
        check = function()
            local ns = NS(); local found, n = {}, 0
            local function scan(s)
                if type(s) ~= "string" then return end
                n = n + 1
                local l = s:lower()
                for _, w in ipairs(BRIT) do if l:find(w, 1, true) then found[#found + 1] = w .. ": " .. Short(s, 40) end end
            end
            for _, e in ipairs(ns and ns.Launchers and ns.Launchers() or {}) do scan(e[2]); scan(e[3]) end
            local function walk(t, d) if d > 6 or type(t) ~= "table" then return end; for _, v in pairs(t) do if type(v) == "string" then scan(v) else walk(v, d + 1) end end end
            if ns and ns.LoadOptions then pcall(ns.LoadOptions) end
            local ip = ns and ns.Service and ns.Service("infoPaneData")   -- (XayaUI_Options InfoPane.lua)
            walk(ip and ip.Data(), 0)
            if n == 0 then return nil, "no text could be read (the settings addon's texts were not found)" end
            return #found == 0, #found == 0 and ("%d texts read, none with a British spelling"):format(n) or (#found .. " found: " .. Short(table.concat(found, " | "), 160))
        end },
    { text = "Look around the settings window (Display tab of a bar cue, Character Pane > Stat list, Release Guard, Enhanced Tooltips) and the What's New pane.\n\n|cffffd100Expect:|r \"color\", \"center\", \"catalog\", \"flavor\", and \"grey\" everywhere. Note any word that still looks British.",
        noVerdict = true, check = function() return true, "by eye: note anything you find" end },
} })

-------------------------------------------------------------------------------
-- Theme page asks first (FA-4, FA-8, FA-13; audit D5, D6, D7) - XayaUI core's ns.Theme; the page's builder is added by XayaUI_Options
-------------------------------------------------------------------------------
local thw = {}
local QA_THEME = "QA audit theme"
local function TH() local ns = NS(); return ns and ns.Theme end
local function Page()
    local ns, T = NS(), TH()
    if ns and ns.LoadOptions then pcall(ns.LoadOptions) end
    if not (T and T.BuildArgs and T.Ask) then return nil end
    thw.args = thw.args or T.BuildArgs(function() end)
    return thw.args
end
local function AskDlg() return rawget(_G, "XayaUIThemeAsk") end
local function Btn(i) local d = AskDlg(); return d and d.btns and d.btns[i] end
local function Press(i) local b = Btn(i); if b and b:IsShown() then b:GetScript("OnClick")(b) end end
QA.Register("audit-theme", { title = "Theme: asks before throwing your colors away; Replace / Save As Copy (FA-4, FA-8, FA-13)", qa = "B260, B261", order = 308, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: XayaUI remembers your current theme (the last step puts it back), changes one color (the accent: you are now on Custom) and then picks Light mode the way the Theme list does.\n\n|cffffd100Expect:|r a small window asks \"Discard your custom colors? ...\" with |cffffd100Discard|r and |cffffd100Cancel|r, and the theme has NOT changed yet. Then click |cffffd100Cancel|r in that window and press Check again: your colors are still there.",
        setup = function()
            local T = TH(); local args = Page(); if not args then error("the settings window (XayaUI Options) is not loaded") end
            thw.saved = thw.saved or T.Export(); thw.base = thw.base or (PlatS.theme and PlatS.theme.base)
            T.SetToken("accent", { 0.85, 0.2, 0.6, 1 }); thw.base0 = PlatS.theme.base
            args.base.set(nil, "light")
        end,
        check = function()
            local d = AskDlg(); local th = PlatS.theme
            if not thw.base0 then return false, "press Do it for me" end
            if d and d:IsShown() then
                local ok = th.base == thw.base0 and Btn(1):GetText() == "Discard"
                return ok, ("asking now (buttons: %s / %s); the theme is still %s"):format(tostring(Btn(1):GetText()), tostring(Btn(2):GetText()), tostring(th.base))
            end
            local kept = th.base == thw.base0 and th.tokens and th.tokens.accent ~= nil
            return kept, kept and "the window is closed and your colors are still there (Cancel kept them)" or ("the theme changed to " .. tostring(th.base))
        end },
    { text = "Press |cffffd100Do it for me|r: XayaUI saves your colors as \"QA audit theme\", changes the accent again, and presses |cffffd100Save|r with that same name.\n\n|cffffd100Expect:|r the window says a theme with that name is already saved, with three buttons in this order: |cffffd100Replace|r, |cffffd100Save As Copy|r, |cffffd100Cancel|r. Click |cffffd100Save As Copy|r, then Check again: \"QA audit theme (1)\" is saved and \"QA audit theme\" is unchanged.",
        setup = function()
            local T = TH(); local args = Page(); if not args then error("the settings window (XayaUI Options) is not loaded") end
            T.Save(QA_THEME, true); thw.made = true
            thw.first = PlatS.themes[QA_THEME].tokens.accent and PlatS.themes[QA_THEME].tokens.accent[1]
            T.SetToken("accent", { 0.2, 0.7, 0.3, 1 })
            args.saveName.set(nil, QA_THEME); args.save.func()
        end,
        check = function()
            local d = AskDlg()
            if not thw.made then return false, "press Do it for me" end
            if d and d:IsShown() then
                local order = tostring(Btn(1):GetText()) .. " / " .. tostring(Btn(2):GetText()) .. " / " .. tostring(Btn(3):GetText())
                return order == "Replace / Save As Copy / " .. (CANCEL or "Cancel"), "asking now: " .. order
            end
            local copy = PlatS.themes[QA_THEME .. " (1)"] ~= nil
            local same = PlatS.themes[QA_THEME] and PlatS.themes[QA_THEME].tokens.accent and PlatS.themes[QA_THEME].tokens.accent[1] == thw.first
            return copy and same, ("copy saved: %s; the original unchanged: %s"):format(copy and "yes" or "no", same and "yes" or "no")
        end },
    { text = "Look at Settings > UI Options > Theme > |cffffd100Reset everything|r: hover it.\n\n|cffffd100Expect:|r it says \"Back to Class colors (the starting theme), ...\". The check reads the text.",
        check = function() local args = Page(); local d = args and args.resetPal and args.resetPal.desc; return type(d) == "string" and d:find("Class colors", 1, true) ~= nil, "Reset everything says: " .. Short(d, 80) end },
    { done = true, text = "Last step: press |cffffd100Do it for me|r to delete the QA saved themes and put your theme back exactly as it was before this walkthrough. Then press |cffffd100Done|r.",
        setup = function()
            local T = TH(); if not T then return end
            if AskDlg() then AskDlg():Hide() end
            for _, n in ipairs(T.SavedNames()) do if n == QA_THEME or n:find("^" .. QA_THEME .. " %(%d+%)$") then T.Delete(n) end end
            if thw.saved then T.Import(thw.saved) end
            thw.done = true; thw.saved, thw.made, thw.base0 = nil, nil, nil
        end,
        check = function()
            local T = TH(); if not T then return false, "no theme" end
            for _, n in ipairs(T.SavedNames()) do if n:find("^" .. QA_THEME) then return false, "a QA saved theme is still there" end end
            return thw.done == true, thw.done and "the QA themes are gone and your theme is back" or "press Do it for me"
        end },
} })

-------------------------------------------------------------------------------
-- Recycle Bin keep time asks first (FA-14); /xui words of a switched-off addon (D8)
-------------------------------------------------------------------------------
QA.Register("audit-bin-words", { title = "Recycle Bin keep time asks first; /xui words name their addon (FA-14, D8)", qa = "B262", order = 309, prefill = true, steps = {
    { text = "Profiles > Recycle Bin. If something is in it that is older than 36 hours (delete a test rule a day early, or Skip), pick |cffffd100Keep deleted items for: 36 hours|r.\n\n|cffffd100Expect:|r a question says how many items are older than that and will be removed for good, with Yes / No; No keeps them. With nothing older, it changes at once with no question. The check shows how many items 36 hours would remove now.",
        noVerdict = true,
        check = function() local ns = NS(); if not (ns and ns.RecycleWouldPurge) then return false, "XayaUI is not loaded" end
            return true, ("keep time now: %s; items 36 hours would remove: %d"):format(ns.RecycleKeepLabel(), ns.RecycleWouldPurge(36)) end },
    { text = "Press |cffffd100Check again|r: the addon looks up which addon owns /xui stats, shop, reskin, releaseguard, calc and calculator.\n\n|cffffd100Expect:|r XayaUI QoL for the first four, XayaUI Bonus Features for calc / calculator. (With that addon switched off, typing the word says which addon to turn on.)",
        check = function() local ns = NS(); if not (ns and ns.ModuleOfCommand) then return false, "XayaUI is not loaded" end
            local want = { stats = "XayaUI_QoL", shop = "XayaUI_QoL", reskin = "XayaUI_QoL", releaseguard = "XayaUI_QoL", calc = "XayaUI_Bonus", calculator = "XayaUI_Bonus" }
            local bad = {}
            for w, a in pairs(want) do local m = ns.ModuleOfCommand(w); if not (m and m.addon == a) then bad[#bad + 1] = w end end
            return #bad == 0, #bad == 0 and "every word names its addon" or ("not listed: " .. table.concat(bad, ", ")) end },
} })

-------------------------------------------------------------------------------
-- Engine: estimate setting off means unknown (D28); a deleted active rule's glow stops (D56); errors recorded (D57)
-------------------------------------------------------------------------------
QA.Register("audit-engine", { title = "Combat tracking: hidden buffs are not guessed when that box is off; a glow stops when its rule is deleted; errors show in /xui report (D28, D56, D57)", qa = "B263, B264", order = 312, prefill = true, steps = {
    { text = "Press |cffffd100Check again|r: with Settings > UI Options > Rule Creation > Combat Tracking Setup > |cffffd100Estimate buffs the game hides in combat|r unticked, the tracker must leave a hidden buff unknown. The addon reads its setting and asks the tracker about a test aura it was told is up.\n\n|cffffd100Expect:|r with the box unticked: unknown. (Ticked: the check only reports.)",
        check = function()
            local ns = NS(); local T, M = ns and ns.AuraTracker, ns and ns.AuraModel
            if not (T and M and T.Resolve and T.Observe) then return false, "the combat tracker is not loaded" end
            local id = 987654321
            T.Observe(id, true, "qa", { expiration = GetTime() + 30, duration = 30, instanceID = 77 })
            local h, p = T.Resolve(id)
            -- (0.7.53) with the box ticked the thing under test (off = unknown) is not exercised: not tested (before: a Pass)
            if M.PresenceEnabled() then return nil, ("the box is ticked, so this is not tested (the tracker answers %s): untick it and Check again"):format(h and (p and "present" or "absent") or "unknown") end
            return h == false, h == false and "the box is off and the hidden buff stays unknown" or "the box is off but the tracker still estimated it"
        end },
    { text = "Make a rule with an Actions tab |cffffd100During|r glow on an action button and make it active (its trigger true), so the button glows. Then delete the rule (it goes to the Recycle Bin).\n\n|cffffd100Expect:|r the glow stops at once (before: it stayed until /reload). Restore it from the Recycle Bin afterwards if you want it back. The addon cannot see a glow, so you judge.",
        noVerdict = true },   -- (0.7.53: the check said "by eye" and offered nothing; the step is yours to judge)
    { text = "Type |cffffd100/xui report|r and look at the errors part.\n\n|cffffd100Expect:|r a rule that failed shows there with code XUI-E010, and a cue migration problem with XUI-E011 (most players have none: then it lists none). The check counts what it finds in the error record.",
        noVerdict = true,
        check = function() local db = PlatS.errors or (PlatS.ui and PlatS.ui.errors); local n = type(db) == "table" and #db or 0
            return true, ("%d error(s) recorded"):format(n) end },
} })
