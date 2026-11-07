"""#336 (Options 0.6.13): art picker rows. The preview's width followed each picture's proportions (8 to 112 px), so the text started
at a different place in every row. Every preview now sits in one fixed column, two icons wide, padded with a transparent image.
Runs the real PickRow (XayaUI_Options/RuleEditor/Editor.lua; Options.lua until P3) and the closed box's `small` (Skin.lua), and checks the spacer file.
Run: python3 tests/art_rows_run.py   (needs: pip install lupa)"""
import os, re, struct, sys
from lupa.lua51 import LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
opt = open(os.path.join(ROOT, "XayaUI_Options", "RuleEditor", "Editor.lua"), encoding="utf-8").read()
skin = open(os.path.join(ROOT, "XayaUI_Options", "Skin.lua"), encoding="utf-8").read()
fails = []
def check(name, ok, extra=""):
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  [" + str(extra) + "]"))
    if not ok:
        fails.append(name)

m = re.search(r"^ns\.TEX_PICK_SPACER = .*?^ns\.TexPickRow = PickRow\n", opt, re.S | re.M)
check("Options.lua builds rows with PickRow", m is not None)
if m:
    L = LuaRuntime(unpack_returned_tuples=True)
    L.execute("ns = { TEX_PICK_ICON = 56 }\n" + m.group(0))
    def advance(row):   # total width of the inline pictures before the label, and the label
        ws = [int(x) for x in re.findall(r"\|T[^|]*:\d+:(\d+)\|t", row)]
        label = re.sub(r"\|T[^|]*\|t", "", row)
        return sum(ws), label
    starts = set()
    for w in (8, 28, 56, 57, 111, 112):
        row = L.eval("ns.TexPickRow('Interface\\\\AddOns\\\\XayaUI\\\\Media\\\\Graphics\\\\X.tga', %d, 'Name %d')" % (w, w))
        adv, label = advance(row)
        starts.add(adv)
        check("picture %d px wide: the label starts after the same %d px column" % (w, 112), adv == 112, (adv, row))
        check("picture %d px wide: drawn at its own width, label intact" % w, ("X.tga:56:%d|t" % w) in row and label.strip() == "Name %d" % w, row)
    check("every row's text starts at the same place", len(starts) == 1, starts)
    row = L.eval("ns.TexPickRow(136243, 56, 'Game art')")
    check("the game's own art (a file ID) gets the same column", advance(row)[0] == 112 and "|T136243:56:56|t" in row, row)

# the closed box: small icon, no padding
sm = re.search(r"local function small\(s\)\n.*?\n                end\n", skin, re.S)
check("Skin.lua's closed box helper found", sm is not None)
if sm:
    L2 = LuaRuntime(unpack_returned_tuples=True)
    L2.execute(sm.group(0).replace("local function small", "function small", 1))
    row = "|TInterface\\AddOns\\XayaUI\\Media\\UI\\xui_blank.tga:56:28|t|TInterface\\AddOns\\XayaUI\\Media\\Graphics\\X.tga:56:56|t|TInterface\\AddOns\\XayaUI\\Media\\UI\\xui_blank.tga:56:28|t  Name"
    out = L2.eval("small(...)", row) if False else L2.globals().small(row)
    check("closed box: the padding is dropped and the picture is small", "xui_blank" not in out and "X.tga:22:22|t" in out, out)

# the spacer file
p = os.path.join(ROOT, "XayaUI", "Media", "UI", "xui_blank.tga")
ok = os.path.exists(p)
check("XayaUI/Media/UI/xui_blank.tga exists", ok)
if ok:
    d = open(p, "rb").read()
    w, h = struct.unpack("<HH", d[12:16])
    bpp, kind = d[16], d[2]
    pixels = d[18:18 + w * h * 4]
    check("spacer: uncompressed 32-bit TGA, power-of-two size", kind == 2 and bpp == 32 and w & (w - 1) == 0 and h & (h - 1) == 0, (kind, bpp, w, h))
    check("spacer: every pixel fully transparent", len(pixels) == w * h * 4 and all(pixels[i + 3] == 0 for i in range(0, len(pixels), 4)))

print("FAILS: %d" % len(fails))
sys.exit(1 if fails else 0)
