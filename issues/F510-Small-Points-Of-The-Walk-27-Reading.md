# F510 — Small Points Of The Walk 27 Reading

```json
{
  "$schema": "issue-1.json",
  "id": "F510",
  "title": "Small Points Of The Walk 27 Reading",
  "state": "Backlog",
  "size": "S",
  "priority": "Medium",
  "rank": 23,
  "blockedBy": [],
  "covers": "The small points a reading by another model found in the window's start and end reports built for walk 27: a task found again only within its own project, a start that is never kept ended, the right task paired when two starts run at once."
}
```

**Why this size.** S: three guards in the planning reports and the start, each with its red test.

**What must be true.** A task the window finds again by the key its start gave is one of the offer's own project; a
start whose task can be kept neither way is ended rather than kept for ever; and when two starts in one project run at
once, each offer is paired with its own task.

## Why

A reading of the window's reports built for walk 27 found, none of them grave:
- `_keepFoundAgain` (`lib/src/ui/planning_reports.dart`) takes a task whose `callerKey` equals the offer on the
  machine, without checking that it is of the offer's project; an offer string shared across projects would be taken
  as ours.
- A pending start whose task row has an empty `task` is neither kept nor forgotten, and stays in the settings until it
  is evicted with the handed offers.
- When Start's step names no container, `_startRunning` (`lib/src/app/fleet_backend.dart`) takes "the only newly
  listed task of this project and repository"; a second start of the same project listed first gets the wrong pairing.

## Plan

- `_keepFoundAgain` matches the offer's project as well as its key.
- A pending start whose row names no task is forgotten, said once in the window's log.
- The start's pairing matches the task's `callerKey` to the offer where the step names no container.
- Red first in `test/ui/window_task_reports_test.dart` and the start's tests: a task of another project with the same
  key is not taken; a row with no task ends the pending start; two starts of one project are each paired with their
  own task.

## Acceptance

- The three tests above, each seen red first.
