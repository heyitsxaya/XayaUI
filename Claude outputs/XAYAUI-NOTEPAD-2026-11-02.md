# XayaUI Notepad: feature writeup

Build 0.5.39 (local; not yet pushed). Date: 2026-11-02. Status: **untested in game**. Syntax-checked and run against stubbed WoW functions (migration, new, duplicate, delete, clear, restore list, all four toolbar positions, options table). Typing-triggered version saving and real frame behavior are not covered by that run.

## What it is

A floating box (QoL UI Updates > Notepad) that holds typed reminders. It holds any number of notes, never silently loses text, and has a toolbar you can place and hide.

Open it with `/xui notepad` (alias `/xui note`), the Show Notepad toggle in the options, or close it with the x on the box. It starts closed. Open or closed, position, size, and all notes are remembered across `/reload` and relogging.

## Using it

- **Move / resize / lock:** drag the title bar to move; drag the bottom-right corner to resize; the Lock button on the title bar freezes both. The border is blue while unlocked and gray while locked.
- **Typing:** click in the box to type. Mouse wheel scrolls. Esc releases the keyboard. By default, entering combat also releases it so your keybinds work (option).
- **Title bar:** shows which note you are on and how many exist (for example `Notepad 2/4`), plus the note's first line.

## Toolbar

| Button | Does |
|---|---|
| New | Adds an empty note after the current one and puts the cursor in it |
| Dup | Duplicates the current note |
| Del | Deletes the current note into the trash (no confirmation needed, because it is recoverable) |
| < and > | Previous / next note (wraps around) |
| Hist | Opens the Restore list |

Options (QoL UI Updates > Notepad > Toolbar): show or hide the toolbar; **position** Top, Bottom, Left, or Right of the box; **Only show on mouseover** (hover-reveal toggle). With hover on, the toolbar appears while the mouse is over the box, while you are typing, or while the Restore list is open. Its space stays reserved so text does not jump when it appears.

## Recovering text (memos)

Every note is stored as its own memo in `CueRulesDB.notepad.notes`, with these protections:

1. **Saved as you type.** There is no save step.
2. **Automatic versions.** A version of the note is saved after a 4-second pause in typing, when you click out of the box, when you switch notes, and on logout. A version is also saved **immediately before any single edit that removes 20 or more characters** (select-all then delete, a big cut), so the text from just before an accidental wipe is always in the list.
3. **Per-note history.** Up to 20 earlier versions per note (adjustable 5 to 50, oldest drop off first). Identical consecutive versions and blank text are not stored.
4. **Trash.** Deleted notes keep their text and history in a trash holding the last 30. Empty, untouched notes are not kept.
5. **Clear is undoable.** "Clear the current note" saves the old text as a version first.
6. **Restore list (Hist).** Two sections: *Earlier versions of this note* and *Deleted notes*. Hover a row for a preview of the full text; click to restore. Restoring a version first saves what is there now, so a restore can itself be undone. Restoring a deleted note puts it back in the note list.

## Limits and honest caveats

- Plain text only. No timed or event-triggered reminders yet (a possible follow-up).
- 8000 characters per note.
- Everything is stored in account-wide SavedVariables (`CueRulesDB`), not per character.
- Versions are kept in SavedVariables, so heavy use grows that file slightly (20 versions of 8000 characters is about 160 KB per note at the extreme).
- A crash or killed client can lose up to the last ~4 seconds of typing if no version was saved yet; the live text is written to the note on every keystroke, but SavedVariables only reach disk on `/reload`, logout, or a clean exit.
- Typing-triggered saving, the hover reveal, and the Restore list have not been exercised in the real game.

## Files

Notepad.lua (new), XayaUI.toc (load order, version), Core.lua (init call, `/xui notepad`), Options.lua (options page, QoL tree entry), README.md (feature list). Backups: `*.pre-notepad.20261102.*.bak`, `Notepad.pre-memos.20261102.lua.bak`.
