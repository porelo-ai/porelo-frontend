# F508 — A Task's Clipboard Write Asks First

```json
{
  "$schema": "issue-1.json",
  "id": "F508",
  "title": "A Task's Clipboard Write Asks First",
  "state": "Review",
  "size": "M",
  "priority": "High",
  "rank": 22,
  "blockedBy": [],
  "covers": "A task's write to this computer's clipboard through OSC 52 is never silent: every write is held and asked about in its own terminal's view, with a preview of what would be written."
}
```

**Why this size.** M, as estimated when it still let one write through after the person's own action: the hold, the
bar with its preview, the drop with the session, the terminals that ask, and their tests. With
[F527](README.md#f527)'s decision the timed silent write it planned is gone, so nothing of this issue is left to build.

**What must be true.** A task's terminal in the window never writes this computer's clipboard without a word. Every
write a task sends (OSC 52), also one right after the person's key, click, paste or drag in that terminal, is held and
asked about with a preview of what would be written; refused, nothing is written. A query of the clipboard (`?`) is
never answered.

Split from the window's terminal behaving as a plain terminal, where it was the one part that is not about keys and
scrolling.

## Why

`Session._copied` (`lib/src/app/session.dart`) once wrote every OSC 52 set at once, with no check and no preview. A
task could thus put text on the clipboard that the person pastes into a shell later, a trailing newline running it.

## Decided

- No silent path at all, after [F527](README.md#f527) (the operator's choice (b)): no timing and no gesture tells which
  program wrote, and a write of text the person saw cannot be told from one a task staged. The one write per own action
  within two seconds that this issue first planned, and the drag-matching write of [F524](README.md#f524) that replaced
  it, are both dropped.

## As it stands

- `lib/src/app/session.dart`: `_copied` holds every write that passes its checks as the one `HeldCopy`, a newer one
  replacing it, and tells the listeners. Only a write for the clipboard is taken (`c`, or no selection, which means it
  too); an empty write, a read (`?`) and more than a megabyte of base64 are ignored; unpadded base64 is normalized. The
  held copy is dropped when the session is left or over, and never kept in the settings or logged.
- `lib/src/ui/session_terminal.dart`: `SessionTerminal`, which the task's view, the setup's two terminals
  (`new_machine.dart`) and the unlock terminal use, asks in `TerminalCopyAsk` inside that view, never in a dialog: the
  number of characters and lines, a preview with line breaks and every character that would not show made visible,
  shortened in the middle with the last line kept, the whole text openable, *Copy* and *Don't copy* without keyboard
  focus, each bar the very copy it shows.
- The diagnosis terminal (`terminal_diagnosis.dart`) is a bare `TerminalView` with no session and takes no OSC 52.

## Acceptance

- Any write a task sends asks in that task's view with its preview, and is copied only on *Copy*; *Don't copy* writes
  nothing. Also a write right after the person's own key, click, paste or drag.
- An empty write changes nothing; a held write is gone once the task's terminal is closed.

## To be checked

- Whether OSC 52 reaches the window at all through ConPTY on Windows, which redraws the screen.

## Open questions

- Whether a person may let one task write without asking for the rest of its run. Not in this issue: it would widen
  what a task may do to the person's clipboard.
