# Stat Calculator on main: in-game checks (Bonus Features 0.6.46, 2026-11-12)

For Xaya or a tester. Main has no XayaUI Dev Assist, so these are written steps rather than `/xui dev qa` walkthroughs. Each step says what to do and what you should see. Every step is **UNVERIFIED IN GAME** until someone runs it. The offline tests (tests/char_stat*_run.py, char_statcalc*_run.py, char_spells*_run.py, char_gear_icons_run.py, statcalc_*_run.py, gate_statcalc_main_run.py) use a stand-in of the game. They do not prove in-game cost, taint or behavior, or how the game's AddOns list looks.

Source: REQUEST-LOG A24 #10 (her words: "Self-contained but under Bonus Features parent addon folder"), #11, #12 and #13. Since Bonus 0.6.46 (A24 #13, the option she chose: "XayaUI_Bonus keeps only a tiny loader: the on/off switch, settings page entry, /xui stats and the minimap row. The calculator code moves to XayaUI_Bonus_StatCalculator, shown in the AddOns list under Bonus Features as 'load on demand'. Off means it is never read; on means it loads once per reload.") the build is two folders on branch `claude/stat-calculator-main`: `XayaUI_Bonus` (the switch, the settings page entry, `/xui stats`, the minimap row, the profile part) and `XayaUI_Bonus_StatCalculator` (the calculator itself, load on demand).

When a step fails, write down its number, what you saw and a screenshot, and run `/xui bug` if there was a Lua error.

## A. Install, the AddOns list, and switching the calculator off and on

Her note on this layout (A24 #13): "unsure how this will look in game -- this might not be okay". Steps 1 to 4 are there so she can look at it and decide.

1. Delete your old `AddOns\XayaUI_Bonus` folder. Copy `XayaUI`, `XayaUI_Bonus`, `XayaUI_Bonus_StatCalculator`, `XayaUI_Options` and `XayaUI_Rules` from the branch into `AddOns`, so the five folders sit side by side (`XayaUI_Bonus_StatCalculator` is its own folder next to `XayaUI_Bonus`, not inside it: the game does not read an addon folder inside another). Then `/reload`, or start the game.
   **Expect:** no Lua error at login.
2. **Look at the AddOns list.** Log out to the character select screen and click **AddOns** (bottom left), or in the game press **Esc** > **AddOns**. Find the **XayaUI** entry and open it (its arrow) if it is folded.
   **Expect (what the build declares; the look itself is UNVERIFIED IN GAME):** under XayaUI you see, among the others, **XayaUI Bonus Features** (version 0.6.46) and **XayaUI Bonus Features: Stat Calculator** (version 0.6.46), each with its own tick box, both ticked. Both files say `## Group: XayaUI`, the same group as XayaUI Bonus Features, so both are listed under XayaUI. Where exactly the Stat Calculator line sits (right under Bonus Features, or elsewhere in the XayaUI group) depends on how the game sorts a group's entries: INFERENCE that it sorts by title, which would put it right after XayaUI Bonus Features. Its tooltip (hover its name) shows its notes, and the game marks it as load on demand (in the client this can show as a note such as "Load on demand" or nothing at all until it is loaded: UNVERIFIED IN GAME). XayaUI Options has always been listed the same way (also load on demand).
   Take a screenshot of the list so she can decide whether this look is okay.
3. **Switch the calculator off and on, and /reload.** This is the Stat Calculator's own switch (not the AddOns list): `/xui` > top tab **Bonus Features** > the tick box on the **Stat Calculator** row.
   - Tick it. **Expect:** the game asks "Stat Calculator: this change takes effect after a reload. Reload now?" with **Reload** / **Later**. The page shows one line: "On after a reload: type /reload to load the Stat Calculator and list its options here." Click **Reload** (or type `/reload`).
   - After the reload, open `/xui` > **Bonus Features** > **Stat Calculator** again. **Expect:** its options are there (**Panel** and **Spell Math** under it, each with its own tick box). `/xui stats` opens the panel. The XayaUI minimap button's list has a **Stat Calculator** row.
   - Untick it. **Expect:** the same "Reload now?" question. Click **Later**: the Stat Calculator keeps working in this session (the panel still opens with `/xui stats`). Then `/reload`. **Expect:** the page shows one line: "Off: none of the Stat Calculator is read. Tick it, then /reload to load it and list its options here." `/xui stats` says "Stat Calculator is off. Turn it on in Bonus Features > Stat Calculator (or /xui stats on), then /reload." The minimap list has no Stat Calculator row.
   - The same from chat: `/xui stats on` says "Stat Calculator: saved ON. It takes effect after a reload: type /reload."; `/xui stats off` says "Stat Calculator: saved OFF. It takes effect after a reload: type /reload."
4. Optional, to see the "off means it is never read" part: with the Stat Calculator off and after a `/reload`, type `/dump C_AddOns.IsAddOnLoaded("XayaUI_Bonus_StatCalculator")`. **Expect:** `false`. Turn it on and `/reload`: **Expect:** `true`. (If you use a memory or CPU addon, XayaUI Bonus Features: Stat Calculator shows nothing while it is off.)
5. With the Stat Calculator on, untick **XayaUI Bonus Features: Stat Calculator** in the game's AddOns list and `/reload`. **Expect:** one chat line at login: "the Stat Calculator is on, but XayaUI Bonus Features: Stat Calculator is switched off in the game's AddOns list. Turn it on, then /reload." No Lua error. Tick it again and `/reload`.
6. With the Stat Calculator on, pull a training dummy and type `/reload` while it is still attacking you (the game may or may not keep you in combat through the loading screen). **Expect:** if the login is in combat, the calculator loads once combat ends and nothing of it shows until then; otherwise it loads at login as usual. UNVERIFIED IN GAME; the offline test plays it (tests/statcalc_lod_run.py, L3).
7. Fresh settings only, if you have never used the Stat Calculator: open the character window (C).
   **Expect:** no Stat Calculator panel, and no **Stat Calc** button anywhere on the character window. That button belongs to Improved Character Display, which is not on main.
8. Click the XayaUI minimap button.
   **Expect:** the list has no **Stat Calculator** row while the Stat Calculator is off.
9. Type `/xui stats status`.
   **Expect:** with it off: `Stat Calculator: off (not loaded).` With it on (after the reload): `Stat Calculator: on, panel on, spell math off (0 spells), converter present.`

## B. Settings carried over from the QA build

10. Only if you used the Stat Calculator on `qa-installer-branch`: before step 1, note its side (Left / Right), text size and heights (Bonus Features > Stat Calculator > Panel > Layout). After step 1, open `/xui` > **Bonus Features** > **Stat Calculator**.
   **Expect:** the same switch state, side, text size and heights as on QA. Nothing was reset. The settings live in `XayaUIBonusDB.characterToolkit`, as on QA.

## C. Settings page

11. `/xui` > top tab **Bonus Features**.
   **Expect:** the tab shows one entry, **Stat Calculator**, with a tick box. It has no Enhanced Tooltips, Data Panels or Utilities entries.
12. Tick **Stat Calculator** and `/reload` (Bonus 0.6.46: on takes effect after a reload, step 3).
   **Expect:** **Panel** and **Spell Math** appear under it, each with its own tick box. Panel is ticked and Spell Math is not. The intro text says the panel opens with the character window when you left it open, or on its own from the minimap button and `/xui stats`. It does not mention a Stat Calc button.
13. Close the settings window.

## D. Docked with the character window

14. Open the character window (C).
   **Expect:** the Stat Calculator opens docked beside it, on the right by default. Its header shows "Equipped <ilvl>" on the left and "Max (bags) <ilvl>" on the right. The tabs are Stats | Gear | Ability Scaling.
15. Close the character window.
   **Expect:** the panel closes with it.
16. Open the character window again, then click the panel's own close button (X).
   **Expect:** the panel closes and the character window stays open. Close and reopen the character window: the panel stays closed (the closed state is remembered).
17. With the character window open, type `/xui stats`.
   **Expect:** the panel opens docked beside the window. Type `/xui stats` again: it closes.

## E. On its own (minimap row, /xui stats, Esc)

18. Close the character window. Click the XayaUI minimap button > **Stat Calculator**.
   **Expect:** the panel opens on its own in the middle of the screen (or where you last dragged it).
19. Drag the panel by its title and release it. Close it and open it again from the minimap row.
   **Expect:** it opens where you left it.
20. With the panel open on its own, press **Esc** once.
   **Expect:** the panel closes, as other game windows do. Open the character window: the panel does **not** come back docked (Esc counted as a close).
21. Open the panel on its own. Open your bags and the world map.
   **Expect:** the panel sits on the same layer as the game's normal windows. It does not float above the map or the bags as a dialog would.

## F. Keyboard (V29)

22. Open the panel on its own, Stats tab. Click a stat's **Change** box (for example Critical Strike) and type a number, without pressing Enter.
   **Expect:** the digits go into the box. Press your **screenshot key**: a screenshot is taken. Press a **movement key**: you move.
23. Click the Change box again, then press **Esc** once.
   **Expect:** the box lets go of the keyboard and the panel stays open. Press **Esc** again: the panel closes.
24. Click a Change box, then press **Enter**.
   **Expect:** the new value shows under the number (green when better, red when worse), and the box lets go of the keyboard. Your movement keys work at once.

## G. Combat (V26, "Hide silently")

25. Open the character window with the panel docked. Attack a training dummy.
   **Expect:** the panel hides as combat starts, with no chat message. The character window itself stays open, and you can still open and close it in combat.
26. In combat, type `/xui stats` and click the minimap button.
   **Expect:** nothing opens and nothing is said in chat. The minimap list opened in combat has **no Stat Calculator row**.
27. Leave combat with the character window still open.
   **Expect:** the panel comes back docked, with fresh numbers. The minimap list has the row again.
28. Open the panel on its own (window closed), then enter combat.
   **Expect:** it hides. After combat it comes back on its own, where it was.
29. Click a Change box (keyboard focus in it), then enter combat.
   **Expect:** the box lets go of the keyboard as combat starts. Your keys work in combat.
30. Open the minimap list **before** combat and keep it open while combat starts.
   **Expect (known limit, reported):** a list that was already open keeps its Stat Calculator row until it closes (core builds the rows when the list opens). Clicking the row in combat does nothing. Fixing this needs a change to core (`XayaUI/MinimapButton.lua`).

## H. Mouse and cost (V27)

31. With the panel closed, click, right-click and camera-drag where it usually sits.
   **Expect:** every click and drag reaches the game. A closed panel takes no mouse input.
32. Stand in a busy place (a city, or a raid with the panel closed) for a minute with the Stat Calculator on but its panel closed. If you have a CPU profiler addon, read XayaUI Bonus Features: Stat Calculator (the calculator) and XayaUI Bonus Features (only its loader: nothing after login).
   **Expect:** close to zero CPU while the panel is closed. With the panel closed it listens only to the start and end of combat and to spec and level changes.

## I. Switching off

33. Untick **Stat Calculator** in Bonus Features (Bonus 0.6.46: it takes effect after a reload, step 3).
   **Expect:** "Reload now?". After the reload the panel is gone, the minimap row leaves the list, and opening the character window shows nothing extra. `/xui stats` says "Stat Calculator is off. Turn it on in Bonus Features > Stat Calculator (or /xui stats on), then /reload."
34. Switch **XayaUI Bonus Features** off in the game's AddOns list, then `/reload`.
   **Expect:** no Bonus Features tab and no minimap row. `/xui stats` opens nothing, and every other part of XayaUI works. Known core text issue (reported, not changed): core's one-line answer names **XayaUI QoL** as the owner of `/xui stats`, because its command list (`XayaUI/Modules.lua` `ns.MODULES`) predates this build.

## Open points for Xaya (reported, not built)

- **No Stat Calc button on main.** The panel opens with the character window (when left open), from the minimap row and from `/xui stats` (A24 #10 (d), as read).
- **Right-column rows and the E? mark (A24 #10 (a), (b)).** These belong to Improved Character Display, which is not on main. As asked, she is asked again after her test on main.
- **Profiles (A24 #13, her answer "Yes, include them (Recommended)"): built.** See section J.
- **Wording of the page's one line and the login message (A24 #13 build, not her text: proposed).** Off: "Off: none of the Stat Calculator is read. Tick it, then /reload to load it and list its options here."; saved on but not loaded yet: "On after a reload: type /reload to load the Stat Calculator and list its options here."; the switch's tooltip uses her option text ("Off means it is never read; on means it loads once per reload."). The AddOns list title "XayaUI Bonus Features: Stat Calculator" is also proposed.
- **Core text (needs core, not changed).** `XayaUI/Modules.lua` `ns.MODULES` lists `stats` under XayaUI QoL and `notes / calc / data` under Bonus. `XayaUI/DebugRecord.lua` XUI-E005 says "Lua error in XayaUI Bonus Features (tooltips, notepad, data panels, calculator)". See also step 30.

## J. Profiles (Bonus 0.6.46, A24 #13)

35. With the Stat Calculator on and set up (for example side Left, text size 13), `/xui` > **Profiles** > **Export**.
   **Expect:** a **Bonus Features** tick box, ticked, between Settings and Blizzard Reskin. Generate the string and copy it.
36. Change the side to Right, then **Profiles** > **Import**, paste the string.
   **Expect:** a **Bonus Features** tick box; no line saying "needs XayaUI Bonus Features". Import it.
   **Expect:** "Reload now?" (the profile question). After the reload the side is Left again.
37. With the Stat Calculator switched **off**, repeat steps 35 and 36.
   **Expect:** Bonus Features is still offered under Export and Import (the part lives in XayaUI_Bonus, which is always read). It never says "needs XayaUI Bonus Features" while XayaUI Bonus Features is installed and on.
38. If you have an older profile string from the QA build: paste it under Import.
   **Expect:** **Bonus Features** is offered (on QA the Stat Calculator's settings travel in the QoL part; the import takes them from there). Only the QoL part says "needs XayaUI QoL". After the import and the reload, the Stat Calculator has the settings from that string. Improved Character Display's slot options in it are not imported (it is not on main). The Stat Calculator's on / off switch stays as it was before the import (the string's switch is Improved Character Display's on QA, so it is not taken).
