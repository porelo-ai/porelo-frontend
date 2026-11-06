# F416 — A Started Task Opens Its Terminal

**Status:** Backlog.
**Size:** S - a task this window just started with a person taking part lands on Work with its terminal open and
attached, not on "No terminal is open in it"; the cause is found first, then the opening made sure.

**What must be true.** After *Start work* with the person taking part (with the agent, or a shell), the window lands
on Work → Running on the new task with its terminal open, so the person meets the agent where they land; only where
the machine refuses a terminal does the page say why, with *Open a new terminal*.

## Why

The operator's walk on the rehearsal VM (2026-11-06): after starting the sluice task on rehearsal, the window landed
on Work → Running with the new task, but said "No terminal is open in it" and offered *Open a new terminal*.

## What the code does

- `shell.dart` `_run` waits for the start's operation to end well (`_workInItOnceUp`), refreshes, finds the task (by
  the name given, or the one of the project not running before) and `_openSession`s it: it shows its tab and goes to
  Work. It opens no terminal itself.
- `running_view.dart` `_console` then shows "No terminal is open in it" wherever the machine says the task's terminal
  is not live (`terminalEnded`), which it cannot tell from one never opened.
- So the task was found; its terminal either was never opened, or was the start's own and ended with the operation.

## Plan

- **To be checked first:** on rehearsal, which of the two: whether the start's operation held the task's first
  terminal (the agent attached in the start's output) and closed it when it ended, or none was opened. The answer
  decides the fix; until then the plan below holds for both.
- `_workInItOnceUp`: after the task is found and not refused a terminal (`Sessions.whyNot`), it opens a new terminal
  in it, as *Open a new terminal* does (`running_view.dart` `_openNew`), so the person lands in it.
- **The test that goes red first:** a by-hand start whose operation ends well lands on the task with a terminal
  opened in it (the sessions' stand-in asked once), not on "No terminal is open in it". It guards a person who
  started work to meet the agent and found an empty page.
