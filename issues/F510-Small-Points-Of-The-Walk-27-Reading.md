# F510 — Small Points Of The Walk 27 Reading

```json
{
  "$schema": "issue-1.json",
  "id": "F510",
  "title": "Small Points Of The Walk 27 Reading",
  "state": "Review",
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

## Decided

- The start's key decides the pairing only where a newly listed task of the project carries a key at all; a machine
  that lists no keys keeps the earlier rule, the only newly listed task, so its start still answers once the agent
  runs.

## How it was built

- `_keepFoundAgain` takes a task found by its key only when it is of the offer's project; a found task whose row names
  no task forgets its pending start and says so once in the window's log.
- `_startRunning` takes the start's key: where Start's step names no container, of the tasks newly listed for the
  project and repository it pairs the one whose key is the start's.
- Red seen first in `test/ui/window_task_reports_test.dart` (a task of another project with the offer's key was kept
  as the offer's; a row with no task left its pending start in the settings) and in `test/app/start_ordered_test.dart`
  (two starts of one project at once gave no answer until the agent's run ended). The reading found that a machine
  listing no keys would then never pair early: its test went red too before the pairing fell back to the earlier rule.
- `start_ordered`, `window_task_reports`, `window_task_starts` and `fleet_model` tests ran green, 93 tests.
