# F515 — A Terminal And Live List Played Through On The VM

```json
{
  "$schema": "issue-1.json",
  "id": "F515",
  "title": "A Terminal And Live List Played Through On The VM",
  "state": "Backlog",
  "size": "M",
  "priority": "High",
  "rank": 88,
  "blockedBy": [],
  "covers": "Story ST47, a terminal and live list used together, played once on the test VM in the window as a person would, for ST347's gathered story run: a task's terminal used as an ordinary terminal, task list --watch open beside it, Ctrl-C giving the terminal back."
}
```

**Why this size.** M: a new feature file with about eight steps, of which the terminal's own input and the watch's
redraws are new; the task's terminal (`theSessionsTerminal`, `say` in `integration_test/support/idea_walk.dart`), the
terminal on the machine and Porelo's stub agent are there already; the story driver's first form if this is the first
built.

**What must be true.** A run on the test VM shows, or names as missing, what ST47 promises: input typed in the window's
task terminal reaches the task whole, `task list --watch` beside it follows the task's states and its clearance hint,
and Ctrl-C ends the watch and leaves an ordinary prompt.

## Why

- Serves porelo-project's *A terminal and live list used together* (story ST47, porelo-project cb298f4), as its part of
  *Every story played through once, as a user would* (story ST347, porelo-project cb298f4): each High story's test run
  once, automated, on a test VM as a person would play it.

## What the story's test asks

- **Does:** opens a task's terminal in the window and types into it as into any terminal (a line with spaces and
  non-ASCII letters, a pasted block of several lines, a key with Ctrl); opens a terminal on the machine beside it and
  runs `porelo task list --watch` there; lets the task work, ask for clearance and end; presses Ctrl-C in the watch.
- **Sees:** the task's agent received exactly what was typed and pasted; the watch's lines change state as the task
  works and ends, and its hint line names the waiting clearance question while it waits; after Ctrl-C a prompt that
  echoes again, the cursor shown, no screen of the watch left over.

## What exists already

- `integration_test/support/idea_walk.dart` finds the task's terminal of a session (`theSessionsTerminal`) and
  types into it (`say`, `untilQuiet`); `walk_screen.dart` sends Ctrl-chords through `sendKeyDownEvent`.
- `the test machine has Porelo's stub agent` and `work on the test machine was started …` start a task with the stub
  agent; `i store a token … by typing it into a terminal on the machine` opens and types into a terminal on the machine.
- Nothing plays `task list --watch` yet, nor compares what a task received with what was typed.

## How it is run

- One feature file and its test, as the existing ones are, run on the test VM `ubuntu26.04` in this repository's own
  account: the checkout's HEAD copied there, the window started under `xvfb-run` inside `dbus-run-session` through
  `tool/e2e.sh --machine`, as `tool/walk_idea.sh` and `tool/rehearse_window.sh` do. Steps already in
  `integration_test/step/` are reused by their sentence; new steps go beside them.
- The run is driven by one story driver, `tool/play_story.sh check|run --vm USER@VM --vm-key FILE --story <id>
  --report DIR`, modelled on `tool/rehearse_window.sh`: the first of these story issues to be built makes it, the
  others add their story. Its report holds one line per step (`OK`, `FAIL` with what was asked and got, or `EXPECTED`
  with the missing issue), a picture of the window where a step failed, and one closing line per story for ST347's
  gathered run: passed, failed with the step, or waiting on the missing issue.

## Plan

- Steps: `Given the test machine has Porelo's stub agent` and a task of it started; `When I type … into the task's
  terminal` (typed, pasted, a Ctrl-key); `Then the task received it whole and unchanged`, read on the VM from what the
  stub agent recorded of its input; `When I run task list --watch in a terminal on the machine beside it`; `Then the
  watch shows the task working`, `… its clearance hint`, `… the task ended`, each read from the terminal's buffer
  against `porelo task list` read over ssh; `When I press Ctrl-C in the watch`; `Then the terminal gives an ordinary
  prompt back`, proven by an `echo` typed after it coming back once, on a line of its own.
- The task and its project are removed again at the end, as `the task … and the project … are removed again` does.

## Expected failures

- [F105](README.md#f105) (Implementing): a task's terminal in the interface behaving as in a plain terminal; the
  input steps fail on it until it is in Review.
- Porelo's `task list --watch`, an overview that stays open on the daemon's watch stream, with a hint line for
  waiting clearance questions and the terminal reset on Ctrl-C; the watch steps fail until Porelo gives it.

## Note

- A test script is test tooling, not production code: no tests for the test scripts, no red-first, no review loops
  (one Sonnet reading at most). The script is proven by its run on the VM.
- On the VM a failing script is fixed ad hoc on the spot and the run carries on. Every fault found, in the script or in
  the product, is collected, not fixed one by one. After the run: product faults become estimated Backlog issues,
  script fixes go into one commit, then one new run.
- One VM run at a time on this host, through the Coordinator: ask before you start a run and post when it ends. No
  second VM, no Molecule beside it; clean up after.
- A story whose issues are not all in Review yet still gets its script and one run; the run names the missing issue as
  an expected failure.

## Acceptance

- One run on the test VM with a report naming each step of the story: OK, FAIL with what was asked and got, or
  EXPECTED with [F105](README.md#f105) or Porelo's missing `task list --watch`.
- The run leaves no task, project or terminal behind on the VM.

## To be checked

- What the stub agent keeps of its input, so the step can compare it byte for byte; where it keeps none, the step
  reads the task's terminal on the machine through `porelo task attach` in a pty instead.

## Estimate

`F515 size=M est=61 basis=median M 61 (24 records)`
