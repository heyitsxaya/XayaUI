import os
import sys as _sys
_sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lua51 as lupa   # Lua 5.1, like the game (tests/lua51.py)
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
L = lupa.runtime(unpack_returned_tuples=True)
L.execute(r'''
secret = {}
function issecretvalue(v) return secret[v] == true end
clock = 0
function debugprofilestop() clock = clock + 0.5; return clock end   -- every call "costs" 0.5 ms
build = "99999"
function GetBuildInfo() return "12.0.0", build, "x", 120000 end
inCombat = false
function InCombatLockdown() return inCombat end
Enum = { TooltipDataType = { Spell = 1, Item = 0 }, TooltipDataLineType = { NestedBlock = 19 } }
names = { [1] = "Sword", [2] = "Roast", [3] = "Roast B", [100] = "Spell A", [9101] = "Fed" }
C_Item = { GetItemNameByID = function(id) return names[id] end }
C_Spell = { GetSpellName = function(id) return names[id] end }
tips = { item = {}, spell = {} }
C_TooltipInfo = { GetItemByID = function(id) return tips.item[id] end, GetSpellByID = function(id) return tips.spell[id] end }
frameFn = nil
function CreateFrame() return { SetScript = function(s, n, f) frameFn = f end } end
XayaUI_NS = {}
CueRulesDB = {}
''')
def load(f):
    L.eval('function(src,n) return (load(src,n)) end')(open(os.path.join(ROOT, f)).read(), f)("XayaUI", L.eval("XayaUI_NS"))
load("XayaUI_Bonus/Tooltips.lua"); load("XayaUI/AuraSources.lua")
fails = 0
def check(n, c):
    global fails
    print(("PASS " if c else "FAIL ") + n); fails += 0 if c else 1
nb = lambda i: "{type=19, tooltipType=1, tooltipID=%d}" % i
L.execute("AS = XayaUI_NS.AuraSources")
check("no source yet", L.eval("AS.Get(9101)") is None)
L.execute("AS.Note('item', 2, {{id=9101}})")
check("label has kind, name and id", L.eval("AS.Label(9101)") == "item Roast [2]")
L.execute("AS.Note('item', 2, {{id=9101}})")
check("same source twice stays one", L.eval("#AS.Get(9101)") == 1)
L.execute("AS.Note('item', 3, {{id=9101}})")
check("second source shows +1 more", L.eval("AS.Label(9101)") == "item Roast [2] +1 more")
L.execute("AS.Note('item', 4, {{id=9101}}); AS.Note('item', 5, {{id=9101}})")
check("capped at 3, flagged as more", L.eval("#AS.Get(9101)") == 3 and L.eval("AS.Get(9101).more") is True)
check("capped label", L.eval("AS.Label(9101)") == "item Roast [2] +2+ more")
L.execute("AS.Note('spell', 100, {{id=100}})")
check("a spell is not its own source", L.eval("AS.Get(100)") is None)
L.execute("build = '100000'")
check("new game build drops the saved map", L.eval("AS.Get(9101)") is None)
# scan: spells first, then the item index
L.execute("tips.spell[100] = {lines={%s}}; tips.item[1] = {lines={%s}}; tips.item[3] = {lines={{type=19,tooltipType=0,tooltipID=5}}}" % (nb(9101), nb(9101)))
L.execute("idx = { ids={1,2,3}, n=3, running=false, nextId=300001, max=300000 }")
L.execute("AS.Start(idx, {100})")
check("scan running", L.eval("AS.state.running") is True)
check("progress known while running", L.eval("AS.Progress()") is not None)
L.execute("for i=1,10 do if frameFn then frameFn({SetScript=function() frameFn=nil end}) end end")
check("scan finished", L.eval("AS.state.running") is False)
check("spell source found", L.eval("AS.Get(9101)[1].k") == "spell" and L.eval("AS.Get(9101)[1].id") == 100)
check("item source found", L.eval("#AS.Get(9101)") == 2 and L.eval("AS.Get(9101)[2].id") == 1)
check("non-spell block ignored", L.eval("AS.Get(5)") is None)
check("marked done for this build", L.eval("CueRulesDB.auraSources.done") is True)
check("progress nil when done", L.eval("AS.Progress()") is None)
# an incomplete index must not finish the pass
L.execute("build = '100001'; idx = { ids={1}, n=1, running=false, nextId=50, max=300000 }; frameFn=nil; AS.state.finished=nil; AS.state.stage=1; AS.state.pos=1")
L.execute("AS.Start(idx, {})")
L.execute("for i=1,10 do if frameFn then frameFn({SetScript=function() frameFn=nil end}) end end")
check("pass waits while the item index is incomplete", L.eval("AS.state.running") is True and L.eval("CueRulesDB.auraSources.done") is False)
L.execute("inCombat = true; local p = AS.state.pos; before = p; frameFn({SetScript=function() end})")
check("paused in combat", L.eval("AS.state.pos") == L.eval("before"))
L.execute("secret[9101]=true; tips.item[2] = {lines={{type=19,tooltipType=1,tooltipID=9101}}}")
check("secret aura id skipped by scan", L.eval("XayaUI_NS.TT.EmbeddedAuras({lines={{type=19,tooltipType=1,tooltipID=9101}}})[1]") is None)
print("FAILS:", fails)
