#!/usr/bin/env python3
"""Offline test (core 0.6.56): D3 / #375, a Sound cue plays on its own channel, SFX by default. Xaya, 2026-11-06: "allow for the option of
speech channel override but otherwise allow sounds to be set to their own channel (generally SFX)"; told speech cannot take a channel
(C_VoiceChat.SpeakText has none): no speech override.
Checks what the game is asked to play: a new Sound cue's sound goes to the SFX channel; changed on the cue to Dialog it goes there; a cue
made before (no channel saved) still plays on Master; a new Speech cue has no channel and plays through the speech call.
Run: python3 tests/sound_cue_channel_run.py   (loads the real addons in the stand-in game, Lua 5.1 via lupa)."""
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
local played, spoken = {}, 0
PlaySound = function(kit, ch) played[#played + 1] = tostring(ch) end
PlaySoundFile = function(f, ch) played[#played + 1] = tostring(ch) end
C_VoiceChat = C_VoiceChat or {}
C_VoiceChat.GetTtsVoices = function() return { { voiceID = 1, name = "v" } } end
C_VoiceChat.SpeakText = function() spoken = spoken + 1 end
local p = ns.NewRule(); p.name = "P"; ns.NormalizeRule(p); ns.rules = { p }
local snd = ns.NewCueRule(p, "sound")
snd.sound.source, snd.sound.value = "kit", "8959"
check("a new Sound cue starts on the SFX channel", snd.sound.channel == "SFX", snd.sound.channel)
ns.PlaySound(snd.sound)
check("... and the game is asked to play it on SFX", played[#played] == "SFX", played[#played])
snd.sound.channel = "Dialog"; ns.PlaySound(snd.sound)
check("changed on the cue to Dialog: it plays on Dialog", played[#played] == "Dialog", played[#played])
local old = { enabled = true, source = "kit", value = "8959" }   -- a cue saved before: no channel
ns.PlaySound(old)
check("a cue made before (no channel saved) still plays on Master", played[#played] == "Master", played[#played])
local sp = ns.NewCueRule(p, "speech")
sp.sound.value = "hello"
check("a new Speech cue has no channel (speech takes none)", sp.sound.channel == nil, tostring(sp.sound.channel))
local n0 = #played
ns.PlaySound(sp.sound)
check("... and plays through the speech call, not a sound channel", spoken == 1 and #played == n0)
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
