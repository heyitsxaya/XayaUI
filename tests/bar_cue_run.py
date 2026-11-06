#!/usr/bin/env python3
"""Bar cues (ROADMAP RM-BARS). Xaya 2026-11-06: "Time to build progress bar cues!" and her answers (docs/process/REQUEST-LOG.md
S8-1 .. S8-4): a new Bar cue kind; tracks aura time left, spell cooldown / recharge, stacks, charges; parts: icon (left / right /
none), spark, name + time texts, stack / charge count; colour = the type the tooltip names FIRST, then the game's dispel type, then a
fixed blue; colour styles Blizzard default / Neon / Pastel / Muted / Custom (a picker per type); default 220 x 22, background 20 %,
1 px border, flat texture, horizontal, drains right to left.

Part A loads the real addons in the stand-in game (tests/harness) and checks what the player gets: the cue, the frame XayaUI draws,
its colour, its value, the editor, the new-rule picker, Smart Categories, and that nothing is saved for players who never use a bar.
Part B loads the real Combat/AuraDisplay.lua in the engine's stand-in container (the one tests/aura_display_run.py uses, read from
that file, with the aura button setters a Bar needs: SetApplicationBar, SetSpellName, AddDispelTypeTexture; Blizzard 12.1.5
Blizzard_CustomAuraButton.lua) and checks the engine draws the same bar: single slot, stacks bar, bars in a dynamic group, a cooldown
bar left to XayaUI, and the same colour decision as XayaUI's own path (parity, V11).
Colour values below are made-up test numbers standing in for the game's tables; they are not Blizzard's.
Run: python3 tests/bar_cue_run.py"""
import os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

RESULTS = []
def check(name, ok, extra=""):
    RESULTS.append((name, bool(ok)))
    print(("PASS " if ok else "FAIL ") + name + (("  [" + str(extra) + "]") if (extra and not ok) else ""))

STUBS = r'''
-- the game's colour tables and tooltip / aura reads, as test stand-ins (made-up numbers)
TEST_FIRE = { r = 0.9, g = 0.4, b = 0.1 }
TEST_SHADOW = { r = 0.45, g = 0.3, b = 0.85 }
TEST_MAGIC = { 0.2, 0.3, 0.95 }
COMBATLOG_DEFAULT_COLORS = { schoolColoring = {} }
local E = Enum and Enum.Damageclass
if E and E.MaskFire then
  COMBATLOG_DEFAULT_COLORS.schoolColoring[E.MaskFire] = TEST_FIRE
  COMBATLOG_DEFAULT_COLORS.schoolColoring[E.MaskShadow] = TEST_SHADOW
end
AuraUtil = AuraUtil or {}
AuraUtil.GetAuraBorderColor = function(t)
  if t == "Magic" then return CreateColor(TEST_MAGIC[1], TEST_MAGIC[2], TEST_MAGIC[3], 1) end
  if t == "Curse" then return CreateColor(0.6, 0, 1, 1) end
  return CreateColor(0.8, 0, 0, 1)
end
TIP = nil            -- what C_TooltipInfo.GetSpellByID returns
AURATIP = nil        -- what C_TooltipInfo.GetUnitAuraByAuraInstanceID returns
AURADATA = nil       -- what C_UnitAuras.GetAuraDataByAuraInstanceID returns
C_TooltipInfo = { GetSpellByID = function() return TIP end, GetUnitAuraByAuraInstanceID = function() return AURATIP end }
C_UnitAuras = C_UnitAuras or {}
C_UnitAuras.GetAuraDataByAuraInstanceID = function() return AURADATA end
CD_DUR = { token = "cooldown duration object" }
C_Spell = C_Spell or {}
C_Spell.GetSpellCooldownDuration = function() return CD_DUR end
'''

LUA_A = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
assert(loadstring(STUBS_SRC))()
local function near(a, b) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 0.002 end

-- nothing about bars exists for a player who never adds one (V14: off costs nothing)
check("no rule carries a bar table by default (RULE_DEFAULTS.visual has no 'bar')", ns.RULE_DEFAULTS.visual.bar == nil)
check("no Bar colour settings are saved until changed", not (CueRulesDB.ui and CueRulesDB.ui.barColors))

-- 1. the kind and its defaults (her answers S8-2 .. S8-4)
local hasBar = false
for _, k in ipairs(ns.CUE_KINDS) do if k == "bar" then hasBar = true end end
check("Bar is a cue kind, labelled 'Bar'", hasBar and ns.CUE_KIND_LABEL.bar == "Bar")
local P = ns.NewRule(); P.name = "Demon Spikes"; P.enabled = true; P.useBuff = true; P.buffID = 203819; P.buffState = "present"; ns.NormalizeRule(P)
ns.rules = { P }
local cue = ns.NewCueRule(P, "bar")
local v = cue and cue.visual
check("a new Bar cue is made", cue ~= nil and cue.cueKind == "bar" and v.kind == "bar")
if not cue then return R end
check("default size 220 x 22", v.w == 220 and v.h == 22, tostring(v.w) .. "x" .. tostring(v.h))
check("default background: black at 20 %", v.bg.enabled and v.bg.color[1] == 0 and v.bg.color[2] == 0 and v.bg.color[3] == 0 and v.bg.color[4] == 0.2)
check("default border: 1 px black", v.border.enabled and v.border.size == 1 and v.border.color[1] == 0 and v.border.color[4] == 1)
local b = ns.BarCueSettings(v)
check("default: flat texture, horizontal, drains right to left (toward the left edge), colour automatic",
  b.texture == "flat" and b.dir == "left" and not b.reverse and b.colorMode == "auto" and ns.BarTexturePath(b) == "Interface\\Buttons\\WHITE8X8"
  and ns.BarOrient(b) == "HORIZONTAL" and select(2, ns.BarOrient(b)) == false)
check("a Bar cue's parts are there: icon, spark, name text, time text, count text", b.icon == "left" and b.spark.enabled and b.name.enabled and v.text.enabled and v.count ~= nil)
check("the rule's aura is what an Automatic bar tracks", ns.BarCueSource(cue) == "aura" and ns.BarCueSpell(cue) == 203819)

-- 2. the frame XayaUI draws
ns.RefreshVisual(cue)
local fr = ns.DisplayFrame(cue)
check("the display frame has a status bar", fr and fr.barF and fr.barF:GetObjectType() == "StatusBar")
if not (fr and fr.barF) then return R end
check("the art texture is hidden (a bar, not a picture)", not fr.tex:IsShown())
check("the icon square sits at the left, 22 x 22", fr.barIcon:IsShown() and fr.barIcon._w == 22 and select(1, fr.barIcon:GetPoint(1)) == "LEFT")
local p1, _, _, x1 = fr.barF:GetPoint(1)
check("the bar starts after the icon", p1 == "TOPLEFT" and x1 == 22, tostring(p1) .. " " .. tostring(x1))
check("the name text shows the aura's name", fr.barName:IsShown() and fr.barName:GetText() ~= nil)
-- record what the game would draw
local rec = {}
rawset(fr.barF, "SetStatusBarColor", function(self, r, g, b2, a) rec.color = { r, g, b2, a } end)
rawset(fr.barF, "SetTimerDuration", function(self, d, interp, dir) rec.timer = { d, interp, dir } end)
local function step(info) fr.barCR = nil; rec.color = nil; ns.UpdateVisualText(cue, info) end
local now = GetTime()
local ref = { unit = "player", expiration = now + 5, duration = 10 }

-- 3. colour (S8-4 "Tooltip first": tooltip type > the aura's dispel type > fixed blue)
TIP = { lines = { { leftText = "Demon Spikes" }, { leftText = "Deals 50 Fire damage to attackers." } } }
ns.BarForgetTooltipTypes()
step({ buffRef = ref })
check("the tooltip names Fire: the bar is the game's Fire colour", rec.color and near(rec.color[1], 0.9) and near(rec.color[2], 0.4) and near(rec.color[3], 0.1) and fr.barColorWhy == "tooltip",
  rec.color and table.concat(rec.color, ",") or "no colour")
check("the value is the aura's remaining time: 5 of 10 s = half", near(fr.barF:GetValue(), 0.5), fr.barF:GetValue())
check("the spark shows on the fill's moving edge (its right edge while draining toward the left)",
  fr.barSpark:IsShown() and select(2, fr.barSpark:GetPoint(1)) == fr.barF:GetStatusBarTexture() and select(3, fr.barSpark:GetPoint(1)) == "RIGHT")
AURADATA = { dispelName = "Magic" }
local refI = { unit = "player", expiration = now + 5, duration = 10, instanceID = 77 }
step({ buffRef = refI })
check("tooltip first: a Magic aura whose tooltip names Fire stays Fire", fr.barColorWhy == "tooltip" and near(rec.color[1], 0.9))
TIP = { lines = { { leftText = "Demon Spikes" }, { leftText = "Increases your armor." } } }
ns.BarForgetTooltipTypes()
step({ buffRef = refI })
check("no type in the tooltip: the aura's dispel type (Magic) colours it", fr.barColorWhy == "dispel" and fr.barColorType == "Magic" and near(rec.color[3], 0.95),
  tostring(fr.barColorWhy))
AURADATA = nil
ns.BarForgetTooltipTypes()
step({ buffRef = ref })
check("no type anywhere: the fixed blue (0.25, 0.62, 1)", fr.barColorWhy == "fallback" and near(rec.color[1], 0.25) and near(rec.color[2], 0.62) and near(rec.color[3], 1))
AURATIP = { lines = { { leftText = "Demon Spikes", rightText = "Magic" }, { leftText = "Armor increased." } } }
ns.BarForgetTooltipTypes()
step({ buffRef = refI })
check("a live aura's tooltip that says Magic at the top right: Magic, from the tooltip", fr.barColorWhy == "tooltip" and fr.barColorType == "Magic")
AURATIP = nil
check("'Shadowflame damage' names Shadow (the first school named)", ns.BarSchoolInText("Deals 10 Shadowflame damage.") == "Shadow")
check("'Frostfire damage' names Frost", ns.BarSchoolInText("Hurls a bolt for 5 Frostfire damage") == "Frost")
check("a dispel word in the description is not read as the type ('Removes 1 Magic effect')",
  ns.BarTypeInTooltip({ lines = { { leftText = "Purge" }, { leftText = "Removes 1 Magic effect." } } }) == nil)
check("no English school word: nothing is guessed", ns.BarSchoolInText("Inflige 10 points de dégâts de Feu.") == nil)

-- 4. colour styles (preconfigured themes + Custom)
local function hsv(r, g, b2) local mx, mn = math.max(r, g, b2), math.min(r, g, b2); local d = mx - mn
  local h = 0; if d > 0 then if mx == r then h = ((g - b2) / d) % 6 elseif mx == g then h = (b2 - r) / d + 2 else h = (r - g) / d + 4 end; h = h / 6 end
  return h, mx > 0 and d / mx or 0, mx end
local h0, s0, v0 = hsv(0.9, 0.4, 0.1)
for _, st in ipairs({ "neon", "pastel", "muted" }) do
  local r, g, b2 = ns.BarTypeColor("Fire", st)
  local h1, s1, v1 = hsv(r, g, b2)
  local moved = (st == "neon" and s1 > s0 and v1 >= v0) or (st == "pastel" and s1 < s0 and v1 > v0) or (st == "muted" and s1 < s0 and v1 < v0)
  check(ns.BAR_STYLE_LABEL[st] .. ": same hue, saturation / brightness moved", near(h0, h1) and moved, ("%.3f %.3f %.3f"):format(h1, s1, v1))
end
check("the styles are Blizzard default, Neon, Pastel, Muted / Dark, Custom", table.concat(ns.BAR_STYLES, ",") == "blizzard,neon,pastel,muted,custom")
ns.SetBarColorStyle("custom")
local r0 = ns.BarTypeColor("Fire")
check("Custom with no pick yet: the type shows Blizzard's colour", near(r0, 0.9))
ns.SetBarCustomColor("Fire", 0.1, 0.8, 0.2, 1)
TIP = { lines = { { leftText = "x" }, { leftText = "Deals 50 Fire damage." } } }
ns.BarForgetTooltipTypes()
step({ buffRef = ref })
check("Custom: the picked Fire colour is drawn", rec.color and near(rec.color[1], 0.1) and near(rec.color[2], 0.8) and near(rec.color[3], 0.2))
ns.SetBarColorStyle("neon")
step({ buffRef = ref })
check("switching the style repaints the bar (Neon Fire, not Custom)", rec.color and not near(rec.color[2], 0.8))
CueRulesDB.ui.barColors = nil; ns.barColorVersion = (ns.barColorVersion or 0) + 1

-- 5. values: reverse, direction, cooldown, stacks
b.reverse = true; ns.RefreshVisual(cue)
local ref3 = { unit = "player", expiration = now + 3, duration = 10 }
step({ buffRef = ref3 })
check("Fill up instead of draining: 3 s of 10 left shows 0.7", near(fr.barF:GetValue(), 0.7), fr.barF:GetValue())
b.reverse = false
b.dir = "right"; ns.RefreshVisual(cue)
check("Drains toward the right: the bar fills from its right edge (reverse fill), spark on the fill's left edge",
  select(2, ns.BarOrient(b)) == true and select(3, fr.barSpark:GetPoint(1)) == "LEFT")
b.dir = "left"
b.source = "cooldown"; P.spellID = 203720; P.useCooldown = true
cue.spellID = P.spellID   -- (Cues.lua EvaluateCue copies the rule's spell to its cues every step)
ns.RefreshVisual(cue)
rec.timer = nil
step({ cd = { known = true, onCd = true, max = 1 } })
check("a cooldown bar is driven by the game from the cooldown's duration object (remaining time)",
  rec.timer and rec.timer[1] == CD_DUR and rec.timer[3] == Enum.StatusBarTimerDirection.RemainingTime, rec.timer and tostring(rec.timer[3]) or "no timer")
rec.timer = nil
step({ cd = { known = true, onCd = false, max = 1, atMax = true } })
check("cooldown ready: no timer, the bar shows no time remaining", rec.timer == nil and near(fr.barF:GetValue(), 0))
b.source = "stacks"; b.max = 5; ns.RefreshVisual(cue)
step({ buffRef = { unit = "player", applications = 3 } })
check("a stacks bar with Maximum 5: 3 stacks fill three fifths", near(fr.barF:GetValue(), 0.6), fr.barF:GetValue())
b.max = 0
local oldMax = ns.AuraMaxStacks; ns.AuraMaxStacks = function() return nil end
step({ buffRef = { unit = "player", applications = 3 } })
check("a stacks bar with no maximum from anywhere stays empty (never guessed)", near(fr.barF:GetValue(), 0))
ns.AuraMaxStacks = function() return 4 end
step({ buffRef = { unit = "player", applications = 3 } })
check("Maximum 0 uses the game's maximum stacks (4): 3 of 4", near(fr.barF:GetValue(), 0.75))
ns.AuraMaxStacks = oldMax
b.source = "charges"; b.max = 0
step({ cd = { known = true, max = 3, count = 2 } })
check("a charges bar: 2 of 3 charges", near(fr.barF:GetValue(), 2 / 3))
b.source = "auto"; P.spellID = 0; P.useCooldown = false
b.icon = "none"; ns.RefreshVisual(cue)
check("Icon None: no icon, the bar fills the whole display", not fr.barIcon:IsShown() and select(4, fr.barF:GetPoint(1)) == 0)
b.icon = "left"; ns.RefreshVisual(cue)

-- 6. the editor
local built = ns.BuildOptionsTable and ns.BuildOptionsTable()
local function findAll(root, pred)
  local out, seen, stack = {}, {}, { root }
  while #stack > 0 do
    local t = table.remove(stack)
    if type(t) == "table" and not seen[t] then
      seen[t] = true
      if pred(t) then out[#out + 1] = t end
      for _, x in pairs(t) do if type(x) == "table" then stack[#stack + 1] = x end end
    end
  end
  return out
end
check("settings window built", built ~= nil)
if built then
  local box = findAll(built, function(t) return type(t.args) == "table" and type(t.args.bar) == "table" and t.args.bar.name == "Bar Options" end)[1]
  check("the Bar cue has its Bar Options box on the Cues tab", box ~= nil)
  if box then
    local a = box.args.bar.args
    check("...with what it tracks, maximum, drain direction, fill up, texture, colour, icon, spark, background, border",
      a.source and a.max and a.dir and a.reverse and a.texture and a.colorMode and a.color and a.icon and a.spark and a.bg and a.border)
    local src = a.source.values
    check("...Tracks offers Automatic, Aura time left, Spell cooldown / recharge, Stacks, Charges",
      src.auto and src.aura and src.cooldown and src.stacks and src.charges)
    local tb = box.args.bartext and box.args.bartext.args
    check("...and a Text box with name, time and count (no absorb: not in her list)", tb and tb.name and tb.dur and tb.cnt and tb.abs == nil)
    check("...then Position", box.args.pos ~= nil)
    check("no 'Custom cues will run your own Lua' note on a Bar cue", box.args.custom == nil)
  end
  local add = findAll(built, function(t) return t.name == "Add a cue" and type(t.values) == "table" end)[1]
  check("'Add a cue' lists Bar", add and add.values.bar == "Bar")
  local st = findAll(built, function(t) return t.name == "Colour style" and type(t.values) == "function" end)[1]
  local vals = st and st.values()
  check("Settings > UI Options: Colour style with the five styles", vals and vals.blizzard and vals.neon and vals.pastel and vals.muted and vals.custom)
  local pickers = findAll(built, function(t) return t.type == "color" and type(t.hidden) == "function" and type(t.set) == "function" and ns.BAR_TYPE_LABEL[t.name] ~= nil end)
  check("Custom: a colour picker for each of the 12 types", #pickers == 12, #pickers)
  check("the pickers show only for Custom", pickers[1] and pickers[1].hidden() == true)
  -- the new-rule picker's Progress Bar row makes a rule with a Bar cue (before: a shelved Buff Bar that drew nothing)
  local row = findAll(built, function(t) return type(t.name) == "string" and t.name:find("Progress Bar", 1, true)
    and (type(t.func) == "function" or (type(t.arg) == "table" and type(t.arg.xuiRow) == "function")) end)[1]
  check("the new-rule picker has a Progress Bar row", row ~= nil)
  if row then
    local before = #ns.rules
    pcall(row.func or row.arg.xuiRow)
    local made
    for i = before + 1, #ns.rules do local r = ns.rules[i]; if r.isCue and r.cueKind == "bar" then made = r end end
    check("...which makes a rule with a Bar cue", made ~= nil and made.visual.kind == "bar" and made.visual.w == 220)
  end
end
check("Smart Categories: the rule is under Progress Bars, not Textures", ns.SmartMatch(P, "smart_bar") and not ns.SmartMatch(P, "smart_tex"))
return R
end
'''


def part_a():
    folders = H.find_addons()
    enabled = [n for n in folders if n != "XayaUI_DevAssist"]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    L.globals().STUBS_SRC = STUBS
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA_A, world, loader)
    for i in range(1, len(res) + 1):
        check("A: " + res[i][1], res[i][2])
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    check("A: no Lua errors in the stand-in game", not errs, len(errs))


# ---------------------------------------------------------------- Part B: the combat engine
def part_b():
    src = open(os.path.join(HERE, "aura_display_run.py"), encoding="utf-8").read()
    m = re.search(r"L\.execute\(r'''\n(.*?)'''\.replace\(\"AURA_DISPLAY_PATH\"", src, re.S)
    if not m:
        check("B: the engine stand-in was found in tests/aura_display_run.py", False)
        return
    block = m.group(1)
    cues = open(os.path.join(ROOT, "XayaUI", "Cues.lua"), encoding="utf-8").read()
    cg = re.search(r"^function ns\.CueGated\(p, cue\)\n.*?^end\n", cues, re.S | re.M)
    # the aura button setters a Bar uses (Blizzard_CustomAuraButton.lua 12.1.5: object types as the game checks them)
    extra = r'''
    function b:SetApplicationBar(bar, opts) assert(bar._kind == "StatusBar", "SetApplicationBar needs a StatusBar"); assert(type(opts) == "table" and type(opts.maxApplications) == "number", "maxApplications"); self.log.appBar, self.log.appOpts = bar, opts end
    function b:SetSpellName(fs) assert(fs._kind == "FontString", "SetSpellName needs a FontString"); self.log.spellName = fs end
    function b:AddDispelTypeTexture(tex, opts) assert(tex._kind == "Texture", "AddDispelTypeTexture needs a Texture"); assert(type(opts) == "table"); self.log.dispel, self.log.dispelOpts = tex, opts end
    return b
end
'''
    n0 = block.count("    return b\nend\n")
    block = block.replace("    return b\nend\n", extra, 1)
    block = block.replace("function b:SetOrientation(o)", "function b:SetStatusBarColor(r, g, bl, a) self.color = { r, g, bl, a } end\n        function b:SetOrientation(o)", 1)
    pre = r'''
CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a, GetRGB = function(s) return s.r, s.g, s.b end, GetRGBA = function(s) return s.r, s.g, s.b, s.a end } end
'''
    post_env = r'''
Enum.CustomAuraButtonDispelTypeTextureStyle = { Border = 0, BorderWithIcon = 1, Icon = 2, PreserveAsset = 3, CustomAsset = 4 }
Enum.Damageclass = { MaskFire = 4, MaskShadow = 32, MaskPhysical = 1, MaskHoly = 2, MaskNature = 8, MaskFrost = 16, MaskArcane = 64 }
''' + STUBS + r'''
C_Spell.GetSpellTexture = function() return 134400 end
C_Spell.GetSpellName = function() return "Test Aura" end
function NS.AuraMaxStacks() return nil end
assert(loadfile(BARCUE_PATH))("XayaUI", NS)
'''
    block = block.replace("local f = assert(loadfile(AURA_DISPLAY_PATH))", post_env + "local f = assert(loadfile(AURA_DISPLAY_PATH))", 1)
    block = (pre + block).replace("AURA_DISPLAY_PATH", repr(os.path.join(ROOT, "XayaUI", "Combat", "AuraDisplay.lua")).replace("'", '"'))
    block = block.replace("BARCUE_PATH", repr(os.path.join(ROOT, "XayaUI", "BarCue.lua")).replace("'", '"'))
    block = block.replace("CUE_GATED_SRC", "[==[" + "local ns = NS\n" + cg.group(0) + "]==]")
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    check("B: the engine stand-in was found and extended", n0 >= 1)
    try:
        L.execute(block)
    except Exception as e:  # noqa: BLE001
        check("B: the engine and BarCue.lua load in the stand-in", False, str(e)[:300])
        return
    lua = L.execute
    lua(r'''
local ns = NS
ns.folders = { { id = "fG", name = "Bars group", cType = "dynamic", cGrowth = "DOWN", cSpacing = 2, cW = 0, cH = 0, cPoint = "CENTER" } }
local n = 0
function BAR(name, folder, id, barExtra, ruleExtra)
  n = n + 1
  local p = { uid = "p" .. n, name = name, folder = folder, useBuff = true, buffID = id, buffState = "present", cdState = "none", enabled = true, visual = { enabled = false } }
  for k, v in pairs(ruleExtra or {}) do p[k] = v end
  local c = { uid = "c" .. n, name = name .. " bar", folder = folder, isCue = true, cueKind = "bar", parentUid = p.uid, cueKey = "q" .. n,
    visual = { enabled = true, trigger = "condition", text = { enabled = true, size = 12 }, count = { enabled = false } } }
  ns.InitBarCue(c)
  for k, v in pairs(barExtra or {}) do c.visual.bar[k] = v end
  ns.rules[#ns.rules + 1] = p; ns.rules[#ns.rules + 1] = c
  return p, c
end
ns.rules = {}
BA, BAc = BAR("aura bar", nil, 7001)
BS, BSc = BAR("stacks bar", nil, 7002, { source = "stacks", max = 5 })
BC, BCc = BAR("cooldown bar", nil, 7003, { source = "cooldown" }, { spellID = 7103 })
BN, BNc = BAR("stacks bar without maximum", nil, 7004, { source = "stacks", max = 0 })
G1, G1c = BAR("group bar 1", "fG", 7011)
G2, G2c = BAR("group bar 2", "fG", 7012)
TIP = nil
evHandler("PLAYER_ENTERING_WORLD")
function LASTBTN(rec) return rec.btns and rec.btns[#rec.btns] end
function SLOT(r) return NS.AuraDisplay._singles[r] end
''')
    own = lambda r: lua("return NS.EngineOwns(%s) == true" % r)
    check("B: an aura-time bar is drawn by the engine (single slot sized 220 x 22)",
          own("BAc") and lua("local s = SLOT(BA); return s and s.ok and s.frame.groups.main.layout.elementWidth == 220 and s.frame.groups.main.layout.elementHeight == 22"))
    check("B: its button gets a status bar the game drives from the aura's duration (remaining time = drains)",
          lua("local b = LASTBTN(SLOT(BA)); return b and b.log.bar and b.log.bar._kind == 'StatusBar' and b.log.barOpts.direction == Enum.StatusBarTimerDirection.RemainingTime"))
    check("B: ...flat texture, horizontal, filling from the left (drains toward the left edge)",
          lua("local bar = LASTBTN(SLOT(BA)).log.bar; return bar.texPath == 'Interface\\\\Buttons\\\\WHITE8X8' and bar.orient == 'HORIZONTAL' and bar.reverse == false"))
    check("B: ...the aura's icon and name are painted by the game (SetIcon, SetSpellName)",
          lua("local b = LASTBTN(SLOT(BA)); return b.log.icon ~= nil and b.log.spellName ~= nil"))
    check("B: no tooltip type: the game colours the fill by dispel type, 'None' = the fixed blue",
          lua("local b = LASTBTN(SLOT(BA)); local o = b.log.dispelOpts; return b.log.dispel == b.log.bar.tex and o.showAlways == true and o.style == 3 and math.abs(o.customDispelColorMap.None.r - 0.25) < 1e-6 and math.abs(o.customDispelColorMap.Magic.b - 0.95) < 1e-6"))
    check("B: a stacks bar uses the game's stack bar (SetApplicationBar, maximum 5), not the duration bar",
          lua("local b = LASTBTN(SLOT(BS)); return b and b.log.appBar and b.log.appOpts.maxApplications == 5 and b.log.bar == nil"))
    check("B: a cooldown bar stays with XayaUI, with its reason", (not own("BCc")) and lua("for _, e in ipairs(NS.AuraDisplay._Left()) do if e[1] == BC and tostring(e[2]):find('cooldown', 1, true) then return true end end return false"))
    check("B: a stacks bar with no maximum stays with XayaUI (empty, never guessed)", not own("BNc"))
    check("B: two bars in one dynamic group: both members' buttons are bars",
          lua("local g = NS.AuraDisplay._groups.fG; if not (g and g.ok) then return false end; for i = 1, 2 do local grp = g.frame.groups[g.memberKey[i]]; if not (grp and grp.layout.elementWidth == 220) then return false end end; local n = 0; for _, b in ipairs(buttons) do if b.log.bar then n = n + 1 end end; return n >= 6"))
    # parity: the same colour decision on both paths (V11)
    lua(r'''
TIP = { lines = { { leftText = "Test Aura" }, { leftText = "Deals 10 Fire damage." } } }
NS.BarForgetTooltipTypes()
BAc.visual.w = 221   -- a look change makes a new slot (LookKey)
NS.AuraDisplay.Build()
''')
    check("B: parity: a tooltip that names Fire gives the engine bar the same colour XayaUI's own bar gets, and no dispel colouring",
          lua("local b = LASTBTN(SLOT(BA)); local r, g, bl = NS.BarCueColor(BAc, nil); return b.log.bar.color and math.abs(b.log.bar.color[1] - r) < 1e-6 and math.abs(b.log.bar.color[2] - g) < 1e-6 and math.abs(b.log.bar.color[1] - 0.9) < 1e-6 and b.log.dispel == nil"))
    lua('BAc.visual.bar.colorMode = "fixed"; BAc.visual.bar.color = { 0.5, 0.1, 0.6, 1 }; BAc.visual.w = 222; NS.AuraDisplay.Build()')
    check("B: parity: a fixed colour is used as it is on both paths",
          lua("local b = LASTBTN(SLOT(BA)); return math.abs(b.log.bar.color[1] - 0.5) < 1e-6 and math.abs(b.log.bar.color[3] - 0.6) < 1e-6 and b.log.dispel == nil and select(5, NS.BarCueColor(BAc)) == 'fixed'"))


def main():
    part_a()
    part_b()
    bad = sum(1 for _, ok in RESULTS if not ok)
    print("%d checks, %d failed" % (len(RESULTS), bad))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
