# F479 — A Planner The Window Started Ends With It

```json
{
  "$schema": "issue-1.json",
  "id": "F479",
  "title": "A Planner The Window Started Ends With It",
  "state": "Analyzed",
  "size": "M",
  "priority": "Medium",
  "rank": 1,
  "blockedBy": [],
  "covers": "A planner the window started because none was serving ends when the window ends, so it neither holds the planner's address file nor stands in the way of the next planner; a planner the window found serving is left running."
}
```

**Why this size.** M: the planner's start keeps what it started, the window's end runs on closing and on SIGTERM and
SIGINT, which it does not catch today, and a test of each; no contract changes on the window's side.

**What must be true.** A person who ends the window finds no planner left running that the window started, and can
start another planner at once.

## Why

The window starts the installed planner, detached, when none serves (`LocalPlanner._startDetached`). After the window
ended, that planner kept running and kept `planner.json` under the runtime directory, so a planner started next, for
instance one built from source, could not start until it was killed by hand.

## Plan

- `LocalPlanner` (`lib/src/app/planner.dart`): `_startDetached` keeps the `Process` it started (`StartPlanner` answers
  it), and the address the planner then writes (`_look`, the port and token of `planner.json`) as the one it started.
  A planner the window found serving keeps none, so nothing below touches it.
- `LocalPlanner.end()`: where it started one, and `planner.json` still names the address it started (else another
  planner took its place and is left alone), it sends SIGTERM, waits two seconds for the process to go and then
  sends SIGKILL, as `owned_process.dart` does for an owned child; it says what it ended in the window's log.
- The window's ends call it: `_letGo` in `lib/src/ui/shell.dart` after the person agreed to leave, and new
  `ProcessSignal.sigterm` and `sigint` watches in `lib/main.dart`, which run the same end and then `exit(0)`
  (watching them takes their default end away, so they must end the window themselves). `q` in `flutter run` ends
  the process without either, as a hard kill does.
- Tests, red first: `test/client/planner_end_test.dart` with a fake start and a fake address file: a planner the
  window started is ended on `end()`; one it found serving is not; one whose address file names another address
  is not; one that ignores SIGTERM is killed. The signal watches get a test of the function they call, not of a
  real signal.

## Acceptance

- After closing the window, or SIGTERM or SIGINT to it, no planner the window started runs, and a planner started
  next writes its address at once.
- A planner that served before the window started still serves after it ended.

## Open questions

- A hard kill of the window (SIGKILL, a crash, `q` in `flutter run`) runs no end of the window's. Ending the planner
  then needs the planner's part: it ends when the pipe of the window that started it closes. Is that asked of
  porelo-planner as its own issue, or is the planner left running after a hard kill?

## To be checked

- Whether the planner removes `planner.json` on SIGTERM; if it does not, `end()` removes it only while it still names
  the address the window started.
- Whether `Process.kill` reaches a process started with `ProcessStartMode.detached` in the Dart this window builds
  with; else `Process.killPid` on its pid.
