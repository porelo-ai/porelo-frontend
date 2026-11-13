# F527 — A Silent Copy Matches What The Person Actually Saw

```json
{
  "$schema": "issue-1.json",
  "id": "F527",
  "title": "A Silent Copy Matches What The Person Actually Saw",
  "state": "Review",
  "size": "S",
  "priority": "High",
  "rank": 99,
  "blockedBy": [],
  "covers": "No task write to the clipboard is silent: every OSC 52 write, also one of exactly the text the person just dragged across, is held and asked about in the bar under the terminal."
}
```

**Why this size.** S: dropping the silent path takes code out of the session and its terminal widget and the tests
over it, adds one test, and words the decision again; no contract another repository reads.

**What must be true.** A task's clipboard write (OSC 52) never goes through without a word, not even one of exactly
the text the person just dragged across: a task cannot make a text match the drag, by hiding it in its buffer or
repainting it under the gesture, and have it land on the clipboard unasked.

## Decided

- No silent path: every copy a task makes is asked about in the bar. The silent path applied only while the task did
  not hear the mouse, so no program in it knew what was dragged and a matching write was a guess, which is the staged
  write no reading of the screen can tell apart; dropping it is the safer and the smaller change. Keeping the path,
  matched to what was drawn, would be M (see *What the code showed before the change*).

## What the code showed before the change

- **Who the silent path serves.** It applies only while the task does not hear the mouse
  (`Session.dragged`, `_SessionTerminalState._pressed` in `lib/src/ui/session_terminal.dart`). Then the drag is
  this window's own selection, which no program in the task is told of; so no program sends a write that answers it.
  A matching write is a coincidence or a guess. Porelo's tmux, with the mouse on, gets the drag itself and its
  copy-mode write is asked about already. On Windows the pseudoconsole keeps the mouse mode at none, but tmux then
  gets no drag either.
- **Hidden glyphs, as the renderer draws them** (`packages/xterm/lib/src/ui/painter.dart`, `paintCellForeground` and
  `paintCellBackground`). Concealed (SGR 8) sets a flag the painter never reads: such text is drawn plainly. Blink is
  drawn steadily. Faint is drawn at half opacity. Inverse swaps foreground and background. What does hide a glyph:
  a foreground equal or close to the background it is drawn on (the theme's, a palette colour or any RGB, also after
  inverse and with faint), which takes a contrast threshold, not equality; a code point of width zero or one drawn
  blank (U+200B, U+3164, U+2800 and the like), which still takes a cell; and a glyph wider than its cell partly
  covering its neighbour. The cell after a wide character is neither drawn nor read (`copiedText` in
  `lib/src/ui/terminal_copy.dart` skips it as the painter does).
- **Counting cells as drawn.** `copiedText` reads code points only. A read as drawn would take each cell's
  `CellData` (`BufferLine.getCellData`) and the view's `TerminalTheme` and palette, which only the widget holds, and
  read a cell as a space when its glyph shows nothing: contrast under a threshold, a blank code point, or concealed
  (kept blank too, in case a later renderer honours it). The widget would then hand the session the texts as drawn.
- **What was last drawn.** Nothing in the terminal says when a line changed: `Terminal` notifies on every write and a
  `BufferLine` has no version. The widget can know the last frame: a post-frame callback (`SchedulerBinding`, with the
  frame's timestamp) runs right after the paint, before any further write, so the buffer then is what was drawn. A
  record kept per frame of the lines on screen (identity, code points, colours, flags) and the time each last
  changed lets the release require that the lines under the gesture are the ones drawn and have stood unchanged for a
  settle time. That reads every cell on screen each frame the terminal draws, about ten thousand on a large window.
  Drags over a line inside that time (a spinner, streaming output, a status line) go to the bar. The release is not
  delayed.
- **The press-time snapshot.** It is taken when the press is handled, so a write that arrived after the last frame and
  before the press is in it, a gap of under one frame that a task cannot aim at, since it does not hear the mouse.
  Lines the gesture ends on outside the window the snapshot covers are refused already (`_Lines.unchanged`).
- **A staged write cannot be told apart.** When the screen plainly showed a text, stably, and the person dragged
  across it, a write of that text is the same bytes whoever sent it and why. No settle time or read as drawn closes
  it: the clipboard is then silently replaced with text the person saw and selected but did not ask to copy, and a
  later paste runs it.

## Plan

Built:

- `lib/src/app/session.dart`: `_copied` holds every write that passes its checks (the clipboard selection, not empty,
  not a read, at most a megabyte of base64). `_drag`, `ownKey`, `dragged`, `pressed`, `lostFocus`, `_asCopied`,
  `_silentAfterDrag`, the session's clock (`sessionClock`, `_now`, the constructor's `clock`) and `_typed` are gone;
  the terminal's output goes straight to `type`.
- `lib/src/ui/session_terminal.dart`: `SessionTerminal` is a stateless widget drawing the `TerminalView` with the
  window's own copy keys (`terminalShortcuts`, copying as shown with `copiedText`); the `Listener`, the focus watch,
  the keyboard handler, `_Drag` and `_Lines` are gone. Its four users (`session_view.dart`, `new_machine.dart` twice,
  `unlock_terminal.dart`) are unchanged.
- Red first, `test/ui/session_terminal_test.dart`: a real drag across `copy me` in a terminal whose task does not hear
  the mouse, then a write of `copy me`, is held and copied only on *Copy*; seen red against the silent path with
  `['copy me']` copied at once.
- The tests of the silent path went: 19 unit tests in `test/app/session_clipboard_test.dart` and 22 widget tests (all
  20 in `test/ui/session_terminal_test.dart`, two in `test/ui/task_terminal_test.dart`). The held-write tests stay,
  those that dragged first now without the drag; the bar's tests and its preview stay. In
  `test/ui/task_terminal_test.dart`, `test/ui/drive_step_test.dart` and `test/ui/terminal_paste_test.dart` (the
  session, sign-in and vault terminals) a drag and a write of its text end in the bar, copied on *Copy*.
- `doc/decisions.md`, *A task's program may write this computer's clipboard, never read it*: every write is asked
  about. The changelog's OSC 52 entry under *Unreleased* says so.

## Acceptance

- A write of exactly the text the person just dragged across is held and copied only on *Copy*; seen red against
  the silent path.
- A write from tmux's copy mode, the person's own copy keys and the paste keys behave as before.

## To be checked

- Measure in a task on Linux and on Windows that a copy from Porelo's tmux is asked about as before, so that dropping
  the silent path changed nothing an honest program does.
