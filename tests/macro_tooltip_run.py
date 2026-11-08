#!/usr/bin/env python3
"""Enhanced Tooltips on macro tooltips (Bonus 0.6.36, issue #462 cause 1). Xaya 2026-11-07 (baseline walkthrough bars-cues, step 8):
Sigil of Flame and Infernal Strike showed "Fire damage" uncoloured; they were hovered as macros on the action bar. The game hands such
a tooltip over as Enum.TooltipDataType.Macro (= 25, docs/reference/api/enums.md), which XayaUI never hooked, so no Type colours, no
Spell ID line and no formula lines appeared on it.

Loads the real addons in the stand-in game (tests/harness), fires the post-calls XayaUI placed for a Macro tooltip with a test tooltip
(its lines as the game would show them), and checks what the player sees:
  - the "fire damage" line is title-cased and drawn in the game's Fire colour (read from the tooltip's own line);
  - the macro's spell is resolved (GetMacroSpell(data.id), checked against the tooltip's title) and its Spell ID line is added;
  - fail safe: a macro whose spell's name is not the tooltip's title, or a game without GetMacroSpell, gets the colours only (no
    Spell ID guessed);
  - Type colours off: the line is left as the game wrote it;
  - parity: the same line on a Spell tooltip and on a Macro tooltip gets the same text.
INFERENCE (not in the 12.1.5 reference, unverified in game): a Macro tooltip's data.id is the macro's index for GetMacroSpell. The
numbers below (colours, IDs) are test stand-ins, not Blizzard's.
Run: python3 tests/macro_tooltip_run.py"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
-- the game's school colours (test stand-in numbers) and the macro / spell reads
COMBATLOG_DEFAULT_COLORS = { schoolColoring = {} }
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
COMBATLOG_DEFAULT_COLORS.schoolColoring[Enum.Damageclass.MaskFire] = { r = 0.9, g = 0.4, b = 0.1 }
MACROS = { [7] = 204596 }     -- macro index 7 shows Sigil of Flame (stand-in)
SPELLNAMES = { [204596] = "Sigil of Flame", [258920] = "Immolation Aura" }
rawset(_G, "GetMacroSpell", function(m) return MACROS[m] end)
C_Spell = C_Spell or {}
local realName = C_Spell.GetSpellName
C_Spell.GetSpellName = function(id) return SPELLNAMES[id] end
local TT = ns.TT
check("Enhanced Tooltips is loaded and on", TT ~= nil and TT.on == true and TT.SectionOn("typeColors"))
check("the game's tooltip type list has Macro (25)", Enum.TooltipDataType.Macro == 25)
-- every post-call XayaUI placed for a tooltip type
local function posts(t) local out = {}; for _, p in ipairs(W.tooltipPostCalls or {}) do if p[1] == t then out[#out + 1] = p[2] end end; return out end
check("XayaUI handles Macro tooltips (a post-call for Enum.TooltipDataType.Macro)", #posts(Enum.TooltipDataType.Macro) > 0, #posts(Enum.TooltipDataType.Macro))
-- a test tooltip as the game draws it: left texts by line, plus the lines XayaUI adds
local added
local function Tip(title, body)
  added = {}
  local L1, L2 = { v = title }, { v = body }
  local function fs(t) return { GetText = function() return t.v end, SetText = function(_, x) t.v = x end } end
  _G.XUIMacroTipTextLeft1, _G.XUIMacroTipTextLeft2, _G.XUIMacroTipTextRight1 = fs(L1), fs(L2), fs({ v = nil })
  local tip = { GetName = function() return "XUIMacroTip" end, NumLines = function() return 2 end,
    AddLine = function(_, a) added[#added + 1] = tostring(a) end,
    AddDoubleLine = function(_, a, b) added[#added + 1] = tostring(a) .. " " .. tostring(b) end }
  local data = { lines = { { leftText = title }, { leftText = body } } }
  return tip, data, L2
end
local function hover(kind, tip, data) for _, f in ipairs(posts(Enum.TooltipDataType[kind])) do f(tip, data) end end
local function hasLine(s) for _, a in ipairs(added) do if a:find(s, 1, true) then return true end end return false end
local FIRE = "|cffe6661aFire Damage|r"
local function LM() return TT.lastMacro or {} end

-- 1. Sigil of Flame as a macro (her case)
local tip, data, L2 = Tip("Sigil of Flame", "Deals 120 fire damage to enemies in the area.")
data.id = 7
hover("Macro", tip, data)
check("a macro's 'fire damage' line is title-cased and drawn in the game's Fire colour", L2.v == "Deals 120 " .. FIRE .. " to enemies in the area.", L2.v)
check("the macro's spell is resolved: Sigil of Flame (204596)", LM().spellID == 204596 and LM().macroID == 7,
  tostring(LM().spellID) .. " " .. tostring(LM().why))
check("...and the coloured words are kept for the QA walkthrough ('Fire Damage e6661a')", LM().colored and LM().colored[1] == "Fire Damage e6661a", LM().colored and LM().colored[1])
check("...and the same spell lines are added: 'Spell ID: 204596'", hasLine("Spell ID: 204596"), table.concat(added, " | "))
check("...the colour is not applied twice (one colour code on the line)", select(2, L2.v:gsub("|c", "")) == 1, L2.v)

-- 2. parity: the same tooltip as a Spell tooltip gets the same line
local tipS, dataS, L2S = Tip("Sigil of Flame", "Deals 120 fire damage to enemies in the area.")
dataS.id = 204596
hover("Spell", tipS, dataS)
check("parity: the Spell tooltip and the Macro tooltip of the same spell show the same line", L2S.v == L2.v, L2S.v)

-- 3. fail safe: the tooltip's title is not the spell GetMacroSpell names (e.g. data.id is not the macro index): colours only
tip, data, L2 = Tip("Infernal Strike", "Deals 60 fire damage.")
data.id = 7
hover("Macro", tip, data)
check("a macro whose resolved spell's name is not the tooltip's title: no Spell ID line (nothing guessed)", not hasLine("Spell ID:") and LM().spellID == nil, table.concat(added, " | "))
check("...but its 'fire damage' is still coloured (colours read only the tooltip's text)", L2.v == "Deals 60 " .. FIRE .. ".", L2.v)
-- 4. a game without GetMacroSpell
rawset(_G, "GetMacroSpell", nil)
tip, data, L2 = Tip("Sigil of Flame", "Deals 120 fire damage.")
data.id = 7
hover("Macro", tip, data)
check("no GetMacroSpell in the game: colours only, no Spell ID, nothing errors", L2.v == "Deals 120 " .. FIRE .. "." and not hasLine("Spell ID:") and LM().why == "the game has no GetMacroSpell",
  tostring(LM().why))
rawset(_G, "GetMacroSpell", function(m) return MACROS[m] end)
-- 5. Type colours off
TT.DB().typeColors.enabled = false
tip, data, L2 = Tip("Sigil of Flame", "Deals 120 fire damage.")
data.id = 7
hover("Macro", tip, data)
check("Type colours off: the macro's line is left as the game wrote it", L2.v == "Deals 120 fire damage.", L2.v)
TT.DB().typeColors.enabled = true
-- 6. a secret macro ID (in combat the game may hand one over): colours only
tip, data, L2 = Tip("Sigil of Flame", "Deals 120 fire damage.")
local sec = {}
W.secret = W.secret or {}; W.secret[sec] = true
data.id = sec
hover("Macro", tip, data)
check("a secret macro ID: colours only, no Spell ID, nothing errors", L2.v == "Deals 120 " .. FIRE .. "." and not hasLine("Spell ID:") and LM().spellID == nil,
  tostring(LM().why))
W.secret[sec] = nil
C_Spell.GetSpellName = realName
return R
end
'''


def main():
    folders = H.find_addons()
    enabled = [n for n in folders if n != "XayaUI_DevAssist"]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    bad = 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        print(("PASS " if ok else "FAIL ") + name)
        if not ok:
            bad += 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
