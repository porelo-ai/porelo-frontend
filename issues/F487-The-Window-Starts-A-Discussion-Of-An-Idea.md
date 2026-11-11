# F487 — The Window Starts A Discussion Of An Idea

```json
{
  "$schema": "issue-1.json",
  "id": "F487",
  "title": "The Window Starts A Discussion Of An Idea",
  "state": "Backlog",
  "size": "S",
  "priority": "High",
  "rank": 9,
  "blockedBy": [],
  "covers": "When the planner orders a discussion of an idea, the window opens its Start with the project set and no repository to choose, the person picks the agent and the model, and the window starts the read-only task over all of the project's repositories that Core offers, the person driving it."
}
```

**Why this size.** The planner's order and Start are there already (`WindowTaskStarts` in
`lib/src/ui/planning_embedding.dart`, `startOrdered` in `lib/src/app/fleet_backend.dart`); this adds a kind of order,
Start's form for it and the new start call, with widget and model tests.

**What must be true.** A person who chooses *Discuss an idea* in the planner gets the Start they know, picks the agent
and the model, and is in a session with an agent that reads the whole project and changes nothing.

## Why

- Serves porelo-project's *Discuss an idea with an agent in the planner* (story ST319, porelo-project 845d526).
- Today the planner orders tasks for one repository of a story, with a prompt, and the window starts each with
  exactly what the order gives. A discussion has no repository of its own and no prompt: the person drives it.

## Plan

- The planner's task order with role `DISCUSSION` (beside `MAIN` and `READER`, no story, its repository the
  project's repositories read as one) is taken by `WindowTaskStarts` to Start's form instead of being started at once;
  agent, model, mode and brief come as in a story's order. A window that does not know the role refuses it, as today.
- Start's form for it: the project fixed, the repository shown as "every repository of the project, read only" and not
  chosen, the agents and models as Start offers them (`MachinePlanningAgents`), the person driving (no prompt, no
  minutes).
- The start is Core's new option, "read every repository of the project, read only": the task's machine assembles
  the checkout itself from where it takes each repository's main, and throws it away when the task ends; no
  repository of all repositories is needed on a forge, so it works on every kind of host and on a person's machine.
- The task is kept as the planner's, with the order's offer id, so its end reaches the planner
  ([F488](README.md#f488)).

## To be checked

- Core: the start option and how a machine that cannot offer it says so, which the form then shows.
- Planner: the words on its menu item.
