# F524 — A Task's Clipboard Write Follows A Copy The Person Made

```json
{
  "$schema": "issue-1.json",
  "id": "F524",
  "title": "A Task's Clipboard Write Follows A Copy The Person Made",
  "state": "Review",
  "size": "M",
  "priority": "High",
  "rank": 97,
  "blockedBy": [],
  "covers": "A task's OSC 52 write never reaches this computer's clipboard without a word, not even as the answer to a copy the person made: the silent path this issue planned is dropped for asking every time."
}
```

**Why this size.** M, as estimated for a write let through where its text is the person's own drag. With
[F527](README.md#f527)'s decision that path is gone, so nothing of this issue is left to build.

**What must be true.** Text a task writes to the clipboard is held and asked about whatever the person did before it:
typing, pasting, clicking, or dragging across exactly that text. No write goes through without a word.

## Why

The reading by another model of [F508](README.md#f508)'s first plan found that any key or press let the next OSC 52
write through for two seconds: a task could write during a typing burst, right after the paste shortcut, or finish a
sequence begun before. This issue narrowed that to a write matching the person's own drag.

## Decided

- Dropped for asking every time, after [F527](README.md#f527) (the operator's choice (b)). A drag is this window's own
  selection, which no program in the task is told of, so a matching write is a guess; and where the screen plainly
  showed a text, a task's write of it is the same bytes as an honest one, which no reading of the screen tells apart.
  Every write is asked about in the bar under the terminal, so the window's question no longer depends on time,
  gesture or focus.

## As it stands

- `lib/src/app/session.dart` holds every write (`HeldCopy`); `ownAction`, `ownKey`, `dragged`, `pressed`,
  `lostFocus` and the session's clock are gone. `lib/src/ui/session_terminal.dart` draws the terminal with no pointer
  or focus watch of its own and asks in `TerminalCopyAsk`.
- `test/ui/session_terminal_test.dart`: a real drag across a text in a terminal whose task does not hear the mouse,
  then a write of that text, is held and copied only on *Copy*.

## Acceptance

- A write of exactly the text the person just dragged across is held and copied only on *Copy*.
- A write after typing, a paste shortcut, a plain click, `Enter` or a focus loss is held as well.

## Estimate

`F524 size=M est=61 basis=median M 61 (24 records)`
