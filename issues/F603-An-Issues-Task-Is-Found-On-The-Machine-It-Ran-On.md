# F603 — An Issue's Task Is Found On The Machine It Ran On

```json
{
  "$schema": "issue-1.json",
  "id": "F603",
  "title": "An Issue's Task Is Found On The Machine It Ran On",
  "state": "Backlog",
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
