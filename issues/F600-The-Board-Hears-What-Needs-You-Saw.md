# F600 — The Board Hears What Needs You Saw

```json
{
  "$schema": "issue-1.json",
  "id": "F600",
  "title": "The Board Hears What Needs You Saw",
  "state": "Review",
  "size": "S",
  "priority": "High",
  "rank": 120,
  "blockedBy": [],
  "covers": "A planning row marked Seen under Needs you leaves the story card's needs you and the Planning count too: the window passes its seen marks to porelo-planner's boards as PlanningSeen, which answers for an issue's put-away reading and for a story's end at its time, and tells the boards when a mark changes."
}
```

**Why this size.** S: one `PlanningSeen` the window owns over the marks `Attention` already keeps, passed into
`PlanningBoards` beside `startTask` and `agents`, a change notified on each mark set or dropped, the pin raised to
porelo-planner's PL149, and a scenario from *Seen* to the card and the count.

**What must be true.** A person who marks a stopped run or reading *Seen* under *Needs you* no longer sees that story
card say *needs you*, nor the Planning count include it, until it is said again under *Needs you*.

## Found

Agent Planner's PL149, *a stopped run seen leaves the card*, from ST369's live test of 15 November, asked what the
window's *Seen* sets (room, 15:19Z). The window's *Seen* (`_PlanningRow` in `lib/src/ui/attention_view.dart`) sets marks
of the window's own in `Attention` (`lib/src/app/attention.dart`): `storyEndSeen` keeps `story ended <id> at <at>` in
`endedPutAway`, `readingSeen` keeps a `PlanningPutAway` in `readingsPutAway`, each with a session-only set beside the
settings. Only *Needs you* and its count read them; the boards hear nothing of them.

## Plan

- **Contract**, as Agent Planner named it (room, 2026-11-15 15:23Z; porelo-planner `9f6769e`, PL149's plan):
  `PlanningSeen`, a `Listenable` the window owns and passes into the boards as it passes `startTask` and `agents`,
  answers whether an issue's `PlanningPutAway` is seen and whether a story's end at a given `at` is seen; the card's
  *needs you* and the Planning count leave out what it answers seen and redraw on its changes. The screen keeps no
  copy.
- **Steps**, once PL149's screen is pinned:
  - `Attention` implements or holds the window's `PlanningSeen`, answering from `_readingsPutAway` and from
    `_endedPutAway` by the story's entry key and `at`, the session-only marks included, and notifying on each change
    (marks set, marks dropped as gone, settings read).
  - `PlanningBoards` in `lib/src/ui/shell.dart` gets it.
  - Raise the pin of `porelo_planning` with its lock, the `xterm` override kept.
  - A scenario: a stopped reading and a story's ended run marked *Seen* leave the card's *needs you* and the Planning
    count; a new reason or a new end brings both back.
- **Red first:** that scenario on the old pin, where the card still says *needs you*.

## Acceptance

- *Seen* on a stopped reading or a story's ended work takes it off the card's *needs you* and the Planning count at
  once. Seen to fail: the scenario on the old pin.
- A changed reason or state, or a later end, is said again on the card and in the count.
- A mark kept for the session only (no time, settings not read) counts the same while the window runs.

## Built

- **Against** porelo-planner `cb9d13a`, its pushed main with `PlanningSeen`, `PlanningStoryEnd`,
  `PlanningAttention.endOn` and `PlanningBoards(seen:)`; the pin already stood there, no override.
- **`Attention.seen`** (`lib/src/app/attention.dart`): a `PlanningSeen` answering from the marks *Seen* already
  keeps, `readingsPutAway` for an issue's `PlanningPutAway` and `endedPutAway` (`story ended <id> at <at>`) for a
  story's end, the session-only marks included. It tells its listeners only when those marks change, last in
  `Attention`'s own update, so the boards and `Attention`, each listening to the other, settle after one round.
- **Marks judged gone against every row**: a mark is dropped when the board, read whole, no longer says its row;
  that is now read from every row the boards say (`PlanningBoards.storyAttention`), seen ones too, since the boards'
  `needsYou` leaves seen rows out and a mark would otherwise drop itself and bring its row back.
- **`lib/src/ui/shell.dart`**: `Attention` is made before the boards, which take `seen: _attention.seen`.
  `PlanningScreen` takes the same boards and has no `seen` of its own. The boards' old `putAway` set is set nowhere
  in the window.
- **Tests:** the scenario *A stopped reading put away leaves its story's card* in `test/features/story_work.feature`
  (folded card, its `planning-warning ST291` gone after *Seen*), and in `test/app/planning_attention_test.dart`
  *a row seen leaves the boards' Needs you and its story's card until it is said again* (a stopped reading and a
  story's end leave `boards.needsYou` and `attentionSeen`, a changed state or a later end brings them back, the
  marks stay kept). The environment of that file now hands `seen` in, as the window does.
- **Red:** the scenario without `seen` handed in: `Expected: no matching candidates, Actual: Found 1 widget with key
  [<'planning-warning ST291'>]`; the unit test with a `PlanningSeen` answering nothing: `Expected: empty, Actual:
  [Instance of 'PlanningNeedsYou']`. Gone-marks read from the boards' filtered `needsYou` on purpose: 6 of 12 red in
  `planning_attention_test.dart` (marks dropped, rows back); restored from a copy.
- **Runs (laptop, one file each):** `planning_attention_test.dart` 12 passed; `story_work_test.dart` 29 passed;
  `planning_board_test.dart` 16 passed. `dart analyze lib test integration_test tool`: No issues found. The whole
  suite runs on the build box at the branch's head.

## To be checked

- An unfolded card's *stopped in Reading - needs you* line is the screen's and is drawn for every stopped reading,
  seen or not; only the folded card's warning and the raised mark follow `seen`. Whether the line should follow it
  too is porelo-planner's to say.
- The boards leave out an issue row with a seen `PlanningPutAway` also where its task's end is reported; the window's
  *Seen* marks only rows without one. No such row was seen to differ in a test.
- The reading by another model has not run.
