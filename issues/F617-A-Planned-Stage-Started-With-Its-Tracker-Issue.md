# F617 — A Planned Stage Started With Its Tracker Issue

```json
{
  "$schema": "issue-1.json",
  "id": "F617",
  "title": "A Planned Stage Started With Its Tracker Issue",
  "state": "Backlog",
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

- `lib/src/client/porelo_client.dart`, `start`: a parameter `work` (issue and phase), sent as `work` only when given.
  Given and not declared by the machine's `Start`, the start is refused with `FeatureNotSupported('Start(work)')`,
  as for `given`: a stage started without its issue would work on nothing it can name.
- `lib/src/app/fleet_backend.dart`, `startOrdered`: the same parameter, passed on; its stand-ins in
  `test/features/support/world.dart`, `test/app/fleet_model_test.dart`, `test/ui/window_task_reports_test.dart` and
  `test/ui/window_task_starts_test.dart` take it.
- `lib/src/ui/planning_embedding.dart`: a planned stage's start passes the order's `work` when present. A discussion
  start is left as it is unless the planner's order gives `work` there too (to be checked).
- `pubspec.yaml`: the `porelo_planning` pin raised to the planner commit whose `PlanningTaskOrder` carries `work`.
- `doc/Backend-API.md`, the row "A task the planner orders": `work` named beside `given`. `CHANGELOG.md`: Added.
- Tests, unit level, the first red: `test/client` against `MockDaemon`: `work` is sent as given where `Start`
  declares it, absent where not given, and a start with it is refused on a machine whose `Start` lacks it (harm: a
  stage runs without knowing its issue, or an older machine is sent a parameter it rejects).
  `test/app/start_ordered_test.dart`: `startOrdered` passes it through. `test/ui/window_task_starts_test.dart`: an
  order with `work` reaches `startOrdered` with it, one without does not.

## To be checked

- Which `porelo_planning` commit carries `work` in `PlanningTaskOrder`, and its Dart shape, for the pin.
- Whether a discussion's order can carry `work` as well.
- Which porelo release declares `Start(work)`, for the live-daemon test's list of declared methods.
