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

- `lib/src/app/settings.dart`: each `planningOffers` entry is a `PlannedOffer`, keyed by machine and container: the
  offer, the provider's name, the project, the story, the task's name, whether its start was reported and the end last
  reported (or the end the task already showed when it started, which is no end of this run). An entry an earlier build
  kept loads and stays, but is not reportable. `planningOffersHanded` keeps every offer handed to Start, the newest
  2000, so a follow-up is never started twice.
- `lib/src/ui/planning_embedding.dart`: `WindowTaskStarts.call` hands the offer before Start is asked, keeps the
  provider, project, story and task once the machine lists the task's name, and tells the reports. `startedOn` falls
  back to the kept offer after a restart.
- `lib/src/ui/planning_reports.dart`: `WindowTaskReports` sends one report at a time through the provider's
  `PlanningSource.taskEvent`: STARTED right after a confirmed start, ENDED for each new `agentEnded` of a watched
  machine's task, with Porelo's record unmapped (`at`, `finished`, `why` from its error, `answer` from its last
  answer, `unpushed`). It looks at the kept offers whenever a machine or the planner changes. A machine name the planner
  must refuse is refused before any call. `TaskNotAnswered` stops the task, forgets its offer and is never sent again;
  another refusal is said on the project's board (the window's status line where no board is open) and not sent again
  in that window's life; a planner not reached is tried again on the next change. The answer's follow-up orders start
  through `WindowTaskStarts` once each, a refused one stopping the rest, and show as the screen's own starts do. `stop`
  stops each task on the machine it was started on, reports nothing and forgets the offer.
- `lib/src/app/planner.dart`: `LocalPlanner.taskEvent` routes to the window's reports, which take it only for an offer
  they keep and send it to the provider kept with that offer.
- Tests, each seen red first: `test/app/planning_offers_test.dart`, `test/ui/window_task_reports_test.dart`; the
  scenario *The end of a task the window started reaches the planner* in `test/features/story_work.feature`, on the
  package's stand-in.

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
- The pin changes what the board shows: offers are UUIDs, findings carry a number, a stop keeps the story's tasks shown
  until reports confirm them ended, and the working count counts stories with tasks at work.
- The feature scenarios' machine names a task started for a story by its container, as Porelo does.
- An end is told apart by its time, whether it finished and how many files it left unpushed; two ends with no time and
  the same two values read as one.
- A report a crash cut off between the planner's answer and the settings write is sent again after the restart.
- A STARTED report already sent when a stop arrives for that task reaches the planner; it answers as for any voided
  offer.

## To be checked

- Against a real planner and machine: a report's round trip, `TaskNotAnswered` for a voided offer, and follow-up
  orders the planner answers after an end.
