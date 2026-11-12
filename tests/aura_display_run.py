"""Offline test for XayaUI_Rules/Combat/AuraDisplay.lua (Lua 5.1 via lupa).  Run: python3 tests/aura_display_run.py

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

import re as _re
_cues = open(os.path.join(ROOT, "XayaUI_Rules", "Cues.lua"), encoding="utf-8").read()
_m = _re.search(r"^function ns\.CueGated\(p, cue\)\n.*?^end\n", _cues, _re.S | _re.M)
assert _m, "ns.CueGated not found in Cues.lua"
CUE_GATED_LUA = "[==[" + "local ns = NS\n" + _m.group(0) + "]==]"
# (core 0.6.56, REQUEST-LOG #81: /xuiengine auto / on / off / reset belong to XayaUI Dev Assist, which is not on this branch. The
# engine's own status, /xuiengine, is tested here; the saved settings those Dev Assist words changed are set below straight through
# the engine's own seam, D.DB / D.FindFolder / D._guard.)
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
        if k == "SetDesaturation" then return function(self, v) self.desat = v end end
        if k == "SetVertexColor" then return function(self, r, g, b, a) self.vc = { r, g, b, a } end end
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
FULL = {}   -- [container] = UpdateAllAuras calls
failAdd = false
buttons = {}

-- the button handed to initializeFrame: its setters check object types like CustomAuraButton does
local function newButton()
    local b = proxyFrame("AuraButton")
    b.log = {}
    function b:SetIcon(tex) assert(tex._kind == "Texture", "SetIcon needs a Texture"); self.log.icon = tex end
    function b:SetDurationCooldown(cd) assert(cd._kind == "Cooldown", "SetDurationCooldown needs a Cooldown"); self.log.cd = cd end
    function b:SetDurationText(fs, opts)
        assert(fs._kind == "FontString", "SetDurationText needs a FontString"); assert(type(opts) == "table")
        if opts.textFormatter ~= nil and REJECT_FORMATTER then error("simulated: textFormatter rejected") end
        self.log.dur, self.log.durOpts = fs, opts
    end
    function b:SetDurationBar(bar, opts) assert(bar._kind == "StatusBar", "SetDurationBar needs a StatusBar"); assert(type(opts) == "table"); self.log.bar, self.log.barOpts = bar, opts end
    function b:SetApplicationCount(fs, opts) assert(fs._kind == "FontString", "SetApplicationCount needs a FontString"); assert(type(opts) == "table"); self.log.count = fs end
    return b
end

function CreateFrame(kind, name, parent, template)
    if template == "CustomAuraContainerTemplate" then
        assert(kind == "AuraContainer", "the container template must be created as an AuraContainer widget, not " .. tostring(kind))
        local c = proxyFrame("Container")
        c.name, c.groups, c.flow, c.refiltered = name, {}, {}, 0
        c.nGroups, c.enabledCalls = 0, 0   -- (set here: the stand-in frame answers unknown fields with a function)
        function c:SetUnit(u) assert(type(u) == "string"); self.unit = u end
        function c:UpdateAllAuras() FULL[self] = (FULL[self] or 0) + 1 end
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
            for _, k in ipairs({ "elementSpacing", "lineSpacing", "groupSpacing", "groupLineSpacing", "elementWidth", "elementHeight" }) do
                assert(l[k] == nil or (type(l[k]) == "number" and l[k] >= 0), k)
            end
            assert(l.layoutIndex == nil or type(l.layoutIndex) == "number", "layoutIndex must be a number.")   -- Blizzard_CustomAuraContainer.lua
            assert(o.initializeFrame == nil or type(o.initializeFrame) == "function")
            self.groups[key] = { filters = cf, layout = l, init = o.initializeFrame, filter = filter, max = o.maxFrameCount,
                sort = o.sortMethod, dir = o.sortDirection, enabled = true, order = self.nGroups + 1 }
            self.nGroups = self.nGroups + 1
            for i = 1, 3 do local b = newButton(); buttons[#buttons + 1] = b; o.initializeFrame(b) end   -- Blizzard pre-creates a batch
        end
        function c:SetAuraGroupCandidateFilters(key, cf) assert(self.groups[key], "no group"); self.groups[key].filters = cf; self.refiltered = (self.refiltered or 0) + 1 end
        function c:SetAuraGroupLayout(key, l) assert(self.groups[key], "no group"); self.groups[key].layout = l end
        function c:SetAuraGroupEnabled(key, en) assert(self.groups[key], "no group"); assert(type(en) == "boolean", "enabled must be a boolean."); self.groups[key].enabled = en; self.enabledCalls = self.enabledCalls + 1 end
        function c:SetAuraGroupSortMethod(key, m, d) assert(self.groups[key], "no group"); assert(isEnum(AuraContainerSortMethod, m)); self.groups[key].sort, self.groups[key].dir = m, d end
        function c:SetFlowLayoutAxis(a) assert(isEnum(AnchorUtil.FlowLayoutAxis, a)); self.flow.axis = a end
        function c:SetFlowLayoutAnchorPoint(p) assert(type(p) == "string"); self.flow.anchor = p end
        function c:SetFlowLayoutGrowthDirection(h, v) assert(isEnum(AnchorUtil.FlowDirection, h) and isEnum(AnchorUtil.FlowDirection, v)); self.flow.h, self.flow.v = h, v end
        function c:SetFlowLayoutMaximumLineSize(m) assert(m == nil or type(m) == "number"); self.flow.max = m end
        containers[#containers + 1] = c
        return c
    elseif kind == "Cooldown" then
        return proxyFrame("Cooldown")
    elseif kind == "StatusBar" then
        local b = proxyFrame("StatusBar")
        b.tex = proxyFrame("Texture")
        function b:SetStatusBarTexture(t) self.texPath = t end
        function b:GetStatusBarTexture() return self.tex end
        function b:SetOrientation(o) assert(o == "VERTICAL" or o == "HORIZONTAL"); self.orient = o end
        function b:SetReverseFill(r) self.reverse = r end
        return b
    end
    local f = proxyFrame(kind)
    function f:RegisterEvent() end
    function f:SetScript(n, fn) if n == "OnEvent" then _G.evHandler = fn end end
    return f
end

SlashCmdList = {}
C_AddOns = { LoadAddOn = function() return true end }
printed = {}

local ns = { rules = {}, folders = {}, settingsTestHooks = { keepOld = true } }   -- (P5) XayaUI Rules' data stays in CueRulesDB here, as before P5 (Modules.lua: a declared store opens as "old")
XayaUI_NS = ns
function ns.Print(...) local t = {} for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end printed[#printed + 1] = table.concat(t, " ") end
function ns.FolderById(id) for _, f in ipairs(ns.folders) do if f.id == id then return f end end end
function ns.Ignored(s) return s == nil or s == "" or s == "none" or s == "any" end
function ns.CooldownUsed(r) return r.useCooldown == true or (tonumber(r.spellID) or 0) ~= 0 or not ns.Ignored(r.cdState) end
function ns.ConditionsOf(p) local out = {} for _, r in ipairs(ns.rules) do if r.parentUid == p.uid and not r.isCue then out[#out + 1] = r end end return out end
ns.runtime = setmetatable({}, { __mode = "k" })
HOSTS = {}
ns.PaintDisplayArt = function(tex, rule) NS_PAINT(tex, rule) end
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
Enum = { AddOnProfilerMetric = { RecentAverageTime = 1 }, StatusBarTimerDirection = { ElapsedTime = 0, RemainingTime = 1 } }
PAINTED = {}
function NS_PAINT(tex, rule) PAINTED[#PAINTED + 1] = { tex = tex, rule = rule } end
profilerMs = 0.2
-- the game's meter knows only addons that exist: since 0.6.0 the engine is part of XayaUI, so "XayaUI_CombatEngine" reads nothing
C_AddOnProfiler = { GetAddOnMetric = function(name, metric) assert(metric == 1); if name == "XayaUI" then return profilerMs end if name == "Blizzard_AuraContainer" then return blizzMs or 0 end end }
_G.NS = ns
assert(loadstring(CUE_GATED_SRC))()   -- the real ns.CueGated from Cues.lua (which cues a condition decides), not a copy
assert(loadfile(MODULES_PATH))("XayaUI", ns)   -- (core 0.6.75) the settings seam the engine reads its saved data through
local f = assert(loadfile(AURA_DISPLAY_PATH))
f("XayaUI_CombatEngine", ns)
'''.replace("AURA_DISPLAY_PATH", repr(os.path.join(ROOT, "XayaUI_Rules", "Combat", "AuraDisplay.lua")).replace("'", '"')).replace("MODULES_PATH", repr(os.path.join(ROOT, "XayaUI", "Modules.lua")).replace("'", '"')).replace("CUE_GATED_SRC", CUE_GATED_LUA))


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
L.execute("""
function MG(i) local g = NS.AuraDisplay._groups.fA; return g.frame.groups[g.memberKey[i]] end   -- member i's own aura group
function SG() local g = NS.AuraDisplay._groups.fA; return g.mainKey and g.frame.groups[g.mainKey] end   -- the shared group (game sorts)
function NKEYS() return NS.AuraDisplay._groups.fA.nKeys end
""")
check("dynamic group drawn by one container (members incl. a static sub-group's rule)", lua("local g = NS.AuraDisplay._groups.fA; return g.ok and #g.memberKey == 3 and MG(1) and MG(2) and MG(3) and g.mainKey == nil"))
# Manual sort (default: rule order): one aura group per member, only that member's IDs, numbered in rule order (Xaya's table)
check("manual: member 1 = a1 (9001) only, layoutIndex 1, one icon", lua("local s = MG(1).filters.includeSpellIDs; return s[9001] and not s[9002] and MG(1).layout.layoutIndex == 1 and MG(1).max == 1"))
check("manual: member 2 = a2 with its extra ID (9002, 9102), layoutIndex 2", lua("local s = MG(2).filters.includeSpellIDs; return s[9002] and s[9102] and not s[9001] and MG(2).layout.layoutIndex == 2"))
check("manual: member 3 = the static sub-group's rule (9050), layoutIndex 3; the disabled rule (9003) is in no group", lua("return MG(3).filters.includeSpellIDs[9050] and MG(3).layout.layoutIndex == 3 and not MG(1).filters.includeSpellIDs[9003] and not MG(2).filters.includeSpellIDs[9003] and not MG(3).filters.includeSpellIDs[9003]"))
check("manual: members are one spacing apart (elementSpacing = spacing, groupSpacing 0: Blizzard's flow adds both, so 0.6.6's groupSpacing = spacing gave 2x)", lua("return MG(1).layout.elementSpacing == 5 and MG(2).layout.elementSpacing == 5 and MG(1).layout.groupSpacing == 0 and MG(2).layout.groupSpacing == 0 and MG(1).layout.lineSpacing == 5"))
check("parent and cue of a group member are engine-owned", own("A1") and own("A1c") and own("AS"))
check("static-group rule gets its own slot", lua("local s = NS.AuraDisplay._singles[S1]; return s and s.ok and s.frame.groups.main.max == 1 and s.frame.unit == 'player'") and own("S1c"))
check("ungrouped rule gets its own slot (the tester's Anti-Magic Shell case)", lua("local s = NS.AuraDisplay._singles[U1]; return s and s.ok") and own("U1") and own("U1c"))
check("a rule's own display (no cue) gets a slot sized like it", lua("local s = NS.AuraDisplay._singles[OWN]; return s and s.ok and s.frame.groups.main.layout.elementWidth == 40"))
check("your target debuff gets a target slot with your debuffs only", lua("local s = NS.AuraDisplay._singles[TD]; return s and s.ok and s.frame.unit == 'target' and s.frame.groups.main.filter == 'HARMFUL|PLAYER' and s.frame.groups.main.filters.includeSpellIDs[204598]"))
check("'missing' rule stays with XayaUI (would be drawn backwards)", not own("M1"))
check("rule that also needs a cooldown state stays with XayaUI", not own("CD1"))
check("centred dynamic group is drawn by the engine (container pinned by its top middle on the group's centre)", lua("local g = NS.AuraDisplay._groups.fC; local p = g and g.frame and g.frame._points[#g.frame._points]; return g.ok and p and p[1] == 'TOP' and p[3] == 'CENTER' and p[4] == 0 and p[5] == 0") and own("C1"))
check("centred group: rows flow left to right from the container's top left, wrapping down", lua("local f = NS.AuraDisplay._groups.fC.frame.flow; return f.axis == 0 and f.anchor == 'TOPLEFT' and f.h == 1 and f.v == -1"))
check("target debuff inside a dynamic group stays with XayaUI", not own("TDG"))
check("disabled rule not drawn", not own("A3"))
L.execute('LEFT = {}; for _, e in ipairs(NS.AuraDisplay._Left()) do LEFT[e[1].name] = e[2] end')
check("every kept display has a reason", lua("return LEFT['m1 missing'] ~= nil and LEFT['cd1 also cooldown'] ~= nil and LEFT['tdg debuff in group'] ~= nil"))
check("a centred group's rule is not kept back any more", lua("return LEFT['c1 centred'] == nil"))
check("a cooldown-only display is not listed as kept (not an aura display)", lua("return LEFT['cooldown only'] == nil"))
check("rules were never modified", lua("for i, r in ipairs(NS.rules) do local c = 0; for _ in pairs(r) do c = c + 1 end; if c ~= SNAP[i] then return false end end return true"))

# 1b. wrap options (items per row / column, which way extra rows go): flow settings handed to Blizzard's container
def flow(): return lua("local f = NS.AuraDisplay._groups.fA.frame.flow; return f.axis .. '|' .. f.anchor .. '|' .. f.h .. '|' .. f.v .. '|' .. tostring(f.max)")
base = flow()
check("default wrap: container width limit, rows go down (TOPLEFT, right, down)", base == "0|TOPLEFT|1|-1|100", base)
lua("for _, f in ipairs(NS.folders) do if f.id == 'fA' then f.cWrapN = 2 end end; NS.AuraDisplay.Build()")
check("items per row 2: limit = 2 icons + 1 gap (65.5) beats the container width", flow() == "0|TOPLEFT|1|-1|65.5", flow())
lua("for _, f in ipairs(NS.folders) do if f.id == 'fA' then f.cWrapN = 5 end end; NS.AuraDisplay.Build()")
check("items per row 5: container width (100) is the shorter limit", flow() == "0|TOPLEFT|1|-1|100", flow())
lua("for _, f in ipairs(NS.folders) do if f.id == 'fA' then f.cWrapN = 3; f.cW = 0; f.cWrapRev = true end end; NS.AuraDisplay.Build()")
check("rows go up: BOTTOMLEFT anchor, grows right and up, 3 per row (100.5)", flow() == "0|BOTTOMLEFT|1|1|100.5", flow())
for g, rev, want in (("LEFT", False, "0|TOPRIGHT|-1|-1"), ("LEFT", True, "0|BOTTOMRIGHT|-1|1"), ("DOWN", False, "1|TOPLEFT|1|-1"), ("DOWN", True, "1|TOPRIGHT|-1|-1"),
                     ("UP", False, "1|BOTTOMLEFT|1|1"), ("UP", True, "1|BOTTOMRIGHT|-1|1")):
    lua("for _, f in ipairs(NS.folders) do if f.id == 'fA' then f.cGrowth = '%s'; f.cWrapRev = %s end end; NS.AuraDisplay.Build()" % (g, "true" if rev else "nil"))
    got = flow().rsplit("|", 1)[0]
    check("growth %s, %s: flow %s" % (g, "extra on the other side" if rev else "default side", want), got == want, got)
lua("for _, f in ipairs(NS.folders) do if f.id == 'fA' then f.cGrowth = 'RIGHT'; f.cWrapN = nil; f.cWrapRev = nil; f.cW = 100 end end; NS.AuraDisplay.Build()")
check("back to default", flow() == base, flow())

# 2. placement of a single slot: on XayaUI's own icon, same parent, same strata
check("single slot sits on XayaUI's icon (TOPLEFT at icon centre - half size)", lua("local s = NS.AuraDisplay._singles[S1]; local p = s.frame._points[#s.frame._points]; return p[1] == 'TOPLEFT' and p[2] == HOSTS[S1c] and p[3] == 'CENTER' and p[4] == -15 and p[5] == 15 and s.frame.parent == HOSTS[S1c].parent and s.frame.strata == 'MEDIUM'"))
check("group container created as AuraContainer widgets only (stub asserts it)", lua("return #containers >= 5"))

# 3. load / talent settings followed live for 'condition' displays
lua('NS.runtime[U1] = { info = { ctxOK = false } }; NS.AuraDisplay.SyncLive()')
check("not loaded -> its slot hides", lua("return NS.AuraDisplay._singles[U1].frame.shown == false"))
lua('NS.runtime[U1] = { info = { ctxOK = true, talentOK = true } }; NS.AuraDisplay.SyncLive()')
check("loaded again -> shown", lua("return NS.AuraDisplay._singles[U1].frame.shown == true"))
lua('NS.runtime[A2] = { info = { ctxOK = false } }; NS.AuraDisplay.SyncLive()')
check("group member not loaded -> its own aura group is switched off, the others stay on", lua("return MG(2).enabled == false and MG(1).enabled == true and MG(3).enabled == true"))
lua('NS.runtime[A2] = nil; NS.AuraDisplay.SyncLive()')
check("and back on when loaded", lua("return MG(2).enabled == true"))
lua('local f = NS.AuraDisplay._groups.fA.frame; BEFORE = f.enabledCalls; NS.AuraDisplay.SyncLive(); NS.AuraDisplay.SyncLive()')
check("no group switch when nothing changed", lua("return NS.AuraDisplay._groups.fA.frame.enabledCalls == BEFORE"))

# 3b. Sort (Xaya 2026-11-04: Default, Expiration, Name, Important, Manual; plus Reverse). The group keeps ONE container for the
# session (Blizzard: aura groups are add-only); the game's sorts use one shared group with Blizzard's comparator, and switching
# only turns groups on and off.
def fa(field, value): lua("for _, f in ipairs(NS.folders) do if f.id == 'fA' then f.%s = %s end end; NS.AuraDisplay.Build()" % (field, value))
lua("OLDFRAME = NS.AuraDisplay._groups.fA.frame; K0 = NKEYS(); OLDM1 = MG(1)")
for key, method in (("default", 0), ("expiration", 4), ("name", 6), ("important", 3)):
    fa("cSort", repr(key).replace("'", '"'))
    check("sort %s: the shared group, Blizzard's %s comparator, every member's IDs, member groups off" % (key, method),
          lua("local m = SG(); local s = m and m.filters.includeSpellIDs; return m and m.enabled and m.sort == %d and m.dir == 0 and s[9001] and s[9002] and s[9102] and s[9050] and OLDM1.enabled == false" % method))
check("switching sorts kept the same container and made only one shared group", lua("return NS.AuraDisplay._groups.fA.frame == OLDFRAME and NKEYS() == K0 + 1"))
fa("cSortRev", "true")
check("reverse: Blizzard's Reverse direction", lua("return SG().dir == 1"))
fa("cSortRev", "nil")
fa("cSort", '"desc"')
check("older save 'Name, Z to A' reads as Name, reversed", lua("return SG().sort == 6 and SG().dir == 1"))
fa("cSort", '"asc"')
check("older save 'Name, A to Z' reads as Name", lua("return SG().sort == 6 and SG().dir == 0"))
lua("SHARED = SG()")
fa("cSort", "nil")
check("back to Manual: the same member groups on again, the shared group off, nothing new made", lua("return MG(1) == OLDM1 and OLDM1.enabled == true and SHARED.enabled == false and NKEYS() == K0 + 1 and NS.AuraDisplay._groups.fA.frame == OLDFRAME"))
fa("cSortRev", "true")
check("manual reversed: last rule gets number 1", lua("return MG(3).layout.layoutIndex == 1 and MG(1).layout.layoutIndex == 3"))
fa("cSortRev", "nil")
# each member keeps its own size (a game sort draws them all at member 1's size); a look change makes that member a new group
lua("OLDM2 = MG(2); A2c.visual.w = 44; A2c.visual.h = 44; NS.AuraDisplay.Build()")
check("manual: each member its own icon size (a2 at 44, a1 at 30)", lua("return MG(2).layout.elementWidth == 44 and MG(1).layout.elementWidth == 30"))
check("a2's look changed: a new group for a2 only, its old one switched off", lua("return MG(2) ~= OLDM2 and OLDM2.enabled == false and MG(1) == OLDM1 and NKEYS() == K0 + 2"))
lua("A2c.visual.w = 30; A2c.visual.h = 30; NS.AuraDisplay.Build()")
check("a2's old look back: its first group is reused", lua("return MG(2) == OLDM2 and NKEYS() == K0 + 2"))
# reorder the rules (drag / arrows change the list order): only the numbers change
lua("""
local i1, i2
for i, r in ipairs(NS.rules) do if r == A1 then i1 = i elseif r == A2 then i2 = i end end
NS.rules[i1], NS.rules[i2] = NS.rules[i2], NS.rules[i1]
NS.AuraDisplay.Build()
""")
check("reordered rules: a2's group is number 1, a1's number 2, same groups and container", lua("return MG(1) == OLDM2 and MG(2) == OLDM1 and OLDM2.layout.layoutIndex == 1 and OLDM1.layout.layoutIndex == 2 and NKEYS() == K0 + 2 and NS.AuraDisplay._groups.fA.frame == OLDFRAME"))
lua("""
local i1, i2
for i, r in ipairs(NS.rules) do if r == A1 then i1 = i elseif r == A2 then i2 = i end end
NS.rules[i1], NS.rules[i2] = NS.rules[i2], NS.rules[i1]
NS.AuraDisplay.Build()
""")
check("order restored", lua("return MG(1) == OLDM1 and OLDM1.layout.layoutIndex == 1"))

# 4. unlock
lua('NS.unlocked = true; NS.AuraDisplay.SyncLive()')
check("everything unlocked: engine steps aside", lua("return NS.AuraDisplay._groups.fA.frame.shown == false and NS.AuraDisplay._singles[S1].frame.shown == false"))
lua('NS.unlocked = false; NS.moveUnlocked[S1c] = true; NS.AuraDisplay.SyncLive()')
check("one display unlocked: only its slot steps aside", lua("return NS.AuraDisplay._singles[S1].frame.shown == false and NS.AuraDisplay._singles[U1].frame.shown == true"))
lua('NS.moveUnlocked[S1c] = nil; NS.groupUnlocked.fA = true; NS.AuraDisplay.SyncLive()')
check("group unlocked: its container steps aside", lua("return NS.AuraDisplay._groups.fA.frame.shown == false"))
lua('NS.groupUnlocked.fA = nil; NS.AuraDisplay.SyncLive()')
check("locked again: all back", lua("return NS.AuraDisplay._groups.fA.frame.shown == true and NS.AuraDisplay._singles[S1].frame.shown == true"))

# 5. (SD-47, round 5: changed from "keep a group with XayaUI, and back") the engine has no per-group off switch: a saved
# groups[id] = false from an older version (found by name through the engine's own D.FindFolder) is ignored and cleared
lua('local D = NS.AuraDisplay; CueRulesDB.engineDisplay.groups = { [assert(D.FindFolder("static group")).id] = false }; D.Build()')
check("a group kept with XayaUI by an older version (saved groups[id] = false): still drawn by the engine, the saved choice cleared (SD-47)",
      own("S1") and lua("return CueRulesDB.engineDisplay.groups == nil"))

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

# 8. guard: lean first, then off; both for this session only (0.6.13)
G = "local g = NS.AuraDisplay._guard; local e = CueRulesDB.engineDisplay; "
lua('profilerMs = 5.0; blizzMs = 0.1; for i = 1, 3 do NS.AuraDisplay.GuardCheck() end')
check("guard: XayaUI's own total (rules, sounds, settings) is shown, never trips the engine", lua(G + "return not g.lean and not g.off and g.own == 5.0 and e.auto == nil"))
lua('blizzMs = 1.2; NS.AuraDisplay.GuardCheck(); NS.AuraDisplay.GuardCheck(); blizzMs = 0.1; NS.AuraDisplay.GuardCheck()')
check("guard: reads Blizzard's container cost (where the containers' work is counted), and a low reading resets it", lua(G + "return not g.lean and g.last == 0.1"))
lua('profilerMs = 0.1; blizzMs = 1.2; for i = 1, 3 do NS.AuraDisplay.GuardCheck() end')
check("guard stage 1: lean mode (spec being played only)", lua(G + "return g.lean == true and e.auto == nil") and not own("SPEC") and own("U1"))
check("guard stage 1 is not saved (a /reload starts clean)", lua(G + "return e.lean == nil"))
check("guard stage 1 counts the displays lean mode handed back (the evidence stage 2 needs)", lua(G + "return g.leanAt == 1.2 and (g.leanHanded or 0) >= 1"))
# 0.6.69 (externals): the meter also counts Blizzard's own buff / target frames and group headers. A reading that does not fall after
# lean mode handed displays back is not XayaUI's, so drawing stays on (switching off would hide every aura the game hides in combat).
lua('printed = {}; for i = 1, 3 do NS.AuraDisplay.GuardCheck() end')
check("guard stage 2, cost not lowered by lean mode: drawing stays ON (kept), said in chat, still lean", lua(G + "return not g.off and g.kept == true and g.lean == true and #e.guardTrips == 2 and e.guardTrips[2].step == 'kept' and printed[1]:find('game.s own frames') ~= nil") and own("U1") and own("A1"))
lua('printed = {}; blizzMs = 5.0; for i = 1, 6 do NS.AuraDisplay.GuardCheck() end')
check("guard: once kept, it does not step again this session", lua(G + "return not g.off and #e.guardTrips == 2 and #printed == 0") and own("U1"))
# the reading fell by at least a fifth after lean mode (XayaUI's containers are the cost) but is still high: off, as before
lua('NS.AuraDisplay._guard.kept = nil; NS.AuraDisplay._guard.leanAt = 2.0; blizzMs = 1.5; printed = {}; for i = 1, 3 do NS.AuraDisplay.GuardCheck() end')
check("guard stage 2: lean mode lowered the cost but not enough: engine drawing off for the session, all back to XayaUI, said in chat", lua(G + "return g.off == true and #e.guardTrips == 3 and e.guardTrips[3].step == 'off' and printed[1]:find('performance guard') ~= nil") and not own("U1") and not own("A1"))
check("guard stage 2 is not saved (no saved switch at all, SD-47)", lua(G + "return e.auto == nil and e.guardTrips[3].session == true"))
# a /reload is the way back (the guard's state is this session's only): a new session starts with a clean guard and the saved setting on
lua('profilerMs = 0.1; blizzMs = 0; local g = NS.AuraDisplay._guard; for _, k in ipairs({ "lean", "off", "kept", "leanAt", "leanHanded", "last", "own" }) do g[k] = nil end; g.bad = 0; NS.AuraDisplay.Build()')
check("after a /reload (clean guard): everything back, lean mode gone", lua(G + "return e.auto == nil and not g.lean and not g.off") and own("U1") and own("SPEC"))
# a trip saved by an older version is cleared; (SD-47, round 5: changed from "a player's own auto off is kept") so is a saved
# "auto off" with no guard trip behind it: the engine has no saved off switch
lua('SAVED = CueRulesDB.engineDisplay; CueRulesDB.engineDisplay = { auto = false, lean = true, groups = {}, guardTrips = { { at = "t1", step = "lean" }, { at = "t2", step = "off" } } }; NS.AuraDisplay.Build()')
check("old saved guard trip (lean + off) is cleared", lua("local e = CueRulesDB.engineDisplay; return e.auto == nil and e.lean == nil and #e.guardTrips == 2") and own("U1") and own("SPEC"))
lua('CueRulesDB.engineDisplay = { auto = false, groups = {}, guardTrips = { { at = "t1", step = "lean" } } }; NS.AuraDisplay.Build()')
check("a player's own auto off from an older version is ignored and cleared (SD-47)", lua("local e = CueRulesDB.engineDisplay; return e.auto == nil and e.guardUndone == nil") and own("U1"))
lua('CueRulesDB.engineDisplay = SAVED; NS.AuraDisplay.Build()')

# 9. a container that fails hands its displays back
lua('failAdd = true; for k, s in pairs(NS.AuraDisplay._singles) do s.frame = nil end; for k, g in pairs(NS.AuraDisplay._groups) do g.frame = nil end; NS.AuraDisplay.Build()')
check("container error: nothing engine-owned, failures listed", (not own("U1")) and (not own("A1")) and lua("for _, e in ipairs(NS.AuraDisplay._Left()) do if e[2]:find('failed') then return true end end return false"))
lua('failAdd = false')

# 9b. the tester's exact display: Anti-Magic Shell as a progress texture (drain), background, half opacity, time text off
lua(r"""
INS = { uid = "ins", name = "Anti-Magic Shell", useBuff = true, buffID = 48707, buffState = "present", enabled = true, load = { mode = "always" }, visual = { enabled = false } }
INSc = { uid = "insc", name = "Anti-Magic Shell (cue)", isCue = true, parentUid = "ins", cueKey = "q1", cueKind = "texture", buffID = 48707, enabled = true,
  visual = { enabled = true, trigger = "condition", kind = "spellicon", w = 94, h = 128, x = 0, y = -28, alpha = 0.5,
    bg = { enabled = true, color = { 0, 0, 0, 0.5 } }, fill = { enabled = true, min = 0, max = 1, reverse = false },
    flash = { enabled = true, threshold = 3 }, text = { enabled = false }, count = { enabled = false } } }
NS.rules[#NS.rules + 1] = INS; NS.rules[#NS.rules + 1] = INSc
buttons = {}; PAINTED = {}
NS.AuraDisplay.Build()
""")
check("tester's Anti-Magic Shell: its own slot, 94 x 128", lua("local s = NS.AuraDisplay._singles[INS]; return s and s.ok and s.frame.groups.main.layout.elementWidth == 94 and s.frame.groups.main.layout.elementHeight == 128") and own("INS") and own("INSc"))
lua("local s = NS.AuraDisplay._singles[INS]; for _, b in ipairs(buttons) do if b.log.bar then INSB = b end end")
check("the drain is a duration bar the game drives: vertical, emptying with the REMAINING time", lua("return INSB ~= nil and INSB.log.bar.orient == 'VERTICAL' and INSB.log.bar.reverse == false and INSB.log.barOpts.direction == 1"))
check("the bar is painted with the display's own art (XayaUI's art routine), not the aura icon", lua("for _, p in ipairs(PAINTED) do if p.tex == INSB.log.bar.tex and p.rule == INSc then return INSB.log.icon == nil end end return false"))
check("half opacity and the background kept; no time text (it is off on his display)", lua("return INSB.alpha == 0.5 and INSB.log.dur == nil"))
lua('printed = {}; SlashCmdList["XUIENGINE"]("")')
check("status: the drain is NOT listed as missing for a single slot; the flash is", lua("local drain, flash = false, false; for _, l in ipairs(printed) do if l:find('Anti%-Magic Shell') then if l:find('drain') then drain = true end if l:find('flash') then flash = true end end end return flash and not drain"))
lua("INSc.visual.fill.dir = 'right'; INSc.visual.fill.reverse = true; buttons = {}; NS.AuraDisplay.Build(); for _, b in ipairs(buttons) do if b.log.bar then INSB = b end end")
check("an edited look makes a new slot: 'right' + reverse -> horizontal, reversed, growing with elapsed time", lua("return INSB.log.bar.orient == 'HORIZONTAL' and INSB.log.bar.reverse == true and INSB.log.barOpts.direction == 0"))

# 9c. #347 (tester, 2026-11-03): Anti-Magic Shell with an Icon cue AND a separate Text cue (duration + shield amount). The single slot
# draws the icon; the Text cue must stay with XayaUI (it was owned and hidden, so the texts vanished in game while the preview showed them).
lua(r"""
TX = { uid = "tx", name = "AMS two cues", useBuff = true, buffID = 48707, buffState = "present", enabled = true, load = { mode = "all" }, visual = { enabled = false } }
TXi = { uid = "txi", name = "AMS icon cue", isCue = true, parentUid = "tx", cueKey = "q1", cueKind = "icon", enabled = true,
  visual = { enabled = true, trigger = "condition", kind = "spellicon", w = 128, h = 128, alpha = 0.25, fill = { enabled = true, min = 0, max = 1 }, text = { enabled = false }, count = { enabled = false } } }
TXt = { uid = "txt", name = "AMS text cue", isCue = true, parentUid = "tx", cueKey = "q2", cueKind = "text", enabled = true,
  visual = { enabled = true, trigger = "condition", w = 128, h = 128, text = { enabled = true, size = 20 }, absorb = { enabled = true, source = "aura" }, count = { enabled = false } } }
TXs = { uid = "txs", name = "AMS sound cue", isCue = true, parentUid = "tx", cueKey = "q3", cueKind = "sound", enabled = true, visual = { enabled = false } }
NS.rules[#NS.rules + 1] = TX; NS.rules[#NS.rules + 1] = TXi; NS.rules[#NS.rules + 1] = TXt; NS.rules[#NS.rules + 1] = TXs
-- the same shape inside the dynamic group fA
GX = { uid = "gx", name = "group two cues", folder = "fA", useBuff = true, buffID = 9011, buffState = "present", enabled = true, visual = { enabled = false } }
GXi = { uid = "gxi", name = "group icon cue", folder = "fA", isCue = true, parentUid = "gx", cueKey = "q1", cueKind = "icon", enabled = true, visual = { enabled = true, trigger = "condition", w = 30, h = 30, text = { enabled = false }, count = { enabled = false } } }
GXt = { uid = "gxt", name = "group text cue", folder = "fA", isCue = true, parentUid = "gx", cueKey = "q2", cueKind = "text", enabled = true, visual = { enabled = true, trigger = "condition", w = 30, h = 30, text = { enabled = true }, count = { enabled = false } } }
NS.rules[#NS.rules + 1] = GX; NS.rules[#NS.rules + 1] = GXi; NS.rules[#NS.rules + 1] = GXt
NS.AuraDisplay.Build()
""")
check("#347: the single slot draws the icon cue (rule and icon cue engine-owned)", lua("local s = NS.AuraDisplay._singles[TX]; return s and s.ok and s.spec.display == TXi") and own("TX") and own("TXi"))
check("#347 (0.6.3): the separate Text cue gets its own slot, so its duration is exact in combat too", own("TXt") and lua("local x = NS.AuraDisplay._extras[TXt]; return x and x.ok and x.spec.display == TXt and x.frame.unit == 'player' and x.frame.groups.main.filters.includeSpellIDs[48707] == true"))
check("#347 (0.6.3): its shield amount (the container cannot draw it) is XayaUI's companion text", lua("return NS.EngineCompanion(TXt) == true and NS.EngineCompanion(TXi) == false and NS.EngineCompanion(TX) == false"))
check("#347: a cue without a display (sound) is still owned as before", own("TXs"))
check("#347: inside a dynamic group the extra display cue stays hidden (XayaUI's layout would misplace it)", own("GXi") and own("GXt"))
lua('printed = {}; SlashCmdList["XUIENGINE"]("")')
check("#347: /xuiengine says the group rule's text cue is hidden", lua("for _, l in ipairs(printed) do if l:find('group two cues', 1, true) and l:find('other display cue', 1, true) then return true end end return false"))

# 11. a new target / focus: Blizzard's container does not refresh by itself (its own target frame calls UpdateAllAuras on
# PLAYER_TARGET_CHANGED); without the call a "Target Debuff (yours)" slot kept the previous target's debuff
lua(r"""
TDF = { uid = "tdf", name = "focus debuff", enabled = true, extra = { list = { { type = "targetDebuff", spellID = 204600, unit = "focus", state = "yes" } } }, visual = { enabled = true, trigger = "condition", w = 30, h = 30 } }
NS.rules[#NS.rules + 1] = TDF
NS.AuraDisplay.Build()
TU0 = FULL[NS.AuraDisplay._singles[TD].frame] or 0; FU0 = FULL[NS.AuraDisplay._singles[TDF].frame] or 0; PU0 = FULL[NS.AuraDisplay._singles[U1].frame] or 0
evHandler(nil, "PLAYER_TARGET_CHANGED")
""")
check("target changed: the target debuff slot refreshes at once", lua("return (FULL[NS.AuraDisplay._singles[TD].frame] or 0) == TU0 + 1"))
check("target changed: focus and player slots are left alone", lua("return (FULL[NS.AuraDisplay._singles[TDF].frame] or 0) == FU0 and (FULL[NS.AuraDisplay._singles[U1].frame] or 0) == PU0"))
lua('evHandler(nil, "PLAYER_FOCUS_CHANGED")')
check("focus changed: the focus debuff slot refreshes", lua("return (FULL[NS.AuraDisplay._singles[TDF].frame] or 0) == FU0 + 1"))
check("a target change does not rebuild anything (no Build in combat needed)", lua("return NS.AuraDisplay._singles[TD].ok == true"))

# 12. texts: shown only when switched on (like XayaUI), styled by XayaUI's own text routine, a blank anchor never breaks a slot
lua(r"""
STYLED = {}
NS.StyleText = function(fs, parent, t, default)
  if t.anchor == "" then error("SetPoint: invalid point ''") end   -- what the game does with a blank point name
  STYLED[#STYLED + 1] = { fs = fs, parent = parent, t = t, default = default }
end
FMT = { name = "XayaUI time format" }
NS.TimeFormatter = function(decimals, below) return FMT end
function newRule(uid, vis, extra)
  local r = { uid = uid, name = uid, useBuff = true, buffID = 9900 + #NS.rules, buffState = "present", enabled = true, visual = vis }
  for k, v in pairs(extra or {}) do r[k] = v end
  NS.rules[#NS.rules + 1] = r
  return r
end
TXOFF = newRule("text unset", { enabled = true, trigger = "buffActive", w = 30, h = 30, text = {}, count = {} })
TXON = newRule("text on", { enabled = true, trigger = "buffActive", w = 30, h = 30, text = { enabled = true, size = 22, font = "lato", color = { 1, 0, 0, 1 }, anchor = "TOP", place = "outer" }, count = { enabled = true, size = 9 } })
TXBL = newRule("blank anchor", { enabled = true, trigger = "buffActive", w = 30, h = 30, text = { enabled = true, anchor = "" }, count = { enabled = false } })
buttons = {}
NS.AuraDisplay.Build()
function BTN(r) local s = NS.AuraDisplay._singles[r]; for _, b in ipairs(buttons) do if b.log.owner == s then return b end end end
""")
# (buttons are matched to slots by the order they were created in)
lua(r"""
BY = {}
for _, b in ipairs(buttons) do BY[#BY + 1] = b end
function LAST_WITH(pred) for i = #BY, 1, -1 do if pred(BY[i]) then return BY[i] end end end
""")
check("text and count left unset (not switched on): the engine draws neither (XayaUI does not either)", lua("return NS.AuraDisplay._singles[TXOFF].ok and (function() for _, b in ipairs(BY) do if b.log.dur or b.log.count then for _, st in ipairs(STYLED) do if st.fs == b.log.dur and st.t == TXOFF.visual.text then return false end end end end return true end)()"))
check("duration text styled by XayaUI's own routine with the display's settings (font, size, colour, outer place)", lua("for _, st in ipairs(STYLED) do if st.t == TXON.visual.text and st.default == 'CENTER' then return true end end return false"))
check("stack count styled the same way (default corner bottom right)", lua("for _, st in ipairs(STYLED) do if st.t == TXON.visual.count and st.default == 'BOTTOMRIGHT' then return true end end return false"))
check("a blank text anchor no longer breaks the slot (it failed and the display fell back to XayaUI)", lua("return NS.AuraDisplay._singles[TXBL].ok == true") and own("TXBL"))
check("time text uses XayaUI's format (the game formatter is handed to the container)", lua("local b = LAST_WITH(function(b) return b.log.durOpts and b.log.durOpts.textFormatter == FMT end); return b ~= nil and not NS.AuraDisplay._singles[TXON].fmtFallback"))

# 13. the container refuses the formatter: the game's own format, said by /xuiengine; the slot still works
lua('REJECT_FORMATTER = true; TXON.visual.text.size = 23; buttons = {}; NS.AuraDisplay.Build()')
check("formatter refused: slot still drawn, game's own time format", lua("return NS.AuraDisplay._singles[TXON].ok == true and NS.AuraDisplay._singles[TXON].fmtFallback == true"))
lua('printed = {}; SlashCmdList["XUIENGINE"]("")')
check("/xuiengine says the time text uses the game's own format", lua("for _, l in ipairs(printed) do if l:find('text on', 1, true) and l:find(\"game's own format\", 1, true) then return true end end return false"))
lua('REJECT_FORMATTER = nil')

# 14. a count set to show spell CHARGES: the container counts aura stacks, so it is not handed the count; XayaUI's companion draws it
lua(r"""
CHG = newRule("charges count", { enabled = true, trigger = "buffActive", w = 30, h = 30, text = { enabled = false }, count = { enabled = true, source = "charges" } })
NS.Val = function(v) if v == nil or v == "" or v == "none" then return nil end return v end
buttons = {}; NS.AuraDisplay.Build()
""")
check("charges count: not handed to the container (it would show aura stacks)", lua("for _, b in ipairs(buttons) do if b.log.count then return false end end return true"))
check("charges count: drawn by XayaUI's companion over the engine's icon", lua("return NS.EngineOwns(CHG) and NS.EngineCompanion(CHG) == true"))

lua('GA, GAc = P("group absorb", "fA", 9020); GAc.visual.absorb = { enabled = true }; NS.AuraDisplay.Build(); printed = {}; SlashCmdList["XUIENGINE"]("")')
check("inside a group: the shield amount is listed by /xuiengine as not drawn (no companion for a group's icons)", lua("for _, l in ipairs(printed) do if l:find('group absorb', 1, true) and l:find('shield amount text', 1, true) then return true end end return false") and lua("return NS.EngineCompanion(GAc) == false"))

# 15. "only while on an action bar": followed by the engine too
lua('BAR = newRule("bar gated", { enabled = true, trigger = "buffActive", requireOnBar = true, w = 30, h = 30, text = {}, count = {} }); NS.AuraDisplay.Build()')
lua('NS.SpellOnActionBar = function(id) return false end; NS.AuraDisplay.SyncLive()')
check("spell not on an action bar: the engine's slot hides (XayaUI would hide it too)", lua("return NS.AuraDisplay._singles[BAR].frame.shown == false"))
lua('NS.SpellOnActionBar = function(id) return true end; NS.AuraDisplay.SyncLive()')
check("back on a bar: shown", lua("return NS.AuraDisplay._singles[BAR].frame.shown == true"))
lua('NS.SpellOnActionBar = nil')

# 16. which display the engine draws: only one XayaUI itself would show (a sound cue with a stale display switch is skipped)
lua(r"""
NS.KindHas = function(r, what) if r.isCue then return r.cueKind ~= "sound" and r.cueKind ~= "speech" and r.cueKind ~= "custom" end return true end
KH = newRule("kind check", { enabled = false })
KHs = { uid = "khs", name = "kh sound cue", isCue = true, parentUid = KH.uid, cueKey = "q1", cueKind = "sound", enabled = true, visual = { enabled = true, trigger = "condition", w = 10, h = 10 } }
KHi = { uid = "khi", name = "kh icon cue", isCue = true, parentUid = KH.uid, cueKey = "q2", cueKind = "icon", enabled = true, visual = { enabled = true, trigger = "condition", w = 44, h = 44, text = {}, count = {} } }
NS.rules[#NS.rules + 1] = KHs; NS.rules[#NS.rules + 1] = KHi
NS.AuraDisplay.Build()
""")
check("a sound cue's leftover display switch is ignored: the icon cue is drawn", lua("local s = NS.AuraDisplay._singles[KH]; return s and s.ok and s.spec.display == KHi and s.frame.groups.main.layout.elementWidth == 44"))

# 17. a rule whose only trigger is one "Buff / Aura (another)" row: drawn like the built-in Buff / Aura
lua(r"""
ROW = { uid = "row", name = "aura row only", enabled = true, extra = { list = { { type = "buffAura", spellID = 9777, alt = { 9779 }, state = "yes" } } }, visual = { enabled = true, trigger = "condition", w = 30, h = 30, text = {}, count = {} } }
ROWM = { uid = "rowm", name = "aura row missing", enabled = true, extra = { list = { { type = "buffAura", spellID = 9778, state = "no" } } }, visual = { enabled = true, trigger = "condition", w = 30, h = 30 } }
NS.rules[#NS.rules + 1] = ROW; NS.rules[#NS.rules + 1] = ROWM
NS.AuraDisplay.Build()
""")
check("lone aura row: its own slot on the player's buffs", lua("local s = NS.AuraDisplay._singles[ROW]; return s and s.ok and s.frame.unit == 'player' and s.frame.groups.main.filter == 'HELPFUL' and s.frame.groups.main.filters.includeSpellIDs[9777] == true"))
check("lone aura row: its extra aura IDs are shown too (0.6.13, gap 9: the icon stayed empty for a variant)", lua("local s = NS.AuraDisplay._singles[ROW]; return s and s.frame.groups.main.filters.includeSpellIDs[9779] == true"))
check("lone aura row set to MISSING stays with XayaUI, with its reason", not own("ROWM") and lua("for _, e in ipairs(NS.AuraDisplay._Left()) do if e[1] == ROWM and e[2]:find('MISSING') then return true end end return false"))

# 18. a rule WITH conditions switches its cues one by one: its separate Text cue stays with XayaUI (no extra slot)
lua(r"""
CX = { uid = "cx", name = "with condition", useBuff = true, buffID = 9811, buffState = "present", enabled = true, visual = { enabled = false } }
CXi = { uid = "cxi", name = "cx icon", isCue = true, parentUid = "cx", cueKey = "q1", cueKind = "icon", enabled = true, visual = { enabled = true, trigger = "condition", w = 30, h = 30, text = {}, count = {} } }
CXt = { uid = "cxt", name = "cx text", isCue = true, parentUid = "cx", cueKey = "q2", cueKind = "text", enabled = true, visual = { enabled = true, trigger = "condition", w = 30, h = 30, text = { enabled = true }, count = {} } }
CXu = { uid = "cxu", name = "cx unlisted text", isCue = true, parentUid = "cx", cueKey = "q3", cueKind = "text", enabled = true, visual = { enabled = true, trigger = "condition", w = 30, h = 30, text = { enabled = true }, count = {} } }
CXc = { uid = "cxc", name = "cx condition", parentUid = "cx", enabled = true, when = { list = {} }, thenCues = { "q2" } }
NS.rules[#NS.rules + 1] = CX; NS.rules[#NS.rules + 1] = CXi; NS.rules[#NS.rules + 1] = CXt; NS.rules[#NS.rules + 1] = CXu; NS.rules[#NS.rules + 1] = CXc
NS.AuraDisplay.Build()
""")
check("rule with conditions: icon drawn by the engine, the condition-switched Text cue stays with XayaUI", own("CXi") and not own("CXt") and lua("return NS.AuraDisplay._extras[CXt] == nil or NS.AuraDisplay._extras[CXt].ok == false"))
check("rule with conditions: a Text cue no condition lists follows the trigger, so it gets its own exact slot (0.6.14)", own("CXu") and lua("return NS.AuraDisplay._extras[CXu] ~= nil and NS.AuraDisplay._extras[CXu].ok == true"))
lua('CXc.enabled = false; NS.AuraDisplay.Build()')
check("its condition switched off: the Text cue it lists stays with XayaUI (silent, as the condition's On switch says)", not own("CXt"))
lua('CXc.enabled = true; NS.AuraDisplay.Build()')
lua('printed = {}; SlashCmdList["XUIENGINE"]("")')
check("/xuiengine counts the separate time / stack displays it draws", lua("for _, l in ipairs(printed) do if l:find('^Engine draws:') and l:find('separate time / stack display', 1, true) then return true end end return false"))

# 19. #260 (core 0.6.19, Xaya: "If a condition is enabled it should be enforced in or out of combat"): an engine-drawn display that a
# condition lists shows only while that condition is true, and its changes (opacity, grey, tint) are drawn on the engine's slot
lua(r"""
GC = { uid = "gc", name = "gated", useBuff = true, buffID = 9901, buffState = "present", enabled = true, visual = { enabled = false } }
GCi = { uid = "gci", name = "gated icon", isCue = true, parentUid = "gc", cueKey = "q1", cueKind = "texture", enabled = true,
  visual = { enabled = true, trigger = "condition", w = 40, h = 40, alpha = 0.8, text = {}, count = {} } }
GCc = { uid = "gcc", name = "Condition 1", parentUid = "gc", enabled = true, when = { list = {} }, thenCues = { "q1" } }
NS.rules[#NS.rules + 1] = GC; NS.rules[#NS.rules + 1] = GCi; NS.rules[#NS.rules + 1] = GCc
NS.runtime[GCi] = { info = { result = false } }
NS.AuraDisplay.Build(); NS.AuraDisplay.SyncLive()
GS = NS.AuraDisplay._singles[GC]
""")
check("a display a condition lists is still drawn by the engine (exact time in combat)", own("GCi") and lua("return GS ~= nil and GS.ok == true"))
check("its condition is false: the engine's slot is hidden (before 0.6.19 it showed whenever the aura was up)", lua("return GS.frame.shown == false"))
lua('NS.runtime[GCi].info.result = true; NS.AuraDisplay.SyncLive()')
check("its condition is true: shown", lua("return GS.frame.shown == true"))
lua('NS.runtime[GCi].info = { result = nil }; NS.AuraDisplay.SyncLive()')
check("its condition unknown (e.g. stacks hidden in combat): hidden, never shown on a guess", lua("return GS.frame.shown == false"))
lua('NS.runtime[GCi].info = { result = true, mods = { alpha = 0.3, desat = true, tint = { 1, 0, 0, 1 } } }; NS.AuraDisplay.SyncLive()')
check("a true condition's changes are drawn on the slot: opacity 0.3",
      lua("if #(GS.btns or {}) == 0 then return false end; for _, b in ipairs(GS.btns) do if b.alpha ~= 0.3 then return false end end return true"))
check("... grey and red tint on the display's art",
      lua("if #(GS.arts or {}) == 0 then return false end; for _, a in ipairs(GS.arts) do if not (a.desat == 1 and a.vc and a.vc[1] == 1 and a.vc[2] == 0) then return false end end return true"))
lua('PAINTED = {}; NS.runtime[GCi].info = { result = true }; NS.AuraDisplay.SyncLive()')
check("the condition's changes end: the art is painted again from the display's own settings and the opacity is its own (0.8)",
      lua("local n = 0; for _, p in ipairs(PAINTED) do if p.rule == GCi then n = n + 1 end end; if n < #GS.arts then return false end; for _, b in ipairs(GS.btns) do if b.alpha ~= 0.8 then return false end end return true"))
lua('GCc.thenCues = nil; NS.runtime[GCi].info = { result = false }; NS.AuraDisplay.SyncLive()')
check("no condition lists the display: it follows the aura as before (shown whatever the cue's own reading)", lua("return GS.frame.shown == true"))
lua('GCc.thenCues = { "q1" }')

# 19. externals and raid defensives (core 0.6.69; Xaya 2026-11-07: "I turned EUI ones on because XUI isn't reliably performing").
# The game hides these auras from XayaUI's reading in combat, but its container may match spell IDs on the player's buffs
# (Blizzard_CustomAuraContainer.lua). (a) a buff learned in game under another ID (AuraAlias.lua: same name, seen out of combat) is in
# the include list too; (b) the status screens can ask who draws a rule's display, and why not.
_alias_path = repr(os.path.join(ROOT, "XayaUI_Rules", "AuraAlias.lua")).replace("'", '"')
L.execute(r'''local cf = CreateFrame; CreateFrame = nil; local f = assert(loadfile(PATH)); f("XayaUI", NS); CreateFrame = cf'''.replace("PATH", _alias_path))
lua(r"""
EXT, EXTc = P("Power Word: Barrier (cast ID)", nil, 62618)
EXTM = P("external MISSING", nil, 33206, { buffState = "missing" })
NS.Settings("core").auraAlias = { [62618] = { [81782] = true } }
NS.AuraDisplay.Build()
""")
check("externals: the buff learned under another ID (81782 for 62618) is in the container's include list",
      lua("local s = NS.AuraDisplay._singles[EXT]; local ids = s and s.frame.groups.main.filters.includeSpellIDs; return s and s.ok and ids[62618] == true and ids[81782] == true"))
check("externals: the rule itself is not changed by the alias (saved rule keeps its one ID)", lua("return EXT.buffAlt == nil and EXT.buffID == 62618"))
check("externals: OwnerOf names the container that draws a display", lua("local o, w = NS.AuraDisplay.OwnerOf(EXT); return o == true and w:find('slot') ~= nil"))
check("externals: OwnerOf a cue answers for its parent rule", lua("local o = NS.AuraDisplay.OwnerOf(EXTc); return o == true"))
check("externals: OwnerOf gives the reason a display stays with XayaUI", lua("local o, w = NS.AuraDisplay.OwnerOf(EXTM); return o == false and w:find('MISSING') ~= nil"))
check("externals: OwnerOf a cooldown-only display is nil (not an aura display)", lua("return NS.AuraDisplay.OwnerOf(CDONLY) == nil"))
# (SD-47, round 5: the engine's drawing is off only by the performance guard, for the session; no saved switch)
lua('NS.AuraDisplay._guard.off = true; NS.AuraDisplay.Build()')
check("externals: engine drawing off (performance guard): OwnerOf says so", lua("local o, w = NS.AuraDisplay.OwnerOf(EXT); return o == false and w:find('stopped drawing') ~= nil"))
lua('NS.AuraDisplay._guard.off = nil; NS.Settings("core").auraAlias = nil; NS.AuraDisplay.Build()')
check("externals: without a learned alias the include list is the rule's own ID only", lua("local ids = NS.AuraDisplay._singles[EXT].frame.groups.main.filters.includeSpellIDs; return ids[62618] and not ids[81782]"))

# 10. loaded twice (XayaUI loads the engine files and the separate XayaUI_CombatEngine folder is installed too): one copy only
lua('BEFORE_D = NS.AuraDisplay; BEFORE_SLASH = SlashCmdList["XUIENGINE"]')
L.execute(r'''local f = assert(loadfile(PATH)); f("XayaUI_CombatEngine", NS)'''.replace("PATH", repr(os.path.join(ROOT, "XayaUI_Rules", "Combat", "AuraDisplay.lua")).replace("'", '"')))
check("second copy steps aside (same module, same command, no second set of hooks)", lua("return NS.AuraDisplay == BEFORE_D and SlashCmdList['XUIENGINE'] == BEFORE_SLASH"))

print()
print("FAILED: " + ", ".join(fails) if fails else "ALL PASSED")
sys.exit(1 if fails else 0)
