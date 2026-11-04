-- SHELVED, loaded by no addon (listed in no .toc). Kept for later; nothing plans to use it yet.
--
-- What it is: the "Mythic+ rating" line that XayaUI_QoL's Character Toolkit showed on the Stats tab (and as a cell on the Sheet tab)
-- from QoL 0.7.0 to 0.7.1. Xaya, 2026-11-04: "m+ rating does not belong in character toolkit at all. partition it out and stash
-- it, it isn't useful YET for any planned feature but could be useful down the line." Removed from the Toolkit in QoL 0.7.2.
--
-- What it showed: the season's overall rating as the value, then one pair per dungeon (best key level, "(over time)" when not
-- timed, the dungeon's score), best first; a "This season" note when there were no details; "Best this expansion (season N)".
--
-- Game API it read (names only; the entries are in docs/reference/api/):
--   C_PlayerInfo.GetPlayerMythicPlusRatingSummary("player")   MayReturnNothing; fields currentSeasonScore, runs[] with
--                                                             challengeModeID, mapScore, bestRunLevel, bestRunDurationMS, finishedSuccess
--   C_ChallengeMode.GetOverallDungeonScore                    fallback for the overall score
--   C_ChallengeMode.GetMapUIInfo(challengeModeID)             dungeon name
--   C_MythicPlus.GetSeasonBestMythicRatingFromThisExpansion   MayReturnNothing; returns rating, season
--   C_MythicPlus.RequestMapInfo()                             documented, no flags: asks the server for the per-dungeon details.
--                                                             The Toolkit called it once, the first time its panel was shown
--                                                             (CharacterToolkit.lua, ShowIfDocked); the game may send the details
--                                                             only after the Group Finder's Mythic+ tab has been opened once.
--
-- To bring it back:
--   1. Paste MythicPlusItem into XayaUI_QoL/CharacterModel.lua above StatItem, where Item, SetValue, Pair, Tip, Field, R, N, num,
--      Big and HIDDEN are already local.
--   2. Add `sec.items[#sec.items + 1] = MythicPlusItem()` after the item level line in the "Character" section of the "stats" tab.
--   3. Call the one-time RequestMapInfo (below) where the panel is first shown.
--   4. Restore the tests removed in QoL 0.7.2 (tests/char_toolkit2_run.py, "Mythic+" checks; git history has them) and QA E1l.
-- Nothing here has been run in game. It was written for the 0.7.0 Toolkit; the helpers it calls may have changed since.

local function MythicPlusItem()
    local it = Item("mplus", "Mythic+ rating")
    local score, runs, hidden
    local sum = C_PlayerInfo and R(C_PlayerInfo.GetPlayerMythicPlusRatingSummary, "player")
    if sum == HIDDEN then hidden = true
    elseif type(sum) == "table" then
        local s = Field(sum, "currentSeasonScore")
        if s == HIDDEN then hidden = true elseif num(s) then score = s end
        local r = Field(sum, "runs")
        if type(r) == "table" then runs = r end
    end
    if score == nil and not hidden then
        local s = C_ChallengeMode and N(C_ChallengeMode.GetOverallDungeonScore)
        if s == HIDDEN then hidden = true elseif num(s) then score = s end
    end
    if hidden then SetValue(it, HIDDEN); return it end
    SetValue(it, score, Big)
    local list = {}
    for _, run in ipairs(runs or {}) do
        local id, sc, lvl, ok = Field(run, "challengeModeID"), Field(run, "mapScore"), Field(run, "bestRunLevel"), Field(run, "finishedSuccess")
        if num(id) and num(sc) and num(lvl) then list[#list + 1] = { id = id, score = sc, level = lvl, timed = ok == true } end
    end
    table.sort(list, function(a, b) if a.score ~= b.score then return a.score > b.score end; return a.id < b.id end)
    for _, run in ipairs(list) do
        local name = C_ChallengeMode and R(C_ChallengeMode.GetMapUIInfo, run.id)
        if type(name) ~= "string" then name = "Dungeon " .. tostring(run.id) end
        Pair(it, name, ("+%d%s, %s"):format(run.level, run.timed and "" or " (over time)", Big(run.score)))
    end
    if num(score) and #list == 0 then Pair(it, "This season", score > 0 and "no dungeon details given" or "no rated runs yet", "mute") end
    local best, season = R(C_MythicPlus and C_MythicPlus.GetSeasonBestMythicRatingFromThisExpansion)
    if num(best) and best > 0 then Pair(it, "Best this expansion", Big(best) .. (num(season) and (" (season " .. tostring(season) .. ")") or "")) end
    Tip(it, "From the game: C_PlayerInfo.GetPlayerMythicPlusRatingSummary (your overall score and each dungeon's best run), else C_ChallengeMode.GetOverallDungeonScore.")
    Tip(it, "Dungeon names come from C_ChallengeMode.GetMapUIInfo. The game may send the details only after the Mythic+ tab has been opened once.")
    return it
end

-- The one-time server request the Toolkit made when its panel was first shown:
local askedMythic = false
local function AskForMythicDetails()
    if not askedMythic and C_MythicPlus and type(C_MythicPlus.RequestMapInfo) == "function" then
        askedMythic = true
        pcall(C_MythicPlus.RequestMapInfo)   -- documented, no flags
    end
end
