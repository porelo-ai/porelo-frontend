# F500 — A Reader Is Started Naming The Work It Reads

```json
{
  "$schema": "issue-1.json",
  "id": "F500",
  "title": "A Reader Is Started Naming The Work It Reads",
  "state": "Review",
  "size": "M",
  "priority": "Highest",
  "rank": 1,
  "blockedBy": [],
  "covers": "A reader the planner offers is started naming the tasks whose work it reads, and each task's end is reported to the planner with the branch its work landed on, so the reader is handed that work and its order names it."
}
```

**Why this size.** M: three small changes on two contracts, each with its red test: the start carries the tasks a
reader reads, the end report carries the branch the work landed on, and the planner hears when held work lands. It
waits on porelo's Start taking the tasks a reader reads and its task row naming the landed branch, and on the
planner's offer naming those tasks and its end record taking the branch.

**What must be true.** A reader the planner offers after a build reads that build's work. The window starts it
naming the tasks whose work it reads, as the offer names them, so porelo's gate gives the reader those branches, read
only. The window reports each task's end with the branch porelo says its work landed on, never a name it makes up,
so the planner can put it into the reader's order. Work still held at the gate is not landed; the planner offers the
reader only once it has.

Found in [F492](README.md#f492)'s run 26, step 9: the reader was ordered to read `porelo/foo-1`, polled
`git ls-remote origin` for half an hour and never saw it, because porelo hides every other task's branch from a task.

## Plan

- `startOrdered` (`lib/src/app/fleet_backend.dart`) takes the tasks a reader reads and gives them to Start in the same
  call. `planning_embedding.dart` passes them from the offer. A red test first: a fake Start sees the offer's tasks.
- `plannedTaskEnded` (`lib/src/ui/planning_reports.dart`) passes the landed branch from the task's row, unchanged, as
  the end record already passes porelo's fields. `models.dart` reads the row's branch. A red test first: the
  planner's fake is told the branch a fake row names.
- A task whose work still waits at its end is reported again once its work has landed (`waiting` 0 and the branch
  named), once, also across restarts of the window, as the end is today. How that report is shaped follows the
  planner's contract: a second event, or the end held back until the work landed. A red test first in
  `window_task_reports_test.dart`.

## Acceptance

- A reader offered for a build is started naming that build's task, and `git ls-remote origin` in it lists the build's
  branch.
- The planner is told the branch a task's work landed on, exactly as porelo names it.
- A build whose work waited at the gate at its end has its landing reported to the planner once.
- The walk's step 9 reaches its readings without hand repair.

## Decided

- Work that waited at the gate when its task ended is told to the planner as a second event, `landed`, carrying where
  it landed, as the planner's contract takes it; the end is not held back. An end that already names where the work
  landed counts as that report, so the work is never told twice.

## How it was built

- `startOrdered` (`lib/src/app/fleet_backend.dart`) takes `reads` and gives it to Start, which `PoreloClient.start`
  sends only where Start declares it and refuses with `FeatureNotSupported` elsewhere; `WindowTaskStarts`
  (`planning_embedding.dart`) passes the order's `reads`, for the first order and for each follow-up alike.
- `Task` (`models.dart`) reads the row's `landed` entries unchanged, `[]` while the work waits, null from a Porelo
  without the field. `plannedLandings` (`planning_reports.dart`) passes them field by field to `plannedTaskEnded`,
  which hands them on in the end record.
- The report sweep tells a finished task's `landed` event once its row names where its work landed after the end was
  told, and keeps that it did with the offer, so a restarted window tells it no second time.
- Tests: `test/app/start_ordered_test.dart` sees Start given the reader's tasks and key through the real backend;
  `test/client/start_key_test.dart` sends `reads` only where Start declares it and reads `landed` from a row;
  `test/ui/window_task_reports_test.dart` starts a planner's reader naming `foo-1`, reports an end with the landing
  its row names, and reports work that landed after its end once as `landed`, also across a restart. Red: with the
  order's `reads` not passed, or the backend giving Start none, the reader was started naming nothing; with the row's
  `landed` not read or not passed, the end named no landing; without the landed event, or without keeping that it
  was told, the planner heard nothing, or heard it twice.
- What only a real host can show, `git ls-remote origin` in the reader listing the build's branch and the walk's
  reader reaching its readings, is shown by the operator's walk.
