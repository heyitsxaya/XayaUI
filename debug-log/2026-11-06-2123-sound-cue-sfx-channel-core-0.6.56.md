# D3 / #375: Sound cues start on the SFX channel; speech has none (core 0.6.56)

Engine session 2. Her answer (QUESTIONS-engine-session.md "Her answers", D3): "allow for the option of speech channel override but otherwise
allow sounds to be set to their own channel (generally SFX)"; told speech cannot take a channel: no speech override (no emulation).
- V2: C_VoiceChat.SpeakText(voiceID, text, rate, volume, overlap) has no channel argument (12.1.5 docs, namespaces.md); PlaySound /
  PlaySoundFile take a channel name (Sound.lua already passes the cue's channel, blank = Master).
- The per-cue "Sound channel" choice already existed (Options.lua sound section). Change: Cues.lua ns.NewCueRule gives a new Sound cue the
  channel "SFX". Cues made before keep their saved value (blank = Master): changing those silently would move sounds she already tuned.
  FLAG for her: say if existing cues should move to SFX too.
- The group-level sound channel override (#372) belongs to the group page round (S3).
- Test: tests/sound_cue_channel_run.py (6 checks; 2 fail on the old code). QA B196.
- #375 (speech channel): not possible in the game's speech call; the issue gets that note.
