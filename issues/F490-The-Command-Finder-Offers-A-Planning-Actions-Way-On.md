# F490 — The Command Finder Offers A Planning Action's Way On

```json
{
  "$schema": "issue-1.json",
  "id": "F490",
  "title": "The Command Finder Offers A Planning Action's Way On",
  "state": "Implementing",
  "size": "S",
  "priority": "Low",
  "rank": 15,
  "blockedBy": [],
  "covers": "An unavailable planning action in the command finder offers its way on, a runnable step to what holds it, beside the disabled action."
}
```

**Why this size.** one optional field carried from the planner's action into the window's command, one more row in
the command finder, and their tests; the pin of porelo_planning moves to a commit that has the field.

**What must be true.** Where a planning action cannot run and the planner names a way on, the command finder (Ctrl+K)
lists that way on as an entry of its own that runs, beside the action, which stays listed, disabled, with why; the way
on never runs the action itself, and an action that can run offers none.

## Why

porelo_planning, as of porelo-planner 1f3d350, gives a `PlanningAction` an optional `wayOn` (`PlanningWayOn`: a label and what it runs): where
the person goes to settle what holds an unavailable action, such as the run that needs attention. The planner's own
menu shows it already. The window turns every planning action into one of its commands (`planningCommand` in
`lib/src/app/commands.dart`), and the finder lists an unavailable one as "label · unavailable: why" with nowhere to
go from there. The finder's rule is "not yet, and here is what is missing"; the way on is that.

## Plan

- Pin porelo_planning (`pubspec.yaml`, path `screen`) to a porelo-planner commit that gives `PlanningAction` its `wayOn` (1f3d350 or later).
- `planningCommands` in `lib/src/app/commands.dart`: for an action with a `wayOn` that cannot run, one more command
  beside it, labelled with the way on's own words, in the group Planning, that runs `wayOn.run` and is available.
  Its id is the action's with a suffix, so a shortcut or a scoped command never takes it for the action.
- The command finder (`lib/src/ui/command_finder.dart`) needs no change of its own: it lists both.
- Red first: an unavailable action with a way on lists both, the way on runs its own step and never the action; an
  available action with a way on lists the action alone; an action without one lists as today.
