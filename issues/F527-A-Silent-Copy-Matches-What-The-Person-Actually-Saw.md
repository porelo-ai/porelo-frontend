# F527 — A Silent Copy Matches What The Person Actually Saw

```json
{
  "$schema": "issue-1.json",
  "id": "F527",
  "title": "A Silent Copy Matches What The Person Actually Saw",
  "state": "Backlog",
  "size": "M",
  "priority": "High",
  "rank": 99,
  "blockedBy": [],
  "covers": "A task's silent clipboard write matches the text the person saw and dragged, not text the task hid in its buffer or repainted under the gesture; or no task write is silent."
}
```

**Why this size.** M: the gesture, the screen read and the gate in one module and their tests, plus a decision on what
"seen" means; no contract another repository reads.

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

## What is not settled

The task writes the buffer, so the text the gate compares with is the task's text. Three ways remain to make a write
match without the person having seen that text:

- **Invisible text.** The task draws characters in the background colour, at zero intensity, concealed (SGR 8), as
  blink-off, or under other text the renderer draws on top; the person drags across what looks like blank space or a
  harmless word and the buffer holds `rm -rf ~` there. The read counts cell code points, not what was drawn.
- **A repaint between the frame the person saw and the release.** The task rewrites the lines under the pointer and
  the press-time snapshot of the lines is taken after the repaint (it is taken when the press is handled, not from
  the last frame drawn), or the task rewrites lines the gesture ends on outside the window the snapshot covers; the
  release then reads text that was on screen for less than a frame, or never.
- **A write staged ahead.** The task sends a matching write right after a repaint it timed to the person's habit
  (a prompt that always shows the same command for a drag), so the copy is "what was dragged" by construction.

## Plan

- To be read in today's code before this goes to Analyzed: the terminal's renderer (which attributes hide a glyph:
  concealed, zero alpha, foreground equal to background, blink), the gesture code in the session's terminal widget,
  and the gate in the session.
- Likely shape: the silent path compares with the text as drawn in the last frame the person could have seen before
  the release - cells whose glyph was not visibly drawn (concealed, invisible colour, covered) count as what they
  showed, and any line under the gesture repainted within a short settle time before the release voids the drag.
- Alternatively, decide that a task's write is never silent and drop the silent path entirely; the bar then asks for
  every copy. This is the smallest change and removes the whole class of mismatch; its cost is one click per copy.
- Unit tests over a fake terminal for each attribute and each repaint timing; widget tests through the gesture.

## Acceptance

- A drag across text drawn concealed, in the background colour or blinked off, followed by a write of that hidden
  text, is held; seen red against today's read by code point.
- A drag whose lines were rewritten within the settle time before the release is held; seen red against today's
  press-time snapshot.
- A drag across plainly drawn text that did not change still lets its exact write through once.

## Open questions

- Keep a silent path at all, given that a drag while the task hears the mouse (tmux with its mouse on) already never
  gets one, or ask about every copy a task makes?

## To be checked

- Which hidden-glyph attributes the terminal's renderer honours, and whether a frame timestamp is available to the
  widget for "last drawn" comparisons.
