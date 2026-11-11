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
- Waits on porelo-planner's PL30 (the screen finds `planner.json` on Windows), which waits on PL29 (its Windows
  build, packed and published as the window's is) and PL28 (its own files on Windows); it starts once PL30 is on the
  planner's `main`.

## How it stands

- Filed in Backlog. Agreed with the planner (2026-11-11):
  - The program is `porelo-planner.exe` on an absolute `PATH` entry: the planner's MSIX puts it there with an app
    execution alias, a ZIP user with a `PATH` entry. The window starts it at most once, as on Linux.
  - Its address is `%LOCALAPPDATA%\porelo-planner\planner.json`, the same JSON as on Linux; `XDG_RUNTIME_DIR`, when
    set, still wins. The window passes no runtime directory on Windows.
  - The package checks the file's and its folders' owners and access lists with one `powershell.exe` call per reach
    of the address, not per request.
  - Both MSIX packages turn off write virtualization (`unvirtualizedResources`), so the window reads the file the
    planner wrote; the planner's install check proves it.

## Plan

- `LocalPlanner` (`lib/src/app/planner.dart`): drop the Windows guard; on Windows look for `porelo-planner.exe` on
  the absolute `PATH` entries, and read its address through the package's `HttpPlanningSource.fromAddressFile` at the
  pin that carries PL30.
- Red first: `test/app/planner_windows_test.dart` turns from "says it is not offered" into "starts the planner once
  and reads its address", with a stand-in program and address file.
- The Windows CI job runs it; `test/app/planner_test.dart` stays bound to Linux where it reads POSIX modes.

## Acceptance

- On GitHub's Windows runner the planner's start and address tests pass, seen red first.
- On Linux nothing changes.
