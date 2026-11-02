-- XayaUI: Save changes + Drafts.
-- While the options window is open, every ROOT rule (a rule together with its cues and conditions) has a saved version: what it looked like when the
-- window opened, or when you last pressed "Save changes". Edits still apply at once so you can test them in game, but a rule that differs from its
-- saved version shows "Save changes" / "Discard changes". If the window closes (or you log out) with unsaved changes, the edited rule is kept in the
-- Drafts page and the rule itself goes back to its saved version. A rule made in this window and never saved lives only in Drafts after closing.
-- Not counted as changes (they follow what you do in the sidebar, not what the rule does): on / off, name, group, collapse state, sidebar icon, edit lock.
local addonName, ns = ...

local baseline = {}      -- [rootUid] = { sig = string, rules = { deep copies }, isNew = true when the rule was made in this window and never saved }
local windowOpen = false
local MAX_DRAFTS = 30

local ROOT_IGNORE = { enabled = true, folder = true, name = true, ocCollapsed = true, listIcon = true, listIconID = true, editLocked = true }
local CHILD_IGNORE = { folder = true, ocCollapsed = true, spellID = true, buffID = true, maxCharges = true, listIcon = true, listIconID = true, editLocked = true }

-- stable text form of a value (sorted keys), used only to compare two states of a rule
local function KeyLess(a, b)
    local ta, tb = type(a), type(b)
    if ta ~= tb then return ta < tb end
    if ta == "number" or ta == "string" then return a < b end
    return tostring(a) < tostring(b)
end
local function Ser(v, out, ignore)
    local t = type(v)
    if t == "table" then
        local keys = {}
        for k in pairs(v) do if not (ignore and ignore[k]) then keys[#keys + 1] = k end end
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
function ns.DraftDirty(rule)
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

-- called when the options window opens: remember the saved version of every rule
function ns.DraftsOnOpen()
    if windowOpen or not ns.rules then return end
    windowOpen = true
    wipe(baseline)
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
    for _, r in ipairs(ns.rules) do
        if not r.parentUid and r.isCue ~= true then
            local group = GroupOf(r.uid)
            baseline[r.uid] = { sig = Sig(group), rules = Copies(group) }
        end
    end
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
    if not windowOpen or not rule or rule.parentUid then return end
    if type(rule.uid) ~= "string" then rule.uid = ns.NewUID() end
    baseline[rule.uid] = { isNew = true }
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
    while #list > MAX_DRAFTS do table.remove(list) end
end

-- the window closed (or the game is logging out): unsaved rules go to Drafts and go back to their saved version
function ns.DraftsOnClose()
    if not windowOpen then return end
    windowOpen = false
    cache = { t = -1 }
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
    if moved > 0 and ns.Print then
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

local lf = CreateFrame("Frame")
lf:RegisterEvent("PLAYER_LOGOUT")
lf:SetScript("OnEvent", function() pcall(ns.DraftsOnClose) end)

-------------------------------------------------------------------------------
-- Drafts page actions
-------------------------------------------------------------------------------
function ns.DraftRestore(id)
    local list = Drafts()
    for i, d in ipairs(list) do
        if d.id == id then
            local copies = Copies(d.rules or {})
            if #copies == 0 then table.remove(list, i); return end
            for _, c in ipairs(copies) do ns.NormalizeRule(c) end
            local uid = d.uid
            local existed = #GroupOf(uid) > 0
            local keepRoot = GroupOf(uid)[1]
            if keepRoot and copies[1] then for k in pairs(ROOT_IGNORE) do copies[1][k] = keepRoot[k] end end
            ReplaceGroup(uid, copies)
            if windowOpen and not baseline[uid] then baseline[uid] = { isNew = true } end   -- no saved version to go back to
            table.remove(list, i)
            cache = { t = -1 }
            if ns.Print then ns.Print(("Draft '%s' was put back into the editor%s. Press 'Save changes' on the rule to keep it."):format(tostring(d.name), existed and " (replacing the rule's current version)" or "")) end
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
function ns.DraftArgs(rule)
    local function clean() return not ns.DraftDirty(rule) end
    local function Notify() if ns.UI and ns.UI.Notify then ns.UI.Notify() end end
    return {
        note = { type = "description", order = -100, width = "full", fontSize = "medium", hidden = clean,
            name = function()
                if ns.DraftIsNew(rule) then
                    return "|cffffd100This rule has not been saved yet.|r It works while this window is open. Press Save changes to keep it. If you close the window first, it is moved to Drafts."
                end
                return "|cffffd100Unsaved changes.|r They already apply, so you can test them. Press Save changes to keep them. If you close the window first, the changes are moved to Drafts and the rule goes back to its last saved version."
            end },
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
            confirm = true,
            confirmText = "Throw away the unsaved changes? The rule goes back to its last saved version (a new, never-saved rule is deleted).",
            func = function() ns.DraftDiscard(rule) end },
        gap = { type = "description", order = -97, width = "full", name = " ", fontSize = "small", hidden = clean },
    }
end

-- The Drafts page (opened from the toolbar). Built fresh on every options refresh.
function ns.BuildDraftsPage()
    local args = {
        intro = { type = "description", order = 0, width = "full", fontSize = "medium",
            name = "Changes you did not save before closing the window are kept here. 'Put back in editor' loads the draft into its rule (or recreates a rule that was never saved); press Save changes on the rule to keep it. Up to " .. MAX_DRAFTS .. " drafts are kept, newest first." },
    }
    local list = Drafts()
    if #list == 0 then
        args.none = { type = "description", order = 1, width = "full", fontSize = "medium", name = "|cff888888No drafts.|r" }
    end
    for i, d in ipairs(list) do
        local n = (type(d.rules) == "table") and #d.rules or 0
        args["d" .. i] = { type = "group", inline = true, order = i, name = tostring(d.name or "Unnamed rule"), args = {
            info = { type = "description", order = 1, width = "full", fontSize = "medium",
                name = date("%Y-%m-%d %H:%M", d.ts or 0) .. "   -   " .. (d.isNew and "a new rule that was never saved" or "unsaved changes to a saved rule") .. "   -   " .. n .. " part(s) (rule, cues, conditions)" },
            restore = { type = "execute", order = 2, width = "double", name = "Put back in editor",
                desc = "Loads this draft into its rule (replacing the rule's current version). It is not saved until you press Save changes.",
                func = function() ns.DraftRestore(d.id) end },
            delete = { type = "execute", order = 3, width = "normal", name = "Delete draft", confirm = true, confirmText = "Delete this draft for good?",
                func = function() ns.DraftDelete(d.id) end },
        } }
    end
    return { type = "group", name = "Drafts", order = 7, hidden = ns.PageHidden("drafts"), args = args }
end
