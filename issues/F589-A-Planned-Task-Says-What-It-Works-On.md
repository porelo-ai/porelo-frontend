# F589 — A Planned Task Says What It Works On

```json
{
  "$schema": "issue-1.json",
  "id": "F589",
  "title": "A Planned Task Says What It Works On",
  "state": "Implementing",
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

## To be checked

- Whether the task should carry the issue's name instead of the repository's (*pi*): that name is Start's, so
  Agent Core and Agent Planner say whether an order names one; the window then shows it.
- With Agent Core, whether a task that may not push names a `buildReader` at all.
