# F538 — The Planner Ends Gracefully On Windows

```json
{
  "$schema": "issue-1.json",
  "id": "F538",
  "title": "The Planner Ends Gracefully On Windows",
  "state": "Backlog",
  "size": "S",
  "priority": "Medium",
  "rank": 107,
  "blockedBy": [],
  "covers": "On Windows the planner the window started is asked to end through its own stop on its input, and is ended hard only when it does not end in time."
}
```

**Why this size.** S: one more way to end the started planner in `LocalPlanner` (`lib/src/app/planner.dart`), chosen
on Windows, and its test with a stand-in planner.

Found in the code reading of [F476](README.md#f476) (2026-11-13).

**How it stands.**
- When the window closes, or a planner it started must go before another starts, the window ends that planner through
  `stopOwnedProcess`: SIGTERM, and SIGKILL after a bounded wait.
- On Windows there is no SIGTERM: `Process.kill` ends the program at once, so the planner never finishes what it was
  writing, as a save under way.
- The window already starts the planner with its input open (`_startWithItsInput`).

**What must be true.**
- On Windows the window asks the planner to end through the planner's own stop on its input, as the planner states it
  (for instance by closing that input), and waits a bounded time for it to end.
- Only a planner still running after that wait is ended hard, and the window's log says so.
- On Linux nothing changes.

**To be agreed with porelo-planner.** How it is told to end on its input on Windows, and how long it may take.
