# F563 — One Title On A Planning Detail Page

```json
{
  "$schema": "issue-1.json",
  "id": "F563",
  "title": "One Title On A Planning Detail Page",
  "state": "Backlog",
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
