# F563 — One Title On A Planning Detail Page

```json
{
  "$schema": "issue-1.json",
  "id": "F563",
  "title": "One Title On A Planning Detail Page",
  "state": "Review",
  "size": "XS",
  "priority": "Highest",
  "rank": 11,
  "blockedBy": [],
  "covers": "Story ST361: a story's or an issue's page in Planning has one title, not the window's Planning head above the screen's breadcrumb."
}
```

**Why this size.** The window's head over the planning screen is drawn in one place; a detail page drops it or the
screen's breadcrumb takes its place.

**What must be true.** A person on a story's or an issue's page in Planning reads one page title, with its *i*, and the
breadcrumb that leads back.

## Plan

- Taken with the next pin raise of `porelo_planning` (porelo-planner's PL131, PL132 and PL133 once on main), as
  porelo-planner's PL133 changes what the screen draws at its head.
- The window's *Planning ⓘ* head stands over the board only; on a detail page the screen's breadcrumb is the title,
  and the page keeps one *i* (the guard in `test/ui/every_page_explained_test.dart` keeps saying so).

## Acceptance

- A guard sees one title on a story's and an issue's page in Planning, red before and green after; the planning
  scenarios and the explanation guard green.

## Built

The pin of `porelo_planning` stands at porelo-planner `f8465da` (PL134, with PL131, PL132, PL133 and PL130 below it),
with `pubspec.lock`. The screen takes `pageButton`, and the window passes its *i* there: it stands after the screen's
*Planning* head on the board, and at the end of the breadcrumb on a story's or an issue's page. The window draws no
head of its own over a reached planning screen. Where none is reached, its own *Planning* head stands over the line
that says why, with the same *i*. `test/ui/planning_finder_test.dart` sees one title, and the *i* inside the screen,
on the board, a story's page and an issue's page. It was red with the window's head and is green now.

A reading by Gemini found that the section check of the planning scenarios read the issue page's one shared card as
a whole, so a row's words could be found in another row. It now reads the row of an issue's facts, and it refuses a
claim the old check passed. The guard now also holds that the page's one *Planning* stands in the screen's head or
breadcrumb, beside the *i*.

## Left

- **No i on the screen's fallback page.** Where no board is read, or the planner of an open story is gone, the screen
  draws its fallback crumb without `pageButton`, so that page has no *i*. This is asked of porelo-planner.
- **The first-time words above the title.** The window can place its first-time words only above the whole screen, so
  they stand above the screen's *Planning* head, not under it. A `pageNote` slot is asked of porelo-planner.

Both are answered by porelo-planner `afadf42`, taken in the next commit: Planning's first-time words go to
`pageNote`, under the screen's head and a detail page's breadcrumb, and the fallback page carries the *i*. A guard holds
each, red on this commit's state.
