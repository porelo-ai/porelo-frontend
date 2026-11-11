# F481 — The Board Shows Each Size As A Badge

```json
{
  "$schema": "issue-1.json",
  "id": "F481",
  "title": "The Board Shows Each Size As A Badge",
  "state": "Idea",
  "size": "XS",
  "priority": "Medium",
  "rank": 3,
  "blockedBy": [],
  "covers": "The window carries the planning screen whose story cards and issue tiles show their T-shirt size as a badge beside the priority chip, and a test of the window sees the badge on its embedded board."
}
```

**Why this size.** The story cards and issue tiles are drawn by the planning screen, `porelo_planning`, which lives in
porelo-planner (`screen/lib/src/ui/planning_view.dart`) and is pinned in `pubspec.yaml`. The badge itself is the
planner's part. The window's part is the move of that pin, its CHANGELOG line and one widget test on the embedded board.

**What must be true.** In the window, every story card and every issue tile, in the wide columns and in the compact
tiles of the narrow ones such as Accepted and Review, shows its size (XS, S, M, L, XL) as a badge next to its priority
chip.

## Why

The operator wants the size on the board at a glance. Today an issue row shows it only as plain text after its state
("Analyzed  M", `planning_view.dart:827` at the pinned 09d560b7), and a story card shows none.

- Serves porelo-project's *Visual adjustments in the planner* (story ST316, porelo-project a08b69f), which groups the
  board's look: the size badge on every card and tile, and a folded state's box that keeps its column's width.

## What the contract already carries

An issue's size is in the board contract today: the screen's model reads `size` (`models.dart:216`) and the issue view
and story view show it. A story has no size in story-2.json; where it comes from is the planner's to propose.

## To be checked

- The planner's issue for the badge and for a story's size, and the planner commit that carries both, which this pin
  moves to.
