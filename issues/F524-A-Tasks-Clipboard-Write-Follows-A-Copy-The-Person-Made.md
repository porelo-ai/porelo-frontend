# F524 — A Task's Clipboard Write Follows A Copy The Person Made

```json
{
  "$schema": "issue-1.json",
  "id": "F524",
  "title": "A Task's Clipboard Write Follows A Copy The Person Made",
  "state": "Backlog",
  "size": "M",
  "priority": "High",
  "rank": 97,
  "blockedBy": [],
  "covers": "A task's OSC 52 write reaches this computer's clipboard without a word only as the answer to a copy the person made in that terminal, not within any two seconds after any key or click."
}
```

**Why this size.** M: a write is let through only where it is the text of the person's own drag on this window's
screen, the drag is read from the pointer itself, the allowance is spent on the first matching write and dropped on
any key, press or focus loss, and the tests for each.

**What must be true.** Text a task writes to the clipboard while the person types, pastes or clicks for any other reason
is held and asked, as any other write is; only a write that answers the person's own copy goes through without a word.

## Why

The reading by another model of [F508](README.md#f508)'s final change found one grave point that the issue accepted
by design: any qualifying action (a key, a pointer press) lets the next OSC 52 write through for two seconds
(`lib/src/app/session.dart`). A task can write during a typing burst, overwrite the clipboard right after the person's
paste shortcut, or finish a sequence begun before the action; losing focus does not end the allowance. The person did
not ask for that copy, and pastes what the task put there.

## Plan

- **What the write says decides, not when it comes.** Neither timing nor a gesture tells which program wrote: with
  Porelo's tmux (`mouse on`, `set-clipboard on`, no copy bindings of its own, the person's own file sourced after) a
  task that asks for the mouse gets the person's drags itself, and a task writing over and over beats tmux's own write
  to the first place after any gesture. So a write goes through without a word only where its text is what the
  person's own drag covered on this window's screen: the cells between where the primary button was pressed and where
  it was let go, read from the terminal's own buffer at the release (trailing spaces of each line aside; the end cell
  taken or not). Anything else is held and asked, as today.
- **A drag is the person's own pointer** (`Listener` in `lib/src/ui/session_terminal.dart`): the primary button of one
  pointer, pressed and moved to another cell before it is let go; a cancel, a second pointer or another button makes it
  none. A plain click, a double or triple click and every key open nothing: tmux's keyboard copies (`C-w`, `M-w`;
  `Enter`, `C-j` in vi mode) and its double-click word copy are asked, since the window cannot see copy mode and those
  keys are typed in a shell all the time.
- **The allowance is one write, within two seconds** of the release (a clock that never goes back), and goes on any key
  the person presses afterwards (a repeat too), a new press of the pointer, the terminal losing the keyboard (observed
  on the terminal's own focus, whichever node it is given), and the session leaving. A write that does not match leaves
  it for the one that does.
- `ownAction` (any pointer press or release) and the first-press-only `ownKey` of `lib/src/app/session.dart` go;
  `Session.dragged(from, to)` takes the drag's cells and `Session.lostFocus()` the focus loss.
- Red first in `test/app/session_clipboard_test.dart`: after a drag, a write of other text is held and the matching one
  still goes through; a write of the dragged text goes through once, a second is held; held after typing, after a key
  repeat, after a paste shortcut, after focus loss, after a plain click, after `Enter`, after a new press, and after two
  seconds. A widget test that the view turns a real drag into the drag's cells and a click into none, and reports
  the loss of focus.

## Estimate

`F524 size=M est=61 basis=median M 61 (24 records)`
