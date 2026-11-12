# F520 — An Agents Activity Played Through On The VM

```json
{
  "$schema": "issue-1.json",
  "id": "F520",
  "title": "An Agents Activity Played Through On The VM",
  "state": "Backlog",
  "size": "M",
  "priority": "High",
  "rank": 93,
  "blockedBy": [],
  "covers": "Story ST33, an agent shown working, resting or waiting, played once on the test VM in the window and at the command line as a person would, for ST347's gathered story run: the task card and the CLI compared while an agent works, rests and waits, with Porelo's stub agent and with pi."
}
```

**Why this size.** M: a feature that drives an agent through three activities twice, with the stub agent and with pi on
a low-cost model, and compares the task card with `porelo task list` at each; starting the stub agent, the provider key
from a file and the task's terminal are there.

**What must be true.** A run on the test VM shows, or names as missing, what ST33 promises: at every point where an
attached agent works, rests or waits, the task card in the window and the command line say the same, and rest is never
shown as ongoing work, for Porelo's stub agent and for pi.

## Why

- Serves porelo-project's *An agent shown working, resting or waiting* (story ST33, porelo-project cb298f4), as its part
  of *Every story played through once, as a user would* (story ST347, porelo-project cb298f4): each High story's test
  run once, automated, on a test VM as a person would play it.

## What the story's test asks

- **Does:** attaches to an agent, lets it work, rest and wait on a question of its own, and looks at the command line
  and at the task card each time; then the same with pi.
- **Sees:** both naming the same state each time; rest shown as rest, not as work; waiting shown as waiting on the
  person.

## What exists already

- `the test machine has Porelo's stub agent` and the walk's pi tasks (`tool/walk_idea.sh` with
  `WALK_PROVIDER_KEY_FILE`, the key on standard input into a vault of the run's own).
- `theSessionsTerminal` and `say` type into a task's terminal; `theTask` in `integration_test/support/idea_walk.dart`
  reads a task as the daemon lists it.
- The task card's activity comes from `Activity` in `lib/src/client/models.dart` (working, waiting, idle); nothing
  compares it with the command line.

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

- Steps, for each agent: `Given a task with <agent> attached`; `When I let it work`, `… rest`, `… wait on a
  question of its own`, each brought about through the task's terminal; `Then the card and the command line say
  <state>`, the card read in the window and `porelo task list` read over ssh at the same moment; `Then rest is not
  shown as work`.
- The stub agent's activities are driven by its own commands; pi's by a prompt that makes it work briefly, then end its
  turn, then ask.
- Tasks, the run's vault and its provider key are removed at the end.

## Expected failures

- [F99](README.md#f99) (Backlog): an attached agent shown at rest or working on the card.
- Porelo's `AT_REST` activity, judged from the screen reads the listing already makes, and the stub agent's
  `at_rest`; the rest steps fail until Porelo gives them.
- Porelo's listing saying when a task's agent waits on a person for its own question; the wait steps fail until it
  does.

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

- One run on the test VM with a report naming each step for both agents: OK, FAIL with what was asked and got,
  or EXPECTED with [F99](README.md#f99), Porelo's missing at-rest activity or its missing wait on a person.
- No task, vault or key of the run is left on the VM.

## To be checked

- How the stub agent is told to work, rest and wait from its terminal, once Porelo gives it `at_rest`.

## Estimate

`F520 size=M est=61 basis=median M 61 (24 records)`
