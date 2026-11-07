#!/usr/bin/env python3
"""Offline test (core 0.6.56): C1, the per-spec learner also keeps the Cooldown Manager's auras and target debuffs. Xaya, 2026-11-06:
"Build it" (cost measured in the stand-in first: about 0.1 ms per read, out of combat, after login / a spec change).
Checks what is saved for the spec: its cooldowns as before, plus each aura on you (selfAura true) and each target debuff (selfAura false)
the Cooldown Manager offers, by aura ID (the first linked spell, else the spell), with the Cooldown Manager ID; an entry without an aura
or with a secret ID is left out; nothing is learned in combat.
Run: python3 tests/class_learn_auras_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))
import run as H  # noqa: E402

LUA = r'''
return function(W, L)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. ((ok or extra == nil) and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
L.startup(); W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 3)
local ns = rawget(_G, "XayaUI_NS")
local SECRET = {}
issecretvalue = function(v) return v == SECRET end
local INFO = {
  [11] = { spellID = 204021, linkedSpellIDs = { 207771 }, hasAura = true, selfAura = false },
  [12] = { spellID = 187827, linkedSpellIDs = {}, hasAura = true, selfAura = true },
  [13] = { spellID = 6789, linkedSpellIDs = {}, hasAura = false, selfAura = false },
  [14] = { spellID = SECRET, linkedSpellIDs = { SECRET }, hasAura = true, selfAura = true } }
C_CooldownViewer = { GetCooldownViewerCategorySet = function(c) if c == 0 then return { 11, 13 } elseif c == 2 then return { 12, 14 } end return {} end,
  GetCooldownViewerCooldownInfo = function(id) return INFO[id] end }
local sid = ns.CurrentSpecID()
ns.CollectCooldownSpells = function() return { { id = 187827, name = "Metamorphosis", cd = 120 } } end   -- (the stand-in has no spellbook cooldowns)
InCombatLockdown = function() return true end
local okL, why = ns.ClassLearn.Learn()
check("nothing is learned in combat", okL == nil and why == "in combat")
InCombatLockdown = function() return false end
local got, why2 = ns.ClassLearn.Learn()
check("learned the spec you are in", got == sid, tostring(got) .. " " .. tostring(why2) .. " sid=" .. tostring(sid) .. " db=" .. tostring(CueRulesDB))
local e = (CueRulesDB.classLearn.specs[sid] or {}).entries or {}
local cd, au, db = 0, {}, {}
for _, x in ipairs(e) do
  if x.kind == "cd" then cd = cd + 1 elseif x.kind == "aura" then au[#au + 1] = x elseif x.kind == "debuff" then db[#db + 1] = x end
end
check("its cooldowns are still learned", cd > 0, cd)
check("the aura on you is kept (aura 187827)", #au == 1 and au[1].id == 187827 and au[1].cdmID == nil, #au)
check("the target debuff is kept by its aura ID with the Cooldown Manager ID (207771 via 204021)", #db == 1 and db[1].id == 207771 and db[1].cdmID == 204021, #db)
check("an entry without an aura and a secret one are left out", #au + #db == 2)
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
        print(("ok  " if ok else "FAIL: ") + name)
        if not ok:
            bad += 1
    errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
    for e in errs:
        print("ERROR in the game stand-in:", str(e)[:600])
    print("%d checks, %d failed, %d Lua errors" % (len(res), bad, len(errs)))
    sys.exit(1 if bad or errs else 0)


if __name__ == "__main__":
    main()
