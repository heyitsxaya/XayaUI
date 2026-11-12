#!/usr/bin/env python3
"""Platform split P3 "Options split" (Options 0.6.83; docs/plans/PLATFORM-SPLIT-2026-11-07.md sections 7, 10 and risk R8): the rule
editor and the rules tree moved out of XayaUI_Options/Options.lua (then to XayaUI_Options/RuleEditor/, later the addon
XayaUI_Rules_Options, since Rules 0.7.0 XayaUI_Rules/Editor/). A pure code move: the player must get exactly the same settings window.
Loads the real addons of this branch (XayaUI, XayaUI_Options, XayaUI_Rules with its rule editor) in the stand-in game, sets up one fixed
state (rules with cues and an outcome, nested groups, a disabled rule, a buff bar, a Recycle Bin item, a fixed clock) and builds the whole
options table (ns.BuildOptionsTable, every page of every module that is on). Every node is written out: its key path, type, order, width,
name, desc, the results of hidden / disabled / get / values / sorting / confirm / image called with an AceConfig-style info table, and
every other plain field; functions that change something (set, func, validate) are only noted as present. Version strings, table
addresses, dates and error positions are normalised.
  A The dump of the new code equals the golden dump, compared per top tab (sha256 and node count), with every addon on.
  C The rule editor's own files register no settings page of their own (rules / core / cooldowns), and no module registers a page
    (this branch holds no feature addon with settings pages).
  D (P4, platform split) XayaUI Rules switched off: the window is the all-on window minus exactly the rules' own parts (the Rules tab,
    the rule list rows and Rule Creation tab of Settings, the backups and the "Rules and groups" part of Profiles); every other line is
    the same. Fails on the code before P4 (there is no XayaUI_Rules folder to switch off: the Rules tab and the backups stay).
  (B, the same comparison with each feature addon switched off in turn, and C's V14 checks of those addons' pages were removed with
  them: XayaUI Chat, QoL, Bonus Features, Blizzard Reskin, Dev Assist, Nameplates and Media are not on this branch, REQUEST-LOG A23.)
Regenerated on 2026-11-09 for the main slim-down (REQUEST-LOG A23; Rules 0.7.0, Options 0.6.107): the golden now holds the all-on
window of this branch only. Confirmed before recording: (1) the dump of this code is byte for byte the dump of the code before the
slim-down (1dc42131, with XayaUI_Rules_Options as its own addon) run with the feature addons' folders taken away (5 top tabs, 7205
lines, same hashes, same registered pages), so the editor's move changed nothing; (2) the dump of 1dc42131 with its feature addons
present reproduces the old golden's all-on "cooldowns" and "settings" hashes, and differs from this code's dump only in lines of the
retired addons: their top tabs (qol, bonus, reskin), their Profiles parts (inc_ / imp_ bonus, qol; Blizzard Reskin's part 2 places
up), their minimap list rows (Notes, Calculator, Stat Calculator, Data Panels, Chat Panel, Improved Chat, Chat privacy cover;
"XayaUI Settings" 4 -> 1), Dev Assist's Settings > Debugging rows (devPages, gameDump, sendDev: now hidden), their registered pages,
and 4 "cooldowns" lines whose order 1.05 the old dump printed as "<version>5" (XayaUI_Media's version "1.0" was normalised away
inside the number); 0 other lines.
History of the golden before the slim-down (recorded with the feature addons then on main):
The golden values below were produced by `python3 tests/options_split_parity_run.py --golden` on a checkout of bd03eb5 (the code
before the move). Regenerated once on 2026-11-08 for XayaUI 0.6.79 (PS-57, #480: reskin and module switches take effect on reload):
the dumps before and after differed in exactly 16 lines (all-on variant; 5 to 16 per variant), each only in the `desc` text of a reskin or module switch that said it applied at once
(Improved Chat, Chat Panel, Character Pane, Esc Menu, Shopping List, the 10 Blizzard Reskin pages, the Overview's "Enable Blizzard
Reskin", in every variant where that page exists); node counts, names, get / hidden / disabled results unchanged (debug-log
2026-11-08 conflicts-reload). Regenerated again on 2026-11-08 for Rules Options 0.6.79 (debug W1, #476: the Specialization lists follow
the game's spec count per class): only the "cooldowns" tab changed, in every variant, 6855 -> 6686 nodes; `--dump` of main b0723dd and of
the new code differ only in lines whose path holds `.specs` (every Specialization list; the 13 rule Load tabs drawn in full lose 13 tick boxes each: the stand-in's C_SpecializationInfo.GetNumSpecializationsForClassID
answers 3, so each class lists 3 specs instead of the 4 indexes the old loop read), 0 other lines (debug-log 2026-11-08 debug-w1). Regenerated again on 2026-11-08 for Options 0.6.97 (debug W3, #471): only the "set" and "settings"
tabs changed (the Theme page), in every variant, +48 nodes; `--dump` of main 1f7352b and of the new code differ in 280 lines per variant, all under
`theme.overrides.` (each class box's colours and Reset become table cells, plus an empty cell per missing colour) or `theme.delete`
(arg.xuiEndMargin), 0 other lines (debug-log 2026-11-08 debug-w3). Regenerated again on 2026-11-08 for Options 0.6.102 (debug W9a, #460):
only the "set" and "settings" tabs changed (the Theme page), in every variant, +2 nodes each; `--dump` of main da9b5e9 and of the new code
differ only under `theme.` (new `gradRev` and `gradTokens`, the `advanced` desc, and the `order` of the nodes after them); with order
numbers set aside, 0 other lines (debug-log 2026-11-08 debug-w9a). Regenerated again on 2026-11-08 for Options 0.6.104 / Reskin 0.6.24
(debug W9b, #472): only the "reskin" tab changed; `--dump` of accb5c8 and of the new code differ (all-on: 275 lines) only in the new
Blizzard Reskin > Theme page (`reskin.rsktheme.*`), one `xuiTheme` row ("Theme") on each element's page, the Esc Menu's Colors group
removed (`reskin.gamemenu.colors.*`, now its Theme row) with a desc on its Reset, and the `order` of the two pages sorted after "Theme"
(Toasts and Pop-ups, Tooltips); 0 other lines (debug-log 2026-11-08 debug-w9b). Regenerated again on 2026-11-08 for Chat 0.6.46 (debug
chat defaults): only the "qol" tab changed, in every variant where XayaUI Chat is on, same node count; `--dump` of 1b974fe and of the new
code differ in 16 lines per variant, all `qol.improvedchat.privacy.*` and only in their get() result (nil before: the privacy cover's
defaults never reached the saved settings in the game; now each shows its default, e.g. Button size 28, Color 0.04 | 0.04 | 0.06), 0 other
lines (debug-log 2026-11-08 debug-chatdefaults). Regenerated again on 2026-11-08 for QoL 0.7.53 (character pane split stage 1, C20): only the
"qol" and "reskin" tabs changed, in every variant where XayaUI QoL is on (QoL off: 0 lines); `--dump` of f870d78 and of the new code differ
(all-on: 609 lines) only in the four feature controls and the Stat list page moving from `reskin.charreskin.*` (ilvl, enchants, gems,
statList, statListPage: 299 nodes) to `qol.charpane.*`, node for node the same after the path (names, descs, orders, get / hidden /
disabled results), the new page node `qol.charpane` ("Character Pane", its switch), and the `order` of the QoL pages sorted after it
(Character Toolkit, Cursor, Improved Chat, Nameplates, Release Guard: +1); 0 other lines (debug-log 2026-11-08 character-split). Regenerated
again on 2026-11-08 for Bonus 0.6.37 / QoL 0.7.53 (character pane split stage 2): `--dump` of stage 1 and of the new code differ only in
(all-on, 246 lines; every variant with XayaUI QoL and Bonus Features on the same) the Stat Calculator's Panel and Spell Math parts moving
from `qol.chartoolkit.*` (panelPart, spells: 117 nodes) to `bonus.statcalc.*`, node for node the same after the path; the new page node
`bonus.statcalc` ("Character Toolkit", its own switch, the toolkit's switch texts) and its intro (the toolkit's, its parts list now
"(Panel, Spell Math)"); the `order` of the Bonus pages after it (+1); QoL's `qol.chartoolkit` switch tip and intro (they named the Stat
Calculator). XayaUI Bonus Features off (139 lines): the two parts gone with it, the minimap list's "Stat Calculator" row gone
(`settings.minimap.entries.stats`, `set.minimap.entries.stats`: the row is Bonus's) and the rows after it one `order` up, and the two QoL
texts. XayaUI QoL off: 0 lines (Bonus Features shows nothing of it). Regenerated again on 2026-11-08 for Options 0.6.105 (the Theme table's rows, REQUEST-LOG session 014bN6tUDLJ6T742DewZDg1s #7): only the
"reskin" tab changed; `--dump` of 3eb0c4b and of the new code differ only in the relWidth of the table's Element cells (h_el and every
el_*, 0.24 -> 0.25: 17 lines changed, i.e. 34 diff lines all-on), 0 other lines in every variant (debug-log 2026-11-08-1941). Regenerated
again on 2026-11-08 for Rules Options 0.6.82 ("Maintain aspect ratio", REQUEST-LOG session 014bN6tUDLJ6T742DewZDg1s rows 24-25): only the
"cooldowns" tab changed, in every variant, 6686 -> 6690 nodes; `--dump` of 1c7ca2b and of the new code differ in exactly 4 added lines per
variant, each the new `pageGroup.size.body.aspect` tick box (name "Maintain aspect ratio", order 2.5, get() false) on one of the 4 group
pages the fixed state draws, 0 other lines (debug-log 2026-11-08 aspect-ratio). Regenerated again on 2026-11-08 for Rules Options 0.6.82 (Count options, REQUEST-LOG session 014bN6tUDLJ6T742DewZDg1s #26): `--dump` of
4bbf585 and of the new code differ only in the "Count of" selects inside each cue's Count options pane (`...cnt.body.pane_cnt.body.source`,
14 lines per variant, all-on): the old golden held `sorting()=ERR <src>: attempt to index field 'source' (a nil value)`, i.e. it had
recorded the bug; now the list's order (e.g. {1="none",2="stacks"}). 0 other lines in every variant (debug-log 2026-11-08 count-options). Regenerated again on 2026-11-08 for Bonus 0.6.38 (REQUEST-LOG session 014bN6tUDLJ6T742DewZDg1s #37, "these are \"Stat Calculator\""):
only the "bonus" tab, in every variant where XayaUI Bonus is on: `bonus.statcalc` is named "Stat Calculator" (was "Character Toolkit",
its switch too), and the Bonus pages, sorted by name, renumber: Data Panels 2 -> 1, Enhanced Tooltips 3 -> 2, Stat Calculator 1 -> 3
(3 lines per variant), plus the desc texts that named the path "Bonus Features > Character Toolkit" (now "... > Stat Calculator"; e.g. qol.chartoolkit.intro); 0 other lines. Regenerated again on 2026-11-08 for American spelling (FA-16, tests/american_spelling_run.py; Chat 0.6.47, Nameplates 0.2.4, Reskin 0.6.25, Rules Options 0.6.82): `--dump` of 4e4e4be and of the new code
differ in 22-25 lines per variant (same line and node counts), each only in words of a name / desc / values text: gray -> grey, Grays -> Greys,
ungrayed -> ungreyed (her exception; the Opacity & Fill / Overlay Layer descs and "(none - grey)"), colour(s / ed) -> color(s / ed), Colours -> Colors
(the Nameplates page and its switch, Friend Colors' Social note, the chat Sidebar's Background desc); a word-by-word comparison found 0 other differences. Regenerated again on 2026-11-09 (merge of the group anchors build): one help text under the group position settings respelled ("centre" -> "center", FA-16); 0 other lines. `--dump DIR` writes the full dumps, one file per variant, to compare by hand (diff) when a check fails.
recorded the bug; now the list's order (e.g. {1="none",2="stacks"}). 0 other lines in every variant (debug-log 2026-11-08 count-options).
Regenerated again on 2026-11-08 for Rules 0.6.82 (group anchors, REQUEST-LOG session 014bN6tUDLJ6T742DewZDg1s rows 14, 18, 28): only the
"cooldowns" tab changed, in every variant, 6690 -> 6694 nodes; `--dump` of 897ae70 and of the new code differ in exactly 8 removed and 12
added lines per variant, on the 4 group pages the fixed state draws: `pageGroup.container` (only its xuiInfo, the settings note that now
says what the anchor point refers to), `pageGroup.container.rel` (only its sorting / values: "Another group" added last) and the new
`pageGroup.container.relGroup` select ("Group", order 4.25, hidden while Relative to is not Another group), 0 other lines in every variant
(debug-log 2026-11-08 group-anchors). `--dump DIR` writes the full dumps, one file per variant, to compare by hand (diff) when a check fails.
Regenerated on 2026-11-12 for Bonus 0.6.45 (the Stat Calculator on main under XayaUI Bonus Features, REQUEST-LOG A24 #10): `--dump` of
origin/main ad60a05 and of the new code (all-on) differ only in the new top tab `bonus` and its 118 `bonus.statcalc.*` lines (the
Stat Calculator page as on qa-installer-branch, with the panel switch's and intro's texts for main), the minimap list's new "Stat
Calculator" row (`set.minimap.entries.stats`, `settings.minimap.entries.stats`: hidden while the Stat Calculator is off) and the
"XayaUI Settings" row after it one `order` down (1 -> 2), 0 other lines. The new variant off-XayaUI_Bonus has the hashes the all-on
window had before (ad60a05's golden) for every tab but "cooldowns" (same node count), whose dump differs from ad60a05's all-on dump
only in the random group and rule ids (the second window built in the process: see main() below), 0 other lines. C now expects the Bonus Features page "statcalc" and no other module page.
Regenerated on 2026-11-12 for Bonus 0.6.46 / Options 0.6.108 (REQUEST-LOG A24 #12 / #13: the Stat Calculator loads on demand; its
settings travel in profiles): `--dump` of c4ae19b and of the new code (all-on, the Stat Calculator off as in a fresh install) differ
only in (1) `bonus.statcalc`: its switch's desc (her option text "Off means it is never read; on means it loads once per reload."),
the 118 `bonus.statcalc.*` lines of the detailed page gone (they come with the loaded calculator) and one `bonus.statcalc.note` line
added; (2) Profiles: the new "Bonus Features" tick box under Export (`inc_bonus`, order 5) and Import (`imp_bonus`, order 8), with
"Blizzard Reskin" one place down (5 -> 6, 8 -> 9); 0 other lines. off-XayaUI_Bonus: 0 lines differ.
Run: python3 tests/options_split_parity_run.py"""
import hashlib, json, os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.environ.get("XUI_HARNESS") or os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

GOLDEN_FILE = os.path.join(HERE, "options_split_parity_golden.json")
# (REQUEST-LOG A23) this branch held no feature addon to switch off in turn. (Bonus 0.6.45, A24 #10) XayaUI Bonus Features is on main
# with the Stat Calculator only: the golden holds the all-on window and the window with it switched off
MODULES = ["XayaUI_Bonus"]


LUA = r'''
return function(W, L)
-- a fixed clock: Recycle Bin dates and "removed for good in" read time() / date()
local T0 = 1790000000
local osdate, ostime = os.date, os.time
rawset(_G, "time", function(t) if t then return ostime(t) end return T0 end)
rawset(_G, "date", function(f, t) return osdate(f, t or T0) end)
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 10)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 3)
ns = rawget(_G, "XayaUI_NS")
if not (ns and ns.BuildOptionsTable) then return { "the settings window did not load" } end
-- the fixed state (P4: none while XayaUI Rules is off; there are no rules then)
if ns.NewRule then
local function rule(name, enabled) local r = ns.NewRule(); r.name = name; r.enabled = enabled; ns.NormalizeRule(r); return r end
ns.folders = {}
local g1 = ns.NewFolder and ns.NewFolder("Group One") or nil
local g2 = ns.NewFolder and g1 and ns.NewFolder("Inner Group", g1.id) or nil
local A = rule("Shell", true); A.useBuff = true; A.buffID = 48707; A.buffState = "present"
local B = rule("Cooldown watch", true); B.spellID = 47528; B.cdState = "ready"; if g1 then B.folder = g1.id end
local C = rule("Switched off", false); if g2 then C.folder = g2.id end
local D = rule("Sound only", true); D.spellID = 49576
ns.rules = { A, B, C, D }
pcall(ns.NewCueRule, A, "icon"); pcall(ns.NewCueRule, A, "text"); pcall(ns.NewCueRule, D, "sound"); pcall(ns.NewCueRule, B, "bar")
local E = rule("Deleted later", true); ns.rules[#ns.rules + 1] = E
if ns.RecycleRule then pcall(ns.RecycleRule, E) end
if ns.MarkDirty then pcall(ns.MarkDirty) end
end
W.tick(0.1, 3)
local root = ns.BuildOptionsTable()
-- the dump
local lines = {}
local function norm(s)
  s = tostring(s)
  s = s:gsub("0x%x+", "<addr>"):gsub("(%a+): <addr>", "%1"):gsub("%d%d%d%d%-%d%d%-%d%d %d%d:%d%d", "<date>")
  s = s:gsub("[%w_/%.%-]+%.lua:%d+:", "<src>:")
  return s
end
local function ser(v, depth, seen)
  local t = type(v)
  if t == "function" then return "fn" end
  if t == "string" then return (string.format("%q", norm(v)):gsub("\\\n", "\\n")) end   -- one line per node
  if t ~= "table" then return norm(v) end
  seen = seen or {}
  if seen[v] then return "<cycle>" end
  if depth > 4 then return "{...}" end
  seen[v] = true
  local keys = {}
  for k in pairs(v) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  local out = {}
  for _, k in ipairs(keys) do out[#out + 1] = tostring(k) .. "=" .. ser(v[k], depth + 1, seen) end
  seen[v] = nil
  return "{" .. table.concat(out, ",") .. "}"
end
local CALL = { name = true, desc = true, hidden = true, disabled = true, get = true, values = true, sorting = true, confirm = true,
  image = true, imageWidth = true, imageHeight = true, order = true, width = true, descStyle = true, confirmText = true }
local function call(fn, info)
  local res = { pcall(fn, info) }
  if not res[1] then return "ERR " .. norm(res[2]) end
  local out = {}
  for i = 2, math.max(2, table.maxn(res)) do out[#out + 1] = ser(res[i], 0) end
  return table.concat(out, " | ")
end
local function walk(node, path, depth)
  if type(node) ~= "table" or depth > 40 then return end
  local info = { options = root, option = node, arg = node.arg, type = node.type, handler = node.handler, uiType = "dialog",
    uiName = "CueRules", appName = "CueRules" }
  for i, k in ipairs(path) do info[i] = k end
  local keys = {}
  for k in pairs(node) do if k ~= "args" and k ~= "plugins" then keys[#keys + 1] = k end end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  local parts = {}
  for _, k in ipairs(keys) do
    local v = node[k]
    if type(v) == "function" and CALL[k] then parts[#parts + 1] = tostring(k) .. "()=" .. call(v, info)
    else parts[#parts + 1] = tostring(k) .. "=" .. ser(v, 1) end
  end
  lines[#lines + 1] = table.concat(path, ".") .. " :: " .. table.concat(parts, " ; ")
  if type(node.args) == "table" then
    local ks = {}
    for k in pairs(node.args) do ks[#ks + 1] = k end
    table.sort(ks, function(a, b) return tostring(a) < tostring(b) end)
    for _, k in ipairs(ks) do
      local p = {}
      for i, x in ipairs(path) do p[i] = x end
      p[#p + 1] = tostring(k)
      walk(node.args[k], p, depth + 1)
    end
  end
end
walk(root, {}, 0)
-- C: which modules registered pages
local reg = {}
for _, m in ipairs({ "chat", "qol", "bonus", "reskin", "debugging", "nameplates", "media", "rules", "core", "cooldowns" }) do
  local ks = {}
  for k in pairs(ns.BuildSettingsPages(m, function() end)) do ks[#ks + 1] = k end
  table.sort(ks)
  reg[#reg + 1] = m .. "=" .. table.concat(ks, ",")
end
return { "ok", table.concat(lines, "\n"), table.concat(reg, " ") }
end
'''


def versions():
    out = {}
    for name, d in H.find_addons().items():
        toc = open(os.path.join(d, name + ".toc"), encoding="utf-8").read()
        m = re.search(r"^## Version:\s*(\S+)", toc, re.M)
        if m:
            out[name] = m.group(1)
    return out


def run_variant(off):
    folders = H.find_addons()
    enabled = [n for n in folders if n != off]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    errs = [str(world.errors[i]) for i in range(1, len(world.errors) + 1)]
    if res[1] != "ok":
        return None, None, errs + [str(res[1])]
    dump = str(res[2])
    # version strings: the addons whose code changes take a new version; the dump must not depend on it
    for name, ver in sorted(versions().items(), key=lambda kv: -len(kv[1])):
        dump = dump.replace(ver, "<version>")
    return dump, str(res[3]), errs


def summarise(dump):
    tabs = {}
    for line in dump.split("\n"):
        path = line.split(" :: ", 1)[0]
        top = path.split(".", 1)[0] if path else "<root>"
        tabs.setdefault(top, []).append(line)
    return {t: [hashlib.sha256("\n".join(ls).encode("utf-8")).hexdigest()[:16], len(ls)] for t, ls in sorted(tabs.items())}


def main():
    dump_dir = None
    if "--dump" in sys.argv:
        dump_dir = sys.argv[sys.argv.index("--dump") + 1]
        os.makedirs(dump_dir, exist_ok=True)
    # the groups' ids come from the process-wide random sequence, so the "cooldowns" hash only matches when the all-on window is the
    # first one built in the process, as when the golden was recorded
    variants = [None] + MODULES
    results = {}
    errs_all = []
    for off in variants:
        tag = "all-on" if off is None else ("off-" + off)
        dump, reg, errs = run_variant(off)
        errs_all += [(tag, e) for e in errs]
        if dump is None:
            results[tag] = None
            continue
        if dump_dir:
            open(os.path.join(dump_dir, tag + ".txt"), "w", encoding="utf-8").write(dump + "\n")
        results[tag] = {"tabs": summarise(dump), "registered": reg}
    if "--golden" in sys.argv:
        json.dump(results, open(GOLDEN_FILE, "w", encoding="utf-8"), indent=1, sort_keys=True)
        print("golden written: %s (%d variants, %d Lua errors)" % (GOLDEN_FILE, len(results), len(errs_all)))
        for tag, e in errs_all:
            print("ERROR in the game stand-in [%s]: %s" % (tag, e[:400]))
        return
    golden = json.load(open(GOLDEN_FILE, encoding="utf-8"))
    total = bad = 0

    def check(name, ok, detail=""):
        nonlocal total, bad
        total += 1
        if not ok:
            bad += 1
        print(("PASS " if ok else "FAIL ") + name + (("  " + detail) if (detail and not ok) else ""))

    for off in [None] + MODULES:
        tag = "all-on" if off is None else ("off-" + off)
        got, want = results.get(tag), golden.get(tag)
        check("[%s] the options table builds" % tag, got is not None)
        if got is None or want is None:
            check("[%s] golden present" % tag, want is not None)
            continue
        keys = sorted(set(got["tabs"]) | set(want["tabs"]))
        for t in keys:
            nm = "[%s] %s: same nodes, names, descs, types, widths, hidden / disabled / get results as before the move" % (tag, t)
            check(nm, got["tabs"].get(t) == want["tabs"].get(t), "got %s want %s" % (got["tabs"].get(t), want["tabs"].get(t)))
        check("[%s] the same settings pages are registered per module" % tag, got["registered"] == want["registered"],
              "got %s want %s" % (got["registered"], want["registered"]))
    # D (P4) XayaUI Rules switched off: no golden from the old code (the module did not exist). The window is the all-on window minus
    # exactly what belongs to the rules (the Rules tab, the rule list rows and the Rule Creation tab of Settings, the backups and the
    # "Rules and groups" tick boxes of Profiles); everything else is line for line the same. Lines that differ for a known reason:
    # the Recycle Bin (no rule could be deleted into it) and the order numbers of the other profile parts (one part fewer before them).
    on_dump, _, _ = run_variant(None)
    off_dump, off_reg, off_errs = run_variant("XayaUI_Rules")
    errs_all += [("off-XayaUI_Rules", e) for e in off_errs]
    check("[off-XayaUI_Rules] the options table builds", off_dump is not None)
    if off_dump is not None and on_dump is not None:
        on_lines, off_lines = set(on_dump.split("\n")), set(off_dump.split("\n"))
        path = lambda l: l.split(" :: ", 1)[0]
        RULES_ONLY = re.compile(r"^(cooldowns(\..*)?|(set\.ui|settings)\.rules(\..*)?|(set\.ui\.display|settings\.ui)\.(displayHeader|parentGradient|"
                                r"selStyle|sidebarSpellIcons)|profiles\.export\.(savedH|backupIntro|saveName|savePick|save|p\d+(\..*)?)|"
                                r"profiles\.(export\.inc|import\.imp)_rules)$")
        KNOWN = re.compile(r"^(profiles\.bin(\..*)?|profiles\.(export\.inc|import\.imp)_\w+)$")
        removed = sorted(path(l) for l in on_lines - off_lines)
        added = sorted(path(l) for l in off_lines - on_lines)
        check("[off-XayaUI_Rules] the Rules tab is absent", not any(path(l) == "cooldowns" for l in off_lines))
        check("[off-XayaUI_Rules] the Rule Creation tab, the rule list rows and the backups are absent",
              not any(re.match(r"^((set\.ui|settings)\.rules|profiles\.export\.(savedH|save|saveName|savePick))$", path(l)) for l in off_lines))
        bad_removed = [p for p in removed if not (RULES_ONLY.match(p) or KNOWN.match(p))]
        bad_added = [p for p in added if not KNOWN.match(p)]
        check("[off-XayaUI_Rules] every other line of the window is the same as with XayaUI Rules on (%d lines gone, all the rules' own)" % len(removed),
              not bad_removed and not bad_added, "unexpected: gone %s / new %s" % (bad_removed[:8], bad_added[:8]))
        inc_on = sorted(re.search(r'name="([^"]+)"', l).group(1) for l in on_lines if path(l).startswith("profiles.export.inc_"))
        inc_off = sorted(re.search(r'name="([^"]+)"', l).group(1) for l in off_lines if path(l).startswith("profiles.export.inc_"))
        check("[off-XayaUI_Rules] Profiles > Export offers every part but \"Rules and groups\"",
              inc_off == sorted(x for x in inc_on if x != "Rules and groups") and "Rules and groups" in inc_on, "%s / %s" % (inc_on, inc_off))
        reg = dict(x.split("=", 1) for x in (off_reg or "").split())
        check("[off-XayaUI_Rules] the other modules register the same settings pages as with it on",
              off_reg == results["all-on"]["registered"], "%s / %s" % (off_reg, results["all-on"]["registered"]))
    allon = results.get("all-on")
    if allon:
        reg = dict(x.split("=", 1) for x in allon["registered"].split())
        check("the rule editor registers no settings page of its own (rules / core / cooldowns)",
              all(reg.get(m) == "" for m in ("rules", "core", "cooldowns")))
        check("no module registers a settings page but XayaUI Bonus Features' Stat Calculator (bonus = statcalc; main holds no other feature addon with pages)",
              all(v == "" for k, v in reg.items() if k != "bonus") and reg.get("bonus") == "statcalc" and len(reg) == 10, allon["registered"])
    for tag, e in errs_all:
        print("ERROR in the game stand-in [%s]: %s" % (tag, e[:600]))
    print("%d checks, %d failed, %d Lua errors" % (total, bad, len(errs_all)))
    sys.exit(1 if bad or errs_all else 0)


if __name__ == "__main__":
    main()
