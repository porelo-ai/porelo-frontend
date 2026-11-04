# F306 — A Work Card Whose Terminal Has Ended

**Status:** Idea. Waits for the foo test.

**What must be true.** A card under *Work* whose terminal session has ended says so in its own words and offers what
can be done next; it does not show a full-width black terminal bar that holds only "Its terminal session has ended."

## Why

`TileConsole._drawn` in `lib/src/ui/tile_console.dart` shows "Its terminal session has ended." in a padded,
full-width terminal-colored container when the terminal screen is known and the session is no longer live.
This branch has no fixed terminal height or enlarge button, but it still has the black bar the promise excludes.

*Work in it by hand* in `workCommands` (`lib/src/app/commands.dart`) uses `Sessions.whyNot`
(`lib/src/app/session.dart`), which checks that the task is running and that a local command reaches its daemon,
without checking the terminal's live state. `TaskTile` in `lib/src/ui/attention_view.dart` offers that command
whenever it is available. Those files do not provide next actions based on the ended terminal's state.
The page with the *Work* cards is redesigned as a whole: this issue goes into [F353](README.md#f353).
