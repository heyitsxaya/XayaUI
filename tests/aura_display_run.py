"""Offline test for XayaUI_CombatEngine/AuraDisplay.lua (Lua 5.1 via lupa).  Run: python3 tests/aura_display_run.py

The game's secure aura container cannot run outside the client, so this uses a STAND-IN that enforces the same argument
rules Blizzard's own source enforces (Blizzard_CustomAuraContainer.lua validators, AuraContainerFlowLayout setters,
CustomAuraButton setter object types; live branch read 2026-11-02).  It proves AuraDisplay.lua calls those APIs with valid
arguments and wires the right spell-ID set; it does NOT prove the real container draws anything: that needs the game.
All spell IDs below are made up.
"""
import os, sys
from lupa.lua51 import LuaRuntime

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
L = LuaRuntime(unpack_returned_tuples=True)

L.execute(r'''
-- ---- generic frame stand-in ----
local function proxyFrame(kind)
    local f = { _kind = kind, _calls = {}, _points = {}, shown = true }
    return setmetatable(f, { __index = function(t, k)
        if k == "SetPoint" then return function(self, ...) self._points[#self._points + 1] = { ... } end end
        if k == "ClearAllPoints" then return function(self) self._points = {} end end
        if k == "Show" then return function(self) self.shown = true end end
        if k == "Hide" then return function(self) self.shown = false end end
        if k == "SetScale" then return function(self, v) self.scale = v end end
        if k == "SetParent" then return function(self, p) self.parent = p end end
        if k == "GetParent" then return function(self) return self.parent end end
        if k == "SetShown" then return function(self, v) self.shown = v and true or false end end
        if k == "IsShown" then return function(self) return self.shown end end
        if k == "GetFrameStrata" then return function(self) return self.strata or "HIGH" end end
        if k == "SetFrameStrata" then return function(self, v) self.strata = v end end
        if k == "SetAlpha" then return function(self, v) self.alpha = v end end
        if k == "SetTexCoord" then return function(self, ...) self.texcoord = { ... } end end
        if k == "SetDrawSwipe" then return function(self, v) self.swipe = v end end
        if k == "SetFont" then return function(self, font, size) self.fontsize = size end end
        if k == "CreateTexture" then return function() return proxyFrame("Texture") end end
        if k == "CreateFontString" then return function() return proxyFrame("FontString") end end
        return function() end
    end })
end

STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
UIParent = proxyFrame("UIParent"); PlayerFrame = proxyFrame("PlayerFrame")
_G.combat = false
function InCombatLockdown() return _G.combat end

AnchorUtil = { FlowLayoutAxis = { Horizontal = 0, Vertical = 1 }, FlowDirection = { Left = -1, Right = 1, Up = 1, Down = -1 } }
AuraContainerSortMethod = { Default = 0, BigDefensive = 1, UnitFrameDebuff = 2, ImportantOnly = 3, Expiration = 4, ExpirationOnly = 5, Name = 6, NameOnly = 7, AuraInstanceIDOnly = 8 }
AuraContainerSortDirection = { Normal = 0, Reverse = 1 }
CustomAuraContainerAuraProcessingPolicy = { None = 0, ProcessAura = 1 }

local function isEnum(e, v) for _, x in pairs(e) do if x == v then return true end end return false end
local function nonNegIntOrInf(v) return v == math.huge or (type(v) == "number" and v >= 0 and v == math.floor(v)) end

containers = {}
failAdd = false
buttons = {}

-- the button handed to initializeFrame: its setters check object types like CustomAuraButton does
local function newButton()
    local b = proxyFrame("AuraButton")
    b.log = {}
    function b:SetIcon(tex) assert(tex._kind == "Texture", "SetIcon needs a Texture"); self.log.icon = tex end
    function b:SetDurationCooldown(cd) assert(cd._kind == "Cooldown", "SetDurationCooldown needs a Cooldown"); self.log.cd = cd end
    function b:SetDurationText(fs, opts) assert(fs._kind == "FontString", "SetDurationText needs a FontString"); assert(type(opts) == "table"); self.log.dur = fs end
    function b:SetApplicationCount(fs, opts) assert(fs._kind == "FontString", "SetApplicationCount needs a FontString"); assert(type(opts) == "table"); self.log.count = fs end
    return b
end

function CreateFrame(kind, name, parent, template)
    if template == "CustomAuraContainerTemplate" then
        assert(kind == "AuraContainer", "the container template must be created as an AuraContainer widget, not " .. tostring(kind))
        local c = proxyFrame("Container")
        c.name, c.groups, c.flow, c.refiltered = name, {}, {}, 0
        function c:SetUnit(u) assert(type(u) == "string"); self.unit = u end
        function c:SetAuraProcessingPolicy(p) assert(isEnum(CustomAuraContainerAuraProcessingPolicy, p)); self.policy = p end
        function c:AddAuraGroup(key, filter, o)
            assert(type(key) == "string" and key ~= "", "groupKey")
            -- Blizzard: AuraUtil.IsValidFilterString (tokens split on "|" / space, each a known AuraFilters value)
            local valid = { HELPFUL = 1, HARMFUL = 1, PLAYER = 1, RAID = 1, CANCELABLE = 1, INCLUDE_NAME_PLATE_ONLY = 1, MAW = 1, EXTERNAL_DEFENSIVE = 1, CROWD_CONTROL = 1, RAID_IN_COMBAT = 1, RAID_PLAYER_DISPELLABLE = 1, BIG_DEFENSIVE = 1, IMPORTANT = 1, DISPELLABLE = 1 }
            for tok in tostring(filter):gmatch("[^| ]+") do assert(valid[tok:gsub("^!", "")], "unknown aura filter component " .. tok) end
            assert(not self.groups[key], "group exists")
            if failAdd then error("simulated: includeSpellIDs rejected") end
            local cf = o.candidateFilters
            assert(cf == nil or type(cf) == "table")
            if cf and cf.includeSpellIDs ~= nil then assert(type(cf.includeSpellIDs) == "table", "includeSpellIDs must be a table") end
            assert(isEnum(AuraContainerSortMethod, o.sortMethod), "sortMethod")
            assert(isEnum(AuraContainerSortDirection, o.sortDirection), "sortDirection")
            assert(nonNegIntOrInf(o.maxFrameCount), "maxFrameCount")
            local l = o.layout
            for _, k in ipairs({ "elementSpacing", "lineSpacing", "elementWidth", "elementHeight" }) do
                assert(l[k] == nil or (type(l[k]) == "number" and l[k] >= 0), k)
            end
            assert(o.initializeFrame == nil or type(o.initializeFrame) == "function")
            self.groups[key] = { filters = cf, layout = l, init = o.initializeFrame, filter = filter, max = o.maxFrameCount }
            for i = 1, 3 do local b = newButton(); buttons[#buttons + 1] = b; o.initializeFrame(b) end   -- Blizzard pre-creates a batch
        end
        function c:SetAuraGroupCandidateFilters(key, cf) assert(self.groups[key], "no group"); self.groups[key].filters = cf; self.refiltered = (self.refiltered or 0) + 1 end
        function c:SetAuraGroupLayout(key, l) assert(self.groups[key], "no group"); self.groups[key].layout = l end
        function c:SetFlowLayoutAxis(a) assert(isEnum(AnchorUtil.FlowLayoutAxis, a)); self.flow.axis = a end
        function c:SetFlowLayoutAnchorPoint(p) assert(type(p) == "string"); self.flow.anchor = p end
        function c:SetFlowLayoutGrowthDirection(h, v) assert(isEnum(AnchorUtil.FlowDirection, h) and isEnum(AnchorUtil.FlowDirection, v)); self.flow.h, self.flow.v = h, v end
        function c:SetFlowLayoutMaximumLineSize(m) assert(m == nil or type(m) == "number"); self.flow.max = m end
        containers[#containers + 1] = c
        return c
    elseif kind == "Cooldown" then
        return proxyFrame("Cooldown")
    end
    local f = proxyFrame(kind)
    function f:RegisterEvent() end
    function f:SetScript(n, fn) if n == "OnEvent" then _G.evHandler = fn end end
    return f
end

SlashCmdList = {}
C_AddOns = { LoadAddOn = function() return true end }
printed = {}

local ns = { rules = {}, folders = {} }
XayaUI_NS = ns
function ns.Print(...) local t = {} for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end printed[#printed + 1] = table.concat(t, " ") end
function ns.FolderById(id) for _, f in ipairs(ns.folders) do if f.id == id then return f end end end
function ns.Ignored(s) return s == nil or s == "" or s == "none" or s == "any" end
function ns.CooldownUsed(r) return r.useCooldown == true or (tonumber(r.spellID) or 0) ~= 0 or not ns.Ignored(r.cdState) end
function ns.ConditionsOf(p) local out = {} for _, r in ipairs(ns.rules) do if r.parentUid == p.uid and not r.isCue then out[#out + 1] = r end end return out end
ns.runtime = setmetatable({}, { __mode = "k" })
HOSTS = {}
function ns.DisplayFrame(rule) local h = HOSTS[rule]; if not h then h = proxyFrame("Host"); h.parent = "PARENT_OF_" .. tostring(rule.name); h.strata = "MEDIUM"; HOSTS[rule] = h end return h end
HOOKS = {}
function hooksecurefunc(t, name, fn) local orig = t[name]; t[name] = function(...) local a, b, c = orig(...); fn(...); return a, b, c end; HOOKS[name] = true end
function ns.MarkDirty() end
function ns.ToggleUnlock() end
function ns.SetGroupUnlocked() end
function ns.SetMoveUnlocked() end
ns.groupUnlocked, ns.moveUnlocked = {}, {}
TIMERS = {}
C_Timer = { After = function(d, fn) TIMERS[#TIMERS + 1] = fn end, NewTicker = function() return {} end }
function GetSpecialization() return 2 end
function GetSpecializationInfo(i) return 250 end
date = os.date
function ns.FindParentRule(rule) for _, r in ipairs(ns.rules) do if r.uid == rule.parentUid and not r.isCue then return r end end end
function ns.CuesOf(rule) local out = {} for _, r in ipairs(ns.rules) do if r.isCue and r.parentUid == rule.uid then out[#out + 1] = r end end return out end
refreshed = 0
function ns.RefreshAllVisuals() refreshed = refreshed + 1 end
CueRulesDB = {}
date = os.date
Enum = { AddOnProfilerMetric = { RecentAverageTime = 1 } }
profilerMs = 0.2
C_AddOnProfiler = { GetAddOnMetric = function(name, metric) assert(metric == 1); if name == "XayaUI_CombatEngine" then return profilerMs end if name == "Blizzard_AuraContainer" then return blizzMs or 0 end end }
_G.NS = ns
local f = assert(loadfile(AURA_DISPLAY_PATH))
f("XayaUI_CombatEngine", ns)
'''.replace("AURA_DISPLAY_PATH", repr(os.path.join(ROOT, "XayaUI_CombatEngine", "AuraDisplay.lua")).replace("'", '"')))


fails = []
def check(name, cond, extra=""):
    print(("PASS " if cond else "FAIL ") + name + (("  [" + str(extra) + "]") if (extra and not cond) else ""))
    if not cond:
        fails.append(name)
def lua(s): return L.execute(s)

L.execute(r"""
local ns = NS
ns.folders = {
  { id = "fA", name = "Alpha Group", cType = "dynamic", cGrowth = "RIGHT", cSpacing = 5, cW = 100, cH = 0, cPoint = "CENTER", cX = 10, cY = 20 },
  { id = "fAs", name = "Alpha static child", parent = "fA" },
  { id = "fS", name = "Static Group" },
  { id = "fC", name = "Center Group", cType = "dynamic", cGrowth = "HCENTER" },
}
local function cueVis() return { enabled = true, trigger = "condition", w = 30, h = 30, zoom = 0, text = { enabled = true, size = 12 }, count = { enabled = true, size = 10 } } end
local n = 0
function P(name, folder, id, extra)   -- a buff rule with an icon cue (the usual shape)
  n = n + 1
  local p = { uid = "u" .. n, name = name, folder = folder, useBuff = true, buffID = id, buffState = "present", cdState = "none", enabled = true, visual = { enabled = false } }
  for k, v in pairs(extra or {}) do p[k] = v end
  local c = { uid = "c" .. n, name = name .. " cue", folder = folder, isCue = true, parentUid = p.uid, cueKey = "k" .. n, visual = cueVis() }
  ns.rules[#ns.rules + 1] = p; ns.rules[#ns.rules + 1] = c
  return p, c
end
ns.rules = {}
A1, A1c = P("a1", "fA", 9001)
A2, A2c = P("a2", "fA", 9002, { buffAlt = { 9102 } })
A3 = P("a3 disabled", "fA", 9003, { enabled = false })
AS = P("a static child", "fAs", 9050)
S1, S1c = P("s1 static", "fS", 9301)
U1, U1c = P("u1 ungrouped", nil, 9401)
M1 = P("m1 missing", nil, 9501, { buffState = "missing" })
CD1 = P("cd1 also cooldown", nil, 9601, { useCooldown = true, spellID = 777, cdState = "ready" })
C1 = P("c1 centred", "fC", 9701)
-- a rule whose own display shows while the buff is up (no cue)
OWN = { uid = "own", name = "own display", useBuff = true, buffID = 9801, buffState = "present", enabled = true, visual = { enabled = true, trigger = "buffActive", w = 40, h = 40 } }
ns.rules[#ns.rules + 1] = OWN
-- target debuff rules
TD = { uid = "td", name = "td debuff", enabled = true, extra = { list = { { type = "targetDebuff", spellID = 204598, unit = "target", state = "yes" } } }, visual = { enabled = true, trigger = "condition", w = 30, h = 30 } }
TDG = { uid = "tdg", name = "tdg debuff in group", folder = "fA", enabled = true, extra = { list = { { type = "targetDebuff", spellID = 204599, state = "yes" } } }, visual = { enabled = true, trigger = "condition", w = 30, h = 30 } }
-- a cooldown-only display: not an aura display at all
CDONLY = { uid = "cdo", name = "cooldown only", useCooldown = true, spellID = 555, cdState = "ready", enabled = true, visual = { enabled = true, trigger = "condition" } }
SPEC = P("spec 251 only", nil, 9901, { load = { specs = { ["251"] = true } } })
ns.rules[#ns.rules + 1] = TD; ns.rules[#ns.rules + 1] = TDG; ns.rules[#ns.rules + 1] = CDONLY
SNAP = {}
for i, r in ipairs(ns.rules) do local c = 0; for _ in pairs(r) do c = c + 1 end; SNAP[i] = c end
""")

# 1. automatic: everything that can be drawn faithfully, without any switch or tag
lua('evHandler("PLAYER_ENTERING_WORLD")')
own = lambda r: lua("return NS.EngineOwns(%s) == true" % r)
check("dynamic group drawn by one container (members incl. a static sub-group's rule)", lua("local g = NS.AuraDisplay._groups.fA; local s = g and g.frame.groups.main.filters.includeSpellIDs; return g.ok and s[9001] and s[9002] and s[9102] and s[9050] and not s[9003]"))
check("parent and cue of a group member are engine-owned", own("A1") and own("A1c") and own("AS"))
check("static-group rule gets its own slot", lua("local s = NS.AuraDisplay._singles[S1]; return s and s.ok and s.frame.groups.main.max == 1 and s.frame.unit == 'player'") and own("S1c"))
check("ungrouped rule gets its own slot (the tester's Anti-Magic Shell case)", lua("local s = NS.AuraDisplay._singles[U1]; return s and s.ok") and own("U1") and own("U1c"))
check("a rule's own display (no cue) gets a slot sized like it", lua("local s = NS.AuraDisplay._singles[OWN]; return s and s.ok and s.frame.groups.main.layout.elementWidth == 40"))
check("your target debuff gets a target slot with your debuffs only", lua("local s = NS.AuraDisplay._singles[TD]; return s and s.ok and s.frame.unit == 'target' and s.frame.groups.main.filter == 'HARMFUL|PLAYER' and s.frame.groups.main.filters.includeSpellIDs[204598]"))
check("'missing' rule stays with XayaUI (would be drawn backwards)", not own("M1"))
check("rule that also needs a cooldown state stays with XayaUI", not own("CD1"))
check("centred dynamic group fails cleanly, its rules stay with XayaUI", lua("return NS.AuraDisplay._groups.fC.ok == false") and not own("C1"))
check("target debuff inside a dynamic group stays with XayaUI", not own("TDG"))
check("disabled rule not drawn", not own("A3"))
L.execute('LEFT = {}; for _, e in ipairs(NS.AuraDisplay._Left()) do LEFT[e[1].name] = e[2] end')
check("every kept display has a reason", lua("return LEFT['m1 missing'] ~= nil and LEFT['cd1 also cooldown'] ~= nil and LEFT['c1 centred'] ~= nil and LEFT['tdg debuff in group'] ~= nil"))
check("a cooldown-only display is not listed as kept (not an aura display)", lua("return LEFT['cooldown only'] == nil"))
check("rules were never modified", lua("for i, r in ipairs(NS.rules) do local c = 0; for _ in pairs(r) do c = c + 1 end; if c ~= SNAP[i] then return false end end return true"))

# 2. placement of a single slot: on XayaUI's own icon, same parent, same strata
check("single slot sits on XayaUI's icon (TOPLEFT at icon centre - half size)", lua("local s = NS.AuraDisplay._singles[S1]; local p = s.frame._points[#s.frame._points]; return p[1] == 'TOPLEFT' and p[2] == HOSTS[S1c] and p[3] == 'CENTER' and p[4] == -15 and p[5] == 15 and s.frame.parent == HOSTS[S1c].parent and s.frame.strata == 'MEDIUM'"))
check("group container created as AuraContainer widgets only (stub asserts it)", lua("return #containers >= 5"))

# 3. load / talent settings followed live for 'condition' displays
lua('NS.runtime[U1] = { info = { ctxOK = false } }; NS.AuraDisplay.SyncLive()')
check("not loaded -> its slot hides", lua("return NS.AuraDisplay._singles[U1].frame.shown == false"))
lua('NS.runtime[U1] = { info = { ctxOK = true, talentOK = true } }; NS.AuraDisplay.SyncLive()')
check("loaded again -> shown", lua("return NS.AuraDisplay._singles[U1].frame.shown == true"))
lua('NS.runtime[A2] = { info = { ctxOK = false } }; NS.AuraDisplay.SyncLive()')
check("group member not loaded -> left out of the group's filter", lua("local s = NS.AuraDisplay._groups.fA.frame.groups.main.filters.includeSpellIDs; return s[9001] and not s[9002] and not s[9102]"))
lua('NS.runtime[A2] = nil; NS.AuraDisplay.SyncLive()')
check("and back in when loaded", lua("local s = NS.AuraDisplay._groups.fA.frame.groups.main.filters.includeSpellIDs; return s[9002] == true"))
lua('local f = NS.AuraDisplay._groups.fA.frame; BEFORE = f.refiltered; NS.AuraDisplay.SyncLive(); NS.AuraDisplay.SyncLive()')
check("no filter rewrite when nothing changed", lua("return NS.AuraDisplay._groups.fA.frame.refiltered == BEFORE"))

# 4. unlock
lua('NS.unlocked = true; NS.AuraDisplay.SyncLive()')
check("everything unlocked: engine steps aside", lua("return NS.AuraDisplay._groups.fA.frame.shown == false and NS.AuraDisplay._singles[S1].frame.shown == false"))
lua('NS.unlocked = false; NS.moveUnlocked[S1c] = true; NS.AuraDisplay.SyncLive()')
check("one display unlocked: only its slot steps aside", lua("return NS.AuraDisplay._singles[S1].frame.shown == false and NS.AuraDisplay._singles[U1].frame.shown == true"))
lua('NS.moveUnlocked[S1c] = nil; NS.groupUnlocked.fA = true; NS.AuraDisplay.SyncLive()')
check("group unlocked: its container steps aside", lua("return NS.AuraDisplay._groups.fA.frame.shown == false"))
lua('NS.groupUnlocked.fA = nil; NS.AuraDisplay.SyncLive()')
check("locked again: all back", lua("return NS.AuraDisplay._groups.fA.frame.shown == true and NS.AuraDisplay._singles[S1].frame.shown == true"))

# 5. keep a group with XayaUI, and back
lua('SlashCmdList["XUIENGINE"]("off static group")')
check("off <group>: its rules go back to XayaUI", not own("S1"))
lua('SlashCmdList["XUIENGINE"]("reset static group")')
check("reset <group>: drawn again", own("S1"))

# 6. edits rebuild on their own (debounced) and combat defers
check("edits are hooked (MarkDirty)", lua("return HOOKS.MarkDirty == true"))
lua('TIMERS = {}; NS.MarkDirty(); NS.MarkDirty()')
check("two quick edits queue one rebuild", lua("return #TIMERS == 1"))
lua('combat = true; NS.rules[#NS.rules + 1] = { uid = "late", name = "late", useBuff = true, buffID = 9991, buffState = "present", enabled = true, visual = { enabled = true, trigger = "buffActive" } }; TIMERS[1]()')
check("no rebuild during combat lockdown", lua("return NS.AuraDisplay._singles[NS.rules[#NS.rules]] == nil"))
lua('combat = false; evHandler("PLAYER_REGEN_ENABLED")')
check("deferred rebuild runs when combat ends", own("NS.rules[#NS.rules]"))

# 7. status names everything; help has no colour code
lua('printed = {}; SlashCmdList["XUIENGINE"]("")')
check("status: what the engine draws", lua("for _, l in ipairs(printed) do if l:find('^Engine draws:') then return true end end return false"))
check("status: what XayaUI keeps, with reasons", lua("local a, b = false, false; for _, l in ipairs(printed) do if l:find('XayaUI keeps') then a = true end if l:find('MISSING') then b = true end end return a and b"))
check("help text has no '|r' colour-code sequence", lua("for _, l in ipairs(printed) do if l:find('|r', 1, true) then return false end end return true"))

# 8. guard: lean first, then off
lua('profilerMs = 0.2; blizzMs = 0.1; for i = 1, 3 do NS.AuraDisplay.GuardCheck() end')
check("guard: cheap engine never trips", lua("return CueRulesDB.engineDisplay.lean == nil and CueRulesDB.engineDisplay.auto == true"))
lua('profilerMs = 0.5; blizzMs = 0.7; NS.AuraDisplay.GuardCheck(); NS.AuraDisplay.GuardCheck(); profilerMs = 0.1; NS.AuraDisplay.GuardCheck()')
check("guard: counts Blizzard's container cost too, and a low reading resets it", lua("return CueRulesDB.engineDisplay.lean == nil"))
lua('profilerMs = 0.6; blizzMs = 0.6; for i = 1, 3 do NS.AuraDisplay.GuardCheck() end')
check("guard stage 1: lean mode (spec being played only)", lua("return CueRulesDB.engineDisplay.lean == true and CueRulesDB.engineDisplay.auto == true") and not own("SPEC") and own("U1"))
lua('printed = {}; for i = 1, 3 do NS.AuraDisplay.GuardCheck() end')
check("guard stage 2: automatic mode off, all back to XayaUI, said in chat", lua("return CueRulesDB.engineDisplay.auto == false and #CueRulesDB.engineDisplay.guardTrips == 2 and printed[1]:find('performance guard') ~= nil") and not own("U1") and not own("A1"))
lua('profilerMs = 0.1; blizzMs = 0; SlashCmdList["XUIENGINE"]("auto on")')
check("auto on: everything back, lean mode cleared", lua("return CueRulesDB.engineDisplay.auto == true and CueRulesDB.engineDisplay.lean == nil") and own("U1") and own("SPEC"))

# 9. a container that fails hands its displays back
lua('failAdd = true; for k, s in pairs(NS.AuraDisplay._singles) do s.frame = nil end; for k, g in pairs(NS.AuraDisplay._groups) do g.frame = nil end; NS.AuraDisplay.Build()')
check("container error: nothing engine-owned, failures listed", (not own("U1")) and (not own("A1")) and lua("for _, e in ipairs(NS.AuraDisplay._Left()) do if e[2]:find('failed') then return true end end return false"))
lua('failAdd = false')

# 10. loaded twice (XayaUI loads the engine files and the separate XayaUI_CombatEngine folder is installed too): one copy only
lua('BEFORE_D = NS.AuraDisplay; BEFORE_SLASH = SlashCmdList["XUIENGINE"]')
L.execute(r'''local f = assert(loadfile(PATH)); f("XayaUI_CombatEngine", NS)'''.replace("PATH", repr(os.path.join(ROOT, "XayaUI_CombatEngine", "AuraDisplay.lua")).replace("'", '"')))
check("second copy steps aside (same module, same command, no second set of hooks)", lua("return NS.AuraDisplay == BEFORE_D and SlashCmdList['XUIENGINE'] == BEFORE_SLASH"))

print()
print("FAILED: " + ", ".join(fails) if fails else "ALL PASSED")
sys.exit(1 if fails else 0)
