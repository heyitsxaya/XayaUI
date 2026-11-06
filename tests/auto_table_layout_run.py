#!/usr/bin/env python3
"""Offline test (XayaUI_Options 0.6.45; Cue set-up, Spec column and bucket headers 0.6.53): the auto-populate table as it is DRAWN. Xaya, 2026-11-06, on a screenshot of the 0.6.42 picker
(each row a tick box with a far-away cue dropdown, the debuff choice on a line of its own, no column names): "need to fix display and
follow proposed rule of columns and type as specified. also need to actually display proposed column names -- note I don't suggest them
just for fun, they are prescriptions for initial display pane configurations".
Opens the real settings window in the stand-in game, loads a spec's list on the Class/Spec Rule Creator page and measures the widgets
AceGUI placed: the header row shows the column names in her order (Name | Type | Trigger | Cue type | Combat load), every table row sits
on one line with its cells left to right under their column names, rows stack without overlapping, nothing runs past the pane's right
edge; the same with Advanced's Extra cues column and in a narrower window.
Limits of the stand-in: text is measured by character count, not by the game's font, so this cannot say whether a long value is cut
inside its dropdown (QA B151 asks for a screenshot).
Run: python3 tests/auto_table_layout_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa; slow)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local multiSU = nil
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
-- rows with a Cue set-up: 187827 Speech (Customize) with an extra Sound (two controls share the cell under Advanced); 204021 Sound
AP.SetChoice({ spec = 581, key = "cd:187827" }, "cue", "speech")
AP.SetExtra({ spec = 581, key = "cd:187827" }, "sound", true)
AP.SetChoice({ spec = 581, key = "cd:204021" }, "cue", "sound")
AP.Load(581)
local COLS = { "on", "nm", "ty", "tr", "cu", "su", "cb" }
local NAMES = { nm = "Name", sp = "Spec", ty = "Type", tr = "Trigger", cu = "Cue type", su = "Cue set-up", cb = "Combat load", xc = "Extra cues" }

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
  local grp = hdr.parent
  check(label .. ": the table sits in a frame (a box), as she asked", grp and grp.type == "InlineGroup", grp and grp.type)
  local cl, cr = content:GetLeft(), content:GetRight()
  local br = box:GetRight()
  local function mid(f) return f:GetTop() - f:GetHeight() / 2 end
  -- a cell: one widget, or the Cue set-up cell's controls together (su1, su2: from the first one's left edge to the last one's right edge)
  local function cellOf(i, k)
    if i == 0 then return (k == "on") and found.hOn or found["h" .. k] end
    local w = found["r" .. i .. k]
    if w or k ~= "su" then return w end
    local parts = {}
    for j = 1, 4 do if found["r" .. i .. "su" .. j] then parts[#parts + 1] = found["r" .. i .. "su" .. j].frame end end
    if #parts == 0 then return nil end
    if #parts > 1 then multiSU = (multiSU or 0) + 1 end
    local a, z = parts[1], parts[#parts]
    local f = { GetLeft = function() return a:GetLeft() end, GetRight = function() return z:GetRight() end,
      GetTop = function() local t = -math.huge; for _, p in ipairs(parts) do t = math.max(t, p:GetTop()) end; return t end,
      GetHeight = function() return a:GetHeight() end, GetWidth = function() return z:GetRight() - a:GetLeft() end }
    return { frame = f }
  end
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
    for _, k in ipairs(cols) do cells[#cells + 1] = cellOf(i, k) end
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
  -- the bucket headers (Spell CD / Aura / Debuff): a tick box and the name on one line, across the table, inside the box
  local bOK, bw = true, ""
  local nb = 0
  for _, b in ipairs({ "cd", "aura", "debuff" }) do
    local t, n = found["b" .. b .. "On"], found["b" .. b .. "Nm"]
    if t and n then
      nb = nb + 1
      if math.abs(mid(t.frame) - mid(n.frame)) > 1 or n.frame:GetLeft() < t.frame:GetRight() - 0.5 or math.abs(t.frame:GetLeft() - cl) > 0.5
        or n.frame:GetRight() > br - 5 then bOK = false; bw = bw .. b .. " " end
    end
  end
  check(label .. ": the bucket headers (Spell CD, Aura, Debuff) each sit on one line with their tick box, inside the box", bOK and nb == 3, bw .. nb)
  return cr - cl
end

local wide = measure("default window", COLS)
AP.adv = true
multiSU = 0
measure("Advanced", { "on", "nm", "ty", "tr", "cu", "su", "cb", "xc" })
check("Advanced: a row whose Cue set-up cell holds two controls (Speech + an extra Sound) was measured", multiSU > 0, multiSU)
AP.adv = nil
AP.Load("all")
measure("all specs (Spec column)", { "on", "nm", "sp", "ty", "tr", "cu", "su", "cb" })
AP.Load(581)
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
