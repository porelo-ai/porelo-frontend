# F589 — A Planned Task Says What It Works On

```json
{
  "$schema": "issue-1.json",
  "id": "F589",
  "title": "A Planned Task Says What It Works On",
  "state": "Review",
  "size": "S",
  "priority": "Medium",
  "rank": 18,
  "blockedBy": [],
  "covers": "A task the planner ordered says on its tile and row which issues and story it works on and at which stage (in analysis, estimation, reading, rework, implementing), and shows a build line only once a push of it can have one, instead of No build yet on an analysis."
}
```

**Why this size.** The planned offer the window keeps gains the order's role, issues and stage, one line on the tile
and the row from it, and the build line held back for a stage that has pushed nothing; tests of each stage.

**What must be true.** A person looking at *Work* reads what a planned task works on, *PI68 of ST366, in analysis*,
not a build line that fits only an implementing task.

## Found

The operator's live test on a host (snapshot 0.5.1~snapshot.552): after *Start In analysis* for a story's one issue
(Unattended), *Work* > *List* showed the task as *pi · porelo · claude · claude-opus-5-5 via anthropic, named at its
start · on <host> · working*, and below it *No build yet* / *Running the agent*.

## Plan

- **Today**, read in the code:
  - `BuildsSaid.onTheTile` (`lib/src/app/builds.dart`) says *No build yet* for every task whose `buildReader` the
    machine names and that has no build yet, whatever the task is for; the tiles and rows in
    `lib/src/ui/attention_view.dart` show it.
  - The window keeps of a planned task only `PlannedOffer`'s machine, container, offer, provider, project, story,
    task and its reports (`lib/src/app/settings.dart`); the order's role, issues and the stage the person started are
    not kept, so no tile can say them.
  - The task's name (*pi*) is the machine's, from Start; the window names nothing.
- **Steps.**
  - `rememberPlanningOffer` keeps the order's `role`, `issues` and the board's target state (`PlanningTaskOrder`),
    read leniently from older settings (absent: said as today).
  - A planned task's tile and row say *<issues> of <story>, <stage>*, the stage in the board's own word (*In
    analysis*, *Estimation*, *Reading*, *Rework*, *Implementing*), beside its name.
  - The build line: for a stage that writes no code (analysis, estimation, reading), none until the task has pushed;
    for implementing and rework, as today.
- **Red first** (harm: a person reads an analysis as a build that has not run, or cannot tell which issue a task is
  for): a model test that an offer keeps role, issues and stage and reads an older one; a widget test per stage of
  the tile's line and of the build line held back until a push; each seen red.

## Acceptance

- The tests above, each seen red first; `test/ui` and `test/features` green.

## Built

- `PlannedOffer` (`lib/src/app/settings.dart`) keeps the order's `role` and `issues` beside its `result` (kept since
  [F591](README.md#f591)), each read leniently: a stored role that is no upper-case word or issues that are not short
  names read as none. `stage` says the board's word from them: `analysis.json` *In analysis*, `estimate.json`
  *Estimation*, a reader *Reading*, else *Implementing*; `worksOn` is *PI68, PI69 of ST366, in analysis*;
  `writesCode` is false for the first three. `WindowTaskStarts` keeps role and issues as it keeps the offer.
- `Tile.planned` (`lib/src/app/attention.dart`) carries the kept offer of the tile's work; the row says `worksOn`
  under its project line (`tile-works-on`), and an opened cause too (`cause-works-on`).
- `BuildsSaid.onTheTile(task, writesCode:)` says no *No build yet* for a task that writes no code until it pushed;
  a build it has is said as before.
- Tests, each seen red by a deliberate break, then restored from a copy:
  - `test/ui/planned_task_line_test.dart` (new; harm: an analysis read as a build that has not run, an issue not
    told): analysis, estimate, reader, implementing, and work no planner ordered. Red with the build line not held
    back (the three stages: `Found 1 widget with text "No build yet"`), with tiles not given their offer (four red),
    with no *Reading* (the reader red).
  - `test/app/planning_offers_test.dart` *a planned task keeps its role and issues across a restart; an older
    entry has none*. Red with the role not written (`Actual: (null, null, null)`), the issues not written, a stored
    role not checked (`Actual: (main; rm, Implementing, null, true)`), stored issues not checked.
- Runs: `dart analyze` No issues found; the two files above green. `test/ui` and `test/features` not run whole.
- Not checked: a real order of a stage reaches the row only with the planner's PL143 screen (pinned in
  [F591](README.md#f591)); here the offer is kept directly. *Rework* is not told from *Implementing*: no order says it.

- **After the reading** by another model (Claude Sonnet). Red, fixed: a role or issues this build cannot keep threw
  after Start had made the task, so its end went unreported; now they are dropped and the offer kept (test *a role or
  issues that cannot be kept are dropped, and the offer is kept*, red with the throw back). Yellows fixed: a start
  found again by its key keeps role and issues (`PendingStart`), tested in *a stage found again by its key after a
  restart…* (red without them, `Actual: (null, null)`); a ran-out question's tile carries its offer too (no test).

## To be checked

- Whether the task should carry the issue's name instead of the repository's (*pi*): that name is Start's, so
  Agent Core and Agent Planner say whether an order names one; the window then shows it.
- With Agent Core, whether a task that may not push names a `buildReader` at all.
- *Rework*: whether an order can say that its task reworks, so its row says *rework* rather than *implementing*.
- From the reading, left: the running view's tabs (`lib/src/ui/running_view.dart`) carry no offer, read only as tabs;
  no test of `cause-works-on`, of a stage with a build already, or of an older entry's row; a role this build does
  not know reads as *Implementing*.
