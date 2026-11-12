"""Display texts of the engine (Visual.lua with the real Core / Conditions / Timing / Triggers / Outcomes / Cues / Engine), against
what the 12.1.5 API documents (Blizzard_APIDocumentationGenerated, build 70688):
  * UnitGetTotalAbsorbs returns a SECRET number always (SecretReturns): shown only through SetText / the game's number helpers,
    "hide when zero" through C_StringUtil.TruncateWhenZero, the "aura" source falls back to the total when the aura's own amount
    is hidden;
  * stacks show from 2 up (Blizzard's own rule), a hidden stack count is UNKNOWN to conditions (not 1);
  * aura references never hold a secret value;
  * a display with no aura to time counts its spell's cooldown down through the game's duration object and a duration text
    binding (C_Spell.GetSpellCooldownDuration(id, true) / GetSpellChargeDuration, C_DurationUtil.CreateDurationTextBinding);
  * XayaUI's time format as a game number formatter (C_StringUtil.CreateNumericRuleFormatter), checked before use;
  * a "Target Debuff (yours)" rule's display shows the debuff's own time and stacks when readable;
  * the companion texts (shield amount, charges) of a display the combat engine draws.
Stand-in game (tests/engine_bench.py stubs). The game's own formatter and binding cannot run here: the stand-ins follow the
documented contracts, and the in-game behaviour is still to be confirmed in game. Run: python3 tests/engine_text_run.py"""
import os, sys
from lupa.lua51 import LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
bench = open(os.path.join(ROOT, "tests", "engine_bench.py")).read()
a = bench.index("L.execute(r'''") + len("L.execute(r'''"); b = bench.index("''')", a)
L = LuaRuntime(unpack_returned_tuples=True)
L.execute("CueRulesDB = { rules = {}, folders = {} }")
L.execute(bench[a:b])
L.execute(r'''
COMBAT = false
SECRET = setmetatable({}, { __tostring = function() return "SECRET" end })        -- a hidden aura / iid
SECRET_ABS = setmetatable({}, { __tostring = function() return "SECRET_ABS" end })  -- the hidden absorb total
SECRET_STR = setmetatable({}, { __tostring = function() return "SECRET_STR" end })  -- a string the game made from a secret
SECRET_NUM = setmetatable({}, { __tostring = function() return "SECRET_NUM" end })  -- a hidden cooldown number
local SECRETS = { [SECRET] = true, [SECRET_ABS] = true, [SECRET_STR] = true, [SECRET_NUM] = true }
function issecretvalue(v) return SECRETS[v] == true end
-- any comparison of a secret errors, like the game for tainted code (a table compared with < / > errors in Lua already;
-- equality with nil is caught by the metatables below)
for s in pairs(SECRETS) do getmetatable(s).__eq = function() error("attempt to compare a secret value") end; getmetatable(s).__lt = getmetatable(s).__eq; getmetatable(s).__le = getmetatable(s).__eq end
Enum = Enum or {}
Enum.CooldownViewerAlertEventType = { Available = 1, PandemicTime = 2, OnCooldown = 3, ChargeGained = 4, OnAuraApplied = 5, OnAuraRemoved = 6 }
Enum.NumericRuleFormatRounding = { Nearest = 0, Up = 1, Down = 2 }
function hooksecurefunc(t, name, fn) local orig = t[name]; t[name] = function(...) local r = { orig(...) }; fn(...); return unpack(r) end end
EVENTS = {}
FRAME_METHODS.RegisterEvent = function(self, e) EVENTS[e] = true end
FRAME_METHODS.RegisterUnitEvent = function(self, e) EVENTS[e] = true end
FRAME_METHODS.GetParent = function(self) return self._parent or UIParent end
FRAME_METHODS.SetParent = function(self, p) self._parent = p end
FRAME_METHODS.GetFrameStrata = function(self) return self._strata or "MEDIUM" end
FRAME_METHODS.SetFrameStrata = function(self, s) self._strata = s end
FRAME_METHODS.GetFrameLevel = function(self) return self._level or 1 end
FRAME_METHODS.SetFrameLevel = function(self, l) self._level = l end
FRAME_METHODS.SetAlpha = function(self, a) self._alpha = a end

-- the world
APPS = 0                                  -- stacks of Anti-Magic Shell (48707) when readable
AURA_UNTIL = nil                          -- shield up until (out of combat: readable)
C_UnitAuras.GetUnitAuraBySpellID = function(unit, id)
  if id ~= 48707 or not (AURA_UNTIL and NOW < AURA_UNTIL) then return nil end
  if COMBAT then return nil end            -- RequiresNonSecretAura: "protected APIs will return no values"
  return { auraInstanceID = 77, applications = APPS, expirationTime = AURA_UNTIL, duration = 10, spellId = 48707 }
end
C_UnitAuras.GetAuraDuration = function() return nil end
AURA_POINTS = 12345
C_UnitAuras.GetAuraDataByAuraInstanceID = function(unit, iid)
  if COMBAT then error("Auras cannot be accessed when secret while tainted") end
  if unit == "player" and iid == 77 then return { points = { AURA_POINTS } } end
  if unit == "target" and iid == 5 then return { points = { 500 } } end
end
TOTAL_CALLS = 0
function UnitGetTotalAbsorbs(u) TOTAL_CALLS = TOTAL_CALLS + 1; return SECRET_ABS end   -- 12.1.5: SecretReturns = true
ABBR = {}; TRUNC = {}
function AbbreviateLargeNumbers(v) ABBR[#ABBR + 1] = v; return SECRET_STR end
C_StringUtil = { TruncateWhenZero = function(v) TRUNC[#TRUNC + 1] = v; return SECRET_STR end }
-- debuffs you put on the target (out of combat readable; in combat the call refuses)
DEBUFF = nil
C_UnitAuras.GetUnitAuras = function(unit, filter)
  assert(filter == "HARMFUL|PLAYER")
  if COMBAT then error("Auras cannot be accessed when secret while tainted") end
  if unit == "target" and DEBUFF then return { DEBUFF } end
  return {}
end
UnitExists = function(u) return u == "player" or u == "target" end
-- cooldowns: 49998 single; 50000 has 2 charges
CD_UNTIL = nil; CHG_CUR = 2
C_Spell.GetSpellCooldown = function(id)
  local act = (id == 49998) and CD_UNTIL ~= nil and NOW < CD_UNTIL
  if id == 50000 then act = CHG_CUR == 0 end
  if COMBAT then return { startTime = SECRET_NUM, duration = SECRET_NUM, isActive = act and true or false, isOnGCD = false, isEnabled = true } end
  return { startTime = act and NOW - 1 or 0, duration = act and 20 or 0, isActive = act and true or false, isOnGCD = false, isEnabled = true }
end
C_Spell.GetSpellCharges = function(id)
  if id ~= 50000 then return nil end
  return { currentCharges = COMBAT and SECRET_NUM or CHG_CUR, maxCharges = 2, isActive = CHG_CUR < 2, cooldownStartTime = 0, cooldownDuration = 0 }
end
DUROBJ = { name = "cooldown duration object" }; CHGOBJ = { name = "recharge duration object" }
CDCALLS = {}
-- (round 7) each call notes the file that asked (level 4: this helper, the stub, pcall, the caller): the display's text (Visual.lua) and, since round 7,
-- the engine's own cooldown widgets (Engine.lua) both ask
local function asker() local i = debug.getinfo(4, "S"); local s = i and i.source or ""; return s:match("([%w_]+%.lua)") or s end
C_Spell.GetSpellCooldownDuration = function(id, ignoreGCD) CDCALLS[#CDCALLS + 1] = { id, ignoreGCD, src = asker() }; return DUROBJ end
C_Spell.GetSpellChargeDuration = function(id) CDCALLS[#CDCALLS + 1] = { id, "charge", src = asker() }; return CHGOBJ end
-- the last call the display's text made (Visual.lua), and the calls of one file
function LASTCALL(src) for i = #CDCALLS, 1, -1 do if CDCALLS[i].src == src then return CDCALLS[i] end end end
-- the game's duration text binding (documented methods only)
BINDINGS = {}
C_DurationUtil = { CreateDurationTextBinding = function()
  local b = { enabled = false }
  function b:SetToDefaults() end
  function b:SetFontString(fs) self.fs = fs end
  function b:SetZeroDurationText(t) self.zero = t end
  function b:SetExpiredText(t) self.expired = t end
  function b:SetFormatter(f) self.fmt = f end
  function b:SetDuration(d) self.dur = d end
  function b:SetEnabled(e) self.enabled = e end
  BINDINGS[#BINDINGS + 1] = b
  return b
end }
-- C_StringUtil.CreateNumericRuleFormatter: breakpoints chosen like the documented "threshold = minimum input value this rule
-- applies to"; FORMATTER_MODE picks how the stand-in scans them ("desc" = first match in a largest-first list, "asc" = last match
-- in a smallest-first list, "broken" = always "?")
FORMATTER_MODE = "desc"; FORMATTERS = 0
local function roundTo(x, step, mode) if not step then return x end local q = x / step; if mode == 1 then q = math.ceil(q - 1e-9) elseif mode == 2 then q = math.floor(q + 1e-9) else q = math.floor(q + 0.5) end return q * step end
C_StringUtil.CreateNumericRuleFormatter = function()
  FORMATTERS = FORMATTERS + 1
  local f = { bps = {} }
  function f:SetBreakpoints(b) self.bps = b end
  function f:FormatNumber(x)
    if FORMATTER_MODE == "broken" then return "?" end
    local bp
    for _, p in ipairs(self.bps) do
      if x >= p.threshold then bp = p; if FORMATTER_MODE == "desc" then break end end
    end
    if not bp then return "" end
    local v = roundTo(x, bp.step, bp.rounding)
    if bp.components then
      local vals = {}
      for i, c in ipairs(bp.components) do
        local y = v
        if c.div then y = y / c.div end
        if c.mod then y = math.fmod(y, c.mod) end
        vals[i] = roundTo(y, c.step, c.rounding)
      end
      return string.format(bp.format, unpack(vals))
    end
    return string.format(bp.format, v)
  end
  return f
end
-- the Cooldown Manager's icon for the shield (in combat its instance id is secret, as seen in game)
local function cdmItem(spellID)
  local f = CreateFrame("Frame")
  f.cooldownInfo = { spellID = spellID }
  function f:GetSpellID() return spellID end
  function f:TriggerAlertEvent() end
  function f:OnUnitAuraUpdatedEvent() end
  function f:OnCooldownIDSet() end
  return f
end
AMS = cdmItem(48707)
BuffIconCooldownViewer = CreateFrame("Frame"); function BuffIconCooldownViewer:GetChildren() return AMS end
EssentialCooldownViewer = CreateFrame("Frame"); function EssentialCooldownViewer:GetChildren() end
UtilityCooldownViewer = CreateFrame("Frame"); function UtilityCooldownViewer:GetChildren() end
BuffBarCooldownViewer = CreateFrame("Frame"); function BuffBarCooldownViewer:GetChildren() end
UPDATERS = {}
local SetScript0 = FRAME_METHODS.SetScript
FRAME_METHODS.SetScript = function(self, n, fn) SetScript0(self, n, fn); if n == "OnUpdate" and fn then UPDATERS[#UPDATERS + 1] = self end end
''')
load = L.eval("function(src, name, ns) local f, e = loadstring(src, '@' .. name); if not f then error(e) end; return f('XayaUI', ns) end")
ns = L.eval("{}"); L.globals().NS = ns
for f in ("XayaUI/Core.lua", "XayaUI/Modules.lua", "XayaUI_Rules/RuleDefaults.lua", "XayaUI/Compat.lua", "XayaUI_Rules/Conditions.lua", "XayaUI_Rules/Timing.lua", "XayaUI_Rules/Triggers.lua", "XayaUI_Rules/Outcomes.lua", "XayaUI_Rules/Cues.lua", "XayaUI_Rules/Actions.lua", "XayaUI/Sound.lua", "XayaUI_Rules/Visual.lua", "XayaUI_Rules/Engine.lua"):
    load(open(os.path.join(ROOT, f), encoding="utf-8").read(), f, ns)
L.execute(r'''
local ns = NS
ns.Print = function() end
ns.PlaySound = function() end
ns.EffectiveSound = function(r) return r.name end
ns.KindHas = function(r, kind) if r.isCue then return (kind == "sound") == (r.cueKind == "sound" or r.cueKind == "speech") end return kind == "visual" end
local function vis(extra)
  local v = { enabled = true, w = 40, h = 40, text = { enabled = true, decimals = true, decimalBelow = 5 }, count = { enabled = false }, absorb = { enabled = false } }
  for k, x in pairs(extra or {}) do v[k] = x end
  return v
end
-- R1: Anti-Magic Shell shown while up, with time, stacks and its own shield amount
R1 = { uid = "r1", name = "AMS", useBuff = true, buffID = 48707, buffState = "present", cdState = "none", enabled = true, load = { mode = "always" },
  visual = vis({ trigger = "buffActive", count = { enabled = true }, absorb = { enabled = true, source = "aura", abbreviate = true, hideZero = true } }) }
-- R2: a cooldown-only display (shown while not ready) with its time text
R2 = { uid = "r2", name = "Death Strike", useCooldown = true, spellID = 49998, cdState = "notReady", buffState = "none", enabled = true, load = { mode = "always" }, visual = vis({ trigger = "condition" }) }
-- R3: a "Target Debuff (yours)" rule with time and stacks
R3 = { uid = "r3", name = "Sigil debuff", enabled = true, load = { mode = "always" }, cdState = "none", buffState = "none",
  extra = { list = { { type = "targetDebuff", spellID = 204598, unit = "target", state = "yes", cdmAbsent = "no" } } },
  visual = vis({ trigger = "condition", count = { enabled = true }, absorb = { enabled = true, source = "aura", abbreviate = false, hideZero = false } }) }
-- R4: a charge spell (2 charges), shown while not fully charged, with time and a charges count
R4 = { uid = "r4", name = "Charges", useCooldown = true, spellID = 50000, cdState = "notReady", buffState = "none", enabled = true, load = { mode = "always" },
  visual = vis({ trigger = "condition", count = { enabled = true, source = "charges" } }) }
ns.rules = { R1, R2, R3, R4 }
ns.folders = {}
CueRulesDB.rules, CueRulesDB.folders = ns.rules, ns.folders
FRAME = 1 / 60
-- (round 5, V27 "No running loops") the engine no longer re-checks every rule on a 0.2 s tick: it steps when the game reports a change,
-- and waits for a countdown's next second with a one-shot timer. This stand-in changes the game's answers without sending events, so
-- each PLAY starts with the step that change's event brings, and C_Timer runs here (due timers run each frame, as in the game).
TIMERS = {}
local function addTimer(d, fn) local t = { at = NOW + (d or 0), fn = fn }; t.Cancel = function() t.dead = true end; TIMERS[#TIMERS + 1] = t; return t end
C_Timer.After = function(d, fn) addTimer(d, fn) end
C_Timer.NewTimer = function(d, fn) local t; t = addTimer(d, function() fn(t) end); return t end
function PLAY(seconds)
  local n = math.max(1, math.floor(seconds / FRAME + 0.5))
  ENGINE_STEP(NS)
  for i = 1, n do
    NOW = NOW + FRAME
    local due = {}
    for j = #TIMERS, 1, -1 do local t = TIMERS[j]; if t.dead or t.at <= NOW then table.remove(TIMERS, j); if not t.dead then due[#due + 1] = t end end end
    for j = #due, 1, -1 do due[j].fn() end
    for _, f in ipairs(UPDATERS) do local fn = f._s_OnUpdate; if fn then fn(f, FRAME) end end
  end
end
function FR(r) return ns.DisplayFrame(r) end
function INFO(r) local rt = ns.runtime[r]; return rt and rt.info end
''')
fails = []
def check(name, ok, extra=""):
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  [" + str(extra) + "]"))
    if not ok: fails.append(name)
lua = lambda s: L.execute(s)
txt = lambda r, fs: lua("local f = FR(%s); local t = f.%s; return t._shown and tostring(t._text) or 'hidden'" % (r, fs))

# 1. out of combat: readable aura. A buff that cannot stack (0) shows no count; time in XayaUI's format; its own shield amount
lua('NOW = 1000; AURA_UNTIL = NOW + 6.5; APPS = 0; PLAY(0.3)')
check("R1 shown while the shield is up", lua("return FR(R1):IsShown() == true"))
check("time text: XayaUI's format (whole seconds above 5)", txt("R1", "text") == "7", txt("R1", "text"))
check("stacks: a buff that cannot stack (0) shows no count (was '0')", txt("R1", "count") == "hidden", txt("R1", "count"))
check("shield amount, source 'aura' out of combat: the aura's own amount, abbreviated", txt("R1", "absorb") == "12.3K", txt("R1", "absorb"))
lua('APPS = 1; PLAY(0.3)')
check("stacks: one stack shows nothing either (Blizzard's rule, same as the combat engine)", txt("R1", "count") == "hidden", txt("R1", "count"))
lua('APPS = 3; PLAY(0.3)')
check("stacks: 3 stacks show '3'", txt("R1", "count") == "3", txt("R1", "count"))
check("condition 'stacks' reads 3 out of combat", lua("return NS.NumRef('n:buffStacks', R1, INFO(R1)) == 3"))

# 2. combat: the game hides the aura; the Cooldown Manager icon says it is up (secret instance id)
lua('COMBAT = true; AMS.wasSetFromAura = false; AMS.auraInstanceID = SECRET; ABBR = {}; PLAY(0.3)')
check("in combat the shield is still known to be up (Cooldown Manager icon with a secret id)", lua("return INFO(R1).present == true"))
check("the aura reference holds no secret value (id dropped, marked hidden)", lua("local r = INFO(R1).buffRef; for k, v in pairs(r) do if issecretvalue(v) then return false end end return r.instanceID == nil and r.hiddenID == true"))
check("condition 'stacks' is UNKNOWN in combat (was a guessed 1)", lua("return NS.NumRef('n:buffStacks', R1, INFO(R1)) == nil"))
check("stack text hidden in combat (no readable count; the combat engine draws it)", txt("R1", "count") == "hidden", txt("R1", "count"))
check("shield amount, source 'aura' in combat: falls back to the total absorbs (the aura's own amount is hidden)",
      txt("R1", "absorb") == "SECRET_STR" and lua("return ABBR[#ABBR] == SECRET_ABS"), txt("R1", "absorb"))
lua('R1.visual.absorb.abbreviate = false; TRUNC = {}; PLAY(0.3)')
check("'hide when zero' without abbreviation: the game's TruncateWhenZero ('' for zero)", txt("R1", "absorb") == "SECRET_STR" and lua("return TRUNC[#TRUNC] == SECRET_ABS"))
lua('R1.visual.absorb.hideZero = false; PLAY(0.3)')
check("neither option: the secret number itself goes to SetText", txt("R1", "absorb") == "SECRET_ABS", txt("R1", "absorb"))
lua('R1.visual.absorb.source = "total"; R1.visual.absorb.abbreviate = true; R1.visual.absorb.hideZero = true; COMBAT = false; ABBR = {}; PLAY(0.3)')
check("source 'total' out of combat: the total is secret even then (SecretReturns), shown through the helper", txt("R1", "absorb") == "SECRET_STR" and lua("return ABBR[#ABBR] == SECRET_ABS"))
lua('AURA_UNTIL = nil; AMS.auraInstanceID = nil; PLAY(0.3)')

# 3. a cooldown with no aura: the game counts it down (duration object + text binding), exact in combat
lua('COMBAT = true; CD_UNTIL = NOW + 20; CDCALLS = {}; PLAY(0.3)')
check("R2 shown while on cooldown", lua("return FR(R2):IsShown() == true"))
check("cooldown duration asked of the game with the global cooldown ignored", lua("local c = LASTCALL('Visual.lua'); return c and c[1] == 49998 and c[2] == true"))
# (round 7, SD-60) the engine waits for the hidden end of the same cooldown in a widget of its own, fed the duration object the
# game reports for GetSpellCooldown (the global cooldown counted, as the cooldown's own reading counts it)
check("(round 7) the engine's cooldown widget asks for the same cooldown's duration with the global cooldown counted",
      lua("local c = LASTCALL('Engine.lua'); return c and c[1] == 49998 and c[2] == false"))
check("a duration text binding drives the display's own time text", lua("local b = FR(R2).cdBind; return b and b.fs == FR(R2).text and b.dur == DUROBJ and b.enabled == true and b.zero == '' and b.expired == ''"))
check("the binding uses XayaUI's time format (game formatter checked against FmtRemaining)", lua("local b = FR(R2).cdBind; return b.fmt ~= nil and b.fmt == NS.TimeFormatter(true, 5)"))
check("the time text is shown", lua("return FR(R2).text._shown == true"))
lua('CD_UNTIL = NOW - 1; PLAY(0.3)')
check("cooldown over: binding stopped (display hidden by its own rule)", lua("return FR(R2).cdBind.enabled == false"))

# 4. a spell with charges: recharge time + charges count
lua('CHG_CUR = 1; CDCALLS = {}; PLAY(0.3)')
check("charge spell not full: the RECHARGE duration object drives the time", lua("local c = LASTCALL('Visual.lua'); return c and c[1] == 50000 and c[2] == 'charge' and FR(R4).cdBind.dur == CHGOBJ and FR(R4).cdBind.enabled"))
check("charges count in combat: the secret number handed to SetText", txt("R4", "count") == "SECRET_NUM", txt("R4", "count"))
lua('COMBAT = false; PLAY(0.3)')
check("charges count out of combat: '1'", txt("R4", "count") == "1", txt("R4", "count"))
lua('CHG_CUR = 2; PLAY(0.3)')

# 4b. charges in a CONDITION, in combat (Insivius's Death and Decay rule, 2026-11-04: "charges == 2" never fired, because the
# count is hidden in combat). The game still says whether a charge is recharging, and the maximum (both NeverSecret).
for cur, want in ((2, 2), (1, 1), (0, 0)):
    v = lua('COMBAT = true; CHG_CUR = %d; local _, info = NS.Evaluate(R4); return NS.NumRef("n:cdCharges", R4, info)' % cur)
    check("charges condition in combat, %d of 2 charges: reads %d" % (cur, want), v == want, v)
v = lua('COMBAT = true; CHG_CUR = 2; local _, info = NS.Evaluate(R4); return NS.CheckValue({ ref = "n:cdCharges", cmp = "==", num = 2 }, R4, nil, info)')
check("'charges == 2' is TRUE in combat at full charges (was unknown)", v is True, v)
lua('''REAL_CHG = C_Spell.GetSpellCharges
C_Spell.GetSpellCharges = function(id) local c = REAL_CHG(id); if c then c.maxCharges = 3 end; return c end''')
v = lua('COMBAT = true; CHG_CUR = 1; local _, info = NS.Evaluate(R4); return NS.NumRef("n:cdCharges", R4, info)')
check("3-charge spell recharging in combat: count stays unknown (no guess)", v is None, v)
v = lua('COMBAT = true; CHG_CUR = 2; local _, info = NS.Evaluate(R4); return NS.NumRef("n:cdCharges", R4, info)')
check("3-charge spell not recharging in combat: exactly its maximum", v == 3, v)
lua('C_Spell.GetSpellCharges = REAL_CHG; COMBAT = false; CHG_CUR = 2')   # (no engine step here: the sections below keep their own timeline)

# 5. "Target Debuff (yours)": the debuff's own time and stacks, out of combat
lua('DEBUFF = { spellId = 204598, auraInstanceID = 5, applications = 2, expirationTime = NOW + 7.2, duration = 10 }; PLAY(0.3)')
check("debuff rule shown", lua("return FR(R3):IsShown() == true"))
check("debuff rule: time text from the debuff itself (was blank)", txt("R3", "text") == "7", txt("R3", "text"))
check("debuff rule: stacks from the debuff itself", txt("R3", "count") == "2", txt("R3", "count"))
check("debuff rule: its 'aura' amount is read on the TARGET (the reference carries its unit)", txt("R3", "absorb") == "500", txt("R3", "absorb"))
lua('COMBAT = true; PLAY(0.3)')
check("in combat the debuff list is refused: no invented time (the combat engine draws these)", lua("return INFO(R3).auraRef == nil"))
check("in combat (debuff unknown) the debuff display is hidden, so no stale or borrowed amount shows", lua("return FR(R3):IsShown() == false"))
lua("COMBAT = false; FR(R3):Show(); NS.UpdateVisualText(R3, { auraRef = { unit = 'target', instanceID = 99 } })")
check("a debuff whose own amount cannot be read is never shown with YOUR absorbs", txt("R3", "absorb") == "hidden", txt("R3", "absorb"))
lua("NS.UpdateVisualText(R3, { auraRef = { unit = 'player', instanceID = 99 } })")
check("(the same on an aura on you: your total absorbs)", txt("R3", "absorb") == "SECRET_ABS", txt("R3", "absorb"))
lua("COMBAT = true")
lua('COMBAT = false; DEBUFF = nil; PLAY(0.3)')

# 6. the game's number formatter for XayaUI's time format: checked before use, the other breakpoint order tried, else not used
probe = lambda: lua("local f = NS.TimeFormatter(true, 5); return f and (f:FormatNumber(65.4) .. '|' .. f:FormatNumber(4.96) .. '|' .. f:FormatNumber(12.2) .. '|' .. f:FormatNumber(7325)) or 'nil'")
check("formatter matches FmtRemaining (m:ss, tenths below 5, whole seconds rounded up, hours)", probe() == "1:05|5.0|13|2h", probe())
lua('FORMATTER_MODE = "asc"')
# (formatters are cached per (tenths, threshold): each case below uses a key not built yet)
check("a client that reads breakpoints smallest-first: the other order is used", lua("local f = NS.TimeFormatter(false, 3); return f ~= nil and f:FormatNumber(2.2) == '3'"))
lua('FORMATTER_MODE = "broken"')
check("a formatter that disagrees is never used (the game's own format is used instead)", lua("return NS.TimeFormatter(true, 7) == nil"))

# 7. companion texts of a display the combat engine draws (shield amount / charges): XayaUI's frame hides, the companion shows
lua('FORMATTER_MODE = "desc"; COMBAT = true; AURA_UNTIL = NOW + 30; AMS.auraInstanceID = SECRET; R1.visual.absorb.source = "aura"; R1.visual.absorb.abbreviate = true')
lua('OWNED = { [R1] = true }; NS.EngineOwns = function(r) return OWNED[r] == true end; NS.EngineCompanion = function(r) return OWNED[r] == true end; PLAY(0.3)')
check("engine-drawn: XayaUI's own icon hidden", lua("return FR(R1):IsShown() == false"))
check("engine-drawn: the companion shows the shield amount over the engine's icon", lua("local c = FR(R1).comp; return c and c._shown and c.absorb._shown and c.absorb._text == SECRET_STR"))
check("companion: aura stacks are the engine's, not drawn twice", lua("return FR(R1).comp.count._shown == false"))
lua('OWNED = {}; PLAY(0.3)')
check("engine stops drawing it: companion hidden, XayaUI's icon back", lua("return FR(R1).comp._shown == false and FR(R1):IsShown() == true"))
lua('OWNED = { [R1] = true }; PLAY(0.3); COMP = FR(R1).comp; SHOWN_BEFORE = COMP._shown; NS.DropVisual(R1)')
check("a dropped display takes its companion with it", lua("return SHOWN_BEFORE == true and COMP._shown == false"))

# 8. the engine steps at once on a new target / focus
check("engine listens to PLAYER_TARGET_CHANGED and PLAYER_FOCUS_CHANGED", lua("return EVENTS.PLAYER_TARGET_CHANGED == true and EVENTS.PLAYER_FOCUS_CHANGED == true"))

# (/xui debug timing, the coverage report, is XayaUI Dev Assist's (on another branch): its checks left with it)

print(); print("FAILED: " + ", ".join(fails) if fails else "ALL PASSED"); sys.exit(1 if fails else 0)
