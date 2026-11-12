# F508 — A Task's Clipboard Write Asks First

```json
{
  "$schema": "issue-1.json",
  "id": "F508",
  "title": "A Task's Clipboard Write Asks First",
  "state": "Backlog",
  "size": "S",
  "priority": "High",
  "rank": 22,
  "blockedBy": [],
  "covers": "A task writes this computer's clipboard through OSC 52 without a word only right after the person's own key or mouse action in its terminal; any other write asks first, with a preview of what would be written."
}
```

**Why this size.** one gate in the session's OSC 52 handling and one dialog with its preview, with their tests; S.

**What must be true.** A task's terminal in the window writes this computer's clipboard silently only right after
the person's own key or mouse action in that terminal, as tmux's copy mode does. Any other write, one a task sends by
itself, asks first and shows a preview of what would be written; refused, nothing is written. A query of the
clipboard (`?`) is never answered, as today.

Split from the window's terminal behaving as a plain terminal, where it was the one part that is not about keys and
scrolling. Today `Session._copied` in `lib/src/app/session.dart` writes every OSC 52 at once, with no check and no
preview.

## Plan

- `lib/src/app/session.dart`: the time of the person's last key or mouse action in the terminal; an OSC 52 write
  within a short window after it is copied at once, any other is held as one pending copy and the session tells its
  listeners.
- `lib/src/ui/session_view.dart`: the held copy asks with a dialog showing what would be written, shortened where
  long, with *Copy* and *Don't copy*.
- Red first in `test/app/`: a write right after a typed key is copied; one with no recent action is held, confirmed
  copies it, refused copies nothing; `?` is not answered.

## Acceptance

- A task's write to the clipboard right after the person's own action is copied without a word.
- Any other write asks with its preview and is copied only when confirmed.
