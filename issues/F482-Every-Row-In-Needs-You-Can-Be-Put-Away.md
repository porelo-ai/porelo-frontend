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
- A mark is dropped once its board, live, complete and every story's work read, no longer says that issue, or says it
  with another reason or state; once its machine is neither a machine of the window nor a provider of the planning,
  the machines read and the planning listing a provider; and once no machine lists its project, every machine having
  answered with its whole list. A board, provider or list not read yet keeps every mark.
- Marks put away before the settings were read are kept in them once they are.
- `_PlanningRow` in `lib/src/ui/attention_view.dart` offers *Seen* for a stopped reading, as it does for a story's
  end; putting it away is written to the window's log, as every row put away is.

## Decided

- The planner's `PlanningBoards.putAway` is not used: its set forgets every row no board says, which at the start of
  the window is every row, so a row put away would come back at each start. The window keeps the set itself, with its
  own rule for dropping a mark, and reads the planner's key for a row.
- The row offers the window's *Seen*, as every other row of *Needs you* does, not the planner view's *Put away*.
- Known limit: a reading that stops again with the same reason and state while the window is closed, after its board
  stopped saying it in between, stays put away, since the window never saw the board without it. Only a window that
  is open sees the stop end.

## How it was built

- `Settings.readingsPutAway` and `setReadingsPutAway` keep the put-away readings; `Attention.readingSeen` adds one,
  `Attention` leaves them out of the open rows and drops the marks that hide nothing any more, as the plan says, and
  copies the ones put away before the settings were read into them; `attention_view.dart` offers *Seen* on a stopped
  reading.
- Tests in `test/app/planning_attention_test.dart`:
  - a reading put away stays away after a restart over the same settings store and comes back once the issue's state
    changes; red without the filter and without the stored field;
  - the mark is kept while the board is not live yet and dropped once it is read whole, and the next stop is said;
    red without the pruning, and with a board not read whole taken as read;
  - the state moving on and back says the stop again; red with only an issue no longer said dropping its mark;
  - the mark is kept while a story's work cannot be read; red with that board taken as read whole;
  - marks of a machine the window does not know and of a project no machine lists are dropped once the machines are
    read; red without each check;
  - a reading put away before the settings were read is kept in them once they are, as a reload of the store shows;
    red without the copy.
- `test/features/story_work.feature` presses *Seen* on a stopped reading and finds the row gone and the mark in the
  settings; red without the button. A partial snapshot is not tested: the planner's fake cannot serve a board without
  its stories.
