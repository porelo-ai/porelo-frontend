# F588 — A Start From The Board Opens Its Task At Once

```json
{
  "$schema": "issue-1.json",
  "id": "F588",
  "title": "A Start From The Board Opens Its Task At Once",
  "state": "Backlog",
  "size": "M",
  "priority": "High",
  "rank": 12,
  "blockedBy": [],
  "covers": "A discussion or a task started from the Planning board takes the start dialog's way: its operation opens at once with the preparation's steps, then the task's terminal; the board shows the story in analysis while it runs; and the counts the window says agree with what runs."
}
```

**Why this size.** The board's start moves from one awaited call onto the window's operations, which the start
dialog already uses, with the hand-over to the session kept; the board's and the status line's counts checked; tests
on both paths.

**What must be true.** A person who presses *Discuss an idea* on the board sees at once that the machine prepares the
discussion, how far it is, and then the agent's terminal; never a board that only says *Planning changes saved.*
while a task is made behind it.

## Found

The operator's live test on a host (snapshot 0.5.1~snapshot.552), Claude Code signed in: *Discuss idea* on the
board showed *Planning changes saved.* and nothing else for a long while; the board's counts stayed (Idea 2, In
analysis 0). Much later the task stood under *Work* > *Running* (*In a terminal*), its agent already asking its first
question. The status line said *0 tasks there* while it ran.

Then *Start work* for *In analysis* on the idea that came in (Unattended, one repository, one issue): the planning
screen's dialog (porelo-planner's `StoryWorkDialog`) said *Waiting for the planner's answer…* and, under the task,
*Waiting for Start*, every field grey and its start button off, with no mark, step or time. It waits on the window's
start hook, the same `WindowTaskStarts` call, here `startOrdered` through `_startRunning`.

## Plan

- **Today**, read in the code:
  - `WindowTaskStarts._start` (`lib/src/ui/planning_embedding.dart`) awaits `start()`, which for a discussion is
    `FleetBackend.startDiscussion` (`lib/src/app/fleet_backend.dart`) through `_startRunning`: it reads Start's whole
    stream and answers only once the agent runs (the step `AGENT` in state `STARTED`). The steps before, the
    container and the image, are read and dropped; no operation is made, so nothing is shown.
  - Only then `onDiscussionStarted` (`_discussionStarted`, `lib/src/ui/shell.dart`) remembers the task, shows its
    tile and opens its session. A start from the start dialog instead runs `Operations.run` with Start's stream and
    opens that operation at once (`_run` in `lib/src/ui/shell.dart`), its steps shown, then the work.
  - A discussion is no story's task: the window reports it to the planner neither as started nor as ended, so the
    board moves nothing while it runs.
- **Steps.**
  - The board's start runs as an operation of the window's (`Operations.run` with Start's stream, titled for the
    discussion or the ordered task), opened at once; `_startRunning`'s early answer is taken from the same stream,
    so the planner still hears once the agent runs, and a refusal is said as [F586](README.md#f586) says it.
  - The same for a task the planning screen's *Start work* dialog starts (`startOrdered`): its operation opens at
    once beside the dialog, so the person sees the preparation while the dialog waits; the dialog's own mark and
    words are porelo-planner's, handed to Agent Planner (an indicator while it waits on Start, and that the window
    shows the start's progress).
  - Once the agent runs, the operation hands over to the task's session as a start from the dialog does; a
    discussion ordered by the planner after a report (no press) opens no view, its operation only listed.
  - With porelo-planner: whether a discussion running moves its idea to *In analysis* on the board (a report of its
    start, or the planner's own state), said with Agent Planner before building; the window then sends what is
    agreed.
- **Red first** (harm: a person thinks the press did nothing and presses again, starting a second discussion, or
  waits blind): a widget test that a discussion pressed on the board opens an operation at once with the stand-in's
  first step and, once the agent runs, the task's session; a test that the planner is still told once; each seen
  red.

## Acceptance

- The tests above, each seen red first; `test/ui` and `test/features` green; the scenario in
  `test/features/planning_discussion.feature` sees the operation before the session.

## To be checked

- Where *0 tasks there* comes from: no string in `lib` says it, so it is the planning screen's own (porelo-planner)
  or another line; and which project it counts, the board's or the discussion's.
- With Agent Planner, the board's *In analysis* for a running discussion.
