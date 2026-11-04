"""Core 0.6.13: the retrospective's aura gaps 5, 12, 15, 20 and 21 (docs/process/RETROSPECTIVE.md), against XayaUI's real core files
and stand-in game calls. Outcomes only: what a trigger answers, what a rule reads, what the game is asked to play.

  gap 5   proc glows: the "Spell Glows" trigger row; a glowing button that only one aura lights answers "present" for that aura,
          but only after the pairing has been seen to hold in game (no disagreement), and never answers "absent";
  gap 12  the "Tier Set Pieces Worn" trigger row (equipped items counted by their item set ID);
  gap 15  an icon whose spell is replaced in combat (COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED) is still found under the new ID;
  gap 20  C_Secrets.ShouldSpellAuraBeSecret is reported, never used to decide (semantics undocumented);
  gap 21  the opt-in game-played aura sound (C_UnitAuras.AddAuraSound, decision D2), and the per-rule "readable in combat" line.

Spell IDs: Rime 59052 -> Howling Blast 49184 and Brain Freeze 190446 -> Flurry 44614 are rows of XayaUI/ProcGlows.lua (generated
from the game's SpellActivationOverlay table, build 12.1.5.70783). Everything else is a stand-in.
Run: python3 tests/aura_gaps_run.py   (needs: pip install lupa)"""
import os, sys
from lupa.lua51 import LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
bench = open(os.path.join(ROOT, "tests", "engine_bench.py")).read()
a = bench.index("L.execute(r'''") + len("L.execute(r'''"); b = bench.index("''')", a)
L = LuaRuntime(unpack_returned_tuples=True)
L.execute("CueRulesDB = { rules = {}, folders = {} }")
L.execute(bench[a:b])
L.execute(r'''
-- events and timers that can be driven
EVENTS = {}
local M = FRAME_METHODS
function M:RegisterEvent(e) EVENTS[e] = EVENTS[e] or {}; table.insert(EVENTS[e], self) end
function M:RegisterUnitEvent(e) EVENTS[e] = EVENTS[e] or {}; table.insert(EVENTS[e], self) end
function FIRE(e, ...) for _, f in ipairs(EVENTS[e] or {}) do local s = f["_s_OnEvent"]; if s then s(f, e, ...) end end end
TIMERS = {}
C_Timer.After = function(d, fn) TIMERS[#TIMERS + 1] = fn end
function RUN_TIMERS() local t = TIMERS; TIMERS = {}; for _, fn in ipairs(t) do fn() end end
HOOKS = {}
hooksecurefunc = function(t, k, fn) if type(t) == "string" then return end; local old = t[k]; t[k] = function(...) local r = { old(...) }; fn(...); return unpack(r) end end

COMBAT = false
InCombatLockdown = function() return COMBAT end
UnitAffectingCombat = function() return COMBAT end
SECRET = setmetatable({}, { __tostring = function() return "SECRET" end })
issecretvalue = function(v) return v == SECRET end
Enum = Enum or {}
Enum.SecrecyLevel = { NeverSecret = 0, AlwaysSecret = 1, ContextuallySecret = 2 }
Enum.UnitAuraSoundTrigger = { Added = 0, ApplicationsIncreased = 1, Removed = 2 }
SPELL_SECRET_NOW = {}
C_Secrets = { ShouldAurasBeSecret = function() return COMBAT end, GetSpellAuraSecrecy = function() return 2 end,
  ShouldSpellAuraBeSecret = function(id) if SPELL_SECRET_NOW[id] == nil then return true end return SPELL_SECRET_NOW[id] end }
-- auras on you: hidden (secret) in combat
AURAS = {}
NIL_IN_COMBAT = {}   -- auras the game answers with nil (not a secret) while restricted
C_UnitAuras.GetUnitAuraBySpellID = function(unit, id)
  if COMBAT then if NIL_IN_COMBAT[id] then return nil end return SECRET end
  return AURAS[id]
end
C_UnitAuras.GetPlayerAuraBySpellID = function(id) return C_UnitAuras.GetUnitAuraBySpellID("player", id) end
-- the game's button highlights
GLOW = {}
GLOW_API = true
C_SpellActivationOverlay = { IsSpellOverlayed = function(id) if not GLOW_API then error("no API") end; return GLOW[id] == true end }
OVERRIDE = {}
C_Spell.GetOverrideSpell = function(id) return OVERRIDE[id] or id end
C_Spell.GetBaseSpell = function(id) for b, o in pairs(OVERRIDE) do if o == id then return b end end return id end
-- the game's aura sounds
SOUNDS_ADDED, SOUNDS_REMOVED, NEXT_SOUND, SOUND_REFUSE = {}, {}, 100, false
C_UnitAuras.AddAuraSound = function(trigger, info)
  if SOUND_REFUSE then error("AddAuraSound: restricted") end
  NEXT_SOUND = NEXT_SOUND + 1
  SOUNDS_ADDED[#SOUNDS_ADDED + 1] = { id = NEXT_SOUND, trigger = trigger, info = info }
  return NEXT_SOUND
end
C_UnitAuras.RemoveAuraSound = function(id) SOUNDS_REMOVED[#SOUNDS_REMOVED + 1] = id end
PLAYED = {}
PlaySoundFile = function(f) PLAYED[#PLAYED + 1] = tostring(f); return true end
-- equipment: item -> set ID (16th value of C_Item.GetItemInfo)
EQUIP, ITEMSET, ITEM_LOADED = {}, {}, {}
GetInventoryItemID = function(unit, slot) return EQUIP[slot] end
C_Item = C_Item or {}
C_Item.GetItemInfo = function(id)
  if not ITEM_LOADED[id] then return nil end
  return "Item " .. id, nil, 4, 600, 80, "Armor", "Plate", 1, "INVTYPE_HEAD", 1, 1, 4, 4, 1, 11, ITEMSET[id], false, ""
end
C_Item.GetItemSetInfo = function(id) return "Set " .. id end
''')
toc = [l.strip() for l in open(os.path.join(ROOT, "XayaUI", "XayaUI.toc")) if l.strip() and not l.startswith("#")]
load = L.eval("function(src, name, ns) local f, e = loadstring(src, '@' .. name); if not f then error(e) end; return f('XayaUI', ns) end")
ns = L.eval("{}"); L.globals().NS = ns
skip = ("Libs", "Console.lua", "GameMenu", "MinimapButton", "AuraSources", "Combat/")
loaded, failed = [], []
for f in toc:
    f = f.replace("\\", "/")
    if f.startswith(skip) or not f.endswith(".lua"):
        continue
    try:
        load(open(os.path.join(ROOT, "XayaUI", f), encoding="utf-8").read(), f, ns); loaded.append(f)
    except Exception as e:
        failed.append((f, str(e)[:200]))

fails = []
def check(name, ok, extra=""):
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  [" + str(extra) + "]"))
    if not ok:
        fails.append(name)

check("every core file loads", not failed, failed)
check("ProcGlows.lua is in the toc and loaded", "ProcGlows.lua" in loaded and L.eval("NS.PROC_GLOW_AURAS and NS.PROC_GLOW_AURAS[59052] ~= nil"))
check("AuraSound.lua is in the toc and loaded", "AuraSound.lua" in loaded and L.eval("NS.AuraSound ~= nil"))
L.execute(r'''
local ns = NS
ns.rules = CueRulesDB.rules
ns.Print = function() end
ns.Log = function() end
function ROW(t) ns.tickID = (ns.tickID or 0) + 1; return (ns.CheckTrigger(t)) end
function PRES(main, alts, spell) ns.tickID = (ns.tickID or 0) + 1; local p, s = ns.AuraPresence(main, alts, spell); return p, s end
function BP2(id) ns.tickID = (ns.tickID or 0) + 1; local p, s = ns.BuffPresent(id); return p, s end
function ANY(rule) ns.tickID = (ns.tickID or 0) + 1; return (ns.BuffPresentAny(rule)) end
''')

# ---------------------------------------------------------------- gap 5: the Spell Glows row
L.execute("GLOW = { [49184] = true }; G1 = { type = 'spellGlow', spellID = 49184, state = 'yes' }")
check("Spell Glows: button highlighted -> true", L.eval("ROW(G1)") is True)
L.execute("G1.state = 'no'")
check("Spell Glows 'is NOT glowing' while it glows -> false", L.eval("ROW(G1)") is False)
L.execute("G1.state = 'yes'; GLOW = {}")
check("Spell Glows: not highlighted -> false (the highlight is readable)", L.eval("ROW(G1)") is False)
L.execute("OVERRIDE = { [49184] = 900001 }; GLOW = { [900001] = true }")
check("Spell Glows: the glow is on the spell that replaces it on the bar -> true", L.eval("ROW(G1)") is True)
L.execute("OVERRIDE = {}; GLOW = {}; GLOW_API = false")
check("Spell Glows: highlight unreadable and no event seen -> unknown (never a guess)", L.eval("ROW(G1)") is None)
L.execute("FIRE('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW', 49184)")
check("Spell Glows: unreadable, but GLOW_SHOW arrived -> true", L.eval("ROW(G1)") is True)
L.execute("FIRE('SPELL_ACTIVATION_OVERLAY_GLOW_HIDE', 49184)")
check("Spell Glows: unreadable, GLOW_HIDE arrived -> unknown again", L.eval("ROW(G1)") is None)
L.execute("GLOW_API = true; TIMERS = {}")
check("Spell Glows is offered as a trigger type with a combat note", L.eval("NS.TRIGGER_TYPES.spellGlow ~= nil and NS.TriggerCombatNote({}, 'x', G1):find('readable') ~= nil"))

# ---------------------------------------------------------------- gap 5: glow -> aura, only after the pairing is seen to hold
L.execute("COMBAT = true; GLOW = { [49184] = true }")
p, s = L.eval("PRES(59052)")
check("Rime hidden in combat, Howling Blast glowing, pairing never seen -> unknown (the table alone is not trusted)", p is None, (p, s))
# out of combat: Rime is on you and the button glows -> one agreeing sighting each time
L.execute("COMBAT = false; AURAS[59052] = { spellId = 59052, auraInstanceID = 5, applications = 0, expirationTime = 0, duration = 0 }")
L.execute("FIRE('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW', 49184); RUN_TIMERS()")
check("one sighting: glow + Rime readable on you -> counted as agreeing", L.eval("CueRulesDB.procGlowSeen.auras[59052].yes") == 1)
L.execute("COMBAT = true")
p, s = L.eval("PRES(59052)")
check("one agreeing sighting is not enough (needs %d) -> still unknown" % L.eval("NS.GLOW_TRUST"), p is None, (p, s))
L.execute("COMBAT = false; FIRE('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW', 49184); RUN_TIMERS(); COMBAT = true")
p, s = L.eval("PRES(59052)")
check("two agreeing sightings: Rime hidden, Howling Blast glowing -> PRESENT, from the glow", p is True and "proc glow" in str(s), (p, s))
L.execute("GLOW = {}")
p, s = L.eval("PRES(59052)")
check("no glow never means absent -> unknown", p is None, (p, s))
# the rule's built-in trigger and a further Buff / Aura row read the same answer (parity, gap 8)
L.execute(r'''
GLOW = { [49184] = true }
RIME = { uid = "rime", name = "Rime", enabled = true, useBuff = true, buffID = 59052, buffState = "present", cdState = "none", load = { mode = "always" } }
NS.rules[#NS.rules + 1] = RIME
RROW = { type = "buffAura", spellID = 59052, state = "yes" }
''')
check("built-in Buff / Aura and a Buff / Aura row agree (both present from the glow)",
      L.eval("ANY(RIME)") is True and L.eval("ROW(RROW)") is True, (L.eval("ANY(RIME)"), L.eval("ROW(RROW)")))
# one disagreement blocks the pairing for good
L.execute("COMBAT = false; AURAS = {}; FIRE('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW', 44614); RUN_TIMERS()")
L.execute("AURAS[190446] = { spellId = 190446, auraInstanceID = 6 }; for i = 1, 3 do FIRE('SPELL_ACTIVATION_OVERLAY_GLOW_SHOW', 44614); RUN_TIMERS() end")
L.execute("COMBAT = true; GLOW = { [44614] = true }")
p, s = L.eval("PRES(190446)")
check("Flurry glowed once while Brain Freeze read absent -> that pairing never answers (unknown), even after 3 agreements",
      p is None and L.eval("CueRulesDB.procGlowSeen.auras[190446].no") == 1, (p, s))
L.execute("CueRulesDB.procGlowSeen.build = 'older build'; COMBAT = true; GLOW = { [49184] = true }")
p, s = L.eval("PRES(59052)")
check("a new table build starts counting again -> unknown", p is None and L.eval("CueRulesDB.procGlowSeen.build == NS.PROC_GLOW_BUILD"), (p, s))
L.execute("COMBAT = false; GLOW = {}; AURAS = {}")

# ---------------------------------------------------------------- gap 15: an icon's spell replaced in combat
L.execute(r'''
ICON = CreateFrame("Frame")
ICON.xuiLastIDs = { 51271 }          -- the IDs it showed while readable
ICON.wasSetFromAura = true
function ICON:GetSpellID() return SECRET end
ICON.cooldownInfo = SECRET
EssentialCooldownViewer = CreateFrame("Frame"); function EssentialCooldownViewer:GetChildren() return ICON end
NOW = NOW + 1
''')
check("before: the icon is found under the spell it showed", L.eval("NS.FindCDMFrame(51271) == ICON"))
check("before: not under the replacement it was given in combat", L.eval("NS.FindCDMFrame(900051) == nil"))
L.execute("FIRE('COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED', 51271, 900051)")
check("after COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED: found under the replacement too (no 0.25 s wait)", L.eval("NS.FindCDMFrame(900051) == ICON"))
L.execute("FIRE('COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED', SECRET, 900052)")
check("a secret payload changes nothing", L.eval("NS.FindCDMFrame(900052) == nil"))
L.execute("EssentialCooldownViewer = nil; NOW = NOW + 1")

# ---------------------------------------------------------------- gap 20: reported, never decides
L.execute("COMBAT = true; NIL_IN_COMBAT[777001] = true; SPELL_SECRET_NOW[777001] = false")
p, s = L.eval("BP2(777001)")
check("ShouldSpellAuraBeSecret = false is shown in the reason but the answer stays unknown", p is None and "NOT secret now" in str(s), (p, s))
L.execute("COMBAT = false")

# ---------------------------------------------------------------- gap 12: Tier Set Pieces Worn
L.execute(r'''
EQUIP = { [1] = 501, [3] = 503, [5] = 505, [7] = 507, [10] = 510, [11] = 511 }
ITEMSET = { [501] = 1234, [503] = 1234, [505] = 1234, [507] = 1234, [510] = 999 }
ITEM_LOADED = { [501] = true, [503] = true, [505] = true, [507] = true, [510] = true, [511] = true }
FIRE("PLAYER_EQUIPMENT_CHANGED")
S4 = { type = "setPieces", setID = 0, op = ">=", count = 4 }
S5 = { type = "setPieces", setID = 0, op = ">=", count = 5 }
S999 = { type = "setPieces", setID = 999, op = ">=", count = 2 }
''')
check("4 pieces of set 1234 worn: '>= 4 of the set worn most' -> true", L.eval("ROW(S4)") is True)
check("... '>= 5' -> false", L.eval("ROW(S5)") is False)
check("set 999 named: 1 piece, '>= 2' -> false", L.eval("ROW(S999)") is False)
L.execute("EQUIP[7] = nil; FIRE('PLAYER_EQUIPMENT_CHANGED')")
check("legs taken off (event): 3 pieces -> '>= 4' false", L.eval("ROW(S4)") is False)
L.execute("EQUIP[7] = 507; ITEM_LOADED[507] = nil; FIRE('PLAYER_EQUIPMENT_CHANGED')")
check("an equipped item's data not loaded yet -> unknown, not a wrong count", L.eval("ROW(S4)") is None)
L.execute("ITEM_LOADED[507] = true; FIRE('GET_ITEM_INFO_RECEIVED', 507)")
check("item data arrives -> counted again: true", L.eval("ROW(S4)") is True)
check("the trigger pane lists the sets worn", "Set 1234 (1234): 4" in str(L.eval("NS.SetPiecesNote()")), L.eval("NS.SetPiecesNote()"))

# ---------------------------------------------------------------- gap 21: the game-played aura sound (D2)
L.execute(r'''
BP = { uid = "bp", name = "Boiling Point", enabled = true, useBuff = true, buffID = 1265968, buffAlt = { 1265969 }, buffState = "present",
  cdState = "none", load = { mode = "always" }, sound = { enabled = true, source = "file", value = "Interface\\AddOns\\XayaUI_Media\\Sounds\\bp.ogg", channel = "Master" },
  gameSound = { enabled = true, when = "auto", channel = "Ambience", throttle = 1 } }
NS.rules[#NS.rules + 1] = BP
SOUNDS_ADDED, SOUNDS_REMOVED = {}, {}
NS.AuraSound.Sync()
''')
n = L.eval("#SOUNDS_ADDED")
check("opt-in on: the game is asked to play the sound for the aura and its extra ID", n == 2, n)
check("... on 'Added', for the player, the rule's file, its own channel (Ambience) and throttle",
      L.eval("(function() local a = SOUNDS_ADDED[1]; return a.trigger == 0 and a.info.unitToken == 'player' and a.info.spellID == 1265968 and a.info.soundFileName:find('bp.ogg') ~= nil and a.info.outputChannel == 'Ambience' and a.info.throttleSeconds == 1 end)()"))
check("XayaUI does not play a second copy when the rule fires", L.eval("NS.AuraSound.Owns(BP)") is True)
L.execute("BP.gameSound.alsoXayaUI = true")
check("'also play it from XayaUI' -> XayaUI plays its own copy too", L.eval("NS.AuraSound.Owns(BP)") is False)
L.execute("BP.gameSound.alsoXayaUI = nil; NS.AuraSound.Sync()")
check("nothing changed -> nothing registered again", L.eval("#SOUNDS_ADDED") == 2 and L.eval("#SOUNDS_REMOVED") == 0)
L.execute("BP.buffState = 'missing'; NS.AuraSound.Sync()")
check("buff MISSING rule -> re-registered on 'Removed'", L.eval("#SOUNDS_REMOVED") == 2 and L.eval("SOUNDS_ADDED[#SOUNDS_ADDED].trigger") == 2)
L.execute("BP.buffState = 'present'; COMBAT = true; BP.gameSound.channel = 'SFX'; SOUNDS_ADDED = {}; NS.AuraSound.Sync()")
check("in combat: nothing is registered (out of combat only), and the pane says it waits",
      L.eval("#SOUNDS_ADDED") == 0 and "Waiting" in str(L.eval("NS.AuraSound.StatusLine(BP)")), L.eval("NS.AuraSound.StatusLine(BP)"))
L.execute("COMBAT = false; FIRE('PLAYER_REGEN_ENABLED'); RUN_TIMERS()")
check("combat ends -> registered with the new channel", L.eval("#SOUNDS_ADDED") == 2 and L.eval("SOUNDS_ADDED[1].info.outputChannel") == "SFX")
L.execute("BP.sound.source = 'kit'; BP.sound.value = '8959'; SOUNDS_ADDED = {}; NS.AuraSound.Sync()")
check("a [Game] sound kit cannot be handed over: not registered, the pane says why, XayaUI keeps playing it",
      L.eval("#SOUNDS_ADDED") == 0 and "sound kit" in str(L.eval("NS.AuraSound.StatusLine(BP)")) and L.eval("NS.AuraSound.Owns(BP)") is False)
L.execute("BP.sound.source = 'file'; BP.sound.value = '569593'; SOUND_REFUSE = true; NS.AuraSound.Sync()")
check("the game refuses -> not owned (XayaUI keeps playing it) and the reason is shown",
      L.eval("NS.AuraSound.Owns(BP)") is False and "refused" in str(L.eval("NS.AuraSound.StatusLine(BP)")), L.eval("NS.AuraSound.StatusLine(BP)"))
L.execute("SOUND_REFUSE = false; NS.AuraSound.Sync()")
check("a FileDataID is passed as soundFileID", L.eval("SOUNDS_ADDED[#SOUNDS_ADDED].info.soundFileID") == 569593)
L.execute("BP.gameSound.enabled = false; SOUNDS_REMOVED = {}; NS.AuraSound.Sync()")
check("opt-in off -> the game's registrations are removed", L.eval("#SOUNDS_REMOVED") == 2 and L.eval("NS.AuraSound.Owns(BP)") is False)

# ---------------------------------------------------------------- gap 21 / #21 part 1: one line for the whole rule
L.execute(r'''
C_Secrets.GetSpellAuraSecrecy = function(id) if id == 59052 then return 0 end return 2 end
MIX = { uid = "mix", name = "mix", enabled = true, useBuff = true, buffID = 424242, buffState = "present", cdState = "none",
  extra = { list = { { type = "spellGlow", spellID = 49184, state = "yes" }, { type = "buffAura", spellID = 59052, state = "yes" } } } }
''')
line = str(L.eval("NS.RuleCombatSummary(MIX)"))
check("rule line: names the trigger that may read unknown in combat", "1 of 3" in line and "Buff / Aura" in line and "Spell Glows" not in line, line)
L.execute("MIX.buffID = 59052")
line = str(L.eval("NS.RuleCombatSummary(MIX)"))
check("rule line: every trigger readable -> says so", "every trigger" in line, line)

# ================================================================ the first half of the batch (gaps 1, 4, 6, 7, 10, 11, 22)
# ---------------------------------------------------------------- gap 1: a hidden Cooldown Manager window gives no answer
L.execute(r'''
COMBAT = true; AURAS = {}; GLOW = {}
IC = CreateFrame("Frame"); IC.cooldownInfo = { spellID = 3001 }; function IC:GetSpellID() return 3001 end
IC.wasSetFromAura = false
BuffIconCooldownViewer = CreateFrame("Frame"); function BuffIconCooldownViewer:GetChildren() return IC end
NOW = NOW + 1
''')
p, s = L.eval("BP2(3001)")
check("shown Tracked Buffs icon, unlit -> missing", p is False, (p, s))
L.execute("BuffIconCooldownViewer:Hide(); NOW = NOW + 1")
p, s = L.eval("BP2(3001)")
check("the same icon while its window is hidden (it stops following auras) -> unknown, not missing", p is None, (p, s))
L.execute("BuffIconCooldownViewer:Show(); IC.wasSetFromAura = true; NOW = NOW + 1")
check("CDMFrameState is a read-only lit / unlit answer", L.eval("NS.CDMFrameState(3001)") is True)
L.execute("BuffIconCooldownViewer = nil; COMBAT = false; NOW = NOW + 1")

# ---------------------------------------------------------------- gap 4: spells replaced by a talent
L.execute(r'''
OVERRIDE = { [4001] = 4002 }
C_Spell.IsSpellUsable = function(id) if id == 4002 then return true, false end return false, false end
CAST = { type = "castSucceeded", spellID = 4001, window = 3, state = "yes" }
USE = { type = "actionUsable", spellID = 4001, state = "usable" }
''')
check("Spell Usable on the base spell reads the spell on your bar (its replacement)", L.eval("ROW(USE)") is True)
L.execute("NOW = NOW + 10; FIRE('UNIT_SPELLCAST_SUCCEEDED', 'player', 'cast-guid', 4002)")
check("casting the replacement counts for a rule on the base spell", L.eval("ROW(CAST)") is True)
L.execute("OVERRIDE = {}; NOW = NOW + 10")

# ---------------------------------------------------------------- gap 6: aura length learned from a fresh application only
L.execute(r'''
COMBAT = false; CueRulesDB.learnedAuraDur = {}
AURAS[6001] = nil
BP2(6001)                                            -- seen absent
AURAS[6001] = { spellId = 6001, auraInstanceID = 61, expirationTime = NOW + 10, duration = 10, applications = 0 }
NS.lastAuraEventAt = NOW
BP2(6001)                                            -- appears: a fresh application
''')
check("a fresh application teaches the aura's length (10 s)", L.eval("CueRulesDB.learnedAuraDur[6001]") == 10)
L.execute("NOW = NOW + 5; AURAS[6001].expirationTime = NOW + 14; AURAS[6001].duration = 14; BP2(6001)")
check("a refresh 5 s later (14 s with carried-over time) does not overwrite it", L.eval("CueRulesDB.learnedAuraDur[6001]") == 10, L.eval("CueRulesDB.learnedAuraDur[6001]"))

# ---------------------------------------------------------------- gap 7: a fallback icon starts the time estimate
L.execute(r'''
COMBAT = true; NOW = NOW + 1
NAMES7 = { [7001] = "Shield Wall", [7002] = "Shield Wall" }
OLDNAME = C_Spell.GetSpellName
C_Spell.GetSpellName = function(id) return NAMES7[id] or OLDNAME(id) end
SW = CreateFrame("Frame"); SW.cooldownInfo = { spellID = 7001 }; function SW:GetSpellID() return 7001 end
SW.wasSetFromAura = true; SW.xuiAppliedAt = NOW - 2
BuffIconCooldownViewer = CreateFrame("Frame"); function BuffIconCooldownViewer:GetChildren() return SW end
CueRulesDB.learnedAuraDur[7002] = 10
''')
L.execute("P7, S7, R7 = NS.AuraPresence(7002, nil, nil)")
check("aura 7002 found through the Tracked Buffs icon filed under its name", L.eval("P7") is True, L.eval("S7"))
check("... and the reference carries that icon, so the estimate starts at its applied moment (8 s left)",
      L.eval("(function() local exp = NS.Timing.AuraEstimate(7002, nil, R7 and R7.cdmFrame); return exp and math.abs(exp - NOW - 8) < 0.01 end)()") is True)
L.execute("BuffIconCooldownViewer = nil; C_Spell.GetSpellName = OLDNAME; COMBAT = false; NOW = NOW + 1")

# ---------------------------------------------------------------- gap 10: a spell you do not have is never "ready"
L.execute(r'''
KNOWN = { [10001] = true }
C_SpellBook = C_SpellBook or {}
C_SpellBook.IsSpellKnownOrInSpellBook = function(id, bank) return KNOWN[id] == true end
IsPlayerSpell = function(id) return KNOWN[id] == true end
C_Spell.GetSpellCooldown = function(id) return { startTime = 0, duration = 0, isActive = false, isOnGCD = false, isEnabled = true, modRate = 1 } end
C_Spell.GetSpellCharges = function() return nil end
''')
L.execute("NK = NS.ReadCooldown({ spellID = 10002 }); KK = NS.ReadCooldown({ spellID = 10001 })")
check("spell not known (talent / spec swapped away) -> not known, with the reason", L.eval("NK.known") is False and "not known" in str(L.eval("NK.why")), L.eval("NK.why"))
check("a known spell off cooldown -> known and ready", L.eval("KK.known") is True and L.eval("NS.CheckCooldownState({ spellID = 10001, cdState = 'ready' }, KK)") is True)

# ---------------------------------------------------------------- gap 11: seconds left on a cooldown in combat
L.execute(r'''
COMBAT = true
CDRET = { startTime = SECRET, duration = SECRET, isActive = false, isOnGCD = false, isEnabled = true }
C_Spell.GetSpellCooldown = function(id) return CDRET end
NS.Timing.CooldownEstimate = function() return nil end
P11 = { spellID = 10001 }
''')
check("times hidden but the game says 'not on cooldown' (NeverSecret flag) -> 0 s left", L.eval("NS.NumRef('n:cdRemain', P11, {})") == 0)
L.execute("CDRET.isActive = true; NS.Timing.CooldownEstimate = function() return NOW - 1 end")
check("on cooldown, the estimate already ran out -> unknown (was 0 s)", L.eval("NS.NumRef('n:cdRemain', P11, {})") is None)
L.execute("NS.Timing.CooldownEstimate = function() return NOW + 4 end")
check("on cooldown, estimate in the future -> its seconds left", abs((L.eval("NS.NumRef('n:cdRemain', P11, {})") or -1) - 4) < 0.01)
L.execute("CDRET.isOnGCD = true")
check("only the global cooldown runs -> 0 s left", L.eval("NS.NumRef('n:cdRemain', P11, {})") == 0)
L.execute("COMBAT = false")

# ---------------------------------------------------------------- gap 22: "Cooldown (any spell)" rows' charges are watched
L.execute(r'''
WATCHED = {}
C_Spell.GetSpellCharges = function(id) WATCHED[id] = true; return { currentCharges = 1, maxCharges = 2, isActive = true } end
CDROW = { uid = "cdrow", name = "rows", enabled = true, spellID = 0, extra = { list = { { type = "cooldown", spellID = 22001, state = "ready" } } } }
NS.rules[#NS.rules + 1] = CDROW
NS._WatchCharges()
''')
check("a Cooldown (any spell) row's charges are read with the rule's own spell", L.eval("WATCHED[22001]") is True)

# ---------------------------------------------------------------- built into aura tracking (core 0.6.20): tier-set auras and the glow line
# 1241227 "Arcanoweave Audacity": in XayaUI/SetBonusAuras.lua, from set 1958's 2-piece bonus, any specialization (game data)
check("SetBonusAuras.lua is loaded and lists 1241227 (set 1958, 2 pieces)", L.eval("NS.SET_BONUS_AURAS and NS.SET_BONUS_AURAS[1241227] and NS.SET_BONUS_AURAS[1241227].set == 1958 and NS.SET_BONUS_AURAS[1241227].pieces == 2") is True)
L.execute(r'''
COMBAT = true; NIL_IN_COMBAT = {}
EQUIP = { [1] = 701, [3] = 703 }; ITEMSET = { [701] = 1958, [703] = 4242 }; ITEM_LOADED = { [701] = true, [703] = true }
FIRE("PLAYER_EQUIPMENT_CHANGED")
''')
p, s2 = L.eval("PRES(1241227)")
check("in combat, 1 piece of its set worn: the set-only aura reads MISSING (not unknown), with the reason", p is False and "set bonus" in str(s2), (p, s2))
L.execute("EQUIP[3] = 702; ITEMSET[702] = 1958; ITEM_LOADED[702] = true; FIRE('PLAYER_EQUIPMENT_CHANGED')")
p, s2 = L.eval("PRES(1241227)")
check("2 pieces worn: the bonus is active, so XayaUI reads the aura as usual (hidden in combat: unknown)", p is None, (p, s2))
p, s2 = L.eval("PRES(1241227, { 777777 })")
check("an extra aura ID that is not set-only keeps the normal reading", p is not False, (p, s2))
L.execute("COMBAT = false; EQUIP = {}; FIRE('PLAYER_EQUIPMENT_CHANGED')")
note = str(L.eval("NS.TriggerCombatNote({}, 'x', { type = 'buffAura', spellID = 1241227, state = 'yes' })"))
check("the aura trigger's In combat line says it comes from a set bonus", "set bonus" in note and "set 1958" in note, note)
# the glow line: Rime 59052 (Howling Blast). (An earlier section made 59052 "never hidden": back to hidden in combat, as in the game.)
L.execute("C_Secrets.GetSpellAuraSecrecy = function() return 2 end; NS.ClearSecrecyCache()")
L.execute("CueRulesDB.procGlowSeen = { build = NS.PROC_GLOW_BUILD, auras = { [59052] = { yes = 1, no = 0 } } }")
note = str(L.eval("NS.TriggerCombatNote({}, 'x', { type = 'buffAura', spellID = 59052, state = 'yes' })"))
check("glow not yet confirmed: the line says it will stand in after 2 agreeing sightings (1 so far)", "will stand in" in note and "1 so far" in note, note)
L.execute("CueRulesDB.procGlowSeen.auras[59052].yes = 2")
note = str(L.eval("NS.TriggerCombatNote({}, 'x', { type = 'buffAura', spellID = 59052, state = 'yes' })"))
check("glow confirmed: the line says the aura is read from its proc glow in combat", "present from its proc glow" in note, note)

# ---------------------------------------------------------------- Advanced Debugging record (core 0.6.20): aura answers as they change
L.execute(r'''
COMBAT = false; CueRulesDB.debugRecord = nil
CueRulesDB.ui = CueRulesDB.ui or {}; CueRulesDB.ui.advancedDebug = true
AURAS[8801] = nil; BP2(8801); BP2(8801)
AURAS[8801] = { spellId = 8801, auraInstanceID = 881, applications = 0, expirationTime = 0, duration = 0 }; BP2(8801); BP2(8801)
function NREC(pat) local n = 0; for _, l in ipairs((CueRulesDB.debugRecord or { lines = {} }).lines) do if l:find(pat, 1, true) then n = n + 1 end end; return n end
''')
check("Advanced Debugging: an aura's answer is recorded when it changes (missing, then present), not on every read",
      L.eval("NREC('(8801): missing')") == 1 and L.eval("NREC('(8801): present')") == 1, (L.eval("NREC('(8801)')"),))
L.execute("CueRulesDB.ui.advancedDebug = false; AURAS[8801] = nil; BP2(8801)")
check("Advanced Debugging off: nothing more is recorded", L.eval("NREC('(8801)')") == 2)
L.execute("CueRulesDB.ui.advancedDebug = true")
okBad = L.eval("function() return pcall(function() return NS.AuraPresentList('not-a-number', { 'also bad' }) end) end")()
check("Advanced Debugging on: a rule holding a non-numeric aura ID (an import, a typo) still reads without an error",
      okBad[0] is True if isinstance(okBad, tuple) else okBad is True, okBad)
check("  ...and the record says which ID it was", L.eval("NREC('(not-a-number)')") == 1)
L.execute("CueRulesDB.ui.advancedDebug = false")

print("FAILS: %d" % len(fails))
sys.exit(1 if fails else 0)
