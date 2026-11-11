# F482 — Every Row In Needs You Can Be Put Away

```json
{
  "$schema": "issue-1.json",
  "id": "F482",
  "title": "Every Row In Needs You Can Be Put Away",
  "state": "Idea",
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

- A reading stop is marked as put away by its issue and the reading round it stopped at, kept in Settings like a story
  end's mark, so a later stop of the same issue is said again.
- The mark is dropped once the board, read whole, no longer says that stop, as for a story's end.
- A row put away is written to the window's log ([F483](README.md#f483)).

## To be checked

- Which key names one reading stop: Planner says whether the board carries a round or an instant for it.
