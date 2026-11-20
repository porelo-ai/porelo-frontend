# F617 — A Planned Stage Started With Its Tracker Issue

```json
{
  "$schema": "issue-1.json",
  "id": "F617",
  "title": "A Planned Stage Started With Its Tracker Issue",
  "state": "Idea",
  "size": "-",
  "priority": "Medium",
  "rank": 1,
  "blockedBy": [],
  "covers": "A planned stage of a project kept in a tracker is started with the issue and phase its order names, passed on as Start's work"
}
```

**What must be true.** A task the window starts for a planned stage of a project kept in a tracker (GitHub Issues)
knows which issue and which phase it works on, because the window passes on what the planner's order names. A
project kept in Markdown starts exactly as today.

## The contract it builds on

- The planner's `PlanningTaskOrder` gains an optional `work: {issue: "<owner>/<repo>#<number>", phase: "<the
  stage, as the order's result kind names it>"}`, present only for a project kept in a tracker.
- Porelo's `Start` takes `work` with the same shape. Porelo cannot work out the issue itself.

## To be checked

- Which `porelo_planning` commit carries `work` in `PlanningTaskOrder`, for the pin.
- Whether a daemon that does not declare `Start(work)` refuses the start in words, as for `given`, never a start
  without it (a stage would then run without knowing its issue).
