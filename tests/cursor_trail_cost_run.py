# Cost and look test for XayaUI_QoL CursorTrail.lua (the Gradient Cursor Trail), Lua 5.1 with a stand-in game world.
# Why (Xaya, 2026-11-04): "right clicking mouse with the cursor shape enabled makes cursor less responsive", "I need cursor and
# performance improvements if I want to be able to play". Her saved settings: the trail on, shape "line" (the smooth line), size 13,
# length 0.2 s, hide while turning on (the Cursor Highlight is off).
# Measured: texture calls per rendered frame and the most dots shown at once, at 60 frames a second while the cursor sweeps a circle
# at a brisk (2,000 px/s) and a fast (5,000 px/s) speed. Counts are from the stand-in (every texture method call), not game timings.
# Before QoL 0.7.13 (same stand-in): 900.6 / 1,621.5 calls a frame and 217 / 401 dots.
# Checks (outcomes):
#   - cost at 5,000 px/s within BUDGET (about 10% above what 0.7.13 measures);
#   - the smooth line stays one band: every shown dot of the band has a neighbour within half its own width (no gaps; the round
#     head at the cursor is left out: it runs half a frame's movement ahead of the band by design, in the old code too);
#   - dots fade out within the chosen length once the cursor stops; nothing is drawn while the camera turns (hide while turning on).
# Deliberate breaks (BREAKS): each must make at least one check fail. The last line carries FAILS: <n>.
# Run: python3 tests/cursor_trail_cost_run.py [--report]   (--report prints the numbers only)
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SRC = open(os.path.join(ROOT, "XayaUI_QoL", "CursorTrail.lua"), encoding="utf-8").read()
REPORT = "--report" in sys.argv
BUDGET = {"calls_avg": 760, "calls_max": 980, "live_max": 345}
GAP_RATIO = 0.5   # nearest shown neighbour within half the dot's own width

WORLD = r'''
CALLS = 0
local REG = {}
REG.__index = function(t, k)
  if k == "Show" then return function(self) CALLS = CALLS + 1; self.shown = true end end
  if k == "Hide" then return function(self) CALLS = CALLS + 1; self.shown = false end end
  if k == "IsShown" then return function(self) CALLS = CALLS + 1; return self.shown == true end end
  if k == "SetPoint" then return function(self, p, rel, rp, x, y) CALLS = CALLS + 1; self.x, self.y = x, y end end
  if k == "SetSize" then return function(self, w) CALLS = CALLS + 1; self.w = w end end
  if type(k) == "string" and k:match("^%u") then return function() CALLS = CALLS + 1 end end
  return nil
end
REGIONS = {}
local function region(kind) local r = setmetatable({ kind = kind }, REG); REGIONS[#REGIONS + 1] = r; return r end
local FR = {}
FR.__index = function(t, k)
  if k == "CreateTexture" then return function() return region("tex") end end
  if k == "CreateMaskTexture" then return function() return region("mask") end end
  if k == "CreateLine" then return function() return region("line") end end
  if k == "SetScript" then return function(self, n, f) self.scripts[n] = f end end
  if type(k) == "string" and k:match("^%u") then return function() end end
  return nil
end
FRAMES_SEEN = {}
CreateFrame = function() local f = setmetatable({ scripts = {} }, FR); FRAMES_SEEN[#FRAMES_SEEN + 1] = f; return f end
UIParent = CreateFrame()
UIParent.GetEffectiveScale = function() return 1 end
NOW = 100
GetTime = function() return NOW end
CX, CY = 800, 500
GetCursorPosition = function() return CX, CY end
LOOK = false
IsMouselooking = function() return LOOK end
CueRulesDB = { cursorTrail = { enabled = true, shape = "line", size = 13, length = 0.2, opacity = 1, reverse = true,
  preset = "fel", hideMouselook = true, customN = 5 } }
XayaUI_NS = { RegisterSettingsPage = function() end, WhenReady = function(f) f() end, RegisterCommand = function() end }
function SHOWN()
  local n = 0
  for _, r in ipairs(REGIONS) do if r.kind == "tex" and r.shown then n = n + 1 end end
  return n
end
-- the largest (distance to the nearest other shown dot) / (own width) over all shown dots
function GAP()
  local list = {}
  -- the band's dots only: the first texture made is the line's round head, drawn at the cursor itself, which by design runs half a
  -- frame's movement ahead of the band (the band's curve ends at the midpoint of the last two cursor samples), so it is left out
  local firstTex
  for _, r in ipairs(REGIONS) do if r.kind == "tex" then firstTex = r; break end end
  for _, r in ipairs(REGIONS) do if r.kind == "tex" and r ~= firstTex and r.shown and r.x and r.w then list[#list + 1] = r end end
  local worst = 0
  for i, a in ipairs(list) do
    local best
    for j, b in ipairs(list) do
      if i ~= j then local d = math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2); if not best or d < best then best = d end end
    end
    if best and a.w > 0 then worst = math.max(worst, best / a.w) end
  end
  return worst
end
'''


def run(src, speed, moving=60, still=0, look=0):
    lua = LuaRuntime()
    lua.globals().SRC = src
    lua.execute(WORLD)
    lua.execute('local ns = XayaUI_NS; assert(loadstring(SRC, "@CursorTrail.lua"))("XayaUI_QoL", ns); ns.CursorTrail_Apply()')
    lua.execute('OU = nil; for _, f in ipairs(FRAMES_SEEN) do if f.scripts.OnUpdate then OU = f.scripts.OnUpdate end end')
    if lua.eval("OU") is None:
        raise RuntimeError("the trail never set its OnUpdate")
    per, shown_max, gap = [], 0, 0.0
    r, dt = 300.0, 1 / 60
    omega = speed / r
    for i in range(moving + still + look):
        if i < moving:
            ang = omega * i * dt
            lua.execute("CX, CY = %f, %f" % (800 + r * math.cos(ang), 500 + r * math.sin(ang)))
        lua.execute("LOOK = %s" % ("true" if i >= moving + still else "false"))
        lua.execute("NOW = NOW + %f; CALLS = 0; OU()" % dt)
        per.append(int(lua.eval("CALLS")))
        shown_max = max(shown_max, int(lua.eval("SHOWN()")))
        if i == moving - 1:
            gap = float(lua.eval("GAP()"))
    return {"per": per, "shown_max": shown_max, "gap": gap, "shown_end": int(lua.eval("SHOWN()"))}


def check_all(src):
    """returns (failures list, report lines)"""
    fails, lines = [], []
    for speed in (2000, 5000):
        res = run(src, speed)
        avg, mx = sum(res["per"]) / len(res["per"]), max(res["per"])
        lines.append("moving %4d px/s: %6.1f calls/frame avg, %4d max, %3d dots shown at most, widest gap %.2f of a dot"
                     % (speed, avg, mx, res["shown_max"], res["gap"]))
        if res["gap"] > GAP_RATIO:
            fails.append("the smooth line breaks into dots at %d px/s (gap %.2f > %.2f)" % (speed, res["gap"], GAP_RATIO))
        if speed == 5000:
            if avg > BUDGET["calls_avg"]: fails.append("avg %.1f calls/frame > budget %d" % (avg, BUDGET["calls_avg"]))
            if mx > BUDGET["calls_max"]: fails.append("max %d calls/frame > budget %d" % (mx, BUDGET["calls_max"]))
            if res["shown_max"] > BUDGET["live_max"]: fails.append("%d dots > budget %d" % (res["shown_max"], BUDGET["live_max"]))
    res = run(src, 5000, moving=30, still=30)
    last = sum(res["per"][-10:]) / 10
    lines.append("cursor still for 0.5 s: %d dots shown, %.1f calls/frame" % (res["shown_end"], last))
    if res["shown_end"] != 0: fails.append("dots still shown 0.5 s after the cursor stopped (length 0.2 s)")
    res = run(src, 5000, moving=30, look=30)
    last = sum(res["per"][-10:]) / 10
    lines.append("camera turning 0.5 s: %d dots shown, %.1f calls/frame" % (res["shown_end"], last))
    if res["shown_end"] != 0: fails.append("the trail still draws while the camera turns (hide while turning is on)")
    return fails, lines


BREAKS = [
    ("the old dense spacing (0.15 of the width)", "size * 0.25) or math.max(2, size * 0.35)", "size * 0.15) or math.max(2, size * 0.35)"),
    ("asking the game IsShown every frame", "if not d.shown then t:Show(); d.shown = true end", "if not t:IsShown() then t:Show(); d.shown = true end"),
    ("spacing so wide the band breaks", "size * 0.25) or math.max(2, size * 0.35)", "size * 0.9) or math.max(2, size * 0.35)"),
]

fails, lines = check_all(SRC)
print("\n".join(lines))
total = 0
if not REPORT:
    for f in fails:
        print("FAIL  " + f)
    total = len(fails)
    for name, old, new in BREAKS:
        if SRC.count(old) != 1:
            print("BREAK %r: text not found exactly once" % name); total += 1; continue
        bf, _ = check_all(SRC.replace(old, new))
        if not bf:
            print("BREAK %r: no check failed" % name); total += 1
print("%d checks, %d deliberate breaks  FAILS: %d" % (8, len(BREAKS), total))
