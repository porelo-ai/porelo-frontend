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
- **After the answer:** where the run asks Start for a follow-up during the report (`onScreenStart` for the same
  source, project and story), the planner took the report: it is kept as reported, and a follow-up start the run
  could not make is said, as the window's own follow-up refusals are.
- **Scenarios** in `test/features/planning_moves.feature`: *A move after the started tasks ended warns of no start
  still handed on* (new step *planning does not warn that moving {id} stops work*, new condition *every started task
  ended*), and *A follow-up the planner orders after a reported start is started once* (the stand-in answers the
  next started report with a reader; `FakeBackend.startsOrdered` counts Start's offers).
- **Red:** the first scenario before the change: `Found 1 widget with key [<'planning-move-warning-item RUNNING_WORK
  ST291'>]`. The second, on the old code, shows `planning-action-error` (the window's own start of the follow-up,
  which the stand-in serves only through the screen's hook); a second start by the window beside the run's would be
  refused as an offer already handed and shown there too (inferred from `_keptWhileStarting`, not run).
- **Runs:** `dart analyze lib test integration_test tool` No issues found. `planning_moves_test`, `story_work_test`,
  `window_task_reports_test`, `window_task_starts_test`: 147 passed. `test/features` whole: 987 passed.
  `test/ui` whole: 1445 passed, 1 failed: *a window that reaches its planner shows the planning screen in place of
  the line* (`planning_placeholder_test.dart`), which fails the same on the unchanged code in this worktree.

## To be checked

- A start still truly unreported (the planner not reached for its started report) is warned of by the screen's run
  as before; no scenario of the window's isolates that local warning, since the stand-in's preview warns of the run
  at work itself.
- A report whose run replays an offer whose start failed earlier throws that start's error without asking Start
  again; the window then takes the report as not taken and sends it again on its next start.
- `planning_placeholder_test.dart`'s failure above, red on `main` in this worktree: its cause was not looked into.
