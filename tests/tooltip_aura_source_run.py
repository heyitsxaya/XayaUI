#!/usr/bin/env python3
"""Aura lines on spell tooltips say where each aura ID came from, and leave out an aura icon ID that repeats the spell's own icon
(Bonus 0.6.13; since 0.6.15 the source text only while Advanced Debugging is on: Xaya 2026-11-06, "only offer this if
debugging mode is enabled"). Why (Xaya, 2026-11-04, Fiery Brand tooltip): "why are there two aura icon ids and damage ratios?". Proposal answered
on 2026-11-06, "Yes, build it": 1. hide "Aura icon ID" when it is the same as the spell's icon; 2. say where each aura ID came from,
so two IDs do not look like an error. The proposal named spells only, so item tooltips keep every aura icon line.
Runs XayaUI_Bonus/Tooltips.lua (with core Modules.lua, AuraSources.lua and TooltipsUI.lua for /xuitt) in Lua 5.1 with a stand-in tooltip and controlled game
answers; checks the exact lines added to the tooltip. Deliberate breaks (BREAKS) must each make a check fail. Last line: FAILS: <n>.
Run: python3 tests/tooltip_aura_source_run.py"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime   # Lua 5.1, like the game (tests/lua51.py)

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
TT_PATH = os.path.join(ROOT, "XayaUI_Bonus", "Tooltips.lua")

WORLD = r'''
secret = {}
function issecretvalue(v) return secret[v] == true end
function GetTime() return 100 end
lines = {}
GameTooltip = { AddDoubleLine = function(self, a, b) lines[#lines + 1] = a .. " " .. b end, IsShown = function() return true end,
  GetUnit = function() return "mouseover", "mouseover" end, RefreshData = function() end }
posts = {}
Enum = { TooltipDataType = { Item = 0, Spell = 1, Unit = 2, Currency = 5, BattlePet = 6, UnitAura = 7, Mount = 10, Achievement = 12, Toy = 19, Quest = 23 },
  TooltipDataLineType = { NestedBlock = 19 }, CooldownViewerCategory = { Essential = 0, Utility = 1, TrackedBuff = 2, TrackedBar = 3 } }
TooltipDataProcessor = { AddTooltipPostCall = function(t, f) posts[t] = f end }
function CreateFrame() return { RegisterEvent = function() end, UnregisterEvent = function() end, SetScript = function() end } end
SlashCmdList = {}
function strsplit(sep, s) local t = {} for p in (s .. sep):gmatch("(.-)" .. sep) do t[#t + 1] = p end return unpack(t) end
inCombat = false
function InCombatLockdown() return inCombat end
ICONS = {}
NAMES = {}
C_Spell = { GetSpellTexture = function(id) return ICONS[id] or (1000 + id) end, GetSpellName = function(id) return NAMES[id] end,
  GetSpellDescription = function() return "Lasts 12 sec." end }
ITEM_ICONS = {}
C_Item = { GetItemIconByID = function(id) return ITEM_ICONS[id] or (2000 + id) end }
cdmSets = { [0] = {}, [1] = {}, [2] = {}, [3] = {} }
cdmInfo = {}
C_CooldownViewer = {
  GetCooldownViewerCategorySet = function(cat) return cdmSets[cat] or {} end,
  GetCooldownViewerCooldownInfo = function(id) return cdmInfo[id] end,
}
function reset() lines = {} end
XayaUI_NS = {}; CueRulesDB = {}
'''


def make(src):
    L = LuaRuntime(unpack_returned_tuples=True)
    L.execute(WORLD)
    # (Bonus 0.6.18 / Dev Assist 0.7.5, REQUEST-LOG #81: /xuitt is XayaUI Dev Assist's, loaded last as the game loads it)
    files = [("XayaUI/Modules.lua", None), ("XayaUI_Bonus/Tooltips.lua", src), ("XayaUI/AuraSources.lua", None), ("XayaUI_Bonus/TooltipsUI.lua", None),
             ("XayaUI_DevAssist/CoreDebug.lua", None)]
    for f, text in files:
        text = text if text is not None else open(os.path.join(ROOT, f), encoding="utf-8").read()
        L.eval("function(src, n) return assert(loadstring(src, n)) end")(text, f)("XayaUI", L.eval("XayaUI_NS"))
    # AuraSources is core; keep its embedded-aura reader and give each check its own record (as tests/tooltips_run.py does)
    L.execute("REAL_AS = XayaUI_NS.AuraSources; RECORDED = {}; XayaUI_NS.AuraSources = { EmbeddedAuras = REAL_AS.EmbeddedAuras, "
              "NestedType = REAL_AS.NestedType, AurasOf = function(k, id) return RECORDED[k .. id] or {} end }")
    # XayaUI Dev Assist loaded (core Modules.lua ns.DevAssistOn; Bonus 0.6.18, Xaya 2026-11-06 "Tooltip, Dev Assist on"): the sources show
    # only while it is. Advanced Debugging (on by default) no longer decides it: it is set off here and the sources still show.
    L.execute("DEBUG_ON = true; XayaUI_NS.DevAssistOn = function() return DEBUG_ON end; XayaUI_NS.AdvancedDebugOn = function() return false end")
    L.execute("XayaUI_NS.TT.DB(); XayaUI_NS.TT.Init(); XayaUI_NS.TT.DB().ids.icon = true")
    return L


def VIA(*s):
    return "  |cff999999via " + ", ".join(s) + "|r"


def nested(aid):
    return "{type=19, tooltipType=1, tooltipID=%d}" % aid


def checks(L):
    R = []

    def check(name, ok, got=None):
        R.append((name + ("" if ok else "  [got %r]" % (got,)), bool(ok)))

    def run(setup, call):
        L.execute("reset(); XayaUI_NS.AuraModel = nil; C_UnitAuras = nil; RECORDED = {}; cdmSets = { [0] = {}, [1] = {}, [2] = {}, [3] = {} }; cdmInfo = {}")
        L.execute(setup)
        L.execute("if XayaUI_NS.TT.ResetCooldownLinks then XayaUI_NS.TT.ResetCooldownLinks() end")
        L.execute(call)
        return list(L.eval("lines").values())

    # A. the Fiery Brand shape: one aura from the tooltip's own effect block, one linked by the Cooldown Manager, every icon the spell's
    fb = run("NAMES = { [204021] = 'Fiery Brand', [207771] = 'Fiery Brand', [207744] = 'Fiery Brand' }; "
             "ICONS = { [204021] = 1344647, [207771] = 1344647, [207744] = 1344647 }; "
             "cdmSets[0] = { 11 }; cdmInfo[11] = { spellID = 204021, linkedSpellIDs = { 207744 } }",
             "posts[1](GameTooltip, { id = 204021, lines = { %s } })" % nested(207771))
    want = ["Spell ID: 204021", "Icon ID: 1344647", "Aura ID: 207771  (Fiery Brand)" + VIA("this tooltip"),
            "Aura ID: 207744  (Fiery Brand)" + VIA("Cooldown Manager")]
    check("Fiery Brand shape: each aura says where it came from; no aura icon line repeats the spell's icon", fb == want, fb)

    # B. an aura whose icon is not the spell's keeps its icon line
    b = run("NAMES = { [500] = 'Shield', [501] = 'Shield Buff' }; ICONS = { [500] = 1500, [501] = 1501 }",
            "posts[1](GameTooltip, { id = 500, lines = { %s } })" % nested(501))
    check("spell: an aura icon different from the spell's is still shown", b == ["Spell ID: 500", "Icon ID: 1500",
          "Aura ID: 501  (Shield Buff)" + VIA("this tooltip"), "Aura icon ID: 1501"], b)

    # C. items: the proposal named spells, so an aura icon equal to the item's icon is still shown
    c = run("NAMES = { [601] = 'Well Fed' }; ICONS = { [601] = 777 }; ITEM_ICONS = { [60] = 777 }",
            "posts[0](GameTooltip, { id = 60, lines = { %s } })" % nested(601))
    check("item: an aura icon equal to the item's icon is still shown (spells only)", c == ["Item ID: 60", "Icon ID: 777",
          "Aura ID: 601  (Well Fed)" + VIA("this tooltip"), "Aura icon ID: 777"], c)

    # D. one aura found two ways: both named, in order
    d = run("NAMES = { [700] = 'Spikes', [701] = 'Spikes' }; cdmSets[0] = { 21 }; cdmInfo[21] = { spellID = 700, linkedSpellIDs = { 701 } }; "
            "XayaUI_NS.AuraModel = { AurasForCast = function(id) if id == 700 then return { { id = 701, name = 'Spikes' } } end return {} end }",
            "XayaUI_NS.TT.DB().ids.icon = false; posts[1](GameTooltip, { id = 700 }); XayaUI_NS.TT.DB().ids.icon = true")
    check("one aura found two ways names both", d == ["Spell ID: 700", "Aura ID: 701  (Spikes)" + VIA("Cooldown Manager", "your casts")], d)

    # E. "recorded earlier" only when nothing else in this hover found it (the record is fed by the tooltip itself)
    e = run("NAMES = { [800] = 'Stew', [801] = 'Fed' }; RECORDED['item800'] = { { id = 801, name = 'Fed' } }",
            "XayaUI_NS.TT.DB().ids.icon = false; posts[0](GameTooltip, { id = 800, lines = { %s } }); XayaUI_NS.TT.DB().ids.icon = true" % nested(801))
    check("recorded earlier is left out beside this tooltip", e == ["Item ID: 800", "Aura ID: 801  (Fed)" + VIA("this tooltip")], e)
    e2 = run("NAMES = { [800] = 'Stew', [801] = 'Fed' }; RECORDED['item800'] = { { id = 801, name = 'Fed' } }",
             "XayaUI_NS.TT.DB().ids.icon = false; posts[0](GameTooltip, { id = 800 }); XayaUI_NS.TT.DB().ids.icon = true")
    check("recorded earlier is shown when it is the only source", e2 == ["Item ID: 800", "Aura ID: 801  (Fed)" + VIA("recorded earlier")], e2)

    # F. the buff-on-you read is named
    f = run("NAMES = { [900] = 'Ward', [901] = 'Ward' }; C_UnitAuras = { GetAuraDataBySpellName = function(u, n, flt) "
            "if n == 'Ward' then return { spellId = 901 } end end }",
            "XayaUI_NS.TT.DB().ids.icon = false; posts[1](GameTooltip, { id = 900 }); XayaUI_NS.TT.DB().ids.icon = true")
    check("an aura read from your buffs says so", f == ["Spell ID: 900", "Aura ID: 901  (Ward)" + VIA("buff on you")], f)

    # G. the /xuitt aura report shows the same sources
    L.execute("printed = {}; print = function(...) local t = {} for i = 1, select('#', ...) do t[#t + 1] = tostring(select(i, ...)) end "
              "printed[#printed + 1] = table.concat(t, ' ') end; C_AddOns = { GetAddOnMetadata = function() return '0.6.13' end }")
    run("NAMES = { [700] = 'Spikes', [701] = 'Spikes' }; cdmSets[0] = { 21 }; cdmInfo[21] = { spellID = 700, linkedSpellIDs = { 701 } }",
        "SlashCmdList.XUITT('aura 700')")
    rep = " | ".join(L.eval("printed").values())
    check("/xuitt aura names the source too", "tooltip shows: 701 Spikes" + VIA("Cooldown Manager") in rep, rep[-200:])

    # H. XayaUI Dev Assist not loaded (Xaya 2026-11-06: "Tooltip, Dev Assist on"; before Bonus 0.6.18 it followed Advanced Debugging):
    # no source text, Advanced Debugging on; the repeated icon line stays left out (that part is not a debugging aid)
    L.execute("DEBUG_ON = false; XayaUI_NS.AdvancedDebugOn = function() return true end")
    off = run("NAMES = { [204021] = 'Fiery Brand', [207771] = 'Fiery Brand', [207744] = 'Fiery Brand' }; "
              "ICONS = { [204021] = 1344647, [207771] = 1344647, [207744] = 1344647 }; "
              "cdmSets[0] = { 11 }; cdmInfo[11] = { spellID = 204021, linkedSpellIDs = { 207744 } }",
              "posts[1](GameTooltip, { id = 204021, lines = { %s } })" % nested(207771))
    check("Dev Assist not loaded (Advanced Debugging on): no source text, and still no repeated aura icon line", off == ["Spell ID: 204021", "Icon ID: 1344647",
          "Aura ID: 207771  (Fiery Brand)", "Aura ID: 207744  (Fiery Brand)"], off)
    L.execute("printed = {}")
    run("NAMES = { [700] = 'Spikes', [701] = 'Spikes' }; cdmSets[0] = { 21 }; cdmInfo[21] = { spellID = 700, linkedSpellIDs = { 701 } }",
        "SlashCmdList.XUITT('aura 700')")
    rep2 = " | ".join(L.eval("printed").values())
    check("Dev Assist reported off: /xuitt aura's tooltip shows line matches the tooltip (no source)", "tooltip shows: 701 Spikes" in rep2 and "via" not in rep2, rep2[-160:])
    L.execute("XayaUI_NS.DevAssistOn = nil")
    nocore = run("NAMES = { [500] = 'Shield', [501] = 'Shield Buff' }", "XayaUI_NS.TT.DB().ids.icon = false; posts[1](GameTooltip, { id = 500, lines = { %s } }); XayaUI_NS.TT.DB().ids.icon = true" % nested(501))
    check("without core's Dev Assist reader: no source text, no error", nocore == ["Spell ID: 500", "Aura ID: 501  (Shield Buff)"], nocore)
    L.execute("DEBUG_ON = true; XayaUI_NS.DevAssistOn = function() return DEBUG_ON end")
    return R


BREAKS = [
    ("aura icon shown even when it repeats the spell's", "if icon and icon ~= ownIcon then", "if icon then"),
    ("items lose an aura icon equal to their own", '(db.ids.icon and kind.key == "spell") and IconID("spell", id)',
     '(db.ids.icon) and IconID(kind.key, id)'),
    ("only the first source kept", "if src and not e.src[src] then e.src[src] = true end", "if src and next(e.src) == nil then e.src[src] = true end"),
    ("recorded earlier kept beside other sources", 'if other then e.src["recorded earlier"] = nil end', ""),
    ("sources shown without Dev Assist", "if not TT.SourcesOn() then return \"\" end", ""),
    ("sources follow Advanced Debugging again (before Bonus 0.6.18)", "return ns.DevAssistOn and ns.DevAssistOn()", "return ns.AdvancedDebugOn and ns.AdvancedDebugOn()"),
    ("no source text", 'return "  |cff999999via " .. table.concat(t, ", ") .. "|r"', 'return ""'),
]

if __name__ == "__main__":
    src = open(TT_PATH, encoding="utf-8").read()
    results = checks(make(src))
    bad = 0
    for name, ok in results:
        print(("PASS " if ok else "FAIL ") + name)
        bad += 0 if ok else 1
    for name, old, new in BREAKS:
        if src.count(old) != 1:
            print("BREAK %r: text not found exactly once" % name); bad += 1; continue
        try:
            r2 = checks(make(src.replace(old, new)))
            caught = not all(ok for _, ok in r2)
        except Exception as ex:   # a break that stops the file loading also counts as caught
            caught = True
        if not caught:
            print("BREAK %r: no check failed" % name); bad += 1
    print("%d checks, %d deliberate breaks  FAILS: %d" % (len(results), len(BREAKS), bad))
    sys.exit(1 if bad else 0)
