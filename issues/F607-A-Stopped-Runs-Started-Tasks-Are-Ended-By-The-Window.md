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
  on and forgets its offer as before; once the stop went through, it reports the task's end through the kept offer,
  queued behind a start's report still waiting, so the planner never hears an end before a start. The end is the
  agent's own where the machine lists a new one, else now, unfinished, *The window stopped the task.* A stop that
  fails reports nothing, so a later Stop names the task again; a forgotten offer and a set of ends told keep it to
  one end. `TaskNotAnswered` to that end is quiet: the planner holds nothing to end.
- **(c)** A `STARTED` report the planner answers with a refusal that is neither transient, `TaskNotAnswered` (already
  stopped and voided) nor `TaskEventConflict` (it binds nothing; the task is kept, as before) stops the task and
  reports its end the same way, once; the refusal is still said. A Start that fails inside the window, before any
  `STARTED` report, reports no end: the planner holds such an offer `OFFERED`, and its core refuses an `ENDED` for
  an offer that has not started.
- **Tests** in `test/ui/window_task_reports_test.dart`: *a stop stops each task on the machine it was started on,
  reports its end once and forgets its offer* (a second Stop of the same task and the agent's later end tell
  nothing more) and *a start the planner refused is stopped and its end reported once*; *a new offer in the container
  of a stopped task is reported* now expects the first task's end between the two starts.
- **Red:** (a) `Which: at location [1]` of the calls, only `PlanningTaskEvent.started` sent; (c) `Expected:
  [(Machine, String):(Instance of 'Machine', porelo-demo-porelo)]  Actual: []`, nothing stopped.
- **Runs (laptop, one file each):** `window_task_reports_test.dart` 71 passed; `window_task_starts_test.dart` 25
  passed; `story_work_test.dart` 29 passed; `planning_moves_test.dart` 24 passed. `dart analyze lib test
  integration_test tool`: No issues found. The whole suite runs on the build box at the branch's head.

## To be checked

- The name the planner's refusal carries when its `STARTED` save is refused and the run halted was not seen live;
  the window ends the task on any refusal but the three above.
- Whether a Start that fails inside the window after the offer was handed should reach the planner in another way is
  porelo-planner's to say: today it keeps that offer `OFFERED` and refuses an end for it.
- The reading by another model has not run.
