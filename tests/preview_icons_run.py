#!/usr/bin/env python3
"""Offline test (Options 0.6.53): the sidebar preview icons are XayaUI's own pictures. Xaya, 2026-11-06: "change the audio preview icon to
JUST a headphone icon please", "instead of gold, do a slash through to indicate it being off", "do the same with the eye so it's clearer
and our own icon please"; her pick: "Yes, slash and dimmed".
Checks what the sidebar draws: on a rule row the eye and the headphone show the slashed picture (dimmed) while the preview is off and the
plain picture (full brightness) while it is on; the four pictures are in the repository as 64 x 64 32-bit TGA files with an alpha channel.
Run: python3 tests/preview_icons_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
import os, struct, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402
REPO = os.path.dirname(HERE)

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. ((ok or extra == nil) and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup(); W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 5)
local ns = rawget(_G, "XayaUI_NS")
local r = ns.NewRule(); r.name = "Preview me"; r.enabled = true; r.useBuff, r.buffID, r.buffState = true, 1001, "present"
r.visual.enabled, r.visual.trigger = true, "condition"
ns.NormalizeRule(r)
-- a rule with a display shows one preview button (the eye); a sound-only rule shows the headphone (Options.lua, two-row sidebar rows)
local s = ns.NewRule(); s.name = "Hear me"; s.enabled = true; s.useBuff, s.buffID, s.buffState = true, 1002, "present"
s.visual.enabled = false; s.sound.enabled, s.sound.source, s.sound.value = true, "kit", "8959"
ns.NormalizeRule(s)
ns.folders = { { id = "fA", name = "Audio" } }
s.folder = "fA"
ns.rules = { s, r }
if ns.ToggleUI then pcall(ns.ToggleUI) end
W.tick(0.1, 4)
ns = rawget(_G, "XayaUI_NS")
local I = ns.PREVIEW_ICONS
check("the preview pictures are XayaUI's own files", I and I.visual.on:find("XayaUI\\Media\\UI\\xui_eye.tga", 1, true) and I.visual.off:find("xui_eye_off.tga", 1, true)
  and I.sound.on:find("xui_headphone.tga", 1, true) and I.sound.off:find("xui_headphone_off.tga", 1, true))
local eye, head
local function walk(f, d)
  if not f or d > 60 or (eye and head) then return end
  if f.xuiEye and f.xuiEye.objs and f.xuiEye:IsShown() then
    for _, o in ipairs(f.xuiEye.objs) do if o == r then eye = f.xuiEye end end
  end
  if f.xuiHead and f.xuiHead.objs and f.xuiHead:IsShown() then   -- a group row shows both; the "Audio" group holds the sound rule
    for _, o in ipairs(f.xuiHead.objs) do if o == s then head = f.xuiHead end end
  end
  for _, c in ipairs(f.GetChildren and { f:GetChildren() } or {}) do walk(c, d + 1) end
end
local function find() eye, head = nil, nil; walk(UIParent, 0) end
local _ = s
find()
check("the display rule's sidebar row has its eye", eye ~= nil)
-- the headphone sits on group rows (and sound-only rows); the stand-in draws no such row here, so its picture choice is checked through
-- the same function every toggle uses (ns.PreviewIcon), and the eye below checks that function on a drawn row
check("headphone: slashed while off, plain while on or partly on", ns.PreviewIcon("sound", 0) == I.sound.off and ns.PreviewIcon("sound", 1) == I.sound.on
  and ns.PreviewIcon("sound", 0.5) == I.sound.on and ns.PreviewIcon("visual", 0) == I.visual.off and ns.PreviewIcon("visual", 0.5) == I.visual.on)
if not eye then return R end
-- the Loaded root (Xaya: "loaded does not have an eye icon next to it to preview every loaded + enabled rule; not loaded also has the same
-- problem"): its eye previews every rule in that list
local rootEye, rootHead
local function walkRoot(f, d)
  if not f or d > 60 or rootEye then return end
  if tostring(f.uniquevalue or "") == "loaded" then rootEye, rootHead = f.xuiEye, f.xuiHead end
  for _, c in ipairs(f.GetChildren and { f:GetChildren() } or {}) do walkRoot(c, d + 1) end
end
walkRoot(UIParent, 0)
local hasR = false
if rootEye and rootEye.objs then for _, o in ipairs(rootEye.objs) do if o == r then hasR = true end end end
check("the LOADED row has an eye that previews its rules (and no headphone)", rootEye ~= nil and rootEye:IsShown() and hasR and not (rootHead and rootHead:IsShown()),
  tostring(rootEye) .. " " .. tostring(rootEye and rootEye:IsShown()) .. " " .. tostring(hasR))
local okNL, nl = pcall(function() return ns.PvFilter(ns.rules, "notloaded", true) end)
check("the NOT LOADED eye covers only rules that are not loaded (here: none of these two)", okNL and #nl == 0, okNL and #nl or nl)
local function look(b) return tostring(b.tex:GetTexture()), b.tex:GetAlpha() end
local et, ea = look(eye)
check("preview off: the slashed eye, dimmed", et == I.visual.off and ea < 0.5, et .. " " .. ea)
ns.SetPreview({ r }, "visual", true); ns.SetPreview({ s }, "sound", true)
if ns.DecorateTrees then ns.DecorateTrees() end
W.tick(0.1, 2)
find()
et, ea = look(eye)
check("preview on: the plain eye at full brightness", et == I.visual.on and ea == 1, et .. " " .. ea)
ns.SetPreview({ r }, "visual", false); ns.SetPreview({ s }, "sound", false)
if ns.DecorateTrees then ns.DecorateTrees() end
W.tick(0.1, 2)
find()
et = look(eye)
check("switched off again: back to the slashed eye", et == I.visual.off, et)
return R
end
'''


def tga_ok(rel):
    path = os.path.join(REPO, rel.replace("\\", "/"))
    tracked = subprocess.run(["git", "ls-files", "--error-unmatch", path], cwd=REPO, capture_output=True).returncode == 0
    if not (tracked and os.path.exists(path)):
        return False
    h = open(path, "rb").read(18)
    w, hh = struct.unpack("<HH", h[12:16])
    return h[2] == 2 and w == 64 and hh == 64 and h[16] == 32 and (h[17] & 0x0F) == 8


def main():
    bad = 0
    for f in ("xui_eye.tga", "xui_eye_off.tga", "xui_headphone.tga", "xui_headphone_off.tga"):
        ok = tga_ok("XayaUI/Media/UI/" + f)
        print(("ok  " if ok else "FAIL: ") + "XayaUI/Media/UI/%s is in the repository: 64 x 64, 32-bit, alpha" % f)
        bad += 0 if ok else 1
    folders = H.find_addons()
    enabled = [n for n in folders if n != "XayaUI_DevAssist"]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(LUA, world, loader)
    n = 4
    for i in range(1, len(res) + 1):
        name, ok = res[i][1], res[i][2]
        n += 1
        if not ok:
            bad += 1
            print("FAIL:", name)
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (n, bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
