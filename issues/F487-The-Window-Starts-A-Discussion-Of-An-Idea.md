# F487 — The Window Starts A Discussion Of An Idea

```json
{
  "$schema": "issue-1.json",
  "id": "F487",
  "title": "The Window Starts A Discussion Of An Idea",
  "state": "Review",
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

## How it stands

- The planner's order with role `DISCUSSION` and a result file is not started at once: `WindowTaskStarts`
  (`lib/src/ui/planning_embedding.dart`) opens Start's form for it, `DiscussionStartDialog`
  (`lib/src/ui/discussion_start_dialog.dart`), with the project fixed and "every repository of the project, read only",
  the machine's agents offered with the order's first, and the order's model; turned away, nothing starts.
- The start is Core's Tasks1 `Start` with `allRepositories` and `result` (`FleetBackend.startDiscussion`), no
  repository, the person driving it; it is no story's task, so no run is told of it.
- A machine whose Porelo does not declare `allRepositories` and `result` on `Start` says so on the form before anything
  is chosen (`FleetBackend.whyNoDiscussion`), and the form offers no Start; one that refuses at the start says so in its
  own words, back to the planner. Start waits until the machine has said; a check that failed is said and offers no
  Start. The machine is asked again before the person is asked and before the offer is handed, so a machine that
  cannot keeps the offer unhanded; a read of the contract that failed is asked again next time, not kept.
- The person chose for the machine the form named: one that no longer carries the project once they chose starts
  nothing.
- A started discussion opens its session under *Running* at once (`WindowTaskStarts.onDiscussionStarted`, the shell's
  `_discussionStarted`).
- Tests: test/features/planning_discussion.feature (the agent picked, every repository read only; turned away starts
  nothing; a started discussion opens its session), test/ui/discussion_start_test.dart, test/ui/window_task_starts_test.dart,
  test/client/whole_project_test.dart.
- Left to [F488](README.md#f488): the discussion's end and its idea file handed to the planner.
- Left to porelo-planner: its board shows the refusal `NotStarted` (the person turned the form away) as an error; asked
  to take it quietly.

## To be checked

- Core: the start option and how a machine that cannot offer it says so, which the form then shows.
- Planner: the words on its menu item.
