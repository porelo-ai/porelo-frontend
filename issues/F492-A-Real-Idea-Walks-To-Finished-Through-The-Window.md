# F492 — A Real Idea Walks To Finished Through The Window

```json
{
  "$schema": "issue-1.json",
  "id": "F492",
  "title": "A Real Idea Walks To Finished Through The Window",
  "state": "Backlog",
  "size": "L",
  "priority": "High",
  "rank": 1,
  "blockedBy": [],
  "covers": "On a local VM, an Idea made in the real window against a real porelo and planner goes through every state to its story Finished, one real low-cost task included, each step read from its effect."
}
```

**Why this size.** a walk script and its integration test here, one shared run with the planner's side, a real task on
the test organization and its clean-up; it crosses repositories, so L, though it is a test script built with little
effort.

**What must be true.** On a local VM, with a real installed `porelo` and a real planner, a person in the window makes
an Idea and takes it through every state until its story is set Finished, as a real user does, including one real,
low-cost task started with a real agent in the test GitHub organization. Nothing on the way is faked, and each step is
judged by its observed effect - the board, the files, the forge - never by what the window reports about itself.

## Plan

- The window runs headless on the VM (`xvfb-run` inside `dbus-run-session`) in this repository's account, driven step
  by step as `tool/rehearse_window.sh` drives a move: a new integration test beside `rehearsing_a_move_test.dart`
  walks the states, and a driver script copies this checkout's HEAD to the VM, runs it through `tool/e2e.sh` and writes
  one line per step (`OK`, `FAIL`, `SKIPPED` with why) and a picture of the window for each one that failed.
- One shared run with the planner's side, not two, in this repository's account on the VM. This side drives every
  step a person takes in the window - making the Idea, each move a person makes, starting the task - and reads each
  effect. The planner's side owns the planner app on the VM against the real `porelo`, every move the planner makes by
  itself (the work proposal's starts, the reading rounds' moves, the move to Review), the task start on its side and
  its result coming back, each with its read (its board and work answers, the store's files, the forge).
- After each step the driver reads the effect itself: the board through the planner's own read, the project's files
  in its repository, the task and its branch through `porelo` and the forge.
- The task runs `pi` with `z-ai/glm-5.3-flash`, as the window rehearsal does. The forge token of the test identity
  goes, as there, on standard input alone into a vault of the run's own, removed on every ending.
- Everything the run makes in the test organization carries the run's name - the project's issues, the task's branch
  and pull request - and the run deletes exactly those at its end, after a failure too, and exits non-zero naming
  anything it left.
- A test script: no red-first test and no unit suite of its own; its proof is the run on the VM.

## Acceptance

- One run on the local VM takes an Idea to Finished through the window, its report shows every step `OK` with the
  effect read, and the test organization afterwards holds nothing the run made.
- A step whose effect does not appear stops the run there and names what it asked and what it got.

## To be checked

- The order of the steps, fixed with the planner's side once its list of steps and reads stands.
- Every tool the walk needs on the VM, checked there before the first run.
