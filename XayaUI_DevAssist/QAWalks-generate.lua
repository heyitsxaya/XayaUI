-------------------------------------------------------------------------------
-- QAWalks-generate.lua (XayaUI_DevAssist 0.7.14): the in-game QA walkthrough for the Generate buttons, the filtered list and the Select
-- all tick box in Rules > Auto-Generate Rules (XayaUI_Options 0.6.54 as built; on main since 687b624; QA B160). Own code.
-- Xaya, 2026-11-06: "four buttons per specialization auto-generation: "Generate All Rules for {Spec}" "Generate CD Tracking Rules for
-- {Spec}" "Generate Aura Tracking Rules for {Spec}" "Generate Target Debuff Tracking Rules for {Spec}"; these buttons filter out what
-- rules display below", "no rules should be auto-shown without a button being clicked first", "missing select all tick box option to
-- select all".
-- Standing rule V22 (Xaya, 2026-11-07): "make sure every feature or significant change to the codebase / bug report fixes have an in game qa
-- test walk through with pre-fill confirmation options or data capturing". prefill = true: the addon reads what the picker lists after
-- each of her clicks and offers its own verdict on "Accept"; nothing is recorded without her click. She presses the real buttons: a step
-- never fakes a press. The one step about looks (are the button labels cut off?) captures the widths it reads into the note and asks her
-- (noVerdict). Ticks the walkthrough makes are removed again in its last step. Reaches the picker only through the published
-- ns.OptionsApi.AutoPicker (XayaUI_Options 0.6.65) and the settings window's Ace tree. Does nothing without the framework. UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end

local function NS() return rawget(_G, "XayaUI_NS") end
local function AP() local ns = NS(); return ns and ns.OptionsApi and ns.OptionsApi.AutoPicker end   -- published by XayaUI_Options (Options.lua): another addon's names are read only through it
local function ACD() return LibStub and LibStub("AceConfigDialog-3.0", true) end
local function Root() local a = ACD(); return a and a.OpenFrames and a.OpenFrames["CueRules"] end

-- the settings window: open it on Rules > Auto-Generate Rules (the sub-tab's key is "creatorTab")
local function Open()
    local ns = NS()
    if not (ns and ns.LoadOptions and ns.LoadOptions()) then return end
    local a = ACD(); if not a then return end
    if not (Root() and Root().frame and Root().frame:IsShown()) then a:Open("CueRules") end
    a:SelectGroup("CueRules", "cooldowns", "creatorTab")
    local reg = LibStub and LibStub("AceConfigRegistry-3.0", true)
    if reg and reg.NotifyChange then reg:NotifyChange("CueRules") end
end
local function Ready()
    if not (Root() and Root().frame and Root().frame:IsShown()) then return false, "the settings window is not open: press Do it for me" end
    return true
end
-- every widget of the open window of one AceGUI type, with its readable text (icons and colour codes removed)
local function Plain(s)
    s = tostring(s or ""):gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end
local function Widgets(kind)
    local out = {}
    local function walk(w, d)
        if not w or d > 30 then return end
        if w.type == kind and w.text and w.text.GetText then
            local ok, t = pcall(w.text.GetText, w.text)
            if ok then out[#out + 1] = { w = w, text = Plain(t) } end
        end
        for _, c in ipairs(w.children or {}) do walk(c, d + 1) end
    end
    walk(Root(), 0)
    return out
end

-- the classes' specs, as the game lists them
local function Specs()
    local out = {}
    for i = 1, (GetNumSpecializations and GetNumSpecializations() or 0) do
        local sid, sname = GetSpecializationInfo(i)
        if sid then out[#out + 1] = { id = sid, name = sname } end
    end
    return out
end
local function Current() local ns = NS(); return ns and ns.CurrentSpecID and ns.CurrentSpecID() end
local function CurrentName()
    local cur = Current()
    for _, s in ipairs(Specs()) do if s.id == cur then return s.name end end
    return "your spec"
end
local function Count(rows)
    local n = { cd = 0, aura = 0, debuff = 0 }
    for _, c in ipairs(rows or {}) do n[c.kind] = (n[c.kind] or 0) + 1 end
    return n
end
local function Describe(n) return ("%d cooldown(s), %d aura(s), %d debuff(s)"):format(n.cd, n.aura, n.debuff) end

-- what the picker lists after a press: filter must match and every row must be of that kind (or, for All, a mix of the three)
local function CheckView(filter, spec)
    local ap = AP(); if not ap then return false, "the settings window (XayaUI_Options) has not been opened yet" end
    local v = ap.view
    if not v then return false, "nothing is listed: press the button first" end
    if v.filter ~= filter then return false, ("the list shows the \"%s\" filter, not \"%s\""):format(tostring(v.filter), filter) end
    if spec and v.spec ~= spec then return false, "the list is for another spec than the button you pressed" end
    local n = Count(v.rows)
    local total = n.cd + n.aura + n.debuff
    if total == 0 then
        return false, "the list is empty (" .. (ap.NoneText and Plain(ap.NoneText(v)) or "") .. "): nothing to check the filter on"
    end
    if filter == "all" then return true, Describe(n) end
    for _, k in ipairs({ "cd", "aura", "debuff" }) do
        if k ~= filter and n[k] > 0 then return false, ("filter \"%s\" lists other kinds too: %s"):format(filter, Describe(n)) end
    end
    return true, Describe(n)
end

local saved
QA.Register("auto-generate-buttons", { title = "Auto-Generate Rules: Generate buttons, filtered list, Select all", qa = "B160, B151, B152", order = 265, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: the settings window opens on |cffffd100Rules > Auto-Generate Rules|r and any list left open is closed.\n\n|cffffd100Expect:|r no list below the buttons yet. For each of your specs four buttons: |cffffd100Generate All Rules for <Spec>|r, |cffffd100Generate CD Tracking Rules for <Spec>|r, |cffffd100Generate Aura Tracking Rules for <Spec>|r, |cffffd100Generate Target Debuff Tracking Rules for <Spec>|r, and the same four ending |cffffd100for my class|r. No button says Auto-populate.",
        setup = function()
            local ap = AP()
            saved = { done = false }
            Open()
            ap = AP()
            if ap and ap.Close then ap.Close() end
            local reg = LibStub and LibStub("AceConfigRegistry-3.0", true)
            if reg and reg.NotifyChange then reg:NotifyChange("CueRules") end
        end,
        check = function()
            local ok, why = Ready(); if not ok then return false, why end
            local ap = AP(); if not (ap and ap.ButtonLabel) then return false, "the picker is not loaded" end
            if ap.view then return false, "a list is already shown: press Do it for me to close it" end
            local want, n = {}, 0
            for _, s in ipairs(Specs()) do for _, f in ipairs(ap.FILTERS) do want[ap.ButtonLabel(f.filter, s.name)] = true; n = n + 1 end end
            for _, f in ipairs(ap.FILTERS) do want[ap.ButtonLabel(f.filter, "my class")] = true; n = n + 1 end
            local seen, old, gen = {}, 0, 0
            for _, b in ipairs(Widgets("Button")) do
                if b.text:find("^Generate ") then gen = gen + 1; seen[b.text] = true end
                if b.text:find("Auto-populate", 1, true) then old = old + 1 end
            end
            local missing
            for label in pairs(want) do if not seen[label] then missing = label; break end end
            if missing then return false, ("button missing on screen: \"%s\" (%d of %d Generate buttons found)"):format(missing, gen, n) end
            if gen ~= n then return false, ("%d Generate buttons on screen, expected %d"):format(gen, n) end
            if old > 0 then return false, old .. " button(s) still say Auto-populate" end
            return true, ("%d Generate buttons with the exact wording, no list shown, none says Auto-populate"):format(n)
        end },
    { text = "Press |cffffd100Generate CD Tracking Rules for your current spec|r yourself (the one for the spec you are playing now), then |cffffd100Check|r.\n\n|cffffd100Expect:|r a table appears below the buttons listing only cooldowns (a Spell CD group, no Aura or Debuff group).",
        check = function() return CheckView("cd", Current()) end },
    { text = "Press |cffffd100Generate Aura Tracking Rules for your current spec|r, then |cffffd100Check|r.\n\n|cffffd100Expect:|r the table now lists only auras on you (an Aura group only). If your Cooldown Manager has no auras the list is empty and says so (the check cannot judge then).",
        check = function() return CheckView("aura", Current()) end },
    { text = "Press |cffffd100Generate Target Debuff Tracking Rules for your current spec|r, then |cffffd100Check|r.\n\n|cffffd100Expect:|r the table lists only target debuffs (a Debuff group only).",
        check = function() return CheckView("debuff", Current()) end },
    { text = "Press |cffffd100Generate All Rules for your current spec|r, then |cffffd100Check|r.\n\n|cffffd100Expect:|r all three groups (Spell CD, Aura, Debuff) in one table, sorted by type and then A-Z.",
        check = function() return CheckView("all", Current()) end },
    { text = "Tick the |cffffd100Select all|r tick box above the table's header row, then |cffffd100Check|r.\n\n|cffffd100Expect:|r every row listed is ticked (also the header row's own tick box and each group's).",
        check = function()
            local ok, why = Ready(); if not ok then return false, why end
            local ap = AP(); local v = ap and ap.view
            if not (v and #v.rows > 0) then return false, "no list is shown: press Generate All Rules for your spec first" end
            local box
            for _, b in ipairs(Widgets("CheckBox")) do if b.text == "Select all" then box = b.w; break end end
            if not box then return false, "there is no tick box named \"Select all\" on screen" end
            if not ap.AllTicked(v.rows) then
                local on = 0
                for _, c in ipairs(v.rows) do if ap.Choice(c) then on = on + 1 end end
                return false, ("%d of %d rows are ticked"):format(on, #v.rows)
            end
            return true, ("all %d rows are ticked"):format(#v.rows)
        end },
    { text = "Untick |cffffd100Select all|r, then |cffffd100Check|r.\n\n|cffffd100Expect:|r every row of the table is unticked again.",
        check = function()
            local ap = AP(); local v = ap and ap.view
            if not (v and #v.rows > 0) then return false, "no list is shown" end
            for _, c in ipairs(v.rows) do if ap.Choice(c) then return false, "a listed row is still ticked" end end
            return true, ("all %d listed rows are unticked"):format(#v.rows)
        end },
    { text = "Press |cffffd100Generate Aura Tracking Rules for your current spec|r (a filtered list), tick |cffffd100Select all|r, then |cffffd100Check|r.\n\n|cffffd100Expect:|r every aura row is ticked. Select all only touches the rows shown, so the cooldowns and debuffs (not listed now) stay unticked.",
        check = function()
            local ap = AP(); local v = ap and ap.view
            if not (v and v.filter == "aura") then return false, "the list is not the Aura Tracking list" end
            if #v.rows == 0 then return false, "no auras to tick (your Cooldown Manager has none for this spec)" end
            if not ap.AllTicked(v.rows) then return false, "not every listed aura is ticked" end
            local others = 0
            for _, c in ipairs(ap.BuildRows(v.spec, "all")) do if c.kind ~= "aura" and ap.Choice(c) then others = others + 1 end end
            return others == 0, others == 0 and ("%d aura row(s) ticked; the cooldown and debuff rows stayed unticked"):format(#v.rows)
                or (others .. " cooldown / debuff row(s) not listed were ticked too: Select all must only touch the rows shown")
        end },
    { text = "If your class has more than one spec: press |cffffd100Generate Aura Tracking Rules for a spec you are NOT in|r, then |cffffd100Check|r.\n\n|cffffd100Expect:|r if you have played that spec since the learner was added, the auras it learned are listed (auras only). If you never did, no rows and the message: \"Auras and target debuffs are read from your Cooldown Manager for the spec you are in now. Switch to <Spec>, then press the button again.\"",
        check = function()
            local ap = AP(); local v = ap and ap.view
            if not v then return false, "nothing is listed: press the button first" end
            local cur = Current()
            if v.spec == cur or v.spec == "all" then return false, "that is your current spec: press the Aura button of another spec" end
            if v.filter ~= "aura" then return false, "that was not the Aura Tracking button" end
            local n = Count(v.rows)
            if #v.rows > 0 then
                local pure = n.cd == 0 and n.debuff == 0
                return pure, pure and (n.aura .. " learned aura(s) listed for that spec") or ("the Aura list also has other kinds: " .. Describe(n))
            end
            local txt = ap.NoneText and Plain(ap.NoneText(v)) or ""
            local good = txt:find("Switch to " .. (ap.SpecName and ap.SpecName(v.spec) or ""), 1, true) ~= nil
            return good, good and ("empty, says: " .. txt) or ("empty, but the message is: " .. txt)
        end },
    { text = "Press |cffffd100Generate All Rules for my class|r, then |cffffd100Generate CD Tracking Rules for my class|r, then |cffffd100Check|r.\n\n|cffffd100Expect:|r a Spec column after Name; the second list shows cooldowns only, from every spec.",
        check = function()
            local ap = AP(); local v = ap and ap.view
            if not v then return false, "nothing is listed: press the buttons first" end
            if v.spec ~= "all" then return false, "the list is not the class-wide list" end
            local ok, note = CheckView("cd", "all")
            if not ok then return false, note end
            local specs = {}
            for _, c in ipairs(v.rows) do specs[c.spec] = true end
            local n = 0 for _ in pairs(specs) do n = n + 1 end
            return n >= 2, n >= 2 and (note .. " from " .. n .. " specs") or ("cooldowns from only " .. n .. " spec (play the other specs once so they are learned)")
        end },
    { text = "Look at the buttons and the list. What did the addon read for the buttons?\n\n|cffffd100Your call:|r are any button names cut off, and how do the buttons wrap (two to a row, or one)? Is the header-row tick box beside |cffffd100Select all|r in the way (or would you rather have just one)? Does the table's title still reading \"Auto-populate: <Spec>\" bother you? Write what you see in the note.",
        noVerdict = true,
        check = function()
            local ok, why = Ready(); if not ok then return false, why end
            local ws = {}
            for _, b in ipairs(Widgets("Button")) do
                if b.text:find("^Generate ") then
                    local w = b.w.frame and b.w.frame.GetWidth and b.w.frame:GetWidth()
                    local tw = b.w.text and b.w.text.GetStringWidth and b.w.text:GetStringWidth()
                    ws[#ws + 1] = ("%s: button %s px, text %s px"):format(b.text, w and ("%.0f"):format(w) or "?", tw and ("%.0f"):format(tw) or "?")
                end
            end
            local rootW = Root() and Root().frame and Root().frame.GetWidth and Root().frame:GetWidth()
            return true, ("window %s px; %s"):format(rootW and ("%.0f"):format(rootW) or "?", table.concat(ws, "; "):sub(1, 400))
        end },
    { text = "Last step: press |cffffd100Do it for me|r to untick everything the walkthrough ticked and close the list.",
        setup = function()
            local ap = AP(); if not ap then return end
            if ap.view then ap.TickAll(ap.view.rows, false) end
            for _, s in ipairs(Specs()) do
                for _, c in ipairs(ap.BuildRows(s.id, "all")) do ap.SetChoice(c, "on", nil) end
            end
            ap.Close()
            local reg = LibStub and LibStub("AceConfigRegistry-3.0", true)
            if reg and reg.NotifyChange then reg:NotifyChange("CueRules") end
            if saved then saved.done = true end
        end,
        check = function()
            local ap = AP(); if not ap then return false, "the picker is not loaded" end
            if ap.view then return false, "a list is still shown" end
            local ticked = 0
            for _, s in ipairs(Specs()) do
                for _, c in ipairs(ap.BuildRows(s.id, "all")) do if ap.Choice(c) then ticked = ticked + 1 end end
            end
            return ticked == 0, ticked == 0 and "list closed, nothing ticked" or (ticked .. " row(s) still ticked")
        end },
} })
