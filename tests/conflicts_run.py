#!/usr/bin/env python3
"""Overlaps with other addons are flagged (XayaUI 0.6.79; PS-56, #469). Xaya, 2026-11-08: "Make sure all addons that have conflicts with
each other (EUI with the chat reskin, elvui with the chat reskin, etc) get appropriately flagged."
On the real addons in the stand-in game, with a stand-in list of loaded addons (C_AddOns.IsAddOnLoaded answers "loaded" for the names
given, as the game does at PLAYER_LOGIN for an addon that loaded):
  A Registry: each part registers from its own module (Modules.lua ns.RegisterConflict): the Chat Panel and Improved Chat (XayaUI Chat),
    the Blizzard Reskin pages and Friend Colors (XayaUI Blizzard Reskin), Character Pane (XayaUI QoL), Nameplates, Enhanced Tooltips and
    Data Panels (XayaUI Bonus Features); every entry names an addon folder.
  B Detection at login with ElvUI, Plater and idTip loaded: the flags land on the right parts and only there.
  C One login chat line, listing each loaded addon with the parts that are on (parts switched off are left out of the line).
  D Each flagged part's settings page shows its line first ("Overlaps with <addon> (loaded): both change <what>."), in the orange of
    the window's warning notes; a page without an overlap shows none.
  E No behaviour change: what is drawn (chat art, Improved Chat's parts, nameplate colour listener, reskins, friend colours, enhanced
    tooltips) is the same with and without the overlapping addons loaded.
  F Nothing loaded that overlaps: no line at login, no flag on any page (the options parity golden covers the whole window).
  G Off costs nothing (V14): with XayaUI Chat switched off nothing of it is registered; with every feature module off nothing is
    registered and no login line is printed.
  H The whole options window with the overlapping addons loaded differs from the window without them only by the added flag lines.
Fails on the code before 0.6.79 (no ns.RegisterConflict: nothing is flagged).
Run: python3 tests/conflicts_run.py   (Lua 5.1 via lupa)."""
import os, sys
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

LUA = r'''
return function(W, L, EXTRA)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
''' + STANDIN + r'''
L.startup()
local ns = rawget(_G, "XayaUI_NS")
local printed = {}
local rawPrint = ns.Print
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
  for _, tab in ipairs({ "reskin", "qol", "bonus" }) do
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
-- what is drawn
local sv = ns.Service("chatDebug"); local C = sv and sv.C
local NP = ns.Service("nameplates")
local bs = ns.Service("blizzardSkins"); local live = bs and bs.Live() or {}
local imp = 0
if C then for name, on in pairs(C.on or {}) do if on and C.PART_GROUP and C.PART_GROUP[name] == "improved" then imp = imp + 1 end end end
local look = {
  "chat art=" .. tostring(C and C.skin), "chat on=" .. tostring(C and C.On()), "improved parts=" .. imp,
  "nameplate listener=" .. tostring(NP and NP.TargetColor and NP.TargetColor.Listening()),
  "friend colours=" .. tostring(ns.FriendColors_Active and ns.FriendColors_Active()),
  "character reskin=" .. tostring(ns.CharReskin_Active and ns.CharReskin_Active()),
}
for _, k in ipairs({ "windows", "minimap", "tooltips", "tracker", "toasts", "menus", "bubbles", "statusbars", "mmbuttons", "buttons" }) do look[#look + 1] = k .. "=" .. tostring(live[k]) end
local tt = ns.TT and ns.TT.DB and ns.TT.DB()
look[#look + 1] = "tooltips enhanced=" .. tostring(tt and tt.enabled)
R.look = table.concat(look, " ")
return R
end
'''


def session(extra, enabled=None):
    folders = H.find_addons()
    on = enabled if enabled is not None else list(folders)
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in on}, "saved": {}}))
    src = LUA.replace("EXTRA or {}", "EXTRA or {}")
    res = L.eval("function(src, W, Ld, x) return loadstring(src)()(W, Ld, x) end")(src, world, loader, H.to_lua(L, extra))
    out = {"checks": [(res[i][1], res[i][2]) for i in range(1, len(res) + 1)],
           "printed": [str(res.printed[i]) for i in range(1, len(res.printed) + 1)],
           "registered": str(res.registered), "look": str(res.look),
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
    flagged = session(["ElvUI", "Plater", "idTip"])
    plain = session([])
    errs = flagged["errors"] + plain["errors"]

    # A registry
    reg = flagged["registered"]
    for part in ("chatpanel=", "improvedchat=", "blizzwindows=", "minimapshape=", "rsktooltips=", "objtracker=", "rsktoasts=", "rskmenus=",
                 "rskbubbles=", "rskstatusbars=", "rskmmbuttons=", "friendcolors=", "charreskin=", "nameplates=", "tooltips=", "datapanels="):
        check("A %s each of its overlapping addons is registered by the part's own module" % part[:-1], part in reg, reg)
    check("A the Chat Panel names ElvUI and EllesmereUIChat (her examples)", "chatpanel=ElvUI+EllesmereUIChat" in reg, reg)
    check("A no flag is registered for parts with no sourced overlap (Buttons, Esc Menu, Shopping List)",
          not any(p in reg for p in ("rskbuttons=", "gamemenu=", "shoppinglist=")), reg)

    # B detection
    pages = flagged["pages"]
    want = {"chatpanel": ["ElvUI"], "improvedchat": ["ElvUI"], "blizzwindows": ["ElvUI"], "minimapshape": ["ElvUI"], "rsktooltips": ["ElvUI"],
            "objtracker": ["ElvUI"], "rskmenus": ["ElvUI"], "rskstatusbars": ["ElvUI"], "friendcolors": ["ElvUI"], "charreskin": ["ElvUI"],
            "nameplates": ["ElvUI", "Plater"], "tooltips": ["ElvUI", "idTip"], "datapanels": ["ElvUI"]}
    for key, (text, first) in sorted(pages.items()):
        exp = want.get(key, [])
        got = [a for a in ("ElvUI", "Plater", "idTip", "EllesmereUIChat") if text and ("Overlaps with %s (loaded)" % a) in text]
        check("B/D page %s: flagged for %s" % (key, ", ".join(exp) or "nothing"), got == exp, "%s | %s" % (got, text))
        if exp:
            check("D page %s: its flag is the first line on the page, in the warning orange" % key,
                  first == "xuiConflict" and text.startswith(" |cffff8a3d") and text.endswith("|r"), "%s | %s" % (first, text))
    check("D wording (Chat Panel): \"Overlaps with ElvUI (loaded): both change the chat window.\"",
          (pages.get("chatpanel") or (None,))[0] == " |cffff8a3dOverlaps with ElvUI (loaded): both change the chat window.|r", pages.get("chatpanel"))
    check("D wording (Nameplates): one line per loaded addon",
          (pages.get("nameplates") or (None,))[0] == " |cffff8a3dOverlaps with ElvUI (loaded): both change nameplates.\nOverlaps with Plater (loaded): both change nameplates.|r", pages.get("nameplates"))
    check("D wording (Enhanced Tooltips): idTip's own sentence",
          "Overlaps with idTip (loaded): both change the IDs shown on tooltips." in str((pages.get("tooltips") or (None,))[0]), pages.get("tooltips"))

    # C the login line
    pr = flagged["printed"]
    check("C exactly one login line about overlaps", len(pr) == 1, pr)
    line = pr[0] if pr else ""
    check("C it lists each loaded addon (name order) with the parts that are on (defaults: Chat Panel, Improved Chat, Friend Colors, Nameplates, Enhanced Tooltips)",
          line == "overlaps with other loaded addons: ElvUI (Chat Panel, Enhanced Tooltips, Friend Colors, Improved Chat, Nameplates); "
                  "idTip (Enhanced Tooltips); Plater (Nameplates). Each part's settings page says what both change.", line)
    check("C parts that are switched off are not in the line (Blizzard Windows, Minimap, Data Panels ... are off by default)",
          not any(p in line for p in ("Blizzard Windows", "Minimap", "Data Panels", "Objective Tracker", "Character Pane")), line)

    # E no behaviour change
    check("E what is drawn is the same with and without the overlapping addons loaded", flagged["look"] == plain["look"],
          "%s || %s" % (flagged["look"], plain["look"]))

    # F nothing loaded
    check("F nothing loaded that overlaps: no login line", plain["printed"] == [], plain["printed"])
    check("F nothing loaded that overlaps: no page carries a flag", all(t is None for t, _ in plain["pages"].values()),
          [k for k, (t, _) in plain["pages"].items() if t])

    # G off costs nothing
    no_chat = session(["ElvUI"], [f for f in folders if f != "XayaUI_Chat"])
    check("G XayaUI Chat off: nothing of it is registered", "chatpanel=" not in no_chat["registered"] and "improvedchat=" not in no_chat["registered"],
          no_chat["registered"])
    core_only = session(["ElvUI", "Plater"], [f for f in folders if f in ("XayaUI", "XayaUI_Options", "XayaUI_Media")])
    check("G every feature module off: nothing registered, no login line", core_only["registered"] == "" and core_only["printed"] == [],
          "%s | %s" % (core_only["registered"], core_only["printed"]))
    errs += no_chat["errors"] + core_only["errors"]

    # H the whole window: only the flag lines are added
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
        import re
        uid = re.compile(r"\bf\d{8,}\b")   # group ids made from the clock and a counter (the two runs make them in a different order)
        # the Rules tab ("cooldowns") lists the sample rules by group ids made from a counter, which differ between two sessions; no
        # part registers an overlap there, so it is left out of this comparison (the parity golden checks it)
        # Settings > Debugging counts the lines of the console and the detailed record: the login line is one more of them (C)
        keep = lambda d: set(l for l in uid.sub("f<id>", d).split("\n") if not l.startswith("cooldowns") and not l.startswith(("set.debug.", "settings.debug.")))
        a, b = keep(base_dump), keep(with_dump)
        added, removed = sorted(b - a), sorted(a - b)
        only_flags = all(l.split(" :: ")[0].endswith(".xuiConflict") for l in added) and not removed
        check("H the window with overlaps loaded = the window without them + %d flag line(s), nothing else" % len(added), only_flags and len(added) == 13,
              "added %s | removed %s" % ([l[:120] for l in added if not l.split(" :: ")[0].endswith(".xuiConflict")][:3] or len(added), removed[:3]))
    else:
        check("H the options window builds", False, "no dump")

    check("no Lua errors in the stand-in game", not errs, errs[:2])
    print("%d checks, %d failed" % (n, bad))
    if bad == 0:
        print("ALL CHECKS PASS")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
