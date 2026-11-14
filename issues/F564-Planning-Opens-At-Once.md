# F564 — Planning Opens At Once

```json
{
  "$schema": "issue-1.json",
  "id": "F564",
  "title": "Planning Opens At Once",
  "state": "Review",
  "size": "S",
  "priority": "Highest",
  "rank": 8,
  "blockedBy": [],
  "covers": "Story ST361: Planning opens at once on a board of the porelo projects' size, shows that it loads while it does, and folds a lane without a stall."
}
```

**Why this size.** The window's own part of the click is cheap; the board the planning screen draws builds every card
at once. The window keeps a guard and takes the screen's change with the next pin raise of `porelo_planning`.

**What must be true.** A click on Planning, the first or any later one, shows the page at once on a board of about 360
stories with several issues each; while the board is read the page says so; folding or unfolding a lane answers
without a stall.

## Cause

The planning screen (porelo-planner `screen/lib/src/ui/planning_view.dart`, at the pinned `f8465da`) builds and lays
out every card of every lane on every build of the board:

- lines 513–536: the board is a vertical `SingleChildScrollView` holding a horizontal `SingleChildScrollView` holding a
  `Row` of every phase, so nothing in it is built lazily;
- line 628: each phase is a `Column` of all its states;
- line 759: each state is `for (final story in cards) _card(context, story)` inside that `Column`, every card built,
  however far out of view; line 707 does the same for the marks of a folded phase in a `Wrap`;
- a fold (`board.foldState`, `board.foldPhase`) notifies the board, and the whole `_board` builder runs again: the
  card cache (`_cards`, line 988) spares rebuilding each card's widgets, but every card's inputs are computed again
  and the whole `Row` is laid out again;
- the cache lives in `_BoardViewState`, which is disposed when the person leaves Planning, so every return builds all
  cards anew. That is why a second click freezes as the first did.

Nothing else on the click path costs much. The window's `_planningPage` (lib/src/ui/shell.dart) only wraps the
screen; `LocalPlanner`'s `FileStat.statSync` (lib/src/app/planner.dart, `_aFile` and `_runnable`) runs over a few
program paths only while no planner is found, never on the click. The board's `jsonDecode` on the UI isolate
(`planner_source.dart` lines 1244 and 1571) takes 7 to 27 ms in the Dart VM for a 1.7 MB board of 360 stories with
four issues each.

While the board is read, the screen says *Waiting for the planner’s answer.* above an empty board (lines 494–495
and 504); before any board is read it says *No project planning has been read from the planner.* (line 142), which
reads as a fault, not as loading. The freeze comes after the board arrives, so these words are never seen while the
window blocks.

## Measured

`flutter test` in debug, headless, a 1600×1000 surface, the stand-in board grown to 360 stories with four issues
each over all 15 states (`test/ui/planning_large_board_test.dart`). Wall time of the click and its pumps until the
board stands, and of a fold and an unfold of the lane of state *Idea*:

| Board | Open | Fold + unfold |
| --- | --- | --- |
| 1 story, idle host | 216 ms | 122 ms |
| 35 stories (the stand-in's), idle host | 378 ms | 138 ms |
| 360 stories, idle host | 1.7–2.1 s | 0.6–0.8 s |
| 360 stories, busy host (load 10) | 6.2–6.7 s | 1.8 s |
| 360 stories, the screen changed to build only 4 cards per lane | 0.6–0.9 s | 0.36–0.41 s |
| 360 stories, the screen changed to build no card | 0.43 s | 0.31 s |

The cost grows with the number of cards built, about 5 ms per card in debug on an idle host; the operator's window,
debug under `flutter run` with the real planner, more work on each card and a busy desktop, takes seconds.

No release number was taken: no window may be opened on this host, and `flutter test` runs debug only.

## The planner's half

Asked of porelo-planner, in `screen/lib/src/ui/planning_view.dart`:

1. **Build only the cards in view** (lines 513–536, 600–631, 704–759). Each phase a column of fixed width that scrolls
   on its own, its states and their cards in one lazy list (a `CustomScrollView` with a `SliverList.builder` of each
   state's cards under its header, or one `ListView.builder` over headers and cards), the phases in a horizontal list;
   the same for the marks of a folded phase. Each state's `DragTarget` then covers its header and its sliver, or the
   column drops onto the state under the pointer. Keeping the board's present one vertical scroll for all columns
   means a two-dimensional lazy view (`TwoDimensionalScrollView`); either way no card out of view is built or laid
   out. The search's `_searchFor` (lines 261–285) then scrolls by index to a found card instead of looking for its
   built element.
2. **Fold without rebuilding the board.** A fold changes one lane: its header and its list, not every card's inputs
   and the whole `Row`. Each state or phase listens for its own fold, or the board passes the fold state down so the
   other lanes' widgets are equal and skipped.
3. **Keep the cards over a return.** The built cards, or at least the parsed board and its sort, are kept beside the
   `PlanningBoard`, not in the `_BoardViewState` a return to Planning makes anew.
4. **A loading state that is seen.** Before the first list of projects is read, the board's place says the board is
   being read, with a progress mark, instead of *No project planning has been read from the planner.* (line 142);
   the *Waiting for the planner’s answer.* line (495) gets the same mark. Once 1 to 3 hold, the first frame after the
   board arrives is short, so the person sees these words and then the board.
5. Optional: decode a board larger than about 1 MB in a background isolate (`planner_source.dart` 1244, 1571); measured
   at 7–27 ms, so not needed for this finding.

## Acceptance

- `test/ui/planning_large_board_test.dart`, skipped until the screen's half is pinned, is green with its skip removed:
  on the 360-story board, opening takes less than 3 times and a fold and unfold less than 2.75 times as long as on the
  stand-in's 35-story board in the same run. Today it is red (1919 against 377 ms to open).
- The planning scenarios and `test/ui/planning_*_test.dart` green.

## Built

The guard `test/ui/planning_large_board_test.dart`: it opens Planning on the stand-in's board, leaves it, opens it again
and folds a lane, then pushes the large board, leaves, returns and folds again, and compares the two. Its wall time
is measured against the small board of the same run, so a busy host slows both alike. Red with the pinned screen
(large board: 4.7–5.1 times as long to open, 3.0–4.3 times to fold); with the screen changed to build four cards per
lane, 1.8–2.1 and 1.1–2.4 times. It is skipped until porelo-planner's change is pinned.

With the screen's change pinned (porelo-planner `8dce2dc`), the guard runs unskipped and passes. Each phase now scrolls
on its own and builds only the cards in its view, so the planning steps find a card by scrolling its phase, not by
looking it up on a board that has built everything:

- `revealPlanning` walks the phases until a card is built and scrolls its phase to it. A single `ensureVisible` can stop
  short there, as a column's length is an estimate until its last cards are built, so the steps scroll the phase
  themselves.
- What a step reads across a whole phase (the sort of *Implementing*, the marks of a folded *Build*, that only the
  searched story remains, that a card or text is nowhere) is gathered while the phase is walked from top to foot, so it
  still covers every card, not only those in view.
- A state is now a group of slivers without a box: the order of working states is read from their headings'
  places in the column, a card is dropped on the heading (`planning-drop`), and a state's presence and its drop hint
  are read from the built group even out of view.
- The board's position is the sideways scroll and each phase's own; going back to the board keeps all of them. The
  board is scrolled with the wheel, as a drag that starts on a card picks the card up.

Seen red with the fixture broken on purpose: one more *Highest* story in *Build* fails the sort, the folded marks and
the hidden low-priority story; *Review* made a working state ahead of *Implementing* fails the working-states order.

A reading of the change closed its gaps: the walk also covers the column of stories outside the reported workflow, and
fails when it finds no column at all; a card's saving line is read with the card in view; the folded phase holds no
mark outside a tile; the guard checks that the lane folded and came back, and compares the medians of three returns
on each board. With the screen pinned, the large board takes 0.85 to 1.5 times as long to open as the small one and
0.77 to 1.3 times as long to fold and unfold a lane.
