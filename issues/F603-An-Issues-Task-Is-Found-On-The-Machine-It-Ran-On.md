# F603 — An Issue's Task Is Found On The Machine It Ran On

```json
{
  "$schema": "issue-1.json",
  "id": "F603",
  "title": "An Issue's Task Is Found On The Machine It Ran On",
  "state": "Review",
  "size": "XS",
  "priority": "High",
  "rank": 123,
  "blockedBy": [],
  "covers": "The Planning issue page's Open task finds a planned task on the machine the window started it on, as its kept offer names, instead of saying This window does not know task pi-2 on this machine for a task that ran on a host."
}
```

**Why this size.** XS: the lookup behind *Open task* and its unavailable line takes the machine from the window's
kept `PlannedOffer` before the board's machine; tests of a project carried on two machines.

**What must be true.** A person on a planning issue whose task ran on a host opens that task from the issue page,
whichever machine the board's planner runs beside.

## Found

The operator's read-only runs of 15 November: the issue page said *This window does not know task pi-2 on this
machine* for a task that ran on the host. Agent Planner asked whose the line is: it is the window's.

## Plan

- **Today**, read in the code: `_planningTaskUnavailable` and the open beside it (`lib/src/ui/shell.dart`) look the
  task up on `planningMachineOf` (`lib/src/ui/planning_embedding.dart`): the provider's own machine where one is
  named so, else `plannedTaskMachine` among the machines carrying the project, the current one first. Where the
  board's provider is this computer, or the current machine carries the project too, that is not the host the task
  ran on. The window keeps the machine of each planned start in `PlannedOffer.machine` (`lib/src/app/settings.dart`).
- **Steps.**
  - Both take the machine from the kept planned offer of that project and task, where one is kept, and only then
    `planningMachineOf`.
  - The unavailable line names the machine it looked on.
- **Red first:** a widget test with the project on this computer and on a host, the task kept as started on the
  host, red today on the line.

## Acceptance

- *Open task* for a task started on a host opens it there, whichever machine is current. Seen to fail: the live
  run's *does not know task pi-2*.
- A task no planned offer names is looked up as today, and the line names the machine.

## Built

- **Machine:** `_planningTaskMachine` in `lib/src/ui/shell.dart` takes the machine of the latest kept
  `PlannedOffer` of the board's project and that task, and only where none is kept `planningMachineOf`; *Open task*
  (`_openPlanningTask`) and its unavailable line (`_planningTaskUnavailable`) both use it.
- **Task:** found on that machine by its name within the project (`Task.task`), as the planner names it, or by its
  container as before (`_plannedTaskOn`); the planner's `task` is the project's name for it, which a container named
  in either of porelod's shapes never equals, so the lookup by container alone missed it on any real machine. Plan
  widened by this; the size stays XS.
- **Line:** *This window does not know task <name> on <machine>.*, the machine looked on.
- **Scenarios** in `test/features/planning_story.feature`: *A task started on another machine opens there from its
  issue* and *A task gone from the machine it was started on names that machine*; steps *the window started task
  {name} of ST291 on the other machine* (the planner's work names `pi-2`, the machine lists container
  `porelo-checkout_pi-2`, the window keeps the offer on `elsewhere`, its start reported), *the other machine no longer
  lists {name}* (`FakeBackend.takesAway`) and *the machine in front is {name}*.
- **Red** on the unchanged shell: the first scenario `Expected: not null  Actual: <null>` (Open task disabled); the
  second `Actual: 'This window does not know task pi-2 on this machine.'`.
- **Runs:** `dart analyze lib test integration_test tool` No issues found. `planning_story_test.dart`: 48 passed;
  `test/features/planning*_test.dart` with `story_work_test.dart`: 124 passed.
