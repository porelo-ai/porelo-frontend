# F477 — An Unreached Organization Says When And Why

```json
{
  "$schema": "issue-1.json",
  "id": "F477",
  "title": "An Unreached Organization Says When And Why",
  "state": "Review",
  "size": "S",
  "priority": "High",
  "rank": 1,
  "blockedBy": [],
  "covers": "A stale organization answer is checked again before it is shown, and one that stays stale says when it was checked last and why, in Porelo's cause and git's own words, instead of only that its repositories could not be read."
}
```

**Why this size.** one source's reading of `porelo project show` and one page's head, no contract of its own.

**What must be true.** A person whose project page shows no repositories learns that the organization could not be
reached, when it was read last and why, so they know what to fix instead of trying again blind.

## Why

`porelo org` and `porelo project show` answer the state kept on the machine at once, `"stale": true` with its
`checked_at`, and check the organization afterwards; a stale project answers its repositories `cannot-say`. The
window never asked again, so a page stayed without repositories although the check succeeded. The page said only "Its repositories could not be read just now.", and the head repeated it. The organization's own pages
said the store could not be reached, but under *read less than a minute ago*: the time the window asked, not the age
of the state.

## Plan

- `lib/src/app/porelo_organization_source.dart`, `readProject`: a `cannot-say` on a stale answer is worded as an
  unreached organization with the local time of `checked_at` (and its date when it is not today); a `checked_at`
  missing or unreadable says that Porelo does not say when. A `cannot-say` on a fresh answer keeps its sentence.
- `lib/src/ui/organization_project_pages.dart`: the page head says only "repositories not read"; the whole sentence
  stands once, above the list.
- `lib/src/app/organization_source.dart`: a stale organization read takes `checked_at` as its read time instead of the
  window's clock, so *read less than a minute ago* never stands over a state kept from before; the test that a
  stale read says when the store was reached last went red first.
- `porelo org` and `project show` answer the state kept on the machine first, `stale`, and check afterwards: a stale
  answer is asked once more with `--refresh`, which waits for the check and replaces it; a refused check leaves the
  kept state, still marked stale. A fresh answer is not asked twice.
- Porelo's `stale_why` (`cause`, git's own `said`) is worded per cause and shown with git's lines beside the time, on
  the project page and the organization's pages; a cause this build does not know is named, and an older Porelo
  without the field says only the time.
- The check is waited for at most 60 seconds; one refused or not ended leaves the kept state, saying what stopped it,
  and only a host key the person declined to trust stops the read, so a write waiting on it does not go on. An older
  read ending after a newer one no longer sets how the cards stand, and a failed check's git lines are never shown.
- No test of its own for the wording: a stale answer was never shown as a good state, and the guard that an unread
  list never counts as empty (`test/ui/organization_project_pages_test.dart`) still holds.

## Acceptance

- Against a Porelo whose kept state is stale but whose check succeeds, the project page shows its repositories.
- Against a Porelo that cannot fetch the organization, the project page and the organization's pages say that it
  could not be checked, when it was checked last, and why.

## Declined from the reading

- A stale `project show` of a project not opened yet shows "no Git repository yet" from the kept state: Porelo answers
  such a project `not-opened` before it judges staleness, so the window cannot tell; the check now replaces most such
  answers. Unchanged.
- A malformed `stale_why` refuses the whole read rather than showing the kept state without a reason: every field of
  the answer is read that way, a malformed one never read as absent. Unchanged.
- The Organizations facts say "not read" for a stale state with no `checked_at`, which current Porelo always gives.
  Unchanged.
