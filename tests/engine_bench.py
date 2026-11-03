"""Whole-engine benchmark: loads the addon's engine files with a stand-in game API and runs ns.Step() over a SavedVariables file.
Run: python3 tests/engine_bench.py <addon folder> <path to WTF/.../SavedVariables/XayaUI.lua> [ticks]
Reads the saved file only (never writes it, never copies its data anywhere). Set SIGOUT=<file> to write each rule's
active / wanted state per tick, so two builds can be compared for identical decisions (cmp the two files).
The numbers are plain Lua 5.1 with stub API calls: compare builds against each other, not against frames per second in the game."""
import sys, os, time
from lupa.lua51 import LuaRuntime
ROOT = sys.argv[1]; SV = sys.argv[2]; TICKS = int(sys.argv[3]) if len(sys.argv) > 3 else 200
L = LuaRuntime(unpack_returned_tuples=True)
L.execute(open(SV, encoding='utf-8', errors='replace').read())
L.execute(r'''
local DEEP
local function deep() return DEEP end
DEEP = setmetatable({}, { __index = function() return DEEP end, __call = function() return nil end })
missing = {}
setmetatable(_G, { __index = function(_, k) missing[k] = (missing[k] or 0) + 1; return DEEP end })
NOW = 1000
function GetTime() return NOW end
function time() return 1793660000 + math.floor(NOW) end
date = os.date
function debugprofilestop() return os.clock() * 1000 end
function issecretvalue() return false end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function hooksecurefunc() end
function InCombatLockdown() return COMBAT end
function UnitAffectingCombat() return COMBAT end
function GetFramerate() return 60 end
COMBAT = true
strsplit = function(sep, s) local out = {} for p in tostring(s):gmatch("([^" .. sep .. "]+)") do out[#out + 1] = p end return unpack(out) end
strtrim = function(s) return (tostring(s):gsub("^%s+", ""):gsub("%s+$", "")) end
tinsert, tremove = table.insert, table.remove
format = string.format
function securecallfunction(f, ...) return f(...) end
-- frames
local FrameMT
local function NewFrame(kind)
  local f = { _kind = kind, _shown = true, _children = {} }
  return setmetatable(f, FrameMT)
end
local methods = {}
function methods:IsShown() return self._shown end
function methods:IsVisible() return self._shown end
function methods:Show() self._shown = true end
function methods:Hide() self._shown = false end
function methods:SetShown(v) self._shown = v and true or false end
function methods:GetFrameLevel() return 1 end
function methods:GetWidth() return 30 end
function methods:GetHeight() return 30 end
function methods:GetSize() return 30, 30 end
function methods:GetScale() return 1 end
function methods:GetEffectiveScale() return 1 end
function methods:GetAlpha() return 1 end
function methods:GetCenter() return 100, 100 end
function methods:GetLeft() return 85 end
function methods:GetRight() return 115 end
function methods:GetTop() return 115 end
function methods:GetBottom() return 85 end
function methods:GetFrameStrata() return "MEDIUM" end
function methods:GetNumRegions() return 0 end
function methods:GetRegions() end
function methods:GetChildren() end
function methods:GetNumPoints() return 0 end
function methods:GetText() return self._text end
function methods:SetText(t) self._text = t end
function methods:GetName() return nil end
function methods:GetObjectType() return self._kind end
function methods:GetParent() return UIParent end
function methods:GetScript() return nil end
function methods:SetScript(n, fn) self["_s_" .. n] = fn end
function methods:HookScript() end
function methods:IsMouseOver() return false end
function methods:GetStringWidth() return 20 end
function methods:CreateTexture() return NewFrame("Texture") end
function methods:CreateFontString() return NewFrame("FontString") end
function methods:CreateMaskTexture() return NewFrame("MaskTexture") end
function methods:CreateAnimationGroup() return NewFrame("AnimationGroup") end
function methods:CreateAnimation() return NewFrame("Animation") end
function methods:IsPlaying() return false end
function methods:GetVertexColor() return 1, 1, 1, 1 end
function methods:GetTexture() return nil end
function methods:GetPoint() return "CENTER", UIParent, "CENTER", 0, 0 end
function methods:GetFont() return "Fonts\\FRIZQT__.TTF", 12, "OUTLINE" end
local noop = function() end
FrameMT = { __index = function(t, k) local m = methods[k]; if m then return m end; if type(k) == "string" and k:match("^[A-Z]") then return noop end; return nil end }
FRAME_METHODS = methods   -- other tests add methods here (tests/layout_parity_run.py adds real geometry)
function CreateFrame(kind, name, parent, template) local f = NewFrame(kind or "Frame"); if name then _G[name] = f end; if parent then f._parent = parent end; return f end
UIParent = NewFrame("Frame"); WorldFrame = NewFrame("Frame")
SlashCmdList = {}
C_Timer = { After = function() end, NewTicker = function() return { Cancel = function() end } end, NewTimer = function() return { Cancel = function() end } end }
C_AddOns = { GetAddOnMetadata = function() return "bench" end, IsAddOnLoaded = function() return false end, GetNumAddOns = function() return 0 end, LoadAddOn = function() end }
-- spells / auras: a stable pseudo-random world
local function h(id) id = tonumber(id) or 0; return (id * 2654435761) % 100 end
C_Spell = {
  GetSpellCooldown = function(id) local x = h(id); if x < 30 then return { startTime = NOW - 2, duration = 8, isEnabled = true, modRate = 1 } end return { startTime = 0, duration = 0, isEnabled = true, modRate = 1 } end,
  GetSpellCharges = function(id) local x = h(id); if x < 10 then return { currentCharges = 1, maxCharges = 2, cooldownStartTime = NOW - 1, cooldownDuration = 10 } end return nil end,
  GetSpellInfo = function(id) return { name = "Spell" .. tostring(id), iconID = 136243, spellID = id } end,
  GetSpellTexture = function() return 136243 end,
  GetSpellName = function(id) return "Spell" .. tostring(id) end,
  IsSpellUsable = function() return true, false end,
  GetSpellDescription = function() return "" end,
  IsSpellInRange = function() return true end,
  GetOverrideSpell = function(id) return id end,
}
C_UnitAuras = {
  GetUnitAuraBySpellID = function(unit, id) local x = h(id); if x < 40 then return { auraInstanceID = id, applications = 1, expirationTime = NOW + 5, duration = 10, spellId = id, icon = 1 } end return nil end,
  GetPlayerAuraBySpellID = function(id) return C_UnitAuras.GetUnitAuraBySpellID("player", id) end,
  GetAuraDataByAuraInstanceID = function() return nil end,
  GetAuraDuration = function() return nil end,
}
IsPlayerSpell = function() return true end
IsSpellKnown = function() return true end
IsSpellKnownOrOverridesKnown = function() return true end
UnitClass = function() return "Demon Hunter", "DEMONHUNTER", 12 end
UnitRace = function() return "Night Elf", "NightElf" end
UnitLevel = function() return 90 end
UnitName = function() return "Xaya", "Sargeras" end
UnitExists = function(u) return u == "player" or u == "target" end
UnitIsDead = function() return false end
UnitIsDeadOrGhost = function() return false end
UnitHealth = function() return 50 end
UnitHealthMax = function() return 100 end
UnitPower = function() return 50 end
UnitPowerMax = function() return 100 end
UnitPowerType = function() return 17, "FURY" end
UnitCanAttack = function() return true end
UnitGUID = function() return "Player-1-1" end
GetSpecialization = function() return 2 end
GetSpecializationInfo = function() return 581, "Vengeance" end
IsInGroup = function() return false end
IsInRaid = function() return false end
IsInInstance = function() return false, "none" end
GetInstanceInfo = function() return "World", "none", 0, "", 5, 0, false, 2552 end
GetNumGroupMembers = function() return 0 end
IsMounted = function() return false end
IsResting = function() return false end
GetShapeshiftForm = function() return 0 end
GetZoneText = function() return "Dornogal" end
GetRealZoneText = function() return "Dornogal" end
GetSubZoneText = function() return "" end
C_Map = { GetBestMapForUnit = function() return 2339 end }
GetLocale = function() return "enUS" end
PlaySoundFile = function() return true end
PlaySound = function() return true end
C_Secrets = nil
''')
toc = [l.strip() for l in open(os.path.join(ROOT, "XayaUI", "XayaUI.toc")) if l.strip() and not l.startswith("#")]
load = L.eval("function(src, name, ns) local f, e = loadstring(src, '@' .. name); if not f then error(e) end; return f('XayaUI', ns) end")
ns = L.eval("{}")
L.globals().NS = ns
skip = ("Libs", "Console.lua", "GameMenu", "MinimapButton", "AuraSources")   # core files only (0.6.0 layout: XayaUI/XayaUI.toc)
loaded, failed = [], []
for f in toc:
    f = f.replace("\\", "/")
    if f.startswith(skip) or not f.endswith(".lua"): continue
    try:
        load(open(os.path.join(ROOT, "XayaUI", f), encoding='utf-8').read(), f, ns); loaded.append(f)
    except Exception as e:
        failed.append((f, str(e)[:150]))
print("loaded:", " ".join(loaded)); print("failed:", failed)
L.execute(r'''
local ns = NS
ns.rules = CueRulesDB.rules; ns.folders = CueRulesDB.folders or {}
if ns.NormalizeRule then for _, r in ipairs(ns.rules) do pcall(ns.NormalizeRule, r) end end
ns.Print = function() end
ns.Log = ns.Log or function() end
errs = {}
local oldPrint = ns.Print
ns.Print = function(msg) errs[#errs + 1] = tostring(msg) end
''')
n = L.eval("#NS.rules"); on = L.eval("(function() local n=0 for _,r in ipairs(NS.rules) do if r.enabled then n=n+1 end end return n end)()")
print("rules:", n, "enabled:", on)
res = L.execute(r'''
local ns, T = NS, ...
for i = 1, 5 do NOW = NOW + 0.2; ns.Step() end      -- warm-up (frames created)
collectgarbage(); collectgarbage()
collectgarbage("stop")
local m0, t0 = collectgarbage("count"), os.clock()
for i = 1, T do NOW = NOW + 0.2; ns.Step() end
local m1, t1 = collectgarbage("count"), os.clock()
collectgarbage("restart")
-- per-frame effects: run every shown frame's OnUpdate for T*6 frames (30 fps between 5 ticks)
local fx0, fxm0 = os.clock(), collectgarbage("count")
collectgarbage("stop")
return (t1 - t0) * 1000 / T, (m1 - m0) / T
''', TICKS)
print("per Step: %.3f ms, %.2f KB garbage" % res)
sig = L.execute(r'''
local ns = NS
local out = {}
for t = 1, 60 do
  NOW = NOW + 0.2
  COMBAT = (t % 20) < 12
  ns.Step()
  local parts = {}
  for i, r in ipairs(ns.rules) do
    local rt = ns.runtime[r]
    parts[#parts + 1] = (rt and rt.active and "A" or "-") .. (rt and rt.visualWanted and "W" or "-")
  end
  out[#out + 1] = table.concat(parts)
end
return table.concat(out, "\n")
''')
open(os.environ.get("SIGOUT", "/dev/null"), "w").write(sig)
print("errors printed:", L.eval("#errs")); 
for i in range(1, min(8, L.eval("#errs")) + 1): print("  ", L.eval("errs[%d]" % i)[:200])
miss = L.eval("missing"); top = sorted(((v, k) for k, v in miss.items()), reverse=True)[:25]
print("auto-stubbed globals:", ", ".join("%s(%d)" % (k, v) for v, k in top))
