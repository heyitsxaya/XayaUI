-------------------------------------------------------------------------------
-- QAWalks-profiles.lua (XayaUI_DevAssist 0.7.35): the in-game QA walkthrough for the settings window's new top level (Options 0.6.72;
-- REQUEST-LOG UI-23 to UI-27): the toolbar gone, the top tabs Rules | QoL | Bonus Features | Blizzard Reskin | Profiles | Settings,
-- "+ New Rule" on the Rules row, Profiles > Import / Export with components and the Recycle Bin as a sub-tab (QA H6 to H9).
-- Standing rule V22 (Xaya 2026-11-07): every step that the addon can judge offers its verdict (prefill = true; recorded only on her
-- click); steps it cannot judge say what to look at (noVerdict). Settings it changes are remembered in the first step and put back in
-- the last. Reaches the settings window only through core (ns.LoadOptions), ns.Share, ns.OptionsApi (its Profile and OpenRecycleBin) and AceConfigDialog.
-- UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end

local function NS() return rawget(_G, "XayaUI_NS") end
local function Prof() local ns = NS(); return ns and ns.OptionsApi and ns.OptionsApi.Profile end
local function ACD() return LibStub and LibStub("AceConfigDialog-3.0", true) end
local function Root() local a = ACD(); return a and a.OpenFrames and a.OpenFrames["CueRules"] end
local function Num(f, m) if not (f and f[m]) then return nil end local ok, v = pcall(f[m], f); if ok and type(v) == "number" then return v end end
local function Open(...)
    local ns = NS()
    if not (ns and ns.LoadOptions and ns.LoadOptions()) then return end
    local a = ACD(); if not a then return end
    if not (Root() and Root().frame and Root().frame:IsShown()) then a:Open("CueRules") end
    a:SelectGroup("CueRules", ...)
end
local function Find(pred)
    local function walk(w, d)
        if not w or d > 25 then return nil end
        if pred(w) then return w end
        for _, c in ipairs(w.children or {}) do local f = walk(c, d + 1); if f then return f end end
    end
    return walk(Root(), 0)
end
local function RowWith(value) return Find(function(w) if w.type ~= "TabGroup" then return false end
    for _, t in ipairs(w.tabs or {}) do if t:IsShown() and t.value == value then return true end end end) end
local function Shown(tg) local o = {}; for _, t in ipairs(tg and tg.tabs or {}) do if t:IsShown() then o[#o + 1] = t end end; return o end
local function TabText(t)
    local s = t.GetText and t:GetText()
    if s and s ~= "" then return s end
    local fs = t.GetFontString and t:GetFontString(); return (fs and fs:GetText()) or ""
end
local function Ready() if not Root() then return false, "the settings window is not open: press Do it for me" end return true end

local WANT = "Rules | QoL | Bonus Features | Blizzard Reskin | Profiles | Settings"
local function CheckTop()
    local ok, why = Ready(); if not ok then return false, why end
    local top = RowWith("profiles"); if not top then return false, "the top tab row is not on screen" end
    local names = {}
    for _, t in ipairs(Shown(top)) do names[#names + 1] = TabText(t) end
    local got = table.concat(names, " | ")
    if got ~= WANT then return false, "the top tabs read: " .. got end
    local bar = Root().frame.xuiToolbar
    if bar and bar:IsShown() then return false, "the old toolbar is still shown" end
    return true, "top tabs: " .. got .. "; no toolbar"
end

local saved
QA.Register("settings-toplevel", { title = "Settings window: new top tabs and Profiles (H6-H9)", qa = "H6, H7, H8, H9", order = 270, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: the settings window opens on |cffffd100Rules|r.\n\n|cffffd100Expect:|r no row of buttons above the tabs (no New Rule / Import / Export / Recycle Bin / Settings cog); the top tabs read " .. WANT .. ", evenly across the row.",
        setup = function()
            local db = rawget(_G, "CueRulesDB")
            saved = { sel = db and db.ui and db.ui.selStyle }
            Open("cooldowns", "smartTab")
        end,
        check = CheckTop },
    { text = "Press |cffffd100Do it for me|r: the |cffffd100Settings|r tab opens.\n\n|cffffd100Expect:|r Settings' left pane (UI Options, Minimap Button, Debugging); the other five tabs stay in the row beside it.",
        setup = function() Open("set", "ui") end,
        check = function()
            local ok, why = CheckTop(); if not ok then return false, why end
            return true, "Settings is open and the row still holds all six tabs"
        end },
    { text = "Press |cffffd100Do it for me|r: back to |cffffd100Rules|r.\n\n|cffffd100Expect:|r a flat |cffffd100+ New Rule|r button at the left end of the Smart Categories / Enabled / Disabled / Drafts row, those four even after it, Auto-Generate Rules apart at the far right.",
        setup = function() Open("cooldowns", "smartTab") end,
        check = function()
            local ok, why = Ready(); if not ok then return false, why end
            local rr = RowWith("creatorTab"); if not rr then return false, "the Rules row is not on screen" end
            local nb = rr.xuiNewRule
            if not (nb and nb:IsShown()) then return false, "no + New Rule button on the Rules row" end
            local fl, bl = Num(rr.frame, "GetLeft"), Num(nb, "GetLeft")
            local smart
            for _, t in ipairs(Shown(rr)) do if t.value == "smartTab" then smart = t end end
            local sl = smart and Num(smart, "GetLeft")
            if not (fl and bl and math.abs(bl - fl) <= 2) then return false, "the button is not at the left end of the row" end
            if not (sl and bl and sl >= bl + (Num(nb, "GetWidth") or 0) - 1) then return false, "Smart Categories does not start after the button" end
            return true, ("+ New Rule at the left end, %.0f px wide; Smart Categories after it"):format(Num(nb, "GetWidth") or 0)
        end },
    { text = "Click |cffffd100+ New Rule|r, then press |cffffd100Check|r.\n\n|cffffd100Expect:|r the rule type picker opens, as the old toolbar button did. Close it again (pick nothing).",
        noVerdict = true },
    { text = "Press |cffffd100Do it for me|r: |cffffd100Profiles|r opens.\n\n|cffffd100Expect:|r its sub-tabs read Import, Export, Recycle Bin; on Export, a tick box for each of Rules and groups, Themes, Settings, QoL, Bonus Features, Blizzard Reskin.",
        setup = function() Open("profiles", "export") end,
        check = function()
            local ok, why = Ready(); if not ok then return false, why end
            local sub = RowWith("bin"); if not sub then return false, "the Profiles sub-tab row is not on screen" end
            local names = {}
            for _, t in ipairs(Shown(sub)) do names[#names + 1] = TabText(t) end
            local got = table.concat(names, ", ")
            if got ~= "Import, Export, Recycle Bin" then return false, "Profiles' sub-tabs read: " .. got end
            local P = Prof()
            if not (P and #P.COMPONENTS == 6) then return false, "the profile components are not loaded" end
            return true, "sub-tabs: " .. got .. "; 6 components to tick"
        end },
    { text = "Press |cffffd100Do it for me|r: a profile with only |cffffd100Settings|r is made from your setup (your Selection style is remembered), your Selection style is then changed, and the profile is imported back with Settings ticked.\n\n|cffffd100Expect:|r a Reload / Later prompt (press Later); the Selection style is back as it was.",
        setup = function()
            local ns, db, P = NS(), rawget(_G, "CueRulesDB"), Prof()
            if not (ns and P and ns.Share and db) then return end
            db.ui = db.ui or {}
            saved.sel = db.ui.selStyle
            local txt = ns.Share.Encode("profile", P.Snapshot({ settings = true }, "qa"))
            db.ui.selStyle = (saved.sel == "bar") and "text" or "bar"
            local data, def = ns.Share.Read(txt or "")
            if data and def then def.Apply(data, { inc = { settings = true }, rules = "add" }) end
        end,
        check = function()
            local db = rawget(_G, "CueRulesDB")
            local now = db and db.ui and db.ui.selStyle
            return now == saved.sel, ("Selection style after the import: %s (before: %s)"):format(tostring(now), tostring(saved.sel))
        end },
    { text = "Press |cffffd100Do it for me|r: |cffffd100Profiles > Recycle Bin|r opens.\n\n|cffffd100Expect:|r the Recycle Bin page (what you deleted, with Restore and Delete now, or \"The Recycle Bin is empty\").",
        setup = function() local ns = NS(); if ns and ns.LoadOptions and ns.LoadOptions() and Root() == nil then local a = ACD(); if a then a:Open("CueRules") end end
            if ns and ns.OptionsApi and ns.OptionsApi.OpenRecycleBin then ns.OptionsApi.OpenRecycleBin() end end,
        check = function()
            local ok, why = Ready(); if not ok then return false, why end
            local a = ACD(); local st = a and a:GetStatusTable("CueRules", { "profiles" })
            local sel = st and st.groups and st.groups.selected
            return sel == "bin", "the Profiles sub-tab picked: " .. tostring(sel)
        end },
    { text = "Last step: your Selection style is put back as it was. Anything look wrong in this walkthrough (a name, a size, where + New Rule sits)? Write it in the note.",
        setup = function() local db = rawget(_G, "CueRulesDB"); if db and db.ui and saved then db.ui.selStyle = saved.sel end end,
        noVerdict = true },
} })

-- (Dev Assist 0.7.35; Options 0.6.72, Chat 0.6.38, QoL 0.7.45, Bonus 0.6.28, Reskin 0.6.10: the tab's name "Blizzard Reskin" (UI-24) in
-- every place a player reads it: the Overview switch, chat messages and tooltips; QA H10)
QA.Register("reskin-rename", { title = "Blizzard Reskin: the new name everywhere (H10)", qa = "H10", order = 271, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: the settings window opens on |cffffd100Blizzard Reskin|r.\n\n|cffffd100Expect:|r the tab reads Blizzard Reskin; its first row Overview has the switch |cffffd100Enable Blizzard Reskin|r.",
        setup = function() Open("reskin") end,
        check = function()
            local ok, why = Ready(); if not ok then return false, why end
            local ns = NS(); local name = ns and ns.OptionsApi and ns.OptionsApi.RESKIN_SWITCH
            local top = RowWith("reskin")
            local label
            for _, t in ipairs(Shown(top)) do if t.value == "reskin" then label = TabText(t) end end
            return label == "Blizzard Reskin" and name == "Enable Blizzard Reskin", ("tab: %s; switch: %s"):format(tostring(label), tostring(name))
        end },
    { text = "Type |cff88ccff/xui chat|r and |cff88ccff/xui shop|r in chat.\n\n|cffffd100Expect:|r wherever a line names the tab, it says Blizzard Reskin (never the old name with UI in it). Note anything that still says the old name.",
        noVerdict = true },
} })
