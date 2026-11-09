#!/usr/bin/env python3
"""Cursor trail colors <-> UI themes (core 0.6.46). Xaya, 2026-11-05: "map cursor theme colors to UI themes and provide them as
theming options as well".
Loads main's addons in the stand-in game (tests/harness, Lua 5.1 via lupa) and checks what the player sees. The Gradient Cursor Trail
and Cursor Highlight themselves are XayaUI QoL's, which lives on qa-installer-branch, not on main (REQUEST-LOG A23); core keeps the
gradients (ns.Theme.CURSOR_PRESETS), the cursor themes and the trail colors it hands out (ns.Theme.TrailStops), checked here:
  1. Settings > Theme lists one "<name>" theme (core 0.6.54: no "Cursor trail:" prefix) per Gradient Cursor Trail gradient (Theme and Start from lists); picking
     one gives ns.Theme.cur the colors derived by the documented rule (re-computed here in Python from the gradients as they were in
     CursorTrail.lua at b8017df: parity, V5), every other token keeps the XUI default, and every text token reads at 4.5:1 or better
     (WCAG 2.x contrast, computed here) on the window background and on the backgrounds it is drawn on.
  2. A saved cursor theme resolves at login and the Theme page lists them (core alone, no cursor feature loaded).
  3. The trail colors core hands out (T.TrailStops, what the trail's "Match the UI theme" draws): a cursor theme gives exactly its
     gradient; another theme accentText -> accent -> gradStart; a Custom theme with its own accent gives the theme's colors, with only
     its window color changed still the gradient.
  4. V14: theme changes add no theme listener and compute no trail colors; a listener taken out with T.OffResolve is gone.
  5. Existing users: a saved theme draws exactly as before.
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
local function nListeners() return #(T.listeners or {}) end
if MODE == "main" then
  local trailCalls = 0
  if T.TrailStops then local real = T.TrailStops; T.TrailStops = function(...) trailCalls = trailCalls + 1; return real(...) end end
  -- the Theme page (Settings > Theme), as the settings window builds it
  if ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 3)
  ns = rawget(_G, "XayaUI_NS"); T = ns.Theme
  local n0 = nListeners()   -- the settings window's own listeners are in from here on
  put("n0", n0)
  local okA, args = pcall(T.BuildArgs, function() end)
  -- (FA-4, Options 0.6.69; Xaya: "Ask first"): picking another theme with unsaved colors of your own asks first; this test answers Discard
  pickArgs = args
  if not okA then put("buildArgsErr", tostring(args)); return R end
  local vals, sorting, under, usort = args.base.values(), args.base.sorting(), args.custom.args.under.values(), args.custom.args.under.sorting()
  put("baseValues", vals); put("baseSorting", sorting); put("underValues", under); put("underSorting", usort)
  local presets = {}
  for k, p in pairs(T.CURSOR_PRESETS or {}) do local st = {} for i, s in ipairs(p[2]) do st[i] = { s[1], s[2], s[3] } end; presets[k] = { p[1], st } end
  put("corePresets", presets)
  -- pick every cursor theme through the page
  local picked = {}
  for _, k in ipairs({ "fel", "fire", "ocean", "aurora", "sunset", "vapor", "rainbow", "gold", "ice" }) do
    pick("cursor_" .. k); W.tick(0.05, 2)
    picked[k] = { base = CueRulesDB.theme.base, cur = cur() }
  end
  put("picked", picked)
  put("off_listeners", nListeners()); put("off_trailCalls", trailCalls)
  -- the lightening rule on a gradient too dark to read (no preset needs it; it must still work)
  local okP, dark = pcall(T.CursorPalette, { { 0.10, 0.05, 0.30 }, { 0.20, 0.04, 0.10 }, { 0.05, 0.05, 0.05 } })
  if okP and dark then local d = {} for k, v in pairs(dark) do d[k] = rgba(v) end; put("darkPal", d) end

  -- the trail colors core hands out (T.TrailStops: what the Gradient Cursor Trail's "Match the UI theme" draws)
  local function stops() local o = {} for i, c in ipairs(T.TrailStops()) do o[i] = { c[1], c[2], c[3] } end return o end
  pick("default"); W.tick(0.05, 2)
  put("stops_default", stops())
  pick("cursor_ocean"); W.tick(0.05, 2)
  put("stops_ocean", stops())
  pick("cursor_rainbow"); W.tick(0.05, 2)
  put("stops_rainbow", stops())
  -- a Custom theme on a cursor theme with its accent changed: the theme's colors, not the gradient
  T.SetToken("accent", { 1, 0, 0, 1 }); W.tick(0.05, 2)
  put("customCur", cur())
  put("stops_custom", stops())
  -- a Custom theme on a cursor theme with only the window color changed: still exactly the gradient
  pick("cursor_gold"); W.tick(0.05, 2)
  T.SetToken("windowBg", { 0.1, 0.1, 0.12, 1 }); W.tick(0.05, 2)
  put("customBase", CueRulesDB.theme.base); put("customUnder", CueRulesDB.theme.under)
  put("stops_customGold", stops())
  -- V14: a listener a feature takes out with T.OffResolve is gone (it runs on no theme change)
  local nb, ran = nListeners(), 0
  local probe = function() ran = ran + 1 end
  T.OnResolve(probe); put("n_probeOn", nListeners() - nb)
  T.OffResolve(probe); put("n_probeOff", nListeners() - nb)
  pick("cursor_fel"); W.tick(0.05, 2)
  put("probeRanAfterOff", ran)
elseif MODE == "saved_theme" then
  put("base", CueRulesDB.theme and CueRulesDB.theme.base)
  put("cur", cur())
  if ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 3)
  ns = rawget(_G, "XayaUI_NS"); T = ns.Theme
  local okA, args = pcall(T.BuildArgs, function() end)
  if okA then put("baseValues", args.base.values()); pickArgs = args end
  if okA then pick("cursor_vapor"); W.tick(0.05, 2); put("curVapor", cur()) end
elseif MODE == "existing" then
  put("base", CueRulesDB.theme.base); put("under", CueRulesDB.theme.under)
  put("cur", cur())
  T.Load("Mine"); W.tick(0.05, 2)
  put("curMine", cur())
end
return R
end
'''


def session(mode, enabled_skip, saved, folders):
    enabled = [n for n in folders if n not in enabled_skip]
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
# existing users unchanged). Each is applied to a copy of the addon folder; each must make at least one check fail. (The breaks in
# XayaUI QoL's CursorTrail.lua / CursorHighlight.lua went with it to qa-installer-branch.)
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


def check_stops(label, got, stops):
    """the trail colors core hands out (T.TrailStops) against the gradient wanted, stop by stop"""
    got = [col(c) for c in (got or [])]
    ok = len(got) == len(stops) and all(close(a, b, 1e-6) for a, b in zip(got, stops))
    check("%s: T.TrailStops gives %s" % (label, " -> ".join(fmt(c) for c in stops)), ok, " -> ".join(fmt(c) for c in got))


def evaluate(folders):
    """runs the three sessions on these addon folders; fills RESULTS; returns the contrast table rows"""
    # ---------------- session 1: fresh install, every addon on main on -----------------------------------------------------------------
    R, errs = session("main", [], {}, folders)
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
    # unchanged keys / names / colors
    cp = R.get("corePresets") or {}
    for k in ORDER:
        got = cp.get(k)
        same = got is not None and got[0] == PRESETS[k][0] and len(got[1]) == len(PRESETS[k][1]) and all(close(tuple(a), b, 0) for a, b in zip(got[1], PRESETS[k][1]))
        check("gradient %s: key, name and colors unchanged" % k, same, got)
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
    # 4. V14: theme changes
    check("V14: nine theme changes added no theme listener", R.get("off_listeners") == R.get("n0"), (R.get("n0"), R.get("off_listeners")))
    check("V14: ...and computed no trail colors (TrailStops calls)", R.get("off_trailCalls") == 0, R.get("off_trailCalls"))
    check("V14: T.OnResolve adds one listener, T.OffResolve takes it out again", R.get("n_probeOn") == 1 and R.get("n_probeOff") == 0,
          (R.get("n_probeOn"), R.get("n_probeOff")))
    check("V14: ...and a listener taken out runs on no theme change", R.get("probeRanAfterOff") == 0, R.get("probeRanAfterOff"))
    # 3. the trail colors core hands out (T.TrailStops)
    check_stops("XUI default theme (accentText -> accent -> gradStart)", R.get("stops_default"), DEFAULT_TRAIL)
    check_stops("Cursor trail: Ocean", R.get("stops_ocean"), PRESETS["ocean"][1])
    check_stops("Cursor trail: Rainbow", R.get("stops_rainbow"), PRESETS["rainbow"][1])
    cc = {t: col(v) for t, v in (R.get("customCur") or {}).items()}
    if cc:
        check_stops("Custom on Rainbow with the accent changed to red (theme tokens)", R.get("stops_custom"),
                    [cc["accentText"][:3], cc["accent"][:3], cc["gradStart"][:3]])
        check("...the middle of those colors is the red accent", close(cc["accent"], (1, 0, 0)))
    else:
        check("Custom on Rainbow with the accent changed to red: the theme resolves", False, "no colors")
    check("Custom on Gold with only the window color changed is Custom", R.get("customBase") == "custom" and R.get("customUnder") == "cursor_gold",
          (R.get("customBase"), R.get("customUnder")))
    check_stops("...and the trail colors are still exactly the Gold gradient", R.get("stops_customGold"), PRESETS["gold"][1])
    for e in errs:
        check("no Lua error (session 1)", False, e)

    # ---------------- session 2: a cursor theme saved (no cursor feature on main) ------------------------------------------------------
    saved2 = {"XayaUI": {"CueRulesDB": {"theme": {"base": "cursor_fel", "tokens": {}, "classes": {}}}}}
    R2, errs2 = session("saved_theme", [], saved2, folders)
    cur2 = {t: col(v) for t, v in (R2.get("cur") or {}).items()}
    fel = palette(PRESETS["fel"][1])
    check("saved theme: Cursor trail: Fel resolves to its colors at login", R2.get("base") == "cursor_fel" and cur2 and all(close(cur2.get(t), fel[t]) for t in fel),
          (R2.get("base"), {t: fmt(cur2.get(t)) for t in ("accent", "label")}))
    check("saved theme: the Theme page lists the cursor themes", all((R2.get("baseValues") or {}).get("cursor_" + k) == PRESETS[k][0] for k in ORDER))
    cv = {t: col(v) for t, v in (R2.get("curVapor") or {}).items()}
    vap = palette(PRESETS["vapor"][1])
    check("saved theme: picking Cursor trail: Vaporwave works", cv and all(close(cv.get(t), vap[t]) for t in vap))
    for e in errs2:
        check("no Lua error (session 2)", False, e)

    # ---------------- session 3: an existing user (saved before 0.6.46) -----------------------------------------------------------------
    mine = {"base": "colorblind", "tokens": {"label": [0.9, 0.3, 0.3, 1]}, "classes": {}, "font": "none", "size": "M"}
    saved3 = {"XayaUI": {"CueRulesDB": {
        "theme": {"base": "custom", "under": "default", "tokens": {"accent": [0.1, 0.6, 0.3, 1]}, "classes": {}, "font": "none", "size": "M"},
        "themes": {"Mine": mine}}}}
    R3, errs3 = session("existing", [], saved3, folders)
    cur3 = {t: col(v) for t, v in (R3.get("cur") or {}).items()}
    check("existing: theme still Custom on XUI default", R3.get("base") == "custom" and R3.get("under") == "default", (R3.get("base"), R3.get("under")))
    check("existing: own accent kept, other tokens the XUI default", cur3 and close(cur3["accent"], (0.1, 0.6, 0.3))
          and close(cur3["accentText"], (0.78, 0.62, 1.0)) and close(cur3["label"], (1.0, 0.82, 0.0)) and close(cur3["gradStart"], (0.30, 0.08, 0.45)))
    cm = {t: col(v) for t, v in (R3.get("curMine") or {}).items()}
    check("existing: loading a saved theme (colorblind + own label) gives the same colors",
          cm and close(cm["label"], (0.9, 0.3, 0.3)) and close(cm["accent"], (0.337, 0.706, 0.914)) and close(cm["accentText"], (0.70, 0.88, 0.98)))
    for e in errs3:
        check("no Lua error (session 3)", False, e)
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
