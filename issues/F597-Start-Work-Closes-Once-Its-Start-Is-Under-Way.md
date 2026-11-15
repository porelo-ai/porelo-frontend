# F597 — Start Work Closes Once Its Start Is Under Way

```json
{
  "$schema": "issue-1.json",
  "id": "F597",
  "title": "Start Work Closes Once Its Start Is Under Way",
  "state": "Review",
  "size": "S",
  "priority": "High",
  "rank": 117,
  "blockedBy": [],
  "covers": "The Planning board's Start work dialog closes once its start is under way, the operation in front carrying the task's progress and any refusal and the planner's answer landing on the board; the dialog stays only for what must be answered before the start begins."
}
```

**Why this size.** S: a pin raise of `porelo_planning` to the planner's commit that lets the starts outlive the
dialog, the window's operation brought in front at the press, a refusal after the close said in the operation and
under *Needs you* (not in a dialog that is gone), and the scenario of `test/features/story_work.feature` turned
round.

**What must be true.** A person who presses *Start* in *Start work* sees the dialog close as soon as the start is
under way and the task's operation in front with its steps; a refusal of the planner before anything starts is still
said in the dialog, one after it in the operation and under *Needs you*.

## Found

The operator's live test (15 November, 15:15Z): *Start work* for ST366 (*Idea* to *In analysis*, porelo-pi, PI68,
unattended) stayed open after the press, saying *Waiting for the planner's answer…* and *Waiting for Start; the window
shows how far it is.*, while the task's start ran behind it (*Preparing and building the task's image, waits on podman
build*). The start runs on by itself, so the dialog could close. [F588](README.md#f588) had left it open, as
closing it at the press is porelo-planner's.

## Plan

- **Today**, read in the code:
  - porelo-planner's screen at the pinned `c8796c6` (`screen/lib/src/ui/story_work_dialog.dart`,
    `screen/lib/src/story_work.dart`): the dialog pops only once `StoryWork.start` returns, which awaits the planner's
    order (`startStoryWork`), then each task's `run.start` through the window's `startTask`, then `run.confirmed`.
    `StoryWork` is the dialog's and is disposed with it, and `owned()` then stops the starts still to come, so the
    window cannot close the dialog without losing them.
  - The window's `WindowTaskStarts` (`lib/src/ui/planning_embedding.dart`) makes the operation at the press and
    answers `startTask` only when Start answers, after the image is built; the operation stands behind the dialog
    until then ([F588](README.md#f588)).
- **Needs of Agent Planner** (an issue of porelo-planner): the task starts and their confirmation run on the board's
  run (`origin.runOf(id)`), not on the dialog's `StoryWork`, so the dialog can pop once the planner took the order and
  the first start was asked, and a refusal after it reaches the board and the window's `onStarted` or its report.
- **Steps** (window), once that commit is pinned:
  - Raise the pin of `porelo_planning` with its lock, the `xterm` override kept.
  - The operation of a board start in front of the board once the dialog closes, as for a discussion
    ([F588](README.md#f588)'s `hitTestable` step, now for *Start work* too).
  - A start refused after the dialog closed: said in its operation and as a *Needs you* row, with
    [F586](README.md#f586)'s words for a sign-in.
  - `test/features/story_work.feature`: the scenario *Start work waits on Start with its mark while the window shows
    how far it is* becomes one where the dialog closes at once and the operation is in front while the stand-in's
    Start still waits.
- **Red first:** that scenario on the old pin: the dialog stays while Start waits.

## Acceptance

- *Start work* closes while Start still runs, and the task's operation is in front with its steps. Seen to fail:
  today's dialog waits.
- A planner refusal before any start is said in the dialog, which stays; a start refused after the close is said in
  the operation and under *Needs you*.
- The board shows the story in its new state once the planner answered, without the dialog.

## Built

- **Planner:** porelo-planner PL146 (`4e0a0a0`, under PL157's `6ac9894`): `StoryWork.start()` answers once the
  planner took the order and the first start was asked, and the remaining starts and their confirmation run on the
  board's run. Built in one commit with [F606](README.md#f606), as the pin brings both.
- **Window:** nothing in the window's start path needed a change. `WindowTaskStarts` already makes the operation at
  the press and brings it in front ([F588](README.md#f588)), and its `onStarted` and Start's refusal do not use the
  dialog's context.
- **Scenarios** (`test/features/story_work.feature`):
  - *Start work closes once its start is under way and the operation shows how far it is* (turned round from *…
    waits on Start with its mark…*): the wizard is closed while the stand-in machine still holds Start, the
    operation shows the image step in front of the board, and once Start goes on the main task runs and the board
    beneath holds the story.
  - *A start refused after Start work closed is said in its operation and under Needs you*: Start refused as
    `SignInNeeded` for codex, after the close. The operation says *codex is not signed in on this machine, so nothing
    was started. Sign it in there, then start again.* and *Needs you* offers to sign codex in on this machine.
- **Red** on porelo-planner `80d29f3` (PL157's wizard before PL146, with the same effort-key fix):
  `Expected: no matching candidates Actual: _TypeWidgetFinder:<Found 1 widget with type "Wizard"`. Green on
  `6ac9894`.
- **Steps:** *the Start work dialog is closed while Start still waits*; *the machine refuses the start of story work
  because {agent} is not signed in* (the stand-in's `orderedFails`). The two steps of the waiting dialog are gone.
- **The board's new state:** the stand-in planner does not move the story on a start, so the scenario proves the
  start running on with the dialog gone and the board beneath still holding the story; the move itself is the
  planner's answer and its own suite's.
- **Runs:** see [F606](README.md#f606)'s *Built*.

## To be checked

- A start the window refuses before Start said anything (no machine for the project, a machine not yet watched, an
  unknown order) makes no operation: it is said on the board's line (`actionProblem`) and in the window's log, not
  under *Needs you*. Found by the reading (Claude Sonnet); not built here.

- The porelo-planner issue and its commit, cited here once filed.
