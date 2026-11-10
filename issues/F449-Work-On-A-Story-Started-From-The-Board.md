# F449 — Work On A Story Started From The Board

```json
{
  "$schema": "issue-1.json",
  "id": "F449",
  "title": "Work On A Story Started From The Board",
  "state": "Implementing",
  "size": "M",
  "priority": "Medium",
  "rank": 4,
  "blockedBy": [],
  "covers": "*Start work* for a story: the planner's screen orders the tasks, the window starts each with Porelo's *Start* on the machine that carries the project, keeps its offer and opens a task started *With you*."
}
```

**Why this size.** a variant of the start dialog filled by the machine's proposal, the start and stop of a story's work,
the agent's outcome where its run ended and its entry under *Needs you*, and a feature file; no task name or
repository typed.

**What must be true.** Dropping a story on a working state (*In analysis*, *Implementing*, …) opens *Start work*: how
to work (*Unattended* or *With you*, only those the project allows), the agent, and the model the project proposes for
that state, changeable. The tasks to be started (one per repository of its issues, or one for the story), whether
the project's coordinator is started or told, and the work order the agent gets are shown, not typed. Starting sets
the working state; the machine sets the done state when the run ends with the agent's *done*, or leaves the operator
a *Needs you* entry with the agent's words.

## What it builds against (in words)

- The planning screen is the planner's package, embedded in the window. It reads the proposal, takes the choices and
  asks the planner for a checked order: one task per repository's main agent and per kept builder, each with its
  offer (where the planner gives one), repository, issues, role, agent, model, mode and prompt. The dialog, the
  proposal, the rounds, the comment, the stop, the reading decisions and the ended rows under *Needs you* are the
  planner's.
- The screen hands each task of the order to the window's start hook, one at a time and in order:
  `PlanningStartTask(source, project, story, task)`, answered by `PlanningTaskStarted(task, container)`. A
  `PlanningRefusal` thrown by the hook stops the rest of that order and shows on that task alone. Once the order
  ends, the screen tells the window what was started: `PlanningTaskChanges.started(source, project, story, tasks)`,
  each task with the order it was started for.
- The modes are `UNATTENDED` and `AGENT`, shown as *Unattended* and *With you*.
- What the window tells the planner of a task it started is `taskEvent(project, task, event)` today, the event
  `started`, `ended` or `stopped`. The agreed shape adds the offer, the container and, for an ended run, when it
  ended, whether it finished, why, the agent's answer and what it left unpushed, taken unmapped from the machine's
  record of the agent's end; the planner's screen does not offer that shape yet.
- Porelo's `Start` takes the project, the repository, the agent, the model, the mode and the prompt, and answers the
  container it made on its final reply; a refusal is an action of its own (`RUNNING`, `NEEDS_VAULT`, …) or a named
  error. It does not answer the task's name within the project, which `List` gives beside the container.

## Plan

- `lib/src/ui/planning_embedding.dart`: `WindowTaskStarts` is the start hook. It picks the machine with
  `plannedTaskMachine`: of the watched machines that carry the project (list it), its host where a host carries it,
  else the one the window is connected to first among them; where none carries it, the machine the window is
  connected to. It starts the task there with `FleetBackend.startOrdered`, exactly as the order gives it, keeps the
  order's offer beside the machine and the container Start answered, reads the task's name from the machine's list
  by that container, and answers both. A refusal by Start, an unnamed one with what the machine printed, becomes a
  `PlanningRefusal` in the machine's words; no machine to start on is refused too. `EmbeddedPlanning.startedOn`
  says on which machine a started container runs. The former `plannerStartTask`, `startedTasks` and
  `startedTerminal`, built on the planner's former start answer, are gone.
- `lib/src/app/fleet_backend.dart`: `startOrdered` sends `Start` with those six arguments and `now`, as the window's
  own start dialog does, certifying what a host asks as every start does, and answers the final reply with what was
  printed before it (shared with `startAgain`). With `now`, Start answers once the task stands, not when its agent's
  run ends.
- `lib/src/app/settings.dart`: `planningOffers`, each `{machine, container, offer}`, read field by field and an entry
  that does not read skipped. `lib/src/app/fleet_model.dart` tells `onRemoved` the container of a task the machine
  confirmed it removed, and `lib/src/app/machines.dart` drops that task's offer then.
- `lib/src/ui/shell.dart`: `_storyWorkStarted` opens the terminal of the task started *With you*, the main one where
  there is one, on the machine it was started on, as a session opens anywhere else in the window: the machine's
  listed task, or the task as Start answered it until the list shows it.
- Tests, each seen red first: `test/app/planning_offers_test.dart`, `test/app/fleet_model_test.dart` (a confirmed
  removal is told, a refused one is not), `test/app/start_ordered_test.dart` (tagged `linux`: the mock daemon on a
  unix socket), `test/ui/window_task_starts_test.dart`, and the scenario *With you opens the terminal of the task the
  window started* in `test/features/story_work.feature`.

## Acceptance

- A task of an order starts on the machine that carries its project, its host where one does, with exactly the
  order's project, repository, agent, model, mode and prompt; the screen gets the task and container Porelo
  answered.
- A refusal by Start shows on that task in the machine's words, and the tasks after it are not started.
- An order's offer is kept beside the machine and container across a restart, and dropped once the machine confirms
  the task removed; a refused removal keeps it.
- A task started *With you* opens in its terminal on the machine it runs on.

## How it stands

- Built against the planner's screen at the change that hands a story's checked tasks to the window's Start one at
  a time, pinned in `pubspec.yaml` by its commit on the planner's `main`.
- `taskEvent` keeps the planner's present shape; the window calls it nowhere yet. The agreed shape, with the offer,
  the container and the run's end, waits on the planner's screen.
- The hook sends `Start` with `now`, as the window's own start dialog does: without it, a prompted `Start` answers
  only when the agent's run ends, so the screen's next task and a *With you* terminal waited on that run. It now
  answers once the task stands; a test with a stand-in whose `Start` without `now` never ends holds it.
- A task removed outside the window (the command line, another window) keeps its offer in the settings until the
  window removes a task of the same container name.
- The planning scenarios follow the pinned screen: a refused save refuses its whole batch, every card of it shows
  the refusal and the board's banner stays until the batch is saved or undone; a proposal offers only builders to
  keep, change or drop, since readers follow the building; a started story stays in its state, and its work names no
  coordinator, until the planner is told its tasks started.

## To be checked

- Against a real machine: that a start which goes through answers `CREATE` or `RESUME` with its container, and how a
  refusal before anything is made (a model the agent does not take) answers.
