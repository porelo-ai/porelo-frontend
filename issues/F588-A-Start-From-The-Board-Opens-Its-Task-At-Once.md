# F588 — A Start From The Board Opens Its Task At Once

```json
{
  "$schema": "issue-1.json",
  "id": "F588",
  "title": "A Start From The Board Opens Its Task At Once",
  "state": "Review",
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
  - Raise the `porelo_planning` pin to porelo-planner `1e66bf5984dcd7430eb29de72aebda2241a9363f`: the *Start work*
    dialog shows a waiting mark beside *Waiting for the planner's answer…*, and a task's line reads *Waiting for
    Start; the window shows how far it is.*
- **Red first** (harm: a person thinks the press did nothing and presses again, starting a second discussion, or
  waits blind): a widget test that a discussion pressed on the board opens an operation at once with the stand-in's
  first step and, once the agent runs, the task's session; a test that the planner is still told once; each seen
  red.

## Built

- `lib/src/app/fleet_backend.dart`: `startOrdered` and `startDiscussion` take `onEvent`, told each line and step
  Start says (and a certificate's words) as it comes, through `_startRunning` and `_startAnswered`; the early answer
  once the agent runs is unchanged, so the planner is told once, as before.
- `lib/src/ui/planning_embedding.dart`: `WindowTaskStarts` runs what Start says as one of the window's operations
  (`operations`, set by the shell), titled *Discuss an idea in <project>* or *Start the <role> task of <story> in
  <repository>*, on the machine it starts on. The operation is made at Start's first line or step: a start refused
  before it says anything makes none and is said once, on the board, as before. It ends done once the task stands,
  or failed in [F586](README.md#f586)'s words where Start refuses after it said something. `pressed` is the planning
  screen's start hook (`plannerPlanning`'s `startTask`) and opens the operation (`openOperation`); `call`, which the
  reports' follow-up orders use, only lists it.
- `lib/src/ui/shell.dart`: sets `operations` and `openOperation`; *Planning* shows the operation of a start pressed
  there over its page, the page kept built beneath (`Offstage` in a fixed `Stack`), so the *Start work* dialog goes on
  waiting on its start and the board keeps its state; closing the operation shows the board again. Once the agent
  runs, a discussion's session (and a *With you* task's) opens as before, which leaves the operation.
- `pubspec.yaml`, `pubspec.lock`: `porelo_planning` pinned to `8beecc3e6fd49d39a7893baa0beaa58f7f544647`,
  porelo-planner's main (its stack was squashed on the push: 8beecc3 holds 1e66bf5's screen part and
  [F591](README.md#f591)'s), with the GitHub url and `path: screen` unchanged and the lock resolved from the forge;
  pubspec's xterm override is unchanged. Built and tested first on the local 1e66bf5 through a temporary override.
- Tests' stand-ins take `onEvent` (`test/features/support/world.dart`, `test/app/fleet_model_test.dart`,
  `test/ui/window_task_reports_test.dart`, `test/ui/window_task_starts_test.dart`); the world's planning start hook is
  `pressed`, as the window's, and its stand-in can say a step and hold a start (`startSays`, `startHeld`).
- Decided: an operation is made at Start's first word, not at the press, so a refusal before Start says anything is
  not said twice. A discussion the planner orders after a report still opens its session once its agent runs, as
  before; only its operation is listed and not opened. No planning test read the old *Waiting for Start* words.

Guards, each seen red first (break from a copy, restored, `cmp` equal, `git diff --stat` unchanged):

- `test/features/planning_discussion.feature`, *A discussion pressed on the board opens its operation at once, then
  its session* — breaks: *Planning* never shows the planned start's operation, and the discussion's start without
  `onEvent`; red both: "Found 0 widgets with type \"OperationOutputView\"".
- `test/features/story_work.feature`, *Start work waits on Start with its mark while the window shows how far it is*
  — break: the old pin (`1868e5e`, pub get, then pubspec and lock put back from copies); red: "Found 0 widgets with
  text \"Waiting for Start; the window shows how far …\"".
- `test/ui/window_task_starts_test.dart`, *what Start says on the way runs as an operation of the window*:
  - a pressed start opens it, done once the task stands, answered once — breaks: `open: null` (red: "Expected:
    ['operation-1'] Actual: []"); the ordered start without `onEvent` (red: "Bad state: No element").
  - a start nobody pressed is only listed — break: opened for every start; red: "Expected: empty Actual:
    ['operation-1']".
  - refused after it said something ends in the refusal's words — break: the operation not told of the refusal;
    red: "Expected: true Actual: <false>" (`failed`).
  - refused before it said anything makes no operation — break: a line said before Start is asked; red: "Expected:
    empty Actual: [Instance of 'Operation']".
- `test/app/start_ordered_test.dart`, what Start says on the way reaches the caller — break: no line forwarded; red:
  "Expected: ['starting'] Actual: []".

### After the reading

Another model read the change and found nothing clearly wrong; fixed on top, each guard seen red first:

- A start whose answer threw an `Error` of the window's own (a `StateError`, a `TypeError`) left its operation
  running for ever: only `Exception`s were caught. Any throw now ends the operation as failed and goes on as before.
  Guard `test/ui/window_task_starts_test.dart`, *a start that breaks in the window after it said something ends its
  operation as failed*; break: the operation not ended on the catch-all; red: "Expected: false Actual: <true>"
  (`running`).
- The board kept beneath the operation still took keys and ran its animations. It is now in `ExcludeFocus` and
  `TickerMode` while the operation is in front. Guard: the step *the operation is in front of the board*, in both
  scenarios; breaks: `excluding: false` (red: "Expected: true Actual: <false>"), `TickerMode(enabled: true)` (red:
  "Expected: false Actual: <true>").
- What the person sees: a discussion's own dialog closes before Start is asked, so its operation is in front of the
  board at once (now asserted with `hitTestable`). The *Start work* dialog is a route over the window: while it waits
  on Start, the operation stands made behind it, not in front (measured once in the scenario: made, not
  hit-testable), and the dialog says that the window shows how far it is; once the start answers, the dialog closes and
  the operation is in front (asserted). Closing the dialog at the press would need porelo-planner, so it is left.
- A start answering after the window's shell was disposed: the start reads the window's operations when Start says
  something, none once the shell is gone, so it makes no operation then; and `Operations` writes nothing after its
  dispose (`_saveSoon`, `_saveNow`). Guard `test/app/operations_record_test.dart`, *an operation that goes on after
  the window closed writes nothing more*; break: `_saveNow` writes after dispose; red: "Expected: <0> Actual: <2>".
  The live read of the operations has no test of its own.

Not checked: the *In analysis* move of a running discussion (no word from Agent Planner here, see *To be checked*);
the status line's *0 tasks there*; a real host; `test/ui` and `test/features` whole.

## Acceptance

- The tests above, each seen red first; `test/ui` and `test/features` green; the scenario in
  `test/features/planning_discussion.feature` sees the operation before the session.

## To be checked

- `_plannedStarts` in the shell is never pruned: an id per start pressed on the board, for the window's life.
- A start's final reply's output and steps may be said twice in its operation where the machine repeats them there.
- A planner-ordered start that fails after it said something also shows as a failed operation under *Needs you*,
  beside the report's own problem.
- Test gaps: the planner told once is asserted only through the stand-in's count of starts; the path of a start that
  answered without starting (`_Said`) has no operation test; a discussion's operation title is not asserted.

- Where *0 tasks there* comes from: no string in `lib` says it, so it is the planning screen's own (porelo-planner)
  or another line; and which project it counts, the board's or the discussion's.
- With Agent Planner, the board's *In analysis* for a running discussion.
