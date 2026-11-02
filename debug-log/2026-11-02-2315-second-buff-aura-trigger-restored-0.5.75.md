# Second Buff / Aura trigger can be added again (XayaUI 0.5.75, fork: main, issue #288)
Logged 2026-11-02 23:15 UTC.

Xaya: "you should still be allowed to add another aura trigger"; a tester posted "Can no longer track multiple buffs" (Add a trigger list showed Aura: Target Debuff etc. but no Buff / Aura). Cause: 0.5.55 (#264) set hideFromMenu on the buffAura row; extra aura IDs on the built-in trigger are ANY-of only, so ALL-of buffs became impossible to build. Fix: Triggers.lua AddChoices offers buffAura (label "Buff / Aura (another)") whenever ns.BuffUsed(rule); the first aura still goes to the built-in section. Saved rules, the Duplicate icon, and evaluation are unchanged. USER-GUIDE.md section on several auras updated. Verified: Lua syntax check only. Not tested in game.
