# F523 — Work Moving On By Itself Played Through On The VM

```json
{
  "$schema": "issue-1.json",
  "id": "F523",
  "title": "Work Moving On By Itself Played Through On The VM",
  "state": "Implementing",
  "size": "M",
  "priority": "High",
  "rank": 96,
  "blockedBy": [],
  "covers": "Story ST314, the planner moves work on from state to state by itself, played once on the test VM in the window as a person would, for ST347's gathered story run: DONE work set to Reading with its reader started unasked, an OK reading set to Review, a blocking one stopped under Needs you and reworked once the person chooses Rework, a failed task kept with a warning."
}
```

**Why this size.** M: three branches of the idea walk past Implementing (an OK reading, a blocking one, a failed task),
each with its reads of the board, Needs you and the tasks; the walk to Reading and Review is there in
`walking_an_idea.feature`.

**What must be true.** A run on the test VM shows, or names as missing, what ST314 promises: work that ends DONE goes to
Reading and its reader starts with no dialog, an OK reading sets Review, a blocking one stops with its findings under
its Needs-you entry until the person chooses Rework there, whereupon the issue stands in Reworking and the window runs
the rework, and a failed task keeps its card with a warning and a Needs-you entry to its result.

## Why

- Serves porelo-project's *The planner moves work on from state to state by itself* (story ST314, porelo-project
  cb298f4), as its part of *Every story played through once, as a user would* (story ST347, porelo-project cb298f4):
  each High story's test run once, automated, on a test VM as a person would play it.

## What the story's test asks

- **Does:** lets an issue's work end DONE in Implementing and watches; lets one reading end OK and another end
  blocking; chooses Rework on the stopped reading's Needs-you entry; lets a task fail.
- **Sees:** Reading set and the reader started without a dialog, with the proposed model; Review after the OK
  reading; the blocking reading stopped, its findings under its Needs-you entry; after Rework is chosen, the issue in
  Reworking and its rework run by the window to its end; the failed task's card kept, with a warning and a Needs-you
  entry to its result.

## What exists already

- `the window posts the end of the builder task`, `each issue is in reading for a reader`, `the window starts the
  offered reader task and it ends` and `the story stands in review` walk DONE to Reading to Review; today the reader is
  started by a step, not unasked.
- `theNewTask`, `untilItEnds` and `theIssueStandsIn` in `integration_test/support/idea_walk.dart` read tasks and the
  board.

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

- A blocking reading does not set Reworking by itself: the planner stops it, keeps the reader's findings in its own
  work record (not in Git) and lists the issue under Needs you, where the person chooses Review anyway, One more
  round or Rework. The story plays the Rework choice, as the results story ([F522](README.md#f522)) does.
- The walk's own seed, `tool/walk-seeds/the_planner_moves_work_on`, is written over the seed given: in `foo-2` a test
  that cannot pass as written, and the story's work rules (`stories/work.yml`) with one reader per repository, a
  reading order that names such a test a blocking finding and a rework order that works off every blocking finding.
  So the first issue's reading ends OK and the second's stops.
- Steps: `Then Reading is set and its reader runs with no dialog shown`, the reader's task read on the VM with its
  model; `Then the first issue stands in Review`; `And the second's reading stops on its blocking findings and Needs
  you lists it`, the probe's attention `BLOCKING_FINDINGS` and the findings under the issue's entry; `When I choose
  Rework on its Needs-you entry`, sent once the dialog offers it; `Then the window runs the rework and it ends`, the
  second in Reworking and its rework started by the window; `Then the failed task's card stays, with a warning and a
  Needs-you entry to its result`. The helpers to read the findings and to choose Rework are shared with the results story.
- The walk's own ending removes tasks and puts repositories back at T0.
- The rework step judges the second issue only once its rework is bound to its offer: the window reports a start a
  while after porelo lists the task, and the planner sets Reworking only on that report, so one read right after the
  task appeared found the issue still in Reading. Since the issue stood in Reading before and a quick rework moves it
  on again, the step proves the move itself: the forge of the issue's repository holds a move to Reworking since the
  run's seed, and the board shows the issue in Reworking, Reading or Review.

## Expected failures

- The real walk of an idea to Finished, built since: the walk this script stands on.
- A reader started naming the work it reads, built since.
- A started offer found again by its key, built since.
- Whether the reader on the VM names the seeded test a blocking finding is known only from a run; if it does not, the
  second's reading ends OK and the stop step fails.
- porelo-planner carrying one story in a real run beside a real installed Porelo, and work moving on by itself from a
  move on the board: the Start dialog filled with the project's defaults and the chain of build, reading and review
  running on, asking the person where a reading blocks.
- Porelo's start taking an opaque key from its caller, at most 200 characters, kept with the task and given back by
  List and Watch.

## Runs so far

- The latest run on the test VM `ubuntu26.04`, in this repository's own account, with porelo 0.5.1~snapshot.564 and
  porelo-planner 8f8a2ef: all 25 steps green, the last two after a resume from walk step 13. It shows all that ST314
  promises: DONE work is set to Reading, and its reader starts with no dialog; the OK reading sets Review; the second
  issue's reading stops on the seeded test as a blocking finding, listed under Needs you; Rework chosen there runs the
  rework to its end, its push forwarded and read again; and the task on a refused key fails, its card kept with "Waits
  on you" and a way to its Needs-you entry. No fault of the window was found.
- After the run: the test organization holds none of the run's repositories, and the VM account holds no task, no
  planner state and no copy of the run.
- The walk tool the run used is not on `main` yet: the Start work wizard filled step by step, the gate forwarding of
  the builders' and the rework's pushes, and the seeds' `workflow.yml` and `issues/README.md` stand on a branch of their
  own, with the fix of finding 4 below.
- Findings, for one commit of walk-tool fixes and then one fresh run:
  1. That branch lacks the fix of [F631](README.md#f631): the first `flutter pub get` of the run's copy on a VM whose
     pub mirror holds the earlier planner pin drops `markdown`, and the window does not start. It is rebased onto
     `main`.
  2. The forward step waits 15 s for the branch dialog, but the window first reads each configured forge's token and
     asks that forge for the repository's branches; with a GitHub entry in the account's settings the dialog came
     later than that (cause inferred, not measured). The step waits as long as the window may ask the forge.
  3. The window runs on the account's own settings, which keep machines and a forge from earlier walks; the walk
     starts from known settings, or names what it found.
  4. The failed-card step looked for the card in the Work page's list while the page stood in *Running*; it picks the
     list first, as the log step does.
  5. The clean-up reports the planner's state as left over where the folder does not exist.
- Still open in the walk tool: its preflight does not check the walk agent, `known_hosts` and the providers on the VM
  before a run; a resume starts a new window, which knows nothing of the tasks the earlier one started, so a step after
  a builder's end is proven only by a fresh run.

## To be checked

- After the run, porelod still lists the run's porelo project, marked Stale, although the run took it out of the
  organization: porelod could not read the organization's repository again without the test person's ssh agent.
  Whether a refresh with the agent present drops it decides whether this goes to porelo as a finding.

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
- The test organization's repositories stand at T0 after the run, and no task of it is left.

## Estimate

`F523 size=M est=61 basis=median M 61 (24 records)`
