# F600 — The Board Hears What Needs You Saw

```json
{
  "$schema": "issue-1.json",
  "id": "F600",
  "title": "The Board Hears What Needs You Saw",
  "state": "Implementing",
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

## To be checked

- PL149's pushed commit, cited here once pushed.
