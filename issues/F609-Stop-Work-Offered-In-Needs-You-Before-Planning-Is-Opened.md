# F609 — Stop Work Offered in Needs You Before Planning Is Opened

```json
{
  "$schema": "issue-1.json",
  "id": "F609",
  "title": "Stop Work Offered in Needs You Before Planning Is Opened",
  "state": "Review",
  "size": "XS",
  "priority": "High",
  "rank": 129,
  "blockedBy": [],
  "covers": "The window hands its task changes (WindowTaskChanges) to the planning boards when it makes them, as it hands the start hooks, so Stop work on a Needs you row works before the planning page was shown"
}
```

**Why this size.** XS: where the window makes `PlanningBoards`, it passes the same `WindowTaskChanges` that
`_planningPage` gives `PlanningScreen`, and the pin moves to the porelo-planner screen build that takes it. One widget
test.

**What must be true.** A person can stop a story's running or raised work from its *Needs you* row right after the
window starts, without opening *Planning* first.

## Found

On 2026-11-17, in a live test on a rented host. *Stop work* on a ST372 row in *Needs you* was disabled: "the window
has not handed the planning screen the hook that stops tasks".

## Plan

- Today: `_planningPage` in `lib/src/ui/shell.dart` (around line 4663) hands `WindowTaskChanges(whyNot, opening,
  onStarted, onStop)` only to `PlanningScreen`. The boards behind *Needs you* get it only once that page was built.
- Contract it builds against: the planning screen package's `PlanningBoards` takes an optional `taskChanges` when it
  is made and hands it to each board.
- Change: where the window makes `PlanningBoards`, it passes the same `WindowTaskChanges`, built once and shared with
  `_planningPage`.
- Red first: a widget test that opens *Needs you* with a running story's row and never opens *Planning*. Today Stop
  work is disabled with that reason; after the change it is enabled, and a tap stops the task through the window.

## Acceptance

- Stop work on a *Needs you* row works right after the window starts.
- The test above fails without the change.
