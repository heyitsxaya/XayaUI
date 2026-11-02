# Four personal sounds added to the sound list (XayaUI 0.5.73, fork: main)
Logged 2026-11-02 23:03 UTC.

Xaya sent five .ogg files: belltreechime, flame_sigil, letfly, resource_overcap, soul_barrier ("put these into our media files"). letfly.ogg was byte-identical (md5 c02f5eca7fd137a8680565bc5d7fafff) to the file already in Media\Audio on the local machine and on Drive, so it was left alone. The other four were copied to Media\Audio\ (local addon folder and Drive) and listed in LocalSounds.lua as "[Local] <name>", the same way as letfly. The audio files are not in git (audio is never committed); the list entries are, and an entry only shows up in the dropdown on a machine where the file exists. Needs a full game restart (not /reload) before the client can play them. Not tested in game.
