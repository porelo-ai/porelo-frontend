# F447 — A Story Moved On The Board And Saved

```json
{
  "$schema": "issue-1.json",
  "id": "F447",
  "title": "A Story Moved On The Board And Saved",
  "state": "Implementing",
  "size": "M",
  "priority": "Medium",
  "rank": 2,
  "blockedBy": [],
  "covers": "A story dragged to another state, kept pending until saved through the planner or undone; a drop on a working state starts its work instead."
}
```

**Why this size.** drag and drop on the board's cards and states, the moves kept as pending until saved or undone, one
write of the contract with its refusals, and a feature file.

**Why it is in Rework.** A move is saved through the planner, the local app that now holds the stories and issues,
instead of the machine's daemon, which knows them no more. The window keeps no planning mock of its own: its board tests
use the package's stand-in source (`package:porelo_planning/planning_fake.dart`), and its test against the planner
starts the planner's own mock mode (`--mock`).

**What must be true.** The operator drags a story to another state; the move is marked and kept until *Save* writes
all of them through the planner at once, or *Undo* drops them. A drag into a working state starts the work instead
(the dialog of the next issue); the window never decides a move is allowed, the planner does.

## What it builds against (in words)

- One call of the planner saves a batch of story and issue moves, all or none, with the revision the board was read at;
  a story's move moves every issue in its least advanced state, and the answer names the new revision and the issues
  moved.
- Refusals: the revision is stale (the board changed since), the move is not allowed (`MoveNotAllowed`, with the
  planner's reason), or the story is unknown.
- A batch saved in some repositories but not all answers `PartlySaved`, and every window is told the board that the
  repositories already pushed hold.
- Only the projects of porelo-ai's own central repositories are saved for now.

## How it stands

- The drag, the drop hint, the pending moves marked *moved*, *Save* and *Undo*, the call with the board's revision, the
  cards taking the issues the planner moved, the stale board read again with the moves that still apply kept, and a
  refusal's words beside its card are the planning package's (`PlanningBoard` and `PlanningView` in
  `porelo_planning`), and its `HttpPlanningSource.saveMoves` makes the call. The window builds none of it.
- The window's part is in place: through its planner (`LocalPlanner`, `lib/src/app/planner.dart`) the board's source
  is the package's HTTP source, so a save reaches the planner with nothing of the window between; leaving Planning or
  closing the window with pending moves asks first (`lib/src/ui/shell.dart`, with the package's
  `confirmPlanningLeave` and `PlanningBoards.hasPendingMoves`). `test/features/planning_moves.feature` keeps the
  board's moves as the window embeds them, on the package's stand-in source; removing the window's question turns
  its four leave scenarios red.
- `test/client/planner_mock_test.dart` asserts through the window's planner in the planner's mock mode: a batch at a
  revision the board has left refused as `StaleRevision`, a move not allowed refused as `MoveNotAllowed` with the
  planner's reason as the words the board shows, and a move of an unknown story refused as `NoSuchStory`, each in
  the planner's own words. Bound to Linux, and skipped where no planner is installed.
- The planner's mock mode saves no move (its mock store has no save, so every allowed batch answers `NotOffered`), so
  a saved move and a `PartlySaved` answer are shown on the package's stand-in source instead, in
  `test/features/planning_moves.feature`: a saved move leaves no pending move and the board takes the planner's new
  revision, so the next save goes through rather than being refused as stale; a `PartlySaved` answer shows on every
  card of the batch in the planner's words with the repositories pushed and the one not pushed, and the board is read
  again, so a story the pushed repository took stands where the planner's store holds it. Both are the package's
  behavior and guard it: each went red when the package was broken on purpose (the saved move kept pending, the old
  revision kept, no read after `PartlySaved`, its repositories left out of the words).
- The package is pinned at the planner's version that brings moves and story work into the screen package, together
  with the start of the work: a refused save refuses its whole batch, and every card of it shows the refusal.
- A drop on a working state opens the start of the work and moves nothing; that start is the next issue's.

## Plan

- No production code in the window: the drag, the pending moves, *Save*, *Undo*, the refusals and the call are the
  package's; the leave questions stand in the shell.
- `test/client/planner_mock_test.dart`: a stale revision, `MoveNotAllowed` with its reason and an unknown story,
  refused through the window's planner in mock mode.
- `test/features/planning_moves.feature` stays on the package's stand-in source: drag, mark, undo, save, a saved
  move taking the planner's new revision, a `PartlySaved` answer and the board read again, a stale board, refusals in
  their own words, a drop on a working state, and the leave questions.

## Acceptance

- After *Save*, the cards stand where the planner's answer puts them; nothing is shown moved that the planner did not
  move.
- *Undo* puts every pending card back without a call to the planner.
- A move refused or overtaken says why in the planner's words and is not lost silently; against the planner's mock
  mode a stale revision, a move not allowed and an unknown story are refused through the window's planner.
- Leaving Planning or closing the window with pending moves asks first.
- A saved move and a partly saved batch are shown on the package's stand-in source, since the planner's mock mode
  saves no move.

## Open questions

- None.

## To be checked

- The mock-mode test on a machine with the planner installed, and a save against a live planner of a porelo-ai
  central repository, including a partly saved batch.
