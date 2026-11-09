#!/usr/bin/env python3
"""Overlaps with other addons are flagged (XayaUI 0.6.79; PS-56, #469). Xaya, 2026-11-08: "Make sure all addons that have conflicts with
each other (EUI with the chat reskin, elvui with the chat reskin, etc) get appropriately flagged."
The flagging is XayaUI core's (Modules.lua section 5d: ns.RegisterConflict, the login check, the page line) and the settings window's
(XayaUI_Options draws the line first on the part's page). The parts that declared overlaps (Chat Panel, Improved Chat, the Blizzard Reskin
pages, Friend Colors, Character Pane, Nameplates, Enhanced Tooltips, Data Panels) belong to feature addons that are not part of this branch
(they live on another branch); XayaUI core, XayaUI_Options and XayaUI_Rules declare no overlap of their own.
On the real addons in the stand-in game, with a stand-in list of loaded addons (C_AddOns.IsAddOnLoaded answers "loaded" for the names
given, as the game does at PLAYER_LOGIN for an addon that loaded):
  R The real addons of this branch: none of them registers an overlap, so with ElvUI, Plater and idTip loaded there is no login line
    and no page carries a flag.
  S A stand-in feature module (registered from the test the way a feature addon registers, before PLAYER_LOGIN: four settings pages on the
    QoL tab and their overlaps) drives core's mechanism:
    A registry: what was registered is listed (an entry naming no addon is ignored);
    B detection at login: flags land on the right pages and only there (an addon that is not loaded is not named);
    C one login chat line, each loaded addon in name order with the parts that are on (a part whose "on" says no is left out of the line);
    D each flagged page shows its line(s) first ("Overlaps with <addon> (loaded): both change <what>.", one line per loaded addon), in the
      orange of the window's warning notes; a page without an overlap shows none;
    F nothing loaded that overlaps: no login line, no flag on any page.
  G Off costs nothing (V14): with only XayaUI and XayaUI_Options on, nothing is registered and no login line is printed.
  H The whole options window with the overlapping addons loaded is the same as the window without them (no part of this branch is
    flagged).
Fails on the code before 0.6.79 (no ns.RegisterConflict: nothing is flagged).
Run: python3 tests/conflicts_run.py   (Lua 5.1 via lupa)."""
import os, re, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402
import options_split_parity_run as P  # noqa: E402

STANDIN = r'''
local LOADED_EXTRA = {}
for _, n in ipairs(EXTRA or {}) do LOADED_EXTRA[n] = true end
local rawLoaded = C_AddOns.IsAddOnLoaded
C_AddOns.IsAddOnLoaded = function(n) if LOADED_EXTRA[n] then return true, true end return rawLoaded(n) end
IsAddOnLoaded = C_AddOns.IsAddOnLoaded
'''

# a stand-in feature module: its pages on the QoL tab and its overlaps, registered as a feature addon's files do (while loading, before
# PLAYER_LOGIN). Each page has an order-0 note of its own, so the flag's place before it is checked too.
STANDIN_PARTS = r'''
local function page(name)
  return function() return { type = "group", name = name, args = {
    intro = { type = "description", order = 0, width = "full", name = "About " .. name .. "." },
    opt = { type = "toggle", order = 1, name = "Option", get = function() return true end, set = function() end } } } end
end
ns.RegisterSettingsPage("qol", "xtestpart", page("Test Part"))
ns.RegisterSettingsPage("qol", "xtestsecond", page("Second Part"))
ns.RegisterSettingsPage("qol", "xtestoff", page("Off Part"))
ns.RegisterSettingsPage("qol", "xtestclean", page("Clean Part"))
ns.RegisterConflict{ part = "xtestpart", label = "Test Part", addons = { "ElvUI", "Plater", "NotLoadedAddon" }, what = "the test frames" }
ns.RegisterConflict{ part = "xtestsecond", label = "Second Part", addons = { "idTip" }, what = "the IDs shown on tooltips" }
ns.RegisterConflict{ part = "xtestoff", label = "Off Part", addons = { "ElvUI" }, what = "the switched-off thing", on = function() return false end }
ns.RegisterConflict{ part = "xtestbad", label = "Bad", addons = {}, what = "nothing" }
'''

LUA = r'''
return function(W, L, EXTRA, PARTS)
local R = {}
''' + STANDIN + r'''
L.startup()
local ns = rawget(_G, "XayaUI_NS")
if PARTS then
''' + STANDIN_PARTS + r'''
end
local printed = {}
ns.Print = function(...) local t = {} for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end printed[#printed + 1] = table.concat(t, " ") end
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.2, 10)
R.printed = {}
for _, p in ipairs(printed) do if p:find("overlaps with other loaded addons", 1, true) then R.printed[#R.printed + 1] = p end end
local reg = {}
for _, c in ipairs(ns.Conflicts and ns.Conflicts() or {}) do reg[#reg + 1] = c.part .. "=" .. table.concat(c.addons, "+") end
R.registered = table.concat(reg, " ")
-- the pages: the window's options table, and each page's first entry in the order the window draws them (AceConfigDialog compareOptions)
local pages = {}
if ns.LoadOptions and ns.LoadOptions() then
  local root = ns.BuildOptionsTable()
  for _, tab in ipairs({ "chat", "reskin", "qol", "bonus" }) do
    for key, g in pairs(root.args[tab] and root.args[tab].args or {}) do
      if type(g) == "table" and g.type == "group" and type(g.args) == "table" then
        local keys = {}
        for k in pairs(g.args) do keys[#keys + 1] = k end
        local function ord(k) local o = g.args[k].order; if type(o) == "function" then o = o() end return tonumber(o) or 100 end
        local function nm(k) local v = g.args[k].name; if type(v) == "function" then local ok, r = pcall(v, {}); v = ok and r or "" end return type(v) == "string" and v or "" end
        table.sort(keys, function(a, b)
          local oa, ob = ord(a), ord(b)
          if oa == ob then return nm(a):upper() < nm(b):upper() end
          if oa < 0 and ob >= 0 then return false end
          if ob < 0 and oa >= 0 then return true end
          return oa < ob
        end)
        local f = g.args.xuiConflict
        pages[#pages + 1] = { key = key, text = f and f.name or nil, first = keys[1] }
      end
    end
  end
end
table.sort(pages, function(a, b) return a.key < b.key end)
R.pages = pages
return R
end
'''


def session(extra, enabled=None, parts=False):
    folders = H.find_addons()
    on = enabled if enabled is not None else list(folders)
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in on}, "saved": {}}))
    res = L.eval("function(src, W, Ld, x, p) return loadstring(src)()(W, Ld, x, p) end")(LUA, world, loader, H.to_lua(L, extra), parts)
    out = {"printed": [str(res.printed[i]) for i in range(1, len(res.printed) + 1)],
           "registered": str(res.registered),
           "pages": {str(res.pages[i].key): (str(res.pages[i].text) if res.pages[i].text else None, str(res.pages[i].first)) for i in range(1, len(res.pages) + 1)},
           "errors": [str(world.errors[i]) for i in range(1, len(world.errors) + 1)]}
    return out


def main():
    bad = n = 0

    def check(name, ok, detail=""):
        nonlocal bad, n
        n += 1
        if not ok:
            bad += 1
        print(("PASS " if ok else "FAIL ") + name + (("  [" + str(detail)[:500] + "]") if (detail and not ok) else ""))

    folders = H.find_addons()
    LOADED = ["ElvUI", "Plater", "idTip"]
    real = session(LOADED)
    flagged = session(LOADED, parts=True)
    plain = session([], parts=True)
    errs = real["errors"] + flagged["errors"] + plain["errors"]

    # R the real addons of this branch
    check("R no part of XayaUI core, XayaUI_Options or XayaUI_Rules registers an overlap", real["registered"] == "", real["registered"])
    check("R ElvUI, Plater and idTip loaded: no login line (nothing on this branch overlaps them)", real["printed"] == [], real["printed"])
    check("R ...and no page carries a flag", all(t is None for t, _ in real["pages"].values()),
          [k for k, (t, _) in real["pages"].items() if t])

    # A registry (the stand-in feature module)
    reg = flagged["registered"]
    check("A each registered part is listed with its addons, in the order registered",
          reg == "xtestpart=ElvUI+Plater+NotLoadedAddon xtestsecond=idTip xtestoff=ElvUI", reg)
    check("A an entry naming no addon is ignored", "xtestbad=" not in reg, reg)

    # B / D detection and the pages
    pages = flagged["pages"]
    want = {"xtestpart": ["ElvUI", "Plater"], "xtestsecond": ["idTip"], "xtestoff": ["ElvUI"], "xtestclean": []}
    check("B the stand-in pages are in the window (QoL tab)", all(k in pages for k in want), sorted(pages))
    for key in sorted(want):
        exp = want[key]
        text, first = pages.get(key, (None, None))
        got = [a for a in ("ElvUI", "Plater", "idTip", "NotLoadedAddon") if text and ("Overlaps with %s (loaded)" % a) in text]
        check("B/D page %s: flagged for %s" % (key, ", ".join(exp) or "nothing"), got == exp, "%s | %s" % (got, text))
        if exp:
            check("D page %s: its flag is the first line on the page (before the page's own order-0 note), in the warning orange" % key,
                  first == "xuiConflict" and text.startswith(" |cffff8a3d") and text.endswith("|r"), "%s | %s" % (first, text))
    others = [k for k, (t, _) in pages.items() if t and k not in want]
    check("B no other page carries a flag", others == [], others)
    check("D wording: one line per loaded addon, each saying what both change",
          (pages.get("xtestpart") or (None,))[0] == " |cffff8a3dOverlaps with ElvUI (loaded): both change the test frames.\nOverlaps with Plater (loaded): both change the test frames.|r",
          pages.get("xtestpart"))
    check("D wording: the part's own sentence", (pages.get("xtestsecond") or (None,))[0] == " |cffff8a3dOverlaps with idTip (loaded): both change the IDs shown on tooltips.|r",
          pages.get("xtestsecond"))

    # C the login line
    pr = flagged["printed"]
    check("C exactly one login line about overlaps", len(pr) == 1, pr)
    line = pr[0] if pr else ""
    want_line = "overlaps with other loaded addons: ElvUI (Test Part); idTip (Second Part); Plater (Test Part). Each part's settings page says what both change."
    check("C it lists each loaded addon (name order, any case) with the parts that are on", line == want_line, line)
    check("C a part that is switched off is not in the line (its page is still flagged)", "Off Part" not in line and (pages.get("xtestoff") or (None,))[0] is not None, line)

    # F nothing loaded
    check("F nothing loaded that overlaps: no login line", plain["printed"] == [], plain["printed"])
    check("F nothing loaded that overlaps: no page carries a flag", all(t is None for t, _ in plain["pages"].values()),
          [k for k, (t, _) in plain["pages"].items() if t])

    # G off costs nothing
    core_only = session(["ElvUI", "Plater"], [f for f in folders if f in ("XayaUI", "XayaUI_Options")])
    check("G XayaUI Rules off too (only XayaUI and XayaUI_Options): nothing registered, no login line",
          core_only["registered"] == "" and core_only["printed"] == [], "%s | %s" % (core_only["registered"], core_only["printed"]))
    errs += core_only["errors"]

    # H the whole window: nothing added, nothing removed
    src = P.LUA.replace("L.startup()\n", "L.startup()\nlocal EXTRA = { 'ElvUI', 'Plater', 'idTip' }\n" + STANDIN, 1)
    old = P.LUA
    P.LUA = src
    try:
        with_dump, _, e1 = P.run_variant(None)
    finally:
        P.LUA = old
    base_dump, _, e2 = P.run_variant(None)
    errs += e1 + e2
    if with_dump and base_dump:
        uid = re.compile(r"\bf\d{8,}\b")   # group ids made from the clock and a counter (the two runs make them in a different order)
        # the Rules tab ("cooldowns") lists the sample rules by group ids made from a counter, which differ between two sessions; no
        # part registers an overlap there, so it is left out of this comparison (the parity golden checks it)
        # Settings > Debugging counts the lines of the console and the detailed record (a login line would be one more of them)
        keep = lambda d: set(l for l in uid.sub("f<id>", d).split("\n") if not l.startswith("cooldowns") and not l.startswith(("set.debug.", "settings.debug.")))
        a, b = keep(base_dump), keep(with_dump)
        added, removed = sorted(b - a), sorted(a - b)
        check("H the window with ElvUI, Plater and idTip loaded = the window without them (no flag line, nothing else changed)",
              not added and not removed, "added %s | removed %s" % ([l[:120] for l in added][:3], [l[:120] for l in removed][:3]))
    else:
        check("H the options window builds", False, "no dump")

    check("no Lua errors in the stand-in game", not errs, errs[:2])
    print("%d checks, %d failed" % (n, bad))
    if bad == 0:
        print("ALL CHECKS PASS")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
