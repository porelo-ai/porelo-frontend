# F478 — A Retry Finds The Planner On Its New Port

```json
{
  "$schema": "issue-1.json",
  "id": "F478",
  "title": "A Retry Finds The Planner On Its New Port",
  "state": "Review",
  "size": "S",
  "priority": "High",
  "rank": 1,
  "blockedBy": [],
  "covers": "The window keeps reading the planner's address file and follows the planner to a new address, starting it again where it is gone, so planning reaches a planner that came back on another port without a restart of the window."
}
```

**Why this size.** one class of the window, `LocalPlanner`, and its tests; the screen package and the planner's
contract stay as they are.

**What must be true.** A person whose planner restarted, on a new port with a new token, presses *Retry planning* and
sees the board again, without restarting the window.

## Why

The planner writes its address and token to `planner.json` each time it starts. The window reads that file once, when
it first reaches the planner, and the source it opens keeps that address for good. After a restart of the planner,
every call and *Retry planning* go to the old port and the page says "the planner cannot be reached: connection
refused"; only a restart of the window reads the file again.

## Plan

- `lib/src/app/planner.dart`: once a planner is found, `LocalPlanner` reads `planner.json` again every two seconds.
  A new address is opened and handed to the screen as the provider's source; the screen's boards move to a new source
  of their own accord, and the old one is closed after. A file gone at two reads in a row means the planner is gone:
  the planner is looked for and started as at first, one at a time, and a planner of the window's that has not
  answered is never started twice. A closed window reads and starts nothing.
- A source of the window's own wrapped around the screen's was tried and dropped: the screen keys a story's work and
  its stop by the source object, so a wrapper would split a stop from the work it stops.
- Tests in `test/app/planner_test.dart`, both seen red with the following switched off: after the planner restarts on
  another port the window follows it there; where the planner found is gone, one is started once and reached. That
  a closed window starts nothing has no test: in a test build the notifier's own assertion stops it first, so a
  break of the guard is never seen red.

## Acceptance

- With the window open on a board, the planner is restarted on another port; *Retry planning* shows the board again.
