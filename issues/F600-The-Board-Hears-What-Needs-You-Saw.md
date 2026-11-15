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

- **Against** porelo-planner `cce776c`, the pin (raised from `cb9d13a` in its own commit), built and tested against
  that pin, never an override. There `PlanningSeen` is the one form of seen marks (`PlanningBoards.putAway` is gone),
  `putAwayOn` answers only an issue row without an end, and `endOn` answers a `PlanningStoryEnd` for every row with an
  end, issue rows included; a story's end seen covers its issue rows that ended at the same time, and the card quiets
  once every row of the story is seen.
- **`Attention.seen`** (`lib/src/app/attention.dart`): a `PlanningSeen` answering from the marks *Seen* already
  keeps, `readingsPutAway` for an issue's `PlanningPutAway` and `endedPutAway` (`story ended <id> at <at>`) for a
  story's end, the session-only marks included (an end with no time, marks set before the settings were read). It
  tells its listeners only when those marks change, in a microtask after `Attention`'s own update, as the settings
  writes there are deferred: that update can run while a frame is drawn, and the boards hearing it redraw.
- **Ended rows marked by their end:** *Seen* on a row with an end, the story's or an issue's whose task ended, keeps
  the mark the boards ask through `endSeen`, `story ended <machine>/<project>/<story> at <at>`, from
  `PlanningAttention.endOn`; before, an ended issue row kept `reading <machine>/<project>/<issue> at <at>`, which the
  boards never ask. A reading put away hides only its stop: `putAwayOn` gives no put-away for a row with an end, so
  its later end is said.
- **Marks judged gone against every row**: a mark is dropped when the board, read whole, no longer says its row;
  that is now read from every row the boards say (`PlanningBoards.storyAttention`), seen ones too, since the boards'
  `needsYou` leaves seen rows out and a mark would otherwise drop itself and bring its row back.
- **`lib/src/ui/shell.dart`**: `Attention` is made before the boards, which take `seen: _attention.seen`.
  `PlanningScreen` takes the same boards and has no `seen` of its own. The boards' old `putAway` set is set nowhere
  in the window.
- **What the window proves:** the boards' Needs you (`boards.needsYou`, what the count reads), the folded card's
  warning, and `attentionSeen` for a story whose end and ended issue were marked seen together. How the card draws
  each row seen is porelo-planner's.
- **Tests:** the scenario *A stopped reading put away leaves its story's card* in `test/features/story_work.feature`
  (folded card, its `planning-warning ST291` gone after *Seen*); in `test/app/planning_attention_test.dart`, whose
  environment now hands `seen` in as the window does:
  - *a row seen leaves the boards' Needs you and its story's card until it is said again* (a stopped reading and a
    story's end leave `boards.needsYou`, a changed state or a later end brings them back, the marks stay kept);
  - *a reading put away still says a later end of its issue's task*;
  - *a story's end with no time seen leaves the boards for this window's life*;
  - *a reading put away before the settings were read leaves the boards*;
  - *a reading put away is said again once its reason changes*;
  - *an issue row whose task ended, marked seen, leaves the boards as its story's end*.
- **Red:**
  - the scenario without `seen` handed in: `Expected: no matching candidates, Actual: Found 1 widget with key
    [<'planning-warning ST291'>]`;
  - the first unit test with a `PlanningSeen` answering nothing: `Expected: empty, Actual: [Instance of
    'PlanningNeedsYou']`;
  - gone-marks read from the boards' filtered `needsYou`: 6 of 11 red (marks dropped, rows back);
  - on `cb9d13a`, `putAwaySeen` without a check for an ended row: `Expected: contains 'reading builder/demo/item',
    Actual: ['story ended builder/demo/story']` (that check went once `cce776c` stopped asking it for ended rows);
  - on `cce776c`, the window keying an ended issue row by its own id: `Expected: Set:['story ended
    builder/demo/story at 2026-11-10T09:00:00Z']  Actual: Set:['reading builder/demo/item at
    2026-11-10T09:00:00Z']`;
  - `seen` reading the settings' sets alone: both session tests red, `Expected: empty, Actual: ['story ended
    builder/demo/story']` and `Actual: ['reading builder/demo/item']`;
  - the reason test is green with `putAwaySeen` matching by issue alone, since the board read whole also drops the
    mark; with both broken, `Expected: ['reading builder/demo/item'], Actual: []`.
  Each break was put back from a copy, `git diff --stat` unchanged.
- **Runs (laptop, one file each, on `cce776c`):** `planning_attention_test.dart` 16 passed; `story_work_test.dart` 29
  passed; `planning_board_test.dart` 16 passed; `window_task_reports_test.dart` 78 passed. `dart analyze lib test integration_test tool`: No issues found. The whole
  suite runs on the build box at the branch's head.

## To be checked

- Marks an earlier build kept for an ended issue row (`reading <machine>/<project>/<issue> at <at>`) hide nothing
  now and are dropped by no rule; they stay in the settings unused.
- No test shows the boards told during a build; the deferral follows the settings writes' reason, not a failure seen.
- The reading by another model has not run.
