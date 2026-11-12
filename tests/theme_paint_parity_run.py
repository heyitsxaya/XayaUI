#!/usr/bin/env python3
"""Debug batch W9a, issue #460 (XayaUI 0.6.81, Options 0.6.102): a theme WITHOUT gradients is painted exactly as before. Gradient
borders changed the paint code of the window frame, panes, buttons and tabs (Options Skin.lua Flat / SkinFrame / PaneDivider, core
Core.lua FlatBox); for a solid theme every one of them must draw what it drew before.
Loads the real addons in the stand-in game, opens the settings window and visits a fixed list of pages (Settings > Theme with Advanced
customization off, Settings > Display, the Rules list, Profiles), runs the skin pass, and writes out every region of the window: per
frame its backdrop colours (version numbers in texts normalised), per texture whether it is shown, its alpha, colour texture, vertex colour and gradient (the stand-in
records SetGradient), its draw size; per font string its text colour. Frames are named by their place in the tree (child indexes).
  A For Class colors, Light mode, Color blind and a Custom theme (own border and button outline colours): the drawing of every page
    equals the one made by the code before W9a (main da9b5e9), per page and theme (sha256 and line count).
The golden values were produced by `python3 tests/theme_paint_parity_run.py --golden` on a checkout of da9b5e9 with this file and the
stand-in of this commit (tests/harness/world.lua, which now records SetGradient); `--dump DIR` writes the drawings to compare by hand.
Regenerated on 2026-11-08 (debug-log 2026-11-08-1941) for a stand-in change only: a button's GetFontString() now carries the button's
text, as in the game, so AceGUI's buttons (which read their label through it) show their label and are sized to it. Produced with
`--golden` on a checkout of main 3eb0c4b with the new tests/harness/world.lua; the branch code with the OLD world.lua still matched the
old golden (19 checks, 0 failed), so the addon changes of that commit draw nothing differently.
Re-recorded on 2026-11-09 when main came to hold XayaUI, XayaUI_Options and XayaUI_Rules only (the rule editor moved into
XayaUI_Rules/Editor/; Bonus, Chat, Dev Assist, Media and QoL went to another branch). Every change from the old golden is in the top tab
row: the QoL, Bonus Features and Blizzard Reskin tabs (pages of the retired addons) are gone and the tabs left are wider. Confirmed with
`--dump` on main e41c49e2^ with the retired addon folders deleted (core, Options, Rules and the separate Rules Options as they were):
that drawing is byte for byte the one of this commit on all 16 theme / page pairs, so neither the folder move nor any change to core,
Options or Rules draws anything differently. XayaUI_Reskin is not on main, so the Display page leaves out the Esc menu hint row
("... is under the Blizzard Reskin tab", Options.lua gm_moved) in the golden too.
Re-recorded on 2026-11-12 for round 6 (Xaya, SD-53: "put a config button in the rules pane"), with `--golden` on HEAD 89ea79a plus
the round-6 guard-setup files only: `--dump` of HEAD and of that code differ, on every theme, in (1) the Rules page: the new "Open
Combat Tracking Setup" button (20 added lines) and its page frame 15 -> 42 px high; (2) Display, and Custom's Theme page: the same
18 px buttons with the same paint, named by a lower child index (AceGUI hands out a pooled frame created earlier); 0 other lines.
Run: python3 tests/theme_paint_parity_run.py   (Lua 5.1 via lupa)"""
import hashlib, json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

GOLDEN_FILE = os.path.join(HERE, "theme_paint_parity_golden.json")
# XayaUI_Reskin (with the Esc menu's own look) is not on main: the Display page leaves out the hint row "The Esc menu's own look ... is
# under the Blizzard Reskin tab" (Options.lua gm_moved); checked below on every theme's Display drawing.

LUA = r'''
return function(W, L)
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
local T = ns.Theme
-- (Advanced customization stays off: with it on, the Theme page offers W9a's new "Use the gradient as the color of" list, an
-- options-table change that tests/options_split_parity_run.py records)
local ACD = LibStub("AceConfigDialog-3.0")
if not (ACD.OpenFrames and ACD.OpenFrames.CueRules) then pcall(ns.ToggleUI) end; W.tick(0.05, 6)
local of = ACD.OpenFrames.CueRules
local function r(x) if type(x) ~= "number" then return tostring(x) end return string.format("%.3f", x) end
local function col(c) if type(c) ~= "table" then return "-" end return r(c[1]) .. "," .. r(c[2]) .. "," .. r(c[3]) .. "," .. r(c[4]) end
local function grad(g) if type(g) ~= "table" then return "-" end return tostring(g[1]) .. ":" .. col(g[2]) .. ">" .. col(g[3]) end
local function dump(f, path, lines, depth)
  if depth > 40 then return end
  if not f:IsVisible() then return end
  lines[#lines + 1] = string.format("%s %s %s bd %s/%s", path, tostring(f:GetObjectType()), r(f:GetWidth()) .. "x" .. r(f:GetHeight()), col(f._bdcolor), col(f._bdborder))
  for i, rg in ipairs(f._regions or {}) do
    local k = rg:GetObjectType()
    if k == "Texture" then
      if rg:IsShown() then
        lines[#lines + 1] = string.format("%s.t%d a %s c %s vc %s g %s sz %s", path, i, r(rg:GetAlpha()), col(rg._color), col(rg._vc), grad(rg._grad), r(rg:GetWidth()) .. "x" .. r(rg:GetHeight()))
      end
    elseif k == "FontString" and rg:IsShown() then
      lines[#lines + 1] = string.format("%s.s%d %q c %s", path, i, tostring(rg:GetText()), col(rg._tc))
    end
  end
  for i, c in ipairs(f._kids or {}) do if c._regions then dump(c, path .. "." .. i, lines, depth + 1) end end
end
local THEMES = {
  { "class", function() T.ResetAll() end },
  { "light", function() T.ResetAll(); T.SetBase("light") end },
  { "colorblind", function() T.ResetAll(); T.SetBase("colorblind") end },
  { "custom", function() T.ResetAll(); T.SetBase("default"); T.SetToken("border", { 0.8, 0.2, 0.3, 1 }); T.SetToken("buttonBorder", { 0.1, 0.7, 0.4, 1 }) end },
}
local PAGES = {
  { "theme", { "set", "ui", "theme" } },
  { "display", { "set", "ui", "display" } },
  { "rules", { "cooldowns" } },
  { "profiles", { "profiles" } },
}
local out = {}
for _, th in ipairs(THEMES) do
  th[2](); W.tick(0.2, 6)
  for _, pg in ipairs(PAGES) do
    pcall(ACD.SelectGroup, ACD, "CueRules", unpack(pg[2])); W.tick(0.2, 6)
    if ns.DecorateTrees then pcall(ns.DecorateTrees) end; W.tick(0.1, 3)
    -- the title bar's ? and collapse arrow: shown again first, so the code before W9a (which repainted them only on show) paints them
    -- for this theme too; W9a repaints them on every skin pass (tests/theme_gradient_borders_run.py checks that part)
    local ch = of.xuiChrome
    if ch then for _, b in ipairs({ ch.arrow, ch.help }) do if b then b:Hide(); b:Show() end end end
    local lines = {}
    dump(of.frame, "win", lines, 0)
    -- (version numbers normalised: the footer and the Settings intro show XayaUI's version, which every landing changes)
    out[#out + 1] = { th[1] .. "/" .. pg[1], (table.concat(lines, "\n"):gsub("v%d+%.%d+%.%d+", "v<version>")) }
  end
end
return out
end
'''


def drawings():
    folders = H.find_addons()
    enabled = list(folders)
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    out = {res[i][1]: res[i][2] for i in range(1, len(res) + 1)}
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    return out, errs


def summary(d):
    return {k: {"sha": hashlib.sha256(v.encode()).hexdigest(), "lines": v.count("\n") + 1 if v else 0} for k, v in d.items()}


def main():
    args = sys.argv[1:]
    d, errs = drawings()
    if "--dump" in args:
        dd = args[args.index("--dump") + 1]
        os.makedirs(dd, exist_ok=True)
        for k, t in d.items():
            open(os.path.join(dd, k.replace("/", "-") + ".txt"), "w").write(t + "\n")
    if "--golden" in args:
        json.dump(summary(d), open(GOLDEN_FILE, "w"), indent=1, sort_keys=True)
        print("golden written:", GOLDEN_FILE)
        return 0
    gold = json.load(open(GOLDEN_FILE))
    got = summary(d)
    results = []
    results.append(("the same theme / page drawings were made as before W9a", sorted(got) == sorted(gold)))
    for k in sorted(gold):
        g = got.get(k)
        if k.endswith("/display"):
            ok = g is not None and g["sha"] == gold[k]["sha"] and "Blizzard Reskin tab" not in d.get(k, "")
            results.append(("%s: (XayaUI_Reskin absent) every region of the window drawn as before W9a, without the Esc menu hint row (%d lines)%s" % (k, gold[k]["lines"], "" if ok else "  [now %s lines]" % (g and g["lines"])), ok))
            continue
        ok = g is not None and g["sha"] == gold[k]["sha"]
        results.append(("%s: every region of the window drawn as before W9a (%d lines)%s" % (k, gold[k]["lines"], "" if ok else "  [now %s lines]" % (g and g["lines"])), ok))
    results.append(("drawings are not empty (the window was open and skinned)", all(v["lines"] > 50 for v in got.values())))
    results.append(("no Lua error" + ("" if not errs else "  [" + "; ".join(str(e)[:300] for e in errs[:3]) + "]"), not errs))
    bad = 0
    for name, ok in results:
        print(("PASS " if ok else "FAIL ") + name)
        bad += 0 if ok else 1
    print("%d checks, %d failed" % (len(results), bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
