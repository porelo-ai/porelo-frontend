# F482 — Every Row In Needs You Can Be Put Away

```json
{
  "$schema": "issue-1.json",
  "id": "F482",
  "title": "Every Row In Needs You Can Be Put Away",
  "state": "Review",
  "size": "S",
  "priority": "High",
  "rank": 4,
  "blockedBy": [],
  "covers": "Every row in Needs you, a planner's reading stop among them, carries Seen; a row put away stays away past a restart of the window until its cause comes again, and is kept in the window's log."
}
```

**Why this size.** One row kind of `Attention` (`lib/src/app/attention.dart`) gets the mark the story ends already
have, and `_PlanningRow` in `lib/src/ui/attention_view.dart` shows *Seen* for it, with widget and model tests.

**What must be true.** A person who has read a row in *Needs you* can put it away, whatever the row is, and it does not
come back until its cause happens again.

## Why

The operator found 18 planner rows in *Needs you*, one for each issue in Implementing (an issue's id, its repository and
"reading ? of ?"), with nothing to press. Today *Seen* is offered on failed operations, missed questions, machine
notices and ended work; a planner row gets it only where a story's work ended (`attention_view.dart:253`). A reading
stop has none: it leaves only when the planner stops saying it.

## Plan

- A stopped reading is put away by the planner's own key for it, `PlanningAttention.putAwayOn`: machine, project,
  issue, and the reason and state the row showed, so a change of either says it again. The window keeps the set in
  Settings (`readingsPutAway`), checked field by field, and `Attention` leaves those rows out of *Needs you*.
- The mark is dropped once the board, live, complete and every story's work read, no longer says that issue, as for
  a story's end; a board not read yet keeps every mark.
- `_PlanningRow` in `lib/src/ui/attention_view.dart` offers *Seen* for a stopped reading, as it does for a story's
  end; putting it away is written to the window's log, as every row put away is.
- Red first: a model test that puts a reading away and reads it after a restart, and a feature scenario that presses
  *Seen* on a stopped reading.

## Decided

- The planner's `PlanningBoards.putAway` is not used: its set forgets every row no board says, which at the start of
  the window is every row, so a row put away would come back at each start. The window keeps the set itself, with its
  own rule for dropping a mark, and reads the planner's key for a row.
- The row offers the window's *Seen*, as every other row of *Needs you* does, not the planner view's *Put away*.

## How it was built

- `Settings.readingsPutAway` and `setReadingsPutAway` keep the put-away readings; `Attention.readingSeen` adds one,
  `Attention` leaves them out of the open rows and drops a mark whose board, read whole, no longer says the issue;
  `attention_view.dart` offers *Seen* on a stopped reading.
- Tests: `test/app/planning_attention_test.dart` puts a reading away, reads it after a restart over the same settings
  store and sees it come back once the issue's state changes; a second test sees the mark kept while the board is not
  read and dropped once it is, and the next stop said. `test/features/story_work.feature` presses *Seen* on a stopped
  reading. Each seen red: without the filter, without the stored field, without the pruning, with a board not read
  whole taken as read, and without the button.
