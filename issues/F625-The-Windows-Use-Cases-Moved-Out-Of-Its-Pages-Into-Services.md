# F625 — The Window's Use Cases Moved Out Of Its Pages Into Services

```json
{
  "$schema": "issue-1.json",
  "id": "F625",
  "title": "The Window's Use Cases Moved Out Of Its Pages Into Services",
  "state": "Idea",
  "size": "L",
  "priority": "High",
  "rank": 1,
  "blockedBy": [],
  "covers": "A page's handler only checks its input, calls one service and shows its answer; starting and reporting planned tasks, handing a forge token on and porelo-host's commands move into services tested without widgets"
}
```

**Why this size.** L: four use cases of a few hundred lines each move out of the UI layer and the host command's
entry, each with its tests moved from widget level to unit level; no contract changes.

**What must be true.** A widget's handler, and `porelo-host`'s command entry, only check what was given, call one
service method and show or print its answer. The use case (what is kept, in which order, under which rule, what is
told the planner or the vault) lives in a service that knows nothing of widgets, a `BuildContext` or the command line,
and is tested without them.

## Plan

Read in today's code; the entry points that carry a use case:

- `lib/src/ui/planning_embedding.dart`, `WindowTaskStarts.call`: chooses the machine, hands and keeps the offer in the
  settings, picks discussion or ordered start, maps refusals and says them under *Needs you*. Moves to
  `lib/src/app/planned_task_starts.dart`; the UI keeps the operation shown and the person's choice of agent.
- `lib/src/ui/planning_reports.dart`, `WindowTaskReports`: reports, stops, the sweep, handing ideas and stage results
  to the planner, with their queue and kept state. Moves to `lib/src/app/planned_task_reports.dart`.
- `lib/src/ui/organization_access_dialogs.dart`, `_handForgeTokenOn` (behind `prepareOrganizationForge` and
  `prepareForgeForPlanning`): the vault's declaration rules, the hand-on and its refusals run inside dialog code with
  a `BuildContext`. The rules move to a service in `lib/src/app/`; the dialogs keep the asking.
- `packages/porelo_host/bin/porelo_host.dart`, `runHostCommand`: parses and runs each command in one function. Each
  command becomes a service method the entry maps arguments to and whose result it prints.
- Steps: one use case at a time, its widget tests turned into unit tests over the service first (they must pass
  unchanged in meaning), then the handler reduced to the mapping.

## To be checked

- Further handlers in `lib/src/ui/shell.dart` (7800 lines) that run a use case themselves, found by reading its
  `await` chains on a backend, settings or the vault; each is added here before the build.
