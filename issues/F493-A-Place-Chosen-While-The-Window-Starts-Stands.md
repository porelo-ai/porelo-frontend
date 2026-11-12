# F493 — A Place Chosen While The Window Starts Stands

```json
{
  "$schema": "issue-1.json",
  "id": "F493",
  "title": "A Place Chosen While The Window Starts Stands",
  "state": "Backlog",
  "size": "XS",
  "priority": "High",
  "rank": 1,
  "blockedBy": [],
  "covers": "A place the person chooses while the window still reads its machines stands; the place saved from before does not replace it when the read ends."
}
```

**Why this size.** one flag in the shell's navigation and its test; XS.

**What must be true.** A person who chooses a place, Planning for one, while the window is still reading its machines
stays there. The place saved from the window's last session is put back only where the person has chosen none yet.

Found in [F492](README.md#f492)'s walk on the VM (runs 15 and 19): the walk chose Planning, and the first read of the
machines took the window back to Work, the place saved before.

## Plan

- The shell remembers whether a place was chosen before the saved navigation was restored; the restore then keeps that
  place and only unfolds the current machine.
- A widget test chooses Planning, restores a saved Work, and expects Planning.

## Acceptance

- A place chosen before the machines are read is the place shown after they are read.
- With no place chosen, the saved place is restored as before.
