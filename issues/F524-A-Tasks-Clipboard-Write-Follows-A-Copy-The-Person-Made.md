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

**Why this size.** M: the terminal tells a copy the person asked for (tmux copy mode's own keys, a selection made with
the pointer) from other actions, the allowance is spent on the first write after that copy and dropped on focus loss,
and the tests for each.

**What must be true.** Text a task writes to the clipboard while the person types, pastes or clicks for any other reason
is held and asked, as any other write is; only a write that answers the person's own copy goes through without a word.

## Why

The reading by another model of [F508](README.md#f508)'s final change found one grave point that the issue accepted
by design: any qualifying action (a key, a pointer press) lets the next OSC 52 write through for two seconds
(`lib/src/app/session.dart`). A task can write during a typing burst, overwrite the clipboard right after the person's
paste shortcut, or finish a sequence begun before the action; losing focus does not end the allowance. The person did
not ask for that copy, and pastes what the task put there.

## Plan

- The allowance is opened only by an action that asks for a copy: in tmux, the copy-mode keys that copy (`Enter`, `y`
  in vi mode, `Ctrl+W`/`Alt+W` in emacs mode, the mouse release that ends a selection in copy mode); in a plain shell,
  the pointer's selection release. Ordinary typing, Ctrl+V/Shift+Insert and clicks elsewhere open none.
- It is spent by the first write, ends on focus loss and after its two seconds.
- Red first in `test/app/session_clipboard_test.dart`: a write during typing, a write after a paste shortcut, a write
  after focus loss and a second write after one copy are each held; a write after a copy-mode copy key goes through.

## To be checked

- Which keys tmux's copy mode binds to copying under the task's tmux configuration, read from Porelo's tmux setup rather
  than assumed.

## Estimate

`F524 size=M est=61 basis=median M 61 (24 records)`
