#!/usr/bin/env python3
"""Offline test (XayaUI_Options 0.6.45): the auto-populate table as it is DRAWN. Xaya, 2026-11-06, on a screenshot of the 0.6.42 picker
(each row a tick box with a far-away cue dropdown, the debuff choice on a line of its own, no column names): "need to fix display and
follow proposed rule of columns and type as specified. also need to actually display proposed column names -- note I don't suggest them
just for fun, they are prescriptions for initial display pane configurations".
Opens the real settings window in the stand-in game, loads a spec's list on the Class/Spec Rule Creator page and measures the widgets
AceGUI placed: the header row shows the column names in her order (Name | Type | Trigger | Cue type | Combat load), every table row sits
on one line with its cells left to right under their column names, rows stack without overlapping, nothing runs past the pane's right
edge; the same with Advanced's Extra cues column and in a narrower window.
Limits of the stand-in: text is measured by character count, not by the game's font, so this cannot say whether a long value is cut
inside its dropdown (QA B150 asks for a screenshot).
Run: python3 tests/auto_table_layout_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa; slow)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
ns = rawget(_G, "XayaUI_NS")
local AP = ns and ns.AutoPicker
check("the auto-populate table is loaded", AP ~= nil and AP.Load ~= nil)
if not (AP and AP.Load) then return R end
GetNumSpecializations = function() return 2 end
GetSpecializationInfo = function(i) if i == 1 then return 577, "Havoc", "", 1247264, "DAMAGER" end return 581, "Vengeance", "", 1247263, "TANK" end
ns.CLASS_AURA_DATA = { [581] = { entries = { { kind = "cd", id = 187827 }, { kind = "cd", id = 204021, talent = true }, { kind = "cd", id = 6789 } } } }
local INFO = { [11] = { spellID = 204021, linkedSpellIDs = { 207771 }, hasAura = true, selfAura = false },
               [12] = { spellID = 187827, linkedSpellIDs = {}, hasAura = true, selfAura = true } }
C_CooldownViewer = { GetCooldownViewerCategorySet = function(cat) if cat == 0 then return { 11, 12 } end return {} end,
  GetCooldownViewerCooldownInfo = function(id) return INFO[id] end }
local ACD = LibStub("AceConfigDialog-3.0")
pcall(ns.ToggleUI); W.tick(0.1, 4)
AP.Load(581)
local COLS = { "on", "nm", "ty", "tr", "cu", "cb" }
local NAMES = { nm = "Name", ty = "Type", tr = "Trigger", cu = "Cue type", cb = "Combat load", xc = "Extra cues" }

local function measure(label, cols)
  ACD:SelectGroup("CueRules", "cooldowns", "creatorTab"); W.tick(0.3, 4)
  local found = {}
  local function walk(w, d)
    if not w or d > 40 then return end
    local path = w.GetUserData and w:GetUserData("path")
    local key = type(path) == "table" and path[#path]
    if type(key) == "string" then found[key] = w end
    for _, c in ipairs(w.children or {}) do walk(c, d + 1) end
  end
  walk(ACD.OpenFrames["CueRules"], 0)
  local nrows = #AP.view.rows
  local hdr = found.hOn
  check(label .. ": the table is drawn with a header row and every row", hdr ~= nil and found["r" .. nrows .. "on"] ~= nil, nrows)
  if not hdr then return end
  local content = hdr.frame:GetParent()
  local box = content:GetParent()   -- the framed box the player sees (AceGUI InlineGroup border)
  local cl, cr = content:GetLeft(), content:GetRight()
  local br = box:GetRight()
  local function mid(f) return f:GetTop() - f:GetHeight() / 2 end
  -- header: column names in her order, each over its column
  local hOK, why = true, ""
  for _, k in ipairs(cols) do
    if k ~= "on" then
      local h = found["h" .. k]
      local txt = h and h.label and h.label:GetText() or (h and h.GetText and h:GetText()) or ""
      if not h or not tostring(txt):find(NAMES[k], 1, true) then hOK = false; why = why .. k .. ":" .. tostring(txt) .. " " end
    end
  end
  check(label .. ": the header shows the column names " .. table.concat((function() local t = {}; for _, k in ipairs(cols) do if k ~= "on" then t[#t + 1] = NAMES[k] end end; return t end)(), " | "), hOK, why)
  local rowsOK, alignOK, edgeOK, stackOK, w1 = true, true, true, true, ""
  local prevBottom
  for i = 0, nrows do
    local cells = {}
    for _, k in ipairs(cols) do cells[#cells + 1] = (i == 0) and (k == "on" and found.hOn or found["h" .. k]) or found["r" .. i .. k] end
    local m0 = mid(cells[1].frame)
    local top, bottom = -math.huge, math.huge
    for j, c in ipairs(cells) do
      local f = c.frame
      if math.abs(mid(f) - m0) > 1 then rowsOK = false; w1 = w1 .. ("row %d col %s off its line (%.1f vs %.1f); "):format(i, cols[j], mid(f), m0) end
      if j > 1 and f:GetLeft() < cells[j - 1].frame:GetRight() - 0.5 then rowsOK = false; w1 = w1 .. ("row %d col %s overlaps; "):format(i, cols[j]) end
      local col = (cols[j] == "on") and found.hOn or found["h" .. cols[j]]
      if math.abs(f:GetLeft() - col.frame:GetLeft()) > 0.5 or math.abs(f:GetWidth() - col.frame:GetWidth()) > 0.5 then alignOK = false end
      top = math.max(top, f:GetTop()); bottom = math.min(bottom, f:GetTop() - f:GetHeight())
    end
    -- AceGUI's own InlineGroup lays its content out 1 px wider than the content frame (content.width = width - 20, border inset 1 px):
    -- allowed; the row must still end well inside the box
    if math.abs(cells[1].frame:GetLeft() - cl) > 0.5 or cells[#cells].frame:GetRight() > cr + 1.01 or cells[#cells].frame:GetRight() > br - 5 then edgeOK = false end
    if prevBottom and top > prevBottom + 0.5 then stackOK = false end
    prevBottom = bottom
  end
  check(label .. ": every row sits on one line, its cells left to right without overlapping", rowsOK, w1)
  check(label .. ": every cell is exactly under its column name (same left edge and width)", alignOK)
  check(label .. ": rows start at the box's left edge and end inside its right edge", edgeOK, ("pane %.1f-%.1f, box right %.1f"):format(cl, cr, br))
  check(label .. ": rows stack top to bottom without overlapping", stackOK)
  return cr - cl
end

local wide = measure("default window", COLS)
AP.adv = true
measure("Advanced", { "on", "nm", "ty", "tr", "cu", "cb", "xc" })
AP.adv = nil
-- less room: the window 200 px narrower (its saved width: AceConfigDialog reopens the window at that size)
local st = ACD:GetStatusTable("CueRules")
local w0 = st.width or ACD.OpenFrames["CueRules"].frame:GetWidth()
st.width = w0 - 200
local narrow = measure("window 200 px narrower", COLS)
check("the narrower window really gives the table less room", wide and narrow and narrow < wide - 100, tostring(wide) .. " / " .. tostring(narrow))
st.width = w0
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
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
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
