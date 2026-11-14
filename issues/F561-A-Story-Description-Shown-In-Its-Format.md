# F561 — A Story Description Shown In Its Format

```json
{
  "$schema": "issue-1.json",
  "id": "F561",
  "title": "A Story Description Shown In Its Format",
  "state": "Review",
  "size": "XS",
  "priority": "Highest",
  "rank": 8,
  "blockedBy": [],
  "covers": "Story ST361: a story's description and an issue's text in Planning are shown in the format the planner's store names, Markdown rendered, instead of as their raw signs."
}
```

**Why this size.** The planning screen does the rendering already, on porelo-planner's main; the window's pin of it
stood one commit before.

**What must be true.** A person reading a story or an issue in the window's Planning sees its headings, lists and
emphasis, not the Markdown signs.

## Plan

- Raise the pin of `porelo_planning` in `pubspec.yaml` to porelo-planner's main at the commit that shows a
  description in its store's format, with `pubspec.lock` (it adds `markdown`).
- The window reads the board through the screen's own `HttpPlanningSource`, which passes the planner's answer on as
  it is, so the format reaches the screen without code here.
- The planning scenarios that read the description's source now read it rendered, and say its raw signs are gone.

## Acceptance

- *A card opens its story* and the finder's story test are red on the old pin and green on the new.

## Built

The pin stands at porelo-planner `6bdad25`. Both checks were red on `8379dfd` and are green on it. The planning
scenarios and pages pass 64 tests, and `dart analyze` is clean. A planner that does not name a format yet still shows
its text plain.
