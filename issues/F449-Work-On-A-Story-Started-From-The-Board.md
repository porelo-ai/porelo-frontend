# F449 — Work On A Story Started From The Board

**Status:** Backlog; blocked by [F447](README.md#f447).
**Size:** M - a variant of the start dialog filled by the machine's proposal, the start and stop of a story's work,
the agent's outcome where its run ended and its entry under *Needs you*, and a feature file; no task name or
repository typed.

**What must be true.** Dropping a story on a working state (*In analysis*, *Implementing*, …) opens *Start work*: how
to work (*Unattended* or *With you*, only those the project allows), the agent, and the model the project proposes for
that state, changeable. The tasks to be started (one per repository of its issues, or one for the story), whether
the project's coordinator is started or told, and the work order the agent gets are shown, not typed. Starting sets
the working state; the machine sets the done state when the run ends with the agent's *done*, or leaves the operator
a *Needs you* entry with the agent's words.

## What it builds against (in words)

- The modes are `UNATTENDED` and `AGENT`, shown as *Unattended* and *With you*.
- The work and the coordinator run on the machine where the operator starts the work; the proposal and the start are
  asked of that machine.
- A proposal for a story and a target working state: the modes allowed, the proposed agent and model, the work order,
  the tasks (name, repository, the issues each covers), and whether the coordinator is started or only told.
- A start with the mode, agent and model chosen and the board's revision: the machine sets the working state, starts
  the tasks and, if none runs, the coordinator, and answers them; refused when the move is not allowed from the
  story's state, or the revision is stale.
- The work running on a story (tasks, coordinator, mode, agent, model, since), and a stop of it. A stopped work leaves
  its items in their working state, marked nobody at work, until the operator moves them. Its tasks are named
  from the story and the repository (`st294`, `st294-porelo`), the coordinator's task is `coordinator`.
- A story's work that ended without its done state carries `ended` (the agent's words, why) on the story's work and
  on the watch of the stories; that is what *Needs you* shows. The machine's event log is not read for it.
- A task's ended run carries the agent's last answer; the machine reads its last line `Outcome: done` or
  `Outcome: blocked - <why>` and sets the done state or leaves an entry under *Needs you*.

## Plan

- `lib/src/app/story_work.dart` (new), a `ChangeNotifier` like `StartWork`: asks the proposal, holds the choices,
  starts, and says the machine's refusal in its words.
- `lib/src/ui/story_work_dialog.dart` (new), after the design: the story and the move (*Accepted → In analysis*), *How
  to work* as two choice cards with the machine's words for each, *Agent* and *Model* reusing the start form's
  pickers (`start_work_view.dart`: the agent list and `start-model`, with the proposal's hint), the tasks list with
  *Name and repository come from the story and its issues; nothing to type.*, the coordinator's sentence, the work
  order shown read-only, and two buttons: the start, labelled by what it does (*Start the analysis*, *Start 2 tasks*), and *Cancel*. There is
  no way to enter a working state without its work: a working state always has an agent at work (the operator,
  2026-11-09).
- The machine the work runs on is chosen in the dialog among the watched machines, the one shown first; the proposal
  is asked again when it changes.
- *With you*: the terminal opens on `coordinator` with several repositories, on the story's one task otherwise, as a
  work session opens today (`running_view.dart`).
- The card and the story screen show the work running from the board's answer; the story screen offers *Stop the
  work*, asked first, saying the story stays in its working state with nobody at work until it is moved.
- The ended tile (`attention_view.dart`) shows the agent's last answer where the run ended for a story's work, beside
  what it already says of the run.
- *Needs you* (`lib/src/app/attention.dart`) gains a row for a story whose work ended without its done state: the
  story, the agent's words from `ended`, and *Open story*; it leaves once the story moves on.
- `test/features/story_work.feature`: a drop on *In analysis* opens the dialog filled by the proposal; only allowed
  modes are offered; a changed model is the one started; several repositories start several tasks and say the
  coordinator; a refused start keeps the story where it was with the machine's words; work ended blocked shows under
  *Needs you* with the agent's words. First red: a mode the project
  does not allow offered in the dialog.

## Acceptance

- Nothing in the dialog is typed but the choices; the tasks, names and repositories are the machine's.
- After *Start*, the story stands in the working state the machine set, and its card says the work running.
- A refused start changes nothing on the board and says why.

## Open questions

- None; *Change state only* is dropped (the operator, 2026-11-09).

## To be checked

- Nothing yet; the names once the daemon's part is served.
