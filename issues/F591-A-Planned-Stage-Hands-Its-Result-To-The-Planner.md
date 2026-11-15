# F591 — A Planned Stage Hands Its Result To The Planner

```json
{
  "$schema": "issue-1.json",
  "id": "F591",
  "title": "A Planned Stage Hands Its Result To The Planner",
  "state": "Review",
  "size": "M",
  "priority": "High",
  "rank": 11,
  "blockedBy": [],
  "covers": "Story: a planning stage hands back its result, and the planner stores it. When an analysis or estimation task the planner ordered ends, the window reads its result file from the machine and hands it to the planner, which validates and saves it through its store before it moves the issue; a missing, unreadable or refused result is said, kept and tried again, as a discussion's idea is today."
}
```

**Why this size.** The way already stands for a discussion's idea (`_handIdea` in
`lib/src/ui/planning_reports.dart`): the start names a result file, the end reads it, the planner takes it. This
issue runs it for the planner's stage tasks, keeps what is needed with the offer, and orders it with the end report;
one contract of Agent Planner's read and one of Agent Core's.

**What must be true.** An issue moves to *Analyzed* or *Estimated* only once the planner has saved what the analysis
or estimation produced; a task that produced nothing usable leaves it where it was, and the person reads why.

## Found

The operator's live test on a host (snapshot 0.5.1~snapshot.552): an *In analysis* task wrote its plan into the
repository's `issues/` and pushed it through the gate, on a host copy that had not yet followed central; the planner
then moved the issue to *Analyzed* on central, whose issue held no plan and no size.

## Plan

- **The contracts**, to be named by their owners before building:
  - Agent Core: a stage task started by `startOrdered` takes a result file as a discussion does (`result`, read by
    `resultOf`, the machine's `TaskResult` with its states), and pushes nothing and has no gate.
  - Agent Planner: the order names the result file and the stage (`PlanningTaskOrder`), and the planner takes a stage
    result (a call beside the idea's `HandIdea`, `lib/src/app/planner_ideas.dart`), validates it, saves it through
    its store and only then moves the issue; it answers saved, refused with faults, or not reached (transient).
- **Today**, read in the code: `WindowTaskStarts` (`lib/src/ui/planning_embedding.dart`) starts an ordered task by
  `startOrdered` with no result file and keeps it by `rememberPlanningOffer`; at its end the reports
  (`lib/src/ui/planning_reports.dart`) send `PlanningTaskEvent.ended` with `plannedTaskEnded`, and the planner moves
  the issue on that report. Only a discussion's end reads a result (`_handIdea`).
- **Steps.**
  - The start passes the order's result file to `startOrdered`, and `PlannedOffer` keeps its name and the stage.
  - At a stage task's end the window reads the result as `_handIdea` does: a result missing after the task left is
    looked at again for `missingSettles`, then said; too large, unreadable or no JSON object is said; the content
    goes to the planner's call. The end report follows the hand-in, so the planner moves the issue only on a saved
    result; a refused result is said with the planner's faults, and the issue stays.
  - A result the planner could not be reached for (a transient refusal) is handed in again on a later sweep, as an
    idea's is; one that cannot be read from the machine is said once and not tried again in this window's life (as
    `_ideasNotHanded` keeps it for ideas); the task is removed only once its result is the planner's.
  - Implementing and later stages report as today, with no result file.
- **Red first** (harm: an issue moved to *Analyzed* with no plan saved, or a plan lost): a reports test that an
  analysis end hands its result before its end report and that a refused result reports no move; a test that a
  result missing, too large or no JSON is said and moves nothing; a test that an unreached planner is tried again
  once; a feature scenario in `test/features/planning_discussion.feature` or a planning file of its own; each seen
  red.

## Acceptance

- The tests above, each seen red first; `test/ui` and `test/features` green.

## Built

- **Contracts**, as their owners named them: the hand-in and the order in Agent Planner's room post of 2026-11-15
  10:12Z and the agreed `result-format.md` (format `porelo-stage-result-1`, 262144 bytes, `{offer, result}` or
  `{offer, missing}`, the result before the `ended` report, idempotent per offer); the order's `result` and `given`
  in porelo-planner `a38e057` (PL143's screen part); Start's `readOnly` and `given` in porelo `4cb4a81bb` (B791's
  contract).
- **Pin:** `porelo_planning` at `a38e057ca726dfecd8d90776862fda83dc59f73a`, with a temporary `dependency_overrides`
  entry to the planner's local clone at the same ref (the `xterm` override kept); `pubspec.lock` names that clone.
  Both go once the planner pushes the commit: the override is removed and the lock resolved from the forge.
- **Hand-in** (`lib/src/app/planner_stage_results.dart`): `handStageResult` posts signed to
  `/projects/{project}/tasks/{task}/result`; 2xx saved; 422 a `StageResultNotSaved` with the planner's faults; 404
  `NoSuchProject` gives the project and asks once more; 503, 504 and no planner are transient; another 404 or 405 says
  the planner needs to be newer. The POST, the project's PUT and the refusal words are shared with ideas
  (`postToPlanner`, `plannerWords`, `faultsIn` in `lib/src/app/planner_ideas.dart`).
- **Start** (`lib/src/ui/planning_embedding.dart`, `lib/src/app/fleet_backend.dart`,
  `lib/src/client/porelo_client.dart`): an order whose MAIN or BUILDER task names a result is started with
  `readOnly`, `result` and `given` (name to text); a machine whose Start declares neither `readOnly` nor `given` is
  refused with `FeatureNotSupported` before anything is sent. `PlannedOffer` and `PendingStart` keep the result file,
  so a start found again by its key keeps it too.
- **End** (`lib/src/ui/planning_reports.dart`): before an end is reported, a stage's result is read from the machine
  and handed in: missing is looked at again for `missingSettles`, then sent as `missing`; too large for the machine
  or the planner, unreadable, or no JSON object is sent as `missing` with one line why. The end follows once the
  planner answered, saved or refused; a refusal is said with its faults. A transient one keeps the end back, is said
  once and tried on the next sweep; a hand-in saved while the end could not be told is not sent again
  (`resultHanded`), also across a restart. One whose file could not be read from the machine is said once and not
  tried again in this window's life.
- **Departure from the Plan:** a refused result still lets its end be reported: the planner moves the issue on the
  saved result, not on the end, as the agreed format says. The window removes no planned stage's task.
- **Tests**, each seen red by a deliberate break, then restored from a copy:
  - `test/app/planner_stage_results_test.dart` (new, six): red with the path `results`, without `missing` in the
    body, with 503 not transient, with a 200 not taken as saved.
  - `test/app/planning_offers_test.dart`: the result file and its hand-in kept across a restart (red without
    `result` written: `Actual: (null, the end)`); a stored path dropped (red unchecked: `Actual: '/etc/passwd'`).
  - `test/ui/window_task_reports_test.dart`, group *an ended planned stage* (nine): hands once before the end (red
    without the hand-in kept: the end ahead of it); keeps the end back while not reached (red); a saved result not
    handed again while its end waits (red without `resultHanded`); refused with faults; missing after settling (red
    with no settling); no JSON object, over the planner's bound, over the machine's (each red); work that pushes
    reports its end alone; a stage found again by its key (red without the result in `PendingStart`, in its JSON or
    from the order).
  - `test/app/start_ordered_test.dart`: a stage's Start carries `readOnly`, `result`, `given` (red without each); a
    machine without `readOnly` or `given` is never asked (red without the check).
  - `test/ui/window_task_starts_test.dart` *a stage starts read only with its result file and given issues…*,
    through `PlanningTaskOrder.from` on the new pin: red without `given`, `readOnly` or the kept result. On the old pin
    the order itself is refused ("Only a discussion hands back a result."), read in its code, not run.
- **Runs:** `dart analyze` No issues found; the six files above green together (122) on the new pin. `test/ui` and
  `test/features` not run whole.
- **Not done:** the Plan's feature scenario. The planner's `MockPlanningSource` serves no stage order and the
  features' world hands nothing to a planner, so a scenario needs a stand-in for both; left to
  [F585](README.md#f585)'s end-to-end scenario or an issue of its own.

## To be checked

- Agent Planner's and Agent Core's issue numbers for their parts, cited here once filed.
- Agent Planner's PL141 hand-in route is built on its branch, not yet handed over; the window was tested against a
  stand-in of the agreed answers, not the planner itself.
