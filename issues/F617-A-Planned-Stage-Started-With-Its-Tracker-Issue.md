# F617 — A Planned Stage Started With Its Tracker Issue

```json
{
  "$schema": "issue-1.json",
  "id": "F617",
  "title": "A Planned Stage Started With Its Tracker Issue",
  "state": "Review",
  "size": "S",
  "priority": "Medium",
  "rank": 1,
  "blockedBy": [],
  "covers": "A planned stage of a project kept in a tracker is started with the issue and phase its order names, passed on as Start's work"
}
```

**Why this size.** S: one optional parameter carried through three layers of this repository (client, backend,
planning embedding), with tests at the client and backend levels; it reads a contract and changes none.

**What must be true.** A task the window starts for a planned stage of a project kept in a tracker (GitHub Issues)
knows which issue and which phase it works on, because the window passes on what the planner's order names. A
project kept in Markdown starts exactly as today.

## The contract it builds on

- The planner's `PlanningTaskOrder` gains an optional `work: {issue: "<owner>/<repo>#<number>", phase: "<the
  stage, as the order's result kind names it>"}`, present only for a project kept in a tracker.
- Porelo's `Start` takes `work` with the same shape. Porelo cannot work out the issue itself.

## Plan

- `lib/src/client/models.dart`: `TrackedWork`, a record of `issue` and `phase` (`StartWork` names the window's own
  start already).
- `lib/src/client/porelo_client.dart`, `start`: `work`, sent as `{issue, phase}` only when given. Given and not
  declared by the machine's `Start`, the start is refused with `FeatureNotSupported('Start(work)')`, as for `given`:
  a stage started without its issue would work on nothing it can name. The window checks nothing of its content:
  the planner refuses a malformed order, and Porelo refuses an issue or phase outside its rules with exit code 64,
  said in its words like any refusal.
- `lib/src/app/fleet_backend.dart`, `startOrdered`: the same parameter, passed on; its stand-ins in
  `test/features/support/world.dart`, `test/app/fleet_model_test.dart`, `test/ui/window_task_reports_test.dart` and
  `test/ui/window_task_starts_test.dart` take it.
- `lib/src/ui/planning_embedding.dart`: every task the planner orders that is not a discussion (a planned stage, and
  a main or builder task that works an issue) passes the order's `work` when present. A discussion's order never
  carries it; the planner refuses one that does.
- `pubspec.yaml`: the `porelo_planning` pin raised to the published planner commit whose `PlanningTaskOrder` carries
  `work` (`PlanningWork`); the same screen also shows a carried item's old id beside its tracker reference and offers
  the forge token where the board was refused for want of it.
- `doc/Backend-API.md`, the row "A task the planner orders": `work` named. `CHANGELOG.md`: Changed.

## Acceptance

- Unit level, each seen red before its code: `test/app/start_ordered_test.dart` against `MockDaemon`: `work` reaches
  Start as `{issue, phase}` where Start declares it, and a start with it is refused before Start is asked where Start
  lacks it (harm: a stage runs without knowing its issue). `test/ui/window_task_starts_test.dart`: an order with
  `work` reaches `startOrdered` with it, and one without sends none (harm: as above, or a Markdown project's start
  changes).
