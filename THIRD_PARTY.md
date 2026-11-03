# Third-party components

- **Ace3** libraries: LibStub in `XayaUI/Libs/`; CallbackHandler-1.0, AceGUI-3.0, AceConfig-3.0 (with its Registry/Cmd/Dialog) in `XayaUI_Options/Libs/`: BSD-licensed, copyright the Ace3 authors. Vendored unmodified from the BuzzardAuras addon's `Libs` folder (an unmodified copy of upstream Ace3 as far as we know). Upstream: https://www.wowace.com/projects/ace3. The Ace3 license text is kept in `XayaUI_Options/Libs/LICENSE-Ace3.txt`. LibStub is Public Domain (credits: Kaelten, Cladhaire, ckknight, Mikk, Ammo, Nevcairiel, joshborke).
- **Fonts** in `XayaUI/Media/Fonts/`: Fira Sans and Fira Mono (Mozilla/Carrois, SIL OFL 1.1), Lato (Łukasz Dziedzic, SIL OFL 1.1), PT Sans (ParaType, SIL OFL 1.1), Barlow (Jeremy Tribby, SIL OFL 1.1). License texts sit beside the files (`OFL-*.txt`).
- **XayaDataBlocks-1.0** (`XayaUI_Chat/Libs/` and `XayaUI_Bonus/Libs/`): XayaUI's own code, packaged as a LibStub library so both addons can carry it.
- **Texture IDs** in `XayaUI/TextureList.lua` are numeric FileDataIDs of Blizzard's own game art; no Blizzard art is redistributed.
- **Sounds**: only the CC0 pack in `XayaUI/Media/Audio/CC0` is included: 33 short cues from Kenney's "Interface Sounds" 1.0 (CC0 1.0, public domain; credit courtesy, see `XayaUI/Media/Audio/CC0/CREDITS.md`). Nothing else is included.
- **Local media, never committed**: `XayaUI/Media/Audio/BW` (from BigWigs: All Rights Reserved; several packs CC BY-NC; the Heroes voice lines are Blizzard-owned), `XayaUI/Media/Audio/PA`, `XayaUI/Media/Graphics` (extracted Blizzard UI art converted to TGA). Personal use only; do not redistribute.
- Ideas only, no code copied (a verbatim line-comparison of XayaUI's own Lua against the installed copies of these addons, run 2026-10-31, found only generic Blizzard-API idioms): BuffReminders (zerbi / Andrea Zerbini, PolyForm Shield 1.0.0), Buzzard Auras (Serina), EllesmereUI (Ellesmere, all rights reserved). The in-game "Addon Info" tab lists these credits with links.
- **QoL Elements are shelved** (stat text boxes, Cursor Tracker + At-Cursor Reminders, Buff Bars: `shelved/QoL.lua`, `shelved/CursorTracker.lua`, `shelved/CursorReminders.lua`, `shelved/Bars.lua`). No addon loads them. The Buff Bars option set was styled after EllesmereUI's Tracking Bars (ideas only); re-add that credit to the in-game tab when Buff Bars returns.


World of Warcraft and Blizzard Entertainment are trademarks of Blizzard Entertainment, Inc. This project is not affiliated with or endorsed by Blizzard.
