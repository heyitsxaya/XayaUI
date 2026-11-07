#!/usr/bin/env python3
"""In-game QA walkthroughs for XayaUI Blizzard Reskin 0.6.10's BlizzardSkins.lua (XayaUI_DevAssist 0.7.41, QAWalks-reskin.lua). Standing rule
V22 (Xaya 2026-11-07): "make sure every feature or significant change to the codebase / bug report fixes have an in game qa test walk
through with pre-fill confirmation options or data capturing".
Checks, on the real addons in the stand-in game: the five walkthroughs (windows, minimap, tooltips, tracker, toasts and pop-ups) are registered with prefill on
and every step has a check or is a question (noVerdict); their own checks give the right verdict on the stand-in (a bag window skinned,
then given back; the square minimap, then round; a tooltip in the theme's window colour; the tracker header in the label colour, then
the Quests section given back); and her reskin settings are put back exactly as they were at the end of each walkthrough.
Negative control: QAWalks-reskin.lua does not exist before this change (every check fails there).
Run: python3 tests/qa_walks_reskin_run.py   (Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
-- stand-ins: a bag window, the minimap, a tooltip, the tracker with a Quests section
local function Window(name)
  local f = CreateFrame("Frame", name, UIParent)
  f.NineSlice = CreateFrame("Frame", nil, f); f.Bg = f:CreateTexture(nil, "BACKGROUND"); f:Hide()
  return f
end
local bag = Window("ContainerFrameCombinedBags")
function OpenAllBags() bag:Show() end
GetMinimapShape = nil   -- not a Blizzard function in 12.1.5 (the stand-in world defines one for other tests)
local MM = CreateFrame("Frame", "Minimap", UIParent); MM.SetMaskTexture = function(self, t) self._mask = t end
local compass = MM:CreateTexture("MinimapCompassTexture", "OVERLAY")
local GT = CreateFrame("Frame", "GameTooltip", UIParent); GT:Hide()
GT.NineSlice = CreateFrame("Frame", nil, GT); GT.NineSlice.Center = GT.NineSlice:CreateTexture(nil, "BACKGROUND")
GT.NineSlice.SetCenterColor = function(self, r, g, b, a) self.Center:SetVertexColor(r, g, b, a) end
GT.NineSlice.SetBorderColor = function() end
function SharedTooltip_SetBackdropStyle(tip) tip.NineSlice:SetCenterColor(0.1, 0.1, 0.1, 1) end
local function Header(p) local h = CreateFrame("Frame", nil, p); h.Background = h:CreateTexture(nil, "BACKGROUND"); h.Text = h:CreateFontString(nil, "OVERLAY"); return h end
local OTF = CreateFrame("Frame", "ObjectiveTrackerFrame", UIParent); OTF.Header = Header(OTF)
local QOT = CreateFrame("Frame", "QuestObjectiveTracker", OTF); QOT.Header = Header(QOT); QOT.EndLayout = function() end
-- Battle.net toast (backdrop) and the pop-up dialogs (art on child "BG"); StaticPopup_Show shows the first free one and sets .which
local BNT = CreateFrame("Frame", "BNToastFrame", UIParent); BNT:Hide()
for i = 1, 4 do local p = CreateFrame("Frame", "StaticPopup" .. i, UIParent); p.BG = CreateFrame("Frame", nil, p); p:Hide() end
StaticPopupDialogs = {}
function StaticPopup_Show(which) if not StaticPopupDialogs[which] then return end; StaticPopup1.which = which; StaticPopup1:Show(); return StaticPopup1 end
function StaticPopup_Hide(which) if StaticPopup1.which == which then StaticPopup1:Hide() end end

L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 5)
local QA = rawget(_G, "XayaUI_DevQA")
local ns = rawget(_G, "XayaUI_NS")
check("Dev Assist has the QA walkthroughs", QA and QA.walks ~= nil)
if not QA then return R end
-- her settings before: one page on (tracker), one window left out, so "put back" is not just "nothing"
CueRulesDB.ui = CueRulesDB.ui or {}
CueRulesDB.ui.rsk = { tracker = true, winOff = { bank = true }, otOff = {} }
local before = "tracker=true bank-out"
local function Same() local r = CueRulesDB.ui.rsk; return r and r.tracker == true and r.winOff and r.winOff.bank == true and not r.windows and not r.minimap and not r.tooltips and not r.shape end

local IDS = { "reskin-windows", "reskin-minimap", "reskin-tooltips", "reskin-tracker", "reskin-toasts" }
for _, id in ipairs(IDS) do
  local w = QA.walks[id]
  local good = w ~= nil and w.prefill == true and w.area == "Reskin"
  if w then for _, s in ipairs(w.steps) do if not (s.check or s.noVerdict) then good = false end end end
  check(id .. ": registered, prefill on, every step has a check or is a question", good)
end
local function run(id, i) local s = QA.walks[id].steps[i]; if s.setup then s.setup() end; if s.check then return s.check() end end

-- windows
check("windows 1: Blizzard Windows switches on", run("reskin-windows", 1))
local ok, why = run("reskin-windows", 2)
check("windows 2: the bags open and carry the XayaUI look", ok, why)
ok, why = run("reskin-windows", 3)
check("windows 3: no Talents window open: the check says so (not a pass)", ok == false and why:find("not open", 1, true), why)
ok, why = run("reskin-windows", 5)
check("windows 5: switched off, the bag window has Blizzard's art back", ok, why)
run("reskin-windows", 6)
check("windows: her settings are put back", Same(), before)

-- minimap
ok, why = run("reskin-minimap", 1)
check("minimap 1: square look on, minimap-button addons told SQUARE", ok and MM._mask ~= nil and why:find("SQUARE", 1, true), why)
ok, why = run("reskin-minimap", 3)
check("minimap 3: Circle gives the round minimap back", ok, why)
run("reskin-minimap", 4)
check("minimap: her settings are put back", Same(), before)

-- tooltips
local s1 = QA.walks["reskin-tooltips"].steps[1]
s1.setup(); ok, why = s1.check()
check("tooltips 1: no tooltip showing: the check says so (not a pass)", ok == false, why)
GT:Show(); SharedTooltip_SetBackdropStyle(GT)
ok, why = s1.check()
check("tooltips 1: a tooltip showing is in the theme's window colour", ok, why)
run("reskin-tooltips", 3)
check("tooltips: her settings are put back", Same(), before)

-- tracker
ok, why = run("reskin-tracker", 1)
check("tracker 1: the tracker header in the theme's label colour", ok, why)
ok, why = run("reskin-tracker", 2)
check("tracker 2: the Quests section left out has Blizzard's header back", ok, why)
run("reskin-tracker", 4)
check("tracker: her settings are put back (Quests not left out)", Same() and not CueRulesDB.ui.rsk.otOff.quests, before)

-- toasts and pop-ups (Reskin 0.6.10)
ok, why = run("reskin-toasts", 1)
check("toasts 1: Toasts and Pop-ups switches on", ok, why)
ok, why = run("reskin-toasts", 2)
check("toasts 2: our test pop-up opens and carries the XayaUI look", ok and StaticPopup1.which == "XAYAUI_QA_RESKIN_POPUP" and StaticPopupDialogs.XAYAUI_QA_RESKIN_POPUP.button1 ~= nil, why)
ok, why = run("reskin-toasts", 4)
check("toasts 4: the Battle.net toast's colour is read and matches the theme", ok and why:find("toast colour", 1, true), why)
ok, why = run("reskin-toasts", 5)
check("toasts 5: switched off, the pop-up has Blizzard's art back", ok, why)
run("reskin-toasts", 6)
check("toasts: the test pop-up is closed and her settings are put back", Same() and not CueRulesDB.ui.rsk.toasts and not StaticPopup1:IsShown(), before)
return R
end
'''


def main():
    folders = H.find_addons()
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world, H.to_lua(L, {"folders": folders, "enabled": {k: True for k in folders}, "saved": {}}))
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
