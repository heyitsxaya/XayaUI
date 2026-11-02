import lupa, sys, os
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
from lupa import LuaRuntime
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
function CreateFrame() return { RegisterEvent=function() end, SetScript=function(s,n,f) _G.evh=f end } end
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
for f in ("Tooltips.lua","TooltipsUI.lua"):
    L.eval('function(src,n) return load(src,n) end')(open(os.path.join(ROOT, f)).read(), f)("XayaUI", L.eval("XayaUI_NS"))
fails=0
def check(n,c):
    global fails
    print(("PASS " if c else "FAIL ")+n); fails += 0 if c else 1
def lines(): return list(L.eval("lines").values())
def run(code): L.execute("reset()"); L.execute(code); return lines()
L.execute("XayaUI_NS.TT.DB(); XayaUI_NS.TT.Init()")
check("hooks registered for all kinds", L.eval("posts[0]~=nil and posts[1]~=nil and posts[2]~=nil and posts[7]~=nil and posts[23]~=nil"))
check("spell id line", run("posts[1](GameTooltip,{id=133})")==["Spell ID: 133"])
check("secret id skipped", run("secret[77]=true; posts[1](GameTooltip,{id=77})")==[])
check("quest off by default", run("posts[23](GameTooltip,{id=5})")==[])
L.execute("XayaUI_NS.TT.DB().ids.icon=true")
check("icon id on spell", run("posts[1](GameTooltip,{id=10})")==["Spell ID: 10","Icon ID: 1010"])
check("icon id on item", run("posts[0](GameTooltip,{id=3})")==["Item ID: 3","Icon ID: 2003"])
L.execute("XayaUI_NS.TT.DB().ids.icon=false")
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
