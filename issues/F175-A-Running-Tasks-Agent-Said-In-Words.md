# F175 — A Running Task's Agent Said In Words

**Status:** Backlog; blocked by `porelo` [B277](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b277).
**Size:** M - the run view told the task it watches, the agent's state, last line and its age, the start's end marked, *Leave*, and a restart offer when messages wait.

**What must be true.** The view of a task started unattended marks where its start ended (*the task
runs; the agent works now*), then says the agent's state in words: working, with its last output
line and its age; resting; ended. A *Leave* button at the top right closes the view without stopping
anything, as in an attended session; an ended task with waiting messages offers *Start again, N
messages wait*.

## Plan

- **Today**, read in the code: `_beginTheRun` (`shell.dart`) opens `OperationOutputView`
  (`operations.dart`), which knows only the start's stream and says *Running.* until it ends;
  only attended modes go on into a session (`session_view.dart`, with *Leave*).
- **The task:** the view gets the machine, project and task it started. After the start's last
  step it shows a line *The task runs; the agent works now* and below it the task's state from
  `Watch`: `Task.activity` (`WORKING`, `IDLE`, `ENDED`, …; an unknown value rendered as it is),
  the last line by `Tail(last: 1)` and its age from `Task.lastWrote`
  ([B277](https://github.com/porelo-ai/porelo/blob/main/issues/base/README.md#b277)). Silence is
  said as silence (*no output for 4 min*), never as waiting for a message, which an unattended run
  cannot show.
- **Leave:** an explicit *Leave* button once the start is done, the same `Command` as the
  session's; it closes the view, the task runs on.
- **Start again:** when `activity` is `ENDED` and `Task.inboxWaiting` is above 0: *Start again, N
  messages wait*, opening the start form filled with the task's name, agent and mode.
- **Tests, their harm, red first:** *Leave* after the start neither cancels the start nor stops
  the task (work interrupted); *Start again* targets that task's project and machine. Words get no
  test.

## Acceptance

- On the VM: an unattended task shows the start's end, its last line with its age, *Leave* keeps
  it running, and an ended task with a waiting message offers the restart.
