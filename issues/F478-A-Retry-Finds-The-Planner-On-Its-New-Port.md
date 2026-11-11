# F478 — A Retry Finds The Planner On Its New Port

```json
{
  "$schema": "issue-1.json",
  "id": "F478",
  "title": "A Retry Finds The Planner On Its New Port",
  "state": "Backlog",
  "size": "S",
  "priority": "High",
  "rank": 1,
  "blockedBy": [],
  "covers": "When the planner cannot be reached, the window reads its address again, starting the planner where none answers, so Retry planning reaches a planner that came back on another port."
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

- `lib/src/app/planner.dart`: the window hands the screen a source of its own that passes every call to the source it
  opened. A call or a watch that fails as `PlannerUnreachable` makes it read `planner.json` again; an address found
  there replaces the source, and where none is found the planner is started as on the first reach, never two at once.
  The failed call itself is not sent again, since a write may have arrived; the next call, as *Retry planning*,
  goes to the planner found.
- Tests in `test/app/planner_test.dart`, red first: after the opened source refuses as unreachable, the next call
  reaches the source opened from the new address; a write that failed is asked once; a planner that answers is not
  started a second time.

## Acceptance

- With the window open on a board, the planner is restarted on another port; *Retry planning* shows the board again.
