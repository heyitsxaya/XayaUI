-------------------------------------------------------------------------------
-- XayaUI_Rules/Editor/RuleSettings.lua : the rule module's rows on Settings > UI Options (the rule list's look on Display, and the Rule Creation
-- tab: drafts, the rule list, the talent scan, Combat Tracking Setup).
-- Part of the rule editor, moved out of Options.lua unchanged in the platform split P3 (Options 0.6.83;
-- docs/plans/PLATFORM-SPLIT-2026-11-07.md section 7, Q1: the rule module owns its editor). This folder talks to the rest of the
-- settings window only through ns.OptionsApi: ns.OptionsApi.Shared (what Options.lua lends it) in, ns.OptionsApi.RuleEditor (what
-- Options.lua asks of it) out; its files share their own parts through ns.OptionsApi.RuleEditorParts.
-------------------------------------------------------------------------------
local addonName, ns = ...
ns = _G.XayaUI_NS or ns   -- one namespace with XayaUI core (XayaUI Rules depends on it: ## Dependencies: XayaUI)
-- (Rules 0.7.0, REQUEST-LOG A23 SD-6) This file is part of XayaUI Rules (it was the load-on-demand addon XayaUI_Rules_Options). The game
-- reads it at login with Rules; everything below only runs when the settings window first opens with Rules on: it is one set-up
-- function, run once by XayaUI_Options (Options.lua ns.OptionsApi.LoadRuleEditor) in the .toc order. Nothing is built before then.
local function EditorFileInit()
if not (ns.OptionsApi and ns.OptionsApi.Shared) then return end   -- Options.lua stopped early (its Ace3 libraries are missing)
local O = ns.OptionsApi.Shared
local Notify = O.Notify

-- Settings > UI Options: the rows that set up the rule list (Display) and the Rule Creation tab. Moved unchanged out of Options.lua
-- BuildAddonSettings, which adds them through ns.OptionsApi.RuleEditor.SettingsRows; Ui and Repaint are that page's own helpers
-- (the platform UI settings table; a sidebar repaint and a redraw).
function ns.OptionsApi.RuleEditor.SettingsRows(Ui, Repaint)
    local display = {
        displayHeader = { type = "header", name = "Display Options", order = 20 },
        selStyle = { type = "select", name = "Selected item in the rule list", order = 21, width = "double",
            desc = "How the row you have selected stands out in the left-hand list.",
            values = { text = "Alternate text color (light purple)", bar = "Highlighted bar over the item" },
            sorting = { "text", "bar" },
            get = function() return ns.SelStyle() end,
            set = function(_, v) Ui().selStyle = (v == "bar") and "bar" or "text"; Repaint() end },
        parentGradient = { type = "toggle", name = "Gradient highlight on the top parent group of a selected nested item", order = 22, width = "full",
            desc = "Highlights the topmost parent group of the selected rule or group with a gradient.",
            get = function() return ns.ParentGradientOn() end,
            set = function(_, v) Ui().parentGradient = v and true or false; Repaint() end },
        sidebarSpellIcons = { type = "toggle", name = "Show a rule's spell / buff icon in the rule list", order = 23, width = "full",
            desc = "Shows a tracked spell or buff's icon in the left-hand list instead of the type icon. Each rule can override it (Sidebar icon).",
            get = function() return ns.SidebarSpellIcons() end,
            set = function(_, v) Ui().sidebarSpellIcons = v and true or false; Repaint() end },
    }
    local rules = { type = "group", name = "Rule Creation", order = 1.2, args = {
        savingHeader = { type = "header", name = "Saving", order = 10 },
        promptSave = { type = "toggle", name = "Use drafts (save bar)", order = 11,
            desc = "Holds rule edits until you save them, with a save bar under the window; closing it moves unsaved changes to Drafts. Off by default: every change is kept at once.",
            get = function() return ns.DraftsEnabled and ns.DraftsEnabled() or false end,
            set = function(_, v) ns.Settings("core").promptSave = v and true or false; if ns.DraftsApplySetting then ns.DraftsApplySetting() end end },
        -- draft settings (0.6.4): what asks first, how many are kept, the chat notice. Grayed out while drafts are off.
        draftsMax = { type = "range", name = "Keep up to (drafts)", order = 11.1, min = 5, max = 100, step = 1,
            desc = "The newest drafts are kept; older ones beyond this number are dropped when the window closes.",
            disabled = function() return not (ns.DraftsEnabled and ns.DraftsEnabled()) end,
            get = function() return ns.DraftsMax and ns.DraftsMax() or 30 end,
            -- (review R7) only the number is stored here: the slider calls set on every step of a drag, and trimming at each step
            -- deleted drafts for good on the way past a low number. The trim runs when the window closes (Drafts.lua DraftsOnClose).
            set = function(_, v) ns.Settings("core").draftsMax = v end },
        draftsConfirmDiscard = { type = "toggle", name = "Confirm Discard changes", order = 11.2,
            desc = "Ask before throwing away a rule's unsaved changes.",
            disabled = function() return not (ns.DraftsEnabled and ns.DraftsEnabled()) end,
            get = function() return ns.Settings("core").draftsConfirmDiscard ~= false end, set = function(_, v) ns.Settings("core").draftsConfirmDiscard = v and true or false end },
        draftsConfirmDelete = { type = "toggle", name = "Confirm deleting a draft", order = 11.3,
            desc = "Ask before a draft is deleted from the Drafts tab.",
            get = function() return ns.Settings("core").draftsConfirmDelete ~= false end, set = function(_, v) ns.Settings("core").draftsConfirmDelete = v and true or false end },
        draftsCloseNotice = { type = "toggle", name = "Chat notice on close", order = 11.4,
            desc = "When the window closes with unsaved changes, say in chat how many rules went to Drafts.",
            disabled = function() return not (ns.DraftsEnabled and ns.DraftsEnabled()) end,
            get = function() return ns.Settings("core").draftsCloseNotice ~= false end, set = function(_, v) ns.Settings("core").draftsCloseNotice = v and true or false end },
        listHeader = { type = "header", name = "Rule list", order = 20 },
        condensedList = { type = "toggle", name = "Condensed rule list (no icons, compact rows)", order = 21, width = "full",
            desc = "Drops the icons and the taller rows from the left-hand rule list and shows plain, compact rows with the +/- toggle on the left.",
            get = function() return ns.CondensedOn() end,
            set = function(_, v) Ui().condensedList = v and true or false; Repaint() end },
        -- The talent scan (Options 0.6.40; Xaya, 2026-11-05: "scan belongs in Settings"; it was in Rules > Class/Spec Rule Creator).
        -- Here because what it saves (XayaUITalentDB, XayaUI_Rules/TalentDump.lua) is read only by rule creation: the talent search of
        -- the rule editor's talent requirement lists every spec and hero tree from it. The last message stays under the button.
        talHdr = { type = "header", name = "All talents (every class and spec)", order = 30 },
        talInfo = { type = "description", order = 30.1, width = "full", fontSize = "medium",
            name = function() return (ns.TalentStatus and ns.TalentStatus() or "") .. " Reads every class, spec, and hero talent tree from the game (not from a fixed list), so it follows the current patch. In chat: /xui debug talents, /xui debug talents status, /xui debug talents <name>." end },
        talScan = { type = "execute", order = 30.2, width = "double", name = "Scan all talents now",
            func = function()
                if not ns.ScanAllTalents then return end
                local ok, m = ns.ScanAllTalents(function(_, msg) ns.OptionsApi.talentScanMsg = msg; Notify() end)
                ns.OptionsApi.talentScanMsg = m; ns.Print(m); Notify()
            end },
        talMsg = { type = "description", order = 30.3, width = "full", fontSize = "medium",
            name = function() return ns.OptionsApi.talentScanMsg or "" end,
            hidden = function() return not ns.OptionsApi.talentScanMsg end },
        -- Combat Tracking Setup (Options 0.6.55; Xaya 2026-11-06, REQUEST-LOG #81: "Rule Creation"; it was on Settings > Debugging)
        auraSetup = { type = "group", inline = true, name = "Combat Tracking Setup", order = 40, args = {
            asText = { type = "description", order = 1, fontSize = "medium",
                name = "Scans YOUR class, spec and talents, reads the game's own spell text, and learns real buff durations from your own casts out of combat. Works for every class. Runs once per spec, and any time you change talents or gear." },
            asOpen = { type = "execute", name = "Open Combat Tracking Setup", order = 2, width = "double",
                func = function() if ns.AuraSetup_Open then ns.AuraSetup_Open() else ns.Print("combat tracking setup is not loaded") end end },
            asPresence = { type = "toggle", name = "Estimate buffs the game hides in combat (from your own casts)", order = 3, width = "full",
                get = function() return ns.AuraModel and ns.AuraModel.PresenceEnabled() end,
                set = function(_, v) if ns.AuraModel then ns.AuraModel.SetSetting("presence", v and true or false) end end },
        } },
    } }
    return display, rules
end

-- (P4b) what the settings window (XayaUI_Options/Options.lua, Skin.lua) calls of the rule editor besides BuildRulesTab, SettingsRows,
-- SelectedRule and StatusText: the same functions as before, now reached through ns.OptionsApi.RuleEditor (the window may not use
-- this addon's names directly: it loads before it, and without it while XayaUI Rules is off). This is the last file of the addon,
-- so every one of them is defined by now.
do
    local RE = ns.OptionsApi.RuleEditor
    for _, n in ipairs({ "DeleteFolderAllById", "SaveRulesSub", "SmartOpen", "FixSelection", "ApplyTreeFilter", "DraftsOnOpen",
        "DraftsOnClose", "SearchOnClose", "UndoFirstState", "DeleteKey", "UndoKey", "MultiDelete", "MultiClear", "MultiReset",
        "MultiCount", "MultiMoveMenu", "SaveBarUpdate", "BuildDraftsPage", "IsEditLocked", "DraftsEnabled", "DraftDirty",
        "CurrentSub", "PickerShown", "CdmWarnArg",   -- (0.6.79, debug W1) these three for Dev Assist's walkthrough "debug-w1"
        "GoHome", "RulesTreeStatus", "ScopePath",   -- (0.6.80, debug W2) these for the Bar cue clean-up and "debug-w2" (#461)
        "MultiHas", "GoHomeKeepScroll",   -- (0.6.82, request row 20) these for Dev Assist's walkthrough "sidebar-delete"
        "MultiMerge" }) do   -- (0.6.82, request rows 19 / 23 / 27) for Dev Assist's walkthrough "merge-rules" (it checks the editor has it)
        RE[n] = ns[n]
    end
    RE.NewRule = ns.UI and ns.UI.NewRule   -- (0.6.79) + New Rule, for the same walkthrough
    RE.RuleSearch = ns.RuleSearch   -- (0.6.81, debug W3) the rule option search (Find, FindControl, folded), for "debug-w3" (#483)
end
end
ns.RuleEditorFiles = ns.RuleEditorFiles or {}
ns.RuleEditorFiles[#ns.RuleEditorFiles + 1] = EditorFileInit
