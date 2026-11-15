# F579 — The Placing Dialog Takes A Dialog's Width

```json
{
  "$schema": "issue-1.json",
  "id": "F579",
  "title": "The Placing Dialog Takes A Dialog's Width",
  "state": "Backlog",
  "size": "XS",
  "priority": "Low",
  "rank": 100,
  "blockedBy": [],
  "covers": "Story ST361: the dialog `Putting <project> on <machine>` stands as wide as the window's other dialogs, its words wrapping there, instead of across almost the whole window."
}
```

**Why this size.** One widget's width in one file.

**What must be true.** `Putting <project> on <machine>` reads as the window's other dialogs do, its paragraph
wrapped at a dialog's width.

## Plan

- `lib/src/ui/placing_project_dialog.dart` builds its `AlertDialog` content as a bare `Column`, so a long paragraph
  stretches the dialog toward the window's width. Wrap the content in `SizedBox(width: Sizes.dialog)`, as
  `Give <machine> your <forge> token, once` does in `shell.dart`.
- It only reads wrong: no test.

## Acceptance

- In the debug build the dialog stands at the token page's width, at 1280 wide and at 390 wide.
