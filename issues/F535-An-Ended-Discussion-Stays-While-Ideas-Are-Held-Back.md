# F535 — An Ended Discussion Stays While Its Ideas Are Held Back

```json
{
  "$schema": "issue-1.json",
  "id": "F535",
  "title": "An Ended Discussion Stays While Its Ideas Are Held Back",
  "state": "Backlog",
  "size": "S",
  "priority": "High",
  "rank": 97,
  "blockedBy": [],
  "covers": "An ended discussion whose task's ideas the machine's listing left out for room is not removed until every idea of it was listed and handed in."
}
```

**Why this size.** S: one field read from each task row, one more condition before an ended discussion is removed,
and their tests.

**What must be true.**
- Porelo's listing of tasks (List and Watch) carries at most 1 MiB of ideas in one reply. A task's later ideas wait
  for a later reply, and its row says how many were left out (`ideasHeldBack`, 0 when all are listed).
- The window reads that count. An ended discussion whose idea was handed in is removed only once the count is 0 and
  every idea its row lists was handed in; until then it stays, as one with ideas not yet handed does today.
- A daemon that does not send the count is taken as having listed every idea, as today.

## How it stands

- `_ideasWaiting` in `lib/src/ui/planning_reports.dart` looks only at the ideas a row lists. With ideas held back the
  row lists the first ones alone; once those are handed, the discussion is removed, and the ideas that still wait go
  with its task.
- `Task` (`lib/src/client/models.dart`) does not read `ideasHeldBack` yet.

## Depends on

Porelo's task listing sending `ideasHeldBack` on each row (an addition to its task contract). Until a daemon sends it,
the window behaves as today.
