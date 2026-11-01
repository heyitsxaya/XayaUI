-------------------------------------------------------------------------------
-- Sound.lua : sound list (built-in kits + LibSharedMedia) and playback.
-------------------------------------------------------------------------------
local addonName, ns = ...

local KIT_NAMES = {
    "RAID_WARNING", "READY_CHECK", "ALARM_CLOCK_WARNING_2", "ALARM_CLOCK_WARNING_3",
    "IG_QUEST_LIST_COMPLETE", "UI_RAID_BOSS_WHISPER_WARNING", "AUCTION_WINDOW_OPEN",
    "MAP_PING", "IG_MAINMENU_OPEN",
}

local function LSM()
    return LibStub and LibStub("LibSharedMedia-3.0", true)
end

-- LocalSounds.lua indexes audio files that are NOT shipped with the addon (licensing), so on another player's
-- machine most of those entries point at files that do not exist. The WoW client has no "does this file exist"
-- call, so each folder of LocalSounds is probed once per session: mute the file, ask the client to play it
-- (PlaySoundFile returns willPlay = false when the file is missing), stop it, unmute it. Two samples per folder
-- are enough because a folder is either installed or it is not. If the client cannot mute, nothing is probed
-- (never makes noise) and the entries are all kept.
local dirOK = {}
local function Probe(path)
    if type(PlaySoundFile) ~= "function" or type(MuteSoundFile) ~= "function" or type(UnmuteSoundFile) ~= "function" then
        return true
    end
    pcall(MuteSoundFile, path)
    local ok, willPlay, handle = pcall(PlaySoundFile, path, "Master")
    if ok and handle and type(StopSound) == "function" then pcall(StopSound, handle) end
    pcall(UnmuteSoundFile, path)
    if not ok then return true end   -- API error: do not hide anything on a guess
    return willPlay and true or false
end

local function FolderAvailable(dir, entries)
    local c = dirOK[dir]
    if c ~= nil then return c end
    local tries = 0
    c = false
    for _, e in ipairs(entries) do
        tries = tries + 1
        if Probe(e) then c = true; break end
        if tries >= 2 then break end
    end
    dirOK[dir] = c
    return c
end

-- LocalSounds entries whose files exist on this machine (cached for the session)
local availableLocal
function ns.AvailableLocalSounds()
    if availableLocal then return availableLocal end
    local byDir, order = {}, {}
    for _, s in ipairs(ns.LocalSounds or {}) do
        local path = s[2]
        local dir = type(path) == "string" and path:match("^(.*)[\\/][^\\/]*$") or ""
        if not byDir[dir] then byDir[dir] = {}; order[#order + 1] = dir end
        local t = byDir[dir]; t[#t + 1] = path
    end
    local ok = {}
    for _, dir in ipairs(order) do ok[dir] = FolderAvailable(dir, byDir[dir]) end
    availableLocal = {}
    for _, s in ipairs(ns.LocalSounds or {}) do
        local path = s[2]
        local dir = type(path) == "string" and path:match("^(.*)[\\/][^\\/]*$") or ""
        if ok[dir] then availableLocal[#availableLocal + 1] = s end
    end
    return availableLocal
end

-- Returns list of { label=, source=, value= }
function ns.BuildSoundList()
    local out = {}
    if SOUNDKIT then
        for _, n in ipairs(KIT_NAMES) do
            if SOUNDKIT[n] then
                out[#out + 1] = { label = "[Game] " .. n, source = "kit", value = tostring(SOUNDKIT[n]) }
            end
        end
    end
    for _, s in ipairs(ns.AvailableLocalSounds()) do
        out[#out + 1] = { label = s[1], source = "file", value = s[2] }
    end
    local lsm = LSM()
    if lsm then
        local names = {}
        for name in pairs(lsm:HashTable("sound")) do names[#names + 1] = name end
        table.sort(names)
        for _, name in ipairs(names) do
            out[#out + 1] = { label = name, source = "lsm", value = name }
        end
    end
    return out
end

function ns.SoundLabel(s)
    if not s or s.value == "" then return "(none)" end
    if s.source == "kit" then
        if SOUNDKIT then
            for k, v in pairs(SOUNDKIT) do
                if tostring(v) == s.value and type(k) == "string" then return "[Game] " .. k end
            end
        end
        return "[Game] " .. s.value
    end
    if s.source == "lsm" then return s.value end
    for _, l in ipairs(ns.LocalSounds or {}) do
        if l[2] == s.value then return l[1] end
    end
    return s.value
end

-- Play regardless of the rule's "Play a sound" switch (used by Test / Preview).
function ns.PlaySoundPreview(s)
    if not s then return end
    local c = {}
    for k, v in pairs(s) do c[k] = v end
    c.enabled = true
    ns.PlaySound(c)
end

function ns.PlaySound(s)
    if not s or not s.enabled or s.value == "" then return end
    local channel = ns.Val(s.channel) or "Master"
    if s.source == "kit" then
        PlaySound(tonumber(s.value), channel)
    elseif s.source == "lsm" then
        local lsm = LSM()
        local path = lsm and lsm:Fetch("sound", s.value, true)
        if path then PlaySoundFile(path, channel) end
    else -- file: path or FileDataID
        PlaySoundFile(tonumber(s.value) or s.value, channel)
    end
end

-- Channel volume (game CVars; WoW has no per-sound volume)
local CHANNEL_CVAR = {
    Master = "Sound_MasterVolume", SFX = "Sound_SFXVolume", Music = "Sound_MusicVolume",
    Ambience = "Sound_AmbienceVolume", Dialog = "Sound_DialogVolume",
}
function ns.GetChannelVolume(channel)
    local cv = CHANNEL_CVAR[channel or "Master"] or CHANNEL_CVAR.Master
    local ok, v = pcall(C_CVar.GetCVar, cv)
    return ok and tonumber(v) or 1
end
function ns.SetChannelVolume(channel, vol)
    local cv = CHANNEL_CVAR[channel or "Master"] or CHANNEL_CVAR.Master
    pcall(C_CVar.SetCVar, cv, tostring(math.max(0, math.min(1, vol or 1))))
end
