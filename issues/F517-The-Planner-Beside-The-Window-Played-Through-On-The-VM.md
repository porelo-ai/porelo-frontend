# F517 — The Planner Beside The Window Played Through On The VM

```json
{
  "$schema": "issue-1.json",
  "id": "F517",
  "title": "The Planner Beside The Window Played Through On The VM",
  "state": "Backlog",
  "size": "M",
  "priority": "Medium",
  "rank": 90,
  "blockedBy": [],
  "covers": "Story ST335, the planner runs beside the window and follows its updates, played once on the test VM in the window as a person would, for ST347's gathered story run: the planner updated while the window is open, the window closed and opened again, the planner killed and found again."
}
```

**Why this size.** M: a feature whose window is closed and started again within one run (two test runs in sequence under
the driver, with state handed between them as `tool/walk_idea.sh` does), an update of the planner between them from two
handed-over builds, and a kill of it; the planner's probe and the board's steps are there.

**What must be true.** A run on the test VM shows, or names as missing, what ST335 promises: after porelo-planner is
updated while the window is open and the window is closed and opened again, it talks to the new planner and shows its
version; after the planner is killed, the window finds it again at its new port.

## Why

- Serves porelo-project's *The planner runs beside the window and follows its updates* (story ST335, porelo-project
  cb298f4), as its part of *Every story played through once, as a user would* (story ST347, porelo-project cb298f4):
  each High story's test run once, automated, on a test VM as a person would play it.

## What the story's test asks

- **Does:** keeps the window open on Planning, updates porelo-planner, closes the window and opens it again; then
  kills the planner.
- **Sees:** the window reading the board through the new planner and naming its version (About); after the kill the
  board again, through the planner at its new port; no planner the window started is left running after the window
  ends.

## What exists already

- `tool/walk_idea.sh` puts a checked planner build first on the window's path (`--planner DIR`, SHA256SUMS) and
  hands a run's state from one test run to the next (`PORELO_WALK_STATE`, `resume`).
- `the planner from the path answers for the project` asks the planner's probe; `LocalPlanner` in
  `lib/src/app/planner.dart` reads `porelo-planner/planner.json` under the runtime directory and starts the planner
  where none answers.
- Nothing updates the planner under a running window, closes the window within a run, or kills the planner.

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

- The driver takes two planner builds (`--planner DIR --planner-next DIR`, each checked against its SHA256SUMS),
  installs the first as the account's planner as the planner's package does (a user service where it is one), and runs
  the first part: open Planning, note the version About shows and the planner's pid and port from `planner.json`.
- While that window is still open it installs the second build the way an update does; the first part ends (the
  window closes) and the driver checks that a planner the window started is gone with it.
- The second part opens the window again: `Then it talks to the new planner, whose version it shows`, against the
  second build's `--version`; `When the planner is killed` (`kill -9` on the pid in `planner.json`); `Then the window
  finds it again on its new port`, the board read once more and `planner.json` naming another port.
- The first build is put back and anything the run started is ended, at every ending.

## Expected failures

- porelo-planner running as a service of the system, a systemd user service started at sign-in by its package and
  seen and stopped with the system's own commands; the update and the kill steps fail until it does.
- porelo-planner ending by itself when the window's end of the pipe it was started with closes, a hard kill of the
  window included.
- A planner the window started ends with it, built since.
- The planner's version in About, built since; the version step named it as missing before.

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

- One run on the test VM with a report naming each step: OK, FAIL with what was asked and got, or EXPECTED with
  the missing issue.
- After the run the account's planner is the one it found, and no planner the run started still runs.

## To be checked

- How the planner's package updates an installed planner on Linux, so the update step does what a person's update
  does and not a copy of the file.

## Estimate

`F517 size=M est=61 basis=median M 61 (24 records)`
