# F532 — A Left Discussion's Missing Result Is Looked At Again Before It Counts

```json
{
  "$schema": "issue-1.json",
  "id": "F532",
  "title": "A Left Discussion's Missing Result Is Looked At Again Before It Counts",
  "state": "Review",
  "size": "S",
  "priority": "High",
  "rank": 94,
  "blockedBy": [],
  "covers": "The idea of a discussion is handed to the planner even when the machine first listed its task as stopped with no result, before the task started; what the window says of an idea is also in its log."
}
```

**Why this size.** S: one rule in the window's hand-in of a discussion's idea, a clock it can be given, a line in
its log, and their tests.

Found in a walk of an idea from a discussion to a finished story on a test machine (2026-11-13): the discussion
ran, wrote its `idea.json` and ended, but the planner never got a story, and nothing in the window's log said why.

**What must be true.**
- A discussion the person left (a stopped task with its result file) whose result shows as missing is looked at
  again on later sweeps for a minute before the window says it wrote no idea; an idea that shows up meanwhile is
  handed in once, as any other.
- Once that minute passed with the result still missing, the window says once that the discussion ended with no
  idea, as before.
- Whatever the window says of a discussion's idea, or of an idea a task proposed, also goes to the window's log, not
  to the board alone.

## How it stood

- The machine may list a task right after its container was made and before it started: it shows as stopped, with
  its result file missing.
- The window took that as the discussion's end (`left|<since>`), said it wrote no idea and marked that end handled
  (`discussionHanded`), so the real end of the same task, with its idea, was never handed in.
- `_sayIdea` and `_sayProposed` went to the board's problems alone while a board listened, so the window's log held
  nothing of it.

Porelo's own listing records such a result too early as well; the window still looks again, since a missing result
can stay so for good and a short gap between create and start can always be listed.
