# F479 — A Planner The Window Started Ends With It

```json
{
  "$schema": "issue-1.json",
  "id": "F479",
  "title": "A Planner The Window Started Ends With It",
  "state": "Accepted",
  "size": "M",
  "priority": "Medium",
  "rank": 1,
  "blockedBy": [],
  "covers": "A planner the window started because none was serving ends when the window ends, so it neither holds the planner's address file nor stands in the way of the next planner; a planner the window found serving is left running."
}
```

**Why this size.** the window's start of the planner, its end of it on every way the window ends, and a test of each;
a hard kill of the window is covered only with the planner's help.

**What must be true.** A person who ends the window finds no planner left running that the window started, and can
start another planner at once.

## Why

The window starts the installed planner, detached, when none serves (`LocalPlanner._startDetached`). After the window
ended, that planner kept running and kept `planner.json` under the runtime directory, so a planner started next, for
instance one built from source, could not start until it was killed by hand.

## To be checked

- Which ways of ending the window run its own end: closing it, `q` in `flutter run` (which calls `exit`), SIGTERM,
  SIGINT. A hard kill runs none, so only a planner that ends on its own when the window's pipe closes (the planner's
  part, if wanted) is ended then.
