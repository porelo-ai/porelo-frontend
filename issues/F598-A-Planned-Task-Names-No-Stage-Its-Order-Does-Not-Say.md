# F598 — A Planned Task Names No Stage Its Order Does Not Say

```json
{
  "$schema": "issue-1.json",
  "id": "F598",
  "title": "A Planned Task Names No Stage Its Order Does Not Say",
  "state": "Backlog",
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
