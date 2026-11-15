# F607 — A Stopped Run's Started Tasks Are Ended By The Window

```json
{
  "$schema": "issue-1.json",
  "id": "F607",
  "title": "A Stopped Run's Started Tasks Are Ended By The Window",
  "state": "Review",
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

## Built

- **Against** porelo-planner `cb9d13a` (the pin), whose core answers a Stop of a stopped run with its offers still
  `STARTED` as at work and takes an `ENDED` report for such an offer, also one halted by a refused `STARTED` save, and
  whose screen hands every task at work to `PlanningTaskChanges.stop`.
- **(a)** `WindowTaskReports.stop` (`lib/src/ui/planning_reports.dart`) stops each task on the machine it was started
  on, where the machine does not list it stopped already, then reports its end through the kept offer, queued behind
  a start's report still waiting, so the planner never hears an end before a start. The end is the agent's own where
  the machine lists a new one, else now, unfinished, *The window stopped the task.*
  - The offer is forgotten only once the planner took the end, answered `TaskNotAnswered` (it holds nothing of the
    task), or `TaskEventConflict` for a task whose start it was never heard to take (the stop dropped the start's
    report, or the planner never took it): those two are not said. A stop that fails, or an end not taken for another
    reason, is said and keeps the offer, so the next Stop, which names the task again, stops or ends what is left;
    after a restart of the window too, since the offer is kept in the settings. One end waits at a time per offer.
- **(c)** A `STARTED` report refused by the planner's save stops the task and reports its end the same way; the
  refusal is still said. `WorkRun.save` (at `10ae255`) catches every `StoreException`, marks the run halted and
  rethrows, and the app names it by its kind (`Problems`): `StaleRevision`, `PartlySaved`, `MoveNotAllowed`, but also
  `Unreachable`, `Busy`, `Unreadable`, `NoSuchStory` and the rest. So every refusal halts the run except those made
  before the save, which keep the task: the run's own (`WorkRefusal`: `TaskEventConflict`, `TaskNotAnswered`,
  `WorkNotAllowed`, `WorkRunning`, `InvalidSettings`, `WorkRecordUnavailable` and the reading ones), the request's
  (`InvalidName`, `InvalidLevel`, `NotACloneUrl`, `IdeaRefused`, `ResultRefused`) and the transient ones. A Start that
  fails inside the window, before any `STARTED` report, reports no end: the planner holds that offer `OFFERED` and
  refuses an end for it.
- **Tests** in `test/ui/window_task_reports_test.dart`:
  - *a stop stops each task on the machine it was started on, reports its end once and forgets its offer*;
  - *a start the planner refused with StaleRevision / Unreachable / Busy / NoSuchStory is stopped and its end
    reported once*;
  - *a stop that failed keeps the offer, and the next Stop stops the task and ends it*;
  - *an end the planner did not take keeps the offer, and the next Stop tells it again*;
  - *an end the planner no longer answers for is not said, and the offer goes*;
  - *a Stop while the start waits for its answer tells the end after it, quietly where none started*;
  - *a start refused with TimedOut / InvalidSettings / TaskEventConflict / WorkNotAllowed / InvalidName stops nothing
    and ends nothing*;
  - *a new offer in the container of a stopped task is reported* now expects the first task's end between the starts.
- **Red:**
  - before any change: (a) `Which: at location [1]` of the calls, only `PlanningTaskEvent.started` sent; (c)
    `Expected: [(Machine, String):(Instance of 'Machine', porelo-demo-porelo)]  Actual: []`;
  - the follow-up tests against the first version of this change: a failed stop and a failed end `Expected:
    '00000000-0000-4000-8000-000000000000'  Actual: <null>` (offer forgotten); the Stop beside a waiting start
    `Expected: empty  Actual: [PlanningRefusal:The task has not started or already ended differently.]`; a start refused
    with `InvalidSettings` `Expected: empty  Actual: [(Machine, String):(Instance of 'Machine', porelo-demo-porelo)]`.
    The `TaskNotAnswered`, `TimedOut` and `TaskEventConflict` cases held already and guard what stays.
  - the second reading found the three save names too few (any store refusal halts the run): `Unreachable`, `Busy`
    and `NoSuchStory` against the three names `Expected: [(Machine, String):(Instance of 'Machine',
    porelo-demo-porelo)]  Actual: []`.
- **Stacked with [F604](README.md#f604)**: a refused `STARTED` report goes through `_notTaken`, the screen's run and the
  window's own report alike.
- **Runs (stack, laptop, one file each):** `window_task_reports_test.dart` 83 passed; `planning_moves_test.dart` 28;
  `story_work_test.dart` 30; `window_task_starts_test.dart` 25.
- **Runs (laptop, one file each):** `window_task_reports_test.dart` 78 passed; `window_task_starts_test.dart` 25
  passed; `story_work_test.dart` 29 passed; `planning_moves_test.dart` 24 passed. `dart analyze lib test
  integration_test tool`: No issues found.

## To be checked

- Which save refusal the live run met was not seen; `NoSuchStory` and `NoSuchIssue` come from the request as well as
  from the store and are taken as halting.
- An end retried after its answer was lost carries a new `at`; the planner may answer `TaskEventConflict`, which is
  said once and the offer goes.
- A kept offer whose end never went is retried only by another Stop, never by itself.
- After a restart of the window, a start whose report was refused may be reported again; the planner then answers
  `TaskNotAnswered` for a halted run, and the window stops the task and forgets its offer without an end.
- Whether a Start that fails inside the window after the offer was handed should reach the planner in another way is
  porelo-planner's to say: today it keeps that offer `OFFERED` and refuses an end for it.
- The second reading found F607's first findings fixed and the save refusals too few, fixed here.
