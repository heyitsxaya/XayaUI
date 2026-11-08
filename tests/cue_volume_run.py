"""#334 (core 0.6.19): a cue's own volume, like Speech volume. Runs the real ns.PlaySound (XayaUI/Sound.lua) against stand-in sound
calls. For the game's sound kits the volume goes to C_Sound.PlaySoundWithOptions as volumeOverride (0-1; the documented 12.1.5 call
Blizzard's own Cooldown Manager and combat audio alerts use). Sound files have no per-sound volume in the game: they play as before.
Run: python3 tests/cue_volume_run.py   (needs: pip install lupa)"""
import os, sys
from lupa.lua51 import LuaRuntime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
L = LuaRuntime(unpack_returned_tuples=True)
L.execute(r'''
CALLS = {}
REFUSE = false
function PlaySound(id, ch) CALLS[#CALLS + 1] = { fn = "PlaySound", id = id, ch = ch } return true end
function PlaySoundFile(f, ch) CALLS[#CALLS + 1] = { fn = "PlaySoundFile", f = f, ch = ch } return true end
C_Sound = { PlaySoundWithOptions = function(p) if REFUSE then error("refused") end; CALLS[#CALLS + 1] = { fn = "WithOptions", p = p } return true, 7 end }
SOUNDKIT = {}
LibStub = nil
''')
src = open(os.path.join(ROOT, "XayaUI", "Sound.lua"), encoding="utf-8").read()
ns = L.eval("{ Val = function(v) if v == nil or v == '' or v == 'none' then return nil end return v end }")
L.globals().NS = ns
L.eval("function(src) local f = assert(loadstring(src, '@Sound.lua')); f('XayaUI', NS) end")(src)
fails = []
def check(name, ok, extra=""):
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  [" + str(extra) + "]"))
    if not ok:
        fails.append(name)
def play(t):
    L.execute("CALLS = {}")
    L.execute("NS.PlaySound(" + t + ")")
    return L.eval("CALLS[1]")

c = play("{ enabled = true, source = 'kit', value = '8959', channel = 'SFX', cueVolume = 40 }")
check("a [Game] sound at 40%: played through PlaySoundWithOptions", c and c["fn"] == "WithOptions", c and c["fn"])
check("  ...with volumeOverride 0.4 and the sound kit ID", c and abs(c["p"]["volumeOverride"] - 0.4) < 1e-9 and c["p"]["soundKitID"] == 8959)
check("  ...and the cue's channel passed as before", c and c["p"]["uiSoundSubType"] == "SFX")
c = play("{ enabled = true, source = 'kit', value = '8959', channel = 'SFX' }")
check("no cue volume set (100%): plays exactly as before (PlaySound)", c and c["fn"] == "PlaySound" and c["id"] == 8959 and c["ch"] == "SFX")
c = play("{ enabled = true, source = 'kit', value = '8959', cueVolume = 0 }")
check("0%: volumeOverride 0 (silent), not ignored", c and c["fn"] == "WithOptions" and c["p"]["volumeOverride"] == 0)
L.execute("REFUSE = true")
c = play("{ enabled = true, source = 'kit', value = '8959', cueVolume = 40 }")
check("the game refuses the call: still plays, the old way (never silent by mistake)", c and c["fn"] == "PlaySound")
L.execute("REFUSE = false")
c = play("{ enabled = true, source = 'file', value = 'Interface\\\\AddOns\\\\XayaUI\\\\Media\\\\Audio\\\\CC0\\\\Kenney\\\\bong_001.ogg', cueVolume = 40 }")
check("a sound FILE: plays as before (the game has no per-sound volume for files)", c and c["fn"] == "PlaySoundFile")
opt = open(os.path.join(ROOT, "XayaUI_Rules_Options", "Editor.lua"), encoding="utf-8").read()
check("the cue's sound pane has the per-cue volume, switched off for files", "cueVolume = { type = \"range\"" in opt and 'disabled = function() return rule.sound.source ~= "kit" end' in opt)
print("FAILS: %d" % len(fails))
sys.exit(1 if fails else 0)
