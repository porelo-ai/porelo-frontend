# F479 — A Planner The Window Started Ends With It

```json
{
  "$schema": "issue-1.json",
  "id": "F479",
  "title": "A Planner The Window Started Ends With It",
  "state": "Review",
  "size": "M",
  "priority": "High",
  "rank": 15,
  "blockedBy": [],
  "covers": "A planner the window started because none was serving ends when the window ends, so it neither holds the planner's address file nor stands in the way of the next planner; a planner the window found serving is left running."
}
```

**Why this size.** M: the planner's start keeps what it started and the pipe to it, the window's end runs on closing
and on SIGTERM and SIGINT, which it does not catch today, and a test of each; no contract changes on the window's side.
`StartPlanner` answering the `Process` touches the 16 fake starts of the planner's tests.
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
- `_letGo` reaches the planner through `widget.planning?.client`, by a small interface beside `NamesItsLog`
  (`EndsWithTheWindow`) that `LocalPlanner` implements.
- Tests, red first: `test/app/planner_end_test.dart`, beside the planner's other tests, with a fake start and a fake
  address file: the start asks for `--end-with-input` and keeps the standard input open; a planner the window started
  is ended on `end()`; one it found serving is not; one whose address file names another address is not; one that
  ignores SIGTERM is killed. The signal watches get a test of the function they call, not of a real signal.

## Acceptance

- After closing the window, or SIGTERM or SIGINT to it, no planner the window started runs, and a planner started
  next writes its address at once.
- After a hard kill of the window (SIGKILL), with a planner that serves `--end-with-input`, no planner the window
  started runs.
- A planner that served before the window started still serves after it ended.

## Checked

- The planner removes `planner.json` itself on a graceful stop (its address file closes with the planner's context and
  deletes the file while it holds the lock), so `end()` only ends the planner and leaves the file alone.
- porelo-planner serves `--end-with-input`: its changelog and documentation name the option.

## How it was built

- `LocalPlanner` (`lib/src/app/planner.dart`) starts the planner in `ProcessStartMode.normal` with `--end-with-input`
  and keeps the process, its input open and never written; its output and error go into the window's log line by line,
  a long line in pieces. It keeps the address the planner then wrote as the one it started.
- `LocalPlanner.end()`, shared by every caller at once, ends only a planner the window started, and only while the
  address file still names the address it started: SIGTERM, two seconds, then SIGKILL (`stopOwnedProcess`), each said
  in the window's log. A planner found serving is never touched.
- The window's ends call it through `EndsWithTheWindow`: `_letGo` in `lib/src/ui/shell.dart` once the person agreed to
  leave, and the SIGTERM and SIGINT watch in `lib/main.dart` (`letGoOnSignals`), which lets go of the tunnels, the
  forwards and the planner at once and exits within five seconds. A hard kill ends the planner by its closed input.
- Tests: `test/app/planner_end_test.dart` (the start asks for `--end-with-input` and keeps the input open; a started
  planner ended on `end()`, one found serving and one whose address file names another address left alone, one that
  ignores SIGTERM killed), `test/ui/planner_ends_with_window_test.dart` (closing the window ends it) and
  `test/app/ending_signals_test.dart` (a signal lets go of everything and exits, also when letting go hangs).
