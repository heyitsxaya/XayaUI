#!/usr/bin/env python3
"""Offline test (Options 0.6.3, #257): the open / close button that Skin.lua draws at the left of a collapsible header (arg.xuiChevron),
the header row no longer reacting to the mouse (no red mouse-over glow, not a click target), the duplicate icon, and everything being put
back when AceGUI reuses the widget. Uses a real AceGUI Button in the stand-in game. Run: python3 tests/header_chevron_run.py"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok) R[#R + 1] = { name, ok and true or false } end
L.startup(); W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 5)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end
ns = rawget(_G, "XayaUI_NS")
check("skin loaded and on", ns and ns.DecorateTrees ~= nil and ns.SkinRows and ns.SkinRows())
local AceGUI = LibStub("AceGUI-3.0")
local root = AceGUI:Create("SimpleGroup")
local open, clicks = true, 0
local btn = AceGUI:Create("Button")
btn:SetUserData("option", { type = "execute", arg = { xuiLeft = true, xuiHeadOut = 20, xuiChevron = function() return open end,
  xuiActions = function() return { up = false, down = function() end, copy = function() end, del = function() end } end } })
btn:SetText("Trigger 1:  Buff / Aura")
btn:SetCallback("OnClick", function() clicks = clicks + 1; open = not open end)
root:AddChild(btn)
ns.DecorateTrees(root)
local f = btn.frame
local b = f.xuiChevBtn
check("an open / close button is drawn", b ~= nil and b:IsShown())
check("open: gold arrow art turned to point down (not the red minus)", b and tostring(b.tex:GetTexture()):find("ChatFrameExpandArrow") ~= nil and math.abs((b.tex._rot or 0) + math.pi / 2) < 1e-6)
check("it sits inside the row at the left (not in the cut-off margin)", (function() local p = b and b._pts and b._pts[1]; return p and p[1] == "LEFT" and (p[4] or 0) >= 0 end)())
check("the title starts to the right of the button", f.xuiTitleX and f.xuiTitleX >= 22)
check("the header row does not react to the mouse", f._mouse == false)
check("no mouse-over glow on the header row", f:GetHighlightTexture():GetAlpha() == 0)
b:GetScript("OnClick")(b)
check("clicking the button opens / closes the section (the header's own action runs)", clicks == 1 and open == false)
ns.DecorateTrees(root)
check("closed: the same arrow pointing right", tostring(b.tex:GetTexture()):find("ChatFrameExpandArrow") ~= nil and (b.tex._rot or 0) == 0)
local copy = f.xuiAct and f.xuiAct.copy
check("duplicate icon is drawn art (two squares), not the note texture", copy and copy.xuiCopyLines and #copy.xuiCopyLines == 8 and copy.tex:GetTexture() == nil)
-- a header without xuiChevron keeps behaving as before (clickable), only without the red glow
local plain = AceGUI:Create("Button")
plain:SetUserData("option", { type = "execute", arg = { xuiLeft = true } })
plain:SetText("Plain header")
root:AddChild(plain)
ns.DecorateTrees(root)
check("a header without the button stays clickable", plain.frame._mouse ~= false and not (plain.frame.xuiChevBtn and plain.frame.xuiChevBtn:IsShown()))
-- release: AceGUI reuses frames; the next user must get a normal button back
btn:Release()
check("released: button hidden, row takes the mouse again, glow restored", not b:IsShown() and f._mouse ~= false and f:GetHighlightTexture():GetAlpha() == 1 and f.xuiTitleX == nil)
local again = AceGUI:Create("Button")
check("reused widget is a normal button", again.frame._mouse ~= false and not (again.frame.xuiChevBtn and again.frame.xuiChevBtn:IsShown()))

-- ===== compact buttons (Xaya's standing rule): sized to the label, sharing a row, never stretched; headers stay full width =====
local box = AceGUI:Create("SimpleGroup"); box:SetLayout("Flow"); box:SetWidth(600)
local function btn(label, arg, full)
  local b2 = AceGUI:Create("Button"); b2:SetText(label)
  b2:SetUserData("option", { type = "execute", name = label, arg = arg })
  if full then b2:SetFullWidth(true) else b2:SetWidth(200) end
  box:AddChild(b2); return b2
end
local a1, a2, a3 = btn("+ New rule"), btn("Enable all", nil, true), btn("Disable all")
local hdr = btn("Section header", { xuiLeft = true }, true)
pcall(box.DoLayout, box)
ns.DecorateTrees(box); pcall(box.DoLayout, box)
local function wOf(x) return x.frame.width or x.frame:GetWidth() end
check("compact: a button is as wide as its label (not 200, not the row)", wOf(a1) < 150 and wOf(a1) >= 64, wOf(a1))
check("compact: a 'full width' button is compact too", wOf(a2) < 150 and a2.width ~= "fill", tostring(wOf(a2)) .. " " .. tostring(a2.width))
check("compact: the three buttons share one row", (function() local p = a2.frame._pts and a2.frame._pts[1]; return p and p[2] == a1.frame and p[3] == "TOPRIGHT" end)())
check("a section header (arg.xuiLeft) keeps its full width", hdr.width == "fill")
-- ===== collapsible heading (Size & Orientation etc.): open / close button at the LEFT, not a red +/- at the right (0.6.4) =====
local open2 = true
local hd = AceGUI:Create("Heading")
hd:SetUserData("option", { type = "header", arg = { xuiCollapse = true, xuiCollapsed = function() return not open2 end, xuiToggle = function() open2 = not open2 end } })
hd:SetText("Size & Orientation")
root:AddChild(hd)
ns.DecorateTrees(root)
local hb = hd.xuiCollBtn
check("heading: open / close button exists", hb ~= nil and hb:IsShown())
check("heading: button at the LEFT of the row", (function() local p = hb and hb._pts and hb._pts[1]; return p and p[1] == "LEFT" end)())
check("heading: no red +/- texture (gold arrow art)", hb and tostring(hb.tex:GetTexture()):find("ChatFrameExpandArrow") ~= nil and not tostring(hb:GetNormalTexture() and hb:GetNormalTexture():GetTexture() or ""):find("PlusButton"))
check("heading: title moved right of the button", (function() local p = hd.label._pts and hd.label._pts[1]; return p and (p[4] or 0) >= 20 end)())
hb:GetScript("OnClick")(hb)
check("heading: clicking toggles the section", open2 == false)
-- ===== sidebar search box vs scrollbar (#14): the bar starts below the box =====
local tree = AceGUI:Create("TreeGroup")
local rows = { { value = "loaded", text = "LOADED" } }
for i = 1, 60 do rows[#rows + 1] = { value = "r" .. i, text = "Rule " .. i } end
tree:SetTree(rows)
tree:SetFullHeight(true)
local holder = AceGUI:Create("SimpleGroup"); holder:SetHeight(300); holder:AddChild(tree)
tree.frame:SetHeight(300); tree.treeframe:SetHeight(300)
pcall(tree.RefreshTree, tree)
ns.DecorateTrees(holder)
local sbar = tree.scrollbar
local p1 = sbar and sbar._pts and sbar._pts[1]
check("search box drawn above the rule list", tree.xuiSearchBox ~= nil)
check("scrollbar starts below the search box (top at 58 px, not AceGUI's 26)", p1 and p1[1] == "TOPRIGHT" and (p1[5] or 0) <= -58, p1 and tostring(p1[5]))
tree:Release()
local p2 = sbar._pts and sbar._pts[1]
check("released tree gets AceGUI's own scrollbar anchor back", p2 and (p2[5] or 0) == -26, p2 and tostring(p2[5]))
return R
end
'''


def main():
    folders = H.find_addons()
    enabled = ["XayaUI", "XayaUI_Media", "XayaUI_Options"]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), H.to_lua(L, {}))
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    bad = 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        if not ok:
            bad += 1
            print("FAIL:", name)
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
