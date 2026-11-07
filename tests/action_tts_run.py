"""Actions > Message > Speak it (text-to-speech): an action's speech went through C_VoiceChat.SpeakText with the old argument order
(voiceID, text, destination, rate, volume). In 12.1.5 the signature is SpeakText(voiceID, text, rate, volume [, overlap])
(docs/reference/api/namespaces.md:5450) and Enum.VoiceTtsDestination no longer exists (not in docs/reference/api/enums.md), so the call
passed rate 1 and volume 0: the action was silent. Found 2026-11-04 while checking #375 (a speech cue's sound channel). Checks that the
action now speaks through the speech cue's helper (Sound.lua ns.Speak) at volume 100 and rate 0, with the game's Standard voice when it
is installed, the first installed voice otherwise, and nothing when no voice is installed.
Run: python3 tests/action_tts_run.py   Needs: pip install lupa."""
import os, sys
import sys as _sys; _sys.path.insert(0, __import__("os").path.dirname(__import__("os").path.abspath(__file__))); import xui_paths as XP  # (P4) core = XayaUI + XayaUI_Rules
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lua51 import runtime
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
L = runtime()
L.execute(r'''
fails, n = 0, 0
function check(name, cond, extra)
  n = n + 1
  if cond then print("ok:   " .. name) else fails = fails + 1; print("FAIL: " .. name .. (extra ~= nil and ("  -> " .. tostring(extra)) or "")) end
end
ns = { MarkDirty = function() end, Print = function() end, VisualFramesOf = function() return {} end, Compat = {} }
spoken = {}
VOICES = { { voiceID = 3, name = "Voice A" }, { voiceID = 7, name = "Voice B" } }
C_VoiceChat = { SpeakText = function(...) spoken[#spoken + 1] = { n = select("#", ...), ... } end, GetTtsVoices = function() return VOICES end }
C_TTSSettings = { GetVoiceOptionID = function(t) return 7 end }
Enum = { TtsVoiceType = { Standard = 0, Alternate = 1 } }   -- 12.1.5: no Enum.VoiceTtsDestination
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
PlaySoundFile = function() end; PlaySound = function() end
LibStub = function() return nil end
''')
for f in ("Sound.lua", "Actions.lua"):
    L.execute('assert(loadfile(%r))("XayaUI", ns)' % XP.core_file(ROOT, f).replace("\\", "/"))
L.execute(r'''
local rule = { name = "Speak test", actions = { start = { msgOn = true, msgType = "TTS", msg = "Shield up" } } }
ns.RunActions(rule, "start")
local c = spoken[1]
check("the action speaks once", #spoken == 1, #spoken)
check("  ...with the 12.x argument order: voice, text, rate, volume", c and c[2] == "Shield up" and c[3] == 0 and c[4] == 100, c and (tostring(c[3]) .. " / " .. tostring(c[4])))
check("  ...at volume 100, not 0 (the old call passed 0: silent)", c and c[4] == 100, c and c[4])
check("  ...in the game's Standard voice (7) when it is installed", c and c[1] == 7, c and c[1])
spoken = {}
C_TTSSettings.GetVoiceOptionID = function() return 99 end   -- a voice that is not installed on this machine
ns.RunActions(rule, "start")
check("a Standard voice that is not installed: the first installed voice (3)", spoken[1] and spoken[1][1] == 3, spoken[1] and spoken[1][1])
spoken = {}
C_TTSSettings = nil
ns.RunActions(rule, "start")
check("no text-to-speech settings namespace: still speaks, first installed voice", spoken[1] and spoken[1][1] == 3 and spoken[1][4] == 100)
spoken = {}
VOICES = {}
ns.RunActions(rule, "start")
check("no voice installed: nothing is called (no error)", #spoken == 0, #spoken)
''')
n, fails = L.eval("n"), L.eval("fails")
print("%d checks, %d failed" % (n, fails))
sys.exit(1 if fails else 0)
