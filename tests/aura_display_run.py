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
        local c = proxyFrame("Container")
        c.name, c.groups, c.flow, c.refiltered = name, {}, {}, 0
        function c:SetUnit(u) assert(type(u) == "string"); self.unit = u end
        function c:SetAuraProcessingPolicy(p) assert(isEnum(CustomAuraContainerAuraProcessingPolicy, p)); self.policy = p end
        function c:AddAuraGroup(key, filter, o)
            assert(type(key) == "string" and key ~= "", "groupKey")
            assert(filter == "HELPFUL" or filter == "HARMFUL", "filterString")
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
            self.groups[key] = { filters = cf, layout = l, init = o.initializeFrame }
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
function ns.CuesOf(rule) local out = {} for _, r in ipairs(ns.rules) do if r.isCue and r.parentUid == rule.uid then out[#out + 1] = r end end return out end
refreshed = 0
function ns.RefreshAllVisuals() refreshed = refreshed + 1 end
CueRulesDB = {}
_G.NS = ns
local f = assert(loadfile(AURA_DISPLAY_PATH))
f("XayaUI_CombatEngine", ns)
'''.replace("AURA_DISPLAY_PATH", repr(os.path.join(ROOT, "XayaUI_CombatEngine", "AuraDisplay.lua")).replace("'", '"')))

fails = []
def check(name, cond, extra=""):
    print(("PASS " if cond else "FAIL ") + name + (("  [" + str(extra) + "]") if (extra and not cond) else ""))
    if not cond:
        fails.append(name)

L.execute(r'''
local ns = NS
ns.folders = {
  { id = "fA", name = "Alpha Group", cType = "dynamic", cGrowth = "RIGHT", cSpacing = 5, cW = 100, cH = 0, cPoint = "CENTER", cX = 10, cY = 20 },
  { id = "fB", name = "Beta Group",  cType = "dynamic", cGrowth = "DOWN",  cSpacing = 3, cW = 0, cH = 360, cPoint = "TOPLEFT", cX = -50, cY = 60, cScale = 2 },
  { id = "fS", name = "Static Group", cType = "static" },
  { id = "fC", name = "Center Group", cType = "dynamic", cGrowth = "HCENTER" },
}
local function parent(uid, folder, id, extra) local r = { uid = uid, name = uid, folder = folder, useBuff = true, buffID = id, enabled = true, engineTag = "t" }; for k, v in pairs(extra or {}) do r[k] = v end return r end
local function cue(uid, folder, id) return { name = uid .. " cue", folder = folder, isCue = true, parentUid = uid, buffID = id, engineTag = "t", visual = { w = 30, h = 30, zoom = 0, text = { enabled = true, size = 12, anchor = "CENTER", x = 0, y = 0 }, count = { enabled = true, size = 10, anchor = "BOTTOMRIGHT", x = 0, y = 0 } } } end
ns.rules = {
  parent("a1", "fA", 9001), cue("a1", "fA", 9001),
  parent("a2", "fA", 9002, { buffAlt = { 9102, 9103 } }), cue("a2", "fA", 9002),
  parent("a3", "fA", 9003, { enabled = false }), cue("a3", "fA", 9003),            -- disabled: must not be matched
  { uid = "a4", name = "mine", folder = "fA", useBuff = true, buffID = 7777, enabled = true },   -- user's own rule, untagged: untouched
  parent("b1", "fB", 9201), cue("b1", "fB", 9201),
  parent("s1", "fS", 9301), cue("s1", "fS", 9301),
  parent("c1", "fC", 9401), cue("c1", "fC", 9401),
}
''')

def lua(s):
    return L.execute(s)

# 0. nothing is drawn before the user switches a group on
check("EngineOwns false before any group is on", lua("return NS.EngineOwns(NS.rules[1]) == false and NS.EngineOwns(NS.rules[2]) == false"))
lua('evHandler("PLAYER_ENTERING_WORLD")')
check("no container is created while no group is switched on", lua("return #containers == 0"))

# 1. switch group A on
lua('SlashCmdList["XUIENGINE"]("on alpha")')
check("one container for group A", lua("return #containers == 1 and containers[1].name == 'XayaUIEngine_fA' and containers[1].unit == 'player'"))
check("includeSpellIDs = enabled tagged ids + alternates only",
      lua("local s = containers[1].groups.main.filters.includeSpellIDs; local n = 0; for k in pairs(s) do n = n + 1 end; return n == 4 and s[9001] and s[9002] and s[9102] and s[9103] and not s[9003] and not s[7777]"))
check("flow: horizontal, TOPLEFT, grows right/down, wrap size = cW",
      lua("local f = containers[1].flow; return f.axis == 0 and f.anchor == 'TOPLEFT' and f.h == 1 and f.v == -1 and f.max == 100"))
check("layout: spacing 5 both ways, icon 30 x 30",
      lua("local l = containers[1].groups.main.layout; return l.elementSpacing == 5 and l.lineSpacing == 5 and l.elementWidth == 30 and l.elementHeight == 30"))
# first icon centre must land at CENTER + (10, 20): TOPLEFT corner = centre + (-15, +15)
check("placement: container TOPLEFT puts first icon centre at (10, 20)",
      lua("local p = containers[1]._points[1]; return p[1] == 'TOPLEFT' and p[3] == 'CENTER' and p[4] == -5 and p[5] == 35"),
      lua("local p = containers[1]._points[1]; return table.concat({tostring(p[1]), tostring(p[3]), tostring(p[4]), tostring(p[5])}, ' ')"))
check("button init wires icon, cooldown (no swipe), duration text, stack text, zoom 0.08",
      lua("local b = buttons[1]; return b.log.icon and b.log.cd and b.log.cd.swipe == false and b.log.dur and b.log.count and b.log.icon.texcoord[1] == 0.08 and b.log.dur.fontsize == 12 and b.log.count.fontsize == 10"))
check("EngineOwns true for tagged parent and cue in the group",
      lua("return NS.EngineOwns(NS.rules[1]) and NS.EngineOwns(NS.rules[2]) and NS.EngineOwns(NS.rules[3])"))
check("EngineOwns false for the user's own untagged rule and for rules in other groups",
      lua("return NS.EngineOwns(NS.rules[7]) == false and NS.EngineOwns(NS.rules[8]) == false"))
check("core visuals were refreshed after the build", lua("return refreshed >= 1"))
check("rules were never modified (no field added or removed)",
      lua("local r = NS.rules[7]; local n = 0; for _ in pairs(r) do n = n + 1 end; return n == 6"))

# 2. group B: TOPLEFT point, scale 2, grows down (vertical axis)
lua('SlashCmdList["XUIENGINE"]("on Beta")')
check("group B: vertical flow, TOPLEFT, wrap size = cH",
      lua("local f = containers[2].flow; return f.axis == 1 and f.anchor == 'TOPLEFT' and f.v == -1 and f.max == 360"))
# XayaUI: container TOPLEFT at CENTER?? no: point TOPLEFT -> centre = pos + (cW/2, -cH/2) with cW=1 (0 -> min 1), cH=360
check("group B placement divides by scale 2 and offsets by container size",
      lua("local p = containers[2]._points[1]; return p[1] == 'TOPLEFT' and p[4] == ((-50 + 0.5) - (0.5 * 30)) / 2 and p[5] == ((60 - 180) + 0.5 * 30) / 2"),
      lua("local p = containers[2]._points[1]; return tostring(p[4]) .. ' ' .. tostring(p[5])"))

# 3. unsupported groups are refused with a reason and XayaUI keeps drawing them
lua('SlashCmdList["XUIENGINE"]("on static")'); lua('SlashCmdList["XUIENGINE"]("on center")')
check("static group refused, reason recorded", lua("local g = NS.AuraDisplay._groups.fS; return g and g.ok == false and g.err:find('not a dynamic') ~= nil"))
check("HCENTER growth refused, reason recorded", lua("local g = NS.AuraDisplay._groups.fC; return g and g.ok == false and g.err:find('not supported') ~= nil"))
check("refused groups are not engine-owned", lua("return NS.EngineOwns(NS.rules[10]) == false and NS.EngineOwns(NS.rules[11]) == false and NS.EngineOwns(NS.rules[12]) == false"))
check("no container made for refused groups", lua("return #containers == 2"))

# 4. rebuild after the user adds a rule updates the filters instead of creating a second group
lua('NS.rules[#NS.rules + 1] = { uid = "a5", name = "a5", folder = "fA", useBuff = true, buffID = 9005, enabled = true, engineTag = "t" }')
before = lua("return containers[1].refiltered")
lua('SlashCmdList["XUIENGINE"]("refresh")')
check("refresh re-filters the existing group (no second group made)", lua("local c = containers[1]; return c.refiltered == %d + 1 and c.groups.main.filters.includeSpellIDs[9005] == true and #containers == 2" % before))

# 5. combat: build is deferred, then runs when combat ends
lua('combat = true; NS.rules[#NS.rules + 1] = { uid = "a6", name = "a6", folder = "fA", useBuff = true, buffID = 9006, enabled = true, engineTag = "t" }')
lua('SlashCmdList["XUIENGINE"]("refresh")')
check("no rebuild during combat lockdown", lua("return containers[1].groups.main.filters.includeSpellIDs[9006] == nil"))
lua('combat = false; evHandler("PLAYER_REGEN_ENABLED")')
check("deferred rebuild runs when combat ends", lua("return containers[1].groups.main.filters.includeSpellIDs[9006] == true"))

# 6. off: XayaUI draws again
lua('SlashCmdList["XUIENGINE"]("off alpha")')
check("off hides the container and hands the rules back", lua("return containers[1].shown == false and NS.EngineOwns(NS.rules[1]) == false"))

# 7. failure: if the container rejects the call, the group falls back to XayaUI's own icons
lua('failAdd = true; CueRulesDB.engineDisplay.groups = {}; NS.folders[1].cType = "dynamic"; containers = {}; NS.AuraDisplay._groups.fA = nil')
lua('SlashCmdList["XUIENGINE"]("on alpha")')
check("container error is caught and recorded", lua("local g = NS.AuraDisplay._groups.fA; return g and g.ok == false and g.err:find('includeSpellIDs rejected') ~= nil"))
check("failed group is not engine-owned (no icon gap)", lua("return NS.EngineOwns(NS.rules[1]) == false"))

# 8. name matching
lua("printed = {}")
lua('SlashCmdList["XUIENGINE"]("on group")')
check("ambiguous group name is refused, nothing changes", lua("return #printed >= 1 and printed[1]:find('groups match') ~= nil"))

print()
print("FAILED: " + ", ".join(fails) if fails else "ALL PASSED")
sys.exit(1 if fails else 0)
