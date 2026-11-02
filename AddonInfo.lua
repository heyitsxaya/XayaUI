-------------------------------------------------------------------------------
-- AddonInfo.lua : the "Addon Info" top-level tab (version, last-updated date, credits).
--
-- Version  = "## Version" in XayaUI.toc (read live, so it can never disagree with the toc).
-- Updated  = "## X-Date" in XayaUI.toc (YYYY-MM-DD). The game has no built-in "last updated" field: bump X-Date by hand
--            whenever you ship a change (same moment you bump Version).
-- Credits  = the CREDITS table below. Edit that table to add or correct an entry; nothing else needs touching.
--            Every line was taken from XayaUI's own files (THIRD_PARTY.md, library headers, Media license.txt files);
--            author names/links come from each addon's own TOC and license files on this PC; where none exists it says so instead of guessing.
-------------------------------------------------------------------------------
local addonName, ns = ...

local function Meta(field)
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    if not get then return nil end
    local ok, v = pcall(get, addonName, field)
    if ok and type(v) == "string" and v ~= "" then return v end
    return nil
end

local PURPLE, GREY, END = "|cffcc80ff", "|cff999999", "|r"   -- PURPLE = the same purple as the selected-tab outline
local REPO_URL = "https://github.com/heyitsxaya/XayaUI"

-- WHEN QoL ELEMENTS COMES BACK (QoL.lua, CursorTracker.lua, CursorReminders.lua, Bars.lua; see .gitignore): add this back to
-- the EllesmereUI note: "The Buff Bars option set (Bars.lua) is styled after EllesmereUI's Tracking Bars." Re-check media credits too.
local CREDITS = {
    { title = "CODE", sub = "Libraries bundled in the Libs folder", entries = {
        { name = "Ace3: AceGUI-3.0, AceConfig-3.0 (Registry, Cmd, Dialog)",
          who = "The Ace3 authors (WowAce). Recent files are committed by Nevcairiel, per their headers.",
          note = "BSD license. Copied unmodified (as far as is known) from the Libs folder of the BuzzardAuras addon.",
          links = { { "WowAce project page", "https://www.wowace.com/projects/ace3" } } },
        { name = "LibStub",
          who = "Kaelten, Cladhaire, ckknight, Mikk, Ammo, Nevcairiel, joshborke (from the library's own credits).",
          note = "Public Domain.",
          links = { { "WowAce page", "http://www.wowace.com/addons/libstub/" } } },
        { name = "CallbackHandler-1.0",
          who = "Part of Ace3; the bundled copy's header names Nevcairiel.",
          note = "BSD license, same package as Ace3 above." },
    } },
    { title = "IDEAS AND DESIGN", sub = "Inspiration only: concepts and layouts, no code copied", entries = {
        { name = "EllesmereUI",
          who = "Ellesmere (the Author field in its TOC; the license says 'copyrighted to their authors').",
          note = "Custom license, all rights reserved. The by-name target-debuff lookup follows the method EllesmereUI uses, and its Cooldown Manager is the in-game behavior reference. No EllesmereUI code is included.",
          links = { { "CurseForge", "https://www.curseforge.com/wow/addons/ellesmereui" } } },
        { name = "BuffReminders",
          who = "zerbi (the Author field in its TOC); the license names Andrea Zerbini as copyright holder.",
          note = "PolyForm Shield 1.0.0. Ideas only; no code copied.",
          links = { { "CurseForge (project 1441094)", "https://www.curseforge.com/projects/1441094" } } },
        { name = "Buzzard Auras",
          who = "Serina (the Author field in its TOC).",
          note = "Ideas only; no code copied. It is also where the Ace3 copy in Libs\\ came from.",
          links = { { "CurseForge (project 1541568)", "https://www.curseforge.com/projects/1541568" } } },
    } },
    { title = "SOUNDS", sub = "Your local files only: personal use, never redistributed", entries = {
        { name = "BigWigs sound packs  ([BW] in the sound list)",
          who = "BigWigs authors: Funkeh, Nebula, Justwait, Delk (its TOC). Clip authors, from each license.txt: unfa, davidbain, tekgnosis (all CC0), and Timbre with original author Corsica_S and voice actress Amy (CC BY-NC 3.0).",
          note = "BigWigs itself is All Rights Reserved. The Heroes voice lines are (C) 2018 Blizzard Entertainment, Inc. Clips are hosted on freesound.org.",
          links = { { "BigWigs on GitHub", "https://github.com/BigWigsMods" }, { "unfa", "https://freesound.org/people/unfa/" },
                    { "davidbain", "https://freesound.org/people/davidbain/" }, { "tekgnosis", "https://freesound.org/people/tekgnosis/" },
                    { "Timbre", "https://freesound.org/people/Timbre/" } } },
        { name = "Details! sounds  ([Details])",
          who = "From the Details! Damage Meter addon. Its author goes by terciob (taken from the Patreon link inside Details itself; its TOC has no Author line).",
          note = "Details is All Rights Reserved (its LICENSE says only that). Personal use only.",
          links = { { "CurseForge (project 61284)", "https://www.curseforge.com/projects/61284" }, { "Author's Patreon", "https://www.patreon.com/terciob" } } },
        { name = "Power Auras sounds  ([PA])",
          who = "From the Power Auras addon. Its authors are NOT on record in this project (the addon is not installed here to check).",
          note = "Creative Commons NonCommercial/Attribution terms (per THIRD_PARTY.md). Fill in the author and link here once confirmed." },
        { name = "Your own sounds  ([Local] and Media\\Audio\\Custom)",
          who = "Xaya.",
          note = "" },
    } },
    { title = "GAME ART", sub = "Blizzard Entertainment", entries = {
        { name = "Blizzard Entertainment",
          who = "Texture IDs in TextureList.lua are Blizzard's own game files, referenced by number. The local [Graphics] images are extracted Blizzard UI art (personal use, not redistributed).",
          note = "World of Warcraft and Blizzard Entertainment are trademarks of Blizzard Entertainment, Inc. XayaUI is not affiliated with or endorsed by Blizzard." },
    } },
}

-- One credit = one square box of full-width rows (title, who, note, then one row per link). No columns.
local function AddCredit(body, j, e)
    local rows = {
        t = { type = "description", order = 1, width = "full", fontSize = "medium", name = PURPLE .. e.name .. END },
        w = { type = "description", order = 2, width = "full", fontSize = "medium", name = e.who },
    }
    if e.note and e.note ~= "" then
        rows.n = { type = "description", order = 3, width = "full", fontSize = "medium", name = GREY .. e.note .. END }
    end
    for k, l in ipairs(e.links or {}) do
        rows["l" .. k] = { type = "input", order = 10 + k, width = "full", name = l[1],
            desc = "Click the box, press Ctrl+A, then Ctrl+C to copy this link.",
            get = function() return l[2] end, set = function() end }
    end
    body["e" .. j] = { type = "group", inline = true, name = "", order = j * 2, arg = { xuiBox = true }, args = rows }
    body["g" .. j] = { type = "description", order = j * 2 + 1, width = "full", name = " ", fontSize = "small" }
end

-- Collapsible category: header with the arrow on the RIGHT (drawn by Skin.lua from arg.xuiArrow), open by default, session-only.
local shut = {}
local function Pane(id, title, count, sub, order, entries)
    local body = {}
    body.sub = { type = "description", order = 0, width = "full", fontSize = "medium", name = GREY .. sub .. END }
    for j, e in ipairs(entries) do AddCredit(body, j, e) end
    return { type = "group", inline = true, name = "", order = order, args = {
        hdr = { type = "execute", order = 1, width = "full",
            arg = { xuiLeft = true, xuiArrow = function() return not shut[id] end },
            name = function() return PURPLE .. title .. END .. "   " .. GREY .. "(" .. count .. ")" .. END end,
            desc = "Expand or collapse this section. Collapsing never changes any setting.",
            func = function()
                shut[id] = (not shut[id]) or nil
                if ns.UI and ns.UI.Notify then ns.UI.Notify() end
            end },
        body = { type = "group", inline = true, name = "", order = 2, arg = { xuiFlat = true },
            hidden = function() return shut[id] and true or false end, args = body },
    } }
end

function ns.BuildAddonInfo()
    local args = {
        intro = { type = "description", order = 0, width = "full", fontSize = "large",
            name = function()
                return PURPLE .. "XayaUI" .. END .. "   v" .. (Meta("Version") or "?")
            end },
        updated = { type = "description", order = 1, width = "full", fontSize = "medium",
            name = function()
                return PURPLE .. "Last updated:" .. END .. " " .. (Meta("X-Date") or "unknown (add '## X-Date: YYYY-MM-DD' to XayaUI.toc)")
            end },
        author = { type = "description", order = 2, width = "full", fontSize = "medium",
            name = function() return PURPLE .. "Author:" .. END .. " " .. (Meta("Author") or "Xaya") end },
        license = { type = "description", order = 3, width = "full", fontSize = "medium",
            name = PURPLE .. "License:" .. END .. " GPL-3.0-or-later for XayaUI's own code. Bundled libraries and any media keep their own licenses (listed below)." },
        cmds = { type = "description", order = 4, width = "full", fontSize = "medium",
            name = PURPLE .. "Commands:" .. END .. " /xui or /xayaui" },
        repo = { type = "input", order = 5, width = "full", name = "Source code (click the box, Ctrl+A, Ctrl+C)",
            get = function() return REPO_URL end, set = function() end },
        howto = { type = "description", order = 6, width = "full", fontSize = "small",
            name = GREY .. "Version and date are read from XayaUI.toc (## Version and ## X-Date). Update both when you ship a change." .. END },
        creditsH1 = { type = "description", order = 10, width = "full", fontSize = "large", arg = { xuiH1 = 26 },
            name = PURPLE .. "Credits and attribution" .. END },
        creditsRule = { type = "header", order = 10.5, name = "" },
        creditsIntro = { type = "description", order = 11, width = "full", fontSize = "medium",
            name = "XayaUI stands on other people's work. Everything below is credited as precisely as this project's own records allow; where a name is not on record, that is stated rather than guessed." },
    }
    for i, sec in ipairs(CREDITS) do
        args["sec" .. i] = Pane("info" .. i, sec.title, #sec.entries, sec.sub, 20 + i * 10, sec.entries)
    end
    return { type = "group", name = "Addon Info", order = 6.5,
        args = { page = { type = "group", inline = true, name = "", order = 1, arg = { xuiFlat = true }, args = args } } }
end
