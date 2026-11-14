# F538 — The Planner Ends Gracefully On Windows

```json
{
  "$schema": "issue-1.json",
  "id": "F538",
  "title": "The Planner Ends Gracefully On Windows",
  "state": "Review",
  "size": "S",
  "priority": "Medium",
  "rank": 107,
  "blockedBy": [],
  "covers": "On Windows the planner the window started is asked to end through its own stop on its input, and is ended hard only when it does not end in time."
}
```

**Why this size.** S: one more way to end the started planner in `LocalPlanner` (`lib/src/app/planner.dart`), chosen
on Windows, and its test with a stand-in planner.

Found in the code reading of the window's planner start on Windows (2026-11-13).

**How it stands.**
- When the window closes, or a planner it started must go before another starts, the window ends that planner in
  `LocalPlanner._stop`. On Linux that is `stopOwnedProcess`, as before: SIGTERM, and SIGKILL after a bounded wait.
- On Windows there is no SIGTERM, and `Process.kill` ends the program at once, so the planner would never finish what it
  was writing, as a save under way. There `_endThroughItsInput` closes the planner's input instead, which the window
  holds open from the start (`_startWithItsInput`, with `--end-with-input`), and waits `inputEndWait` for it to end.
  Only a planner still running then is ended hard, with a warning in the window's log that it was ended hard.
- The platform is `LocalPlanner`'s `onWindows`, `Platform.isWindows` unless given, so a Linux test takes the Windows
  path. `test/app/planner_end_test.dart` starts stand-in planners, shell scripts, on it: one that ends when its input
  closes, at once or a second later within a three-second wait, is not ended hard and no hard end is logged; one that
  ignores its input is ended hard no earlier than the wait and the log says so; on Linux the same planner is still
  ended with SIGTERM, its input left open.
- An end of the window that comes while a restart stops the planner it replaces waits for that stop, which on Windows
  takes up to five seconds, and no planner is started once the end began or the planner was disposed; a planner whose
  start the end overtook is stopped by that start.

**What must be true.**
- On Windows the window asks the planner to end through the planner's own stop on its input, as the planner states it
  (for instance by closing that input), and waits a bounded time for it to end.
- Only a planner still running after that wait is ended hard, and the window's log says so.
- On Linux nothing changes.

## Decided

- **The wait is three seconds** (`plannerInputEndWait`). With the two seconds a hard end then has to show its exit, the
  whole end stays within the five seconds the window gives its ends on a signal (`letGoOnSignals`, SIGINT on Windows
  too), and the planner has more time to finish than the two seconds SIGTERM gives it on Linux. How long the planner's
  own stop takes was not measured.
- **The window's end is final**: `end()` keeps its future once asked, so every later caller waits for the same end, and
  the window starts no planner after it.

## To be agreed with porelo-planner

- porelo-planner's `main` ends on its input since commit `6110468` ("End a planner started with --end-with-input once
  its input closes"): started with `--end-with-input`, `PlannerApplication.main` hands `System.in` to `InputEnd.watch`
  (`planner/app/src/main/java/org/fuin/porelo/planner/app/InputEnd.java`), whose thread reads the input to its end, then
  closes the Spring context through `SpringApplication.exit` and exits with that close's code: 0 for a clean end, 1
  where the input broke or the close failed. Anything written on the input means nothing to it.
- The 0.1.0 planner does not know the option and its main code never reads its input, so on Windows it runs on after its
  input closes and falls back to the hard end after the wait, said in the window's log.
- Whether three seconds suffice for the planner's stop, including one under way while the window's change stream to it
  is still open, is for porelo-planner to confirm.
