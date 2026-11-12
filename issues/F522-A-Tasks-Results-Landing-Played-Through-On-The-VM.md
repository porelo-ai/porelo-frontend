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
  "covers": "Story ST313, a task's results land where the next step and others find them, played once on the test VM in the window as a person would, for ST347's gathered story run: a reading's findings kept as a file, worked off and deleted by a rework, an idea brought back as an issue in Idea, both commits seen from another computer."
}
```

**Why this size.** M: a walk of one story through Reading and Reworking on the idea walk's support (`tool/walk_idea.sh`,
`integration_test/support/idea_walk.dart`), with a seed that gives the reader something to find, and reads of the
findings file, the issue in Idea and a fresh clone's history.

**What must be true.** A run on the test VM shows, or names as missing, what ST313 promises: a reading's findings lie as
a Markdown file where the project's setting says, a rework started with that state's instructions works them off and
deletes the file, an idea a task brings back is an issue in Idea, and a clone elsewhere shows both commits.

## Why

- Serves porelo-project's *A task's results land where the next step and others find them* (story ST313, porelo-project
  a5b6a2e), as its part of *Every story played through once, as a user would* (story ST347, porelo-project cb298f4):
  each High story's test run once, automated, on a test VM as a person would play it.

## What the story's test asks

- **Does:** runs a story's work with a reading that has findings and a task that brings back an idea; starts the
  rework; then reads the repository on another computer.
- **Sees:** the findings file where the project's setting says; after the rework the findings worked off and the file
  gone; the idea as an issue in Idea; on the other computer both commits in Git's history.

## What exists already

- The idea walk (`walking_an_idea.feature`, `tool/walk_idea.sh`) takes a story through Implementing, Reading and
  Review with a real pi task, seeds the test organization's repositories and puts them back.
- `each issue is in reading for a reader`, `the window starts the offered reader task and it ends`, `the forge holds
  the work of the builder agent`, `the planner holds the story with its issues in idea`.
- Nothing reads a findings file, starts a rework, or reads a second clone.

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

- The seed gives the builder's work a fault the reader is bound to find (a test that fails), and the prompt of one
  task asks it to bring back an idea.
- Steps on the walk's support: `Then the findings file lies where the project's setting says`, read in the forge;
  `When I start the rework the planner offers`; `Then the findings are worked off and the file is deleted`; `Then the
  idea is an issue in Idea`, asked of the planner's probe; `Then a fresh clone shows the findings commit and its
  deletion`, cloned on this host into the run's report directory, not on the VM.
- The walk's own ending puts every repository back at T0.

## Expected failures

- porelo-project's PJ108 (Backlog): ideas and issues checked where the planner keeps them; the idea step fails on it.
- porelo-project's PJ109 (Backlog): where a task's results are kept; the findings steps fail on it.
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
- The test organization's repositories stand at T0 after the run, and the second clone is removed.

## To be checked

- The project setting that names the findings file's place, once porelo-project's PJ109 says it.

## Estimate

`F522 size=M est=61 basis=median M 61 (24 records)`
