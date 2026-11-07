import sys, os
import sys as _sys
_sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lua51 as lupa   # Lua 5.1, like the game (tests/lua51.py)
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
import sys as _sys, os as _os
_sys.path.insert(0, _os.path.dirname(_os.path.abspath(__file__)))
from lua51 import runtime as LuaRuntime   # Lua 5.1, like the game (tests/lua51.py)
L = LuaRuntime(unpack_returned_tuples=True)
L.execute(r'''
secret = {}
function issecretvalue(v) return secret[v] == true end
now = 100
function GetTime() return now end
lines = {}
GameTooltip = { AddDoubleLine=function(self,a,b) lines[#lines+1]=a.." "..b end, IsShown=function() return true end,
  GetUnit=function() return "mouseover", "mouseover" end, RefreshData=function() end }
posts = {}
Enum = { TooltipDataType = { Item=0, Spell=1, Unit=2, Currency=5, BattlePet=6, UnitAura=7, Mount=10, Achievement=12, Toy=19, Quest=23 } }
TooltipDataProcessor = { AddTooltipPostCall=function(t,f) posts[t]=f end }
function CreateFrame() return { RegisterEvent=function() end, UnregisterEvent=function() end, SetScript=function(s,n,f) _G.evh=f end } end
SlashCmdList = {}
function strsplit(sep, s) local t={} for p in (s..sep):gmatch("(.-)"..sep) do t[#t+1]=p end return table.unpack(t) end
C_Spell = { GetSpellTexture=function(id) return 1000+id end }
C_Item = { GetItemIconByID=function(id) return 2000+id end }
inCombat=false
function InCombatLockdown() return inCombat end
function IsInInstance() return true, "party" end
C_ChallengeMode = { IsChallengeModeActive=function() return true end }
function UnitIsPlayer(u) return isPlayer end
function UnitIsUnit(a,b) return a==b end
function UnitGUID() return guid end
function UnitCanAttack() return canAttack end
function GetAverageItemLevel() return 500, 480.25 end
function CanInspect() return true end
notified=0; cleared=0
function NotifyInspect() notified=notified+1 end
function ClearInspectPlayer() cleared=cleared+1 end
C_PaperDollInfo = { GetInspectItemLevel=function() return 512.5 end }
C_ScenarioInfo = { GetUnitCriteriaProgressValues=function() return 4, 1.25, "1.25%" end }
function reset() lines = {} end
''')

L.execute("XayaUI_NS = {}; CueRulesDB = {}")
# (Bonus 0.6.18 / Dev Assist 0.7.5, REQUEST-LOG #81: /xuitt is XayaUI Dev Assist's, XayaUI_DevAssist/CoreDebug.lua, loaded last as the game
# loads it)
for f in ("XayaUI/Modules.lua","XayaUI_Bonus/Tooltips.lua","XayaUI_Rules/AuraSources.lua","XayaUI_Bonus/TooltipsUI.lua","XayaUI_DevAssist/CoreDebug.lua"):   # 0.5.108: core contract + the embedded-aura reader now in core
    L.eval('function(src,n) return (load(src,n)) end')(open(os.path.join(ROOT, f)).read(), f)("XayaUI", L.eval("XayaUI_NS"))
# (Bonus 0.6.30 reads AuraSources / AuraModel through ns.Service; this test sets ns.AuraSources / ns.AuraModel directly, so the lookup answers with them)
L.execute('local real = XayaUI_NS.Service; XayaUI_NS.Service = function(n) if n == "AuraSources" then return XayaUI_NS.AuraSources elseif n == "AuraModel" then return XayaUI_NS.AuraModel end return real(n) end')
# AuraSources is core and always loaded in game; these checks test Tooltips alone, so keep only its embedded-aura reader (0.5.108)
L.execute("REAL_AS = XayaUI_NS.AuraSources; XayaUI_NS.AuraSources = { EmbeddedAuras = REAL_AS.EmbeddedAuras, NestedType = REAL_AS.NestedType }")
# Bonus 0.6.18: aura sources show only while XayaUI Dev Assist is loaded (core ns.DevAssistOn; Xaya 2026-11-06 "Tooltip, Dev Assist on");
# on here (tests/tooltip_aura_source_run.py checks it off)
L.execute("XayaUI_NS.DevAssistOn = function() return true end")
fails=0
def check(n,c):
    global fails
    print(("PASS " if c else "FAIL ")+n); fails += 0 if c else 1
def lines(): return list(L.eval("lines").values())
def run(code): L.execute("reset()"); L.execute(code); return lines()
# Bonus 0.6.13: each aura line ends with where it was found, grey (Xaya 2026-11-06: "say where each aura ID came from")
VIA = lambda *s: "  |cff999999via " + ", ".join(s) + "|r"
L.execute("XayaUI_NS.TT.DB(); XayaUI_NS.TT.Init()")
check("hooks registered for all kinds", L.eval("posts[0]~=nil and posts[1]~=nil and posts[2]~=nil and posts[7]~=nil and posts[23]~=nil"))
check("spell id line", run("posts[1](GameTooltip,{id=133})")==["Spell ID: 133"])
check("secret id skipped", run("secret[77]=true; posts[1](GameTooltip,{id=77})")==[])
check("quest off by default", run("posts[23](GameTooltip,{id=5})")==[])
L.execute("XayaUI_NS.TT.DB().ids.icon=true")
check("icon id on spell", run("posts[1](GameTooltip,{id=10})")==["Spell ID: 10","Icon ID: 1010"])
check("icon id on item", run("posts[0](GameTooltip,{id=3})")==["Item ID: 3","Icon ID: 2003"])
L.execute("XayaUI_NS.TT.DB().ids.icon=false")
L.execute("Enum.TooltipDataLineType = { NestedBlock = 19 }; C_Spell.GetSpellName=function(id) return id==9101 and 'Test Fed' or nil end")
nb = "{type=19, tooltipType=1, tooltipID=9101}"
check("item: embedded effect gives Aura ID with name", run("posts[0](GameTooltip,{id=3, lines={%s}})" % nb)==["Item ID: 3","Aura ID: 9101  (Test Fed)"+VIA("this tooltip")])
check("spell: embedded id equal to the spell itself not repeated", run("posts[1](GameTooltip,{id=9101, lines={%s}})" % nb)==["Spell ID: 9101"])
check("non-spell nested block ignored", run("posts[0](GameTooltip,{id=3, lines={{type=19, tooltipType=0, tooltipID=55}}})")==["Item ID: 3"])
check("secret nested id skipped", run("secret[9102]=true; posts[0](GameTooltip,{id=3, lines={{type=19, tooltipType=1, tooltipID=9102}}})")==["Item ID: 3"])
check("duplicate nested ids shown once", run("posts[0](GameTooltip,{id=3, lines={%s,%s}})" % (nb, nb))==["Item ID: 3","Aura ID: 9101  (Test Fed)"+VIA("this tooltip")])
L.execute("XayaUI_NS.TT.DB().ids.aura=false")
check("aura option off hides it", run("posts[0](GameTooltip,{id=3, lines={%s}})" % nb)==["Item ID: 3"])
L.execute("XayaUI_NS.TT.DB().ids.aura=true; XayaUI_NS.TT.DB().ids.icon=true")
check("aura icon id with icon option", run("posts[0](GameTooltip,{id=3, lines={%s}})" % nb)==["Item ID: 3","Icon ID: 2003","Aura ID: 9101  (Test Fed)"+VIA("this tooltip"),"Aura icon ID: 10101"])
L.execute("XayaUI_NS.TT.DB().ids.icon=false")
# spell -> aura lookup beyond the embedded block (Xaya: hovering Darkness 196718 showed no aura; its aura is 209426)
L.execute("C_Spell.GetSpellName=function(id) local n={[196718]='Darkness',[209426]='Darkness',[9101]='Test Fed',[555]='Quick Buff',[777]='Plain Strike'} return n[id] end; C_Spell.GetSpellDescription=function(id) if id==196718 then return 'Summons darkness. Lasts 8 sec.' end return 'Hits hard.' end")
check("spell with a duration and no known aura says so", run("posts[1](GameTooltip,{id=196718})")==["Spell ID: 196718","Aura ID: not known yet"])
check("spell without a duration says nothing", run("posts[1](GameTooltip,{id=777})")==["Spell ID: 777"])
check("item never says not known yet", run("posts[0](GameTooltip,{id=3})")==["Item ID: 3"])
L.execute("XayaUI_NS.TT.DB().ids.auraHint=false")
check("hint option off", run("posts[1](GameTooltip,{id=196718})")==["Spell ID: 196718"])
L.execute("XayaUI_NS.TT.DB().ids.auraHint=true")
L.execute("XayaUI_NS.AuraModel = { AurasForCast=function(id) if id==196718 then return { {id=209426, name='Darkness'} } end return {} end }")
check("learned cast link shows aura name and id", run("posts[1](GameTooltip,{id=196718})")==["Spell ID: 196718","Aura ID: 209426  (Darkness)"+VIA("your casts")])
L.execute("XayaUI_NS.AuraModel = nil")
L.execute("XayaUI_NS.AuraSources = { EmbeddedAuras = REAL_AS.EmbeddedAuras, NestedType = REAL_AS.NestedType, AurasOf=function(k,id) if k=='spell' and id==555 then return { {id=556, name='Quick Buff Aura'} } end return {} end }")
check("recorded source link shows aura", run("posts[1](GameTooltip,{id=555})")==["Spell ID: 555","Aura ID: 556  (Quick Buff Aura)"+VIA("recorded earlier")])
check("recorded source link works for items", (L.execute("XayaUI_NS.AuraSources.AurasOf=function(k,id) if k=='item' and id==3 then return { {id=557} } end return {} end") or True) and run("posts[0](GameTooltip,{id=3})")==["Item ID: 3","Aura ID: 557"+VIA("recorded earlier")])
L.execute("XayaUI_NS.AuraSources = { EmbeddedAuras = REAL_AS.EmbeddedAuras, NestedType = REAL_AS.NestedType, EmbeddedAuras = REAL_AS.EmbeddedAuras, NestedType = REAL_AS.NestedType }")
L.execute("noted=nil; XayaUI_NS.AuraSources = { EmbeddedAuras = REAL_AS.EmbeddedAuras, NestedType = REAL_AS.NestedType, Note=function(k,id,a) noted={k,id,a[1].id} end, AurasOf=function() return {} end }; C_UnitAuras = { GetAuraDataBySpellName=function(u,n,f) if u=='player' and n=='Darkness' and f=='HELPFUL' then return { spellId=209426 } end end }")
check("live buff with the same name gives the aura", run("posts[1](GameTooltip,{id=196718})")==["Spell ID: 196718","Aura ID: 209426  (Darkness)"+VIA("buff on you")])
check("live match is remembered for next time", L.eval("noted~=nil and noted[1]=='spell' and noted[2]==196718 and noted[3]==209426"))
L.execute("secret[209426]=true")
check("secret live aura id is skipped", run("posts[1](GameTooltip,{id=196718})")==["Spell ID: 196718","Aura ID: not known yet"])
L.execute("secret[209426]=nil; C_UnitAuras=nil; XayaUI_NS.AuraSources=nil")
# Bonus 0.6.1: a spell whose aura has the spell's OWN ID (Xaya: Immolation Aura 258920 said "not known yet" while the buff was on her)
L.execute("XayaUI_NS.AuraSources = { EmbeddedAuras = REAL_AS.EmbeddedAuras, NestedType = REAL_AS.NestedType }; C_Spell.GetSpellName=function(id) return 'Fire Ring' end; C_Spell.GetSpellDescription=function(id) return 'Burns for 9 sec.' end")
L.execute("C_UnitAuras = { GetPlayerAuraBySpellID=function(id) if id==258920 then return { spellId=258920 } end end }")
check("self-ID buff on you: aura line says same as the spell", run("posts[1](GameTooltip,{id=258920})")==["Spell ID: 258920","Aura ID: 258920  (same as the spell)"])
L.execute("C_UnitAuras = nil")
check("self-ID remembered after the buff ends", run("posts[1](GameTooltip,{id=258920})")==["Spell ID: 258920","Aura ID: 258920  (same as the spell)"])
check("self-ID remembered in saved data", L.eval("(XayaUI_NS.TT.DB().selfAura or {ids={}}).ids[258920]==true"))
check("other duration spell still not known", run("posts[1](GameTooltip,{id=258921})")==["Spell ID: 258921","Aura ID: not known yet"])
L.execute("XayaUI_NS.AuraModel = { AurasForCast=function() return {} end, CastAppliesSelf=function(id) return id==258922 end }")
check("self-ID from a recorded cast", run("posts[1](GameTooltip,{id=258922})")==["Spell ID: 258922","Aura ID: 258922  (same as the spell)"])
L.execute("XayaUI_NS.AuraModel = nil; C_UnitAuras = { GetAuraDataBySpellName=function(u,n,f) return { spellId=258923 } end }")
check("self-ID from the same-name read", run("posts[1](GameTooltip,{id=258923})")==["Spell ID: 258923","Aura ID: 258923  (same as the spell)"])
L.execute("C_UnitAuras = { GetPlayerAuraBySpellID=function(id) return 'S' end }; secret['S']=true")
check("secret aura answer is not proof", run("posts[1](GameTooltip,{id=258924})")==["Spell ID: 258924","Aura ID: not known yet"])
L.execute("C_UnitAuras = { GetPlayerAuraBySpellID=function(id) error('blocked') end }")
check("throwing aura API contained", run("posts[1](GameTooltip,{id=258925})")==["Spell ID: 258925","Aura ID: not known yet"])
L.execute("C_UnitAuras = { GetPlayerAuraBySpellID=function(id) return {} end }; XayaUI_NS.TT.DB().ids.aura=false")
check("aura option off hides the self-ID line", run("posts[1](GameTooltip,{id=258926})")==["Spell ID: 258926"])
L.execute("XayaUI_NS.TT.DB().ids.aura=true; C_UnitAuras=nil")
check("self-ID never shown on items", run("posts[0](GameTooltip,{id=258920})")==["Item ID: 258920"])

# Bonus 0.6.4: Cooldown Manager links. Modelled on the real rules: IN COMBAT every aura read gives no answer (GetPlayerAuraBySpellID is
# SecretWhenUnitAuraRestricted / RequiresNonSecretAura), the Cooldown Manager data still reads (no secret returns in its documentation).
L.execute("""
XayaUI_NS.AuraSources = { EmbeddedAuras = REAL_AS.EmbeddedAuras, NestedType = REAL_AS.NestedType }
XayaUI_NS.AuraModel = nil
C_Spell.GetSpellName = function(id) return ({ [203720] = 'Demon Spikes', [203819] = 'Demon Spikes', [300001] = 'Own Buff', [300002] = 'Big Hit',
  [300003] = 'Base', [300005] = 'Linked Buff' })[id] end
C_Spell.GetSpellDescription = function(id) return 'Lasts 12 sec.' end
C_UnitAuras = { GetPlayerAuraBySpellID = function() return nil end, GetAuraDataBySpellName = function() return nil end }   -- combat: no answers
inCombat = true
Enum.CooldownViewerCategory = { Essential = 0, Utility = 1, TrackedBuff = 2, TrackedBar = 3 }
cdmLoaded = false
cdmSets = { [0] = { 11, 13 }, [1] = {}, [2] = { 12, 14 }, [3] = { 15 } }
cdmInfo = {
  [11] = { spellID = 203720, linkedSpellIDs = { 203819 } },                                   -- Demon Spikes: linked aura
  [12] = { spellID = 300001, linkedSpellIDs = {} },                                           -- buff tracker, own ID
  [13] = { spellID = 300002, linkedSpellIDs = {} },                                           -- cooldown tracker, no aura known
  [14] = { spellID = 300003, overrideSpellID = 300004, linkedSpellIDs = {} },                 -- buff tracker with an override: ambiguous
  [15] = { spellID = 300006, overrideSpellID = 300007, linkedSpellIDs = { 300005, 777001 } },  -- linked aura, also under the override
}
C_CooldownViewer = {
  GetCooldownViewerCategorySet = function(cat, allow) if not cdmLoaded then return {} end return cdmSets[cat] or {} end,
  GetCooldownViewerCooldownInfo = function(id) return cdmInfo[id] end,
}
if XayaUI_NS.TT.ResetCooldownLinks then XayaUI_NS.TT.ResetCooldownLinks() end
""")
check("cdm: data not loaded yet -> not known, and the empty answer is not kept", run("posts[1](GameTooltip,{id=203720})")==["Spell ID: 203720","Aura ID: not known yet (auras are hidden in combat)"])
L.execute("cdmLoaded = true; secret[777001] = true")
check("cdm: Demon Spikes in combat -> its linked aura 203819", run("posts[1](GameTooltip,{id=203720})")==["Spell ID: 203720","Aura ID: 203819  (Demon Spikes)"+VIA("Cooldown Manager")])
check("cdm: buff tracker with no links -> same as the spell, in combat", run("posts[1](GameTooltip,{id=300001})")==["Spell ID: 300001","Aura ID: 300001  (same as the spell)"])
check("cdm: cooldown tracker with no links -> still not known (no guess)", run("posts[1](GameTooltip,{id=300002})")==["Spell ID: 300002","Aura ID: not known yet (auras are hidden in combat)"])
check("cdm: buff tracker with an override and no links -> no guess", run("posts[1](GameTooltip,{id=300003})")==["Spell ID: 300003","Aura ID: not known yet (auras are hidden in combat)"])
check("cdm: linked aura also found from the override spell; secret link skipped", run("posts[1](GameTooltip,{id=300007})")==["Spell ID: 300007","Aura ID: 300005  (Linked Buff)"+VIA("Cooldown Manager")])
L.execute("C_CooldownViewer.GetCooldownViewerCooldownInfo = function() error('blocked') end; if XayaUI_NS.TT.ResetCooldownLinks then XayaUI_NS.TT.ResetCooldownLinks() end")
check("cdm: a throwing API is contained", run("posts[1](GameTooltip,{id=300002})")==["Spell ID: 300002","Aura ID: not known yet (auras are hidden in combat)"])
L.execute("C_CooldownViewer.GetCooldownViewerCooldownInfo = function(id) return cdmInfo[id] end; if XayaUI_NS.TT.ResetCooldownLinks then XayaUI_NS.TT.ResetCooldownLinks() end; inCombat = false")
check("out of combat the hint has no combat note", run("posts[1](GameTooltip,{id=300002})")==["Spell ID: 300002","Aura ID: not known yet"])
# /xuitt aura report
L.execute("printed = {}; print = function(...) local t = {} for i = 1, select('#', ...) do t[#t+1] = tostring(select(i, ...)) end printed[#printed+1] = table.concat(t, ' ') end")
L.execute("C_AddOns = { GetAddOnMetadata = function(a, k) return '0.6.4' end }; inCombat = true; SlashCmdList.XUITT('aura 203720')")
rep = " | ".join(L.eval("printed").values())
check("/xuitt aura: version, combat, Cooldown Manager links, live read, result", "XayaUI Bonus 0.6.4" in rep and "in combat: yes" in rep and "linked auras {203819}" in rep
      and "no answer (hidden in combat)" in rep and "tooltip shows: 203819 Demon Spikes" in rep)
if "tooltip shows: 203819" not in rep: print("   report was:", rep)
L.execute("inCombat = false; C_CooldownViewer = nil; if XayaUI_NS.TT.ResetCooldownLinks then XayaUI_NS.TT.ResetCooldownLinks() end; C_UnitAuras = nil; XayaUI_NS.AuraSources = nil")

check("npc id (6th field)", "NPC ID: 12345" in run('isPlayer=false; canAttack=false; guid="Creature-0-1-2-3-12345-0000A"; posts[2](GameTooltip,{guid=guid})'))
check("player guid no npc", not any("NPC" in l for l in run('isPlayer=true; guid="Player-1-0000ABCD"; posts[2](GameTooltip,{guid=guid})')))
check("own ilvl equipped", "Item level: 480.2" in " ".join(run('isPlayer=true; GameTooltip.GetUnit=function() return "player","player" end; guid="Player-1-A"; posts[2](GameTooltip,{guid=guid})')) or "Item level: 480.3" in " ".join(lines()))
L.execute('GameTooltip.GetUnit=function() return "mouseover","mouseover" end; guid="Player-1-B"; now=200; notified=0; cleared=0')
r=run('posts[2](GameTooltip,{guid=guid})')
check("other: inspect requested, no line yet", L.eval("notified")==1 and L.eval("cleared")==1 and not any("Item level" in l for l in r))
L.execute('evh(nil,"INSPECT_READY","Player-1-B")')
check("inspect released", L.eval("cleared")==2)
check("cached ilvl shown", "Item level: 512.5" in run('posts[2](GameTooltip,{guid=guid})'))
check("foreign INSPECT_READY ignored", (L.execute('evh(nil,"INSPECT_READY","Player-9-Z")') or True) and L.eval("cleared")==2)
L.execute('inCombat=true; guid="Player-1-C"; now=500'); run('posts[2](GameTooltip,{guid=guid})')
check("no inspect in combat", L.eval("notified")==1)
L.execute('inCombat=false')
r=run('isPlayer=false; canAttack=true; guid="Creature-0-1-2-3-9-1"; posts[2](GameTooltip,{guid=guid})')
check("enemy forces line", "Enemy forces: 1.2% (4)" in r or "Enemy forces: 1.3% (4)" in r)
r=run('secret[1.25]=true; posts[2](GameTooltip,{guid=guid})')
check("secret forces skipped", not any("Enemy" in l for l in r))
L.execute('secret[1.25]=nil; XayaUI_NS.TT.DB().forces.enabled=false')
check("forces toggle off", not any("Enemy" in l for l in run('posts[2](GameTooltip,{guid=guid})')))
g=L.eval("XayaUI_NS.BuildTooltipsTab(function() end)")
check("options group built", g.args.ids is not None and g.args.ilvl is not None and g.args.forces is not None)
print("FAILS:",fails); sys.exit(1 if fails else 0)
