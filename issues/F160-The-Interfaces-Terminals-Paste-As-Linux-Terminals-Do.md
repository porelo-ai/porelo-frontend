# F160 — The Interface's Terminals Paste As Linux Terminals Do

**Status:** Accepted.

**Order.** Early: every secret now goes through these terminals.

**What must be true.** Every terminal in the interface takes `Ctrl+Shift+V` and `Shift+Insert` as
paste in addition to `Ctrl+V`, and names the paste shortcut beside the terminal.

## Why

The sign-in and unlock terminal (`unlock_terminal.dart`) pastes only on `Ctrl+V`; the standard
Linux terminal shortcut `Ctrl+Shift+V` does nothing, so pasting a sign-in code or secret with it
fails silently.

## Acceptance

- `Ctrl+Shift+V`, `Shift+Insert` and `Ctrl+V` all paste the clipboard into the interface's
  terminals, and the shortcut is named beside the terminal.
- Seen to fail: with `Ctrl+Shift+V` or `Shift+Insert` removed from the key map, pressing that
  shortcut sends no clipboard text into the terminal.

## To be checked

- Whether the session terminal in `session_view.dart` has the same key handling as
  `unlock_terminal.dart`.
