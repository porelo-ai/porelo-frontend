# F591 — A Planned Stage Hands Its Result To The Planner

```json
{
  "$schema": "issue-1.json",
  "id": "F591",
  "title": "A Planned Stage Hands Its Result To The Planner",
  "state": "Backlog",
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

## To be checked

- Agent Planner's and Agent Core's issue numbers for their parts, cited here once filed.
