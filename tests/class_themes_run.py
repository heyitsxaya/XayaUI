#!/usr/bin/env python3
"""Class themes v2 (XayaUI 0.6.86, Options 0.6.109): each listed class gets its own colours and parent-group glow under the "class" base
(Theme.lua T.CLASS_THEMES). Xaya confirmed each one on the design canvas "XayaUI Addon Mockups" (boards "Class themes v2" and "Glow
gradients") and decided on 2026-11-13 that the glows keep their exact stop positions ("Exact positions"), so gradients gained an
optional per-stop position list (pos).
Loads the real addons in the stand-in game (Lua 5.1 via lupa); the player is a Demon Hunter there.
  A Lookup: for each of the thirteen classes, T.ClassPalette has the brief's colours (hex / 255; tabSelBg alpha 0.9, primaryBg 0.95,
    everything else 1) and T.ClassGrads(file).gradStart the brief's "Glow as designed" stops and positions. The expected values below
    are typed from the handoffs, not read from Theme.lua: the coding brief (eleven classes) as updated by the design session's full
    approved list of 2026-11-13 (Druid, Monk and Shaman glows resmoothed, Druid rule name #590E00, Mage and Warlock confirmed).
  B Fallback: a class without an entry (a new class, or Mage with its entry taken out for the test) gets exactly the derived palette
    (class colour times the fixed multipliers) and no gradient; T.ClassTheme answers nil.
  C Resolve: "class" follows the played class (Demon Hunter) and a hand-picked one (Priest, Warlock); its glow is T.curGrad.gradStart
    with its positions; a class without an entry has none; a Custom theme started from Class colors keeps the glow; your own solid "Parent group glow" replaces it;
    a saved class theme with a picked class brings that class's glow (T.SavedGrads).
  D Share strings: the export of "Class colors" (played and picked Mage) is byte-for-byte the string made before gradients existed
    (the same strings tests/theme_gradient_borders_run.py checks); an own gradient with positions survives export and import; a pos
    that does not fit (wrong length, going back, above 1) is dropped and the gradient drawn evenly spaced.
  E Drawing: T.PaintLine with positions lays out the pieces at the stops' places, the first colour held before the first place and
    the last after the last one; without positions the pieces are of equal length, as before; Reverse leaves a class glow alone
    (Xaya 2026-11-13) but still turns a gradient of your own round.
  F The parent group glow (TreePaint): a Demon Hunter's glow is drawn across the row as its stops at the banner's 0.95; a Mage's is
    a class without an entry draws the glow colour to black on one texture, as before, and the earlier glow's pieces are hidden.
Run: python3 tests/class_themes_run.py"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

PAL_KEYS = ["accent", "accentText", "label", "buttonText", "tabSelBg", "tabSelBorder", "primaryBg", "primaryBorder", "border"]
# class: (accent, accentText, label/buttonText, tabSelBg, tabSelBorder, primaryBg, primaryBorder, border), glow "hex pos%" list
BRIEF = {
    "PRIEST": ("C7C2C8 D7D2D8 D8D2B1 2A242A A487A5 393339 B79AB4 403B40",
               "FFFFFF 0,FBFAF7 10,E5DFC7 22,D0C498 34,C7B19C 48,BE9D9F 62,B494A7 78,A498B9 100"),
    "WARRIOR": ("C6A27B EFCEAA DDD1A5 362107 D67066 542620 EB8375 3D3E39",
                "C69B6D 0,C69B6D 6,A68565 24,9A7D60 32,767C77 52,5F7F91 58,61A1BD 76,7FD5F8 100"),
    "EVOKER": ("5FA997 A2E4D3 8BA5E0 062D26 40A690 0D3E34 5DB7A9 2F423C",
               "33937F 0,33937F 6,06332A 22,0E2A2B 38,13222B 54,201923 70,2F0D15 86,2F0D15 100"),
    "DRUID": ("E6803A FBC8AB E7CDAA 3B1D0B CF7940 522912 E18D5D 473A30",
              "FF7C0A 0,FF7C0A 6,E87E42 24,E47F51 40,CB8689 53,B289B6 66,6884D1 83,537BE8 100"),
    "DEMONHUNTER": ("C27FDD E7C7F4 DCC8ED 311D38 B178C7 43294D C58ADB 433948",
                    "A330C9 0,A330C9 6,70369A 20,594085 34,4C4C7A 48,245B67 62,608D66 78,9CDC24 100"),
    "DEATHKNIGHT": ("DF5F69 FFC3C2 E7CDAA 351315 D66F71 542526 EB8184 4C3737",
                    "C41E3A 0,C41E3A 10,601A21 24,352031 40,292C5B 56,305597 72,A4E1FF 86,A4E1FF 100"),
    "SHAMAN": ("5899F3 B8DBE6 DAD3A6 012A3D 3BA0BC 492746 D686BC 2D404A",
               "0070DD 0,0070DD 10,2168BD 24,415E9A 37,65537B 51,7E4D57 65,94422F 78,844C3E 92"),
    "MONK": ("66E19A A9E4CA D5D59B 022F1D 39A979 114024 5ABC7E 49392D",
             "00FF98 0,00FF98 10,00ED9D 25,00D4A1 40,34B58D 55,7AAB61 70,B2A341 85,D29B2F 100"),
    "PALADIN": ("DD8AAE FAC2D8 D9D3A6 3C1D0E D3764A 453200 CA9D33 4C3734",
                "F48CBA 0,F48CBA 14,CF7496 30,CF7496 44,D99682 58,E3B564 72,EBCE90 86,F3E6BC 100"),
    "ROGUE": ("CDCA5A D8D7B1 BFD8C8 202731 6497C7 55251B B3A659 344134",
              "CBC256 0,CBC256 12,ACAA4D 25,707C3B 37,304B26 50,0F341C 64,24303D 84,2F2543 100"),
    "HUNTER": ("A9CC7B C7DEAC DED1A9 212A14 7F9F52 2D3B1B 92B16C 394032",
               "AAD372 0,AAD372 20,9AC067 33,76934D 46,516633 58,313E1B 71,252F12 84,292807 100"),
    "MAGE": ("5ED6F6 A0E0F3 BED4EB 06293E 359BD9 003C4B 00B7DA 3D3B4C",
             "3FC7EB 0,3FC7EB 4,85BFEB 25,D3AEED 62,EA8F49 90,EA8F49 100"),
    "WARLOCK": ("979AF1 CCD0FF D4CAF5 28213E 8D8EBE 402A50 A695EF 49383C",
                "8788EE 0,8788EE 2,7879D4 17,6262AC 31,484780 46,2C3252 61,09302B 75,05270D 90"),
}
ALPHA = {"tabSelBg": 0.9, "primaryBg": 0.95}


def hexcol(h, a=1.0):
    return [int(h[0:2], 16) / 255, int(h[2:4], 16) / 255, int(h[4:6], 16) / 255, a]


def expected():
    out = {}
    for cls, (pal, glow) in BRIEF.items():
        hx = pal.split()
        vals = [hx[0], hx[1], hx[2], hx[2], hx[3], hx[4], hx[5], hx[6], hx[7]]
        p = {k: hexcol(v, ALPHA.get(k, 1.0)) for k, v in zip(PAL_KEYS, vals)}
        stops, pos = [], []
        for s in glow.split(","):
            h, pc = s.split()
            stops.append(hexcol(h))
            pos.append(int(pc) / 100)
        out[cls] = {"pal": p, "stops": stops, "pos": pos}
    return out


LUA = r'''
return function(W, L, EXP, OLD)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local function near(a, b) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < 1e-6 end
local function sameCol(a, b) return type(a) == "table" and type(b) == "table" and near(a[1], b[1]) and near(a[2], b[2]) and near(a[3], b[3]) and near(a[4] or 1, b[4] or 1) end
local function fmt(c) if type(c) ~= "table" then return tostring(c) end return string.format("%.4f,%.4f,%.4f,%.3f", c[1] or -1, c[2] or -1, c[3] or -1, c[4] or 1) end
local function sameList(a, b) if type(a) ~= "table" or type(b) ~= "table" or #a ~= #b then return false end for i = 1, #a do if not near(a[i], b[i]) then return false end end return true end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
local T = ns.Theme

-- A lookup
local n = 0
for cls, e in pairs(EXP) do
  n = n + 1
  local pal = T.ClassPalette(cls)
  local bad = {}
  for k, c in pairs(e.pal) do if not sameCol(pal[k], c) then bad[#bad + 1] = k .. " " .. fmt(pal[k]) .. " want " .. fmt(c) end end
  check("A " .. cls .. ": palette is the brief's (9 colours)", #bad == 0, table.concat(bad, "; "))
  local g = T.ClassGrads(cls).gradStart
  local okStops = g and #g.stops == #e.stops
  if okStops then for i = 1, #e.stops do if not sameCol(g.stops[i], e.stops[i]) then okStops = false end end end
  check("A " .. cls .. ": glow stops are the brief's", okStops, g and fmt(g.stops[1]) or "no gradient")
  check("A " .. cls .. ": glow positions are the brief's", g and sameList(g.pos, e.pos), g and g.pos and table.concat(g.pos, ",") or "no pos")
end
check("A all thirteen classes checked", n == 13, n)
local listed = 0; for _ in pairs(T.CLASS_THEMES) do listed = listed + 1 end
check("A T.CLASS_THEMES lists exactly the thirteen", listed == 13, listed)

-- B fallback: the derived palette, worked out here from the class colour
local function derived(file)
  local c = T.ClassColor(file)
  local function mix(a, b, t) return { a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, a[4] or 1 } end
  local w = { 1, 1, 1, 1 }
  return { accent = { c[1], c[2], c[3], 1 }, accentText = mix(c, w, 0.35), gradStart = { c[1] * 0.4, c[2] * 0.4, c[3] * 0.4, 1 },
    label = mix(c, w, 0.25), buttonText = mix(c, w, 0.25), tabSelBg = { c[1] * 0.28, c[2] * 0.28, c[3] * 0.28, 0.9 },
    tabSelBorder = { c[1], c[2], c[3], 1 }, primaryBg = { c[1] * 0.45, c[2] * 0.45, c[3] * 0.45, 0.95 },
    primaryBorder = { c[1] * 0.85, c[2] * 0.85, c[3] * 0.85, 1 }, buttonBorder = mix({ 0.25, 0.25, 0.25, 1 }, c, 0.25),
    border = mix({ 0.30, 0.30, 0.30, 1 }, c, 0.15) }
end
-- every class has an entry now: a class the table does not list (a new class, or an entry taken out) is shown by taking Mage's out
local MAGE_ENTRY = T.CLASS_THEMES.MAGE
T.CLASS_THEMES.MAGE = nil
for _, cls in ipairs({ "MAGE", "NEWCLASS" }) do
  RAID_CLASS_COLORS[cls] = cls == "MAGE" and { r = 0.247, g = 0.78, b = 0.922 } or { r = 0.529, g = 0.533, b = 0.933 }
  local pal, want, bad, cnt = T.ClassPalette(cls), derived(cls), {}, 0
  for k in pairs(pal) do cnt = cnt + 1 end
  for k, c in pairs(want) do if not sameCol(pal[k], c) then bad[#bad + 1] = k end end
  check("B " .. cls .. ": the derived palette, unchanged (11 colours)", #bad == 0 and cnt == 11, table.concat(bad, ",") .. " n=" .. cnt)
  check("B " .. cls .. ": no class theme, no gradient", T.ClassTheme(cls) == nil and next(T.ClassGrads(cls)) == nil)
end
T.CLASS_THEMES.MAGE = MAGE_ENTRY
check("B Mage back in the table: its own colours again", sameCol(T.ClassPalette("MAGE").accent, EXP.MAGE.pal.accent))
check("B a listed class keeps the derived colours the brief does not list (gradStart, buttonBorder)",
  sameCol(T.ClassPalette("PRIEST").gradStart, derived("PRIEST").gradStart) and sameCol(T.ClassPalette("PRIEST").buttonBorder, derived("PRIEST").buttonBorder))

-- C resolve
T.ResetAll(); T.SetBase("class")
check("C played class (Demon Hunter): accent is the Demon Hunter's", sameCol(T.cur.accent, EXP.DEMONHUNTER.pal.accent), fmt(T.cur.accent))
local g = T.curGrad.gradStart
check("C played class: the glow is its gradient, with positions", g and #g.stops == 8 and sameList(g.pos, EXP.DEMONHUNTER.pos))
check("C played class: T.Grad of the parent group glow is that gradient", (function() local x = T.Grad("xui-list-parent", "bg"); return x and sameCol(x.stops[6], EXP.DEMONHUNTER.stops[6]) and sameList(x.pos, EXP.DEMONHUNTER.pos) end)())
check("C no border takes the glow: the window border is solid", T.Grad("xui-window", "border") == nil)
T.SetBase("class", "PRIEST")
check("C picked class (Priest): palette and glow are the Priest's", sameCol(T.cur.tabSelBorder, EXP.PRIEST.pal.tabSelBorder)
  and T.curGrad.gradStart and sameCol(T.curGrad.gradStart.stops[1], EXP.PRIEST.stops[1]))
T.SetBase("class", "NEWCLASS")
check("C picked a class without an entry: no glow gradient, accent is the class colour", T.curGrad.gradStart == nil and sameCol(T.cur.accent, { 0.529, 0.533, 0.933, 1 }), fmt(T.cur.accent))
T.SetBase("class", "WARLOCK")
check("C picked Warlock: its palette, and its glow holds the last colour from 90%", sameCol(T.cur.accent, EXP.WARLOCK.pal.accent)
  and T.curGrad.gradStart and #T.curGrad.gradStart.stops == 8 and near(T.curGrad.gradStart.pos[8], 0.9))
T.SetBase("class", "ROGUE"); T.MakeCustom()
check("C Custom started from Class colors (Rogue) keeps the Rogue glow", T.curGrad.gradStart and sameCol(T.curGrad.gradStart.stops[1], EXP.ROGUE.stops[1]))
T.SetToken("gradStart", { 0.5, 0.1, 0.1, 1 })
check("C your own solid Parent group glow replaces the class glow", T.curGrad.gradStart == nil)
T.ResetToken("gradStart")
check("C reset: the class glow is back", T.curGrad.gradStart ~= nil)
T.SetTokenGradient("gradStart", false)
check("C 'solid' for the glow is kept as false (the class has a gradient there)", T.DB().grads and T.DB().grads.gradStart == false)
local sg = T.SavedGrads({ base = "class", classPick = "HUNTER", tokens = {} })
check("C a saved class theme (picked Hunter) brings the Hunter glow", sg.gradStart and sameCol(sg.gradStart.stops[8], EXP.HUNTER.stops[8]) and sameList(sg.gradStart.pos, EXP.HUNTER.pos))

-- D share strings
T.ResetAll()
check("D export of Class colors (played Demon Hunter) is the string made before gradients", T.Export() == OLD.class, T.Export())
T.ResetAll(); T.SetBase("class", "MAGE"); T.SetFont("none")
check("D export of Class colors (picked Mage) is the string made before gradients", T.Export() == OLD.classMage, T.Export())
T.ResetAll(); T.SetBase("class", "PRIEST")
check("D export of Class colors (picked Priest) carries no gradient", not T.Export():find("grads") and not T.Decode(T.Export()).grads)
T.ResetAll(); T.SetBase("default")
local th = T.DB(); th.grads = { accent = { stops = { { 1, 0, 0, 1 }, { 0, 0, 1, 1 }, { 0, 1, 0, 1 } }, pos = { 0.2, 0.3, 0.9 } } }; T.Changed()
local s = T.Export()
T.ResetAll(); local ok = T.Import(s)
check("D an own gradient with positions survives export and import", ok and T.curGrad.accent and sameList(T.curGrad.accent.pos, { 0.2, 0.3, 0.9 }), s)
local cases = { { 0.5, 0.4, 1 }, { 0, 1 }, { 0, 0.5, 1.2 }, "x" }
local dropped = 0
for _, p in ipairs(cases) do local cg = T.CleanGrad({ stops = { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } }, pos = p }); if cg and cg.pos == nil then dropped = dropped + 1 end end
check("D a pos that does not fit is dropped, the gradient kept (4 cases)", dropped == 4, dropped)
check("D a gradient without pos stays without pos", T.CleanGrad({ stops = { { 1, 0, 0 }, { 0, 1, 0 } } }).pos == nil)

-- E drawing
T.ResetAll()
local host = CreateFrame("Frame", nil, UIParent); host:SetSize(200, 20); host:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
local tex = host:CreateTexture(nil, "BACKGROUND"); tex:SetAllPoints(); tex:Show()
local A, B, C = { 1, 0, 0, 1 }, { 0, 1, 0, 1 }, { 0, 0, 1, 1 }
local function pieces()
  local out = {}
  for _, s in ipairs(tex.xuiGradL and tex.xuiGradL.segs or {}) do
    if s:IsShown() then
      local _, _, _, x0 = s:GetPoint(1)
      local p2, _, rp2, x1 = s:GetPoint(2)
      out[#out + 1] = { x0, rp2 == "BOTTOMRIGHT" and 200 or x1, s.xuiGrad[2], s.xuiGrad[3] }
    end
  end
  return out
end
T.PaintLine(host, tex, nil, { stops = { A, B, C }, pos = { 0.1, 0.5, 0.75 } }, "H")
local p = pieces()
check("E with positions: 4 pieces (hold, two blends, hold)", #p == 4, #p)
check("E hold 0..20 in the first colour", p[1] and near(p[1][1], 0) and near(p[1][2], 20) and sameCol(p[1][3], A) and sameCol(p[1][4], A))
check("E blend 20..100 first to second", p[2] and near(p[2][1], 20) and near(p[2][2], 100) and sameCol(p[2][3], A) and sameCol(p[2][4], B))
check("E blend 100..150 second to third", p[3] and near(p[3][1], 100) and near(p[3][2], 150) and sameCol(p[3][4], C))
check("E hold 150..end in the last colour", p[4] and near(p[4][1], 150) and near(p[4][2], 200) and sameCol(p[4][3], C) and sameCol(p[4][4], C))
T.PaintLine(host, tex, nil, { stops = { A, A, B, C }, pos = { 0, 0.5, 0.5, 1 } }, "H")
p = pieces()
check("E two stops at one place make no piece (A..A, A|B jump, B..C)", #p == 2 and near(p[1][2], 100) and sameCol(p[2][3], B), #p)
T.PaintLine(host, tex, nil, { stops = { A, B, C } }, "H")
p = pieces()
check("E without positions: 2 equal pieces, as before", #p == 2 and near(p[1][2], 100) and near(p[2][1], 100))
T.PaintLine(host, tex, { 1, 1, 1, 1 }, nil, "H")
check("E solid again: no piece shown", #pieces() == 0)
local th2 = T.DB(); th2.gradRev = true
local og = T.ClassGrads("PALADIN").gradStart
th2.base = "class"; th2.classPick = "PALADIN"; T.Resolve()
local rg = T.Grad("xui-list-parent", "bg")
-- Xaya 2026-11-13: "reverse themeing for class colors shouldn't be allowed": a saved Reverse leaves the class glow as designed
check("E Reverse leaves the class glow as designed (Paladin, saved gradRev from before)", rg and near(rg.pos[2], og.pos[2]) and near(rg.pos[3], og.pos[3])
  and sameCol(rg.stops[1], og.stops[1]) and sameCol(rg.stops[8], og.stops[8]), rg and table.concat(rg.pos, ","))
check("E Class colors alone does not offer the Reverse switch", not T.HasGradient())
check("E the fixed mark never reaches saved data", T.DB().grads == nil and not (T.Export and T.Export():find("fixed")))
T.MakeCustom(); T.Resolve()
local cg = T.Grad("xui-list-parent", "bg")
check("E Custom started from Class colors: the glow is still not reversed", cg and sameCol(cg.stops[1], og.stops[1]) and not T.HasGradient())
-- a gradient of your own on top of the class base still turns round
T.DB().grads = { border = { stops = { { 1, 0, 0, 1 }, { 0, 0, 1, 1 } } } }; T.Resolve()
check("E your own gradient on Class colors offers the switch", T.HasGradient())
local mine = T.curGrad.border
local mg = T.Grad("xui-window", "border")
check("E your own gradient still turns round", mine and mg and sameCol(mg.stops[1], mine.stops[#mine.stops]) and sameCol(mg.stops[#mg.stops], mine.stops[1]))
local pg = T.Grad("xui-list-parent", "bg")
check("E ... while the class glow beside it does not", pg and sameCol(pg.stops[1], og.stops[1]))
T.ResetAll()

-- F the parent group glow
if ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
local btn = CreateFrame("Button", nil, UIParent); btn:SetSize(240, 20); btn:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -40)
btn.uniquevalue = "root\001grp"; btn.obj = { status = { selected = "root\001grp\001inner\001rule" } }
check("F Options loaded: the row painter is there", type(ns.SafeDecorate) == "function")
T.SetBase("class")   -- played Demon Hunter
ns.lastTreeErr = nil
ns.SafeDecorate(btn)
local bn = btn.xuiBanner
local segs = bn and bn.xuiGradL and bn.xuiGradL.segs or {}
local shown = {}; for _, sg2 in ipairs(segs) do if sg2:IsShown() then shown[#shown + 1] = sg2 end end
check("F Demon Hunter: the glow is drawn in pieces across the row (7 pieces: the 0-6% hold, 6 blends)", #shown == 7 and bn:IsShown(), #shown .. " " .. tostring(ns.lastTreeErr))
local first, last = shown[1] and shown[1].xuiGrad, shown[#shown] and shown[#shown].xuiGrad
local dh = EXP.DEMONHUNTER.stops
check("F Demon Hunter: first piece is the class colour hold, last ends on the lime, at 0.95",
  first and sameCol(first[2], { dh[1][1], dh[1][2], dh[1][3], 0.95 }) and sameCol(first[3], { dh[2][1], dh[2][2], dh[2][3], 0.95 })
  and last and sameCol(last[3], { dh[8][1], dh[8][2], dh[8][3], 0.95 }), first and fmt(first[2]))
local x1
if shown[2] then local _, _, _, x = shown[2]:GetPoint(1); x1 = x end
check("F Demon Hunter: the hold is 6% of the row (14.4 of 240)", near(x1, 240 * 0.06), x1)
T.SetBase("class", "NEWCLASS")
ns.SafeDecorate(btn)
local any = false; for _, sg2 in ipairs(segs) do if sg2:IsShown() then any = true end end
local gs = T.cur.gradStart
check("F a class without an entry: no pieces; one texture from the glow colour to black, as before", not any and bn._grad and bn._grad[1] == "HORIZONTAL"
  and sameCol(bn._grad[2], { gs[1], gs[2], gs[3], 0.95 }) and sameCol(bn._grad[3], { 0, 0, 0, 0.95 }), bn._grad and fmt(bn._grad[2]))
btn.obj.status.selected = "root\001other"
ns.SafeDecorate(btn)
check("F row no longer the selection's top group: banner hidden", not bn:IsShown())
check("F no decoration error", ns.lastTreeErr == nil, ns.lastTreeErr)
T.ResetAll()
return R
end
'''

OLD = {
    "class": "XUITHEME1:51d616ce:eyJiYXNlIjoiY2xhc3MiLCJjbGFzc2VzIjp7fSwiZm9udCI6Im5vbmUiLCJzaXplIjoiTSIsInRva2VucyI6e30sInYiOjF9",
    "classMage": "XUITHEME1:2d951c73:eyJiYXNlIjoiY2xhc3MiLCJjbGFzc1BpY2siOiJNQUdFIiwiY2xhc3NlcyI6e30sImZvbnQiOiJub25lIiwic2l6ZSI6Ik0iLCJ0b2tlbnMiOnt9LCJ2IjoxfQ==",
}


def main():
    folders = H.find_addons()
    enabled = [n for n in folders if n not in ("XayaUI_DevAssist", "XayaUI_Rules")]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    run = L.eval("function(src, W, Ld, e, o) return loadstring(src)()(W, Ld, e, o) end")
    res = run(LUA, world, loader, H.to_lua(L, expected()), H.to_lua(L, OLD))
    bad = 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        print(("PASS " if ok else "FAIL ") + str(name)[:900])
        if not ok:
            bad += 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    return 1 if bad or errs else 0


if __name__ == "__main__":
    sys.exit(main())
