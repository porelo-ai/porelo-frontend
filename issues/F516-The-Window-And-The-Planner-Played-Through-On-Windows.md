# F516 — The Window And The Planner Played Through On Windows

```json
{
  "$schema": "issue-1.json",
  "id": "F516",
  "title": "The Window And The Planner Played Through On Windows",
  "state": "Backlog",
  "size": "M",
  "priority": "High",
  "rank": 89,
  "blockedBy": [],
  "covers": "Story ST334, the window and the planner on Windows, played once on a Windows test machine as a person would, for ST347's gathered story run: both installed, Planning opened, the board read through the local planner, both Windows builds green."
}
```

**Why this size.** M: an install step for both Windows packages and a feature of three steps run with `flutter test -d
windows`, a reading of both repositories' last Windows builds, and the story driver's Windows form; the board's reading
steps of the idea walk are reused.

**What must be true.** A run on a Windows test machine shows, or names as missing, what ST334 promises: with the window
and porelo-planner installed from their Windows packages, Planning shows the board read through the planner running
there, and both repositories' Windows builds are green.

## Why

- Serves porelo-project's *The window and the planner on Windows* (story ST334, porelo-project cb298f4), as its part of
  *Every story played through once, as a user would* (story ST347, porelo-project cb298f4): each High story's test run
  once, automated, on a test VM as a person would play it.

## What the story's test asks

- **Does:** installs the window and porelo-planner on Windows x64 from their packages, starts the window and opens
  Planning.
- **Sees:** the board, read through the planner running on that computer (its address file under
  `%LOCALAPPDATA%\porelo-planner`), not a note that planning is not offered there; and both repositories' Windows
  builds green on GitHub.

## What exists already

- `the planner from the path answers for the project` and `i open the planning of the walk project` read the
  board and ask the planner's own probe; both are written for Linux (`XDG_RUNTIME_DIR` in
  `integration_test/support/idea_walk.dart`).
- `tool/windows-install-check.ps1` installs the signed MSIX and starts it; nothing opens Planning there.
- There is no Windows machine among the test machines of this host, and no virtual display: on Windows the window runs
  in the guest's own desktop session.

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
- On Windows there is no virtual display: the window runs in the Windows machine's own desktop session, and the driver's
  Windows form does there what the Plan says.

## Plan

- The driver's Windows form installs both packages in the guest (the window's MSIX as
  `tool/windows-install-check.ps1` does; the planner's ZIP or MSIX as porelo-planner hands it over, checked against
  its digest), copies the checkout's HEAD there and runs the feature with `flutter test -d windows`.
- Steps: `When I open Planning`; `Then the board appears, read through the planner on this computer`, read against
  the planner's address file under `%LOCALAPPDATA%` and its answer; `And no note says planning is not offered`.
  The planner's paths in `idea_walk.dart` take the Windows ones on Windows.
- A last step reads both repositories' latest `main` Build on GitHub over its API (curl, no `gh`) and names the
  Windows job's result.
- Both packages are removed again from the guest at the end.

## Expected failures

- [F476](README.md#f476) (Backlog): the window finding and starting the planner on Windows; Planning fails on it.
- porelo-planner's PL29 (Implementing): the planner's Windows executable built, tested and shipped; the install fails
  on it.
- porelo-planner's PL30 (Backlog): the screen finding the planner on Windows.

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

- One run on a Windows test machine with a report naming each step: OK, FAIL with what was asked and got, or
  EXPECTED with [F476](README.md#f476), porelo-planner's PL29 or PL30.
- Both packages are gone from the guest after the run.

## To be checked

- Which Windows machine runs it: the test machines of this host are Linux VMs. A Windows guest beside them, or the
  Build's Windows runner, is said in the room before the run; until one is named, the run reads the two Windows
  builds alone and names the rest as waiting on that machine.

## Estimate

`F516 size=M est=61 basis=median M 61 (24 records)`
