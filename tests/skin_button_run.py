# Checks ns.SkinPlainButton (Skin.lua) against stand-in frames: first 164 lines of Skin.lua are loaded (helpers + the function).
import lupa, os
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
L = lupa.LuaRuntime(unpack_returned_tuples=True)
src = open(os.path.join(ROOT, 'XayaUI_Options/Skin.lua'), encoding='utf-8').read().split('\n')
end_line = next(i for i, l in enumerate(src) if l.startswith('function ns.SkinPlainButton'))
while src[end_line] != 'end': end_line += 1
chunk = '\n'.join(src[:end_line + 1])
L.execute(r'''
function LibStub() return {} end
SlashCmdList = {}
CueRulesDB = {}
local function tex() local t = { a = 1, shown = true }
  function t:SetAlpha(a) self.a = a end function t:GetAlpha() return self.a end
  function t:GetObjectType() return "Texture" end
  function t:SetColorTexture(r,g,b,al) self.col = {r,g,b,al} end
  function t:ClearAllPoints() end function t:SetPoint() end function t:SetHeight() end function t:SetWidth() end
  function t:Show() self.shown = true end function t:Hide() self.shown = false end
  return t end
function newButton()
  local b = { regs = { tex(), tex() }, hooks = {} }
  local fs = { c = {} }
  function fs:SetTextColor(r,g,bb) self.c = {r,g,bb} end function fs:ClearAllPoints() end function fs:SetPoint() end
  b.fs = fs
  function b:GetRegions() return table.unpack(self.regs) end
  function b:CreateTexture() local t = tex(); self.created = (self.created or 0) + 1; return t end
  function b:GetFontString() return self.fs end
  b.ht = tex(); function b:GetHighlightTexture() return self.ht end
  function b:HookScript(n, f) self.hooks[n] = f end
  return b end
''')
L.eval('function(src, ns) return load(src, "XayaUI_Options/Skin.lua")("XayaUI", ns) end')(chunk, L.eval('(function() XayaUI_NS = {} return XayaUI_NS end)()'))
fails = 0
def check(n, c):
    global fails
    print(("PASS " if c else "FAIL ") + n); fails += 0 if c else 1
L.execute("ns = XayaUI_NS; b = newButton(); p = newButton()")
check("function exported", L.eval("type(ns.SkinPlainButton)") == "function")
L.execute("ns.SkinPlainButton(b, false)")
check("Blizzard art hidden", L.eval("b.regs[1].a == 0 and b.regs[2].a == 0"))
check("highlight art hidden", L.eval("b.ht.a == 0"))
check("flat background painted", L.eval("b.xuiFlat ~= nil and b.xuiFlat.bg.col ~= nil"))
check("text gold by default", L.eval("b.fs.c[1] == 1 and b.fs.c[2] == 0.82"))
L.execute("b.hooks.OnEnter(b)")
check("hover text white", L.eval("b.fs.c[1] == 1 and b.fs.c[2] == 1 and b.fs.c[3] == 1"))
L.execute("b.hooks.OnLeave(b)")
check("leave restores the button text color", L.eval("b.fs.c[2] == 0.82"))
L.execute("ns.SkinPlainButton(b, false); local n = b.created")
check("second call adds no new textures", L.eval("b.created") == 5)
L.execute("CueRulesDB.ui = { skinOff = true }; ns.SkinPlainButton(b, false)")
check("skin off restores the Blizzard art", L.eval("b.regs[1].a == 1 and b.ht.a == 1 and b.xuiFlat.bg.shown == false"))
L.execute("CueRulesDB.ui = nil; ns.SkinPlainButton(b, false)")
check("skin back on hides it again", L.eval("b.regs[1].a == 0 and b.xuiFlat.bg.shown == true"))
print("FAILS:", fails)
