"""Actions > Glow a frame: every glow type LibCustomGlow offers (button, pixel, autocast, proc) with its own settings, and a color that
carries transparency (#249; Xaya 2026-11-04: "make sure support for each type is available in addition to colorizing and opacity /
positioning options"). The color picker offers opacity; offsets, layer and each type's settings reach the library; a setting left
empty passes nil (the library's default); a type's settings show only for that type; damaged saved values never reach the library. LibCustomGlow (installed by other addons) is replaced by a stand-in that records the color
it is handed; the library's own handling of the fourth value was read in its public source (LibCustomGlow-1.0 MINOR 25: pixel,
autocast and proc glows use it in SetVertexColor, the button glow in its alpha animation; see the debug log).
Run: python3 tests/action_glow_alpha_run.py   Needs: pip install lupa."""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
L = runtime()
L.execute(r'''
fails, n = 0, 0
function check(name, cond, extra)
  n = n + 1
  if cond then print("ok:   " .. name) else fails = fails + 1; print("FAIL: " .. name .. (extra ~= nil and ("  -> " .. tostring(extra)) or "")) end
end
printed = {}
ns = { MarkDirty = function() end, Print = function(m) printed[#printed + 1] = m end, VisualFramesOf = function() return {} end }
seen = {}   -- the color each glow call received, by glow type
args = {}   -- the other arguments it received
local lib = {
  PixelGlow_Start = function(f, color, ...) seen.pixel = color; args.pixel = { n = select("#", ...), ... } end,
  AutoCastGlow_Start = function(f, color, ...) seen.autocast = color; args.autocast = { n = select("#", ...), ... } end,
  ProcGlow_Start = function(f, opts) seen.proc = opts and opts.color; args.proc = opts end,
  ButtonGlow_Start = function(f, color, ...) seen.button = color; args.button = { n = select("#", ...), ... } end,
  PixelGlow_Stop = function() end, AutoCastGlow_Stop = function() end, ButtonGlow_Stop = function() end, ProcGlow_Stop = function() end,
}
LibStub = function(name, silent) if name == "LibCustomGlow-1.0" then return lib end end
TestFrame = { GetObjectType = function() return "Frame" end }
''')
L.execute('assert(loadfile(%r))("XayaUI", ns)' % os.path.join(ROOT, "XayaUI", "Actions.lua").replace("\\", "/"))
L.execute(r'''
local rule = { name = "Glow test", actions = { start = { glowOn = true, glowTarget = "frame", glowFrame = "TestFrame" } } }
local pane = ns.ActionsPane(rule, function() end)
local opt = pane.start and pane.start.args and pane.start.args.glowColor
check("the glow color option exists on the During moment", opt ~= nil)
check("the glow color picker offers opacity (hasAlpha)", opt and opt.hasAlpha == true, opt and tostring(opt.hasAlpha))

-- a glow saved before this change (no opacity stored) is drawn fully opaque, as before
for _, t in ipairs({ "button", "pixel", "autocast", "proc" }) do
  rule.actions.start.glowType = t; seen[t] = nil
  ns.RunActions(rule, "start")
  local c = seen[t]
  check("no opacity saved: the " .. t .. " glow is drawn opaque (alpha 1)", c and c[4] == 1, c and tostring(c[4]))
end
local r, g, b, a = opt.get()
check("no opacity saved: the picker shows the default color at full opacity", r == 0.95 and g == 0.95 and b == 0.32 and a == 1,
  table.concat({ tostring(r), tostring(g), tostring(b), tostring(a) }, " "))

-- picking a half-transparent red: saved, shown back, and every glow type is drawn with it
opt.set(nil, 1, 0, 0, 0.4)
r, g, b, a = opt.get()
check("the picker shows the picked color and opacity back (1, 0, 0, 0.4)", r == 1 and g == 0 and b == 0 and a == 0.4,
  table.concat({ tostring(r), tostring(g), tostring(b), tostring(a) }, " "))
for _, t in ipairs({ "button", "pixel", "autocast", "proc" }) do
  rule.actions.start.glowType = t; seen[t] = nil
  ns.RunActions(rule, "start")
  local c = seen[t]
  check("opacity 0.4: the " .. t .. " glow is drawn red at alpha 0.4", c and c[1] == 1 and c[2] == 0 and c[3] == 0 and c[4] == 0.4,
    c and table.concat({ tostring(c[1]), tostring(c[2]), tostring(c[3]), tostring(c[4]) }, " "))
end

-- back to fully opaque: nothing extra is kept in the saved rule
opt.set(nil, 1, 0, 0, 1)
check("opacity back to 1: no opacity value stays in the saved rule", rule.actions.start.glowA == nil, tostring(rule.actions.start.glowA))
-- a damaged saved value never breaks the glow: it is drawn opaque
rule.actions.start.glowA = "x"; rule.actions.start.glowType = "pixel"; seen.pixel = nil
ns.RunActions(rule, "start")
check("a non-number opacity in the saved rule draws an opaque glow", seen.pixel and seen.pixel[4] == 1, seen.pixel and tostring(seen.pixel[4]))
rule.actions.start.glowA = 7; seen.pixel = nil
ns.RunActions(rule, "start")
check("an opacity above 1 in the saved rule is drawn at 1", seen.pixel and seen.pixel[4] == 1, seen.pixel and tostring(seen.pixel[4]))

-- ===== each glow type's own settings =====
local A = rule.actions.start
for k in pairs(A) do if k ~= "glowOn" and k ~= "glowTarget" and k ~= "glowFrame" then A[k] = nil end end
local args_ = pane.start.args
local function S(key, v) args_[key].set(nil, v) end
local function shown(key) return args_[key] ~= nil and not args_[key].hidden() end
local function run(t) A.glowType = t; args[t] = nil; ns.RunActions(rule, "start"); return args[t] end
local function s(v) return tostring(v) end

-- nothing set: every setting is nil, so the library uses its own defaults
local p = run("pixel")
check("pixel, nothing set: lines, speed, length, thickness, offsets, border all nil (library defaults); key XayaUI; layer nil",
  p and p[1] == nil and p[2] == nil and p[3] == nil and p[4] == nil and p[5] == nil and p[6] == nil and p[7] == nil and p[8] == "XayaUI" and p[9] == nil,
  p and table.concat({ s(p[1]), s(p[2]), s(p[3]), s(p[4]), s(p[5]), s(p[6]), s(p[7]), s(p[8]), s(p[9]) }, ","))
local ac = run("autocast")
check("autocast, nothing set: groups, speed, scale, offsets nil; key XayaUI; layer nil",
  ac and ac[1] == nil and ac[2] == nil and ac[3] == nil and ac[4] == nil and ac[5] == nil and ac[6] == "XayaUI" and ac[7] == nil)
local pr = run("proc")
check("proc, nothing set: offsets, loop length, start flash, layer nil (library defaults), key XayaUI",
  pr and pr.xOffset == nil and pr.yOffset == nil and pr.duration == nil and pr.startAnim == nil and pr.frameLevel == nil and pr.key == "XayaUI")
local bt = run("button")
check("button, nothing set: speed and layer nil", bt and bt[1] == nil and bt[2] == nil)

-- the settings window shows a type's settings only for that type
A.glowType = "button"
check("button: Speed and Layer shown; no offsets (the library cannot move the button glow); no pixel / autocast / proc settings",
  shown("btnFreq") and shown("glowLevel") and not shown("glowX") and not shown("glowY") and not shown("pixN") and not shown("acN") and not shown("procDur"))
A.glowType = "pixel"
check("pixel: offsets, layer, lines, speed, length, thickness, dark border shown; no button / autocast / proc settings",
  shown("glowX") and shown("glowY") and shown("glowLevel") and shown("pixN") and shown("pixFreq") and shown("pixLen") and shown("pixTh")
  and shown("pixBorder") and not shown("btnFreq") and not shown("acN") and not shown("procDur"))
A.glowType = "autocast"
check("autocast: offsets, layer, sparkle groups, speed, size shown; no pixel settings",
  shown("glowX") and shown("acN") and shown("acFreq") and shown("acScale") and not shown("pixN") and not shown("pixBorder"))
A.glowType = "proc"
check("proc: offsets, layer, loop length, start flash shown", shown("glowX") and shown("glowY") and shown("procDur") and shown("procStart") and not shown("acN"))
A.glowOn = nil
check("glow switched off: none of the glow settings are shown", not shown("glowX") and not shown("procDur") and not shown("glowColor"))
A.glowOn = true
check("After It Ends (stop a glow) has no glow type settings", pane.finish.args.glowX == nil and pane.finish.args.pixN == nil)

-- set through the settings window, and drawn with them
S("glowX", 5); S("glowY", -3); S("glowLevel", 12)
S("pixN", 12); S("pixFreq", -0.5); S("pixLen", 10); S("pixTh", 3); args_.pixBorder.set(nil, false)
p = run("pixel")
check("pixel: 12 lines, speed -0.5 (reversed), length 10, thickness 3, offset 5 / -3, no border, layer 12",
  p and p[1] == 12 and p[2] == -0.5 and p[3] == 10 and p[4] == 3 and p[5] == 5 and p[6] == -3 and p[7] == false and p[9] == 12,
  p and table.concat({ s(p[1]), s(p[2]), s(p[3]), s(p[4]), s(p[5]), s(p[6]), s(p[7]), s(p[9]) }, ","))
S("acN", 6); S("acFreq", 0.3); S("acScale", 1.5)
ac = run("autocast")
check("autocast: 6 groups, speed 0.3, size 1.5, offset 5 / -3, layer 12",
  ac and ac[1] == 6 and ac[2] == 0.3 and ac[3] == 1.5 and ac[4] == 5 and ac[5] == -3 and ac[7] == 12)
S("btnFreq", 0.5)
bt = run("button")
check("button: speed 0.5, layer 12 (and no offset is passed)", bt and bt[1] == 0.5 and bt[2] == 12 and bt.n == 2, bt and s(bt.n))
S("procDur", 2); args_.procStart.set(nil, false)
pr = run("proc")
check("proc: loop 2 s, no start flash, offset 5 / -3, layer 12",
  pr and pr.duration == 2 and pr.startAnim == false and pr.xOffset == 5 and pr.yOffset == -3 and pr.frameLevel == 12)
check("the settings show back what was set", args_.pixN.get() == 12 and args_.pixBorder.get() == false and args_.procStart.get() == false and args_.glowX.get() == 5)

-- speed 0 and length 0 mean "the library's default"; a value equal to the default is not kept
S("pixFreq", 0); S("pixLen", 0); S("pixN", 8)
p = run("pixel")
check("pixel speed 0 and length 0 pass nil (library default); lines back at 8 keeps nothing", p[2] == nil and p[3] == nil and A.pixN == nil and A.pixFreq == nil)
args_.pixBorder.set(nil, true); args_.procStart.set(nil, true)
check("border and start flash back on: nothing kept", A.pixBorder == nil and A.procStart == nil)
S("acN", 4); S("acFreq", 0); S("acScale", 1)
check("set back to the defaults, nothing is kept and the sliders show the library defaults (lines 8, speed 0.25, groups 4, speed 0.125, size 1)",
  A.acN == nil and A.acFreq == nil and A.acScale == nil and args_.pixN.get() == 8 and args_.pixFreq.get() == 0.25 and args_.acN.get() == 4
  and args_.acFreq.get() == 0.125 and args_.acScale.get() == 1,
  table.concat({ s(A.acN), s(A.acFreq), s(A.acScale), s(args_.pixN.get()), s(args_.pixFreq.get()), s(args_.acN.get()), s(args_.acFreq.get()), s(args_.acScale.get()) }, ","))

-- damaged or out-of-range saved values never reach the library
A.pixN = "lots"; A.glowX = 999; A.glowY = -999; A.pixTh = 0/0
p = run("pixel")
check("damaged values: a word passes nil, offsets are kept inside -40..40, NaN passes nil", p[1] == nil and p[5] == 40 and p[6] == -40 and p[4] == nil,
  table.concat({ s(p[1]), s(p[5]), s(p[6]), s(p[4]) }, ","))
print(("%d checks, %d failed"):format(n, fails))
''')
sys.exit(1 if L.eval("fails") else 0)
