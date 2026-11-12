# F502 — A Task's Declared Outcome Goes With Its End

```json
{
  "$schema": "issue-1.json",
  "id": "F502",
  "title": "A Task's Declared Outcome Goes With Its End",
  "state": "Review",
  "size": "S",
  "priority": "High",
  "rank": 18,
  "blockedBy": [],
  "covers": "The window reports each task's end to the planner with the outcome the task declared, DONE or BLOCKED, and its why, as Porelo's List and Watch give them, so the planner can keep a blocked issue where it is instead of moving it on."
}
```

**Why this size.** S: one more record read from the task's row and passed through the end report the window already
sends, with its tests; no contract another repository reads from the window. It waits on the planner's end record
taking the declared outcome beside the fields it takes today.

**What must be true.** When a task the window started for the planner ends, the planner is told how the task itself
said its work ended: DONE, or BLOCKED with the reason it gave. Today the window reports only whether the run finished
and what never reached the gate, so a task that declared BLOCKED and ended its run normally reads to the planner as
done, and its issue is moved on. This is part of ST313's work: a task's result lands where the next step finds it.

Porelo already answers the outcome on each task's row of `List` and `Watch` as `ended`, with `outcome`, `why` and `at`:
the task's own declaration first (DONE or BLOCKED, BLOCKED always with a non-blank why), else FAILED with the run's
error when the run ended unfinished, else absent. A finished run without a declaration has no `ended`.

## Plan

- `lib/src/client/models.dart`: a `TaskEnd` with `outcome`, `why` and `at`, read from the row's `ended` as strings,
  unmapped; `Task.ended` holds it, null where the row has none. The outcome is kept as Porelo names it, so a value
  this build does not know is passed on, not dropped. A red test first in `test/client/`: a row with `ended` reads its
  three fields, a row without reads null.
- `plannedTaskEnded` (`lib/src/ui/planning_reports.dart`) takes the task's `TaskEnd` and passes its outcome and why
  unchanged into the planner's end record, beside the fields it passes today; where the row has no `ended`, no outcome
  is sent and the record is as today. The why of the record is the declared one where a declaration stands, and the
  run's error otherwise, which is what Porelo's `ended.why` already says. The sweep (`_sweepNow`) hands the row's
  `ended` in with the run's end; `report` keeps taking a finished record from the screen as it is.
- The end key (`plannedEndKey`) stays the run's end: one run's end is reported once, with the outcome its row showed.
- A red test first in `test/ui/window_task_reports_test.dart`: a task whose run finished with a declared BLOCKED and a
  why is reported to the planner's fake with outcome BLOCKED and that why; one with no declaration is reported with
  no outcome, as today.

## Acceptance

- A task that declares BLOCKED with a reason and ends its run is reported to the planner with BLOCKED and that reason,
  and its issue stays under *Needs you* on the board.
- A task that declares DONE is reported with DONE; a run that ended unfinished without a declaration with FAILED and
  its error; a finished run without a declaration with no outcome.
- Each end is reported once, also across restarts of the window, as today.

## Checked

- Porelo's row may show a run's end before the declaration that came with it. An end whose row shows no outcome yet is
  held once for a moment (five seconds) and looked at again; it goes then, without an outcome only where the row still
  shows none. An empty outcome is told as none.
