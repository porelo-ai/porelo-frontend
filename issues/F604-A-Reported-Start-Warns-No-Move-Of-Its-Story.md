# F604 — A Reported Start Warns No Move Of Its Story

```json
{
  "$schema": "issue-1.json",
  "id": "F604",
  "title": "A Reported Start Warns No Move Of Its Story",
  "state": "Review",
  "size": "S",
  "priority": "High",
  "rank": 124,
  "blockedBy": [],
  "covers": "A start the window handed on stops counting as one the planner does not report yet once the window reported it started, or it ended, so a later move of its story warns only of tasks at work, instead of Stop the tasks and move for tasks long ended."
}
```

**Why this size.** S: the window's reports go through the client's `taskEvent`, as Agent Planner named, so the
offer leaves the run's unreported starts and follow-ups start once; tests of a move after a reported start, after an
end, and while a start is still unreported.

**What must be true.** A person moving a story whose planned tasks all ended is not told that a start is still
handed on and must be stopped; the warning stands only while a start is truly unreported or a task is at work.

## Found

The operator's live test (15 November, ~15:38Z): moving ST366 *Estimated* to *Backlog* asked *ST366 has a start this
window handed on that the planner does not report yet; it is stopped first.* with *Stop the tasks and move*, while
`pi` and `pi-2` had both ended and their results were saved (PI68 *Analyzed*, *Estimated*).

## Plan

- **Today**, read in the code:
  - porelo-planner's screen (pinned `c8796c6`, `screen/lib/src/planning_board.dart`, `_localWarnings`) adds the
    warning while `runOf(story).starting`, which is true while the run's `_unreported` offers are not empty
    (`screen/lib/src/task_runs.dart`). An offer enters `_unreported` in `PlanningRun.start` and leaves it only on a
    failed start, on a cancelled epoch, or in `PlanningRun.report` for a `started` event, the path of the client's
    `taskEvent` (`PlanningTaskReports`).
  - The window reports a planned task's events itself (`lib/src/ui/planning_reports.dart`, `_deliver`), calling
    `source.taskEvent` on the planner source directly, not the client's `taskEvent`. The planner hears the start, but
    the screen's run never does, so the offer stays unreported for the window's life, and an end does not clear it
    either.
  - The window's `_plannedStarts` in `lib/src/ui/shell.dart` only says which operations stand over the board; it is
    not this warning.
- **Agent Planner's answer** (room, 2026-11-15 15:43Z): the window delivers its reports through the client's
  `taskEvent` (`PlanningClient.taskEvent`, the screen's `PlanningRun.report`), which binds the offer to its machine,
  drops it from the run's unreported starts once the started event is answered, cancels the run on `SaveRefused`,
  and starts the next tasks the answer names (`run.follow`). Calling the source directly skips all four. No second
  call is added in porelo-planner; nothing of the planner's is built for this.
- **Steps.**
  - `_deliver` (`lib/src/ui/planning_reports.dart`) reports through the client's `taskEvent` where the screen holds
    the offer's binding, and the window's own follow-ups (`_startFollowUps`) do not start what `run.follow` starts.
  - An offer kept across a restart, which the screen holds no binding for (`PlanningRun.report` refuses it with
    `TaskEventConflict`), is reported as today; no run of the screen reserved it, so none warns of it.
  - The window's `startedReported` and other kept marks follow the answer as today.
- **Red first:** a widget test: a board start, its started report delivered by the window, then a move of the story;
  red today on the warning.

## Acceptance

- A move of a story whose planned start the window reported, or whose task ended, shows no *start this window handed
  on* warning. Seen to fail: the live test's move of ST366.
- A move while a start is still unreported, or a task at work, warns as today.

## Built

- **Reports through the run:** `WindowTaskStarts.pressed` (`lib/src/ui/planning_embedding.dart`), the screen's start
  hook, which only the screen's run calls after reserving the offer, keeps the offer with its source for this window's
  life; `screenRunOf` answers that source once the hook returned and a timer later, when the run holds what Start
  answered. `_deliver` (`lib/src/ui/planning_reports.dart`) sends the report of such an offer through
  `PlanningTaskReports` (a small client of its own, `_ScreenRunReports`, given the one provider), so
  `PlanningRun.report` binds the machine, drops the offer from the run's unreported starts on *started*, cancels on
  `SaveRefused` and starts the answer's follow-ups through `run.follow`; the window's own `_startFollowUps` is not
  called on that path.
- **Direct as before:** an offer the window started itself, one kept from before this window started, one whose
  planner is now reached through another source, and one the run refuses with `TaskEventConflict` before it asks
  the planner are reported through the source and followed by the window, as today.
- **The planner's answer decides (after the reading):** `_throughTheScreen` sends the report within
  `ReportAtPlanner.watch` (`lib/src/app/report_at_planner.dart`, a zone value for the report's offer). A source that
  is `TellsTaskReports` says through `ReportAtPlanner.told` when it asks the planner and when the planner answered;
  the window's planner is `WindowPlannerSource` (`lib/src/app/planner.dart`), an `HttpPlanningSource` that the
  `LocalPlanner` now opens by default. Not asked and `TaskEventConflict`: the run did not know the offer, the source
  is asked directly. Not answered: not taken (`_notTaken`, so `TaskNotAnswered` voids the task and a lasting refusal
  is not sent again). Answered: kept as reported, whatever the run's `follow` threw after it (a `TaskEventConflict`,
  a replayed start failure, a failed follow-up start), which is said once; neither the report nor its follow-ups are
  sent again. A source that does not tell is reported directly, as before this issue. The press hook
  `onScreenStart`, which stood for the answer, is gone.
- **Checked against porelo-planner `cb9d13a`** (`screen/lib/src/task_runs.dart`, read only): `PlanningRun.report`
  checks the binding and throws `TaskEventConflict` before it calls `run.source.taskEvent` once, then, after the
  answer, drops the offer from the unreported starts, `observe`s the work and awaits `run.follow`; `follow` throws a
  `TaskEventConflict` for an offer of another run and replays a failed start's error before it asks Start, and only
  then calls the run's `startTask`. `run.source` is the provider's source, so the call goes through
  `WindowPlannerSource.taskEvent` in the report's zone. `http/planner_source.dart` is the same at `cb9d13a` as at the
  pinned `c8796c6`, so the subclass's constructor and `PlannerAddress.read` hold for both.
- **Scenarios** in `test/features/planning_moves.feature`: *A move after the started tasks ended warns of no start
  still handed on* (new step *planning does not warn that moving {id} stops work*, new condition *every started task
  ended*), and *A follow-up the planner orders after a reported start is started once* (the stand-in answers the
  next started report with a reader; `FakeBackend.startsOrdered` counts Start's offers).
- **Red:** the first scenario before the change: `Found 1 widget with key [<'planning-move-warning-item RUNNING_WORK
  ST291'>]`. The second, on the old code, shows `planning-action-error` (the window's own start of the follow-up,
  which the stand-in serves only through the screen's hook); a second start by the window beside the run's would be
  refused as an offer already handed and shown there too (inferred from `_keptWhileStarting`, not run).
- **Scenarios after the reading:** *A started report refused while another task is pressed is not kept as taken*
  (the stand-in holds the started report, the board's hook is pressed for another task of ST291, the planner then
  refuses the report) and *A follow-up the run refuses after a taken report sends the report once* (after ST291's
  start the planner orders one of ST291's started offers after every start; ST292 is started). New steps in
  `test/features/step/`, the stand-in records each report and can hold one, `World.planningStarts` is the hook.
- **Red after the reading**, on the code before the fix: the first `Expected: false Actual: <true>` (kept as
  reported); the second `Expected: an object with length of <1> ... Which: has length of <2>` (the report sent again).
- **Runs:** `dart analyze lib test integration_test tool` No issues found. `planning_moves_test`, `story_work_test`,
  `window_task_reports_test`, `window_task_starts_test`: 147 passed. `test/features` whole: 987 passed.
  `test/ui` whole: 1445 passed, 1 failed: *a window that reaches its planner shows the planning screen in place of
  the line* (`planning_placeholder_test.dart`), which fails the same on the unchanged code in this worktree.

- **Box:** the build box's Maven `test` phase (format check, `dart analyze --fatal-infos`, `porelo_host`'s tests and the
  whole `flutter test` suite) at `5f5c3e7`: BUILD SUCCESS, 4634 passed, 37 skipped, 0 failed, the placeholder test above
  included, so its failure is this laptop's alone. The same at `aea0709`, with every issue of the branch: BUILD SUCCESS,
  4640 passed, 37 skipped, 0 failed.
- **Runs after the reading** (laptop, one file at a time): `planning_moves_test` 28, `story_work_test` 27,
  `window_task_reports_test` 70, `window_task_starts_test` 25, all passed; analyze No issues found.
- **Box at the final code:** the build box's Maven `test` phase at `6206dd8` (both readings' fixes): BUILD SUCCESS,
  4651 passed, 37 skipped, 0 failed (also 460 and 5 passed). `cd492be` before it: BUILD SUCCESS, 4649 passed, 37
  skipped, 0 failed.

## To be checked

- A start still truly unreported (the planner not reached for its started report) is warned of by the screen's run
  as before; no scenario of the window's isolates that local warning, since the stand-in's preview warns of the run
  at work itself.
