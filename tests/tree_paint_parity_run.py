#!/usr/bin/env python3
"""Platform split P4b (Options 0.6.87; docs/plans/PLATFORM-SPLIT-2026-11-07.md section 7, Q1): the row painting every tab shares
(DecorateButton / DecorateTree / the feature tick boxes / left-aligned headings / ns.DecorateTrees) moved out of the rule editor into
XayaUI_Options/TreePaint.lua, with the rules tree's parts called back as hooks (ns.OptionsApi.TreePaint.rules). A pure move: what the
player sees in the window must not change. (P4b also made the editor a load-on-demand addon; since Rules 0.7.0 the editor is part of
XayaUI Rules instead: XayaUI_Rules/Editor/, set up by Options' ns.OptionsApi.LoadRuleEditor when the window loads while Rules is on.)
The options table is compared by tests/options_split_parity_run.py; this test compares what is DRAWN, which that one cannot see.
Loads the real addons in the stand-in game, sets up one fixed state (rules in nested groups, a disabled rule, a sound-only rule),
opens the window and visits every tab and Rules sub-tab (with a rule selected), runs the decorate pass and writes out every shown
tree row: key, height, alpha, mouse, the name's font, colour, text and anchor points, the insets (xuiTextL / R, xuiIconR), and for
each decoration on the row (open / close arrow, preview eye / headphone, locks, reorder arrows, feature tick box, QoL tick box,
banner, selection bar, divider, Smart Categories note, type icon) whether it is shown, its anchor points, size and tick state; and
every heading / button label's anchors and justification, and every top tab's tick box. Frame references are named by role.
  A XayaUI Rules on: the drawing equals the golden, per tab (sha256 and line count).
  B XayaUI Rules off: the same against the golden with XayaUI Rules off (the editor is not read; TreePaint paints the tabs alone).
  C V14: with XayaUI Rules off no file of XayaUI_Rules (so none of its editor) was read and the rule editor's hooks are absent; with
    it on the editor was set up with the window (ns.RuleEditorFiles run and cleared) and its hooks are registered.
The golden values were first produced by `python3 tests/tree_paint_parity_run.py --golden` on a checkout of 232552d (before P4b) and
regenerated for later deliberate changes (Bonus 0.6.38, Options 0.6.104, QoL 0.7.53, Bonus 0.6.37); `--dump DIR` writes the drawings
to compare by hand. Regenerated on 2026-11-09 for the main slim-down (main holds XayaUI, XayaUI_Options and XayaUI_Rules only; Rules
0.7.0): `--dump` of 1dc4213 (the last commit with the retired addons, whose golden this test passed there) and of the new code
differ only in (1) the top tabs QoL, Bonus Features and Blizzard Reskin, gone with their addons (3 "tab ... box" lines fewer in every
drawing; their own drawings are no longer made), and (2) the Profiles drawing's left-over tree rows, which belong to the tab visited
just before it: before, the Blizzard Reskin tree; now the Rules > Disabled tree (the first 12 lines of that drawing). The Profiles
tabs, heading and button lines, every Rules drawing (rules-selected is byte-identical) and Settings are otherwise unchanged.
Regenerated on 2026-11-12 for Bonus 0.6.45 (the Stat Calculator on main under XayaUI Bonus Features, REQUEST-LOG A24 #10): `--dump` of
origin/main ad60a05 and of the new code differ only in (1) one new line "tab bonus box false" (the Bonus Features top tab, no tick box)
in every drawing, and (2) the Rules-off Profiles drawing's left-over tree row, which belongs to the tab shown just before it: now the
Bonus Features tree's "Stat Calculator" row (one line). 0 other lines.
Regenerated on 2026-11-13 for class themes v2 (XayaUI 0.6.86, Options 0.6.109): the stand-in's player is a Demon Hunter, which now has
its own class colours. `--dump` of fda1e29 and of the new code differ in each of the 8 drawings by one line: the selected rule's text colour
(accentText, now the Demon Hunter's #E7C7F4). With every digit masked the drawings are identical. 0 other lines.
Regenerated again on 2026-11-13 (design mockup, ClassThemesV2 cards: the name on a class glow is drawn in the class's glow text
colour): `--dump` of 992bb2e and of the new code differ in one line each of rules-selected and rules-smart, the glow row ("BY TYPE (3)")
whose text colour is now the Demon Hunter's #FCE3FF (0.99 0.89 1.00) instead of the row text colour. 0 other lines.
Run: python3 tests/tree_paint_parity_run.py   (Lua 5.1 via lupa)"""
import hashlib, json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.environ.get("XUI_HARNESS") or os.path.join(HERE, "harness"))
import run as H  # noqa: E402

GOLDEN_FILE = os.path.join(HERE, "tree_paint_parity_golden.json")
LUA = r'''
return function(W, L, rulesOn)
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local ns = rawget(_G, "XayaUI_NS")
local pick
if ns.NewRule then
  local function rule(name, enabled, folder) local r = ns.NewRule(); r.name = name; r.enabled = enabled; r.folder = folder; ns.NormalizeRule(r); r.uid = r.uid or (ns.NewUID and ns.NewUID()); return r end
  ns.folders = { { id = "f1", name = "Defensives" }, { id = "f2", name = "Inner", parent = "f1" }, { id = "f3", name = "Sounds" } }
  local A = rule("Shell", true, "f1"); A.useBuff, A.buffID, A.buffState = true, 48707, "present"; A.visual.enabled = true; A.visual.trigger = "condition"
  local B = rule("Cooldown watch", true, "f2"); B.spellID = 47528; B.cdState = "ready"; B.visual.enabled = true
  local C = rule("Switched off", false, "f1")
  local D = rule("Sound only", true, "f3"); D.spellID = 49576; D.sound.enabled, D.sound.source, D.sound.value = true, "kit", "8959"
  local E = rule("Top level", true, nil); E.spellID = 6789
  ns.rules = { A, B, C, D, E }
  CueRulesDB.rules = ns.rules
  pick = B
end
if ns.ToggleUI then pcall(ns.ToggleUI) end
W.tick(0.1, 6)
ns = rawget(_G, "XayaUI_NS")
local ACD = LibStub("AceConfigDialog-3.0")
local out = {}
local function r1(x) if type(x) ~= "number" then return tostring(x) end return string.format("%.2f", x) end
local function role(f, b)
  if f == nil then return "nil" end
  if f == b then return "row" end
  if b and f == b.text then return "row.text" end
  if f == UIParent then return "UIParent" end
  if b and f == b.xuiIcon then return "row.icon" end
  return type(f)
end
local function pts(f, b)
  if not (f and f.GetNumPoints) then return "-" end
  local o = {}
  for i = 1, f:GetNumPoints() do
    local p, rel, rp, x, y = f:GetPoint(i)
    o[#o + 1] = tostring(p) .. ">" .. role(rel, b) .. "." .. tostring(rp) .. "(" .. r1(x) .. "," .. r1(y) .. ")"
  end
  table.sort(o)
  return table.concat(o, " ")
end
local function sz(f) if not (f and f.GetWidth) then return "-" end return r1(f:GetWidth()) .. "x" .. r1(f:GetHeight()) end
local DECOS = { "xuiChev", "xuiEye", "xuiHead", "xuiEdit", "xuiMove", "xuiUp", "xuiDown", "xuiSwitchBox", "xuiStatCheck", "xuiSub",
  "xuiBanner", "xuiBannerBar", "xuiSelTex", "xuiDivider", "xuiType", "xuiType2", "xuiMultiTex" }
local function rows()
  local found = {}
  local function walk(f, d)
    if not f or d > 60 then return end
    if f.uniquevalue and f.IsShown and f:IsShown() then found[#found + 1] = f end
    for _, c in ipairs(f.GetChildren and { f:GetChildren() } or {}) do walk(c, d + 1) end
  end
  walk(UIParent, 0)
  return found
end
local function dumpRow(b, lines)
  local t = b.text
  local fp, fs, ff = "", "", ""
  if t and t.GetFont then fp, fs, ff = t:GetFont() end
  local cr, cg, cb = 0, 0, 0
  if t and t.GetTextColor then cr, cg, cb = t:GetTextColor() end
  lines[#lines + 1] = string.format("row %s | h %s a %s mouse %s | font %s %s %s | col %s %s %s | text %q | %s | L %s R %s icR %s twoRow %s",
    tostring(b.uniquevalue):gsub("\001", "/"), r1(b:GetHeight()), r1(b:GetAlpha()), tostring(b:IsMouseEnabled()), tostring(fp), r1(fs), tostring(ff),
    r1(cr), r1(cg), r1(cb), t and tostring(t:GetText()) or "", pts(t, b), tostring(b.xuiTextL), tostring(b.xuiTextR), tostring(b.xuiIconR), tostring(b.xuiTwoRow))
  for _, k in ipairs(DECOS) do
    local d = b[k]
    if d and d.IsShown and d:IsShown() then
      local chk = d.GetChecked and tostring(d:GetChecked()) or ""
      local en = d.IsEnabled and tostring(d:IsEnabled()) or ""
      local tx = (d.GetText and d:GetObjectType() == "FontString") and tostring(d:GetText()) or ""
      lines[#lines + 1] = string.format("  %s %s %s %s %s %s", k, pts(d, b), sz(d), chk, en, tx)
    end
  end
end
local function dumpWidgets(w, lines, depth)
  if not w or depth > 16 then return end
  if (w.type == "Heading" and w.label) then lines[#lines + 1] = "heading " .. tostring(w.label:GetText()) .. " | " .. pts(w.label, nil) .. " " .. tostring(w.label:GetJustifyH()) end
  if (w.type == "Button" and w.text) then lines[#lines + 1] = "button " .. tostring(w.text:GetText()) .. " | " .. tostring(w.text:GetJustifyH()) end
  if w.type == "TabGroup" and w.tabs then
    for _, tab in ipairs(w.tabs) do
      if tab:IsShown() then lines[#lines + 1] = "tab " .. tostring(tab.value) .. " box " .. tostring(tab.xuiTabBox and tab.xuiTabBox:IsShown() or false) end
    end
  end
  for _, c in ipairs(w.children or {}) do dumpWidgets(c, lines, depth + 1) end
end
local function visit(name, ...)
  pcall(ACD.SelectGroup, ACD, "CueRules", ...)
  W.tick(0.2, 4)
  if ns.DecorateTrees then pcall(ns.DecorateTrees) end
  W.tick(0.1, 2)
  local lines = {}
  local rs = rows()
  table.sort(rs, function(a, b) local ta, tb = a:GetTop() or 0, b:GetTop() or 0; if ta ~= tb then return ta > tb end return tostring(a.uniquevalue) < tostring(b.uniquevalue) end)
  for _, b in ipairs(rs) do dumpRow(b, lines) end
  local of = ACD.OpenFrames and ACD.OpenFrames.CueRules
  if of then dumpWidgets(of, lines, 0) end
  out[#out + 1] = { name, table.concat(lines, "\n") }
end
if ns.rules and pick then
  visit("rules-enabled", "cooldowns", "enabledTab")
  if ns.EditRule then pcall(ns.EditRule, pick); W.tick(0.2, 4) end
  local of = ACD.OpenFrames and ACD.OpenFrames.CueRules
  local lines = {}
  if ns.DecorateTrees then pcall(ns.DecorateTrees) end; W.tick(0.1, 2)
  local rs = rows()
  table.sort(rs, function(a, b) local ta, tb = a:GetTop() or 0, b:GetTop() or 0; if ta ~= tb then return ta > tb end return tostring(a.uniquevalue) < tostring(b.uniquevalue) end)
  for _, b in ipairs(rs) do dumpRow(b, lines) end
  out[#out + 1] = { "rules-selected", table.concat(lines, "\n") }
  visit("rules-smart", "cooldowns", "smartTab")
  visit("rules-disabled", "cooldowns", "disabledTab")
end
for _, tab in ipairs({ "profiles", "set" }) do visit(tab, tab) end
local hooks = ns.OptionsApi and ns.OptionsApi.TreePaint and ns.OptionsApi.TreePaint.rules
-- (Rules 0.7.0) the editor's files (XayaUI_Rules/Editor/) each add one set-up function to ns.RuleEditorFiles; LoadRuleEditor runs
-- them and clears the list, so a list still there means the editor was read but not set up
return out, (hooks ~= nil), (rawget(ns, "RuleEditorFiles") ~= nil)
end
'''


def run_variant(rules_on):
    folders = H.find_addons()
    enabled = [n for n in folders if rules_on or n != "XayaUI_Rules"]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    res, hooks, pending = L.eval("function(src, W, Ld, on) return loadstring(src)()(W, Ld, on) end")(LUA, world, loader, rules_on)
    tabs = {res[i][1]: res[i][2] for i in range(1, len(res) + 1)}
    loaded = [loader.loadedOrder[i] for i in range(1, len(loader.loadedOrder) + 1)]
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    return tabs, bool(hooks), loaded, errs, bool(pending)


def summary(tabs):
    return {k: {"sha": hashlib.sha256(v.encode()).hexdigest(), "lines": v.count("\n") + 1 if v else 0} for k, v in tabs.items()}


def main():
    args = sys.argv[1:]
    on = run_variant(True)
    off = run_variant(False)
    if "--dump" in args:
        d = args[args.index("--dump") + 1]
        os.makedirs(d, exist_ok=True)
        for label, v in (("on", on), ("off", off)):
            for k, t in v[0].items():
                open(os.path.join(d, "%s-%s.txt" % (label, k)), "w").write(t + "\n")
    if "--golden" in args:
        json.dump({"on": summary(on[0]), "off": summary(off[0])}, open(GOLDEN_FILE, "w"), indent=1, sort_keys=True)
        print("golden written:", GOLDEN_FILE)
        return 0
    gold = json.load(open(GOLDEN_FILE))
    results = []

    def check(name, ok, detail=""):
        results.append((name + (("  [" + detail + "]") if detail and not ok else ""), bool(ok)))

    for label, v in (("XayaUI Rules on", on), ("XayaUI Rules off", off)):
        tabs, hooks, loaded, errs, pending = v
        want = gold["on" if v is on else "off"]
        got = summary(tabs)
        check("[%s] the same tabs were drawn as before P4b" % label, sorted(got) == sorted(want), "%s vs %s" % (sorted(got), sorted(want)))
        for k in sorted(want):
            g = got.get(k)
            check("[%s] %s: every row, decoration, heading and tab box drawn as before P4b (%d lines)" % (label, k, want[k]["lines"]),
                  g is not None and g["sha"] == want[k]["sha"], "now %s lines" % (g and g["lines"]))
        check("[%s] no Lua error" % label, not errs, "; ".join(str(e)[:300] for e in errs[:3]))
    # (Rules 0.7.0) the rule editor is part of XayaUI Rules (XayaUI_Rules/Editor/), set up by Options' LoadRuleEditor when the window
    # loads; there is no XayaUI_Rules_Options addon any more
    tabs, hooks, loaded, errs, pending = on
    check("[XayaUI Rules on] V14: XayaUI_Rules (with its editor files) and XayaUI_Options loaded, the editor was set up with the window and its row hooks are registered",
          "XayaUI_Rules" in loaded and "XayaUI_Options" in loaded and "XayaUI_Rules_Options" not in loaded and not pending and hooks,
          "loaded %s, editor files left unset %s, hooks %s" % (loaded, pending, hooks))
    tabs, hooks, loaded, errs, pending = off
    check("[XayaUI Rules off] V14: no file of XayaUI_Rules (so none of its editor) was read and no rule hook is registered",
          "XayaUI_Rules" not in loaded and not pending and not hooks and "XayaUI_Options" in loaded,
          "loaded %s, editor files left unset %s, hooks %s" % (loaded, pending, hooks))
    bad = 0
    for name, ok in results:
        print(("PASS " if ok else "FAIL ") + name)
        bad += 0 if ok else 1
    print("%d checks, %d failed" % (len(results), bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
