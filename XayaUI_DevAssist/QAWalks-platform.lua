-------------------------------------------------------------------------------
-- QAWalks-platform.lua (XayaUI_DevAssist 0.7.54): the in-game QA walkthrough for the Platform services of the platform split, phase P1
-- (docs/plans/PLATFORM-SPLIT-2026-11-07.md sections 6.1, 6.3, 6.4, 6.6; core 0.6.74, Options 0.6.80, Bonus 0.6.30, Nameplates 0.2.2;
-- QA H11): profile parts registered by their modules (with the new Nameplates part, and "needs <addon>" for a part whose addon is not
-- loaded), Recycle Bin kinds, theme scopes (no change without a scope) and Bonus reading the aura readers as services.
-- Standing rule V22 (Xaya 2026-11-07): every step the addon can judge offers its verdict (prefill = true; recorded only on her click).
-- Two parts around a /reload: part 1 imports a profile, part 2 (after the /reload) reads that the imported Nameplates colour was kept.
-- Part 1 keeps what it changes in its saved result ("was: ..."), which part 2 reads to put it back; no saved key of its own.
-- Reaches XayaUI only through core (ns.LoadOptions, ns.Share, ns.Service, ns.Theme, the Recycle Bin calls), ns.OptionsApi.Profile and
-- ns.OptionsApi.SetImportText / ProfilesTable (Options 0.6.80: paste a test profile into Profiles > Import and read that tab).
-- UNTESTED IN GAME.
-------------------------------------------------------------------------------
local QA = rawget(_G, "XayaUI_DevQA")
if not QA then return end

local function NS() return rawget(_G, "XayaUI_NS") end
-- (Dev Assist 0.7.55, P2 settings seam) XayaUI's settings through its views (core Modules.lua section 0b); an empty table without XayaUI
local function Settings(m) local cns = NS(); return cns and cns.Settings and cns.Settings(m) or {} end
local PlatS = Settings("platform")
local function Prof() local ns = NS(); return ns and ns.LoadOptions and ns.LoadOptions() and ns.OptionsApi and ns.OptionsApi.Profile end
local function NP() local ns = NS(); return ns and ns.Service and ns.Service("nameplates") end
local function ACD() return LibStub and LibStub("AceConfigDialog-3.0", true) end
local function Open(...)
    local ns = NS()
    if not (ns and ns.LoadOptions and ns.LoadOptions()) then return end
    local a = ACD(); if not a then return end
    local r = a.OpenFrames and a.OpenFrames["CueRules"]
    if not (r and r.frame and r.frame:IsShown()) then a:Open("CueRules") end
    a:SelectGroup("CueRules", ...)
end
local function F(c) return c and ("%.2f,%.2f,%.2f"):format(c[1] or 0, c[2] or 0, c[3] or 0) or "?" end
local function AllKeys(P) local inc = {}; for _, c in ipairs(P.COMPONENTS) do inc[c.key] = true end; return inc end

-- part 1 / part 2 state: the colour imported, and what was there before (kept in part 1's result note, read after the /reload)
local st = {}
local QA_COLOR = { 0.85, 0.30, 0.65 }
local imported   -- set by part 1's import in this session (gone after the /reload)
QA.Register("platform-services", { title = "Platform: profile parts, Recycle Bin kinds, theme scopes and Bonus services (part 1 of 2) (H11)", area = "Platform", qa = "H11", order = 272, prefill = true, steps = {
    { text = "Press |cffffd100Do it for me|r: a profile with every part this setup offers is made (Rules and groups, Themes, Settings, QoL, Bonus Features, Blizzard Reskin, and Nameplates while XayaUI Nameplates is on). Then your Nameplates target colour is set to white and the profile is imported back with only Settings and Nameplates ticked (Rules are not touched).\n\n|cffffd100Expect:|r a Reload / Later prompt (press |cffffd100Later|r). The check shows the parts the profile holds and the colour before and after. If XayaUI Nameplates is off, tick it in the AddOns list, /reload and run this again.",
        setup = function()
            local ns, P, np = NS(), Prof(), NP()
            if not (ns and P and ns.Share) then error("the settings window could not load") end
            if not np then error("XayaUI Nameplates is off: tick it in the AddOns list, /reload, run this again") end
            local d = np.DB()
            st.was = { d.color and d.color[1], d.color and d.color[2], d.color and d.color[3] }
            st.wasOn = d.targetColor and true or false
            d.color = { QA_COLOR[1], QA_COLOR[2], QA_COLOR[3] }
            local txt = ns.Share.Encode("profile", P.Snapshot(AllKeys(P), "qa"))
            d.color = { 1, 1, 1 }
            local data, def = ns.Share.Read(txt or "")
            st.held = {}
            for _, c in ipairs(P.Held(data or {})) do st.held[#st.held + 1] = c.label end
            st.res = data and def and def.Apply(data, { inc = { settings = true, nameplates = true }, rules = "add" })
            imported = true
        end,
        check = function()
            local np = NP(); if not np then return false, "XayaUI Nameplates is not loaded" end
            if not st.held then return nil, "press Do it for me first" end
            local c = np.DB().color
            local okC = c and math.abs(c[1] - QA_COLOR[1]) < 0.01 and math.abs(c[2] - QA_COLOR[2]) < 0.01 and math.abs(c[3] - QA_COLOR[3]) < 0.01
            local holdsNp = false
            for _, l in ipairs(st.held) do if l == "Nameplates" then holdsNp = true end end
            return (okC and holdsNp) and true or false, ("was: color=%s on=%s; parts held: %s; colour after the import: %s (want %s)"):format(
                F(st.was), st.wasOn and "1" or "0", table.concat(st.held, ", "), F(c), F(QA_COLOR))
        end },
    { text = "Press |cffffd100Do it for me|r: a test profile is pasted into |cffffd100Profiles > Import|r. It holds your Settings and one part of an addon that does not exist (\"XayaUI QA Example\").\n\n|cffffd100Expect:|r under \"Parts to import\" a tick box for Settings and the line |cffffd100needs XayaUI QA Example|r. Do not press Import (the check imports it for you: the part is skipped, nothing of it is written).",
        setup = function()
            local ns, P = NS(), Prof()
            local api = ns and ns.OptionsApi
            if not (P and ns.Share and api and api.SetImportText) then error("the settings window could not load") end
            local data = P.Snapshot({ settings = true }, "qa needs")
            data.parts.qa_needs = { marker = 1 }
            data.partInfo = { qa_needs = { v = 1, module = "XayaUI_QAExample", title = "XayaUI QA Example", label = "QA Example" } }
            st.needsText = ns.Share.Encode("profile", data)
            api.SetImportText(st.needsText)
            Open("profiles", "import")
        end,
        check = function()
            local ns, P = NS(), Prof()
            if not (ns and P and st.needsText) then return nil, "press Do it for me first" end
            local pt = ns.OptionsApi and ns.OptionsApi.ProfilesTable and ns.OptionsApi.ProfilesTable()
            local line = pt and pt.args.import.args.needs_qa_needs
            local data, def = ns.Share.Read(st.needsText)
            local res = data and def and def.Apply(data, { inc = { qa_needs = true }, rules = "add" })
            local skipped = res and res.skipped and res.skipped[1]
            local ok = line and line.name == "needs XayaUI QA Example" and skipped == "XayaUI QA Example" and #(res.done or {}) == 0
            return ok and true or false, ("Import shows: %s; importing only that part: skipped %s, imported %d part(s)"):format(
                tostring(line and line.name), tostring(skipped), res and #(res.done or {}) or -1)
        end },
    { text = "Press |cffffd100Do it for me|r: a test rule \"QA bin test rule\" (switched off) is made, deleted into the Recycle Bin and restored through the bin's registered \"rule\" kind; a bin item of a kind no addon registers is added too.\n\n|cffffd100Expect:|r the check says the rule is back and the bin item is gone; the unknown item reads \"(qaUnknown: module not loaded)\", Restore refuses it and it stays in the bin. Open |cffffd100Profiles > Recycle Bin|r to see that line.",
        setup = function()
            local ns = NS()
            if not (ns and ns.rules and ns.RecycleRule and ns.RecycleRestore and ns.RecycleDB) then error("the Recycle Bin is not loaded") end
            local r = { name = "QA bin test rule", enabled = false }
            if ns.NormalizeRule then pcall(ns.NormalizeRule, r) end
            ns.rules[#ns.rules + 1] = r
            st.binRule = r
            local it = ns.RecycleRule(r)
            st.inBin = it and it.id
            st.binOk, st.binNote = ns.RecycleRestore(it and it.id or -1)
            local b = ns.RecycleDB()
            st.unknownId = (b.nextId or 1); b.nextId = st.unknownId + 1
            b.items[#b.items + 1] = { id = st.unknownId, kind = "qaUnknown", name = "QA unknown kind", deletedAt = time(), rules = {} }
            st.unkOk, st.unkNote = ns.RecycleRestore(st.unknownId)
            Open("profiles", "bin")
        end,
        check = function()
            local ns = NS()
            if not (st.binRule and ns) then return nil, "press Do it for me first" end
            local back = false
            for _, x in ipairs(ns.rules or {}) do if x == st.binRule then back = true end end
            local stays, what = false, nil
            for _, x in ipairs(ns.RecycleItems()) do if x.id == st.unknownId then stays = true; what = x.what end end
            local ok = back and st.binOk and st.unkOk == false and stays and what == "(qaUnknown: module not loaded)"
            return ok and true or false, ("rule back: %s (restore said %s); unknown item: restore %s, still in the bin: %s, reads %s"):format(
                back and "yes" or "NO", tostring(st.binOk), tostring(st.unkOk), stays and "yes" or "NO", tostring(what))
        end },
    { text = "Press |cffffd100Do it for me|r: every theme colour is read, then the Tooltips page (Blizzard Reskin) gets its own button colour and Blizzard Reskin as a whole its own window colour (theme scopes; nothing paints with them yet), every colour is read again, and both overrides are removed.\n\n|cffffd100Expect:|r nothing on screen changes. The check compares the two readings: every colour asked for without a scope is the same; the Tooltips scope gave its own colours.",
        setup = function()
            local ns = NS(); local T = ns and ns.Theme
            if not (T and T.SetScopeToken) then error("theme scopes are not loaded") end
            local function read() local o = {}; for _, c in ipairs(T.CLASSES) do for prop in pairs(c[3]) do o[c[1] .. "." .. prop] = T.Col(c[1], prop) end end; return o end
            st.before = read()
            T.SetScopeToken("reskin.tooltips", "buttonBg", { 0.9, 0.1, 0.1, 1 })
            T.SetScopeClassColor("reskin", "xui-window", "bg", { 0.1, 0.9, 0.1, 1 })
            st.after = read()
            st.scoped = T.Col("xui-button", "bg", "reskin.tooltips")
            st.scopedWin = T.Col("xui-window", "bg", "reskin.tooltips")
            T.SetScopeToken("reskin.tooltips", "buttonBg", nil)
            T.SetScopeClassColor("reskin", "xui-window", "bg", nil)
            local th = PlatS.theme
            st.left = th and th.scopes ~= nil
        end,
        check = function()
            if not st.before then return nil, "press Do it for me first" end
            local diff = {}
            for k, a in pairs(st.before) do
                local b = st.after[k]
                if not (b and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4]) then diff[#diff + 1] = k end
            end
            local s, w = st.scoped, st.scopedWin
            local okS = s and math.abs(s[1] - 0.9) < 0.01 and w and math.abs(w[2] - 0.9) < 0.01
            local ok = #diff == 0 and okS and not st.left
            return ok and true or false, ("colours without a scope that changed: %d%s; Tooltips scope: button %s, window %s; overrides left stored: %s"):format(
                #diff, #diff > 0 and (" (" .. table.concat(diff, ", ") .. ")") or "", F(s), F(w), st.left and "YES" or "no")
        end },
    { text = "Press |cffffd100Do it for me|r: XayaUI Bonus's enhanced tooltip reads which auras a spell applies, once as now (rule tracking offers its aura readers as services) and once with those services hidden for that one read (as when rule tracking is switched off in a later version).\n\n|cffffd100Expect:|r both reads run without an error; without the services the list has no more auras than with them. Then hover a spell you know the buff of: the tooltip's Aura ID lines are as before.",
        setup = function()
            local ns = NS()
            local tt = ns and ns.Service and ns.Service("tooltipsDebug")
            local TT = tt and tt.TT
            if not (TT and TT.AurasFor) then error("XayaUI Bonus (enhanced tooltips) is not loaded") end
            st.svcAS, st.svcAM = ns.Service("AuraSources") ~= nil, ns.Service("AuraModel") ~= nil
            local spell = 1459   -- Arcane Intellect (any spell ID works: the read only lists what is known)
            local ok1, with = pcall(TT.AurasFor, "spell", spell, nil)
            local real = ns.Service
            ns.Service = function(n) if n == "AuraSources" or n == "AuraModel" then return nil end return real(n) end
            local ok2, without = pcall(TT.AurasFor, "spell", spell, nil)
            ns.Service = real
            st.tt = { ok1 = ok1, n1 = ok1 and type(with) == "table" and #with or -1, ok2 = ok2, n2 = ok2 and type(without) == "table" and #without or -1,
                err = (not ok1 and tostring(with)) or (not ok2 and tostring(without)) or nil }
        end,
        check = function()
            local t = st.tt
            if not t then return nil, "press Do it for me first" end
            local ok = st.svcAS and st.svcAM and t.ok1 and t.ok2 and t.n2 <= t.n1
            return ok and true or false, ("services offered: AuraSources %s, AuraModel %s; with them: %d aura(s); without them: %d aura(s)%s"):format(
                st.svcAS and "yes" or "NO", st.svcAM and "yes" or "NO", t.n1, t.n2, t.err and ("; error: " .. t.err) or "")
        end },
    { done = true, text = "Press |cffffd100Do it for me|r to remove the QA test rule and the unknown bin item again. Then press |cffffd100Done|r here first (so part 1's record is kept), type |cffffd100/reload|r, and run \"Platform: the imported Nameplates colour after the /reload (part 2 of 2)\".",
        setup = function()
            local ns = NS(); if not ns then return end
            local first
            for i = #(ns.rules or {}), 1, -1 do if ns.rules[i] == st.binRule then table.remove(ns.rules, i); first = i end end
            if QA.LeaveMovedRuleRow then QA.LeaveMovedRuleRow(first) end   -- (0.7.64, debug W3: no editor sliding onto the next rule)
            if ns.RecycleDeleteNow and st.unknownId then ns.RecycleDeleteNow(st.unknownId) end
            if ns.MarkDirty then ns.MarkDirty() end
        end },
} })

QA.Register("platform-services-reload", { title = "Platform: the imported Nameplates colour after the /reload (part 2 of 2) (H11)", area = "Platform", qa = "H11", order = 272.1, prefill = true, steps = {
    { text = "Run this after part 1 and its /reload.\n\n|cffffd100Expect:|r your target's nameplate in the pink-purple colour part 1 imported (target an enemy with a nameplate to see it). The check reads the saved colour.",
        check = function()
            if imported then return nil, "not reloaded yet: type /reload, then come back and Check again" end
            local note = QA.SeenNote("platform-services", 1)
            if not note then return nil, "part 1 has no record: run it to its end first (press Done before the /reload)" end
            local np = NP(); if not np then return false, "XayaUI Nameplates is not loaded" end
            local r, g, b = np.Color()
            local ok = math.abs(r - QA_COLOR[1]) < 0.01 and math.abs(g - QA_COLOR[2]) < 0.01 and math.abs(b - QA_COLOR[3]) < 0.01
            return ok, ("saved colour after the /reload: %.2f,%.2f,%.2f (imported: %s)"):format(r, g, b, F(QA_COLOR))
        end },
    { done = true, text = "Last step: press |cffffd100Do it for me|r to put your Nameplates target colour and switch back as they were before part 1 (from part 1's record). Then press |cffffd100Done|r.",
        setup = function()
            local np = NP(); if not np then error("XayaUI Nameplates is not loaded") end
            local note = QA.SeenNote("platform-services", 1) or ""
            local r, g, b, on = note:match("was: color=([%d%.]+),([%d%.]+),([%d%.]+) on=(%d)")
            if not r then error("part 1's record of your colour is missing: set QoL > Nameplates yourself") end
            local d = np.DB()
            d.color = { tonumber(r), tonumber(g), tonumber(b) }
            d.targetColor = on == "1"
            if np.TargetColor and np.TargetColor.Apply then pcall(np.TargetColor.Apply) end
        end },
} })

-------------------------------------------------------------------------------
-- (Dev Assist 0.7.72) Main without Blizzard Reskin and Nameplates (QA A5; REQUEST-LOG TRI-4, TRI-6, TRI-7, 2026-11-08). Xaya: main
-- holds only core + settings, Rules, QoL and Bonus Features (Chat counts as Bonus Features), plus Dev Assist and Media; "just remove
-- all blizzard reskins for the time being". XayaUI_Reskin and XayaUI_Nameplates live on qa-installer-branch (tools/qa-only-paths.txt).
-- Pre-fill (V22): step 1 reads each addon's state from core (ns.ModuleState); step 2 counts new XayaUI errors while the window opens
-- and lists its top tabs; step 3 reads Dev Assist's own list. UNTESTED IN GAME.
-------------------------------------------------------------------------------
do
    local function NSm() return rawget(_G, "XayaUI_NS") end
    local function Errs() local ns = NSm(); local n = ns and ns.ErrorCount and ns.ErrorCount(); return tonumber(n) or 0 end
    local function State(a)
        local ns = NSm()
        if not (ns and ns.ModuleState) then return "unknown" end
        local ok, s = pcall(ns.ModuleState, a)
        return ok and s or "unknown"
    end
    local function OptApi()
        local ns = NSm()
        if not (ns and ns.LoadOptions and ns.LoadOptions()) then return nil end
        return ns.OptionsApi
    end
    local QA_ONLY = { "XayaUI_Reskin", "XayaUI_Nameplates" }
    local ON_MAIN = { "XayaUI", "XayaUI_Rules", "XayaUI_Chat", "XayaUI_QoL", "XayaUI_Bonus", "XayaUI_Media" }
    local ms = {}
    QA.Register("main-slim", { title = "Main without Blizzard Reskin and Nameplates (A5)", area = "Platform", qa = "A5", order = 272.9, prefill = true, steps = {
        { text = "Install only what |cffffd100main|r holds now: XayaUI, XayaUI_Options, XayaUI_Rules, XayaUI_Rules_Options, XayaUI_Chat, XayaUI_QoL, XayaUI_Bonus, XayaUI_DevAssist (and XayaUI_Media). Delete |cffffd100XayaUI_Reskin|r and |cffffd100XayaUI_Nameplates|r from your AddOns folder if they are there, then |cffffd100/reload|r and open this walkthrough again.\n\n|cffffd100Expect:|r no red Lua error at login. The check reads whether Blizzard Reskin and Nameplates are installed (they should not be) and lists the other addons' states and XayaUI's saved error count (old errors from earlier sessions count too).",
            check = function()
                local out, ok = {}, true
                for _, a in ipairs(QA_ONLY) do
                    local s = State(a)
                    out[#out + 1] = a:gsub("XayaUI_", "") .. ": " .. s
                    if s ~= "missing" then ok = false end
                end
                local others = {}
                for _, a in ipairs(ON_MAIN) do others[#others + 1] = a:gsub("XayaUI_", "") .. " " .. State(a) end
                return ok, ("%s (should be missing); %s; XayaUI errors saved: %d"):format(table.concat(out, ", "), table.concat(others, ", "), Errs())
            end },
        { text = "Press |cffffd100Do it for me|r: the settings window opens.\n\n|cffffd100Expect:|r it opens with no Lua error. The Blizzard UI tab still holds the Chat Panel and the Character Pane, but no Blizzard Reskin pages (Esc Menu, Blizzard windows, tooltips ...). The check counts new XayaUI errors and lists the top tabs.",
            setup = function()
                local api = OptApi(); if not api then error("the settings window addon (XayaUI_Options) could not be loaded") end
                ms.err0 = Errs()
                if not api.IsOpen() then api.Toggle() end
            end,
            check = function()
                local api = OptApi(); if not (api and ms.err0) then return nil, "press Do it for me first" end
                local tabs, tree = {}, api.LastTree and api.LastTree()
                for k in pairs(tree and tree.args or {}) do tabs[#tabs + 1] = k end
                table.sort(tabs)
                local e = Errs() - ms.err0
                return (api.IsOpen() and e == 0) and true or false, ("open: %s; new XayaUI errors: %d; top tabs: %s"):format(tostring(api.IsOpen()), e, table.concat(tabs, ", "))
            end },
        { text = "No action: the check reads Dev Assist's own walkthrough list.\n\n|cffffd100Expect:|r no walkthrough and no checklist step for Blizzard Reskin or Nameplates is listed while those addons are not installed (they stay on qa-installer-branch).",
            check = function()
                local bad, n, hidden = 0, 0, 0
                for _, id in ipairs(QA.list) do
                    local def = QA.walks[id]
                    n = n + 1
                    if def.needs and QA.Missing(def.needs) then bad = bad + 1 end
                    for _, st in ipairs(def.steps or {}) do
                        if type(st) == "table" and st.needs and QA.Missing(st.needs) then bad = bad + 1 end
                    end
                end
                for _, a in ipairs(QA_ONLY) do if QA.Missing(a) then hidden = hidden + 1 end end
                return bad == 0, ("%d walkthroughs listed; %d walkthroughs or steps for a missing addon; %d of 2 QA-branch addons missing here"):format(n, bad, hidden)
            end },
        { done = true, text = "Last step: press |cffffd100Do it for me|r to close the settings window. Then press |cffffd100Done|r.",
            setup = function()
                local api = OptApi()
                if api and api.IsOpen() then api.Toggle() end
                ms.closed = true
            end,
            check = function() return ms.closed == true, ms.closed and "closed" or "not closed yet" end },
    } })
end
