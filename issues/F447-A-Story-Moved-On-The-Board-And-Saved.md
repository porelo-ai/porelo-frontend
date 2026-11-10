# F447 — A Story Moved On The Board And Saved

**Status:** Rework: a move is saved through the planner, the local app that now holds the stories and issues, instead of
the machine's daemon, which knows them no more. The window's planning mock (`lib/src/mock/planning_data.dart`,
`planning_moves.dart` and what they serve) moves into the planner, which gets a mock mode serving this board; the
window's planning tests start the planner in that mode instead of a mock in the window, and the Dart mock stays until
the planner's mock mode exists. To be built once the planner's API is served.
**Size:** M - drag and drop on the board's cards and states, the moves kept as pending until saved or undone, one
write of the contract with its refusals, and a feature file.

**What must be true.** The operator drags a story to another state; the move is marked and kept until *Save* writes
all of them through the machine at once, or *Undo* drops them. A drag into a working state starts the work instead
(the dialog of the next issue); the window never decides a move is allowed, the machine does.

## What it builds against (in words)

- A move of a story to a waiting or closed state, with the revision the board was read at: the machine moves every
  issue that is in the story's state (issues further on stay), all moves or none, and answers the new revision and
  the issues it moved.
- Refusals: the revision is stale (the board changed since), the move is not allowed from that state (with the
  machine's reason), or the story is unknown.
- A move of one issue alone, the same way, for the story's own screen.

## Plan

- `lib/src/ui/planning_view.dart`: each card a `LongPressDraggable`/`Draggable`, each state group a `DragTarget`
  that shows *Drop here for <state>* while a card is over it; a folded phase or state accepts a drop too.
- `lib/src/app/planning_board.dart`: the pending moves (story → state), each card marked *moved*; the bar *n state
  change(s) not saved yet: …* with *Undo* and *Save*. Save sends them in one call with the board's revision, and the cards take the issues the machine says it moved
  at once, before the watch brings the rest; on a
  stale revision the board is read again and the moves that still apply stay pending, the others are named as made
  elsewhere; on a refusal the machine's words are shown beside the card and the move stays pending.
- A drop on a working state is never pending: it opens the start of the work (built with that issue), and the card
  stays where it was until the work started.
- The button is *Save*, not *Sign and save*: planning data carries no signature (the operator, 2026-11-09).
- Leaving Planning or the window with pending moves asks first, as the window asks for an unsent message.
- `client/porelo_client.dart`: the move of stories and of issues; the mock daemon and the fake backend apply them and
  answer a stale revision when told to.
- `test/features/planning_moves.feature`: drag, marked, undo, save; save on a stale board; a refused move with the
  machine's words; a drop on a working state opens the start and moves nothing. First red: a saved move that the
  machine refused still shown in its new column.

## Acceptance

- After *Save*, the cards stand where the machine's next answer puts them; nothing is shown moved that the machine did
  not move.
- *Undo* puts every pending card back without a call to the machine.
- A move refused or overtaken says why and is not lost silently.

## Open questions

- None.

## To be checked

- Nothing yet; the names once the daemon's part is served.
