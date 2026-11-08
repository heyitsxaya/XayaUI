#!/usr/bin/env python3
"""Platform split P3 "Options split" (Options 0.6.83; docs/plans/PLATFORM-SPLIT-2026-11-07.md sections 7, 10 and risk R8): the rule
editor and the rules tree moved out of XayaUI_Options/Options.lua into XayaUI_Options/RuleEditor/. A pure code move: the player must
get exactly the same settings window. Loads the real addons in the stand-in game, sets up one fixed state (rules with cues and an
outcome, nested groups, a disabled rule, a buff bar, a Recycle Bin item, a fixed clock) and builds the whole options table
(ns.BuildOptionsTable, every page of every module that is on). Every node is written out: its key path, type, order, width, name,
desc, the results of hidden / disabled / get / values / sorting / confirm / image called with an AceConfig-style info table, and every
other plain field; functions that change something (set, func, validate) are only noted as present. Version strings, table addresses,
dates and error positions are normalised.
  A The dump of the new code equals the dump of the old code (Options 0.6.82, main bd03eb5), compared per top tab (sha256 and node
    count), with every module on.
  B The same with each feature module switched off in turn (Chat, QoL, Bonus Features, Blizzard Reskin, Dev Assist, Nameplates, Media).
  C Off costs nothing (V14): a feature addon that is switched off has registered no settings page (ns.BuildSettingsPages(module)
    is empty) and its top tab is absent; the rule editor's own files register no page of their own.
  D (P4, platform split) XayaUI Rules switched off: the window is the all-on window minus exactly the rules' own parts (the Rules tab,
    the rule list rows and Rule Creation tab of Settings, the backups and the "Rules and groups" part of Profiles); every other line is
    the same. Fails on the code before P4 (there is no XayaUI_Rules folder to switch off: the Rules tab and the backups stay).
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
pages the fixed state draws, 0 other lines (debug-log 2026-11-08 aspect-ratio). `--dump DIR` writes the full dumps, one file per variant, to compare by hand (diff) when a check fails.
Run: python3 tests/options_split_parity_run.py"""
import hashlib, json, os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.environ.get("XUI_HARNESS") or os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

GOLDEN_FILE = os.path.join(HERE, "options_split_parity_golden.json")
MODULES = ["XayaUI_Chat", "XayaUI_QoL", "XayaUI_Bonus", "XayaUI_Reskin", "XayaUI_DevAssist", "XayaUI_Nameplates", "XayaUI_Media"]
MODULE_KEY = {"XayaUI_Chat": "chat", "XayaUI_QoL": "qol", "XayaUI_Bonus": "bonus", "XayaUI_Reskin": "reskin"}

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


def page_keys(addon):
    """the page keys an addon's own files register (ns.RegisterSettingsPage(module, key, ...)), read from its files"""
    out = set()
    d = H.find_addons()[addon]
    for base, _, files in os.walk(d):
        for f in files:
            if f.endswith(".lua"):
                src = open(os.path.join(base, f), encoding="utf-8", errors="replace").read()
                out |= set(re.findall(r'RegisterSettingsPage\(\s*"[a-z]+"\s*,\s*"(\w+)"', src))
    return out


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

    for off in variants:
        tag = "all-on" if off is None else ("off-" + off)
        got, want = results.get(tag), golden.get(tag)
        check("[%s] the options table builds" % tag, got is not None)
        if got is None or want is None:
            check("[%s] golden present" % tag, want is not None)
            continue
        keys = sorted(set(got["tabs"]) | set(want["tabs"]))
        for t in keys:
            check("[%s] %s: same nodes, names, descs, types, widths, hidden / disabled / get results as before the move" % (tag, t),
                  got["tabs"].get(t) == want["tabs"].get(t), "got %s want %s" % (got["tabs"].get(t), want["tabs"].get(t)))
        check("[%s] the same settings pages are registered per module" % tag, got["registered"] == want["registered"],
              "got %s want %s" % (got["registered"], want["registered"]))
        # C: off costs nothing (V14): none of the pages the switched-off addon's files register exists
        if off:
            have = set()
            for x in got["registered"].split():
                m, ks = x.split("=", 1)
                have |= set(k for k in ks.split(",") if k)
            own = page_keys(off)
            check("[%s] V14: the switched-off addon registered none of its %d settings pages" % (tag, len(own)), not (own & have),
                  "still registered: %s" % sorted(own & have))
            if off in ("XayaUI_Chat", "XayaUI_Bonus"):
                check("[%s] V14: its top tab is absent" % tag, MODULE_KEY[off] not in got["tabs"])
    # D (P4) XayaUI Rules switched off: no golden from the old code (the module did not exist). The window is the all-on window minus
    # exactly what belongs to the rules (the Rules tab, the rule list rows and the Rule Creation tab of Settings, the backups and the
    # "Rules and groups" tick boxes of Profiles); everything else is line for line the same. Lines that differ for a known reason:
    # the Recycle Bin (no rule could be deleted into it), the order numbers of the other profile parts (one part fewer before them),
    # and Dev Assist's detailed-record rows (they list rules and count the record's lines).
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
        KNOWN = re.compile(r"^(profiles\.bin(\..*)?|profiles\.(export\.inc|import\.imp)_\w+|(set|settings)\.debug\.devPages\.devrecord\.(recFocus|recordInfo))$")
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
    for tag, e in errs_all:
        print("ERROR in the game stand-in [%s]: %s" % (tag, e[:600]))
    print("%d checks, %d failed, %d Lua errors" % (total, bad, len(errs_all)))
    sys.exit(1 if bad or errs_all else 0)


if __name__ == "__main__":
    main()
