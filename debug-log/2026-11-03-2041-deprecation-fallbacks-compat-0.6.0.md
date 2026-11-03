# Found by the new harness: twelve calls only worked with the client setting loadDeprecationFallbacks on (XayaUI 0.6.0, fork: main)
Logged 2026-11-03 ~20:41 UTC. Not reported by a player; found by comparing every game name XayaUI uses with Blizzard's own 12.1.5 interface code (mirror github.com/Gethe/wow-ui-source, branch live, commit d07eb00, "12.1.5 (70688)"). The names below exist in 12.1.5 ONLY inside the Blizzard_Deprecated* addons, which load only when loadDeprecationFallbacks is on ("will be removed at the next expansion"). With it off, each failed silently (the calls were guarded or pcall'd):
- Chat Panel: ChatFrame_AddMessageEventFilter (filters and highlights never installed), ChatFrame_OpenChat (input area click), ChatEdit_GetActiveWindow / ChatEdit_ActivateChat / ChatEdit_DeactivateChat (fade while typing, closing the edit box on collapse, re-anchoring hooks), ChatFrame_ContainsMessageGroup (History), NUM_CHAT_WINDOWS (window list, probe).
- Rule actions Say / Yell / Group and the note-share chat line: SendChatMessage (now C_ChatInfo.SendChatMessage).
- Load condition "Boss encounter" and the note-share encounter wait: IsEncounterInProgress (now C_InstanceEncounter.IsEncounterInProgress).
- Weapon-enchant trigger: GetWeaponEnchantInfo (now C_PaperDollInfo.GetTemporaryEnchantmentInfo per slot).
- Action-slot check: HasAction fallback (C_ActionBar.HasAction was already first).
Also: the edit-box hooks were on the global copies, which Blizzard's own code never calls (it calls ChatFrameUtil directly), so they missed the game's own calls even with the setting on. They are now on ChatFrameUtil.
Fix: XayaUI/Compat.lua, current API first, old name as a last resort; every caller goes through it. The harness fails the build if any other file names a deprecated-only global.
Xaya's Config.wtf does not set loadDeprecationFallbacks (client default; the default value could not be confirmed).
Unverified in game: QA-CHECKLIST.md B8, B9, D2, D3.
