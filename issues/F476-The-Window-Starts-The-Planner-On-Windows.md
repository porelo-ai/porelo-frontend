# F476 — The Window Starts The Planner On Windows

```json
{
  "$schema": "issue-1.json",
  "id": "F476",
  "title": "The Window Starts The Planner On Windows",
  "state": "Backlog",
  "size": "S",
  "priority": "High",
  "rank": 17,
  "blockedBy": [],
  "covers": "On Windows the window finds and starts porelo-planner's Windows build as it does on Linux, and reads the board through it, instead of saying planning is not offered there."
}
```

**Why this size.** the planner's start and address lookup in one module, `lib/src/app/planner.dart`, and its tests;
the Windows guard taken out again.

**What must be true.** On Windows, where porelo-planner's Windows build is installed, the planning place starts it at
most once, finds the address it writes, and shows the board, as on Linux. Where it is not installed, the place says
how to install it, in the same words as on Linux with the Windows package named.

- Placed by the operator (2026-11-11): porelo-planner gets a Windows build, packaged and published as the window's
  is, which takes back the window's "Planning is not offered in Porelo on Windows yet" (`plannerNotOnWindows`).
- Serves porelo-project's *A planner app serves the board to the window* (story ST311).
- Waits on porelo-planner's issue that builds and publishes its Windows package; it starts once that is on the
  planner's `main`.

## How it stands

- Filed in Backlog. Where the planner writes its address on Windows, and where its program is installed there, is
  agreed with the planner in the room and written into the plan before building.

## Plan

- `LocalPlanner` (`lib/src/app/planner.dart`): drop the Windows guard; on Windows look for the planner's program
  where its Windows package installs it and on the path, and read its address file where the planner writes it on
  Windows, through the package's `HttpPlanningSource.fromAddressFile`.
- Red first: `test/app/planner_windows_test.dart` turns from "says it is not offered" into "starts the planner once
  and reads its address", with a stand-in program and address file.
- The Windows CI job runs it; `test/app/planner_test.dart` stays bound to Linux where it reads POSIX modes.

## Acceptance

- On GitHub's Windows runner the planner's start and address tests pass, seen red first.
- On Linux nothing changes.
