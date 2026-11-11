# F475 — The Window Reports Its Planned Tasks To The Planner

```json
{
  "$schema": "issue-1.json",
  "id": "F475",
  "title": "The Window Reports Its Planned Tasks To The Planner",
  "state": "Implementing",
  "size": "M",
  "priority": "Medium",
  "rank": 5,
  "blockedBy": [],
  "covers": "Each task the window started for a story is reported to the planner when it starts and when its agent ends, once per end and across restarts; the planner's follow-up tasks are started once, a stop stops the tasks without a report."
}
```

**Why this size.** the stored offers grow by what a report needs, a reporter that follows the machines' task lists,
the follow-up starts and the stop hook, against a new pin of the planner's package, with unit tests and a feature
scenario.

**What must be true.** A task the window started for a story tells the planner that it started and, once its agent
ended, how it ended, so the story's work on the board follows what the machines did; the planner's next tasks start by
themselves, once; a stopped story's tasks stop. Nothing is reported twice, nothing is lost when the window was closed
while a run ended.

## What it builds against (in words)

- The planner's screen package takes a report of a started task as `taskEvent(project, task, event, offer, container,
  machine, ended)`: the event `started`, `ended` or `stopped`, the offer the planner gave, the container Start made,
  the machine's name as the person sees it (1 to 128 characters, no control characters, no line breaks, no lone
  surrogates), and for an end Porelo's record of the agent's end unmapped: when, whether it finished, why, its answer
  and how many files it left unpushed.
- A provider's source answers a report with the story's work and the follow-up orders still valid, each with an
  offer of its own, which the window starts once through its Start hook for the project and story they came for.
- A report the planner cannot place answers `TaskNotAnswered` (HTTP 404): the planner voided that offer, as it does
  for a story whose work was stopped.
- The screen's `PlanningTaskChanges.stop(source, project, story, tasks)` asks the window to stop tasks whose Start
  was in flight at a stop, or that ran when the story's work was stopped; no report follows, the planner voided their
  offers.

## Plan

- Written while building; see *How it stands*.

## Acceptance

- A started task is reported once as started, on the machine it runs on, and a refused report keeps the task.
- An agent's end is reported once, also after a restart of the window, and an end that came while the window was
  closed is reported when it opens.
- The planner's follow-up orders start once each, also after a retry or a restart; a refused one stops the rest.
- A stop stops each task on its machine with no report and forgets its offer; a report answered `TaskNotAnswered`
  stops the task and is never sent again.
- A machine name the planner must refuse is refused before any call.

## How it stands

- Pinned to the planner's screen package at the change that follows, stops and reports a story's work.
