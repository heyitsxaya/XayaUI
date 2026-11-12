# Stat Calculator on main: in-game checks (Bonus Features 0.6.45, 2026-11-12)

For Xaya or a tester. Main has no XayaUI Dev Assist, so these are written steps rather than `/xui dev qa` walkthroughs. Each step says what to do and what you should see. Every step is **UNVERIFIED IN GAME** until someone runs it. The offline tests (tests/char_stat*_run.py, char_statcalc*_run.py, char_spells*_run.py, char_gear_icons_run.py, statcalc_*_run.py) use a stand-in of the game. They do not prove in-game cost, taint or behavior.

Source: REQUEST-LOG A24 #10 (her words: "Self-contained but under Bonus Features parent addon folder") and #11. The build is `XayaUI_Bonus` on branch `claude/stat-calculator-main`, which holds only the Stat Calculator.

When a step fails, write down its number, what you saw and a screenshot, and run `/xui bug` if there was a Lua error.

## A. Install and off by default

1. Delete your old `AddOns\XayaUI_Bonus` folder. Copy `XayaUI`, `XayaUI_Bonus`, `XayaUI_Options` and `XayaUI_Rules` from the branch into `AddOns`, then `/reload`.
   **Expect:** the game's AddOns list shows **XayaUI Bonus Features** (version 0.6.45) under XayaUI. There is no Lua error at login.
2. Fresh settings only, if you have never used the Stat Calculator: open the character window (C).
   **Expect:** no Stat Calculator panel, and no **Stat Calc** button anywhere on the character window. That button belongs to Improved Character Display, which is not on main.
3. Click the XayaUI minimap button.
   **Expect:** the list has no **Stat Calculator** row while the Stat Calculator is off.
4. Type `/xui stats status`.
   **Expect:** one chat line: `Stat Calculator: off, panel on, spell math off (0 spells), converter present.`

## B. Settings carried over from the QA build

5. Only if you used the Stat Calculator on `qa-installer-branch`: before step 1, note its side (Left / Right), text size and heights (Bonus Features > Stat Calculator > Panel > Layout). After step 1, open `/xui` > **Bonus Features** > **Stat Calculator**.
   **Expect:** the same switch state, side, text size and heights as on QA. Nothing was reset. The settings live in `XayaUIBonusDB.characterToolkit`, as on QA.

## C. Settings page

6. `/xui` > top tab **Bonus Features**.
   **Expect:** the tab shows one entry, **Stat Calculator**, with a tick box. It has no Enhanced Tooltips, Data Panels or Utilities entries.
7. Tick **Stat Calculator**.
   **Expect:** **Panel** and **Spell Math** appear under it, each with its own tick box. Panel is ticked and Spell Math is not. The intro text says the panel opens with the character window when you left it open, or on its own from the minimap button and `/xui stats`. It does not mention a Stat Calc button.
8. Close the settings window.

## D. Docked with the character window

9. Open the character window (C).
   **Expect:** the Stat Calculator opens docked beside it, on the right by default. Its header shows "Equipped <ilvl>" on the left and "Max (bags) <ilvl>" on the right. The tabs are Stats | Gear | Ability Scaling.
10. Close the character window.
   **Expect:** the panel closes with it.
11. Open the character window again, then click the panel's own close button (X).
   **Expect:** the panel closes and the character window stays open. Close and reopen the character window: the panel stays closed (the closed state is remembered).
12. With the character window open, type `/xui stats`.
   **Expect:** the panel opens docked beside the window. Type `/xui stats` again: it closes.

## E. On its own (minimap row, /xui stats, Esc)

13. Close the character window. Click the XayaUI minimap button > **Stat Calculator**.
   **Expect:** the panel opens on its own in the middle of the screen (or where you last dragged it).
14. Drag the panel by its title and release it. Close it and open it again from the minimap row.
   **Expect:** it opens where you left it.
15. With the panel open on its own, press **Esc** once.
   **Expect:** the panel closes, as other game windows do. Open the character window: the panel does **not** come back docked (Esc counted as a close).
16. Open the panel on its own. Open your bags and the world map.
   **Expect:** the panel sits on the same layer as the game's normal windows. It does not float above the map or the bags as a dialog would.

## F. Keyboard (V29)

17. Open the panel on its own, Stats tab. Click a stat's **Change** box (for example Critical Strike) and type a number, without pressing Enter.
   **Expect:** the digits go into the box. Press your **screenshot key**: a screenshot is taken. Press a **movement key**: you move.
18. Click the Change box again, then press **Esc** once.
   **Expect:** the box lets go of the keyboard and the panel stays open. Press **Esc** again: the panel closes.
19. Click a Change box, then press **Enter**.
   **Expect:** the new value shows under the number (green when better, red when worse), and the box lets go of the keyboard. Your movement keys work at once.

## G. Combat (V26, "Hide silently")

20. Open the character window with the panel docked. Attack a training dummy.
   **Expect:** the panel hides as combat starts, with no chat message. The character window itself stays open, and you can still open and close it in combat.
21. In combat, type `/xui stats` and click the minimap button.
   **Expect:** nothing opens and nothing is said in chat. The minimap list opened in combat has **no Stat Calculator row**.
22. Leave combat with the character window still open.
   **Expect:** the panel comes back docked, with fresh numbers. The minimap list has the row again.
23. Open the panel on its own (window closed), then enter combat.
   **Expect:** it hides. After combat it comes back on its own, where it was.
24. Click a Change box (keyboard focus in it), then enter combat.
   **Expect:** the box lets go of the keyboard as combat starts. Your keys work in combat.
25. Open the minimap list **before** combat and keep it open while combat starts.
   **Expect (known limit, reported):** a list that was already open keeps its Stat Calculator row until it closes (core builds the rows when the list opens). Clicking the row in combat does nothing. Fixing this needs a change to core (`XayaUI/MinimapButton.lua`).

## H. Mouse and cost (V27)

26. With the panel closed, click, right-click and camera-drag where it usually sits.
   **Expect:** every click and drag reaches the game. A closed panel takes no mouse input.
27. Stand in a busy place (a city, or a raid with the panel closed) for a minute with the Stat Calculator on but its panel closed. If you have a CPU profiler addon, read XayaUI_Bonus.
   **Expect:** close to zero CPU while the panel is closed. With the panel closed it listens only to the start and end of combat and to spec and level changes.

## I. Switching off

28. Untick **Stat Calculator** in Bonus Features.
   **Expect:** the panel closes, the minimap row leaves the list, and opening the character window shows nothing extra. `/xui stats` says "Stat Calculator is off. Turn it on in Bonus Features > Stat Calculator (or /xui stats on)."
29. Switch **XayaUI Bonus Features** off in the game's AddOns list, then `/reload`.
   **Expect:** no Bonus Features tab and no minimap row. `/xui stats` opens nothing, and every other part of XayaUI works. Known core text issue (reported, not changed): core's one-line answer names **XayaUI QoL** as the owner of `/xui stats`, because its command list (`XayaUI/Modules.lua` `ns.MODULES`) predates this build.

## Open points for Xaya (reported, not built)

- **No Stat Calc button on main.** The panel opens with the character window (when left open), from the minimap row and from `/xui stats` (A24 #10 (d), as read).
- **Right-column rows and the E? mark (A24 #10 (a), (b)).** These belong to Improved Character Display, which is not on main. As asked, she is asked again after her test on main.
- **Profiles.** XayaUI Bonus Features registers no profile part on main, and the Stat Calculator's settings were not in Bonus's profile part on QA either. Adding one is her choice.
- **Core text (needs core, not changed).** `XayaUI/Modules.lua` `ns.MODULES` lists `stats` under XayaUI QoL and `notes / calc / data` under Bonus. `XayaUI/DebugRecord.lua` XUI-E005 says "Lua error in XayaUI Bonus Features (tooltips, notepad, data panels, calculator)". See also step 25.
