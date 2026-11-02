# Minimap icon: restore the crop (build 0.5.65, fork: main)
Logged 2026-11-02-2158 UTC. Issue #275. Session: https://claude.ai/code/session_014bN6tT2RgkgAqnny8XmpAA

Error in 0.5.64 (mine): my edit put a comment before SetTexCoord on the same line, so the 0.08 to 0.92 crop was commented out. 0.5.65 restores it. Lesson: when editing a line that holds several statements, put the comment last. Not tested in game.
