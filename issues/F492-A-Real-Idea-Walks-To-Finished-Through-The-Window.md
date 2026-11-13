# F492 — A Real Idea Walks To Finished Through The Window

```json
{
  "$schema": "issue-1.json",
  "id": "F492",
  "title": "A Real Idea Walks To Finished Through The Window",
  "state": "Review",
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
- The order, each step's reads holding before the next: the window starts and names the project; the Idea is made
  in a discussion task; it is handed in as a story with issues in Idea; a person moves each issue to Backlog; the work
  is proposed and ordered; the builder task is started and its STARTED posted; the agent works under a deadline; its
  ENDED is posted; the offered reader task is started and ended; a person sets the story Finished; then the clean-up.
- All three tasks - discussion, builder, reader - run `pi` with `z-ai/glm-5.3-flash`, as the window rehearsal does.
  The discussion runs in its terminal, the walk typing as the person does; builder and reader run unattended. The forge token of the test identity
  goes, as there, on standard input alone into a vault of the run's own, removed on every ending.
- The clean-up runs on every ending, after a failure too: the task branches and pull requests carrying the run's name
  are deleted, and each repository the planner's store wrote to gets one new commit restoring the tree it had when the
  run started, never a force push; the run's vault and its copy on the VM go with it. It exits non-zero naming
  anything it left.
- A test script: no red-first test and no unit suite of its own; its proof is the run on the VM.

## Acceptance

- One run on the local VM takes an Idea to Finished through the window, its report shows every step `OK` with the
  effect read, and the test organization afterwards holds nothing the run made.
- A step whose effect does not appear stops the run there and names what it asked and what it got.

## How it was built

- `tool/walk_idea.sh` drives the run on the VM and `integration_test/walking_an_idea_test.dart` walks its steps. A
  run writes one line per step to its report with the effect read, and a picture of the window for each step that
  failed.
- The last run went green on every step with the planner's and its probe's builds: the window made the Idea, handed
  it in, moved each issue to Backlog, ordered the work, started the builder and the reader, and set the story Finished.
  The forge held the builder's commit at its task branch at the two steps that read it.
- The clean-up restored each repository the run wrote to with one new commit per repository, removed the task branches
  and the run's vault, and left nothing in the test organization. No test repository's workflow refused the restoring
  commit.
- Every tool the walk needs on the VM is checked by the driver before its first step.
- A machine without a homeserver of its own takes the walk with `--mail drop`, now the default: the run's project then
  goes without mail.

