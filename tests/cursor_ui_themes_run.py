#!/usr/bin/env python3
"""Cursor trail colors <-> UI themes (core 0.6.46, QoL 0.7.17). Xaya, 2026-11-05: "map cursor theme colors to UI themes and provide
them as theming options as well".
Loads the real addons in the stand-in game (tests/harness, Lua 5.1 via lupa) and checks what the player sees:
  1. Settings > Theme lists one "<name>" theme (core 0.6.54: no "Cursor trail:" prefix) per Gradient Cursor Trail gradient (Theme and Start from lists); picking
     one gives ns.Theme.cur the colors derived by the documented rule (re-computed here in Python from the gradients as they were in
     CursorTrail.lua at b8017df: parity, V5), every other token keeps the XUI default, and every text token reads at 4.5:1 or better
     (WCAG 2.x contrast, computed here) on the window background and on the backgrounds it is drawn on.
  2. With XayaUI_QoL switched off, a saved cursor theme still resolves and the Theme page still lists them.
  3. The trail's "Match the UI theme": the dots drawn on screen take the theme's colors (a cursor theme: exactly its gradient;
     another theme: accentText -> accent -> gradStart), the settings preview strip too, and a theme change recolors them without
     touching the trail's settings.
  4. Cursor Highlight "Use the UI theme's accent": the drawn shape takes the accent and follows theme changes; off: its own color.
  5. V14: with the cursor features off (or on without the theme options) no cursor listener sits in core's theme listener list and a
     theme change makes no cursor frame or trail color work; the listener comes and goes with the options.
  6. Existing users: a saved theme, a saved trail gradient and a saved highlight color draw exactly as before.
Run: python3 tests/cursor_ui_themes_run.py [--report]   (--report also prints the contrast table for the debug log)
"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

REPORT = "--report" in sys.argv
ROOT = os.path.abspath(os.path.join(HERE, ".."))

# The trail gradients exactly as XayaUI_QoL/CursorTrail.lua had them at b8017df (key, name, head first). Must stay unchanged.
PRESETS = {
    "fel":     ("Fel",       [(0.35, 1.00, 0.25), (0.15, 0.80, 0.45), (0.55, 0.20, 0.85)]),
    "fire":    ("Fire",      [(1.00, 0.95, 0.40), (1.00, 0.55, 0.10), (0.85, 0.15, 0.05), (0.25, 0.05, 0.05)]),
    "ocean":   ("Ocean",     [(0.70, 1.00, 1.00), (0.15, 0.75, 0.95), (0.10, 0.35, 0.85), (0.05, 0.10, 0.45)]),
    "aurora":  ("Aurora",    [(0.30, 1.00, 0.60), (0.20, 0.85, 0.95), (0.45, 0.45, 1.00), (0.75, 0.30, 0.95)]),
    "sunset":  ("Sunset",    [(1.00, 0.90, 0.45), (1.00, 0.55, 0.30), (0.95, 0.30, 0.50), (0.55, 0.25, 0.75), (0.20, 0.15, 0.50)]),
    "vapor":   ("Vaporwave", [(1.00, 0.45, 0.85), (0.75, 0.50, 1.00), (0.35, 0.75, 1.00), (0.30, 1.00, 0.90)]),
    "rainbow": ("Rainbow",   [(1.00, 0.20, 0.20), (1.00, 0.70, 0.10), (0.95, 1.00, 0.20), (0.25, 0.90, 0.35), (0.25, 0.55, 1.00), (0.65, 0.30, 0.95)]),
    "gold":    ("Gold",      [(1.00, 0.98, 0.75), (1.00, 0.82, 0.25), (0.80, 0.50, 0.10)]),
    "ice":     ("Frost",     [(1.00, 1.00, 1.00), (0.65, 0.90, 1.00), (0.30, 0.55, 1.00)]),
}
ORDER = ["fel", "fire", "ocean", "aurora", "sunset", "vapor", "rainbow", "gold", "ice"]
# XUI default tokens a cursor theme must leave alone (T.TOKENS defaults), and the default theme's three trail tokens
KEEP = {"text": (0.96, 0.96, 0.98, 1), "textMuted": (0.60, 0.60, 0.65, 1), "windowBg": (0.06, 0.06, 0.06, 1), "paneBg": (0.04, 0.04, 0.04, 1),
        "border": (0.30, 0.30, 0.30, 1), "titleBar": (0.13, 0.13, 0.13, 1), "buttonBg": (0.04, 0.04, 0.04, 0.70),
        "buttonBorder": (0.25, 0.25, 0.25, 1), "tabBg": (0.03, 0.03, 0.03, 0.70), "tabBorder": (0.22, 0.22, 0.22, 1),
        "treeBar": (0.34, 0.34, 0.40, 1), "danger": (1.00, 0.12, 0.12, 1)}
DEFAULT_TRAIL = [(0.78, 0.62, 1.00), (0.75, 0.25, 1.00), (0.30, 0.08, 0.45)]   # XUI default: accentText, accent, gradStart
WIN, BODY, WHITE = KEEP["windowBg"][:3], KEEP["text"][:3], (1.0, 1.0, 1.0)
EPS = 1e-6


# ---- the documented rule, written again here (XayaUI/Theme.lua T.CursorPalette's comment) ---------------------------------------
def lin(v):
    v = min(1.0, max(0.0, v))
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def lum(c): return 0.2126 * lin(c[0]) + 0.7152 * lin(c[1]) + 0.0722 * lin(c[2])


def contrast(a, b):
    la, lb = lum(a), lum(b)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


def mix(a, b, t): return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def over(c, a, bg): return tuple(c[i] * a + bg[i] * (1 - a) for i in range(3))


def lighten(c):
    for i in range(21):
        m = mix(c, WHITE, i * 0.05)
        if contrast(m, WIN) >= 4.5:
            return m + (1.0,)
    return WHITE + (1.0,)


def dark_for(c, top, a, texts):
    k0 = top / max(c[0], c[1], c[2], 0.001)
    for i in range(21):
        k = k0 * (1 - i * 0.05)
        d = tuple(x * k for x in c)
        if all(contrast(t, over(d, a, WIN)) >= 4.5 for t in texts):
            return d + (a,)
    return (0.0, 0.0, 0.0, a)


def palette(stops):
    main = stops[1] if len(stops) > 1 else stops[0]
    lightest = stops[0]
    for s in stops[1:]:
        if lum(s) > lum(lightest):
            lightest = s
    p = {"accent": lighten(main)}
    p["tabSelBorder"] = p["accent"]
    p["accentText"] = lighten(mix(main, WHITE, 0.35))
    p["label"] = lighten(lightest)
    p["buttonText"] = p["label"]
    p["gradStart"] = dark_for(stops[-1], 0.45, 1.0, [BODY, p["accentText"][:3]])
    p["tabSelBg"] = dark_for(main, 0.30, 0.90, [BODY, p["accentText"][:3]])
    p["primaryBg"] = dark_for(main, 0.45, 0.95, [p["buttonText"][:3]])
    p["primaryBorder"] = (main[0] * 0.85, main[1] * 0.85, main[2] * 0.85, 1.0)
    return p


def grad(stops, t):
    n = len(stops)
    if n == 1 or t <= 0:
        return stops[0]
    if t >= 1:
        return stops[-1]
    pos = t * (n - 1)
    i = int(pos)
    f = pos - i
    a, b = stops[i], stops[i + 1]
    return tuple(a[k] + (b[k] - a[k]) * f for k in range(3))


def close(a, b, eps=EPS):
    return a is not None and b is not None and len(a) >= 3 and all(abs(float(a[i]) - float(b[i])) <= eps for i in range(min(len(a), len(b))))


def fmt(c): return "(" + ", ".join("%.4f" % float(x) for x in c) + ")" if c is not None else "nil"


# ---- the sessions (Lua) ---------------------------------------------------------------------------------------------------------
LUA = r'''
return function(W, L, MODE)
local pickArgs   -- (FA-4) the Theme page's args, set once they are built; pick() answers the "Ask first" dialog with Discard
local function pick(v) pickArgs.base.set(nil, v); local d = rawget(_G, "XayaUIThemeAsk"); if d and d:IsShown() then d.btns[1]:GetScript("OnClick")(d.btns[1]) end end
local R = { log = {} }
local function put(k, v) R[k] = v end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 5)
local ns = rawget(_G, "XayaUI_NS")
local T = ns and ns.Theme
put("hasTheme", T ~= nil)
if not T then return R end
local function rgba(c) if not c then return nil end return { c[1], c[2], c[3], c[4] or 1 } end
local function cur() local o = {} for k, v in pairs(T.cur) do o[k] = rgba(v) end return o end
local function frameAt(level)
  for _, o in ipairs(W.objects) do if o._kind == "Frame" and o._strata == "TOOLTIP" and o._level == level then return o end end
end
local function nListeners() return #(T.listeners or {}) end
CX, CY = 500, 400
GetCursorPosition = function() return CX, CY end   -- the cursor, moved by this test (addon code reads the global per call)

-- the color every live trail dot shows at age f (fraction of the trail length), dots dropped by one cursor move
local function trailAt(fs)
  local fr = frameAt(80)
  if not fr then return nil end
  local life = CueRulesDB.cursorTrail.length or 0.6
  W.tick(life / 2, 3)          -- older dots run out
  CX = CX + 1; W.tick(0.001, 1) -- (a sample point that drops nothing: below the spacing)
  CX = CX + 60; W.tick(0.001, 1) -- this frame drops a row of dots, all born now (age 0)
  local outs, prev = {}, 0
  for i, f in ipairs(fs) do
    if f > prev then W.tick((f - prev) * life, 1) end
    prev = f
    local first, same, n = nil, true, 0
    for _, o in ipairs(W.objects) do
      if o._kind == "Texture" and o._parent == fr and o._shown and o._vc then
        n = n + 1
        if not first then first = o._vc
        elseif math.abs(o._vc[1] - first[1]) + math.abs(o._vc[2] - first[2]) + math.abs(o._vc[3] - first[3]) > 1e-9 then same = false end
      end
    end
    outs[i] = { first and { first[1], first[2], first[3] } or false, same, n }
  end
  return outs
end
local function hlColor()
  local fr = frameAt(70)
  if not (fr and fr._shown) then return nil end
  for _, o in ipairs(W.objects) do
    if o._kind == "Texture" and o._parent == fr and o._shown and o._vc then return { o._vc[1], o._vc[2], o._vc[3] } end
  end
end

if MODE == "main" then
  -- V14 at login: both cursor features saved off (with the theme options picked)
  put("login_trailFrame", frameAt(80) ~= nil)
  put("login_hlFrame", frameAt(70) ~= nil)
  put("n_login", nListeners())   -- compared with the session without XayaUI_QoL
  local trailCalls = 0
  if T.TrailStops then local real = T.TrailStops; T.TrailStops = function(...) trailCalls = trailCalls + 1; return real(...) end end
  -- the Theme page (Settings > Theme), as the settings window builds it
  if ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 3)
  ns = rawget(_G, "XayaUI_NS"); T = ns.Theme
  local n0 = nListeners()   -- the settings window's own listeners are in from here on
  put("n0", n0)
  local okA, args = pcall(T.BuildArgs, function() end)
  -- (FA-4, Options 0.6.64; Xaya: "Ask first"): picking another theme with unsaved colors of your own asks first; this test answers Discard
  pickArgs = args
  if not okA then put("buildArgsErr", tostring(args)); return R end
  local vals, sorting, under, usort = args.base.values(), args.base.sorting(), args.custom.args.under.values(), args.custom.args.under.sorting()
  put("baseValues", vals); put("baseSorting", sorting); put("underValues", under); put("underSorting", usort)
  -- one table: the trail reads core's gradients
  put("oneTable", rawequal(ns.CURSORTRAIL_PRESETS, T.CURSOR_PRESETS) and T.CURSOR_PRESETS ~= nil)
  local presets = {}
  for k, p in pairs(T.CURSOR_PRESETS or {}) do local st = {} for i, s in ipairs(p[2]) do st[i] = { s[1], s[2], s[3] } end; presets[k] = { p[1], st } end
  put("corePresets", presets)
  -- pick every cursor theme through the page; theme changes while the cursor features are off
  local picked = {}
  for _, k in ipairs({ "fel", "fire", "ocean", "aurora", "sunset", "vapor", "rainbow", "gold", "ice" }) do
    pick("cursor_" .. k); W.tick(0.05, 2)
    picked[k] = { base = CueRulesDB.theme.base, cur = cur() }
  end
  put("picked", picked)
  put("off_trailFrame", frameAt(80) ~= nil); put("off_hlFrame", frameAt(70) ~= nil)
  put("off_listeners", nListeners()); put("off_trailCalls", trailCalls)
  -- the lightening rule on a gradient too dark to read (no preset needs it; it must still work)
  local okP, dark = pcall(T.CursorPalette, { { 0.10, 0.05, 0.30 }, { 0.20, 0.04, 0.10 }, { 0.05, 0.05, 0.05 } })
  if okP and dark then local d = {} for k, v in pairs(dark) do d[k] = rgba(v) end; put("darkPal", d) end

  -- Gradient Cursor Trail: "Match the UI theme" in its gradient list
  pick("default"); W.tick(0.05, 2)
  local tr = ns.BuildCursorTab(function() end)
  local pr = tr.args.colors.args.preset
  put("trailValues", pr.values); put("trailSorting", pr.sorting)
  pr.set(nil, "fel"); W.tick(0.05, 2)
  CueRulesDB.cursorTrail.enabled = true; ns.CursorTrail_Apply(); W.tick(0.05, 2)
  put("n_trailFel", nListeners())   -- on, with a gradient (fel): no listener
  pr.set(nil, "theme"); W.tick(0.05, 2)
  put("trailPreset", CueRulesDB.cursorTrail.preset)
  put("n_trailTheme", nListeners())
  put("trail_default", trailAt({ 0, 0.5, 0.9 }))
  put("preview_default", tr.args.colors.args.preview.name())
  -- a theme change recolors the trail (the trail's settings untouched)
  pick("cursor_ocean"); W.tick(0.05, 2)
  put("trail_ocean", trailAt({ 0, 1 / 3, 2 / 3, 0.95 }))
  put("preview_ocean", tr.args.colors.args.preview.name())
  pick("cursor_rainbow"); W.tick(0.05, 2)
  put("trail_rainbow", trailAt({ 0, 0.2, 0.4, 0.6, 0.8 }))
  -- a Custom theme on a cursor theme with its accent changed: the trail takes the theme's colors, not the gradient
  T.SetToken("accent", { 1, 0, 0, 1 }); W.tick(0.05, 2)
  put("customCur", cur())
  put("trail_custom", trailAt({ 0, 0.5 }))
  -- a Custom theme on a cursor theme with only the window color changed: still exactly the gradient
  pick("cursor_gold"); W.tick(0.05, 2)
  T.SetToken("windowBg", { 0.1, 0.1, 0.12, 1 }); W.tick(0.05, 2)
  put("customBase", CueRulesDB.theme.base); put("customUnder", CueRulesDB.theme.under)
  put("trail_customGold", trailAt({ 0, 0.5 }))
  -- V14: the listener goes when the trail goes back to a gradient or off
  pr.set(nil, "fire"); W.tick(0.05, 2)
  put("n_trailBackToFire", nListeners())
  put("trail_fire", trailAt({ 0, 1 / 3 }))
  pr.set(nil, "theme"); W.tick(0.05, 2)
  CueRulesDB.cursorTrail.enabled = false; ns.CursorTrail_Apply(); W.tick(0.05, 2)
  put("n_trailOff", nListeners())
  local before = trailCalls
  pick("cursor_fel"); W.tick(0.05, 2)
  put("trailCallsWhileOff", trailCalls - before)

  -- Cursor Highlight: "Use the UI theme's accent"
  CueRulesDB.cursorHighlight.useThemeColor = false
  CueRulesDB.cursorHighlight.enabled = true; ns.CursorHighlight_Apply(); W.tick(0.05, 2)
  put("n_hlOwn", nListeners())
  put("hl_own", hlColor())
  local hl = ns.BuildCursorHighlightTab(function() end)
  local opt = hl.args.look.args.useThemeColor
  put("hl_hasOption", opt ~= nil)
  if opt then
    opt.set(nil, true); W.tick(0.05, 2)
    put("hl_pickerDisabled", hl.args.look.args.color.disabled and hl.args.look.args.color.disabled() or false)
    put("n_hlTheme", nListeners())
    put("hl_theme_fel", hlColor()); put("accent_fel", rgba(T.cur.accent))
    pick("cursor_fire"); W.tick(0.05, 2)
    put("hl_theme_fire", hlColor()); put("accent_fire", rgba(T.cur.accent))
    -- hidden (Only show in combat, out of combat) stays hidden through a theme change
    CueRulesDB.cursorHighlight.combatOnly = true; ns.CursorHighlight_Apply(); W.tick(0.05, 2)
    local fr = frameAt(70)
    put("hl_hiddenBefore", fr and fr._alpha)
    pick("cursor_ocean")
    put("hl_hiddenAfter", fr and fr._alpha)
    CueRulesDB.cursorHighlight.combatOnly = false; ns.CursorHighlight_Apply(); W.tick(0.05, 2)
    opt.set(nil, false); W.tick(0.05, 2)
    put("n_hlOptOff", nListeners())
    put("hl_ownAgain", hlColor())
    opt.set(nil, true); W.tick(0.05, 2)
    CueRulesDB.cursorHighlight.enabled = false; ns.CursorHighlight_Apply(); W.tick(0.05, 2)
    put("n_hlOff", nListeners())
  end
elseif MODE == "qol_off" then
  put("n_login", nListeners())
  put("qolLoaded", ns.CursorTrail_Apply ~= nil or ns.CursorHighlight_Apply ~= nil)
  put("base", CueRulesDB.theme and CueRulesDB.theme.base)
  put("cur", cur())
  if ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 3)
  ns = rawget(_G, "XayaUI_NS"); T = ns.Theme
  local okA, args = pcall(T.BuildArgs, function() end)
  if okA then put("baseValues", args.base.values()); pickArgs = args end
  if okA then pick("cursor_vapor"); W.tick(0.05, 2); put("curVapor", cur()) end
elseif MODE == "existing" then
  put("n_login", nListeners())
  put("base", CueRulesDB.theme.base); put("under", CueRulesDB.theme.under)
  put("cur", cur())
  put("preset", CueRulesDB.cursorTrail.preset)
  put("trail_fire", trailAt({ 0, 1 / 3, 2 / 3 }))
  put("hl", hlColor())
  T.Load("Mine"); W.tick(0.05, 2)
  put("curMine", cur())
  put("trail_afterLoad", trailAt({ 0 }))
  put("hl_afterLoad", hlColor())
end
return R
end
'''


def session(mode, enabled_skip, saved, folders):
    enabled = [n for n in folders if n != "XayaUI_DevAssist" and n not in enabled_skip]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": saved}))
    res = L.eval("function(src, W, Ld, m) return loadstring(src)()(W, Ld, m) end")(LUA, world, loader, mode)
    errs = [str(world.errors[i])[:600] for i in range(1, len(world.errors) + 1)]
    return H.lua_to_py(res) if res is not None else {}, errs


RESULTS = []


def check(name, ok, extra=""):
    RESULTS.append((name, bool(ok), extra))


# Deliberate breaks (negative controls for the checks that hold on the old code by design: defaults kept, readable text, V14,
# existing users unchanged). Each is applied to a copy of the addon folder; each must make at least one check fail.
BREAKS = [
    ("a cursor theme also recolors the body text", "XayaUI", "Theme.lua",
     "    pal.primaryBorder = { main[1] * 0.85, main[2] * 0.85, main[3] * 0.85, 1 }\n",
     "    pal.primaryBorder = { main[1] * 0.85, main[2] * 0.85, main[3] * 0.85, 1 }; pal.text = Copy4(main)\n"),
    ("text colors never lightened", "XayaUI", "Theme.lua",
     "if T.Contrast(m, bg) >= T.MIN_TEXT_CONTRAST then return m end", "if T.Contrast(m, bg) >= 0 then return m end"),
    ("glow / tab / button backgrounds never darkened for text", "XayaUI", "Theme.lua", "        if ok then return d end", "        if true then return d end"),
    ("a Custom theme's own accent ignored by Match the UI theme", "XayaUI", "Theme.lua",
     "if p and not (own.accent or own.accentText or own.gradStart) then", "if p then"),
    ("Theme.OffResolve removes nothing", "XayaUI", "Theme.lua", "if f ~= fn then keep[#keep + 1] = f end", "keep[#keep + 1] = f"),
    ("trail listener kept with any gradient", "XayaUI_QoL", "CursorTrail.lua", "    ListenTheme(c.preset == \"theme\")", "    ListenTheme(true)"),
    ("trail listener kept when the trail is switched off", "XayaUI_QoL", "CursorTrail.lua",
     "    if not c.enabled then\n        ListenTheme(false)\n", "    if not c.enabled then\n"),
    ("every saved gradient treated as Match the UI theme", "XayaUI_QoL", "CursorTrail.lua",
     "if c.preset == \"theme\" and TH and TH.TrailStops then", "if TH and TH.TrailStops then"),
    ("highlight listener kept with the option off", "XayaUI_QoL", "CursorHighlight.lua", "    ListenTheme(c.useThemeColor)", "    ListenTheme(c.enabled)"),
    ("a hidden highlight shown again by a theme change", "XayaUI_QoL", "CursorHighlight.lua", "    if hiddenNow then frame:SetAlpha(0) end", ""),
    ("existing highlights switched to the theme accent (default on)", "XayaUI_QoL", "CursorHighlight.lua",
     "    useThemeColor = false,", "    useThemeColor = true,"),
]


def broken_folders(base, addon, rel, old, new, tmp):
    """a copy of one addon folder (code and .toc only) with one text replaced; None when the text is not there exactly once"""
    import shutil
    src = os.path.join(base[addon], rel)
    text = open(src, encoding="utf-8").read()
    if text.count(old) != 1:
        return None
    dst = os.path.join(tmp, addon)
    shutil.copytree(base[addon], dst, ignore=shutil.ignore_patterns("*.tga", "*.blp", "*.ogg", "*.mp3", "*.ttf", "*.png", "*.jpg"))
    with open(os.path.join(dst, rel), "w", encoding="utf-8") as f:
        f.write(text.replace(old, new))
    out = dict(base)
    out[addon] = dst
    return out


def col(v):
    """a Lua color table (converted to a list) -> tuple"""
    if v is None or v is False:
        return None
    if isinstance(v, dict):
        return tuple(v[k] for k in sorted(v))
    return tuple(v)


def check_trail(label, samples, stops, fs):
    if not samples:
        check(label + ": the trail draws", False, "no trail frame or no samples")
        return
    for (sample, f) in zip(samples, fs):
        got, same, n = sample[0], sample[1], sample[2]
        want = grad(stops, f)
        check("%s: dots at %.0f%% of the trail are %s" % (label, f * 100, fmt(want)), n > 0 and same and close(col(got), want, 1e-4),
              "%d dots, all same %s, got %s" % (n, same, fmt(col(got))))


def preview_first(text):
    """the first swatch of the settings preview strip (|T...:r:g:b|t) as 0-255 integers"""
    import re
    m = re.search(r"\|TInterface\\Buttons\\WHITE8X8:16:9:0:0:8:8:0:8:0:8:(\d+):(\d+):(\d+)\|t", text or "")
    return tuple(int(x) for x in m.groups()) if m else None


def to255(c): return tuple(int(x * 255 + 0.5) for x in c[:3])


def evaluate(folders):
    """runs the three sessions on these addon folders; fills RESULTS; returns the contrast table rows"""
    # ---------------- session 1: fresh install, every addon on, cursor features saved off (with the theme options picked) -----------
    saved = {"XayaUI": {"CueRulesDB": {"cursorTrail": {"enabled": False, "preset": "theme"},
                                       "cursorHighlight": {"enabled": False, "useThemeColor": True}}}}
    R, errs = session("main", [], saved, folders)
    if "buildArgsErr" in R:
        check("the Theme page builds", False, R["buildArgsErr"])
    # 1. the Theme page lists the cursor themes, in the gradient order, after the color blind ones and before Custom
    vals, srt = R.get("baseValues") or {}, R.get("baseSorting") or []
    for k in ORDER:
        check("Theme page lists \"%s\" (no \"Cursor trail:\" prefix, core 0.6.54)" % PRESETS[k][0], vals.get("cursor_" + k) == PRESETS[k][0], vals.get("cursor_" + k))
        check("Start from (Custom) lists \"%s\"" % PRESETS[k][0], (R.get("underValues") or {}).get("cursor_" + k) == PRESETS[k][0])
    want_order = ["default", "class", "light", "colorblind", "protan", "tritan"] + ["cursor_" + k for k in ORDER] + ["custom"]
    check("Theme page order: built-ins, the nine cursor themes in the trail's order, then Custom", srt[:len(want_order)] == want_order, srt)
    check("Start from order ends with the cursor themes", (R.get("underSorting") or [])[-9:] == ["cursor_" + k for k in ORDER], R.get("underSorting"))
    # one table, unchanged keys / names / colors
    check("the trail reads core's gradient table (one table, not a copy)", R.get("oneTable") is True)
    cp = R.get("corePresets") or {}
    for k in ORDER:
        got = cp.get(k)
        same = got is not None and got[0] == PRESETS[k][0] and len(got[1]) == len(PRESETS[k][1]) and all(close(tuple(a), b, 0) for a, b in zip(got[1], PRESETS[k][1]))
        check("gradient %s: key, name and colors unchanged" % k, same, got)
    qsrc = open(os.path.join(ROOT, "XayaUI_QoL", "CursorTrail.lua"), encoding="utf-8").read()
    check("CursorTrail.lua holds no copy of the gradient colors", "{0.35,1.00,0.25}" not in qsrc and "{0.65,0.90,1.00}" not in qsrc)
    # picking each theme: the derived palette (parity with the rule written again here), defaults kept, contrast
    contrast_rows = []
    for k in ORDER:
        p = (R.get("picked") or {}).get(k)
        if not p:
            check("picking Cursor trail: %s" % PRESETS[k][0], False, "not picked")
            continue
        cur = {t: col(v) for t, v in p["cur"].items()}
        want = palette(PRESETS[k][1])
        check("picking Cursor trail: %s sets the theme" % PRESETS[k][0], p["base"] == "cursor_" + k, p["base"])
        bad = [t for t in want if not close(cur.get(t), want[t]) or abs(float(cur[t][3]) - want[t][3]) > EPS]
        check("Cursor trail: %s: ns.Theme.cur carries the derived colors (%d tokens)" % (PRESETS[k][0], len(want)), not bad,
              "; ".join("%s got %s want %s" % (t, fmt(cur.get(t)), fmt(want[t])) for t in bad))
        kept = [t for t in KEEP if not close(cur.get(t), KEEP[t]) or abs(float(cur[t][3]) - KEEP[t][3]) > EPS]
        check("Cursor trail: %s: surfaces, body text, borders, tree bars and Danger keep the XUI default" % PRESETS[k][0], not kept, kept)
        win = cur["windowBg"][:3]
        row = {"name": PRESETS[k][0]}
        for t in ("accent", "accentText", "label", "buttonText"):
            row[t] = contrast(cur[t][:3], win)
        row["text/gradStart"] = contrast(cur["text"][:3], cur["gradStart"][:3])
        row["accentText/gradStart"] = contrast(cur["accentText"][:3], cur["gradStart"][:3])
        ts = over(cur["tabSelBg"][:3], cur["tabSelBg"][3], win)
        row["text/tabSelBg"] = contrast(cur["text"][:3], ts)
        row["accentText/tabSelBg"] = contrast(cur["accentText"][:3], ts)
        row["buttonText/primaryBg"] = contrast(cur["buttonText"][:3], over(cur["primaryBg"][:3], cur["primaryBg"][3], win))
        row["tabSelBorder"] = contrast(cur["tabSelBorder"][:3], win)
        row["primaryBorder"] = contrast(cur["primaryBorder"][:3], win)
        row["gradStart"] = contrast(cur["gradStart"][:3], win)
        low = [t for t in row if t not in ("name", "tabSelBorder", "primaryBorder", "gradStart") and row[t] < 4.5]
        check("Cursor trail: %s: every text color reads at 4.5:1 or better" % PRESETS[k][0], not low, ["%s %.2f" % (t, row[t]) for t in low])
        contrast_rows.append(row)
    d = R.get("darkPal")
    if d:
        dd = {t: col(v) for t, v in d.items()}
        want = palette([(0.10, 0.05, 0.30), (0.20, 0.04, 0.10), (0.05, 0.05, 0.05)])
        check("a gradient too dark to read is lightened to 4.5:1 (accent, accentText, label)",
              all(contrast(dd[t][:3], WIN) >= 4.5 for t in ("accent", "accentText", "label")) and contrast((0.20, 0.04, 0.10), WIN) < 4.5,
              {t: round(contrast(dd[t][:3], WIN), 2) for t in ("accent", "accentText", "label")})
        check("...and matches the rule written here", all(close(dd[t], want[t]) for t in want), {t: (fmt(dd[t]), fmt(want[t])) for t in want if not close(dd[t], want[t])})
    else:
        check("a gradient too dark to read is lightened to 4.5:1 (T.CursorPalette)", False, "no T.CursorPalette")
    # 5. V14: off at login, theme changes while off
    check("V14: trail saved off: no trail frame at login", R.get("login_trailFrame") is False)
    check("V14: highlight saved off: no highlight frame at login", R.get("login_hlFrame") is False)
    check("V14: nine theme changes with both off made no cursor frame", R.get("off_trailFrame") is False and R.get("off_hlFrame") is False)
    check("V14: ...no cursor listener was added", R.get("off_listeners") == R.get("n0"), (R.get("n0"), R.get("off_listeners")))
    check("V14: ...and no trail color work ran (TrailStops calls)", R.get("off_trailCalls") == 0, R.get("off_trailCalls"))
    # 3. the trail
    tv, ts = R.get("trailValues") or {}, R.get("trailSorting") or []
    check("trail gradient list offers \"Match the UI theme\"", tv.get("theme") == "Match the UI theme", tv.get("theme"))
    check("trail gradient list: the nine gradients, Match the UI theme, then Custom", ts == ORDER + ["theme", "custom"], ts)
    check("V14: trail on with a gradient (fel): no listener", R.get("n_trailFel") == R.get("n0"), (R.get("n0"), R.get("n_trailFel")))
    check("trail set to Match the UI theme", R.get("trailPreset") == "theme", R.get("trailPreset"))
    check("V14: trail on + Match the UI theme: exactly one listener added", R.get("n_trailTheme") == (R.get("n0") or 0) + 1, (R.get("n0"), R.get("n_trailTheme")))
    check_trail("XUI default theme (accentText -> accent -> gradStart)", R.get("trail_default"), DEFAULT_TRAIL, [0, 0.5, 0.9])
    check("settings preview strip starts with the theme's accentText", preview_first(R.get("preview_default")) == to255(DEFAULT_TRAIL[0]), preview_first(R.get("preview_default")))
    check_trail("after switching to Cursor trail: Ocean (no trail setting touched)", R.get("trail_ocean"), PRESETS["ocean"][1], [0, 1 / 3, 2 / 3, 0.95])
    check("settings preview strip follows (Ocean's head color)", preview_first(R.get("preview_ocean")) == to255(PRESETS["ocean"][1][0]), preview_first(R.get("preview_ocean")))
    check_trail("Cursor trail: Rainbow", R.get("trail_rainbow"), PRESETS["rainbow"][1], [0, 0.2, 0.4, 0.6, 0.8])
    cc = {t: col(v) for t, v in (R.get("customCur") or {}).items()}
    if cc:
        check_trail("Custom on Rainbow with the accent changed to red (theme tokens)", R.get("trail_custom"),
                    [cc["accentText"][:3], cc["accent"][:3], cc["gradStart"][:3]], [0, 0.5])
        check("...the middle of that trail is the red accent", close(cc["accent"], (1, 0, 0)))
    check("Custom on Gold with only the window color changed is Custom", R.get("customBase") == "custom" and R.get("customUnder") == "cursor_gold",
          (R.get("customBase"), R.get("customUnder")))
    check_trail("...and the trail still runs exactly the Gold gradient", R.get("trail_customGold"), PRESETS["gold"][1], [0, 0.5])
    check("V14: trail back to a gradient (Fire): the listener is gone", R.get("n_trailBackToFire") == R.get("n0"), (R.get("n0"), R.get("n_trailBackToFire")))
    check_trail("existing gradient (Fire) draws as before", R.get("trail_fire"), PRESETS["fire"][1], [0, 1 / 3])
    check("V14: trail switched off: the listener is gone", R.get("n_trailOff") == R.get("n0"), (R.get("n0"), R.get("n_trailOff")))
    check("V14: a theme change with the trail off computes no trail colors", R.get("trailCallsWhileOff") == 0, R.get("trailCallsWhileOff"))
    # 4. the highlight
    check("highlight on, option off: no listener", R.get("n_hlOwn") == R.get("n0"), (R.get("n0"), R.get("n_hlOwn")))
    check("highlight draws its own color with the option off", close(col(R.get("hl_own")), (1.00, 0.82, 0.10)), fmt(col(R.get("hl_own"))))
    check("Color and Size tab has \"Use the UI theme's accent\"", R.get("hl_hasOption") is True)
    if R.get("hl_hasOption"):
        check("the color picker is greyed out while the option is on", R.get("hl_pickerDisabled") is True)
        check("V14: option on: exactly one listener added", R.get("n_hlTheme") == (R.get("n0") or 0) + 1, (R.get("n0"), R.get("n_hlTheme")))
        fel = palette(PRESETS["fel"][1])["accent"]
        check("highlight draws the theme's accent (Cursor trail: Fel)", close(col(R.get("hl_theme_fel")), fel) and close(col(R.get("accent_fel")), fel),
              fmt(col(R.get("hl_theme_fel"))))
        fire = palette(PRESETS["fire"][1])["accent"]
        check("highlight follows a theme change (to Cursor trail: Fire) without its settings touched", close(col(R.get("hl_theme_fire")), fire), fmt(col(R.get("hl_theme_fire"))))
        check("a hidden highlight (combat only, out of combat) stays hidden through a theme change",
              R.get("hl_hiddenBefore") == 0 and R.get("hl_hiddenAfter") == 0, (R.get("hl_hiddenBefore"), R.get("hl_hiddenAfter")))
        check("V14: option off: the listener is gone", R.get("n_hlOptOff") == R.get("n0"), (R.get("n0"), R.get("n_hlOptOff")))
        check("option off: back to its own color", close(col(R.get("hl_ownAgain")), (1.00, 0.82, 0.10)), fmt(col(R.get("hl_ownAgain"))))
        check("V14: highlight switched off: the listener is gone", R.get("n_hlOff") == R.get("n0"), (R.get("n0"), R.get("n_hlOff")))
    for e in errs:
        check("no Lua error (session 1)", False, e)

    # ---------------- session 2: XayaUI_QoL switched off, a cursor theme saved ------------------------------------------------------
    saved2 = {"XayaUI": {"CueRulesDB": {"theme": {"base": "cursor_fel", "tokens": {}, "classes": {}}}}}
    R2, errs2 = session("qol_off", ["XayaUI_QoL"], saved2, folders)
    check("QoL off: QoL not loaded", R2.get("qolLoaded") is False)
    cur2 = {t: col(v) for t, v in (R2.get("cur") or {}).items()}
    fel = palette(PRESETS["fel"][1])
    check("QoL off: the saved Cursor trail: Fel theme resolves to its colors", R2.get("base") == "cursor_fel" and cur2 and all(close(cur2.get(t), fel[t]) for t in fel),
          (R2.get("base"), {t: fmt(cur2.get(t)) for t in ("accent", "label")}))
    check("QoL off: the Theme page lists the cursor themes", all((R2.get("baseValues") or {}).get("cursor_" + k) == PRESETS[k][0] for k in ORDER))
    cv = {t: col(v) for t, v in (R2.get("curVapor") or {}).items()}
    vap = palette(PRESETS["vapor"][1])
    check("QoL off: picking Cursor trail: Vaporwave works", cv and all(close(cv.get(t), vap[t]) for t in vap))
    for e in errs2:
        check("no Lua error (session 2)", False, e)

    # ---------------- session 3: an existing user (saved before 0.6.46 / 0.7.17) ------------------------------------------------------
    mine = {"base": "colorblind", "tokens": {"label": [0.9, 0.3, 0.3, 1]}, "classes": {}, "font": "none", "size": "M"}
    saved3 = {"XayaUI": {"CueRulesDB": {
        "theme": {"base": "custom", "under": "default", "tokens": {"accent": [0.1, 0.6, 0.3, 1]}, "classes": {}, "font": "none", "size": "M"},
        "themes": {"Mine": mine},
        "cursorTrail": {"enabled": True, "preset": "fire", "customN": 3, "length": 0.6, "size": 18, "opacity": 1, "shape": "star",
                        "reverse": False, "hideMouselook": True,
                        "custom": [[1, 0.3, 0.3], [1, 0.85, 0.2], [0.3, 0.5, 1], [0.3, 1, 0.5], [0.85, 0.4, 1], [1, 1, 1]]},
        "cursorHighlight": {"enabled": True, "shape": "circle", "size": 56, "color": [0.2, 0.4, 0.6], "opacity": 0.5,
                            "combatOnly": False, "hideMouselook": True, "style": "fill", "thickness": 3, "art": "point", "artPath": "",
                            "keepColors": False}}}}
    R3, errs3 = session("existing", [], saved3, folders)
    cur3 = {t: col(v) for t, v in (R3.get("cur") or {}).items()}
    check("existing: theme still Custom on XUI default", R3.get("base") == "custom" and R3.get("under") == "default", (R3.get("base"), R3.get("under")))
    check("existing: own accent kept, other tokens the XUI default", cur3 and close(cur3["accent"], (0.1, 0.6, 0.3))
          and close(cur3["accentText"], (0.78, 0.62, 1.0)) and close(cur3["label"], (1.0, 0.82, 0.0)) and close(cur3["gradStart"], (0.30, 0.08, 0.45)))
    check("existing: trail gradient still Fire", R3.get("preset") == "fire", R3.get("preset"))
    check_trail("existing: the Fire trail draws as before", R3.get("trail_fire"), PRESETS["fire"][1], [0, 1 / 3, 2 / 3])
    check("existing: highlight draws its saved color (no theme option in its saved table)", close(col(R3.get("hl")), (0.2, 0.4, 0.6)), fmt(col(R3.get("hl"))))
    cm = {t: col(v) for t, v in (R3.get("curMine") or {}).items()}
    check("existing: loading a saved theme (colorblind + own label) gives the same colors",
          cm and close(cm["label"], (0.9, 0.3, 0.3)) and close(cm["accent"], (0.337, 0.706, 0.914)) and close(cm["accentText"], (0.70, 0.88, 0.98)))
    check_trail("existing: the trail does not follow the theme (still Fire)", R3.get("trail_afterLoad"), PRESETS["fire"][1], [0])
    check("existing: the highlight does not follow the theme (still its saved color)", close(col(R3.get("hl_afterLoad")), (0.2, 0.4, 0.6)))
    for e in errs3:
        check("no Lua error (session 3)", False, e)
    # V14 at login, across sessions: QoL on with both cursor features saved off (theme options picked), and an existing user with
    # both on without the theme options, have exactly the theme listeners of a session without XayaUI_QoL at all
    check("V14: at login, cursor features off: no more theme listeners than with XayaUI_QoL switched off",
          R.get("n_login") is not None and R.get("n_login") == R2.get("n_login"), (R.get("n_login"), R2.get("n_login")))
    check("V14: at login, trail on (Fire) and highlight on (own color): no cursor theme listener",
          R3.get("n_login") is not None and R3.get("n_login") == R2.get("n_login"), (R3.get("n_login"), R2.get("n_login")))
    return contrast_rows


def main():
    import tempfile
    folders = H.find_addons()
    contrast_rows = evaluate(folders)
    results = list(RESULTS)
    bad = 0
    for name, ok, extra in results:
        print(("PASS " if ok else "FAIL ") + name + ("" if ok or extra in ("", None) else "  [%s]" % (extra,)))
        bad += 0 if ok else 1
    for (name, addon, rel, old, new) in BREAKS:
        with tempfile.TemporaryDirectory(prefix="xui_cursor_themes_") as tmp:
            bf = broken_folders(folders, addon, rel, old, new, tmp)
            if bf is None:
                print("BREAK %r: text not found exactly once in %s/%s" % (name, addon, rel)); bad += 1
                continue
            del RESULTS[:]
            evaluate(bf)
            caught = [n for (n, ok, _) in RESULTS if not ok]
            if caught:
                print("BREAK caught (%d checks fail): %s  -- e.g. %s" % (len(caught), name, caught[0][:110]))
            else:
                print("BREAK %r: no check failed" % name); bad += 1
    if REPORT and contrast_rows:
        cols = ["accent", "accentText", "label", "buttonText", "text/gradStart", "accentText/gradStart", "text/tabSelBg",
                "accentText/tabSelBg", "buttonText/primaryBg", "tabSelBorder", "primaryBorder", "gradStart"]
        print("| Theme | " + " | ".join(cols) + " |")
        print("|---" * (len(cols) + 1) + "|")
        for r in contrast_rows:
            print("| " + r["name"] + " | " + " | ".join("%.2f" % r[c] for c in cols) + " |")
        for k in ORDER:
            p = palette(PRESETS[k][1])
            print("%-10s " % PRESETS[k][0] + "  ".join("%s=%s" % (t, fmt(p[t])) for t in ("accent", "accentText", "label", "gradStart", "tabSelBg", "primaryBg", "primaryBorder")))
    print("%d checks, %d deliberate breaks, %d failed" % (len(results), len(BREAKS), bad))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
