# F501 — A Started Offer Is Found Again By Its Key

```json
{
  "$schema": "issue-1.json",
  "id": "F501",
  "title": "A Started Offer Is Found Again By Its Key",
  "state": "Backlog",
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

Found in F492's runs 24 to 26.

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
