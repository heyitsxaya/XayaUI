# Maintain aspect ratio (art) - #313. Runs the real code blocks from Visual.lua (ArtNativeRatio) and Options.lua
# (ResetArtAspect / KeepArtAspect / ArtAspectSet) under Lua 5.1 with small stubs.
import re, sys, os
import lupa.lua51 as l

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
vis = open(os.path.join(ROOT, "Visual.lua")).read()
opt = open(os.path.join(ROOT, "Options.lua")).read()
vblock = vis[vis.index("local function GraphicSize"):vis.index("\nend\n", vis.index("function ns.ArtNativeRatio")) + 5]
oblock = opt[opt.index("local artSeen"):opt.index("\nend\n", opt.index("function ns.ArtAspectSet")) + 5]

L = l.LuaRuntime()
L.execute("""
ns = {}
function ns.Val(v) if v == nil or v == "" or v == "none" then return nil end return v end
ns.LocalGraphics = { { "[Graphics] Wide", "Interface\\\\AddOns\\\\XayaUI\\\\Media\\\\Graphics\\\\Wide.tga", 256, 128 },
                     { "[User icon] Tall", "Interface\\\\AddOns\\\\XayaUI_Media\\\\Icons\\\\tall.tga", 64, 128 } }
C_Texture = { GetAtlasInfo = function(n) if n == "bar-atlas" then return { width = 300, height = 60 } end end }
""")
L.execute("local ns = ns\n" + vblock + "\n" + oblock)
ns = L.globals().ns
fails = []
def check(name, got, want):
    ok = got == want
    print(("PASS " if ok else "FAIL ") + name + ": " + repr(got) + ("" if ok else "  want " + repr(want)))
    if not ok: fails.append(name)
def V(**kw):
    t = L.table()
    for k, v in kw.items(): t[k] = v
    return t
def size(v): return (v["iconW"], v["iconH"])
noop = L.eval("function() end")

# native ratios
check("spell icon ratio", ns.ArtNativeRatio(V(kind="spellicon")), 1)
check("user icon file ratio", ns.ArtNativeRatio(V(kind="spellicon", iconSrc="file", iconPath="Interface/AddOns/XayaUI_Media/Icons/tall.tga")), 0.5)
check("local graphic ratio", ns.ArtNativeRatio(V(kind="file", tex="Interface\\AddOns\\XayaUI\\Media\\Graphics\\Wide.tga")), 2)
check("atlas ratio", ns.ArtNativeRatio(V(kind="atlas", tex="bar-atlas")), 5)
check("file ID unknown", ns.ArtNativeRatio(V(kind="file", tex="449486")), None)

# 1. toggle on resets a stretched spell icon to square, keeping its width; the display box is untouched
v = V(kind="spellicon", w=94, h=128, iconW=94, iconH=40, keepAspect=True)
check("reset returns true", ns.ResetArtAspect(v), True)
check("icon reset to square", size(v), (94, 94))
check("display box untouched", (v["w"], v["h"]), (94, 128))

# 2. art following a display of another shape gets explicit, native-shaped size (display crops it)
v = V(kind="file", tex="Interface\\AddOns\\XayaUI\\Media\\Graphics\\Wide.tga", w=128, h=128, iconW=0, iconH=0)
ns.ResetArtAspect(v)
check("wide art in square box", size(v), (128, 64))
v = V(kind="file", tex="Interface\\AddOns\\XayaUI\\Media\\Graphics\\Wide.tga", w=256, h=128, iconW=0, iconH=0)
ns.ResetArtAspect(v)
check("display already art-shaped: stays following", size(v), (0, 0))

# 3. caps at 512
v = V(kind="atlas", tex="bar-atlas", w=128, h=128, iconW=10, iconH=0)
ns.ResetArtAspect(v); check("thin atlas keeps width", size(v), (10, 2))
v = V(kind="spellicon", iconSrc="file", iconPath="Interface\\AddOns\\XayaUI_Media\\Icons\\tall.tga", w=128, h=128, iconW=400, iconH=0)
ns.ResetArtAspect(v); check("tall art capped at 512", size(v), (256, 512))

# 4. unknown size: nothing changes
v = V(kind="file", tex="449486", w=128, h=64, iconW=0, iconH=0)
check("unknown returns false", ns.ResetArtAspect(v), False)
check("unknown unchanged", size(v), (0, 0))

# 5. linked art sliders at native ratio, not the current one
v = V(kind="file", tex="Interface\\AddOns\\XayaUI\\Media\\Graphics\\Wide.tga", w=128, h=128, iconW=100, iconH=100, keepAspect=True)
ns.ArtAspectSet(v, "iconW", noop)(None, 200); check("width slider -> native height", size(v), (200, 100))
ns.ArtAspectSet(v, "iconH", noop)(None, 30); check("height slider -> native width", size(v), (60, 30))
ns.ArtAspectSet(v, "iconW", noop)(None, 0); check("0 follows display on both axes", size(v), (0, 0))
v["keepAspect"] = False; v["iconW"], v["iconH"] = 50, 50
ns.ArtAspectSet(v, "iconW", noop)(None, 80); check("off: independent", size(v), (80, 50))
# unknown art: linked at its current proportions
v = V(kind="file", tex="449486", w=128, h=64, iconW=0, iconH=0, keepAspect=True)
ns.ArtAspectSet(v, "iconW", noop)(None, 64); check("unknown art linked at current shape", size(v), (64, 32))

# 6. swapping art while on snaps it; the first look only records; off does nothing
v = V(kind="spellicon", w=128, h=64, iconW=128, iconH=64, keepAspect=True)
ns.SeedArtAspect(v)
ns.KeepArtAspect(v); check("no swap, no change", size(v), (128, 64))
v["kind"], v["tex"] = "file", "Interface\\AddOns\\XayaUI\\Media\\Graphics\\Wide.tga"
ns.KeepArtAspect(v); check("swap while on keeps 2:1 here", size(v), (128, 64))
v["tex"] = "bar-atlas"; v["kind"] = "atlas"
ns.KeepArtAspect(v); check("swap to 5:1 atlas", size(v), (128, 26))
v["keepAspect"] = False; v["kind"] = "spellicon"
ns.KeepArtAspect(v); check("swap while off: untouched", size(v), (128, 26))
w = V(kind="spellicon", w=94, h=128, iconW=94, iconH=40, keepAspect=True)
ns.KeepArtAspect(w); check("existing display never mutated on first look", size(w), (94, 40))

print("\n%d failed" % len(fails) if fails else "\nall passed")
sys.exit(1 if fails else 0)
