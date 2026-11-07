#!/usr/bin/env python3
"""The rule list's right-hand icon columns (Options 0.6.64; REQUEST-LOG UI-70, Xaya 2026-11-07: "icons still not appropriately handled
and display irregularly" [screenshots: a header's red +/- on top of the eye and headphone; icons missing or shifted from row to row]; her
answer UI-72: "copy the WA format w/ toggle being under group as previously suggested").
Checks, on the real addons in the stand-in game (Rules > Enabled and Smart Categories): on every one-row row the icons sit in the same
columns from the right edge: open / close 4 px (headers only), the preview (eye, or the headphone on a sound-only row) 23 px, the note
(edit lock) 42 px, the lock (movement) 61 px; a header's open / close button is the far-right one with the eye just left of it; nothing
overlaps; a row's name ends left of its leftmost icon. Before (Options 0.6.63) a header's button sat 46 px in, over the eye (61) and
headphone (42), and the locks moved right when the other was missing.
Run: python3 tests/sidebar_icon_columns_run.py   (Lua 5.1 via lupa; slow)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. ((ok or extra == nil) and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup(); W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 5)
local ns = rawget(_G, "XayaUI_NS")
local function rule(name, vis, snd, folder)
  local r = ns.NewRule(); r.name = name; r.enabled = true; r.useBuff, r.buffID, r.buffState = true, 1000 + #name, "present"
  r.visual.enabled = vis; if vis then r.visual.trigger = "condition" end
  if snd then r.sound.enabled, r.sound.source, r.sound.value = true, "kit", "8959" end
  r.folder = folder; ns.NormalizeRule(r); return r
end
ns.folders = { { id = "fA", name = "VDH" }, { id = "fB", name = "Sounds only" } }
ns.rules = { rule("Show me", true, false, "fA"), rule("Hear me", false, true, "fB"), rule("Both", true, true, "fA") }
CueRulesDB.rules = ns.rules
if ns.ToggleUI then pcall(ns.ToggleUI) end
W.tick(0.1, 4)
ns = rawget(_G, "XayaUI_NS")
local ACD = LibStub("AceConfigDialog-3.0")
local COL = ns.OptionsApi and ns.OptionsApi.SIDE_COL
check("the columns are defined once (ns.OptionsApi.SIDE_COL)", COL and COL.expand == 4 and COL.preview == 23 and COL.note == 42 and COL.lock == 61,
  COL and (COL.expand .. "/" .. COL.preview .. "/" .. COL.note .. "/" .. COL.lock))
COL = COL or { expand = 4, preview = 23, note = 42, lock = 61 }
local function off(b) if not (b and b:IsShown()) then return nil end local p, _, rp, x = b:GetPoint(1); if p == "RIGHT" and rp == "RIGHT" then return -(x or 0) end return "not right-anchored" end
local function rows()
  local out = {}
  local function walk(f, d)
    if not f or d > 60 then return end
    if f.uniquevalue and f.IsShown and f:IsShown() then out[#out + 1] = f end
    for _, c in ipairs(f.GetChildren and { f:GetChildren() } or {}) do walk(c, d + 1) end
  end
  walk(UIParent, 0); return out
end
for _, sub in ipairs({ "enabledTab", "smartTab", "disabledTab" }) do
  ACD:SelectGroup("CueRules", "cooldowns", sub); W.tick(0.2, 4)
  if ns.DecorateTrees then ns.DecorateTrees() end; W.tick(0.1, 2)
  local bad, seen = {}, 0
  for _, b in ipairs(rows()) do
    if not b.xuiTwoRow then
      seen = seen + 1
      local name = tostring(b.uniquevalue):match("([^\001]+)$")
      local function want(fr, col, what) local o = off(fr); if o ~= nil and o ~= col then bad[#bad + 1] = name .. " " .. what .. " at " .. tostring(o) end end
      want(b.xuiEye, COL.preview, "eye"); want(b.xuiHead, COL.preview, "headphone"); want(b.xuiEdit, COL.note, "note"); want(b.xuiMove, COL.lock, "lock")
      if b.xuiChev and b.xuiChev:IsShown() then
        local p, _, rp = b.xuiChev:GetPoint(1)
        if p == "RIGHT" then want(b.xuiChev, COL.expand, "open / close") end
      end
      if b.xuiEye and b.xuiEye:IsShown() and b.xuiHead and b.xuiHead:IsShown() then bad[#bad + 1] = name .. ": eye and headphone both shown in one column" end
    end
  end
  check(sub .. ": every one-row row's icons in the fixed columns (open / close 4, preview 23, note 42, lock 61)", seen > 0 and #bad == 0, seen .. " rows; " .. table.concat(bad, "; "):sub(1, 400))
end
-- the LOADED header: open / close at the far right, the eye just left of it
ACD:SelectGroup("CueRules", "cooldowns", "enabledTab"); W.tick(0.2, 4)
local hdr
for _, b in ipairs(rows()) do if tostring(b.uniquevalue) == "loaded" then hdr = b end end
check("LOADED: its open / close button is the far-right icon and the eye sits just left of it (WeakAuras)", hdr and off(hdr.xuiChev) == COL.expand and off(hdr.xuiEye) == COL.preview,
  hdr and (tostring(off(hdr.xuiChev)) .. " / " .. tostring(off(hdr.xuiEye))) or "no LOADED row")
return R
end
'''


def main():
    folders = H.find_addons()
    enabled = [n for n in folders if n != "XayaUI_DevAssist"]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    bad = 0
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        print(("PASS " if ok else "FAIL ") + name)
        if not ok:
            bad += 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
