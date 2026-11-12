# F479 — A Planner The Window Started Ends With It

```json
{
  "$schema": "issue-1.json",
  "id": "F479",
  "title": "A Planner The Window Started Ends With It",
  "state": "Estimated",
  "size": "M",
  "priority": "Medium",
  "rank": 16,
  "blockedBy": [],
  "covers": "A planner the window started because none was serving ends when the window ends, so it neither holds the planner's address file nor stands in the way of the next planner; a planner the window found serving is left running."
}
```

**Why this size.** M: the planner's start keeps what it started and the pipe to it, the window's end runs on closing
and on SIGTERM and SIGINT, which it does not catch today, and a test of each; no contract changes on the window's side.
The planner's end on a closed pipe is the planner's own part, `--end-with-input`.

**What must be true.** A person who ends the window finds no planner left running that the window started, and can
start another planner at once.

## Why

The window starts the installed planner, detached, when none serves (`LocalPlanner._startDetached`). After the window
ended, that planner kept running and kept `planner.json` under the runtime directory, so a planner started next, for
instance one built from source, could not start until it was killed by hand.

## Decided by the operator (2026-11-12)

- A planner the window started ends itself when the window's pipe to it closes. Started with `--end-with-input` and its
  standard input a pipe, the planner ends when that pipe closes, a hard kill of the window included. This issue is
  built once porelo-planner serves `--end-with-input`.
- The end by SIGTERM, then SIGKILL, stays for the window's clean ends: closing it, SIGTERM and SIGINT.

## Plan

- `LocalPlanner` (`lib/src/app/planner.dart`): `_startDetached` becomes a start in `ProcessStartMode.normal` with
  `--end-with-input`. `StartPlanner` answers the `Process`; `LocalPlanner` keeps it, its standard input open and never
  written, and reads its standard output and error into the window's log so the planner never blocks on a full pipe.
  It keeps the address the planner then writes (`_look`, the port and token of `planner.json`) as the one it started.
  A planner the window found serving keeps none, so nothing below touches it.
- **Why `normal`.** `detached` gives the planner no pipe. `detachedWithStdio` and `normal` both keep one, and both end
  the planner when the window's process goes, as the system closes the pipe. Only `normal` answers `exitCode`, which
  the wait below needs (`detachedWithStdio` throws on it), and `Process.kill` reaches it. A planner the window started
  thus no longer outlives it to serve the account's other windows and tools; one that serves before the window starts
  is not touched. The comment on `_startDetached` that says otherwise goes with it.
- `LocalPlanner.end()`: where it started one, and `planner.json` still names the address it started (else another
  planner took its place and is left alone), it sends SIGTERM, waits two seconds for `exitCode` and then sends
  SIGKILL, as `owned_process.dart` does for an owned child; it says what it ended in the window's log.
- The window's ends call it: `_letGo` in `lib/src/ui/shell.dart` after the person agreed to leave, and new
  `ProcessSignal.sigterm` and `sigint` watches in `lib/main.dart`, which run the same end and then `exit(0)`
  (watching them takes their default end away, so they must end the window themselves). A hard kill (SIGKILL, a
  crash, `q` in `flutter run`) runs neither; the closed pipe ends the planner then.
- Tests, red first: `test/client/planner_end_test.dart` with a fake start and a fake address file: the start asks for
  `--end-with-input` and keeps the standard input open; a planner the window started is ended on `end()`; one it found
  serving is not; one whose address file names another address is not; one that ignores SIGTERM is killed. The signal
  watches get a test of the function they call, not of a real signal.

## Acceptance

- After closing the window, or SIGTERM or SIGINT to it, no planner the window started runs, and a planner started
  next writes its address at once.
- After a hard kill of the window (SIGKILL), with a planner that serves `--end-with-input`, no planner the window
  started runs.
- A planner that served before the window started still serves after it ended.

## To be checked

- Whether the planner removes `planner.json` on SIGTERM; if it does not, `end()` removes it only while it still names
  the address the window started.
