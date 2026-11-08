-------------------------------------------------------------------------------
-- AddonInfo.lua : what the version pane's Info tab shows on Version info and Credits + Acknowledgements (InfoPane.lua draws it).
-- Until Options 0.6.56 this was the "Addon Info" page (opened by the version text) and Settings > Acknowledgements; Xaya 2026-11-06:
-- "Both move into the pane" (Addon Info -> Info > Version info; Acknowledgements -> Info > Credits + Acknowledgements, "Move as-is").
--
-- Version  = "## Version" in XayaUI.toc (read live, so it can never disagree with the toc).
-- Updated  = "## X-Date" in XayaUI.toc (YYYY-MM-DD). The game has no built-in "last updated" field: bump X-Date by hand
--            whenever you ship a change (same moment you bump Version).
-- Credits  = the CREDITS table below. Edit that table to add or correct an entry; nothing else needs touching.
--            Every line was taken from XayaUI's own files (THIRD_PARTY.md, library headers, Media license.txt files);
--            author names/links come from each addon's own TOC and license files on this PC; where none exists it says so instead of guessing.
-------------------------------------------------------------------------------
local addonName, ns = ...
ns = _G.XayaUI_NS or ns   -- one namespace with XayaUI core (this addon depends on it: ## Dependencies: XayaUI)

local function Meta(field)
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    if not get then return nil end
    local ok, v = pcall(get, ns.name or "XayaUI", field)   -- XayaUI core's own .toc (this file is in XayaUI_Options)
    if ok and type(v) == "string" and v ~= "" then return v end
    return nil
end

local REPO_URL = "https://github.com/heyitsxaya/XayaUI"

-- WHEN QoL ELEMENTS COMES BACK (QoL.lua, CursorTracker.lua, CursorReminders.lua, Bars.lua; see .gitignore): add this back to
-- the EllesmereUI note: "The Buff Bars option set (Bars.lua) is styled after EllesmereUI's Tracking Bars." Re-check media credits too.
-- (Options 0.6.64; REQUEST-LOG B6 / ATTR-1, reading taken: the section titles are her "subheaders (code, ideas and design, etc) h2", in
-- normal case; until 0.6.63 they were capitals, "CODE", "IDEAS AND DESIGN", ...)
local CREDITS = {
    { title = "Code", sub = "Libraries bundled in the Libs folder", entries = {
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
    { title = "Ideas and design", sub = "Inspiration only: concepts and layouts, no code copied", entries = {
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
    { title = "Sounds", sub = "Your local files only: personal use, never redistributed", entries = {
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
    { title = "Game art", sub = "Blizzard Entertainment", entries = {
        { name = "Blizzard Entertainment",
          who = "Texture IDs in TextureList.lua are Blizzard's own game files, referenced by number. The local [Graphics] images are extracted Blizzard UI art (personal use, not redistributed).",
          note = "World of Warcraft and Blizzard Entertainment are trademarks of Blizzard Entertainment, Inc. XayaUI is not affiliated with or endorsed by Blizzard." },
    } },
}

-- Info > Credits + Acknowledgements, as blocks for InfoPane.lua. Options 0.6.64 (REQUEST-LOG B6, reading taken; her words, ATTR-1:
-- "this attribution pane is very messy. let's do the following: / * increase the gutter by 10px / * credits and attribution are h1 /
-- * subheaders (code, ideas and design, etc) h2 / * each section under a subheader should have an unrounded box with rows (no columns)
-- on a slightly less transparent background (10%)"): "Credits and attribution" stays the h1; each section is a "credits" block: a plain
-- h2 in normal case (no arrow, no collapsing, no count, no line under it), its sub line, then ONE square box for the whole section with
-- each credit a row of it (name, who, note, one copyable box per link; no columns), the box's background 10% more opaque than the pane's;
-- 10 px more gutter after each section's box. The intro paragraph is gone. (Before: "Move as-is" from Settings > Acknowledgements:
-- the intro, capitalised collapsible section rows with a count, one box per credit.)
function ns.CreditsBlocks()
    local out = {
        { "h1", "Credits and attribution" },
        { "rule" },
    }
    for _, sec in ipairs(CREDITS) do
        out[#out + 1] = { "credits", sec.title, sec.sub, sec.entries }
    end
    return out
end

-- Info > Version info: what the Addon Info page showed, with the credits line pointing to its new place.
function ns.VersionInfoBlocks()
    return {
        { "h1", "XayaUI   v" .. (Meta("Version") or "?") },
        { "kv", "Last updated:", Meta("X-Date") or "unknown (add '## X-Date: YYYY-MM-DD' to XayaUI.toc)" },
        { "kv", "Author:", Meta("Author") or "Xaya" },
        { "kv", "License:", "GPL-3.0-or-later for XayaUI's own code. Bundled libraries and any media keep their own licenses (listed in Info > Credits + Acknowledgments)." },
        { "kv", "Commands:", "/xui or /xayaui" },
        { "input", "Source code (click the box, Ctrl+A, Ctrl+C)", REPO_URL },
        { "small", "Version and date are read from XayaUI.toc (## Version and ## X-Date). Update both when you ship a change." },
        { "kv", "Credits and attribution:", "Info > Credits + Acknowledgments." },
    }
end
