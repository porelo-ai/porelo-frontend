# F527 — A Silent Copy Matches What The Person Actually Saw

```json
{
  "$schema": "issue-1.json",
  "id": "F527",
  "title": "A Silent Copy Matches What The Person Actually Saw",
  "state": "Analyzed",
  "size": "S",
  "priority": "High",
  "rank": 99,
  "blockedBy": [],
  "covers": "A task's silent clipboard write matches the text the person saw and dragged, not text the task hid in its buffer or repainted under the gesture; or no task write is silent.",
  "openQuestions": 1
}
```

**Why this size.** S: dropping the silent path takes code out of the session and its terminal widget and the tests
over it, adds one test, and words the decision again; no contract another repository reads. Keeping the path and
making it match what was drawn is M: a read of the cells as drawn against the theme, a per-frame record of the lines on
screen, a settle time, and their tests.

**What must be true.** A task's clipboard write (OSC 52) goes through without a word only when its text is what the
person saw and meant to copy with their drag, not merely what the task's own buffer held under the drag; whatever the
task did to the screen during or right after the gesture to make a different text match is asked about instead.

## The contract today

- A task's terminal lets one OSC 52 write onto this computer's clipboard silently only if it equals the text the
  person just dragged across in that terminal, read from the window's own buffer at the release, once, within two
  seconds. Every other write is held and shown in a bar under the terminal with its size and a preview that shows
  hidden characters, and is copied only on *Copy*.
- The drag counts only when one pointer pressed with the main button alone moved on the screen to another cell and was
  let go, the task did not hear the mouse at the press or the release, and the buffer lines under the gesture were the
  same objects with the same characters at the release as at the press. Another button, a cancel or the keyboard
  leaving during the gesture ends it; a key (also one an input method takes while composing), any text the terminal
  sends, a new press, the keyboard leaving or the session's end after it ends the allowance.
- The dragged text keeps a gap the cursor skipped as the space it shows; only plain spaces at a line's end are
  dropped, so any control in the write that the screen did not show holds it.

## What the code shows

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

- **Recommended: no task write is silent.** Every OSC 52 write is held and asked about in the bar under the terminal.
  This removes the whole class of mismatch, closes the staged write, which matching cannot, and costs no honest
  program anything, since none can answer this window's drag. Its cost is one click on *Copy* for a write that today
  goes through, which only a program guessing the selection gets.
- `lib/src/app/session.dart`: `_copied` holds every write that passes its checks; `_drag`, `ownKey`, `dragged`,
  `pressed`, `lostFocus`, `_asCopied` and `_silentAfterDrag` go, and with them the session's clock (`sessionClock`,
  `_now`), which only the drag reads.
- `lib/src/ui/session_terminal.dart`: `SessionTerminal` keeps drawing the terminal and the bar; the `Listener`, the
  focus watch, the keyboard handler, `_Drag` and `_Lines` go. Its four users (`session_view.dart`,
  `new_machine.dart` twice, `unlock_terminal.dart`) are unchanged, and every one of their terminals asks.
- Red first, in `test/app/session_clipboard_test.dart`: a write of exactly the text just dragged across, in a
  terminal whose task does not hear the mouse, is held; red against today's silent path. The drag tests in it and in
  `test/ui/session_terminal_test.dart` go; the bar's tests and the held-write tests stay. In
  `test/ui/drive_step_test.dart` the drive terminal's drag ends in the bar instead of a copy.
- `doc/decisions.md`, *A task's program may write this computer's clipboard, never read it*: every write is asked
  about. A changelog entry under *Changed*.
- **If the silent path is kept** (M): the widget reads the dragged cells as drawn (above) and keeps the per-frame
  record with a settle time of about half a second before the release; unit tests over a fake terminal for each
  hiding attribute, contrast threshold and blank code point, and widget tests that pump frames for each repaint
  timing. The staged write stays open and goes into the decision as an accepted risk.

## Acceptance

- A write of exactly the text the person just dragged across is held and copied only on *Copy*; seen red against
  today's silent path.
- A write from tmux's copy mode, the person's own copy keys and the paste keys behave as today.

## Open questions

- Keep a silent path at all, made to match what was drawn with a settle time and the staged write accepted as a risk,
  or ask about every copy a task makes, as recommended?

## To be checked

- Measure in a task on Linux and on Windows that a drag with Porelo's tmux never takes the silent path today, so that
  dropping it changes nothing an honest program does.
