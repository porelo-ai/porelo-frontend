# F501 — A Started Offer Is Found Again By Its Key

```json
{
  "$schema": "issue-1.json",
  "id": "F501",
  "title": "A Started Offer Is Found Again By Its Key",
  "state": "Review",
  "size": "S",
  "priority": "Highest",
  "rank": 2,
  "blockedBy": [],
  "covers": "The window gives each task it starts for a planner's offer the offer as the start's own key, and finds the offer of every listed task by that key after a restart, so a window that dies between Start and keeping the pair loses no offer."
}
```

**Why this size.** S: one more parameter on the ordered and discussion starts, and the report's sweep reading the key
from the task's row, with their tests. It waits on porelo's Start taking a caller's key, at most 200 characters, kept
with the task from its creation and given back by List and Watch.

**What must be true.** A task the window started for a planner's offer is reported to the planner under that offer,
also when the window ended between Start's answer and keeping the offer with its container. Today the window keeps
the pair after Start answers; an end in between leaves a task no window reports, and the offer is held as handed.

Found in [F492](README.md#f492)'s runs 24 to 26.

## Plan

- `startOrdered` and `startDiscussion` (`lib/src/app/fleet_backend.dart`) give Start the offer as its key.
  `planning_embedding.dart` passes it. A red test first: a fake Start sees the offer.
- `models.dart` reads the key from the task's row. The report's sweep (`lib/src/ui/planning_reports.dart`) takes a
  listed task whose key is an offer this window handed and has no kept pair for, keeps the pair and reports it as
  today. A red test first: an offer handed, no pair kept, a listed task with that key, and its start reported once.
- The kept pair stays: it also tells a later task under the same container name apart, which the key does too once
  every task carries one.

## Acceptance

- A window killed right after Start's answer reports that task's start and end to the planner under its offer after
  its restart.
- No offer is reported for a task whose key names no offer this window handed.

## Decided

- porelo's Start takes `callerKey` (at most 200 characters, no control characters), keeps it with the task from its
  creation, across a resume and every restart, and gives it back on the task's row in List and Watch as `callerKey`.
  The window sends it only where the machine's Start declares it, so an older machine starts the task without it and
  only the kept pair finds that task again.
- An offer handed to Start is kept with what keeping its task needs (machine, provider, project, story, whether it is
  a discussion) until its pair is kept or its start refused, so the sweep after a restart can keep the pair.

## How it was built

- `startOrdered` and `startDiscussion` (`lib/src/app/fleet_backend.dart`) take `callerKey`, which
  `PoreloClient.start` sends where Start declares it; `WindowTaskStarts` (`planning_embedding.dart`) passes the offer
  for both, and keeps a `PendingStart` in the settings when it hands the offer, dropped once the pair is kept or the
  start is refused.
- `Task` (`models.dart`) reads `callerKey` from the row, "" where none was given.
- The report sweep (`planning_reports.dart`) first keeps, for each pending start not being started in this window, the
  listed task on its machine whose key is the offer: as a story's task, or as a discussion. It then reports as before,
  so its start and any end it shows go out once under its offer. A listed task whose key names no offer this window
  handed is left alone.
- Tests: `test/client/start_key_test.dart` sends the key only where Start declares it and reads it from a row;
  `test/ui/window_task_reports_test.dart` hands an offer whose start never answers, reopens the window twice and sees
  the start reported once under the offer, and with an end that came while the window was closed, the start and the
  end once each; a task whose key names no offer is not reported; `test/ui/window_task_starts_test.dart` sees a
  discussion's Start given the offer. Red: without the offer on the ordered start, the reports tests got no key and
  no report; without the offer on the discussion's start, its Start got no key; with the sweep keeping nothing found
  again, or the row's key not read, nothing was reported and the row gave back "".
