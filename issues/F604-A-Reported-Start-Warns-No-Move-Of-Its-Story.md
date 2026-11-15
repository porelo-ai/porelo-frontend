# F604 — A Reported Start Warns No Move Of Its Story

```json
{
  "$schema": "issue-1.json",
  "id": "F604",
  "title": "A Reported Start Warns No Move Of Its Story",
  "state": "Backlog",
  "size": "S",
  "priority": "High",
  "rank": 124,
  "blockedBy": [],
  "covers": "A start the window handed on stops counting as one the planner does not report yet once the window reported it started, or it ended, so a later move of its story warns only of tasks at work, instead of Stop the tasks and move for tasks long ended."
}
```

**Why this size.** S: the window's started and ended reports reach the screen's run as its own reports do, so the
offer leaves the run's unreported starts; tests of a move after a reported start, after an end, and while a start
is still unreported.

**What must be true.** A person moving a story whose planned tasks all ended is not told that a start is still
handed on and must be stopped; the warning stands only while a start is truly unreported or a task is at work.

## Found

The operator's live test (15 November, ~15:38Z): moving ST366 *Estimated* to *Backlog* asked *ST366 has a start this
window handed on that the planner does not report yet; it is stopped first.* with *Stop the tasks and move*, while
`pi` and `pi-2` had both ended and their results were saved (PI68 *Analyzed*, *Estimated*).

## Plan

- **Today**, read in the code:
  - porelo-planner's screen (pinned `c8796c6`, `screen/lib/src/planning_board.dart`, `_localWarnings`) adds the
    warning while `runOf(story).starting`, which is true while the run's `_unreported` offers are not empty
    (`screen/lib/src/task_runs.dart`). An offer enters `_unreported` in `PlanningRun.start` and leaves it only on a
    failed start, on a cancelled epoch, or in `PlanningRun.report` for a `started` event, the path of the client's
    `taskEvent` (`PlanningTaskReports`).
  - The window reports a planned task's events itself (`lib/src/ui/planning_reports.dart`, `_deliver`), calling
    `source.taskEvent` on the planner source directly, not the client's `taskEvent`. The planner hears the start, but
    the screen's run never does, so the offer stays unreported for the window's life, and an end does not clear it
    either.
  - The window's `_plannedStarts` in `lib/src/ui/shell.dart` only says which operations stand over the board; it is
    not this warning.
- **Steps.**
  - After the window delivered a `started` event, or an end, for an offer this window handed on, the screen's run
    hears it, so the offer leaves `_unreported`: through the screen's own path where it binds the offer, or a call
    Agent Planner names for it (to agree; the window's own delivery stays, as it carries offers kept across a
    restart, which the screen holds no binding for, and starts the follow-ups).
  - Raise the pin of `porelo_planning` should that need a screen change.
- **Red first:** a widget test: a board start, its started report delivered by the window, then a move of the story;
  red today on the warning.

## Acceptance

- A move of a story whose planned start the window reported, or whose task ended, shows no *start this window handed
  on* warning. Seen to fail: the live test's move of ST366.
- A move while a start is still unreported, or a task at work, warns as today.
