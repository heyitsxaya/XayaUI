# Actions > "Speak it" was silent: the old SpeakText argument order (core 0.6.38; fork: main)
Logged 2026-11-04 22:02 UTC. Session branch `claude/cool-ramanujan-ewx8e5`. Found while checking #375 (a speech cue's sound channel,
Insivius). Nothing here has run in the game.

## Game API (V2)
- `C_VoiceChat.SpeakText(voiceID: number, text: cstring, rate: number, volume: number, overlap: bool = false)` ·
  SecretArguments=AllowedWhenTainted (`docs/reference/api/namespaces.md:5450`). No destination and no sound channel.
- `Enum.VoiceTtsDestination` is not in `docs/reference/api/enums.md` (12.1.5). `Enum.TtsVoiceType` is (`Standard` = 0,
  `Alternate` = 1; `enums.md:13779`). `C_TTSSettings.GetVoiceOptionID(voiceType)` → voiceID (`namespaces.md:4611`).

## Defect
`XayaUI/Actions.lua` (DoChat, message type TTS) called `SpeakText(vid, msg, Enum.VoiceTtsDestination and ... or 1, 0, 100)`: the old
(voiceID, text, destination, rate, volume) order. With no `Enum.VoiceTtsDestination` that is rate 1 and volume 0: silent. The speech
cue (`Sound.lua` `ns.Speak`) already used the 12.x order.

## Fix
The action speaks through `ns.Speak({ value = msg, voice = <the game's Standard voice>, rate = 0, ttsVolume = 100 })`: the 12.x
order, the Standard voice when it is installed (else the first installed voice, as the cue does), nothing when no voice is installed.

## #375 (no change made; for Xaya / Insivius)
A speech cue cannot be given a sound channel: `SpeakText` has none (above). The game plays text-to-speech on its own output; the cue
already has its own volume (0-100) and rate. INFERENCE (not checked in game): the game's Master volume may still scale it.

## Scope (V4)
`git grep SpeakText`: `XayaUI/Sound.lua:143` (ns.Speak, correct), `XayaUI/Actions.lua` (this fix). No other caller.

## Tests
- New `tests/action_tts_run.py` (7): the action speaks once, in the 12.x order (rate 0, volume 100), the Standard voice (7) when
  installed, the first installed voice when it is not, without the settings namespace, and nothing with no voice installed. On the
  old Actions.lua: 5 FAIL (rate 1 / volume 0; the voice not checked against the installed ones).
- `tests/action_glow_run.py` (34), `tests/engine_text_run.py`, `tests/timing_run.py`: all passed.
