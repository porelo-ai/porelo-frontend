# F160 — The Interface's Terminals Paste As Linux Terminals Do

**Status:** Implementing.
**Size:** S - one shared key map, three terminals and their widget tests.

**Order.** Early: every secret now goes through these terminals.

**What must be true.** Every terminal in the interface takes `Ctrl+Shift+V` and `Shift+Insert` as
paste in addition to `Ctrl+V`, and names the paste shortcut beside the terminal.

## Why

The sign-in and unlock terminal (`unlock_terminal.dart`) pastes only on `Ctrl+V`; the standard
Linux terminal shortcut `Ctrl+Shift+V` does nothing, so pasting a sign-in code or secret with it
fails silently.

## Plan

- **Today**, read in the code: xterm 4.0's `defaultTerminalShortcuts` on Linux and Windows are
  `Ctrl+Shift+C` copy, `Ctrl+V` paste and `Ctrl+A` select all; a `SingleActivator` matches its
  modifiers exactly, so `Ctrl+Shift+V` and `Shift+Insert` do not paste; what they send instead is
  measured by the test that goes red first. The session
  terminal (`session_view.dart`) takes `copyAsShownShortcuts` (`terminal_copy.dart`), which only
  swaps the copy. The sign-in and unlock terminal (`unlock_terminal.dart`) and the new machine's
  vault terminal (`new_machine.dart`) pass no `shortcuts`, so they take xterm's defaults. The
  session terminal's input handler (`ModifiedKeys`) sits behind the shortcuts and is not touched.
- **One key map for every terminal:** `copyAsShownShortcuts` becomes `terminalShortcuts`, which
  adds `Ctrl+Shift+V` and `Shift+Insert` as `PasteTextIntent` on Linux and Windows and keeps
  `Ctrl+V`; macOS keeps xterm's `Cmd` keys. All three terminals take it, and the unlock and vault
  terminals get `CopiesAsShown` with it, so they copy as the session terminal does.
- **The shortcut named:** one line under each terminal, from one widget in `terminal_copy.dart`:
  "Paste with Ctrl+Shift+V". No test holds the words.
- **Left as it is:** the terminal diagnosis (`terminal_diagnosis.dart`), which shows each key as it
  arrives and is not a terminal anybody types into.
- **Test, its harm:** a sign-in code or secret pasted with the Linux shortcut goes nowhere, or goes
  as a stray `Ctrl+V` to the far end. One widget test per terminal puts a text on the clipboard,
  presses each of the three shortcuts and reads what reached the session's input. Red first: today
  `Ctrl+Shift+V` and `Shift+Insert` bring nothing in all three.

## Acceptance

- `Ctrl+Shift+V`, `Shift+Insert` and `Ctrl+V` all paste the clipboard into the interface's
  terminals, and the shortcut is named beside the terminal.
- Seen to fail: with `Ctrl+Shift+V` or `Shift+Insert` removed from the key map, pressing that
  shortcut sends no clipboard text into the terminal.
