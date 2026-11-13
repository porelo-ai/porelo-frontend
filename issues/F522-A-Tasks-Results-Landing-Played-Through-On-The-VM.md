# F522 — A Tasks Results Landing Played Through On The VM

```json
{
  "$schema": "issue-1.json",
  "id": "F522",
  "title": "A Tasks Results Landing Played Through On The VM",
  "state": "Backlog",
  "size": "M",
  "priority": "High",
  "rank": 95,
  "blockedBy": [],
  "covers": "Story ST313, a task's results land where the next step and others find them, played once on the test VM in the window as a person would, for ST347's gathered story run: a reading stopped by its blocking findings as the planner shows them, a rework chosen for them, the next reading finding them worked off, and an idea a task brought back as an issue in Idea."
}
```

**Why this size.** M: a walk of one story through Reading and Reworking on the idea walk's support (`tool/walk_idea.sh`,
`integration_test/support/idea_walk.dart`), with a seed that gives the reader something to find, and reads of the
findings and the issue in Idea where the planner and the window show them.

**What must be true.** A run on the test VM shows, or names as missing, what ST313 promises: a reading's blocking
findings stop it, and the planner shows them on the issue under Needs you; a rework chosen there works them off, and the
next reading finds nothing blocking and sets the issue to Review; an idea a task brings back is an issue in Idea.

## Why

- Serves porelo-project's *A task's results land where the next step and others find them* (story ST313, porelo-project
  a5b6a2e), as its part of *Every story played through once, as a user would* (story ST347, porelo-project cb298f4):
  each High story's test run once, automated, on a test VM as a person would play it.

## What the story's test asks

- **Does:** runs a story's work with a reading that has blocking findings and a task that brings back an idea; chooses
  Rework for the stopped reading under Needs you; lets the window run the rework and the next reading.
- **Sees:** the reading stopped and its blocking findings on the issue's Needs-you entry; after the rework and the next
  reading the issue in Review, needing nobody, and gone from Needs you; the idea as an issue in Idea.

## What exists already

- The idea walk (`walking_an_idea.feature`, `tool/walk_idea.sh`) takes a story through Implementing, Reading and
  Review with a real pi task, seeds the test organization's repositories and puts them back.
- `each issue is in reading for a reader`, `the window starts the offered reader task and it ends`, `the forge holds
  the work of the builder agent`, `the planner holds the story with its issues in idea`.
- Nothing read a reading's findings or chose a rework before this story.

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

- A reader's findings are the one `Findings:` block its answer ends with. The planner judges it (`WorkEnds.judge`) and
  keeps the answer and the findings in its own work record, not in Git. There is no findings place in `project.yml` or
  in porelo.
- The walk's own seed, `tool/walk-seeds/a_tasks_results_land`, is written over the seed given: a test in `foo-1` that
  cannot pass as written and that the story's issue does not touch, and the story's work rules (`stories/work.yml`),
  whose reading order asks for such a test as a blocking finding, whose rework order asks to work off every blocking
  finding, and whose builder order asks the task to propose one idea of its own through Porelo.
- Steps on the walk's support, after the readers end: `Then the idea a task brought back is an issue in Idea`, read in
  the issue repositories and asked of the planner's probe; `And the planner shows the reading's blocking findings and
  Needs you lists the issue`, the probe's attention `BLOCKING_FINDINGS` and the findings under the issue's entry;
  `When I choose Rework for the stopped reading`, from that entry; `And the window starts the offered rework task and
  it ends`; `Then the planner shows the findings worked off`, the issue read again and in Review, needing nobody, and
  gone from Needs you.
- The walk's own ending puts every repository back at T0.

## Expected failures

- A task handing its ideas to the planner, whose backend, and before it the window, checks that an idea or an issue
  holds every field it must; the idea step fails until that holds.
- A task proposing an idea of its own (`Tasks1.ProposeIdea` in porelo, with the project's allowance of ideas): until
  porelo offers it, the builder cannot bring back an idea, and the idea step fails.
- [F492](README.md#f492) (Implementing): the real walk this script stands on; a fault in its steps names it.

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

- One run on the test VM with a report naming each step: OK, FAIL with what was asked and got, or EXPECTED with the
  missing issue.
- The test organization's repositories stand at T0 after the run.

## Estimate

`F522 size=M est=61 basis=median M 61 (24 records)`
