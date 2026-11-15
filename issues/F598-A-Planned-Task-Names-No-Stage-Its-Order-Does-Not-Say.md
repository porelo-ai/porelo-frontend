# F598 — A Planned Task Names No Stage Its Order Does Not Say

```json
{
  "$schema": "issue-1.json",
  "id": "F598",
  "title": "A Planned Task Names No Stage Its Order Does Not Say",
  "state": "Review",
  "size": "XS",
  "priority": "High",
  "rank": 118,
  "blockedBy": [],
  "covers": "A planned task's tile and row name a stage only where its order says one (a result file for In analysis or Estimation, a reader's role for Reading), and otherwise say only its issues and story, instead of Implementing for a task started from the board for In analysis."
}
```

**Why this size.** XS: one getter in `PlannedOffer` (`lib/src/app/settings.dart`) stops guessing *Implementing*,
`worksOn` drops the stage where there is none, and tests of each case; whether its build line shows stays as it is.

**What must be true.** A person who started a story *In analysis* on the board does not read *implementing* on its
task under *Work*: the window says a stage only where the planner's order says it, and nothing it inferred.

## Found

The operator's live test (15 November, ~15:14Z): the task started from the board as ST366 *Idea* to *In analysis*
(porelo-pi, PI68, unattended) showed under *Work* as *PI68 of ST366, implementing*. The project's `work.yml` names no
`result:` yet, so the planner ordered an ordinary MAIN task with no result file; that the task runs as an ordinary
task is expected.

## Plan

- **Today**, read in the code: `PlannedOffer.stage` (`lib/src/app/settings.dart`) says *In analysis* or
  *Estimation* from the order's result file (`analysis.json`, `estimate.json`), *Reading* for a READER, and
  *Implementing* for every other role, so a MAIN task without a result reads as *implementing* whatever the board
  moved. porelo-planner's `PlanningTaskOrder` (pinned `c8796c6`) carries `role`, `issues` and `result` but not the
  board's target state, so the window cannot know it; the stage word is the window's own inference.
- **Steps.**
  - `stage` answers null for a role with no result where the order states nothing more (MAIN, BUILDER, a role this
    build does not know); `worksOn` then says `<issues> of <story>` without a stage.
  - `writesCode` keeps its meaning without the word: a task with no result and no READER role may push, so its build
    line shows as today.
  - Should porelo-planner's order carry the board's target state later, the window takes the stage from it; not
    built here.
- **Red first:** a test of `PlannedOffer` with role MAIN and no result, red today on *implementing*; the existing
  stage tests stay green.

## Acceptance

- A MAIN or BUILDER task with no result file reads *PI68 of ST366* under *Work*, with no stage. Seen to fail: today's
  *PI68 of ST366, implementing*.
- A task whose order names `analysis.json` or `estimate.json` still reads *in analysis* or *estimation*, a READER
  *reading*.
- A role this build does not know names no stage.

## Built

- **Stage:** `PlannedOffer.stage` (`lib/src/app/settings.dart`) answers *In analysis* or *Estimation* from the
  order's result file and *Reading* for a READER, and null for every other role (MAIN, BUILDER, one this build does
  not know); `worksOn` then says `<issues> of <story>` alone, and still null where an earlier build kept no role.
- **Build line:** `writesCode` is spelled from the role and result directly, with the same answers as before: true
  where no role was kept, false for a result file or a READER, true otherwise.
- **Tests:** `test/app/planning_offers_test.dart` *a planned task names a stage only where its order says one* (MAIN,
  BUILDER and an unknown role with no result; the result and reader stages); `test/ui/planned_task_line_test.dart`
  *work whose order names no stage says its issues and story alone, and its build line* in place of *implementing work
  says so*.
- **Red:** `Expected: (null, PI68 of ST366, true)  Actual: (Implementing, PI68 of ST366, implementing, true)`; on the
  row `Found 0 widgets with text "PI68 of ST366"`.
- **Runs:** `dart analyze lib test integration_test tool` No issues found. `planning_offers_test` and
  `planned_task_line_test`: 19 passed. `test/app` whole: 1667 passed, 5 skipped, 41 failed, all in
  `planner_end_test`, `planner_ideas_test`, `planner_log_level_test`, `planner_stage_results_test` and
  `planner_test`, which start or reach a local planner over a socket; `planner_ideas_test` and `planner_test` fail
  the same with `lib/` as on the branch's base.

- **Box:** the build box's Maven `test` phase (format check, `dart analyze --fatal-infos`, `porelo_host`'s tests and the
  whole `flutter test` suite) at `5f5c3e7`: BUILD SUCCESS, 4634 passed, 37 skipped, 0 failed, the planner tests above
  included, so their failures are this laptop's alone. The same at `aea0709`, with every issue of the branch: BUILD
  SUCCESS, 4640 passed, 37 skipped, 0 failed.
