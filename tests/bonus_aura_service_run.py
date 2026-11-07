#!/usr/bin/env python3
"""XayaUI Bonus reaches the rule-tracking side's aura readers only through the Platform's service registry (Bonus 0.6.30, core 0.6.74;
docs/plans/PLATFORM-SPLIT-2026-11-07.md section 6.4: "Core offers them through the existing service registry (ns.Provide /
ns.Service); Bonus asks for them and shows nothing extra when Core is off").
Runs XayaUI_Bonus/Tooltips.lua with core Modules.lua (the service registry) in Lua 5.1 with the stand-in tooltip of
tests/tooltip_aura_source_run.py, and checks the exact lines added to a spell tooltip:
  A service absent (rule tracking off: AuraSources.lua / AuraModel.lua not loaded): the tooltip shows its ID lines and no aura line,
    the talent hash still works, nothing errors;
  B services present, with ns.AuraSources / ns.AuraModel NOT set: the aura lines come from the services (this tooltip's effect block,
    what was recorded earlier, your casts), and the talent list comes from AuraModel;
  C the real AuraSources.lua offers itself as the service: its embedded-aura reader fills the tooltip.
Negative control: A and B fail on main 774980c (Tooltips.lua read ns.AuraSources / ns.AuraModel directly: an index of nil there).
Run: python3 tests/bonus_aura_service_run.py"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime   # Lua 5.1, like the game (tests/lua51.py)
from tooltip_aura_source_run import WORLD  # the same stand-in tooltip and game answers

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")


def make(extra):
    L = LuaRuntime(unpack_returned_tuples=True)
    L.execute(WORLD)
    for f in ["XayaUI/Modules.lua", "XayaUI_Bonus/Tooltips.lua"] + extra:
        text = open(os.path.join(ROOT, f), encoding="utf-8").read()
        L.eval("function(src, n) return assert(loadstring(src, n)) end")(text, f)("XayaUI", L.eval("XayaUI_NS"))
    L.execute("XayaUI_NS.TT.DB(); XayaUI_NS.TT.Init(); XayaUI_NS.TT.DB().ids.icon = false")
    return L


def lines(L, call):
    L.execute("reset(); ERR = nil")
    L.execute("local ok, e = pcall(function() %s end); if not ok then ERR = tostring(e) end" % call)
    return list(L.eval("lines").values()), L.eval("ERR")


def main():
    R = []

    def check(name, ok, got=None):
        R.append((name + ("" if ok else "  [got %r]" % (got,)), bool(ok)))

    nested = "{type=19, tooltipType=1, tooltipID=501}"
    # A. absent
    L = make([])
    L.execute("NAMES = { [500] = 'Shield', [501] = 'Shield Buff' }")
    got, err = lines(L, "posts[1](GameTooltip, { id = 500, lines = { %s } })" % nested)
    # (the tooltip's own "not known yet" line is what it shows for any spell with no known aura, with rule tracking on too)
    check("A: no service: the tooltip shows its ID line and no aura from the effect block, no error", got == ["Spell ID: 500", "Aura ID: not known yet"] and err is None, (got, err))
    L.execute("ERR = nil; local ok, h = pcall(XayaUI_NS.TT.TalentHash); if not ok then ERR = tostring(h) else HASH = h end")
    check("A: no service: the talent hash still works (an empty talent list: djb2 of \"\" = 00001505)", L.eval("ERR") is None and L.eval("HASH") == "00001505", (L.eval("ERR"), L.eval("HASH")))
    # B. present, only as services
    L = make([])
    L.execute("NAMES = { [500] = 'Shield', [501] = 'Shield Buff', [502] = 'Old Buff', [503] = 'Cast Buff' }; noted = nil; "
              "XayaUI_NS.AuraSources = nil; XayaUI_NS.AuraModel = nil; "
              "XayaUI_NS.Provide('AuraSources', { EmbeddedAuras = function(data, skip) return { { id = 501, name = 'Shield Buff' } } end, "
              "  AurasOf = function(k, id) if id == 500 then return { { id = 502, name = 'Old Buff' } } end return {} end, "
              "  Note = function(k, id, a) noted = id end }); "
              "XayaUI_NS.Provide('AuraModel', { AurasForCast = function(id) if id == 500 then return { { id = 503, name = 'Cast Buff' } } end return {} end, "
              "  ActiveTalentSpells = function() return { 7, 3 } end })")
    got, err = lines(L, "posts[1](GameTooltip, { id = 500 })")
    want = ["Spell ID: 500", "Aura ID: 501  (Shield Buff)", "Aura ID: 502  (Old Buff)", "Aura ID: 503  (Cast Buff)"]
    check("B: the aura lines come from the services (effect block, recorded earlier, your casts)", got == want and err is None, (got, err))
    check("B: ...and what the tooltip showed is noted through the service", L.eval("noted") == 500, L.eval("noted"))
    L.execute("ERR = nil; local ok, h = pcall(XayaUI_NS.TT.TalentHash); if not ok then ERR = tostring(h) else HASH = h end")
    L.execute("local s, h = '3,7', 5381; for i = 1, #s do h = (h * 33 + s:byte(i)) % 4294967296 end; WANTHASH = ('%08x'):format(h)")
    check("B: the talent hash reads the talent list from the AuraModel service", L.eval("ERR") is None and L.eval("HASH") == L.eval("WANTHASH"), (L.eval("ERR"), L.eval("HASH")))
    # C. the real AuraSources.lua provides itself
    L = make(["XayaUI/AuraSources.lua"])
    L.execute("NAMES = { [500] = 'Shield', [501] = 'Shield Buff' }; XayaUI_NS.AuraSources = nil")
    got, err = lines(L, "posts[1](GameTooltip, { id = 500, lines = { %s } })" % nested)
    check("C: AuraSources.lua offers itself as the service; its effect-block reader fills the tooltip", got == ["Spell ID: 500", "Aura ID: 501  (Shield Buff)"] and err is None, (got, err))
    bad = 0
    for name, ok in R:
        print(("PASS " if ok else "FAIL ") + name)
        bad += 0 if ok else 1
    print("%d checks  FAILS: %d" % (len(R), bad))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
