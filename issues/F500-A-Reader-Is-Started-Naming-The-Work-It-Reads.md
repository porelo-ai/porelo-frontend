# F500 — A Reader Is Started Naming The Work It Reads

```json
{
  "$schema": "issue-1.json",
  "id": "F500",
  "title": "A Reader Is Started Naming The Work It Reads",
  "state": "Backlog",
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

Found in F492's run 26, step 9: the reader was ordered to read `porelo/foo-1`, polled
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
