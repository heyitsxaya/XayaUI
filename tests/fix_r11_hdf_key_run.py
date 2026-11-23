#!/usr/bin/env python3
"""TF tests of the hidden-data fight's triage (round 11b, triage unit; build spec docs/plans/HIDDEN-DATA-FIGHT-SPEC-2026-11-17.md section 6,
XUI-Docs). What the player sees inside a Mythic+ key, played through the stand-in's own drivers (tests/harness/world.lua:
W.enterInstance, W.startKey, W.enterCombat ...), never by setting state by hand:

  F10  (XayaUI_Bonus_StatCalculator/StatCalculator.lua OnRestriction) the Stat Calculator open with its Change box focused:
       K1 walking into a dungeon (the Map and Chat restrictions start, ADDON_RESTRICTION_STATE_CHANGED (4,1) and (5,1)): she keeps typing
          (the box keeps the keyboard, and the keys she types go to the box);
       K2 the key starting (ChallengeMode (2,1)): the box lets go, and PRINTSCREEN / W reach the game (gate G-023, kept);
       K3 walking into a raid: she keeps typing too.
       Before the fix (r11bpre-triage) K1 and K3 fail: the calculator let go of the keyboard for ANY restriction type, so every dungeon
       or raid entry took the box away from her. Core's KeyCatch.lua already let go for Combat, Encounter, ChallengeMode and PvP only.
  F2   (XayaUI_Rules/Combat/AuraDisplay.lua; a probe, no change) in a key between pulls the game forbids addon calls on the aura
       container's buttons while auras are hidden (N12.1.0 07-14), but combat lockdown is off, and the container builds wait only on
       the lockdown. P1 a rule edit (a rebuild after 1 s), P2 the mover opened and closed, P3 a target change: no Lua error, nothing in
       the error record, the displays drawn by the container still shown. (Passes before and after: the builds touch a button only
       inside the container's initializeFrame callback, which the game allows.)
  T-1  (XayaUI_Rules/Triggers.lua TDList, spec F7) the game's other documented reading of the aura list while auras are hidden is a
       hidden list (N12.1.0 06-18, "a secret vector"; open question 10): with two "Target Debuff (yours)" rules whose debuffs are lit on
       their Cooldown Manager icons, both displays show in combat in a key, and the line hook finds no same-type '==' on the hidden list.
       Before the fix the second row of the same engine step compared the memo (the hidden list) with its error marker ('l == TD_ERR'),
       which raises in game (N12.0.0): its rule read unknown and its display stayed hidden while its icon was lit.
Stand-in numbers and event orders are not WoW (UNVERIFIED IN GAME; the event order is spec section 3.3 INFERENCE).
Run: python3 tests/fix_r11_hdf_key_run.py   (Lua 5.1 via lupa; XUI_API_INDEX for the API index)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

STATCALC = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { "[F10] " .. name .. ((ok or extra == nil) and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup()
W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
local ns = rawget(_G, "XayaUI_NS")
ns.Print = function() end
if not rawget(_G, "CharacterFrame") then rawset(_G, "CharacterFrame", CreateFrame("Frame", "CharacterFrame", UIParent)) end
CharacterFrame:Hide()
ns.RunCommand("stats", ""); W.tick(0.1, 3); ns.RunCommand("stats", ""); W.tick(0.1, 1)
local sc = ns.Service and ns.Service("statCalc")
check("(setup) the Stat Calculator's service is there", sc ~= nil)
if not sc then return R end
local c = sc.Cfg(); c.enabled, c.panel = true, true; ns.StatCalc_Apply()
CharacterFrame:Show()
sc.Open("stats"); W.tick(0.1, 3)
local panel = rawget(_G, "XayaUIStatCalculator")
check("(setup) the panel is open beside the character window", panel ~= nil and panel:IsShown())
if not panel then return R end
c.tab = "stats"; ns.StatCalc_Render(); W.tick(0.1, 2)
local box = sc.Drawn().boxes["sv:crit"]
check("(setup) the Critical Strike Change box is drawn", box ~= nil)
if not box then return R end
local function keysToGame()
  W.tick(0.02, 1)
  local n0 = #W.gameRanLog
  local a, b = W.pressKey("PRINTSCREEN"), W.pressKey("W")
  return a == "game" and b == "game" and W.gameRanLog[n0 + 1] == "SCREENSHOT" and W.gameRanLog[n0 + 2] == "MOVEFORWARD"
end
local function seen(t, s) for _, x in ipairs(W.restrictionLog) do if x[1] == t and x[2] == s then return true end end; return false end
box:SetFocus()
W.enterInstance("party", 8); W.tick(0.1, 3)
check("(sanity) entering the dungeon fired the Map and Chat restrictions (4,1) and (5,1)", seen(4, 1) and seen(5, 1))
check("K1 walking into a dungeon (Map and Chat restrictions start) with the Change box focused: she keeps typing (the box keeps the keyboard)",
  box:HasFocus())
check("K1 ...and the keys she types go to the box, not to the game", W.pressKey("PRINTSCREEN") == box)
W.startKey(503, 10, { 9, 10 }); W.tick(0.1, 3)
check("K2 the key starts (ChallengeMode restriction, Activating): the box lets go of the keyboard (gate G-023, kept)", not box:HasFocus())
check("K2 ...and PRINTSCREEN and W reach the game (screenshot, move forward)", keysToGame())
W.completeKey(); W.leaveInstance(); W.tick(0.1, 3)
if not panel:IsShown() then sc.Open("stats"); W.tick(0.1, 2) end
c.tab = "stats"; ns.StatCalc_Render(); W.tick(0.1, 2)
box = sc.Drawn().boxes["sv:crit"]
if box then
  box:SetFocus()
  W.enterInstance("raid", 16); W.tick(0.1, 3)
  check("K3 walking into a raid with the box focused: she keeps typing", box:HasFocus())
  box:ClearFocus()
  W.leaveInstance(); W.tick(0.1, 3)
else
  check("K3 (setup) the box is drawn again after the key", false)
end
return R
end
'''

AURAS = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { "[F2] " .. name .. ((ok or extra == nil) and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local targetOn = false
local UE0 = UnitExists
UnitExists = function(u) if u == "target" then return targetOn end return UE0(u) end
L.startup(); W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 3)
local ns = rawget(_G, "XayaUI_NS")
if not ns then check("(sanity) core loaded", false); return R end
ns.rules = {}
local function mk(nm, f)
  local r = ns.NewRule(); r.name = nm; r.enabled = true
  r.visual.enabled, r.visual.kind, r.visual.w, r.visual.h = true, "spellicon", 32, 32
  r.visual.trigger = "buffActive"; r.sound.enabled = false
  f(r); ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r; return r
end
local BUFFS = {}
for i = 1, 3 do BUFFS[i] = mk("buff " .. i, function(r) r.useBuff, r.buffID, r.buffState, r.cdState = true, 8100 + i, "present", "none" end) end
ns.MarkDirty(); W.tick(0.1, 20)
local D = ns.AuraDisplay
local function owned() local n = 0; for _, r in ipairs(BUFFS) do if D and D.OwnerOf and D.OwnerOf(r) == true then n = n + 1 end end; return n end
check("(setup) the game's aura container draws the three buff displays", owned() == 3, owned())
for i = 1, 3 do W.addAura("player", { spellId = 8100 + i, duration = 600 }) end
W.tick(0.1, 5)
local function log() return type(CueRulesDB.errorLog) == "table" and CueRulesDB.errorLog or {} end
local function dump() local t = {}; for _, e in ipairs(log()) do t[#t + 1] = tostring(e.code) .. " " .. tostring(e.msg):sub(1, 160) end; return table.concat(t, " || ") end
local function errs() local t = {}; for i = 1, #W.errors do t[#t + 1] = tostring(W.errors[i]):sub(1, 200) end; return table.concat(t, " | ") end
W.enterInstance("party", 8); W.startKey(503, 10, { 9, 10 }); W.tick(0.1, 10)
check("(sanity) in the key between pulls: auras hidden, no combat lockdown", W.aurasSecret() and not InCombatLockdown())
-- P1 a rule edit: the container build runs 1 s later (AuraDisplay.lua QueueBuild), out of lockdown
BUFFS[2].visual.w = 36; ns.MarkDirty(); W.tick(0.1, 20)
check("P1 a rule edited between pulls in a key (the containers rebuild): no Lua error, nothing recorded", #W.errors == 0 and #log() == 0, errs() .. " || " .. dump())
check("P1 ...the container still draws the three displays", owned() == 3, owned())
-- P2 the mover opened and closed (AuraDisplay's ToggleUnlock hook: SyncLive out of lockdown)
if ns.ToggleUnlock then pcall(ns.ToggleUnlock); W.tick(0.1, 3); pcall(ns.ToggleUnlock); W.tick(0.1, 3) end
check("P2 the mover opened and closed between pulls in a key: no Lua error, nothing recorded", #W.errors == 0 and #log() == 0, errs() .. " || " .. dump())
-- P3 a target change (the container's UpdateAllAuras)
targetOn = true; W.fire("PLAYER_TARGET_CHANGED"); W.tick(0.1, 3)
check("P3 a target change between pulls in a key: no Lua error, nothing recorded", #W.errors == 0 and #log() == 0, errs() .. " || " .. dump())
W.completeKey(); W.leaveInstance(); W.tick(0.1, 5)
return R
end
'''

TDLIST = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { "[T-1] " .. name .. ((ok or extra == nil) and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local S = W.S
local targetOn = false
local UE0 = UnitExists
UnitExists = function(u) if u == "target" then return targetOn end return UE0(u) end
-- the game's other documented reading of the aura list while auras are hidden (N12.1.0 06-18: "will return a secret vector"; the
-- stand-in's own choice is an error, spec 2.2 open question 10): a hidden value whose real type is table, for your target's debuffs
local GUA0 = C_UnitAuras.GetUnitAuras
C_UnitAuras.GetUnitAuras = function(unit, filter, ...)
  if unit == "target" and W.aurasSecret() then return S.newTable({ { spellId = 350001 }, { spellId = 350002 } }, "A") end
  return GUA0(unit, filter, ...)
end
-- two of your debuffs, each on a lit Cooldown Manager icon (the target's debuffs: Blizzard's buff viewer rebinds on target change)
local function icon(spellID)
  local fr = { wasSetFromAura = true, cooldownInfo = { spellID = spellID } }
  fr.GetSpellID = function() return spellID end
  fr.IsShown = function() return true end
  fr.IsVisible = function() return true end
  return fr
end
local kids = { icon(350001), icon(350002) }
BuffIconCooldownViewer = { IsVisible = function() return true end, IsShown = function() return true end, GetChildren = function() return unpack(kids) end }
L.startup(); W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 3)
local ns = rawget(_G, "XayaUI_NS")
if not ns then check("(sanity) core loaded", false); return R end
W.RemoveAuraContainer()   -- (XayaUI draws these displays itself; the combat engine records XUI-W002 once, declared below)
ns.rules = {}
local function mk(nm, id)
  local r = ns.NewRule(); r.name = nm; r.enabled = true
  r.visual.enabled, r.visual.kind, r.visual.w, r.visual.h = true, "spellicon", 32, 32
  r.visual.trigger = "condition"; r.sound.enabled = false
  r.cdState, r.buffState = "none", "none"
  r.extra = { list = { { type = "targetDebuff", spellID = id, unit = "target", state = "yes" } } }
  ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r; return r
end
local A, B = mk("my debuff A", 350001), mk("my debuff B", 350002)
ns.MarkDirty(); W.tick(1 / 60, 30)
local framesOf = ns.VisualProbeState and ns.VisualProbeState()
local function shown(r) local fr = framesOf and framesOf[r]; return fr and fr:IsShown() and true or false end
W.enterInstance("party", 8); W.startKey(503, 10, { 9, 10 }); W.tick(0.1, 5)
W.enterCombat(); W.tick(0.1, 5)
targetOn = true; W.fire("PLAYER_TARGET_CHANGED"); W.tick(1 / 60, 10)
W.fire("UNIT_AURA", "target", W.payload({ isFullUpdate = true })); W.tick(1 / 60, 10)
check("(sanity) in the key, in combat: your debuffs on the target are a hidden list", W.aurasSecret() and S.isHidden(C_UnitAuras.GetUnitAuras("target", "HARMFUL|PLAYER")))
check("1. both of your debuffs are lit on their Cooldown Manager icons: both displays show (the second row of the same step reads the shared"
  .. " list too)", shown(A) and shown(B), tostring(shown(A)) .. "/" .. tostring(shown(B)))
local n, t = 0, {}
for _, x in ipairs((L.lineHook and L.lineHook.sites) or {}) do if tostring(x.site):find("Triggers.lua", 1, true) then n = n + (x.n or 1); t[#t + 1] = tostring(x.rule) .. " " .. tostring(x.site) end end
check("2. no misuse of the hidden list in Triggers.lua (no same-type '==' on it: the line hook found none)", n == 0, table.concat(t, ", "))
W.leaveCombat(); W.tick(0.1, 5); W.completeKey(); W.leaveInstance(); W.tick(0.1, 5)
return R
end
'''

STATCALC_ON = {"XayaUI_Bonus": {"XayaUIBonusDB": {"storeVersion": 1, "characterToolkit": {"enabled": True}}}}


def session(src, folders, saved):
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in folders}, "saved": saved}))
    res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(src, world, loader)
    return [(res[i][1], res[i][2]) for i in range(1, len(res) + 1)], [str(world.errors[i]) for i in range(1, len(world.errors) + 1)]


def main():
    all_folders = H.find_addons()
    out, errs = [], []
    o, e = session(STATCALC, all_folders, STATCALC_ON); out += o; errs += e
    rules = {k: v for k, v in all_folders.items() if k in ("XayaUI", "XayaUI_Rules", "XayaUI_Options")}
    o, e = session(AURAS, rules, {}); out += o; errs += e
    o, e = session(TDLIST, rules, {}); out += o; errs += e
    bad = 0
    for name, ok in out:
        print(("PASS " if ok else "FAIL ") + str(name)[:900])
        bad += 0 if ok else 1
    for x in errs:
        print("ERROR in the game stand-in:", x[:600])
    print("EXPECT_ERRORS XUI-W002 1")   # (T-1 session: W.RemoveAuraContainer() above, on purpose; Combat/AuraDisplay.lua records it once)
    print("%d checks, %d failed, %d Lua errors" % (len(out), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
