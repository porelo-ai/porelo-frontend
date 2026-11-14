# F549 — Planning Tests Follow The Board Without Its Closed Filter

```json
{
  "$schema": "issue-1.json",
  "id": "F549",
  "title": "Planning Tests Follow The Board Without Its Closed Filter",
  "state": "Backlog",
  "size": "S",
  "priority": "Highest",
  "rank": 1,
  "blockedBy": [],
  "covers": "The window's planning feature tests stop using the board's Finished-and-Rejected filter and its separate Retry button, which porelo-planner's planning package drops for one Reload planning button; built against the planner commit that drops them."
}
```

**Why this size.** Tests of one module only, about six step and feature files and their generated tests; no lib code
and no contract the window serves changes.

**What must be true.** The window's feature suite passes against the planning package that no longer has the
"Show Finished and Rejected (n)" filter and has one "Reload planning" button in place of "Retry planning", and still
proves what those scenarios guard: closed work stays reachable and can take a drop, and a failed planning watch can
be resumed while the machine stays connected.

## Plan

- Pin the planning package in `pubspec.yaml` to porelo-planner's commit that drops the filter and merges the buttons
  (with the `xterm` override kept), `flutter pub get`, and run `test/features` and `test/ui` whole: what goes red first
  are the steps below.
- The filter: `test/features/step/closed_planning_states_are_hidden.dart` (expects "Show Finished and Rejected (3)"),
  `test/features/step/i_show_closed_planning_states.dart` (taps `show-closed`), used by `planning_board.feature`
  ("Closed states can be revealed") and `planning_moves.feature` ("A closed destination accepts a drop");
  `test/features/support/story_work.dart` case `show closed cards` (taps `planning-show-closed`, then unfolds `Done`),
  used by `story_work.feature` ("Closed stories without work can start"). Each is rewritten to reach the closed
  states the way the board now shows them; a scenario whose harm the board no longer has is deleted with its steps.
- The buttons: `test/features/step/i_retry_planning.dart` (taps `retry`, used by `planning_board.feature` and
  `planning_story.feature`) and `test/features/step/i_reload_planning_moves.dart` (taps `reload`, used by
  `planning_moves.feature`) tap the one remaining button by its new key; if both steps then do the same, one is kept
  and the features reuse it.
- `dart run build_runner build && dart format test/features integration_test`, then the generated tests are
  committed. `board.retry()` stays in the package, so `test/app/planning_stream_lifecycle_test.dart` is unchanged.

## Acceptance

- `test/features` and `test/ui` pass whole against the planner commit, with no step naming the filter or a Retry
  button; the closed-drop and watch-resume scenarios still run and fail when the closed states or the reload are
  broken on purpose.

## To be checked

- On the planner commit: how closed states show now (always, or in a folded phase), and the merged button's key.
