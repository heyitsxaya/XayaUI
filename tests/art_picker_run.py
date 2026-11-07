"""#333 (core 0.6.15): the art picker offered 149 pictures that exist only on Xaya's machine, so every other player saw blank rows.
XayaUI/UserMedia.lua ns.AvailableLocalGraphics checks each folder of LocalGraphics.lua once per session (two samples through
Texture:SetTexture, which returns success: bool in the 12.1.5 docs) and the picker lists only folders the game can find.
Runs the real UserMedia.lua against a stand-in texture whose SetTexture fails for files that are "not installed".
Run: python3 tests/art_picker_run.py   (needs: pip install lupa)"""
import os, sys
from lupa.lua51 import LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
L = LuaRuntime(unpack_returned_tuples=True)
L.execute(r'''
INSTALLED = {}          -- folder -> true when its files exist on this machine
MODE = "bool"           -- "bool": SetTexture returns true / false; "nothing": returns nothing; "error": raises
CALLS = 0
local function dirOf(p) return (p:match("^(.*)\\[^\\]*$")) end
local function NewTexture()
  return { SetTexture = function(self, p)
    if p == nil then return true end
    CALLS = CALLS + 1
    if MODE == "error" then error("boom") end
    if MODE == "nothing" then return end
    return INSTALLED[dirOf(p)] == true
  end }
end
function CreateFrame() return { Hide = function() end, CreateTexture = function() return NewTexture() end, RegisterEvent = function() end, SetScript = function() end } end
C_AddOns = { IsAddOnLoaded = function() return false end }
local G = "Interface\\AddOns\\XayaUI\\Media\\Graphics\\"
NS = { LocalGraphics = {
  { "[Graphics] A1", G .. "A1.tga", 64, 64 }, { "[Graphics] A2", G .. "A2.tga", 64, 64 },
  { "[Bar Fills] B1", G .. "Bar_Fills\\B1.tga", 256, 64 }, { "[Bar Fills] B2", G .. "Bar_Fills\\B2.tga", 256, 64 }, { "[Bar Fills] B3", G .. "Bar_Fills\\B3.tga", 256, 64 },
} }
XayaUI_UserMedia = { graphics = { { "mine", "Pictures\\mine.tga", 64, 64 } }, sounds = {} }
''')
src = open(os.path.join(ROOT, "XayaUI", "UserMedia.lua"), encoding="utf-8").read()
L.eval("function(src) local f = assert(loadstring(src, '@UserMedia.lua')); f('XayaUI', NS) end")(src)

fails = []
def check(name, ok, extra=""):
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  [" + str(extra) + "]"))
    if not ok:
        fails.append(name)

LOAD = L.eval("function(src) local f = assert(loadstring(src, '@UserMedia.lua')); f('XayaUI', NS) end")
def fresh():
    # a new session: folder answers are kept for the whole session (new files need a game restart anyway), so reload the file
    L.execute("NS.LocalGraphics = { unpack(NS.LocalGraphics, 1, 5) }")
    LOAD(src)

def labels():
    L.execute("NS.ResetAvailableLocalGraphics()")
    return L.eval("(function() local t = {} for _, g in ipairs(NS.AvailableLocalGraphics()) do t[#t + 1] = g[1] end return table.concat(t, ',') end)()")

# a tester: neither of Xaya's folders is installed; their own XayaUI_Media picture is
L.execute("INSTALLED = {}; MODE = 'bool'")
got = labels()
check("tester: none of Xaya's pictures are offered (no blank rows)", "[Graphics]" not in got and "[Bar Fills]" not in got, got)
check("tester: their own XayaUI_Media picture is still offered (listed on purpose, never checked)", "[User] mine" in got, got)
check("the full list is untouched (rules that use a path keep it)", L.eval("#NS.LocalGraphics") == 6)
# Xaya: both folders installed
fresh()
L.execute("INSTALLED = { ['Interface\\\\AddOns\\\\XayaUI\\\\Media\\\\Graphics'] = true, ['Interface\\\\AddOns\\\\XayaUI\\\\Media\\\\Graphics\\\\Bar_Fills'] = true }")
got = labels()
check("Xaya: every picture is offered", got.count("[Graphics]") == 2 and got.count("[Bar Fills]") == 3, got)
# one folder installed
fresh()
L.execute("INSTALLED = { ['Interface\\\\AddOns\\\\XayaUI\\\\Media\\\\Graphics'] = true }")
got = labels()
check("only one folder installed: only its pictures", got.count("[Graphics]") == 2 and "[Bar Fills]" not in got, got)
# cost: two samples per folder at most, once per session
fresh()
L.execute("CALLS = 0; INSTALLED = {}; NS.ResetAvailableLocalGraphics()")
L.execute("NS.AvailableLocalGraphics(); NS.AvailableLocalGraphics()")
check("at most two files checked per folder, and only once per session", L.eval("CALLS") <= 4, L.eval("CALLS"))
# fail open: an older client that returns nothing, or an error, hides nothing
L.execute("INSTALLED = {}")
for mode in ("nothing", "error"):
    L.execute("MODE = '%s'" % mode)
    fresh()
    got = labels()
    check("SetTexture %s: nothing is hidden (never a guess)" % ("returns nothing" if mode == "nothing" else "errors"),
          got.count("[Graphics]") == 2 and got.count("[Bar Fills]") == 3, got)
# the picker uses the checked list
opt = open(os.path.join(ROOT, "XayaUI_Options", "RuleEditor", "Editor.lua"), encoding="utf-8").read()
check("the art picker reads ns.AvailableLocalGraphics", "ns.AvailableLocalGraphics()" in opt)

print("FAILS: %d" % len(fails))
sys.exit(1 if fails else 0)
