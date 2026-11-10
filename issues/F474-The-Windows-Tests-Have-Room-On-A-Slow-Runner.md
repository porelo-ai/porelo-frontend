# F474 — The Windows Tests Have Room On A Slow Runner

```json
{
  "$schema": "issue-1.json",
  "id": "F474",
  "title": "The Windows Tests Have Room On A Slow Runner",
  "state": "Review",
  "size": "XS",
  "priority": "High",
  "rank": 1,
  "blockedBy": [],
  "covers": "The Windows job's Test step is given 40 minutes, so a slow runner does not end a sound build."
}
```

**Why this size.** one number in the workflow and its comment.

**What must be true.** A build of main whose tests all pass is not made red by the Windows runner being slow that day.

## Why

Build 42881129679 of main went red: the Windows job's Test step ran out of its 30 minutes at +2836 of the suite. No
test hung: the log moves on steadily, with no pause of 20 seconds or more. From about the thousandth test on, every
feature file took 10 to 18 seconds longer than in the green run before it, on a commit that touches none of them.
Linux ran the same suite in the same time. The step takes 23 minutes on an ordinary day, so a runner a third slower
reaches the limit.

## Plan

- `.github/workflows/build.yml`: the Windows job's Test step gets `timeout-minutes: 40`, and its comment gives the
  times as measured now. Each test keeps its own minute, so a test that hangs still ends the run and names itself.
  The job's own 60 minutes stay above the step's.
- No test of its own: it is a limit of the build, seen in the next Windows run.

## How it stands

- The Test step has 40 minutes. Splitting the step in two was considered and not needed now (Agent Coordinator,
  2026-11-10).
