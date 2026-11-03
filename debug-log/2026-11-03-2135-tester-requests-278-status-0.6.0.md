# Tester request set (#278): resubmitted screenshot, status and API check (build 0.6.0, fork: main)
Logged 2026-11-03-2135 UTC. Issue: #278 (status comment added; no new issue, same seven items). Session: https://claude.ai/code/session_014bN6tVL9bjDjygA5a6XHFk

Xaya shared the Discord screenshot again (11/1/2026 21:44, "edited"). Same seven requests as #278: duration-based sound / texture cues; triggers on a buff's "unknown" value; more preloaded textures; a cue volume slider that leaves game audio alone; stun / charm / fear / sleep trigger; slow / snare / root trigger; target or focus casting an interruptible spell. No code written.

What changed since #278 was filed (0.5.67): the duration engine shipped in 0.5.98 (#314), so item 1 is built but unverified in game; the state trigger for you already covers stun, fear / charm (grouped), root, and silence (`Triggers.lua`), not asleep or slow, and not target / focus. Checked against the 12.1.5.70688 API dump: `PlaySound` has a `volumeOverride` argument (game sound kits only; file sounds have none per the wiki), the by-unit loss-of-control call is secret under restriction, and the cast `notInterruptible` flag is secret when unit-spellcast restrictions apply. The `locType` names for sleep and snare are not documented anywhere I could reach, so a probe (`/xui loc` while affected) comes before any new trigger.

Spec, per-item analysis, decision graph, confidence, seven questions: project doc `claude/XAYAUI-TESTER-REQUESTS-278-STATUS-2026-11-03.md`. Roadmap: `ROADMAP.md`, section 9.
