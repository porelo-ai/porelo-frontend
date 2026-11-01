# F297 — Register's Progress With Its Steps And Usual Time

**Status:** Idea.
**Severity:** medium.
**Size:** M - the signed host action's steps and their timing, the bring dialog, kept durations, with their tests; no
contract with another repository.

**What must be true.** While *Register the project* (and the other signed host actions in the same dialog) runs, the
dialog shows a progress bar with which step of how many is running, the step's words, and how long that step usually
takes here; a step running well past its usual time says so before the step limit ends it.

## Why

Seen in the sprint 6m walk (2026-11-01, michi): Retry showed only "Opening the connection to walk6m…" for a long
while, with no sign of how far along it was or how long to wait. The step words and the per-step limit of the earlier
fix (commit 31de8694, three minutes per step) say what runs and stop a hang, but not where it stands.

## The shape

- `SignedHostAction` names its steps up front (read, file, publish, connect, upload, apply, record), so the count is
  known before the first runs; a step skipped on Retry counts as done.
- The dialog shows a determinate bar over the steps and, under it, "Step 4 of 7: Opening the connection to walk6m… —
  usually about 20 s".
- The usual time per step is the median of the last runs here, kept in the settings by step name; with none kept, no
  time is said.

## Plan

- `lib/src/app/signed_host_actions.dart`, `lib/src/ui/project_bring_dialog.dart`, `lib/src/app/settings.dart`.
- **Red first:** a widget test whose fake action holds step 2 of 5 shows "Step 2 of 5" and a bar at that place; a
  second run with kept durations shows the usual time.

## Acceptance

- Every running step shows its number, the total and its words.
- A step past twice its usual time says it takes longer than usual.
