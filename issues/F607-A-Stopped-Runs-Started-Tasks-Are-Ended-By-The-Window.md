# F607 — A Stopped Run's Started Tasks Are Ended By The Window

```json
{
  "$schema": "issue-1.json",
  "id": "F607",
  "title": "A Stopped Run's Started Tasks Are Ended By The Window",
  "state": "Implementing",
  "size": "S",
  "priority": "High",
  "rank": 127,
  "blockedBy": [],
  "covers": "The window stops the tasks a Stop on an already stopped run still names as started and reports each one's end, and reports an end for a task whose start answered with an error after the planner offered it, so no planner offer stays started and the story can be started again."
}
```

**Why this size.** S: the window's answer to Stop takes the tasks porelo-planner names again, stops each on its machine
and reports its end through the client's `taskEvent`; a start that failed after the offer reports an end too; tests
of both over a fake planner and machine, and the pin raised to porelo-planner's PL149 build.

**What must be true.** A story whose run was stopped can be started again: no task of it stays *started* at the
planner because the window never stopped it or never said that its start failed.

## Found

ST369's live test of 15 November: a stopped run kept its story blocked, the planner refusing a new start while a task
of the stopped run still stood *started*. The operator chose Agent Planner's ways (a) and (c) for PL149 (Agent
Planner, room 2026-11-15 16:23Z).

## Plan

- **Contract**, as Agent Planner named it (room, 16:23Z; its commit and Stop's exact answer posted when they stand):
  - (a) Stop on an already stopped run answers its tasks still *started* again (today it answers none). The window
    stops those tasks and reports each one's end through the client's `taskEvent`; that end clears them.
  - (c) When the window's start of a task was answered with an error after the planner offered it (the planner's
    *started* save refused, or the start failing after the task came up), the window reports an end for that task.
- **Today**, read in the code: the window's stop of planned tasks (`WindowTaskStarts`, `PlanningTaskChanges.stop` in
  `lib/src/ui/planning_embedding.dart`) and its reports (`lib/src/ui/planning_reports.dart`, which
  [F604](README.md#f604) moves onto the client's `taskEvent`). Which paths of a failed start end without any report is
  read before building.
- **Steps**, once PL149's planner side stands: stop each task Stop names again on the machine it was started on (the
  kept `PlannedOffer`), report its end once stopped; report an end for an offered task whose start failed; never a
  second end for one already reported.
- **Red first:** a test with a fake planner whose Stop answers a started task of a stopped run, red today (nothing is
  stopped or reported); one with a start failing after the offer, red today (no end reported).

## Acceptance

- After Stop on a stopped run, each task it names is stopped and its end reported; a new start of the story is then
  accepted. Seen to fail: the live test's blocked story.
- A start answered with an error after the offer reports that task's end once.

## To be checked

- PL149's commit and Stop's exact answer, cited here once posted.
