-- XayaUI: Save changes + Drafts.
-- While the options window is open, every ROOT rule (a rule together with its cues and conditions) has a saved version: what it looked like when the
-- window opened, or when you last pressed "Save changes". Edits still apply at once so you can test them in game, but a rule that differs from its
-- saved version shows "Save changes" / "Discard changes". If the window closes (or you log out) with unsaved changes, the edited rule is kept in the
-- Drafts page and the rule itself goes back to its saved version. A rule made in this window and never saved lives only in Drafts after closing.
-- Not counted as changes (they follow what you do in the sidebar, not what the rule does): on / off, name, group, collapse state, sidebar icon, edit lock.
local addonName, ns = ...
ns = _G.XayaUI_NS or ns   -- one namespace with XayaUI core (this addon depends on it: ## Dependencies: XayaUI)

local baseline = {}      -- [rootUid] = { sig = string, rules = { deep copies }, isNew = true when the rule was made in this window and never saved }
local windowOpen = false
local MAX_DRAFTS = 30   -- default; Settings > UI Options > Rule Creation > "Keep up to" (ui.draftsMax, 5 to 100)
-- Draft settings (0.6.4, Settings > UI Options > Rule Creation). All default to the behavior before they existed.
local function DUi() return (CueRulesDB and CueRulesDB.ui) or {} end
function ns.DraftsMax() local n = tonumber(DUi().draftsMax) or MAX_DRAFTS; return math.max(5, math.min(100, math.floor(n))) end
function ns.DraftsConfirmDiscard() return DUi().draftsConfirmDiscard ~= false end
function ns.DraftsConfirmDelete() return DUi().draftsConfirmDelete ~= false end
function ns.DraftsCloseNotice() return DUi().draftsCloseNotice ~= false end

local ROOT_IGNORE = { enabled = true, folder = true, name = true, ocCollapsed = true, listIcon = true, listIconID = true, editLocked = true }
local CHILD_IGNORE = { folder = true, ocCollapsed = true, spellID = true, buffID = true, maxCharges = true, listIcon = true, listIconID = true, editLocked = true }

-- stable text form of a value (sorted keys), used only to compare two states of a rule
local function KeyLess(a, b)
    local ta, tb = type(a), type(b)
    if ta ~= tb then return ta < tb end
    if ta == "number" or ta == "string" then return a < b end
    return tostring(a) < tostring(b)
end
-- An empty table counts as missing (audit D23: just opening a rule's Load tab makes its getters create empty load.classes / specs / roles
-- / heroes / instanceTypes tables, which read the same as no table; before, that alone counted as "unsaved changes").
local function Blank(x)   -- a table holding nothing but (nested) empty tables
    if type(x) ~= "table" then return false end
    for _, y in pairs(x) do if not Blank(y) then return false end end
    return true
end
local function Ser(v, out, ignore)
    local t = type(v)
    if t == "table" then
        local keys = {}
        for k, x in pairs(v) do if not (ignore and ignore[k]) and not Blank(x) then keys[#keys + 1] = k end end
        table.sort(keys, KeyLess)
        out[#out + 1] = "{"
        for _, k in ipairs(keys) do out[#out + 1] = tostring(k); out[#out + 1] = "="; Ser(v[k], out); out[#out + 1] = ";" end
        out[#out + 1] = "}"
    elseif t == "number" then out[#out + 1] = string.format("%.6g", v)
    elseif t == "string" then out[#out + 1] = string.format("%q", v)
    elseif t == "boolean" then out[#out + 1] = v and "T" or "F"
    else out[#out + 1] = "?" end
end

-- the root rule and its cues / conditions, in list order
local function GroupOf(uid)
    local out = {}
    if type(uid) ~= "string" then return out end
    for _, r in ipairs(ns.rules or {}) do
        if r.uid == uid and not r.parentUid then out[#out + 1] = r; break end
    end
    if #out == 0 then return out end
    for _, r in ipairs(ns.rules) do
        if r.parentUid == uid then out[#out + 1] = r end
    end
    return out
end
local function Sig(group)
    local out = {}
    for i, r in ipairs(group) do
        out[#out + 1] = "#"
        Ser(r, out, (i == 1) and ROOT_IGNORE or CHILD_IGNORE)
    end
    return table.concat(out)
end
local function Copies(group)
    local out = {}
    for _, r in ipairs(group) do out[#out + 1] = ns.Copy(r) end
    return out
end
local function RootOf(rule)
    if not rule then return nil end
    if rule.parentUid then return ns.FindParentRule and ns.FindParentRule(rule) or nil end
    return rule
end

-- Replace the rules of a group by `copies` (fresh tables), at the place the root had in the list. Visuals are rebuilt.
local function ReplaceGroup(uid, copies)
    local old, kept, at = {}, {}, nil
    for _, r in ipairs(ns.rules) do
        if (r.uid == uid and not r.parentUid) or r.parentUid == uid then
            old[#old + 1] = r
            at = at or (#kept + 1)
        else
            kept[#kept + 1] = r
        end
    end
    at = at or (#kept + 1)
    local merged = {}
    for i = 1, at - 1 do merged[#merged + 1] = kept[i] end
    for _, c in ipairs(copies) do merged[#merged + 1] = c end
    for i = at, #kept do merged[#merged + 1] = kept[i] end
    for i = #ns.rules, 1, -1 do ns.rules[i] = nil end   -- ns.rules is the saved table itself: change it in place
    for i, r in ipairs(merged) do ns.rules[i] = r end
    for _, r in ipairs(old) do pcall(ns.DropVisual, r) end
    for _, c in ipairs(copies) do pcall(ns.RefreshVisual, c) end
    ns.MarkDirty()
end
local function RemoveGroup(uid)
    ReplaceGroup(uid, {})
end

local function Drafts()
    if not CueRulesDB then return {} end
    CueRulesDB.drafts = CueRulesDB.drafts or {}
    return CueRulesDB.drafts
end

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------
local cache = { t = -1 }
-- "Prompt for saving and enable drafts" (Settings > UI Options). Off by default: edits are kept as you make them, there is no save bar,
-- and closing the window never moves anything to Drafts. On: the behaviour described in the guide (section 12.2).
function ns.DraftsEnabled()
    local ui = CueRulesDB and CueRulesDB.ui
    return ui ~= nil and ui.promptSave == true
end
function ns.DraftDirty(rule)
    if not ns.DraftsEnabled() then return false end
    local root = RootOf(rule)
    if not (root and root.uid) then return false end
    local b = baseline[root.uid]
    if not b then return false end
    if b.isNew then return true end
    local now = GetTime and GetTime() or 0
    if cache.t ~= now then cache = { t = now } end
    local c = cache[root.uid]
    if c == nil then
        local group = GroupOf(root.uid)
        c = (#group > 0) and (Sig(group) ~= b.sig) or false
        cache[root.uid] = c
    end
    return c
end
function ns.DraftIsNew(rule)
    local root = RootOf(rule)
    local b = root and root.uid and baseline[root.uid]
    return b and b.isNew and true or false
end

-- V14 (Options 0.6.41; Xaya 2026-11-05: "anything that is disabled in the addon through a tick box should NEVER LOAD or contribute to
-- performance cost / demand in any way"). With "Use drafts" off (the default) nothing is copied when the window opens: up to 0.6.40
-- every rule was deep-copied at every opening and the copies thrown away at the close. The undo journal (Ctrl+Z, below) also starts
-- from a rule's saved version; with drafts off it gets one copy of just the rule being edited, taken when the rule is shown in the
-- window (ns.UndoFirstState: the window shows a rule before anything in it can be edited). The logout watch that moves unsaved rules
-- to Drafts is registered only while the window is open with drafts on.
local logoutWatch
local function WatchLogout(on)
    if on then
        if not logoutWatch then
            logoutWatch = CreateFrame("Frame")
            logoutWatch:SetScript("OnEvent", function() pcall(ns.DraftsOnClose) end)
        end
        logoutWatch:RegisterEvent("PLAYER_LOGOUT")
    elseif logoutWatch then
        logoutWatch:UnregisterEvent("PLAYER_LOGOUT")
    end
end
local function TakeAllBaselines()
    for _, r in ipairs(ns.rules) do
        if not r.parentUid and r.isCue ~= true and type(r.uid) == "string" then
            local group = GroupOf(r.uid)
            baseline[r.uid] = { sig = Sig(group), rules = Copies(group) }
        end
    end
end

-- called when the options window opens: remember the saved version of every rule (drafts on)
function ns.DraftsOnOpen()
    if windowOpen or not ns.rules then return end
    windowOpen = true
    wipe(baseline)
    if ns.UndoReset then ns.UndoReset() end
    cache = { t = -1 }
    local used = {}
    for _, r in ipairs(ns.rules) do if type(r.uid) == "string" then used[r.uid] = true end end
    for _, r in ipairs(ns.rules) do
        if not r.parentUid and type(r.uid) ~= "string" then
            local u = ns.NewUID()
            while used[u] do u = ns.NewUID() end
            used[u] = true
            r.uid = u
        end
    end
    if ns.DraftsEnabled() then
        TakeAllBaselines()
        WatchLogout(true)
    elseif ns.UndoFirstState then
        ns.UndoFirstState()
    end
end

-- The setting was switched while the window is open: the rules as they are right now become the saved versions (turning it on starts with
-- a clean slate; turning it off keeps every edit), then the window is redrawn without or with the save bar.
function ns.DraftsApplySetting()
    cache = { t = -1 }
    wipe(baseline)
    local on = ns.DraftsEnabled()
    if windowOpen and ns.rules and on then TakeAllBaselines() end
    WatchLogout(windowOpen and on)
    if windowOpen and not on and ns.UndoFirstState then ns.UndoFirstState() end
    if ns.UI and ns.UI.Notify then pcall(ns.UI.Notify) end
end

-- a rule made in the open window: nothing saved yet, so closing without "Save changes" keeps it only in Drafts
-- Rebuild the on-screen displays of a group and redraw the options tree now and once more next frame (the second pass catches
-- rows that only exist after the first rebuild). Called after a save, after the window closes, and after the window opens.
function ns.RefreshSidebar(group)
    for _, r in ipairs(group or {}) do pcall(ns.RefreshVisual, r) end
    local function go() if ns.UI and ns.UI.Notify then pcall(ns.UI.Notify) end end
    go()
    if C_Timer then C_Timer.After(0, go) end
end

function ns.DraftNew(rule)
    if not ns.DraftsEnabled() then return end   -- autosave mode: a new rule is simply kept
    if not windowOpen or not rule or rule.parentUid then return end
    if type(rule.uid) ~= "string" then rule.uid = ns.NewUID() end
    baseline[rule.uid] = { isNew = true }
    if ns.UndoSeed then ns.UndoSeed(rule.uid) end
    cache = { t = -1 }
end

function ns.DraftSave(rule)
    local root = RootOf(rule)
    if not (root and root.uid) then return end
    local group = GroupOf(root.uid)
    baseline[root.uid] = { sig = Sig(group), rules = Copies(group) }
    local list = Drafts()
    for i = #list, 1, -1 do if list[i].uid == root.uid then table.remove(list, i) end end
    cache = { t = -1 }
    ns.MarkDirty()
    ns.RefreshSidebar(group)   -- a saved edit redraws the displays and the side panel (icons, names, eyes) right away
end

-- put the root's saved version back, keeping what the sidebar controls (on / off, name, group) as they are now
local function Revert(uid)
    local b = baseline[uid]
    local live = GroupOf(uid)[1]
    if not b then return end
    if b.isNew or not b.rules then RemoveGroup(uid); baseline[uid] = nil; return end
    local copies = Copies({ unpack(b.rules) })
    local root = copies[1]
    if live and root then for k in pairs(ROOT_IGNORE) do root[k] = live[k] end end
    for i = 2, #copies do if live then copies[i].folder = live.folder end end
    ReplaceGroup(uid, copies)
end

function ns.DraftDiscard(rule)
    local root = RootOf(rule)
    if not (root and root.uid) then return end
    local uid, wasNew = root.uid, baseline[root.uid] and baseline[root.uid].isNew
    Revert(uid)
    if wasNew then baseline[uid] = nil
    else
        -- the reverted rule IS the saved version now: take the baseline again from the live copy, so nothing the rebuild added to it
        -- can make it compare as "changed" and keep the Unsaved changes bar showing on the other tabs
        local g = GroupOf(uid)
        if #g > 0 then baseline[uid] = { sig = Sig(g), rules = Copies(g) } end
    end
    cache = { t = -1 }
    if not wasNew and ns.ReselectRule then local r = GroupOf(uid)[1]; if r then pcall(ns.ReselectRule, r) end end
    if ns.UI and ns.UI.Notify then
        ns.UI.Notify()
        if C_Timer then C_Timer.After(0, function() cache = { t = -1 }; ns.UI.Notify() end) end   -- a second pass next frame redraws the other tabs
    end
end

local function StoreDraft(uid, group, isNew)
    local list = Drafts()
    for i = #list, 1, -1 do if list[i].uid == uid then table.remove(list, i) end end
    local root = group[1]
    local nm = root and tostring(root.name or "") or ""
    table.insert(list, 1, { id = uid .. ":" .. tostring(time()), uid = uid, name = (nm ~= "") and nm or "Unnamed rule", ts = time(), isNew = isNew and true or nil, rules = Copies(group) })
    while #list > ns.DraftsMax() do table.remove(list) end
end
-- the "Keep up to" number was lowered: drop the oldest drafts beyond it now
function ns.DraftsTrim()
    local list = Drafts()
    while #list > ns.DraftsMax() do table.remove(list) end
end

-- the window closed (or the game is logging out): unsaved rules go to Drafts and go back to their saved version
function ns.DraftsOnClose()
    if not windowOpen then return end
    windowOpen = false
    WatchLogout(false)
    if ns.UndoReset then ns.UndoReset() end
    cache = { t = -1 }
    if not ns.DraftsEnabled() then wipe(baseline); return end   -- autosave mode: everything stays as edited
    local moved, names = 0, {}
    for uid, b in pairs(baseline) do
        local group = GroupOf(uid)
        if #group > 0 and (b.isNew or Sig(group) ~= b.sig) then
            StoreDraft(uid, group, b.isNew)
            Revert(uid)
            moved = moved + 1
            names[#names + 1] = tostring(group[1].name or "")
        end
    end
    wipe(baseline)
    ns.RefreshSidebar()   -- reverted rules: redraw the side panel so it matches what is saved
    if moved > 0 and ns.Print and ns.DraftsCloseNotice() then
        ns.Print(("%d rule(s) had unsaved changes. The changes were kept in Drafts (toolbar > Drafts) and the rule(s) went back to the last saved version."):format(moved))
    end
end


-------------------------------------------------------------------------------
-- Save variants (0.5.31): save as a copy / add to drafts / add a copy to drafts
-------------------------------------------------------------------------------
-- A copy of a rule group under a new identity: the root gets a new uid and `suffix` after its name; its cues / conditions follow the new root.
local function CopyGroup(group, suffix)
    local copies = Copies(group)
    local root = copies[1]
    if not root then return nil end
    local used = {}
    for _, r in ipairs(ns.rules or {}) do if type(r.uid) == "string" then used[r.uid] = true end end
    local u = ns.NewUID()
    while used[u] do u = ns.NewUID() end
    root.uid = u
    local nm = tostring(root.name or "")
    root.name = ((nm ~= "") and nm or "Rule") .. suffix
    for i = 2, #copies do copies[i].uid = nil; copies[i].parentUid = u end
    return copies, u
end

-- Save as a copy: the edited version becomes a NEW saved rule next to the original; the original goes back to its last saved version.
-- Not offered for a rule that was never saved (it has no saved version to go back to; use Save changes).
function ns.DraftSaveAsCopy(rule)
    local root = RootOf(rule)
    if not (root and root.uid) or ns.DraftIsNew(root) then return end
    local uid = root.uid
    local copies, newUid = CopyGroup(GroupOf(uid), " Copy")
    if not copies then return end
    local origName = tostring(root.name or "")
    Revert(uid)
    local g = GroupOf(uid)
    if #g > 0 then baseline[uid] = { sig = Sig(g), rules = Copies(g) } end   -- the original is its saved version again
    for _, c in ipairs(copies) do ns.rules[#ns.rules + 1] = c end
    for _, c in ipairs(copies) do pcall(ns.RefreshVisual, c) end
    if windowOpen then
        local cg = GroupOf(newUid)
        baseline[newUid] = { sig = Sig(cg), rules = Copies(cg) }   -- the copy counts as saved
    end
    cache = { t = -1 }
    ns.MarkDirty()
    if ns.Print then ns.Print(("Saved your edits as a new rule '%s'. '%s' went back to its last saved version."):format(tostring(copies[1].name), origName)) end
    if ns.ReselectRule then local r = GroupOf(newUid)[1]; if r then pcall(ns.ReselectRule, r) end end
    if ns.UI and ns.UI.Notify then
        ns.UI.Notify()
        if C_Timer then C_Timer.After(0, function() cache = { t = -1 }; ns.UI.Notify() end) end
    end
end

-- Add to drafts: the edited version moves to the Drafts page and the rule goes back to its last saved version (a never-saved rule leaves the list).
function ns.DraftAddToDrafts(rule)
    local root = RootOf(rule)
    if not (root and root.uid) then return end
    local uid = root.uid
    local group = GroupOf(uid)
    if #group == 0 then return end
    local b = baseline[uid]
    StoreDraft(uid, group, b and b.isNew)
    local nm = tostring(root.name or "")
    ns.DraftDiscard(root)
    if ns.Print then ns.Print(("Your edits to '%s' were added to Drafts. The rule is back at its last saved version."):format(nm ~= "" and nm or "Unnamed rule")) end
end

-- Add a copy to drafts: the edited version is stored in Drafts as a separate, never-saved rule; the rule itself stays open and unsaved as it is.
function ns.DraftAddCopyToDrafts(rule)
    local root = RootOf(rule)
    if not (root and root.uid) then return end
    local copies, newUid = CopyGroup(GroupOf(root.uid), " Copy")
    if not copies then return end
    StoreDraft(newUid, copies, true)
    if ns.Print then ns.Print(("A copy of '%s' was added to Drafts. This rule is unchanged and still has unsaved edits."):format(tostring(root.name or ""))) end
    if ns.UI and ns.UI.Notify then ns.UI.Notify() end
end


-------------------------------------------------------------------------------
-- Drafts page actions
-------------------------------------------------------------------------------
-- What Restore says before it replaces a live rule while drafts are off (audit D22): nothing to Save then, so it is kept at once.
function ns.DraftRestoreConfirm(id)
    if ns.DraftsEnabled() then return false end
    for _, d in ipairs(Drafts()) do
        if d.id == id and #GroupOf(d.uid) > 0 then
            return "Drafts are off, so this replaces the rule '" .. tostring(d.name or "Unnamed rule") .. "' with the draft right away and keeps it. Replace it?"
        end
    end
    return false
end
function ns.DraftRestore(id)
    local list = Drafts()
    for i, d in ipairs(list) do
        if d.id == id then
            local copies = Copies(d.rules or {})
            if #copies == 0 then table.remove(list, i); return end
            local uid = d.uid
            local keepRoot = GroupOf(uid)[1]
            if keepRoot and ns.IsEditLocked and ns.IsEditLocked(keepRoot) then   -- audit D26: a locked rule does not change
                if ns.Print then ns.Print(("'%s' is edit-locked: unlock it in the sidebar to restore this draft."):format(tostring(keepRoot.name or d.name))) end
                return
            end
            for _, c in ipairs(copies) do ns.NormalizeRule(c) end
            local existed = keepRoot ~= nil
            if keepRoot and copies[1] then for k in pairs(ROOT_IGNORE) do copies[1][k] = keepRoot[k] end end
            ReplaceGroup(uid, copies)
            if windowOpen and not baseline[uid] then baseline[uid] = { isNew = true } end   -- no saved version to go back to
            table.remove(list, i)
            cache = { t = -1 }
            if ns.Print then
                if ns.DraftsEnabled() then
                    ns.Print(("Draft '%s' was put back into the editor%s. Press 'Save changes' on the rule to keep it."):format(tostring(d.name), existed and " (replacing the rule's current version)" or ""))
                else   -- drafts off: there is no save bar, the restored version is kept as it is
                    ns.Print(("Draft '%s' was put back%s and is kept (drafts are off)."):format(tostring(d.name), existed and ", replacing the rule's current version," or ""))
                end
            end
            if ns.ReselectRule then local r = GroupOf(uid)[1]; if r then pcall(ns.ReselectRule, r) end end
            if ns.UI and ns.UI.Notify then ns.UI.Notify() end
            return
        end
    end
end
function ns.DraftDelete(id)
    local list = Drafts()
    for i, d in ipairs(list) do if d.id == id then table.remove(list, i); break end end
    if ns.UI and ns.UI.Notify then ns.UI.Notify() end
end

-------------------------------------------------------------------------------
-- Options pieces
-------------------------------------------------------------------------------
-- Save bar shown at the top of every tab of a rule while it has unsaved changes. Returns a fresh args table each call.
-- The wording of the unsaved-changes bar (the strip under the window and the note at the top of a rule tab).
function ns.DraftBarText(isNew)
    if isNew then
        return "|cffffd100This rule has not been saved yet.|r It works while this window is open. Select Save changes to keep it. If you close this window first, the rule is stored in Drafts."
    end
    return "|cffffd100You have unsaved changes.|r They are already active, so you can test them now. Select Save changes to keep them. If you close this window first, the changes are stored in Drafts and the rule returns to its last saved version."
end

function ns.DraftArgs(rule)
    local function clean() return not ns.DraftDirty(rule) end
    local function Notify() if ns.UI and ns.UI.Notify then ns.UI.Notify() end end
    return {
        note = { type = "description", order = -100, width = "full", fontSize = "medium", hidden = clean,
            name = function() return ns.DraftBarText(ns.DraftIsNew(rule)) end },
        save = { type = "execute", order = -99, width = "normal", name = "Save changes", hidden = clean, arg = { xuiRed = true },
            desc = "Keep the changes made to this rule (its triggers, cues, conditions, actions and load settings).",
            func = function() ns.DraftSave(rule); Notify() end },
        saveCopy = { type = "execute", order = -98.9, width = "normal", name = "Save as a copy",
            hidden = function() return clean() or ns.DraftIsNew(rule) end,
            desc = "Keep your edits as a NEW rule next to this one. This rule goes back to its last saved version.",
            func = function() ns.DraftSaveAsCopy(rule) end },
        toDrafts = { type = "execute", order = -98.8, width = "normal", name = "Add to drafts", hidden = clean,
            desc = "Move your edits to the Drafts page and put this rule back to its last saved version (a never-saved rule leaves the list).",
            func = function() ns.DraftAddToDrafts(rule) end },
        copyToDrafts = { type = "execute", order = -98.7, width = "normal", name = "Add as a copy to drafts", hidden = clean,
            desc = "Store a copy of your edits in the Drafts page as a separate rule. This rule stays as it is, still unsaved.",
            func = function() ns.DraftAddCopyToDrafts(rule) end },
        discard = { type = "execute", order = -98, width = "normal", hidden = clean,
            name = function() return ns.DraftIsNew(rule) and "Discard new rule" or "Discard changes" end,
            confirm = function() return ns.DraftsConfirmDiscard() end,   -- Settings > Rule Creation > "Confirm Discard changes"
            confirmText = "Throw away the unsaved changes? The rule goes back to its last saved version (a new, never-saved rule is deleted).",
            func = function() ns.DraftDiscard(rule) end },
        gap = { type = "description", order = -97, width = "full", name = " ", fontSize = "small", hidden = clean },
    }
end

-- What a draft holds, in words, so a draft can be recognized without restoring it. Everything is read from the stored copy (plain tables);
-- nothing here touches the live rules. A damaged draft falls back to its date line only (see BuildDraftsPage).
local CD_SHORT = { hasCharge = "has a charge", ready = "ready", notReady = "not ready", empty = "empty" }
local BUFF_SHORT = { missing = "missing", present = "present" }
local MAX_SHOWN = 4   -- items named per line; the rest is counted ("and 2 more")

local function Plural(n, one, many) return n .. " " .. (n == 1 and one or (many or (one .. "s"))) end
local function Short(s, n)
    s = tostring(s or ""):gsub("[\r\n|]", " ")
    if #s > n then s = s:sub(1, n - 3) .. "..." end
    return s
end
local function SpellText(id)
    id = tonumber(id) or 0
    if id <= 0 then return nil end
    local ok, n = pcall(C_Spell.GetSpellName, id)
    if ok and n then return n .. " (" .. id .. ")" end
    return "spell " .. id
end
local function ItemText(id)
    id = tonumber(id) or 0
    if id <= 0 then return nil end
    local ok, n = pcall(C_Item.GetItemNameByID, id)
    if ok and n then return n .. " (" .. id .. ")" end
    return "item " .. id
end
local function IconTag(tx) return tx and ("|T" .. tostring(tx) .. ":14|t ") or "" end

-- "Cooldown: Metamorphosis (187827), ready", "Aura: ..., present", or the extra trigger's type and its first spell / item.
local function TriggerItems(root)
    local out, j = {}, 0
    for _, tok in ipairs(ns.TriggerSequence(root)) do
        if tok == "cd" then
            local sp = SpellText(root.spellID)
            local st = CD_SHORT[root.cdState]
            out[#out + 1] = "Cooldown" .. (sp and (": " .. sp) or "") .. (st and (", " .. st) or "")
        elseif tok == "buff" then
            local sp = SpellText(root.buffID)
            local st = BUFF_SHORT[root.buffState]
            out[#out + 1] = "Aura" .. (sp and (": " .. sp) or "") .. (st and (", " .. st) or "")
        else
            j = j + 1
            local row = type(root.extra) == "table" and type(root.extra.list) == "table" and root.extra.list[j]
            if type(row) == "table" then
                local def = ns.TRIGGER_TYPES and ns.TRIGGER_TYPES[row.type]
                local text = (def and def.label) or tostring(row.type or "Trigger")
                if def and def.fields then
                    for _, f in ipairs(def.fields) do
                        local what
                        if f.kind == "spell" or f.kind == "talent" then what = SpellText(row[f.key])
                        elseif f.kind == "item" then what = ItemText(row[f.key]) end
                        if what then text = text .. ": " .. what; break end
                    end
                end
                out[#out + 1] = text
            end
        end
    end
    return out
end

local function SoundText(s)
    if type(s) ~= "table" then return "Sound" end
    if s.source == "tts" then
        local v = tostring(s.value or "")
        return (v ~= "") and ("Speech \"" .. Short(v, 30) .. "\"") or "Speech"
    end
    local label = ns.SoundLabel and ns.SoundLabel(s) or tostring(s.value or "")
    if label == "(none)" or label == "" then return "Sound (none chosen)" end
    return "Sound \"" .. Short(label, 30) .. "\""
end

-- the icon / texture / text a display shows
local function VisualText(v, kind, root)
    if type(v) ~= "table" then return nil end
    if kind == "text" then return "Text" end
    if v.kind == "spellicon" then
        local src = v.iconSrc or "auto"
        if src == "spell" then
            local id = tonumber(v.iconSpell) or 0
            local ok, tx = pcall(C_Spell.GetSpellTexture, id)
            return "Icon: " .. IconTag(ok and id > 0 and tx or nil) .. (SpellText(id) or "no spell chosen")
        elseif src == "item" then
            return "Icon: " .. (ItemText(v.iconItem) or "no item chosen")
        elseif src == "file" then
            local p = tostring(v.iconPath or "")
            return "Icon: " .. ((p ~= "") and Short(p:match("([^\\/]+)$") or p, 28) or "own file")
        end
        local ok, tx = pcall(ns.TriggerIcon, root)
        return "Icon: " .. IconTag(ok and tx or nil) .. "from the first trigger"
    end
    local tex = tostring(v.tex or "")
    if tex == "" then return (kind == "icon") and "Icon" or "Texture (none chosen)" end
    return "Texture: " .. Short(tex:match("([^\\/]+)$") or tex, 30)
end

local function CueItems(rules)
    local out, root = {}, rules[1]
    for i = 2, #rules do
        local c = rules[i]
        if type(c) == "table" and c.isCue then
            local k = c.cueKind
            local name = (type(c.cueName) == "string" and c.cueName:match("%S")) and (c.cueName .. " = ") or ""
            local what
            if k == "sound" or k == "speech" then what = SoundText(c.sound)
            elseif k == "custom" then what = "Custom"
            else what = VisualText(c.visual, k, root) end
            out[#out + 1] = name .. (what or tostring(ns.CUE_KIND_LABEL and ns.CUE_KIND_LABEL[k] or k or "Cue"))
        end
    end
    -- an older rule with no cues of its own can still carry a sound or a display
    if #out == 0 and type(root) == "table" then
        if type(root.sound) == "table" and root.sound.enabled then out[#out + 1] = SoundText(root.sound) end
        if type(root.visual) == "table" and root.visual.enabled then out[#out + 1] = VisualText(root.visual, nil, root) end
    end
    return out
end

local function Listed(label_one, label_many, items)
    local n = #items
    if n == 0 then return "|cffffd100" .. label_many .. ":|r  |cff888888none|r" end
    local shown = {}
    for i = 1, math.min(n, MAX_SHOWN) do shown[i] = items[i] end
    local s = table.concat(shown, ";  ")
    if n > MAX_SHOWN then s = s .. ";  and " .. (n - MAX_SHOWN) .. " more" end
    return "|cffffd100" .. (n == 1 and label_one or label_many) .. ":|r  " .. s
end

local function DraftLines(d)
    local rules = (type(d.rules) == "table") and d.rules or {}
    local root = rules[1]
    local nCond, nCue = 0, 0
    for i = 2, #rules do
        if type(rules[i]) == "table" then if rules[i].isCue then nCue = nCue + 1 else nCond = nCond + 1 end end
    end
    local trig = (type(root) == "table") and TriggerItems(root) or {}
    local head = "|cff999999" .. date("%Y-%m-%d %H:%M", d.ts or 0) .. "   -   " .. (d.isNew and "new rule, never saved" or "unsaved changes to a saved rule")
        .. "   -   " .. Plural(#trig, "trigger") .. ", " .. Plural(nCue, "cue") .. ", and " .. Plural(nCond, "condition") .. "|r"
    return head, Listed("Trigger", "Triggers", trig), Listed("Cue", "Cues", CueItems(rules))
end

-- The Drafts page (opened from the toolbar). Built fresh on every options refresh.
-- One small box per draft: the date line with the two buttons beside it (Restore, Delete), then what its triggers and cues are.
function ns.BuildDraftsPage()
    local function Notify() if ns.UI and ns.UI.Notify then ns.UI.Notify() end end
    local args = {
        -- 0.6.4 (Xaya): the tab is always there. With drafts off it explains what they do and offers the switch; with drafts on the same
        -- switch turns them off. The finer settings (how many are kept, confirmations, the chat notice) are in Settings > Rule Creation.
        about = { type = "description", order = -3, width = "full", fontSize = "medium",
            name = function()
                if ns.DraftsEnabled() then
                    return "|cffffd100Drafts are on.|r While you edit a rule, a bar under the window offers Save changes, Save as a copy, Add to drafts, and Discard changes. Closing the window with unsaved changes moves them here and puts the rule back to its last saved version."
                end
                return "|cffffd100Drafts are off.|r Every change is kept the moment you make it, with no save bar.\n\nWith drafts on, edits are tried out live but kept only when you select Save changes. Closing the window first moves unsaved changes to this tab, where Restore puts them back in the editor. You can also Save as a copy, park an edit with Add to drafts, or Discard changes."
            end },
        toggle = { type = "execute", order = -2,
            name = function() return ns.DraftsEnabled() and "Turn drafts off" or "Turn drafts on" end,
            desc = "Turning drafts on starts from a clean slate: the rules as they are now count as saved. Turning them off keeps every edit you have made. Drafts already on this tab stay here either way.",
            func = function()
                local ui = CueRulesDB and CueRulesDB.ui
                if not ui then return end
                ui.promptSave = not ns.DraftsEnabled()
                if ns.DraftsApplySetting then ns.DraftsApplySetting() end
                Notify()
            end },
        settings = { type = "execute", order = -1.9, name = "Draft settings",
            desc = "Settings > UI Options > Rule Creation: how many drafts are kept, which actions ask first, and the chat notice.",
            func = function() if ns.OpenDraftSettings then ns.OpenDraftSettings() end end },
        intro = { type = "description", order = 0, width = "full", fontSize = "medium",
            hidden = function() return not ns.DraftsEnabled() and #Drafts() == 0 end,
            name = function() return "Changes you did not save before closing the window are kept here. Restore loads a draft into its rule (or recreates a rule that was never saved); then select Save changes on the rule to keep it. Up to " .. ns.DraftsMax() .. " drafts are kept, newest first." end },
    }
    local list = Drafts()
    if #list == 0 then
        args.none = { type = "description", order = 1, width = "full", fontSize = "medium", name = "|cff888888No drafts.|r",
            hidden = function() return not ns.DraftsEnabled() end }
    end
    for i, d in ipairs(list) do
        local ok, head, trig, cue = pcall(DraftLines, d)
        if not ok then
            head, trig, cue = "|cff999999" .. date("%Y-%m-%d %H:%M", d.ts or 0) .. "   -   details could not be read|r", nil, nil
        end
        local box = {
            head = { type = "description", order = 1, width = "relative", relWidth = 0.72, fontSize = "medium", name = head },
            restore = { type = "execute", order = 2, width = "relative", relWidth = 0.13, name = "Restore",
                desc = function()
                    if ns.DraftsEnabled() then return "Put this draft back in the editor: it is loaded into its rule (replacing the rule's current version). It is not saved until you select Save changes." end
                    return "Put this draft back: it replaces the rule's current version and is kept at once (drafts are off, so there is no Save changes). Asks first."
                end,
                confirm = function() return ns.DraftRestoreConfirm(d.id) end,   -- audit D22: asks first while drafts are off (AceConfig shows the popup)
                func = function() ns.DraftRestore(d.id) end },
            delete = { type = "execute", order = 3, width = "relative", relWidth = 0.11, name = "Delete", confirm = function() return ns.DraftsConfirmDelete() end, confirmText = "Delete this draft for good?",
                func = function() ns.DraftDelete(d.id) end },
        }
        if trig then box.trig = { type = "description", order = 4, width = "full", fontSize = "medium", name = trig } end
        if cue then box.cue = { type = "description", order = 5, width = "full", fontSize = "medium", name = cue } end
        args["d" .. i] = { type = "group", inline = true, order = i, name = tostring(d.name or "Unnamed rule"), args = box }
    end
    return { type = "group", name = "Drafts", order = 7, hidden = ns.PageHidden("drafts"), args = args }
end

-------------------------------------------------------------------------------
-- Undo / redo for the rule being edited (Ctrl+Z, Ctrl+Y or Ctrl+Shift+Z while the options window has focus and no text box is being typed in).
-- One step = one burst of edits (a slider drag is one step): every edit calls ns.MarkDirty, which fires EDITED (UndoNote below); half a second after the last
-- one the rule (with its cues and conditions) is compared with its last recorded state and, if different, the old state is kept. The first state
-- is the one the rule had when the window opened (the Drafts baseline), so the very first edit can be undone too. History is per rule, lives only
-- while the window is open (50 steps), and is not saved. On / off, group, collapse state, sidebar icon and edit lock follow the sidebar and are
-- not part of undo.
-------------------------------------------------------------------------------
local UNDO_MAX = 50
local UNDO_ROOT_IGNORE = { enabled = true, folder = true, ocCollapsed = true, listIcon = true, listIconID = true, editLocked = true }
local undo = {}            -- [uid] = { cur = { sig, rules }, back = { states }, fwd = { states } }
local restoring, pendingUid, armed, lastNote = false, nil, false, 0

local function USig(group)
    local out = {}
    for i, r in ipairs(group) do out[#out + 1] = "#"; Ser(r, out, (i == 1) and UNDO_ROOT_IGNORE or CHILD_IGNORE) end
    return table.concat(out)
end
local function UState(uid)
    local u = undo[uid]
    if u then return u end
    local b = baseline[uid]
    if b and b.rules then
        u = { cur = { sig = USig(b.rules), rules = b.rules }, back = {}, fwd = {} }
        undo[uid] = u
        return u
    end
end
function ns.UndoSeed(uid)   -- the rule as it is right now becomes the first state (a rule made in this window)
    local g = GroupOf(uid)
    if #g == 0 then undo[uid] = nil return end
    undo[uid] = { cur = { sig = USig(g), rules = Copies(g) }, back = {}, fwd = {} }
end
local function Commit()
    local uid = pendingUid
    pendingUid = nil
    if not uid or restoring or not windowOpen then return end
    local u = UState(uid)
    local g = GroupOf(uid)
    if not u or #g == 0 then return end
    local sig = USig(g)
    if sig == u.cur.sig then return end
    u.back[#u.back + 1] = u.cur
    if #u.back > UNDO_MAX then table.remove(u.back, 1) end
    u.fwd = {}
    u.cur = { sig = sig, rules = Copies(g) }
end
local function Arm()
    armed = true
    C_Timer.After(0.5, function()
        if GetTime() - lastNote < 0.45 then Arm() else armed = false; Commit() end
    end)
end
local function UndoNote()   -- runs after every edit: ns.MarkDirty fires EDITED (Modules.lua section 6)
    if restoring or not windowOpen or not C_Timer or not ns.SelectedRuleForUndo then return end
    local root = RootOf(ns.SelectedRuleForUndo())
    if not (root and root.uid) then return end
    if pendingUid and pendingUid ~= root.uid then Commit() end   -- moved to another rule: close the first one's step now
    pendingUid = root.uid
    lastNote = GetTime()
    if not armed then Arm() end
end
ns.On("EDITED", UndoNote)
local function Restore(uid, st)
    restoring = true
    local live = GroupOf(uid)[1]
    local copies = Copies(st.rules)
    local root = copies[1]
    if live and root then for k in pairs(UNDO_ROOT_IGNORE) do root[k] = live[k] end end
    for i = 2, #copies do if live then copies[i].folder = live.folder end end
    ReplaceGroup(uid, copies)
    restoring = false
    cache = { t = -1 }
    if ns.ReselectRule then local r = GroupOf(uid)[1]; if r then pcall(ns.ReselectRule, r) end end
    if ns.UI and ns.UI.Notify then
        ns.UI.Notify()
        if C_Timer then C_Timer.After(0, function() cache = { t = -1 }; ns.UI.Notify() end) end
    end
end
-- Ctrl+Z (redo = false) / Ctrl+Y (redo = true). Returns true when the key was used.
function ns.UndoKey(redo)
    if not windowOpen or not ns.SelectedRuleForUndo then return false end
    local root = RootOf(ns.SelectedRuleForUndo())
    if not (root and root.uid) then return false end
    local uid = root.uid
    if ns.IsEditLocked and ns.IsEditLocked(root) then   -- audit D26: a locked rule does not change
        ns.Print(("'%s' is edit-locked: unlock it in the sidebar to undo or redo."):format(tostring(root.name or "rule")))
        return true
    end
    if pendingUid then Commit() end   -- an edit made less than half a second ago counts first
    local u = UState(uid)
    if not u then ns.Print("nothing recorded to undo for this rule yet") return true end
    local src, dst = redo and u.fwd or u.back, redo and u.back or u.fwd
    if #src == 0 then ns.Print(redo and "nothing to redo for this rule" or "nothing to undo for this rule") return true end
    local st = table.remove(src)
    dst[#dst + 1] = u.cur
    u.cur = st
    Restore(uid, st)
    ns.Print(((redo and "redid" or "undid") .. " the last change to '%s'  (%d step(s) left to undo)"):format(tostring(root.name or "rule"), #u.back))
    return true
end
function ns.UndoReset() wipe(undo); pendingUid = nil end
-- "Use drafts" off: the rule the window shows gets its first undo state now, a copy of it as it is (V14 note above). Run after the window
-- opens and after every pane the window builds (Options.lua hooks AceConfigDialog.FeedGroup), so before anything in it can be edited.
function ns.UndoFirstState()
    if not windowOpen or ns.DraftsEnabled() or not ns.SelectedRuleForUndo then return end
    local root = RootOf(ns.SelectedRuleForUndo())
    local uid = root and root.uid
    if type(uid) ~= "string" or baseline[uid] or undo[uid] then return end
    local group = GroupOf(uid)
    if #group > 0 then baseline[uid] = { rules = Copies(group) } end
end
